#!/bin/bash
# Tests for motion-explainer: a theme folder (colors, characters and their faces, pictures) and a script
# (cast, objects, scenes of beats, figures) become one offline HTML page with a video and figures under it.
#
# What is checked:
#   1. build.py reads a theme folder from outside the plugin, refuses a broken script or unsafe art and
#      names the field, and stops with how to install uv when uv is missing. The page loads nothing from
#      the network and puts the video before the figures.
#   2. The default theme casts the four pixel-art bodies, and the art comes only from the theme and the
#      script.
#   3. In a headless browser: actors and objects never overlap, chart lines come from layout offsets, a
#      holder hangs and stands its items on its anchor line, a screen zooms to a rect of a taller page, a
#      beat fires its effect while a jump fires none, the video plays once, pauses, resumes, and jumps to a
#      step from the bar, reduced motion shows each scene at its end and fires no effect, a phone width
#      has no sideways scroll and a readable line, the page reads in light and dark, and the figures draw
#      from the script's objects.
#   4. capture.py saves scene frames and a sheet and prints the errors of the page, and both examples build
#      with the default theme.
#   5. references/ describes every field and beat action, SKILL.md walks the steps and keeps lines short,
#      the effects core is bundled unmodified with its license, and no absolute path to another repository
#      or a home folder is in the plugin.
#
# The browser cases open a copy of a built page with a probe script added. The probe drives window.MX and
# writes what it saw into <pre id="mx-probe">, which `browser.py dump` prints. Animation frames do not run
# on the browser's virtual time, so the copy runs them on timers.
# Exit 0 when every case passes, 1 when any fails (the failing cases are listed).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN="$(cd "$SKILL_DIR/../.." && pwd)"
BUILD="$SKILL_DIR/scripts/build.py"
CAPTURE="$SKILL_DIR/scripts/capture.py"
SCHEMA="$SKILL_DIR/scripts/schema.py"
BROWSER="$SKILL_DIR/scripts/browser.py"
ENGINE="$SKILL_DIR/engine"
PIXEL="$SKILL_DIR/themes/pixel"
CACHE_SCRIPT="$PLUGIN/examples/cache/script.json"
REDELIVERY_SCRIPT="$PLUGIN/examples/redelivery/script.json"
CORE_DIR="$SKILL_DIR/vendor/sakuga-vfx"
# The spec tool of the earlier form, which the checks of current behavior still run.
TOOL="$SKILL_DIR/scripts/motion_explainer.py"
CACHE="$PLUGIN/examples/cache"
# core.js of Sakuga VFX at the pinned commit, as published; the bundled copy must be this file.
UPSTREAM_SHA256="f0518dd7d4dd1986eab2c9c76796421f4c827e91eac627f4c91a63c362c79419"
export PYTHONDONTWRITEBYTECODE=1

WORK="$(mktemp -d "${TMPDIR:-/tmp}/motion-explainer-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
OUT_THEME="$WORK/outside/theme"
OUT_SCRIPT="$WORK/outside/script"

PASS=0
FAIL=0
FAILED=()
why=""

check() {
  local name="$1" fn="$2"
  why=""
  if "$fn"; then
    echo "  PASS: $name"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $name${why:+ ($why)}"; FAIL=$((FAIL + 1)); FAILED+=("$name")
  fi
}

need() {  # need <file>...: fails naming the first file that is missing
  local f
  for f in "$@"; do
    [ -e "$f" ] || { why="there is no ${f#"$PLUGIN"/}"; return 1; }
  done
}

# A helper module for the judging scripts: reads the theme and the script a built page holds.
mkdir -p "$WORK/lib"
cat > "$WORK/lib/mxpage.py" <<'PY'
import json

def held(page, name):
    """The JSON value the page assigns to window.<name>, or None."""
    key = "window.%s = " % name
    i = page.find(key)
    if i < 0:
        return None
    return json.JSONDecoder().raw_decode(page, i + len(key))[0]
PY
export PYTHONPATH="$WORK/lib"

# --- the outside theme and the probe script ---------------------------------------------------------

# make_outside: writes a theme folder and a script folder outside the plugin. Their pictures have known
# shapes, so the checks know where the engine must put things; expect.json holds those places.
make_outside() {
  [ -s "$OUT_SCRIPT/script.json" ] && return 0
  mkdir -p "$OUT_THEME/faces" "$OUT_SCRIPT"
  python3 - "$OUT_THEME" "$OUT_SCRIPT" <<'PY'
import json, os, struct, sys, zlib
theme_dir, script_dir = sys.argv[1], sys.argv[2]

def png(path, w, h, rects):
    """A PNG with a transparent background and opaque rectangles (x0, y0, x1, y1, rgba), later on top."""
    rows = [bytearray(w * 4) for _ in range(h)]
    for x0, y0, x1, y1, c in rects:
        for y in range(y0, y1):
            rows[y][x0 * 4:x1 * 4] = bytes(c) * (x1 - x0)
    raw = b"".join(b"\x00" + bytes(r) for r in rows)
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))

ink = (28, 26, 24, 255)
faces = {}
for n, body in enumerate(("robot", "android", "guide", "drone")):
    faces[body] = {"default": "wait", "faces": {}}
    for m, face in enumerate(("wait", "explain", "surprised", "cheer")):
        name = "faces/%s-%s.png" % (body, face)
        png(os.path.join(theme_dir, name), 120, 160, [(20, 10, 100, 160, (40 + 50 * n, 90 + 40 * m, 120, 255)), (40, 40, 80, 60, ink)])
        faces[body]["faces"][face] = name
# A rail: two posts and a bar. Its visible box is x 20..380, y 40..190, and it hangs things at y 48.
png(os.path.join(theme_dir, "rail.png"), 400, 200, [(20, 40, 40, 190, ink), (360, 40, 380, 190, ink), (20, 40, 380, 56, ink)])
json.dump({"anchors": {"hang": [200, 48]}}, open(os.path.join(theme_dir, "rail.json"), "w"))
# A folder in two layers cut by one box (x 20..280, y 20..230): things stand on y 150, and the front
# layer covers y 120 and below.
png(os.path.join(theme_dir, "folder-back.png"), 300, 240, [(20, 20, 280, 230, (200, 160, 90, 255))])
png(os.path.join(theme_dir, "folder-front.png"), 300, 240, [(20, 120, 280, 230, (230, 190, 110, 255))])
json.dump({"anchors": {"rim": [150, 150]}}, open(os.path.join(theme_dir, "folder-back.json"), "w"))
# A tag (visible box 80 x 100) in two colors, one for each state.
png(os.path.join(theme_dir, "tag.png"), 100, 140, [(10, 20, 90, 120, (15, 118, 110, 255))])
png(os.path.join(theme_dir, "tag2.png"), 100, 140, [(10, 20, 90, 120, (224, 96, 74, 255))])
colors = {"ink": "#1c1a18", "sub": "#6b625a", "line": "#e2d8cc", "paper": "#ffffff", "bg": "#f6f1ea",
          "panel": "#efe6da", "slotLine": "#d3c2aa", "primary": "#123456", "primary2": "#0d2740",
          "primarySoft": "#dbe6f0", "accent": "#aa3300", "accent2": "#882800", "accentSoft": "#f7e2d8",
          "yellow": "#f2c14e", "yellowSoft": "#fdf0c8", "ok": "#3f9a6f", "okSoft": "#e1f2e9", "edge": "#0d2740"}
theme = {"name": "probe", "font": "system-ui, sans-serif", "colors": colors, "floorY": 474,
         "characterScale": 1, "characters": faces,
         "images": {"rail": {"file": "rail.png", "px": 800}, "folder-back": {"file": "folder-back.png", "px": 600, "group": "folder"},
                    "folder-front": {"file": "folder-front.png", "px": 600, "group": "folder"},
                    "tag": {"file": "tag.png", "px": 200}, "tag2": {"file": "tag2.png", "px": 200}}}
