#!/usr/bin/env python3
"""Check a finished document before handing it out.

| Check | What goes wrong when it fails |
|---|---|
| Network resources | The document does not open offline, and opening it tells a server who read it |
| Empty slots | A step ladder slot was never filled |
| Duplicate ids | Two elements share an id; links and SVG markers point at the wrong one |
| References | A link, marker, or label points at an id that does not exist |
| Contents and sections | The contents list keeps a section that was removed |
| Opening | Something other than one lead sentence sits between the title and the first heading |
| Collapsed blocks | A `<details>` ships open, so collapsing it achieved nothing |
| Text | Checked by `prose.py` (words, caption numbers, tables, contents vs headings, links) |
| Pages and print | Header buttons, pages, per-page contents, section id prefixes, and the PDF button agree |
| Figure per section | A section has neither a `<figure>` nor a stated reason (`data-nofig`) for having none |
| Figures and text | Checked by `figure.py` (captions, legends, names, term table in figures) |

`--live` opens the document in a Chromium-based browser (found by `chrome.py`) at each
width in `--widths` and checks that the page height does not move while the page loads
and that nothing overflows sideways. Sections and pages that are not shown are copied
out of the flow, drawn, and measured the same way.

The document language comes from `<html lang>`. Checks that read Japanese wording run
only for Japanese documents.

Output: `OK` lines passed, `NG` lines failed (details indented below), `--` lines only
count. Exit code 0 when nothing failed, 1 otherwise.

Usage:

  check.py <document.html> [--sections N] [--words FILE ...] [--no-default-words]
           [--live] [--widths 500,768,1024,1440]
"""
import argparse
import io
import os
import re
import shutil
import sys
import tempfile
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from figure import lang_of  # noqa: E402

# The contents of <script> and <style> are code, not markup: drop them and keep the tags.
CODE_BODY = re.compile(r"(<(script|style)\b[^>]*>).*?(</\2>)", re.S | re.I)

EMPTY_SLOT = re.compile(r'<div\b[^>]*\bclass="ladder"[^>]*>\s*</div>')
LADDER_SLOT = re.compile(r'<div\b[^>]*\bclass="ladder"[^>]*\bdata-ladder="')

ID = re.compile(r'\sid="([^"]+)"')
REF_URL = re.compile(r"url\(#([^)]+)\)")
REF_HREF = re.compile(r'(?:xlink:)?href="#([^"]+)"')
REF_ARIA = re.compile(r'aria-labelledby="([^"]+)"')
INLINE_SVG = re.compile(r"<svg\b.*?</svg>", re.S)

SECTION = re.compile(r"<section\b")
TOC = re.compile(r'<nav[^>]*class="[^"]*toc[^"]*"[^>]*>(.*?)</nav>', re.S)
TOC_ITEM = re.compile(r"<a\b[^>]*href=\"#")
# The document template lists sections as buttons that switch the shown section.
TOC_BTN = re.compile(r"<button\b[^>]*\bdata-sec=\"")
# `open` as an attribute of <details>, not as part of another attribute's value.
DETAILS_OPEN = re.compile(
    r"""<details\b(?:\s+(?!open\b)[\w:.-]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s"'>]+))?)*"""
    r"""\s+open(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s"'>]+))?[\s/>]""", re.I)
DETAILS = re.compile(r"<details\b", re.I)

# Opening: after the title, only one lead sentence until the contents or the first heading.
H1_END = re.compile(r"</h1>")
TOC_OPEN = re.compile(r'<nav[^>]*class="[^"]*toc[^"]*"')
H2_OPEN = re.compile(r"<h2\b")
LEAD = re.compile(r'<p\b[^>]*class="[^"]*lead[^"]*"[^>]*>.*?</p>', re.S)
# Opening tags only; closing tags of the title's wrapper are not content.
BLOCK_TAG = re.compile(
    r"<(div|ul|ol|p|table|section|figure|details|blockquote|aside|h[3-6])\b", re.I)
