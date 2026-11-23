#!/usr/bin/env python3
"""Prints the values of the user's theme file that apply to a diagram.

Usage:
  diagram-theme.py

The theme file is .design-theme.json at the root of the git repository the command runs in, or else
~/.design-theme.json. The repository's file is used as it is, and the home file is not merged into
it. The file is the shared theme format of the design-formats plugin: up to four objects, light,
dark, font, and space. Every key of that format is checked, and the keys a diagram uses are printed
as JSON on stdout: the colors of light and dark except bar, the four font keys, and the three
corners. space.page-width and the bar colors belong to pages and are accepted without being printed.
Keys the file leaves out are not printed, and the diagram keeps the project's value for them.

Without a theme file it prints {} and says on stderr that the diagram keeps the project's own look.

Exit status:
  0  printed the theme's diagram values, or {} when there is no theme file
  2  called wrongly, or the theme file is not JSON or holds an unknown key or a bad value; each such
     key is named on stderr and nothing is printed on stdout

Uses only the Python standard library, reads only the theme file, writes nothing, runs no other
program, connects to nothing, and keeps nothing.
"""
import json
import os
import re
import sys

THEME_NAME = ".design-theme.json"
COLOR_KEYS = ("bg", "surface", "ink", "sub", "line", "accent", "accent-ink", "accent-soft", "bar", "label")
FONT_KEYS = ("sans", "mono", "size", "line-height")
SPACE_KEYS = ("page-width", "radius-small", "radius", "radius-large")
# Keys of the shared format that belong to pages: checked, never printed.
PAGE_KEYS = {"light.bar", "dark.bar", "space.page-width"}
COLOR = re.compile(r"^(#([0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})|(rgb|rgba|hsl|hsla)\([0-9.,%\s/+-]+\))$")
# Each number key: (smallest, largest), the same ranges as the design-formats theme format.
LIMITS = {"font.size": (12, 40), "font.line-height": (1, 3), "space.page-width": (320, 4000),
          "space.radius-small": (0, 64), "space.radius": (0, 64), "space.radius-large": (0, 64)}
GROUPS = {"light": COLOR_KEYS, "dark": COLOR_KEYS, "font": FONT_KEYS, "space": SPACE_KEYS}


def problems_of(theme):
    """Returns one line per key the theme file may not hold, naming the key."""
    if not isinstance(theme, dict):
        return ["the theme file holds %s, not an object of light, dark, font, and space" % type(theme).__name__]
    problems = []
    for group, values in theme.items():
        known = GROUPS.get(group)
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
            elif name in ("font.sans", "font.mono"):
                if not isinstance(value, str) or not value.strip() or re.search(r"[;{}<>\\]", value) or len(value) > 300:
                    problems.append("%s: %r is not a font list such as \"Inter\", sans-serif" % (name, value))
            else:
                low, high = LIMITS[name]
                if isinstance(value, bool) or not isinstance(value, (int, float)) or not low <= value <= high:
                    problems.append("%s: %r is not a number from %s to %s" % (name, value, low, high))
    return problems


def diagram_values(theme):
    """Returns the keys of a checked theme that a diagram uses, leaving out empty groups."""
    result = {}
    for group, values in theme.items():
        kept = {key: (value.strip() if isinstance(value, str) else value)
                for key, value in values.items() if "%s.%s" % (group, key) not in PAGE_KEYS}
        if kept:
            result[group] = kept
    return result


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


def main(argv):
    if argv:
        print("usage: diagram-theme.py", file=sys.stderr)
        return 2
    path = theme_file()
    if path is None:
        print("{}")
        print("diagram-theme: no theme file (%s at the root of the repository or ~/%s); "
              "the diagram keeps the project's own look" % (THEME_NAME, THEME_NAME), file=sys.stderr)
        return 0
    try:
        with open(path, encoding="utf-8") as source:
            raw = source.read()
        theme = json.loads(raw) if raw.strip() else {}
    except (OSError, ValueError) as err:
        print("diagram-theme: cannot read the theme file %s (%s)" % (path, err), file=sys.stderr)
        return 2
    problems = problems_of(theme)
    if problems:
        for line in problems:
            print("diagram-theme: %s: %s" % (path, line), file=sys.stderr)
        print("diagram-theme: fix the theme file and run diagram-theme.py again", file=sys.stderr)
        return 2
    print(json.dumps(diagram_values(theme), ensure_ascii=False, indent=2))
    print("diagram-theme: read %s" % path, file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
