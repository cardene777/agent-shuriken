#!/usr/bin/env bash
# Tests for the product-deck plugin: which skill it holds, what no file in it names, that it ships no
# sample image, where its SKILL.md takes samples and Playwright from, and which word lists
# scripts/audit-text.mjs reads. Every HOME and deck the tests use is a throwaway folder.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
PLUGIN_DIR="$(cd "$HERE/../../.." && pwd)"
NAME=product-deck
SKILL="$SKILL_DIR/SKILL.md"
AUDIT_TEXT="$SKILL_DIR/scripts/audit-text.mjs"
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

no_local_names() {
  need "$SKILL" || return 1
  local hits
  # The scan catches a planted line, so an empty result means the words are absent.
  mkdir -p "$T/control"
  printf 'see %s and %s\n' "G""H #12" "~/.co""dex/config" > "$T/control/planted.md"
  [ "$(names_of_this_pc "$T/control" | grep -c .)" = 1 ] || { why="the scan misses a planted line"; return 1; }
  hits="$(names_of_this_pc "$PLUGIN_DIR")"
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

refuses_without_word_list() {
  need "$AUDIT_TEXT" || return 1
  deck "$T/no-list/deck" "This slide utilizes the record."
  mkdir -p "$T/no-list/home"
  run env HOME="$T/no-list/home" node "$AUDIT_TEXT" "$T/no-list/deck/deck-data.mjs" --terms "$T/no-list/deck/terms.txt"
  [ "$status" -eq 2 ] || { why="without a word list it exited $status, not 2: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)"; return 1; }
  [[ "$out" == *"~/.product-deck/prose-words.txt"* ]] || { why="the refusal does not name ~/.product-deck/prose-words.txt: $out"; return 1; }
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

check "the plugin holds one skill of its name" holds_one_skill
check "no file names the author's PC, products, or other repositories" no_local_names
check "the SKILL.md names no agent or its tool" no_agent_names
check "the plugin ships no sample image" ships_no_sample_image
check "the SKILL.md reads samples only when the folder exists" reads_samples_when_present
check "the SKILL.md takes Playwright from the user's project" playwright_from_project
check "the wording check reads the word list from the home folder" reads_home_word_list
check "the wording check reads the passed word list" reads_passed_word_list
check "the wording check refuses without a word list" refuses_without_word_list
check "the wording check reads the terms from the home folder" reads_home_terms
check "the wording check refuses without terms" refuses_without_terms

printf '\n%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
