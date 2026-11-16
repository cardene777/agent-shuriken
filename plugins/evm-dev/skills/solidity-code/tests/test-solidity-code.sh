#!/usr/bin/env bash
# Tests for solidity-code.py, the bundled items, the SKILL.md, and the eval suite.
# Projects and items written here live in a throwaway folder; nothing reaches the network.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
SCRIPT="$SKILL_DIR/scripts/solidity-code.py"
ITEMS="$SKILL_DIR/references/items"
SKILL="$SKILL_DIR/SKILL.md"
PLUGIN="$(cd "$SKILL_DIR/../.." && pwd)"
EVALS="$PLUGIN/evals"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'chmod -R u+rw "$T" 2>/dev/null; rm -rf "$T"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }

# A stand-in forge on the PATH, so the Foundry version does not depend on this machine.
mkdir -p "$T/bin"
printf '#!/bin/sh\necho "forge Version: 1.9.0-stable"\n' > "$T/bin/forge"
chmod +x "$T/bin/forge"
run() { PATH="$T/bin:$PATH" python3 "$SCRIPT" "$@"; }

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

# write <path> <content>: writes a file, creating its folder.
write() { mkdir -p "$(dirname "$1")"; printf '%s\n' "$2" > "$1"; }

# foundry_project <folder> <openzeppelin version or "" for a package.json without one>
foundry_project() {
  write "$1/foundry.toml" '[profile.default]
src = "src"
solc = "0.8.34"'
  if [ -n "$2" ]; then
    write "$1/lib/openzeppelin-contracts/package.json" "{\"name\": \"openzeppelin-solidity\", \"version\": \"$2\"}"
  else
    write "$1/lib/openzeppelin-contracts/package.json" '{"name": "openzeppelin-solidity"}'
  fi
  write "$1/lib/forge-std/package.json" '{"name": "forge-std", "version": "1.17.0"}'
}

# The bundled items are many; an empty or missing folder must not pass for a clean one.
bundled_check() {
  [ -x "$SCRIPT" ] || return 1
  [ "$(find "$ITEMS" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')" -ge 10 ] || return 1
  run check > "$T/bundled.out" 2>&1
}
check "check passes on the bundled items" bundled_check

bad_items_named() {
  local d="$T/bad" code
  item "$d" good-item 'tool: openzeppelin' 'since: 5.7.0' 'checked: 2026-11-01' 'source: OpenZeppelin Contracts changelog' 'detect: draft-ERC4337'
  item "$d" no-source 'tool: openzeppelin' 'since: 5.7.0' 'checked: 2026-11-01'
  item "$d" no-since 'tool: hardhat' 'checked: 2026-11-01' 'source: Hardhat changelog'
  item "$d" unknown-tool 'tool: truffle' 'since: 5.0.0' 'checked: 2026-11-01' 'source: Truffle docs'
  item "$d" bad-date 'tool: solc' 'since: 0.8.31' 'checked: 2026-02-30' 'source: Solidity blog'
  item "$d" broken-pattern 'tool: ethereum' 'checked: 2026-11-01' 'source: EIP-7702' 'detect: tx\.origin(=='
  run check --dir "$d" > "$T/bad.out" 2>&1
  code=$?
  [ "$code" -eq 1 ] || return 1
  grep -q 'no-source' "$T/bad.out" && grep -q 'no-since' "$T/bad.out" && grep -q 'unknown-tool' "$T/bad.out" \
    && grep -q 'bad-date' "$T/bad.out" && grep -q 'broken-pattern' "$T/bad.out" && ! grep -q 'good-item' "$T/bad.out"
}
check "check names an item with a missing field, an unknown tool, an impossible date, or a broken pattern" bad_items_named

# Counted to 2026-05-01: 2026-01-31 is exactly 90 days old (still ok), 2026-01-30 is 91 (stale).
stale_marked() {
  local d="$T/stale"
  item "$d" edge-item 'tool: solc' 'since: 0.8.31' 'checked: 2026-01-31' 'source: Solidity blog'
  item "$d" old-item 'tool: hardhat' 'since: 3.4.0' 'checked: 2026-01-30' 'source: Hardhat changelog'
  item "$d" chain-item 'tool: ethereum' 'checked: 2026-04-30' 'source: EIP-7702'
  run list --dir "$d" --today 2026-05-01 > "$T/list.out" 2>&1 || return 1
  grep -Eq '^ok +solc +0\.8\.31 +2026-01-31 +edge-item$' "$T/list.out" \
    && grep -Eq '^stale +hardhat +3\.4\.0 +2026-01-30 +old-item$' "$T/list.out" \
    && grep -Eq '^ok +ethereum +- +2026-04-30 +chain-item$' "$T/list.out" \
    && grep -Eq '^3 items, 1 stale as of 2026-05-01$' "$T/list.out"
}
check "list marks the items checked more than 90 days ago" stale_marked

