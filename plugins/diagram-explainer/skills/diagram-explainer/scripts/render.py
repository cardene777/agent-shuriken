#!/usr/bin/env python3
"""Render a content JSON into the body of the explainer template (templates/starter-doc.html).

The content JSON is the source of truth: pages, sections, the contents list, and every
figure come from the same input. Figures are drawn inside the document:

- `chart` blocks (time bands, capped bars, bar charts, periods) carry the JSON that
  assets/charts.js draws when the page opens.
- `html` blocks with a `caption` become `<figure class="free">`. Their CSS applies only
  inside the block (nested under the block id). Anything that runs on open (`<script>`,
  attributes starting with `on`) or loads from outside (`<link>`, `<iframe>`, ...) is refused.
- A step ladder is an `html` block holding `<div class="ladder" data-ladder="NAME"></div>`,
  filled later by ladder.py.

Fixed shapes that help reading without being figures (keys, cards, note, compare, table) are
built from their own fields.

Resulting layout:

- a header band holds the title, a language switch (English / Japanese interface text), a light
  or dark switch, and a help button; on narrow screens the switches move into the top bar
- with 2 or more `tabs`, page tabs in the header split the document into pages
- under the first title and lead, a facts table gives the time the document describes, and the
  specification it follows and the date its sources were read when they are given (`facts`)
- the left contents list picks a section; one section is shown at a time
- pages not shown first are kept in a `template` and built when opened
- on narrow screens a bar shows the current section and a contents button slides the list in
- the words of the frame and the switches come from assets/ui.json, in the document language

Everything between `<!-- diagram-explainer:content:start -->` and
`<!-- diagram-explainer:content:end -->` in the template is replaced. The rest of the
template (asset markers and the scripts that load them) stays as it is.
"""
import argparse
import datetime
import html
import io
import json
import os
import re
import sys


ID = re.compile(r"^[A-Za-z][A-Za-z0-9_-]*$")
START = "<!-- diagram-explainer:content:start -->"
END = "<!-- diagram-explainer:content:end -->"
TEMPLATE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        "templates", "starter-doc.html")
# Document languages. The first one is the default.
LANGS = ("en", "ja")
# The interface words of the page, keyed by language (`en`, `ja`). assets/ui.json is the only
# place they are defined: render.py and ladder.py read it, build.py copies it into the page, and
# assets/doc.js reads it there to rewrite every element marked with `data-ui`, `data-ui-label`,
# or `data-ui-title` when the reader switches the interface language.
UI_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "ui.json")
# The symbol kept in front of the contents button text in both languages.
CONTENTS_ICON = "\u2630"
# Icons of the light and dark buttons. Each button also has a label in the interface language.
SUN_ICON = ('<svg viewBox="0 0 16 16" aria-hidden="true" focusable="false"><circle cx="8" cy="8" r="3"/>'
            '<path d="M8 1.5V3M8 13v1.5M1.5 8H3M13 8h1.5M3.4 3.4l1.1 1.1M11.5 11.5l1.1 1.1'
            'M3.4 12.6l1.1-1.1M11.5 4.5l1.1-1.1"/></svg>')
MOON_ICON = ('<svg viewBox="0 0 16 16" aria-hidden="true" focusable="false">'
             '<path d="M13.4 10.1A5.6 5.6 0 0 1 5.9 2.6a5.6 5.6 0 1 0 7.5 7.5z"/></svg>')
# The icon at the start of a warning note.
WARN_ICON = ('<svg class="note-icon" viewBox="0 0 16 16" aria-hidden="true" focusable="false">'
             '<path d="M8 1.8 14.8 13.8H1.2z"/><path d="M8 6.3v3.6M8 11.6v.1"/></svg>')
