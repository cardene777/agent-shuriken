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
- the facts on the cover give as many candidates as there are candidate cards, as many axes as axis
  sections, and as many sources as the sources section lists, the research date as YYYY-MM-DD, and
  an author row that is either empty or holds a name, not only spaces
- when the report keys its candidates, every card has its own key of lowercase letters, digits, and
  hyphens, and every row with a data-candidate key names a card's key
- every caution has an <h3> title that names the risk, not a word such as "Risk" or "Warning", and no
  role="alert", because it is in the page from the start
- no dragon figure is left undrawn: dragon embed has replaced every <pre class="dragon"> block
"""
import re
import sys
from html.parser import HTMLParser

REQUIRED = ["summary", "candidates", "risks", "ranking", "sources"]
SCORE_CLASSES = {"s": "S", "a": "A", "b": "B", "c": "C", "d": "D"}
RISK_CLASSES = {"critical", "high", "medium", "low"}
VOID = ("br", "hr", "img", "meta", "link", "input", "col", "source", "wbr")
KEY = re.compile(r"[a-z0-9]+(-[a-z0-9]+)*")
ISO_DATE = re.compile(r"\d{4}-\d{2}-\d{2}")
# Titles that name a kind of notice instead of the risk, in English and in Japanese, escaped so that
# this file stays in English.
GENERIC_TITLES = {
    "risk", "risks", "warning", "warnings", "caution", "note", "notice", "important", "attention", "info", "information",
    "\u30ea\u30b9\u30af", "\u6ce8\u610f", "\u8b66\u544a", "\u91cd\u8981", "\u304a\u77e5\u3089\u305b", "\u6ce8\u8a18",
}


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
        self.source_items = 0
        self.captures = []         # open elements whose text is read, each a dict with its depth
        self.cards = []            # one dict per candidate card: its key, name, and line
        self.rows = []             # (key, line) for every other element with a data-candidate key
        self.facts = []            # one dict per row of the facts table: its label key, value, date, and line
        self.cautions = []         # one dict per caution: its title, role, and line

    def classes(self, attrs):
        return set((dict(attrs).get("class") or "").split())

    def inside(self, section_id):
        return any(entry[2] == section_id for entry in self.stack)

    def open(self, kind, **info):
        frame = {"kind": kind, "depth": len(self.stack), "text": "", "line": self.getpos()[0], **info}
        self.captures.append(frame)
        return frame

    def nearest(self, kind):
        return next((f for f in reversed(self.captures) if f["kind"] == kind), None)

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        cls = self.classes(attrs)
        line = self.getpos()[0]
        if tag in ("img", "iframe", "video", "audio", "source") and re.match(r"(?i)\s*(https?:)?//", a.get("src") or ""):
            self.problems.append(f"<{tag}> loads {a.get('src')} from the network")
        if tag == "script" and a.get("src"):
            self.problems.append(f"<script> loads {a.get('src')}; keep the report free of external scripts")
        if tag == "link" and "stylesheet" in (a.get("rel") or "").lower():
            self.problems.append(f"<link> loads the stylesheet {a.get('href')}")
        if tag == "pre" and "dragon" in cls:
            self.problems.append(f"line {line}: a dragon figure is not drawn yet; run dragon embed on the report")
        if tag == "section":
            if a.get("id"):
                self.sections.setdefault(a["id"], 0)
            if "axis" in cls:
                self.axes += 1
        if tag == "table":
            self.tables.append({"marked": False, "rationale": False, "line": line})
        if tag == "th" and "rationale" in cls and self.tables:
            self.tables[-1]["rationale"] = True
        if "score" in cls:
            letter = [c for c in cls if c in SCORE_CLASSES]
            if len(letter) != 1:
                self.problems.append(f"line {line}: a score needs exactly one of the classes s, a, b, c, d")
            self.score = [letter[0] if letter else None, ""]
            if self.tables and self.in_table():
                self.tables[-1]["marked"] = True
        if "risk" in cls:
            if not cls & RISK_CLASSES:
                self.problems.append(f"line {line}: a risk label needs one of the classes critical, high, medium, low")
            if self.tables and self.in_table():
                self.tables[-1]["marked"] = True
        if "fill" in cls:
            m = re.search(r"width:\s*([0-9.]+)%", a.get("style") or "")
            if not m or not 0 <= float(m.group(1)) <= 100:
                self.problems.append(f"line {line}: a bar fill needs style=\"width: N%\" with N from 0 to 100")
        if tag == "a" and self.inside("sources") and re.match(r"(?i)https?://", a.get("href") or ""):
            self.source_links += 1
        if tag == "li" and self.inside("sources"):
            self.source_items += 1
        if tag not in VOID:
            self.stack.append((tag, cls, a.get("id")))
        else:
            return
        # The parts whose text is read, opened after the element is on the stack so that they close with it.
        card, fact, caution = self.nearest("card"), self.nearest("fact"), self.nearest("caution")
        if "card" in cls and self.inside("candidates"):
            self.open("card", key=a.get("data-candidate"), name="")
        elif "data-candidate" in a:
            self.rows.append((a["data-candidate"], line))
        if tag == "h3" and card is not None and not card["name"]:
            self.open("card-name", card=card)
        if tag == "table" and "facts" in cls:
            self.open("facts")
        elif self.nearest("facts") is not None:
            if tag == "tr":
                self.open("fact", label=None, value=None, date=None)
            elif tag == "th" and fact is not None:
                fact["label"] = a.get("data-t")
            elif tag == "td" and fact is not None:
                self.open("fact-value", fact=fact)
            elif tag == "time" and fact is not None:
                fact["date"] = a.get("datetime")
        if "caution" in cls:
            self.open("caution", title=None, role=a.get("role"))
        elif tag == "h3" and caution is not None and caution["title"] is None:
            self.open("caution-title", caution=caution)

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
        while self.captures and self.captures[-1]["depth"] > len(self.stack):
            self.read(self.captures.pop())

    def read(self, frame):
        """Keeps what a part held once its element closes."""
        kind, text = frame["kind"], frame["text"]
        if kind == "card":
            self.cards.append(frame)
        elif kind == "card-name":
            frame["card"]["name"] = " ".join(text.split())
        elif kind == "fact":
            self.facts.append(frame)
        elif kind == "fact-value":
            frame["fact"]["value"] = text
        elif kind == "caution":
            self.cautions.append(frame)
        elif kind == "caution-title":
            frame["caution"]["title"] = " ".join(text.split())

    def handle_data(self, data):
        if self.score is not None:
            self.score[1] += data
        for frame in self.captures:
            frame["text"] += data
        for entry in self.stack:
            if entry[0] == "section" and entry[2] in self.sections:
                self.sections[entry[2]] += len(data.strip())


def facts_problems(report):
    """The facts on the cover agree with the report they describe."""
    problems = []
    facts = {f["label"]: f for f in report.facts if f["label"]}
    for label, noun, actual, what in (
        ("factCandidates", "candidates", len(report.cards), "candidate cards"),
        ("factAxes", "axes", report.axes, "axis sections"),
        ("factSources", "sources", report.source_items, "sources in the sources section"),
    ):
        fact = facts.get(label)
        if fact is None:
            continue
        value = (fact["value"] or "").strip()
        if not value.isdigit():
            problems.append(f"line {fact['line']}: the facts give {value!r} {noun}; write the number")
        elif int(value) != actual:
            problems.append(f"line {fact['line']}: the facts give {value} {noun}, but the report has {actual} {what}")
    date = facts.get("factResearched")
    if date is not None and not ISO_DATE.fullmatch((date["date"] or (date["value"] or "")).strip()):
        problems.append(f"line {date['line']}: the research date in the facts is not written as YYYY-MM-DD")
    author = facts.get("factAuthor")
    if author is not None and author["value"] and not author["value"].strip():
        problems.append(f"line {author['line']}: the author row of the facts holds only spaces; put the name in it or leave it empty")
    return problems


def key_problems(report):
    """Every card has its own key, and every keyed row names one, once the report keys its candidates."""
    if not report.rows and not any(c["key"] is not None for c in report.cards):
        return []
    problems, seen = [], set()
    for card in report.cards:
        key, name = card["key"], card["name"] or "?"
        if not key:
            problems.append(f"line {card['line']}: the candidate card {name} has no data-candidate key")
        elif not KEY.fullmatch(key):
            problems.append(f"line {card['line']}: the key {key!r} of the card {name} needs lowercase letters, digits, and hyphens")
        elif key in seen:
            problems.append(f"line {card['line']}: two candidate cards share the key {key!r}")
        seen.add(key)
    # A card without its key leaves the rows of that candidate without a card; its line says enough.
    if all(c["key"] for c in report.cards):
        for key, line in report.rows:
            if key not in seen:
                problems.append(f"line {line}: the row names the candidate key {key!r}, which no card has")
    return problems


def caution_problems(report):
    problems = []
    for caution in report.cautions:
        if caution["title"] is None:
            problems.append(f"line {caution['line']}: the caution has no <h3> title naming the risk")
        elif caution["title"].lower().rstrip(".!") in GENERIC_TITLES:
            problems.append(f"line {caution['line']}: the caution is titled {caution['title']!r}; name the risk itself in its <h3>")
        if (caution["role"] or "").strip() == "alert":
            problems.append(f"line {caution['line']}: the caution is in the page from the start, so it takes no role=\"alert\"")
    return problems


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
    problems += facts_problems(report) + key_problems(report) + caution_problems(report)

    for p in problems:
        print(p)
    if problems:
        return 1
    print("ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
