#!/bin/bash
# Tests for motion-diagram: a JSON spec of parts and lines becomes one HTML page whose cards run
# through the flow once, and export writes the same run as a video, a GIF, and an image.
#
# What is checked:
#   1. render writes one page that loads nothing from the network, from a spec that uses every kind
#      of part, and lays the parts out from their lines.
#   2. check refuses a spec that breaks the flow or whose text is over its limit, naming the field,
#      and render refuses the same specs without writing a file.
#   3. In a headless browser: the cards run once and stop at the counts of the spec, replay runs
#      them again, reduced motion shows the end, a pressed part shows its details, the page shows no
#      prose before a part is pressed, and the flow turns from left to right to top to bottom on a
#      phone. In a frame of a throwaway document, a page below the first screen or in a hidden part
#      waits in its finished state and runs once when shown, and printing stops a run at the finished
#      picture; a page opened with #end never runs. Without a browser these cases fail.
#   4. The theme keys, the light and dark colors, and the one dictionary of interface words.
#   5. export writes an MP4 video, a GIF, and a PNG image, and says how to install Node.js without it.
#   6. SKILL.md, the pages that tell when the page runs, and the repository checks.
#
# Exit 0 when every case passes, 1 when any fails (the failing cases are listed).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN="$(cd "$SKILL_DIR/../.." && pwd)"
TOOL="$SKILL_DIR/scripts/motion_diagram.py"
BROWSER="$SKILL_DIR/scripts/browser.py"
EXPORT="$SKILL_DIR/scripts/export.sh"
UI="$SKILL_DIR/templates/ui.json"
FULL="$SCRIPT_DIR/fixtures/full.json"
export PYTHONDONTWRITEBYTECODE=1

WORK="$(mktemp -d "${TMPDIR:-/tmp}/motion-diagram-test.XXXXXX")"
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

# A copy of the full spec changed by a Python expression on `s` (the spec as a dict).
variant() {
  local out="$1" expr="$2"
  python3 - "$FULL" "$out" "$expr" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
def part(pid):
    return next(p for p in s["parts"] if p["id"] == pid)
exec(sys.argv[3])
json.dump(s, open(sys.argv[2], "w"), ensure_ascii=False)
PY
}

# Index of a part in the full spec, for field names such as parts[3].keep.
index_of() { python3 -c 'import json,sys; s=json.load(open(sys.argv[1])); print([p["id"] for p in s["parts"]].index(sys.argv[2]))' "$FULL" "$1"; }

render_full() {
  [ -s "$WORK/full.html" ] && return 0
  python3 "$TOOL" render "$FULL" --out "$WORK/full.html" > "$WORK/render.out" 2>&1 || { why="render exited $? : $(head -3 "$WORK/render.out" | tr '\n' ' ')"; return 1; }
}

# --- 1. render and layout -------------------------------------------------------------------

render_writes_one_offline_page() {
  render_full || return 1
  [ -s "$WORK/full.html" ] || { why="no page written"; return 1; }
  python3 - "$WORK/full.html" <<'PY' || { why="the page loads from outside or misses a part"; return 1; }
import re, sys
html = open(sys.argv[1]).read()
if re.search(r'<(script|link|img|iframe|source|video|audio)[^>]+(src|href)\s*=\s*["\']?(https?:)?//', html, re.I):
    sys.exit(1)
if re.search(r'url\(\s*["\']?(https?:)?//', html, re.I) or "@import" in html:
    sys.exit(1)
for pid in ["forum", "papers", "blogs", "rules", "model", "dropped", "team", "drafts", "person", "issue", "payments"]:
    if not re.search(r'data-part="%s"' % pid, html):
        sys.exit(1)
if 'data-boundary' not in html or 'data-back' not in html:
    sys.exit(1)
PY
}

layout_orders_parts_by_their_lines() {
  render_full || return 1
  python3 - "$WORK/full.html" <<'PY'
import re, sys
html = open(sys.argv[1]).read()
rank = {m.group(1): int(m.group(2)) for m in re.finditer(r'data-part="([a-z0-9-]+)"[^>]*?data-rank="(\d+)"', html)}
lane = {m.group(1): m.group(2) for m in re.finditer(r'data-part="([a-z0-9-]+)"[^>]*?data-lane="([a-z]+)"', html)}
want = {"forum": 0, "papers": 0, "blogs": 0, "rules": 1, "model": 2, "drafts": 3, "person": 4, "issue": 5, "team": 3}
bad = [k for k, v in want.items() if rank.get(k) != v]
if lane.get("team") != "side" or lane.get("dropped") != "side" or lane.get("rules") != "main":
    bad.append("lanes")
if bad:
    print(" ".join("%s=%s" % (k, rank.get(k)) for k in bad))
    sys.exit(1)
PY
  [ $? -eq 0 ] || { why="ranks or lanes differ"; return 1; }
}

