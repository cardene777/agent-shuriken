#!/usr/bin/env bash
# Tests for excalidraw_diagram.py in throwaway folders under a throwaway HOME.
# A stand-in browser (EXCALIDRAW_DIAGRAM_BROWSER) writes a blank PNG of the requested size,
# so no real browser runs and nothing reaches the network.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../scripts/excalidraw_diagram.py"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }

export HOME="$T/home"
export MOCK_DIR="$T/mock"
export MOCK_LOG="$T/mock.log"
export EXCALIDRAW_DIAGRAM_BROWSER="$T/bin/browser"
export PYTHONDONTWRITEBYTECODE=1
mkdir -p "$HOME" "$T/bin" "$MOCK_DIR" "$T/out"
: > "$MOCK_LOG"

# A blank grayscale PNG of a given size.
cat > "$MOCK_DIR/png.py" <<'PY'
import struct, sys, zlib
w, h, out = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
def chunk(kind, body):
    return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)
raw = b"".join(b"\x00" + b"\xff" * w for _ in range(h))
with open(out, "wb") as f:
    f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 0, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))
PY
# The stand-in browser: logs its arguments and writes the screenshot. FAKE_EXTRA widens it.
cat > "$T/bin/browser" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_LOG"
for a in "$@"; do
  case "$a" in
    --window-size=*) ws="${a#*=}" ;;
    --force-device-scale-factor=*) sc="${a#*=}" ;;
    --screenshot=*) out="${a#*=}" ;;
    --user-data-dir=*) printf 'profile %s\n' "${a#*=}" >> "$MOCK_LOG" ;;
  esac
done
python3 "$MOCK_DIR/png.py" "$(( ${ws%,*} * sc + ${FAKE_EXTRA:-0} ))" "$(( ${ws#*,} * sc ))" "$out"
SH
chmod +x "$T/bin/browser"

# Independent checks of a scene, written apart from the plugin's own rules.
cat > "$MOCK_DIR/verify.py" <<'PY'
import json, math, sys
doc = json.load(open(sys.argv[1]))
what = sys.argv[2]
els = [e for e in doc["elements"] if not e.get("isDeleted")]
by = {e["id"]: e for e in els}
shapes = [e for e in els if e["type"] in ("rectangle", "ellipse", "diamond")]
zones = [e for e in shapes if e["id"].startswith("zone:")]
nodes = [e for e in shapes if not e["id"].startswith("zone:")]
arrows = [e for e in els if e["type"] == "arrow"]
def box(e): return (e["x"], e["y"], e["x"] + e["width"], e["y"] + e["height"])
def pts(e): return [(e["x"] + p[0], e["y"] + p[1]) for p in e["points"]]
def seg_hits(p, q, b, pad=0):
    l, t, r, bt = b[0] + pad, b[1] + pad, b[2] - pad, b[3] - pad
    if p[1] == q[1]:
        return t < p[1] < bt and min(p[0], q[0]) < r and max(p[0], q[0]) > l
    if p[0] == q[0]:
        return l < p[0] < r and min(p[1], q[1]) < bt and max(p[1], q[1]) > t
    return True
def dist(p, b):
    dx = max(b[0] - p[0], 0, p[0] - b[2]); dy = max(b[1] - p[1], 0, p[1] - b[3])
    return math.hypot(dx, dy)
ok = True
if what == "format":
    ok = doc["type"] == "excalidraw" and doc["version"] == 2 and len(by) == len(els)
    need = {"id", "type", "x", "y", "width", "height", "angle", "strokeColor", "backgroundColor", "fillStyle",
            "strokeWidth", "strokeStyle", "roughness", "opacity", "groupIds", "roundness", "seed", "version",
            "versionNonce", "isDeleted", "boundElements", "updated", "link", "locked"}
    ok = ok and all(need <= set(e) for e in els)
    ok = ok and all({"text", "originalText", "fontSize", "fontFamily", "textAlign", "verticalAlign", "containerId", "lineHeight"} <= set(e) for e in els if e["type"] == "text")
    ok = ok and all(e["points"][0] == [0, 0] for e in els if e["type"] in ("arrow", "line"))
elif what == "bound":
    for a in arrows:
        for k in ("startBinding", "endBinding"):
            t = by.get((a.get(k) or {}).get("elementId"))
            ok = ok and t is not None and {"id": a["id"], "type": "arrow"} in (t["boundElements"] or [])
elif what == "centered":
    for t in els:
        if t["type"] == "text" and t["containerId"]:
            c = by[t["containerId"]]
            ok = ok and abs(t["x"] + t["width"] / 2 - c["x"] - c["width"] / 2) <= 1 and abs(t["y"] + t["height"] / 2 - c["y"] - c["height"] / 2) <= 1
elif what == "apart":
    for i, a in enumerate(nodes):
        for b in nodes[i + 1:]:
            if set(a["groupIds"]) & set(b["groupIds"]):
                continue
            A, B = box(a), box(b)
            ok = ok and max(B[0] - A[2], A[0] - B[2], B[1] - A[3], A[1] - B[3]) >= 40
elif what == "ends":
    for a in arrows:
        p = pts(a)
        for k, q in (("startBinding", p[0]), ("endBinding", p[-1])):
            ok = ok and abs(dist(q, box(by[a[k]["elementId"]])) - 5) < 0.01
elif what == "straight":
    for a in arrows:
        p = pts(a)
        ok = ok and (len(p) == 2 or a["roundness"] is None) and all(u[0] == v[0] or u[1] == v[1] for u, v in zip(p, p[1:]))
elif what == "clear":
    for a in arrows:
        for p, q in zip(pts(a), pts(a)[1:]):
            ok = ok and not any(seg_hits(p, q, box(n)) for n in nodes)
elif what == "labels":
    labels = [e for e in els if e["type"] == "text" and e["id"].endswith(":label") and not e["id"].startswith("zone:")]
    ok = len(labels) == int(sys.argv[3])
    for t in labels:
        b = box(t)
        for a in arrows:
            ok = ok and not any(seg_hits(p, q, b) for p, q in zip(pts(a), pts(a)[1:]))
        ok = ok and not any(max(box(n)[0] - b[2], b[0] - box(n)[2], box(n)[1] - b[3], b[1] - box(n)[3]) < 0 for n in nodes)
elif what == "zones":
    for z in zones:
        members = [n for n in nodes if n["id"].startswith("node:") and all(
            box(z)[0] + 50 <= box(n)[0] and box(n)[2] <= box(z)[2] - 50 and box(z)[1] + 50 <= box(n)[1] and box(n)[3] <= box(z)[3] - 50 for _ in [0])]
        others = [n for n in nodes if n not in members]
        ok = ok and members and not any(max(box(z)[0] - box(n)[2], box(n)[0] - box(z)[2], box(z)[1] - box(n)[3], box(n)[1] - box(z)[3]) < 40 for n in others)
