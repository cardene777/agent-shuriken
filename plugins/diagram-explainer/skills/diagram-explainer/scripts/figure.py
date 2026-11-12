#!/usr/bin/env python3
"""Check how the figures and the text of a finished document fit together.

`prose.py` checks the words of the text. This script checks the joins between
figures and text:

| Check | Result | Why |
|---|---|---|
| Figure caption | NG | A figure without a caption is shown without saying what it is. A chart or step ladder placed outside `<figure>` fails here too |
| Legend placement | NG | A legend inside a collapsed `<details>` cannot be read while looking at the figure |
| Term table in figure text | NG | Words the term table says to replace also must not appear inside figures |
| Paragraph before a figure | counted | The text does not say what the figure shows |
| Names only in figures | counted | A sign that the figure and the text call the same thing by different names |

Names that appear only in figures are counted, not failed: whether two names mean the
same thing depends on the document's context.

Figure text is read from HTML figures (`<figure class="free">`), step ladders
(the `<svg>` that `ladder.py` puts in `<div class="ladder">`), and charts (the strings
in the chart's JSON spec and its buttons). Captions are text, not figure content.

Usage:

  figure.py <document.html> [--top 8] [--words <term table>] [--words <another>] [--no-default-words]
"""
import argparse
import html as H
import io
import json
import os
import re
import sys
from collections import OrderedDict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

LANG = re.compile(r"<html\b[^>]*\blang=[\"']?([A-Za-z-]*)", re.I)
FIGURE = re.compile(r"<figure\b([^>]*)>(.*?)</figure>", re.S)
FIGCAP = re.compile(r"<figcaption\b[^>]*>.*?</figcaption>", re.S)
CLASS = re.compile(r'\bclass="([^"]*)"')
ID_ATTR = re.compile(r'\bid="([^"]+)"')
LEGEND = re.compile(r'<div\b[^>]*\bclass="(?:[^"]*\s)?legend(?:\s[^"]*)?"[^>]*>')
DETAILS = re.compile(r"<details\b[^>]*>(.*?)</details>", re.S)
SECTION = re.compile(r'<section\b[^>]*\bid="([^"]+)"[^>]*>(.*?)</section>', re.S)
SECTION_START = re.compile(r'<section\b[^>]*\bid="([^"]+)"')
PARA = re.compile(r"<p\b[^>]*>(.*?)</p>", re.S)
TAG = re.compile(r"<[^>]+>")
CODE_BLOCK = re.compile(r"<(script|style)\b.*?</\1>", re.S)
# A step ladder slot and the `<svg>` that ladder.py puts in it.
LADDER = re.compile(r'<div\b[^>]*\bclass="ladder"[^>]*\bdata-ladder="([\w.-]+)"[^>]*>'
                    r'\s*(?:<svg\b.*?</svg>)?\s*</div>', re.S)
CHART_SVG = re.compile(r'<svg\b[^>]*\bdata-chart="[^"]*"[^>]*>')
CHART_SPEC = re.compile(r'<script\b[^>]*\btype="application/json"[^>]*>(.*?)</script>', re.S)
# Tags that run inside one label; every other tag ends a label. `span` ends a label
# because HTML figures often draw each box as a span.
INLINE_TAG = re.compile(r"</?(?:a|abbr|b|code|em|i|kbd|mark|q|s|small|strong|sub|sup|"
                        r"tspan|u)\b[^>]*>", re.I)
# A name has at least one letter (Latin, kana, or kanji); numbers and symbols are not names.
NAMEY = re.compile(r"[A-Za-zぁ-んァ-ヴ一-龥]")

KINDS = ("HTML figure", "ladder", "chart")


def lang_of(doc):
    """The document language from `<html lang>`, lower case; `en` when it is missing."""
    m = LANG.search(doc)
    return (m.group(1) or "en").lower() if m else "en"


def visible(fragment):
    """Only the text a reader sees."""
    return H.unescape(TAG.sub(" ", CODE_BLOCK.sub(" ", fragment)))


# Two inline elements side by side, such as a name and its subtitle in one box
# (`<b>Catalog</b><small>every copy</small>`), are two labels, not one.
INLINE_PAIR = re.compile(r"(</(?:b|code|em|i|kbd|mark|small|strong|u)>)(\s*)"
                         r"(?=<(?:b|code|em|i|kbd|mark|small|strong|u)\b)", re.I)


def labels(fragment):
    """Separate pieces of visible text, one per box, cell, line, or SVG `<text>`."""
    fragment = INLINE_PAIR.sub(r"\1<br>\2", CODE_BLOCK.sub(" ", fragment))
    fragment = INLINE_TAG.sub("", fragment)
    out = []
    for piece in TAG.split(fragment):
        s = re.sub(r"\s+", " ", H.unescape(piece)).strip()
        if s:
            out.append(s)
    return out


