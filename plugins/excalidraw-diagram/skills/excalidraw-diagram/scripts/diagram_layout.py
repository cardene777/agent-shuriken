"""Lay out a validated spec as Excalidraw elements.

Graph diagrams:

1. Every node is sized from its text, so its text fits with 20 px to spare on each side.
2. Nodes are put in tiers (rows going down, or columns going right). A node's tier is
   the one the spec gives, or one more than the deepest node with an edge into it.
   Each tier is centered on the same line, and spacing is computed from widths and gaps,
   never guessed. Nodes in a tier are reordered to cut crossings (barycenter sweeps that
   keep the spec's order on ties and unless crossings drop), or keep the spec's order
   exactly with "order": "listed".
3. A group is laid out the same way inside its own zone, and the zone then takes part
   in the outer layout as one item, so zones never overlap each other or other nodes.
4. Arrows leave and enter shapes at right angles, 12 px outside the outline, and are
   routed along horizontal and vertical lines that keep 10 px away from every shape
   (a shortest-path search that pays extra for bends, for sharing a line, and for
   crossing or nearly touching an arrow routed before).
5. Each label is placed beside one straight stretch of its arrow, where it touches no
   shape outline, no other text, and no line, and keeps clear of zone outlines.

When something does not fit, the caller tries again with 1.5 and 2.25 times the spacing.
Sequence diagrams put participants in a row with dashed lifelines and one message per row.
"""
import bisect
import heapq
import math

import diagram_check as rules
import diagram_geometry as geo
import diagram_scene as scene
import diagram_text as measure
from diagram_spec import PALETTE

FONT = 16
TITLE_FONT = 28
SQRT2 = math.sqrt(2)
ARROW_GAP = 12        # arrow ends stop this far outside a shape
CLEAR = 10            # arrows keep this far from shapes they pass
LABEL_OFFSET = 8      # a label sits this far beside its line
ZONE_LABEL_CLEAR = 10  # an arrow label keeps this far from a zone's dashed outline, inside or outside
ZONE_PAD = rules.ZONE_PAD
TITLE_GAP = 40
BEND = 40
BORDER_COST = 1.25
OVERLAP_BASE, OVERLAP_PER = 400, 4
ZONE_EDGE_COST = 3      # per px of running along a zone's dashed outline
MEET_COST = 150         # per point where a route crosses or touches an arrow routed before it
NEAR = 8                # a route passing this close to another arrow's end seems to touch it
MIDDLE_PULL = 0.0005    # per px of length and px off the middle: prefer bends halfway between the ends
LOOP_W, LOOP_H = 40, 30
SCALES = (1.0, 1.5, 2.25)
INK = scene.INK
LIFELINE = "#868e96"

NORMAL = {"top": (0, -1), "bottom": (0, 1), "left": (-1, 0), "right": (1, 0)}
# Directions of travel: 0 right, 1 left, 2 down, 3 up.
STEP = {0: (1, 0), 1: (-1, 0), 2: (0, 1), 3: (0, -1)}
OPPOSITE = {0: 1, 1: 0, 2: 3, 3: 2}
OUTWARD = {"right": 0, "left": 1, "bottom": 2, "top": 3}
INWARD = {"right": 1, "left": 0, "bottom": 3, "top": 2}
KIND = {"box": "rectangle", "table": "rectangle", "ellipse": "ellipse", "diamond": "diamond"}


class PlacementError(Exception):
    """The layout ran out of room. More spacing may help."""


def _snap(v, step=10):
    return int(math.ceil(v / float(step) - 1e-9)) * step


def _style(spec):
    sketch = spec["style"] == "sketch"
    family = measure.FAMILY_HAND if sketch else measure.FAMILY_SANS
    return {"family": family, "lh": measure.line_height(family), "rough": 1 if sketch else 0,
            "fill": "hachure" if spec["fill"] == "hachure" else "solid"}


def _r(v):
    return round(v, 2)


# ------------------------------------------------------------------ sizes and tiers

def _size_node(n, family):
    shape, label, lines = n["shape"], n["label"], n["lines"]
    out = {"id": n["id"], "shape": shape, "kind": KIND[shape], "color": n["color"],
           "group": n["group"], "tier": n["tier"], "label": label, "lines": lines}
    # Shapes are sized for the first line drawn bold (as the SVG and PNG draw it); the text
    # element keeps the regular size, which is what the Excalidraw editor shows.
    if shape == "table":
        hw, hh = measure.text_size(label, FONT, family)
        rw = measure.room_for(label, FONT, family)[0]
        body = "\n".join(lines)
        bw, bh = measure.text_size(body, FONT, family) if lines else (0.0, 0.0)
        out["w"] = max(160, _snap(max(rw, bw + 12) + 40))
        out["head_h"] = max(50, _snap(hh + 24))
        out["h"] = out["head_h"] + (_snap(bh + 28) if lines else 0)
        out["head_text"], out["body_text"] = (hw, hh), (bw, bh)
        return out
    content = label + ("\n" + "\n".join(lines) if lines else "")
    tw, th = measure.text_size(content, FONT, family)
    rw = measure.room_for(content, FONT, family)[0]
    if shape == "ellipse":
        w, h = max(140, _snap((rw + 24) * SQRT2)), max(60, _snap((th + 20) * SQRT2))
    elif shape == "diamond":
        w, h = max(140, _snap(2 * (rw + 24))), max(80, _snap(2 * (th + 16)))
    else:
        w, h = max(160, _snap(rw + 40)), max(60, _snap(th + 40))
    out.update({"w": w, "h": h, "content": content, "text": (tw, th)})
    return out


