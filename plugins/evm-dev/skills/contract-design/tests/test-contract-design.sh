#!/usr/bin/env bash
# Tests for contract-design.py, the bundled items, the template, the checklist, the SKILL.md, and
# the eval suite. Items and designs written here live in a throwaway folder; nothing reaches the
# network.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
SCRIPT="$SKILL_DIR/scripts/contract-design.py"
ITEMS="$SKILL_DIR/references/items"
CHECKLIST="$SKILL_DIR/references/checklist.md"
SECTIONS_FILE="$SKILL_DIR/templates/sections.md"
DECLARATION="$SKILL_DIR/musubi.json"
SKILL="$SKILL_DIR/SKILL.md"
PLUGIN="$(cd "$SKILL_DIR/../.." && pwd)"
REPO="$(cd "$PLUGIN/../.." && pwd)"
EVALS="$PLUGIN/evals"
DESIGN_DOC="$REPO/plugins/doc-formats/skills/design-doc"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }

run() { python3 "$SCRIPT" "$@"; }

# The eight sections of this skill, in the order of templates/sections.md. Open decisions comes from
# the design format of design-doc, and verify wants it last.
OWN=("Purpose and scope" "Contracts" "Token standards" "State and invariants" "Roles and governance" "Upgrades" "Prices, ordering, and randomness" "External calls and failures")
DATED="Contracts"
TOPICS=(upgrades access oracles randomness ordering tokens)

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
check "check passes on the bundled contract-design items and covers every topic" bundled_check

bad_items_named() {
  local d="$T/bad" code
  item "$d" good-item 'topic: oracles' 'subject: A price feed' 'checked: 2026-11-01' 'source: The vendor, documentation'
  item "$d" no-source 'topic: randomness' 'subject: A randomness service' 'checked: 2026-11-01'
  item "$d" no-subject 'topic: tokens' 'checked: 2026-11-01' 'source: The vendor, documentation'
  item "$d" unknown-topic 'topic: indexing' 'subject: An indexer' 'checked: 2026-11-01' 'source: The vendor'
  item "$d" bad-date 'topic: access' 'subject: A role library' 'checked: 2026-02-30' 'source: The library, documentation'
  run check --dir "$d" > "$T/bad.out" 2>&1
  code=$?
  [ "$code" -eq 1 ] || return 1
  grep -q 'no-source' "$T/bad.out" && grep -q 'no-subject' "$T/bad.out" && grep -q 'unknown-topic' "$T/bad.out" \
    && grep -q 'bad-date' "$T/bad.out" && ! grep -q 'good-item' "$T/bad.out"
}
check "check names a contract-design item with a missing field, an unknown topic, or an impossible date" bad_items_named

# Counted to 2026-05-01: 2026-01-31 is exactly 90 days old (still ok), 2026-01-30 is 91 (stale).
stale_marked() {
  local d="$T/stale"
  item "$d" edge-item 'topic: ordering' 'subject: Private mempool' 'checked: 2026-01-31' 'source: The relay, documentation'
  item "$d" old-item 'topic: upgrades' 'subject: Proxy library' 'checked: 2026-01-30' 'source: The library, release notes'
  run list --dir "$d" --today 2026-05-01 > "$T/list.out" 2>&1 || return 1
  grep -Eq '^ok +ordering +2026-01-31 +edge-item +Private mempool$' "$T/list.out" \
    && grep -Eq '^stale +upgrades +2026-01-30 +old-item +Proxy library$' "$T/list.out" \
    && grep -Eq '^2 items, 1 stale as of 2026-05-01$' "$T/list.out"
}
check "list marks the contract-design items checked more than 90 days ago" stale_marked

# The execution delay of AccessManager belongs to each member of a role, not to the role.
access_item_delay() {
  local f="$ITEMS/openzeppelin-5-access.md"
  [ -f "$f" ] || return 1
  ! grep -qiF 'a role can carry an execution delay' "$f" || return 1
  grep -qiE 'execution delay[^.]*each member|each member[^.]*execution delay' "$f"
}
check "the contract-design access item puts the execution delay on each member of a role" access_item_delay