json.dump(theme, open(os.path.join(theme_dir, "theme.json"), "w"), indent=1)

# A page twice as tall as it is wide, and a small drawing of the script's own.
png(os.path.join(script_dir, "tall.png"), 400, 1000, [(0, 0, 400, 1000, (250, 250, 250, 255)), (40, 620, 160, 670, (15, 118, 110, 255))])
open(os.path.join(script_dir, "art.svg"), "w").write(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 80"><rect x="6" y="6" width="88" height="68" rx="10" fill="#fdf8ee" stroke="#22303c" stroke-width="5"/></svg>\n')
tags = lambda *ids: [{"id": i, "image": "tag", "label": i.upper(), "hidden": True} for i in ids]
script = {
    "lang": "en", "title": "Probe", "subtitle": "Every kind of object",
    "cast": {"a": {"character": "robot", "label": "A"}, "b": {"character": "android", "label": "B"}},
    "images": {"tall": {"file": "tall.png", "px": 1200}, "art": {"file": "art.svg"}},
    "objects": {
        "chart": {"type": "nodes", "levels": [[{"id": "top", "image": "tag", "label": "Top"}], tags("c1", "c2", "c3")]},
        "rail": {"type": "holder", "back": "rail", "anchor": "hang", "width": 420,
                 "items": [{"id": "t1", "image": "tag", "x": 0.3, "label": "T1"}, {"id": "t2", "image": "tag", "x": 0.7, "label": "T2"}]},
        "folder": {"type": "holder", "back": "folder-back", "front": "folder-front", "anchor": "rim", "stand": True, "width": 320,
                   "items": [{"id": "f1", "image": "tag", "x": 0.5, "label": "F1"}]},
        "page": {"type": "screen", "image": "tall", "address": "probe", "width": 620, "view": 0.6,
                 "marks": {"m": {"rect": [0.1, 0.62, 0.3, 0.05]}}},
        "box": {"type": "prop", "image": "tag", "states": {"open": "tag2"}, "label": "Box", "width": 140},
        "note": {"type": "card", "title": "Note", "width": 240, "parts": [{"type": "text", "text": "A short note."}]},
        "pic": {"type": "prop", "image": "art", "label": "Art", "width": 110},
    },
    "scenes": [
        {"chapter": "One", "cast": ["a", {"id": "b", "side": "right"}], "objects": ["chart"], "beats": [
            {"do": "say", "who": "a", "text": "Here is the chart.", "face": "explain"},
            {"do": "show", "target": "chart.c1", "fx": {"word": "pon"}},
            {"do": "show", "target": "chart.c2"},
            {"do": "show", "target": "chart.c3"},
            {"do": "say", "who": "b", "text": "Three of them.", "face": "cheer"}]},
        {"chapter": "Two", "cast": ["a"], "objects": ["rail"], "beats": [{"do": "say", "who": "a", "text": "Tags hang here."}]},
        {"chapter": "Two", "cast": ["a"], "objects": ["folder"], "beats": [{"do": "say", "who": "a", "text": "A tag stands here."}]},
        {"chapter": "Three", "cast": ["a"], "objects": ["page"], "beats": [
            {"do": "say", "who": "a", "text": "Look lower on the page."},
            {"do": "show", "target": "page.m"},
            {"do": "focus", "target": "page", "mark": "m"},
            {"do": "tap", "target": "page.m", "fx": {"burst": 40, "word": "don"}}]},
        {"chapter": "Four", "cast": ["a", {"id": "b", "side": "right"}], "objects": ["box", "note", "pic"], "beats": [
            {"do": "swap", "target": "box", "state": "open"},
            {"do": "say", "who": "b", "text": "It opened.", "face": "surprised", "fx": {"word": "kachi"}}]},
    ],
    "figures": [
        {"kind": "still", "question": "What does the chart hold?", "answer": "One top and three below it.", "scene": 0,
         "labels": {"chart": "The chart", "a": "The speaker"}},
        {"kind": "flow", "question": "How does the box change?", "answer": "It opens.",
         "steps": [{"target": "box", "text": "Closed"}, {"target": "box", "state": "open", "text": "Open"}, {"target": "chart.c1", "text": "Shown"}]},
        {"kind": "compare", "question": "Which is which?", "answer": "A box opens and a tag hangs.",
         "sides": [{"title": "Box", "target": "box", "points": ["Opens"]}, {"title": "Tag", "target": "rail.t1", "points": ["Hangs"]}]},
        {"kind": "table", "question": "What is shown where?", "answer": "Each scene shows one thing.",
         "columns": ["Scene", "Object"], "rows": [["One", "Chart"], ["Two", "Rail"], ["Three", "Page"]]},
    ],
}
json.dump(script, open(os.path.join(script_dir, "script.json"), "w"), indent=1)
# Where things must land, as fractions of the holder picture after it is cut to its visible box.
json.dump({"hang": (48 - 40) / 150, "rim": (150 - 20) / 210}, open(os.path.join(script_dir, "expect.json"), "w"))
PY
}

# build <theme-dir> <script> <page>: builds the page once; later calls reuse it.
build() {
  [ -s "$3" ] && return 0
  need "$BUILD" || return 1
  python3 "$BUILD" "$1" "$2" "$3" > "$3.out" 2>&1 || { why="build exited $?: $(head -3 "$3.out" | tr '\n' ' ')"; return 1; }
}

build_probe() { make_outside && build "$OUT_THEME" "$OUT_SCRIPT/script.json" "$WORK/probe.html"; }

# js <name>: saves the probe body read from standard input as $WORK/<name>.js. The body runs 800 ms after
# the page loads and fills `out`; it can use wait(ms), video (the .mx element), and box(e) ([x, y, w, h]
# in the 896 x 504 frame of the video).
js() { cat > "$WORK/$1.js"; }

# probe_js <page> <name> <width> [browser options]: opens a copy of the page with the probe $WORK/<name>.js
# added and saves what it reports, with the errors of the page, to $WORK/<name>.json.
probe_js() {
  local page="$1" name="$2" width="$3"; shift 3
  python3 - "$page" "$WORK/$name.js" "$WORK/$name.html" <<'PY' || { why="the page has no <head> or </body> to add the probe to"; return 1; }
import sys
page, body, out = open(sys.argv[1]).read(), open(sys.argv[2]).read(), sys.argv[3]
head = ("<script>window.__errors = []; addEventListener('error', e => __errors.push(String(e.message || e)));"
        " addEventListener('unhandledrejection', e => __errors.push(String(e.reason)));"
        " window.requestAnimationFrame = f => setTimeout(() => f(performance.now()), 16);"
        " window.cancelAnimationFrame = id => clearTimeout(id);</script>")
tail = ("<pre id=\"mx-probe\"></pre><script>(async () => { const out = {};"
        " const wait = ms => new Promise(r => setTimeout(r, ms));"
        " const video = document.querySelector('#me-player .mx'); const cv = video && video.querySelector('.cv');"
        " const box = e => { const c = cv.getBoundingClientRect(), r = e.getBoundingClientRect(), k = c.width / 896;"
        " return [(r.left - c.left) / k, (r.top - c.top) / k, r.width / k, r.height / k]; };"
        " try { await wait(800);\n" + body + "\n} catch (e) { out.thrown = String(e && e.stack || e); }"
        " out.errors = window.__errors; document.getElementById('mx-probe').textContent = JSON.stringify(out); })();</script>")
i, j = page.find("<head>"), page.rfind("</body>")
if i < 0 or j < 0:
    sys.exit(1)
open(out, "w").write(page[:i + 6] + head + page[i + 6:j] + tail + page[j:])
PY
  python3 "$BROWSER" dump "file://$WORK/$name.html" --size "${width}x900" "$@" > "$WORK/$name.dom" 2> "$WORK/$name.err" || { why="no browser: $(head -1 "$WORK/$name.err")"; return 1; }
  python3 - "$WORK/$name.dom" "$WORK/$name.json" <<'PY' || { why="the probe reported nothing"; return 1; }
import html, re, sys
m = re.search(r'<pre id="mx-probe">(.*?)</pre>', open(sys.argv[1]).read(), re.S)
if not m or not m.group(1).strip():
    sys.exit(1)
open(sys.argv[2], "w").write(html.unescape(m.group(1)))
PY
}

