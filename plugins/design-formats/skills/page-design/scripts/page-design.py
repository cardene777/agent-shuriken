#!/usr/bin/env python3
"""Check HTML pages and Markdown documents against the look rules of page-design.

Usage:
  page-design.py verify [--source] <file>...
  page-design.py theme [--defaults] <page.html>

Each file ending in .html or .htm is read as a page, and each file ending in .md as a document.
Every problem is printed as one line, <file>:<line>: <rule>: <how to fix>. The text of the page is
never printed, only rule names, line numbers, and fixes.

A page holds its figures as dragon blocks (<pre class="dragon" data-still>) while it is written, and
`dragon embed` draws each one as an SVG. A page that still holds a block is refused. With --source,
the file is checked as the source of a page, such as a template: it may hold still dragon blocks and
the dragon entry line, and a block without data-still is refused. The text inside a block and inside
a drawn figure is the figure's own, so the text rules do not read it.

theme writes the user's theme into a page made from a template. The theme is .design-theme.json at
the root of the git repository the command runs in, or else ~/.design-theme.json. Its keys and their
types are in formats/theme.md. The values replace the tokens in the light :root block and in both
dark blocks; keys the theme leaves out keep the page's values. Without a theme file the page is left
as it is. A theme file with an unknown key or a bad value is refused, each key named, and the page is
left as it is. With --defaults, theme prints the keys a page defines and their values as JSON.

Exit codes:
  0  every file keeps the rules; or theme applied the theme, found no theme file, or printed the defaults
  1  a file breaks a rule; each problem is named above the summary line
  2  called wrongly: no file, a missing file, or a file that is neither HTML nor Markdown; or a theme
     file that cannot be read or holds an unknown key or a bad value

Uses only the Python standard library, reads only the files it is given and the theme file, writes
only the page theme is given, runs no other program, connects to nothing, and keeps nothing.
"""

import json
import os
import re
import sys
from html.parser import HTMLParser

FIXES = {
    "heading-punctuation": "take the colon and any Japanese comma or period out of the heading; keep the name as the title and put the detail on the line under it",
    "facts-in-one-line": "put these facts in a table or a grid of label and value cells instead of one sentence",
    "label-colon": "write a sentence, a table row, or a heading with its text under it instead of joining a label and a value with a colon or =",
    "small-text": "use 12px (0.75rem) or larger",
    "missing-lang": 'give <html> a lang attribute, "en" by default',
    "missing-language-switch": 'put English and Japanese buttons with data-lang="en" and data-lang="ja" in the header',
    "missing-theme-switch": 'put light and dark buttons with data-theme-choice="light" and data-theme-choice="dark" in the header',
    "missing-dictionary": "keep every UI string in one dictionary object with an en and a ja entry",
    "missing-dark-colors": 'redefine the color tokens under @media (prefers-color-scheme: dark) and :root[data-theme="dark"]',
    "missing-reduced-motion": "add @media (prefers-reduced-motion: reduce) that turns the transitions and animations off",
    "external-file": "inline it or embed it as a data: URI; the page reads no other file",
    "figure-not-embedded": "run dragon embed on the page (npx -y @cardenelabs/dragon@<version> embed <page> --out <page>), which draws each still block as an SVG",
    "figure-not-still": "add data-still to the dragon block, so the page shows the last step as one picture",
    "facts-not-table": 'put the facts in <table class="facts">, one row per fact, with the label in <th scope="row"> and the value in <td>',
    "sentence-per-line": "end the line after each Japanese full stop, and start the next sentence on its own line in a document or after <br> in a page",
    "list-detail-width": "give the list column of .split a fixed width, such as minmax(320px, 380px), and the details the rest, minmax(0, 1fr)",
}

