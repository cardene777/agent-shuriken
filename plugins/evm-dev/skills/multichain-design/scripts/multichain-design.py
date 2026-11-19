#!/usr/bin/env python3
"""Dated items about the deployment tools, bridges, message protocols, and token standards a design for
more than one chain relies on.

Commands
  check [--dir DIR]                  validate the items; exit 1 naming each bad item
  list [--dir DIR] [--today DATE]    one line per item, `stale` once checked more than 90 days ago

An item is a Markdown file whose front matter holds `topic` (one of deployment, bridges, messaging,
tokens), `subject` (the tool, protocol, standard, or practice it is about), `checked` (YYYY-MM-DD), and `source` (the organization and document, never a URL).

Exit codes: 0 fine, 1 problems found, 2 wrong use or unreadable items.
"""
import argparse
import datetime
import sys
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent.parent
ITEMS_DIR = SKILL_DIR / "references" / "items"
TOPICS = ("deployment", "bridges", "messaging", "tokens")
FIELDS = ("topic", "subject", "checked", "source")
FRESH_DAYS = 90
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
        wrong = ["missing %s" % key for key in FIELDS if not fields.get(key)]
        topic = fields.get("topic", "")
        if topic and topic not in TOPICS:
            wrong.append("unknown topic %s (use one of %s)" % (topic, ", ".join(TOPICS)))
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


def cmd_check(args):
    items, problems = load_items(args.dir)
    for problem in problems:
        print(problem)
    if problems:
        print("multichain-design: %d problem%s; fix the front matter of each item named above"
              % (len(problems), "" if len(problems) == 1 else "s"))
        return 1
    print("multichain-design: ok (%d items)" % len(items))
    return 0


def cmd_list(args):
    items, problems = load_items(args.dir)
    if problems:
        for problem in problems:
            print(problem, file=sys.stderr)
        print("multichain-design: the items have problems; run check and fix them first", file=sys.stderr)
        return 2
    try:
        today = datetime.date.fromisoformat(args.today) if args.today else datetime.datetime.now(datetime.timezone.utc).date()
    except ValueError:
        print("multichain-design: --today takes a date such as 2026-11-17", file=sys.stderr)
        return 2
    stale = 0
    for item in items:
        old = (today - item["checked_date"]).days > FRESH_DAYS
        stale += old
        print("%-6s %-12s %s %s %s" % ("stale" if old else "ok", item["topic"], item["checked"],
                                       item["name"], item["subject"]))
    print("%d items, %d stale as of %s" % (len(items), stale, today.isoformat()))
    return 0


def main(argv):
    parser = argparse.ArgumentParser(prog="multichain-design.py", description=__doc__.split("\n\n")[0],
                                     epilog="Exit codes: 0 fine, 1 problems found, 2 wrong use.")
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("check", help="validate the items")
    p.add_argument("--dir", default=str(ITEMS_DIR), help="folder of items (default: the bundled items)")
    p = sub.add_parser("list", help="list the items and mark the stale ones")
    p.add_argument("--dir", default=str(ITEMS_DIR), help="folder of items (default: the bundled items)")
    p.add_argument("--today", help="count the days to this date (YYYY-MM-DD) instead of today in UTC")
    args = parser.parse_args(argv)
    return {"check": cmd_check, "list": cmd_list}[args.command](args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
