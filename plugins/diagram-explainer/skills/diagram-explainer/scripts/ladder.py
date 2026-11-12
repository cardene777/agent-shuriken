#!/usr/bin/env python3
"""Draw a step ladder as one figure and put it into its slot in the body.

A step ladder answers "what happens at which step". Each step can carry up to six items
(number, what is done, what is called, the check that gates it, who acts, where the result
is kept). Folding that into the label of a single arrow makes it unreadable, so the ladder
draws one box per step.

The figure is an `<svg>` held directly by the body and loads nothing from outside.
Colors come from the CSS variables of the body; `assets/ladder.css` supplies defaults.

Usage:

  ladder.py --html <body HTML> --src <directory with the ladder JSON files>

Write the slot in the body on one line:

  <div class="ladder" data-ladder="steps"></div>

This name reads `<src>/steps.json`. The JSON fields are described in
`references/ladder-shape.md`.

Box and line names carry `data-node-label` / `data-edge-label` so that the term-table
check in `figure.py` can read them.
"""
import argparse
import html
import io
import json
import os
import re
import sys

SLOT = re.compile(r'(<div\b[^>]*\bclass="ladder"[^>]*\bdata-ladder="([\w.-]+)"[^>]*>)(\s*)(</div>)')
HTML_LANG = re.compile(r'<html\b[^>]*\blang="([^"]*)"', re.I)

# Default text drawn into the figure, per document language. `%s` is a step number.
UI = {
    "en": {"alt": "Step ladder", "back_edge": "Back to step %s", "back_note": "back to %s"},
    "ja": {"alt": "段の並び", "back_edge": "工程%s へ戻る", "back_note": "%s へ戻る"},
}

# Figure dimensions. The width follows the content; the height is set here.
NH = 58          # height of one step box
PITCH = 76       # distance between steps (box 58 + arrow 18)
BAND_H = 32      # height of a band heading
BAND_GAP = 10    # gap between bands
PAD_TOP = 12
PAD_BOTTOM = 6
NUM_W = 64       # width of the number column
SIDE_PAD = 16    # inner padding of a box
GAP_MID = 40     # gap between the step text and the right column
CH_W = 150       # left lane that carries the lines going back
TONES = {"emphasis": "var(--lad-emphasis)",
         "plain": "var(--lad-plain)",
         "strong": "var(--lad-strong)"}


def width_of(text, size):
    """Estimated text width: CJK characters count 1em, others 0.6em.

    Monospace characters are 0.6em, so mixed lines err on the side of not overflowing the box.
    """
    return sum(1.0 if ord(c) > 0x2E80 else 0.6 for c in text) * size


def esc(text):
    return html.escape(str(text), quote=True)


def fail(msg):
    sys.stderr.write("NG %s\n" % msg)
    sys.exit(1)


def lang_of(doc):
    """The document language from `<html lang>`: `ja` for Japanese, `en` otherwise."""
    m = HTML_LANG.search(doc)
    return "ja" if m and m.group(1).lower().startswith("ja") else "en"


