#!/usr/bin/env bash
# Tests for financial-standards.py, the bundled items, the template, the checklist, the SKILL.md,
# and the eval suite. Items and designs written here live in a throwaway folder; nothing reaches
# the network.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
SCRIPT="$SKILL_DIR/scripts/financial-standards.py"
ITEMS="$SKILL_DIR/references/items"
CHECKLIST="$SKILL_DIR/references/checklist.md"
TEMPLATE="$SKILL_DIR/templates/design.md"
SKILL="$SKILL_DIR/SKILL.md"
PLUGIN="$(cd "$SKILL_DIR/../.." && pwd)"
REPO="$(cd "$PLUGIN/../.." && pwd)"
EVALS="$PLUGIN/evals"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }

run() { python3 "$SCRIPT" "$@"; }

# The nine sections a design holds, in the order verify wants them.
SECTIONS=("Standard and business" "Application" "Data and storage" "On-chain" "Off-chain" \
  "Integration" "Security and operations" "Verification and delivery" "Open decisions")

# item <folder> <name> <field lines...>: writes one item file with the given front matter lines.
item() {
  local d="$1" name="$2" line
  shift 2
  mkdir -p "$d"
  {
    printf -- '---\n'
    for line in "$@"; do printf '%s\n' "$line"; done
    printf -- '---\n\n# %s\n\nBody.\n' "$name"
  } > "$d/$name.md"
}

# design <file> [<section to leave out>]: writes a complete design, with one body line per section
# that carries SECRET_TEXT_MARKER, so a check can tell whether verify printed the design's text.
design() {
  local f="$1" skip="${2:-}" s
  mkdir -p "$(dirname "$f")"
  {
    printf '# Payments settlement design\n\n'
    for s in "${SECTIONS[@]}"; do
      [ "$s" = "$skip" ] && continue
      printf '## %s\n\n' "$s"
      if [ "$s" = "Standard and business" ]; then
        printf 'ISO 20022 CBPR+ SR2025, checked 2026-11-16. SECRET_TEXT_MARKER\n\n'
      else
        printf 'What this part decides. SECRET_TEXT_MARKER\n\n'
      fi
    done
  } > "$f"
}

# The bundled items are few; an empty or missing folder must not pass for a clean one, and every
# standard the skill names needs at least one item.
bundled_check() {
  local s
  [ -f "$SCRIPT" ] || return 1
  run check > "$T/bundled.out" 2>&1 || return 1
  for s in iso-20022 fix fpml cdm lei xbrl; do
    grep -rqx "standard: $s" "$ITEMS" || return 1
  done
}
check "check passes on the bundled items and covers every standard" bundled_check

bad_items_named() {
  local d="$T/bad" code
  item "$d" good-item 'standard: iso-20022' 'version: SR2025' 'checked: 2026-11-01' 'source: Swift, Standards MX release notes'
  item "$d" no-source 'standard: fix' 'version: FIX Latest' 'checked: 2026-11-01'
  item "$d" no-version 'standard: lei' 'checked: 2026-11-01' 'source: GLEIF, LEI data'
  item "$d" unknown-standard 'standard: swift-mt' 'version: SR2025' 'checked: 2026-11-01' 'source: Swift'
  item "$d" bad-date 'standard: xbrl' 'version: 2.1' 'checked: 2026-02-30' 'source: XBRL International'
  run check --dir "$d" > "$T/bad.out" 2>&1
  code=$?
  [ "$code" -eq 1 ] || return 1
  grep -q 'no-source' "$T/bad.out" && grep -q 'no-version' "$T/bad.out" && grep -q 'unknown-standard' "$T/bad.out" \
    && grep -q 'bad-date' "$T/bad.out" && ! grep -q 'good-item' "$T/bad.out"
}
check "check names an item with a missing field, an unknown standard, or an impossible date" bad_items_named