def spec_strings(fragment):
    """Every string value in a chart's JSON spec (the labels the chart draws)."""
    out = []

    def walk(v):
        if isinstance(v, str):
            if v.strip():
                out.append(v.strip())
        elif isinstance(v, list):
            for x in v:
                walk(x)
        elif isinstance(v, dict):
            for x in v.values():
                walk(x)

    for raw in CHART_SPEC.findall(fragment):
        try:
            walk(json.loads(raw.replace("<\\/", "</")))
        except ValueError:
            continue
    return out


def section_at(starts, pos):
    sid = "body"
    for start, name in starts:
        if start > pos:
            break
        sid = name
    return sid


def figure_blocks(body):
    """(section id, figure markup, text before it in the section) for every `<figure>`."""
    out = []
    for sid, frag in SECTION.findall(body):
        for m in FIGURE.finditer(frag):
            out.append((sid, m.group(0), frag[:m.start()]))
    if out:
        return out
    # A document without sections is read as one body.
    for m in FIGURE.finditer(body):
        out.append(("body", m.group(0), body[:m.start()]))
    return out


def bare_figures(body):
    """Charts and step ladders placed outside any `<figure>`: (section id, name, markup)."""
    spans = [(m.start(), m.end()) for m in FIGURE.finditer(body)]
    starts = [(m.start(), m.group(1)) for m in SECTION_START.finditer(body)]

    def inside(pos):
        return any(s <= pos < e for s, e in spans)

    out = []
    for m in LADDER.finditer(body):
        if not inside(m.start()):
            out.append((section_at(starts, m.start()), "ladder " + m.group(1), m.group(0)))
    for m in CHART_SVG.finditer(body):
        if not inside(m.start()):
            ident = ID_ATTR.search(m.group(0))
            out.append((section_at(starts, m.start()),
                        "chart " + (ident.group(1) if ident else "?"), m.group(0)))
    return out


def figure_texts(sid, index, fig):
    """(figure name, OrderedDict kind -> labels) for one `<figure>`, caption excluded."""
    attrs = FIGURE.match(fig).group(1)
    inner = FIGCAP.sub(" ", FIGURE.match(fig).group(2))
    ident = ID_ATTR.search(attrs) or ID_ATTR.search(inner)
    name = ident.group(1) if ident else "%s figure %d" % (sid, index)
    kinds = OrderedDict((k, []) for k in KINDS)
    for m in LADDER.finditer(inner):
        kinds["ladder"] += labels(m.group(0))
    rest = LADDER.sub(" ", inner)
    cls = CLASS.search(attrs)
    if cls and "chart" in cls.group(1).split():
        kinds["chart"] += spec_strings(rest) + labels(rest)
    else:
        kinds["HTML figure"] += labels(rest)
    return name, kinds


def all_figure_texts(body):
    """(figure name, kind -> labels) for every figure, plus ladders outside `<figure>`."""
    out = []
    counter = {}
    for sid, fig, _before in figure_blocks(body):
        counter[sid] = counter.get(sid, 0) + 1
        out.append(figure_texts(sid, counter[sid], fig))
    for _sid, name, markup in bare_figures(body):
        if name.startswith("ladder "):
            kinds = OrderedDict((k, []) for k in KINDS)
            kinds["ladder"] = labels(markup)
            out.append((name, kinds))
    return out


def text_without_figures(body):
    """Visible text of the document with figure content removed and captions kept."""
    def keep_caption(m):
        return " ".join(FIGCAP.findall(m.group(0)))
    body = FIGURE.sub(keep_caption, body)
    body = LADDER.sub(" ", body)
    return visible(body)


def flat(text):
    """Form used to compare names with the text: no whitespace, lower case."""
    return re.sub(r"\s+", "", text).lower()


