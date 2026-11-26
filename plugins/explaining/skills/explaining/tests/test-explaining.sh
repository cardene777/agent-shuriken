#!/usr/bin/env bash
# Tests for the explaining plugin: which skill it holds, what its musubi.json provides, what the
# provided structure asks for, whether the example uses every technique, what no file in it names,
# and whether the repository lists it. Nothing is written outside a throwaway folder.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
PLUGIN_DIR="$(cd "$HERE/../../.." && pwd)"
TOP="$(cd "$PLUGIN_DIR/../.." && pwd)"
NAME=explaining
SKILL="$SKILL_DIR/SKILL.md"
YAML="$SKILL_DIR/agents/openai.yaml"
DECLARATION="$SKILL_DIR/musubi.json"
STRUCTURE="$SKILL_DIR/references/structure.md"
EXAMPLE="$SKILL_DIR/examples/confirmation-protocol.md"
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

# need <file>...: every file exists. The reason names the file from the plugin folder.
need() {
  local f
  for f in "$@"; do
    [ -f "$f" ] || { why="${f#"$PLUGIN_DIR"/} is missing"; return 1; }
  done
}

holds_one_skill() {
  local found
  found="$(cd "$PLUGIN_DIR/skills" 2>/dev/null && LC_ALL=C ls -d -- */ 2>/dev/null | tr -d / | tr '\n' ' ')"
  [ "$found" = "$NAME " ] || { why="skills/ holds: ${found:-nothing}"; return 1; }
  need "$SKILL" "$YAML" \
    "$PLUGIN_DIR/.claude-plugin/plugin.json" "$PLUGIN_DIR/.codex-plugin/plugin.json" \
    "$PLUGIN_DIR/README.md" "$PLUGIN_DIR/README.ja.md" "$PLUGIN_DIR/CHANGELOG.md" "$PLUGIN_DIR/LICENSE" \
    "$PLUGIN_DIR/assets/icon.svg" "$PLUGIN_DIR/docs/how-it-works.md" "$PLUGIN_DIR/docs/how-it-works.ja.md" || return 1
  grep -qx "name: $NAME" "$SKILL" || { why="SKILL.md does not say name: $NAME"; return 1; }
}

provides_structure() {
  need "$DECLARATION" || return 1
  local problem
  problem="$(python3 -I - "$DECLARATION" <<'PY'
import json, sys
declaration = json.load(open(sys.argv[1], encoding="utf-8"))
want = {"structure": {"version": "1.0.0", "file": "references/structure.md"}}
if declaration.get("musubi") != "2026-11-19":
    print("musubi.json does not name definition version 2026-11-19")
elif declaration.get("provides") != want:
    print("musubi.json provides %s" % json.dumps(declaration.get("provides"), sort_keys=True))
elif "follows" in declaration:
    print("musubi.json follows other content")
PY
)"
  [ -z "$problem" ] || { why="$problem"; return 1; }
  need "$STRUCTURE"
}

# section <heading>: prints the lines under "## <heading>" of the structure, up to the next "## ".
section() {
  awk -v want="## $1" '$0 == want { on = 1; next } on && /^## / { exit } on' "$STRUCTURE"
}

# asks_for <heading> <phrase>...: the structure has the section, the section says when to use it,
# and it holds every phrase, ignoring case.
asks_for() {
  need "$STRUCTURE" || return 1
  local heading="$1" body phrase
  shift
  body="$(section "$heading")"
  [ -n "$body" ] || { why="references/structure.md has no section \"## $heading\""; return 1; }
  grep -qiF -- "Use it when" <<< "$body" || { why="the section \"$heading\" does not say when to use it"; return 1; }
  for phrase in "$@"; do
    grep -qiF -- "$phrase" <<< "$body" || { why="the section \"$heading\" does not say \"$phrase\""; return 1; }
  done
}

one_example_and_map() {
  asks_for "One running example" "every section" || return 1
  asks_for "A map of the stages" "numbered" "before"
}

pairs_and_misreadings() {
  asks_for "Pairs told apart" "table" || return 1
  asks_for "Misreadings ruled out" "negative sentence"
}

every_combination() {
  asks_for "Every combination of conditions" "result" "figure that takes input"
}

closing_table() {
  asks_for "A closing table and one sentence" "table of roles" "one sentence"
}

figures_by_what_they_do() {
  need "$STRUCTURE" || return 1
  local row
  for row in '| A figure that steps | `sequence` |' '| A figure that takes input | `try` |' \
    '| A figure of the state before and after | `state` |'; do
    grep -qF -- "$row" "$STRUCTURE" || { why="references/structure.md has no row $row"; return 1; }
  done
}

# The example marks each part with a comment naming the technique it uses, one per technique heading
# of the structure, and holds a dragon figure of each of the three kinds.
example_uses_everything() {
  need "$STRUCTURE" "$EXAMPLE" || return 1
  local heading kind
  while IFS= read -r heading; do
    grep -qF -- "<!-- technique: $heading -->" "$EXAMPLE" \
      || { why="the example has no part marked <!-- technique: $heading -->"; return 1; }
  done < <(sed -n 's/^## //p' "$STRUCTURE" | grep -vx -e 'Figures by what they do' -e 'Order of the parts')
  for kind in sequence try state; do
    awk '/^```dragon$/ { getline; print }' "$EXAMPLE" | grep -q "^$kind " \
      || { why="the example has no dragon figure of the kind $kind"; return 1; }
  done
}

