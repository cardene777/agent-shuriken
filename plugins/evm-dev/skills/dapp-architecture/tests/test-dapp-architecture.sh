#!/usr/bin/env bash
# Tests for dapp-architecture.py, the bundled items, the template, the checklist, the SKILL.md, and
# the eval suite. Items and designs written here live in a throwaway folder; nothing reaches the
# network.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
SCRIPT="$SKILL_DIR/scripts/dapp-architecture.py"
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
SECTIONS=("Purpose and users" "Components" "Transactions and gas" "Reading chain data" "Data placement" \
  "Environments" "Keys and admin" "Monitoring and operations" "Open decisions")
TOPICS=(indexing transactions automation monitoring networks admin storage)

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
    printf '# Marketplace architecture\n\n'
    for s in "${SECTIONS[@]}"; do
      [ "$s" = "$skip" ] && continue
      printf '## %s\n\n' "$s"
      if [ "$s" = "Components" ]; then
        printf 'A self-hosted indexer and a relayer, checked 2026-11-17. SECRET_TEXT_MARKER\n\n'
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
check "check passes on the bundled items and covers every topic" bundled_check

bad_items_named() {
  local d="$T/bad" code
  item "$d" good-item 'topic: indexing' 'subject: A hosted indexer' 'checked: 2026-11-01' 'source: The vendor, documentation'
  item "$d" no-source 'topic: monitoring' 'subject: A monitor' 'checked: 2026-11-01'
  item "$d" no-subject 'topic: storage' 'checked: 2026-11-01' 'source: The vendor, documentation'
  item "$d" unknown-topic 'topic: wallets' 'subject: A wallet' 'checked: 2026-11-01' 'source: The vendor'
  item "$d" bad-date 'topic: networks' 'subject: A testnet' 'checked: 2026-02-30' 'source: The foundation'
  run check --dir "$d" > "$T/bad.out" 2>&1
  code=$?
  [ "$code" -eq 1 ] || return 1
  grep -q 'no-source' "$T/bad.out" && grep -q 'no-subject' "$T/bad.out" && grep -q 'unknown-topic' "$T/bad.out" \
    && grep -q 'bad-date' "$T/bad.out" && ! grep -q 'good-item' "$T/bad.out"
}
check "check names an item with a missing field, an unknown topic, or an impossible date" bad_items_named

# Counted to 2026-05-01: 2026-01-31 is exactly 90 days old (still ok), 2026-01-30 is 91 (stale).
stale_marked() {
  local d="$T/stale"
  item "$d" edge-item 'topic: automation' 'subject: Keeper network' 'checked: 2026-01-31' 'source: The network, documentation'
  item "$d" old-item 'topic: admin' 'subject: Multisig wallet' 'checked: 2026-01-30' 'source: The wallet, release notes'
  run list --dir "$d" --today 2026-05-01 > "$T/list.out" 2>&1 || return 1
  grep -Eq '^ok +automation +2026-01-31 +edge-item +Keeper network$' "$T/list.out" \
    && grep -Eq '^stale +admin +2026-01-30 +old-item +Multisig wallet$' "$T/list.out" \
    && grep -Eq '^2 items, 1 stale as of 2026-05-01$' "$T/list.out"
}
check "list marks the items checked more than 90 days ago" stale_marked

verify_complete() {
  local f="$T/complete/docs/design/marketplace.md"
  design "$f"
  run verify "$f" > "$T/verify-ok.out" 2>&1 || return 1
  # Other level-two headings may sit between the nine.
  { printf '## Glossary\n\nTerms. SECRET_TEXT_MARKER\n\n'; cat "$f"; } > "$T/complete/extra.md"
  run verify "$T/complete/extra.md" > "$T/verify-extra.out" 2>&1
}
check "verify accepts a complete dApp design" verify_complete