ANY_TAG = re.compile(r"<[A-Za-z]")
PANEL_ANY = re.compile(r"\bdata-panel=")

# Tabs (data-tab buttons and data-panel bodies): one button per body, section ids split by tab.
TAB_BTN = re.compile(r'<button\b[^>]*\bdata-tab="([^"]+)"[^>]*>', re.S)
PANEL_OPEN = re.compile(r'<div\b[^>]*\bdata-panel="([^"]+)"[^>]*>')
PANEL_HIDDEN = re.compile(r'<div\b[^>]*\bdata-panel="[^"]+"[^>]*\bhidden\b[^>]*>')
FILL = re.compile(r'<template\b[^>]*\bdata-fill="([^"]+)"')
SEC_ID = re.compile(r'<section\b[^>]*\bid="([^"]+)"')
# Japanese documents only: the tab number ("tab 1 /") and the stated tab count, in Japanese wording.
TAB_NO = re.compile(r"タブ(\d+)\s*/")
TAB_COUNT_TEXT = re.compile(r"中身は([0-9]+|[一二三四五六七八九十]+)つ")
KANJI = {"一": 1, "二": 2, "三": 3, "四": 4, "五": 5,
         "六": 6, "七": 7, "八": 8, "九": 9, "十": 10}
# Header pages (the document template): one header button per page.
PAGE_BTN = re.compile(r'<button\b[^>]*\bdata-page="([^"]+)"[^>]*>', re.S)
PAGE_OPEN = re.compile(r'<div\b[^>]*\bclass="doc-page"[^>]*\bdata-page="([^"]+)"[^>]*>')
PAGE_TOC = re.compile(r'<nav\b[^>]*\bclass="doc-toc"[^>]*\bdata-page="([^"]+)"[^>]*>(.*?)</nav>',
                      re.S)
PAGES_NAV = re.compile(r'<nav\b[^>]*\bclass="doc-pages"[^>]*>(.*?)</nav>', re.S)
# print.js fills every page before printing all of them through this function (doc.js).
FILL_ALL_PAGES = "dxFillAllPages"

DOC_SEC = re.compile(r'<section class="doc-sec" id="([^"]+)"([^>]*)>(.*?)</section>', re.S)
NOFIG_ATTR = re.compile(r'\bdata-nofig="([^"]*)"')

# Anything the browser fetches just by opening the page.
#
# `<a href>` is not counted: it only leaves the page when the reader clicks it.
REMOTE = r"(?:https?:)?//"
OUTBOUND = [
    (re.compile(r"""\ssrc\s*=\s*["']?(%s[^"'\s>]*)""" % REMOTE, re.I), "src"),
    (re.compile(r"""\ssrcset\s*=\s*["'][^"']*?(%s[^"'\s>,]*)""" % REMOTE, re.I), "srcset"),
    (re.compile(r"""<(?!a[\s>])[A-Za-z][\w-]*\b[^>]*\s(?:xlink:)?href\s*=\s*["']?(%s[^"'\s>]*)"""
                % REMOTE, re.I), "href"),
    (re.compile(r"""url\(\s*['"]?(%s[^'")\s]*)""" % REMOTE, re.I), "url()"),
    (re.compile(r"""@import\s+['"](%s[^'"]*)""" % REMOTE, re.I), "@import"),
]

