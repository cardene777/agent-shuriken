"""Check an Excalidraw scene against the layout and quality rules.

`check(doc)` returns a Report. Problems are rule breaks that must be fixed; warnings are
flaws worth a look that some diagrams cannot avoid, such as arrows that cross; notes are
advice. Only problems fail the check. The rules work on any `.excalidraw` file, not only
on files this plugin wrote, so a scene edited in the Excalidraw editor can be checked again.
"""
import math
import unicodedata

import diagram_geometry as geo
import diagram_text as measure

MIN_FONT = 16          # smallest readable text, in px
MIN_GAP = 40           # space between shapes that are not nested
ZONE_PAD = 50          # space between a background zone and the shapes inside it
END_MIN = 4            # an arrow end stays at least this far from a shape
BIND_MAX = 30          # a bound end is at most this far from its shape; an unbound end this close should be bound
TEXT_PAD = 5           # Excalidraw keeps bound text this far inside its shape
TEXT_MARGIN = 4        # free text stays this far from outlines it does not sit inside
ZONE_TEXT_MARGIN = 8   # and this far from a zone's outline, inside or outside, so it does not read as sitting on it
CENTER_TOL = 2.0       # how far bound text may sit from the middle of its shape
TOUCH = 3              # arrows closer than this seem to touch
LINEAR = ("arrow", "line")
CHECKED = geo.SHAPES + ("text",) + LINEAR
NOT_DRAWN = ("image", "freedraw", "frame", "magicframe", "embeddable", "iframe")


class Report(object):
    def __init__(self):
        self.problems = []
        self.warnings = []
        self.notes = []
        self.counts = {"shapes": 0, "arrows": 0, "lines": 0, "texts": 0}

    def fail(self, rule, message):
        self.problems.append((rule, message))

    def warn(self, rule, message):
        self.warnings.append((rule, message))

    def note(self, message):
        self.notes.append(message)

    def summary(self):
        c = self.counts
        return "Checked %d shapes, %d arrows, %d lines, and %d texts." % (
            c["shapes"], c["arrows"], c["lines"], c["texts"])


def _first_line(s, limit=32):
    line = (s or "").split("\n")[0].strip()
    return line if len(line) <= limit else line[:limit - 3] + "..."


def _num(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v)


class Scene(object):
    """Live elements by id, with names a person can recognise."""

    def __init__(self, elements):
        self.all = [e for e in elements if isinstance(e, dict) and not e.get("isDeleted")]
        self.by_id = {}
        for e in self.all:
            if isinstance(e.get("id"), str):
                self.by_id.setdefault(e["id"], e)
        self.shapes_in_group = {}
        for e in self.all:
            if e.get("type") in geo.SHAPES:
                for g in e.get("groupIds") or []:
                    self.shapes_in_group[g] = self.shapes_in_group.get(g, 0) + 1

    def own_label(self, shape):
        """Free text grouped with this shape alone and lying inside it, such as a zone's label."""
        groups = [g for g in shape.get("groupIds") or [] if self.shapes_in_group.get(g) == 1]
        if not groups:
            return None
        box = geo.bbox(shape)
        for t in self.all:
            if (t.get("type") == "text" and not t.get("containerId") and set(groups) & set(t.get("groupIds") or [])
                    and _num(t.get("x")) and _num(t.get("y")) and geo.contains(box, _text_box(t))):
                return t
        return None

    def bound_text(self, shape):
        for b in shape.get("boundElements") or []:
            if isinstance(b, dict) and b.get("type") == "text":
                t = self.by_id.get(b.get("id"))
                if t is not None and t.get("type") == "text":
                    return t
        return None

    def name(self, e):
        if e is None:
            return "a missing element"
        kind = e.get("type")
        if kind == "text":
            return 'text "%s"' % _first_line(e.get("text"))
        if kind in LINEAR:
            ends = []
            for key in ("startBinding", "endBinding"):
                b = e.get(key)
                target = self.by_id.get(b.get("elementId")) if isinstance(b, dict) else None
                ends.append(self.name(target) if target is not None else "?")
            if ends != ["?", "?"]:
                return "the %s from %s to %s" % (kind, ends[0], ends[1])
            return "%s %s" % (kind, e.get("id"))
        t = self.bound_text(e)
        if t is not None and (t.get("text") or "").strip():
            return '"%s"' % _first_line(t.get("text"))
        t = self.own_label(e)
        if t is not None and (t.get("text") or "").strip():
            return 'the zone "%s"' % _first_line(t.get("text"))
        return "%s %s" % (kind, e.get("id"))


