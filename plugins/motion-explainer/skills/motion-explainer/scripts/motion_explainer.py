#!/usr/bin/env python3
"""Check a motion-explainer spec and the SVG art it names, and render them into one HTML page.

Usage:
  motion_explainer.py check <spec.json>
  motion_explainer.py render <spec.json> --out <page.html>

A spec walks one running example through a mechanism scene by scene: the art direction of the
subject, a cast of one to four speakers, the parts on the stage with their states and places, the
scenes that change them, and figures that answer one question each. The part art is SVG files the
agent draws for the subject, named by the spec; each cast member takes one of the four pixel bodies
the skill ships (characters/), and each scene names its speaker, the speaker's pose, and an effect.
check prints one line per problem, `<field>: <problem>`, naming the field, such as
`scenes[1].set.cache` or `cast[0].body`. render runs the same checks, writes nothing when any fails,
and otherwise writes one page that loads nothing from the network: a player that plays the scenes
once, with chapters, effects from the bundled Sakuga VFX core (vendor/), and the figures under it,
drawn from the same art.

Text width counts 2 for a CJK character and 1 for any other character.

Exit codes:
  0  the spec is fine (check), or the page was written (render)
  1  the spec or its art has problems; each is printed
  2  called wrongly, or the spec is not readable JSON

Uses only the Python standard library, reads only the spec, the art it names, and the files next to
this script, writes only the page it is given, runs no other program, and connects to nothing.
"""

import base64
import copy
import html
import json
import os
import re
import sys
import unicodedata
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
TEMPLATES = os.path.join(os.path.dirname(HERE), "templates")
CHARACTERS = os.path.join(os.path.dirname(HERE), "characters")
CORE = os.path.join(os.path.dirname(HERE), "vendor", "sakuga-vfx", "core.js")

SVG = "http://www.w3.org/2000/svg"
XLINK = "http://www.w3.org/1999/xlink"
ET.register_namespace("", SVG)
ET.register_namespace("xlink", XLINK)

ID = re.compile(r"^[a-z][a-z0-9-]*$")
COLOR = re.compile(r"^#[0-9a-fA-F]{6}$")
LIMITS = {"title": 40, "lead": 120, "summary": 400, "cast": 16, "name": 20, "chapter": 16,
          "line": 80, "question": 60, "answer": 120, "label": 40, "step": 30, "side": 24,
          "point": 40, "column": 24, "cell": 48}
ART_BYTES = 100_000
DEFAULT_MS, MIN_MS, MAX_MS = 2800, 800, 20000
KINDS = ("still", "flow", "compare", "table")
BODIES = ("robot", "android", "guide", "drone")
POSES = ("wait", "explain", "surprised", "cheer")   # the order of the poses in each body's sheet
WORDS = ("don", "pon", "kachi", "shu", "zuza", "gogo")   # the sound-effect words of the core
FX_KEYS = ("burst", "word", "at")
CAST_W = 13   # percent of the stage width a cast member takes on the stage; its poses are square
CAST_H = round(CAST_W * 16 / 9, 2)
REFUSED = {"script", "foreignObject", "iframe", "object", "embed", "image", "style"}
DRAWING = {"svg", "g", "path", "rect", "circle", "ellipse", "line", "polyline", "polygon", "text",
           "tspan", "textPath", "defs", "use", "symbol", "title", "desc", "linearGradient",
           "radialGradient", "stop", "pattern", "clipPath", "mask", "marker", "filter",
           "feGaussianBlur", "feOffset", "feBlend", "feColorMatrix", "feComposite", "feFlood",
           "feMerge", "feMergeNode", "feDropShadow", "feMorphology", "feTurbulence",
           "feDisplacementMap", "feComponentTransfer", "feFuncR", "feFuncG", "feFuncB", "feFuncA"}
OUTSIDE_URL = re.compile(r"url\(\s*(?![\"']?\s*#)", re.I)