# Injected before </body> for --live. It samples heights every 150 ms of virtual time and
# writes the result into a <pre> that --dump-dom returns.
PROBE = r"""
<script>
(function(){
  var pane = document.querySelector('.doc-main');
  var heights = [], stages = [], n = 0;
  function px(v){ return Math.round(v); }
  function paneHeight(){
    return pane ? pane.scrollHeight : px(document.body.getBoundingClientRect().height);
  }
  // Sections already shown are measured through the page height.
  var shown = [].filter.call(document.querySelectorAll('section'), function(s){
    return s.offsetParent !== null;
  });
  var shownFigs = [].filter.call(document.querySelectorAll('figure'), function(f){
    return f.offsetParent !== null;
  }).length;
  var width = (pane && pane.clientWidth) || document.body.clientWidth;
  // Sections not shown have no size. A copy laid out out of the flow has the size the
  // section gets when it is opened: absolute keeps it out of the page height, opacity 0
  // and pointer-events none keep it invisible and inert (display:none would give size 0).
  function stage(node, name){
    var box = document.createElement('div');
    box.setAttribute('data-check-stage', '');
    box.style.cssText = 'position:absolute;left:0;top:0;pointer-events:none;opacity:0;' +
                        'width:' + width + 'px';
    box.appendChild(node);
    document.body.appendChild(box);
    [].forEach.call(box.querySelectorAll('section'), function(s){
      s.classList.add('on');
      s.removeAttribute('hidden');
    });
    // Charts on pages that were never opened are drawn when the page opens.
    if (typeof window.dxCharts === 'function') window.dxCharts(box);
    var sec = box.querySelector('section') || box;
    stages.push({name: name, box: box, sec: sec, seen: []});
  }
  [].forEach.call(document.querySelectorAll('section'), function(s){
    if (s.offsetParent === null) stage(s.cloneNode(true), s.id || ('#' + stages.length));
  });
  // Pages that were never opened keep their body in <template>.
  [].forEach.call(document.querySelectorAll('template[data-fill]'), function(t){
    var secs = t.content.querySelectorAll('section');
    if (!secs.length) { stage(t.content.cloneNode(true), t.getAttribute('data-fill')); return; }
    [].forEach.call(secs, function(s){ stage(s.cloneNode(true), s.id || ('#' + stages.length)); });
  });
  function tick(){
    var h = paneHeight();
    if (!heights.length || heights[heights.length-1] !== h) heights.push(h);
    for (var i = 0; i < stages.length; i++){
      var s = stages[i], v = px(s.box.getBoundingClientRect().height);
      if (!s.seen.length || s.seen[s.seen.length-1] !== v) s.seen.push(v);
    }
  }
  var t = setInterval(function(){
    tick();
    if (n === 4) { window.scrollTo(0, document.body.scrollHeight); if (pane) pane.scrollTop = pane.scrollHeight; }
    if (n === 30) { window.scrollTo(0, 0); if (pane) pane.scrollTop = 0; }
    n++;
    if (n < 60) return;
    clearInterval(t);
    var moving = [], wide = [], unmeasured = [], secs = shown.length, figs = shownFigs;
    shown.forEach(function(s){
      var over = s.scrollWidth - s.clientWidth;
      if (over > 0) wide.push((s.id || 'section') + '(' + over + ')');
    });
    for (var i = 0; i < stages.length; i++){
      var s = stages[i], last = s.seen[s.seen.length-1];
      if (!last) { unmeasured.push(s.name); continue; }
      secs++;
      figs += s.box.querySelectorAll('figure').length;
      if (s.seen.length > 1) moving.push(s.name + '(' + s.seen.join(':') + ')');
      var over = s.sec.scrollWidth - s.sec.clientWidth;
      if (over > 0) wide.push(s.name + '(' + over + ')');
    }
    // A copy out of the flow does not change the page height when removed; any change is
    // the amount the copies pushed the page.
    var withStage = px(document.body.getBoundingClientRect().height);
    [].forEach.call(document.querySelectorAll('[data-check-stage]'), function(b){
      b.parentNode.removeChild(b);
    });
    var left = document.querySelectorAll('[data-check-stage]').length;
    var moved = withStage - px(document.body.getBoundingClientRect().height);
    var d = document.documentElement;
    var pre = document.createElement('pre');
    pre.textContent = '@@V@@' + heights.join(',') + '#' + moving.join(' ') +
                      '#' + unmeasured.join(' ') + '#' + secs + '/' + figs +
                      '#' + d.scrollWidth + '/' + d.clientWidth +
                      '#' + (pane ? pane.scrollWidth + '/' + pane.clientWidth : '0/0') +
                      '#' + wide.join(' ') +
                      '#' + stages.length + '/' + left + '/' + moved + '@@V@@';
    document.body.insertBefore(pre, document.body.firstChild);
  }, 150);
})();
</script>
"""