# --- 2. check and render refuse ---------------------------------------------------------------

refuses() {  # refuses <spec> <field that must be named>
  local out status
  out="$(python3 "$TOOL" check "$1" 2>&1)"; status=$?
  [ "$status" -eq 1 ] || { why="check exited $status for $2"; return 1; }
  printf '%s' "$out" | grep -qF "$2" || { why="check did not name $2"; return 1; }
}

check_refuses_a_spec_that_breaks_the_flow() {
  python3 "$TOOL" check "$FULL" > "$WORK/ok.out" 2>&1 || { why="the full spec was refused: $(head -2 "$WORK/ok.out" | tr '\n' ' ')"; return 1; }
  local rules lines
  rules="$(index_of rules)"
  lines="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["lines"]))' "$FULL")"
  variant "$WORK/unknown.json" 's["lines"][0]["to"] = "nowhere"'
  refuses "$WORK/unknown.json" "lines[0].to" || return 1
  variant "$WORK/keeps-more.json" 'part("rules")["keep"] = 101'
  refuses "$WORK/keeps-more.json" "parts[$rules].keep" || return 1
  variant "$WORK/back-later.json" 's["lines"].append({"from": "rules", "to": "issue", "back": True})'
  refuses "$WORK/back-later.json" "lines[$lines]" || return 1
  variant "$WORK/crosses.json" 's["lines"].append({"from": "drafts", "to": "payments"})'
  refuses "$WORK/crosses.json" "lines[$lines]" || return 1
}

check_refuses_text_over_its_limit() {
  local rules
  rules="$(index_of rules)"
  # Width counts 2 for a CJK character and 1 for any other character.
  variant "$WORK/title-80.json" 's["title"] = "a" * 80'
  python3 "$TOOL" check "$WORK/title-80.json" > /dev/null 2>&1 || { why="a title of width 80 was refused"; return 1; }
  variant "$WORK/title-81.json" 's["title"] = "あ" * 40 + "a"'
  refuses "$WORK/title-81.json" "title" || return 1
  variant "$WORK/name-24.json" 'part("rules")["name"] = "あ" * 12'
  python3 "$TOOL" check "$WORK/name-24.json" > /dev/null 2>&1 || { why="a name of width 24 was refused"; return 1; }
  variant "$WORK/name-25.json" 'part("rules")["name"] = "あ" * 12 + "a"'
  refuses "$WORK/name-25.json" "parts[$rules].name" || return 1
  variant "$WORK/details-200.json" 'part("rules")["details"] = "あ" * 100'
  python3 "$TOOL" check "$WORK/details-200.json" > /dev/null 2>&1 || { why="details of width 200 were refused"; return 1; }
  variant "$WORK/details-201.json" 'part("rules")["details"] = "a" * 201'
  refuses "$WORK/details-201.json" "parts[$rules].details" || return 1
}

render_refuses_a_spec_that_check_refuses() {
  variant "$WORK/bad.json" 's["lines"][0]["to"] = "nowhere"'
  python3 "$TOOL" render "$WORK/bad.json" --out "$WORK/bad.html" > "$WORK/bad.out" 2>&1
  local status=$?
  [ "$status" -eq 1 ] || { why="render exited $status"; return 1; }
  [ ! -e "$WORK/bad.html" ] || { why="render wrote a file"; return 1; }
  grep -qF "lines[0].to" "$WORK/bad.out" || { why="render did not name the field"; return 1; }
}

# --- 3. in a headless browser -----------------------------------------------------------------