HEADING_MARKS = re.compile("[:\uff1a\u3001\u3002]")
SEPARATORS = re.compile(r"\u3001|,\s|\s\u00b7\s|\s\|\s|\s/\s")
LABEL_COLON = re.compile(r"^(\*\*[^*]{1,40}\*\*|[^\s:\uff1a|`][^:\uff1a|`]{0,39}?)(:(\s|$)|\uff1a)")
LABEL_EQUALS = re.compile(r"\S\s=\s\S")
INLINE_CODE = re.compile(r"`[^`]*`")
EXTERNAL = re.compile(r"^\s*(https?:)?//", re.I)
# The line that loads dragon from jsDelivr, which a source page carries until dragon embed replaces it.
DRAGON_ENTRY = re.compile(r"^https://cdn\.jsdelivr\.net/npm/@cardenelabs/dragon@[0-9.]+/dist/cdn/dragon\.js$")
SMALL_FONT = re.compile(r"font(-size)?\s*:\s*([^;}\"']+)", re.I)
SIZE = re.compile(r"(\d+(?:\.\d+)?)(px|rem|em)\b", re.I)
SCRIPT_HEADING = re.compile(r"""\b(\w*(?:title|heading|Title|Heading)\w*)\s*:\s*(["'])((?:(?!\2).){1,200})\2""")
# A heading kept per language, such as title: { en: "...", ja: "..." } in DATA.
SCRIPT_HEADING_SET = re.compile(r"""\b\w*(?:title|heading|Title|Heading)\w*\s*:\s*\{([^{}]{1,600})\}""")
QUOTED = re.compile(r"""(["'])((?:(?!\1).){1,200})\1""")
# A string in a script, of any length from 12 characters, with its escapes, on one line of the source.
SCRIPT_STRING = re.compile(r"""(["'`])((?:\\.|(?!\1)[^\\\n]){12,})\1""")
STRING_ESCAPE = re.compile(r"\\(u\{[0-9A-Fa-f]{1,6}\}|u[0-9A-Fa-f]{4}|x[0-9A-Fa-f]{2}|.)")
ESCAPED_CHARS = {"n": "\n", "r": "\r", "t": "\t"}


def unescape(text):
    """The text of a script string with its escapes read, as `\\n`, `\\"`, and `\\u3001`."""
    def one(match):
        code = match.group(1) or ""
        if code[0] in "ux" and len(code) > 1:
            return chr(int(code[1:].strip("{}"), 16))
        return ESCAPED_CHARS.get(code, code)
    return STRING_ESCAPE.sub(one, text)
CODE_MARKS = re.compile(r"[<>{}()=;$\[\]]")
# A Japanese full stop with more text after it on the same line. A full stop right before a closing
# bracket or quote ends a quoted sentence inside a longer one, so it does not end the line.
CLOSERS = "\u300d\u300f\uff09)\u3011\u3009\u300b\uff63\"'\u201d\u2019"
JOINED_SENTENCES = re.compile("\u3002(?![" + re.escape(CLOSERS) + "])\\s*\\S")
CSS_RULE = re.compile(r"([^{}]+)\{([^{}]*)\}")
SPLIT_SELECTOR = re.compile(r"\.split(?![\w-])")
GRID_COLUMNS = re.compile(r"grid-template-columns\s*:\s*([^;}]+)", re.I)
FIXED_LENGTH = re.compile(r"\d+(?:\.\d+)?(?:px|rem|em)", re.I)
# A facts container that a script builds as markup in a string.
SCRIPT_FACTS = re.compile(r"""<([a-z][a-z0-9]*)\b[^<>]*\b(?:class=["'](?:[^"']*\s)?facts(?:\s[^"']*)?["']|id=["']facts["'])""", re.I)


def facts_in_one_line(text):
    """True when the text joins three or more facts that each hold a number."""
    parts = [p for p in SEPARATORS.split(text) if p.strip()]
    if len(parts) < 3:
        return False
    return sum(1 for p in parts if re.search(r"\d", p)) >= 3