# Chart kinds drawn inside the document. assets/charts.js draws them.
CHARTS = ("timeband", "capbar", "bars", "period")
# The most view buttons a time band chart may have; more choices than this are hard to compare.
MAX_VIEWS = 5
# Color names for the reading shapes. The colors themselves live in assets/doc.css.
TONES = ("accent", "good", "warn", "info")
# The facts under the first title, in this order: the time the document describes, the
# specification and version it follows, and the date its sources were read. Each pairs the
# content JSON field with the interface word of its label.
FACTS = (("asOf", "factAsOf"), ("spec", "factSpec"), ("read", "factRead"))
# A run of this many `details` blocks or more gets buttons that open or close them all.
DETAILS_RUN = 4
# What an `html` block may not contain: things that run on open, things that load from
# outside, and things that move styles out of the block.
FREE_BANNED = re.compile(
    r"<\s*/?\s*(?:script|style|link|iframe|object|embed|meta|base|frame)\b|\son[a-z]+\s*=|javascript:", re.I)
CSS_BANNED = re.compile(r"@import|</|<!--", re.I)
HTML_OPEN = re.compile(r"<html\b[^>]*>", re.I)


def esc(value):
    return html.escape(str(value), quote=True)


def fail(message):
    raise ValueError(message)


def check_id(value, where):
    if not isinstance(value, str) or not ID.fullmatch(value):
        fail("invalid %s id: %r" % (where, value))
    return value


def inline(text):
    """Turn the one inline markup the content allows (`code`) into HTML."""
    parts = re.split(r"(`[^`]+`)", str(text))
    return "".join(
        "<code>%s</code>" % esc(part[1:-1]) if part.startswith("`") else esc(part)
        for part in parts
    )


# Opening and closing brackets. A sentence end inside them does not split the sentence.
OPEN = "「『（(【〔［"
CLOSE = "」』）)】〕］"


def split_sentences(text):
    """Split Japanese text at `。`, except inside brackets and backtick code."""
    text = str(text)
    out, start, depth, code = [], 0, 0, False
    for i, ch in enumerate(text):
        if ch == "`":
            code = not code
        elif code:
            continue
        elif ch in OPEN:
            depth += 1
        elif ch in CLOSE:
            depth = max(0, depth - 1)
        elif ch == "。" and depth == 0:
            rest = text[i + 1:].lstrip()
            if rest and rest[0] not in CLOSE:
                out.append(text[start:i + 1])
                start = i + 1
    out.append(text[start:])
    return [s.strip() for s in out if s.strip()]


def plain(text):
    """Text for an attribute value, with the code markup removed."""
    return esc(re.sub(r"`([^`]+)`", r"\1", str(text)))


# The figure number at the start of a caption: "Figure 3", "Fig. 3", or "Example 3", or the
# Japanese word for figure or example followed by the number (references/document-shape.md).
CAPTION_NO = re.compile(r"^((?:Figure|Fig\.|Example)\s*\d+|[\u56f3\u4f8b]\s*\d+)\s*(?=\S)")


def caption(text):
    """A caption with its figure number in its own element.

    doc.css keeps the number apart from the caption with a margin, not a space: despace.py
    removes the space between a number and Japanese text, which would run the two together.
    """
    m = CAPTION_NO.match(str(text))
    if not m:
        return inline(text)
    return '<span class="fig-no">%s</span>%s' % (esc(m.group(1)), inline(str(text)[m.end():]))


_UI = {}


def ui_words(lang):
    """The interface words of one language, read once from assets/ui.json."""
    if not _UI:
        with io.open(UI_PATH, encoding="utf-8") as f:
            _UI.update(json.load(f))
    if lang not in _UI:
        fail("assets/ui.json has no %s words" % lang)
    return _UI[lang]


def say(ui, key, **values):
    """One interface word with its `{name}` blanks filled in, the way `say` in assets/doc.js does."""
    return re.sub(r"\{(\w+)\}", lambda m: str(values.get(m.group(1), "")), ui[key])