# judge <name> <python>: runs the judging code on $WORK/<name>.json (as `got`, with its page errors
# refused first); what it prints becomes the reason when it fails.
judge() {
  why="$(python3 - "$WORK/$1.json" "$2" "$OUT_SCRIPT/expect.json" <<'PY'
import json, os, sys
got = json.load(open(sys.argv[1]))
expect = json.load(open(sys.argv[3])) if os.path.exists(sys.argv[3]) else {}
if got.get("thrown"):
    print("the probe threw: %s" % got["thrown"][:200]); sys.exit(1)
if got.get("errors"):
    print("the page reported errors: %s" % got["errors"][:3]); sys.exit(1)
exec(sys.argv[2])
PY
)" || return 1
  why=""
}

# --- 1. build ----------------------------------------------------------------------------------------

build_reads_a_theme_folder_from_outside_the_plugin() {
  build_probe || return 1
  python3 - "$WORK/probe.html" <<'PY' || { why="the page does not hold the colors and characters of the outside theme"; return 1; }
import sys
from mxpage import held
page = open(sys.argv[1]).read()
theme = held(page, "MX_THEME") or {}
ok = theme.get("colors", {}).get("primary") == "#123456"
ok = ok and set(theme.get("characters", {})) == {"robot", "android", "guide", "drone"}
sys.exit(0 if ok else 1)
PY
  [ $? -eq 0 ] || return 1
  js outside <<'JS'
out.actors = video.querySelectorAll('.actor[data-actor]').length;
out.objects = video.querySelectorAll('.obj[data-object]').length;
JS
  probe_js "$WORK/probe.html" outside 1000 || return 1
  judge outside '
if got["actors"] != 2 or got["objects"] != 7:
    print("the video built %d actors and %d objects, want 2 and 7" % (got["actors"], got["objects"])); sys.exit(1)
'
}

# script_variant <name> <python on s>: a copy of the probe script folder with its script changed.
script_variant() {
  make_outside || return 1
  rm -rf "$WORK/$1"; cp -R "$OUT_SCRIPT" "$WORK/$1"
  python3 - "$WORK/$1/script.json" "$2" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
exec(sys.argv[2])
open(sys.argv[1], "w").write(json.dumps(s, ensure_ascii=False))
PY
}

build_refuses() {  # build_refuses <variant> <field that must be named>
  local out status
  out="$(python3 "$BUILD" "$OUT_THEME" "$WORK/$1/script.json" "$WORK/$1/page.html" 2>&1)"; status=$?
  [ "$status" -eq 1 ] || { why="build exited $status for $2"; return 1; }
  printf '%s' "$out" | grep -qF "$2" || { why="build did not name $2: $(printf '%s' "$out" | head -2 | tr '\n' ' ')"; return 1; }
  [ ! -e "$WORK/$1/page.html" ] || { why="build wrote a page for $2"; return 1; }
}

build_refuses_a_broken_script_and_names_the_field() {
  need "$BUILD" || return 1
  build_probe || return 1
  script_variant type 's["objects"]["note"]["type"] = "blob"' && build_refuses type "objects.note.type" || return 1
  script_variant character 's["cast"]["a"]["character"] = "nobody"' && build_refuses character "cast.a.character" || return 1
  script_variant face 's["scenes"][0]["beats"][0]["face"] = "dance"' && build_refuses face "scenes[0].beats[0].face" || return 1
  script_variant image 's["objects"]["box"]["image"] = "missing"' && build_refuses image "objects.box.image" || return 1
  script_variant action 's["scenes"][0]["beats"][1]["do"] = "explode"' && build_refuses action "scenes[0].beats[1].do" || return 1
}

build_without_uv_says_how_to_install_it() {
  need "$BUILD" || return 1
  make_outside || return 1
  local real status
  real="$(python3 -c 'import os, sys; print(os.path.realpath(sys.executable))')"
  mkdir -p "$WORK/nouv"; ln -sf "$real" "$WORK/nouv/python3"
  PATH="$WORK/nouv" "$WORK/nouv/python3" "$BUILD" "$OUT_THEME" "$OUT_SCRIPT/script.json" "$WORK/nouv/page.html" > "$WORK/nouv.out" 2>&1; status=$?
  [ "$status" -ne 0 ] || { why="build ended with 0 without uv"; return 1; }
  [ ! -e "$WORK/nouv/page.html" ] || { why="build wrote a page without uv"; return 1; }
  grep -qi "install uv" "$WORK/nouv.out" || { why="build did not say how to install uv: $(head -2 "$WORK/nouv.out" | tr '\n' ' ')"; return 1; }
}

# --- 2. theme and art --------------------------------------------------------------------------------

the_default_theme_casts_the_four_bodies_with_their_poses_as_faces() {
  need "$PIXEL/theme.json" "$BUILD" || return 1
  why="$(python3 - "$PIXEL" <<'PY'
import json, os, struct, sys
folder = sys.argv[1]
theme = json.load(open(os.path.join(folder, "theme.json")))
chars = theme.get("characters", {})
if set(chars) != {"robot", "android", "guide", "drone"}:
    print("the characters are %s" % sorted(chars)); sys.exit(1)
for body, ch in chars.items():
    if set(ch.get("faces", {})) != {"wait", "explain", "surprised", "cheer"}:
        print("%s has the faces %s" % (body, sorted(ch.get("faces", {})))); sys.exit(1)
    for face, name in ch["faces"].items():
        raw = open(os.path.join(folder, name), "rb").read()
        color = struct.unpack(">IIBB", raw[16:26])[3] if raw[:8] == b"\x89PNG\r\n\x1a\n" else None
        if color != 6 and not (color == 3 and b"tRNS" in raw):
            print("%s of %s is not a PNG with transparency" % (face, body)); sys.exit(1)
PY
)" || return 1
  mkdir -p "$WORK/bodies"
  python3 - "$WORK/bodies/script.json" <<'PY'
import json, sys
say = lambda who, face: {"do": "say", "who": who, "text": "I take a pose.", "face": face}
json.dump({"lang": "en", "title": "Bodies",
           "cast": {"r": {"character": "robot", "label": "Robot"}, "n": {"character": "android", "label": "Android"},
                    "g": {"character": "guide", "label": "Guide"}, "d": {"character": "drone", "label": "Drone"}},
           "objects": {},
           "scenes": [{"cast": ["r", "n", {"id": "g", "side": "right"}, {"id": "d", "side": "right"}],
                       "beats": [say("r", "wait"), say("n", "explain"), say("g", "surprised"), say("d", "cheer")]}]},
          open(sys.argv[1], "w"))
PY
  build "$PIXEL" "$WORK/bodies/script.json" "$WORK/bodies.html" || return 1
  js bodies <<'JS'