# probe <name> <width> <hash> [--reduced-motion]: opens the page and saves what the page reports.
probe() {
  local name="$1" width="$2" hash="$3"; shift 3
  render_full || return 1
  python3 "$BROWSER" dump "file://$WORK/full.html#$hash" --size "${width}x900" "$@" > "$WORK/$name.dom" 2> "$WORK/$name.err" || { why="no browser: $(head -1 "$WORK/$name.err")"; return 1; }
  python3 - "$WORK/$name.dom" "$WORK/$name.json" <<'PY' || { why="the page reported nothing"; return 1; }
import html, re, sys
m = re.search(r'<pre[^>]*id="md-probe"[^>]*>(.*?)</pre>', open(sys.argv[1]).read(), re.S)
if not m:
    sys.exit(1)
open(sys.argv[2], "w").write(html.unescape(m.group(1)))
PY
}

WANT_COUNTS='{"forum": "60", "papers": "25", "blogs": "15", "rules": "30", "model": "6", "dropped": "94", "team": "2", "drafts": "8", "person": "2", "issue": "2"}'

counts_are() {  # counts_are <probe json>
  python3 - "$1" "$WANT_COUNTS" <<'PY'
import json, sys
got = json.load(open(sys.argv[1]))["counts"]
want = json.loads(sys.argv[2])
bad = {k: got.get(k) for k, v in want.items() if str(got.get(k)) != v}
if bad:
    print(bad)
    sys.exit(1)
PY
}

the_page_runs_once_and_stops() {
  [ -s "$WORK/wide.json" ] || probe wide 1000 "probe&press=rules&replay" || return 1
  local c
  c="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["firstRun"]["cards"], d["firstRun"]["moving"])' "$WORK/wide.json")" || { why="no first run"; return 1; }
  set -- $c
  [ "$1" -gt 0 ] || { why="no card moved"; return 1; }
  [ "$2" = "False" ] || { why="something still moves after the run"; return 1; }
  python3 -c 'import json,sys; json.dump(json.load(open(sys.argv[1]))["firstRun"], open(sys.argv[2], "w"))' "$WORK/wide.json" "$WORK/first.json"
  counts_are "$WORK/first.json" > "$WORK/first.diff" || { why="counts $(cat "$WORK/first.diff")"; return 1; }
}

replay_runs_again_and_reduced_motion_shows_the_end() {
  [ -s "$WORK/wide.json" ] || probe wide 1000 "probe&press=rules&replay" || return 1
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d["runs"] == 2 and d["moving"] is False and d["cards"] > 0 else 1)' "$WORK/wide.json" || { why="replay did not run the cards again"; return 1; }
  counts_are "$WORK/wide.json" > /dev/null || { why="counts after replay differ"; return 1; }
  probe still 1000 "probe" --reduced-motion || return 1
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d["cards"] == 0 and d["moving"] is False else 1)' "$WORK/still.json" || { why="cards moved with reduced motion"; return 1; }
  counts_are "$WORK/still.json" > "$WORK/still.diff" || { why="counts with reduced motion $(cat "$WORK/still.diff")"; return 1; }
}

a_pressed_part_shows_its_details_and_example() {
  [ -s "$WORK/wide.json" ] || probe wide 1000 "probe&press=rules&replay" || return 1
  python3 - "$WORK/wide.json" "$FULL" <<'PY' || { why="the details or the example are missing"; return 1; }
import json, sys
d = json.load(open(sys.argv[1]))
rules = next(p for p in json.load(open(sys.argv[2]))["parts"] if p["id"] == "rules")
text = d["pressed"]
sys.exit(0 if rules["details"] in text and rules["example"] in text and rules["name"] in text else 1)
PY
}

the_page_shows_no_prose_before_a_part_is_pressed() {
  [ -s "$WORK/wide.json" ] || probe wide 1000 "probe&press=rules&replay" || return 1
  python3 - "$WORK/wide.json" "$FULL" "$UI" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
spec = json.load(open(sys.argv[2]))
ui = json.load(open(sys.argv[3]))
allowed = {spec["title"]}
allowed |= {p["name"] for p in spec["parts"]}
allowed |= {b["name"] for b in spec.get("boundaries", [])}
allowed |= {l.get("label", "") for l in spec["lines"]}
allowed |= set(ui["en"].values()) | set(ui["ja"].values())
extra = []
for line in d["before"]:
    line = line.strip()
    if not line or line in allowed or line.replace(",", "").isdigit():
        continue
    extra.append(line)
if extra:
    print(extra[:5])
    sys.exit(1)
PY
  [ $? -eq 0 ] || { why="text besides names, counts, and interface words"; return 1; }
}

