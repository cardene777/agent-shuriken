#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = [
#   "Pillow==13.0.0",
# ]
# ///
"""Builds one offline HTML page with an explainer video from a theme folder and a script.

Usage:
  build.py <theme-dir> <script.json> <out.html>

The theme folder holds theme.json (colors, font, characters and their faces, pictures) and the
pictures it names. The script names its cast, its objects, its scenes of beats, its figures, and the
pictures it brings itself, as paths from its own folder. references/theme.md and
references/script.md describe every field.

The pictures are cut to what is visible, shrunk to what the video shows, and inlined, so the page
loads nothing from the network. The page holds the engine, the effects core of Sakuga VFX, the theme,
and the script; the engine lays out each scene and plays it in the browser.

Pillow cuts the pictures, and uv fetches it for one run (scripts/with_pillow.py), so the first thing
the script does is start again through uv.

Exit codes:
  0  wrote the page
  1  refused the theme or the script; each problem is printed as `<field>: <reason>`, nothing is written
  2  called wrongly
  3  uv is missing; nothing is written
"""

import base64
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SKILL = os.path.dirname(HERE)
sys.path.insert(0, HERE)

import schema  # noqa: E402
import with_pillow  # noqa: E402

USAGE = "usage: build.py <theme-dir> <script.json> <out.html>"


def refuse(problems):
    for field, reason in problems:
        print("motion-explainer: %s: %s" % (field, reason), file=sys.stderr)
    sys.exit(1)


def load_json(path, name):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except OSError as e:
        refuse([(name, "cannot be read: %s" % e.strerror)])
    except ValueError as e:
        refuse([(name, "is not JSON: %s" % e)])


class Pictures:
    """Every picture of the video as a data URI, with the shape the engine lays out by."""

    def __init__(self, pixelated):
        from PIL import Image
        self.Image = Image
        self.pixelated = pixelated
        self.images, self.aspect, self.vbox, self.anchors = {}, {}, {}, {}

    def visible_box(self, im):
        return im.getchannel("A").point(lambda a: 255 if a > 12 else 0).getbbox() or (0, 0, im.width, im.height)

    def uri(self, im, quality=90, jpeg=False, lossless=False):
        buf = io.BytesIO()
        if jpeg:
            im.convert("RGB").save(buf, "JPEG", quality=86, optimize=True)
            return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()
        if lossless:
            im.save(buf, "WEBP", lossless=True, quality=100, method=6)
        else:
            im.save(buf, "WEBP", quality=quality, method=6)
        return "data:image/webp;base64," + base64.b64encode(buf.getvalue()).decode()

    def svg(self, name, path, field):
        text = open(path, encoding="utf-8").read()
        why = schema.unsafe_svg(text)
        if why:
            refuse([(field, "%s %s" % (os.path.basename(path), why))])
        m = re.search(r'viewBox\s*=\s*["\']\s*[-\d.]+[\s,]+[-\d.]+[\s,]+([\d.]+)[\s,]+([\d.]+)', text)
        if m and float(m.group(1)) > 0:
            self.aspect[name] = round(float(m.group(2)) / float(m.group(1)), 4)
        self.images[name] = "data:image/svg+xml;base64," + base64.b64encode(text.encode("utf-8")).decode()

    def add(self, name, spec, folder, field, px, quality, groups, pixel=False):
        path = os.path.join(folder, spec["file"])
        if path.lower().endswith(".svg"):
            self.svg(name, path, field)
            return
        im = self.Image.open(path).convert("RGBA")
        if spec.get("jpeg"):
            self.aspect[name] = round(im.height / im.width, 4)
            self.images[name] = self.uri(im, jpeg=True)
            return
        box = (0, 0, im.width, im.height)
        if spec.get("group"):
            box = groups[spec["group"]]
        elif spec.get("crop", True):
            box = self.visible_box(im)
        im = im.crop(box)
        self.aspect[name] = round(im.height / im.width, 4)
        v = self.visible_box(im)
        self.vbox[name] = [round(v[0] / im.width, 4), round(v[1] / im.height, 4), round(v[2] / im.width, 4), round(v[3] / im.height, 4)]
        marks = schema.side_anchors(schema.Problems(), field, path)
        if marks:
            self.anchors[name] = {k: [round((x - box[0]) / im.width, 4), round((y - box[1]) / im.height, 4)] for k, (x, y) in marks.items()}
        size = spec.get("px", px)
        if not pixel:
            im.thumbnail((size, size), self.Image.Resampling.LANCZOS)
        self.images[name] = self.uri(im, spec.get("quality", quality), lossless=pixel)

    def groups(self, images, folder):
        """Layers of one thing (the back and the front of a folder) are cut by one box, so they stay in register."""
        out = {}
        for spec in images.values():
            if spec.get("group") and not spec["file"].lower().endswith(".svg"):
                b = self.visible_box(self.Image.open(os.path.join(folder, spec["file"])).convert("RGBA"))
                g = out.get(spec["group"])
                out[spec["group"]] = b if not g else (min(g[0], b[0]), min(g[1], b[1]), max(g[2], b[2]), max(g[3], b[3]))
        return out

    def characters(self, theme, folder):
        """Every face of one character is cut by the same box, so faces swap without a jump, and every
        character keeps the scale it was drawn at, so the cast stands at one size."""
        chars = {}
        scale = theme.get("characterScale", 1)
        for cid, ch in theme["characters"].items():
            ims = {f: self.Image.open(os.path.join(folder, path)).convert("RGBA") for f, path in ch["faces"].items()}
            boxes = [self.visible_box(im) for im in ims.values()]
            box = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
            width = (box[2] - box[0]) * scale * ch.get("scale", 1)
            faces = {}
            for f, im in ims.items():
                cut = im.crop(box)
                if not self.pixelated:
                    cut.thumbnail((int(width * 1.7), int(width * 1.7 * cut.height / cut.width) + 1), self.Image.Resampling.LANCZOS)
                key = "%s:%s" % (cid, f)
                self.images[key] = self.uri(cut, lossless=self.pixelated)
                faces[f] = key
            chars[cid] = {"default": ch.get("default", next(iter(ch["faces"]))), "faces": faces, "width": round(width),
                          "aspect": round((box[3] - box[1]) / (box[2] - box[0]), 4), "head": ch.get("head", 1)}
        return chars