PROBE_OUT = re.compile(
    r"@@V@@([\d,]*)#([^#@]*)#([^#@]*)#(\d+)/(\d+)#(\d+)/(\d+)#(\d+)/(\d+)#([^#@]*)"
    r"#(\d+)/(\d+)/(-?\d+)@@V@@")
NAMED = re.compile(r"([^\s(]+)\(([^)]*)\)")


def strip_code(doc):
    """The markup without the code inside <script> and <style>."""
    return CODE_BODY.sub(r"\1\3", doc)


def refs(text):
    """Every id that text refers to."""
    out = []
    out += REF_URL.findall(text)
    out += REF_HREF.findall(text)
    for m in REF_ARIA.finditer(text):
        out += m.group(1).split()
    return out


def times(n):
    return "once" if n == 1 else "%d times" % n


def live(doc, widths):
    """Open the document in a browser at each width.

    Returns (failures, counted-only notes).
    """
    from chrome import ENV, find_chrome, run
    chrome, looked = find_chrome()
    if not chrome:
        return ["no Chromium-based browser found (looked in: %s). Set %s to a browser executable."
                % ("; ".join(looked), ENV)], []
    i = doc.lower().rfind("</body>")
    page = doc[:i] + PROBE + doc[i:] if i >= 0 else doc + PROBE
    bad = []
    unmeasured = set()
    counts = {}
    staged = {}
    tmpdir = tempfile.mkdtemp(prefix="dx-check-")
    try:
        tmp = os.path.join(tmpdir, "page.html")
        with io.open(tmp, "w", encoding="utf-8") as f:
            f.write(page)
        for w in widths:
            stdout, why = run(chrome, tmp, w, 900, 60000, 300)
            if why:
                bad.append("width %d: could not measure (%s)" % (w, why))
                continue
            m = PROBE_OUT.search(stdout)
            if not m:
                bad.append("width %d: the page returned no measurements" % w)
                continue
            steps = [v for v in m.group(1).split(",") if v]
            if len(steps) != 1:
                bad.append("width %d: the page height changed %s while loading (%s)"
                           % (w, times(len(steps) - 1), " -> ".join(steps)))
            for name, seq in NAMED.findall(m.group(2)):
                vals = seq.split(":")
                bad.append("width %d: hidden section %s changed height %s while loading (%s)"
                           % (w, name, times(len(vals) - 1), " -> ".join(vals)))
            unmeasured.update(m.group(3).split())
            counts[w] = (int(m.group(4)), int(m.group(5)))
            sw, cw = int(m.group(6)), int(m.group(7))
            if sw > cw:
                bad.append("width %d: the page is %d px wider than the window" % (w, sw - cw))
            psw, pcw = int(m.group(8)), int(m.group(9))
            if psw > pcw:
                bad.append("width %d: the content column scrolls sideways by %d px" % (w, psw - pcw))
            for name, over in NAMED.findall(m.group(10)):
                bad.append("width %d: section %s is %s px wider than its column" % (w, name, over))
            staged[w] = int(m.group(11))
            left, moved = int(m.group(12)), int(m.group(13))
            if left:
                bad.append("width %d: %d measuring copies were left in the page" % (w, left))
            if moved:
                bad.append("width %d: measuring copies moved the page height by %d px" % (w, moved))
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)
    notes = ["-- browser %s" % chrome]
    if counts:
        if len(set(counts.values())) == 1:
            secs, figs = next(iter(counts.values()))
            notes.append("-- measured at each width: sections %d, figures %d (copied out of the flow: %d)"
                         % (secs, figs, max(staged.values()) if staged else 0))
        else:
            notes.append("-- measured: %s" % ", ".join(
                "width %d sections %d figures %d" % (w, counts[w][0], counts[w][1])
                for w in widths if w in counts))
    if unmeasured:
        names = sorted(unmeasured)
        notes.append("-- could not measure (height 0): %d (%s)" % (len(names), " ".join(names)))
    return bad, notes