MX.seek(MX.END - 1, false);
const th = window.MX_THEME, sc = window.MX_SCRIPT, want = { r: 'wait', n: 'explain', g: 'surprised', d: 'cheer' };
out.faces = {};
for (const id in want) {
  const img = video.querySelector(`.actor[data-actor="${id}"] img`);
  out.faces[id] = { same: !!img && img.getAttribute('src') === th.images[th.characters[sc.cast[id].character].faces[want[id]]],
                    pixelated: !!img && getComputedStyle(img).imageRendering === 'pixelated' };
}
JS
  probe_js "$WORK/bodies.html" bodies 1000 || return 1
  judge bodies '
for cid, f in got["faces"].items():
    if not f["same"]:
        print("%s does not show the face its last line names" % cid); sys.exit(1)
    if not f["pixelated"]:
        print("%s is not drawn with sharp pixels" % cid); sys.exit(1)
'
}

the_art_comes_only_from_the_theme_and_the_script() {
  need "$ENGINE/engine.js" "$ENGINE/engine.css" "$SKILL_DIR/templates/page.html" "$PIXEL/theme.json" "$CACHE_SCRIPT" "$REDELIVERY_SCRIPT" || return 1
  why="$(python3 - "$ENGINE" "$SKILL_DIR/templates" "$SKILL_DIR/scripts" <<'PY'
import os, re, sys
for folder in sys.argv[1:]:
    for name in sorted(os.listdir(folder)):
        path = os.path.join(folder, name)
        if not os.path.isfile(path):
            continue
        text = open(path, encoding="utf-8", errors="replace").read()
        if "data:image" in text:
            print("%s holds a picture" % name); sys.exit(1)
        if re.search(r'<svg(?![^>]*class="ui")', text):
            print("%s holds a drawing that is not a player icon" % name); sys.exit(1)
PY
)" || return 1
  make_outside || return 1
  build "$PIXEL" "$CACHE_SCRIPT" "$WORK/cache-pixel.html" || return 1
  build "$PIXEL" "$REDELIVERY_SCRIPT" "$WORK/redelivery-pixel.html" || return 1
  build "$OUT_THEME" "$CACHE_SCRIPT" "$WORK/cache-outside.html" || return 1
  why="$(python3 - "$WORK/cache-pixel.html" "$WORK/redelivery-pixel.html" "$WORK/cache-outside.html" "$CACHE_SCRIPT" "$REDELIVERY_SCRIPT" <<'PY'
import base64, json, os, re, sys
uri = re.compile(r"data:image/[a-z+]+;base64,[A-Za-z0-9+/=]+")
def pictures(path):
    return set(uri.findall(open(path).read()))
def svgs(path):
    return [base64.b64decode(u.split(",", 1)[1]).decode("utf-8", "replace") for u in pictures(path) if u.startswith("data:image/svg+xml")]
def first_path(script_path):
    s = json.load(open(script_path))
    for spec in s.get("images", {}).values():
        if spec["file"].endswith(".svg"):
            m = re.search(r'\sd="([^"]{12,})"', open(os.path.join(os.path.dirname(script_path), spec["file"])).read())
            if m:
                return m.group(1)
    return None
cache_page, redelivery_page, outside_page = sys.argv[1:4]
mine_c, mine_r = first_path(sys.argv[4]), first_path(sys.argv[5])
if not mine_c or not mine_r:
    print("an example brings no SVG drawing of its own"); sys.exit(1)
in_c, in_r = "\n".join(svgs(cache_page)), "\n".join(svgs(redelivery_page))
if mine_c not in in_c or mine_r not in in_r:
    print("a page does not draw the art of its own script"); sys.exit(1)
if mine_c in in_r or mine_r in in_c:
    print("a page draws the art of the other script"); sys.exit(1)
# The same script built with two themes shares only the script's own pictures.
script_pictures = pictures(cache_page) & pictures(outside_page)
shared = {u for u in script_pictures if not u.startswith("data:image/svg+xml")}
if shared:
    print("%d pictures are the same with both themes" % len(shared)); sys.exit(1)
PY
)" || return 1
  why=""
}

# --- 3. in a headless browser ------------------------------------------------------------------------

actors_and_objects_never_overlap_in_any_scene() {
  build "$PIXEL" "$CACHE_SCRIPT" "$WORK/cache-pixel.html" || return 1
  build "$PIXEL" "$REDELIVERY_SCRIPT" "$WORK/redelivery-pixel.html" || return 1
  js overlap <<'JS'
const shown = e => !e.hasAttribute('data-off');
out.scenes = [];
for (let i = 0; i < MX.SCENE_T.length; i++) {
  const end = (MX.SCENE_T[i + 1] ?? MX.END) - 1, mid = Math.round((MX.SCENE_T[i] + end) / 2);
  for (const t of [mid, end]) {
    MX.seek(t, false);
    out.scenes.push({ scene: i, t,
      actors: [...video.querySelectorAll('.actor[data-actor]')].filter(shown).map(e => [e.dataset.actor, box(e)]),
      objects: [...video.querySelectorAll('.obj[data-object]')].filter(shown).map(e => [e.dataset.object, box(e)]) });
  }
}
JS
  local example
  for example in cache redelivery; do
    cp "$WORK/overlap.js" "$WORK/overlap-$example.js"
    probe_js "$WORK/$example-pixel.html" "overlap-$example" 1000 || return 1
    judge "overlap-$example" '
def cross(a, b):
    return min(a[0] + a[2], b[0] + b[2]) - max(a[0], b[0]) > 1 and min(a[1] + a[3], b[1] + b[3]) - max(a[1], b[1]) > 1
if not got["scenes"]:
    print("the video has no scenes"); sys.exit(1)
for s in got["scenes"]:
    things = [("actor", n, b) for n, b in s["actors"]] + [("object", n, b) for n, b in s["objects"]]
    for i, (ka, na, a) in enumerate(things):
        for kb, nb, b in things[i + 1:]:
            if cross(a, b):
                print("scene %d at %d ms: %s %s overlaps %s %s" % (s["scene"], s["t"], ka, na, kb, nb)); sys.exit(1)
' || { why="$example: $why"; return 1; }
  done
}

chart_lines_are_the_same_while_nodes_pop_in_and_at_rest() {
  build_probe || return 1
  js chart <<'JS'
const end0 = MX.SCENE_T[1] - 1;
MX.seek(end0, false);
const chart = video.querySelector('.obj[data-object="chart"]');
const lines = () => [...chart.querySelectorAll('svg.edges path.line')].filter(p => !p.hasAttribute('data-off')).map(p => p.getAttribute('d'));
out.rest = lines();
// A node popping in is scaled and moved by its animation; the lines must not follow that.
chart.querySelectorAll('.node').forEach(n => { n.style.transform = 'translate(17px, 23px) scale(.4)'; });
MX.seek(end0, false);
out.popping = lines();
JS
  probe_js "$WORK/probe.html" chart 1000 || return 1
  judge chart '
if len(got["rest"]) != 3 or not all(got["rest"]):
    print("the chart draws %d lines at rest, want 3" % len(got["rest"])); sys.exit(1)
if got["popping"] != got["rest"]:
    print("the lines move with the nodes while they pop in"); sys.exit(1)
'
}