class Ctx:
    """Per-document state: the language, the ids already used, and the section being written."""

    def __init__(self, lang="en"):
        self.lang = lang
        self.ui = ui_words(lang)
        self.names = set()
        self.section = None
        self.counts = {}

    def claim(self, name, where):
        if name in self.names:
            fail("duplicate %s id: %s" % (where, name))
        self.names.add(name)

    def enter(self, section_id):
        self.section = section_id
        self.counts = {}

    def local_id(self, kind):
        """A new id inside the current section, such as `a-s2-table1`."""
        self.counts[kind] = self.counts.get(kind, 0) + 1
        name = "%s-%s%d" % (self.section, kind, self.counts[kind])
        self.claim(name, kind)
        return name

    def prose(self, text):
        """Body text. Japanese text starts each sentence on a new line, so sentence ends
        are easy to follow; other languages keep the text as one run."""
        if self.lang != "ja":
            return inline(text)
        return "<br>".join(inline(s) for s in split_sentences(text))


def render_chart(block, ctx):
    """A chart drawn inside the document. The spec JSON is placed in the page and
    assets/charts.js draws it."""
    chart_id = check_id(block.get("id"), "chart")
    kind = block.get("kind")
    if kind not in CHARTS:
        fail("chart %s: kind must be one of %s" % (chart_id, " / ".join(CHARTS)))
    spec = block.get("spec")
    if not isinstance(spec, dict) or not spec:
        fail("chart %s has no spec (what to draw)" % chart_id)
    cap = block.get("caption")
    if not cap:
        fail("chart %s has no caption" % chart_id)
    spec_id = chart_id + "-spec"
    ctx.claim(chart_id, "chart")
    ctx.claim(spec_id, "chart")
    views = block.get("views", [])
    head = ""
    if views:
        if kind != "timeband" or not isinstance(views, list):
            fail("chart %s: only a timeband chart can have views" % chart_id)
        if len(views) > MAX_VIEWS:
            fail("chart %s has %d views; keep at most %d" % (chart_id, len(views), MAX_VIEWS))
        say_id = chart_id + "-say"
        ctx.claim(say_id, "chart")
        buttons = "".join(
            '<button type="button" data-lanes="%s" data-say="%s" aria-pressed="false">%s</button>'
            % (esc(",".join(v.get("lanes", []))), plain(v.get("say", "")), inline(v.get("label", "")))
            for v in views)
        head = ('\n  <div class="chart-views" data-chart="%s" data-text="%s">%s</div>'
                '\n  <p class="tabtext" id="%s"></p>' % (chart_id, say_id, buttons, say_id))
    data = json.dumps(spec, ensure_ascii=False).replace("</", "<\\/")
    # The chart sits in a frame of its own (`fig-scroll`), so a chart wider than the screen
    # scrolls sideways there while its buttons and caption stay in place. The frame is a region
    # named by the caption, so a keyboard reader can focus it and scroll it.
    return ('<figure class="chart" data-kind="%s">%s\n'
            '  <div class="fig-scroll" role="region" tabindex="0" aria-label="%s">'
            '<svg id="%s" data-chart="%s" data-spec="%s" role="img" aria-label="%s"></svg></div>\n'
            '  <script type="application/json" id="%s">%s</script>\n'
            '  <figcaption>%s</figcaption>\n</figure>'
            % (kind, head, plain(cap), chart_id, kind, spec_id, plain(cap), spec_id, data, caption(cap)))


def items_of(block, kind, least, most=None):
    """The items of a reading shape: an array of objects whose length is in range."""
    items = block.get("items")
    if (not isinstance(items, list) or len(items) < least or (most and len(items) > most)
            or not all(isinstance(x, dict) for x in items)):
        span = "exactly %d" % least if most == least else "%d or more" % least
        fail("%s.items must be an array of %s objects" % (kind, span))
    return items


def tone_of(value, kind, default):
    if value is None:
        return default
    if value not in TONES:
        fail("%s: tone must be one of %s" % (kind, " / ".join(TONES)))
    return value


def render_keys(block, ctx):
    """Key facts: the numbers or terms to remember, each with a short explanation."""
    items = items_of(block, "keys", 2)
    for x in items:
        if not x.get("term") or not x.get("text"):
            fail("keys.items need term and text")
    return '<div class="keys">\n%s\n</div>' % "\n".join(
        "  <div><b>%s</b><span>%s</span></div>" % (inline(x["term"]), ctx.prose(x["text"])) for x in items)


