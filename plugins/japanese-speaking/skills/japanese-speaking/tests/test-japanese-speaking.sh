#!/usr/bin/env bash
# Tests for the japanese-speaking skill: the speaking.py check command on the fixtures, and the order
# of the steps in SKILL.md. Everything runs on the fixtures next to this file and a throwaway folder.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
SCRIPT="$SKILL_DIR/scripts/speaking.py"
FIX="$HERE/fixtures"
PY="$(command -v python3)"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }
speaking() { PYTHONDONTWRITEBYTECODE=1 "$PY" "$SCRIPT" "$@"; }

# Runs check on a fixture and keeps the output and the exit status in $T.
run() {  # <name> <args>...
  local name="$1"
  shift
  speaking check "$@" >"$T/$name.out" 2>"$T/$name.err"
  printf '%s' "$?" >"$T/$name.status"
}
status_is() { [ "$(cat "$T/$1.status")" = "$2" ]; }
has() { grep -qE "$2" "$T/$1.out"; }
lacks() { ! grep -qE "$2" "$T/$1.out"; }

# --- check: JSON scripts

reports_patterns() {
  run rejected "$FIX/rejected-2026-11-18.json"
  status_is rejected 1 || return 1
  grep -E '^L[0-9]+ ' "$T/rejected.out" | grep -qvE '^L[0-9]+ [a-z-]+ .+$' && return 1
  has rejected '^L6 casual-contraction ' || return 1
  has rejected '^L10 casual-contraction '
}
check "check reports each pattern with its line number in a JSON script" "reports_patterns"

reads_plain_text() {
  run plain "$FIX/plain.txt"
  status_is plain 1 || return 1
  has plain '^L4 clipped-question ' || return 1
  has plain '^L5 particle-ending ' || return 1
  lacks plain '^L[123] '
}
check "check reads a plain text script with and without speaker names" "reads_plain_text"

finds_rejected_patterns() {
  run rejected2 "$FIX/rejected-2026-11-18.json"
  has rejected2 '^L8 quiz-question ' || return 1
  has rejected2 '^L3 particle-ending ' || return 1
  has rejected2 '^L3 clipped-question '
}
check "check finds the three patterns in the rejected 2026-11-18 drafts" "finds_rejected_patterns"

finds_casual_and_written() {
  run casual "$FIX/casual.json"
  status_is casual 1 || return 1
  local n
  for n in 1 2 3; do has casual "^L$n casual-contraction " || return 1; done
  for n in 4 5 6 7; do has casual "^L$n written-style " || return 1; done
  ! has casual "^L8 "
}
check "check finds casual contractions and written-style phrases" "finds_casual_and_written"

finds_sources() {
  run sources "$FIX/sources.json"
  status_is sources 1 || return 1
  has sources '^L1 unhedged-source ' || return 1
  has sources '^L2 vague-source ' || return 1
  has sources '^L3 vague-source ' || return 1
  lacks sources '^L2 unhedged-source ' || return 1
  lacks sources '^L4 '
}
check "check finds unhedged and vague sources" "finds_sources"

# --- check: notes and a clean script

prints_notes() {
  run notes "$FIX/notes.json"
  status_is notes 0 || return 1
  lacks notes '^L[0-9]+ ' || return 1
  has notes '^note repeated-ending L1-L3 ' || return 1
  has notes '^note long-sentence L2 ' || return 1
  run natural_notes "$FIX/natural.json"
  local name
  for name in utterance-length-median utterance-length-cv short-utterance-ratio backchannel-count ne-yo-ratio; do
    has natural_notes "^note $name " || return 1
  done
}
check "check prints script-level notes without failing" "prints_notes"

passes_natural() {
  run natural "$FIX/natural.json"
  status_is natural 0 || return 1
  lacks natural '^L[0-9]+ '
}
check "check passes a natural spoken script" "passes_natural"

# --- check: --source

lists_absent_names() {
  run sourced "$FIX/sourced.json" --source "$FIX/source.md"
  status_is sourced 1 || return 1
  has sourced '^L3 not-in-source CrewAI$' || return 1
  has sourced '^L3 not-in-source 15$' || return 1
  has sourced '^L4 not-in-source ミストラル$' || return 1
  lacks sourced 'not-in-source (LangGraph|ラングチェーン|オワスプ|12|モデル|チーム)$' || return 1
  lacks sourced '^L[12] '
}
check "check lists numbers and names absent from the source" "lists_absent_names"

# --- check: input it cannot read

rejects_bad_input() {
  local name
  for name in missing broken no-lines no-text; do
    case "$name" in
      missing) run "$name" "$T/missing.json" ;;
      broken) run "$name" "$FIX/broken.txt" ;;
      *) run "$name" "$FIX/$name.json" ;;
    esac
    status_is "$name" 2 || return 1
    [ ! -s "$T/$name.out" ] || return 1
    [ "$(wc -l <"$T/$name.err" | tr -d ' ')" = 1 ] || return 1
    grep -qE '^error: .+' "$T/$name.err" || return 1
  done
}
check "check rejects unreadable input with exit 2" "rejects_bad_input"

# --- SKILL.md

skill_order() {
  [ -f "$SKILL_DIR/SKILL.md" ] || return 1
  "$PY" - "$SKILL_DIR/SKILL.md" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
order = ["## 3. Write", "## 4. Check with the script", "## 5. Have a fresh reader listen", "## 6. Fix and check again"]
at = [text.find(h) for h in order]
if -1 in at or at != sorted(at):
    sys.exit(1)
if "Add no fact, number, or name that the material does not have" not in text:
    sys.exit(1)
if "speaking.py\" check" not in text and "speaking.py check" not in text:
    sys.exit(1)
PY
}
check "SKILL.md orders write, check, fresh review, and fix and forbids new facts" "skill_order"

printf '\n%d passed, %d failed, 0 skipped (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" = 0 ]