the_picture_turns_on_a_phone() {
  [ -s "$WORK/wide.json" ] || probe wide 1000 "probe&press=rules&replay" || return 1
  probe narrow 390 "probe" || return 1
  python3 - "$WORK/wide.json" "$WORK/narrow.json" <<'PY' || { why="direction or overflow differs"; return 1; }
import json, sys
wide = json.load(open(sys.argv[1]))
narrow = json.load(open(sys.argv[2]))
sys.exit(0 if wide["flow"] == "row" and narrow["flow"] == "column" and not wide["overflow"] and not narrow["overflow"] else 1)
PY
  probe at728 728 "probe" || return 1
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d["flow"] == "row" and not d["overflow"] else 1)' "$WORK/at728.json" || { why="at 728 px the flow is not left to right"; return 1; }
}

# The end sends a line back too, so the cards that stop there sit where a line back starts.
resting_cards_cover_nothing() {
  variant "$WORK/endback.json" 's["lines"].append({"from": "issue", "to": "rules", "back": True, "label": "Issues teach"})'
  python3 "$TOOL" render "$WORK/endback.json" --out "$WORK/endback.html" > /dev/null 2>&1 || { why="the spec with a line back from the end was not rendered"; return 1; }
  local width
  for width in 1000 390; do
    python3 "$BROWSER" dump "file://$WORK/endback.html#probe" --size "${width}x900" > "$WORK/endback-$width.dom" 2> /dev/null || { why="no browser"; return 1; }
    python3 - "$WORK/endback-$width.dom" <<'PY' > "$WORK/endback-$width.out" || { why="at $width px: $(cat "$WORK/endback-$width.out")"; return 1; }
import html, json, re, sys
m = re.search(r'<pre[^>]*id="md-probe"[^>]*>(.*?)</pre>', open(sys.argv[1]).read(), re.S)
if not m:
    print("the page reported nothing"); sys.exit(1)
hits = json.loads(html.unescape(m.group(1))).get("covered")
if hits is None:
    print("the page did not report covered cards"); sys.exit(1)
if hits:
    print("resting cards cover " + ", ".join(hits)); sys.exit(1)
PY
  done
}

# framed <name> <layout> <steps>: puts the rendered page into a frame of a throwaway document and lets
# the document's script take <steps>, then saves what it saw. <layout> is "below" (the frame sits
# under two screens of space), "hidden" (the frame sits in a hidden part), or "top" (the frame is on
# the first screen). A srcdoc frame shares the document's origin, so the script can read the page,
# and the page cannot tell it from the isolated frame of a document that embeds it.
# On virtual time the headless browser paints only now and then, so inside the frame two stand-ins
# play the browser's part: a timer gives the animation frames, as #probe does for the page alone,
# and an observer reports the picture on screen when the steps call onScreen(true), as a browser does
# when the document scrolls the frame into view or shows its part.
framed() {
  local name="$1" layout="$2" steps="$3"
  render_full || return 1
  python3 - "$WORK/full.html" "$WORK/$name.html" "$layout" "$steps" "$WANT_COUNTS" <<'PY' || { why="the throwaway document was not written"; return 1; }
import html, sys
page, out, layout, steps, want = open(sys.argv[1]).read(), sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
browser = """<script>
window.requestAnimationFrame = f => setTimeout(() => f(performance.now()), 16);
window.__watchers = [];
window.IntersectionObserver = class { constructor(cb) { this.cb = cb; window.__watchers.push(this); } observe(el) { this.el = el; } disconnect() { this.off = true; } };
window.__onScreen = on => window.__watchers.forEach(w => { if (!w.off && w.el) w.cb([{ isIntersecting: on, target: w.el }]); });
</script>"""
page = page.replace('<head>', '<head>' + browser, 1)
frame ='<iframe id="f" style="display:block;width:1000px;height:820px;border:0" srcdoc="%s"></iframe>' % html.escape(page, quote=True)
body = {
    "below": '<div style="height:2400px"></div>' + frame + '<div style="height:1600px"></div>',
    "hidden": '<div id="part" hidden>' + frame + '</div>',
    "top": frame,
}[layout]
script = """
const f = document.getElementById('f');
const want = %s;
const pause = ms => new Promise(r => setTimeout(r, ms));
function look() {
  const d = f.contentDocument, counts = {};
  d.querySelectorAll('[data-count-for]').forEach(e => { counts[e.dataset.countFor] = e.textContent.replace(/\\D/g, ''); });
  const cards = [...d.querySelectorAll('.md-card')];
  return { counts, shown: cards.filter(c => c.style.opacity === '1').length, places: cards.map(c => c.style.transform + ' ' + c.style.opacity).join('|') };
}
async function moving() { const a = look().places; await pause(400); return look().places !== a; }
async function settle() { for (let i = 0; i < 200 && await moving(); i++); }
async function starts() { for (let i = 0; i < 8; i++) { if (await moving()) return true; } return false; }
const onScreen = on => f.contentWindow.__onScreen(on);
const full = c => Object.keys(want).every(k => c[k] === want[k]);
const seen = {};
f.addEventListener('load', async () => {
  try { %s } catch (e) { seen.error = String(e); }
  document.getElementById('seen').textContent = JSON.stringify(seen);
});
""" % (want, steps)
open(out, "w").write('<!doctype html><html><head><meta charset="utf-8"></head><body style="margin:0">%s<pre id="seen"></pre><script>%s</script></body></html>' % (body, script))
PY
  python3 "$BROWSER" dump "file://$WORK/$name.html" --size 1000x900 > "$WORK/$name.dom" 2> "$WORK/$name.err" || { why="no browser: $(head -1 "$WORK/$name.err")"; return 1; }
  python3 - "$WORK/$name.dom" "$WORK/$name.json" <<'PY' || { why="the throwaway document saw nothing"; return 1; }
import html, re, sys
m = re.search(r'<pre id="seen">(.*?)</pre>', open(sys.argv[1]).read(), re.S)
if not m or not m.group(1).strip():
    sys.exit(1)
open(sys.argv[2], "w").write(html.unescape(m.group(1)))
PY
}

