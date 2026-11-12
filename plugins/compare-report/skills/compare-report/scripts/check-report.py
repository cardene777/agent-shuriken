"""Checks a finished report before it is shown to the user.

Usage: python3 check-report.py <report.html>
Prints one line per problem and exits 1 when there is any, or prints "ok" and exits 0.

A report passes when:
- no template placeholder ({{...}}) is left
- it loads nothing from the network: no script, stylesheet, @import, or image from a URL
- the summary, candidates, risks, ranking, and sources sections exist and are not empty,
  and there is at least one section with the class "axis"
- every table that shows a score or a risk label has a header cell with the class "rationale"
- every score is one of S, A, B, C, and D, with the matching class
- every bar's fill sets a width between 0% and 100%
- the sources section links at least one http or https page
"""
import re
import sys
from html.parser import HTMLParser

REQUIRED = ["summary", "candidates", "risks", "ranking", "sources"]
SCORE_CLASSES = {"s": "S", "a": "A", "b": "B", "c": "C", "d": "D"}
RISK_CLASSES = {"critical", "high", "medium", "low"}


class Report(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.problems = []
        self.stack = []            # open element names with their classes and ids
        self.sections = {}         # id -> text length inside it
        self.axes = 0
        self.tables = []           # one dict per table
        self.score = None          # the class of the score being read, and its text
        self.source_links = 0

    def classes(self, attrs):
        return set((dict(attrs).get("class") or "").split())

    def inside(self, section_id):
        return any(entry[2] == section_id for entry in self.stack)

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        cls = self.classes(attrs)
        if tag in ("img", "iframe", "video", "audio", "source") and re.match(r"(?i)\s*(https?:)?//", a.get("src") or ""):
            self.problems.append(f"<{tag}> loads {a.get('src')} from the network")
        if tag == "script" and a.get("src"):
            self.problems.append(f"<script> loads {a.get('src')}; keep the report free of external scripts")
        if tag == "link" and "stylesheet" in (a.get("rel") or "").lower():
            self.problems.append(f"<link> loads the stylesheet {a.get('href')}")
        if tag == "section":
            if a.get("id"):
                self.sections.setdefault(a["id"], 0)
            if "axis" in cls:
                self.axes += 1
        if tag == "table":
            self.tables.append({"marked": False, "rationale": False, "line": self.getpos()[0]})
        if tag == "th" and "rationale" in cls and self.tables:
            self.tables[-1]["rationale"] = True
        if "score" in cls:
            letter = [c for c in cls if c in SCORE_CLASSES]
            if len(letter) != 1:
                self.problems.append(f"line {self.getpos()[0]}: a score needs exactly one of the classes s, a, b, c, d")
            self.score = [letter[0] if letter else None, ""]
            if self.tables and self.in_table():
                self.tables[-1]["marked"] = True
        if "risk" in cls:
            if not cls & RISK_CLASSES:
                self.problems.append(f"line {self.getpos()[0]}: a risk label needs one of the classes critical, high, medium, low")
            if self.tables and self.in_table():
                self.tables[-1]["marked"] = True
        if "fill" in cls:
            m = re.search(r"width:\s*([0-9.]+)%", a.get("style") or "")
            if not m or not 0 <= float(m.group(1)) <= 100:
                self.problems.append(f"line {self.getpos()[0]}: a bar fill needs style=\"width: N%\" with N from 0 to 100")
        if tag == "a" and self.inside("sources") and re.match(r"(?i)https?://", a.get("href") or ""):
            self.source_links += 1
        if tag not in ("br", "hr", "img", "meta", "link", "input", "col", "source", "wbr"):
            self.stack.append((tag, cls, a.get("id")))

    def in_table(self):
        return any(entry[0] == "table" for entry in self.stack)

    def handle_endtag(self, tag):
        if self.score is not None and tag == "span":
            letter, text = self.score
            if letter and text.strip() != SCORE_CLASSES[letter]:
                self.problems.append(f"line {self.getpos()[0]}: the score shows {text.strip()!r} but its class says {SCORE_CLASSES[letter]}")
            self.score = None
        for i in range(len(self.stack) - 1, -1, -1):
            if self.stack[i][0] == tag:
                del self.stack[i:]
                break

    def handle_data(self, data):
        if self.score is not None:
            self.score[1] += data
        for entry in self.stack:
            if entry[0] == "section" and entry[2] in self.sections:
                self.sections[entry[2]] += len(data.strip())


def main():
    if len(sys.argv) != 2:
        print("usage: check-report.py <report.html>", file=sys.stderr)
        return 2
    text = open(sys.argv[1], encoding="utf-8").read()
    problems = []
    for m in sorted(set(re.findall(r"\{\{[A-Z_]+\}\}", text))):
        problems.append(f"the placeholder {m} is still in the report")
    for m in re.findall(r"@import[^;]*", text):
        problems.append(f"the stylesheet imports {m.strip()}")
    for m in re.findall(r"url\(\s*['\"]?(?:https?:)?//[^)]*\)", text):
        problems.append(f"the stylesheet loads {m}")

    report = Report()
    report.feed(text)
    problems += report.problems
    for section in REQUIRED:
        if section not in report.sections:
            problems.append(f"the section with id=\"{section}\" is missing")
        elif report.sections[section] == 0:
            problems.append(f"the section with id=\"{section}\" is empty")
    if report.axes == 0:
        problems.append("there is no section with class=\"axis\" comparing the candidates on one axis")
    for table in report.tables:
        if table["marked"] and not table["rationale"]:
            problems.append(f"line {table['line']}: a table with scores or risk labels has no <th class=\"rationale\"> column")
    if "sources" in report.sections and report.source_links == 0:
        problems.append("the sources section links no http or https page")

    for p in problems:
        print(p)
    if problems:
        return 1
    print("ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
