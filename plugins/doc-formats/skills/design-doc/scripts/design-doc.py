#!/usr/bin/env python3
"""Checks that a design document written in the design format of the design-doc skill has every
section filled in.

Commands
  verify --sections FILE [--dated SECTION]... DESIGN
      check that DESIGN has the sections of FILE in their order and Open decisions after them,
      each filled in, and a real date (YYYY-MM-DD) in each dated section

The sections file is the part of a design a following skill keeps, such as its
templates/sections.md. Its level-two headings outside fenced code are the sections a design must
hold, in that order. Open decisions belongs to the format, so the sections file does not hold it.

Exit codes: 0 fine, 1 problems found, 2 wrong use or an unreadable or empty sections file.
verify also names each decision ID, such as D9, that the text cites but no row of the Open
decisions table defines.
verify prints only section names, decision IDs, and what is wrong with them, never the text of the
design.
"""
import argparse
import datetime
import re
import sys
from pathlib import Path

DECISIONS_SECTION = "Open decisions"
PLACEHOLDER = "Fill in:"
HEADING = re.compile(r"^##\s+(.+?)\s*#*\s*$")
FENCE = re.compile(r"^\s*(```|~~~)")
DATE = re.compile(r"\b(\d{4}-\d{2}-\d{2})\b")
DECISION_ROW = re.compile(r"^\s*\|\s*([A-Z])(\d+)\s*\|")


class WrongUse(Exception):
    """A problem with how verify was called, reported with exit code 2."""


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


def real_date(text):
    try:
        datetime.date.fromisoformat(text)
        return True
    except ValueError:
        return False


def read_sections(path, dated):
    """The section names a design must hold, in order, with Open decisions last."""
    try:
        text = Path(path).read_text(encoding="utf-8", errors="replace")
    except OSError:
        raise WrongUse("cannot read the sections file %s; pass the skill's templates/sections.md" % path)
    names = [title for title, _ in split_sections(text)[1]]
    if not names:
        raise WrongUse("%s has no sections; pass a file whose level-two headings are the skill's sections" % path)
    if DECISIONS_SECTION in names:
        raise WrongUse("%s holds %s, which the format adds after the skill's sections; remove it from the file"
                       % (path, DECISIONS_SECTION))
    for name in dated:
        if name not in names:
            raise WrongUse("--dated %s is not a section of %s" % (name, path))
    return names + [DECISIONS_SECTION]


def undefined_decisions(sections):
    """IDs such as D9 that the design cites but no row of an Open decisions table defines, in the
    order they first appear. Only letters that begin a row's ID count as ID letters, so ERC-20, SR2025,
    or step B3 are not read as IDs, and a design without such a table has nothing to check."""
    defined = set()
    for title, body in sections:
        if title == DECISIONS_SECTION:
            for line in body:
                match = DECISION_ROW.match(line)
                if match:
                    defined.add(match.group(1) + match.group(2))
    letters = "".join(sorted({name[0] for name in defined}))
    if not letters:
        return []
    cited = re.compile(r"(?<![A-Za-z0-9_])([%s]\d+)(?![A-Za-z0-9_])" % letters)
    text = "\n".join(line for _, body in sections for line in body)
    missing = []
    for name in cited.findall(text):
        if name not in defined and name not in missing:
            missing.append(name)
    return missing


def design_problems(text, required, dated):
    """Problems as 'what: section' lines, naming only sections, never the design's text."""
    preamble, sections = split_sections(text)
    problems = []
    if any(PLACEHOLDER in line for line in preamble):
        problems.append("unfinished: title")
    positions = {}
    for index, (title, _) in enumerate(sections):
        positions.setdefault(title, index)
    last = -1
    for name in required:
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
        elif name in dated and not any(real_date(d) for d in DATE.findall("\n".join(lines))):
            problems.append("no checked date: %s" % name)
    problems.extend("undefined decision: %s" % name for name in undefined_decisions(sections))
    return problems


def cmd_verify(args):
    try:
        required = read_sections(args.sections, args.dated)
    except WrongUse as error:
        print("design-doc: %s" % error, file=sys.stderr)
        return 2
    try:
        text = Path(args.file).read_text(encoding="utf-8", errors="replace")
    except OSError:
        print("design-doc: cannot read %s; pass the design file" % args.file, file=sys.stderr)
        return 2
    problems = design_problems(text, required, set(args.dated))
    for problem in problems:
        print(problem)
    if problems:
        print("design-doc: %d problem%s; fill in or add each section, or define each decision, named above"
              % (len(problems), "" if len(problems) == 1 else "s"))
        return 1
    print("design-doc: ok (%d sections)" % len(required))
    return 0


def main(argv):
    parser = argparse.ArgumentParser(prog="design-doc.py", description=__doc__.split("\n\n")[0],
                                     epilog="Exit codes: 0 fine, 1 problems found, 2 wrong use.")
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("verify", help="check that a design has every section filled in")
    p.add_argument("--sections", required=True,
                   help="the sections file of the skill that wrote the design, such as its templates/sections.md")
    p.add_argument("--dated", action="append", default=[], metavar="SECTION",
                   help="a section that must hold a checked date (YYYY-MM-DD); repeat for more")
    p.add_argument("file", help="the design file")
    args = parser.parse_args(argv)
    return {"verify": cmd_verify}[args.command](args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