def _check_format(doc, scene, report):
    seen = set()
    for i, e in enumerate(doc.get("elements") or []):
        where = "element %d" % i
        if not isinstance(e, dict):
            report.fail("format", "%s is not an object" % where)
            continue
        eid, kind = e.get("id"), e.get("type")
        if not isinstance(eid, str) or not eid:
            report.fail("format", "%s has no id" % where)
            continue
        if eid in seen:
            report.fail("format", "id %s is used by more than one element" % eid)
        seen.add(eid)
        if e.get("isDeleted") or kind not in CHECKED:
            continue
        for key in ("x", "y", "width", "height"):
            if not _num(e.get(key)):
                report.fail("format", "%s (%s) needs a number in %s" % (eid, kind, key))
        if kind == "text":
            if not isinstance(e.get("text"), str):
                report.fail("format", "text %s has no text" % eid)
            if not _num(e.get("fontSize")) or e.get("fontSize") <= 0:
                report.fail("format", "text %s needs a positive fontSize" % eid)
        if kind in LINEAR:
            pts = e.get("points")
            if not isinstance(pts, list) or len(pts) < 2 or not all(
                    isinstance(p, (list, tuple)) and len(p) == 2 and _num(p[0]) and _num(p[1]) for p in pts):
                report.fail("format", "%s %s needs at least two [x, y] points" % (kind, eid))


def _check_references(scene, report):
    for e in scene.all:
        eid = e.get("id")
        cid = e.get("containerId") if e.get("type") == "text" else None
        if cid is not None:
            c = scene.by_id.get(cid)
            if c is None:
                report.fail("reference", 'text %s names container %s, which does not exist' % (eid, cid))
            elif not any(isinstance(b, dict) and b.get("id") == eid for b in c.get("boundElements") or []):
                report.fail("reference", "%s does not list its text %s in boundElements" % (scene.name(c), eid))
        for b in e.get("boundElements") or []:
            if not isinstance(b, dict):
                report.fail("reference", "%s has a malformed boundElements entry" % scene.name(e))
                continue
            other = scene.by_id.get(b.get("id"))
            if other is None:
                report.fail("reference", "%s lists %s in boundElements, which does not exist" % (scene.name(e), b.get("id")))
            elif b.get("type") == "text" and other.get("containerId") != eid:
                report.fail("reference", "%s lists text %s, whose containerId is not %s" % (scene.name(e), b.get("id"), eid))
            elif b.get("type") == "arrow" and eid not in [
                    (other.get(k) or {}).get("elementId") for k in ("startBinding", "endBinding")
                    if isinstance(other.get(k), dict)]:
                report.fail("reference", "%s lists %s, which is not bound to it" % (scene.name(e), scene.name(other)))
        if e.get("type") in LINEAR:
            for key in ("startBinding", "endBinding"):
                b = e.get(key)
                if b is None:
                    continue
                target = scene.by_id.get(b.get("elementId")) if isinstance(b, dict) else None
                if target is None:
                    report.fail("reference", "%s of %s %s points at an element that does not exist" % (key, e.get("type"), eid))
                elif not any(isinstance(x, dict) and x.get("id") == eid for x in target.get("boundElements") or []):
                    report.fail("reference", "%s does not list %s in boundElements" % (scene.name(target), scene.name(e)))