def panels_of(body):
    """(tab key, that tab's body) in document order."""
    hits = [(m.group(1), m.start(), m.end()) for m in PANEL_OPEN.finditer(body)]
    out = []
    for i, (key, start, end) in enumerate(hits):
        stop = hits[i + 1][1] if i + 1 < len(hits) else len(body)
        out.append((key, body[end:stop]))
    return out


def tabs_check(body, found, ja):
    """Count tab mismatches. Returns None for documents without tabs."""
    btns = TAB_BTN.findall(body)
    parts = panels_of(body)
    if not btns and not parts:
        return None
    n = 0
    if len(btns) != len(parts):
        n += 1
        found.append("tab buttons %d / tab bodies %d (counts differ)" % (len(btns), len(parts)))
    if sorted(btns) != sorted(k for k, _ in parts):
        n += 1
        found.append("button keys %s do not match body keys %s"
                     % (", ".join(btns), ", ".join(k for k, _ in parts)))
    if len(set(btns)) != len(btns):
        n += 1
        found.append("two or more buttons share a key")

    # Tabs not shown at first live in <template>, so opening the page draws only one tab.
    shown = len(parts) - len(PANEL_HIDDEN.findall(body))
    filled = len(FILL.findall(body))
    if shown != 1:
        n += 1
        found.append("tabs shown at first: %d (should be 1)" % shown)
    if filled != len(parts) - 1:
        n += 1
        found.append("tabs in <template>: %d (should be %d)" % (filled, len(parts) - 1))

    # Each tab uses its own section id prefix (`a-s3`), so ids never collide across tabs.
    # The prefix need not equal the tab key.
    seen = {}
    for key, frag in parts:
        heads = {}
        for sid in SEC_ID.findall(frag):
            heads.setdefault(sid.split("-", 1)[0] if "-" in sid else "", []).append(sid)
        if len(heads) > 1:
            n += 1
            found.append("tab %s splits its section ids over %d prefixes (%s)"
                         % (key, len(heads), ", ".join(sorted(heads)[:4])))
        for head in heads:
            if seen.setdefault(head, key) != key:
                n += 1
                found.append("prefix %s is used by two tabs, %s and %s"
                             % (head or "(none)", seen[head], key))
        if not TOC.search(frag):
            n += 1
            found.append("tab %s has no contents list" % key)

    if ja:
        # Tab numbers in the text count up from 1 in button order.
        nos = [int(x) for x in TAB_NO.findall(body)]
        if nos and nos != list(range(1, len(nos) + 1)):
            n += 1
            found.append("tab numbers are not consecutive (%s)" % ", ".join(str(x) for x in nos))
        # The tab count stated in the opening matches the tabs.
        m = TAB_COUNT_TEXT.search(re.sub(r"<[^>]+>", "", body))
        if m:
            said = m.group(1)
            said = int(said) if said.isdigit() else KANJI.get(said, -1)
            if said != len(parts):
                n += 1
                found.append("the opening states %d parts, but there are %d tabs"
                             % (said, len(parts)))
    return n