def width(text):
    """Display width: 2 for a wide (CJK) character, 1 for any other."""
    return sum(2 if unicodedata.east_asian_width(c) in ("W", "F") else 1 for c in text)


def local(name):
    return name.rsplit("}", 1)[-1]


def is_number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


class Spec:
    """The checked spec, the parsed art, and the end state of each scene."""

    def __init__(self, spec, folder):
        self.spec = spec
        self.folder = folder
        self.problems = []
        self.parts = {}
        self.order = []
        self.cast = {}
        self.cast_order = []
        self.art = {}       # a part id -> the parsed root of its art
        self.scene_ids = {}
        self.frames = []

    def say(self, field, problem):
        self.problems.append("%s: %s" % (field, problem))

    def text(self, value, field, limit, required=True):
        if value is None:
            if required:
                self.say(field, "is required")
            return False
        if not isinstance(value, str) or not value.strip():
            self.say(field, "must be text")
            return False
        if width(value) > limit:
            self.say(field, "is %d wide; keep it to %d (a CJK character counts 2)" % (width(value), limit))
            return False
        return True

    def states(self, value, field):
        if not isinstance(value, list) or not value:
            self.say(field, "must list at least one state")
            return []
        seen = []
        for i, s in enumerate(value):
            if not isinstance(s, str) or not ID.match(s):
                self.say("%s[%d]" % (field, i), "must start with a lowercase letter and use lowercase letters, digits, and -")
            elif s in seen:
                self.say("%s[%d]" % (field, i), 'is listed twice ("%s")' % s)
            else:
                seen.append(s)
        return seen if len(seen) == len(value) else []

    def check(self):
        s = self.spec
        if not isinstance(s, dict):
            self.say("spec", "must be a JSON object")
            return self
        if s.get("lang") not in ("en", "ja"):
            self.say("lang", "must be en or ja")
        self.text(s.get("title"), "title", LIMITS["title"])
        self.text(s.get("lead"), "lead", LIMITS["lead"])
        self.check_direction(s.get("direction"))
        if "narrator" in s:
            self.say("narrator", "is replaced by cast; list one to four cast members, each with one of the bodies %s" % ", ".join(BODIES))
        self.check_cast(s.get("cast"))
        parts = s.get("parts")
        if not isinstance(parts, list) or not 1 <= len(parts) <= 12:
            self.say("parts", "must list one to twelve parts")
        else:
            for i, p in enumerate(parts):
                self.check_part(i, p)
        scenes = s.get("scenes")
        if not isinstance(scenes, list) or not 2 <= len(scenes) <= 12:
            self.say("scenes", "must list two to twelve scenes")
        elif not self.problems:
            self.check_scenes(scenes)
        figures = s.get("figures", [])
        if not isinstance(figures, list) or len(figures) > 8:
            self.say("figures", "must be a list of at most eight figures")
        elif not self.problems:
            for i, f in enumerate(figures):
                self.check_figure(i, f)
        return self

    def check_direction(self, d):
        if not isinstance(d, dict):
            self.say("direction", "must be an object with summary, stage, and accent")
            return
        self.text(d.get("summary"), "direction.summary", LIMITS["summary"])
        for key in ("stage", "accent"):
            if not isinstance(d.get(key), str) or not COLOR.match(d[key]):
                self.say("direction." + key, "must be a color written as #rrggbb")

    def check_cast(self, cast):
        if not isinstance(cast, list) or not 1 <= len(cast) <= len(BODIES):
            self.say("cast", "must list one to four cast members, each with id, body, and name")
            return
        bodies = []
        for i, c in enumerate(cast):
            field = "cast[%d]" % i
            if not isinstance(c, dict):
                self.say(field, "must be an object with id, body, and name")
                continue
            cid = c.get("id")
            if not isinstance(cid, str) or not ID.match(cid):
                self.say(field + ".id", "must start with a lowercase letter and use lowercase letters, digits, and -")
                continue
            if cid in self.cast:
                self.say(field + ".id", 'is used twice ("%s")' % cid)
                continue
            body = c.get("body")
            if body not in BODIES:
                self.say(field + ".body", "must be one of %s" % ", ".join(BODIES))
            elif body in bodies:
                self.say(field + ".body", 'is cast twice ("%s"); give each cast member its own body' % body)
            else:
                bodies.append(body)
            self.text(c.get("name"), field + ".name", LIMITS["cast"])
            if "at" in c:
                self.place(c["at"], field + ".at", [CAST_W, CAST_H], "the cast member")
            self.cast[cid] = c
            self.cast_order.append(cid)

    def check_fx(self, fx, field):
        """The effect of one scene: a burst behind a part, one sound-effect word next to a part, or both."""
        if fx is None:
            return None
        field += ".fx"
        if not isinstance(fx, dict) or not fx:
            self.say(field, "must be an object with burst, word, or at")
            return None
        for key in fx:
            if key not in FX_KEYS:
                self.say("%s.%s" % (field, key), "is not a field of an effect; use burst, word, and at")
        for key in ("burst", "at"):
            if key in fx and fx[key] not in self.parts:
                self.say("%s.%s" % (field, key), 'no part is named "%s"' % fx[key])
        if "word" in fx:
            if fx["word"] not in WORDS:
                self.say(field + ".word", "must be one of %s" % ", ".join(WORDS))
            elif "burst" not in fx and "at" not in fx:
                self.say(field + ".at", "names no part for the word; name the part with burst or at")
        return {key: fx[key] for key in FX_KEYS if key in fx}

    def check_part(self, i, p):
        field = "parts[%d]" % i
        if not isinstance(p, dict):
            self.say(field, "must be an object")
            return
        pid = p.get("id")
        if not isinstance(pid, str) or not ID.match(pid):
            self.say(field + ".id", "must start with a lowercase letter and use lowercase letters, digits, and -")
            return
        if pid in self.parts:
            self.say(field + ".id", 'is used twice ("%s")' % pid)
            return
        self.parts[pid] = p
        self.order.append(pid)
        self.text(p.get("name"), field + ".name", LIMITS["name"])
        size = p.get("size")
        if not (isinstance(size, list) and len(size) == 2 and all(is_number(v) and 0 < v <= 100 for v in size)):
            self.say(field + ".size", "must be [w, h], each above 0 and at most 100 percent of the stage")
            size = None
        self.place(p.get("at"), field + ".at", size)
        states = self.states(p.get("states"), field + ".states")
        if states:
            self.load_art(pid, p.get("art"), field + ".art", states)

    def place(self, xy, field, size, what="the part"):
        if not (isinstance(xy, list) and len(xy) == 2 and all(is_number(v) and 0 <= v <= 100 for v in xy)):
            self.say(field, "must be [x, y], each from 0 to 100 percent of the stage")
            return False
        if size and (xy[0] + size[0] > 100 or xy[1] + size[1] > 100):
            self.say(field, "puts %s past the edge of the stage (x + %s and y + %s must be at most 100)" % (what, size[0], size[1]))
            return False
        return True

    def load_art(self, key, path, field, states):
        if not isinstance(path, str) or not path.strip():
            self.say(field, "must be the path of an SVG file, relative to the spec")
            return
        if os.path.isabs(path):
            self.say(field, "must be relative to the spec, not %s" % path)
            return
        full = os.path.join(self.folder, path)
        try:
            with open(full, "rb") as f:
                raw = f.read(ART_BYTES + 1)
        except OSError:
            self.say(field, "no file at %s" % path)
            return
        if len(raw) > ART_BYTES:
            self.say(field, "%s is over %d bytes; draw it with fewer points" % (path, ART_BYTES))
            return
        text = raw.decode("utf-8", "replace")
        if re.search(r"<!(DOCTYPE|ENTITY)", text, re.I):
            self.say(field, "%s declares a DOCTYPE or an entity; draw with elements only" % path)
            return
        try:
            root = ET.fromstring(text)
        except ET.ParseError as e:
            self.say(field, "%s is not readable SVG (%s)" % (path, e))
            return
        if root.tag != "{%s}svg" % SVG:
            self.say(field, "%s must have one svg element at the top, in the SVG namespace" % path)
            return
        if not root.get("viewBox"):
            self.say(field, "%s needs a viewBox on its svg element" % path)
            return
        found = self.unsafe(root, states)
        if found:
            self.say(field, "%s %s" % (path, found))
            return
        self.art[key] = root

    @staticmethod
    def unsafe(root, states):
        """The first reason the art could load from outside, run a script, or miss a state."""
        for el in root.iter():
            if not isinstance(el.tag, str):
                continue
            name = local(el.tag)
            if el.tag.startswith("{") and not el.tag.startswith("{%s}" % SVG):
                return "holds %s, which is not an SVG element" % name
            if name in REFUSED:
                why = "would restyle the whole page; put styles in attributes" if name == "style" else "is not allowed"
                return "holds a %s element, which %s" % (name, why)
            if name not in DRAWING:
                return "holds a %s element, which is not a drawing element" % name
            for attr, value in el.attrib.items():
                aname = local(attr)
                if aname.lower().startswith("on"):
                    return "has the attribute %s, which would run a script" % aname
                if aname == "href" and not value.startswith("#"):
                    return "links to %s; an href must start with #" % value
                if OUTSIDE_URL.search(value):
                    return "has url( pointing outside the drawing in %s; url( must point at #" % aname
                if "@import" in value.lower() or "javascript:" in value.lower():
                    return "has @import or javascript: in %s" % aname
            when = el.get("data-when")
            if when is not None:
                names = when.split()
                if not names:
                    return "has an empty data-when"
                for s in names:
                    if s not in states:
                        return 'names the state "%s" in data-when, which is not one of %s' % (s, ", ".join(states))
        return None

    def check_scenes(self, scenes):
        state = {pid: self.parts[pid]["states"][0] for pid in self.order}
        place = {pid: list(self.parts[pid]["at"]) for pid in self.order}
        voice = None
        for i, sc in enumerate(scenes):
            field = "scenes[%d]" % i
            if not isinstance(sc, dict):
                self.say(field, "must be an object")
                continue
            sid = sc.get("id")
            if not isinstance(sid, str) or not ID.match(sid):
                self.say(field + ".id", "must start with a lowercase letter and use lowercase letters, digits, and -")
            elif sid in self.scene_ids:
                self.say(field + ".id", 'is used twice ("%s")' % sid)
            else:
                self.scene_ids[sid] = i
            self.text(sc.get("chapter"), field + ".chapter", LIMITS["chapter"])
            self.text(sc.get("line"), field + ".line", LIMITS["line"])
            if "narrator" in sc:
                self.say(field + ".narrator", "is replaced by speaker and pose")
            speaker = sc.get("speaker", self.cast_order[0])
            if speaker not in self.cast:
                self.say(field + ".speaker", 'no cast member is named "%s"; use one of %s' % (speaker, ", ".join(self.cast_order)))
            pose = sc.get("pose", "explain")
            if pose not in POSES:
                self.say(field + ".pose", "must be one of %s" % ", ".join(POSES))
            fx = self.check_fx(sc.get("fx"), field)
            ms = sc.get("ms", DEFAULT_MS)
            if not isinstance(ms, int) or isinstance(ms, bool) or not MIN_MS <= ms <= MAX_MS:
                self.say(field + ".ms", "must be a whole number from %d to %d" % (MIN_MS, MAX_MS))
                ms = DEFAULT_MS
            changed, moved = set(), set()
            sets = sc.get("set", {})
            if not isinstance(sets, dict):
                self.say(field + ".set", "must be an object of part ids and states")
                sets = {}
            for pid, st in sets.items():
                f = "%s.set.%s" % (field, pid)
                if pid not in self.parts:
                    self.say(f, 'no part is named "%s"' % pid)
                elif st not in self.parts[pid]["states"]:
                    self.say(f, '%s has no state "%s"; use one of %s' % (pid, st, ", ".join(self.parts[pid]["states"])))
                else:
                    if state[pid] != st:
                        changed.add(pid)
                    state[pid] = st
            moves = sc.get("move", {})
            if not isinstance(moves, dict):
                self.say(field + ".move", "must be an object of part ids and places")
                moves = {}
            for pid, xy in moves.items():
                f = "%s.move.%s" % (field, pid)
                if pid not in self.parts:
                    self.say(f, 'no part is named "%s"' % pid)
                elif self.place(xy, f, self.parts[pid]["size"]):
                    if place[pid] != list(xy):
                        changed.add(pid)
                        moved.add(pid)
                    place[pid] = list(xy)
            if not changed and (speaker, pose) == voice:
                self.say(field, "changes nothing; set a state, move a part, change the speaker or pose, or join it with the scene before")
            voice = (speaker, pose)
            self.frames.append({"id": sid, "chapter": sc.get("chapter"), "line": sc.get("line"),
                                "speaker": speaker, "pose": pose, "fx": fx, "ms": ms, "states": dict(state),
                                "at": {k: list(v) for k, v in place.items()},
                                "changed": [pid for pid in self.order if pid in changed],
                                "moved": [pid for pid in self.order if pid in moved]})

    def part_state(self, pid, st, field):
        if pid not in self.parts:
            self.say(field + ".part", 'no part is named "%s"' % pid)
            return False
        if st not in self.parts[pid]["states"]:
            self.say(field + ".state", '%s has no state "%s"' % (pid, st))
            return False
        return True

    def check_figure(self, i, f):
        field = "figures[%d]" % i
        if not isinstance(f, dict):
            self.say(field, "must be an object")
            return
        if self.text(f.get("question"), field + ".question", LIMITS["question"]) and not f["question"].rstrip().endswith(("?", "？")):
            self.say(field + ".question", "must end in ? or ？")
        self.text(f.get("answer"), field + ".answer", LIMITS["answer"])
        kind = f.get("kind")
        if kind not in KINDS:
            self.say(field + ".kind", "must be one of %s" % ", ".join(KINDS))
        elif kind == "still":
            if f.get("scene") not in self.scene_ids:
                self.say(field + ".scene", 'no scene is named "%s"' % f.get("scene"))
            labels = f.get("labels")
            if not isinstance(labels, dict) or not 1 <= len(labels) <= 6:
                self.say(field + ".labels", "must name one to six parts with a label each")
                return
            for pid, text in labels.items():
                if pid not in self.parts:
                    self.say("%s.labels.%s" % (field, pid), 'no part is named "%s"' % pid)
                else:
                    self.text(text, "%s.labels.%s" % (field, pid), LIMITS["label"])
        elif kind == "flow":
            steps = f.get("steps")
            if not isinstance(steps, list) or not 2 <= len(steps) <= 6:
                self.say(field + ".steps", "must list two to six steps")
                return
            for j, st in enumerate(steps):
                sf = "%s.steps[%d]" % (field, j)
                if not isinstance(st, dict):
                    self.say(sf, "must be an object with part, state, and text")
                    continue
                self.part_state(st.get("part"), st.get("state"), sf)
                self.text(st.get("text"), sf + ".text", LIMITS["step"])
        elif kind == "compare":
            sides = f.get("sides")
            if not isinstance(sides, list) or len(sides) != 2:
                self.say(field + ".sides", "must list two sides")
                return
            for j, side in enumerate(sides):
                sf = "%s.sides[%d]" % (field, j)
                if not isinstance(side, dict):
                    self.say(sf, "must be an object with title, part, state, and points")
                    continue
                self.text(side.get("title"), sf + ".title", LIMITS["side"])
                self.part_state(side.get("part"), side.get("state"), sf)
                points = side.get("points")
                if not isinstance(points, list) or not 1 <= len(points) <= 4:
                    self.say(sf + ".points", "must list one to four points")
                    continue
                for k, pt in enumerate(points):
                    self.text(pt, "%s.points[%d]" % (sf, k), LIMITS["point"])
        else:
            columns = f.get("columns")
            if not isinstance(columns, list) or not 1 <= len(columns) <= 5:
                self.say(field + ".columns", "must list one to five columns")
                return
            for j, c in enumerate(columns):
                self.text(c, "%s.columns[%d]" % (field, j), LIMITS["column"])
            rows = f.get("rows")
            if not isinstance(rows, list) or not 1 <= len(rows) <= 12:
                self.say(field + ".rows", "must list one to twelve rows")
                return
            for j, row in enumerate(rows):
                if not isinstance(row, list) or len(row) != len(columns):
                    self.say("%s.rows[%d]" % (field, j), "must have %d cells, one per column" % len(columns))
                    continue
                for k, cell in enumerate(row):
                    self.text(cell, "%s.rows[%d][%d]" % (field, j, k), LIMITS["cell"])