def run(doc, top=8, words=None, allow=None, use_default=True):
    """Returns (findings that fail, counted-only report lines, details).

    `words` (the document's term table) and, for Japanese documents, the default word
    lists are applied to the text inside figures.
    """
    import prose

    body = doc
    ja = lang_of(doc).startswith("ja")
    ng = []
    notes = []

    blocks = figure_blocks(body)
    bare = bare_figures(body)

    # 1. Captions. A chart or ladder outside <figure> cannot have a caption.
    nocap = []
    for sid, fig, _before in blocks:
        if not FIGCAP.search(fig):
            ident = ID_ATTR.search(FIGURE.match(fig).group(1))
            nocap.append("%s %s" % (sid, ident.group(1)) if ident else sid)
    nocap += ["%s %s" % (sid, name) for sid, name, _m in bare]
    nall = len(blocks) + len(bare)
    if nocap:
        ng.append("figures without a caption: %d (%s)" % (len(nocap), ", ".join(nocap[:4])))
    if not nall:
        notes.append("-- no figures in <figure> form")
    elif not nocap:
        notes.append("OK all %d figures have a caption" % nall)
    else:
        notes.append("NG figures without a caption: %d of %d (outside <figure>: %d)"
                     % (len(nocap), nall, len(bare)))

    # 2. Legends. A legend inside <details> passes only when its figure is in the same
    #    <details>: opening it shows both together.
    hidden_legend = []
    for sid, frag in SECTION.findall(body) or [("body", body)]:
        for d in DETAILS.findall(frag):
            if LEGEND.search(d) and not ("<figure" in d or LADDER.search(d) or CHART_SVG.search(d)):
                hidden_legend.append(sid)
    nleg = len(LEGEND.findall(body))
    if hidden_legend:
        ng.append("legends inside a collapsed block: %d (%s)"
                  % (len(hidden_legend), ", ".join(hidden_legend[:4])))
    if not nleg:
        notes.append("-- no legends")
    elif not hidden_legend:
        notes.append("OK all %d legends sit with their figure" % nleg)
    else:
        notes.append("NG legends inside a collapsed block: %d of %d" % (len(hidden_legend), nleg))

    # 3. Paragraph before each figure (counted only).
    nolead = []
    for sid, _fig, before in blocks:
        paras = [re.sub(r"\s+", "", visible(p)) for p in PARA.findall(before)]
        if not [p for p in paras if len(p) >= 20]:
            nolead.append(sid)
    notes.append("-- figures with no paragraph before them: %d of %d" % (len(nolead), len(blocks)))

    # 4. Names that appear in figures but nowhere in the text (counted only).
    #    Read from HTML figures and step ladders; chart labels come from data, not names.
    figtexts = all_figure_texts(body)
    text = flat(text_without_figures(body))
    only = OrderedDict()
    for name, kinds in figtexts:
        for label in kinds["HTML figure"] + kinds["ladder"]:
            if not 2 <= len(label) <= 40 or not NAMEY.search(label):
                continue
            f = flat(label)
            if f and f not in text:
                only.setdefault(label, []).append(name)
    shared = [k for k, v in only.items() if len(set(v)) >= 2]
    notes.append("-- names only in figures, not in the text: %d (in 2 or more figures: %d)"
                 % (len(only), len(shared)))

    # 5. Term table words in figure text. The default word lists are Japanese and apply
    #    to Japanese documents only; a table given with --words applies to every document.
    table = OrderedDict()
    if ja and use_default:
        table.update(prose.default_words())
    table.update(words or {})
    if table:
        hits = OrderedDict()
        seen = OrderedDict((kind, 0) for kind in KINDS)
        for name, kinds in figtexts:
            for kind, found in kinds.items():
                found = sorted(set(found))
                seen[kind] += len(found)
                for label in found:
                    rest = prose.drop_allowed(label, allow)
                    for word, into in table.items():
                        if word and word in rest:
                            hits.setdefault((kind, word, into), set()).add(name)
        for (kind, word, into), where in hits.items():
            ng.append("term-table word in %s text: %s%s (%s)"
                      % (kind, word, (" -> %s" % into) if into else "",
                         ", ".join(sorted(where)[:4])))
        looked = ", ".join("%s %d" % kv for kv in seen.items())
        if not hits:
            notes.append("OK no term-table words in figure text (words %d / labels: %s)"
                         % (len(table), looked))
        else:
            notes.append("NG term-table words in figure text: %d (words %d / labels: %s)"
                         % (len(hits), len(table), looked))
    else:
        notes.append("-- no term table (figure text not checked for words)")

    detail = {
        "nolead": nolead[:top],
        "only": sorted(only.items(), key=lambda kv: -len(kv[1]))[:top],
        "figs": len(blocks),
        "bare": len(bare),
    }
    return ng, notes, detail


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("html")
    ap.add_argument("--top", type=int, default=8, help="how many details to list")
    ap.add_argument("--words", action="append", default=None,
                    help="term table for this document (same format as prose.py, repeatable)")
    ap.add_argument("--no-default-words", action="store_true",
                    help="do not apply the default word lists (Japanese documents)")
    a = ap.parse_args(argv)

    import prose
    doc = io.open(a.html, encoding="utf-8").read()
    words = prose.load_words(a.words) if a.words else None
    allow = prose.load_allow(a.words) if a.words else None
    ng, notes, detail = run(doc, a.top, words, allow, not a.no_default_words)
    for line in notes:
        print(line)
    for line in ng:
        print("     %s" % line)
    if detail["nolead"]:
        print("     figures with no paragraph before them: %s" % ", ".join(detail["nolead"]))
    for label, where in detail["only"]:
        print("     name only in figures: %s (%s)" % (label, ", ".join(sorted(set(where))[:3])))
    print("---- %s (%s)"
          % ("no figure findings" if not ng else "figure findings: %d" % len(ng),
             os.path.basename(a.html)))
    return 0 if not ng else 1


if __name__ == "__main__":
    sys.exit(main())