def validate(spec, name):
    """Check the ladder definition. Stop without drawing at the first problem."""
    if not isinstance(spec, dict):
        fail("%s: the top level must be an object" % name)
    if spec.get("schema_version") != 1:
        fail("%s: schema_version is not 1 (%r)" % (name, spec.get("schema_version")))

    steps = spec.get("steps")
    if not isinstance(steps, list) or not steps:
        fail("%s: steps is empty" % name)

    seen = []
    for i, s in enumerate(steps):
        if not isinstance(s, dict):
            fail("%s: steps[%d] is not an object" % (name, i))
        for key in ("n", "title"):
            if key not in s:
                fail("%s: steps[%d] has no %s" % (name, i, key))
        if not isinstance(s["n"], int):
            fail("%s: steps[%d].n is not an integer (%r)" % (name, i, s["n"]))
        seen.append(s["n"])

    # Numbers must be unique: rows are looked up by number, and bands and back lines find
    # positions with `order.index()`, so a repeated number would point at the wrong step.
    #
    # Ascending order is not required. Steps are drawn in array order and the number is
    # only a name for the step, so a step can be inserted without renumbering.
    if len(set(seen)) != len(seen):
        fail("%s: steps share a number n (%s)" % (name, seen))

    tones = spec.get("actors", {})
    if not isinstance(tones, dict):
        fail("%s: actors must be an object" % name)
    for i, s in enumerate(steps):
        actor = s.get("actor")
        if actor is not None and actor not in tones:
            fail("%s: steps[%d].actor is not in actors (%r)" % (name, i, actor))
    for key, val in tones.items():
        tone = (val or {}).get("tone")
        if tone not in TONES:
            fail("%s: actors[%r].tone is not one of %s (%r)"
                 % (name, key, " / ".join(sorted(TONES)), tone))

    for i, b in enumerate(spec.get("bands", [])):
        for key in ("label", "from", "to"):
            if key not in b:
                fail("%s: bands[%d] has no %s" % (name, i, key))
        if b["from"] not in seen or b["to"] not in seen:
            fail("%s: bands[%d] range is not in steps (%s-%s)" % (name, i, b["from"], b["to"]))

    for i, e in enumerate(spec.get("back", [])):
        for key in ("from", "to"):
            if key not in e:
                fail("%s: back[%d] has no %s" % (name, i, key))
        if e["from"] not in seen:
            fail("%s: back[%d].from is not in steps (%r)" % (name, i, e["from"]))
        if e["to"] not in seen:
            fail("%s: back[%d].to is not in steps (%r)" % (name, i, e["to"]))
        # A back line points to an earlier step. Forward moves belong to the main flow;
        # drawing them here would draw them twice.
        if seen.index(e["to"]) >= seen.index(e["from"]):
            fail("%s: back[%d] does not point to an earlier step (%s -> %s)"
                 % (name, i, e["from"], e["to"]))

    note = spec.get("back_note")
    if note is not None and (not isinstance(note, str) or note.count("%s") != 1):
        fail("%s: back_note must contain %%s exactly once (%r)" % (name, note))


def sub_line(step):
    """The second line of a step: what is called and the check, on one line."""
    calls, gate = step.get("calls", ""), step.get("gate", "")
    if calls and gate:
        return "%s → %s" % (calls, gate)
    return calls or gate or ""


def box_width(spec):
    """Box width from the longest line, so no text leaves its box."""
    left = 0.0
    right = 0.0
    for s in spec["steps"]:
        left = max(left, width_of(s["title"], 15), width_of(sub_line(s), 12))
        actor = spec.get("actors", {}).get(s.get("actor"), {})
        right = max(right, width_of(s.get("place", ""), 12),
                    width_of(actor.get("label", ""), 12))
    return int(NUM_W + left + GAP_MID + right + SIDE_PAD + 0.5)


