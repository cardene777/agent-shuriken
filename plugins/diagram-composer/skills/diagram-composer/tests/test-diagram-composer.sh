#!/usr/bin/env bash
# Tests for the diagram-composer skill: what SKILL.md says, and how validate_diagram_geometry.py
# judges a geometry manifest. Every manifest is written to a throwaway folder.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
PLUGIN_DIR="$(cd "$HERE/../../.." && pwd)"
SKILL="$SKILL_DIR/SKILL.md"
YAML="$SKILL_DIR/agents/openai.yaml"
CHECKER="$SKILL_DIR/scripts/validate_diagram_geometry.py"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export PYTHONDONTWRITEBYTECODE=1

why=""
check() {
  why=""
  if "$2"; then
    PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"
  else
    FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"
    [ -n "$why" ] && printf '        %s\n' "$why"
  fi
}

need_skill() { [ -f "$SKILL" ] || { why="$SKILL is missing"; return 1; }; }
need_checker() { [ -f "$CHECKER" ] || { why="$CHECKER is missing"; return 1; }; }

# A diagram that keeps every rule: one handoff from a client to a server, a label above the line,
# and a chip inside the server's padding.
CLEAN='{"theme":"light","metaphor":"handoff",
  "containers":[{"id":"server","x":557,"y":292,"width":178,"height":258,"padding":16}],
  "elements":[{"id":"key-chip","container":"server","x":590,"y":496,"width":112,"height":24}],
  "connectors":[{"id":"request","x1":312,"y1":430,"x2":557,"y2":430,"lane":"main"}],
  "labels":[{"id":"request-label","x":365,"y":382,"width":140,"height":24,"connector":"request"}]}'

# edit <jq filter>: prints the clean diagram changed by the filter.
edit() { printf '%s' "$CLEAN" | jq -c "$1"; }

# judge <manifest json>: runs the checker on the manifest; sets out and status.
judge() {
  printf '%s' "$1" > "$T/manifest.json"
  out="$(python3 "$CHECKER" "$T/manifest.json" 2>&1)"
  status=$?
}

skill_name() {
  need_skill || return 1
  grep -qx 'name: diagram-composer' "$SKILL" || { why="SKILL.md frontmatter does not say name: diagram-composer"; return 1; }
  [ -f "$YAML" ] || { why="$YAML is missing"; return 1; }
  grep -qx '  display_name: "Diagram Composer"' "$YAML" || { why="openai.yaml does not show Diagram Composer"; return 1; }
}

no_private_names() {
  need_skill || return 1
  local hits
  hits="$(grep -rIl --exclude="$(basename "$0")" -e 'deep-navy' -e 'editorial-gold' -e 'reference-decks' -e 'slide/references' "$PLUGIN_DIR")"
  [ -z "$hits" ] || { why="private names in: $(printf '%s ' $hits)"; return 1; }
}

# need_scan: this file defines the private-name scan the checks below run.
need_scan() { declare -F private_shapes_in > /dev/null || { why="the test defines no private_shapes_in scan"; return 1; }; }