def top_level(value, separator):
    """Split a CSS value at the separators that sit outside parentheses."""
    parts, depth, current = [], 0, ""
    for char in value:
        depth += (char == "(") - (char == ")")
        if depth == 0 and (char.isspace() if separator == " " else char == separator):
            if current.strip():
                parts.append(current.strip())
            current = ""
        else:
            current += char
    if current.strip():
        parts.append(current.strip())
    return parts


def list_column_grows(columns):
    """True when the first of two or more grid columns has no fixed or capped width."""
    tracks = top_level(columns, " ")
    if len(tracks) < 2:
        return False
    first = tracks[0].lower()
    if first.startswith("minmax(") and first.endswith(")"):
        limits = top_level(first[7:-1], ",")
        return len(limits) != 2 or not FIXED_LENGTH.fullmatch(limits[1])
    return not FIXED_LENGTH.fullmatch(first)


def label_joined(text):
    text = INLINE_CODE.sub("", text.strip())
    if not text or "://" in text.split(" ", 1)[0]:
        return False
    return bool(LABEL_COLON.match(text)) or bool(LABEL_EQUALS.search(text))


def small_sizes(css):
    """Yield the offset of each font size under 12px in a block of CSS."""
    for match in SMALL_FONT.finditer(css):
        value = match.group(2)
        size = SIZE.search(value.split("/")[0])
        if not size:
            continue
        number, unit = float(size.group(1)), size.group(2).lower()
        px = number if unit == "px" else number * 16
        if px < 12:
            yield match.start()


def line_at(text, offset, first_line):
    return first_line + text.count("\n", 0, offset)


