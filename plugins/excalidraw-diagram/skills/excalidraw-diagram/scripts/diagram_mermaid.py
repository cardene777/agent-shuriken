"""Turn a Mermaid flowchart or sequence diagram into a diagram spec.

Only a documented subset is read; any other statement stops with its line number, so
nothing is dropped without a word.

Flowcharts (`flowchart` or `graph`, direction TD, TB, or LR):
  nodes     A  A[box]  A(rounded box)  A([stadium])  A((circle))  A{decision}  A[(database)]
            A[[subroutine]]  A{{hexagon}}  A>flag], text in "quotes" allowed, <br> breaks a line
  edges     -->  ---  -.->  -.-  ==>  ===  <-->  with |label| after the arrow or -- label -->,
            chains (A --> B --> C) and & (A & B --> C)
  groups    subgraph id [Title] ... end, one level deep
  ignored   classDef, class, style, linkStyle, click, and %% comments (listed as notes)
Sequence diagrams (`sequenceDiagram`):
  participant A, participant A as Label, actor A as Label, title Text, autonumber,
  messages A->>B: text (arrow), A-->>B: text (dashed arrow), A->B (line), A-->B (dashed line),
  A-)B and A--)B (as arrows); activate, deactivate, and +/- markers are ignored (listed as notes)
"""
import html
import re


class MermaidError(Exception):
    """The text is outside the supported subset. The message names the line."""


SHAPES = [  # opener, closer, spec shape; longer openers first
    ("([", "])", "ellipse"), ("((", "))", "ellipse"), ("[(", ")]", "box"), ("[[", "]]", "box"),
    ("{{", "}}", "box"), ("[", "]", "box"), ("(", ")", "box"), ("{", "}", "diamond"), (">", "]", "box"),
]
EDGE_TEXT = [  # an arrow with its label written inside it
    (re.compile(r"--\s*([^-.|>=\s][^|]*?)\s*-{2,}>"), "solid", "end"),
    (re.compile(r"--\s*([^-.|>=\s][^|]*?)\s*-{3,}"), "solid", "none"),
    (re.compile(r"-\.\s*([^-.|>=\s][^|]*?)\s*\.+->"), "dashed", "end"),
    (re.compile(r"==\s*([^-.|>=\s][^|]*?)\s*={2,}>"), "solid", "end"),
]
EDGE = [
    (re.compile(r"<-{2,}>"), "solid", "both"), (re.compile(r"<={2,}>"), "solid", "both"),
    (re.compile(r"<-\.+->"), "dashed", "both"), (re.compile(r"-{2,}>"), "solid", "end"),
    (re.compile(r"={2,}>"), "solid", "end"), (re.compile(r"-\.+->"), "dashed", "end"),
    (re.compile(r"-{3,}"), "solid", "none"), (re.compile(r"={3,}"), "solid", "none"),
    (re.compile(r"-\.+-"), "dashed", "none"),
]
UNSUPPORTED_EDGE = re.compile(r"(--[ox]|[ox]--|-\.-[ox]|==[ox])(\s|$)")
IGNORED = ("classDef", "class", "style", "linkStyle", "click")
ID = re.compile(r"[A-Za-z0-9_]+")


def _clean(text):
    text = html.unescape(text.replace("#quot;", '"'))
    text = re.sub(r"<br\s*/?>", "\n", text, flags=re.I)
    return "\n".join(line.strip() for line in text.split("\n")).strip()


def _split_text(text):
    lines = [x for x in _clean(text).split("\n") if x]
    return (lines[0] if lines else ""), lines[1:]


def _statements(source):
    """Yield (line number, statement) with comments removed and ';' splitting statements."""
    for number, raw in enumerate(source.split("\n"), 1):
        line = raw.strip()
        if line.startswith("%%"):
            continue
        current, quote, depth = "", False, 0
        for ch in line:
            if ch == '"':
                quote = not quote
            elif not quote and ch in "[({":
                depth += 1
            elif not quote and ch in "])}":
                depth = max(0, depth - 1)
            if ch == ";" and not quote and depth == 0:
                if current.strip():
                    yield number, current.strip()
                current = ""
                continue
            current += ch
        if current.strip():
            yield number, current.strip()


class _Flow(object):
    def __init__(self):
        self.nodes, self.order, self.edges = {}, [], []
        self.groups, self.group = [], None

    def node(self, number, nid, text, shape):
        if nid not in self.nodes:
            self.nodes[nid] = {"id": nid, "label": nid, "lines": [], "shape": "box", "group": None}
            self.order.append(nid)
        n = self.nodes[nid]
        if text is not None:
            label, lines = _split_text(text)
            if not label:
                raise MermaidError("line %d: node %s has empty text" % (number, nid))
            n.update({"label": label, "lines": lines, "shape": shape})
        if self.group and n["group"] is None:
            n["group"] = self.group


