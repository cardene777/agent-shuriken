#!/usr/bin/env bash
# Tests for wallet-design.py, the bundled items, the template, the checklist, the SKILL.md, and the
# eval suite. Items and designs written here live in a throwaway folder; nothing reaches the network.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
SCRIPT="$SKILL_DIR/scripts/wallet-design.py"
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
SECTIONS=("Purpose and users" "Accounts" "Keys and recovery" "Signatures and permissions" "Approvals" \
  "Gas and sponsorship" "Agent payments" "Chains and environments" "Open decisions")
TOPICS=(accounts signatures approvals gas payments)

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
    printf '# Wallet design\n\n'
    for s in "${SECTIONS[@]}"; do
      [ "$s" = "$skip" ] && continue
      printf '## %s\n\n' "$s"
      if [ "$s" = "Accounts" ]; then
        printf 'EIP-7702 delegation to an audited account on EntryPoint v0.8, checked 2026-11-17. SECRET_TEXT_MARKER\n\n'
      else
        printf 'What this part decides. SECRET_TEXT_MARKER\n\n'
      fi
    done
  } > "$f"
}

# The bundled items are few; an empty or missing folder must not pass for a clean one, and every
# topic the skill names needs at least one item.
bundled_check() {
  local t
  [ -f "$SCRIPT" ] || return 1
  run check > "$T/bundled.out" 2>&1 || return 1
  for t in "${TOPICS[@]}"; do
    grep -rqx "topic: $t" "$ITEMS" || return 1
  done
}
check "check passes on the bundled wallet-design items and covers every topic" bundled_check

bad_items_named() {
  local d="$T/bad" code
  item "$d" good-item 'topic: gas' 'subject: A paymaster service' 'checked: 2026-11-01' 'source: The vendor, documentation'
  item "$d" no-source 'topic: payments' 'subject: A payment protocol' 'checked: 2026-11-01'
  item "$d" no-subject 'topic: approvals' 'checked: 2026-11-01' 'source: The vendor, documentation'
  item "$d" unknown-topic 'topic: indexing' 'subject: An indexer' 'checked: 2026-11-01' 'source: The vendor'
  item "$d" bad-date 'topic: accounts' 'subject: An account contract' 'checked: 2026-02-30' 'source: The team, release notes'
  run check --dir "$d" > "$T/bad.out" 2>&1
  code=$?
  [ "$code" -eq 1 ] || return 1
  grep -q 'no-source' "$T/bad.out" && grep -q 'no-subject' "$T/bad.out" && grep -q 'unknown-topic' "$T/bad.out" \
    && grep -q 'bad-date' "$T/bad.out" && ! grep -q 'good-item' "$T/bad.out"
}
check "check names a wallet-design item with a missing field, an unknown topic, or an impossible date" bad_items_named

# Counted to 2026-05-01: 2026-01-31 is exactly 90 days old (still ok), 2026-01-30 is 91 (stale).
stale_marked() {
  local d="$T/stale"
  item "$d" edge-item 'topic: signatures' 'subject: Permission API' 'checked: 2026-01-31' 'source: The wallet, documentation'
  item "$d" old-item 'topic: accounts' 'subject: EntryPoint' 'checked: 2026-01-30' 'source: The team, release notes'
  run list --dir "$d" --today 2026-05-01 > "$T/list.out" 2>&1 || return 1
  grep -Eq '^ok +signatures +2026-01-31 +edge-item +Permission API$' "$T/list.out" \
    && grep -Eq '^stale +accounts +2026-01-30 +old-item +EntryPoint$' "$T/list.out" \
    && grep -Eq '^2 items, 1 stale as of 2026-05-01$' "$T/list.out"
}
check "list marks the wallet-design items checked more than 90 days ago" stale_marked

