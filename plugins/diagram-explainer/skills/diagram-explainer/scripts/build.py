#!/usr/bin/env python3
"""Finish a body HTML into one self-contained HTML file.

First every asset marker is replaced with the asset's content. Then the document is checked
for unfinished shapes; if any is found, nothing is written.

What counts as unfinished:

| Leftover | Why it is refused |
|---|---|
| `<iframe>` | The document draws its figures itself; a frame shows nothing once shared, or hides a second document |
| `class="mermaid"` | Needs a drawing library fetched when the page opens |
| `<script type="text/html"` | Figure source hidden in the body instead of a drawn figure |
| empty step ladder slot | `ladder.py` has not filled it |
| `<svg>` with no content | A figure failed to export (chart svgs are drawn on open and may be empty) |
| asset marker still in the file | The marker was not on its own line, so it was not replaced |

Usage:

  build.py --in <body HTML> --out <finished HTML>
"""
import argparse
import io
import os
import re
import sys

# Step ladders are filled by `ladder.py`; an empty slot means that step was skipped.
EMPTY_LADDER = re.compile(r'<div\b[^>]*\bclass="ladder"[^>]*>\s*</div>')
# Charts (`data-chart`) are drawn by `assets/charts.js` when the page opens, so they stay empty.
EMPTY_SVG = re.compile(r"<svg\b(?![^>]*\bdata-chart=)[^>]*>\s*</svg>")
IFRAME_TAG = re.compile(r"<iframe\b", re.I)
MARK_NAME = "diagram-explainer:asset"

LITERAL = [
    ('class="mermaid"', "mermaid diagram"),
    ('<script type="text/html"', "figure source hidden in the body"),
]

# Asset markers are replaced with the skill's asset files. Write each marker on its own line:
# `/* diagram-explainer:asset doc.css */` inside `<style>`, and
# `// diagram-explainer:asset print.js` inside `<script>`.
# The assets stay in one place and the shared document is still a single file.
ASSET_MARK = re.compile(r"^[ \t]*(?:/\*|//)\s*diagram-explainer:asset\s+([\w.-]+)\s*(?:\*/)?[ \t]*$",
                        re.M)
ASSETS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets")


def inline_assets(doc, die):
    """Replace the markers with the asset contents. Returns (document, asset names used)."""
    used = []

    def take(m):
        name = m.group(1)
        path = os.path.join(ASSETS, name)
        if not os.path.isfile(path):
            die("the body points to a missing asset (%s)" % name)
        used.append(name)
        with io.open(path, encoding="utf-8") as f:
            return f.read().rstrip("\n")

    return ASSET_MARK.sub(take, doc), used


def check(doc):
    """Count leftovers. Returns a list of (label, count)."""
    bad = []
    for needle, label in LITERAL:
        n = doc.count(needle)
        if n:
            bad.append(("%s (%s)" % (label, needle), n))
    n = len(IFRAME_TAG.findall(doc))
    if n:
        bad.append(("embedded frame (<iframe>)", n))
    n = len(EMPTY_LADDER.findall(doc))
    if n:
        bad.append(("unfilled step ladder slot", n))
    n = len(EMPTY_SVG.findall(doc))
    if n:
        bad.append(("figure with no content (empty <svg>)", n))
    n = doc.count(MARK_NAME)
    if n:
        bad.append(("asset marker not replaced (%s)" % MARK_NAME, n))
    return bad


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--in", dest="src", required=True, help="body HTML")
    ap.add_argument("--out", dest="dst", required=True, help="finished HTML")
    a = ap.parse_args(argv)

    def die(msg):
        sys.stderr.write("NG %s\n" % msg)
        sys.exit(1)

    try:
        with io.open(a.src, encoding="utf-8") as f:
            doc = f.read()
    except OSError as exc:
        die("cannot read %s (%s)" % (a.src, exc))

    doc, used = inline_assets(doc, die)
    if used:
        print("  inlined assets %s" % ", ".join(used))
    bad = check(doc)
    if bad:
        sys.stderr.write("NG unfinished shapes remain; nothing was written.\n")
        for label, n in bad:
            sys.stderr.write("  %s ... %d\n" % (label, n))
        return 1

    with io.open(a.dst, "w", encoding="utf-8") as f:
        f.write(doc)
    print("wrote %s (%d bytes, %d figures)"
          % (a.dst, len(doc.encode("utf-8")), len(re.findall(r"<figure\b", doc))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