def render_cards(block, ctx):
    """Cards side by side, one per item the reader reads on its own.

    The cards of a block hold the same fields in the same order. A `tone` marks the state of an
    item (good, warn), never a kind of item; a card without one is not colored.
    """
    items = items_of(block, "cards", 2)
    out = []
    for x in items:
        if not x.get("title") or not (x.get("text") or x.get("list")):
            fail("cards.items need title and either text or list")
        if x.get("list") is not None and (not isinstance(x["list"], list) or not x["list"]):
            fail("cards.items.list must be a non-empty array")
        parts = ['<span class="chip">%s</span>' % inline(x["label"])] if x.get("label") else []
        parts.append("<h4>%s</h4>" % inline(x["title"]))
        if x.get("text"):
            parts.append("<p>%s</p>" % ctx.prose(x["text"]))
        if x.get("list"):
            parts.append("<ul>%s</ul>" % "".join("<li>%s</li>" % ctx.prose(i) for i in x["list"]))
        tone = tone_of(x.get("tone"), "cards", None)
        out.append('  <li class="card"%s>%s</li>'
                   % (' data-tone="%s"' % tone if tone else "", "".join(parts)))
    return '<ul class="cards">\n%s\n</ul>' % "\n".join(out)


def render_note(block, ctx):
    """A note beside the main text.

    `tone` `warn` makes a warning: a framed box with an icon and a title that names the risk.
    Any other tone makes an explanation: a titled paragraph in gray text, with no box.
    """
    if not block.get("text"):
        fail("note has no text")
    title = "<b>%s</b>" % inline(block["title"]) if block.get("title") else ""
    text = "<p>%s</p>" % ctx.prose(block["text"])
    if tone_of(block.get("tone"), "note", "info") != "warn":
        return '<div class="note">%s%s</div>' % (title, text)
    if not title:
        fail("warning note %r... has no title (name the risk in a few words)" % str(block["text"])[:40])
    return '<div class="note warn" role="note">%s%s%s</div>' % (WARN_ICON, title, text)


def render_table(block, ctx):
    """A table named by its caption, with a header cell for each column and for each row.

    `num` lists the columns that hold numbers, counted from 0; their cells are aligned right.
    The table sits in a box (`.tbl`) that the reader can focus and scroll when the table is
    longer or wider than the box, and the caption names that box.
    """
    columns, rows = block.get("columns"), block.get("rows")
    if not isinstance(columns, list) or not columns or not isinstance(rows, list):
        fail("table needs columns and rows arrays")
    where = " / ".join(str(c) for c in columns[:3])
    cap = block.get("caption")
    if not isinstance(cap, str) or not cap.strip():
        fail("table (%s) has no caption (name the table in a few words)" % where)
    width = len(columns)
    num = block.get("num", [])
    if not isinstance(num, list) or not all(isinstance(j, int) and not isinstance(j, bool)
                                            and 0 <= j < width for j in num):
        fail("table (%s): num must list column numbers from 0 to %d" % (where, width - 1))

    def cell(tag, scope, j, text):
        attrs = (' scope="%s"' % scope if scope else "") + (' class="num"' if j in num else "")
        return "<%s%s>%s</%s>" % (tag, attrs, inline(text), tag)

    head = "".join(cell("th", "col", j, x) for j, x in enumerate(columns))
    body = []
    for row in rows:
        if not isinstance(row, list) or len(row) != width:
            fail("a table row does not have as many cells as columns")
        body.append("<tr>%s</tr>" % "".join(cell("th", "row", j, x) if j == 0 else cell("td", None, j, x)
                                            for j, x in enumerate(row)))
    cap_id = ctx.local_id("table")
    return ('<div class="tbl" role="region" tabindex="0" aria-labelledby="%s"><table>\n'
            '<caption id="%s">%s</caption>\n<thead><tr>%s</tr></thead>\n<tbody>\n%s\n</tbody>\n</table></div>'
            % (cap_id, cap_id, inline(cap), head, "\n".join(body)))