# --- render --------------------------------------------------------------------------------------

def esc(text):
    return html.escape(str(text), quote=True)


class Drawer:
    """Writes the art into the page, giving each copy its own ids so two copies never share one."""

    def __init__(self, art):
        self.art = art
        self.count = 0

    def __call__(self, key):
        self.count += 1
        prefix = "me%d-" % self.count
        root = copy.deepcopy(self.art[key])
        ids = {el.get("id") for el in root.iter() if el.get("id")}
        for el in root.iter():
            if el.get("id"):
                el.set("id", prefix + el.get("id"))
            for attr, value in list(el.attrib.items()):
                if local(attr) == "href" and value[1:] in ids:
                    el.set(attr, "#" + prefix + value[1:])
                elif "url(" in value:
                    el.set(attr, re.sub(r"url\(\s*([\"']?)#([^)\"']+)\1\s*\)",
                                        lambda m: "url(#%s%s)" % (prefix if m.group(2) in ids else "", m.group(2)), value))
        for attr in ("width", "height", "x", "y"):
            root.attrib.pop(attr, None)
        root.set("aria-hidden", "true")
        root.set("focusable", "false")
        return ET.tostring(root, encoding="unicode", short_empty_elements=True)


def luminance(color):
    r, g, b = (int(color[i:i + 2], 16) / 255 for i in (1, 3, 5))
    lin = [c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4 for c in (r, g, b)]
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