class Page(HTMLParser):
    SKIP = {"script", "style", "code", "pre", "textarea", "template", "svg", "math"}
    HEADINGS = {"h1", "h2", "h3", "h4", "h5", "h6", "title"}

    def __init__(self, source=False):
        super().__init__(convert_charrefs=True)
        self.source = source
        self.problems = []
        self.skip = []
        self.heading = None
        self.has_html = False
        self.lang_ok = True
        self.langs = set()
        self.themes = set()
        self.styles = []
        self.figure_styles = []
        self.scripts = []
        self.current = None
        self.facts = 0
        self.first_cell = False

    def problem(self, line, rule):
        self.problems.append((line, rule))

    def handle_starttag(self, tag, attrs):
        line = self.getpos()[0]
        values = {name: value or "" for name, value in attrs}
        if tag == "html":
            self.has_html = True
            self.lang_ok = bool(values.get("lang", "").strip())
        if values.get("data-lang"):
            self.langs.add(values["data-lang"].strip())
        if values.get("data-theme-choice"):
            self.themes.add(values["data-theme-choice"].strip())
        in_figure = "svg" in self.skip or tag == "svg"
        if tag == "pre" and "dragon" in values.get("class", "").split():
            if not self.source:
                self.problem(line, "figure-not-embedded")
            elif "data-still" not in values:
                self.problem(line, "figure-not-still")
        if values.get("style") and not in_figure:
            for _ in small_sizes(values["style"]):
                self.problem(line, "small-text")
            if re.search(r"url\(\s*['\"]?(https?:)?//", values["style"], re.I):
                self.problem(line, "external-file")
        source = None
        if tag in ("script", "img", "iframe", "embed", "source", "audio", "video", "track"):
            source = values.get("src")
        elif tag == "link":
            source = values.get("href")
        elif tag == "object":
            source = values.get("data")
        if source and EXTERNAL.match(source) and not (self.source and tag == "script" and DRAGON_ENTRY.match(source.strip())):
            self.problem(line, "external-file")
        if tag in ("iframe", "object", "embed") and not source:
            self.problem(line, "external-file")
        if not self.skip and not in_figure:
            self.check_facts(tag, values, line)
        if tag in ("style", "script"):
            # A figure's own style sizes its text to the figure, so only the page's style is measured.
            self.current = (tag, line, [], in_figure)
        if tag in self.SKIP:
            self.skip.append(tag)
        elif tag in self.HEADINGS and not self.skip:
            self.heading = (line, [])

    def check_facts(self, tag, values, line):
        """The facts of a page are a table whose rows each start with a row header."""
        if self.facts:
            if tag == "table":
                self.facts += 1
            elif tag == "tr":
                self.first_cell = True
            elif tag in ("th", "td") and self.first_cell:
                self.first_cell = False
                if tag == "td" or values.get("scope", "").strip().lower() != "row":
                    self.problem(line, "facts-not-table")
            return
        if "facts" in values.get("class", "").split() or values.get("id", "").strip() == "facts":
            if tag == "table":
                self.facts = 1
            else:
                self.problem(line, "facts-not-table")

    def handle_endtag(self, tag):
        if self.facts and tag == "table":
            self.facts -= 1
        if self.current and tag == self.current[0]:
            kind, line, parts, in_figure = self.current
            if kind == "style" and in_figure:
                self.figure_styles.append((line, "".join(parts)))
            else:
                (self.styles if kind == "style" else self.scripts).append((line, "".join(parts)))
            self.current = None
        if self.skip and tag == self.skip[-1]:
            self.skip.pop()
            return
        if self.heading and tag in self.HEADINGS:
            line, parts = self.heading
            if HEADING_MARKS.search(" ".join("".join(parts).split())):
                self.problem(line, "heading-punctuation")
            self.heading = None

    def handle_data(self, data):
        if self.current:
            self.current[2].append(data)
        if self.skip:
            return
        if self.heading:
            self.heading[1].append(data)
            return
        text = " ".join(data.split())
        if not text:
            return
        line = self.getpos()[0] + data[: len(data) - len(data.lstrip())].count("\n")
        joined = JOINED_SENTENCES.search(data)
        if joined:
            self.problem(self.getpos()[0] + data[: joined.start()].count("\n"), "sentence-per-line")
        if facts_in_one_line(text):
            self.problem(line, "facts-in-one-line")
        elif label_joined(text):
            self.problem(line, "label-colon")

    def finish(self):
        css = "\n".join(text for _, text in self.styles)
        for line, text in self.styles:
            for offset in small_sizes(text):
                self.problem(line_at(text, offset, line), "small-text")
        for line, text in self.styles + self.figure_styles:
            for match in re.finditer(r"@import|url\(\s*['\"]?(https?:)?//", text, re.I):
                self.problem(line_at(text, match.start(), line), "external-file")
        for line, text in self.styles:
            for rule in CSS_RULE.finditer(text):
                if not SPLIT_SELECTOR.search(rule.group(1)):
                    continue
                for columns in GRID_COLUMNS.finditer(rule.group(2)):
                    if list_column_grows(columns.group(1)):
                        self.problem(line_at(text, rule.start(2) + columns.start(), line), "list-detail-width")
        for line, text in self.scripts:
            for match in SCRIPT_HEADING.finditer(text):
                if HEADING_MARKS.search(match.group(3)):
                    self.problem(line_at(text, match.start(), line), "heading-punctuation")
            for match in SCRIPT_HEADING_SET.finditer(text):
                for value in QUOTED.finditer(match.group(1)):
                    if HEADING_MARKS.search(value.group(2)):
                        self.problem(line_at(text, match.start(1) + value.start(), line), "heading-punctuation")
            for match in SCRIPT_FACTS.finditer(text):
                if match.group(1).lower() != "table":
                    self.problem(line_at(text, match.start(), line), "facts-not-table")
            for match in SCRIPT_STRING.finditer(text):
                # Only strings that read as prose; markup and code built in strings are skipped.
                words = unescape(match.group(2))
                if CODE_MARKS.search(words):
                    continue
                if facts_in_one_line(words):
                    self.problem(line_at(text, match.start(), line), "facts-in-one-line")
        scripts = "\n".join(text for _, text in self.scripts)
        if self.has_html and not self.lang_ok:
            self.problem(1, "missing-lang")
        if not {"en", "ja"} <= self.langs:
            self.problem(1, "missing-language-switch")
        if not {"light", "dark"} <= self.themes:
            self.problem(1, "missing-theme-switch")
        if not (re.search(r"""(^|[\s{,])["']?en["']?\s*:\s*\{""", scripts) and re.search(r"""(^|[\s{,])["']?ja["']?\s*:\s*\{""", scripts)):
            self.problem(1, "missing-dictionary")
        if not re.search(r"prefers-color-scheme\s*:\s*dark", css, re.I):
            self.problem(1, "missing-dark-colors")
        if re.search(r"\b(transition|animation)\s*:", css, re.I) and not re.search(r"prefers-reduced-motion", css, re.I):
            self.problem(1, "missing-reduced-motion")