a_holder_hangs_and_stands_its_items_on_the_anchor_line() {
  build_probe || return 1
  js holder <<'JS'
const shownImg = scope => [...scope.querySelectorAll('.hslot .npic img')].filter(i => i.style.opacity !== '0');
MX.seek(MX.SCENE_T[2] - 1, false);
const rail = video.querySelector('.obj[data-object="rail"]'), rs = rail.querySelector('.hstage').getBoundingClientRect();
out.hang = shownImg(rail).map(i => (i.getBoundingClientRect().top - rs.top) / rs.height);
MX.seek(MX.SCENE_T[3] - 1, false);
const folder = video.querySelector('.obj[data-object="folder"]'), stage = folder.querySelector('.hstage'), fs = stage.getBoundingClientRect();
const item = shownImg(folder)[0], ir = item.getBoundingClientRect();
out.stand = (ir.bottom - fs.top) / fs.height;
const front = stage.querySelector(':scope > .hf');
stage.querySelectorAll('img').forEach(i => { i.style.pointerEvents = 'auto'; });
out.frontOnTop = !!front && document.elementFromPoint(ir.left + ir.width / 2, ir.bottom - 3) === front;
JS
  probe_js "$WORK/probe.html" holder 1000 || return 1
  judge holder '
if len(got["hang"]) != 2 or any(abs(y - expect["hang"]) > 0.012 for y in got["hang"]):
    print("the hung tags start at %s of the rail, want %.3f" % (["%.3f" % y for y in got["hang"]], expect["hang"])); sys.exit(1)
if abs(got["stand"] - expect["rim"]) > 0.012:
    print("the standing tag ends at %.3f of the folder, want %.3f" % (got["stand"], expect["rim"])); sys.exit(1)
if not got["frontOnTop"]:
    print("the front of the folder does not cover the lower part of the standing tag"); sys.exit(1)
'
}

a_screen_zooms_to_a_rect_of_a_taller_page() {
  build_probe || return 1
  js screen <<'JS'
const r = e => e.getBoundingClientRect();
MX.seek(MX.SCENE_T[3] + 1, false);
const scr = video.querySelector('.obj[data-object="page"]'), vp = scr.querySelector('.vp'), shot = scr.querySelector('.shot');
out.top = { shotTop: r(shot).top - r(vp).top, shotH: r(shot).height, vpH: r(vp).height };
MX.seek(MX.SCENE_T[4] - 1, false);
const m = r(shot.querySelector('.mark')), v = r(vp);
out.focus = { inside: m.left >= v.left - 1 && m.right <= v.right + 1 && m.top >= v.top - 1 && m.bottom <= v.bottom + 1,
              fill: Math.max(m.width / v.width, m.height / v.height) };
JS
  probe_js "$WORK/probe.html" screen 1000 || return 1
  judge screen '
t, f = got["top"], got["focus"]
if abs(t["shotTop"]) > 1 or t["shotH"] < 1.5 * t["vpH"]:
    print("the window does not show the top of a taller page: %s" % t); sys.exit(1)
if not f["inside"] or f["fill"] < 0.75:
    print("the named rect does not fill the window: %s" % f); sys.exit(1)
'
}

a_beat_fires_its_effect_and_a_jump_fires_none() {
  build_probe || return 1
  js effects <<'JS'
const log = [], FX = window.SakugaFX;
for (const name of ['sfx', 'burst', 'shards', 'puff', 'kira', 'slash', 'ring']) {
  const f = FX[name];
  if (typeof f === 'function') FX[name] = function (...a) { log.push({ kind: name, word: name === 'sfx' ? a[0] : null }); return f.apply(this, a); };
}
MX.seek(0, true);
await wait(MX.END + 1500);
out.played = log.splice(0);
for (let i = 0; i < MX.SCENE_T.length; i++) { MX.seek((MX.SCENE_T[i + 1] ?? MX.END) - 1, false); await wait(1200); }
out.jumped = log.splice(0);
JS
  probe_js "$WORK/probe.html" effects 1000 || return 1
  judge effects '
words = sorted(f["word"] for f in got["played"] if f["kind"] == "sfx")
if words != ["don", "kachi", "pon"]:
    print("playing fired the words %s, want don, kachi, and pon" % words); sys.exit(1)
if not any(f["kind"] == "burst" for f in got["played"]):
    print("playing fired no burst"); sys.exit(1)
if got["jumped"]:
    print("jumping fired %s" % sorted({f["kind"] for f in got["jumped"]})); sys.exit(1)
'
}

the_video_plays_pauses_and_jumps_to_a_step_from_the_bar() {
  build_probe || return 1
  js player <<'JS'
const stepNow = () => { const c = video.querySelector('.step .cur:not(.out)'); return c ? c.textContent : ''; };
out.autoplay = !video.hasAttribute('data-paused') && MX.playing();
await wait(700);
out.firstStep = stepNow();
video.click();
const t1 = MX.now();
await wait(500);
out.pauseHeld = video.hasAttribute('data-paused') && !MX.playing() && MX.now() === t1;
const button = document.getElementById('me-play');
out.button = !!button;
if (button) { button.click(); await wait(400); out.resumed = MX.playing() && MX.now() > t1; }
await wait(MX.END + 2000);
out.ended = !MX.playing() && MX.now() === MX.END;
out.replay = button ? button.textContent.trim() : null;
const segs = [...video.querySelectorAll('.progress .seg')];
out.segs = segs.length;
out.steps = MX.steps.map(s => s.name);
if (segs[2]) { segs[2].click(); await wait(100); out.jump = { t: MX.now(), from: MX.steps[2].t, playing: MX.playing(), step: stepNow() }; }
JS
  probe_js "$WORK/probe.html" player 1000 || return 1
  judge player '
if not got["autoplay"]:
    print("the video does not play by itself"); sys.exit(1)
if "One" not in got["firstStep"]:
    print("the first step is named %r under the title" % got["firstStep"]); sys.exit(1)
if not got["pauseHeld"]:
    print("a click does not pause the video"); sys.exit(1)
if not got["button"] or not got.get("resumed"):
    print("the play button does not resume the video"); sys.exit(1)
if not got["ended"] or got["replay"] != "Replay":
    print("the video does not stop at its end with the button offering a replay (%r)" % got["replay"]); sys.exit(1)
if got["segs"] != 4 or got["steps"] != ["One", "Two", "Three", "Four"]:
    print("the bar has %d segments for the steps %s, want 4" % (got["segs"], got["steps"])); sys.exit(1)
j = got.get("jump") or {}
if not j or not (j["from"] <= j["t"] <= j["from"] + 300) or not j["playing"] or "Three" not in j["step"]:
    print("the third segment does not play from the start of its step: %s" % j); sys.exit(1)
'
}

