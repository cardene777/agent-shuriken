#!/usr/bin/env python3
"""Check a motion-diagram spec and render it into one HTML page.

Usage:
  motion_diagram.py check <spec.json>
  motion_diagram.py render <spec.json> --out <page.html>

A spec lists parts (sources, boxes, checks, people, bins, ends, and parts outside a boundary) and
the lines between them. check prints one line per problem, `<field>: <problem>`, and names the
field, such as `lines[3].to` or `parts[2].keep`. render runs the same checks, writes nothing when
any fails, and otherwise writes one page that loads nothing from the network: the parts laid out in
columns from their lines, and a script that runs cards through the flow once when the page opens.

Text width counts 2 for a CJK character and 1 for any other character. The opening sentence may
be 80 wide, a part name 24, the details and the example of a part 200, a line label 32, a boundary
name 40, and the unit of the counts, shown beside the opening sentence, 8.

Exit codes:
  0  the spec is fine (check), or the page was written (render)
  1  the spec has problems; each is printed
  2  called wrongly, or the spec is not readable JSON

Uses only the Python standard library, reads only the spec and the files next to this script,
writes only the page it is given, runs no other program, and connects to nothing.
"""

import html
import json
import os
import re
import sys
import unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
TEMPLATES = os.path.join(os.path.dirname(HERE), "templates")

KINDS = ("source", "box", "check", "person", "bin", "end", "outside")
ICONS = ("inbox", "filter", "read", "stack", "person", "archive", "done", "lock", "doc", "feed",
         "code", "chat", "mail", "data", "cloud", "gear", "chart", "clock", "people", "flag",
         "bell", "key", "cart", "globe")
DEFAULT_ICON = {"source": "inbox", "box": "stack", "check": "filter", "person": "person",
                "bin": "archive", "end": "done", "outside": "lock"}
LIMITS = {"title": 80, "name": 24, "details": 200, "example": 200, "label": 32, "boundary": 40,
          "unit": 8}
ID = re.compile(r"^[a-z][a-z0-9-]*$")


def width(text):
    """Display width: 2 for a wide (CJK) character, 1 for any other."""
    return sum(2 if unicodedata.east_asian_width(c) in ("W", "F") else 1 for c in text)


def is_count(value):
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