verify_complete() {
  local f="$T/complete/docs/design/wallet.md"
  design "$f"
  run verify "$f" > "$T/verify-ok.out" 2>&1 || return 1
  # Other level-two headings may sit between the nine.
  { printf '## Glossary\n\nTerms. SECRET_TEXT_MARKER\n\n'; cat "$f"; } > "$T/complete/extra.md"
  run verify "$T/complete/extra.md" > "$T/verify-extra.out" 2>&1
}
check "verify accepts a complete wallet design" verify_complete

# Each broken design breaks one thing, so a check that misses one of them fails here.
verify_refusals() {
  local d="$T/broken" f
  design "$d/missing.md" "Approvals"
  design "$d/misplaced.md"
  python3 - "$d/misplaced.md" <<'PYEOF'
import sys
p = sys.argv[1]
text = open(p, encoding="utf-8").read()
a = text.index("## Keys and recovery")
b = text.index("## Signatures and permissions")
c = text.index("## Approvals")
open(p, "w", encoding="utf-8").write(text[:a] + text[b:c] + text[a:b] + text[c:])
PYEOF
  design "$d/empty.md"
  python3 - "$d/empty.md" <<'PYEOF'
import sys
p = sys.argv[1]
text = open(p, encoding="utf-8").read()
text = text.replace("## Chains and environments\n\nWhat this part decides. SECRET_TEXT_MARKER\n", "## Chains and environments\n\n<!-- left empty -->\n")
open(p, "w", encoding="utf-8").write(text)
PYEOF
  design "$d/unfinished.md"
  printf 'Fill in: who may change the spending limit.\n' >> "$d/unfinished.md"
  design "$d/undated.md"
  python3 - "$d/undated.md" <<'PYEOF'
import sys
p = sys.argv[1]
text = open(p, encoding="utf-8").read().replace(", checked 2026-11-17", "")
open(p, "w", encoding="utf-8").write(text)
PYEOF
  for f in missing misplaced empty unfinished undated; do
    run verify "$d/$f.md" > "$T/verify-$f.out" 2>&1
    [ $? -eq 1 ] || return 1
    ! grep -q 'SECRET_TEXT_MARKER' "$T/verify-$f.out" || return 1
  done
  grep -Eq '^missing: Approvals$' "$T/verify-missing.out" \
    && grep -Eq '^out of order: (Keys and recovery|Signatures and permissions)$' "$T/verify-misplaced.out" \
    && grep -Eq '^empty: Chains and environments$' "$T/verify-empty.out" \
    && grep -Eq '^unfinished: Open decisions$' "$T/verify-unfinished.out" \
    && grep -Eq '^no checked date: Accounts$' "$T/verify-undated.out"
}
check "verify names each missing, misplaced, empty, or unfinished wallet-design section without printing the design's text" verify_refusals

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
check "the wallet-design template has every section in order" template_sections

verify_template() {
  [ -f "$TEMPLATE" ] && [ -f "$SCRIPT" ] || return 1
  run verify "$TEMPLATE" > "$T/verify-template.out" 2>&1
  [ $? -eq 1 ] && grep -q '^unfinished: ' "$T/verify-template.out"
}
check "verify refuses the unfilled wallet-design template" verify_template

no_urls() {
  [ "$(find "$ITEMS" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')" -ge 5 ] || return 1
  ! grep -rIlE 'https?://|www\.' "$ITEMS" > /dev/null || return 1
  ! grep -rL '^source: .\{8,\}' "$ITEMS" | grep -q .
}
check "no wallet-design item holds a URL" no_urls

checklist_rules() {
  local phrase
  [ -f "$CHECKLIST" ] || return 1
  for phrase in \
    '.env' \
    'environment variable' \
    'recovery' \
    'rotat' \
    'EIP-712' \
    'chain ID' \
    'nonce' \
    'deadline' \
    'ERC-1271' \
    'ERC-6492' \
    'session key' \
    'expir' \
    'unlimited' \
    'revoke' \
    'EntryPoint' \
    'delegat' \
    'initializ' \
    'storage' \
    'paymaster' \
    'spending limit' \
    'payee' \
    'phishing'; do
    grep -qiF -- "$phrase" "$CHECKLIST" || return 1
  done
}
check "the wallet-design checklist keeps its rules" checklist_rules