checklist_tx_gas_cap() {
  grep -F 'EIP-7825' "$CHECKLIST" | grep -qF '16,777,216'
}
check "the contract-design checklist bounds a transaction by the EIP-7825 gas cap" checklist_tx_gas_cap

# A grant made with no delay skips the delay the design relies on, and an admin that can revoke a
# role can also grant it.
checklist_grant_delay() {
  grep -iE 'grant' "$CHECKLIST" | grep -qiE 'delay' || return 1
  grep -iE 'revoke' "$CHECKLIST" | grep -qiE 'grant'
}
check "the contract-design checklist checks that no grant skips the delay" checklist_grant_delay

no_urls() {
  [ "$(find "$ITEMS" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')" -ge 6 ] || return 1
  ! grep -rIlE 'https?://|www\.' "$ITEMS" > /dev/null || return 1
  ! grep -rL '^source: .\{8,\}' "$ITEMS" | grep -q .
}
check "no contract-design item holds a URL" no_urls

checklist_rules() {
  local phrase
  [ -f "$CHECKLIST" ] || return 1
  for phrase in \
    'who may call' \
    'invariant' \
    'decimals' \
    'rounding' \
    'initializer' \
    '_disableInitializers' \
    'ERC-7201' \
    'storage layout' \
    'stale' \
    'sequencer' \
    'prevrandao' \
    'VRF' \
    'slippage' \
    'deadline' \
    'commit-reveal' \
    'reentrancy' \
    'checks-effects-interactions' \
    'pull' \
    'SafeERC20' \
    'fee-on-transfer' \
    'two-step' \
    'timelock' \
    'pauser' \
    'anyone can call' \
    'unbounded'; do
    grep -qiF -- "$phrase" "$CHECKLIST" || return 1
  done
}
check "the contract-design checklist keeps its rules" checklist_rules

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
check "the contract-design SKILL.md keeps its rules" skill_rules

# The body is counted in words and the description in characters, as the size the agent reads.
SKILL_WORDS_MAX=700
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
check "the contract-design SKILL.md stays within its size limits" skill_size

