#!/usr/bin/env bash
# Tests for the chainome-diagram plugin: which skill it holds, what no file in it names, what its
# SKILL.md says, and how diagram-theme.py reads the user's theme file. Nothing is written outside a
# throwaway folder, and every theme run uses a throwaway HOME.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
PLUGIN_DIR="$(cd "$HERE/../../.." && pwd)"
NAME=chainome-diagram
SKILL="$SKILL_DIR/SKILL.md"
THEME="$SKILL_DIR/scripts/diagram-theme.py"
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
  need "$SKILL" "$SKILL_DIR/agents/openai.yaml" || return 1
  grep -qx "name: $NAME" "$SKILL" || { why="SKILL.md does not say name: $NAME"; return 1; }
}

# Prints file:line for every line under the folders given that names the author's PC, products, or
# other repositories. The words are built from parts so that this file does not hold them.
names_of_this_pc() {
  python3 - "$@" <<'PY'
import os, re, sys
pattern = re.compile("/Us" "ers/|~/[.]co" "dex/|~/[.]cl" "aude/|\\b(?:G" "H|Iss" "ue) #\\d+|agent-con" "figs"
                     "|(?i:jf" "et|kagi" "ban)|\\bO" "WS\\b")
images = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico")
for top in sys.argv[1:]:
    for folder, _, files in os.walk(top):
        for name in files:
            path = os.path.join(folder, name)
            if name.lower().endswith(images):
                continue
            with open(path, encoding="utf-8", errors="ignore") as source:
                for number, line in enumerate(source, 1):
                    if pattern.search(line):
                        print(f"{os.path.relpath(path, top)}:{number}")
PY
}

# The scan finds each general shape planted in a throwaway folder, one per line, and nothing in a
# line of plain words. The shapes are printed from parts so that this file does not hold them.
scan_finds_general_shapes() {
  local hits
  mkdir -p "$T/control"
  {
    printf '/%s/someone/notes.md\n' Users
    printf '/%s/someone/notes.md\n' home
    printf '~/.%s/settings.json\n' claude
    printf '~/.%s/config.toml\n' codex
    printf 'fixed in %s #%d\n' GH 12
    printf 'see %s #%d\n' Issue 3
    printf 'plain words, a docs/home/page.md link, and #12 alone\n'
  } > "$T/control/planted.md"
  hits="$(names_of_this_pc "$T/control" | tr '\n' ' ')"
  [ "$hits" = "planted.md:1 planted.md:2 planted.md:3 planted.md:4 planted.md:5 planted.md:6 " ] \
    || { why="expected lines 1 to 6 of planted.md (a home path under /Users and /home, a local agent path for each agent, an issue reference of each form), observed: ${hits:-nothing}"; return 1; }
}

# The scan names the shapes it looks for, and its pattern is written whole: no word in it is joined
# from two string literals, which is how a name would hide from a search.
scan_names_only_general_shapes() {
  local shapes body
  shapes="$(names_of_this_pc --shapes | tr '\n' '|')"
  [ "$shapes" = "home path|local agent path|issue reference|" ] \
    || { why="the scan names the shapes: ${shapes:-nothing}; expected home path, local agent path, issue reference"; return 1; }
  body="$(sed -n '/^names_of_this_pc() {$/,/^}$/p' "$HERE/test-$NAME.sh" | tr '\n' ' ')"
  [ -n "$body" ] || { why="the scan function was not found in the test"; return 1; }
  ! printf '%s' "$body" | grep -qE "[\"'][[:space:]]+[\"']" \
    || { why="the scan joins string literals: $(printf '%s' "$body" | grep -oE ".{0,12}[\"'][[:space:]]+[\"'].{0,12}" | head -1)"; return 1; }
}

no_local_names() {
  need "$SKILL" || return 1
  local hits
  hits="$(names_of_this_pc "$PLUGIN_DIR")"
  [ -z "$hits" ] || { why="found at: $(printf '%s ' $hits)"; return 1; }
}

# The first word of the plugin name may appear only inside the name itself: in the skill name,
# paths, and install commands. The word is taken from NAME, so this file adds no copy of it.
first_word_only_in_the_name() {
  local hits
  hits="$(python3 - "$PLUGIN_DIR" "$NAME" <<'PY'
import os, re, sys
top, name = sys.argv[1], sys.argv[2]
word = re.compile(re.escape(name.split("-")[0]), re.I)
images = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico")
for folder, _, files in os.walk(top):
    for file_name in files:
        path = os.path.join(folder, file_name)
        if file_name.lower().endswith(images):
            continue
        with open(path, encoding="utf-8", errors="ignore") as source:
            for number, line in enumerate(source, 1):
                if word.search(line.replace(name, "")):
                    print(f"{os.path.relpath(path, top)}:{number}")
PY
)"
  [ -z "$hits" ] || { why="the word is used outside the name at: $(printf '%s ' $hits)"; return 1; }
}