# seen_is <name> <python condition on d>: the condition holds on what the throwaway document saw;
# otherwise prints what it saw.
seen_is() {
  python3 - "$WORK/$1.json" "$2" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
if not eval(sys.argv[2], {}, {"d": d}):
    print(json.dumps(d)[:300])
    sys.exit(1)
PY
}

a_page_below_the_first_screen_waits_finished() {
  framed below below "
    onScreen(false); await pause(3000);
    const b = look(); seen.beforeFull = full(b.counts); seen.beforeShown = b.shown; seen.beforeMoving = await moving();
    f.scrollIntoView(); onScreen(true);
    seen.startedMoving = await starts();
    await settle();
    const a = look(); seen.afterFull = full(a.counts); seen.afterShown = a.shown;
    window.scrollTo(0, 0); onScreen(false); await pause(1500); f.scrollIntoView(); onScreen(true);
    seen.againMoving = await starts();" || return 1
  seen_is below 'd.get("beforeFull") and d.get("beforeShown", 0) > 0 and d.get("beforeMoving") is False' > "$WORK/below.diff" || { why="before it was on screen the page did not wait in its finished state: $(cat "$WORK/below.diff")"; return 1; }
  seen_is below 'd.get("startedMoving") is True' > "$WORK/below.diff" || { why="the page did not run when scrolled into view: $(cat "$WORK/below.diff")"; return 1; }
  seen_is below 'd.get("afterFull") and d.get("afterShown", 0) > 0 and d.get("againMoving") is False' > "$WORK/below.diff" || { why="the run did not end finished, or ran again: $(cat "$WORK/below.diff")"; return 1; }
}

a_page_in_a_hidden_part_runs_when_shown() {
  framed hidden hidden "
    onScreen(false); await pause(3000);
    const b = look(); seen.beforeFull = full(b.counts); seen.beforeMoving = await moving();
    document.getElementById('part').hidden = false; onScreen(true);
    seen.startedMoving = await starts();
    await settle();
    const a = look(); seen.afterFull = full(a.counts); seen.afterShown = a.shown;" || return 1
  seen_is hidden 'd.get("beforeFull") and d.get("beforeMoving") is False' > "$WORK/hidden.diff" || { why="while hidden the page did not wait in its finished state: $(cat "$WORK/hidden.diff")"; return 1; }
  seen_is hidden 'd.get("startedMoving") is True and d.get("afterFull") and d.get("afterShown", 0) > 0' > "$WORK/hidden.diff" || { why="the page did not run once when shown: $(cat "$WORK/hidden.diff")"; return 1; }
}