def _tiers(keys, pairs, fixed):
    """Tier of each key: its fixed tier, or one more than its deepest predecessor.

    Edges that close a cycle (found by a depth-first walk in spec order) are ignored, so
    the first node of a loop stays on top.
    """
    succ = {k: [] for k in keys}
    for a, b in pairs:
        if a != b and b not in succ[a]:
            succ[a].append(b)
    state, post, back = {}, [], set()

    def visit(u):
        state[u] = 1
        for v in succ[u]:
            if state.get(v) == 1:
                back.add((u, v))
            elif v not in state:
                visit(v)
        state[u] = 2
        post.append(u)

    for k in keys:
        if k not in state:
            visit(k)
    tier = {}
    for k in reversed(post):
        if k in fixed:
            tier[k] = fixed[k]
            continue
        preds = [a for a in keys if k in succ[a] and (a, k) not in back]
        tier[k] = max([tier[a] + 1 for a in preds if a in tier] or [0])
    levels = {t: i for i, t in enumerate(sorted(set(tier.values())))}
    return {k: levels[tier[k]] for k in keys}


def _starts(row, cross, gap):
    """Where each item of one centered tier starts along the cross axis."""
    c = -(sum(cross(k) for k in row) + gap * (len(row) - 1)) / 2.0
    out = {}
    for k in row:
        out[k] = c
        c += cross(k) + gap
    return out


def _order_rows(rows, tiers, links, ends, cross, gap):
    """Reorder the items in each tier so fewer links between neighboring tiers cross.

    Barycenter sweeps: going down, each item moves to the average position of what it links
    to in the tier above (going up, the tier below), measured at the linked point, which for
    a zone is the node inside it. Items without such links keep their place, and equal
    positions keep the listed order. A new order is kept only when it has strictly fewer
    crossings than the best one so far, starting from the listed order.
    """
    pairs = []      # (upper item, offset of the link along it, lower item, offset)
    for i, (a, b, _) in enumerate(links):
        if a == b or abs(tiers[a] - tiers[b]) != 1:
            continue
        oa, ob = ends[i] if ends is not None else (None, None)
        oa = cross(a) / 2.0 if oa is None else oa
        ob = cross(b) / 2.0 if ob is None else ob
        pairs.append((a, oa, b, ob) if tiers[a] < tiers[b] else (b, ob, a, oa))
    if not pairs:
        return rows
    rank = {k: i for row in rows.values() for i, k in enumerate(row)}

    def starts(rws):
        out = {}
        for row in rws.values():
            out.update(_starts(row, cross, gap))
        return out

    def crossings(rws):
        at = starts(rws)
        by_tier = {}
        for u, ou, l, ol in pairs:
            by_tier.setdefault(tiers[u], []).append((at[u] + ou, at[l] + ol))
        n = 0
        for es in by_tier.values():
            for i, e in enumerate(es):
                n += sum(1 for f in es[i + 1:] if (e[0] - f[0]) * (e[1] - f[1]) < 0)
        return n

    def sweep(rws, downward):
        rws = {t: list(r) for t, r in rws.items()}
        for t in (sorted(rws) if downward else sorted(rws, reverse=True))[1:]:
            at = starts(rws)
            wanted = {}
            for u, ou, l, ol in pairs:
                if downward and tiers[l] == t:
                    wanted.setdefault(l, []).append(at[u] + ou - ol)
                elif not downward and tiers[u] == t:
                    wanted.setdefault(u, []).append(at[l] + ol - ou)
            def key(k):
                w = wanted.get(k)
                start = sum(w) / len(w) if w else at[k]
                return (start + cross(k) / 2.0, rank[k])
            rws[t].sort(key=key)
        return rws

    best, fewest = rows, crossings(rows)
    current = rows
    for _ in range(4):
        if fewest == 0:
            break
        for downward in (True, False):
            current = sweep(current, downward)
            n = crossings(current)
            if n < fewest:
                best, fewest = current, n
    return best


