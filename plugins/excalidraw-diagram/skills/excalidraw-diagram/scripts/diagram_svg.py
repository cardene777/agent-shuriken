"""Draw an Excalidraw scene as SVG, the way the Excalidraw editor draws it.

Elements whose roughness is above 0 are drawn by hand, as the editor draws them: strokes bow a
little and are drawn twice, and fills and hatching are as loose (diagram_sketch.py). Elements
with roughness 0 get clean outlines. Text in Excalifont or Nunito embeds those fonts
(diagram_fonts.py); other text uses the fonts on the viewer's machine. A scene whose appState
theme is "dark" is shown the way Excalidraw's dark mode shows it, with the colors inverted.
Rectangles, ellipses, diamonds, text, arrows, and lines are drawn; other element types are left
out and counted. The first line of text bound to a shape (a node's name) is drawn bold, or
thickened with a thin outline in a font with no bold face, so it stands out from the detail
lines under it.

Every SVG carries a comment with a digest of the rest of the file, so a later run can
tell whether the file is still exactly as this plugin wrote it.
"""
import hashlib
import math
import re

import diagram_fonts as fonts
import diagram_geometry as geo
import diagram_sketch as sketch
import diagram_text as measure

PAD = 24
MARK = "<!-- excalidraw-diagram sha256:"
SANS = ("'Helvetica Neue', Helvetica, Arial, 'Hiragino Sans', 'Noto Sans CJK JP', 'Noto Sans', "
        "'Yu Gothic', 'Segoe UI', sans-serif")
MONO = "Menlo, Consolas, 'DejaVu Sans Mono', monospace"
_COLOR = re.compile(r"^(#[0-9a-fA-F]{3,8}|[a-zA-Z]{3,20})$")
DRAWN = geo.SHAPES + ("text", "arrow", "line")
DARK = "filter:invert(93%) hue-rotate(180deg)"   # what Excalidraw's dark mode does to the canvas


def _esc(s):
    s = "".join(c for c in s if c in "\n\t" or ord(c) >= 32)
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")


def _color(v, default):
    return v if isinstance(v, str) and _COLOR.match(v) else default


def _n(v):
    return ("%.2f" % v).rstrip("0").rstrip(".")


def _num(v, default=0.0):
    return float(v) if isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v) else default


class _Defs(object):
    def __init__(self):
        self.items, self.ids = [], {}

    def hatch(self, color, cross):
        key = (color, cross)
        if key not in self.ids:
            pid = "hatch%d" % len(self.ids)
            self.ids[key] = pid
            lines = '<path d="M0 4H8" stroke="%s" stroke-width="1.5"/>' % color
            if cross:
                lines += '<path d="M4 0V8" stroke="%s" stroke-width="1.5"/>' % color
            self.items.append('<pattern id="%s" width="8" height="8" patternUnits="userSpaceOnUse" '
                              'patternTransform="rotate(-45)">%s</pattern>' % (pid, lines))
        return "url(#%s)" % self.ids[key]


def _paint(e, defs, fill=True):
    stroke = _color(e.get("strokeColor"), "#1e1e1e")
    sw = _num(e.get("strokeWidth"), 2.0)
    attrs = ['stroke="%s"' % stroke, 'stroke-width="%s"' % _n(sw)]
    style = e.get("strokeStyle")
    if style == "dashed":
        attrs.append('stroke-dasharray="8 %s"' % _n(8 + sw))
    elif style == "dotted":
        attrs.append('stroke-dasharray="1.5 %s" stroke-linecap="round"' % _n(6 + sw))
    bg = _color(e.get("backgroundColor"), "transparent")
    if not fill or bg == "transparent":
        attrs.append('fill="none"')
    elif e.get("fillStyle") in ("hachure", "cross-hatch", "zigzag"):
        attrs.append('fill="%s"' % defs.hatch(bg, e.get("fillStyle") == "cross-hatch"))
    else:
        attrs.append('fill="%s"' % bg)
    op = _num(e.get("opacity"), 100.0)
    if op < 100:
        attrs.append('opacity="%s"' % _n(max(0.0, op) / 100))
    return " ".join(attrs)