a_page_opened_with_end_never_runs() {
  probe ended 1000 "probe&end" || return 1
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d.get("runs") == 0 and d.get("shown", 0) > 0 and d.get("moving") is False else 1)' "$WORK/ended.json" || { why="the page ran, or shows no resting cards: $(head -c 200 "$WORK/ended.json")"; return 1; }
  counts_are "$WORK/ended.json" > "$WORK/ended.diff" || { why="counts with #end $(cat "$WORK/ended.diff")"; return 1; }
}

printing_draws_the_finished_picture() {
  framed printed top "
    onScreen(true); await pause(700);
    seen.runningBefore = await moving();
    f.contentWindow.dispatchEvent(new Event('beforeprint'));
    const p = look(); seen.printFull = full(p.counts); seen.printShown = p.shown;
    seen.movingAfter = await moving();" || return 1
  seen_is printed 'd.get("runningBefore") is True' > "$WORK/printed.diff" || { why="the run was not in progress when printing started: $(cat "$WORK/printed.diff")"; return 1; }
  seen_is printed 'd.get("printFull") and d.get("printShown", 0) > 0 and d.get("movingAfter") is False' > "$WORK/printed.diff" || { why="printing did not stop the run at the finished picture: $(cat "$WORK/printed.diff")"; return 1; }
  python3 - "$WORK/full.html" <<'PY' || { why="no print rule hides the replay button and the switches"; return 1; }
import re, sys
page = open(sys.argv[1]).read()
at = page.find("@media print")
if at < 0:
    sys.exit(1)
depth, end = 0, None
for i in range(page.index("{", at), len(page)):
    depth += {"{": 1, "}": -1}.get(page[i], 0)
    if depth == 0:
        end = i
        break
block = page[at:end]
hidden =[sel for sel, body in re.findall(r'([^{}]+)\{([^{}]*)\}', block[block.index("{") + 1:]) if re.search(r'display:\s*none', body)]
sys.exit(0 if any(".md-tools" in sel for sel in hidden) else 1)
PY
}

# --- 4. theme and interface words -------------------------------------------------------------

the_page_takes_the_theme_keys() {
  render_full || return 1
  python3 - "$WORK/full.html" <<'PY'
import re, sys
css = open(sys.argv[1]).read()
colors = ["bg", "surface", "ink", "sub", "line", "accent", "accent-ink", "accent-soft", "label"]
light = re.search(r':root\s*\{([^}]*)\}', css)
dark_system = re.search(r'@media\s*\(prefers-color-scheme:\s*dark\)\s*\{\s*:root:not\(\[data-theme="light"\]\)[^{]*\{([^}]*)\}', css)
dark_choice = re.search(r':root\[data-theme="dark"\][^{]*\{([^}]*)\}', css)
if not (light and dark_system and dark_choice):
    sys.exit(1)
def has(block, keys):
    return all(re.search(r'--%s\s*:' % k, block) for k in keys)
ok = has(light.group(1), colors + ["sans", "mono"]) and has(dark_system.group(1), colors) and has(dark_choice.group(1), colors)
sys.exit(0 if ok else 1)
PY
  [ $? -eq 0 ] || { why="a theme key or a dark block is missing"; return 1; }
}

interface_words_come_from_one_dictionary() {
  [ -s "$UI" ] || { why="no templates/ui.json"; return 1; }
  render_full || return 1
  variant "$WORK/ja.json" 's["lang"] = "ja"; s["title"] = "毎日集める"'
  python3 "$TOOL" render "$WORK/ja.json" --out "$WORK/ja.html" > /dev/null 2>&1 || { why="the Japanese spec did not render"; return 1; }
  python3 - "$UI" "$WORK/full.html" "$WORK/ja.html" <<'PY'
import html as h, json, re, sys
ui = json.load(open(sys.argv[1]))
if set(ui) != {"en", "ja"} or set(ui["en"]) != set(ui["ja"]):
    sys.exit(1)
for word in ui["ja"].values():
    if re.search(r'[぀-ヿ一-鿿] [A-Za-z0-9]|[A-Za-z0-9] [぀-ヿ一-鿿]', word):
        sys.exit(1)
for path, lang in ((sys.argv[2], "en"), (sys.argv[3], "ja")):
    page = open(path).read()
    if not re.search(r'<html[^>]*lang="%s"' % lang, page):
        sys.exit(1)
    m = re.search(r'<script type="application/json" id="md-ui">(.*?)</script>', page, re.S)
    if not m or json.loads(m.group(1)) != ui:
        sys.exit(1)
    if not re.search(r'data-lang="en"', page) or not re.search(r'data-lang="ja"', page):
        sys.exit(1)
    for key, text in re.findall(r'data-ui="([a-zA-Z]+)"[^>]*>([^<]*)<', page):
        if text and h.unescape(text) != ui[lang][key]:
            sys.exit(1)
PY
  [ $? -eq 0 ] || { why="the dictionary, the page language, or the switch differs"; return 1; }
}