elif what == "crossings":
    # Points where two arrows cross or touch; arrows here run only horizontally and vertically.
    def cells(e):
        out = set()
        for p, q in zip(pts(e), pts(e)[1:]):
            n = int(round(max(abs(q[0] - p[0]), abs(q[1] - p[1]))))
            for k in range(n + 1):
                out.add((round(p[0] + (q[0] - p[0]) * k / max(n, 1)), round(p[1] + (q[1] - p[1]) * k / max(n, 1))))
        return out
    def trunk(a, b):
        # Cells two arrows share as a trunk: from their common start to where they split.
        pa, pb = pts(a), pts(b)
        if pa[0] != pb[0] or (a.get("startBinding") or {}).get("elementId") != (b.get("startBinding") or {}).get("elementId"):
            return set()
        k = 0
        while k + 1 < min(len(pa), len(pb)) and pa[k + 1] == pb[k + 1]:
            k += 1
        if k + 1 >= len(pa) or k + 1 >= len(pb):
            return set()
        o, na, nb = pa[k], pa[k + 1], pb[k + 1]
        near = min((na, nb), key=lambda q: abs(q[0] - o[0]) + abs(q[1] - o[1]))
        same = (na[0] - o[0]) * (nb[1] - o[1]) == (na[1] - o[1]) * (nb[0] - o[0]) and (na[0] - o[0]) * (nb[0] - o[0]) + (na[1] - o[1]) * (nb[1] - o[1]) > 0
        shared = {"points": pa[:k + 1] + ([near] if same else []), "x": a["x"], "y": a["y"]}
        return cells({"x": 0, "y": 0, "points": [list(q) for q in shared["points"]]}) if len(shared["points"]) > 1 else {(round(o[0]), round(o[1]))}
    n = sum(1 for i, a in enumerate(arrows) for b in arrows[i + 1:] if (cells(a) & cells(b)) - trunk(a, b))
    print(n); sys.exit(0)
elif what == "zone-gap":
    labels = [e for e in els if e["type"] == "text" and e["id"].startswith("edge:")]
    for t in labels:
        b = box(t)
        for z in zones:
            Z = box(z)
            inside = min(b[0] - Z[0], b[1] - Z[1], Z[2] - b[2], Z[3] - b[3])
            outside = max(Z[0] - b[2], b[0] - Z[2], Z[1] - b[3], b[1] - Z[3])
            ok = ok and (inside >= float(sys.argv[3]) or outside >= float(sys.argv[3]))
elif what == "center-of":
    e = by[sys.argv[3]]; print("%g %g" % (e["x"] + e["width"] / 2, e["y"] + e["height"] / 2)); sys.exit(0)
sys.exit(0 if ok else 1)
PY
V() { python3 "$MOCK_DIR/verify.py" "$@"; }
run() { python3 "$SCRIPT" "$@"; }

cat > "$T/out/shop.diagram.json" <<'JSON'
{
  "title": "Checkout",
  "nodes": [
    {"id": "web", "label": "Web app", "lines": ["Next.js", "port 3000"], "color": "blue"},
    {"id": "api", "label": "API gateway", "lines": ["REST"], "color": "violet"},
    {"id": "orders", "label": "Order service", "lines": ["POST /orders"], "group": "svc", "color": "green"},
    {"id": "pay", "label": "Payment service", "lines": ["POST /charges"], "group": "svc", "color": "green"},
    {"id": "db", "label": "orders", "lines": ["id uuid", "total int"], "shape": "table", "color": "orange"},
    {"id": "ok", "label": "Paid?", "shape": "diamond"}
  ],
  "edges": [
    {"from": "web", "to": "api", "label": "HTTPS"},
    {"from": "api", "to": "orders"},
    {"from": "api", "to": "pay", "line": "dashed"},
    {"from": "orders", "to": "db", "label": "SQL"},
    {"from": "pay", "to": "ok"},
    {"from": "ok", "to": "web", "label": "retry", "head": "both"}
  ],
  "groups": [{"id": "svc", "label": "Services", "color": "green"}]
}
JSON
S="$T/out/shop"

