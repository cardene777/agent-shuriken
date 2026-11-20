#!/usr/bin/env python3
"""Check HTML pages and Markdown documents against the look rules of page-design.

Usage:
  page-design.py verify <file>...

Each file ending in .html or .htm is read as a page, and each file ending in .md as a document.
Every problem is printed as one line, <file>:<line>: <rule>: <how to fix>. The text of the page is
never printed, only rule names, line numbers, and fixes.

Exit codes:
  0  every file keeps the rules
  1  a file breaks a rule; each problem is named above the summary line
  2  called wrongly: no file, a missing file, or a file that is neither HTML nor Markdown

Uses only the Python standard library, reads only the files it is given, runs no other program,
connects to nothing, and keeps nothing.
"""

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
}

HEADING_MARKS = re.compile("[:\uff1a\u3001\u3002]")
SEPARATORS = re.compile(r"\u3001|,\s|\s\u00b7\s|\s\|\s|\s/\s")
LABEL_COLON = re.compile(r"^(\*\*[^*]{1,40}\*\*|[^\s:\uff1a|`][^:\uff1a|`]{0,39}?)(:(\s|$)|\uff1a)")
LABEL_EQUALS = re.compile(r"\S\s=\s\S")
INLINE_CODE = re.compile(r"`[^`]*`")
EXTERNAL = re.compile(r"^\s*(https?:)?//", re.I)
SMALL_FONT = re.compile(r"font(-size)?\s*:\s*([^;}\"']+)", re.I)
SIZE = re.compile(r"(\d+(?:\.\d+)?)(px|rem|em)\b", re.I)
SCRIPT_HEADING = re.compile(r"""\b(\w*(?:title|heading|Title|Heading)\w*)\s*:\s*(["'])((?:(?!\2).){1,200})\2""")
SCRIPT_STRING = re.compile(r"""(["'`])((?:(?!\1)[^\\\n]){12,300})\1""")
CODE_MARKS = re.compile(r"[<>{}()=;$\[\]]")


def facts_in_one_line(text):
    """True when the text joins three or more facts that each hold a number."""
    parts = [p for p in SEPARATORS.split(text) if p.strip()]
    if len(parts) < 3:
        return False
    return sum(1 for p in parts if re.search(r"\d", p)) >= 3


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

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.problems = []
        self.skip = []
        self.heading = None
        self.has_html = False
        self.lang_ok = True
        self.langs = set()
        self.themes = set()
        self.styles = []
        self.scripts = []
        self.current = None

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
        if values.get("style"):
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
        if source and EXTERNAL.match(source):
            self.problem(line, "external-file")
        if tag in ("iframe", "object", "embed") and not source:
            self.problem(line, "external-file")
        if tag in ("style", "script"):
            self.current = (tag, line, [])
        if tag in self.SKIP:
            self.skip.append(tag)
        elif tag in self.HEADINGS and not self.skip:
            self.heading = (line, [])

    def handle_endtag(self, tag):
        if self.current and tag == self.current[0]:
            kind, line, parts = self.current
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
        if facts_in_one_line(text):
            self.problem(line, "facts-in-one-line")
        elif label_joined(text):
            self.problem(line, "label-colon")

    def finish(self):
        css = "\n".join(text for _, text in self.styles)
        for line, text in self.styles:
            for offset in small_sizes(text):
                self.problem(line_at(text, offset, line), "small-text")
            for match in re.finditer(r"@import|url\(\s*['\"]?(https?:)?//", text, re.I):
                self.problem(line_at(text, match.start(), line), "external-file")
        for line, text in self.scripts:
            for match in SCRIPT_HEADING.finditer(text):
                if HEADING_MARKS.search(match.group(3)):
                    self.problem(line_at(text, match.start(), line), "heading-punctuation")
            for match in SCRIPT_STRING.finditer(text):
                # Only strings that read as prose; markup and code built in strings are skipped.
                if CODE_MARKS.search(match.group(2)):
                    continue
                if facts_in_one_line(match.group(2)):
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


def check_html(text):
    page = Page()
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
        if facts_in_one_line(INLINE_CODE.sub("", body)):
            problems.append((number, "facts-in-one-line"))
        elif label_joined(body):
            problems.append((number, "label-colon"))
    return problems


def main(argv):
    if len(argv) < 2 or argv[0] != "verify":
        print("usage: page-design.py verify <file>...", file=sys.stderr)
        return 2
    files = argv[1:]
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
        found = check_markdown(text) if path.lower().endswith(".md") else check_html(text)
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
