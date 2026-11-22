#!/usr/bin/env python3
"""First pass of the dashboard judgment: marks the screens that may be dashboards.

Usage:
    python3 screen_kind.py <screen-spec.md>...

Reads the table under the heading "## 項目定義" or "## Item definitions" of each screen
specification and counts the cells of its kind column ("種別" or "Kind"). A screen with at least one
chart and at least one total is a `candidate`; every other screen is `other`. A candidate is not yet
a dashboard: the second pass in SKILL.md decides that from the screen's main purpose.

The kind words differ from one specification to the next, so a cell counts when it contains a word,
not only when it equals one. The Japanese words match specifications written in Japanese.

Prints one line per file: <file> chart=<n> total=<n> => candidate|other
Exits 0, or 2 when a file cannot be read.
Uses only the Python standard library.
"""

import re
import sys

SECTION = re.compile(r"^## (項目定義|Item definitions)", re.IGNORECASE)
KIND_HEADERS = {"種別", "kind"}
CHART = re.compile(r"グラフ|chart|graph", re.IGNORECASE)
TOTAL = re.compile(r"数値|サマリー|KPI|合計|推移|number|summary|total|trend", re.IGNORECASE)
SEPARATOR = re.compile(r"^:?-+:?$")


def cells(line):
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def judge(path):
    chart = total = 0
    inside = False
    column = None
    with open(path, encoding="utf-8") as source:
        for line in source:
            if line.startswith("## "):
                inside = bool(SECTION.match(line))
                column = None
                continue
            if not inside or not line.lstrip().startswith("|"):
                column = None
                continue
            row = cells(line)
            if column is None:
                # The first row of a table is its header. Without a kind header, the second column holds the kind.
                lowered = [cell.lower() for cell in row]
                column = next((i for i, cell in enumerate(lowered) if cell in KIND_HEADERS), 1)
                continue
            if column >= len(row) or not row[column] or SEPARATOR.match(row[column]):
                continue
            if CHART.search(row[column]):
                chart += 1
            if TOTAL.search(row[column]):
                total += 1
    return chart, total


def main():
    if len(sys.argv) < 2:
        print("usage: python3 screen_kind.py <screen-spec.md>...", file=sys.stderr)
        sys.exit(2)
    for path in sys.argv[1:]:
        try:
            chart, total = judge(path)
        except OSError as error:
            print(f"screen_kind.py: cannot read {path}: {error}", file=sys.stderr)
            sys.exit(2)
        verdict = "candidate" if chart >= 1 and total >= 1 else "other"
        print(f"{path} chart={chart} total={total} => {verdict}")


if __name__ == "__main__":
    main()