# The scan's patterns are general shapes only: SHAPES is assigned once, as three plain lines with no
# quote or expansion that could join parts into a word, and once the words of those shapes and the
# syntax of regular expressions are taken out, no letter is left. The test compiles no other pattern
# and searches the plugin with no recursive grep, so it cannot look for a specific word.
scan_lists_general_shapes() {
  local said
  said="$(python3 - "$HERE/test-diagram-composer.sh" 2>&1 <<'PY'
import re, sys
source = open(sys.argv[1], encoding="utf-8").read()
found = re.findall(r"^SHAPES='([^']*)'$", source, re.M)
if len(found) != 1:
    sys.exit("SHAPES is assigned %d times, not once" % len(found))
lines = found[0].splitlines()
if len(lines) != 3 or any(c in found[0] for c in "\"$`"):
    sys.exit("SHAPES is not three plain lines: %r" % found[0])
rest = re.sub(r"\\[bdsw]|\[[^]]*\]|\b(?:Users|home|claude|codex|GH|Issue)\b", "", found[0])
if re.search(r"[A-Za-z]", rest):
    sys.exit("SHAPES holds a word other than the general shapes: %r" % rest)
compiled = re.findall(r"^\s*\w+ = re[.]compile[(](.*)[)]$", source, re.M)
if compiled != ['"|".join(os.environ["SHAPES"].splitlines())']:
    sys.exit("the test compiles a pattern other than SHAPES: %r" % compiled)
greps = [str(n) for n, line in enumerate(source.splitlines(), 1) if re.search(r"\bgrep\s+(?:-[A-Za-z]*[rR]|--recursive)", line)]
if greps:
    sys.exit("the test searches with a recursive grep at line %s" % ", ".join(greps))
PY
)" || { why="$said"; return 1; }
}

# One line of each shape, planted in a throwaway folder, is found. The lines are printed from parts
# so that this file does not hold them.
scan_finds_planted_shapes() {
  need_scan || return 1
  local hits
  mkdir -p "$T/shapes"
  {
    printf 'see /%s/someone/notes\n' Users home
    printf 'see ~/.%s/settings\n' claude codex
    printf 'see %s #%d\n' GH 12 Issue 3
  } > "$T/shapes/planted.md"
  hits="$(private_shapes_in "$T/shapes" | LC_ALL=C sort | tr '\n' ' ')"
  [ "$hits" = "planted.md:1 planted.md:2 planted.md:3 planted.md:4 planted.md:5 planted.md:6 " ] \
    || { why="expected lines 1 to 6 of planted.md (a home folder under /Users and /home, a local agent path for each agent, an issue reference of each form), the scan found: ${hits:-nothing}"; return 1; }
}

# A home folder written with a <name> placeholder, a throwaway folder whose path ends in a home
# folder, and plain words with a bare number sign are not shapes.
scan_passes_placeholders() {
  need_scan || return 1
  local hits
  mkdir -p "$T/plain"
  {
    printf 'a placeholder such as /%s/<name> or /%s/<name>\n' Users home
    printf 'a throwaway HOME such as $T/case/%s/notes\n' home
    printf 'plain words, a docs/%s/page.md link, and #12 alone\n' home
  } > "$T/plain/plain.md"
  hits="$(private_shapes_in "$T/plain")"
  [ -z "$hits" ] || { why="the scan flagged: $(printf '%s ' $hits)"; return 1; }
}

# A shape planted in a copy of the plugin is found in a top-level file, in a file of the skill
# folder, and in a file of a hidden manifest folder, and nowhere else.
scan_finds_shapes_in_plugin_copy() {
  need_scan || return 1
  local hits
  cp -R "$PLUGIN_DIR" "$T/copy"
  printf 'see /%s/someone/notes\n' Users >> "$T/copy/README.md"
  printf 'see ~/.%s/settings\n' codex >> "$T/copy/skills/diagram-composer/SKILL.md"
  printf 'see %s #%d\n' Issue 3 >> "$T/copy/.codex-plugin/plugin.json"
  hits="$(private_shapes_in "$T/copy" | sed 's/:[0-9]*$//' | LC_ALL=C sort | tr '\n' ' ')"
  [ "$hits" = ".codex-plugin/plugin.json README.md skills/diagram-composer/SKILL.md " ] \
    || { why="expected .codex-plugin/plugin.json, README.md, and skills/diagram-composer/SKILL.md, the scan found: ${hits:-nothing}"; return 1; }
}

no_local_names() {
  need_scan || return 1
  local hits
  # The scan finds planted lines (the checks above), so an empty result means the shapes are absent.
  hits="$(private_shapes_in "$PLUGIN_DIR")"
  [ -z "$hits" ] || { why="found at: $(printf '%s ' $hits)"; return 1; }
}