def _max_text_box(c):
    w, h = float(c.get("width", 0)), float(c.get("height", 0))
    if c.get("type") == "ellipse":
        return w / math.sqrt(2) - 2 * TEXT_PAD, h / math.sqrt(2) - 2 * TEXT_PAD
    if c.get("type") == "diamond":
        return w / 2 - 2 * TEXT_PAD, h / 2 - 2 * TEXT_PAD
    return w - 2 * TEXT_PAD, h - 2 * TEXT_PAD


def _text_extent(t):
    """The stored size, or an estimate when the file leaves it out."""
    w, h = float(t.get("width") or 0), float(t.get("height") or 0)
    if w <= 0 or h <= 0:
        w, h = measure.text_size(t.get("text") or "", float(t.get("fontSize") or 20), t.get("fontFamily"))
    return w, h


def _text_box(t):
    w, h = _text_extent(t)
    x, y = float(t.get("x", 0)), float(t.get("y", 0))
    return (x, y, x + w, y + h)


def _check_shapes(scene, shapes, report):
    boxes = {s["id"]: geo.bbox(s) for s in shapes}
    zones = set()
    for a in shapes:
        for b in shapes:
            if a is not b and geo.contains(boxes[a["id"]], boxes[b["id"]]) and boxes[a["id"]] != boxes[b["id"]]:
                zones.add(a["id"])
    for i, a in enumerate(shapes):
        for b in shapes[i + 1:]:
            ra, rb = boxes[a["id"]], boxes[b["id"]]
            shared = set(a.get("groupIds") or []) & set(b.get("groupIds") or [])
            outer, inner = (a, b) if geo.contains(ra, rb) else (b, a) if geo.contains(rb, ra) else (None, None)
            if outer is not None:
                ro, ri = boxes[outer["id"]], boxes[inner["id"]]
                pad = min(ri[0] - ro[0], ri[1] - ro[1], ro[2] - ri[2], ro[3] - ri[3])
                if pad < ZONE_PAD and not shared:
                    report.fail("zone-padding", "%s sits %d px inside %s; keep at least %d px between a zone and the shapes in it"
                                % (scene.name(inner), pad, scene.name(outer), ZONE_PAD))
            elif geo.rects_overlap(ra, rb):
                report.fail("overlap", "%s and %s overlap" % (scene.name(a), scene.name(b)))
            elif not shared:
                gap = geo.rect_gap(ra, rb)
                if gap < MIN_GAP:
                    report.fail("spacing", "%s and %s are %d px apart; keep at least %d px between shapes"
                                % (scene.name(a), scene.name(b), gap, MIN_GAP))
    return zones