def inset(spec, pid):
    """How far the drawing sits inside its box on a 16:9 stage, in percent of the box, as [x, y].
    The drawing keeps the shape of its viewBox, so the mark and the label hug the drawing."""
    vb = [float(v) for v in re.split(r"[\s,]+", spec.art[pid].get("viewBox").strip())]
    w, h = spec.parts[pid]["size"]
    drawing, box = vb[2] / vb[3], (w * 16) / (h * 9)
    if box > drawing:
        return [round((1 - drawing / box) * 50, 2), 0]
    return [0, round((1 - box / drawing) * 50, 2)]


def box_style(spec, pid, at):
    size, gap = spec.parts[pid]["size"], inset(spec, pid)
    return "left:%s%%;top:%s%%;width:%s%%;height:%s%%;--ix:%s%%;--iy:%s%%" % (at[0], at[1], size[0], size[1], gap[0], gap[1])


def stage_html(spec, draw):
    out = []
    for pid in spec.order:
        p = spec.parts[pid]
        out.append('<div class="me-part" data-part="%s" data-state="%s" style="%s"><div class="me-art">%s</div>'
                   '<span class="me-tag">%s</span></div>' % (pid, p["states"][0], box_style(spec, pid, p["at"]), draw(pid), esc(p["name"])))
    return "\n".join(out)