def render_compare(block, ctx):
    """Two values side by side (before and after); the second one is emphasized."""
    items = items_of(block, "compare", 2, 2)
    sides = []
    for i, x in enumerate(items):
        if not x.get("label") or not x.get("value"):
            fail("compare.items need label and value")
        say = '<p class="say">%s</p>' % ctx.prose(x["text"]) if x.get("text") else ""
        sides.append('<div class="side%s"><div class="cap">%s</div><div class="big">%s</div>%s</div>'
                     % (" after" if i else "", inline(x["label"]), inline(x["value"]), say))
    return ('<div class="compare">%s<div class="arrow" aria-hidden="true">→</div>%s</div>'
            % (sides[0], sides[1]))


def render_free(block, ctx):
    """A shape the fixed blocks do not cover. The writer supplies HTML and CSS; the CSS
    applies only inside this block.

    A block with `caption` becomes a figure (`<figure>` with a caption) and counts as the
    section's figure. A block without one is plain body markup and does not count.
    """
    free_id = check_id(block.get("id"), "html")
    ctx.claim(free_id, "html")
    body = block.get("html")
    if not isinstance(body, str) or not body.strip():
        fail("html block %s has no html" % free_id)
    if FREE_BANNED.search(body):
        fail("html block %s contains something not allowed (script / style / link / iframe / "
             "object / embed / meta / base / frame / on* attributes / javascript:)" % free_id)
    css = block.get("css", "")
    if not isinstance(css, str) or CSS_BANNED.search(css):
        fail("html block %s: css contains something not allowed (@import / tags)" % free_id)
    # CSS nesting keeps the writer's rules under this block's id.
    style = "<style>#%s { %s }</style>\n" % (free_id, css) if css.strip() else ""
    cap = block.get("caption")
    if cap:
        return ('%s<figure class="free" id="%s">\n%s\n  <figcaption>%s</figcaption>\n</figure>'
                % (style, free_id, body, caption(cap)))
    return '%s<div class="free" id="%s">\n%s\n</div>' % (style, free_id, body)


def render_block(block, ctx):
    if not isinstance(block, dict) or not isinstance(block.get("type"), str):
        fail("each block must be an object with a type")
    kind = block["type"]
    if kind == "paragraph":
        return "<p>%s</p>" % ctx.prose(block.get("text", ""))
    if kind == "heading":
        # A sub-heading inside a section; one section explains a whole topic in prose.
        if not block.get("text"):
            fail("heading has no text")
        return "<h3>%s</h3>" % inline(block["text"])
    if kind == "list":
        items = block.get("items")
        if not isinstance(items, list) or not items:
            fail("list.items must be a non-empty array")
        return "<ul>\n%s\n</ul>" % "\n".join("  <li>%s</li>" % ctx.prose(x) for x in items)
    if kind == "chart":
        return render_chart(block, ctx)
    if kind == "table":
        return render_table(block, ctx)
    if kind == "code":
        language = block.get("language")
        cls = ' class="language-%s"' % esc(language) if language else ""
        return "<pre><code%s>%s</code></pre>" % (cls, esc(block.get("text", "")))
    if kind == "keys":
        return render_keys(block, ctx)
    if kind == "cards":
        return render_cards(block, ctx)
    if kind == "note":
        return render_note(block, ctx)
    if kind == "compare":
        return render_compare(block, ctx)
    if kind == "html":
        return render_free(block, ctx)
    if kind == "details":
        return render_details(block, ctx)
    fail("unknown block type: %s" % kind)


def render_details(block, ctx):
    """A collapsed block of long raw data. It holds no other collapsed block."""
    summary = block.get("summary")
    if not summary:
        fail("details has no summary")
    blocks = block.get("blocks", [])
    if any(isinstance(b, dict) and b.get("type") == "details" for b in blocks):
        fail("details %r holds another details block; put the second one beside it" % summary)
    return ('<details class="exp">\n  <summary><span class="lbl">%s</span></summary>\n'
            '  <div class="exp-body">\n%s\n  </div>\n</details>'
            % (inline(summary), "\n".join("    " + line for b in blocks
                                              for line in render_block(b, ctx).splitlines())))