def _check_texts(scene, shapes, zones, lines, report):
    texts = [e for e in scene.all if e.get("type") == "text"]
    for t in texts:
        size = t.get("fontSize")
        if _num(size) and size < MIN_FONT:
            report.fail("font-size", "%s is %gpx; use at least %d px" % (scene.name(t), size, MIN_FONT))
    for t in texts:
        c = scene.by_id.get(t.get("containerId")) if t.get("containerId") else None
        if c is not None and c.get("type") in geo.SHAPES:
            w, h = _text_extent(t)
            mw, mh = _max_text_box(c)
            if w > mw + 1 or h > mh + 1:
                report.fail("text-fit", "%s does not fit in its %s: it needs %dx%d px, the shape holds %dx%d px; make the shape larger or the text shorter"
                            % (scene.name(t), c.get("type"), math.ceil(w), math.ceil(h), max(0, int(mw)), max(0, int(mh))))
            cb, tb = geo.bbox(c), _text_box(t)
            if t.get("verticalAlign", "middle") == "middle" and abs((tb[1] + tb[3]) / 2 - (cb[1] + cb[3]) / 2) > CENTER_TOL:
                report.fail("text-center", "%s is not centered vertically in %s" % (scene.name(t), scene.name(c)))
            if t.get("textAlign", "center") == "center" and abs((tb[0] + tb[2]) / 2 - (cb[0] + cb[2]) / 2) > CENTER_TOL:
                report.fail("text-center", "%s is not centered horizontally in %s" % (scene.name(t), scene.name(c)))
            continue
        # Free text, or a label bound to an arrow.
        tb = _text_box(t)
        for s in shapes:
            margin = ZONE_TEXT_MARGIN if s["id"] in zones else TEXT_MARGIN
            poly = geo.polygon(s)
            if not geo.rect_meets_polygon(geo.inflate(tb, margin), poly):
                continue
            if geo.rect_inside_polygon(tb, poly, margin):
                continue
            if s["id"] in zones:
                report.fail("text-overlap", "%s sits on the outline of %s; keep text at least %d px from a zone's outline"
                            % (scene.name(t), scene.name(s), ZONE_TEXT_MARGIN))
            else:
                report.fail("text-overlap", "%s crosses the outline of %s" % (scene.name(t), scene.name(s)))
        for ln in lines:
            if c is not None and ln is c:
                continue
            pts = geo.linear_points(ln)
            if any(geo.segment_hits_rect(p, q, geo.inflate(tb, 2)) for p, q in geo.segments(pts)):
                report.fail("label-on-line", "%s is crossed by %s; move the label off the line" % (scene.name(t), scene.name(ln)))
    for i, a in enumerate(texts):
        for b in texts[i + 1:]:
            if geo.rects_overlap(geo.inflate(_text_box(a), 1), _text_box(b)):
                report.fail("text-overlap", "%s and %s overlap" % (scene.name(a), scene.name(b)))


def _check_lines(scene, shapes, zones, lines, report):
    solid = [s for s in shapes if s["id"] not in zones]
    polys = {s["id"]: geo.polygon(s) for s in shapes}
    for ln in lines:
        pts = geo.linear_points(ln)
        if len(pts) < 2:
            continue
        if len(pts) > 2 and ln.get("roundness") and not ln.get("elbowed"):
            report.fail("curve", "%s has %d points and a roundness, so Excalidraw draws it as a curve; set roundness to null"
                        % (scene.name(ln), len(pts)))
        for s in solid:
            if any(geo.segment_enters(p, q, polys[s["id"]]) for p, q in geo.segments(pts)):
                report.fail("arrow-through", "%s passes through %s" % (scene.name(ln), scene.name(s)))
        if ln.get("type") != "arrow":
            continue
        for key, point in (("startBinding", pts[0]), ("endBinding", pts[-1])):
            end = "start" if key == "startBinding" else "end"
            b = ln.get(key)
            target = scene.by_id.get(b.get("elementId")) if isinstance(b, dict) else None
            if target is not None and target.get("type") in geo.SHAPES:
                d = geo.distance_to(point, polys[target["id"]])
                if d < END_MIN:
                    report.fail("arrow-end", "the %s of %s is %d px from %s; keep its ends %d to %d px outside the shape"
                                % (end, scene.name(ln), d, scene.name(target), END_MIN, BIND_MAX))
                elif d > BIND_MAX:
                    report.fail("arrow-end", "the %s of %s is bound to %s but ends %d px away" % (end, scene.name(ln), scene.name(target), d))
                continue
            for s in solid:
                d = geo.distance_to(point, polys[s["id"]])
                if d == 0:
                    report.fail("arrow-end", "the %s of %s is inside %s" % (end, scene.name(ln), scene.name(s)))
                elif d <= BIND_MAX:
                    report.fail("unbound", "the %s of %s is %d px from %s but not bound to it, so it will not follow when %s moves"
                                % (end, scene.name(ln), d, scene.name(s), scene.name(s)))
    runs = []
    for ln in lines:
        for p, q in geo.segments(geo.linear_points(ln)):
            if abs(p[1] - q[1]) < 0.5:
                runs.append((ln, "h", p[1], min(p[0], q[0]), max(p[0], q[0]), (p, q)))
            elif abs(p[0] - q[0]) < 0.5:
                runs.append((ln, "v", p[0], min(p[1], q[1]), max(p[1], q[1]), (p, q)))
    reported = set()
    for i, a in enumerate(runs):
        for b in runs[i + 1:]:
            if a[0] is b[0] or a[1] != b[1] or abs(a[2] - b[2]) >= 1:
                continue
            trunk = _trunk(a[0], b[0])[0]
            if a[5] in trunk and b[5] in trunk:
                continue
            if min(a[4], b[4]) - max(a[3], b[3]) > 2:
                pair = (a[0]["id"], b[0]["id"])
                if pair not in reported:
                    reported.add(pair)
                    report.fail("arrow-overlap", "%s and %s run along the same stretch of line" % (scene.name(a[0]), scene.name(b[0])))