def cast_html(spec, on_stage):
    """The cast members with a place (on the stage) or without one (beside the bubble), each a body
    that shows one pose of its sheet and the member's name."""
    out = []
    first = spec.frames[0]
    for cid in spec.cast_order:
        c = spec.cast[cid]
        if ("at" in c) != on_stage:
            continue
        style = ' style="left:%s%%;top:%s%%;width:%s%%"' % (c["at"][0], c["at"][1], CAST_W) if on_stage else ""
        pose = first["pose"] if cid == first["speaker"] else "wait"
        out.append('<figure class="me-cast" data-cast="%s" data-body="%s" data-pose="%s"%s><div class="me-body"></div>'
                   '<figcaption class="me-name">%s</figcaption></figure>' % (cid, c["body"], pose, style, esc(c["name"])))
    return "\n".join(out)


def cast_css(spec):
    """One rule per cast body that puts its pose sheet on the body, as a data URI so the page stays one file."""
    out = []
    for cid in spec.cast_order:
        body = spec.cast[cid]["body"]
        with open(os.path.join(CHARACTERS, body + ".png"), "rb") as f:
            sheet = base64.b64encode(f.read()).decode("ascii")
        out.append('.me-cast[data-body="%s"] .me-body { background-image: url(data:image/png;base64,%s); }' % (body, sheet))
    return "\n".join(out)