# Each broken design breaks one thing, so a check that misses one of them fails here.
verify_refusals() {
  local d="$T/broken" f
  design "$d/missing.md" "Environments"
  design "$d/misplaced.md"
  python3 - "$d/misplaced.md" <<'PYEOF'
import sys
p = sys.argv[1]
text = open(p, encoding="utf-8").read()
a = text.index("## Transactions and gas")
b = text.index("## Reading chain data")
c = text.index("## Data placement")
open(p, "w", encoding="utf-8").write(text[:a] + text[b:c] + text[a:b] + text[c:])
PYEOF
  design "$d/empty.md"
  python3 - "$d/empty.md" <<'PYEOF'
import sys
p = sys.argv[1]
text = open(p, encoding="utf-8").read()
text = text.replace("## Keys and admin\n\nWhat this part decides. SECRET_TEXT_MARKER\n", "## Keys and admin\n\n<!-- left empty -->\n")
open(p, "w", encoding="utf-8").write(text)
PYEOF
  design "$d/unfinished.md"
  printf 'Fill in: who may pause the contracts.\n' >> "$d/unfinished.md"
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
  grep -Eq '^missing: Environments$' "$T/verify-missing.out" \
    && grep -Eq '^out of order: (Transactions and gas|Reading chain data)$' "$T/verify-misplaced.out" \
    && grep -Eq '^empty: Keys and admin$' "$T/verify-empty.out" \
    && grep -Eq '^unfinished: Open decisions$' "$T/verify-unfinished.out" \
    && grep -Eq '^no checked date: Components$' "$T/verify-undated.out"
}
check "verify names each missing, misplaced, empty, or unfinished dApp section without printing the design's text" verify_refusals

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
check "the dApp template has every section in order" template_sections

verify_template() {
  [ -f "$TEMPLATE" ] && [ -f "$SCRIPT" ] || return 1
  run verify "$TEMPLATE" > "$T/verify-template.out" 2>&1
  [ $? -eq 1 ] && grep -q '^unfinished: ' "$T/verify-template.out"
}
check "verify refuses the unfilled dApp template" verify_template

# ids_design <file> <citing text> <ID>...: a complete design whose first section carries the citing
# text and whose Open decisions section ends with a table that defines the given IDs.
ids_design() {
  local f="$1" cites="$2"
  shift 2
  design "$f"
  python3 - "$f" "$cites" "$@" <<'PYEOF'
import sys
p, cites, ids = sys.argv[1], sys.argv[2], sys.argv[3:]
text = open(p, encoding="utf-8").read().replace("SECRET_TEXT_MARKER", "SECRET_TEXT_MARKER " + cites, 1)
rows = "".join("| %s | A decision. SECRET_TEXT_MARKER |\n" % i for i in ids)
open(p, "w", encoding="utf-8").write(text.rstrip("\n") + "\n\n| ID | Decision |\n|---|---|\n" + rows)
PYEOF
}

# A cited ID is undefined when no row of the Open decisions table starts with it, and D10 is not
# D1. verify names each undefined ID once and never prints the design's text.
verify_undefined_id() {
  local f="$T/ids/undefined.md"
  ids_design "$f" "Rests on D2, D9, and D10." D1 D2
  run verify "$f" > "$T/verify-undefined.out" 2>&1
  [ $? -eq 1 ] || return 1
  ! grep -q 'SECRET_TEXT_MARKER' "$T/verify-undefined.out" || return 1
  grep -Eq '^undefined decision: D9$' "$T/verify-undefined.out" \
    && grep -Eq '^undefined decision: D10$' "$T/verify-undefined.out" \
    && [ "$(grep -c '^undefined decision: ' "$T/verify-undefined.out")" -eq 2 ]
}
check "dapp-architecture verify names a cited Open decisions ID the table does not define" verify_undefined_id

# An ID the table defines but the text never cites is fine, and standard names are not IDs.
verify_uncited_id() {
  local f="$T/ids/uncited.md"
  ids_design "$f" "Rests on D2. ERC-20, EIP-7825, SR2025, and step B3 apply." D1 D2
  run verify "$f" > "$T/verify-uncited.out" 2>&1
}
check "dapp-architecture verify accepts an uncited Open decisions ID and standard names" verify_uncited_id

ponder_018() {
  local f="$ITEMS/ponder.md"
  [ -f "$f" ] || return 1
  ! grep -qF 'versions up to 0.17' "$f" || return 1
  grep -qF '0.18' "$f"
}
check "the dapp-architecture Ponder item names the 0.18 releases" ponder_018

no_urls() {
  [ "$(find "$ITEMS" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')" -ge 7 ] || return 1
  ! grep -rIlE 'https?://|www\.' "$ITEMS" > /dev/null || return 1
  ! grep -rL '^source: .\{8,\}' "$ITEMS" | grep -q .
}
check "no dApp item holds a URL" no_urls