display_name_is_general() {
  local claude codex yaml
  claude="$(jq -r .displayName "$PLUGIN_DIR/.claude-plugin/plugin.json")"
  codex="$(jq -r .interface.displayName "$PLUGIN_DIR/.codex-plugin/plugin.json")"
  yaml="$(sed -nE 's/^  display_name: "(.+)"$/\1/p' "$SKILL_DIR/agents/openai.yaml")"
  [ "$claude|$codex|$yaml" = "Blockchain Diagram|Blockchain Diagram|Blockchain Diagram" ] \
    || { why="display names: .claude-plugin '$claude', .codex-plugin '$codex', openai.yaml '$yaml'"; return 1; }
}

no_agent_names() {
  need "$SKILL" || return 1
  local hit
  # A folder such as .claude/ is a path, not the agent's name.
  hit="$(grep -inE '(^|[^.a-z])(askuserquestion|claude|codex|chatgpt|gpt-?[0-9]|opus|sonnet|haiku|gemini|copilot)' "$SKILL" | head -1)"
  [ -z "$hit" ] || { why="SKILL.md names an agent, its tool, or a model: $hit"; return 1; }
  ! sed -n '2,/^---$/p' "$SKILL" | grep -q '^allowed-tools:' || { why="SKILL.md has allowed-tools in its frontmatter"; return 1; }
  grep -qF 'ask the user in the chat' "$SKILL" || { why="SKILL.md does not say to ask the user in the chat"; return 1; }
}

# theme_case <case>: makes a throwaway HOME and a git repository for one run of diagram-theme.py.
theme_case() {
  mkdir -p "$T/$1/home" "$T/$1/repo/.git" "$T/$1/repo/src"
}

# run_theme <case>: runs diagram-theme.py from a folder inside the case's repository, with the
# case's HOME. Sets status, and leaves stdout and stderr in the case folder.
status=0
run_theme() {
  (cd "$T/$1/repo/src" && HOME="$T/$1/home" python3 "$THEME" > "$T/$1/out" 2> "$T/$1/err")
  status=$?
}

# same_json <file> <json>: the file holds the JSON given, keys in any order.
same_json() {
  python3 - "$1" "$2" <<'PY'
import json, sys
try:
    observed = json.load(open(sys.argv[1], encoding="utf-8"))
except ValueError:
    sys.exit(1)
sys.exit(0 if observed == json.loads(sys.argv[2]) else 1)
PY
}

theme_from_home() {
  need "$THEME" || return 1
  theme_case home
  printf '%s\n' '{"light": {"accent": "#0b6e4f", "ink": "#111111"}, "dark": {"accent": "#5fd0a5"}, "font": {"size": 16, "mono": "\"JetBrains Mono\", monospace"}, "space": {"radius": 6}}' \
    > "$T/home/home/.design-theme.json"
  run_theme home
  [ "$status" -eq 0 ] || { why="exit $status: $(head -3 "$T/home/err")"; return 1; }
  same_json "$T/home/out" '{"light": {"accent": "#0b6e4f", "ink": "#111111"}, "dark": {"accent": "#5fd0a5"}, "font": {"size": 16, "mono": "\"JetBrains Mono\", monospace"}, "space": {"radius": 6}}' \
    || { why="printed: $(head -c 300 "$T/home/out")"; return 1; }
}

repository_theme_wins() {
  need "$THEME" || return 1
  theme_case repo
  printf '%s\n' '{"light": {"accent": "#0b6e4f"}, "font": {"size": 16}}' > "$T/repo/home/.design-theme.json"
  printf '%s\n' '{"light": {"accent": "#aa3300"}}' > "$T/repo/repo/.design-theme.json"
  run_theme repo
  [ "$status" -eq 0 ] || { why="exit $status: $(head -3 "$T/repo/err")"; return 1; }
  same_json "$T/repo/out" '{"light": {"accent": "#aa3300"}}' \
    || { why="expected only the repository's light.accent, without the home file's keys; printed: $(head -c 300 "$T/repo/out")"; return 1; }
}