def chapters_html(spec):
    out = []
    for i, f in enumerate(spec.frames):
        out.append('<li><button type="button" data-chapter="%d"><span class="me-bar"><i></i></span>'
                   '<span class="me-cn">%d</span><span class="me-ct">%s</span></button></li>' % (i, i + 1, esc(f["chapter"])))
    return "\n".join(out)


def chip(draw, pid, state):
    return '<div class="me-chip" data-part="%s" data-state="%s"><div class="me-art">%s</div></div>' % (pid, state, draw(pid))


def figure_html(spec, draw, f):
    kind = f["kind"]
    head = '<figcaption><h3 class="me-q">%s</h3><p class="me-a">%s</p></figcaption>' % (esc(f["question"]), esc(f["answer"]))
    if kind == "still":
        frame = spec.frames[spec.scene_ids[f["scene"]]]
        numbers = {pid: n + 1 for n, pid in enumerate(pid for pid in spec.order if pid in f["labels"])}
        pieces = []
        for pid in spec.order:
            badge = '<b class="me-badge">%d</b>' % numbers[pid] if pid in numbers else ""
            pieces.append('<div class="me-piece" data-part="%s" data-state="%s" style="%s"><div class="me-art">%s</div>%s</div>'
                          % (pid, frame["states"][pid], box_style(spec, pid, frame["at"][pid]), draw(pid), badge))
        legend = "".join('<li><b class="me-badge">%d</b><span><strong>%s</strong>%s</span></li>'
                         % (numbers[pid], esc(spec.parts[pid]["name"]), esc(f["labels"][pid])) for pid in numbers)
        body = ('<div class="me-still"><div class="me-mini">%s</div><ol class="me-legend">%s</ol></div>'
                % ("".join(pieces), legend))
    elif kind == "flow":
        steps = "".join('<li class="me-step">%s<p><span class="me-sn">%d</span>%s</p></li>'
                        % (chip(draw, st["part"], st["state"]), n + 1, esc(st["text"])) for n, st in enumerate(f["steps"]))
        body = '<ol class="me-flow" style="--n:%d">%s</ol>' % (len(f["steps"]), steps)
    elif kind == "compare":
        sides = "".join('<div class="me-side"><h4>%s</h4>%s<ul>%s</ul></div>'
                        % (esc(s["title"]), chip(draw, s["part"], s["state"]),
                           "".join("<li>%s</li>" % esc(pt) for pt in s["points"])) for s in f["sides"])
        body = '<div class="me-compare">%s</div>' % sides
    else:
        head_row = "".join('<th scope="col">%s</th>' % esc(c) for c in f["columns"])
        rows = "".join("<tr>%s</tr>" % "".join("<td>%s</td>" % esc(c) for c in row) for row in f["rows"])
        body = '<div class="me-table"><table><thead><tr>%s</tr></thead><tbody>%s</tbody></table></div>' % (head_row, rows)
    return '<figure class="me-fig" data-kind="%s">%s%s</figure>' % (kind, head, body)