def _rotation(e, cx, cy):
    a = _num(e.get("angle"))
    return ' transform="rotate(%s %s %s)"' % (_n(math.degrees(a)), _n(cx), _n(cy)) if a else ""


def _radius(e, w, h):
    r = e.get("roundness")
    if not isinstance(r, dict):
        return 0.0
    m = min(w, h)
    if r.get("type") == 3:
        # Excalidraw's adaptive radius: a quarter of the shorter side, at most its value (32 by default).
        fixed = _num(r.get("value"), 32.0) or 32.0
        return 0.25 * m if m <= fixed / 0.25 else fixed
    return 0.25 * m


def _arrowhead(kind, tip, prev, sw, stroke):
    dx, dy = tip[0] - prev[0], tip[1] - prev[1]
    n = math.hypot(dx, dy)
    if n == 0:
        return ""
    ux, uy = dx / n, dy / n
    size = min(10 + 2 * sw, n * 0.75 + 4)
    if kind in ("dot", "circle", "circle_outline"):
        fill = stroke if kind != "circle_outline" else "none"
        return '<circle cx="%s" cy="%s" r="%s" fill="%s" stroke="%s" stroke-width="%s"/>' % (
            _n(tip[0] - ux * 4), _n(tip[1] - uy * 4), _n(2 + sw), fill, stroke, _n(sw))
    if kind == "bar":
        return '<path d="M%s %sL%s %s" stroke="%s" stroke-width="%s" stroke-linecap="round"/>' % (
            _n(tip[0] - uy * size / 2), _n(tip[1] + ux * size / 2), _n(tip[0] + uy * size / 2),
            _n(tip[1] - ux * size / 2), stroke, _n(sw))
    a = math.radians(25)
    w1 = (tip[0] - size * (ux * math.cos(a) - uy * math.sin(a)), tip[1] - size * (uy * math.cos(a) + ux * math.sin(a)))
    w2 = (tip[0] - size * (ux * math.cos(a) + uy * math.sin(a)), tip[1] - size * (uy * math.cos(a) - ux * math.sin(a)))
    if kind in ("triangle", "triangle_outline", "diamond", "diamond_outline"):
        fill = "none" if kind.endswith("_outline") else stroke
        return '<path d="M%s %sL%s %sL%s %sZ" fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round"/>' % (
            _n(w1[0]), _n(w1[1]), _n(tip[0]), _n(tip[1]), _n(w2[0]), _n(w2[1]), fill, stroke, _n(sw))
    return ('<path d="M%s %sL%s %sL%s %s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" '
            'stroke-linejoin="round"/>') % (_n(w1[0]), _n(w1[1]), _n(tip[0]), _n(tip[1]), _n(w2[0]), _n(w2[1]), stroke, _n(sw))


def _text(e, background, label_on_line, bold_first):
    size = _num(e.get("fontSize"), 20.0)
    family = e.get("fontFamily")
    lh = _num(e.get("lineHeight"), measure.line_height(family)) * size
    lines = (e.get("text") or "").split("\n")
    x, y = _num(e.get("x")), _num(e.get("y"))
    w = _num(e.get("width")) or measure.text_size(e.get("text") or "", size, family)[0]
    h = _num(e.get("height")) or lh * len(lines)
    align = e.get("textAlign")
    anchor, tx = ("middle", x + w / 2) if align == "center" else ("end", x + w) if align == "right" else ("start", x)
    embedded = fonts.family_name(family)
    font = MONO if family in measure.MONO_FAMILIES else ("'%s', " % embedded + SANS) if embedded else SANS
    color = _color(e.get("strokeColor"), "#1e1e1e")
    out = []
    if label_on_line:
        out.append('<rect x="%s" y="%s" width="%s" height="%s" fill="%s"/>' % (
            _n(x - 4), _n(y - 2), _n(w + 8), _n(h + 4), background))
    top = y + (h - lh * len(lines)) / 2
    for i, line in enumerate(lines):
        base = top + lh * i + lh / 2 + size * 0.35
        weight = ""
        if bold_first and i == 0:
            # Excalifont and the bundled Nunito have no bold face: a thin outline in the text's own color thickens it.
            weight = (' stroke="%s" stroke-width="0.7" stroke-linejoin="round"' % color) if embedded \
                else ' font-weight="bold"'
        out.append('<text x="%s" y="%s" font-family="%s" font-size="%s"%s fill="%s" text-anchor="%s" '
                   'style="white-space:pre">%s</text>' % (_n(tx), _n(base), font, _n(size), weight, color, anchor, _esc(line)))
    return "".join(out)


