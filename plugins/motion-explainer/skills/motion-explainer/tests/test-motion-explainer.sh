#!/bin/bash
# Tests for motion-explainer: a spec and the SVG art an agent draws for one subject become one HTML
# page with a player that walks one running example scene by scene, and figures under it.
#
# What is checked:
#   1. render writes one page that loads nothing from the network, with the player before the figures.
#   2. In a headless browser: each scene shows its line and marks only the parts that change, the
#      speaker of each scene takes its pose while the rest of the cast waits, a cast member stands
#      beside the bubble or on the stage, a scene fires its burst and word and moved parts land in
#      puffs, the player plays once, pauses, resumes, and opens a chapter in its end state, reduced
#      motion shows each scene at its end and fires no effect, a phone width has no sideways scroll,
#      and the page reads in light and dark.
#   3. The cast comes from the four bodies the skill ships, the part art comes only from the spec,
#      the effects core is bundled unmodified with its license, and the figures draw from the same
#      parts without dragon.
#   4. check refuses a broken spec, a broken cast or effect, and unsafe art, naming the field, and
#      render writes nothing for them.
#   5. SKILL.md walks from the art direction through the cast and effects to the page.
#
# The browser cases open the page with #probe and read what the page writes into <pre id="me-probe">.
# Exit 0 when every case passes, 1 when any fails (the failing cases are listed).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN="$(cd "$SKILL_DIR/../.." && pwd)"
TOOL="$SKILL_DIR/scripts/motion_explainer.py"
BROWSER="$SKILL_DIR/scripts/browser.py"
CACHE="$PLUGIN/examples/cache"
REDELIVERY="$PLUGIN/examples/redelivery"
BODIES="$SKILL_DIR/characters"
CORE_DIR="$SKILL_DIR/vendor/sakuga-vfx"
# core.js of Sakuga VFX at the pinned commit, as published; the bundled copy must be this file.
UPSTREAM_SHA256="f0518dd7d4dd1986eab2c9c76796421f4c827e91eac627f4c91a63c362c79419"
export PYTHONDONTWRITEBYTECODE=1

WORK="$(mktemp -d "${TMPDIR:-/tmp}/motion-explainer-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

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

render_one() {  # render_one <spec> <page>
  [ -s "$2" ] && return 0
  python3 "$TOOL" render "$1" --out "$2" > "$2.out" 2>&1 || { why="render exited $?: $(head -3 "$2.out" | tr '\n' ' ')"; return 1; }
}

render_cache() { render_one "$CACHE/spec.json" "$WORK/cache.html"; }

# probe <name> <width> <hash> [--reduced-motion]: opens the cache page and saves what the page reports.
probe() {
  render_cache || return 1
  probe_page "$WORK/cache.html" "$@"
}

# probe_page <page> <name> <width> <hash> [--reduced-motion]: the same for any rendered page.
probe_page() {
  local page="$1" name="$2" width="$3" hash="$4"; shift 4
  python3 "$BROWSER" dump "file://$page#$hash" --size "${width}x900" "$@" > "$WORK/$name.dom" 2> "$WORK/$name.err" || { why="no browser: $(head -1 "$WORK/$name.err")"; return 1; }
  python3 - "$WORK/$name.dom" "$WORK/$name.json" <<'PY' || { why="the page reported nothing"; return 1; }
import html, re, sys
m = re.search(r'<pre[^>]*id="me-probe"[^>]*>(.*?)</pre>', open(sys.argv[1]).read(), re.S)
if not m:
    sys.exit(1)
open(sys.argv[2], "w").write(html.unescape(m.group(1)))
PY
}

