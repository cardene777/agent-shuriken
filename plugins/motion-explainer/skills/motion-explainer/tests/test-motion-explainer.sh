#!/bin/bash
# Tests for motion-explainer: a spec and the SVG art an agent draws for one subject become one HTML
# page with a player that walks one running example scene by scene, and figures under it.
#
# What is checked:
#   1. render writes one page that loads nothing from the network, with the player before the figures.
#   2. In a headless browser: each scene shows its line and marks only the parts that change, the
#      narrator takes the state each scene names, the player plays once, pauses, resumes, and opens a
#      chapter in its end state, reduced motion shows each scene at its end, a phone width has no
#      sideways scroll, and the page reads in light and dark.
#   3. The art comes only from the spec, and the figures draw from the same parts without dragon.
#   4. check refuses a broken spec and unsafe art, naming the field, and render writes nothing for them.
#   5. SKILL.md walks from the art direction to looking at the page.
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
  local name="$1" width="$2" hash="$3"; shift 3
  render_cache || return 1
  python3 "$BROWSER" dump "file://$WORK/cache.html#$hash" --size "${width}x900" "$@" > "$WORK/$name.dom" 2> "$WORK/$name.err" || { why="no browser: $(head -1 "$WORK/$name.err")"; return 1; }
  python3 - "$WORK/$name.dom" "$WORK/$name.json" <<'PY' || { why="the page reported nothing"; return 1; }
import html, re, sys
m = re.search(r'<pre[^>]*id="me-probe"[^>]*>(.*?)</pre>', open(sys.argv[1]).read(), re.S)
if not m:
    sys.exit(1)
open(sys.argv[2], "w").write(html.unescape(m.group(1)))
PY
}

# The end state of every scene, worked out from the spec: states, places, and the parts that change.
expected() {
  python3 - "$CACHE/spec.json" "$WORK/expected.json" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
state = {p["id"]: p["states"][0] for p in s["parts"]}
place = {p["id"]: list(p["at"]) for p in s["parts"]}
out = []
for sc in s["scenes"]:
    changed = set()
    for pid, st in sc.get("set", {}).items():
        if state[pid] != st:
            changed.add(pid)
        state[pid] = st
    for pid, xy in sc.get("move", {}).items():
        if place[pid] != list(xy):
            changed.add(pid)
        place[pid] = list(xy)
    out.append({"line": sc["line"], "narrator": sc["narrator"], "changed": sorted(changed), "states": dict(state), "at": {k: list(v) for k, v in place.items()}})
json.dump(out, open(sys.argv[2], "w"))
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
want = json.load(open(sys.argv[2]))
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

the_narrator_takes_the_state_each_scene_names() {
  scenes_report || return 1
  python3 - "$WORK/scenes.json" "$WORK/expected.json" <<'PY' || { why="the narrator shows another state, or shows drawings of other states"; return 1; }
import json, sys
got = json.load(open(sys.argv[1]))["scenes"]
want = json.load(open(sys.argv[2]))
for g, w in zip(got, want):
    if g["narrator"] != w["narrator"] or not g["narratorShowsOnlyItsState"]:
        sys.exit(1)
    if not g["partsShowOnlyTheirStates"]:
        sys.exit(1)
PY
}

the_player_plays_once_pauses_and_opens_a_chapter_at_its_end() {
  expected
  probe ran 1000 "probe&wait=all" || return 1
  python3 - "$WORK/ran.json" "$WORK/expected.json" <<'PY' || { why="the player did not stop at the last scene"; return 1; }
import json, sys
g = json.load(open(sys.argv[1])); w = json.load(open(sys.argv[2]))
sys.exit(0 if g["scene"] == len(w) - 1 and g["playing"] is False and g["played"] == len(w) else 1)
PY
  [ $? -eq 0 ] || return 1
  probe paused 1000 "probe&pause=1" || return 1
  python3 - "$WORK/paused.json" "$WORK/expected.json" <<'PY' || { why="pausing did not hold the scene, or resuming did not reach the end"; return 1; }
import json, sys
g = json.load(open(sys.argv[1])); w = json.load(open(sys.argv[2]))
a, b = g["paused"], g["resumed"]
ok = a["playing"] is False and a["sceneBefore"] == a["sceneAfter"] == 1 and b["scene"] == len(w) - 1 and b["playing"] is False
sys.exit(0 if ok else 1)
PY
  [ $? -eq 0 ] || return 1
  probe chapter 1000 "probe&chapter=3" || return 1
  python3 - "$WORK/chapter.json" "$WORK/expected.json" <<'PY' || { why="a chapter did not open its scene in its end state"; return 1; }
import json, sys
g = json.load(open(sys.argv[1])); w = json.load(open(sys.argv[2]))[3]
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
g = json.load(open(sys.argv[1])); w = json.load(open(sys.argv[2]))[4]
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
  python3 - "$WORK/cache.html" "$WORK/redelivery.html" "$CACHE" "$REDELIVERY" <<'PY' || { why="the narrator art is not the art of its spec, or both pages share it"; return 1; }
import re, sys
def narrator(page):
    m = re.search(r'<div[^>]*data-narrator[^>]*>(.*?</svg>)', open(page).read(), re.S)
    return m.group(1) if m else ""
a, b = narrator(sys.argv[1]), narrator(sys.argv[2])
if not a or not b or a == b:
    sys.exit(1)
if "M58 40 L72 66" not in a or "M50 70 Q54 26" not in b:
    sys.exit(1)
PY
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
  variant unknown-face 's["scenes"][0]["narrator"] = "asleep"'
  refuses "$WORK/unknown-face/spec.json" "scenes[0].narrator" || return 1
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

skill_md_walks_from_the_art_direction_to_looking_at_the_page() {
  python3 - "$SKILL_DIR/SKILL.md" <<'PY' || { why="SKILL.md misses a step or puts them out of order"; return 1; }
import re, sys
text = open(sys.argv[1]).read().lower()
order = ["running example", "art direction", "narrator", "every state", "check", "render", "phone width"]
at = [text.find(w) for w in order]
sys.exit(0 if all(a >= 0 for a in at) and at == sorted(at) else 1)
PY
}

check "render writes one offline page with the player first" render_writes_one_offline_page
check "each scene shows its line and marks only the parts that change" each_scene_shows_its_line_and_marks_only_the_parts_that_change
check "the narrator takes the state each scene names" the_narrator_takes_the_state_each_scene_names
check "the player plays once, pauses, and opens a chapter at its end" the_player_plays_once_pauses_and_opens_a_chapter_at_its_end
check "reduced motion shows each scene at its end" reduced_motion_shows_each_scene_at_its_end
check "the art comes only from the spec" the_art_comes_only_from_the_spec
check "figures under the player draw from the same parts" figures_under_the_player_draw_from_the_same_parts
check "a phone width has no sideways scroll and readable scene text" a_phone_width_has_no_sideways_scroll_and_readable_scene_text
check "the page reads in light and dark" the_page_reads_in_light_and_dark
check "check refuses a broken spec and names the field" check_refuses_a_broken_spec_and_names_the_field
check "check refuses art that loads from outside or runs a script" check_refuses_art_that_loads_from_outside_or_runs_a_script
check "SKILL.md walks from the art direction to looking at the page" skill_md_walks_from_the_art_direction_to_looking_at_the_page

echo "[test-motion-explainer] ran: $((PASS + FAIL))"
echo "[test-motion-explainer] PASS: $PASS, FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "failed cases:"
  for name in "${FAILED[@]}"; do echo "    $name"; done
  exit 1
fi
exit 0