# The services that run scheduled calls, relay transactions, or watch contracts are dated in the
# items of dapp-architecture, so contract-design sends the agent there instead of keeping copies.
DAPP_ITEMS="$PLUGIN/skills/dapp-architecture/references/items"
sends_to_dapp_items() {
  local phrase
  [ -f "$SKILL" ] || return 1
  grep -q '^topic: automation' "$DAPP_ITEMS"/*.md 2>/dev/null || return 1
  for phrase in \
    'scheduled calls' \
    'relayers' \
    'monitoring' \
    'the items of the dapp-architecture skill' \
    'when that skill is not installed' \
    'never choose a deprecated or retired service'; do
    grep -qF -- "$phrase" "$SKILL" || return 1
  done
}
check "the contract-design SKILL.md sends automation, relayer, and monitoring services to the dapp-architecture items" sends_to_dapp_items

# One fact lives in one skill: no contract-design item shares a file name or a subject with an item
# of dapp-architecture.
no_copies() {
  local f subject
  [ "$(find "$ITEMS" -name '*.md' | wc -l | tr -d ' ')" -ge 1 ] && [ -d "$DAPP_ITEMS" ] || return 1
  for f in "$ITEMS"/*.md; do
    [ -e "$DAPP_ITEMS/$(basename "$f")" ] && return 1
    subject="$(sed -n 's/^subject: //p' "$f")"
    [ -n "$subject" ] || return 1
    grep -qxF -- "subject: $subject" "$DAPP_ITEMS"/*.md && return 1
  done
  return 0
}
check "no contract-design item copies a dapp-architecture item" no_copies

# Each case has a case.yaml and an executable fixture.sh that runs the way claude plugin eval runs it
# (in home/cwd with HOME at home). A design case leaves the project's README and grades the design
# file the prompt names; the unrelated case grades that the skill did not start.
CASES=(token-sale-contracts nft-raffle-contracts contract-design-unrelated-request)
eval_suite() {
  local c home
  for c in "${CASES[@]}"; do
    [ -f "$EVALS/$c/case.yaml" ] && [ -x "$EVALS/$c/fixture.sh" ] || return 1
    home="$T/fixture-$c/home"
    mkdir -p "$home/cwd"
    (cd "$home/cwd" && HOME="$home" bash "$EVALS/$c/fixture.sh") > /dev/null 2>&1 || return 1
    if [ "$c" = contract-design-unrelated-request ]; then
      grep -q 'name: skill-not-loaded' "$EVALS/$c/case.yaml" && grep -q "input_match: 'contract-design'" "$EVALS/$c/case.yaml" || return 1
      continue
    fi
    grep -q 'name: skill-fired' "$EVALS/$c/case.yaml" && grep -q "input_match: 'contract-design'" "$EVALS/$c/case.yaml" || return 1
    grep -q 'path: docs/design/' "$EVALS/$c/case.yaml" && [ -s "$home/cwd/README.md" ] || return 1
  done
  git -C "$PLUGIN" check-ignore -q "evals/results/run.json"
}
check "the eval suite has its contract-design cases and each fixture builds its state" eval_suite

readmes_list() {
  grep -qF '/evm-dev:contract-design' "$REPO/README.md" && grep -qF '/evm-dev:contract-design' "$REPO/README.ja.md"
}
check "the root READMEs list /evm-dev:contract-design" readmes_list

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
    && bash "$PLUGIN/skills/dapp-architecture/tests/test-dapp-architecture.sh" > "$T/dapp-architecture.out" 2>&1
}
check "the other evm-dev skills still pass their tests with contract-design" others_kept

# The skill writes in the design format of design-doc and checks a design with its verify, both
# pinned by a range and a fingerprint in musubi.json. musubi check compares the fingerprints.
follows_design_doc() {
  [ -f "$DECLARATION" ] || return 1
  python3 - "$SKILL_DIR" <<'PYEOF'
import json, os, re, sys
skill = sys.argv[1]
declaration = json.load(open(os.path.join(skill, "musubi.json"), encoding="utf-8"))
follows = declaration.get("follows", {})
pin = re.compile(r"^sha256-[A-Za-z0-9+/]{43}=$")
if declaration.get("musubi") != "2026-11-19" or sorted(follows) != ["design-doc/design", "design-doc/verify"] \
        or "provides" in declaration:
    print("      musubi.json declares %s" % json.dumps(declaration, sort_keys=True))
    sys.exit(1)
for ref, entry in follows.items():
    if entry.get("version") != "^1.0.0" or not pin.match(entry.get("integrity", "")):
        print("      %s is %s" % (ref, entry))
        sys.exit(1)
examples = follows["design-doc/design"].get("examples", [])
if len(examples) != 1 or not examples[0].startswith("examples/") \
        or not os.path.isfile(os.path.join(skill, examples[0])):
    print("      the design examples are %s" % examples)
    sys.exit(1)
sys.exit(1 if "examples" in follows["design-doc/verify"] else 0)
PYEOF
}
check "the skill follows design and verify of design-doc" follows_design_doc

# The three lines musubi add prints for design-doc/design, and the verify step that passes this
# skill's sections file and dated section.
LINE_FORMAT='Write in the `design` format of the `design-doc` skill: open the `design-doc` skill by name and read the file it names for `design`.'
LINE_CHECK='If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.'
LINE_MISSING='If the `design-doc` skill is not installed, do not start: tell the user that `design-doc` is missing and how to install it, then stop.'
writes_in_the_format() {
  [ -f "$SKILL" ] || return 1
  grep -qxF -- "$LINE_FORMAT" "$SKILL" && grep -qxF -- "$LINE_CHECK" "$SKILL" || return 1
  grep -qF -- 'put the sections of `templates/sections.md` where the format says' "$SKILL" || return 1
  grep -qF -- "verify --sections <folder of this SKILL.md>/templates/sections.md --dated \"$DATED\" <design file>" "$SKILL" || return 1
  ! grep -qF -- 'templates/design.md' "$SKILL"
}
check "the SKILL.md writes in the design-doc format and runs its verify" writes_in_the_format

stops_without_design_doc() {
  [ -f "$SKILL" ] && grep -qxF -- "$LINE_MISSING" "$SKILL"
}
check "the SKILL.md stops when design-doc is missing" stops_without_design_doc

sections_in_order() {
  local s n=0 got
  [ -f "$SECTIONS_FILE" ] || return 1
  got="$(grep -E '^## ' "$SECTIONS_FILE" | sed 's/^## //')"
  for s in "${OWN[@]}"; do
    n=$((n + 1))
    [ "$(printf '%s\n' "$got" | sed -n "${n}p")" = "$s" ] || { echo "      section $n is not $s"; return 1; }
  done
  [ "$(printf '%s\n' "$got" | wc -l | tr -d ' ')" -eq 8 ] && [ "$(grep -c '^Fill in: ' "$SECTIONS_FILE")" -ge 8 ]
}
check "the sections file keeps the eight sections in order" sections_in_order

old_template_gone() {
  [ ! -e "$SKILL_DIR/templates/design.md" ] && [ -f "$SECTIONS_FILE" ] && ! grep -q '^## Open decisions' "$SECTIONS_FILE"
}
check "the old design template is gone" old_template_gone

example_passes() {
  local example
  [ -f "$DECLARATION" ] && [ -f "$DESIGN_DOC/scripts/design-doc.py" ] || return 1
  example="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["follows"]["design-doc/design"]["examples"][0])' "$DECLARATION")" || return 1
  python3 "$DESIGN_DOC/scripts/design-doc.py" verify --sections "$SECTIONS_FILE" --dated "$DATED" "$SKILL_DIR/$example" > "$T/example.out" 2>&1 \
    || { sed 's/^/      /' "$T/example.out"; return 1; }
}
check "the example design passes the verify of design-doc" example_passes

no_verify_command() {
  python3 "$SCRIPT" verify "$T/no-such-design.md" > "$T/no-verify.out" 2>&1
  [ $? -eq 2 ] && grep -q "invalid choice: 'verify'" "$T/no-verify.out" && ! grep -q 'def design_problems' "$SCRIPT"
}
check "the script has no verify command" no_verify_command

eval_cases_load_doc_formats() {
  local c
  for c in "${CASES[@]}"; do
    grep -qxF 'plugins: ["../..", "../../../doc-formats"]' "$EVALS/$c/case.yaml" || { echo "      $c"; return 1; }
  done
}
check "the eval cases load doc-formats too" eval_cases_load_doc_formats

depends_on_doc_formats() {
  python3 - "$PLUGIN/.claude-plugin/plugin.json" <<'PYEOF'
import json, sys
deps = json.load(open(sys.argv[1], encoding="utf-8")).get("dependencies", [])
names = [d if isinstance(d, str) else d.get("name") for d in deps]
sys.exit(0 if "doc-formats" in names else 1)
PYEOF
}
check "evm-dev depends on doc-formats in its Claude Code manifest" depends_on_doc_formats

readmes_install_doc_formats() {
  local page
  for page in README.md README.ja.md; do
    grep -qF 'codex plugin add doc-formats@agent-shuriken' "$PLUGIN/$page" \
      && grep -qF 'copilot plugin install doc-formats@agent-shuriken' "$PLUGIN/$page" || { echo "      $page"; return 1; }
  done
}
check "the evm-dev READMEs tell Codex and Copilot CLI users to install doc-formats" readmes_install_doc_formats

how_it_works_format() {
  local page
  for page in docs/how-it-works.md docs/how-it-works.ja.md; do
    ! grep -qF 'templates/design.md' "$PLUGIN/$page" || { echo "      $page names templates/design.md"; return 1; }
    [ "$(grep -cF 'templates/sections.md' "$PLUGIN/$page")" -ge 5 ] && grep -qF 'design-doc' "$PLUGIN/$page" \
      || { echo "      $page"; return 1; }
  done
}
check "the evm-dev how-it-works pages describe the design-doc format" how_it_works_format

printf '%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