def pages_check(body, doc, found):
    """Count mismatches in header pages (the document template).

    Returns None for documents without pages, else (count, number of pages).
    """
    pages = PAGE_OPEN.findall(body)
    if not pages:
        return None
    n = 0
    nav = PAGES_NAV.search(body)
    btns = PAGE_BTN.findall(nav.group(1)) if nav else []
    if len(pages) > 1:
        if sorted(btns) != sorted(pages) or len(set(btns)) != len(btns):
            n += 1
            found.append("header buttons %s do not match pages %s"
                         % (", ".join(btns) or "(none)", ", ".join(pages)))
    elif nav:
        n += 1
        found.append("a document with one topic has header tabs")

    # Pages not shown at first live in <template>, so opening the page draws only one page.
    filled = FILL.findall(body)
    if sorted(filled) != sorted(pages[1:]):
        n += 1
        found.append("pages in <template>: %s (should be every page but the first: %s)"
                     % (", ".join(filled) or "(none)", ", ".join(pages[1:]) or "(none)"))

    # Each page's contents list matches that page's sections, and prefixes stay per page.
    tocs = dict((k, v) for k, v in PAGE_TOC.findall(body))
    starts = [(m.group(1), m.end()) for m in PAGE_OPEN.finditer(body)]
    seen = {}
    for i, (key, end) in enumerate(starts):
        stop = starts[i + 1][1] if i + 1 < len(starts) else len(body)
        sids = SEC_ID.findall(body[end:stop])
        if key not in tocs:
            n += 1
            found.append("page %s has no contents list" % key)
            continue
        listed = re.findall(r'data-sec="([^"]+)"', tocs[key])
        if listed != sids:
            n += 1
            found.append("page %s: contents %s do not match sections %s"
                         % (key, ", ".join(listed) or "(none)", ", ".join(sids) or "(none)"))
        for head in set(sid.split("-", 1)[0] for sid in sids):
            if seen.setdefault(head, key) != key:
                n += 1
                found.append("prefix %s is used by two pages, %s and %s" % (head, seen[head], key))

    # Printing: the PDF button and the function that fills unopened pages before printing.
    if "printbar" not in doc or FILL_ALL_PAGES not in doc:
        n += 1
        found.append("the PDF button script (print.js) is missing")
    return n, len(pages)


def figure_rule(body):
    """Each section of the document template has a figure or a stated reason for none.

    Charts, HTML figures with a caption, and captioned step ladders are all `<figure>`.
    A section without one gives the reason as `nofigure` in the content JSON, which
    render.py writes as `data-nofig`.
    Returns None for documents without template sections, else
    (ids of sections with neither, number of sections, number with a reason).
    """
    secs = DOC_SEC.findall(body)
    if not secs:
        return None
    missing, reasons = [], 0
    for sid, attrs, inner in secs:
        if "<figure" in inner:
            continue
        m = NOFIG_ATTR.search(attrs)
        if m and m.group(1).strip():
            reasons += 1
            continue
        missing.append(sid)
    return missing, len(secs), reasons


def print_check(doc, found):
    """Tab documents: the PDF button and the switch for what gets printed."""
    n = 0
    if "printbar" not in doc:
        n += 1
        found.append("the PDF button (printbar) is missing")
    if "print-current" not in doc:
        n += 1
        found.append("the switch for what gets printed (print-current) is missing")
    return n


