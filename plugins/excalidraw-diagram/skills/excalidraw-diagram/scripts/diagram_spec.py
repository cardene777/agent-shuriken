"""Read and validate a diagram spec.

A spec is a small JSON object the agent writes: nodes, edges, and groups for a graph, or
participants and messages for a sequence diagram. `validate` returns the spec with
defaults filled in, or raises SpecError listing every problem at once.
"""
import re

import diagram_theme as themes

PALETTE = {
    # name: (outline and text, shape fill, zone fill)
    "gray": ("#495057", "#e9ecef", "#f8f9fa"),
    "blue": ("#1971c2", "#a5d8ff", "#e7f5ff"),
    "green": ("#2f9e44", "#b2f2bb", "#ebfbee"),
    "red": ("#e03131", "#ffc9c9", "#fff5f5"),
    "orange": ("#e8590c", "#ffd8a8", "#fff4e6"),
    "yellow": ("#f08c00", "#ffec99", "#fff9db"),
    "violet": ("#6741d9", "#d0bfff", "#f3f0ff"),
    "teal": ("#0c8599", "#99e9f2", "#e3fafc"),
}
SHAPES = ("box", "ellipse", "diamond", "table")
LINES = ("solid", "dashed", "dotted")
HEADS = ("end", "both", "none")
ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$")
MAX_NODES, MAX_EDGES, MAX_LINES, MAX_TEXT = 80, 160, 15, 120

KEYS = {
    "graph": {"type", "title", "theme", "direction", "order", "style", "fill", "nodes", "edges", "groups", "node_gap",
              "tier_gap"},
    "sequence": {"type", "title", "theme", "style", "fill", "participants", "messages"},
    "node": {"id", "label", "lines", "shape", "color", "group", "tier"},
    "edge": {"from", "to", "label", "line", "head"},
    "group": {"id", "label", "color", "tier"},
    "participant": {"id", "label", "lines", "color"},
    "message": {"from", "to", "label", "line", "head"},
}


class SpecError(Exception):
    """The spec cannot be drawn. The message lists every problem, one per line."""


class _Errors(list):
    def add(self, where, message):
        self.append("%s: %s" % (where, message))


def _text(errors, where, value, required):
    if value is None:
        if required:
            errors.add(where, "is required")
        return ""
    if not isinstance(value, str):
        errors.add(where, "must be a string")
        return ""
    value = value.replace("\t", " ").replace("\r", "")
    lines = [line.rstrip() for line in value.split("\n")]
    while lines and not lines[-1]:
        lines.pop()
    value = "\n".join(lines).strip("\n")
    if required and not value.strip():
        errors.add(where, "must not be empty")
    if any(len(line) > MAX_TEXT for line in lines):
        errors.add(where, "has a line over %d characters; break it with \\n or shorten it" % MAX_TEXT)
    if any(ord(c) < 32 and c != "\n" for c in value):
        errors.add(where, "holds a control character")
    return value


def _lines(errors, where, value):
    if value is None:
        return []
    if not isinstance(value, list) or not all(isinstance(v, str) for v in value):
        errors.add(where, "must be a list of strings")
        return []
    if len(value) > MAX_LINES:
        errors.add(where, "has %d lines; keep it to %d" % (len(value), MAX_LINES))
    out = []
    for i, v in enumerate(value):
        t = _text(errors, "%s[%d]" % (where, i), v, False)
        out.extend(x for x in t.split("\n") if x.strip())
    return out


def _choice(errors, where, value, options, default):
    if value is None:
        return default
    if value not in options:
        errors.add(where, '"%s" is not one of %s' % (value, ", ".join(options)))
        return default
    return value


def _int(errors, where, value, low, high):
    if value is None:
        return None
    if not isinstance(value, int) or isinstance(value, bool) or not low <= value <= high:
        errors.add(where, "must be a whole number from %d to %d" % (low, high))
        return None
    return value


def _unknown(errors, where, obj, kind):
    for key in sorted(set(obj) - KEYS[kind]):
        errors.add(where, 'unknown key "%s" (allowed: %s)' % (key, ", ".join(sorted(KEYS[kind]))))


def _objects(errors, spec, key, required):
    value = spec.get(key)
    if value is None:
        if required:
            errors.add(key, "is required")
        return []
    if not isinstance(value, list) or not all(isinstance(v, dict) for v in value):
        errors.add(key, "must be a list of objects")
        return []
    return value


def _ids(errors, items, kind):
    seen = set()
    for i, item in enumerate(items):
        where = "%s[%d].id" % (kind, i)
        v = item.get("id")
        if not isinstance(v, str) or not ID.match(v):
            errors.add(where, "must be letters, digits, '_', '.', or '-', starting with a letter or digit")
        elif v in seen:
            errors.add(where, '"%s" is used twice' % v)
        seen.add(v)
    return seen


def _common(errors, spec):
    out = {
        "title": _text(errors, "title", spec.get("title"), False),
        "theme": _choice(errors, "theme", spec.get("theme"), tuple(themes.names()), themes.default()),
        # "style" and "fill" adjust the theme: clean or hand-drawn lines, and solid or hatched fills.
        "style": _choice(errors, "style", spec.get("style"), ("clean", "sketch"), None),
        "fill": _choice(errors, "fill", spec.get("fill"), ("solid", "hachure"), None),
    }
    return out


