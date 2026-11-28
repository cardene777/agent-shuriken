"""The fields of a theme and a script, and the check build.py runs before it builds anything.

FIELDS names every field of each part of a theme and a script, and ACTIONS names every beat action
with the fields it takes besides the ones every beat takes. references/theme.md and
references/script.md describe each of them, and check() refuses a field that is not listed, so a
field the engine reads is never left out of the references.

check(theme, script, theme_dir, script_dir) returns a list of (field, reason) pairs, empty when both
are usable. Uses only the Python standard library.
"""

import json
import os
import re

COLORS = ("ink", "sub", "line", "paper", "bg", "panel", "slotLine", "primary", "primary2", "primarySoft",
          "accent", "accent2", "accentSoft", "yellow", "yellowSoft", "ok", "okSoft", "edge")
WORDS = ("don", "pon", "kachi", "shu", "zuza", "gogo")
PICTURE_TYPES = (".png", ".webp", ".jpg", ".jpeg", ".svg")

FIELDS = {
    "theme": ("name", "font", "colors", "fx", "floorY", "mark", "characterScale", "pixelated", "characters", "images"),
    "theme.colors": COLORS,
    "theme.fx": ("fill", "shade", "line", "ink", "accent", "sfx"),
    "theme.characters": ("default", "faces", "head", "scale"),
    "theme.images": ("file", "px", "crop", "group", "jpeg"),
    "theme.anchors": ("anchors",),
    "script": ("lang", "title", "subtitle", "lead", "cast", "images", "objects", "scenes", "figures"),
    "script.cast": ("character", "label", "tone", "scale"),
    "script.images": ("file", "px", "quality"),
    "object.nodes": ("type", "title", "levels", "edges", "gap", "rowGap", "size"),
    "object.nodes.node": ("id", "label", "sub", "image", "states", "hidden", "tag", "chip", "float", "tone", "rot", "size", "parent"),
    "object.holder": ("type", "back", "front", "anchor", "line", "stand", "width", "itemWidth", "labels", "label", "items"),
    "object.holder.item": ("id", "image", "states", "x", "width", "label", "sub", "hidden", "tone"),
    "object.screen": ("type", "image", "states", "frame", "address", "width", "view", "marks"),
    "object.screen.mark": ("rect", "kind"),
    "object.card": ("type", "title", "note", "band", "dot", "frame", "address", "width", "parts"),
    "object.prop": ("type", "image", "states", "width", "label"),
    "part.text": ("type", "id", "hidden", "text", "style"),
    "part.button": ("type", "id", "hidden", "text", "tone"),
    "part.row": ("type", "id", "hidden", "parts", "justify"),
    "part.tags": ("type", "id", "hidden", "items"),
    "part.tags.item": ("id", "text", "tone", "hidden"),
    "part.checks": ("type", "id", "hidden", "items", "style"),
    "part.checks.item": ("id", "text"),
    "part.slots": ("type", "id", "hidden", "count", "cols", "height", "image", "numbered"),
    "part.counter": ("type", "id", "hidden", "start", "total", "unit"),
    "part.image": ("type", "id", "hidden", "image", "states", "width", "height"),
    "part.field": ("type", "id", "hidden", "label", "placeholder"),
    "scene": ("chapter", "cast", "objects", "layout", "zoom", "gap", "beats"),
    "scene.cast": ("id", "side"),
    "beat": ("do", "wait", "hold", "fx", "fxAt"),
    "fx": ("word", "size", "dx", "dy", "rot", "burst", "kira", "kdx", "puff", "slash", "ring"),
    "figure.still": ("kind", "question", "answer", "scene", "labels"),
    "figure.flow": ("kind", "question", "answer", "steps"),
    "figure.flow.step": ("target", "state", "text"),
    "figure.compare": ("kind", "question", "answer", "sides"),
    "figure.compare.side": ("title", "target", "state", "points"),
    "figure.table": ("kind", "question", "answer", "columns", "rows"),
}