def render_blocks(blocks, ctx):
    """The blocks of a section. A run of DETAILS_RUN or more `details` blocks in a row starts with
    buttons that open or close all of them (assets/doc.js runs them)."""
    out, run = [], []

    def end_run():
        if len(run) >= DETAILS_RUN:
            out.append('<div class="details-all">'
                       '<button type="button" data-ui="openAll" data-details="open">%s</button>'
                       '<button type="button" data-ui="closeAll" data-details="close">%s</button></div>'
                       % (esc(say(ctx.ui, "openAll")), esc(say(ctx.ui, "closeAll"))))
        out.extend(run)
        del run[:]

    for b in blocks:
        part = render_block(b, ctx)
        if b.get("type") == "details":
            run.append(part)
        else:
            end_run()
            out.append(part)
    end_run()
    return "\n".join(out)


def render_section(section, number, head, ctx):
    section_id = check_id(section.get("id"), "section")
    title = section.get("title")
    if not title:
        fail("section %s has no title" % section_id)
    blocks = section.get("blocks", [])
    if not isinstance(blocks, list):
        fail("section %s: blocks must be an array" % section_id)
    # A section without a figure states why. check.py fails a section with neither.
    nofigure = section.get("nofigure")
    if nofigure is not None and (not isinstance(nofigure, str) or not nofigure.strip()):
        fail("section %s: nofigure must be a sentence giving the reason" % section_id)
    nofig = ' data-nofig="%s"' % plain(nofigure) if nofigure else ""
    ctx.enter(section_id)
    body = render_blocks(blocks, ctx)
    return ('<section class="doc-sec" id="%s" data-name="%s"%s>\n%s'
            '  <h2><span class="num">%02d</span>%s</h2>\n%s\n</section>'
            % (section_id, plain(title), nofig, head, number, inline(title), body))


def page_head(title, lead, ctx, facts=""):
    lead_html = '\n    <p class="lead">%s</p>' % ctx.prose(lead) if lead else ""
    facts_html = "\n    " + facts if facts else ""
    return ('  <div class="doc-pagehead">\n    <h1>%s</h1>%s%s\n  </div>\n'
            % (inline(title), lead_html, facts_html))


def render_facts(doc, ui, lang, today=None):
    """The facts table under the first title, one row per fact in the order of FACTS.

    The time always has a row: `facts.asOf`, else the `date` field, else the build date.
    """
    facts = doc.get("facts", {})
    names = [name for name, _key in FACTS]
    if not isinstance(facts, dict) or any(k not in names or not isinstance(v, str) or not v.strip()
                                          for k, v in facts.items()):
        fail("facts must be an object whose fields are %s, each a non-empty string" % ", ".join(names))
    date = doc.get("date")
    if date is not None and (not isinstance(date, str) or not date.strip()):
        fail("date must be a non-empty string")
    values = dict(facts, asOf=facts.get("asOf") or date or today_label(lang, today))
    rows = "".join('\n        <tr><th scope="row" data-ui="%s">%s</th><td>%s</td></tr>'
                   % (key, esc(say(ui, key)), inline(values[name])) for name, key in FACTS if name in values)
    return ('<table class="facts" data-ui-label="facts" aria-label="%s">\n      <tbody>%s\n      </tbody>\n    </table>'
            % (esc(say(ui, "facts")), rows))


def today_label(lang="en", today=None):
    d = today or datetime.date.today()
    ui = ui_words(lang)
    return say(ui, "date", year=d.year, month=ui["months"][d.month - 1], day=d.day)


