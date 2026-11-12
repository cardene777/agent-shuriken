"""Plane geometry shared by the layout and the checks.

Rectangles are (left, top, right, bottom). Shapes become convex polygons: a rectangle
by its corners, a diamond by its four tips, and an ellipse by 32 points on its outline.
"""
import math

SHAPES = ("rectangle", "ellipse", "diamond")


def bbox(e):
    x, y = float(e.get("x", 0)), float(e.get("y", 0))
    w, h = float(e.get("width", 0)), float(e.get("height", 0))
    return (min(x, x + w), min(y, y + h), max(x, x + w), max(y, y + h))


def inflate(r, d):
    return (r[0] - d, r[1] - d, r[2] + d, r[3] + d)


def rects_overlap(a, b):
    """True when the rectangles share area (touching edges do not count)."""
    return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


def rect_gap(a, b):
    """Distance between two rectangles along the axis that separates them, negative if they overlap."""
    return max(b[0] - a[2], a[0] - b[2], b[1] - a[3], a[1] - b[3])


def contains(outer, inner, margin=0.0):
    return (inner[0] >= outer[0] + margin and inner[1] >= outer[1] + margin
            and inner[2] <= outer[2] - margin and inner[3] <= outer[3] - margin)


def _rotate(points, cx, cy, angle):
    if not angle:
        return points
    c, s = math.cos(angle), math.sin(angle)
    return [(cx + (px - cx) * c - (py - cy) * s, cy + (px - cx) * s + (py - cy) * c) for px, py in points]


def polygon(e):
    l, t, r, b = bbox(e)
    cx, cy = (l + r) / 2, (t + b) / 2
    kind = e.get("type")
    if kind == "diamond":
        pts = [(cx, t), (r, cy), (cx, b), (l, cy)]
    elif kind == "ellipse":
        rx, ry = (r - l) / 2, (b - t) / 2
        pts = [(cx + rx * math.cos(2 * math.pi * i / 32), cy + ry * math.sin(2 * math.pi * i / 32))
               for i in range(32)]
    else:
        pts = [(l, t), (r, t), (r, b), (l, b)]
    return _rotate(pts, cx, cy, float(e.get("angle") or 0))


def shrink(poly, d):
    cx = sum(p[0] for p in poly) / len(poly)
    cy = sum(p[1] for p in poly) / len(poly)
    out = []
    for px, py in poly:
        dx, dy = cx - px, cy - py
        n = math.hypot(dx, dy) or 1.0
        out.append((px + dx / n * d, py + dy / n * d))
    return out


def _cross(o, a, b):
    return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])


def inside(p, poly):
    """True when p is inside the convex polygon or on its outline."""
    sign = 0
    n = len(poly)
    for i in range(n):
        c = _cross(poly[i], poly[(i + 1) % n], p)
        if abs(c) < 1e-9:
            continue
        s = 1 if c > 0 else -1
        if sign and s != sign:
            return False
        sign = s
    return True


def _on_segment(p, q, r):
    return min(p[0], q[0]) - 1e-9 <= r[0] <= max(p[0], q[0]) + 1e-9 and \
        min(p[1], q[1]) - 1e-9 <= r[1] <= max(p[1], q[1]) + 1e-9


def segments_meet(p1, p2, q1, q2):
    d1, d2 = _cross(q1, q2, p1), _cross(q1, q2, p2)
    d3, d4 = _cross(p1, p2, q1), _cross(p1, p2, q2)
    if ((d1 > 0 > d2) or (d1 < 0 < d2)) and ((d3 > 0 > d4) or (d3 < 0 < d4)):
        return True
    if abs(d1) < 1e-9 and _on_segment(q1, q2, p1):
        return True
    if abs(d2) < 1e-9 and _on_segment(q1, q2, p2):
        return True
    if abs(d3) < 1e-9 and _on_segment(p1, p2, q1):
        return True
    if abs(d4) < 1e-9 and _on_segment(p1, p2, q2):
        return True
    return False


def segment_enters(p, q, poly):
    """True when the segment p-q passes through the inside of the convex polygon.

    The polygon is first pulled 1 px inward, so a segment that only touches the outline
    does not count.
    """
    small = shrink(poly, 1.0)
    if inside(p, small) or inside(q, small):
        return True
    n = len(small)
    return any(segments_meet(p, q, small[i], small[(i + 1) % n]) for i in range(n))


def rect_polygon(r):
    return [(r[0], r[1]), (r[2], r[1]), (r[2], r[3]), (r[0], r[3])]


def segment_hits_rect(p, q, r):
    return segment_enters(p, q, rect_polygon(r))


def rect_meets_polygon(r, poly):
    """True when the rectangle and the convex polygon share any point."""
    rp = rect_polygon(r)
    if any(inside(p, poly) for p in rp) or any(inside(p, rp) for p in poly):
        return True
    n = len(poly)
    return any(segments_meet(a, b, poly[i], poly[(i + 1) % n])
               for a, b in zip(rp, rp[1:] + rp[:1]) for i in range(n))


def rect_inside_polygon(r, poly, margin):
    """True when the rectangle lies inside the convex polygon and at least margin from its outline.

    The distance is measured to every edge, so the margin is the same on every side; pulling
    the corners toward the middle would leave much less on the long sides of a wide shape.
    """
    n = len(poly)
    for p in rect_polygon(r):
        if not inside(p, poly):
            return False
        if min(_dist_point_segment(p, poly[i], poly[(i + 1) % n]) for i in range(n)) < margin - 1e-9:
            return False
    return True


def _dist_point_segment(p, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    n = dx * dx + dy * dy
    t = 0.0 if n == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / n))
    return math.hypot(p[0] - (a[0] + t * dx), p[1] - (a[1] + t * dy))


def distance_to_segment(p, a, b):
    return _dist_point_segment(p, a, b)


def distance_to(p, poly):
    """0 when p is inside the polygon, otherwise the distance to its outline."""
    if inside(p, poly):
        return 0.0
    n = len(poly)
    return min(_dist_point_segment(p, poly[i], poly[(i + 1) % n]) for i in range(n))


def linear_points(e):
    x, y = float(e.get("x", 0)), float(e.get("y", 0))
    return [(x + float(p[0]), y + float(p[1])) for p in e.get("points") or []]


def segments(points):
    return list(zip(points, points[1:]))