def _arrange(keys, size, fixed, links, down, node_gap, tier_gap, listed=False, ends=None):
    """Place the items of one container in centered tiers.

    size[k] is (width, height); links are (a, b, (label width, label height)). ends[i] is
    where link i meets its two items along the cross axis, measured from each item's start
    (None for the middle). With listed=True the tiers keep the order of keys exactly;
    otherwise they are reordered to cut crossings.
    Returns ({k: (x, y)}, width, height) with (0, 0) at the container's top-left.
    """
    tiers = _tiers(keys, [(a, b) for a, b, _ in links], fixed)
    main = (lambda k: size[k][1]) if down else (lambda k: size[k][0])
    cross = (lambda k: size[k][0]) if down else (lambda k: size[k][1])
    cross_gap, gaps = node_gap, {}
    for a, b, (lw, lh) in links:
        if a == b or not (lw or lh):
            continue
        if tiers[a] == tiers[b]:
            need = (lw if down else lh) + 2 * ARROW_GAP + 2 * LABEL_OFFSET + 8
            cross_gap = max(cross_gap, _snap(need))
        elif abs(tiers[a] - tiers[b]) == 1:
            need = (lh if down else lw) + 2 * ARROW_GAP + 2 * LABEL_OFFSET + 8
            t = min(tiers[a], tiers[b])
            gaps[t] = max(gaps.get(t, tier_gap), _snap(need))
    rows = {}
    for k in keys:
        rows.setdefault(tiers[k], []).append(k)
    if not listed:
        rows = _order_rows(rows, tiers, links, ends, cross, cross_gap)
    pos, m = {}, 0
    for t in sorted(rows):
        row = rows[t]
        total = sum(cross(k) for k in row) + cross_gap * (len(row) - 1)
        c = -(total // 2)
        for k in row:
            pos[k] = (c, m) if down else (m, c)
            c += cross(k) + cross_gap
        m += max(main(k) for k in row) + gaps.get(t, tier_gap)
    minx = min(p[0] for p in pos.values())
    miny = min(p[1] for p in pos.values())
    pos = {k: (p[0] - minx, p[1] - miny) for k, p in pos.items()}
    width = max(pos[k][0] + size[k][0] for k in keys)
    height = max(pos[k][1] + size[k][1] for k in keys)
    return pos, width, height


# ------------------------------------------------------------------ ports

def _sides(a, b, down):
    """Which side an arrow leaves box a from, and which side it enters box b from."""
    if down:
        if b[1] >= a[3] + 1:
            return "bottom", "top"
        if b[3] <= a[1] - 1:
            return "top", "bottom"
        return ("right", "left") if b[0] + b[2] >= a[0] + a[2] else ("left", "right")
    if b[0] >= a[2] + 1:
        return "right", "left"
    if b[2] <= a[0] - 1:
        return "left", "right"
    return ("bottom", "top") if b[1] + b[3] >= a[1] + a[3] else ("top", "bottom")


def _center(box):
    return (box[0] + box[2]) / 2.0, (box[1] + box[3]) / 2.0


def _span(kind, box, side, self_loop):
    """The stretch of a side where ports may sit."""
    horizontal = side in ("top", "bottom")
    lo, hi = (box[0], box[2]) if horizontal else (box[1], box[3])
    mid, length = (lo + hi) / 2.0, hi - lo
    if kind == "rectangle":
        inset = min(20.0, length * 0.15)
        return lo + inset, hi - inset
    if kind == "ellipse" or self_loop:
        return mid - length / 4.0, mid + length / 4.0
    return mid, mid


def _boundary(kind, box, side, coord):
    """The point of the outline on that side at that coordinate along the side."""
    cx, cy = _center(box)
    hw, hh = (box[2] - box[0]) / 2.0, (box[3] - box[1]) / 2.0
    if side in ("top", "bottom"):
        d = (coord - cx) / hw if hw else 0.0
        off = hh * (math.sqrt(max(0.0, 1 - d * d)) if kind == "ellipse" else
                    max(0.0, 1 - abs(d)) if kind == "diamond" else 1.0)
        return coord, (cy - off if side == "top" else cy + off)
    d = (coord - cy) / hh if hh else 0.0
    off = hw * (math.sqrt(max(0.0, 1 - d * d)) if kind == "ellipse" else
                max(0.0, 1 - abs(d)) if kind == "diamond" else 1.0)
    return (cx - off if side == "left" else cx + off), coord


def _end(kind, box, side, coord):
    """The arrow end (outside the outline) and the point where routing starts (outside the box)."""
    bx, by = _boundary(kind, box, side, coord)
    nx, ny = NORMAL[side]
    p = (_r(bx + nx * ARROW_GAP), _r(by + ny * ARROW_GAP))
    if side == "top":
        esc = (p[0], min(p[1], box[1] - ARROW_GAP))
    elif side == "bottom":
        esc = (p[0], max(p[1], box[3] + ARROW_GAP))
    elif side == "left":
        esc = (min(p[0], box[0] - ARROW_GAP), p[1])
    else:
        esc = (max(p[0], box[2] + ARROW_GAP), p[1])
    return p, esc


def _ports(edges, boxes, kinds, down):
    """Choose sides and spread the ends that share a side. Returns {(edge, end): (side, coord)}."""
    sides = {}
    attach = {}
    pairs = {(e["from"], e["to"]) for e in edges}
    axis = 0 if down else 1
    middle = (min(b[axis] for b in boxes.values()) + max(b[axis + 2] for b in boxes.values())) / 2.0
    for i, e in enumerate(edges):
        a, b = e["from"], e["to"]
        loop_side = "right" if down else "bottom"
        s = (loop_side, loop_side) if a == b else _sides(boxes[a], boxes[b], down)
        # An arrow back against the flow goes around the side its two ends lean toward (right,
        # or bottom when the flow goes right, unless both sit before the middle), unless it
        # answers an arrow going the other way, in which case the two run side by side.
        if s == (("top", "bottom") if down else ("left", "right")) and (b, a) not in pairs:
            lean = (_center(boxes[a])[axis] + _center(boxes[b])[axis]) / 2.0
            if lean < middle - 1:
                s = ("left", "left") if down else ("top", "top")
            else:
                s = ("right", "right") if down else ("bottom", "bottom")
        sides[(i, 0)], sides[(i, 1)] = s
    for (i, end), side in sides.items():
        node = edges[i]["from"] if end == 0 else edges[i]["to"]
        attach.setdefault((node, side), []).append((i, end))

    def other_center(i, end):
        e = edges[i]
        return _center(boxes[e["to"] if end == 0 else e["from"]])

    # A diamond has one tip per side: keep the best-aligned end there, move the others aside.
    for (node, side), ends in sorted(attach.items(), key=lambda kv: (kv[0][0], kv[0][1])):
        if kinds[node] != "diamond" or len(ends) < 2 or edges[ends[0][0]]["from"] == edges[ends[0][0]]["to"]:
            continue
        cx, cy = _center(boxes[node])
        axis = 0 if side in ("top", "bottom") else 1
        ends.sort(key=lambda it: (abs(other_center(*it)[axis] - (cx, cy)[axis]), it))
        for it in list(ends[1:]):
            oc = other_center(*it)
            if axis == 0:
                perp = "left" if oc[0] < cx else "right"
            else:
                perp = "top" if oc[1] < cy else "bottom"
            if not attach.get((node, perp)):
                ends.remove(it)
                attach[(node, perp)] = [it]
                sides[it] = perp

    coords = {}
    spans = {}
    for (node, side), ends in attach.items():
        if not ends:
            continue
        loop = any(edges[i]["from"] == edges[i]["to"] for i, _ in ends)
        spans[(node, side)] = _span(kinds[node], boxes[node], side, loop)
        axis = 0 if side in ("top", "bottom") else 1
        ends.sort(key=lambda it: (other_center(*it)[axis], it))
        lo, hi = spans[(node, side)]
        for j, it in enumerate(ends):
            coords[it] = lo + (hi - lo) * (j + 1) / (len(ends) + 1)
    # Facing sides that carry exactly the same arrows get matching ports, so the arrows run straight.
    facing = {("bottom", "top"), ("top", "bottom"), ("right", "left"), ("left", "right")}
    done = set()
    for i, e in enumerate(edges):
        sa, sb = sides[(i, 0)], sides[(i, 1)]
        if e["from"] == e["to"] or (sa, sb) not in facing:
            continue
        ka, kb = (e["from"], sa), (e["to"], sb)
        if frozenset((ka, kb)) in done:
            continue
        done.add(frozenset((ka, kb)))
        A, B = attach[ka], attach[kb]
        ids = [it[0] for it in A]
        if len(set(ids)) != len(ids) or sorted(ids) != sorted(it[0] for it in B):
            continue
        lo = max(spans[ka][0], spans[kb][0])
        hi = min(spans[ka][1], spans[kb][1])
        n = len(ids)
        if hi < lo or (n > 1 and hi - lo < 16 * (n + 1)):
            continue
        for j, edge_index in enumerate(ids):
            c = lo + (hi - lo) * (j + 1) / (n + 1)
            coords[(edge_index, 0)] = coords[(edge_index, 1)] = c
    # A side with a single arrow lines it up with the other end, so the arrow runs straight.
    for i, e in enumerate(edges):
        if e["from"] == e["to"] or (sides[(i, 0)], sides[(i, 1)]) not in facing:
            continue
        for free in (1, 0):
            node, side = (e["to"], sides[(i, 1)]) if free else (e["from"], sides[(i, 0)])
            want = coords[(i, 1 - free)]
            lo, hi = spans[(node, side)]
            if kinds[node] != "diamond" and len(attach[(node, side)]) == 1 and lo <= want <= hi:
                coords[(i, free)] = want
                break
    # An arrow from a side to a perpendicular side (a diamond tip to a box above or below it)
    # makes one bend when the box's port lines up just past the tip.
    for i, e in enumerate(edges):
        sa, sb = sides[(i, 0)], sides[(i, 1)]
        if e["from"] == e["to"] or (sa in ("top", "bottom")) == (sb in ("top", "bottom")):
            continue
        for free in (1, 0):
            node, side = (e["to"], sb) if free else (e["from"], sa)
            other_node, other_side = (e["from"], sa) if free else (e["to"], sb)
            if kinds[node] != "rectangle" or len(attach[(node, side)]) != 1:
                continue
            esc = _end(kinds[other_node], boxes[other_node], other_side, coords[(i, 1 - free)])[1]
            if side in ("top", "bottom"):
                want = esc[0] + (24 if other_side == "right" else -24)
            else:
                want = esc[1] + (24 if other_side == "bottom" else -24)
            lo, hi = spans[(node, side)]
            if lo <= want <= hi:
                coords[(i, free)] = want
                break
    return {it: (sides[it], round(coords[it])) for it in sides}


# ------------------------------------------------------------------ routing

class Router(object):
    """Shortest orthogonal paths on a grid of lines between and around the obstacles."""

    def __init__(self, obstacles, extra_x, extra_y, zones=(), meet=MEET_COST):
        self.obs = obstacles
        self.meet = meet
        self.xs, self.xborder = self._lines([o[0] for o in obstacles] + [o[2] for o in obstacles], extra_x)
        self.ys, self.yborder = self._lines([o[1] for o in obstacles] + [o[3] for o in obstacles], extra_y)
        self.xi = {x: i for i, x in enumerate(self.xs)}
        self.yi = {y: j for j, y in enumerate(self.ys)}
        nx, ny = len(self.xs), len(self.ys)
        self.inside = [bytearray(ny) for _ in range(nx)]
        self.hblock = [bytearray(nx) for _ in range(ny)]
        self.vblock = [bytearray(ny) for _ in range(nx)]
        for (l, t, r, b) in obstacles:
            i0, i1 = bisect.bisect_right(self.xs, l), bisect.bisect_left(self.xs, r)
            j0, j1 = bisect.bisect_right(self.ys, t), bisect.bisect_left(self.ys, b)
            for j in range(j0, j1):
                for i in range(i0, i1):
                    self.inside[i][j] = 1
                for i in range(max(0, i0 - 1), min(nx - 1, i1)):
                    self.hblock[j][i] = 1
            for i in range(i0, i1):
                for j in range(max(0, j0 - 1), min(ny - 1, j1)):
                    self.vblock[i][j] = 1
        # Stretches of grid lines that would run along a zone's outline.
        self.zone_h, self.zone_v = {}, {}
        for (l, t, r, b) in zones:
            for y in self.ys:
                if abs(y - t) <= 8 or abs(y - b) <= 8:
                    self.zone_h.setdefault(y, []).append((l, r))
            for x in self.xs:
                if abs(x - l) <= 8 or abs(x - r) <= 8:
                    self.zone_v.setdefault(x, []).append((t, b))

    @staticmethod
    def _lines(base, extra):
        base = sorted(set(_r(v) for v in base))
        lines = set(base) | set(_r(v) for v in extra)
        for a, b in zip(base, base[1:]):
            mid = (a + b) / 2.0
            if b - a >= 24:
                lines.add(_r(mid))
            if b - a >= 64:
                lines.update((_r(mid - 16), _r(mid + 16)))
            if b - a >= 112:
                lines.update((_r(mid - 32), _r(mid + 32)))
        lines.update((_r(min(lines) - 40), _r(max(lines) + 40)))
        return sorted(lines), set(base) - set(_r(v) for v in extra)

    def _blocked(self, i, j, d):
        if d == 0:
            return self.hblock[j][i]
        if d == 1:
            return self.hblock[j][i - 1]
        if d == 2:
            return self.vblock[i][j]
        return self.vblock[i][j - 1]

    def route(self, s, sd, e, ed, used, strict):
        si, sj = self.xi.get(_r(s[0])), self.yi.get(_r(s[1]))
        ei, ej = self.xi.get(_r(e[0])), self.yi.get(_r(e[1]))
        if None in (si, sj, ei, ej) or self.inside[si][sj] or self.inside[ei][ej]:
            return None
        xs, ys = self.xs, self.ys
        nx, ny = len(xs), len(ys)
        ex, ey = xs[ei], ys[ej]
        xmid, ymid = (xs[si] + ex) / 2.0, (ys[sj] + ey) / 2.0
        start = (si, sj, sd)
        dist = {start: 0.0}
        prev = {}
        heap = [(abs(xs[si] - ex) + abs(ys[sj] - ey), 0.0, si, sj, sd)]
        while heap:
            _, g, i, j, d = heapq.heappop(heap)
            if g > dist.get((i, j, d), float("inf")):
                continue
            if i == ei and j == ej and (d == ed or not strict) and (i, j, d) != start:
                path, key = [], (i, j, d)
                while key in prev:
                    path.append((xs[key[0]], ys[key[1]]))
                    key = prev[key]
                path.append((xs[si], ys[sj]))
                return path[::-1]
            first = (i, j, d) == start
            for nd in (0, 1, 2, 3):
                if nd == OPPOSITE[d] or (strict and first and nd != sd):
                    continue
                di, dj = STEP[nd]
                ni, nj = i + di, j + dj
                if not (0 <= ni < nx and 0 <= nj < ny) or self._blocked(i, j, nd) or self.inside[ni][nj]:
                    continue
                if nd in (0, 1):
                    length = abs(xs[ni] - xs[i])
                    factor = BORDER_COST if ys[j] in self.yborder else 1.0
                    pen = (_overlap(used[0], ys[j], xs[i], xs[ni]) + MIDDLE_PULL * abs(ys[j] - ymid) * length
                           + _along(self.zone_h, ys[j], xs[i], xs[ni]))
                else:
                    length = abs(ys[nj] - ys[j])
                    factor = BORDER_COST if xs[i] in self.xborder else 1.0
                    pen = (_overlap(used[1], xs[i], ys[j], ys[nj]) + MIDDLE_PULL * abs(xs[i] - xmid) * length
                           + _along(self.zone_v, xs[i], ys[j], ys[nj]))
                if self.meet and _on_route(used, xs[ni], ys[nj]):
                    pen += self.meet
                cost = g + length * factor + pen + (BEND if nd != d else 0)
                if not strict and ni == ei and nj == ej and nd != ed:
                    cost += BEND
                key = (ni, nj, nd)
                if cost < dist.get(key, float("inf")):
                    dist[key] = cost
                    prev[key] = (i, j, d)
                    heapq.heappush(heap, (cost + abs(xs[ni] - ex) + abs(ys[nj] - ey), cost, ni, nj, nd))
        return None


def _on_route(used, x, y):
    """True when the point lies on an arrow already routed, or within NEAR px of one of its
    ends along the same line, so stepping on it crosses that arrow or seems to touch it."""
    return any(r1 - NEAR <= x <= r2 + NEAR for r1, r2 in used[0].get(_r(y), ())) or \
        any(r1 - NEAR <= y <= r2 + NEAR for r1, r2 in used[1].get(_r(x), ()))


def _overlap(used, line, a, b):
    runs = used.get(_r(line))
    if not runs:
        return 0
    lo, hi = min(a, b), max(a, b)
    ov = sum(max(0.0, min(hi, r2) - max(lo, r1)) for r1, r2 in runs)
    return OVERLAP_BASE + OVERLAP_PER * ov if ov > 0.5 else 0


def _along(runs_by_line, line, a, b):
    runs = runs_by_line.get(line)
    if not runs:
        return 0
    lo, hi = min(a, b), max(a, b)
    return ZONE_EDGE_COST * sum(max(0.0, min(hi, r2) - max(lo, r1)) for r1, r2 in runs)


def _simplify(points):
    out = []
    for p in points:
        p = (_r(p[0]), _r(p[1]))
        if out and p == out[-1]:
            continue
        if len(out) >= 2:
            a, b = out[-2], out[-1]
            if (a[0] == b[0] == p[0]) or (a[1] == b[1] == p[1]):
                out[-1] = p
                continue
        out.append(p)
    return out


def _record(used, points):
    for p, q in zip(points, points[1:]):
        if p[1] == q[1]:
            used[0].setdefault(_r(p[1]), []).append((min(p[0], q[0]), max(p[0], q[0])))
        elif p[0] == q[0]:
            used[1].setdefault(_r(p[0]), []).append((min(p[1], q[1]), max(p[1], q[1])))


# ------------------------------------------------------------------ labels

def _label_ok(rect, shapes, texts, segs):
    """A label touches no shape outline, keeps ZONE_LABEL_CLEAR from a zone's outline on
    either side, and keeps clear of other text and of every line."""
    for poly, zone in shapes:
        margin = ZONE_LABEL_CLEAR if zone else rules.TEXT_MARGIN
        if geo.rect_meets_polygon(geo.inflate(rect, margin), poly):
            if not zone or not geo.rect_inside_polygon(rect, poly, margin):
                return False
    wide = geo.inflate(rect, 4)
    if any(geo.rects_overlap(wide, t) for t in texts):
        return False
    near = geo.inflate(rect, 3)
    return not any(geo.segment_hits_rect(p, q, near) for p, q in segs)


def _place_label(points, w, h, shapes, texts, segs, loop=False):
    """Top-left of a free spot beside one straight stretch of the arrow, or None.

    The label stays within the length of the stretch it sits beside, except on a loop
    back to the same shape, whose stretches may be shorter than the label.
    """
    runs = list(zip(points, points[1:]))
    runs.sort(key=lambda pq: -(abs(pq[0][0] - pq[1][0]) + abs(pq[0][1] - pq[1][1])))
    for p, q in runs:
        horizontal = abs(p[1] - q[1]) < 0.5
        lo, hi = (min(p[0], q[0]), max(p[0], q[0])) if horizontal else (min(p[1], q[1]), max(p[1], q[1]))
        half = (w if horizontal else h) / 2.0
        if loop:
            lo = hi = (lo + hi) / 2.0
        else:
            lo, hi = lo + half + 4, hi - half - 4
        if hi < lo:
            continue
        for f in (0.5, 0.35, 0.65, 0.2, 0.8, 0.05, 0.95):
            c = lo + (hi - lo) * f
            if horizontal:
                y = p[1]
                cands = [(c - w / 2, y - LABEL_OFFSET - h), (c - w / 2, y + LABEL_OFFSET)]
            else:
                x = p[0]
                cands = [(x + LABEL_OFFSET, c - h / 2), (x - LABEL_OFFSET - w, c - h / 2)]
            for x0, y0 in cands:
                x0, y0 = round(x0), round(y0)
                rect = (x0, y0, x0 + w, y0 + h)
                if _label_ok(rect, shapes, texts, segs):
                    return x0, y0
    return None


# ------------------------------------------------------------------ graph

def _graph(spec, scale, meet=MEET_COST):
    st = _style(spec)
    fam, lh, rough = st["family"], st["lh"], st["rough"]
    down = spec["direction"] == "down"
    node_gap, tier_gap = _snap(spec["node_gap"] * scale), _snap(spec["tier_gap"] * scale)
    nodes = {n["id"]: _size_node(n, fam) for n in spec["nodes"]}
    order = [n["id"] for n in spec["nodes"]]
    edges = spec["edges"]
    lsize = [measure.text_size(e["label"], FONT, fam) if e["label"] else (0.0, 0.0) for e in edges]
    groups = {g["id"]: g for g in spec["groups"]}
    listed = spec["order"] == "listed"

    zones = {}
    for gid, g in groups.items():
        keys = [k for k in order if nodes[k]["group"] == gid]
        links = [(e["from"], e["to"], lsize[i]) for i, e in enumerate(edges)
                 if e["from"] in keys and e["to"] in keys]
        fixed = {k: nodes[k]["tier"] for k in keys if nodes[k]["tier"] is not None}
        pos, cw, ch = _arrange(keys, {k: (nodes[k]["w"], nodes[k]["h"]) for k in keys}, fixed,
                               links, down, node_gap, tier_gap, listed)
        lw, lhh = measure.text_size(g["label"], FONT, fam)
        top = max(ZONE_PAD, _snap(10 + lhh + 20))
        zones[gid] = {"pos": pos, "cw": cw, "ch": ch, "top": top, "label": (lw, lhh),
                      "w": _snap(max(cw + 2 * ZONE_PAD, lw + 32)), "h": _snap(ch + top + ZONE_PAD)}

    item_of = {k: ("g:" + nodes[k]["group"]) if nodes[k]["group"] else ("n:" + k) for k in order}
    items, size, fixed = [], {}, {}
    for k in order:
        it = item_of[k]
        if it in size:
            continue
        items.append(it)
        if it.startswith("g:"):
            z = zones[it[2:]]
            size[it] = (z["w"], z["h"])
            if groups[it[2:]]["tier"] is not None:
                fixed[it] = groups[it[2:]]["tier"]
        else:
            size[it] = (nodes[k]["w"], nodes[k]["h"])
            if nodes[k]["tier"] is not None:
                fixed[it] = nodes[k]["tier"]
    def inside(k):
        """Where node k's middle sits along a zone's cross axis, or None outside a zone."""
        if not nodes[k]["group"]:
            return None
        z = zones[nodes[k]["group"]]
        rx, ry = z["pos"][k]
        return (z["w"] - z["cw"]) // 2 + rx + nodes[k]["w"] / 2.0 if down else z["top"] + ry + nodes[k]["h"] / 2.0

    outer = [e for e in edges if item_of[e["from"]] != item_of[e["to"]]]
    links = [(item_of[e["from"]], item_of[e["to"]], lsize[i]) for i, e in enumerate(edges)
             if item_of[e["from"]] != item_of[e["to"]]]
    ends = [(inside(e["from"]), inside(e["to"])) for e in outer]
    pos, width, _ = _arrange(items, size, fixed, links, down, node_gap, tier_gap, listed, ends)

    title_size = measure.text_size(spec["title"], TITLE_FONT, fam) if spec["title"] else None
    top0 = _snap(title_size[1] + TITLE_GAP) if title_size else 0
    for it, (x, y) in pos.items():
        y += top0
        if it.startswith("n:"):
            nodes[it[2:]]["x"], nodes[it[2:]]["y"] = x, y
            continue
        z = zones[it[2:]]
        z["x"], z["y"] = x, y
        off = (z["w"] - z["cw"]) // 2
        for k, (rx, ry) in z["pos"].items():
            nodes[k]["x"], nodes[k]["y"] = x + off + rx, y + z["top"] + ry

    elements, shape_of, obstacles, texts, shapes = [], {}, [], [], []
    # Zones first, so they sit behind everything else.
    for gid, z in zones.items():
        stroke, _, zfill = PALETTE[groups[gid]["color"]]
        zid, grp = "zone:" + gid, "group:zone:" + gid
        rect = scene.base("rectangle", zid, z["x"], z["y"], z["w"], z["h"], stroke, zfill, "solid", 1,
                          "dashed", rough, {"type": 3}, [grp])
        lw, lhh = z["label"]
        label = scene.text(zid + ":label", z["x"] + 16, z["y"] + 10, _r(lw), _r(lhh), groups[gid]["label"],
                           FONT, fam, lh, "left", "top", None, stroke, [grp])
        elements += [rect, label]
        shapes.append((geo.polygon(rect), True))
        texts.append(geo.bbox(label))
        obstacles.append(geo.inflate(geo.bbox(label), 4))

    boxes, kinds = {}, {}
    for k in order:
        n = nodes[k]
        stroke, fill, _ = PALETTE[n["color"]]
        x, y, w, h = n["x"], n["y"], n["w"], n["h"]
        boxes[k], kinds[k] = (x, y, x + w, y + h), n["kind"]
        sid = "node:" + k
        if n["shape"] == "table":
            grp = ["group:table:" + k]
            hh = n["head_h"]
            head = scene.base("rectangle", sid, x, y, w, hh, stroke, fill, st["fill"], 2, "solid", rough, None, grp)
            tw, th = n["head_text"]
            ht = scene.text(sid + ":text", _r(x + (w - tw) / 2), _r(y + (hh - th) / 2), _r(tw), _r(th), n["label"],
                            FONT, fam, lh, "center", "middle", sid, INK, grp)
            scene.bind(head, ht["id"], "text")
            elements += [head, ht]
            shape_of[(k, "head")] = head
            texts.append(geo.bbox(ht))
            shapes.append((geo.polygon(head), False))
            if n["lines"]:
                bw, bh = n["body_text"]
                body = scene.base("rectangle", sid + ":fields", x, y + hh, w, h - hh, stroke, "#ffffff", "solid", 2,
                                  "solid", rough, None, grp)
                bt = scene.text(sid + ":fields:text", x + 16, _r(y + hh + (h - hh - bh) / 2), _r(bw), _r(bh),
                                "\n".join(n["lines"]), FONT, fam, lh, "left", "top", None, INK, grp)
                elements += [body, bt]
                shape_of[(k, "body")] = body
                texts.append(geo.bbox(bt))
                shapes.append((geo.polygon(body), False))
        else:
            shape = scene.base(n["kind"], sid, x, y, w, h, stroke, fill, st["fill"], 2, "solid", rough,
                               {"type": 3} if n["shape"] == "box" else None)
            tw, th = n["text"]
            t = scene.text(sid + ":text", _r(x + (w - tw) / 2), _r(y + (h - th) / 2), _r(tw), _r(th), n["content"],
                           FONT, fam, lh, "center", "middle", sid, INK)
            scene.bind(shape, t["id"], "text")
            elements += [shape, t]
            shape_of[(k, "head")] = shape
            texts.append(geo.bbox(t))
            shapes.append((geo.polygon(shape), False))
        obstacles.append(geo.inflate(boxes[k], CLEAR))

    title = None
    if title_size:
        tw, th = title_size
        title = scene.text("title", _r((width - tw) / 2), 0, _r(tw), _r(th), spec["title"], TITLE_FONT, fam, lh,
                           "center", "top", None, INK)
        texts.append(geo.bbox(title))
        obstacles.append(geo.inflate(geo.bbox(title), 4))

    ports = _ports(edges, boxes, kinds, down)
    ends = {}
    for (i, end), (side, coord) in ports.items():
        node = edges[i]["from"] if end == 0 else edges[i]["to"]
        ends[(i, end)] = (side,) + _end(kinds[node], boxes[node], side, coord)
    router = Router(obstacles, [v[2][0] for v in ends.values()], [v[2][1] for v in ends.values()],
                    [geo.bbox(e) for e in elements if e["id"].startswith("zone:") and e["type"] == "rectangle"], meet)
    used = ({}, {})
    routes = {}
    # A loop back to the same node leaves and re-enters across the flow: right when it goes down, bottom when it goes right.
    for i, e in enumerate(edges):
        if e["from"] != e["to"]:
            continue
        (side, pa, _), (_, pb, _) = ends[(i, 0)], ends[(i, 1)]
        if side == "right":
            xl = max(pa[0], pb[0]) + LOOP_W - ARROW_GAP
            routes[i] = _simplify([pa, (xl, pa[1]), (xl, pb[1]), pb])
        else:
            yl = max(pa[1], pb[1]) + LOOP_W - ARROW_GAP
            routes[i] = _simplify([pa, (pa[0], yl), (pb[0], yl), pb])
        _record(used, routes[i])
    plain = [i for i, e in enumerate(edges) if e["from"] != e["to"]]
    plain.sort(key=lambda i: (abs(ends[(i, 0)][2][0] - ends[(i, 1)][2][0]) + abs(ends[(i, 0)][2][1] - ends[(i, 1)][2][1]), i))
    for i in plain:
        (sa, pa, ea), (sb, pb, eb) = ends[(i, 0)], ends[(i, 1)]
        path = router.route(ea, OUTWARD[sa], eb, INWARD[sb], used, True) or \
            router.route(ea, OUTWARD[sa], eb, INWARD[sb], used, False)
        if path is None:
            raise PlacementError("edges[%d] (%s -> %s): no route that keeps clear of the other shapes"
                                 % (i, edges[i]["from"], edges[i]["to"]))
        routes[i] = _simplify([pa] + path + [pb])
        _record(used, routes[i])

    segs = [pq for i in range(len(edges)) for pq in zip(routes[i], routes[i][1:])]
    arrows, labels = [], []
    for i, e in enumerate(edges):
        grp = ["group:edge:%d" % i] if e["label"] else []
        arrow = scene.linear("arrow", "edge:%d" % i, routes[i], INK, 2, e["line"], rough,
                             "arrow" if e["head"] == "both" else None,
                             None if e["head"] == "none" else "arrow", grp)
        for end, key in ((0, "startBinding"), (1, "endBinding")):
            node = e["from"] if end == 0 else e["to"]
            side = ends[(i, end)][0]
            point = ends[(i, end)][1]
            target = shape_of[(node, "head")]
            if (node, "body") in shape_of and (side == "bottom" or (side in ("left", "right")
                                                                     and point[1] > target["y"] + target["height"])):
                target = shape_of[(node, "body")]
            arrow[key] = {"elementId": target["id"], "focus": 0, "gap": ARROW_GAP}
            if not any(b["id"] == arrow["id"] for b in target["boundElements"] or []):
                scene.bind(target, arrow["id"], "arrow")
        arrows.append(arrow)
        if e["label"]:
            w, h = lsize[i]
            spot = _place_label(routes[i], w, h, shapes, texts, segs, e["from"] == e["to"])
            if spot is None:
                raise PlacementError('edges[%d] (%s -> %s): no free spot beside the arrow for its label "%s"'
                                     % (i, e["from"], e["to"], e["label"].split("\n")[0]))
            t = scene.text("edge:%d:label" % i, spot[0], spot[1], _r(w), _r(h), e["label"], FONT, fam, lh,
                           "center", "top", None, INK, grp)
            labels.append(t)
            texts.append(geo.bbox(t))
    elements += arrows + labels
    if title:
        elements.append(title)
    return elements


# ------------------------------------------------------------------ sequence

def _sequence(spec, scale):
    st = _style(spec)
    fam, lh, rough = st["family"], st["lh"], st["rough"]
    parts, msgs = spec["participants"], spec["messages"]
    index = {p["id"]: i for i, p in enumerate(parts)}
    boxes = []
    for p in parts:
        content = p["label"] + ("\n" + "\n".join(p["lines"]) if p["lines"] else "")
        tw, th = measure.text_size(content, FONT, fam)
        rw = measure.room_for(content, FONT, fam)[0]
        boxes.append({"w": max(120, _snap(rw + 40)), "h": max(60, _snap(th + 40)), "content": content, "text": (tw, th)})
    height = max(b["h"] for b in boxes)
    gaps = [_snap(boxes[i]["w"] / 2 + boxes[i + 1]["w"] / 2 + 60 * scale) for i in range(len(parts) - 1)]
    lsize = [measure.text_size(m["label"], FONT, fam) if m["label"] else (0.0, 0.0) for m in msgs]
    for k, m in enumerate(msgs):
        a, b = index[m["from"]], index[m["to"]]
        lw = lsize[k][0]
        if a == b:
            if a < len(gaps):
                gaps[a] = max(gaps[a], _snap(LOOP_W + LABEL_OFFSET + lw + 24))
        else:
            g = a if b > a else a - 1
            gaps[g] = max(gaps[g], _snap(lw + 48))
    xs = [boxes[0]["w"] // 2]
    for g in gaps:
        xs.append(xs[-1] + g)
    title_size = measure.text_size(spec["title"], TITLE_FONT, fam) if spec["title"] else None
    top = _snap(title_size[1] + TITLE_GAP) if title_size else 0

    elements, lifelines = [], []
    for i, p in enumerate(parts):
        stroke, fill, _ = PALETTE[p["color"]]
        b = boxes[i]
        sid, grp = "participant:" + p["id"], ["group:participant:" + p["id"]]
        x = xs[i] - b["w"] // 2
        rect = scene.base("rectangle", sid, x, top, b["w"], height, stroke, fill, st["fill"], 2, "solid", rough,
                          {"type": 3}, grp)
        tw, th = b["text"]
        t = scene.text(sid + ":text", _r(x + (b["w"] - tw) / 2), _r(top + (height - th) / 2), _r(tw), _r(th),
                       b["content"], FONT, fam, lh, "center", "middle", sid, INK, grp)
        scene.bind(rect, t["id"], "text")
        elements += [rect, t]
    cursor = top + height + 40
    arrows, labels = [], []
    for k, m in enumerate(msgs):
        a, b = index[m["from"]], index[m["to"]]
        lw, lhh = lsize[k]
        grp = ["group:message:%d" % k] if m["label"] else []
        if a == b:
            x, y = xs[a], cursor + 12
            pts = [(x, y), (x + LOOP_W, y), (x + LOOP_W, y + LOOP_H), (x, y + LOOP_H)]
            spot = (x + LOOP_W + LABEL_OFFSET, _r(y + LOOP_H / 2.0 - lhh / 2))
            cursor = y + LOOP_H + 24
        else:
            y = cursor + (lhh + LABEL_OFFSET if m["label"] else 0) + 12
            pts = [(xs[a], y), (xs[b], y)]
            nxt = xs[a + 1] if b > a else xs[a - 1]
            spot = (_r((xs[a] + nxt) / 2.0 - lw / 2), _r(y - LABEL_OFFSET - lhh))
            cursor = y + 24
        arrows.append(scene.linear("arrow", "message:%d" % k, pts, INK, 2, m["line"], rough, None,
                                   None if m["head"] == "none" else "arrow", grp))
        if m["label"]:
            labels.append(scene.text("message:%d:label" % k, spot[0], spot[1], _r(lw), _r(lhh), m["label"],
                                     FONT, fam, lh, "center", "top", None, INK, grp))
    for i, p in enumerate(parts):
        lifelines.append(scene.linear("line", "participant:%s:lifeline" % p["id"], [(xs[i], top + height), (xs[i], cursor + 16)],
                                      LIFELINE, 1, "dashed", rough, None, None, ["group:participant:" + p["id"]]))
    elements += lifelines + arrows + labels
    if title_size:
        tw, th = title_size
        right = xs[-1] + boxes[-1]["w"] / 2.0
        elements.append(scene.text("title", _r((right - tw) / 2), 0, _r(tw), _r(th), spec["title"], TITLE_FONT, fam, lh,
                                   "center", "top", None, INK))
    return elements


def draw(spec, scale=1.0, meet=MEET_COST):
    """Elements for a validated spec at one spacing scale. Raises PlacementError.

    meet is what the router pays for each point where an arrow crosses or touches one
    routed before it.
    """
    return _graph(spec, scale, meet) if spec["type"] == "graph" else _sequence(spec, scale)


def build(spec):
    """Draw with more and more spacing until the scene passes the checks.

    At each spacing, arrows are first routed to avoid crossing each other; when that leaves
    a problem (avoiding a crossing can push two arrows onto one line), they are routed again
    without that cost before the spacing grows.
    Returns (doc, report, scale, error): doc and report of the last attempt that drew,
    and the PlacementError of the last attempt that could not draw (or None).
    """
    doc = report = error = None
    used = None
    meets = (MEET_COST, 0) if spec["type"] == "graph" else (0,)
    for scale in SCALES:
        for meet in meets:
            try:
                elements = draw(spec, scale, meet)
            except PlacementError as e:
                error = e
                continue
            doc, report, used = scene.document(elements), None, scale
            report = rules.check(doc)
            if not report.problems:
                return doc, report, scale, None
    return doc, report, used, error