no_theme_prints_empty() {
  need "$THEME" || return 1
  theme_case none
  run_theme none
  [ "$status" -eq 0 ] || { why="exit $status: $(head -3 "$T/none/err")"; return 1; }
  same_json "$T/none/out" '{}' || { why="printed: $(head -c 300 "$T/none/out")"; return 1; }
  grep -qF "project's own look" "$T/none/err" || { why="it does not say that the diagram keeps the project's own look: $(head -3 "$T/none/err")"; return 1; }
}

# The full example of the shared format, with the page keys that a diagram leaves out, and a file of
# the boundary values that are still allowed.
full_theme_accepted() {
  need "$THEME" || return 1
  theme_case full
  cat > "$T/full/home/.design-theme.json" <<'JSON'
{
  "light": {
    "bg": "#fafaf7", "surface": "#ffffff", "ink": "#111111", "sub": "#444444", "line": "#dddddd",
    "accent": "#0b6e4f", "accent-ink": "#ffffff", "accent-soft": "#e3f2ec", "bar": "#eeeeee", "label": "#f2f2f2"
  },
  "dark": {
    "bg": "#101312", "surface": "#181c1a", "ink": "#eeeeee", "sub": "#b0b8b4", "line": "#2c3330",
    "accent": "#5fd0a5", "accent-ink": "#0b1410", "accent-soft": "#1b3a2f", "bar": "#232a27", "label": "#1f2523"
  },
  "font": { "sans": "\"Inter\", sans-serif", "mono": "\"JetBrains Mono\", monospace", "size": 16, "line-height": 1.75 },
  "space": { "page-width": 1100, "radius-small": 4, "radius": 6, "radius-large": 8 }
}
JSON
  run_theme full
  [ "$status" -eq 0 ] || { why="exit $status: $(head -3 "$T/full/err")"; return 1; }
  same_json "$T/full/out" '{
    "light": {"bg": "#fafaf7", "surface": "#ffffff", "ink": "#111111", "sub": "#444444", "line": "#dddddd",
              "accent": "#0b6e4f", "accent-ink": "#ffffff", "accent-soft": "#e3f2ec", "label": "#f2f2f2"},
    "dark": {"bg": "#101312", "surface": "#181c1a", "ink": "#eeeeee", "sub": "#b0b8b4", "line": "#2c3330",
             "accent": "#5fd0a5", "accent-ink": "#0b1410", "accent-soft": "#1b3a2f", "label": "#1f2523"},
    "font": {"sans": "\"Inter\", sans-serif", "mono": "\"JetBrains Mono\", monospace", "size": 16, "line-height": 1.75},
    "space": {"radius-small": 4, "radius": 6, "radius-large": 8}}' \
    || { why="expected every key but light.bar, dark.bar, and space.page-width; printed: $(head -c 400 "$T/full/out")"; return 1; }
  theme_case edge
  printf '%s\n' '{"light": {"accent": "rgb(42, 91, 215)", "ink": "#123"}, "font": {"size": 12, "line-height": 3}, "space": {"radius-small": 0, "radius-large": 64}}' \
    > "$T/edge/home/.design-theme.json"
  run_theme edge
  [ "$status" -eq 0 ] || { why="the boundary values were refused, exit $status: $(head -3 "$T/edge/err")"; return 1; }
  same_json "$T/edge/out" '{"light": {"accent": "rgb(42, 91, 215)", "ink": "#123"}, "font": {"size": 12, "line-height": 3}, "space": {"radius-small": 0, "radius-large": 64}}' \
    || { why="the boundary values printed: $(head -c 300 "$T/edge/out")"; return 1; }
}

# Each way a key can be wrong is named on standard error, nothing reaches stdout, and the exit is 2.
theme_refuses_bad_keys() {
  need "$THEME" || return 1
  local key
  theme_case bad
  printf '%s\n' '{"light": {"acent": "#111111", "ink": "blue-ish"}, "dark": {"bg": 12}, "font": {"size": 11, "line-height": "1.7", "sans": "Inter; color: red"}, "space": {"radius": 65, "radius-small": true}, "shadow": {}}' \
    > "$T/bad/home/.design-theme.json"
  run_theme bad
  [ "$status" -eq 2 ] || { why="exit $status instead of 2"; return 1; }
  [ ! -s "$T/bad/out" ] || { why="it printed to stdout: $(head -c 200 "$T/bad/out")"; return 1; }
  for key in light.acent light.ink dark.bg font.size font.line-height font.sans space.radius space.radius-small shadow; do
    grep -qE "(^|[^a-z.-])$key:" "$T/bad/err" || { why="the refusal does not name $key: $(tr '\n' ' ' < "$T/bad/err" | head -c 400)"; return 1; }
  done
}