def _meeting(p1, p2, q1, q2):
    """The point where two segments meet, or None.

    Crossing, touching at a corner, and one ending on the other all count. Segments that
    run along each other give the middle of the stretch they share.
    """
    dx1, dy1 = p2[0] - p1[0], p2[1] - p1[1]
    dx2, dy2 = q2[0] - q1[0], q2[1] - q1[1]
    den = dx1 * dy2 - dy1 * dx2
    ox, oy = q1[0] - p1[0], q1[1] - p1[1]
    if abs(den) < 1e-9:
        length = math.hypot(dx1, dy1)
        if abs(ox * dy1 - oy * dx1) / length > 0.5:
            return None
        k = 0 if abs(dx1) >= abs(dy1) else 1
        lo = max(min(p1[k], p2[k]), min(q1[k], q2[k]))
        hi = min(max(p1[k], p2[k]), max(q1[k], q2[k]))
        if lo > hi + 1e-9:
            return None
        t = ((lo + hi) / 2.0 - p1[k]) / (dx1 if k == 0 else dy1)
        return (p1[0] + t * dx1, p1[1] + t * dy1)
    t = (ox * dy2 - oy * dx2) / den
    u = (ox * dy1 - oy * dx1) / den
    if -1e-9 <= t <= 1 + 1e-9 and -1e-9 <= u <= 1 + 1e-9:
        return (p1[0] + t * dx1, p1[1] + t * dy1)
    # An end that stops just short of the other segment reads as touching it.
    for end, a, b in ((p1, q1, q2), (p2, q1, q2), (q1, p1, p2), (q2, p1, p2)):
        if geo.distance_to_segment(end, a, b) < TOUCH:
            return end
    return None


def _trunk(a, b):
    """Where two arrows share a trunk: both leave one shape from one point, run together on one
    line, and split. Returns (their segments along the trunk, the point where they split), or
    ([], None) when they do not, including when one runs along the other to its end."""
    pa, pb = geo.linear_points(a), geo.linear_points(b)
    start_a, start_b = a.get("startBinding") or {}, b.get("startBinding") or {}
    if len(pa) < 2 or len(pb) < 2 or pa[0] != pb[0] or not start_a.get("elementId") \
            or start_a.get("elementId") != start_b.get("elementId"):
        return [], None
    k = 0
    while k + 1 < min(len(pa), len(pb)) and pa[k + 1] == pb[k + 1]:
        k += 1
    if k + 1 >= len(pa) or k + 1 >= len(pb):
        return [], None
    segs = list(zip(pa[:k + 1], pa[1:k + 1])) + [(pa[k], pa[k + 1]), (pb[k], pb[k + 1])]
    o, na, nb = pa[k], pa[k + 1], pb[k + 1]
    da, db = (na[0] - o[0], na[1] - o[1]), (nb[0] - o[0], nb[1] - o[1])
    same_way = da[0] * db[1] == da[1] * db[0] and da[0] * db[0] + da[1] * db[1] > 0
    # Leaving the last shared point the same way, the shorter one turns off the other's line there.
    split = min((na, nb), key=lambda q: abs(q[0] - o[0]) + abs(q[1] - o[1])) if same_way else o
    return segs, split