def _read_node(number, s, pos, flow):
    m = ID.match(s, pos)
    if not m:
        raise MermaidError("line %d: expected a node id at '%s'" % (number, s[pos:pos + 20]))
    nid, pos = m.group(0), m.end()
    for opener, closer, shape in SHAPES:
        if not s.startswith(opener, pos):
            continue
        start = pos + len(opener)
        inner = s[start:].lstrip()
        if inner.startswith('"'):
            q = s.find('"', s.index('"', start) + 1)
            if q < 0:
                raise MermaidError("line %d: a quote in node %s is not closed" % (number, nid))
            text = s[s.index('"', start) + 1:q]
            end = s.find(closer, q + 1)
            if end < 0 or s[q + 1:end].strip():
                raise MermaidError("line %d: node %s needs %s after its quoted text" % (number, nid, closer))
        else:
            end = s.find(closer, start)
            if end < 0:
                raise MermaidError("line %d: node %s opens with %s but never closes with %s" % (number, nid, opener, closer))
            text = s[start:end]
        flow.node(number, nid, text.replace("`", ""), shape)
        return nid, end + len(closer)
    flow.node(number, nid, None, None)
    return nid, pos


def _read_group(number, s, pos, flow):
    ids = []
    while True:
        while pos < len(s) and s[pos].isspace():
            pos += 1
        nid, pos = _read_node(number, s, pos, flow)
        ids.append(nid)
        rest = s[pos:].lstrip()
        if rest.startswith("&"):
            pos = len(s) - len(rest) + 1
            continue
        return ids, pos


def _read_edge(number, s, pos):
    while pos < len(s) and s[pos].isspace():
        pos += 1
    if UNSUPPORTED_EDGE.match(s, pos):
        raise MermaidError("line %d: arrows ending in o or x are not supported; use -->" % number)
    label = ""
    for rx, line, head in EDGE_TEXT + EDGE:
        m = rx.match(s, pos)
        if m:
            if m.groups():
                label = m.group(1)
            pos = m.end()
            break
    else:
        raise MermaidError("line %d: expected an arrow such as --> at '%s'" % (number, s[pos:pos + 20]))
    rest = s[pos:].lstrip()
    if rest.startswith("|"):
        end = rest.find("|", 1)
        if end < 0:
            raise MermaidError("line %d: a |label| is not closed" % number)
        label = rest[1:end]
        pos = len(s) - len(rest) + end + 1
    return {"line": line, "head": head, "label": _clean(label)}, pos


def _slug(text):
    s = re.sub(r"[^A-Za-z0-9]+", "-", text).strip("-").lower()
    return s[:40] or "group"


def _flowchart(lines, header, notes):
    m = re.match(r"^(?:flowchart|graph)(?:\s+(\w+))?\s*$", header[1], re.I)
    direction = (m.group(1) or "TD").upper() if m else None
    if direction not in ("TD", "TB", "LR"):
        raise MermaidError("line %d: direction %s is not supported; use TD or LR" % (header[0], direction))
    flow = _Flow()
    for number, s in lines:
        word = s.split()[0]
        if word in IGNORED:
            notes.append("line %d: %s is ignored; colors come from the spec" % (number, word))
            continue
        if word == "subgraph":
            if flow.group:
                raise MermaidError("line %d: subgraphs inside subgraphs are not supported" % number)
            rest = s[len("subgraph"):].strip()
            m = re.match(r'^([A-Za-z0-9_]+)\s*\[\s*"?(.*?)"?\s*\]$', rest)
            if m:
                gid, label = m.group(1), m.group(2)
            else:
                label = rest.strip('"')
                gid = rest if ID.fullmatch(rest) else _slug(label)
            if not label:
                raise MermaidError("line %d: a subgraph needs a name" % number)
            base, k = gid, 2
            while any(g["id"] == gid for g in flow.groups):
                gid, k = "%s-%d" % (base, k), k + 1
            flow.groups.append({"id": gid, "label": _clean(label)})
            flow.group = gid
            continue
        if s == "end":
            if not flow.group:
                raise MermaidError("line %d: end without a subgraph" % number)
            flow.group = None
            continue
        if word == "direction":
            raise MermaidError("line %d: direction inside a subgraph is not supported" % number)
        left, pos = _read_group(number, s, 0, flow)
        while pos < len(s.rstrip()):
            edge, pos = _read_edge(number, s, pos)
            right, pos = _read_group(number, s, pos, flow)
            for a in left:
                for b in right:
                    item = {"from": a, "to": b}
                    if edge["label"]:
                        item["label"] = edge["label"]
                    if edge["line"] != "solid":
                        item["line"] = edge["line"]
                    if edge["head"] != "end":
                        item["head"] = edge["head"]
                    flow.edges.append(item)
            left = right
    if flow.group:
        raise MermaidError("the subgraph %s has no end" % flow.group)
    if not flow.order:
        raise MermaidError("the flowchart has no nodes")
    spec = {"type": "graph", "direction": "right" if direction == "LR" else "down", "nodes": []}
    for nid in flow.order:
        n = flow.nodes[nid]
        item = {"id": nid, "label": n["label"]}
        if n["lines"]:
            item["lines"] = n["lines"]
        if n["shape"] and n["shape"] != "box":
            item["shape"] = n["shape"]
        if n["group"]:
            item["group"] = n["group"]
        spec["nodes"].append(item)
    used = {n["group"] for n in flow.nodes.values()}
    groups = [g for g in flow.groups if g["id"] in used]
    for g in flow.groups:
        if g["id"] not in used:
            notes.append("subgraph %s has no nodes and is left out" % g["id"])
    if groups:
        spec["groups"] = groups
    if flow.edges:
        spec["edges"] = flow.edges
    return spec