project_read() {
  local f="$T/proj-foundry" h="$T/proj-hardhat"
  foundry_project "$f" 5.7.0
  write "$f/src/Token.sol" 'pragma solidity ^0.8.24;'
  run project "$f" > "$T/project-f.out" 2>&1 || return 1
  grep -Eq '^framework +foundry$' "$T/project-f.out" && grep -Eq '^solc +0\.8\.34$' "$T/project-f.out" \
    && grep -Eq '^openzeppelin +5\.7\.0$' "$T/project-f.out" && grep -Eq '^forge-std +1\.17\.0$' "$T/project-f.out" \
    && grep -Eq '^foundry +1\.9\.0$' "$T/project-f.out" && grep -Eq '^hardhat +none$' "$T/project-f.out" || return 1
  write "$h/package.json" '{"devDependencies": {"hardhat": "^3.22.0"}}'
  write "$h/node_modules/hardhat/package.json" '{"name": "hardhat", "version": "3.22.0"}'
  write "$h/node_modules/@openzeppelin/contracts/package.json" '{"name": "@openzeppelin/contracts"}'
  write "$h/hardhat.config.ts" 'import { defineConfig } from "hardhat/config";
export default defineConfig({ solidity: "0.8.28" });'
  run project "$h" > "$T/project-h.out" 2>&1 || return 1
  grep -Eq '^framework +hardhat$' "$T/project-h.out" && grep -Eq '^hardhat +3\.22\.0$' "$T/project-h.out" \
    && grep -Eq '^solc +0\.8\.28$' "$T/project-h.out" && grep -Eq '^openzeppelin +unknown$' "$T/project-h.out" \
    && grep -Eq '^foundry +none$' "$T/project-h.out"
}
check "project reads the framework and the versions, and says unknown for what it cannot read" project_read

# Items shared by the scan checks: one per tool kind, so a version gate and the always-on
# ethereum kind are both exercised, plus a Hardhat item for a project that has no Hardhat.
scan_items() {
  local d="$T/scan-items"
  item "$d" oz-drops-draft 'tool: openzeppelin' 'since: 5.7.0' 'checked: 2026-11-01' 'source: OpenZeppelin Contracts changelog' 'detect: draft-I?ERC4337'
  item "$d" eoa-check 'tool: ethereum' 'checked: 2026-11-01' 'source: EIP-7702' 'detect: tx\.origin\s*==\s*msg\.sender'
  item "$d" hh-config 'tool: hardhat' 'since: 3.0.0' 'checked: 2026-11-01' 'source: Hardhat changelog' 'detect: module\.exports' 'files: hardhat.config.*'
  item "$d" env-reader 'tool: ethereum' 'checked: 2026-11-01' 'source: EIP-7702' 'detect: PRIVATE' 'files: *'
}
scan_items

scan_matches() {
  local p="$T/scan-match" code
  foundry_project "$p" 5.7.0
  write "$p/src/A.sol" 'pragma solidity ^0.8.24;

import {ERC4337Utils} from "@openzeppelin/contracts/account/utils/draft-ERC4337Utils.sol";'
  write "$p/src/B.sol" 'pragma solidity ^0.8.24;
contract B {
  function f() external {

    require(tx.origin == msg.sender, "no contracts");
  }
}'
  write "$p/src/C.sol" 'pragma solidity ^0.8.24;
contract C {}'
  run scan "$p" --items "$T/scan-items" > "$T/scan-match.out" 2>&1
  code=$?
  [ "$code" -eq 1 ] || return 1
  grep -Eq '^src/A\.sol:3 oz-drops-draft$' "$T/scan-match.out" && grep -Eq '^src/B\.sol:5 eoa-check$' "$T/scan-match.out" \
    && ! grep -q 'src/C.sol' "$T/scan-match.out" || return 1
  # The same project without the two lines has nothing to report.
  write "$p/src/A.sol" 'pragma solidity ^0.8.24;
import {ERC4337Utils} from "@openzeppelin/contracts/account/utils/ERC4337Utils.sol";'
  write "$p/src/B.sol" 'pragma solidity ^0.8.24;
contract B {}'
  run scan "$p" --items "$T/scan-items" > "$T/scan-clean.out" 2>&1
}
check "scan names each line that matches an item for the project's versions" scan_matches

scan_before_since() {
  local p="$T/scan-old"
  foundry_project "$p" 5.6.1
  write "$p/src/A.sol" 'import {ERC4337Utils} from "@openzeppelin/contracts/account/utils/draft-ERC4337Utils.sol";'
  write "$p/src/B.sol" 'contract B { function f() external { require(tx.origin == msg.sender); } }'
  run scan "$p" --items "$T/scan-items" > "$T/scan-old.out" 2>&1
  [ $? -eq 1 ] || return 1
  ! grep -q 'oz-drops-draft' "$T/scan-old.out" && grep -Eq '^src/B\.sol:1 eoa-check$' "$T/scan-old.out"
}
check "scan skips an item for versions before its since" scan_before_since