changelog_names_general_shapes() {
  local log="$PLUGIN_DIR/CHANGELOG.md"
  [ -f "$log" ] || { why="$log is missing"; return 1; }
  grep -qF 'looks only for general shapes' "$log" \
    || { why="CHANGELOG.md does not say that the name scan looks only for general shapes"; return 1; }
}

points_at_users_deck() {
  need_skill || return 1
  ! grep -qi 'catalog' "$SKILL" || { why="SKILL.md still says catalog: $(grep -ni 'catalog' "$SKILL" | head -1)"; return 1; }
  grep -qF "the user's deck" "$SKILL" || { why="SKILL.md does not point at the user's deck"; return 1; }
}

three_review_steps() {
  need_skill || return 1
  local phrase
  for phrase in 'at least three full slides' 'until the user selects' 'unmodified' 'baseline'; do
    grep -qiF "$phrase" "$SKILL" || { why="SKILL.md does not say '$phrase'"; return 1; }
  done
}

example_passes() {
  need_skill || return 1
  need_checker || return 1
  awk '/^## Geometry manifest/ { s = 1 } s && /^```json$/ { b = 1; next } b && /^```$/ { exit } b { print }' "$SKILL" > "$T/example.json"
  [ -s "$T/example.json" ] || { why="no json block under ## Geometry manifest"; return 1; }
  out="$(python3 "$CHECKER" "$T/example.json" 2>&1)"
  [ $? -eq 0 ] || { why="the example is rejected: $(printf '%s' "$out" | tr '\n' ' ')"; return 1; }
}

names_checker_by_folder() {
  need_skill || return 1
  grep -qF 'folder that contains this SKILL.md' "$SKILL" || { why="SKILL.md does not say where the checker's folder is"; return 1; }
  grep -qF 'python3 "$S/validate_diagram_geometry.py"' "$SKILL" || { why="SKILL.md does not run the checker through \$S"; return 1; }
}

runs_from_any_folder() {
  need_checker || return 1
  local here_out there_out
  edit '.labels[0].y = 420' > "$T/bad.json"
  here_out="$(cd "$SKILL_DIR" && python3 "$CHECKER" "$T/bad.json" 2>&1; echo "exit=$?")"
  mkdir -p "$T/project/docs"
  cp "$T/bad.json" "$T/project/docs/bad.json"
  there_out="$(cd "$T/project" && python3 "$CHECKER" docs/bad.json 2>&1; echo "exit=$?")"
  [ "$here_out" = "$there_out" ] || { why="from the skill: $here_out / from a project: $there_out"; return 1; }
  [[ "$there_out" == *"exit=1" ]] || { why="a label on the line was not rejected: $there_out"; return 1; }
}

finds_labels_on_connectors() {
  need_checker || return 1
  local result
  result="$(python3 - "$CHECKER" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("checker", sys.argv[1])
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)
label = {"id": "L", "x": 100, "y": 100, "width": 100, "height": 40}
# As many lines that miss as lines that cross, so a checker that always says "hit" fails.
cases = [
    ("diagonal across", {"x1": 50, "y1": 50, "x2": 250, "y2": 200}, True),
    ("diagonal clear", {"x1": 0, "y1": 0, "x2": 40, "y2": 20}, False),
    ("horizontal across", {"x1": 50, "y1": 120, "x2": 250, "y2": 120}, True),
    ("horizontal clear", {"x1": 50, "y1": 400, "x2": 250, "y2": 400}, False),
    ("vertical across", {"x1": 150, "y1": 0, "x2": 150, "y2": 300}, True),
    ("vertical clear", {"x1": 500, "y1": 0, "x2": 500, "y2": 300}, False),
    # A segment is not an infinite line: extended it would hit, but it ends first.
    ("ends short of the label", {"x1": 0, "y1": 120, "x2": 50, "y2": 120}, False),
]
wrong = [name for name, line, hit in cases if checker.rect_hits_connector(label, line) != hit]
manifest = {"theme": "light", "metaphor": "handoff", "labels": [label],
            "connectors": [dict(cases[0][1], id="C1", lane="main")]}
