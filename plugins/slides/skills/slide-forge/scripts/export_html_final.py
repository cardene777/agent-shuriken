#!/usr/bin/env python3
"""export_html_final.py: writes the public HTML of a slide by removing the edit toolbar and its
script from the edit page.

Implements references/edit-mode-spec.md and references/export-recipes.md. Uses only the Python
standard library.

Usage:
    python3 export_html_final.py edit-mode.html public.html

Removes every region between the markers inject_edit_mode.py writes
(`<!-- slide-forge-inject-start -->` and `<!-- slide-forge-inject-end -->`): the toolbar, its
dictionary, and its script.
The contenteditable and data-key attributes stay: a viewer who edits the public page changes only
their own view.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

INJECT_PATTERN = re.compile(
    r"<!-- slide-forge-inject-start -->.*?<!-- slide-forge-inject-end -->",
    re.DOTALL,
)


def strip(html: str) -> str:
    """Removes every region between the slide-forge markers."""
    cleaned, count = INJECT_PATTERN.subn("", html)
    if count == 0:
        print("WARN: no slide-forge-inject markers found, so the output is the same as the input", file=sys.stderr)
    return cleaned


def main() -> int:
    parser = argparse.ArgumentParser(description="remove the slide-forge edit toolbar from an edit page")
    parser.add_argument("input_html", help="input edit-mode HTML")
    parser.add_argument("output_html", help="output public HTML")
    args = parser.parse_args()

    in_path = Path(args.input_html)
    if not in_path.is_file():
        print(f"ERROR: input HTML not found: {in_path}", file=sys.stderr)
        return 1

    html = in_path.read_text(encoding="utf-8")
    stripped = strip(html)
    Path(args.output_html).write_text(stripped, encoding="utf-8")
    print(f"OK: {args.output_html} generated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
