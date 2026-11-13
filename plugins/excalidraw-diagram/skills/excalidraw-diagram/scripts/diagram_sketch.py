"""Hand-drawn strokes and fills for the SVG and PNG of elements whose roughness is above 0.

The Excalidraw editor draws such elements with rough.js: each straight stroke bows a little and
is drawn twice, curves wobble at their control points, and a solid fill is a slightly looser copy
of the outline. This module draws the same kind of strokes and fills. Every random number comes
from the element's seed, so the same file always gives the same picture.
The formulas follow rough.js (MIT License, Copyright (c) 2019 Preet Shihn); see
THIRD_PARTY_NOTICES.md.
"""
import math

FILL_GAIN = 0.8   # a solid fill is drawn this much rougher than its outline


class Pen(object):
    """The rough.js options Excalidraw passes for one element, and the element's random numbers."""

    def __init__(self, seed, roughness, stroke_width, multi=True):
        self.seed = (int(seed) & 0xFFFFFFFF) or 1
        self.roughness = float(roughness)
        self.max_offset = 2.0
        self.bowing = 1.0
        self.curve_fitting = 0.95
        self.multi = multi
        self.hachure_gap = max(0.1, stroke_width * 4)
        self.fill_weight = stroke_width / 2.0

    def random(self):
        # rough.js: Math.imul(48271, seed), keeping 31 bits.
        self.seed = (48271 * self.seed) & 0xFFFFFFFF
        return (self.seed & 0x7FFFFFFF) / 2147483648.0

    def copy(self, roughness=None, multi=None):
        p = Pen(1, self.roughness if roughness is None else roughness, 0, self.multi if multi is None else multi)
        p.seed, p.max_offset, p.bowing, p.curve_fitting = self.seed, self.max_offset, self.bowing, self.curve_fitting
        p.hachure_gap, p.fill_weight = self.hachure_gap, self.fill_weight
        return p


def _off(lo, hi, pen, gain=1.0):
    return pen.roughness * gain * (pen.random() * (hi - lo) + lo)


def _wobble(x, pen, gain=1.0):
    return _off(-x, x, pen, gain)


def _line(x1, y1, x2, y2, pen, move, overlay):
    """One bowed stroke from (x1, y1) to (x2, y2); the ends stay put, as Excalidraw keeps them."""
    length_sq = (x1 - x2) ** 2 + (y1 - y2) ** 2
    length = math.sqrt(length_sq)
    gain = 1.0 if length < 200 else 0.4 if length > 500 else -0.0016668 * length + 1.233334
    offset = pen.max_offset
    if offset * offset * 100 > length_sq:
        offset = length / 10.0
    spread = offset / 2.0 if overlay else offset
    diverge = 0.2 + pen.random() * 0.2
    mx = _wobble(pen.bowing * pen.max_offset * (y2 - y1) / 200.0, pen, gain)
    my = _wobble(pen.bowing * pen.max_offset * (x1 - x2) / 200.0, pen, gain)
    ops = [("M", x1, y1)] if move else []
    ops.append(("C", mx + x1 + (x2 - x1) * diverge + _wobble(spread, pen, gain),
                my + y1 + (y2 - y1) * diverge + _wobble(spread, pen, gain),
                mx + x1 + 2 * (x2 - x1) * diverge + _wobble(spread, pen, gain),
                my + y1 + 2 * (y2 - y1) * diverge + _wobble(spread, pen, gain), x2, y2))
    return ops


def segment(x1, y1, x2, y2, pen):
    """A straight stroke, bowed and drawn twice (once for dashed lines)."""
    ops = _line(x1, y1, x2, y2, pen, True, False)
    if pen.multi:
        ops += _line(x1, y1, x2, y2, pen, True, True)
    return ops


def _bezier(cur, c1, c2, end, pen):
    """A cubic curve whose control points wobble, drawn twice."""
    ops = []
    spreads = (pen.max_offset or 1.0, (pen.max_offset or 1.0) + 0.3)
    for i in range(2 if pen.multi else 1):
        ops.append(("M", cur[0], cur[1]))
        s = spreads[i]
        ops.append(("C", c1[0] + _wobble(s, pen), c1[1] + _wobble(s, pen), c2[0] + _wobble(s, pen),
                    c2[1] + _wobble(s, pen), end[0], end[1]))
    return ops


def _curve(points, pen):
    """A smooth curve through points (Catmull-Rom), as rough.js draws an ellipse."""
    ops = []
    if len(points) <= 3:
        return ops
    ops.append(("M", points[1][0], points[1][1]))
    for i in range(1, len(points) - 2):
        p0, p1, p2, p3 = points[i - 1], points[i], points[i + 1], points[i + 2]
        ops.append(("C", p1[0] + (p2[0] - p0[0]) / 6.0, p1[1] + (p2[1] - p0[1]) / 6.0,
                    p2[0] + (p1[0] - p3[0]) / 6.0, p2[1] + (p1[1] - p3[1]) / 6.0, p2[0], p2[1]))
    return ops


def _merged(ops):
    """One closed outline for a fill: drop every move but the first."""
    return [op for i, op in enumerate(ops) if i == 0 or op[0] != "M"]


def d(ops, fmt):
    out = []
    for op in ops:
        out.append(op[0] + " ".join(fmt(v) for v in op[1:]))
    return "".join(out)


# ------------------------------------------------------------------ shapes

def polyline(points, pen, closed=False):
    ops = []
    for (x1, y1), (x2, y2) in zip(points, points[1:]):
        ops += segment(x1, y1, x2, y2, pen)
    if closed and len(points) > 2:
        ops += segment(points[-1][0], points[-1][1], points[0][0], points[0][1], pen)
    return ops


