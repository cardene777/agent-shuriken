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
#      phone. Without a browser these cases fail.
#   4. The theme keys, the light and dark colors, and the one dictionary of interface words.
#   5. export writes an MP4 video, a GIF, and a PNG image, and says how to install Node.js without it.
#   6. SKILL.md and the repository checks.
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
check "the page takes the theme keys and has light and dark colors" the_page_takes_the_theme_keys
check "interface words come from one dictionary in both languages" interface_words_come_from_one_dictionary
check "export writes mp4, gif, and png" export_writes_mp4_gif_and_png
check "export without node says how to install it" export_without_node_says_how_to_install_it
check "the skill agrees on the parts before writing the spec" the_skill_agrees_on_the_parts_first
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