def html_text(s):
    return str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")


def script_json(value):
    """JSON that can stand inside a <script> element."""
    return json.dumps(value, ensure_ascii=False).replace("</", "<\\/")


def main(argv):
    if len(argv) != 3:
        print(USAGE, file=sys.stderr)
        return 2
    theme_dir, script_path, out_path = argv
    if not os.path.isdir(theme_dir):
        refuse([("theme", "%s is not a folder" % theme_dir)])
    theme = load_json(os.path.join(theme_dir, "theme.json"), "theme.json")
    script = load_json(script_path, os.path.basename(script_path))
    script_dir = os.path.dirname(os.path.abspath(script_path))
    problems = schema.check(theme, script, theme_dir, script_dir)
    if problems:
        refuse(problems)

    pics = Pictures(bool(theme.get("pixelated")))
    images = theme.get("images", {})
    groups = pics.groups(images, theme_dir)
    for name, spec in images.items():
        pics.add(name, spec, theme_dir, "theme.images.%s.file" % name, 200, 90, groups, pics.pixelated)
    characters = pics.characters(theme, theme_dir)
    own = script.get("images", {})
    own_groups = pics.groups(own, script_dir)
    for name, spec in own.items():
        pics.add(name, spec, script_dir, "images.%s.file" % name, 1600, 82, own_groups)

    built = {k: v for k, v in theme.items() if k not in ("images", "characters")}
    built.update(images=pics.images, aspect=pics.aspect, vbox=pics.vbox, anchors=pics.anchors, characters=characters)
    play = {k: v for k, v in script.items() if k != "images"}

    ui = json.load(open(os.path.join(SKILL, "templates", "ui.json"), encoding="utf-8"))
    words = ui[script["lang"]]
    page = open(os.path.join(SKILL, "templates", "page.html"), encoding="utf-8").read()
    fill = {
        "lang": script["lang"],
        "title": html_text(script["title"]),
        "lead": html_text(script.get("lead", "")),
        "engine_css": open(os.path.join(SKILL, "engine", "engine.css"), encoding="utf-8").read(),
        "fx_core": open(os.path.join(SKILL, "vendor", "sakuga-vfx", "core.js"), encoding="utf-8").read(),
        "theme": script_json(built),
        "script": script_json(play),
        "ui": script_json(words),
        "engine_js": open(os.path.join(SKILL, "engine", "engine.js"), encoding="utf-8").read(),
    }
    for key, value in words.items():
        fill["ui_" + key] = html_text(value)
    page = re.sub(r"\{\{(\w+)\}\}", lambda m: fill[m.group(1)], page)
    folder = os.path.dirname(os.path.abspath(out_path))
    os.makedirs(folder, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(page)
    print("motion-explainer: built %s (%d KB)" % (out_path, len(page.encode("utf-8")) // 1024))
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print(USAGE, file=sys.stderr)
        sys.exit(2)
    with_pillow.ensure(__file__)
    sys.exit(main(sys.argv[1:]))