# Beat actions and the fields each takes besides FIELDS["beat"].
ACTIONS = {
    "say": ("who", "text", "face", "act", "emote"),
    "face": ("who", "face"),
    "act": ("who", "act"),
    "emote": ("who", "emote"),
    "enter": ("who", "side"),
    "exit": ("who",),
    "show": ("target", "column"),
    "hide": ("target",),
    "press": ("target", "text", "tone"),
    "set": ("target", "state", "items"),
    "mark": ("target", "on"),
    "text": ("target", "text", "sub", "tone"),
    "swap": ("target", "state"),
    "clear": ("target",),
    "shake": ("target",),
    "fly": ("text", "image", "width", "from", "to", "land"),
    "stamp": ("target", "text", "image"),
    "focus": ("target", "mark", "rect", "pad"),
    "tap": ("target",),
    "fx": ("target",),
    "fill": ("target", "from", "to", "step", "counter"),
    "count": ("target", "from", "to", "step", "state", "fxEvery"),
    "type": ("target", "text", "step"),
}
ACTS = ("hop", "shake", "write", "still")
OBJECT_TYPES = ("nodes", "holder", "screen", "card", "prop")
PART_TYPES = ("text", "button", "row", "tags", "checks", "slots", "counter", "image", "field")
FIGURE_KINDS = ("still", "flow", "compare", "table")


class Problems(list):
    def add(self, field, reason):
        self.append((field, reason))

    def fields(self, where, value, section):
        """Refuses value when it is not an object, or names a field the section does not list."""
        if not isinstance(value, dict):
            self.add(where, "must be an object")
            return False
        for key in value:
            if key not in FIELDS[section]:
                self.add("%s.%s" % (where, key), "is not a field of %s" % section)
        return True


def is_text(v):
    return isinstance(v, str) and v.strip() != ""