def render(spec, name, lang="en"):
    """Build the `<svg>` from the ladder definition."""
    ui = UI[lang]
    steps = spec["steps"]
    bands = spec.get("bands", [])
    back = spec.get("back", [])
    actors = spec.get("actors", {})

    nx = CH_W + 50 if back else 20
    nw = box_width(spec)
    order = [s["n"] for s in steps]
    groups = ([(b["label"], [s for s in steps
                             if order.index(b["from"]) <= order.index(s["n"]) <= order.index(b["to"])])
               for b in bands] if bands else [(None, steps)])

    rows = {}
    parts = []
    y = PAD_TOP
    for gi, (label, members) in enumerate(groups):
        if label:
            parts.append(
                '<text class="lad-band" x="%d" y="%d">%s</text>'
                '<line class="lad-hair" x1="%d" y1="%d" x2="%d" y2="%d"/>'
                % (nx, y + 12, esc(label), nx, y + 20, nx + nw, y + 20))
            y += BAND_H
        for si, s in enumerate(members):
            rows[s["n"]] = y
            actor = actors.get(s.get("actor"), {})
            tone = TONES.get(actor.get("tone"), TONES["plain"])
            parts.append(
                '<g><rect class="lad-node" x="%d" y="%d" width="%d" height="%d" rx="3"/>'
                '<rect x="%d" y="%d" width="4" height="%d" fill="%s"/>'
                '<text class="lad-num" x="%d" y="%d" fill="%s">%s</text>'
                '<text class="lad-title" data-node-label="%s" x="%d" y="%d">%s</text>'
                % (nx, y, nw, NH, nx, y, NH, tone,
                   nx + 20, y + 35, tone, esc(s.get("badge", "%02d" % s["n"])),
                   esc(s["title"]), nx + NUM_W, y + 25, esc(s["title"])))
            sub = sub_line(s)
            if sub:
                parts.append('<text class="lad-sub" x="%d" y="%d">%s</text>'
                             % (nx + NUM_W, y + 45, esc(sub)))
            if s.get("place"):
                parts.append('<text class="lad-place" x="%d" y="%d">%s</text>'
                             % (nx + nw - SIDE_PAD, y + 25, esc(s["place"])))
            if actor.get("label"):
                parts.append('<text class="lad-who" x="%d" y="%d" fill="%s">%s</text>'
                             % (nx + nw - SIDE_PAD, y + 45, tone, esc(actor["label"])))
            last = (gi == len(groups) - 1) and (si == len(members) - 1)
            if not last:
                parts.append(
                    '<line class="lad-flow" x1="%d" y1="%d" x2="%d" y2="%d" marker-end="url(#%s-f)"/>'
                    % (nx + 32, y + NH, nx + 32, y + PITCH - 4, name))
            y += PITCH
        y += BAND_GAP
    height = y - BAND_GAP + PAD_BOTTOM

    for e in back:
        ys = rows[e["from"]] + NH - 18
        yt = rows[e["to"]] + NH - 18
        mid = (ys + yt) / 2.0
        label = e.get("label", "")
        parts.append(
            '<path class="lad-back" data-edge-label="%s" d="M %d %d H %d V %d H %d"'
            ' marker-end="url(#%s-b)"/>'
            % (esc(label or (ui["back_edge"] % e["to"])), nx, ys, CH_W, yt, nx - 8, name))
        if label:
            parts.append('<text class="lad-blabel" x="%d" y="%.1f">%s</text>'
                         % (CH_W - 12, mid + 4, esc(label)))
        parts.append('<text class="lad-blabel" x="%d" y="%.1f">%s</text>'
                     % (CH_W - 12, mid + 20, esc(spec.get("back_note", ui["back_note"]) % e["to"])))

    defs = (
        '<defs>'
        '<marker id="%s-f" viewBox="0 0 8 8" refX="4" refY="4" markerWidth="6" markerHeight="6"'
        ' orient="auto"><path d="M0 0 L8 4 L0 8 z" class="lad-head"/></marker>'
        '<marker id="%s-b" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="6" markerHeight="6"'
        ' orient="auto"><path d="M0 0 L8 4 L0 8 z" class="lad-head-back"/></marker>'
        '</defs>' % (name, name))
    return ('<svg class="ladfig" viewBox="0 0 %d %d" role="img" aria-label="%s">%s%s</svg>'
            % (nx + nw + 10, height, esc(spec.get("alt", ui["alt"])), defs, "".join(parts)))


def fill(doc, src):
    """Fill every slot with its figure. Returns (document, names filled)."""
    used = []
    lang = lang_of(doc)

    def take(m):
        name = m.group(2)
        path = os.path.join(src, name + ".json")
        if not os.path.isfile(path):
            fail("no definition for slot %s (%s)" % (name, path))
        try:
            with io.open(path, encoding="utf-8") as f:
                spec = json.load(f)
        except (OSError, ValueError) as exc:
            fail("%s: cannot read the definition (%s)" % (name, exc))
        validate(spec, name)
        used.append(name)
        return m.group(1) + render(spec, name, lang) + m.group(4)

    return SLOT.sub(take, doc), used


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--html", required=True, help="body HTML (rewritten in place)")
    ap.add_argument("--src", required=True, help="directory with the ladder JSON files")
    a = ap.parse_args(argv)

    with io.open(a.html, encoding="utf-8") as f:
        doc = f.read()
    doc, used = fill(doc, a.src)
    if not used:
        sys.stderr.write("NG no ladder slot found (<div class=\"ladder\" data-ladder=...>)\n")
        return 1
    with io.open(a.html, "w", encoding="utf-8") as f:
        f.write(doc)
    print("filled %d ladders (%s)" % (len(used), ", ".join(used)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