def _check_crossings(scene, lines, report):
    """Warn about every pair of arrows that cross or touch, with how many points they meet at.
    Two arrows of one trunk meet along it and where they split; that is not a crossing."""
    arrows = []
    for ln in lines:
        if ln.get("type") == "arrow":
            arrows.append((ln, [(p, q) for p, q in geo.segments(geo.linear_points(ln)) if p != q]))
    for i, (a, sa) in enumerate(arrows):
        for b, sb in arrows[i + 1:]:
            points = set()
            segs, split = _trunk(a, b)
            trunk = set(segs)
            for p, q in sa:
                for r, s in sb:
                    if (p, q) in trunk and (r, s) in trunk:
                        continue
                    m = _meeting(p, q, r, s)
                    if m is not None and not (split and abs(m[0] - split[0]) <= 1 and abs(m[1] - split[1]) <= 1):
                        points.add((round(m[0]), round(m[1])))
            n = len(points)
            if n:
                report.warn("crossing", "%s crosses %s %s" % (
                    scene.name(a), scene.name(b), "once" if n == 1 else "%d times" % n))


def _is_emoji(ch):
    o = ord(ch)
    return 0x1F300 <= o <= 0x1FAFF or 0x2600 <= o <= 0x27BF or unicodedata.category(ch) == "So"


def _notes(scene, shapes, zones, report):
    name_only, roomy = [], []
    for s in shapes:
        if s["id"] in zones or s.get("type") != "rectangle":
            continue
        t = scene.bound_text(s)
        if t is None:
            continue
        if len((t.get("text") or "").strip().split("\n")) == 1 and not set(s.get("groupIds") or []):
            name_only.append(scene.name(s))
        w, h = _text_extent(t)
        if float(s.get("width", 0)) > w + 160 and float(s.get("height", 0)) > h + 100:
            roomy.append(scene.name(s))
    if name_only:
        report.note("%d boxes hold one line of text (%s). Add fields, protocols, or ports where they help the reader"
                    % (len(name_only), ", ".join(name_only[:6]) + (", ..." if len(name_only) > 6 else "")))
    if roomy:
        report.note("%s have much more room than their text; smaller shapes read better" % ", ".join(roomy[:6]))
    emoji = [scene.name(t) for t in scene.all if t.get("type") == "text" and any(_is_emoji(c) for c in t.get("text") or "")]
    if emoji:
        report.note("%s contain emoji, which look different in every viewer; use words such as [OK] and [NG]" % ", ".join(emoji[:6]))
    skipped = sorted({e.get("type") for e in scene.all if e.get("type") in NOT_DRAWN})
    if skipped:
        report.note("elements of type %s were not checked" % ", ".join(str(k) for k in skipped))


def check(doc):
    report = Report()
    scene = Scene(doc.get("elements") or [])
    _check_format(doc, scene, report)
    if report.problems:
        return report
    _check_references(scene, report)
    shapes = [e for e in scene.all if e.get("type") in geo.SHAPES]
    lines = [e for e in scene.all if e.get("type") in LINEAR]
    report.counts = {
        "shapes": len(shapes),
        "arrows": sum(1 for e in lines if e.get("type") == "arrow"),
        "lines": sum(1 for e in lines if e.get("type") == "line"),
        "texts": sum(1 for e in scene.all if e.get("type") == "text"),
    }
    zones = _check_shapes(scene, shapes, report)
    _check_texts(scene, shapes, zones, lines, report)
    _check_lines(scene, shapes, zones, lines, report)
    _check_crossings(scene, lines, report)
    _notes(scene, shapes, zones, report)
    return report