def _bounds(e):
    kind = e.get("type")
    if kind in ("arrow", "line"):
        pts = geo.linear_points(e)
        if not pts:
            return None
        xs, ys = [p[0] for p in pts], [p[1] for p in pts]
        return (min(xs) - 12, min(ys) - 12, max(xs) + 12, max(ys) + 12)
    if kind in geo.SHAPES:
        poly = geo.polygon(e)
        xs, ys = [p[0] for p in poly], [p[1] for p in poly]
        return (min(xs), min(ys), max(xs), max(ys))
    return geo.bbox(e)


def render(doc):
    """Return (svg text with its digest comment, width, height, sorted list of element types left out)."""
    elements = [e for e in doc.get("elements") or [] if isinstance(e, dict) and not e.get("isDeleted")]
    by_id = {e.get("id"): e for e in elements}
    background = _color((doc.get("appState") or {}).get("viewBackgroundColor"), "#ffffff")
    drawn = [e for e in elements if e.get("type") in DRAWN]
    skipped = sorted({str(e.get("type")) for e in elements if e.get("type") not in DRAWN})
    boxes = [b for b in (_bounds(e) for e in drawn) if b]
    if boxes:
        l, t = min(b[0] for b in boxes) - PAD, min(b[1] for b in boxes) - PAD
        r, b = max(b[2] for b in boxes) + PAD, max(b[3] for b in boxes) + PAD
    else:
        l, t, r, b = 0, 0, 2 * PAD, 2 * PAD
    l, t = math.floor(l), math.floor(t)
    width, height = int(math.ceil(r - l)), int(math.ceil(b - t))
    defs = _Defs()
    body = []
    for e in drawn:
        kind = e.get("type")
        x, y = _num(e.get("x")), _num(e.get("y"))
        w, h = _num(e.get("width")), _num(e.get("height"))
        if kind in geo.SHAPES and _num(e.get("roughness")) > 0:
            body.append("<g%s>%s</g>" % (_rotation(e, x + w / 2, y + h / 2), _rough_shape(e, kind, x, y, w, h)))
        elif kind == "rectangle":
            rx = _radius(e, w, h)
            body.append('<rect x="%s" y="%s" width="%s" height="%s" rx="%s" %s%s/>' % (
                _n(x), _n(y), _n(w), _n(h), _n(rx), _paint(e, defs), _rotation(e, x + w / 2, y + h / 2)))
        elif kind == "ellipse":
            body.append('<ellipse cx="%s" cy="%s" rx="%s" ry="%s" %s%s/>' % (
                _n(x + w / 2), _n(y + h / 2), _n(w / 2), _n(h / 2), _paint(e, defs), _rotation(e, x + w / 2, y + h / 2)))
        elif kind == "diamond":
            pts = [(x + w / 2, y), (x + w, y + h / 2), (x + w / 2, y + h), (x, y + h / 2)]
            body.append('<polygon points="%s" stroke-linejoin="round" %s%s/>' % (
                " ".join("%s,%s" % (_n(px), _n(py)) for px, py in pts), _paint(e, defs), _rotation(e, x + w / 2, y + h / 2)))
        elif kind == "text":
            container = by_id.get(e.get("containerId"))
            on_line = container is not None and container.get("type") in ("arrow", "line")
            in_shape = container is not None and container.get("type") in geo.SHAPES
            body.append("<g%s>%s</g>" % (_rotation(e, x + w / 2, y + h / 2), _text(e, background, on_line, in_shape)))
        else:
            pts = geo.linear_points(e)
            if len(pts) < 2:
                continue
            closed = kind == "line" and e.get("polygon") is True
            xs, ys = [p[0] for p in pts], [p[1] for p in pts]
            rot = _rotation(e, (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2)
            if _num(e.get("roughness")) > 0:
                body.append("<g%s>%s</g>" % (rot, _rough_linear(e, kind, pts)))
                continue
            tag = "polygon" if closed else "polyline"
            parts = ['<%s points="%s" stroke-linecap="round" stroke-linejoin="round" %s/>' % (
                tag, " ".join("%s,%s" % (_n(px), _n(py)) for px, py in pts), _paint(e, defs, fill=closed))]
            if kind == "arrow":
                stroke = _color(e.get("strokeColor"), "#1e1e1e")
                sw = _num(e.get("strokeWidth"), 2.0)
                if e.get("endArrowhead"):
                    parts.append(_arrowhead(e["endArrowhead"], pts[-1], pts[-2], sw, stroke))
                if e.get("startArrowhead"):
                    parts.append(_arrowhead(e["startArrowhead"], pts[0], pts[1], sw, stroke))
            body.append("<g%s>%s</g>" % (rot, "".join(parts)))
    dark = (doc.get("appState") or {}).get("theme") == "dark"
    head = '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="%d %d %d %d"%s>' % (
        width, height, l, t, width, height, ' style="%s"' % DARK if dark else "")
    parts = [head]
    faces, _ = fonts.faces((e.get("fontFamily"), e.get("text") or "") for e in drawn if e.get("type") == "text")
    if defs.items or faces:
        parts.append("<defs>%s%s</defs>" % ("<style>%s</style>" % faces if faces else "", "".join(defs.items)))
    parts.append('<rect x="%d" y="%d" width="%d" height="%d" fill="%s"/>' % (l, t, width, height, background))
    parts.extend(body)
    parts.append("</svg>")
    return add_marker("\n".join(parts) + "\n"), width, height, skipped


# ------------------------------------------------------------------ hand-drawn elements

def _stroke(e):
    """Stroke attributes of a hand-drawn outline. Dashed and dotted strokes are drawn once and
    0.5 px wider, as Excalidraw draws them."""
    stroke = _color(e.get("strokeColor"), "#1e1e1e")
    sw = _num(e.get("strokeWidth"), 2.0)
    style = e.get("strokeStyle")
    if style in ("dashed", "dotted"):
        sw += 0.5
    attrs = ['fill="none"', 'stroke="%s"' % stroke, 'stroke-width="%s"' % _n(sw),
             'stroke-linecap="round"', 'stroke-linejoin="round"']
    if style == "dashed":
        attrs.append('stroke-dasharray="8 %s"' % _n(8 + sw))
    elif style == "dotted":
        attrs.append('stroke-dasharray="1.5 %s"' % _n(6 + sw))
    op = _num(e.get("opacity"), 100.0)
    if op < 100:
        attrs.append('opacity="%s"' % _n(max(0.0, op) / 100))
    return " ".join(attrs)


def _pen(e, salt=0):
    return sketch.Pen(int(_num(e.get("seed"), 1)) + salt, _num(e.get("roughness")), _num(e.get("strokeWidth"), 2.0),
                      multi=e.get("strokeStyle") in (None, "solid"))


def _rough_shape(e, kind, x, y, w, h):
    pen = _pen(e)
    if kind == "rectangle":
        fill, outline, poly = sketch.rectangle(x, y, w, h, _radius(e, w, h), pen)
    elif kind == "ellipse":
        fill, outline, poly = sketch.ellipse(x + w / 2, y + h / 2, w, h, pen)
    else:
        poly = [(x + w / 2, y), (x + w, y + h / 2), (x + w / 2, y + h), (x, y + h / 2)]
        fill, outline = sketch.polygon(poly, pen)
    parts = []
    bg = _color(e.get("backgroundColor"), "transparent")
    op = _num(e.get("opacity"), 100.0)
    alpha = ' opacity="%s"' % _n(max(0.0, op) / 100) if op < 100 else ""
    if bg != "transparent":
        if e.get("fillStyle") in ("hachure", "cross-hatch", "zigzag"):
            hp = _pen(e, 1)
            ops = sketch.hachure(poly, hp)
            if e.get("fillStyle") == "cross-hatch":
                ops += sketch.hachure(poly, hp, 49)
            parts.append('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round"%s/>' % (
                sketch.d(ops, _n), bg, _n(hp.fill_weight), alpha))
        else:
            parts.append('<path d="%s" fill="%s" stroke="none"%s/>' % (sketch.d(fill, _n), bg, alpha))
    parts.append('<path d="%s" %s/>' % (sketch.d(outline, _n), _stroke(e)))
    return "".join(parts)


def _rough_head(kind, tip, prev, e, salt):
    stroke = _color(e.get("strokeColor"), "#1e1e1e")
    sw = _num(e.get("strokeWidth"), 2.0)
    if kind not in ("arrow", "triangle"):
        return _arrowhead(kind, tip, prev, sw, stroke)
    dx, dy = tip[0] - prev[0], tip[1] - prev[1]
    n = math.hypot(dx, dy)
    if n == 0:
        return ""
    ux, uy = dx / n, dy / n
    size = min(10 + 2 * sw, n * 0.75 + 4)
    a = math.radians(25)
    w1 = (tip[0] - size * (ux * math.cos(a) - uy * math.sin(a)), tip[1] - size * (uy * math.cos(a) + ux * math.sin(a)))
    w2 = (tip[0] - size * (ux * math.cos(a) + uy * math.sin(a)), tip[1] - size * (uy * math.cos(a) - ux * math.sin(a)))
    pen = sketch.Pen(int(_num(e.get("seed"), 1)) + salt, _num(e.get("roughness")), sw)
    if kind == "arrow":
        ops = sketch.polyline([w1, tip], pen) + sketch.polyline([w2, tip], pen)
        return '<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round"/>' % (
            sketch.d(ops, _n), stroke, _n(sw))
    fill, outline = sketch.polygon([w1, tip, w2], pen)
    return ('<path d="%s" fill="%s" stroke="none"/><path d="%s" fill="none" stroke="%s" stroke-width="%s" '
            'stroke-linecap="round" stroke-linejoin="round"/>') % (
        sketch.d(fill, _n), stroke, sketch.d(outline, _n), stroke, _n(sw))


def _rough_linear(e, kind, pts):
    closed = kind == "line" and e.get("polygon") is True
    parts = ['<path d="%s" %s/>' % (sketch.d(sketch.polyline(pts, _pen(e), closed), _n), _stroke(e))]
    if kind == "arrow":
        if e.get("endArrowhead"):
            parts.append(_rough_head(e["endArrowhead"], pts[-1], pts[-2], e, 2))
        if e.get("startArrowhead"):
            parts.append(_rough_head(e["startArrowhead"], pts[0], pts[1], e, 3))
    return "".join(parts)


def _digest(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def add_marker(text):
    first, rest = text.split("\n", 1)
    return "%s\n%s%s -->\n%s" % (first, MARK, _digest(text), rest)


def marker_ok(text):
    """True when the SVG still has this plugin's digest of its own content."""
    lines = text.split("\n")
    if len(lines) < 2 or not lines[1].startswith(MARK) or not lines[1].endswith(" -->"):
        return False
    digest = lines[1][len(MARK):-4]
    return digest == _digest("\n".join(lines[:1] + lines[2:]))