class Flow:
    """The checked spec with the facts render needs: ranks, lanes, and counts."""

    def __init__(self, spec):
        self.spec = spec
        self.problems = []
        self.parts = {}
        self.index = {}
        self.main = []      # (line index, from, to, line)
        self.drops = []
        self.backs = []
        self.rank = {}
        self.received = {}
        self.out = {}

    def say(self, field, problem):
        self.problems.append("%s: %s" % (field, problem))

    def text(self, value, field, limit, required=False):
        if value is None:
            if required:
                self.say(field, "is required")
            return
        if not isinstance(value, str) or not value.strip():
            self.say(field, "must be text")
            return
        if width(value) > limit:
            self.say(field, "is %d wide; keep it to %d (a CJK character counts 2)" % (width(value), limit))

    def check(self):
        s = self.spec
        if not isinstance(s, dict):
            self.say("spec", "must be a JSON object")
            return self
        if s.get("version") != 1:
            self.say("version", "must be 1")
        if s.get("lang", "en") not in ("en", "ja"):
            self.say("lang", "must be en or ja")
        self.text(s.get("title"), "title", LIMITS["title"], required=True)
        if "unit" in s:
            self.text(s["unit"], "unit", LIMITS["unit"])
        parts = s.get("parts")
        if not isinstance(parts, list) or not parts:
            self.say("parts", "must list at least one part")
            return self
        for i, p in enumerate(parts):
            self.check_part(i, p)
        lines = s.get("lines", [])
        if not isinstance(lines, list):
            self.say("lines", "must be a list")
            return self
        outside = self.check_boundaries(s.get("boundaries", []))
        for i, line in enumerate(lines):
            self.check_line(i, line, outside)
        if self.problems:
            return self
        self.check_order()
        if not self.problems:
            self.check_counts()
        return self

    def check_part(self, i, p):
        field = "parts[%d]" % i
        if not isinstance(p, dict):
            self.say(field, "must be an object")
            return
        pid = p.get("id")
        if not isinstance(pid, str) or not ID.match(pid):
            self.say(field + ".id", "must start with a lowercase letter and use lowercase letters, digits, and -")
            return
        if pid in self.parts:
            self.say(field + ".id", 'is used twice ("%s")' % pid)
            return
        kind = p.get("kind")
        if kind not in KINDS:
            self.say(field + ".kind", "must be one of %s" % ", ".join(KINDS))
            return
        self.parts[pid] = p
        self.index[pid] = i
        self.text(p.get("name"), field + ".name", LIMITS["name"], required=True)
        for key in ("details", "example"):
            if key in p:
                self.text(p[key], "%s.%s" % (field, key), LIMITS[key])
        if "icon" in p and p["icon"] not in ICONS:
            self.say(field + ".icon", "must be one of %s" % ", ".join(ICONS))
        if "count" in p and (kind != "source" or not is_count(p["count"])):
            self.say(field + ".count", "belongs to a source and is a whole number of 0 or more")
        if "keep" in p and (kind not in ("check", "person") or not is_count(p["keep"])):
            self.say(field + ".keep", "belongs to a check or a person and is a whole number of 0 or more")

    def check_boundaries(self, boundaries):
        outside = {}
        if not isinstance(boundaries, list):
            self.say("boundaries", "must be a list")
            return outside
        for i, b in enumerate(boundaries):
            field = "boundaries[%d]" % i
            if not isinstance(b, dict):
                self.say(field, "must be an object")
                continue
            self.text(b.get("name"), field + ".name", LIMITS["boundary"], required=True)
            members = b.get("parts")
            if not isinstance(members, list) or not members:
                self.say(field + ".parts", "must list the parts outside the boundary")
                continue
            for j, pid in enumerate(members):
                part = self.parts.get(pid)
                if part is None:
                    self.say("%s.parts[%d]" % (field, j), 'no part is named "%s"' % pid)
                elif part["kind"] != "outside":
                    self.say("%s.parts[%d]" % (field, j), 'part "%s" must have the kind outside' % pid)
                else:
                    outside[pid] = b.get("name", "")
        for pid, p in self.parts.items():
            if p["kind"] == "outside" and pid not in outside:
                self.say("parts[%d]" % self.index[pid], "an outside part must be listed by a boundary")
        return outside

    def check_line(self, i, line, outside):
        field = "lines[%d]" % i
        if not isinstance(line, dict):
            self.say(field, "must be an object")
            return
        ends = []
        for end in ("from", "to"):
            pid = line.get(end)
            if pid not in self.parts:
                self.say("%s.%s" % (field, end), 'no part is named "%s"' % pid)
            ends.append(pid)
        if len([e for e in ends if e in self.parts]) < 2:
            return
        a, b = ends
        if "label" in line:
            self.text(line["label"], field + ".label", LIMITS["label"])
        for pid in ends:
            if pid in outside:
                self.say(field, 'crosses the boundary "%s"; nothing flows to or from a part outside it' % outside[pid])
                return
        drop, back = bool(line.get("drop")), bool(line.get("back"))
        if drop and back:
            self.say(field, "is a drop or a line back, not both")
            return
        kinds = (self.parts[a]["kind"], self.parts[b]["kind"])
        if drop:
            if kinds[0] not in ("check", "person") or kinds[1] != "bin":
                self.say(field, "a drop goes from a check or a person to a bin")
                return
            self.drops.append((i, a, b, line))
            return
        if back:
            self.backs.append((i, a, b, line))
            return
        if kinds[1] == "bin":
            self.say(field, 'a line to a bin is a drop; give it "drop": true')
            return
        if kinds[0] in ("bin", "end"):
            self.say(field + ".from", "a %s sends no cards on" % kinds[0])
            return
        if kinds[1] == "source":
            self.say(field + ".to", "a source starts the flow and receives no cards")
            return
        if "count" in line and not is_count(line["count"]):
            self.say(field + ".count", "must be a whole number of 0 or more")
            return
        self.main.append((i, a, b, line))

    def check_order(self):
        """Ranks by the longest path over the main lines; a cycle needs a line back."""
        incoming = {pid: [] for pid in self.parts}
        outgoing = {pid: [] for pid in self.parts}
        for i, a, b, line in self.main:
            incoming[b].append((i, a, line))
            outgoing[a].append((i, b, line))
        self.incoming, self.outgoing = incoming, outgoing
        flow_parts = [pid for pid, p in self.parts.items() if p["kind"] not in ("outside", "bin")]
        pending = {pid: len(incoming[pid]) for pid in flow_parts}
        ready = [pid for pid in flow_parts if pending[pid] == 0]
        order = []
        rank = {pid: 0 for pid in ready}
        while ready:
            pid = ready.pop(0)
            order.append(pid)
            for _, b, _ in outgoing[pid]:
                rank[b] = max(rank.get(b, 0), rank[pid] + 1)
                pending[b] -= 1
                if pending[b] == 0:
                    ready.append(b)
        if len(order) < len(flow_parts):
            self.say("lines", 'the lines go round without a line back; give the line that returns "back": true')
            return
        self.order, self.rank = order, rank
        for i, a, b, line in self.backs:
            if self.parts[a]["kind"] in ("outside", "bin") or self.parts[b]["kind"] in ("outside", "bin"):
                self.say("lines[%d]" % i, "a line back joins two parts of the flow")
            elif rank[b] >= rank[a]:
                self.say("lines[%d]" % i, 'a line back points to an earlier part, but "%s" does not come before "%s"' % (b, a))

    def numbered(self):
        return any(p["kind"] in ("check", "person") for p in self.parts.values()) or \
            any("count" in p for p in self.parts.values())

    def check_counts(self):
        if not self.numbered():
            return
        for pid, p in self.parts.items():
            field = "parts[%d]" % self.index[pid]
            if p["kind"] == "source" and "count" not in p:
                self.say(field + ".count", "a flow with numbers needs a count on every source")
            if p["kind"] in ("check", "person") and "keep" not in p:
                self.say(field + ".keep", "a check or a person needs keep, the number it lets through")
        if self.problems:
            return
        received = {pid: 0 for pid in self.parts}
        out = {}
        for pid in self.order:
            p = self.parts[pid]
            if p["kind"] == "source":
                out[pid] = p["count"]
            elif p["kind"] in ("check", "person"):
                if p["keep"] > received[pid]:
                    self.say("parts[%d].keep" % self.index[pid],
                             "keeps %d of the %d cards it receives" % (p["keep"], received[pid]))
                    return
                out[pid] = p["keep"]
            else:
                out[pid] = received[pid]
            sends = self.outgoing[pid]
            if len(sends) == 1:
                received[sends[0][1]] += out[pid]
            elif len(sends) > 1:
                total = 0
                for i, b, line in sends:
                    if "count" not in line:
                        self.say("lines[%d].count" % i, '"%s" sends to more than one part, so each of its lines needs a count' % pid)
                        return
                    total += line["count"]
                    received[b] += line["count"]
                if total > out[pid]:
                    self.say("lines[%d].count" % sends[-1][0], '"%s" sends %d but has %d' % (pid, total, out[pid]))
                    return
        for i, a, b, line in self.drops:
            received[b] += received[a] - out[a]
        self.received, self.out = received, out

    def layout(self):
        """Columns from the ranks, and the lane of each part: main, or side for a source that joins
        midway and for a bin. A side part in the same column as another side part goes one lane lower."""
        place = {}
        for pid in self.order:
            p = self.parts[pid]
            rank = self.rank[pid]
            lane = "main"
            if p["kind"] == "source" and self.outgoing[pid]:
                target = self.rank[self.outgoing[pid][0][1]]
                if target >= 2:
                    rank, lane = target, "side"
            place[pid] = {"rank": rank, "lane": lane, "span": 1}
        for pid, p in self.parts.items():
            if p["kind"] == "bin":
                senders = [self.rank[a] for _, a, b, _ in self.drops if b == pid]
                start = min(senders) if senders else 0
                end = max(senders) if senders else 0
                place[pid] = {"rank": start, "lane": "side", "span": end - start + 1}
        rows = []  # side rows: list of occupied column sets
        for pid in self.order + [q for q in self.parts if self.parts[q]["kind"] == "bin"]:
            spot = place.get(pid)
            if not spot or spot["lane"] != "side":
                continue
            cols = set(range(spot["rank"], spot["rank"] + spot["span"]))
            for r, used in enumerate(rows):
                if not used & cols:
                    used |= cols
                    spot["row"] = r + 2
                    break
            else:
                rows.append(set(cols))
                spot["row"] = len(rows) + 1
        for spot in place.values():
            spot.setdefault("row", 1)
        columns = max([s["rank"] + s["span"] for s in place.values()] or [1])
        return place, columns, len(rows) + 1


