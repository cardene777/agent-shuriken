#!/usr/bin/env python3
"""Checks a deck outline (slides-outline.md) written in the format of references/deck-format.md.

Usage:
    python3 validate.py [--ban WORD]... <slides-outline.md>

Exit codes: 0 when the outline has no errors (warnings may still be printed), 1 when it has
errors, and 2 when the arguments are wrong or the file does not exist.
Errors and warnings go to standard error, and the OK line goes to standard output.

Rules (references/deck-format.md and references/readability-rules.md):
1. Every slide starts with a `## Slide N / M ─ <title>` heading.
2. Every slide has a `> meta:` line with `type=`.
3. A content slide has a `### Takeaway` section.
4. A `### Figure` section specifies the figure with an `Elements:` list of at least one item.
   More than five items is a warning.
5. Slide numbers count up from 1, and every slide gives the same total.
6. A general code word, or a word given with --ban, outside code and quotes is a warning.

The headings `Takeaway`, `Figure`, and `Elements` may also be written in the other spellings that
outline-headings.json lists, so an outline written in Japanese keeps its own headings.

Uses only the Python standard library and reads only the file it is given and outline-headings.json.
"""
import argparse
import json
import re
import sys
from pathlib import Path

# The spellings each heading may take, read from the file next to this script.
HEADINGS = json.loads((Path(__file__).resolve().parent / "outline-headings.json").read_text(encoding="utf-8"))


def spellings(key: str) -> str:
    """Returns a regular expression group that matches any spelling of the heading."""
    return "(?:" + "|".join(re.escape(word) for word in HEADINGS[key]) + ")"

# General code words that a non-engineer audience does not read (references/readability-rules.md).
# Words of one field are added per deck with --ban.
BANNED_WORDS = [
    "function", "method", "class", "struct", "variable",
    "API", "endpoint", "SDK", "query", "repository",
]

SLIDE_HEADING = re.compile(r"^##\s+Slide\s+(\d+)\s*/\s*(\d+)\s*[─–—-]\s*(.+)$")
SECTION = re.compile(r"^###\s")
SEPARATOR = re.compile(r"^---\s*$")
ELEMENTS = re.compile(r"^\**" + spellings("elements") + r"\**\s*[:：。]?\s*\**\s*$", re.IGNORECASE)
TAKEAWAY = re.compile(r"^###\s+" + spellings("takeaway") + r"\s*$")
FIGURE = re.compile(r"^###\s+" + spellings("figure") + r"\s*$")
LIST_ITEM = re.compile(r"^[-*]\s+")
# Text inside backticks and quotes is quoted material, not the deck's own words.
QUOTED = re.compile(r"`[^`]*`|\"[^\"]*\"|“[^”]*”|「[^」]*」")


def word_pattern(word: str) -> re.Pattern:
    """Matches the word and its plural as a whole word, in any letter case."""
    return re.compile(r"\b" + re.escape(word) + r"(?:e?s)?\b", re.IGNORECASE)


def split_slides(lines: list[str]) -> list[dict]:
    """Returns each slide's first and last line index, number, and total."""
    slides: list[dict] = []
    for i, line in enumerate(lines):
        found = SLIDE_HEADING.match(line.strip())
        if found:
            if slides:
                slides[-1]["end"] = i - 1
            slides.append({"start": i, "end": len(lines) - 1,
                           "num": int(found.group(1)), "total": int(found.group(2))})
    return slides


def check_figure(slide_lines: list[str], heading: int, prefix: str,
                 errors: list[str], warnings: list[str]) -> None:
    """Checks the `### Figure` section that starts at the heading line."""
    elements = None
    for k in range(heading + 1, len(slide_lines)):
        text = slide_lines[k].strip()
        if SECTION.match(text) or SEPARATOR.match(text):
            break
        if ELEMENTS.match(text):
            elements = k
            break
    if elements is None:
        errors.append(f"{prefix} `### Figure` has no `Elements:` list, so the figure is not specified")
        return
    items = []
    for k in range(elements + 1, len(slide_lines)):
        text = slide_lines[k].strip()
        if not text:
            if items:
                break
            continue
        if not LIST_ITEM.match(text):
            break
        items.append(text)
    if not items:
        errors.append(f"{prefix} `Elements:` lists nothing, so the figure is not specified")
    elif len(items) > 5:
        warnings.append(f"{prefix} the figure lists {len(items)} elements, more than 5 (split it across slides)")


def validate(text: str, extra_words: list[str]) -> tuple[list[str], list[str]]:
    """Checks the outline text and returns (errors, warnings)."""
    errors: list[str] = []
    warnings: list[str] = []
    lines = text.split("\n")
    slides = split_slides(lines)
    if not slides:
        errors.append("no slides found (expected `## Slide N / M ─ <title>` headings)")
        return errors, warnings

    previous = 0
    total = slides[0]["total"]
    for slide in slides:
        if slide["num"] != previous + 1:
            errors.append(f"slide number jump: expected {previous + 1}, got {slide['num']}")
        if slide["total"] != total:
            errors.append(f"slide[{slide['num']}] total mismatch: expected {total}, got {slide['total']}")
        previous = slide["num"]

    banned = [(word, word_pattern(word)) for word in BANNED_WORDS + extra_words]
    for slide in slides:
        slide_lines = lines[slide["start"]:slide["end"] + 1]
        prefix = f"slide[{slide['num']}/{slide['total']}]"

        meta = [line.strip() for line in slide_lines if line.strip().startswith("> meta:")]
        slide_type = "content"
        if not meta:
            errors.append(f"{prefix} missing `> meta:` line")
        elif "type=" not in meta[0]:
            errors.append(f"{prefix} the `> meta:` line has no `type=...`")
        else:
            found = re.search(r"type=(\w+)", meta[0])
            if found:
                slide_type = found.group(1)
                if slide_type not in ("hero", "chapter", "content"):
                    warnings.append(f"{prefix} unknown type: {slide_type}")

        has_takeaway = any(TAKEAWAY.match(line.strip()) for line in slide_lines)
        if slide_type == "content" and not has_takeaway:
            errors.append(f"{prefix} missing `### Takeaway` section")

        for index, line in enumerate(slide_lines):
            if FIGURE.match(line.strip()):
                check_figure(slide_lines, index, prefix, errors, warnings)

        in_code = False
        for index, line in enumerate(slide_lines):
            if line.strip().startswith("```"):
                in_code = not in_code
                continue
            if in_code:
                continue
            plain = QUOTED.sub("", line)
            for word, pattern in banned:
                if pattern.search(plain):
                    warnings.append(f"{prefix} line {slide['start'] + index + 1}: banned word found: {word!r}")
                    break

    return errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser(description="Check a deck outline (slides-outline.md).")
    parser.add_argument("--ban", action="append", default=[], metavar="WORD",
                        help="also flag this word, for the words of the deck's own field (repeatable)")
    parser.add_argument("outline", help="path to slides-outline.md")
    args = parser.parse_args()

    path = Path(args.outline)
    if not path.is_file():
        print(f"[ERROR] not found: {path}", file=sys.stderr)
        return 2
    errors, warnings = validate(path.read_text(encoding="utf-8"), args.ban)

    if errors:
        print(f"[VALIDATION ERROR] {len(errors)} error(s)", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
    if warnings:
        print(f"[VALIDATION WARN] {len(warnings)} warning(s)", file=sys.stderr)
        for warning in warnings:
            print(f"  - {warning}", file=sys.stderr)
    if errors:
        return 1
    print(f"[VALIDATION OK] {path.name}: errors: 0, warnings: {len(warnings)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