def opening_check(body, found):
    """Between each title and the contents or first heading, only one lead sentence.

    Judged by position, not wording: any other block there fails, whatever it says.
    Returns None for tab documents (the tab bar sits under the title) and for documents
    without a title followed by contents or a heading.
    Otherwise returns (failures, elements looked at, lead sentences, titles).
    """
    if PANEL_ANY.search(body):
        return None
    heads = []
    for h1 in H1_END.finditer(body):
        stops = [m.start() for m in (TOC_OPEN.search(body, h1.end()),
                                     H2_OPEN.search(body, h1.end())) if m]
        if stops:
            heads.append(body[h1.end():min(stops)])
    if not heads:
        return None
    n = ntag = nlead = 0
    for head in heads:
        leads = LEAD.findall(head)
        rest = LEAD.sub("", head)
        nlead += len(leads)
        ntag += len(ANY_TAG.findall(head))
        if len(leads) > 1:
            n += 1
            found.append("%d lead sentences under one title (keep one)" % len(leads))
        for m in BLOCK_TAG.finditer(rest):
            n += 1
            found.append("<%s> between the title and the first heading" % m.group(1).lower())
    return n, ntag, nlead, len(heads)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("html")
    ap.add_argument("--sections", type=int, default=None, help="expected number of sections")
    ap.add_argument("--live", action="store_true",
                    help="open the document in a browser and measure height and overflow")
    ap.add_argument("--widths", default="500,768,1024,1440",
                    help="window widths for --live, comma separated")
    ap.add_argument("--words", action="append", default=None,
                    help="term table for this document (passed to prose.py and figure.py, repeatable)")
    ap.add_argument("--no-default-words", action="store_true",
                    help="do not apply the default word lists")
    ap.add_argument("--para", type=int, default=None,
                    help="characters that make a paragraph long (passed to prose.py)")
    ap.add_argument("--sent", type=int, default=None,
                    help="characters that make a sentence long (passed to prose.py)")
    a = ap.parse_args(argv)

    if a.live:
        try:
            widths = [int(x) for x in a.widths.split(",") if x.strip()]
        except ValueError:
            ap.error("--widths takes whole numbers separated by commas")
        if not widths or min(widths) <= 0:
            ap.error("--widths takes positive whole numbers")

    doc = io.open(a.html, encoding="utf-8").read()
    body = strip_code(doc)
    ja = lang_of(doc).startswith("ja")
    ng = 0

    # 1. Network resources
    hits = [(label, pat.findall(doc)) for pat, label in OUTBOUND]
    got = [(label, urls) for label, urls in hits if urls]
    if got:
        ng += 1
        print("NG resources loaded from the network: %s"
              % ", ".join("%s %d" % (label, len(urls)) for label, urls in got))
        for label, urls in got:
            for u in urls:
                print("     %s %s" % (label, u[:100]))
    else:
        print("OK nothing is loaded from the network")

    # 2. Empty slots
    empty = EMPTY_SLOT.findall(body)
    nslot = len(LADDER_SLOT.findall(body))
    if empty:
        ng += 1
        print("NG empty step ladder slots: %d of %d (run ladder.py)" % (len(empty), nslot))
    else:
        print("OK no empty slots (step ladders %d)" % nslot)

    # 3. Duplicate ids and 4. references.
    #
    # Every failing item is listed, so the count in the NG line always matches the lines below.
    ids = ID.findall(body)
    dup = [(k, v) for k, v in Counter(ids).items() if v > 1]
    if dup:
        ng += 1
        print("NG duplicate ids: %d" % len(dup))
        for k, v in dup:
            print("     %s ... %d times" % (k, v))
    else:
        print("OK %d ids, no duplicates" % len(ids))

    # An inline SVG resolves its own references (markers, gradients); other markup
    # resolves against every id in the document.
    inline = INLINE_SVG.findall(body)
    allids = set(ids)
    unresolved = []
    for i, f in enumerate(inline):
        own = set(ID.findall(f))
        for r in refs(f):
            if r not in own:
                unresolved.append("inline SVG %d: %s" % (i + 1, r))
    for r in refs(INLINE_SVG.sub("", body)):
        if r not in allids:
            unresolved.append("document: %s" % r)
    if unresolved:
        ng += 1
        print("NG unresolved references: %d" % len(unresolved))
        for u in unresolved:
            print("     %s" % u)
    else:
        print("OK every reference resolves (inline SVG %d)" % len(inline))

    # 5. Contents and sections
    nsec = len(SECTION.findall(body))
    tocs = TOC.findall(body)
    if tocs:
        # The document template has one contents list per page; count them all.
        nitem = sum(len(TOC_ITEM.findall(t)) + len(TOC_BTN.findall(t)) for t in tocs)
        # Fails only when the contents list has more items: a removed section is still listed.
        # Which section each item points at is checked by the page check below.
        if nitem > nsec:
            ng += 1
            print("NG contents %d items / sections %d (the contents list has extra items)"
                  % (nitem, nsec))
        elif nitem < nsec:
            print("-- contents %d items / sections %d (%d sections not listed)"
                  % (nitem, nsec, nsec - nitem))
        else:
            print("OK contents %d items = sections %d" % (nitem, nsec))
    else:
        print("-- no contents list (sections %d)" % nsec)
    if a.sections is not None and nsec != a.sections:
        ng += 1
        print("NG sections %d (expected %d)" % (nsec, a.sections))

    # 6. Opening
    openbad = []
    op = opening_check(body, openbad)
    if op is None:
        print("-- opening not checked (no title followed by contents or a heading, or a tab document)")
    else:
        opn, ntag, nlead, nhead = op
        if opn:
            ng += 1
            print("NG opening: %d extra items after the title (titles %d, elements looked at %d)"
                  % (opn, nhead, ntag))
            for b in openbad:
                print("     %s" % b)
        else:
            print("OK opening: only lead sentences after the title (titles %d, leads %d, elements looked at %d)"
                  % (nhead, nlead, ntag))

    # 7. Collapsed blocks start closed
    nopen = len(DETAILS_OPEN.findall(body))
    ndet = len(DETAILS.findall(body))
    if nopen:
        ng += 1
        print("NG open <details>: %d of %d (remove the open attribute)" % (nopen, ndet))
    else:
        print("OK %d <details>, all closed" % ndet)

    # 8. Text (prose.py). Whether the content is true is not checked here.
    import prose
    words = prose.load_words(a.words) if a.words else None
    allow = prose.load_allow(a.words) if a.words else None
    pn, pnotes, pm = prose.run(doc, words, not a.no_default_words,
                                  para_max=a.para, sent_max=a.sent, allow=allow)
    for line in pnotes:
        print(line)
    for line in pn:
        print("     %s" % line)
    for n, sid, text in (pm.get("long_p") or [])[:3]:
        print("     long paragraph %d (%s) %s..." % (n, sid, text[:40]))
    if pn:
        ng += 1

    # 9. Pages, tabs, and printing
    pagebad = []
    tn = tabs_check(body, pagebad, ja)
    pg = pages_check(body, doc, pagebad)
    if pg is not None:
        if pg[0]:
            ng += 1
            print("NG pages and printing: %d" % pg[0])
            for b in pagebad:
                print("     %s" % b)
        elif pg[1] > 1:
            print("OK %d pages: header buttons, contents, and sections agree; the PDF button is present"
                  % pg[1])
        else:
            print("OK 1 page (no header): contents and sections agree; the PDF button is present")
    elif tn is None:
        print("-- no pages or tabs")
    else:
        pn2 = print_check(doc, pagebad)
        if tn or pn2:
            ng += 1
            print("NG tabs and printing: %d" % (tn + pn2))
            for b in pagebad:
                print("     %s" % b)
        else:
            print("OK %d tabs: keys, sections, contents, and numbers agree; the PDF button is present"
                  % len(panels_of(body)))

    # 10. A figure in every section of the document template
    fr = figure_rule(body)
    if fr is not None:
        if fr[0]:
            ng += 1
            print("NG sections without a figure: %d (%s)" % (len(fr[0]), " ".join(fr[0])))
            print("     add a figure, or give the section a nofigure reason in the content JSON")
        else:
            print("OK all %d sections have a figure (sections with a nofigure reason: %d)"
                  % (fr[1], fr[2]))

    # 11. Figures and text (figure.py)
    import figure
    fng, fnotes, fdetail = figure.run(doc, words=words, allow=allow,
                                      use_default=not a.no_default_words)
    for line in fnotes:
        print(line)
    for line in fng:
        print("     %s" % line)
    for label, where in fdetail["only"][:3]:
        print("     name only in figures: %s (%s)" % (label, ", ".join(sorted(set(where))[:3])))
    if fng:
        ng += 1

    # 12. Open it in a browser
    if a.live:
        bad, notes = live(doc, widths)
        for line in notes:
            print(line)
        if bad:
            ng += 1
            print("NG browser measurements: %d" % len(bad))
            for b in bad:
                print("     %s" % b)
        else:
            print("OK at widths %s the page height stays still and nothing overflows sideways"
                  % "/".join(str(w) for w in widths))

    print("---- %s (%d bytes)" % ("no problems" if not ng else "NG %d" % ng,
                                  len(doc.encode("utf-8"))))
    return 0 if not ng else 1


if __name__ == "__main__":
    sys.exit(main())