# The end state of every scene, worked out from the spec: states, places, the parts that change and
# move, the speaker and its pose, and the effect the scene names.
expected() {
  python3 - "$CACHE/spec.json" "$WORK/expected.json" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
state = {p["id"]: p["states"][0] for p in s["parts"]}
place = {p["id"]: list(p["at"]) for p in s["parts"]}
cast = s.get("cast") or []
out = []
for sc in s["scenes"]:
    changed, moved = set(), set()
    for pid, st in sc.get("set", {}).items():
        if state[pid] != st:
            changed.add(pid)
        state[pid] = st
    for pid, xy in sc.get("move", {}).items():
        if place[pid] != list(xy):
            changed.add(pid)
            moved.add(pid)
        place[pid] = list(xy)
    out.append({"line": sc["line"], "changed": sorted(changed), "moved": sorted(moved),
                "speaker": sc.get("speaker", cast[0]["id"] if cast else None), "pose": sc.get("pose", "explain"),
                "fx": sc.get("fx"), "states": dict(state), "at": {k: list(v) for k, v in place.items()}})
json.dump({"cast": cast, "scenes": out}, open(sys.argv[2], "w"))
PY
}

# --- 1. render ------------------------------------------------------------------------------------

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

# --- 2. in a headless browser ---------------------------------------------------------------------

scenes_report() {
  [ -s "$WORK/scenes.json" ] && return 0
  probe scenes 1000 "probe&scenes" || return 1
  expected
}

each_scene_shows_its_line_and_marks_only_the_parts_that_change() {
  scenes_report || return 1
  why="$(python3 - "$WORK/scenes.json" "$WORK/expected.json" <<'PY'
import json, sys
got = json.load(open(sys.argv[1]))["scenes"]
want = json.load(open(sys.argv[2]))["scenes"]
if len(got) != len(want):
    print("scenes %d, want %d" % (len(got), len(want))); sys.exit(1)
for i, (g, w) in enumerate(zip(got, want)):
    if g["line"] != w["line"]:
        print("scene %d shows %r" % (i, g["line"])); sys.exit(1)
    if sorted(g["changed"]) != w["changed"]:
        print("scene %d marks %s, want %s" % (i, sorted(g["changed"]), w["changed"])); sys.exit(1)
PY
)" || return 1
  why=""
}

# The speaker takes the pose; every other cast member waits. A body shows one pose of its sheet of
# four (wait, explain, surprised, cheer), so the sheet's position says which pose is on screen.
speaker_and_poses_match() {  # speaker_and_poses_match <scenes.json>
  python3 - "$1" "$WORK/expected.json" <<'PY'
import json, sys
got = json.load(open(sys.argv[1]))["scenes"]
want = json.load(open(sys.argv[2]))
names = {c["id"]: c["name"] for c in want["cast"]}
order = ["wait", "explain", "surprised", "cheer"]
if not names:
    print("the spec has no cast"); sys.exit(1)
for i, (g, w) in enumerate(zip(got, want["scenes"])):
    if g.get("speaker") != w["speaker"] or g.get("who") != names.get(w["speaker"]):
        print("scene %d: the bubble is %r (%r), want %r" % (i, g.get("speaker"), g.get("who"), w["speaker"])); sys.exit(1)
    for cid in names:
        pose = w["pose"] if cid == w["speaker"] else "wait"
        if g["poses"].get(cid) != pose:
            print("scene %d: %s is %r, want %r" % (i, cid, g["poses"].get(cid), pose)); sys.exit(1)
        if abs(g["frames"][cid] - order.index(pose) * 100 / 3) > 0.5:
            print("scene %d: %s shows the frame at %s%%, not %s" % (i, cid, g["frames"][cid], pose)); sys.exit(1)
    if not g.get("partsShowOnlyTheirStates"):
        print("scene %d: a part shows drawings of other states" % i); sys.exit(1)
PY
}

the_speaker_takes_the_scenes_pose_and_the_others_wait() {
  scenes_report || return 1
  why="$(speaker_and_poses_match "$WORK/scenes.json")" || return 1
  why=""
}

