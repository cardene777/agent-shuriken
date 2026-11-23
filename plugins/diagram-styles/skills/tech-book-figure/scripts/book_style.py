#!/usr/bin/env python3
"""Tells the tech-book-figure skill what to draw a figure from, before it draws.

usage: book_style.py

Run it from the folder that holds the book text. It prints, on standard output:

  style4: samples or written
      samples when ~/.styles/style-catalog.json exists and ~/.styles/diagram-style-samples/style4/
      holds two or more images; written otherwise. With samples, one "sample:" line per image with
      its absolute path and the layouts the catalog records for it. Without, one "missing:" line
      that names what was missing.
  theme: none, or the theme file it read
      The theme file is .design-theme.json at the root of the git repository the command runs in,
      or else ~/.design-theme.json, in the format of the design-formats plugin's theme file. One
      "theme <key>:" line per key a figure takes, with what it replaces in style4, and one line
      naming the keys the file holds that a figure does not use.

Exits 0 when the skill may draw, 1 when the theme file is refused (each refused key is named on
standard error and the skill stops before drawing), and 2 on wrong usage. It reads only those
files, writes nothing, and connects to nothing.
"""

import json
import os
import re
import sys

SAMPLES = os.path.join("diagram-style-samples", "style4")
IMAGE = re.compile(r"\.(png|webp|jpe?g)$", re.I)
THEME_NAME = ".design-theme.json"

# The keys of the shared theme file and the value each takes. The same keys and limits as the
# theme command of the design-formats plugin, which a plugin may not call, so they are kept here.
COLOR_KEYS = ("bg", "surface", "ink", "sub", "line", "accent", "accent-ink", "accent-soft", "bar", "label")
FONT_KEYS = {"sans": "font", "mono": "font", "size": (12, 40), "line-height": (1, 3)}
SPACE_KEYS = {"page-width": (320, 4000), "radius-small": (0, 64), "radius": (0, 64), "radius-large": (0, 64)}
GROUPS = {"light": COLOR_KEYS, "dark": COLOR_KEYS, "font": tuple(FONT_KEYS), "space": tuple(SPACE_KEYS)}
COLOR = re.compile(r"^(#([0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})|(rgb|rgba|hsl|hsla)\([0-9.,%\s/+-]+\))$")

# The keys a printed figure takes, in this order, and what each replaces in style4.
USED = (
    ("light.bg", "the ground in place of white"),
    ("light.ink", "the lines and letters in place of black"),
    ("light.sub", "the gray of hatching, dotted lines, and secondary labels"),
    ("light.accent", "the first accent in place of teal"),
    ("light.accent-soft", "the light fill of the first accent"),
    ("font.sans", "the letters in the look of this typeface in place of handwriting"),
)


def style_source(home):
    """Returns the lines that say whether to draw from the samples or from the written rules."""
    styles = os.path.join(home, ".styles")
    catalog_path = os.path.join(styles, "style-catalog.json")
    if not os.path.isfile(catalog_path):
        return ["style4: written", "missing: ~/.styles/style-catalog.json"]
    try:
        catalog = json.load(open(catalog_path, encoding="utf-8"))
    except (OSError, ValueError) as error:
        return ["style4: written", "missing: a readable ~/.styles/style-catalog.json (%s)" % error]
    folder = os.path.join(styles, SAMPLES)
    names = sorted(n for n in os.listdir(folder) if IMAGE.search(n) and os.path.isfile(os.path.join(folder, n))) \
        if os.path.isdir(folder) else []
    if len(names) < 2:
        return ["style4: written",
                "missing: two or more images in ~/.styles/%s/ (found %d)" % (SAMPLES, len(names))]
    layouts = {}
    images = catalog.get("images") if isinstance(catalog, dict) else None
    for image in images if isinstance(images, list) else []:
        if not isinstance(image, dict):
            continue
        paths = [p for p in [image.get("path")] + list(image.get("original_paths") or []) if isinstance(p, str)]
        for path in paths:
            if os.path.dirname(os.path.normpath(path)) == SAMPLES:
                layouts[os.path.basename(path)] = [str(x) for x in image.get("layouts") or []]
    lines = ["style4: samples"]
    for name in names:
        recorded = ", ".join(layouts.get(name) or []) or "not recorded in the catalog"
        lines.append("sample: %s (layouts: %s)" % (os.path.join(folder, name), recorded))
    return lines


def theme_file(home):
    """Returns the theme file to read: the repository's, else the home one, else None."""
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
    candidate = os.path.join(home, THEME_NAME)
    return candidate if os.path.isfile(candidate) else None


def theme_problems(theme):
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
            kind = {**FONT_KEYS, **SPACE_KEYS}.get(key) if group in ("font", "space") else "color"
            if key not in known:
                problems.append("%s: not a key; %s takes %s" % (name, group, ", ".join(known)))
            elif kind == "color":
                if not isinstance(value, str) or not COLOR.match(value.strip()):
                    problems.append("%s: %r is not a color such as #2a5bd7 or rgb(42, 91, 215)" % (name, value))
            elif kind == "font":
                if not isinstance(value, str) or not value.strip() or re.search(r"[;{}<>\\]", value) or len(value) > 300:
                    problems.append("%s: %r is not a font list such as \"Inter\", sans-serif" % (name, value))
            else:
                low, high = kind
                if isinstance(value, bool) or not isinstance(value, (int, float)) or not low <= value <= high:
                    problems.append("%s: %r is not a number from %s to %s" % (name, value, low, high))
    return problems


def main(args):
    if args:
        print("usage: book_style.py (run it from the folder that holds the book text)", file=sys.stderr)
        return 2
    home = os.path.expanduser("~")
    print("\n".join(style_source(home)))
    path = theme_file(home)
    if path is None:
        print("theme: none (no %s at the root of this repository or in the home folder); "
              "style4 keeps its own colors and handwritten letters" % THEME_NAME)
        return 0
    try:
        theme = json.load(open(path, encoding="utf-8"))
    except OSError as error:
        problems = ["cannot be read (%s)" % error]
    except ValueError as error:
        problems = ["is not JSON (%s)" % error]
    else:
        problems = theme_problems(theme)
    if problems:
        print("theme: %s is refused; stop before drawing, and fix or remove the file" % path, file=sys.stderr)
        for problem in problems:
            print("theme %s" % problem, file=sys.stderr)
        return 1
    print("theme: %s" % path)
    for name, replaces in USED:
        group, key = name.split(".")
        value = theme.get(group, {}).get(key)
        if value is not None:
            print("theme %s: %s, %s" % (name, value.strip(), replaces))
    used = {name for name, _ in USED}
    unused = sorted("%s.%s" % (g, k) for g, values in theme.items() for k in values if "%s.%s" % (g, k) not in used)
    if unused:
        print("theme not used by a figure: %s" % ", ".join(unused))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