# Prints file:line for every line under the folders given that holds a home path, a local agent
# path, an issue reference, or a URL outside this repository. Each shape is a general form, and
# none spells out the text it finds. The SVG namespace is not a link.
names_of_this_pc() {
  python3 -I - "$@" <<'PY'
import os, re, sys
own = "github.com/" + "cardene777"
shapes = {
    "home path": r"/(?:Users|home)/[^/\s]+/",
    "local agent path": r"~/\.(?:claude|codex)/",
    "issue reference": r"\b(?:GH|Issue) #\d+",
    "outside URL": r"https?://(?!" + re.escape(own) + r"(?![\w.-]))(?!www\.w3\.org/)[^\s)\"'>]+",
}
pattern = re.compile("|".join(shapes.values()))
images = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico")
for top in sys.argv[1:]:
    for folder, _, files in os.walk(top):
        for name in sorted(files):
            path = os.path.join(folder, name)
            if name.lower().endswith(images):
                continue
            with open(path, encoding="utf-8", errors="ignore") as source:
                for number, line in enumerate(source, 1):
                    if pattern.search(line):
                        print(f"{os.path.relpath(path, top)}:{number}")
PY
}

no_local_names() {
  need "$SKILL" || return 1
  local hits
  hits="$(names_of_this_pc "$PLUGIN_DIR" | grep -v '^skills/[^/]*/tests/')"
  [ -z "$hits" ] || { why="found at: $(printf '%s ' $hits)"; return 1; }
}

# The scan finds each shape planted at the end of SKILL.md in a copy of the plugin, one per line, and
# nothing in the line of plain words. The shapes are printed from parts so that this file does not
# hold them.
scan_finds_planted_shapes() {
  need "$SKILL" || return 1
  local hits expected="" n lines
  mkdir -p "$T/control"
  cp -R "$PLUGIN_DIR" "$T/control/$NAME"
  lines="$(wc -l < "$SKILL" | tr -d ' ')"
  {
    printf '/%s/someone/notes.md\n' Users
    printf '~/.%s/settings.json\n' claude
    printf 'fixed in %s #%d\n' GH 12
    printf 'read %s://%s/guide\n' https example.com
    printf 'plain words, a docs/home/page.md link, #12 alone, %s://%s/%s, and %s://%s/%s/agent-shuriken\n' https github.com cardene777 https github.com cardene777
  } >> "$T/control/$NAME/skills/$NAME/SKILL.md"
  for n in 1 2 3 4; do expected="${expected}skills/$NAME/SKILL.md:$((lines + n)) "; done
  hits="$(names_of_this_pc "$T/control/$NAME" | grep -v '^skills/[^/]*/tests/' | tr '\n' ' ')"
  [ "$hits" = "$expected" ] || { why="expected ${expected}observed: ${hits:-nothing}"; return 1; }
}

repository_lists_it() {
  local file first
  first="$(cd "$TOP/plugins" && LC_ALL=C ls -d -- */ | head -1 | tr -d /)"
  jq -e --arg n "$NAME" '[.plugins[] | select(.name == $n and .source == "./plugins/" + $n)] | length == 1' \
    "$TOP/.claude-plugin/marketplace.json" > /dev/null \
    || { why=".claude-plugin/marketplace.json does not list $NAME once from ./plugins/$NAME"; return 1; }
  for file in README.md README.ja.md; do
    grep -qE "^\| \[$NAME\]\(plugins/$NAME\) \|" "$TOP/$file" || { why="$file has no table row for $NAME"; return 1; }
  done
  for file in docs/publishing.md docs/publishing.ja.md; do
    grep -qE "^\| $NAME \|" "$TOP/$file" || { why="$file has no status row for $NAME"; return 1; }
    grep -F "| $first |" "$TOP/$file" | grep -qF "| $NAME |" \
      || { why="the question table of $file has no column for $NAME"; return 1; }
  done
  root_changelog_names "$TOP/CHANGELOG.md" \
    || { why="CHANGELOG.md names $NAME neither under ## [Unreleased] nor in the newest release's Plugins table"; return 1; }
}

# root_changelog_names <file>: the root changelog names the plugin with a line under ## [Unreleased]
# that starts with "The <name> plugin", or with a row of the newest repository release's table, the
# same two forms that check_root_changelog in scripts/check.sh accepts.
root_changelog_names() {
  local unreleased newest
  unreleased="$(awk '/^## \[Unreleased\]/ { on = 1; next } /^## \[/ { on = 0 } on' "$1")"
  grep -qE "^- The $NAME plugin" <<< "$unreleased" && return 0
  newest="$(awk '/^## \[[0-9]+\.[0-9]+\.[0-9]+\] - / { if (seen) exit; seen = 1; on = 1; next } /^## \[/ { on = 0 } on' "$1")"
  grep -qE "^\| $NAME \| [0-9]+\.[0-9]+\.[0-9]+ \|$" <<< "$newest"
}

check "the plugin holds one skill of its name with its pages" holds_one_skill
check "explaining provides structure in musubi.json" provides_structure
check "the structure asks for one example and a map of the stages" one_example_and_map
check "the structure asks for pairs and ruled-out misreadings" pairs_and_misreadings
check "the structure asks for every combination of conditions" every_combination
check "the structure asks for a closing table and one sentence" closing_table
check "the structure names figures by what they do and maps them to dragon kinds" figures_by_what_they_do
check "the example uses every technique and the three figures" example_uses_everything
check "no file holds a home path, a local agent path, an issue reference, or an outside URL" no_local_names
check "the scan finds a planted line of each shape" scan_finds_planted_shapes
check "the repository lists explaining" repository_lists_it

printf 'checks: %d\n' "$((PASS + FAIL))"
printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