figures_under_the_video_draw_from_the_scripts_objects() {
  build_probe || return 1
  js figures <<'JS'
const sc = window.MX_SCRIPT, th = window.MX_THEME;
const picOf = (target, state) => {
  const [oid, pid] = target.split('.'), o = sc.objects[oid];
  const spec = pid ? (o.levels ? o.levels.flat() : o.items || []).find(n => n.id === pid) : o;
  return th.images[state ? (spec.states || {})[state] : spec.image];
};
const figs = document.getElementById('me-figures');
out.kinds = [...figs.querySelectorAll('figure[data-kind]')].map(f => f.dataset.kind);
const imgs = kind => [...figs.querySelectorAll(`figure[data-kind="${kind}"] img[data-target]`)]
  .map(i => ({ target: i.dataset.target, state: i.dataset.state || '', same: i.getAttribute('src') === picOf(i.dataset.target, i.dataset.state) }));
out.flow = imgs('flow');
out.compare = imgs('compare');
const still = figs.querySelector('figure[data-kind="still"]');
out.still = still && { objects: [...still.querySelectorAll('.obj[data-object]:not([data-off])')].map(o => o.dataset.object),
                       marks: still.querySelectorAll('[data-mark]').length, labels: [...still.querySelectorAll('li')].map(l => l.textContent.trim()) };
const table = figs.querySelector('figure[data-kind="table"] table');
out.table = table && { cols: table.querySelectorAll('thead th').length, rows: table.querySelectorAll('tbody tr').length };
out.text = [...figs.querySelectorAll('figure[data-kind]')].map(f => f.textContent);
JS
  probe_js "$WORK/probe.html" figures 1000 || return 1
  judge figures '
s = json.load(open(os.path.join(os.path.dirname(sys.argv[3]), "script.json")))
figs = s["figures"]
if got["kinds"] != [f["kind"] for f in figs]:
    print("the figures are %s" % got["kinds"]); sys.exit(1)
for fig, text in zip(figs, got["text"]):
    if fig["question"] not in text:
        print("the %s figure does not ask %r" % (fig["kind"], fig["question"])); sys.exit(1)
want_flow = [(x["target"], x.get("state", "")) for x in figs[1]["steps"]]
if [(x["target"], x["state"]) for x in got["flow"]] != want_flow or not all(x["same"] for x in got["flow"]):
    print("the flow draws %s, not the pictures of %s" % (got["flow"], want_flow)); sys.exit(1)
if [x["target"] for x in got["compare"]] != [x["target"] for x in figs[2]["sides"]] or not all(x["same"] for x in got["compare"]):
    print("the comparison draws %s" % got["compare"]); sys.exit(1)
st = got["still"] or {}
labels = list(figs[0]["labels"].values())
if st.get("objects") != s["scenes"][0]["objects"] or st.get("marks") != len(labels) or not all(any(l in x for x in st.get("labels", [])) for l in labels):
    print("the still does not show scene 0 with its labels: %s" % st); sys.exit(1)
if got["table"] != {"cols": 2, "rows": 3}:
    print("the table is %s, want 2 columns and 3 rows" % got["table"]); sys.exit(1)
'
}

# --- 4. capture and the examples ---------------------------------------------------------------------

capture_saves_scene_frames_and_a_sheet_and_prints_page_errors() {
  need "$CAPTURE" || return 1
  build_probe || return 1
  js end <<'JS'
out.end = MX.END; out.scenes = MX.SCENE_T.length;
JS
  probe_js "$WORK/probe.html" end 1000 || return 1
  python3 "$CAPTURE" scenes "$WORK/probe.html" "$WORK/frames" > "$WORK/frames.out" 2>&1 || { why="capture scenes exited $?: $(head -2 "$WORK/frames.out" | tr '\n' ' ')"; return 1; }
  python3 "$CAPTURE" sheet "$WORK/probe.html" "$WORK/sheet.png" --every 2000 > "$WORK/sheet.out" 2>&1 || { why="capture sheet exited $?: $(head -2 "$WORK/sheet.out" | tr '\n' ' ')"; return 1; }
  python3 - "$WORK/probe.html" "$WORK/broken.html" <<'PY'
import sys
page = open(sys.argv[1]).read()
j = page.rfind("</body>")
open(sys.argv[2], "w").write(page[:j] + "<script>setTimeout(() => { throw new Error('probe-boom'); }, 900);</script>" + page[j:])
PY
  python3 "$CAPTURE" scenes "$WORK/broken.html" "$WORK/broken-frames" > "$WORK/broken.out" 2>&1; local status=$?
  why="$(python3 - "$WORK/end.json" "$WORK/frames" "$WORK/frames.out" "$WORK/sheet.png" "$WORK/sheet.out" "$WORK/broken.out" "$status" <<'PY'
import json, os, struct, sys
end, frames, frames_out, sheet, sheet_out, broken_out, status = sys.argv[1:8]
got = json.load(open(end))
def size(path):
    raw = open(path, "rb").read(24)
    return struct.unpack(">II", raw[16:24]) if raw[:8] == b"\x89PNG\r\n\x1a\n" else None
for i in range(1, got["scenes"] + 1):
    for when in ("mid", "end"):
        path = os.path.join(frames, "scene-%02d-%s.png" % (i, when))
        if not os.path.exists(path) or size(path) != (896, 504):
            print("no 896 x 504 frame %s" % os.path.basename(path)); sys.exit(1)
if "page errors: 0" not in open(frames_out).read():
    print("capture scenes did not report the errors of the page"); sys.exit(1)
frames_in_sheet = got["end"] // 2000 + 1
if not os.path.exists(sheet) or not size(sheet) or "sheet: %d frames every 2000 ms" % frames_in_sheet not in open(sheet_out).read():
    print("capture sheet did not save %d frames" % frames_in_sheet); sys.exit(1)
if "page errors: 0" not in open(sheet_out).read():
    print("capture sheet did not report the errors of the page"); sys.exit(1)
text = open(broken_out).read()
if status != "1" or "page error:" not in text or "probe-boom" not in text:
    print("capture did not print the error of a broken page (exit %s)" % status); sys.exit(1)
PY
)" || return 1
  why=""
}

both_examples_build_as_scripts_with_the_default_theme() {
  need "$CACHE_SCRIPT" "$REDELIVERY_SCRIPT" "$PIXEL/theme.json" || return 1
  build "$PIXEL" "$CACHE_SCRIPT" "$WORK/cache-pixel.html" || return 1
  build "$PIXEL" "$REDELIVERY_SCRIPT" "$WORK/redelivery-pixel.html" || return 1
  js example <<'JS'
out.scenes = MX.SCENE_T.length; out.steps = MX.steps.length; out.figures = document.querySelectorAll('#me-figures figure[data-kind]').length;
JS
  local example script
  for example in cache redelivery; do
    script="$CACHE_SCRIPT"; [ "$example" = redelivery ] && script="$REDELIVERY_SCRIPT"
    cp "$WORK/example.js" "$WORK/example-$example.js"
    probe_js "$WORK/$example-pixel.html" "example-$example" 1000 || return 1
    judge "example-$example" '
s = json.load(open("'"$script"'"))
if got["scenes"] != len(s["scenes"]) or got["steps"] < 2 or got["figures"] != len(s.get("figures", [])):
    print("the video has %d scenes, %d steps, and %d figures" % (got["scenes"], got["steps"], got["figures"])); sys.exit(1)
' || { why="$example: $why"; return 1; }
  done
}

# --- 5. references, SKILL.md, the bundle, and paths --------------------------------------------------

references_describe_every_field_of_a_theme_and_a_script() {
  need "$SCHEMA" "$ENGINE/engine.js" || return 1
  why="$(python3 - "$SCHEMA" "$ENGINE/engine.js" "$SKILL_DIR/references" <<'PY'
import glob, importlib.util, os, re, sys
spec = importlib.util.spec_from_file_location("schema", sys.argv[1])
schema = importlib.util.module_from_spec(spec); spec.loader.exec_module(schema)
engine = open(sys.argv[2]).read()
block = engine[engine.find("const DO = {"):]
block = block[:block.find("\n};")]
runs = set(re.findall(r"^  (\w+)\(", block, re.M))
missing = sorted(runs - set(schema.ACTIONS))
if missing:
    print("the schema does not name the beat actions %s" % missing); sys.exit(1)
rows = "\n".join(line for path in glob.glob(os.path.join(sys.argv[3], "*.md")) for line in open(path) if line.startswith("|"))
named = lambda word: "`%s`" % word in rows
for section, fields in schema.FIELDS.items():
    for field in fields:
        if not named(field):
            print("references/ do not describe %s.%s" % (section, field)); sys.exit(1)
for action, fields in schema.ACTIONS.items():
    for word in [action] + list(fields):
        if not named(word):
            print("references/ do not describe %s of the beat %s" % (word, action)); sys.exit(1)
PY
)" || return 1
  why=""
}