def _validate_graph(spec, errors):
    _unknown(errors, "spec", spec, "graph")
    out = _common(errors, spec)
    out["type"] = "graph"
    out["direction"] = _choice(errors, "direction", spec.get("direction"), ("down", "right"), "down")
    out["order"] = _choice(errors, "order", spec.get("order"), ("auto", "listed"), "auto")
    out["node_gap"] = _int(errors, "node_gap", spec.get("node_gap"), 40, 400) or 60
    out["tier_gap"] = _int(errors, "tier_gap", spec.get("tier_gap"), 60, 600) or 80
    nodes = _objects(errors, spec, "nodes", True)
    edges = _objects(errors, spec, "edges", False)
    groups = _objects(errors, spec, "groups", False)
    if len(nodes) > MAX_NODES or len(edges) > MAX_EDGES:
        errors.add("spec", "has %d nodes and %d edges; split it into diagrams of at most %d nodes and %d edges"
                   % (len(nodes), len(edges), MAX_NODES, MAX_EDGES))
    node_ids = _ids(errors, nodes, "nodes")
    group_ids = _ids(errors, groups, "groups")
    out["groups"] = []
    for i, g in enumerate(groups):
        where = "groups[%d]" % i
        _unknown(errors, where, g, "group")
        out["groups"].append({
            "id": g.get("id"),
            "label": _text(errors, where + ".label", g.get("label"), True),
            "color": _choice(errors, where + ".color", g.get("color"), tuple(PALETTE), "gray"),
            "tier": _int(errors, where + ".tier", g.get("tier"), 0, 50),
        })
    out["nodes"] = []
    used_groups = set()
    for i, n in enumerate(nodes):
        where = "nodes[%d]" % i
        _unknown(errors, where, n, "node")
        group = n.get("group")
        if group is not None and group not in group_ids:
            errors.add(where + ".group", '"%s" is not the id of a group in "groups"' % group)
            group = None
        used_groups.add(group)
        out["nodes"].append({
            "id": n.get("id"),
            "label": _text(errors, where + ".label", n.get("label"), True),
            "lines": _lines(errors, where + ".lines", n.get("lines")),
            "shape": _choice(errors, where + ".shape", n.get("shape"), SHAPES, "box"),
            "color": _choice(errors, where + ".color", n.get("color"), tuple(PALETTE), "gray"),
            "group": group,
            "tier": _int(errors, where + ".tier", n.get("tier"), 0, 50),
        })
    for g in out["groups"]:
        if g["id"] not in used_groups:
            errors.add("groups", 'group "%s" has no nodes; set "group" on its nodes or remove it' % g["id"])
    out["edges"] = []
    for i, e in enumerate(edges):
        where = "edges[%d]" % i
        _unknown(errors, where, e, "edge")
        for end in ("from", "to"):
            if e.get(end) not in node_ids:
                errors.add(where + "." + end, '"%s" is not the id of a node' % e.get(end))
        out["edges"].append({
            "from": e.get("from"), "to": e.get("to"),
            "label": _text(errors, where + ".label", e.get("label"), False),
            "line": _choice(errors, where + ".line", e.get("line"), LINES, "solid"),
            "head": _choice(errors, where + ".head", e.get("head"), HEADS, "end"),
        })
    return out


def _validate_sequence(spec, errors):
    _unknown(errors, "spec", spec, "sequence")
    out = _common(errors, spec)
    out["type"] = "sequence"
    parts = _objects(errors, spec, "participants", True)
    msgs = _objects(errors, spec, "messages", False)
    if len(parts) > 20 or len(msgs) > MAX_EDGES:
        errors.add("spec", "has %d participants and %d messages; split it into diagrams of at most 20 participants and %d messages"
                   % (len(parts), len(msgs), MAX_EDGES))
    ids = _ids(errors, parts, "participants")
    out["participants"] = []
    for i, p in enumerate(parts):
        where = "participants[%d]" % i
        _unknown(errors, where, p, "participant")
        out["participants"].append({
            "id": p.get("id"),
            "label": _text(errors, where + ".label", p.get("label"), True),
            "lines": _lines(errors, where + ".lines", p.get("lines")),
            "color": _choice(errors, where + ".color", p.get("color"), tuple(PALETTE), "gray"),
        })
    out["messages"] = []
    for i, m in enumerate(msgs):
        where = "messages[%d]" % i
        _unknown(errors, where, m, "message")
        for end in ("from", "to"):
            if m.get(end) not in ids:
                errors.add(where + "." + end, '"%s" is not the id of a participant' % m.get(end))
        out["messages"].append({
            "from": m.get("from"), "to": m.get("to"),
            "label": _text(errors, where + ".label", m.get("label"), False),
            "line": _choice(errors, where + ".line", m.get("line"), ("solid", "dashed"), "solid"),
            "head": _choice(errors, where + ".head", m.get("head"), ("end", "none"), "end"),
        })
    return out


def validate(spec):
    errors = _Errors()
    if not isinstance(spec, dict):
        raise SpecError("spec: must be a JSON object")
    kind = spec.get("type", "graph")
    if kind == "graph":
        out = _validate_graph(spec, errors)
    elif kind == "sequence":
        out = _validate_sequence(spec, errors)
    else:
        raise SpecError('type: "%s" is not one of graph, sequence' % kind)
    if errors:
        raise SpecError("\n".join(errors))
    return out