# Counted to 2026-05-01: 2025-11-02 is exactly 180 days old (still ok), 2025-11-01 is 181 (stale).
stale_marked() {
  local d="$T/stale"
  item "$d" edge-item 'standard: fpml' 'version: 5.13' 'checked: 2025-11-02' 'source: FpML, specification'
  item "$d" old-item 'standard: cdm' 'version: 6.0' 'checked: 2025-11-01' 'source: FINOS, CDM release notes'
  run list --dir "$d" --today 2026-05-01 > "$T/list.out" 2>&1 || return 1
  grep -Eq '^ok +fpml +5\.13 +2025-11-02 +edge-item$' "$T/list.out" \
    && grep -Eq '^stale +cdm +6\.0 +2025-11-01 +old-item$' "$T/list.out" \
    && grep -Eq '^2 items, 1 stale as of 2026-05-01$' "$T/list.out"
}
check "list marks the items checked more than 180 days ago" stale_marked

verify_complete() {
  local f="$T/complete/docs/design/payments.md"
  design "$f"
  run verify "$f" > "$T/verify-ok.out" 2>&1 || return 1
  # Other level-two headings may sit between the nine.
  { printf '## Glossary\n\nTerms. SECRET_TEXT_MARKER\n\n'; cat "$f"; } > "$T/complete/extra.md"
  run verify "$T/complete/extra.md" > "$T/verify-extra.out" 2>&1
}
check "verify accepts a complete design" verify_complete

# Each broken design breaks one thing, so a check that misses one of them fails here.
verify_refusals() {
  local d="$T/broken" f
  design "$d/missing.md" "Integration"
  design "$d/misplaced.md"
  python3 - "$d/misplaced.md" <<'PYEOF'
import sys
p = sys.argv[1]
text = open(p, encoding="utf-8").read()
a = text.index("## On-chain")
b = text.index("## Off-chain")
c = text.index("## Integration")
open(p, "w", encoding="utf-8").write(text[:a] + text[b:c] + text[a:b] + text[c:])
PYEOF
  design "$d/empty.md"
  python3 - "$d/empty.md" <<'PYEOF'
import sys
p = sys.argv[1]
text = open(p, encoding="utf-8").read()
text = text.replace("## Application\n\nWhat this part decides. SECRET_TEXT_MARKER\n", "## Application\n\n<!-- left empty -->\n")
open(p, "w", encoding="utf-8").write(text)
PYEOF
  design "$d/unfinished.md"
  printf 'Fill in: who may read the evidence.\n' >> "$d/unfinished.md"
  design "$d/undated.md"
  python3 - "$d/undated.md" <<'PYEOF'
import sys
p = sys.argv[1]
text = open(p, encoding="utf-8").read().replace(", checked 2026-11-16", "")
open(p, "w", encoding="utf-8").write(text)
PYEOF
  for f in missing misplaced empty unfinished undated; do
    run verify "$d/$f.md" > "$T/verify-$f.out" 2>&1
    [ $? -eq 1 ] || return 1
    ! grep -q 'SECRET_TEXT_MARKER' "$T/verify-$f.out" || return 1
  done
  grep -Eq '^missing: Integration$' "$T/verify-missing.out" \
    && grep -Eq '^out of order: (On-chain|Off-chain)$' "$T/verify-misplaced.out" \
    && grep -Eq '^empty: Application$' "$T/verify-empty.out" \
    && grep -Eq '^unfinished: Open decisions$' "$T/verify-unfinished.out" \
    && grep -Eq '^no checked date: Standard and business$' "$T/verify-undated.out"
}
check "verify names each missing, misplaced, empty, or unfinished section without printing the design's text" verify_refusals

template_sections() {
  local s n=0 got
  [ -f "$TEMPLATE" ] || return 1
  got="$(grep -E '^## ' "$TEMPLATE" | sed 's/^## //')"
  for s in "${SECTIONS[@]}"; do
    n=$((n + 1))
    [ "$(printf '%s\n' "$got" | sed -n "${n}p")" = "$s" ] || return 1
  done
  [ "$(printf '%s\n' "$got" | wc -l | tr -d ' ')" -eq 9 ]
}
check "the template has every section in order" template_sections

verify_template() {
  [ -f "$TEMPLATE" ] && [ -f "$SCRIPT" ] || return 1
  run verify "$TEMPLATE" > "$T/verify-template.out" 2>&1
  [ $? -eq 1 ] && grep -q '^unfinished: ' "$T/verify-template.out"
}
check "verify refuses the unfilled template" verify_template