a_cast_member_stands_beside_the_bubble_or_on_the_stage() {
  variant onstage 's["cast"].append({"id": "kai", "body": "guide", "name": "Kai", "at": [4, 62]}); s["scenes"][1]["speaker"] = "kai"; s["scenes"][1]["pose"] = "surprised"'
  python3 "$TOOL" render "$WORK/onstage/spec.json" --out "$WORK/onstage.html" > "$WORK/onstage.out" 2>&1 || { why="render refused a cast member on the stage: $(head -2 "$WORK/onstage.out" | tr '\n' ' ')"; return 1; }
  probe_page "$WORK/onstage.html" cast 1000 "probe&cast" || return 1
  probe_page "$WORK/onstage.html" cast-phone 390 "probe&cast" || return 1
  why="$(python3 - "$WORK/cast.json" "$WORK/cast-phone.json" <<'PY'
import json, sys
g, phone = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
first = [c for c in g["cast"] if c != "kai"][0]
a, k = g["cast"][first], g["cast"]["kai"]
if a["onStage"] or not a["besideBubble"]:
    print("%s, who has no place, is not under the stage beside the bubble" % first); sys.exit(1)
if not k["onStage"] or abs(k["at"][0] - 4) > 0.5 or abs(k["at"][1] - 62) > 0.5:
    print("kai is not on the stage at [4, 62]: %s" % k); sys.exit(1)
if a["width"] < 120 or phone["cast"][first]["width"] < 80:
    print("the cast under the stage is %d px wide (%d at a phone width); want 120 and 80" % (a["width"], phone["cast"][first]["width"])); sys.exit(1)
if not all(c["pixelated"] for c in g["cast"].values()):
    print("a body is not drawn with sharp pixels"); sys.exit(1)
if g["bubbleOnStage"][0] or not g["bubbleOnStage"][1]:
    print("the bubble does not follow the speaker: %s" % g["bubbleOnStage"][:2]); sys.exit(1)
PY
)" || return 1
  why=""
}

a_scene_fires_its_burst_and_word_and_moved_parts_land_in_puffs() {
  expected
  probe fired 1000 "probe&wait=all" || return 1
  why="$(python3 - "$WORK/fired.json" "$WORK/expected.json" <<'PY'
import json, sys
fired = json.load(open(sys.argv[1])).get("fired")
want = json.load(open(sys.argv[2]))["scenes"]
if fired is None:
    print("the page reports no effects"); sys.exit(1)
if not any(w["fx"] for w in want):
    print("no scene of the example names an effect"); sys.exit(1)
def has(i, kind, **kw):
    return any(f["scene"] == i and f["kind"] == kind and all(f.get(k) == v for k, v in kw.items()) for f in fired)
for i, w in enumerate(want):
    fx = w["fx"] or {}
    if fx.get("burst") and not has(i, "burst", part=fx["burst"]):
        print("scene %d fired no burst behind %s" % (i, fx["burst"])); sys.exit(1)
    if fx.get("word") and not has(i, "word", word=fx["word"], part=fx.get("at", fx.get("burst"))):
        print("scene %d fired no %s" % (i, fx["word"])); sys.exit(1)
    if not fx.get("word") and has(i, "word"):
        print("scene %d fired a word it does not name" % i); sys.exit(1)
    for pid in w["moved"]:
        if not has(i, "puff", part=pid):
            print("scene %d moved %s without puffs" % (i, pid)); sys.exit(1)
PY
)" || return 1
  why=""
}

reduced_motion_fires_no_effect_and_still_changes_poses() {
  expected
  probe reduced-fired 1000 "probe&wait=all" --reduced-motion || return 1
  python3 - "$WORK/reduced-fired.json" <<'PY' || { why="effects fired with reduced motion"; return 1; }
import json, sys
g = json.load(open(sys.argv[1]))
sys.exit(0 if g.get("fired") == [] else 1)
PY
  [ $? -eq 0 ] || return 1
  probe reduced-scenes 1000 "probe&scenes" --reduced-motion || return 1
  why="$(speaker_and_poses_match "$WORK/reduced-scenes.json")" || return 1
  why=""
}