def esc(text):
    return html.escape(text, quote=True)


def cells_html(flow, place):
    cells = {}
    for pid in flow.order + [q for q in flow.parts if flow.parts[q]["kind"] == "bin"]:
        spot = place[pid]
        cells.setdefault((spot["rank"], spot["row"], spot["span"]), []).append(pid)
    side_ranks = set()
    for (rank, row, span), pids in cells.items():
        if row > 1:
            side_ranks |= set(range(rank, rank + span))
    out = []
    for (rank, row, span), pids in sorted(cells.items()):
        wide = row == 1 and len(pids) > 1 and rank not in side_ranks
        attrs = ' data-wide' if wide else ''
        out.append('<div class="md-cell" style="--r:%d;--l:%d;--span:%d"%s>' % (rank, row, span, attrs))
        for pid in pids:
            out.append(part_html(flow, pid, place[pid]))
        out.append("</div>")
    return "\n".join(out)


def part_html(flow, pid, spot):
    p = flow.parts[pid]
    icon = p.get("icon", DEFAULT_ICON[p["kind"]])
    count = ""
    if flow.numbered() and p["kind"] != "outside":
        count = '<span class="md-count" data-count-for="%s">0</span>' % esc(pid)
    rank = ' data-rank="%d" data-lane="%s"' % (spot["rank"], "main" if spot["lane"] == "main" else "side") if spot else ""
    return ('<button type="button" class="md-part" data-part="%s"%s data-kind="%s" aria-pressed="false">'
            '<span class="md-icon" data-icon="%s"></span><span class="md-name">%s</span>%s</button>'
            % (esc(pid), rank, p["kind"], icon, esc(p["name"]), count))