def state_css(spec):
    names = []
    for states in [spec.parts[pid]["states"] for pid in spec.order]:
        for s in states:
            if s not in names:
                names.append(s)
    return "\n".join('[data-state="%s"] [data-when]:not([data-when~="%s"]) { display: none; }' % (s, s) for s in names)


def page(spec):
    s = spec.spec
    lang = s["lang"]
    with open(os.path.join(TEMPLATES, "page.html"), encoding="utf-8") as f:
        template = f.read()
    with open(os.path.join(TEMPLATES, "ui.json"), encoding="utf-8") as f:
        ui = json.load(f)
    words = ui[lang]
    draw = Drawer(spec.art)
    accent = s["direction"]["accent"]
    data = {"lang": lang, "parts": spec.order,
            "sizes": {pid: spec.parts[pid]["size"] for pid in spec.order},
            "insets": {pid: inset(spec, pid) for pid in spec.order},
            "cast": [{"id": cid, "name": spec.cast[cid]["name"], "at": spec.cast[cid].get("at")} for cid in spec.cast_order],
            "castWidth": CAST_W, "castHeight": CAST_H,
            "scenes": [{k: fr[k] for k in ("line", "speaker", "pose", "fx", "ms", "states", "at", "changed", "moved")} for fr in spec.frames]}
    with open(CORE, encoding="utf-8") as f:
        core = f.read()

    def script_json(value):
        return json.dumps(value, ensure_ascii=False, separators=(",", ":")).replace("<", "\\u003c")

    fills = {
        "{{lang}}": lang,
        "{{title}}": esc(s["title"]),
        "{{lead}}": esc(s["lead"]),
        "{{stage}}": s["direction"]["stage"],
        "{{accent}}": accent,
        "{{accent_ink}}": "#16130f" if luminance(accent) > 0.36 else "#ffffff",
        "{{state_css}}": state_css(spec),
        "{{cast_css}}": cast_css(spec),
        "{{cast_row}}": cast_html(spec, False),
        "{{cast_stage}}": cast_html(spec, True),
        "{{speaker}}": spec.frames[0]["speaker"],
        "{{speaker_name}}": esc(spec.cast[spec.frames[0]["speaker"]]["name"]),
        "{{fx_core}}": core,
        "{{parts}}": stage_html(spec, draw),
        "{{chapters}}": chapters_html(spec),
        "{{figures}}": "\n".join(figure_html(spec, draw, f) for f in s.get("figures", [])),
        "{{data}}": script_json(data),
        "{{ui}}": script_json(ui),
    }
    for key, value in words.items():
        fills["{{ui_%s}}" % key] = esc(value)
    return re.sub(r"\{\{[a-z_]+\}\}", lambda m: fills.get(m.group(0), m.group(0)), template)


def load(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        print("spec: cannot read %s (%s)" % (path, e))
        return None


def main(argv):
    if len(argv) >= 2 and argv[0] in ("check", "render"):
        cmd, path, rest = argv[0], argv[1], argv[2:]
        out = ""
        if cmd == "render":
            if len(rest) != 2 or rest[0] != "--out":
                print("usage: motion_explainer.py render <spec.json> --out <page.html>", file=sys.stderr)
                return 2
            out = rest[1]
        elif rest:
            print("usage: motion_explainer.py check <spec.json>", file=sys.stderr)
            return 2
        data = load(path)
        if data is None:
            return 2
        spec = Spec(data, os.path.dirname(os.path.abspath(path))).check()
        if spec.problems:
            for line in spec.problems:
                print(line)
            return 1
        if cmd == "check":
            print("ok")
            return 0
        text = page(spec)
        with open(out, "w", encoding="utf-8") as f:
            f.write(text)
        print("wrote %s" % out)
        return 0
    print((__doc__ or "").strip().split("\n\n")[1], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