skill_md_walks_composition_script_build_capture_words_check_and_show() {
  python3 - "$SKILL_DIR/SKILL.md" <<'PY' || { why="SKILL.md misses a step or puts them out of order"; return 1; }
import sys
text = open(sys.argv[1]).read().lower()
order = ["plan the composition", "write the script", "build.py", "capture.py", "check the words", "show the page"]
at = [text.find(w) for w in order]
sys.exit(0 if all(a >= 0 for a in at) and at == sorted(at) else 1)
PY
}

skill_md_keeps_lines_to_one_sentence_and_labels_to_names() {
  python3 - "$SKILL_DIR/SKILL.md" <<'PY' || { why="SKILL.md does not keep a line to one short sentence in a speech bubble and a label to the name of a thing"; return 1; }
import sys
text = " ".join(open(sys.argv[1]).read().lower().split())
sys.exit(0 if all(w in text for w in ("one short sentence", "speech bubble", "the name of a thing")) else 1)
PY
}

no_absolute_path_to_another_repository_or_a_home_folder() {
  # The files carried over from the earlier engine are the ones that pointed at other folders.
  need "$BUILD" "$CAPTURE" "$ENGINE/engine.js" "$ENGINE/engine.css" "$PIXEL/theme.json" "$CACHE_SCRIPT" "$REDELIVERY_SCRIPT" || return 1
  why="$(python3 - "$PLUGIN" <<'PY'
import os, re, sys
home = re.compile("/" + "Users/[^/\"' ]+|/" + "home/[^/\"' ]+|[A-Z]:\\\\" + "Users\\\\|/private/" + "(tmp|var)/|/tmp/" + "claude")
for root, dirs, files in os.walk(sys.argv[1]):
    dirs[:] = [d for d in dirs if d not in (".git", "__pycache__")]
    for name in files:
        path = os.path.join(root, name)
        try:
            text = open(path, encoding="utf-8").read()
        except (UnicodeDecodeError, OSError):
            continue
        m = home.search(text)
        if m:
            print("%s names %s" % (os.path.relpath(path, sys.argv[1]), m.group(0))); sys.exit(1)
PY
)" || return 1
  why=""
}

# --- checks of the earlier form: render, probe, and refuse ------------------------------------------

render_one() {  # render_one <spec> <page>
  [ -s "$2" ] && return 0
  python3 "$TOOL" render "$1" --out "$2" > "$2.out" 2>&1 || { why="render exited $?: $(head -3 "$2.out" | tr '\n' ' ')"; return 1; }
}

render_cache() { render_one "$CACHE/spec.json" "$WORK/cache.html"; }

# probe <name> <width> <hash> [--reduced-motion]: opens the cache page and saves what the page reports.
probe() {
  render_cache || return 1
  local name="$1" width="$2" hash="$3"; shift 3
  python3 "$BROWSER" dump "file://$WORK/cache.html#$hash" --size "${width}x900" "$@" > "$WORK/$name.dom" 2> "$WORK/$name.err" || { why="no browser: $(head -1 "$WORK/$name.err")"; return 1; }
  python3 - "$WORK/$name.dom" "$WORK/$name.json" <<'PY' || { why="the page reported nothing"; return 1; }
import html, re, sys
m = re.search(r'<pre[^>]*id="me-probe"[^>]*>(.*?)</pre>', open(sys.argv[1]).read(), re.S)
if not m:
    sys.exit(1)
open(sys.argv[2], "w").write(html.unescape(m.group(1)))
PY
}

# The end state of every scene, worked out from the spec: states, places, the speaker and its pose.
expected() {
  python3 - "$CACHE/spec.json" "$WORK/expected.json" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
state = {p["id"]: p["states"][0] for p in s["parts"]}
place = {p["id"]: list(p["at"]) for p in s["parts"]}
cast = s.get("cast") or []
out = []
for sc in s["scenes"]:
    for pid, st in sc.get("set", {}).items():
        state[pid] = st
    for pid, xy in sc.get("move", {}).items():
        place[pid] = list(xy)
    out.append({"speaker": sc.get("speaker", cast[0]["id"] if cast else None), "pose": sc.get("pose", "explain"),
                "states": dict(state), "at": {k: list(v) for k, v in place.items()}})
json.dump({"cast": cast, "scenes": out}, open(sys.argv[2], "w"))
PY
}

render_writes_one_offline_page() {
  render_cache || return 1
  python3 - "$WORK/cache.html" "$CACHE/spec.json" <<'PY' || { why="the page loads from outside, misses a part, or puts the figures first"; return 1; }
import json, re, sys
page = open(sys.argv[1]).read()
spec = json.load(open(sys.argv[2]))
if re.search(r'\b(src|href)\s*=\s*["\']?(https?:)?//', page, re.I):
    sys.exit(1)
if re.search(r'url\(\s*["\']?(https?:)?//', page, re.I) or "@import" in page:
    sys.exit(1)
player, figures = page.find('id="me-player"'), page.find('id="me-figures"')
if player < 0 or figures < 0 or player > figures:
    sys.exit(1)
for p in spec["parts"]:
    if 'data-part="%s"' % p["id"] not in page:
        sys.exit(1)
PY
}

# The speaker takes the pose; every other cast member waits.
speaker_and_poses_match() {  # speaker_and_poses_match <scenes.json>
  python3 - "$1" "$WORK/expected.json" <<'PY'
import json, sys
got = json.load(open(sys.argv[1]))["scenes"]
want = json.load(open(sys.argv[2]))
names = {c["id"]: c["name"] for c in want["cast"]}
order = ["wait", "explain", "surprised", "cheer"]
for i, (g, w) in enumerate(zip(got, want["scenes"])):
    for cid in names:
        pose = w["pose"] if cid == w["speaker"] else "wait"
        if g["poses"].get(cid) != pose or abs(g["frames"][cid] - order.index(pose) * 100 / 3) > 0.5:
            print("scene %d: %s is %r, want %r" % (i, cid, g["poses"].get(cid), pose)); sys.exit(1)
PY
}

reduced_motion_fires_no_effect_and_still_changes_poses() {
  expected
  probe reduced-fired 1000 "probe&wait=all" --reduced-motion || return 1
  python3 - "$WORK/reduced-fired.json" <<'PY' || { why="effects fired with reduced motion"; return 1; }
import json, sys
sys.exit(0 if json.load(open(sys.argv[1])).get("fired") == [] else 1)
PY
  [ $? -eq 0 ] || return 1
  probe reduced-scenes 1000 "probe&scenes" --reduced-motion || return 1
  why="$(speaker_and_poses_match "$WORK/reduced-scenes.json")" || return 1
  why=""
}

reduced_motion_shows_each_scene_at_its_end() {
  expected
  probe reduced 1000 "probe&wait=all" --reduced-motion || return 1
  python3 - "$WORK/reduced.json" <<'PY' || { why="the player moved or played with reduced motion"; return 1; }
import json, sys
g = json.load(open(sys.argv[1]))
sys.exit(0 if g["playing"] is False and g["played"] <= 1 and g["transition"] in ("0s", "") else 1)
PY
  [ $? -eq 0 ] || return 1
  probe reduced-chapter 1000 "probe&chapter=4" --reduced-motion || return 1
  python3 - "$WORK/reduced-chapter.json" "$WORK/expected.json" <<'PY' || { why="a chapter with reduced motion did not show its end state"; return 1; }
import json, sys
g = json.load(open(sys.argv[1])); w = json.load(open(sys.argv[2]))["scenes"][4]
ok = g["scene"] == 4 and g["states"] == w["states"] and g["transition"] in ("0s", "")
ok = ok and all(abs(g["at"][k][0] - v[0]) < 0.5 and abs(g["at"][k][1] - v[1]) < 0.5 for k, v in w["at"].items())
sys.exit(0 if ok else 1)
PY
}