def boundary_html(flow):
    out = []
    for i, b in enumerate(flow.spec.get("boundaries", [])):
        members = "".join(part_html(flow, pid, None) for pid in b["parts"])
        out.append('<div class="md-boundary" data-boundary="%d"><span class="md-icon" data-icon="lock"></span>'
                   '<span class="md-bname">%s</span><div class="md-outside">%s</div></div>'
                   % (i, esc(b["name"]), members))
    return "\n".join(out)


def finals(flow):
    """The number each part shows at the end of the run."""
    if not flow.numbered():
        return {}
    result = {}
    for pid, p in flow.parts.items():
        if p["kind"] == "source":
            result[pid] = p["count"]
        elif p["kind"] in ("check", "person"):
            result[pid] = p["keep"]
        elif p["kind"] != "outside":
            result[pid] = flow.received[pid]
    return result


def page(flow):
    spec = flow.spec
    place, columns, lanes = flow.layout()
    with open(os.path.join(TEMPLATES, "page.html"), encoding="utf-8") as f:
        template = f.read()
    with open(os.path.join(TEMPLATES, "ui.json"), encoding="utf-8") as f:
        ui = json.load(f)
    lang = spec.get("lang", "en")
    data = {
        "lang": lang,
        "numbered": flow.numbered(),
        "columns": columns,
        "parts": {pid: {"kind": p["kind"], "name": p["name"], "details": p.get("details", ""),
                        "example": p.get("example", ""), "keep": p.get("keep"), "count": p.get("count"),
                        "received": flow.received.get(pid)}
                  for pid, p in flow.parts.items()},
        "order": flow.order,
        "main": [{"from": a, "to": b, "count": line.get("count")} for _, a, b, line in flow.main],
        "drops": [{"from": a, "to": b} for _, a, b, _ in flow.drops],
        "backs": [{"from": a, "to": b, "label": line.get("label", "")} for _, a, b, line in flow.backs],
        "finals": finals(flow),
    }
    def script_json(value):
        return json.dumps(value, ensure_ascii=False).replace("</", "<\\/")
    back_attr = ' data-back="%d"' % len(flow.backs)
    fills = {
        "{{lang}}": lang,
        "{{title}}": esc(spec["title"]),
        "{{unit}}": ' <span class="md-unit">%s</span>' % esc(spec["unit"]) if spec.get("unit") else "",
        "{{cells}}": cells_html(flow, place),
        "{{boundaries}}": boundary_html(flow),
        "{{columns}}": str(columns),
        "{{lanes}}": str(lanes),
        "{{back}}": back_attr,
        "{{replay}}": esc(ui[lang]["replay"]),
        "{{hint}}": esc(ui[lang]["hint"]),
        "{{spec}}": script_json(data),
        "{{ui}}": script_json(ui),
    }
    # One pass, so text from the spec that looks like a placeholder is never filled in.
    return re.sub(r"\{\{[a-z]+\}\}", lambda m: fills.get(m.group(0), m.group(0)), template)


def load(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        print("motion-diagram: cannot read %s: %s" % (path, e), file=sys.stderr)
        sys.exit(2)


def main(argv):
    if len(argv) < 2 or argv[0] not in ("check", "render"):
        print((__doc__ or "").strip().split("\n\n")[1], file=sys.stderr)
        return 2
    command, path = argv[0], argv[1]
    flow = Flow(load(path)).check()
    if flow.problems:
        for line in flow.problems:
            print(line)
        return 1
    if command == "check":
        return 0
    if len(argv) != 4 or argv[2] != "--out":
        print("motion-diagram: render needs --out <page.html>", file=sys.stderr)
        return 2
    text = page(flow)
    out = argv[3]
    tmp = out + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, out)
    print("wrote %s" % out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