def check_html(text, source=False):
    page = Page(source)
    page.feed(text)
    page.close()
    page.finish()
    return page.problems


def check_markdown(text):
    problems = []
    fence = None
    comment = False
    lines = text.split("\n")
    start = 0
    if lines and lines[0].strip() == "---":
        for i in range(1, len(lines)):
            if lines[i].strip() == "---":
                start = i + 1
                break
    for number, raw in enumerate(lines, 1):
        if number <= start:
            continue
        line = raw.strip()
        mark = re.match(r"^(`{3,}|~{3,})", line)
        if fence:
            if mark and line.startswith(fence):
                fence = None
            continue
        if mark:
            fence = mark.group(1)
            continue
        if comment:
            comment = "-->" not in line
            continue
        if line.startswith("<!--"):
            comment = "-->" not in line
            continue
        if not line or line.startswith("|") or line.startswith(">"):
            continue
        heading = re.match(r"^#{1,6}\s+(.*)$", line)
        if heading:
            if HEADING_MARKS.search(INLINE_CODE.sub("", heading.group(1))):
                problems.append((number, "heading-punctuation"))
            continue
        body = re.sub(r"^([-*+]|\d+\.)\s+(\[[ xX]\]\s+)?", "", line)
        if JOINED_SENTENCES.search(INLINE_CODE.sub("", body)):
            problems.append((number, "sentence-per-line"))
        if facts_in_one_line(INLINE_CODE.sub("", body)):
            problems.append((number, "facts-in-one-line"))
        elif label_joined(body):
            problems.append((number, "label-colon"))
    return problems


# The theme file. A user's look lives in .design-theme.json at the root of the repository the
# command runs in, or else in ~/.design-theme.json, as JSON keyed like the template tokens.
THEME_NAME = ".design-theme.json"
COLOR_KEYS = ("bg", "surface", "ink", "sub", "line", "accent", "accent-ink", "accent-soft", "bar", "label")
# key: (CSS token, kind). A px value is written as a number of pixels.
FONT_KEYS = {"sans": ("sans", "font"), "mono": ("mono", "font"), "size": ("text-size", "px"),
             "line-height": ("line-height", "number")}
SPACE_KEYS = {"page-width": ("page-width", "px"), "radius-small": ("radius-small", "px"),
              "radius": ("radius", "px"), "radius-large": ("radius-large", "px")}
LIGHT_BLOCK = re.compile(r"(:root\s*\{)([^}]*)(\})")
DARK_BLOCKS = (re.compile(r'(:root:not\(\[data-theme="light"\]\)\s*\{)([^}]*)(\})'),
               re.compile(r'(:root\[data-theme="dark"\]\s*\{)([^}]*)(\})'))
TOKEN = r"(--%s\s*:\s*)([^;}]+)(;?)"
COLOR = re.compile(r"^(#([0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})|(rgb|rgba|hsl|hsla)\([0-9.,%\s/+-]+\))$")
# Each number key: (smallest, largest). The text stays at 12px or larger, as verify asks.
LIMITS = {"text-size": (12, 40), "line-height": (1, 3), "page-width": (320, 4000),
          "radius-small": (0, 64), "radius": (0, 64), "radius-large": (0, 64)}