def _rounded_ops(x, y, w, h, r, pen):
    """The path Excalidraw builds for a rounded rectangle: four sides and four quadratic corners."""
    def quad(cur, cp, end):
        c1 = (cur[0] + 2.0 / 3 * (cp[0] - cur[0]), cur[1] + 2.0 / 3 * (cp[1] - cur[1]))
        c2 = (end[0] + 2.0 / 3 * (cp[0] - end[0]), end[1] + 2.0 / 3 * (cp[1] - end[1]))
        return _bezier(cur, c1, c2, end, pen)
    ops = []
    ops += segment(x + r, y, x + w - r, y, pen)
    ops += quad((x + w - r, y), (x + w, y), (x + w, y + r))
    ops += segment(x + w, y + r, x + w, y + h - r, pen)
    ops += quad((x + w, y + h - r), (x + w, y + h), (x + w - r, y + h))
    ops += segment(x + w - r, y + h, x + r, y + h, pen)
    ops += quad((x + r, y + h), (x, y + h), (x, y + h - r))
    ops += segment(x, y + h - r, x, y + r, pen)
    ops += quad((x, y + r), (x, y), (x + r, y))
    return ops


def rectangle(x, y, w, h, r, pen):
    """(fill ops, outline ops) for a rectangle with corner radius r (0 for square corners)."""
    if r > 0:
        outline = _rounded_ops(x, y, w, h, r, pen)
        fill = _merged(_rounded_ops(x, y, w, h, r, pen.copy(pen.roughness + FILL_GAIN, False)))
        return fill, outline, _rounded_points(x, y, w, h, r)
    pts = [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]
    fill, outline = polygon(pts, pen)
    return fill, outline, pts


def _rounded_points(x, y, w, h, r, steps=4):
    pts = []
    for cx, cy, a0 in ((x + w - r, y + r, -90), (x + w - r, y + h - r, 0), (x + r, y + h - r, 90), (x + r, y + r, 180)):
        for k in range(steps + 1):
            a = math.radians(a0 + 90.0 * k / steps)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def polygon(points, pen):
    """(fill ops, outline ops) for a closed polygon."""
    outline = polyline(points, pen, True)
    o = pen.max_offset
    fill = [("M", points[0][0] + _wobble(o, pen), points[0][1] + _wobble(o, pen))]
    fill += [("L", px + _wobble(o, pen), py + _wobble(o, pen)) for px, py in points[1:]]
    fill.append(("Z",))
    return fill, outline


def ellipse(cx, cy, w, h, pen):
    """(fill ops, outline ops, outline points) for an ellipse, as rough.js draws it."""
    pen.curve_fitting = 1.0
    psq = math.sqrt(math.pi * 2 * math.sqrt(((w / 2.0) ** 2 + (h / 2.0) ** 2) / 2))
    steps = int(math.ceil(max(9, 9 / math.sqrt(200) * psq)))
    inc = math.pi * 2 / steps
    rx, ry = abs(w / 2.0), abs(h / 2.0)

    def points(offset, overlap):
        rad = _wobble(0.5, pen) - math.pi / 2
        pts = [(_wobble(offset, pen) + cx + 0.9 * rx * math.cos(rad - inc),
                _wobble(offset, pen) + cy + 0.9 * ry * math.sin(rad - inc))]
        a, end = rad, math.pi * 2 + rad - 0.01
        while a < end:
            pts.append((_wobble(offset, pen) + cx + rx * math.cos(a), _wobble(offset, pen) + cy + ry * math.sin(a)))
            a += inc
        for k, f in ((0.5, 1.0), (1.0, 0.98), (0.5, 0.9)):
            ang = rad + (math.pi * 2 if f == 1.0 else 0) + overlap * k
            pts.append((_wobble(offset, pen) + cx + f * rx * math.cos(ang), _wobble(offset, pen) + cy + f * ry * math.sin(ang)))
        return pts

    first = points(1, inc * _off(0.1, _off(0.4, 1, pen), pen))
    ops = _curve(first, pen)
    if pen.multi:
        ops += _curve(points(1.5, 0), pen)
    outline = [(cx + rx * math.cos(2 * math.pi * k / 24), cy + ry * math.sin(2 * math.pi * k / 24)) for k in range(24)]
    return ops, ops, outline


def hachure(poly, pen, angle=-41):
    """Hatching lines that fill a polygon, each a rough stroke, as rough.js fills with "hachure"."""
    gap = max(1, round(pen.hachure_gap))
    a = math.radians(angle + 90)
    cos_a, sin_a = math.cos(a), math.sin(a)
    rot = [(px * cos_a + py * sin_a, -px * sin_a + py * cos_a) for px, py in poly]
    ys = [p[1] for p in rot]
    ops = []
    y = min(ys) + gap
    fill_pen = pen.copy(multi=False)
    while y < max(ys):
        xs = []
        for (x1, y1), (x2, y2) in zip(rot, rot[1:] + rot[:1]):
            if (y1 <= y < y2) or (y2 <= y < y1):
                xs.append(x1 + (y - y1) * (x2 - x1) / (y2 - y1))
        xs.sort()
        for xa, xb in zip(xs[0::2], xs[1::2]):
            pa = (xa * cos_a - y * sin_a, xa * sin_a + y * cos_a)
            pb = (xb * cos_a - y * sin_a, xb * sin_a + y * cos_a)
            ops += segment(pa[0], pa[1], pb[0], pb[1], fill_pen)
        y += gap
    return ops
