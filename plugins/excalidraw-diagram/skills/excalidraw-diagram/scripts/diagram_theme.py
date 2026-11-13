"""The themes a spec can pick with "theme", read from themes.json.

A theme sets how lines are drawn (roughness and width), which font the text uses, how shapes
and zones are filled, and whether the picture is shown on a dark background. Every setting the
layout and the SVG need comes from that one file; this module only reads and checks it.
"""
import json
import os

PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "themes.json")
VERSION = 1
FONTS = {"excalifont": 5, "nunito": 6, "helvetica": 2}   # Excalidraw's fontFamily numbers
CHOICES = {
    "roughness": (0, 1, 2),
    "font": tuple(FONTS),
    "fill": ("solid", "hachure", "none"),
    "tint": ("medium", "light"),
    "zone_fill": ("light", "none"),
    "outline": ("color", "ink"),
    "shape_stroke": (1, 2, 4),
    "line_stroke": (1, 2, 4),
    "dark": (False, True),
}
_cache = {}


class ThemeError(Exception):
    """themes.json is missing or does not follow its format."""


def _load():
    if "data" in _cache:
        return _cache["data"]
    try:
        with open(PATH, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError) as e:
        raise ThemeError("themes.json cannot be read: %s" % e)
    if not isinstance(data, dict) or data.get("version") != VERSION:
        raise ThemeError("themes.json: version must be %d" % VERSION)
    themes = data.get("themes")
    if not isinstance(themes, dict) or not themes:
        raise ThemeError("themes.json: themes must be an object of named themes")
    for name, t in themes.items():
        if not isinstance(t, dict):
            raise ThemeError("themes.json: theme %s must be an object" % name)
        for key, options in CHOICES.items():
            if t.get(key) not in options or isinstance(t.get(key), bool) != isinstance(options[0], bool):
                raise ThemeError("themes.json: theme %s: %s must be one of %s"
                                 % (name, key, ", ".join(str(o) for o in options)))
        color = t.get("line_color")
        if not (isinstance(color, str) and len(color) == 7 and color[0] == "#"):
            raise ThemeError("themes.json: theme %s: line_color must be a color like #495057" % name)
    if data.get("default") not in themes:
        raise ThemeError("themes.json: default must name one of the themes")
    _cache["data"] = data
    return data


def names():
    """Theme names in the order the file lists them."""
    return list(_load()["themes"])


def default():
    return _load()["default"]


def settings(spec):
    """The settings for a validated spec: its theme, with "style" and "fill" applied on top."""
    t = dict(_load()["themes"][spec["theme"]])
    if spec.get("style") == "clean":
        t["roughness"], t["font"] = 0, "helvetica"
    elif spec.get("style") == "sketch":
        t["roughness"] = max(1, t["roughness"])
        if t["font"] == "helvetica":
            t["font"] = "excalifont"
    if spec.get("fill"):
        t["fill"] = spec["fill"]
    t["family"] = FONTS[t["font"]]
    return t