checklist_rules() {
  local phrase
  [ -f "$CHECKLIST" ] || return 1
  for phrase in \
    'personal data' \
    'events are public' \
    'who pays the gas' \
    'relayer key' \
    'admin key' \
    'chain ID' \
    'nonce' \
    'deadline' \
    'indexer or a database' \
    'reorg' \
    'confirmation' \
    'log index' \
    'deployment block' \
    'multisig' \
    'timelock' \
    'pauser' \
    'per environment' \
    'relayer balance' \
    'indexer lag' \
    'content-addressed' \
    'pinned'; do
    grep -qiF -- "$phrase" "$CHECKLIST" || return 1
  done
}
check "the dApp checklist keeps its rules" checklist_rules

skill_rules() {
  local phrase
  [ -f "$SKILL" ] || return 1
  for phrase in \
    'Ask the decisions one at a time' \
    'record it under Open decisions as an assumption' \
    'Run `list`' \
    're-check it against the official document' \
    'use the evm-standards skill' \
    'Run `verify`' \
    'go through `references/checklist.md`' \
    'Do not write contracts, ABIs, API definitions, frontend code, tests, or scripts' \
    'Never read a private key or a mnemonic' \
    'never sign' \
    'refuse a command that passes a key' \
    'Never read `.env` files' \
    'Never edit the items in the plugin'; do
    grep -qF -- "$phrase" "$SKILL" || return 1
  done
}
check "the dApp SKILL.md keeps its rules" skill_rules

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
check "the dApp SKILL.md stays within its size limits" skill_size

# Each case has a case.yaml and an executable fixture.sh that runs the way claude plugin eval runs it
# (in home/cwd with HOME at home). A design case leaves the project's README and grades the design
# file the prompt names; the unrelated case grades that the skill did not start.
CASES=(nft-marketplace-architecture treasury-payouts-architecture architecture-unrelated-request)
eval_suite() {
  local c home
  for c in "${CASES[@]}"; do
    [ -f "$EVALS/$c/case.yaml" ] && [ -x "$EVALS/$c/fixture.sh" ] || return 1
    home="$T/fixture-$c/home"
    mkdir -p "$home/cwd"
    (cd "$home/cwd" && HOME="$home" bash "$EVALS/$c/fixture.sh") > /dev/null 2>&1 || return 1
    if [ "$c" = architecture-unrelated-request ]; then
      grep -q 'name: skill-not-loaded' "$EVALS/$c/case.yaml" && grep -q "input_match: 'dapp-architecture'" "$EVALS/$c/case.yaml" || return 1
      continue
    fi
    grep -q 'name: skill-fired' "$EVALS/$c/case.yaml" && grep -q "input_match: 'dapp-architecture'" "$EVALS/$c/case.yaml" || return 1
    grep -q 'path: docs/design/' "$EVALS/$c/case.yaml" && [ -s "$home/cwd/README.md" ] || return 1
  done
  git -C "$PLUGIN" check-ignore -q "evals/results/run.json"
}
check "the eval suite has its dapp-architecture cases and each fixture builds its state" eval_suite

readmes_list() {
  grep -qF '/evm-dev:dapp-architecture' "$REPO/README.md" && grep -qF '/evm-dev:dapp-architecture' "$REPO/README.ja.md"
}
check "the root READMEs list /evm-dev:dapp-architecture" readmes_list

others_kept() {
  # A test that another skill's test runs skips this check: the outer test runs every other skill's
  # tests once itself, so the same tests are not run again inside each other.
  [ -n "${EVM_DEV_NESTED:-}" ] && return 0
  local EVM_DEV_NESTED=1
  export EVM_DEV_NESTED
  bash "$PLUGIN/skills/evm-standards/scripts/evm-standards.sh" check > "$T/evm-standards.out" 2>&1 \
    && bash "$PLUGIN/skills/solidity-code/tests/test-solidity-code.sh" > "$T/solidity-code.out" 2>&1 \
    && bash "$PLUGIN/skills/financial-standards/tests/test-financial-standards.sh" > "$T/financial-standards.out" 2>&1 \
    && bash "$PLUGIN/skills/contract-tests/tests/test-contract-tests.sh" > "$T/contract-tests.out" 2>&1
}
check "the other evm-dev skills still pass their tests with dapp-architecture" others_kept

printf '%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