def tokens_of(block):
    return {name: value.strip() for name, value in re.findall(r"--([a-z][a-z0-9-]*)\s*:\s*([^;}]+)", block)}


def number_of(value):
    """Returns the number in a value such as 15px or 1.7, as an int when it has no fraction."""
    m = re.match(r"^\s*(\d+(?:\.\d+)?)(px)?\s*$", value)
    if not m:
        return None
    n = float(m.group(1))
    return int(n) if n.is_integer() else n


def theme_defaults(text):
    """Returns the theme keys a page defines, with their values."""
    light = LIGHT_BLOCK.search(text)
    light_tokens = tokens_of(light.group(2)) if light else {}
    dark = DARK_BLOCKS[1].search(text) or DARK_BLOCKS[0].search(text)
    dark_tokens = tokens_of(dark.group(2)) if dark else {}
    result = {"light": {k: light_tokens[k] for k in COLOR_KEYS if k in light_tokens},
              "dark": {k: dark_tokens[k] for k in COLOR_KEYS if k in dark_tokens},
              "font": {}, "space": {}}
    for group, keys in (("font", FONT_KEYS), ("space", SPACE_KEYS)):
        for key, (token, kind) in keys.items():
            if token in light_tokens:
                value = light_tokens[token]
                result[group][key] = value if kind == "font" else number_of(value)
    return result


def theme_problems(theme):
    """Returns one line per key the theme file may not hold, naming the key."""
    if not isinstance(theme, dict):
        return ["the theme file holds %s, not an object of light, dark, font, and space" % type(theme).__name__]
    problems = []
    for group, values in theme.items():
        known = {"light": COLOR_KEYS, "dark": COLOR_KEYS, "font": tuple(FONT_KEYS), "space": tuple(SPACE_KEYS)}.get(group)
        if known is None:
            problems.append("%s: not a key; the keys are light, dark, font, and space" % group)
            continue
        if not isinstance(values, dict):
            problems.append("%s: holds %s, not an object" % (group, type(values).__name__))
            continue
        for key, value in values.items():
            name = "%s.%s" % (group, key)
            if key not in known:
                problems.append("%s: not a key; %s takes %s" % (name, group, ", ".join(known)))
            elif group in ("light", "dark"):
                if not isinstance(value, str) or not COLOR.match(value.strip()):
                    problems.append("%s: %r is not a color such as #2a5bd7 or rgb(42, 91, 215)" % (name, value))
            elif {**FONT_KEYS, **SPACE_KEYS}[key][1] == "font":
                if not isinstance(value, str) or not value.strip() or re.search(r"[;{}<>\\]", value) or len(value) > 300:
                    problems.append("%s: %r is not a font list such as \"Inter\", sans-serif" % (name, value))
            else:
                token = {**FONT_KEYS, **SPACE_KEYS}[key][0]
                low, high = LIMITS[token]
                if isinstance(value, bool) or not isinstance(value, (int, float)) or not low <= value <= high:
                    problems.append("%s: %r is not a number from %s to %s" % (name, value, low, high))
    return problems


def css_value(group, key, value):
    if group in ("light", "dark"):
        return value.strip()
    kind = {**FONT_KEYS, **SPACE_KEYS}[key][1]
    if kind == "font":
        return value.strip()
    text = ("%d" % value) if float(value).is_integer() else ("%g" % value)
    return text + "px" if kind == "px" else text


def set_tokens(block, values):
    for token, value in values.items():
        block = re.sub(TOKEN % re.escape(token), lambda m: m.group(1) + value + (m.group(3) or ";"), block, count=1)
    return block