def is_number(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def picture_file(p, where, folder, path):
    if not is_text(path):
        p.add(where, "must name a picture file")
        return None
    full = os.path.normpath(os.path.join(folder, path))
    if os.path.splitext(full)[1].lower() not in PICTURE_TYPES:
        p.add(where, "must be a PNG, WebP, JPEG, or SVG file")
    elif not os.path.isfile(full):
        p.add(where, "names %s, which does not exist" % path)
    else:
        return full
    return None


def check_theme(theme, folder):
    """The problems of a theme, and the names of its pictures with the anchors of each."""
    p = Problems()
    anchors = {}
    if not p.fields("theme", theme, "theme"):
        return p, {}, anchors
    if not is_text(theme.get("font")):
        p.add("theme.font", "must name the font of the video")
    colors = theme.get("colors")
    if p.fields("theme.colors", colors, "theme.colors"):
        for key in COLORS:
            if not is_text(colors.get(key)):
                p.add("theme.colors.%s" % key, "must be a color")
    if "fx" in theme and p.fields("theme.fx", theme["fx"], "theme.fx"):
        sfx = theme["fx"].get("sfx")
        if sfx is not None and not (isinstance(sfx, list) and len(sfx) == 2 and all(is_text(c) for c in sfx)):
            p.add("theme.fx.sfx", "must be two colors, the fill and the edge of a word")
    if not is_number(theme.get("floorY")) or not 0 < theme["floorY"] <= 504:
        p.add("theme.floorY", "must be the line the cast stands on, from 1 to 504")
    if "characterScale" in theme and (not is_number(theme["characterScale"]) or theme["characterScale"] <= 0):
        p.add("theme.characterScale", "must be a number above 0")
    if "pixelated" in theme and not isinstance(theme["pixelated"], bool):
        p.add("theme.pixelated", "must be true or false")
    images = theme.get("images", {})
    if isinstance(images, dict):
        for name, spec in images.items():
            where = "theme.images.%s" % name
            if not p.fields(where, spec, "theme.images"):
                continue
            full = picture_file(p, where + ".file", folder, spec.get("file"))
            if "px" in spec and (not isinstance(spec["px"], int) or spec["px"] <= 0):
                p.add(where + ".px", "must be a whole number above 0")
            for flag in ("crop", "jpeg"):
                if flag in spec and not isinstance(spec[flag], bool):
                    p.add("%s.%s" % (where, flag), "must be true or false")
            if "group" in spec and not is_text(spec["group"]):
                p.add(where + ".group", "must name a group")
            if full:
                anchors[name] = side_anchors(p, where, full)
    else:
        p.add("theme.images", "must be an object")
    if "mark" in theme and theme["mark"] not in images:
        p.add("theme.mark", "names %r, which is not an image of the theme" % theme["mark"])
    characters = theme.get("characters")
    faces = {}
    if not isinstance(characters, dict) or not characters:
        p.add("theme.characters", "must hold at least one character")
    else:
        for cid, ch in characters.items():
            where = "theme.characters.%s" % cid
            if not p.fields(where, ch, "theme.characters"):
                continue
            fs = ch.get("faces")
            if not isinstance(fs, dict) or not fs:
                p.add(where + ".faces", "must hold at least one face")
                continue
            for face, path in fs.items():
                picture_file(p, "%s.faces.%s" % (where, face), folder, path)
            if "default" in ch and ch["default"] not in fs:
                p.add(where + ".default", "names %r, which is not one of its faces" % ch["default"])
            for key in ("head", "scale"):
                if key in ch and (not is_number(ch[key]) or ch[key] <= 0):
                    p.add("%s.%s" % (where, key), "must be a number above 0")
            faces[cid] = set(fs)
    return p, faces, anchors


def side_anchors(p, where, picture):
    """The anchors of a picture, from a JSON file next to it with the same name."""
    side = os.path.splitext(picture)[0] + ".json"
    if not os.path.isfile(side):
        return {}
    try:
        data = json.load(open(side, encoding="utf-8"))
    except ValueError as e:
        p.add(where + ".anchors", "%s is not JSON: %s" % (os.path.basename(side), e))
        return {}
    if not p.fields(where + ".anchors", data, "theme.anchors"):
        return {}
    marks = data.get("anchors", {})
    if not isinstance(marks, dict) or not all(isinstance(v, list) and len(v) == 2 and all(is_number(n) for n in v) for v in marks.values()):
        p.add(where + ".anchors", "must map each anchor to [x, y] in pixels of the picture")
        return {}
    return marks


class Script:
    """Walks a script and collects what its beats may name."""

    def __init__(self, p, theme_faces, pictures, anchors):
        self.p, self.faces, self.pictures, self.anchors = p, theme_faces, pictures, anchors
        self.targets = {}  # target -> {"pic": picture name or None, "states": set}
        self.cast = {}

    def picture(self, where, name):
        if name not in self.pictures:
            self.p.add(where, "names %r, which is neither an image of the theme nor of the script" % (name,))
            return False
        return True

    def states(self, where, states):
        if states is None:
            return set()
        if not isinstance(states, dict):
            self.p.add(where, "must map each state to an image")
            return set()
        for state, name in states.items():
            self.picture("%s.%s" % (where, state), name)
        return set(states)

    def target(self, key, pic=None, states=()):
        self.targets[key] = {"pic": pic, "states": set(states)}

    def obj(self, oid, s):
        where = "objects.%s" % oid
        if not isinstance(s, dict):
            self.p.add(where, "must be an object")
            return
        kind = s.get("type")
        if kind not in OBJECT_TYPES:
            self.p.add(where + ".type", "must be one of %s, not %r" % (", ".join(OBJECT_TYPES), kind))
            return
        self.p.fields(where, s, "object." + kind)
        getattr(self, "obj_" + kind)(oid, where, s)

    def obj_prop(self, oid, where, s):
        ok = self.picture(where + ".image", s.get("image"))
        self.target(oid, s.get("image") if ok else None, self.states(where + ".states", s.get("states")))

    def obj_screen(self, oid, where, s):
        ok = self.picture(where + ".image", s.get("image"))
        self.target(oid, s.get("image") if ok else None, self.states(where + ".states", s.get("states")))
        if s.get("frame", "browser") not in ("browser", "phone"):
            self.p.add(where + ".frame", "must be browser or phone")
        if "view" in s and (not is_number(s["view"]) or not 0 < s["view"] <= 2):
            self.p.add(where + ".view", "must be the height of the window over its width, above 0")
        marks = s.get("marks", {})
        if not isinstance(marks, dict):
            self.p.add(where + ".marks", "must map each mark to its rect")
            return
        for mid, m in marks.items():
            mw = "%s.marks.%s" % (where, mid)
            rect = m.get("rect") if isinstance(m, dict) else m
            if isinstance(m, dict):
                self.p.fields(mw, m, "object.screen.mark")
                if m.get("kind") not in (None, "field", "pill"):
                    self.p.add(mw + ".kind", "must be field or pill")
            if not (isinstance(rect, list) and len(rect) == 4 and all(is_number(n) and 0 <= n <= 1 for n in rect)):
                self.p.add(mw, "must be a rect [x, y, w, h] in fractions of the page")
            self.target("%s.%s" % (oid, mid))

    def obj_nodes(self, oid, where, s):
        levels = s.get("levels")
        if not isinstance(levels, list) or not levels or not all(isinstance(l, list) and l for l in levels):
            self.p.add(where + ".levels", "must be rows of nodes, each with at least one node")
            return
        seen = set()
        for li, level in enumerate(levels):
            for ni, n in enumerate(level):
                nw = "%s.levels[%d][%d]" % (where, li, ni)
                if not self.p.fields(nw, n, "object.nodes.node"):
                    continue
                pic = n.get("image")
                if pic is not None and not self.picture(nw + ".image", pic):
                    pic = None
                states = self.states(nw + ".states", n.get("states"))
                if "parent" in n and n["parent"] not in seen:
                    self.p.add(nw + ".parent", "names %r, which is not a node of an earlier row" % (n["parent"],))
                if "id" in n:
                    seen.add(n["id"])
                    self.target("%s.%s" % (oid, n["id"]), pic, states)
        if s.get("edges", "tree") not in ("tree", "string", False):
            self.p.add(where + ".edges", "must be tree, string, or false")
        self.target(oid)

    def obj_holder(self, oid, where, s):
        back_ok = self.picture(where + ".back", s.get("back"))
        if "front" in s:
            self.picture(where + ".front", s["front"])
        if "anchor" in s and back_ok and s["anchor"] not in self.anchors.get(s["back"], {}):
            self.p.add(where + ".anchor", "names %r, which is not an anchor of %s" % (s["anchor"], s["back"]))
        if s.get("labels", "below") not in ("below", "above"):
            self.p.add(where + ".labels", "must be below or above")
        items = s.get("items")
        if not isinstance(items, list) or not items:
            self.p.add(where + ".items", "must hold at least one item")
            items = []
        for i, it in enumerate(items):
            iw = "%s.items[%d]" % (where, i)
            if not self.p.fields(iw, it, "object.holder.item"):
                continue
            ok = self.picture(iw + ".image", it.get("image"))
            if not is_number(it.get("x")) or not 0 <= it["x"] <= 1:
                self.p.add(iw + ".x", "must be where the item sits, from 0 to 1 across the holder")
            states = self.states(iw + ".states", it.get("states"))
            if "id" in it:
                self.target("%s.%s" % (oid, it["id"]), it.get("image") if ok else None, states)
        self.target(oid, s.get("back") if back_ok else None)

    def obj_card(self, oid, where, s):
        if s.get("frame") not in (None, "browser", "phone"):
            self.p.add(where + ".frame", "must be browser or phone")
        parts = s.get("parts", [])
        if not isinstance(parts, list):
            self.p.add(where + ".parts", "must be a list of parts")
            parts = []
        for i, part in enumerate(parts):
            self.part(oid, "%s.parts[%d]" % (where, i), part)
        self.target(oid)

    def part(self, oid, where, part):
        if not isinstance(part, dict):
            self.p.add(where, "must be an object")
            return
        kind = part.get("type")
        if kind not in PART_TYPES:
            self.p.add(where + ".type", "must be one of %s, not %r" % (", ".join(PART_TYPES), kind))
            return
        self.p.fields(where, part, "part." + kind)
        pic, states = None, set()
        if kind in ("text", "button") and not is_text(part.get("text")):
            self.p.add(where + ".text", "must hold the words of the part")
        if kind == "row":
            for i, q in enumerate(part.get("parts", [])):
                self.part(oid, "%s.parts[%d]" % (where, i), q)
        if kind in ("tags", "checks"):
            for i, it in enumerate(part.get("items", [])):
                itw = "%s.items[%d]" % (where, i)
                if self.p.fields(itw, it, "part.%s.item" % kind):
                    if not is_text(it.get("text")):
                        self.p.add(itw + ".text", "must hold the words of the item")
                    if "id" in it:
                        self.target("%s.%s" % (oid, it["id"]))
        if kind == "slots":
            if not isinstance(part.get("count"), int) or part["count"] < 1:
                self.p.add(where + ".count", "must be a whole number above 0")
            if "image" in part:
                self.picture(where + ".image", part["image"])
        if kind == "image":
            if self.picture(where + ".image", part.get("image")):
                pic = part["image"]
            states = self.states(where + ".states", part.get("states"))
        if "id" in part:
            self.target("%s.%s" % (oid, part["id"]), pic, states)

    def scene(self, i, s, cast_ids, object_ids):
        where = "scenes[%d]" % i
        if not self.p.fields(where, s, "scene"):
            return
        for j, c in enumerate(s.get("cast", [])):
            cw = "%s.cast[%d]" % (where, j)
            cid = c
            if isinstance(c, dict):
                self.p.fields(cw, c, "scene.cast")
                cid = c.get("id")
                if c.get("side", "left") not in ("left", "right"):
                    self.p.add(cw + ".side", "must be left or right")
            if cid not in cast_ids:
                self.p.add(cw, "names %r, who is not in the cast" % (cid,))
        for j, oid in enumerate(s.get("objects", [])):
            if oid not in object_ids:
                self.p.add("%s.objects[%d]" % (where, j), "names %r, which is not an object" % (oid,))
        for j, col in enumerate(s.get("layout", [])):
            for k, oid in enumerate(col if isinstance(col, list) else [col]):
                if oid not in object_ids:
                    self.p.add("%s.layout[%d][%d]" % (where, j, k), "names %r, which is not an object" % (oid,))
        beats = s.get("beats")
        if not isinstance(beats, list) or not beats:
            self.p.add(where + ".beats", "must hold at least one beat")
            return
        for j, b in enumerate(beats):
            self.beat("%s.beats[%d]" % (where, j), b)

    def beat(self, where, b):
        if not isinstance(b, dict):
            self.p.add(where, "must be an object")
            return
        action = b.get("do")
        if action not in ACTIONS:
            self.p.add(where + ".do", "must be one of %s, not %r" % (", ".join(ACTIONS), action))
            return
        allowed = FIELDS["beat"] + ACTIONS[action]
        for key in b:
            if key not in allowed:
                self.p.add("%s.%s" % (where, key), "is not a field of the beat %s" % action)
        if "who" in ACTIONS[action]:
            who = b.get("who")
            for who in who if action in ("enter", "exit") and isinstance(who, list) else [who]:
                if who not in self.cast:
                    self.p.add(where + ".who", "names %r, who is not in the cast" % (who,))
        if action == "say" and not is_text(b.get("text")):
            self.p.add(where + ".text", "must hold the line")
        if "face" in b and b.get("who") in self.cast:
            faces = self.faces.get(self.cast[b["who"]], set())
            if b["face"] not in faces:
                self.p.add(where + ".face", "names %r, which is not a face of %s" % (b["face"], self.cast[b["who"]]))
        if "act" in b and b["act"] not in ACTS + (None,):
            self.p.add(where + ".act", "must be one of %s" % ", ".join(ACTS))
        if "target" in ACTIONS[action]:
            t = b.get("target")
            for t in t if action == "clear" and isinstance(t, list) else [t]:
                if t not in self.targets:
                    self.p.add(where + ".target", "names %r, which is not an object or a part of one" % (t,))
        if action == "swap" and b.get("target") in self.targets and b.get("state") not in self.targets[b["target"]]["states"] | {"base"}:
            self.p.add(where + ".state", "names %r, which is not a state of %s" % (b.get("state"), b["target"]))
        if action == "focus" and "mark" in b and "%s.%s" % (b.get("target"), b["mark"]) not in self.targets:
            self.p.add(where + ".mark", "names %r, which is not a mark of %s" % (b["mark"], b.get("target")))
        if action == "fly":
            if "image" in b:
                self.picture(where + ".image", b["image"])
            elif not is_text(b.get("text")):
                self.p.add(where + ".text", "must hold the words on the slip, or name an image")
            for end in ("from", "to"):
                if b.get(end) not in self.targets and b.get(end) not in self.cast:
                    self.p.add("%s.%s" % (where, end), "names %r, which is neither in the cast nor an object" % (b.get(end),))
            if "land" in b:
                self.fx(where + ".land", b["land"])
        if action == "stamp" and "image" in b:
            self.picture(where + ".image", b["image"])
        if action in ("fill", "count") and not isinstance(b.get("to"), int):
            self.p.add(where + ".to", "must be the whole number to stop at")
        if action == "type" and not is_text(b.get("text")):
            self.p.add(where + ".text", "must hold the words to type")
        if "fx" in b:
            self.fx(where + ".fx", b["fx"])
        if "fxAt" in b and b["fxAt"] not in self.targets:
            self.p.add(where + ".fxAt", "names %r, which is not an object or a part of one" % (b["fxAt"],))

    def fx(self, where, fx):
        if isinstance(fx, str):
            fx = {"word": fx}
        if not self.p.fields(where, fx, "fx"):
            return
        if "word" in fx and fx["word"] not in WORDS:
            self.p.add(where + ".word", "must be one of %s" % ", ".join(WORDS))

    def figure(self, i, f, scenes):
        where = "figures[%d]" % i
        if not isinstance(f, dict):
            self.p.add(where, "must be an object")
            return
        kind = f.get("kind")
        if kind not in FIGURE_KINDS:
            self.p.add(where + ".kind", "must be one of %s" % ", ".join(FIGURE_KINDS))
            return
        self.p.fields(where, f, "figure." + kind)
        for key in ("question", "answer"):
            if not is_text(f.get(key)):
                self.p.add("%s.%s" % (where, key), "must hold one sentence")
        if kind == "still":
            if not isinstance(f.get("scene"), int) or not 0 <= f["scene"] < scenes:
                self.p.add(where + ".scene", "must be the number of a scene, from 0")
            labels = f.get("labels")
            if not isinstance(labels, dict) or not labels:
                self.p.add(where + ".labels", "must name at least one thing on screen with its label")
            else:
                for key in labels:
                    if key not in self.targets and key not in self.cast:
                        self.p.add("%s.labels.%s" % (where, key), "is neither in the cast nor an object")
        if kind in ("flow", "compare"):
            many = "steps" if kind == "flow" else "sides"
            items = f.get(many)
            if not isinstance(items, list) or not (2 <= len(items) <= (6 if kind == "flow" else 2)):
                self.p.add("%s.%s" % (where, many), "must hold %s" % ("two to six steps" if kind == "flow" else "two sides"))
                items = []
            for j, it in enumerate(items):
                iw = "%s.%s[%d]" % (where, many, j)
                if not self.p.fields(iw, it, "figure.%s.%s" % (kind, "step" if kind == "flow" else "side")):
                    continue
                t = self.targets.get(it.get("target"))
                if not t or not t["pic"]:
                    self.p.add(iw + ".target", "names %r, which has no picture to draw" % (it.get("target"),))
                elif "state" in it and it["state"] not in t["states"]:
                    self.p.add(iw + ".state", "names %r, which is not a state of %s" % (it["state"], it["target"]))
        if kind == "table":
            cols, rows = f.get("columns"), f.get("rows")
            if not isinstance(cols, list) or not 1 <= len(cols) <= 5 or not all(is_text(c) for c in cols):
                self.p.add(where + ".columns", "must hold one to five column names")
            elif not isinstance(rows, list) or not 1 <= len(rows) <= 12 or not all(isinstance(r, list) and len(r) == len(cols) for r in rows):
                self.p.add(where + ".rows", "must hold one to twelve rows of %d cells" % len(cols))


def check(theme, script, theme_dir, script_dir):
    """The problems of a theme and a script that uses it, as (field, reason) pairs."""
    p, faces, anchors = check_theme(theme, theme_dir)
    if not p.fields("script", script, "script"):
        return p
    if script.get("lang") not in ("en", "ja"):
        p.add("lang", "must be en or ja")
    if not is_text(script.get("title")):
        p.add("title", "must hold the title of the video")
    pictures = set(theme.get("images", {}) if isinstance(theme.get("images"), dict) else {})
    images = script.get("images", {})
    if not isinstance(images, dict):
        p.add("images", "must map each picture name to its file")
        images = {}
    for name, spec in images.items():
        where = "images.%s" % name
        if name in pictures:
            p.add(where, "is already an image of the theme")
            continue
        if not p.fields(where, spec, "script.images"):
            continue
        full = picture_file(p, where + ".file", script_dir, spec.get("file"))
        if full:
            anchors[name] = side_anchors(p, where, full)
        pictures.add(name)
    s = Script(p, faces, pictures, anchors)
    cast = script.get("cast", {})
    if not isinstance(cast, dict):
        p.add("cast", "must map each id to a cast member")
        cast = {}
    for cid, c in cast.items():
        where = "cast.%s" % cid
        if not p.fields(where, c, "script.cast"):
            continue
        if c.get("character") not in faces:
            p.add(where + ".character", "names %r, which is not a character of the theme" % (c.get("character"),))
            continue
        s.cast[cid] = c["character"]
    objects = script.get("objects", {})
    if not isinstance(objects, dict):
        p.add("objects", "must map each id to an object")
        objects = {}
    for oid, o in objects.items():
        if "." in oid:
            p.add("objects.%s" % oid, "an id holds no dot")
            continue
        s.obj(oid, o)
    scenes = script.get("scenes")
    if not isinstance(scenes, list) or not scenes:
        p.add("scenes", "must hold at least one scene")
        scenes = []
    for i, sc in enumerate(scenes):
        s.scene(i, sc, set(cast), set(objects))
    figures = script.get("figures", [])
    if not isinstance(figures, list) or len(figures) > 8:
        p.add("figures", "must be a list of at most eight figures")
        figures = []
    for i, f in enumerate(figures):
        s.figure(i, f, len(scenes))
    return p


UNSAFE_SVG = [
    (re.compile(r"<script\b", re.I), "runs a script"),
    (re.compile(r"\son[a-z]+\s*=", re.I), "has an event handler"),
    (re.compile(r"<foreignObject\b", re.I), "holds a foreignObject"),
    (re.compile(r"""\b(?:href|xlink:href|src)\s*=\s*["']\s*(?!#)""", re.I), "loads from outside"),
    (re.compile(r"url\(\s*['\"]?\s*(?!#)", re.I), "loads from outside"),
    (re.compile(r"@import", re.I), "loads from outside"),
]


def unsafe_svg(text):
    """Why an SVG drawing cannot go into the page, or None when it is safe."""
    for pattern, why in UNSAFE_SVG:
        if pattern.search(text):
            return why
    return None