skill_rules() {
  local phrase
  [ -f "$SKILL" ] || return 1
  for phrase in \
    'Ask the decisions one at a time' \
    'record it under Open decisions as an assumption' \
    'Run `list`' \
    're-check it against the official document' \
    'use the evm-standards skill' \
    'the items of the dapp-architecture skill' \
    'Run `verify`' \
    'go through `references/checklist.md`' \
    'Do not write Solidity, tests, or deployment scripts' \
    'the solidity-code skill' \
    'Never read a private key or a mnemonic' \
    'never sign' \
    'refuse a command that passes a key' \
    'Never read `.env` files' \
    'Never edit the items in the plugin'; do
    grep -qF -- "$phrase" "$SKILL" || return 1
  done
}
check "the wallet-design SKILL.md keeps its rules" skill_rules

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
check "the wallet-design SKILL.md stays within its size limits" skill_size

# Each case has a case.yaml and an executable fixture.sh that runs the way claude plugin eval runs it
# (in home/cwd with HOME at home). A design case leaves the project's README and grades the design
# file the prompt names; the unrelated case grades that the skill did not start.
CASES=(smart-account-choice agent-payments-wallet wallet-design-unrelated-request)
eval_suite() {
  local c home
  for c in "${CASES[@]}"; do
    [ -f "$EVALS/$c/case.yaml" ] && [ -x "$EVALS/$c/fixture.sh" ] || return 1
    home="$T/fixture-$c/home"
    mkdir -p "$home/cwd"
    (cd "$home/cwd" && HOME="$home" bash "$EVALS/$c/fixture.sh") > /dev/null 2>&1 || return 1
    if [ "$c" = wallet-design-unrelated-request ]; then
      grep -q 'name: skill-not-loaded' "$EVALS/$c/case.yaml" && grep -q "input_match: 'wallet-design'" "$EVALS/$c/case.yaml" || return 1
      continue
    fi
    grep -q 'name: skill-fired' "$EVALS/$c/case.yaml" && grep -q "input_match: 'wallet-design'" "$EVALS/$c/case.yaml" || return 1
    grep -q 'path: docs/design/' "$EVALS/$c/case.yaml" && [ -s "$home/cwd/README.md" ] || return 1
  done
  git -C "$PLUGIN" check-ignore -q "evals/results/run.json"
}
check "the eval suite has its wallet-design cases and each fixture builds its state" eval_suite

readmes_list() {
  grep -qF '/evm-dev:wallet-design' "$REPO/README.md" && grep -qF '/evm-dev:wallet-design' "$REPO/README.ja.md"
}
check "the root READMEs list /evm-dev:wallet-design" readmes_list

others_kept() {
  # A test that another skill's test runs skips this check: the outer test runs every other skill's
  # tests once itself, so the same tests are not run again inside each other.
  [ -n "${EVM_DEV_NESTED:-}" ] && return 0
  local EVM_DEV_NESTED=1
  export EVM_DEV_NESTED
  bash "$PLUGIN/skills/evm-standards/scripts/evm-standards.sh" check > "$T/evm-standards.out" 2>&1 \
    && bash "$PLUGIN/skills/solidity-code/tests/test-solidity-code.sh" > "$T/solidity-code.out" 2>&1 \
    && bash "$PLUGIN/skills/financial-standards/tests/test-financial-standards.sh" > "$T/financial-standards.out" 2>&1 \
    && bash "$PLUGIN/skills/contract-tests/tests/test-contract-tests.sh" > "$T/contract-tests.out" 2>&1 \
    && bash "$PLUGIN/skills/contract-design/tests/test-contract-design.sh" > "$T/contract-design.out" 2>&1 \
    && bash "$PLUGIN/skills/dapp-architecture/tests/test-dapp-architecture.sh" > "$T/dapp-architecture.out" 2>&1
}
check "the other evm-dev skills still pass their tests with wallet-design" others_kept

printf '%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