a_phone_width_has_no_sideways_scroll_and_readable_scene_text() {
  probe phone 390 "probe&wait=all" || return 1
  python3 - "$WORK/phone.json" <<'PY' || { why="the page scrolls sideways or scene text is under 12 px"; return 1; }
import json, sys
g = json.load(open(sys.argv[1]))
sys.exit(0 if g["scrollWidth"] <= g["innerWidth"] and g["minFont"] >= 12 else 1)
PY
}

the_page_reads_in_light_and_dark() {
  render_cache || return 1
  grep -q 'prefers-color-scheme: dark' "$WORK/cache.html" || { why="no dark scheme in the page"; return 1; }
  grep -q 'data-theme-choice="dark"' "$WORK/cache.html" || { why="no theme switch"; return 1; }
  probe dark 1000 "probe&theme=dark" || return 1
  probe light 1000 "probe&theme=light" || return 1
  python3 - "$WORK/dark.json" "$WORK/light.json" <<'PY' || { why="the page does not turn dark and light"; return 1; }
import json, re, sys
def lum(c):
    r, g, b = [int(x) / 255 for x in re.findall(r"\d+", c)[:3]]
    return 0.2126 * r + 0.7152 * g + 0.0722 * b
d, l = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
ok = lum(d["background"]) < 0.35 and lum(d["color"]) > 0.6 and lum(l["background"]) > 0.8 and lum(l["color"]) < 0.4
sys.exit(0 if ok else 1)
PY
}

# The bundled core is the upstream file at the pinned commit, its license sits next to it, and the
# page holds the core once.
the_effects_core_is_bundled_unmodified_with_its_license() {
  render_cache || return 1
  why="$(python3 - "$CORE_DIR" "$WORK/cache.html" "$UPSTREAM_SHA256" <<'PY'
import hashlib, json, os, re, sys
folder, page, want = sys.argv[1], open(sys.argv[2]).read(), sys.argv[3]
try:
    core = open(os.path.join(folder, "core.js"), "rb").read()
    pin = json.load(open(os.path.join(folder, "pin.json")))
    lic = open(os.path.join(folder, "LICENSE")).read()
except (OSError, ValueError) as e:
    print("the bundle is incomplete: %s" % e); sys.exit(1)
digest = hashlib.sha256(core).hexdigest()
if digest != want or pin.get("sha256") != want:
    print("core.js is not the upstream file (sha256 %s)" % digest); sys.exit(1)
if not re.fullmatch(r"[0-9a-f]{40}", str(pin.get("commit", ""))) or pin.get("repo") != "finktheartist/sakuga-vfx":
    print("pin.json does not name the repository and the commit"); sys.exit(1)
if "MIT License" not in lic or "Permission is hereby granted" not in lic:
    print("LICENSE is not the MIT license"); sys.exit(1)
if page.count("const api = window.SakugaFX = {") != 1:
    print("the page holds the core %d times" % page.count("const api = window.SakugaFX = {")); sys.exit(1)
PY
)" || return 1
  why=""
}

# A copy of the cache example in the work folder, its spec changed by a Python expression on `s`.
variant() {  # variant <name> <expr>
  rm -rf "$WORK/$1"; cp -R "$CACHE" "$WORK/$1"
  python3 - "$WORK/$1/spec.json" "$2" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
exec(sys.argv[2])
open(sys.argv[1], "w").write(json.dumps(s, ensure_ascii=False))
PY
}

refuses() {  # refuses <spec> <field that must be named>
  local out status
  out="$(python3 "$TOOL" check "$1" 2>&1)"; status=$?
  [ "$status" -eq 1 ] || { why="check exited $status for $2"; return 1; }
  printf '%s' "$out" | grep -qF "$2" || { why="check did not name $2"; return 1; }
  python3 "$TOOL" render "$1" --out "$1.html" > /dev/null 2>&1
  [ ! -e "$1.html" ] || { why="render wrote a page for $2"; return 1; }
}

unsafe_art() {  # unsafe_art <name> <text to put before </svg>>
  variant "$1" 'pass'
  python3 - "$WORK/$1/art/browser.svg" "$2" <<'PY'
import sys
path, extra = sys.argv[1], sys.argv[2]
svg = open(path).read()
open(path, "w").write(svg.replace("</svg>", extra + "\n</svg>"))
PY
  refuses "$WORK/$1/spec.json" "parts[0].art"
}

check_refuses_art_that_loads_from_outside_or_runs_a_script() {
  unsafe_art script '<script>alert(1)</script>' || return 1
  unsafe_art handler '<rect width="2" height="2" onclick="alert(1)"/>' || return 1
  unsafe_art outside '<use href="https://example.com/a.svg#x"/>' || return 1
  unsafe_art outside-url '<rect width="2" height="2" style="fill: url(https://example.com/x)"/>' || return 1
  unsafe_art foreign '<foreignObject width="2" height="2"><div>x</div></foreignObject>' || return 1
}

check "build reads a theme folder from outside the plugin" build_reads_a_theme_folder_from_outside_the_plugin
check "render writes one offline page with the player first" render_writes_one_offline_page
check "build refuses a broken script and names the field" build_refuses_a_broken_script_and_names_the_field
check "check refuses art that loads from outside or runs a script" check_refuses_art_that_loads_from_outside_or_runs_a_script
check "build without uv says how to install it" build_without_uv_says_how_to_install_it
check "the default theme casts the four bodies with their poses as faces" the_default_theme_casts_the_four_bodies_with_their_poses_as_faces
check "the art comes only from the theme and the script" the_art_comes_only_from_the_theme_and_the_script
check "actors and objects never overlap in any scene" actors_and_objects_never_overlap_in_any_scene
check "chart lines are the same while nodes pop in and at rest" chart_lines_are_the_same_while_nodes_pop_in_and_at_rest
check "a holder hangs and stands its items on the anchor line" a_holder_hangs_and_stands_its_items_on_the_anchor_line
check "a screen zooms to a rect of a taller page" a_screen_zooms_to_a_rect_of_a_taller_page
check "a beat fires its effect, and a jump fires none" a_beat_fires_its_effect_and_a_jump_fires_none
check "the video plays, pauses, and jumps to a step from the bar" the_video_plays_pauses_and_jumps_to_a_step_from_the_bar
check "reduced motion shows each scene at its end" reduced_motion_shows_each_scene_at_its_end
check "reduced motion fires no effect and still changes poses" reduced_motion_fires_no_effect_and_still_changes_poses
check "a phone width has no sideways scroll and readable scene text" a_phone_width_has_no_sideways_scroll_and_readable_scene_text
check "the page reads in light and dark" the_page_reads_in_light_and_dark
check "figures under the video draw from the script's objects" figures_under_the_video_draw_from_the_scripts_objects
check "the effects core is bundled unmodified with its license" the_effects_core_is_bundled_unmodified_with_its_license
check "capture saves scene frames and a sheet and prints page errors" capture_saves_scene_frames_and_a_sheet_and_prints_page_errors
check "both examples build as scripts with the default theme" both_examples_build_as_scripts_with_the_default_theme
check "references describe every field of a theme and a script" references_describe_every_field_of_a_theme_and_a_script
check "SKILL.md walks composition, script, build, capture, words check, and show" skill_md_walks_composition_script_build_capture_words_check_and_show
check "SKILL.md keeps lines to one sentence and labels to names" skill_md_keeps_lines_to_one_sentence_and_labels_to_names
check "no absolute path to another repository or a home folder" no_absolute_path_to_another_repository_or_a_home_folder

echo "[test-motion-explainer] ran: $((PASS + FAIL))"
echo "[test-motion-explainer] PASS: $PASS, FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "failed cases:"
  for name in "${FAILED[@]}"; do echo "    $name"; done
  exit 1
fi
exit 0