no_urls() {
  [ "$(find "$ITEMS" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')" -ge 6 ] || return 1
  ! grep -rIlE 'https?://|www\.' "$ITEMS" > /dev/null || return 1
  ! grep -rL '^source: .\{8,\}' "$ITEMS" | grep -q .
}
check "no item holds a URL" no_urls

checklist_rules() {
  local phrase
  [ -f "$CHECKLIST" ] || return 1
  for phrase in \
    'original message' \
    'free-text remittance information' \
    'salt' \
    'domain' \
    'does not parse XML' \
    'external message ID alone' \
    'not settlement finality' \
    'legal finality' \
    'revocation' \
    'append' \
    'version and profile' \
    'off-chain responsibilities' \
    'nonce' \
    'expiry' \
    'replay' \
    'idempotent' \
    'reconcil'; do
    grep -qiF -- "$phrase" "$CHECKLIST" || return 1
  done
}
check "the checklist keeps the always-fail rules" checklist_rules

skill_rules() {
  local phrase
  [ -f "$SKILL" ] || return 1
  for phrase in \
    'Ask the decisions one at a time' \
    'record it under Open decisions as an assumption' \
    'Run `list`' \
    're-check it against the official document' \
    'use the evm-standards skill' \
    'Never put the original message, names, addresses, account numbers, or free-text remittance information on chain' \
    'The contract accepts only signed evidence' \
    'Run `verify`' \
    'go through `references/checklist.md`' \
    'Do not write contracts, schemas, ABIs, API definitions, tests, or scripts' \
    'Never read a private key or a mnemonic' \
    'never sign' \
    'refuse a command that passes a key' \
    'Never edit the items in the plugin'; do
    grep -qF -- "$phrase" "$SKILL" || return 1
  done
}
check "the SKILL.md keeps its rules" skill_rules

# The body is counted in words and the description in characters, as the size the agent reads.
SKILL_WORDS_MAX=600
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
# (in home/cwd with HOME at home). A design case leaves the project's README and grades the design
# file the prompt names; the unrelated case grades that the skill did not start.
CASES=(iso20022-settlement fix-trade-evidence standards-unrelated-request)
eval_suite() {
  local c home
  for c in "${CASES[@]}"; do
    [ -f "$EVALS/$c/case.yaml" ] && [ -x "$EVALS/$c/fixture.sh" ] || return 1
    home="$T/fixture-$c/home"
    mkdir -p "$home/cwd"
    (cd "$home/cwd" && HOME="$home" bash "$EVALS/$c/fixture.sh") > /dev/null 2>&1 || return 1
    if [ "$c" = standards-unrelated-request ]; then
      grep -q 'name: skill-not-loaded' "$EVALS/$c/case.yaml" && grep -q "input_match: 'financial-standards'" "$EVALS/$c/case.yaml" || return 1
      continue
    fi
    grep -q 'name: skill-fired' "$EVALS/$c/case.yaml" && grep -q "input_match: 'financial-standards'" "$EVALS/$c/case.yaml" || return 1
    grep -q 'path: docs/design/' "$EVALS/$c/case.yaml" && [ -s "$home/cwd/README.md" ] || return 1
  done
  git -C "$PLUGIN" check-ignore -q "evals/results/run.json"
}
check "the eval suite has its financial-standards cases and each fixture builds its state" eval_suite

readmes_list() {
  grep -qF '/evm-dev:financial-standards' "$REPO/README.md" && grep -qF '/evm-dev:financial-standards' "$REPO/README.ja.md"
}
check "the root READMEs list /evm-dev:financial-standards" readmes_list

others_kept() {
  # A test that another skill's test runs skips this check: the outer test runs every other skill's
  # tests once itself, so the same tests are not run again inside each other.
  [ -n "${EVM_DEV_NESTED:-}" ] && return 0
  local EVM_DEV_NESTED=1
  export EVM_DEV_NESTED
  bash "$PLUGIN/skills/evm-standards/scripts/evm-standards.sh" check > "$T/evm-standards.out" 2>&1 \
    && bash "$PLUGIN/skills/solidity-code/tests/test-solidity-code.sh" > "$T/solidity-code.out" 2>&1
}
check "the other evm-dev skills still pass their tests" others_kept

printf '%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
