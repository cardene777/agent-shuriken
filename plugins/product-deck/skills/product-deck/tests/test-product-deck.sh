#!/usr/bin/env bash
# Tests for the product-deck plugin: which skill it holds, which shapes no file in it holds, that it
# ships no sample image, where its SKILL.md takes samples and Playwright from, which word lists
# scripts/audit-text.mjs reads and what it checks without one, and which theme file scripts/theme.mjs
# reads. Every HOME, repository, and deck the tests use is a throwaway folder.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
PLUGIN_DIR="$(cd "$HERE/../../.." && pwd)"
NAME=product-deck
SKILL="$SKILL_DIR/SKILL.md"
AUDIT_TEXT="$SKILL_DIR/scripts/audit-text.mjs"
THEME="$SKILL_DIR/scripts/theme.mjs"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

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

# need <file>...: every file exists.
need() {
  local f
  for f in "$@"; do
    [ -f "$f" ] || { why="$f is missing"; return 1; }
  done
}

# run <command>...: runs a command; sets out and status.
run() {
  out="$("$@" 2>&1)"
  status=$?
}

holds_one_skill() {
  local found
  found="$(cd "$PLUGIN_DIR/skills" 2>/dev/null && LC_ALL=C ls -d -- */ 2>/dev/null | tr -d / | tr '\n' ' ')"
  [ "$found" = "$NAME " ] || { why="skills/ holds: ${found:-nothing}"; return 1; }
  need "$SKILL" "$SKILL_DIR/agents/openai.yaml" || return 1
  grep -qx "name: $NAME" "$SKILL" || { why="SKILL.md does not say name: $NAME"; return 1; }
}

# The shapes no file of a public plugin may hold, one regular expression per line: a home folder on
# macOS or Linux where a path starts (a throwaway HOME such as $T/case/home/ is not one), the
# configuration folder of a local agent, and an issue reference. They are general shapes only, so
# this file names no product, company, or person.
SHAPES='(?<![A-Za-z0-9_.-])/(?:Users|home)/[A-Za-z0-9._-]+
~/[.](?:claude|codex)/
\b(?:GH|Issue) #[0-9]+'