# --- build
out="$(run build "$S.diagram.json")"; rc=$?
check "build exits 0" '[ "$rc" = 0 ]'
check "build writes the .excalidraw, .svg, and .png files" '[ -s "$S.excalidraw" ] && [ -s "$S.svg" ] && [ -s "$S.png" ]'
check "build reports that the checks found no problems" 'printf "%s\n" "$out" | grep -q "^No problems found."'
check "the scene has the type, version, and fields Excalidraw writes" 'V "$S.excalidraw" format'
check "every arrow is bound at both ends and each shape lists its arrows" 'V "$S.excalidraw" bound'
check "text bound to a shape is centered in it" 'V "$S.excalidraw" centered'
check "shapes are at least 40 px apart" 'V "$S.excalidraw" apart'
check "arrow ends stop 5 px outside the shapes they connect" 'V "$S.excalidraw" ends'
check "arrows run in horizontal and vertical stretches with no rounding" 'V "$S.excalidraw" straight'
check "no arrow passes through a shape" 'V "$S.excalidraw" clear'
check "all 3 arrow labels are placed off every line and off every shape" 'V "$S.excalidraw" labels 3'
check "a zone keeps 50 px around its nodes and 40 px from other shapes" 'V "$S.excalidraw" zones'
check "check accepts the built scene" 'run check "$S.excalidraw" >/dev/null'
check "the SVG parses as XML" 'python3 -c "import sys, xml.etree.ElementTree as E; E.parse(sys.argv[1])" "$S.svg"'
svg_size="$(sed -nE '1s/.*width="([0-9]+)" height="([0-9]+)".*/\1 \2/p' "$S.svg")"
png_size="$(python3 -c "import struct,sys; d=open(sys.argv[1],'rb').read(); print('%d %d' % tuple(x // 2 for x in struct.unpack('>II', d[16:24])))" "$S.png")"
check "the PNG is twice the size of the SVG" '[ -n "$svg_size" ] && [ "$svg_size" = "$png_size" ]'
check "the PNG carries the plugin's marker" 'grep -aq "excalidraw-diagram sha256:" "$S.png"'
check "the browser runs headless and cannot resolve host names" \
  'grep -q -- "--headless=new" "$MOCK_LOG" && grep -q -- "--host-resolver-rules=MAP \* ~NOTFOUND" "$MOCK_LOG"'
profile="$(sed -n 's/^profile //p' "$MOCK_LOG" | tail -1)"
check "the browser profile is removed afterwards" '[ -n "$profile" ] && [ ! -e "$profile" ]'
check "the diamond holds its text" 'run check "$S.excalidraw" | grep -q "^No problems"'
cp "$S.excalidraw" "$T/first.excalidraw"
run build "$S.diagram.json" >/dev/null; rc=$?
check "building again replaces the plugin's own unchanged files" '[ "$rc" = 0 ]'
check "the same spec gives the same file" 'cmp -s "$S.excalidraw" "$T/first.excalidraw"'

# --- overwrite protection
python3 -c "import json,sys; d=json.load(open(sys.argv[1])); d.pop('generator'); json.dump(d, open(sys.argv[1], 'w'))" "$S.excalidraw"
cp "$S.excalidraw" "$T/edited.excalidraw"
run build "$S.diagram.json" >/dev/null 2>"$T/err"; rc=$?
check "a scene saved by the editor is not replaced: exit 3" '[ "$rc" = 3 ] && grep -q "shop.excalidraw" "$T/err"'
check "the edited scene is left as it was" 'cmp -s "$S.excalidraw" "$T/edited.excalidraw"'
run build "$S.diagram.json" --replace >/dev/null; rc=$?
check "--replace replaces it" '[ "$rc" = 0 ] && cmp -s "$S.excalidraw" "$T/first.excalidraw"'
python3 -c "import json,sys; d=json.load(open(sys.argv[1])); d['elements'][0]['x'] += 1; json.dump(d, open(sys.argv[1], 'w'))" "$S.excalidraw"
run build "$S.diagram.json" >/dev/null 2>&1; rc=$?
check "a scene changed by hand after it was written is not replaced" '[ "$rc" = 3 ]'
run build "$S.diagram.json" --replace >/dev/null
printf 'not mine\n' > "$T/out/other.png"
cp "$S.diagram.json" "$T/out/other.diagram.json"
run build "$T/out/other.diagram.json" >/dev/null 2>&1; rc=$?
check "a PNG the plugin did not write is not replaced, and nothing is written" \
  '[ "$rc" = 3 ] && [ ! -e "$T/out/other.excalidraw" ] && [ "$(cat "$T/out/other.png")" = "not mine" ]'
printf '<svg/>\n' > "$T/out/shop.svg"
run build "$S.diagram.json" >/dev/null 2>&1; rc=$?
check "an SVG changed after it was written is not replaced" '[ "$rc" = 3 ]'
run build "$S.diagram.json" --replace >/dev/null

# --- render
cp "$S.excalidraw" "$T/out/edited.excalidraw"
python3 -c "import json,sys; d=json.load(open(sys.argv[1])); d.pop('generator'); json.dump(d, open(sys.argv[1], 'w'))" "$T/out/edited.excalidraw"
cp "$T/out/edited.excalidraw" "$T/edited-copy.excalidraw"
run render "$T/out/edited.excalidraw" >/dev/null; rc=$?
check "render writes the SVG and PNG of an edited scene" '[ "$rc" = 0 ] && [ -s "$T/out/edited.svg" ] && [ -s "$T/out/edited.png" ]'
check "render leaves the scene itself unchanged" 'cmp -s "$T/out/edited.excalidraw" "$T/edited-copy.excalidraw"'
run render "$T/out/edited.excalidraw" >/dev/null; rc=$?
check "render replaces its own earlier SVG and PNG" '[ "$rc" = 0 ]'

# --- PNG fallbacks
out="$(EXCALIDRAW_DIAGRAM_BROWSER=none run build "$S.diagram.json" --name nobrowser)"; rc=$?
check "without a browser the PNG is skipped, the rest is written, and the exit code is 0" \
  '[ "$rc" = 0 ] && printf "%s\n" "$out" | grep -q "^PNG skipped:" && [ -s "$T/out/nobrowser.svg" ] && [ ! -e "$T/out/nobrowser.png" ]'
EXCALIDRAW_DIAGRAM_BROWSER=none run build "$S.diagram.json" --name required --png require >/dev/null; rc=$?
check "--png require exits 4 when no PNG can be made, after writing the scene and SVG" \
  '[ "$rc" = 4 ] && [ -s "$T/out/required.excalidraw" ] && [ -s "$T/out/required.svg" ]'
out="$(FAKE_EXTRA=3 run build "$S.diagram.json" --name wrongsize)"
check "a screenshot of the wrong size is not kept" \
  'printf "%s\n" "$out" | grep -q "PNG skipped: the browser wrote a" && [ ! -e "$T/out/wrongsize.png" ]'
out="$(EXCALIDRAW_DIAGRAM_BROWSER="$T/missing" run build "$S.diagram.json" --name missing)"
check "a browser path that does not exist is reported" 'printf "%s\n" "$out" | grep -q "is not an executable file"'

# --- bad input
printf '{"nodes": [{"id": "a", "label": "A", "colour": "red"}], "edges": [{"from": "a", "to": "b"}]}\n' > "$T/bad.json"
run build "$T/bad.json" >/dev/null 2>"$T/err"; rc=$?
check "a spec with an unknown key and a missing node exits 2 and names both" \
  '[ "$rc" = 2 ] && grep -q "unknown key \"colour\"" "$T/err" && grep -q "edges\[0\].to: \"b\" is not the id of a node" "$T/err"'
check "nothing is written for a bad spec" '[ ! -e "$T/bad.excalidraw" ]'
printf '{not json' > "$T/broken.json"
run build "$T/broken.json" >/dev/null 2>&1; rc=$?
check "invalid JSON exits 2" '[ "$rc" = 2 ]'
run build "$S.diagram.json" --name "../x" >/dev/null 2>&1; rc=$?
check "--name with a folder in it exits 2" '[ "$rc" = 2 ]'
run check "$T/broken.json" >/dev/null 2>&1; rc=$?
check "check exits 2 for a file that is not a scene" '[ "$rc" = 2 ]'

# --- the checks catch broken scenes
mutate() {  # mutate <name> <python statements on d, with helpers el(id) and pts(id, list)>
  python3 - "$S.excalidraw" "$T/$1.excalidraw" "$2" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
els = {e["id"]: e for e in d["elements"]}
def el(i): return els[i]
exec(sys.argv[3])
json.dump(d, open(sys.argv[2], "w"))
PY
}
expect() {  # expect <name> <rule>
  run check "$T/$1.excalidraw" > "$T/$1.out" 2>&1
  local rc=$?
  [ "$rc" = 1 ] && grep -q "^  $2: " "$T/$1.out"
}
mutate overlap 'el("node:pay")["x"] = el("node:orders")["x"] + 20'
check "check finds overlapping shapes" 'expect overlap overlap'
mutate spacing 'el("node:pay")["x"] = el("node:orders")["x"] + el("node:orders")["width"] + 20; el("node:pay:text")["x"] = el("node:pay")["x"] + (el("node:pay")["width"] - el("node:pay:text")["width"]) / 2'
check "check finds shapes closer than 40 px" 'expect spacing spacing'
mutate fit 'el("node:api:text")["width"] = 400; el("node:api:text")["x"] = el("node:api")["x"] + el("node:api")["width"] / 2 - 200'
check "check finds text wider than its shape" 'expect fit text-fit'
mutate center 'el("node:api:text")["y"] += 9'
check "check finds text that is not centered in its shape" 'expect center text-center'
mutate font 'el("edge:0:label")["fontSize"] = 12'
check "check finds text under 16 px" 'expect font font-size'
mutate through 'a = el("edge:0"); a["points"] = [[0, 0], [0, 400]]; a["height"] = 400'
check "check finds an arrow that passes through a shape" 'expect through arrow-through'
mutate end 'a = el("edge:0"); a["points"][-1][1] += 20; a["height"] += 20'
check "check finds an arrow end inside its shape" 'expect end arrow-end'
mutate unbound 'el("edge:0")["endBinding"] = None; el("node:api")["boundElements"] = [b for b in el("node:api")["boundElements"] if b["id"] != "edge:0"]'
check "check finds an arrow that ends next to a shape without being bound to it" 'expect unbound unbound'
mutate curve 'el("edge:1")["roundness"] = {"type": 2}'
check "check finds a bent arrow that Excalidraw would draw as a curve" 'expect curve curve'
mutate label 'l = el("edge:0:label"); a = el("edge:0"); l["x"] = a["x"] - l["width"] / 2'
check "check finds a label crossed by its arrow" 'expect label label-on-line'
mutate overlapline 'b = el("edge:1"); a = el("edge:2"); b["x"], b["y"], b["points"], b["width"], b["height"] = a["x"], a["y"], [list(p) for p in a["points"]], a["width"], a["height"]'
check "check finds two arrows running along the same line" 'expect overlapline arrow-overlap'
mutate reference 'el("edge:0")["startBinding"]["elementId"] = "node:gone"'
check "check finds a binding to an element that does not exist" 'expect reference reference'
mutate zone 'z = el("zone:svc"); z["x"] += 30; z["width"] -= 30'
check "check finds a zone that holds its nodes with less than 50 px" 'expect zone zone-padding'

# --- layout rules
cat > "$T/tiers.json" <<'JSON'
{"nodes": [{"id": "a", "label": "A"}, {"id": "b", "label": "B"}, {"id": "c", "label": "C"}, {"id": "d", "label": "D", "tier": 0}],
 "edges": [{"from": "a", "to": "b"}, {"from": "b", "to": "c"}, {"from": "a", "to": "c"}, {"from": "c", "to": "a"}, {"from": "c", "to": "d"}]}
JSON
run build "$T/tiers.json" --png skip >/dev/null; rc=$?
ya="$(V "$T/tiers.excalidraw" center-of node:a)"; yb="$(V "$T/tiers.excalidraw" center-of node:b)"
yc="$(V "$T/tiers.excalidraw" center-of node:c)"; yd="$(V "$T/tiers.excalidraw" center-of node:d)"
check "a loop does not stop the layout, and its first node stays on top" '[ "$rc" = 0 ] && [ "${ya#* }" = "${yd#* }" ]'
check "a node sits one tier below its deepest predecessor" \
  'python3 -c "import sys; a,b,c=(float(v) for v in sys.argv[1:]); sys.exit(0 if a < b < c else 1)" "${ya#* }" "${yb#* }" "${yc#* }"'
check "nodes in one tier keep the order of the spec when reordering saves no crossing" \
  'python3 -c "import sys; sys.exit(0 if float(sys.argv[1]) < float(sys.argv[2]) else 1)" "${ya% *}" "${yd% *}"'
check "an arrow back up the flow enters its target from the right side" \
  'python3 -c "
import json,sys
d=json.load(open(sys.argv[1])); e={x[\"id\"]:x for x in d[\"elements\"]}; a=e[\"edge:4\"]; t=e[\"node:d\"]
end=a[\"x\"]+a[\"points\"][-1][0]
sys.exit(0 if end == t[\"x\"]+t[\"width\"]+5 else 1)" "$T/tiers.excalidraw"'
check "an arrow that answers another runs beside it, into the bottom of its target" \
  'python3 -c "
import json,sys
d=json.load(open(sys.argv[1])); e={x[\"id\"]:x for x in d[\"elements\"]}; a=e[\"edge:3\"]; t=e[\"node:a\"]
end=a[\"y\"]+a[\"points\"][-1][1]
sys.exit(0 if end == t[\"y\"]+t[\"height\"]+5 else 1)" "$T/tiers.excalidraw"'
sed 's/"nodes"/"direction": "right", "nodes"/' "$T/tiers.json" > "$T/right.json"
run build "$T/right.json" --png skip >/dev/null
xa="$(V "$T/right.excalidraw" center-of node:a)"; xb="$(V "$T/right.excalidraw" center-of node:b)"
check "direction right puts the next tier to the right" \
  'python3 -c "import sys; sys.exit(0 if float(sys.argv[1]) < float(sys.argv[2]) else 1)" "${xa% *}" "${xb% *}"'
cat > "$T/wide.json" <<'JSON'
{"nodes": [{"id": "a", "label": "Reader"}, {"id": "b", "label": "Worker"}, {"id": "c", "label": "Writer"}],
 "edges": [{"from": "b", "to": "b", "label": "on failure"}]}
JSON
out="$(run build "$T/wide.json" --png skip)"; rc=$?
check "when a label does not fit, the spacing is widened and the build still passes" \
  '[ "$rc" = 0 ] && printf "%s\n" "$out" | grep -q "^Spacing was widened"'
check "a loop back to the same node is bound to it at both ends" 'V "$T/wide.excalidraw" bound'
cat > "$T/tight.json" <<'JSON'
{"nodes": [{"id": "a", "label": "A", "group": "g"}, {"id": "b", "label": "B", "group": "g"}],
 "edges": [{"from": "a", "to": "b", "label": "this label is far too long to ever fit\nand it has\nmany\nlines\nthat\nkeep\ngoing\non\nand on\nand on"}, {"from": "a", "to": "a"}, {"from": "a", "to": "a"}, {"from": "a", "to": "a"}],
 "groups": [{"id": "g", "label": "G"}]}
JSON
run build "$T/tight.json" --png skip > "$T/tight.out" 2>&1; rc=$?
check "when nothing fits, build exits 1, names the arrow, and writes nothing" \
  '[ "$rc" = 1 ] && grep -q "Nothing was written" "$T/tight.out" && [ ! -e "$T/tight.excalidraw" ]'

# --- crossings, names in bold, and labels near zones
cat > "$T/cross.json" <<'JSON'
{"title": "Checkout", "direction": "down",
 "nodes": [{"id": "web", "label": "Web app", "lines": ["Next.js", "port 4310"], "color": "blue"},
           {"id": "api", "label": "API gateway", "lines": ["REST, JWT"], "color": "violet"},
           {"id": "orders", "label": "Order service", "lines": ["POST /orders"], "group": "svc", "color": "green"},
           {"id": "pay", "label": "Payment service", "lines": ["Stripe"], "group": "svc", "color": "green"},
           {"id": "fail", "label": "Retry queue", "lines": ["3 tries"], "color": "red", "shape": "ellipse"},
           {"id": "db", "label": "orders", "lines": ["id uuid", "total int", "status text"], "shape": "table", "color": "orange"}],
 "edges": [{"from": "web", "to": "api", "label": "HTTPS"}, {"from": "api", "to": "orders"}, {"from": "api", "to": "pay"},
           {"from": "pay", "to": "fail", "label": "on error", "line": "dashed"},
           {"from": "orders", "to": "db", "label": "SQL", "line": "dashed"}],
 "groups": [{"id": "svc", "label": "Services", "color": "green"}]}
JSON
out="$(run build "$T/cross.json")"; rc=$?
xf="$(V "$T/cross.excalidraw" center-of node:fail)"; xd="$(V "$T/cross.excalidraw" center-of node:db)"
check "a tier below a zone is reordered after the nodes inside it, so no arrows cross" \
  '[ "$rc" = 0 ] && [ "$(V "$T/cross.excalidraw" crossings)" = 0 ] && python3 -c "import sys; sys.exit(0 if float(sys.argv[1]) < float(sys.argv[2]) else 1)" "${xd% *}" "${xf% *}"'
check "a build without crossings prints no crossing warning and needs no wider spacing" \
  '! printf "%s\n" "$out" | grep -q "^Warning: crossing" && ! printf "%s\n" "$out" | grep -q "^Spacing was widened"'
check "arrow labels keep at least 8 px from a zone outline, inside or outside" 'V "$T/cross.excalidraw" zone-gap 8'
check "the first line of each shape's text is thickened in the hand-drawn SVG, and nothing else is" \
  '[ "$(grep -o "stroke-width=\"0.7\"[^>]*>[^<]*" "$T/cross.svg" | sed "s/.*>//" | sort | tr "\n" "|")" = "API gateway|Order service|Payment service|Retry queue|Web app|orders|" ]'
run build "$T/cross.json" --theme clean --name cross-clean --png skip >/dev/null
check "the first line of each shape's text is bold in the clean SVG, and nothing else is" \
  '[ "$(grep -o "font-weight=\"bold\"[^>]*>[^<]*" "$T/cross-clean.svg" | sed "s/.*>//" | sort | tr "\n" "|")" = "API gateway|Order service|Payment service|Retry queue|Web app|orders|" ]'
check "detail lines and arrow labels are not bold" \
  'grep -q ">Next.js<" "$T/cross.svg" && ! grep -q "\(bold\|0\.7\)[^>]*>Next.js<" "$T/cross.svg" && ! grep -q "\(bold\|0\.7\)[^>]*>SQL<" "$T/cross.svg"'
printf '{"nodes": [{"id": "a", "label": "Payment reconciliation service"}]}\n' > "$T/boldroom.json"
run build "$T/boldroom.json" --png skip >/dev/null
check "a shape leaves room for its name in bold, which runs wider than the regular text" 'python3 -c "
import json,sys
d=json.load(open(sys.argv[1])); e={x[\"id\"]:x for x in d[\"elements\"]}
sys.exit(0 if e[\"node:a\"][\"width\"] - 40 >= 1.07 * e[\"node:a:text\"][\"width\"] else 1)" "$T/boldroom.excalidraw"'
sed 's/"direction": "down"/"direction": "down", "order": "listed"/' "$T/cross.json" > "$T/listed.json"
out="$(run build "$T/listed.json" --png skip)"; rc=$?
xf="$(V "$T/listed.excalidraw" center-of node:fail)"; xd="$(V "$T/listed.excalidraw" center-of node:db)"
check "\"order\": \"listed\" keeps the order of the spec even when arrows then cross" \
  '[ "$rc" = 0 ] && [ "$(V "$T/listed.excalidraw" crossings)" = 1 ] && python3 -c "import sys; sys.exit(0 if float(sys.argv[1]) < float(sys.argv[2]) else 1)" "${xf% *}" "${xd% *}"'
check "a crossing is printed as a warning that names both arrows, and the build still passes" \
  'printf "%s\n" "$out" | grep -qx "Warning: crossing: the arrow from \"Payment service\" to \"Retry queue\" crosses the arrow from \"Order service\" to \"orders\" once" && printf "%s\n" "$out" | grep -q "^No problems found."'
run check "$T/listed.excalidraw" > "$T/listed.out"; rc=$?
check "check warns about crossing arrows and still exits 0" '[ "$rc" = 0 ] && grep -c "^Warning: crossing:" "$T/listed.out" | grep -qx 1'
cat > "$T/inner.json" <<'JSON'
{"nodes": [{"id": "a1", "label": "Reader", "group": "g"}, {"id": "a2", "label": "Parser", "group": "g"},
           {"id": "b1", "label": "Cache", "group": "g"}, {"id": "b2", "label": "Index", "group": "g"}],
 "edges": [{"from": "a1", "to": "b2"}, {"from": "a2", "to": "b1"}],
 "groups": [{"id": "g", "label": "Search"}]}
JSON
run build "$T/inner.json" --png skip >/dev/null; rc=$?
x1="$(V "$T/inner.excalidraw" center-of node:b1)"; x2="$(V "$T/inner.excalidraw" center-of node:b2)"
check "tiers inside a zone are reordered too" \
  '[ "$rc" = 0 ] && [ "$(V "$T/inner.excalidraw" crossings)" = 0 ] && python3 -c "import sys; sys.exit(0 if float(sys.argv[1]) < float(sys.argv[2]) else 1)" "${x2% *}" "${x1% *}"'
printf '{"order": "sideways", "nodes": [{"id": "a", "label": "A"}]}\n' > "$T/order.json"
run build "$T/order.json" >/dev/null 2>"$T/err"; rc=$?
check "an unknown order exits 2 and names it" '[ "$rc" = 2 ] && grep -q "^  order: \"sideways\" is not one of auto, listed" "$T/err"'
cat > "$T/retry.json" <<'JSON'
{"nodes": [{"id": "s", "label": "Start"}, {"id": "e", "label": "Enter email"}, {"id": "v", "label": "Valid?", "shape": "diamond"},
           {"id": "x", "label": "Show error"}, {"id": "c", "label": "Create user"}],
 "edges": [{"from": "s", "to": "e"}, {"from": "e", "to": "v"}, {"from": "v", "to": "x", "label": "no"},
           {"from": "v", "to": "c", "label": "yes"}, {"from": "x", "to": "e"}]}
JSON
out="$(run build "$T/retry.json" --png skip)"; rc=$?
check "an arrow back from a node on the left goes around the left, crossing nothing" \
  '[ "$rc" = 0 ] && ! printf "%s\n" "$out" | grep -q "^Warning: crossing" && python3 -c "
import json,sys
d=json.load(open(sys.argv[1])); e={x[\"id\"]:x for x in d[\"elements\"]}; a=e[\"edge:4\"]; t=e[\"node:e\"]
sys.exit(0 if a[\"x\"]+a[\"points\"][-1][0] == t[\"x\"]-5 else 1)" "$T/retry.excalidraw"'
cat > "$T/route1.json" <<'JSON'
{"nodes": [{"id": "n0", "label": "Node 0"}, {"id": "n1", "label": "Node 1"}, {"id": "n2", "label": "Node 2"},
           {"id": "n3", "label": "Node 3"}, {"id": "n4", "label": "Node 4"}, {"id": "n5", "label": "Node 5"}],
 "edges": [{"from": "n0", "to": "n1"}, {"from": "n1", "to": "n2"}, {"from": "n2", "to": "n3"}, {"from": "n0", "to": "n4"},
           {"from": "n0", "to": "n5"}, {"from": "n0", "to": "n2"}, {"from": "n4", "to": "n0"}, {"from": "n4", "to": "n1"}]}
JSON
cat > "$T/route2.json" <<'JSON'
{"nodes": [{"id": "n0", "label": "Node 0"}, {"id": "n1", "label": "Node 1"}, {"id": "n2", "label": "Node 2"}, {"id": "n3", "label": "Node 3"},
           {"id": "n4", "label": "Node 4"}, {"id": "n5", "label": "Node 5"}, {"id": "n6", "label": "Node 6"}, {"id": "n7", "label": "Node 7"}],
 "edges": [{"from": "n0", "to": "n1"}, {"from": "n1", "to": "n2"}, {"from": "n1", "to": "n3"}, {"from": "n2", "to": "n4"}, {"from": "n1", "to": "n5"},
           {"from": "n5", "to": "n6"}, {"from": "n5", "to": "n7"}, {"from": "n4", "to": "n0"}, {"from": "n0", "to": "n1"}, {"from": "n6", "to": "n7"}]}
JSON
cat > "$T/route3.json" <<'JSON'
{"direction": "right",
 "nodes": [{"id": "n0", "label": "Node 0"}, {"id": "n1", "label": "Node 1"}, {"id": "n2", "label": "Node 2"}, {"id": "n3", "label": "Node 3"},
           {"id": "n4", "label": "Node 4"}, {"id": "n5", "label": "Node 5"}, {"id": "n6", "label": "Node 6"}, {"id": "n7", "label": "Node 7"}],
 "edges": [{"from": "n0", "to": "n1"}, {"from": "n0", "to": "n2"}, {"from": "n0", "to": "n3"}, {"from": "n3", "to": "n4"}, {"from": "n0", "to": "n5"},
           {"from": "n5", "to": "n6"}, {"from": "n1", "to": "n7"}, {"from": "n6", "to": "n4"}, {"from": "n0", "to": "n3"}, {"from": "n1", "to": "n5"}]}
JSON
for case in route1 route2; do
  out="$(run build "$T/$case.json" --png skip)"; rc=$?
  check "the router steers around arrows it already drew ($case: at most 2 crossing pairs)" \
    '[ "$rc" = 0 ] && [ "$(printf "%s\n" "$out" | grep -c "^Warning: crossing")" -le 2 ]'
done
out="$(run build "$T/route3.json" --png skip)"; rc=$?
check "when steering around arrows puts two on one line, they are routed again before the spacing grows" \
  '[ "$rc" = 0 ] && ! printf "%s\n" "$out" | grep -q "^Spacing was widened"'
mutate touch 'import copy
def free(i, x, y, p):
    a = copy.deepcopy(el("edge:0")); d["elements"].append(a)
    a.update(id=i, x=x, y=y, points=p, width=max(abs(q[0]) for q in p), height=max(abs(q[1]) for q in p),
             startBinding=None, endBinding=None, groupIds=[], boundElements=None)
free("upright", -500, 0, [[0, 0], [0, 200]]); free("near", -600, 100, [[0, 0], [98, 0]]); free("apart", -600, 150, [[0, 0], [90, 0]])'
run check "$T/touch.excalidraw" > "$T/touch.out"; rc=$?
check "check counts an arrow that stops 2 px short of another as touching it, and one 10 px short as apart" \
  '[ "$rc" = 0 ] && [ "$(grep -c "^Warning: crossing:" "$T/touch.out")" = 1 ] && grep -q "arrow near crosses arrow upright\|arrow upright crosses arrow near" "$T/touch.out"'
cat > "$T/keep.json" <<'JSON'
{"nodes": [{"id": "a", "label": "A"}, {"id": "b", "label": "B"},
           {"id": "x", "label": "X", "tier": 1}, {"id": "y", "label": "Y", "tier": 1}, {"id": "z", "label": "Z"}],
 "edges": [{"from": "a", "to": "z"}]}
JSON
run build "$T/keep.json" --png skip >/dev/null
xx="$(V "$T/keep.excalidraw" center-of node:x)"; xz="$(V "$T/keep.excalidraw" center-of node:z)"
check "a tier keeps the order of the spec when moving a node would save no crossing" \
  'python3 -c "import sys; sys.exit(0 if float(sys.argv[1]) < float(sys.argv[2]) else 1)" "${xx% *}" "${xz% *}"'
cat > "$T/sweeps.json" <<'JSON'
{"nodes": [{"id": "n0", "label": "N0"}, {"id": "n1", "label": "N1"}, {"id": "n2", "label": "N2"}, {"id": "n3", "label": "N3"}, {"id": "n4", "label": "N4"},
           {"id": "n5", "label": "N5"}, {"id": "n6", "label": "N6"}, {"id": "n7", "label": "N7"}, {"id": "n8", "label": "N8"}],
 "edges": [{"from": "n0", "to": "n1"}, {"from": "n1", "to": "n2"}, {"from": "n2", "to": "n3"}, {"from": "n2", "to": "n4"}, {"from": "n4", "to": "n5"},
           {"from": "n3", "to": "n6"}, {"from": "n5", "to": "n7"}, {"from": "n3", "to": "n8"}, {"from": "n1", "to": "n5"}]}
JSON
run build "$T/sweeps.json" --png skip >/dev/null; rc=$?
x6="$(V "$T/sweeps.excalidraw" center-of node:n6)"; x8="$(V "$T/sweeps.excalidraw" center-of node:n8)"; x5="$(V "$T/sweeps.excalidraw" center-of node:n5)"
check "the order with the fewest crossings between tiers is kept, not the last one tried" \
  '[ "$rc" = 0 ] && python3 -c "import sys; a,b,c=(float(v.split()[0]) for v in sys.argv[1:]); sys.exit(0 if a < b < c else 1)" "$x6" "$x8" "$x5"'
mutate zonetext 'z = el("zone:svc"); l = el("edge:0:label"); l["x"] = z["x"] + 12; l["y"] = z["y"] + z["height"] - l["height"] - 6'
check "check finds a label on a zone's outline" \
  'expect zonetext text-overlap && grep -q "sits on the outline of the zone \"Services\"" "$T/zonetext.out"'

# --- sequence diagrams
cat > "$T/seq.json" <<'JSON'
{"type": "sequence", "title": "Sign in",
 "participants": [{"id": "c", "label": "Client"}, {"id": "s", "label": "Server"}, {"id": "d", "label": "Database"}],
 "messages": [{"from": "c", "to": "s", "label": "POST /login"}, {"from": "s", "to": "d", "label": "SELECT user"},
              {"from": "d", "to": "s", "label": "row", "line": "dashed"}, {"from": "s", "to": "s", "label": "check hash"},
              {"from": "s", "to": "c", "label": "token", "line": "dashed", "head": "none"}]}
JSON
run build "$T/seq.json" --png skip >/dev/null; rc=$?
check "a sequence diagram builds and passes the checks" '[ "$rc" = 0 ] && run check "$T/seq.excalidraw" >/dev/null'
check "participants sit in one row with a dashed lifeline each" 'python3 -c "
import json,sys
d=json.load(open(sys.argv[1])); e=d[\"elements\"]
boxes=[x for x in e if x[\"id\"].startswith(\"participant:\") and x[\"type\"]==\"rectangle\"]
lines=[x for x in e if x[\"type\"]==\"line\"]
sys.exit(0 if len(boxes)==3 and len({b[\"y\"] for b in boxes})==1 and len(lines)==3 and all(l[\"strokeStyle\"]==\"dashed\" for l in lines) else 1)" "$T/seq.excalidraw"'
check "messages are horizontal, dashed when asked, and a message to itself loops back" 'python3 -c "
import json,sys
d=json.load(open(sys.argv[1])); m={x[\"id\"]:x for x in d[\"elements\"] if x[\"type\"]==\"arrow\"}
ok=all(len(a[\"points\"])==2 and a[\"points\"][1][1]==0 for k,a in m.items() if k!=\"message:3\")
ok=ok and len(m[\"message:3\"][\"points\"])==4 and m[\"message:2\"][\"strokeStyle\"]==\"dashed\" and m[\"message:4\"][\"endArrowhead\"] is None
sys.exit(0 if ok else 1)" "$T/seq.excalidraw"'
check "every message label sits above its arrow and off every line" 'V "$T/seq.excalidraw" labels 5'

# --- Mermaid
cat > "$T/flow.mmd" <<'MMD'
%% a comment
flowchart LR
    A([Start]) --> B[Enter email]
    B --> C{Valid?}
    C -->|yes| D[(Save user)]
    C -- no --> E["Show (error)"]
    E -.-> B
    D & E --- F((End))
    F <--> G[Two<br/>lines]
    subgraph store [Storage]
        D
    end
    classDef red fill:#f00
MMD
run mermaid "$T/flow.mmd" > "$T/flow.json" 2>"$T/flow.err"; rc=$?
check "mermaid converts the flowchart subset" '[ "$rc" = 0 ]'
check "Mermaid shapes map to ellipse, box, and diamond" 'python3 -c "
import json,sys
d=json.load(open(sys.argv[1])); n={x[\"id\"]:x for x in d[\"nodes\"]}
sys.exit(0 if (d[\"direction\"], n[\"A\"][\"shape\"], n[\"C\"][\"shape\"], n[\"F\"][\"shape\"], n[\"D\"].get(\"shape\", \"box\"), n[\"E\"][\"label\"], n[\"G\"][\"lines\"]) == (\"right\", \"ellipse\", \"diamond\", \"ellipse\", \"box\", \"Show (error)\", [\"lines\"]) else 1)" "$T/flow.json"'
check "Mermaid edges keep labels, dashes, missing heads, double heads, and & fan-in" 'python3 -c "
import json,sys
d=json.load(open(sys.argv[1])); e=[(x[\"from\"],x[\"to\"],x.get(\"label\",\"\"),x.get(\"line\",\"solid\"),x.get(\"head\",\"end\")) for x in d[\"edges\"]]
want=[(\"A\",\"B\",\"\",\"solid\",\"end\"),(\"B\",\"C\",\"\",\"solid\",\"end\"),(\"C\",\"D\",\"yes\",\"solid\",\"end\"),(\"C\",\"E\",\"no\",\"solid\",\"end\"),(\"E\",\"B\",\"\",\"dashed\",\"end\"),(\"D\",\"F\",\"\",\"solid\",\"none\"),(\"E\",\"F\",\"\",\"solid\",\"none\"),(\"F\",\"G\",\"\",\"solid\",\"both\")]
sys.exit(0 if e==want else 1)" "$T/flow.json"'
check "a subgraph becomes a group holding its nodes" 'python3 -c "
import json,sys
d=json.load(open(sys.argv[1])); n={x[\"id\"]:x for x in d[\"nodes\"]}
sys.exit(0 if d[\"groups\"]==[{\"id\":\"store\",\"label\":\"Storage\"}] and n[\"D\"][\"group\"]==\"store\" and \"group\" not in n[\"B\"] else 1)" "$T/flow.json"'
check "ignored Mermaid lines are named in a note" 'grep -q "line 13: classDef is ignored" "$T/flow.err"'
run build "$T/flow.mmd" --png skip >/dev/null; rc=$?
check "build accepts a .mmd file directly" '[ "$rc" = 0 ] && [ -s "$T/flow.excalidraw" ]'
cat > "$T/seq.mmd" <<'MMD'
sequenceDiagram
    autonumber
    participant C as Client
    actor U as User
    C->>+S: POST /login
    S-->>C: token
    S->U: ping
MMD
run mermaid "$T/seq.mmd" > "$T/seq.mmd.json" 2>/dev/null
check "Mermaid sequence diagrams keep participants, numbering, dashes, and heads" 'python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
p=[(x[\"id\"],x[\"label\"]) for x in d[\"participants\"]]
m=[(x[\"from\"],x[\"to\"],x[\"label\"],x.get(\"line\",\"solid\"),x.get(\"head\",\"end\")) for x in d[\"messages\"]]
sys.exit(0 if p==[(\"C\",\"Client\"),(\"U\",\"User\"),(\"S\",\"S\")] and m==[(\"C\",\"S\",\"1. POST /login\",\"solid\",\"end\"),(\"S\",\"C\",\"2. token\",\"dashed\",\"end\"),(\"S\",\"U\",\"3. ping\",\"solid\",\"none\")] else 1)" "$T/seq.mmd.json"'
for case in 'graph BT|line 1: direction BT' \
            'flowchart TD\n  subgraph a\n  subgraph b\n  end\n  end|line 3: subgraphs inside subgraphs' \
            'flowchart TD\n  A --o B|line 2: arrows ending in o or x' \
            'sequenceDiagram\n  A->>B: hi\n  loop every minute|line 3:' \
            'pie title Pets|line 1: pie diagrams are not supported'; do
  printf "${case%%|*}\n" > "$T/bad.mmd"
  run mermaid "$T/bad.mmd" >/dev/null 2>"$T/err"; rc=$?
  check "mermaid refuses \"$(printf "${case%%|*}" | tail -1 | sed 's/^ *//')\" with the line number" '[ "$rc" = 2 ] && grep -qF "${case#*|}" "$T/err"'
done
run mermaid "$T/flow.mmd" -o "$T/flow.json" >/dev/null 2>&1; rc=$?
check "mermaid -o does not replace an existing file without --replace" '[ "$rc" = 3 ]'

# --- themes and the hand-drawn look
cat > "$T/checkout.json" <<'JSON'
{"title": "Checkout", "direction": "down",
 "nodes": [{"id": "web", "label": "Web app", "lines": ["Next.js", "port 3000"], "color": "blue"},
           {"id": "api", "label": "API gateway", "lines": ["REST, JWT"], "color": "violet"},
           {"id": "orders", "label": "Order service", "lines": ["POST /orders"], "group": "svc", "color": "green"},
           {"id": "payments", "label": "Payment service", "lines": ["POST /payments"], "group": "svc", "color": "green"},
           {"id": "db", "label": "orders", "lines": ["id uuid", "total int", "status text"], "shape": "table", "color": "orange"},
           {"id": "card", "label": "Card processor", "lines": ["external", "HTTPS"], "color": "gray"}],
 "edges": [{"from": "web", "to": "api", "label": "HTTPS"}, {"from": "api", "to": "orders"}, {"from": "api", "to": "payments"},
           {"from": "orders", "to": "db", "label": "SQL", "line": "dashed"}, {"from": "payments", "to": "card", "label": "charge"}],
 "groups": [{"id": "svc", "label": "Services", "color": "green"}]}
JSON
THEMES="sketch hatch pencil soft marker dark clean friendly"
check "themes.json lists the eight themes in order, with sketch as the default" \
  '[ "$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d[\"default\"], *d[\"themes\"])" "$HERE/../themes.json")" = "sketch $THEMES" ]'
for theme in $THEMES; do
  out="$(run build "$T/checkout.json" --theme "$theme" --name "co-$theme" --png skip)"; rc=$?
  check "the checkout diagram builds with the $theme theme and passes every check" \
    '[ "$rc" = 0 ] && printf "%s\n" "$out" | grep -q "^No problems found." && ! printf "%s\n" "$out" | grep -q "^Warning:"'
done
run build "$T/checkout.json" --png skip >/dev/null
check "a spec without a theme is drawn with sketch: hand-drawn lines and Excalifont" 'python3 -c "
import json,sys
d=json.load(open(sys.argv[1])); els=d[\"elements\"]
ok=all(e[\"roughness\"]==1 for e in els if e[\"type\"]!=\"text\") and all(e[\"fontFamily\"]==5 for e in els if e[\"type\"]==\"text\")
sys.exit(0 if ok and \"theme\" not in d[\"appState\"] else 1)" "$T/checkout.excalidraw"'
check "a spec without a theme gives the same scene as the sketch theme" 'cmp -s "$T/checkout.excalidraw" "$T/co-sketch.excalidraw" || python3 -c "
import json,sys
a=json.load(open(sys.argv[1])); b=json.load(open(sys.argv[2])); sys.exit(0 if a[\"elements\"]==b[\"elements\"] else 1)" "$T/checkout.excalidraw" "$T/co-sketch.excalidraw"'
printf '{"theme": "neon", "nodes": [{"id": "a", "label": "A"}]}\n' > "$T/neon.json"
run build "$T/neon.json" >/dev/null 2>"$T/err"; rc=$?
check "an unknown theme exits 2 and lists the eight themes" \
  '[ "$rc" = 2 ] && grep -qF "theme: \"neon\" is not one of sketch, hatch, pencil, soft, marker, dark, clean, friendly" "$T/err"'
run build "$T/checkout.json" --theme neon --png skip >/dev/null 2>"$T/err"; rc=$?
check "an unknown --theme exits 2 the same way" '[ "$rc" = 2 ] && grep -qF "theme: \"neon\" is not one of" "$T/err"'
check "hand-drawn shapes and arrows are curves in the SVG, not rectangles or polylines" \
  'grep -q "<path d=\"M[^\"]*C" "$T/co-sketch.svg" && ! grep -q "<rect x=\"[^\"]*\" y=\"[^\"]*\" width=\"[^\"]*\" height=\"[^\"]*\" rx=" "$T/co-sketch.svg" && ! grep -q "<polyline" "$T/co-sketch.svg"'
check "the hand-drawn SVG embeds the Excalifont file for Latin text as a data URL, and no other" \
  '[ "$(grep -o "@font-face{font-family:[^;]*" "$T/co-sketch.svg" | sort -u)" = "@font-face{font-family:'"'"'Excalifont'"'"'" ] && [ "$(grep -o "@font-face" "$T/co-sketch.svg" | wc -l | tr -d " ")" = 1 ] && grep -q "src:url(data:font/woff2;base64," "$T/co-sketch.svg"'
check "the friendly SVG embeds Nunito, and the clean SVG embeds no font and draws plain rectangles" \
  'grep -q "font-family:'"'"'Nunito'"'"'" "$T/co-friendly.svg" && ! grep -q "@font-face" "$T/co-clean.svg" && grep -q "<rect x=\"[^\"]*\" y=\"[^\"]*\" width=\"[^\"]*\" height=\"[^\"]*\" rx=" "$T/co-clean.svg"'
check "the hatch theme fills shapes with hatching, drawn as strokes in the fill color" \
  'python3 -c "
import json,sys
d=json.load(open(sys.argv[1])); n=[e for e in d[\"elements\"] if e[\"id\"]==\"node:web\"][0]
sys.exit(0 if n[\"fillStyle\"]==\"hachure\" else 1)" "$T/co-hatch.excalidraw" && grep -q "fill=\"none\" stroke=\"#a5d8ff\"" "$T/co-hatch.svg"'
check "the pencil theme draws shapes in thin black outlines with no fill" 'python3 -c "
import json,sys
d=json.load(open(sys.argv[1])); s=[e for e in d[\"elements\"] if e[\"type\"]==\"rectangle\" and not e[\"id\"].startswith(\"zone:\")]
sys.exit(0 if s and all(e[\"strokeColor\"]==\"#1e1e1e\" and e[\"backgroundColor\"]==\"transparent\" and e[\"strokeWidth\"]==1 for e in s) else 1)" "$T/co-pencil.excalidraw"'
check "the soft theme fills shapes with the light tint and leaves zones unfilled" 'python3 -c "
import json,sys
d=json.load(open(sys.argv[1])); e={x[\"id\"]:x for x in d[\"elements\"]}
sys.exit(0 if e[\"node:web\"][\"backgroundColor\"]==\"#e7f5ff\" and e[\"zone:svc\"][\"backgroundColor\"]==\"transparent\" else 1)" "$T/co-soft.excalidraw"'
check "the marker theme uses roughness 2 and 4 px outlines" 'python3 -c "
import json,sys
d=json.load(open(sys.argv[1])); e={x[\"id\"]:x for x in d[\"elements\"]}
sys.exit(0 if e[\"node:web\"][\"roughness\"]==2 and e[\"node:web\"][\"strokeWidth\"]==4 else 1)" "$T/co-marker.excalidraw"'
check "the dark theme sets appState.theme to dark and its SVG inverts the colors as Excalidraw does" \
  'python3 -c "import json,sys; sys.exit(0 if json.load(open(sys.argv[1]))[\"appState\"].get(\"theme\")==\"dark\" else 1)" "$T/co-dark.excalidraw" && grep -q "<svg [^>]*style=\"filter:invert(93%) hue-rotate(180deg)\"" "$T/co-dark.svg" && ! grep -q "invert(" "$T/co-sketch.svg"'
check "in the checkout diagram every arrow ends 5 px from its shape" 'V "$T/co-sketch.excalidraw" ends'
check "the two arrows from the API gateway start at the same point and split" 'python3 -c "
import json,sys
d=json.load(open(sys.argv[1])); e={x[\"id\"]:x for x in d[\"elements\"]}
p=lambda a: [(a[\"x\"]+q[0], a[\"y\"]+q[1]) for q in a[\"points\"]]
a, b = p(e[\"edge:1\"]), p(e[\"edge:2\"])
sys.exit(0 if a[0]==b[0] and a[1]==b[1] and a[-1]!=b[-1] else 1)" "$T/co-sketch.excalidraw"'
check "every box in the checkout diagram has the same width" 'python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
w={e[\"width\"] for e in d[\"elements\"] if e[\"type\"]==\"rectangle\" and e[\"id\"].startswith(\"node:\") and not e[\"id\"].endswith(\":fields\")}
sys.exit(0 if len(w)==1 else 1)" "$T/co-sketch.excalidraw"'
printf '{"nodes": [{"id": "a", "label": "A"}, {"id": "b", "label": "A service with a very long name indeed"}], "edges": [{"from": "a", "to": "b"}]}\n' > "$T/wide2.json"
run build "$T/wide2.json" --png skip >/dev/null
check "a box far narrower than the widest one widens by at most half its width" 'python3 -c "
import json,sys
d=json.load(open(sys.argv[1])); e={x[\"id\"]:x for x in d[\"elements\"]}
sys.exit(0 if 160 < e[\"node:a\"][\"width\"] <= 240 < e[\"node:b\"][\"width\"] else 1)" "$T/wide2.excalidraw"'
cp "$T/co-sketch.excalidraw" "$T/again1.excalidraw"; cp "$T/co-sketch.svg" "$T/again1.svg"
run build "$T/checkout.json" --theme sketch --name co-sketch --png skip --replace >/dev/null
check "building the same spec again writes byte-identical .excalidraw and SVG files" \
  'cmp -s "$T/again1.excalidraw" "$T/co-sketch.excalidraw" && cmp -s "$T/again1.svg" "$T/co-sketch.svg"'
sed 's/"direction": "down"/"direction": "down", "style": "clean", "fill": "hachure"/' "$T/checkout.json" > "$T/override.json"
run build "$T/override.json" --png skip >/dev/null
check "\"style\" and \"fill\" adjust the theme: clean lines and hatched fills on top of sketch" 'python3 -c "
import json,sys
d=json.load(open(sys.argv[1])); e={x[\"id\"]:x for x in d[\"elements\"]}
sys.exit(0 if e[\"node:web\"][\"roughness\"]==0 and e[\"node:web\"][\"fillStyle\"]==\"hachure\" and e[\"node:web:text\"][\"fontFamily\"]==2 else 1)" "$T/override.excalidraw"'
printf '{"type": "sequence", "theme": "pencil", "participants": [{"id": "c", "label": "Client"}, {"id": "s", "label": "Server", "color": "blue"}], "messages": [{"from": "c", "to": "s", "label": "GET /"}]}\n' > "$T/seqtheme.json"
run build "$T/seqtheme.json" --png skip >/dev/null; rc=$?
check "sequence diagrams take the theme too" '[ "$rc" = 0 ] && python3 -c "
import json,sys
d=json.load(open(sys.argv[1])); e={x[\"id\"]:x for x in d[\"elements\"]}
sys.exit(0 if e[\"participant:s\"][\"strokeColor\"]==\"#1e1e1e\" and e[\"message:0\"][\"strokeWidth\"]==1 else 1)" "$T/seqtheme.excalidraw"'
printf '{"nodes": [{"id": "a", "label": "注文サービス", "lines": ["POST /orders"]}, {"id": "b", "label": "決済"}], "edges": [{"from": "a", "to": "b", "label": "請求"}]}\n' > "$T/ja.json"
run build "$T/ja.json" --png skip >/dev/null; rc=$?
check "Japanese text in the hand-drawn theme builds and falls back to the system fonts after Excalifont" \
  '[ "$rc" = 0 ] && grep -q "font-family=\"'"'"'Excalifont'"'"', '"'"'Helvetica Neue'"'"'" "$T/ja.svg"'
mkdir -p "$T/skill" && cp -R "$HERE/../scripts" "$T/skill/" && sed 's/"roughness": 2/"roughness": 9/' "$HERE/../themes.json" > "$T/skill/themes.json"
python3 "$T/skill/scripts/excalidraw_diagram.py" build "$T/checkout.json" --out "$T/skill" --png skip >/dev/null 2>"$T/err"; rc=$?
check "a themes.json that breaks its format stops the build with exit 2 and names the setting" \
  '[ "$rc" = 2 ] && grep -qF "themes.json: theme marker: roughness must be one of 0, 1, 2" "$T/err"'

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