# --- 5. export --------------------------------------------------------------------------------

export_writes_mp4_gif_and_png() {
  mkdir -p "$WORK/out"
  bash "$EXPORT" "$FULL" --out "$WORK/out" > "$WORK/export.out" 2>&1 || { why="export exited $? : $(tail -2 "$WORK/export.out" | tr '\n' ' ')"; return 1; }
  python3 - "$WORK/out" <<'PY' || { why="a file is missing or has the wrong kind"; return 1; }
import os, sys
d = sys.argv[1]
def head(name, n):
    p = os.path.join(d, name)
    return open(p, "rb").read(n) if os.path.exists(p) and os.path.getsize(p) > 1000 else b""
ok = head("full.mp4", 12)[4:8] == b"ftyp" and head("full.gif", 6) in (b"GIF89a", b"GIF87a") and head("full.png", 8) == b"\x89PNG\r\n\x1a\n"
sys.exit(0 if ok else 1)
PY
}

export_without_node_says_how_to_install_it() {
  mkdir -p "$WORK/nonode"
  local out status
  out="$(PATH=/usr/bin:/bin bash "$EXPORT" "$FULL" --out "$WORK/nonode" 2>&1)"; status=$?
  [ "$status" -ne 0 ] || { why="export exited 0 without Node.js"; return 1; }
  printf '%s' "$out" | grep -qF "Node.js" || { why="the message does not name Node.js"; return 1; }
  [ -z "$(ls -A "$WORK/nonode")" ] || { why="export wrote files without Node.js"; return 1; }
  PATH=/usr/bin:/bin python3 "$TOOL" check "$FULL" > /dev/null 2>&1 || { why="check failed without Node.js"; return 1; }
  PATH=/usr/bin:/bin python3 "$TOOL" render "$FULL" --out "$WORK/nonode-page.html" > /dev/null 2>&1 || { why="render failed without Node.js"; return 1; }
}

# --- 6. SKILL.md and the repository ---------------------------------------------------------

the_skill_agrees_on_the_parts_first() {
  local skill="$SKILL_DIR/SKILL.md"
  [ -s "$skill" ] || { why="no SKILL.md"; return 1; }
  python3 - "$skill" <<'PY' || { why="SKILL.md does not agree on the parts before the spec, or misses a command"; return 1; }
import re, sys
text = open(sys.argv[1]).read()
agree = re.search(r'agree', text, re.I)
spec = re.search(r'before (you )?writ(e|ing) the spec', text, re.I)
order = agree and spec
commands = all(word in text for word in ("motion_diagram.py check", "motion_diagram.py render", "export.sh"))
sys.exit(0 if order and commands and text.startswith("---\nname: motion-diagram\n") else 1)
PY
}

# Each page that tells how the page plays says that it runs when its picture is first on screen, that
# #end opens it finished, and that it prints finished.
the_docs_say_when_the_page_runs() {
  python3 - "$SKILL_DIR/SKILL.md" "$PLUGIN/README.md" "$PLUGIN/docs/how-it-works.md" "$PLUGIN/README.ja.md" "$PLUGIN/docs/how-it-works.ja.md" <<'PY' > "$WORK/docs.diff" || { why="$(cat "$WORK/docs.diff")"; return 1; }
import sys
missing = []
for path in sys.argv[1:]:
    text = open(path).read()
    words = ("#end", "画面に", "印刷") if path.endswith(".ja.md") else ("#end", "on screen", "print")
    lacks = [w for w in words if w not in text]
    if lacks:
        missing.append("%s lacks %s" % (path.split("/plugins/")[-1], ", ".join(lacks)))
if missing:
    print("; ".join(missing))
    sys.exit(1)
PY
}

