#!/usr/bin/env bash
# Tests for the chainome-diagram plugin: which skill it holds, what no file in it names, and what
# its SKILL.md says about asking the user. Nothing is written outside a throwaway folder.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
PLUGIN_DIR="$(cd "$HERE/../../.." && pwd)"
NAME=chainome-diagram
SKILL="$SKILL_DIR/SKILL.md"
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

# need <file>...: every file exists.
need() {
  local f
  for f in "$@"; do
    [ -f "$f" ] || { why="$f is missing"; return 1; }
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

check "the plugin holds one skill of its name" holds_one_skill
check "no file names the author's PC, products, or other repositories" no_local_names
check "the SKILL.md names no agent or its tool" no_agent_names

printf '\n%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