def switches(ui):
    """The language switch and the light or dark switch, side by side (assets/doc.js runs them).

    The language buttons name each language in itself, so they read the same in both languages.
    """
    theme = "".join(
        '<button type="button" data-theme-choice="%s" data-ui-label="%s" data-ui-title="%s" '
        'aria-label="%s" title="%s" aria-pressed="false">%s</button>'
        % (mode, mode, mode, esc(say(ui, mode)), esc(say(ui, mode)), icon)
        for mode, icon in (("light", SUN_ICON), ("dark", MOON_ICON)))
    return ('<div class="doc-ctrl">\n'
            '    <div class="doc-seg" role="group" data-ui-label="language" aria-label="%s">'
            '<button type="button" data-lang="en" lang="en" aria-pressed="false">English</button>'
            '<button type="button" data-lang="ja" lang="ja" aria-pressed="false">日本語</button></div>\n'
            '    <div class="doc-seg" role="group" data-ui-label="theme" aria-label="%s">%s</div>\n'
            '  </div>' % (esc(say(ui, "language")), esc(say(ui, "theme")), theme))


def lang_of(doc):
    lang = doc.get("lang", LANGS[0])
    if lang not in LANGS:
        fail("lang must be one of %s (got %r)" % (" / ".join(LANGS), lang))
    return lang