# The same command as the check of that name in scripts/check.sh, run on the marketplace and this
# plugin only, so the case stays fast; the whole of scripts/check.sh runs before the pull request.
claude_plugin_validate() {
  local repo target
  repo="$(git -C "$PLUGIN" rev-parse --show-toplevel 2>/dev/null)" || { why="not in a repository"; return 1; }
  command -v claude > /dev/null 2>&1 || { why="the claude command is missing"; return 1; }
  for target in "$repo" "$PLUGIN"; do
    claude plugin validate "$target" 2>&1 | grep -q 'Validation passed' || { why="claude plugin validate $target failed"; return 1; }
  done
}

check "render writes one offline page from a full spec" render_writes_one_offline_page
check "layout orders parts by their lines" layout_orders_parts_by_their_lines
check "check refuses a spec that breaks the flow" check_refuses_a_spec_that_breaks_the_flow
check "check refuses text over its limit" check_refuses_text_over_its_limit
check "render refuses a spec that check refuses" render_refuses_a_spec_that_check_refuses
check "the page runs once and stops at the counts of the spec" the_page_runs_once_and_stops
check "replay runs again and reduced motion shows the end" replay_runs_again_and_reduced_motion_shows_the_end
check "a pressed part shows its details and example" a_pressed_part_shows_its_details_and_example
check "the page shows no prose before a part is pressed" the_page_shows_no_prose_before_a_part_is_pressed
check "the picture runs left to right when wide and top to bottom on a phone" the_picture_turns_on_a_phone
check "resting cards cover no line back and no part text" resting_cards_cover_nothing
check "a page below the first screen waits finished and runs once when scrolled into view" a_page_below_the_first_screen_waits_finished
check "a page in a hidden part runs once when the part is shown" a_page_in_a_hidden_part_runs_when_shown
check "a page opened with #end shows the finished picture and never runs" a_page_opened_with_end_never_runs
check "printing stops the run and draws the finished picture without the tools" printing_draws_the_finished_picture
check "the page takes the theme keys and has light and dark colors" the_page_takes_the_theme_keys
check "interface words come from one dictionary in both languages" interface_words_come_from_one_dictionary
check "export writes mp4, gif, and png" export_writes_mp4_gif_and_png
check "export without node says how to install it" export_without_node_says_how_to_install_it
check "the skill agrees on the parts before writing the spec" the_skill_agrees_on_the_parts_first
check "the docs say when the page runs, what #end does, and how it prints" the_docs_say_when_the_page_runs

# The page takes the user's theme with the theme command of page-design's verify file, so the skill
# follows page-design/verify through musubi as an optional follow (agent-shuriken#553).
follows_page_design_verify() {
  [ -f "$SKILL_DIR/musubi.json" ] || { why="musubi.json is missing"; return 1; }
  python3 - "$SKILL_DIR/musubi.json" <<'PY' || { why="musubi.json does not follow only page-design/verify as an optional follow"; return 1; }
import json, re, sys
declaration = json.load(open(sys.argv[1], encoding="utf-8"))
follows = declaration.get("follows", {})
follow = follows.get("page-design/verify", {})
ok = (
    declaration.get("musubi") == "2026-11-21"
    and "provides" not in declaration
    and list(follows) == ["page-design/verify"]
    and follow.get("version") == "^2.0.0"
    and follow.get("optional") is True
    and re.fullmatch(r"sha256-[A-Za-z0-9+/]{43}=", str(follow.get("integrity", ""))) is not None
)
sys.exit(0 if ok else 1)
PY
  local line page
  for line in \
    'When the `page-design` skill is installed, run the `verify` of the `page-design` skill: open the `page-design` skill by name and run the file it names for `verify`.' \
    'If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.' \
    'If the `page-design` skill is not installed, go on without the `verify` of `page-design`.'; do
    grep -qxF -- "$line" "$SKILL_DIR/SKILL.md" || { why="SKILL.md lacks the line: $line"; return 1; }
  done
  for page in README.md README.ja.md docs/how-it-works.md docs/how-it-works.ja.md; do
    grep -qF 'page-design/verify' "$PLUGIN/$page" && grep -qF 'musubi.json' "$PLUGIN/$page" \
      || { why="$page does not name musubi.json and page-design/verify"; return 1; }
  done
}
check "motion-diagram follows verify of page-design as an optional follow" follows_page_design_verify
check "claude plugin validate" claude_plugin_validate

echo ""
echo "[test-motion-diagram] ran: $((PASS + FAIL))"
echo "[test-motion-diagram] PASS: $PASS, FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "failed cases:"
  printf '    %s\n' "${FAILED[@]}"
  exit 1
fi
exit 0