if not any("collides with connector C1" in e for e in checker.validate_diagram(manifest)):
    wrong.append("validate_diagram misses the diagonal line")
print(", ".join(wrong))
PY
)" || { why="the checker could not be loaded"; return 1; }
  [ -z "$result" ] || { why="wrong for: $result"; return 1; }
}

keeps_clearance() {
  need_checker || return 1
  # The label's bottom edge is at y = 406. A line 12 px below it is too close; 13 px is clear.
  judge "$(edit '.connectors[0].y1 = 418 | .connectors[0].y2 = 418')"
  [ "$status" -ne 0 ] || { why="a line 12 px from the label was accepted"; return 1; }
  judge "$(edit '.connectors[0].y1 = 419 | .connectors[0].y2 = 419')"
  [ "$status" -eq 0 ] || { why="a line 13 px from the label was rejected: $out"; return 1; }
}

names_each_rule() {
  need_checker || return 1
  local filter expected
  while IFS='|' read -r filter expected; do
    judge "$(edit "$filter")"
    [ "$status" -ne 0 ] || { why="accepted after $filter"; return 1; }
    [[ "$out" == *"$expected"* ]] || { why="after $filter, expected '$expected' in: $out"; return 1; }
  done <<'CASES'
del(.theme)|diagram has no theme
del(.metaphor)|diagram has no visual metaphor
del(.connectors[0].lane)|connector request has no semantic lane
.elements[0].container = "nowhere"|element key-chip has no known container
.elements[0].x = 560|element key-chip violates container server padding
CASES
}

names_rejected_slide() {
  need_checker || return 1
  judge "{\"diagrams\":[$CLEAN,$(edit 'del(.theme)')]}"
  [ "$status" -ne 0 ] || { why="a deck with a broken second slide was accepted"; return 1; }
  [[ "$out" == *"slide 2: diagram has no theme"* ]] || { why="slide 2 was not named: $out"; return 1; }
  [[ "$out" != *"slide 1:"* ]] || { why="the clean slide 1 was named: $out"; return 1; }
}

accepts_clean() {
  need_checker || return 1
  judge "$CLEAN"
  [ "$status" -eq 0 ] || { why="the clean diagram was rejected: $out"; return 1; }
  [ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = 1 ] && [[ "$out" == OK:* ]] || { why="expected one OK: line, got: $out"; return 1; }
}

check "the skill keeps the name diagram-composer" skill_name
check "no file names a private deck or theme" no_private_names
check "the private-name scan lists only general shapes" scan_lists_general_shapes
check "the private-name scan finds a planted line of each shape" scan_finds_planted_shapes
check "the private-name scan passes placeholders and plain words" scan_passes_placeholders
check "the private-name scan finds shapes planted in a copy of the plugin" scan_finds_shapes_in_plugin_copy
check "no file holds a home path, a local agent path, or an issue reference" no_local_names
check "the changelog says the name scan looks only for general shapes" changelog_names_general_shapes
check "the SKILL.md points at the user's deck, not a catalog" points_at_users_deck
check "the SKILL.md keeps its three review steps" three_review_steps
check "the SKILL.md example passes the checker" example_passes
check "the SKILL.md names the checker by the skill's folder" names_checker_by_folder
check "the checker runs from any folder" runs_from_any_folder
check "the checker finds labels on connectors" finds_labels_on_connectors
check "the checker keeps a 12 px clearance" keeps_clearance
check "the checker names each rule it rejects" names_each_rule
check "the checker names the rejected slide" names_rejected_slide
check "the checker accepts a clean diagram" accepts_clean

printf '\n%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