theme_refuses_non_json() {
  need "$THEME" || return 1
  theme_case broken
  printf '%s\n' '{"light": {"accent": "#0b6e4f"' > "$T/broken/home/.design-theme.json"
  run_theme broken
  [ "$status" -eq 2 ] || { why="exit $status instead of 2"; return 1; }
  [ ! -s "$T/broken/out" ] || { why="it printed to stdout: $(head -c 200 "$T/broken/out")"; return 1; }
  grep -qF '.design-theme.json' "$T/broken/err" || { why="the refusal does not name the theme file: $(head -3 "$T/broken/err")"; return 1; }
}

theme_standard_library() {
  need "$THEME" || return 1
  local bad
  bad="$(python3 - "$THEME" <<'PY'
import ast, re, sys
source = open(sys.argv[1], encoding="utf-8").read()
names = set()
for node in ast.walk(ast.parse(source)):
    if isinstance(node, ast.Import):
        names.update(alias.name.split(".")[0] for alias in node.names)
    elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
        names.add(node.module.split(".")[0])
outside = sorted(name for name in names if name not in sys.stdlib_module_names)
if re.search(r"^# /// script$", source, re.M):
    outside.append("a PEP 723 script block")
print(" ".join(outside))
PY
)"
  [ -z "$bad" ] || { why="imports beyond the standard library: $bad"; return 1; }
}

skill_applies_theme() {
  need "$SKILL" || return 1
  local phrase key
  for phrase in 'scripts/diagram-theme.py' '`.design-theme.json` at the root of the repository' '`~/.design-theme.json`' "project's own look"; do
    grep -qF -- "$phrase" "$SKILL" || { why="SKILL.md does not say: $phrase"; return 1; }
  done
  [ "$(grep -nF '`.design-theme.json` at the root of the repository' "$SKILL" | head -1 | cut -d: -f1)" -lt \
    "$(grep -nF '`~/.design-theme.json`' "$SKILL" | head -1 | cut -d: -f1)" ] \
    || { why="SKILL.md does not name the repository's theme file before the home one"; return 1; }
  for key in bg surface ink sub line accent accent-ink accent-soft label sans mono size line-height radius-small radius radius-large; do
    grep -qF "\`$key\`" "$SKILL" || { why="SKILL.md does not map the key $key to a part of the diagram"; return 1; }
  done
}

pages_say_where_the_theme_is() {
  local page phrase
  for page in README.md README.ja.md docs/how-it-works.md docs/how-it-works.ja.md; do
    need "$PLUGIN_DIR/$page" || return 1
    for phrase in '`.design-theme.json`' '`~/.design-theme.json`' 'diagram-theme.py'; do
      grep -qF -- "$phrase" "$PLUGIN_DIR/$page" || { why="$page does not name $phrase"; return 1; }
    done
  done
}

changelog_names_theme() {
  need "$PLUGIN_DIR/CHANGELOG.md" || return 1
  grep -qE '^- .*`\.design-theme\.json`' "$PLUGIN_DIR/CHANGELOG.md" \
    || { why="no release note line in CHANGELOG.md names \`.design-theme.json\`"; return 1; }
}

check "the plugin holds one skill of its name" holds_one_skill
check "no file holds the first word of the plugin name outside the name" first_word_only_in_the_name
check "the display name is Blockchain Diagram" display_name_is_general
check "the scan finds a home path, a local agent path, and an issue reference" scan_finds_general_shapes
check "the scan names only the three general shapes and builds no word from parts" scan_names_only_general_shapes
check "no file names a local folder or another repository" no_local_names
check "the SKILL.md names no agent or its tool" no_agent_names
check "diagram-theme prints the diagram keys of the home theme" theme_from_home
check "a repository theme wins over the home theme" repository_theme_wins
check "without a theme file diagram-theme prints an empty object" no_theme_prints_empty
check "a full shared theme file is accepted without the page keys" full_theme_accepted
check "diagram-theme refuses unknown keys and bad values naming each key" theme_refuses_bad_keys
check "diagram-theme refuses a file that is not JSON" theme_refuses_non_json
check "diagram-theme uses only the standard library" theme_standard_library
check "the SKILL.md applies the theme file and keeps the project's look without one" skill_applies_theme
check "the READMEs and how-it-works pages say where the theme file is read from" pages_say_where_the_theme_is
check "the changelog names the theme file" changelog_names_theme

printf '\n%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