scan_unknown() {
  local p="$T/scan-unknown" code
  foundry_project "$p" ""
  write "$p/src/A.sol" 'import {ERC4337Utils} from "@openzeppelin/contracts/account/utils/draft-ERC4337Utils.sol";'
  run scan "$p" --items "$T/scan-items" > "$T/scan-unknown.out" 2>&1
  code=$?
  [ "$code" -ne 0 ] || return 1
  grep -Eq '^unknown$' "$T/scan-unknown.out" && grep -q 'oz-drops-draft' "$T/scan-unknown.out" \
    && ! grep -qi 'no match' "$T/scan-unknown.out" && ! grep -Eq '^src/A\.sol:1 ' "$T/scan-unknown.out"
}
check "scan lists items it could not judge as unknown" scan_unknown

scan_private() {
  local p="$T/scan-private" code
  foundry_project "$p" 5.7.0
  write "$p/src/A.sol" 'contract A { function f() external { require(tx.origin == msg.sender, "LINE_TEXT_MARKER"); } }'
  write "$p/lib/dep/src/Dep.sol" 'contract D { function f() external { require(tx.origin == msg.sender); } }'
  write "$p/node_modules/dep/Dep.sol" 'contract D { function f() external { require(tx.origin == msg.sender); } }'
  write "$p/out/A.sol" 'require(tx.origin == msg.sender);'
  write "$p/cache/A.sol" 'require(tx.origin == msg.sender);'
  write "$p/.env" 'PRIVATE=placeholder'
  write "$p/.env.local" 'PRIVATE=placeholder'
  chmod 000 "$p/.env.local"
  run scan "$p" --items "$T/scan-items" > "$T/scan-private.out" 2>&1
  code=$?
  chmod 600 "$p/.env.local"
  [ "$code" -eq 1 ] || return 1
  grep -Eq '^src/A\.sol:1 eoa-check$' "$T/scan-private.out" && ! grep -q 'LINE_TEXT_MARKER' "$T/scan-private.out" \
    && ! grep -Eq '(^|/)(lib|node_modules|out|cache)/' "$T/scan-private.out" && ! grep -q '\.env' "$T/scan-private.out" \
    && ! grep -qi 'error\|traceback\|permission' "$T/scan-private.out"
}
check "scan prints no line text and reads no dependencies or env files" scan_private

no_urls() {
  [ "$(find "$ITEMS" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')" -ge 10 ] || return 1
  ! grep -rIlE 'https?://|www\.' "$ITEMS" > /dev/null || return 1
  ! grep -rL '^source: .\{8,\}' "$ITEMS" | grep -q .
}
check "no item holds a URL" no_urls

skill_rules() {
  local phrase
  [ -f "$SKILL" ] || return 1
  for phrase in \
    'Run `project` before writing' \
    'follow the conventions the project already uses' \
    're-check it against the official document' \
    'Run `scan` after writing' \
    'then build and run the tests' \
    'If the build or the tests cannot run, say so' \
    'Never write a private key or a mnemonic into a file' \
    'refuse a command that passes a key' \
    'Choosing how a contract is upgraded belongs to the contract design skill' \
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
# (in home/cwd with HOME at home). A project case must leave a project whose framework and versions
# `project` reads as the case expects; the unrelated case grades that the skill did not start.
CASES=(erc4337-imports proxy-init-data eoa-only-mint hardhat-network code-unrelated-request)
expect_project() {
  case "$1" in
    erc4337-imports) printf 'framework +foundry\nopenzeppelin +5\\.7\\.0\n' ;;
    proxy-init-data) printf 'framework +foundry\nopenzeppelin +5\\.6\\.1\n' ;;
    eoa-only-mint) printf 'framework +foundry\nopenzeppelin +5\\.6\\.1\n' ;;
    hardhat-network) printf 'framework +hardhat\nhardhat +3\\.22\\.0\n' ;;
  esac
}
eval_suite() {
  local c home want
  for c in "${CASES[@]}"; do
    [ -f "$EVALS/$c/case.yaml" ] && [ -x "$EVALS/$c/fixture.sh" ] || return 1
    home="$T/fixture-$c/home"
    mkdir -p "$home/cwd"
    (cd "$home/cwd" && HOME="$home" bash "$EVALS/$c/fixture.sh") > /dev/null 2>&1 || return 1
    if [ "$c" = code-unrelated-request ]; then
      grep -q 'name: skill-not-loaded' "$EVALS/$c/case.yaml" || return 1
      continue
    fi
    grep -q 'name: skill-fired' "$EVALS/$c/case.yaml" || return 1
    run project "$home/cwd" > "$T/fixture-$c.out" 2>&1 || return 1
    while IFS= read -r want; do
      grep -Eq "^$want\$" "$T/fixture-$c.out" || return 1
    done < <(expect_project "$c")
  done
  git -C "$PLUGIN" check-ignore -q "evals/results/run.json"
}
check "the eval suite has its cases and each fixture builds its state" eval_suite

evm_standards_kept() {
  bash "$PLUGIN/skills/evm-standards/scripts/evm-standards.sh" check > "$T/evm-standards.out" 2>&1
}
check "the evm-standards items still pass their check" evm_standards_kept

printf '%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
