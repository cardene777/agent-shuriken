#!/usr/bin/env python3
"""Dated items about the versions of financial standards, and a check that a design written from
the template has every section filled in.

Commands
  check [--dir DIR]                  validate the items; exit 1 naming each bad item
  list [--dir DIR] [--today DATE]    one line per item, `stale` once checked more than 180 days ago
  verify FILE                        check that a design has the nine sections in order, each
                                     filled in, with a checked date in Standard and business

An item is a Markdown file whose front matter holds `standard` (one of iso-20022, fix, fpml, cdm,
lei, xbrl), `version` (the version in force when it was checked), `checked` (YYYY-MM-DD), and
`source` (the organization and document, never a URL).

Exit codes: 0 fine, 1 problems found, 2 wrong use or unreadable items.
verify prints only section names and what is wrong with them, never the text of the design.
"""
import argparse
import datetime
import re
import sys
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent.parent
ITEMS_DIR = SKILL_DIR / "references" / "items"
STANDARDS = ("iso-20022", "fix", "fpml", "cdm", "lei", "xbrl")
FRESH_DAYS = 180
SECTIONS = ("Standard and business", "Application", "Data and storage", "On-chain", "Off-chain",
            "Integration", "Security and operations", "Verification and delivery", "Open decisions")
DATED_SECTION = "Standard and business"
PLACEHOLDER = "Fill in:"
HEADING = re.compile(r"^##\s+(.+?)\s*#*\s*$")
FENCE = re.compile(r"^\s*(```|~~~)")
DATE = re.compile(r"\b(\d{4}-\d{2}-\d{2})\b")


def front_matter(path):
    """The `key: value` lines between the first two `---` lines, or None when there are none."""
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    fields = {}
    for line in lines[1:]:
        if line.strip() == "---":
            return fields
        key, sep, value = line.partition(":")
        if sep:
            fields[key.strip()] = value.strip()
    return None


def load_items(folder):
    """(items, problems): items as dicts with their name, problems as 'name: what is wrong'."""
    items, problems = [], []
    paths = sorted(Path(folder).glob("*.md"))
    if not paths:
        problems.append("%s: no items" % folder)
    for path in paths:
        name = path.stem
        fields = front_matter(path)
        if fields is None:
            problems.append("%s: no front matter between --- lines" % name)
            continue
        wrong = []
        for key in ("standard", "version", "checked", "source"):
            if not fields.get(key):
                wrong.append("missing %s" % key)
        standard = fields.get("standard", "")
        if standard and standard not in STANDARDS:
            wrong.append("unknown standard %s (use one of %s)" % (standard, ", ".join(STANDARDS)))
        try:
            fields["checked_date"] = datetime.date.fromisoformat(fields.get("checked", ""))
        except ValueError:
            if fields.get("checked"):
                wrong.append("checked %s is not a real date (YYYY-MM-DD)" % fields["checked"])
        if wrong:
            problems.append("%s: %s" % (name, "; ".join(wrong)))
            continue
        fields["name"] = name
        items.append(fields)
    return items, problems


def real_date(text):
    try:
        datetime.date.fromisoformat(text)
        return True
    except ValueError:
        return False


def split_sections(text):
    """(preamble lines, [(title, body lines)]) from level-two headings outside code fences."""
    preamble, sections, fenced = [], [], False
    for line in text.splitlines():
        if FENCE.match(line):
            fenced = not fenced
        match = None if fenced else HEADING.match(line)
        if match:
            sections.append((match.group(1), []))
        elif sections:
            sections[-1][1].append(line)
        else:
            preamble.append(line)
    return preamble, sections


def content_lines(lines):
    """The lines a reader sees: no blank lines, no headings, no HTML comments."""
    text = re.sub(r"<!--.*?-->", "", "\n".join(lines), flags=re.S)
    return [line for line in text.splitlines() if line.strip() and not line.lstrip().startswith("#")]


def design_problems(text):
    """Problems as 'what: section' lines, naming only sections, never the design's text."""
    preamble, sections = split_sections(text)
    problems = []
    if any(PLACEHOLDER in line for line in preamble):
        problems.append("unfinished: title")
    positions = {}
    for index, (title, _) in enumerate(sections):
        positions.setdefault(title, index)
    last = -1
    for name in SECTIONS:
        if name not in positions:
            problems.append("missing: %s" % name)
            continue
        index = positions[name]
        if index < last:
            problems.append("out of order: %s" % name)
        last = max(last, index)
        lines = content_lines(sections[index][1])
        if not lines:
            problems.append("empty: %s" % name)
        elif any(PLACEHOLDER in line for line in lines):
            problems.append("unfinished: %s" % name)
        elif name == DATED_SECTION and not any(real_date(d) for d in DATE.findall("\n".join(lines))):
            problems.append("no checked date: %s" % name)
    return problems


def cmd_check(args):
    items, problems = load_items(args.dir)
    for problem in problems:
        print(problem)
    if problems:
        print("financial-standards: %d problem%s; fix the front matter of each item named above"
              % (len(problems), "" if len(problems) == 1 else "s"))
        return 1
    print("financial-standards: ok (%d items)" % len(items))
    return 0


def cmd_list(args):
    items, problems = load_items(args.dir)
    if problems:
        for problem in problems:
            print(problem, file=sys.stderr)
        print("financial-standards: the items have problems; run check and fix them first", file=sys.stderr)
        return 2
    try:
        today = datetime.date.fromisoformat(args.today) if args.today else datetime.datetime.now(datetime.timezone.utc).date()
    except ValueError:
        print("financial-standards: --today takes a date such as 2026-11-16", file=sys.stderr)
        return 2
    stale = 0
    for item in items:
        old = (today - item["checked_date"]).days > FRESH_DAYS
        stale += old
        print("%-6s %-10s %s %s %s" % ("stale" if old else "ok", item["standard"], item["version"],
                                       item["checked"], item["name"]))
    print("%d items, %d stale as of %s" % (len(items), stale, today.isoformat()))
    return 0


def cmd_verify(args):
    path = Path(args.file)
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        print("financial-standards: cannot read %s; pass the design file" % args.file, file=sys.stderr)
        return 2
    problems = design_problems(text)
    for problem in problems:
        print(problem)
    if problems:
        print("financial-standards: %d problem%s; fill in or add each section named above"
              % (len(problems), "" if len(problems) == 1 else "s"))
        return 1
    print("financial-standards: ok (%d sections)" % len(SECTIONS))
    return 0


def main(argv):
    parser = argparse.ArgumentParser(prog="financial-standards.py", description=__doc__.split("\n\n")[0],
                                     epilog="Exit codes: 0 fine, 1 problems found, 2 wrong use.")
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("check", help="validate the items")
    p.add_argument("--dir", default=str(ITEMS_DIR), help="folder of items (default: the bundled items)")
    p = sub.add_parser("list", help="list the items and mark the stale ones")
    p.add_argument("--dir", default=str(ITEMS_DIR), help="folder of items (default: the bundled items)")
    p.add_argument("--today", help="count the days to this date (YYYY-MM-DD) instead of today in UTC")
    p = sub.add_parser("verify", help="check that a design has every section filled in")
    p.add_argument("file")
    args = parser.parse_args(argv)
    return {"check": cmd_check, "list": cmd_list, "verify": cmd_verify}[args.command](args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