the_player_plays_once_pauses_and_opens_a_chapter_at_its_end() {
  expected
  probe ran 1000 "probe&wait=all" || return 1
  python3 - "$WORK/ran.json" "$WORK/expected.json" <<'PY' || { why="the player did not stop at the last scene"; return 1; }
import json, sys
g = json.load(open(sys.argv[1])); w = json.load(open(sys.argv[2]))["scenes"]
sys.exit(0 if g["scene"] == len(w) - 1 and g["playing"] is False and g["played"] == len(w) else 1)
PY
  [ $? -eq 0 ] || return 1
  probe paused 1000 "probe&pause=1" || return 1
  python3 - "$WORK/paused.json" "$WORK/expected.json" <<'PY' || { why="pausing did not hold the scene, or resuming did not reach the end"; return 1; }
import json, sys
g = json.load(open(sys.argv[1])); w = json.load(open(sys.argv[2]))["scenes"]
a, b = g["paused"], g["resumed"]
ok = a["playing"] is False and a["sceneBefore"] == a["sceneAfter"] == 1 and b["scene"] == len(w) - 1 and b["playing"] is False
sys.exit(0 if ok else 1)
PY
  [ $? -eq 0 ] || return 1
  probe chapter 1000 "probe&chapter=3" || return 1
  python3 - "$WORK/chapter.json" "$WORK/expected.json" <<'PY' || { why="a chapter did not open its scene in its end state"; return 1; }
import json, sys
g = json.load(open(sys.argv[1])); w = json.load(open(sys.argv[2]))["scenes"][3]
ok = g["scene"] == 3 and g["playing"] is False and g["states"] == w["states"]
ok = ok and all(abs(g["at"][k][0] - v[0]) < 0.5 and abs(g["at"][k][1] - v[1]) < 0.5 for k, v in w["at"].items())
sys.exit(0 if ok else 1)
PY
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

# --- 3. art and figures ---------------------------------------------------------------------------

the_art_comes_only_from_the_spec() {
  local f
  for f in "$SKILL_DIR"/templates/* "$SKILL_DIR"/scripts/*; do
    [ -f "$f" ] || continue
    if grep -qi '<svg\|<path\|<circle' "$f"; then why="$(basename "$f") holds a drawing"; return 1; fi
  done
  render_cache || return 1
  render_one "$REDELIVERY/spec.ja.json" "$WORK/redelivery.html" || return 1
  python3 - "$WORK/cache.html" "$WORK/redelivery.html" "$CACHE/spec.json" "$REDELIVERY/spec.ja.json" <<'PY' || { why="a page does not draw the part art of its own spec, or both pages share it"; return 1; }
import json, os, re, sys
def first_path(spec_path):
    spec = json.load(open(spec_path))
    art = open(os.path.join(os.path.dirname(spec_path), spec["parts"][0]["art"])).read()
    return re.search(r'\sd="([^"]{12,})"', art).group(1)
a, b = open(sys.argv[1]).read(), open(sys.argv[2]).read()
mine_a, mine_b = first_path(sys.argv[3]), first_path(sys.argv[4])
if mine_a == mine_b or mine_a not in a or mine_b not in b or mine_b in a or mine_a in b:
    sys.exit(1)
PY
}

# The four bodies are PNG sheets of four poses side by side, with a transparent background, and the
# page draws each cast member with the sheet of its body.
the_cast_comes_from_the_four_bodies() {
  render_cache || return 1
  why="$(python3 - "$BODIES" "$WORK/cache.html" "$CACHE/spec.json" <<'PY'
import base64, json, os, struct, sys
folder, page, spec = sys.argv[1], open(sys.argv[2]).read(), json.load(open(sys.argv[3]))
for body in ("robot", "android", "guide", "drone"):
    path = os.path.join(folder, body + ".png")
    if not os.path.isfile(path):
        print("no sheet for %s" % body); sys.exit(1)
    raw = open(path, "rb").read()
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        print("%s.png is not a PNG" % body); sys.exit(1)
    w, h, _, color = struct.unpack(">IIBB", raw[16:26])
    if w != 4 * h or h < 32:
        print("%s.png is %dx%d, not four square poses side by side" % (body, w, h)); sys.exit(1)
    if color != 6 and not (color == 3 and b"tRNS" in raw):
        print("%s.png has no transparency" % body); sys.exit(1)
cast = spec.get("cast")
if not cast:
    print("the cache example names no cast"); sys.exit(1)
for c in cast:
    sheet = base64.b64encode(open(os.path.join(folder, c["body"] + ".png"), "rb").read()).decode()
    if 'data-cast="%s"' % c["id"] not in page or 'data-body="%s"' % c["body"] not in page or sheet not in page:
        print("the page does not draw %s with the %s sheet" % (c["id"], c["body"])); sys.exit(1)
PY
)" || return 1
  why=""
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

figures_under_the_player_draw_from_the_same_parts() {
  render_cache || return 1
  python3 - "$WORK/cache.html" "$CACHE/spec.json" <<'PY' || { why="a figure kind is missing, a figure draws no part art, or the page mentions dragon"; return 1; }
import json, re, sys
page = open(sys.argv[1]).read()
spec = json.load(open(sys.argv[2]))
figs = page[page.find('id="me-figures"'):]
for kind in ("still", "flow", "compare", "table"):
    if 'data-kind="%s"' % kind not in figs:
        sys.exit(1)
for kind in ("still", "flow", "compare"):
    block = figs[figs.find('data-kind="%s"' % kind):]
    block = block[:block.find("</figure>")]
    if "<svg" not in block or "data-part=" not in block:
        sys.exit(1)
if "dragon" in page.lower():
    sys.exit(1)
PY
}

# --- 4. check and render refuse -------------------------------------------------------------------

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

check_refuses_a_broken_spec_and_names_the_field() {
  python3 "$TOOL" check "$CACHE/spec.json" > "$WORK/ok.out" 2>&1 || { why="the cache example was refused: $(head -2 "$WORK/ok.out" | tr '\n' ' ')"; return 1; }
  python3 "$TOOL" check "$REDELIVERY/spec.ja.json" > "$WORK/ok-ja.out" 2>&1 || { why="the redelivery example was refused: $(head -2 "$WORK/ok-ja.out" | tr '\n' ' ')"; return 1; }
  variant unknown-part 's["scenes"][1]["set"]["nowhere"] = "idle"'
  refuses "$WORK/unknown-part/spec.json" "scenes[1].set.nowhere" || return 1
  variant unknown-state 's["scenes"][0]["set"]["browser"] = "flying"'
  refuses "$WORK/unknown-state/spec.json" "scenes[0].set.browser" || return 1
  variant no-line 'del s["scenes"][2]["line"]'
  refuses "$WORK/no-line/spec.json" "scenes[2].line" || return 1
}

check_refuses_a_broken_cast_or_effect_and_names_the_field() {
  variant body 's["cast"][0]["body"] = "tank"'
  refuses "$WORK/body/spec.json" "cast[0].body: " || return 1
  variant twice 's["cast"].append({"id": "two", "body": s["cast"][0]["body"], "name": "Two"})'
  refuses "$WORK/twice/spec.json" "cast[1].body: " || return 1
  variant five 's["cast"] = [{"id": "c%d" % i, "body": "robot", "name": "C"} for i in range(5)]'
  refuses "$WORK/five/spec.json" "cast: " || return 1
  variant edge 's["cast"][0]["at"] = [95, 90]'
  refuses "$WORK/edge/spec.json" "cast[0].at: " || return 1
  variant speaker 's["scenes"][0]["speaker"] = "nobody"'
  refuses "$WORK/speaker/spec.json" "scenes[0].speaker: " || return 1
  variant pose 's["scenes"][0]["pose"] = "dance"'
  refuses "$WORK/pose/spec.json" "scenes[0].pose: " || return 1
  variant fx-part 's["scenes"][0]["fx"] = {"burst": "nowhere"}'
  refuses "$WORK/fx-part/spec.json" "scenes[0].fx.burst: " || return 1
  variant fx-word 's["scenes"][0]["fx"] = {"burst": s["parts"][0]["id"], "word": "boom"}'
  refuses "$WORK/fx-word/spec.json" "scenes[0].fx.word: " || return 1
  variant old-narrator 's["narrator"] = {"name": "Owl", "art": "art/owl.svg", "states": ["calm"]}'
  refuses "$WORK/old-narrator/spec.json" "narrator: " || return 1
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
  unsafe_art unknown-when '<rect width="2" height="2" data-when="flying"/>' || return 1
}

# --- 5. SKILL.md -----------------------------------------------------------------------------------

skill_md_walks_from_the_art_direction_through_the_cast_and_effects_to_the_page() {
  python3 - "$SKILL_DIR/SKILL.md" <<'PY' || { why="SKILL.md misses a step or puts them out of order"; return 1; }
import re, sys
text = open(sys.argv[1]).read().lower()
order = ["running example", "art direction", "cast", "every state", "speaker", "effect", "check", "render", "phone width"]
at = [text.find(w) for w in order]
sys.exit(0 if all(a >= 0 for a in at) and at == sorted(at) else 1)
PY
}

check "render writes one offline page with the player first" render_writes_one_offline_page
check "each scene shows its line and marks only the parts that change" each_scene_shows_its_line_and_marks_only_the_parts_that_change
check "the speaker takes the scene's pose and the others wait" the_speaker_takes_the_scenes_pose_and_the_others_wait
check "a cast member stands beside the bubble or on the stage" a_cast_member_stands_beside_the_bubble_or_on_the_stage
check "a scene fires its burst and word, and moved parts land in puffs" a_scene_fires_its_burst_and_word_and_moved_parts_land_in_puffs
check "the player plays once, pauses, and opens a chapter at its end" the_player_plays_once_pauses_and_opens_a_chapter_at_its_end
check "reduced motion shows each scene at its end" reduced_motion_shows_each_scene_at_its_end
check "reduced motion fires no effect and still changes poses" reduced_motion_fires_no_effect_and_still_changes_poses
check "the cast comes from the four bodies" the_cast_comes_from_the_four_bodies
check "the art comes only from the spec" the_art_comes_only_from_the_spec
check "the effects core is bundled unmodified with its license" the_effects_core_is_bundled_unmodified_with_its_license
check "figures under the player draw from the same parts" figures_under_the_player_draw_from_the_same_parts
check "a phone width has no sideways scroll and readable scene text" a_phone_width_has_no_sideways_scroll_and_readable_scene_text
check "the page reads in light and dark" the_page_reads_in_light_and_dark
check "check refuses a broken spec and names the field" check_refuses_a_broken_spec_and_names_the_field
check "check refuses a broken cast or effect and names the field" check_refuses_a_broken_cast_or_effect_and_names_the_field
check "check refuses art that loads from outside or runs a script" check_refuses_art_that_loads_from_outside_or_runs_a_script
check "SKILL.md walks from the art direction through the cast and effects to the page" skill_md_walks_from_the_art_direction_through_the_cast_and_effects_to_the_page

echo "[test-motion-explainer] ran: $((PASS + FAIL))"
echo "[test-motion-explainer] PASS: $PASS, FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "failed cases:"
  for name in "${FAILED[@]}"; do echo "    $name"; done
  exit 1
fi
exit 0