def apply_theme(text, theme):
    """Returns the page with the theme's values in its light block and its two dark blocks."""
    light = {name: css_value("light", name, v) for name, v in theme.get("light", {}).items()}
    for group, keys in (("font", FONT_KEYS), ("space", SPACE_KEYS)):
        for key, value in theme.get(group, {}).items():
            light[keys[key][0]] = css_value(group, key, value)
    dark = {name: css_value("dark", name, v) for name, v in theme.get("dark", {}).items()}
    text = LIGHT_BLOCK.sub(lambda m: m.group(1) + set_tokens(m.group(2), light) + m.group(3), text, count=1)
    for pattern in DARK_BLOCKS:
        text = pattern.sub(lambda m: m.group(1) + set_tokens(m.group(2), dark) + m.group(3), text, count=1)
    return text


def theme_file():
    """Returns the theme file to use: the repository's, else the home one, else None."""
    folder = os.path.abspath(os.getcwd())
    while True:
        if os.path.exists(os.path.join(folder, ".git")):
            candidate = os.path.join(folder, THEME_NAME)
            if os.path.isfile(candidate):
                return candidate
            break
        parent = os.path.dirname(folder)
        if parent == folder:
            break
        folder = parent
    home = os.path.join(os.path.expanduser("~"), THEME_NAME)
    return home if os.path.isfile(home) else None


def theme_main(args):
    defaults = args[:1] == ["--defaults"]
    pages = args[1:] if defaults else args
    if len(pages) != 1 or not re.search(r"\.html?$", pages[0], re.I):
        print("usage: page-design.py theme [--defaults] <page.html>", file=sys.stderr)
        return 2
    page = pages[0]
    try:
        text = open(page, encoding="utf-8").read()
    except OSError:
        print("page-design: cannot read %s" % page, file=sys.stderr)
        return 2
    if defaults:
        print(json.dumps(theme_defaults(text), ensure_ascii=False, indent=2))
        return 0
    path = theme_file()
    if path is None:
        print("page-design: no theme file (%s at the root of the repository or ~/%s); %s left as it is" % (THEME_NAME, THEME_NAME, page))
        return 0
    try:
        raw = open(path, encoding="utf-8").read()
        theme = json.loads(raw) if raw.strip() else {}
    except (OSError, ValueError) as err:
        print("page-design: cannot read the theme file %s (%s)" % (path, err), file=sys.stderr)
        return 2
    problems = theme_problems(theme)
    if problems:
        for line in problems:
            print("page-design: %s: %s" % (path, line), file=sys.stderr)
        print("page-design: %s left as it is; fix the theme file and run theme again" % page, file=sys.stderr)
        return 2
    themed = apply_theme(text, theme)
    if themed != text:
        with open(page, "w", encoding="utf-8") as out:
            out.write(themed)
    print("page-design: theme %s applied to %s" % (path, page))
    return 0


def main(argv):
    if argv[:1] == ["theme"]:
        return theme_main(argv[1:])
    source = len(argv) > 1 and argv[1] == "--source"
    files = argv[2:] if source else argv[1:]
    if not argv or argv[0] != "verify" or not files:
        print("usage: page-design.py verify [--source] <file>...\n       page-design.py theme [--defaults] <page.html>", file=sys.stderr)
        return 2
    for path in files:
        if not re.search(r"\.(html?|md)$", path, re.I):
            print("page-design: %s is neither HTML (.html) nor Markdown (.md)" % path, file=sys.stderr)
            return 2
        try:
            open(path, encoding="utf-8").close()
        except OSError:
            print("page-design: cannot read %s" % path, file=sys.stderr)
            return 2
    count = 0
    for path in files:
        text = open(path, encoding="utf-8", errors="replace").read()
        found = check_markdown(text) if path.lower().endswith(".md") else check_html(text, source)
        for line, rule in sorted(set(found)):
            print("%s:%d: %s: %s" % (path, line, rule, FIXES[rule]))
            count += 1
    if count:
        print("page-design: %d problem%s; fix each line named above and run verify again" % (count, "" if count == 1 else "s"))
        return 1
    print("page-design: ok (%d file%s)" % (len(files), "" if len(files) == 1 else "s"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