# Prints file:line for every line under the folders given that holds one of SHAPES.
private_shapes_in() {
  SHAPES="$SHAPES" python3 - "$@" <<'PY'
import os, re, sys
pattern = re.compile("|".join(os.environ["SHAPES"].splitlines()))
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

no_local_names() {
  need "$SKILL" || return 1
  local hits
  # The scan catches planted lines (scan_lists_general_shapes), so an empty result means the shapes are absent.
  hits="$(private_shapes_in "$PLUGIN_DIR")"
  [ -z "$hits" ] || { why="found at: $(printf '%s ' $hits)"; return 1; }
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

# The scan's patterns are general shapes only: SHAPES is assigned once, as three plain lines with no
# quote or expansion that could join parts into a word, and once the words of those shapes and the
# syntax of regular expressions are taken out, no letter is left. The scan compiles no other pattern,
# and it catches a planted line of each shape while it passes a home folder written with a <name> placeholder.
scan_lists_general_shapes() {
  local said
  said="$(python3 - "$HERE/test-product-deck.sh" 2>&1 <<'PY'
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
    sys.exit("the scan compiles a pattern other than SHAPES: %r" % compiled)
PY
)" || { why="$said"; return 1; }
  mkdir -p "$T/shapes"
  {
    printf 'see /%s/someone/notes\n' Users home
    printf 'see ~/.%s/settings\n' claude codex
    printf 'see %s #%d\n' GH 12 Issue 3
  } > "$T/shapes/planted.md"
  printf 'a placeholder such as /%s/<name> or /%s/<name>\n' Users home > "$T/shapes/placeholder.md"
  local hits
  hits="$(private_shapes_in "$T/shapes" | LC_ALL=C sort | tr '\n' ' ')"
  [ "$hits" = "planted.md:1 planted.md:2 planted.md:3 planted.md:4 planted.md:5 planted.md:6 " ] \
    || { why="the scan found: ${hits:-nothing}"; return 1; }
}

ships_no_sample_image() {
  local images
  images="$(cd "$PLUGIN_DIR" && find . -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' \
    -o -iname '*.webp' -o -iname '*.svg' \) | LC_ALL=C sort | tr '\n' ' ')"
  [ "$images" = "./assets/icon.svg " ] || { why="the images are not only assets/icon.svg: ${images:-none}"; return 1; }
  [ ! -e "$SKILL_DIR/samples" ] || { why="the skill still has a samples/ folder"; return 1; }
}

# The SKILL.md lists the samples with two shell lines; they list the folder only when it exists.
reads_samples_when_present() {
  need "$SKILL" || return 1
  local set_line='samples="$HOME/.product-deck/samples"' list_line='[ -d "$samples" ] && ls "$samples"'
  grep -qxF -- "$set_line" "$SKILL" && grep -qxF -- "$list_line" "$SKILL" \
    || { why="SKILL.md does not list ~/.product-deck/samples/ with: $set_line / $list_line"; return 1; }
  mkdir -p "$T/samples-none" "$T/samples-some/.product-deck/samples"
  : > "$T/samples-some/.product-deck/samples/hero-left.jpg"
  run env HOME="$T/samples-none" bash -c "$set_line; $list_line"
  [ "$status" -ne 0 ] && [ -z "$out" ] || { why="without the folder the lines printed: $status $out"; return 1; }
  run env HOME="$T/samples-some" bash -c "$set_line; $list_line"
  [ "$status" -eq 0 ] && [ "$out" = hero-left.jpg ] || { why="with the folder the lines printed: $status $out"; return 1; }
}

# Every script that drives a browser resolves Playwright from PLAYWRIGHT_FROM, and says so when it is not there.
playwright_from_project() {
  need "$SKILL" "$SKILL_DIR/scripts/capture.mjs" || return 1
  local f
  grep -qF 'PLAYWRIGHT_FROM' "$SKILL" || { why="SKILL.md does not say to pass PLAYWRIGHT_FROM"; return 1; }
  for f in "$SKILL_DIR"/scripts/*.mjs; do
    grep -qi 'playwright' "$f" || continue
    grep -qE 'load-playwright\.mjs|process\.env\.PLAYWRIGHT_FROM' "$f" || { why="$(basename "$f") does not resolve Playwright from PLAYWRIGHT_FROM"; return 1; }
  done
  mkdir -p "$T/no-playwright"
  run env PLAYWRIGHT_FROM="$T/no-playwright" node "$SKILL_DIR/scripts/capture.mjs" --url "file://$T/page.html" --out "$T/shot.png"
  [ "$status" -ne 0 ] && [[ "$out" == *PLAYWRIGHT_FROM* ]] || { why="a project without Playwright gave: $status $(printf '%s' "$out" | tail -2 | tr '\n' ' ')"; return 1; }
  [ ! -e "$T/shot.png" ] || { why="a screenshot was written without Playwright"; return 1; }
}

# deck <folder> <slide text>: writes a one-slide deck and a terms table that matches it.
deck() {
  mkdir -p "$1"
  printf 'export const faces = [{ title: "Sample slide", body: "%s" }];\n' "$2" > "$1/deck-data.mjs"
  printf '%s\n' 'synonym  record  entry' 'core  record  1' > "$1/terms.txt"
}

# The words in the table use the English names of the kinds.
english_list() {
  printf '%s\n' '# kind  word  instead' 'wordy  utilize  use' 'bare-english  workflow  steps' 'allow  API  keep' > "$1"
}

reads_home_word_list() {
  need "$AUDIT_TEXT" || return 1
  deck "$T/home-list/deck" "This slide utilizes the record."
  mkdir -p "$T/home-list/home/.product-deck"
  english_list "$T/home-list/home/.product-deck/prose-words.txt"
  run env HOME="$T/home-list/home" node "$AUDIT_TEXT" "$T/home-list/deck/deck-data.mjs" --terms "$T/home-list/deck/terms.txt"
  [ "$status" -eq 1 ] && [[ "$out" == *utilize* ]] || { why="the word list in the home folder was not read: $status $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)"; return 1; }
  deck "$T/home-list/clean" "This slide shows the record."
  run env HOME="$T/home-list/home" node "$AUDIT_TEXT" "$T/home-list/clean/deck-data.mjs" --terms "$T/home-list/clean/terms.txt"
  [ "$status" -eq 0 ] || { why="a slide without listed words was flagged: $status $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)"; return 1; }
}

# The passed list wins over the home folder, and the Japanese names of the kinds are read too.
reads_passed_word_list() {
  need "$AUDIT_TEXT" || return 1
  local list="$T/passed/prose-words.txt"
  mkdir -p "$T/passed/home"
  printf 'export const faces = [{ title: "見本の面", body: "この面は記録を実施するの文を持つ" }];\n' > "$T/passed/deck-data.mjs"
  printf '%s\n' '同義  記録  台帳' '中核  記録  1' > "$T/passed/terms.txt"
  printf '%s\n' '回りくどい  を実施する  をする' '裸の英単語  workflow  流れ' '許す  API  そのまま' > "$list"
  run env HOME="$T/passed/home" node "$AUDIT_TEXT" "$T/passed/deck-data.mjs" --terms "$T/passed/terms.txt" --prose-words "$list"
  [ "$status" -eq 1 ] && [[ "$out" == *を実施する* ]] || { why="the passed word list was not read: $status $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)"; return 1; }
  # A list in the home folder that lacks the word does not replace the passed one.
  mkdir -p "$T/passed/home/.product-deck"
  english_list "$T/passed/home/.product-deck/prose-words.txt"
  run env HOME="$T/passed/home" node "$AUDIT_TEXT" "$T/passed/deck-data.mjs" --terms "$T/passed/terms.txt" --prose-words "$list"
  [ "$status" -eq 1 ] && [[ "$out" == *を実施する* ]] || { why="the home folder's list replaced the passed one: $status"; return 1; }
}

# says_no_list: the output says that no word list was found where it looked, and that the built-in rules ran.
says_no_list() {
  [[ "$out" == *"no word list at ~/.product-deck/prose-words.txt"* && "$out" == *"built-in rules"* ]] \
    || { why="the output does not say that no word list was found and the built-in rules ran: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-240)"; return 1; }
}

# With an empty ~/.product-deck/, a word that mixes in for a kept term and a Japanese sentence where a
# person does a thing's action are flagged by the built-in rules.
flags_builtin_without_list() {
  need "$AUDIT_TEXT" || return 1
  mkdir -p "$T/no-list/home/.product-deck"
  deck "$T/no-list/synonym" "Each entry holds the record."
  run env HOME="$T/no-list/home" node "$AUDIT_TEXT" "$T/no-list/synonym/deck-data.mjs" --terms "$T/no-list/synonym/terms.txt"
  [ "$status" -eq 1 ] && [[ "$out" == *"entry → record"* ]] \
    || { why="a word that mixes in was not flagged without a word list: $status $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)"; return 1; }
  says_no_list || return 1
  mkdir -p "$T/no-list/subject"
  printf 'export const faces = [{ title: "見本の面", body: "人は記録に残る" }];\n' > "$T/no-list/subject/deck-data.mjs"
  printf '%s\n' '同義  記録  台帳' '中核  記録  1' > "$T/no-list/subject/terms.txt"
  run env HOME="$T/no-list/home" node "$AUDIT_TEXT" "$T/no-list/subject/deck-data.mjs" --terms "$T/no-list/subject/terms.txt"
  [ "$status" -eq 1 ] && [[ "$out" == *"a person does a thing's action"* ]] \
    || { why="a person doing a thing's action was not flagged without a word list: $status $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)"; return 1; }
  says_no_list
}

# With an empty ~/.product-deck/, a slide that breaks no built-in rule passes, even with a word a list would drop.
passes_clean_without_list() {
  need "$AUDIT_TEXT" || return 1
  mkdir -p "$T/no-list-clean/home/.product-deck"
  deck "$T/no-list-clean/deck" "This slide utilizes the record."
  run env HOME="$T/no-list-clean/home" node "$AUDIT_TEXT" "$T/no-list-clean/deck/deck-data.mjs" --terms "$T/no-list-clean/deck/terms.txt"
  [ "$status" -eq 0 ] || { why="a clean slide without a word list exited $status, not 0: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)"; return 1; }
  says_no_list
}

lists_builtin_without_list() {
  need "$AUDIT_TEXT" || return 1
  local listed
  mkdir -p "$T/no-list-names/home/.product-deck"
  listed="$(env HOME="$T/no-list-names/home" node "$AUDIT_TEXT" --list-checks 2>/dev/null)"
  status=$?
  [ "$status" -eq 0 ] && [ "$listed" = "the same thing is called by different words
a core word comes before its explanation
a person does a thing's action" ] || { why="--list-checks without a word list gave: $status $(printf '%s' "$listed" | tr '\n' '|')"; return 1; }
}

# A list passed by path is the caller's choice, so a missing one stops the run instead of falling back.
refuses_missing_passed_list() {
  need "$AUDIT_TEXT" || return 1
  mkdir -p "$T/missing-passed/home/.product-deck"
  deck "$T/missing-passed/deck" "This slide shows the record."
  run env HOME="$T/missing-passed/home" node "$AUDIT_TEXT" "$T/missing-passed/deck/deck-data.mjs" \
    --terms "$T/missing-passed/deck/terms.txt" --prose-words "$T/missing-passed/none.txt"
  [ "$status" -eq 2 ] || { why="a missing passed list exited $status, not 2: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)"; return 1; }
  [[ "$out" == *"$T/missing-passed/none.txt"* ]] || { why="the refusal does not name the passed path: $out"; return 1; }
  [[ "$out" != *"checked "* ]] || { why="a check ran with a missing passed list: $out"; return 1; }
}

reads_home_terms() {
  need "$AUDIT_TEXT" || return 1
  deck "$T/home-terms/deck" "Each entry holds the record."
  mkdir -p "$T/home-terms/home/.product-deck"
  english_list "$T/home-terms/home/.product-deck/prose-words.txt"
  cp "$T/home-terms/deck/terms.txt" "$T/home-terms/home/.product-deck/writing-terms.txt"
  run env HOME="$T/home-terms/home" node "$AUDIT_TEXT" "$T/home-terms/deck/deck-data.mjs"
  [ "$status" -eq 1 ] && [[ "$out" == *"entry"*"record"* ]] || { why="the terms in the home folder were not read: $status $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)"; return 1; }
  need "$PLUGIN_DIR/docs/how-it-works.md" || return 1
  grep -qE '^synonym +[a-z]+ +[a-z]+' "$PLUGIN_DIR/docs/how-it-works.md" && grep -qE '^core +[a-z]+ +[0-9]+' "$PLUGIN_DIR/docs/how-it-works.md" \
    || { why="docs/how-it-works.md does not show a terms table with synonym and core lines"; return 1; }
  [ ! -e "$SKILL_DIR/references/writing-terms.txt" ] || { why="the skill still ships references/writing-terms.txt"; return 1; }
}

refuses_without_terms() {
  need "$AUDIT_TEXT" || return 1
  deck "$T/no-terms/deck" "This slide shows the record."
  mkdir -p "$T/no-terms/home/.product-deck"
  english_list "$T/no-terms/home/.product-deck/prose-words.txt"
  run env HOME="$T/no-terms/home" node "$AUDIT_TEXT" "$T/no-terms/deck/deck-data.mjs"
  [ "$status" -eq 2 ] || { why="without terms it exited $status, not 2: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)"; return 1; }
  [[ "$out" == *"~/.product-deck/writing-terms.txt"* ]] || { why="the refusal does not name ~/.product-deck/writing-terms.txt: $out"; return 1; }
}

# theme_case <folder>: a throwaway home and git repository for the theme script, with a folder inside the repository.
theme_case() {
  mkdir -p "$1/home" "$1/repo/.git" "$1/repo/docs/decks"
}

# theme_run <folder>: runs the theme script inside the repository of the folder; sets status, out (stdout), and err.
theme_run() {
  out="$(cd "$1/repo/docs/decks" && env HOME="$1/home" node "$THEME" 2>"$1/err")"
  status=$?
  err="$(cat "$1/err")"
}

keeps_look_without_theme() {
  need "$THEME" || return 1
  theme_case "$T/theme-none"
  theme_run "$T/theme-none"
  [ "$status" -eq 0 ] && [ -z "$out" ] || { why="without a theme file it gave: $status $out"; return 1; }
  [[ "$err" == *"no theme file"* && "$err" == *"own look"* ]] || { why="it does not say the deck keeps its own look: $err"; return 1; }
}

reads_home_theme() {
  need "$THEME" || return 1
  theme_case "$T/theme-home"
  cat > "$T/theme-home/home/.design-theme.json" <<'JSON'
{
  "light": {"accent": "#0b6e4f", "ink": "#111111", "bar": "#eeeeee", "label": "#f2f2f2"},
  "dark": {"accent": "#5fd0a5"},
  "font": {"sans": "\"Inter\", sans-serif", "size": 16, "line-height": 1.6},
  "space": {"radius-small": 0, "radius": 6, "radius-large": 64, "page-width": 1100}
}
JSON
  theme_run "$T/theme-home"
  [ "$status" -eq 0 ] || { why="a home theme file exited $status: $err"; return 1; }
  local line
  for line in ':root {' '  --accent: #0b6e4f;' '  --ink: #111111;' '  --sans: "Inter", sans-serif;' '  --line-height: 1.6;' \
    '  --radius-small: 0px;' '  --radius: 6px;' '  --radius-large: 64px;' '}'; do
    grep -qxF -- "$line" <<<"$out" || { why="the CSS lacks the line '$line': $(printf '%s' "$out" | tr '\n' '|')"; return 1; }
  done
  [ "$(grep -c -- '--' <<<"$out")" = 7 ] || { why="the CSS sets other tokens: $(printf '%s' "$out" | tr '\n' '|')"; return 1; }
  for line in dark.accent light.bar light.label font.size space.page-width; do
    [[ "$err" == *"$line"* ]] || { why="it does not name $line as not used: $err"; return 1; }
  done
}

repo_theme_wins() {
  need "$THEME" || return 1
  theme_case "$T/theme-repo"
  printf '%s\n' '{"light": {"accent": "#0b6e4f"}, "font": {"sans": "serif"}}' > "$T/theme-repo/home/.design-theme.json"
  printf '%s\n' '{"light": {"accent": "#aa3300"}}' > "$T/theme-repo/repo/.design-theme.json"
  theme_run "$T/theme-repo"
  [ "$status" -eq 0 ] && grep -qxF '  --accent: #aa3300;' <<<"$out" \
    || { why="the repository theme was not used: $status $(printf '%s' "$out" | tr '\n' '|') $err"; return 1; }
  [[ "$out" != *"#0b6e4f"* && "$out" != *"--sans"* ]] || { why="the home theme was merged in: $(printf '%s' "$out" | tr '\n' '|')"; return 1; }
}

refuses_bad_theme() {
  need "$THEME" || return 1
  theme_case "$T/theme-bad"
  cat > "$T/theme-bad/repo/.design-theme.json" <<'JSON'
{
  "light": {"acent": "#000000", "accent": "blue"},
  "font": {"mono": "x; color: red", "size": 50, "line-height": 3.5},
  "space": {"radius": 65},
  "shadow": {}
}
JSON
  theme_run "$T/theme-bad"
  [ "$status" -eq 2 ] && [ -z "$out" ] || { why="a bad theme file gave: $status $out"; return 1; }
  local key
  for key in light.acent light.accent font.mono font.size font.line-height space.radius shadow; do
    [[ "$err" == *"$key"* ]] || { why="the refusal does not name $key: $err"; return 1; }
  done
  printf '{"light": \n' > "$T/theme-bad/repo/.design-theme.json"
  theme_run "$T/theme-bad"
  [ "$status" -eq 2 ] && [ -z "$out" ] || { why="a theme file that is not JSON gave: $status $out"; return 1; }
}

skill_applies_theme() {
  need "$SKILL" || return 1
  grep -qF 'node "$S/theme.mjs"' "$SKILL" || { why="SKILL.md does not run node \"\$S/theme.mjs\""; return 1; }
  grep -qF '.design-theme.json' "$SKILL" || { why="SKILL.md does not name .design-theme.json"; return 1; }
  grep -qF 'every style takes its colors, type, and corners from the theme' "$SKILL" \
    || { why="SKILL.md does not say every style takes its colors, type, and corners from the theme"; return 1; }
  grep -qF 'pick one main color' "$SKILL" || { why="SKILL.md does not say to pick one main color without a theme"; return 1; }
}

# The pages that describe the plugin say both changes, in English and in Japanese.
docs_describe_changes() {
  local unreleased f
  unreleased="$(sed -n '/^## \[Unreleased\]/,/^## \[[0-9]/p' "$PLUGIN_DIR/CHANGELOG.md")"
  [[ "$unreleased" == *"built-in rules"* && "$unreleased" == *".design-theme.json"* ]] \
    || { why="CHANGELOG.md (Unreleased) does not name the built-in rules and .design-theme.json"; return 1; }
  for f in README.md docs/how-it-works.md; do
    grep -qF 'built-in rules' "$PLUGIN_DIR/$f" && grep -qF '.design-theme.json' "$PLUGIN_DIR/$f" \
      || { why="$f does not name the built-in rules and .design-theme.json"; return 1; }
  done
  for f in README.ja.md docs/how-it-works.ja.md; do
    grep -qF '組み込みの規則' "$PLUGIN_DIR/$f" && grep -qF '.design-theme.json' "$PLUGIN_DIR/$f" \
      || { why="$f does not name 組み込みの規則 and .design-theme.json"; return 1; }
  done
}

check "the plugin holds one skill of its name" holds_one_skill
check "the private-name scan lists only general shapes" scan_lists_general_shapes
check "no file holds a home path, a local agent path, or an issue reference" no_local_names
check "the SKILL.md names no agent or its tool" no_agent_names
check "the plugin ships no sample image" ships_no_sample_image
check "the SKILL.md reads samples only when the folder exists" reads_samples_when_present
check "the SKILL.md takes Playwright from the user's project" playwright_from_project
check "the wording check reads the word list from the home folder" reads_home_word_list
check "the wording check reads the passed word list" reads_passed_word_list
check "the wording check flags a slide on the built-in rules without a word list" flags_builtin_without_list
check "the wording check passes a clean slide without a word list" passes_clean_without_list
check "the wording check lists the built-in checks without a word list" lists_builtin_without_list
check "the wording check refuses a passed word list that is missing" refuses_missing_passed_list
check "the wording check reads the terms from the home folder" reads_home_terms
check "the wording check refuses without terms" refuses_without_terms
check "the theme script keeps the deck's look without a theme file" keeps_look_without_theme
check "the theme script reads the home theme file" reads_home_theme
check "the repository theme file wins over the home one" repo_theme_wins
check "the theme script refuses unknown keys and bad values" refuses_bad_theme
check "the SKILL.md applies the theme file to every style" skill_applies_theme
check "the changelog, README, and how-it-works describe the built-in rules and the theme file" docs_describe_changes

printf '\n%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
