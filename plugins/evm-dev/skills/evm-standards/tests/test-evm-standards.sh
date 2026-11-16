#!/usr/bin/env bash
# Tests for evm-standards.sh, the bundled items, the SKILL.md, and the eval suite.
# Item files written here live in a throwaway folder; nothing reaches the network.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
SCRIPT="$SKILL_DIR/scripts/evm-standards.sh"
ITEMS="$SKILL_DIR/references/items"
SKILL="$SKILL_DIR/SKILL.md"
PLUGIN="$(cd "$SKILL_DIR/../.." && pwd)"
EVALS="$PLUGIN/evals"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }

# item <folder> <name> <status> <checked> [source]: writes one item file; an empty source leaves the field out.
item() {
  mkdir -p "$1"
  {
    printf -- '---\nstatus: %s\nchecked: %s\n' "$3" "$4"
    [ -n "${5-x}" ] && printf 'source: %s\n' "${5-The EIP document}"
    printf -- '---\n\n# %s\n\nBody.\n' "$2"
  } > "$1/$2.md"
}

# The bundled items are many; an empty or missing folder must not pass for a clean one.
bundled_check() {
  [ -x "$SCRIPT" ] || return 1
  [ "$(find "$ITEMS" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')" -ge 30 ] || return 1
  bash "$SCRIPT" check > "$T/bundled.out" 2>&1
}
check "check passes on the bundled items" bundled_check

bad_items_named() {
  local d="$T/bad" code
  item "$d" eip-1-good live 2026-01-01
  item "$d" eip-2-nosource live 2026-01-01 ""
  item "$d" erc-3-unknown draft 2026-01-01
  item "$d" erc-4-baddate specified 2026-02-30
  bash "$SCRIPT" check --dir "$d" > "$T/bad.out" 2>&1
  code=$?
  [ "$code" -eq 1 ] || return 1
  grep -q 'eip-2-nosource' "$T/bad.out" && grep -q 'erc-3-unknown' "$T/bad.out" \
    && grep -q 'erc-4-baddate' "$T/bad.out" && ! grep -q 'eip-1-good' "$T/bad.out"
}
check "check names an item with a missing field, an unknown status, or an impossible date" bad_items_named

# On 2026-02-01, an announced item checked 2026-01-01 is 31 days old (past 30), one checked
# 2026-01-02 is exactly 30 days old (not past), a live item checked 2026-01-01 is well within 180,
# a specified item checked 2025-11-05 is 88 days old (within 90), and a stopped item checked
# 2025-08-01 is 184 days old (past 180).
stale_marked() {
  local d="$T/stale"
  item "$d" eip-10-old announced 2026-01-01
  item "$d" eip-11-edge announced 2026-01-02
  item "$d" erc-12-live live 2026-01-01
  item "$d" erc-13-specified specified 2025-11-05
  item "$d" eip-14-stopped stopped 2025-08-01
  bash "$SCRIPT" list --dir "$d" --today 2026-02-01 > "$T/list.out" 2>&1 || return 1
  grep -Eq '^stale +announced +2026-01-01 +eip-10-old$' "$T/list.out" \
    && grep -Eq '^ok +announced +2026-01-02 +eip-11-edge$' "$T/list.out" \
    && grep -Eq '^ok +live +2026-01-01 +erc-12-live$' "$T/list.out" \
    && grep -Eq '^ok +specified +2025-11-05 +erc-13-specified$' "$T/list.out" \
    && grep -Eq '^stale +stopped +2025-08-01 +eip-14-stopped$' "$T/list.out"
}
check "list marks the items past the days for their status" stale_marked

only_erc_eip() {
  local f n=0
  for f in "$ITEMS"/*; do
    [ -e "$f" ] || return 1
    case "$(basename "$f")" in
      erc-*.md | eip-*.md) n=$((n + 1)) ;;
      *) return 1 ;;
    esac
  done
  [ "$n" -ge 30 ]
}
check "every item is an ERC or an EIP" only_erc_eip

no_urls() {
  [ -d "$ITEMS" ] || return 1
  ! grep -rIlE 'https?://|www\.' "$ITEMS" > /dev/null
}
check "no item holds a URL" no_urls

skill_rules() {
  local phrase
  [ -f "$SKILL" ] || return 1
  for phrase in \
    'Run `list` before answering' \
    're-check it against the official ERC or EIP document before you answer' \
    'say that you could not confirm it, with the date the item was checked' \
    'Never edit the items in the plugin'; do
    grep -qF -- "$phrase" "$SKILL" || return 1
  done
}
check "the SKILL.md keeps its rules on stale items and on not editing the items" skill_rules

# The body is counted in words and the description in characters, as the size the agent reads.
SKILL_WORDS_MAX=500
SKILL_DESCRIPTION_MAX=300
skill_size() {
  [ -f "$SKILL" ] || return 1
  python3 - "$SKILL" "$SKILL_WORDS_MAX" "$SKILL_DESCRIPTION_MAX" <<'PYEOF'
import re, sys
front, body = open(sys.argv[1], encoding="utf-8").read().split("---", 2)[1:]
words = len(body.split())
chars = len(re.search(r"^description: (.*)$", front, re.M).group(1))
print("      SKILL.md body %d words (max %s), description %d characters (max %s)" % (words, sys.argv[2], chars, sys.argv[3]))
sys.exit(0 if words <= int(sys.argv[2]) and chars <= int(sys.argv[3]) else 1)
PYEOF
}
check "the SKILL.md stays within its size limits" skill_size

# Each case has a case.yaml and an executable fixture.sh that runs the way claude plugin eval runs it
# (in home/cwd with HOME at home). The knowledge cases grade that the skill fired; the unrelated one
# grades that it did not.
CASES=(eof-status p256-precompile erc-status unrelated-request)
eval_suite() {
  local c home
  for c in "${CASES[@]}"; do
    [ -f "$EVALS/$c/case.yaml" ] && [ -x "$EVALS/$c/fixture.sh" ] || return 1
    home="$T/fixture-$c/home"
    mkdir -p "$home/cwd"
    (cd "$home/cwd" && HOME="$home" bash "$EVALS/$c/fixture.sh") > /dev/null 2>&1 || return 1
    case "$c" in
      unrelated-request) grep -q 'name: skill-not-loaded' "$EVALS/$c/case.yaml" || return 1 ;;
      *) grep -q 'name: skill-fired' "$EVALS/$c/case.yaml" || return 1 ;;
    esac
  done
  git -C "$PLUGIN" check-ignore -q "evals/results/run.json"
}
check "the eval suite has its cases and each fixture builds its state" eval_suite

printf '%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