def render(doc, template, today=None):
    """Return (html, stats) where stats counts pages, sections, and figures."""
    if not isinstance(doc, dict):
        fail("the top level of the content JSON must be an object")
    lang = lang_of(doc)
    title = doc.get("title")
    lead = doc.get("lead")
    tabs = doc.get("tabs")
    if not title or not lead or not isinstance(tabs, list) or not tabs:
        fail("title, lead, and tabs are required")
    keys = [check_id(tab.get("id"), "tab") for tab in tabs]
    if len(keys) != len(set(keys)):
        fail("duplicate tab id")
    many = len(tabs) > 1
    ctx = Ctx(lang)
    ui = ctx.ui
    facts = render_facts(doc, ui, lang, today)
    ctx.claim("doc-side", "document")
    if many:
        for key in keys:
            ctx.claim("doc-tab-" + key, "page tab")
            ctx.claim("doc-page-" + key, "page")

    tocs, pages, nsec = [], [], 0
    for i, (key, tab) in enumerate(zip(keys, tabs)):
        label = tab.get("label")
        if not label:
            fail("tab %s has no label" % key)
        sections = tab.get("sections", [])
        if not isinstance(sections, list) or not sections:
            fail("tab %s: sections must be a non-empty array" % key)
        for section in sections:
            ctx.claim(check_id(section.get("id"), "section"), "section")
        nsec += len(sections)
        # The facts sit under the first title of the document.
        heading = page_head(tab.get("title") or label, tab.get("lead") or (lead if i == 0 else ""), ctx,
                            facts if i == 0 else "") if many else page_head(title, lead, ctx, facts)
        body = "\n\n".join(render_section(s, n, heading if n == 1 else "", ctx)
                           for n, s in enumerate(sections, 1))
        toc_head = '\n    <p class="doc-toc-head">%s</p>' % inline(label) if many else ""
        toc_name = re.sub(r"`([^`]+)`", r"\1", str(label))
        tocs.append('  <nav class="doc-toc" data-page="%s" data-ui-label="pageContents" '
                    'data-ui-name="%s" aria-label="%s"%s>%s\n%s\n  </nav>'
                    % (key, esc(toc_name), esc(say(ui, "pageContents", name=toc_name)),
                       " hidden" if i else "", toc_head,
                       "\n".join('    <button type="button" data-sec="%s">%s</button>'
                                 % (s["id"], inline(s["title"])) for s in sections)))
        # With several pages, each page is the panel of its tab.
        panel = (' id="doc-page-%s" role="tabpanel" aria-labelledby="doc-tab-%s"' % (key, key)) if many else ""
        if i == 0:
            pages.append('<div class="doc-page" data-page="%s"%s>\n\n%s\n\n</div>' % (key, panel, body))
        else:
            # Pages not shown first go into a template and are built when opened.
            pages.append('<div class="doc-page" data-page="%s"%s hidden>\n<template data-fill="%s">\n\n'
                         '%s\n\n</template>\n</div>' % (key, panel, key, body))

    # The header band: the title, the page tabs when there are several pages, and on its right the
    # switches and the help button. print.js puts the PDF button before the help button, and on
    # narrow screens assets/doc.js moves the switches into the top bar.
    tablist = ""
    if many:
        tablist = ('\n  <nav class="doc-pages" role="tablist" data-ui-label="pages" aria-label="%s">\n%s\n  </nav>'
                   % (esc(say(ui, "pages")), "\n".join(
                       '    <button type="button" role="tab" id="doc-tab-%s" data-page="%s" aria-controls="doc-page-%s" '
                       'aria-selected="%s" tabindex="%s">%s</button>'
                       % (key, key, key, "true" if i == 0 else "false", "0" if i == 0 else "-1", inline(tab["label"]))
                       for i, (key, tab) in enumerate(zip(keys, tabs)))))
    parts = ['<header class="doc-top">\n  <span class="doc-brand">%s</span>%s\n  <div class="doc-tools">\n    %s\n'
             '    <button type="button" class="doc-help" data-ui-label="help" aria-label="%s" aria-haspopup="dialog">?</button>\n'
             '  </div>\n</header>' % (inline(title), tablist, switches(ui).replace("\n", "\n  "), esc(say(ui, "help")))]
    parts.append('<aside class="doc-side" id="doc-side" data-ui-label="contents" aria-label="%s">\n%s\n</aside>'
                 % (esc(say(ui, "contents")), "\n".join(tocs)))
    parts.append('<div class="doc-mbar"><button type="button" data-ui="contents" data-ui-icon="%s" aria-controls="doc-side" '
                 'aria-expanded="false">%s %s</button><span class="doc-here"></span>'
                 '<span class="doc-count"></span></div>'
                 % (CONTENTS_ICON, CONTENTS_ICON, esc(say(ui, "contents"))))
    parts.append('<main class="doc-main">\n%s\n<div class="doc-step"><button type="button" '
                 'data-ui="prev" data-step="-1">%s</button><span class="doc-count"></span>'
                 '<button type="button" data-ui="next" data-step="1">%s</button></div>\n</main>'
                 % ("\n".join(pages), esc(say(ui, "prev")), esc(say(ui, "next"))))
    parts.append('<div class="doc-scrim"></div>')

    start = template.find(START)
    end = template.find(END)
    if start < 0 or end < start:
        fail("the template has no %s and %s markers" % (START, END))
    out = template[:start + len(START)] + "\n" + "\n".join(parts) + "\n" + template[end:]
    out = re.sub(r"<title>.*?</title>",
                 lambda _m: '<title>%s</title>\n<meta name="description" content="%s">'
                 % (plain(title), plain(lead)), out, count=1, flags=re.S)
    if not HTML_OPEN.search(out):
        fail("the template has no <html> tag")
    out = HTML_OPEN.sub('<html lang="%s">' % lang, out, count=1)
    stats = {"pages": len(tabs), "sections": nsec,
             "figures": "\n".join(pages).count("<figure")}
    return out, stats


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--in", dest="src", required=True, help="content JSON")
    ap.add_argument("--template", default=TEMPLATE,
                    help="template HTML (default: templates/starter-doc.html)")
    ap.add_argument("--out", required=True, help="body HTML to write")
    args = ap.parse_args(argv)
    try:
        with io.open(args.src, encoding="utf-8") as f:
            doc = json.load(f)
        with io.open(args.template, encoding="utf-8") as f:
            template = f.read()
        output, stats = render(doc, template)
        with io.open(args.out, "w", encoding="utf-8") as f:
            f.write(output)
        print("wrote %s (%d pages, %d sections, %d figures)"
              % (args.out, stats["pages"], stats["sections"], stats["figures"]))
        return 0
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        sys.stderr.write("NG %s\n" % exc)
        return 1


if __name__ == "__main__":
    sys.exit(main())