MESSAGE = re.compile(r"^([A-Za-z0-9_]+)\s*(-->>|->>|--\)|-\)|-->|->)\s*([+-]?)\s*([A-Za-z0-9_]+)\s*(?::(.*))?$")


def _sequence(lines, notes):
    parts, order, msgs, title, number_messages = {}, [], [], "", False

    def participant(pid, label=None):
        if pid not in parts:
            parts[pid] = {"id": pid, "label": pid}
            order.append(pid)
        if label:
            text, more = _split_text(label)
            parts[pid]["label"] = text
            if more:
                parts[pid]["lines"] = more

    for number, s in lines:
        word = s.split()[0]
        if word in ("participant", "actor"):
            m = re.match(r"^(?:participant|actor)\s+([A-Za-z0-9_]+)(?:\s+as\s+(.+))?$", s)
            if not m:
                raise MermaidError("line %d: write participant <id> or participant <id> as <label>" % number)
            participant(m.group(1), m.group(2))
            continue
        if word == "autonumber":
            number_messages = True
            continue
        if word.rstrip(":") == "title":
            title = _clean(s[len("title"):].lstrip(" :"))
            continue
        if word in ("activate", "deactivate"):
            notes.append("line %d: %s is ignored" % (number, word))
            continue
        if re.match(r"^[A-Za-z0-9_]+\s*--?x", s):
            raise MermaidError("line %d: messages ending in x are not supported; use ->> or -->>" % number)
        m = MESSAGE.match(s)
        if not m:
            raise MermaidError("line %d: '%s' is not supported in sequence diagrams here (supported: participant, actor, "
                               "messages such as A->>B: text, autonumber, title)" % (number, word))
        a, op, marker, b, text = m.groups()
        if marker:
            notes.append("line %d: the activation marker %s is ignored" % (number, marker))
        participant(a)
        participant(b)
        label = _clean(text or "").replace("\n", " ")
        if number_messages:
            label = ("%d. %s" % (len(msgs) + 1, label)).strip() if label else str(len(msgs) + 1)
        item = {"from": a, "to": b}
        if label:
            item["label"] = label
        if op.startswith("--"):
            item["line"] = "dashed"
        if op in ("->", "-->"):
            item["head"] = "none"
        msgs.append(item)
    if not order:
        raise MermaidError("the sequence diagram has no participants")
    spec = {"type": "sequence", "participants": [parts[p] for p in order]}
    if title:
        spec["title"] = title
    if msgs:
        spec["messages"] = msgs
    return spec


def parse(source):
    """Return (spec, notes). Raises MermaidError for anything outside the subset."""
    if source.startswith("﻿"):
        source = source[1:]
    lines, notes = [], []
    for number, s in _statements(source):
        if s.startswith("%%{"):
            notes.append("line %d: the init directive is ignored" % number)
            continue
        lines.append((number, s))
    if not lines:
        raise MermaidError("the text holds no diagram")
    header = lines[0]
    kind = header[1].split()[0]
    if kind in ("flowchart", "graph"):
        return _flowchart(lines[1:], header, notes), notes
    if kind == "sequenceDiagram":
        if header[1].strip() != "sequenceDiagram":
            raise MermaidError("line %d: write sequenceDiagram on a line of its own" % header[0])
        return _sequence(lines[1:], notes), notes
    raise MermaidError("line %d: %s diagrams are not supported; use flowchart, graph, or sequenceDiagram" % (header[0], kind))
