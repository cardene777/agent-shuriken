#!/usr/bin/env bash
# Tests for release-check.py, the bundled items, the SKILL.md, and the eval suite. Storage layouts,
# ABIs, and bytecode written here follow what forge 1.5 and solc 0.8.30 write, live in a throwaway
# folder, and are built by hand; nothing reaches the network and nothing runs forge or Hardhat.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
SCRIPT="$SKILL_DIR/scripts/release-check.py"
ITEMS="$SKILL_DIR/references/items"
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

TOPICS=(layout evm tools)

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

bundled_check() {
  local t
  [ -f "$SCRIPT" ] || return 1
  run check > "$T/bundled.out" 2>&1 || return 1
  for t in "${TOPICS[@]}"; do
    grep -rqx "topic: $t" "$ITEMS" || return 1
  done
}
check "check passes on the bundled release-check items and covers every topic" bundled_check

bad_items_named() {
  local d="$T/bad" code
  item "$d" good-item 'topic: layout' 'subject: A layout check' 'checked: 2026-11-01' 'source: The vendor, documentation'
  item "$d" no-source 'topic: evm' 'subject: An EVM version' 'checked: 2026-11-01'
  item "$d" no-subject 'topic: tools' 'checked: 2026-11-01' 'source: The tool, reference'
  item "$d" unknown-topic 'topic: gas' 'subject: Gas prices' 'checked: 2026-11-01' 'source: The tool'
  item "$d" bad-date 'topic: layout' 'subject: Namespaced storage' 'checked: 2026-02-30' 'source: The standard'
  run check --dir "$d" > "$T/bad.out" 2>&1
  code=$?
  [ "$code" -eq 1 ] || return 1
  grep -q 'no-source' "$T/bad.out" && grep -q 'no-subject' "$T/bad.out" && grep -q 'unknown-topic' "$T/bad.out" \
    && grep -q 'bad-date' "$T/bad.out" && ! grep -q 'good-item' "$T/bad.out"
}
check "check names a release-check item with a missing field, an unknown topic, or an impossible date" bad_items_named

# Counted to 2026-05-01: 2026-01-31 is exactly 90 days old (still ok), 2026-01-30 is 91 (stale).
stale_marked() {
  local d="$T/stale"
  item "$d" edge-item 'topic: evm' 'subject: Chain EVM versions' 'checked: 2026-01-31' 'source: The chains, documentation'
  item "$d" old-item 'topic: tools' 'subject: Gas snapshots' 'checked: 2026-01-30' 'source: The tool, reference'
  run list --dir "$d" --today 2026-05-01 > "$T/list.out" 2>&1 || return 1
  grep -Eq '^ok +evm +2026-01-31 +edge-item +Chain EVM versions$' "$T/list.out" \
    && grep -Eq '^stale +tools +2026-01-30 +old-item +Gas snapshots$' "$T/list.out" \
    && grep -Eq '^2 items, 1 stale as of 2026-05-01$' "$T/list.out"
}
check "list marks the release-check items checked more than 90 days ago" stale_marked

# layouts <folder>: writes storage layouts in the shape forge writes. The old version is a Base
# contract (owner, then a 49-slot gap) under Vault (total and fee sharing a slot, a mapping to a
# Position struct, a dynamic array of users). Each new version changes one set of things.
layouts() {
  python3 - "$1" <<'PYEOF'
import json, os, sys
root = sys.argv[1]
os.makedirs(root, exist_ok=True)

def entry(label, slot, typ, offset=0, contract="src/Vault.sol:Vault"):
    return {"astId": 1, "contract": contract, "label": label, "offset": offset, "slot": str(slot), "type": typ}

def types(struct_id="17", struct_owner="Vault", position=None, gap=49, total="t_uint128", fee="t_uint64"):
    position = position or [("amount", 0, 0, "t_uint128"), ("since", 0, 16, "t_uint64"), ("active", 0, 24, "t_bool")]
    s = "t_struct(Position)%s_storage" % struct_id
    t = {
        "t_address": {"encoding": "inplace", "label": "address", "numberOfBytes": "20"},
        "t_bool": {"encoding": "inplace", "label": "bool", "numberOfBytes": "1"},
        "t_uint32": {"encoding": "inplace", "label": "uint32", "numberOfBytes": "4"},
        "t_uint64": {"encoding": "inplace", "label": "uint64", "numberOfBytes": "8"},
        "t_uint128": {"encoding": "inplace", "label": "uint128", "numberOfBytes": "16"},
        "t_uint256": {"encoding": "inplace", "label": "uint256", "numberOfBytes": "32"},
        "t_array(t_address)dyn_storage": {"encoding": "dynamic_array", "label": "address[]", "numberOfBytes": "32", "base": "t_address"},
        "t_array(t_uint256)%d_storage" % gap: {"encoding": "inplace", "label": "uint256[%d]" % gap, "numberOfBytes": str(32 * gap), "base": "t_uint256"},
        "t_mapping(t_address,%s)" % s: {"encoding": "mapping", "label": "mapping(address => struct %s.Position)" % struct_owner,
                                         "numberOfBytes": "32", "key": "t_address", "value": s},
        s: {"encoding": "inplace", "label": "struct %s.Position" % struct_owner, "numberOfBytes": "32",
            "members": [entry(l, sl, ty, off) for (l, sl, off, ty) in position]},
    }
    return t, s

def write(name, storage, t):
    with open(os.path.join(root, name), "w", encoding="utf-8") as f:
        json.dump({"storage": storage, "types": t}, f, indent=2)

t, s = types()
old = [entry("owner", 0, "t_address"), entry("__gap", 1, "t_array(t_uint256)49_storage"),
       entry("total", 50, "t_uint128"), entry("fee", 50, "t_uint64", 16),
       entry("positions", 51, "t_mapping(t_address,%s)" % s), entry("users", 52, "t_array(t_address)dyn_storage")]
write("old.json", old, t)

# Compatible: a bool packed into owner's slot, a new variable at the start of the gap with the gap
# shrunk by one, a new variable at the end, and the contract renamed to VaultV2 (new struct id).
t2, s2 = types(struct_id="42", struct_owner="VaultV2", gap=48)
good = [entry("owner", 0, "t_address", contract="src/VaultV2.sol:VaultV2"),
        entry("paused", 0, "t_bool", 20, contract="src/VaultV2.sol:VaultV2"),
        entry("cap", 1, "t_uint256", contract="src/VaultV2.sol:VaultV2"),
        entry("__gap", 2, "t_array(t_uint256)48_storage", contract="src/VaultV2.sol:VaultV2"),
        entry("total", 50, "t_uint128", contract="src/VaultV2.sol:VaultV2"),
        entry("fee", 50, "t_uint64", 16, contract="src/VaultV2.sol:VaultV2"),
        entry("positions", 51, "t_mapping(t_address,%s)" % s2, contract="src/VaultV2.sol:VaultV2"),
        entry("users", 52, "t_array(t_address)dyn_storage", contract="src/VaultV2.sol:VaultV2"),
        entry("version", 53, "t_uint256", contract="src/VaultV2.sol:VaultV2")]
write("good.json", good, t2)

# In place: fee narrowed to uint32, Position's members reordered, users renamed to members, and
# total removed.
t3, s3 = types(position=[("amount", 0, 0, "t_uint128"), ("active", 0, 16, "t_bool"), ("since", 0, 17, "t_uint64")])
inplace = [entry("owner", 0, "t_address"), entry("__gap", 1, "t_array(t_uint256)49_storage"),
           entry("fee", 50, "t_uint32", 16), entry("positions", 51, "t_mapping(t_address,%s)" % s3),
           entry("members", 52, "t_array(t_address)dyn_storage")]
write("inplace.json", inplace, t3)

# Gap: cap added to Base without shrinking the gap, so the gap and everything after it move.
gapped = [entry("owner", 0, "t_address"), entry("cap", 1, "t_uint256"), entry("__gap", 2, "t_array(t_uint256)49_storage"),
          entry("total", 51, "t_uint128"), entry("fee", 51, "t_uint64", 16),
          entry("positions", 52, "t_mapping(t_address,%s)" % s), entry("users", 53, "t_array(t_address)dyn_storage")]
write("gapped.json", gapped, t)
PYEOF
}

layout_compatible() {
  local d="$T/layout"
  [ -f "$SCRIPT" ] || return 1
  layouts "$d"
  run layout "$d/old.json" "$d/good.json" > "$T/layout-good.out" 2>&1 || return 1
  ! grep -Eq '^(removed|moved|retyped|gap|renamed) ' "$T/layout-good.out" \
    && grep -Eq '^layout: compatible \(1 contract compared, 0 renamed\)$' "$T/layout-good.out"
}
check "layout passes an upgrade that appends variables and shrinks the gap to match" layout_compatible

layout_breaks() {
  local d="$T/layout"
  [ -f "$d/old.json" ] || layouts "$d"
  run layout "$d/old.json" "$d/inplace.json" > "$T/layout-inplace.out" 2>&1
  [ $? -eq 1 ] || return 1
  grep -qx 'removed Vault total slot 50 offset 0' "$T/layout-inplace.out" \
    && grep -qx 'retyped Vault fee uint64 -> uint32' "$T/layout-inplace.out" \
    && grep -qx 'retyped Vault positions mapping(address => struct Position) changed inside' "$T/layout-inplace.out" \
    && grep -qx 'renamed Vault users -> members slot 52 offset 0' "$T/layout-inplace.out" \
    && ! grep -q '^moved ' "$T/layout-inplace.out" \
    && grep -Eq '^layout: 3 problems in 1 contract compared \(1 renamed\)$' "$T/layout-inplace.out" || return 1
  run layout "$d/old.json" "$d/gapped.json" > "$T/layout-gap.out" 2>&1
  [ $? -eq 1 ] || return 1
  grep -qx 'gap Vault __gap ends at slot 51 instead of 50' "$T/layout-gap.out" \
    && grep -qx 'moved Vault total 50:0 -> 51:0' "$T/layout-gap.out" \
    && grep -qx 'moved Vault fee 50:16 -> 51:16' "$T/layout-gap.out" \
    && grep -qx 'moved Vault positions 51:0 -> 52:0' "$T/layout-gap.out" \
    && grep -qx 'moved Vault users 52:0 -> 53:0' "$T/layout-gap.out" \
    && ! grep -q 'moved Vault __gap' "$T/layout-gap.out" \
    && ! grep -q 'cap' "$T/layout-gap.out"
}
check "layout names removed, moved, retyped, and renamed variables and a gap that no longer ends where it did" layout_breaks

# Foundry out folders: one artifact per contract under <file>.sol/, test and script artifacts that
# also changed, and a build-info folder, none of which may be compared.
out_folders() {
  python3 - "$1" "$T/layout" <<'PYEOF'
import json, os, sys
root, layouts = sys.argv[1], sys.argv[2]
def load(name):
    return json.load(open(os.path.join(layouts, name)))
def artifact(folder, path, layout):
    p = os.path.join(root, folder, path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    json.dump({"abi": [], "bytecode": {"object": "0x00"}, "deployedBytecode": {"object": "0x00"}, "storageLayout": layout},
              open(p, "w"), indent=2)
token = {"storage": [{"astId": 1, "contract": "src/Token.sol:Token", "label": "supply", "offset": 0, "slot": "0", "type": "t_uint256"}],
         "types": {"t_uint256": {"encoding": "inplace", "label": "uint256", "numberOfBytes": "32"}}}
artifact("old", "Vault.sol/Vault.json", load("old.json"))
artifact("new", "Vault.sol/Vault.json", load("inplace.json"))
artifact("old", "Token.sol/Token.json", token)
artifact("new", "Token.sol/Token.json", token)
artifact("old", "Vault.t.sol/VaultTest.json", load("old.json"))
artifact("new", "Vault.t.sol/VaultTest.json", load("gapped.json"))
artifact("old", "Deploy.s.sol/Deploy.json", load("old.json"))
artifact("new", "Deploy.s.sol/Deploy.json", load("gapped.json"))
for side in ("old", "new"):
    os.makedirs(os.path.join(root, side, "build-info"), exist_ok=True)
    json.dump({"output": {"contracts": {}}}, open(os.path.join(root, side, "build-info", "abc.json"), "w"))
artifact("v1", "VaultV1.sol/VaultV1.json", load("old.json"))
artifact("v2", "VaultV2.sol/VaultV2.json", load("good.json"))
PYEOF
}

layout_folders() {
  local d="$T/outs"
  [ -f "$T/layout/old.json" ] || layouts "$T/layout"
  out_folders "$d" || return 1
  run layout "$d/old" "$d/new" > "$T/layout-folders.out" 2>&1
  [ $? -eq 1 ] || return 1
  grep -qx 'removed Vault total slot 50 offset 0' "$T/layout-folders.out" \
    && ! grep -Eq 'VaultTest|Deploy|Token ' "$T/layout-folders.out" \
    && grep -Eq '^layout: 3 problems in 2 contracts compared \(1 renamed\)$' "$T/layout-folders.out" || return 1
  run layout "$d/old" "$d/new" --contract Token > "$T/layout-token.out" 2>&1 || return 1
  grep -Eq '^layout: compatible \(1 contract compared, 0 renamed\)$' "$T/layout-token.out" || return 1
  run layout "$d/v1" "$d/v2" > "$T/layout-none.out" 2>&1
  [ $? -eq 2 ] || return 1
  run layout "$d/v1" "$d/v2" --contract VaultV1 --new-contract VaultV2 > "$T/layout-pair.out" 2>&1 || return 1
  grep -Eq '^layout: compatible \(1 contract compared, 0 renamed\)$' "$T/layout-pair.out"
}
check "layout compares Foundry out folders contract by contract, leaving out tests, scripts, and build-info" layout_folders

abis() {
  python3 - "$1" <<'PYEOF'
import json, os, sys
root = sys.argv[1]
os.makedirs(root, exist_ok=True)
def fn(name, inputs, outputs=(), mut="nonpayable"):
    return {"type": "function", "name": name, "stateMutability": mut,
            "inputs": [{"name": "", "type": t, "internalType": t} for t in inputs],
            "outputs": [{"name": "", "type": t, "internalType": t} for t in outputs]}
def ev(name, params):
    return {"type": "event", "name": name, "anonymous": False,
            "inputs": [{"name": "p%d" % i, "type": t, "indexed": ix, "internalType": t} for i, (t, ix) in enumerate(params)]}
def err(name, inputs):
    return {"type": "error", "name": name, "inputs": [{"name": "", "type": t, "internalType": t} for t in inputs]}
order = {"type": "tuple", "name": "order", "internalType": "struct Vault.Order",
         "components": [{"name": "amount", "type": "uint256"}, {"name": "to", "type": "address"}]}
old = [fn("deposit", ["uint256"], ["bool"]), fn("withdraw", ["uint256"]), fn("balanceOf", ["address"], ["uint256"], "view"),
       fn("price", [], ["uint256"], "view"), {"type": "receive", "stateMutability": "payable"},
       {"type": "function", "name": "place", "stateMutability": "nonpayable", "inputs": [order], "outputs": []},
       ev("Deposited", [("address", True), ("uint256", False)]), ev("Withdrawn", [("address", True), ("uint256", False)]),
       err("Paused", []), err("Insufficient", ["uint256", "uint256"])]
added = old + [fn("pause", []), ev("PausedSet", [("bool", False)]), err("Cap", ["uint256"])]
changed = [fn("deposit", ["uint256"], ["uint256"]), fn("balanceOf", ["address"], ["uint256"], "view"),
           fn("price", [], ["uint256"]), fn("pause", []),
           {"type": "function", "name": "place", "stateMutability": "nonpayable", "inputs": [order], "outputs": []},
           ev("Deposited", [("address", True), ("uint256", True)]), ev("Withdrawn", [("address", True), ("uint256", False), ("uint256", False)]),
           err("Insufficient", ["uint256", "uint256"]), err("Cap", ["uint256"])]
json.dump(old, open(os.path.join(root, "old.json"), "w"), indent=2)
json.dump({"abi": added}, open(os.path.join(root, "added.json"), "w"), indent=2)
json.dump({"abi": changed}, open(os.path.join(root, "changed.json"), "w"), indent=2)
PYEOF
}

abi_changes() {
  local d="$T/abi"
  [ -f "$SCRIPT" ] || return 1
  abis "$d"
  run abi "$d/old.json" "$d/added.json" > "$T/abi-added.out" 2>&1 || return 1
  grep -Eq '^abi: compatible \(1 contract compared\)$' "$T/abi-added.out" || return 1
  run abi "$d/old.json" "$d/changed.json" > "$T/abi-changed.out" 2>&1
  [ $? -eq 1 ] || return 1
  grep -qx 'changed-function changed deposit(uint256) outputs (bool) -> (uint256)' "$T/abi-changed.out" \
    && grep -qx 'changed-function changed price() stateMutability view -> nonpayable' "$T/abi-changed.out" \
    && grep -qx 'removed-function changed withdraw(uint256)' "$T/abi-changed.out" \
    && grep -qx 'removed-function changed receive()' "$T/abi-changed.out" \
    && grep -qx 'changed-event changed Deposited(address,uint256) indexed (true,false) -> (true,true)' "$T/abi-changed.out" \
    && grep -qx 'removed-event changed Withdrawn(address,uint256)' "$T/abi-changed.out" \
    && grep -qx 'removed-error changed Paused()' "$T/abi-changed.out" \
    && ! grep -Eq 'balanceOf|place|Insufficient|pause\(|Cap\(' "$T/abi-changed.out" \
    && grep -Eq '^abi: 7 breaking changes in 1 contract compared$' "$T/abi-changed.out"
}
check "abi names removed or changed functions, events, and errors and passes added ones" abi_changes

# Bytecode: PUSH1 0x5f (push data, not an opcode), PUSH0, MCOPY, TLOAD, TSTORE, CLZ, BLOBHASH,
# BLOBBASEFEE, STOP, then solc's CBOR metadata, whose hash bytes hold 5e and 5f too.
METADATA="a2646970667358221220$(printf '5e5f%.0s' $(seq 1 16))64736f6c634300081e0033"
RUNTIME="605f5f5e5c5d1e494a00$METADATA"

foundry_artifact() {
  # foundry_artifact <file> <creation hex> <runtime hex>
  mkdir -p "$(dirname "$1")"
  printf '{"abi": [], "bytecode": {"object": "0x%s"}, "deployedBytecode": {"object": "0x%s"}}\n' "$2" "$3" > "$1"
}

opcodes_named() {
  local d="$T/op"
  [ -f "$SCRIPT" ] || return 1
  foundry_artifact "$d/out/Vault.sol/Vault.json" "6080604052$RUNTIME" "$RUNTIME"
  run opcodes "$d/out" --evm shanghai > "$T/op-shanghai.out" 2>&1
  [ $? -eq 1 ] || return 1
  grep -qx 'opcode Vault runtime MCOPY needs cancun' "$T/op-shanghai.out" \
    && grep -qx 'opcode Vault runtime TLOAD needs cancun' "$T/op-shanghai.out" \
    && grep -qx 'opcode Vault runtime TSTORE needs cancun' "$T/op-shanghai.out" \
    && grep -qx 'opcode Vault runtime BLOBHASH needs cancun' "$T/op-shanghai.out" \
    && grep -qx 'opcode Vault runtime BLOBBASEFEE needs cancun' "$T/op-shanghai.out" \
    && grep -qx 'opcode Vault runtime CLZ needs osaka' "$T/op-shanghai.out" \
    && ! grep -q 'PUSH0' "$T/op-shanghai.out" \
    && [ "$(grep -c '^opcode ' "$T/op-shanghai.out")" -eq 6 ] || return 1
  run opcodes "$d/out" --evm paris > "$T/op-paris.out" 2>&1
  [ $? -eq 1 ] && grep -qx 'opcode Vault runtime PUSH0 needs shanghai' "$T/op-paris.out" \
    && [ "$(grep -c '^opcode ' "$T/op-paris.out")" -eq 7 ] || return 1
  run opcodes "$d/out" --evm Osaka > "$T/op-osaka.out" 2>&1 || return 1
  ! grep -q '^opcode ' "$T/op-osaka.out" && grep -Eq '^opcodes: every opcode runs on osaka \(1 contract\)$' "$T/op-osaka.out"
}
check "opcodes names each opcode the target EVM version lacks, skipping push data and metadata" opcodes_named

opcodes_shapes() {
  local d="$T/shapes" plain init lib
  [ -f "$SCRIPT" ] || return 1
  plain="6001600201$(printf '00')"
  # The constructor stores into transient storage once; the runtime that follows is plain.
  init="60016000""5d""6080604052"
  foundry_artifact "$d/foundry/Guard.sol/Guard.json" "$init$plain" "$plain"
  # A Hardhat artifact with an unlinked library placeholder, its debug file, and build-info.
  lib="73__\$b5b2f3a4c1d0e9f8a7b6c5d4e3f2a1b0c9\$__5af4"
  mkdir -p "$d/hardhat/contracts/Pool.sol" "$d/hardhat/build-info"
  printf '{"_format": "hh-sol-artifact-1", "contractName": "Pool", "bytecode": "0x60806040%s5e00", "deployedBytecode": "0x%s5e00"}\n' "$lib" "$lib" \
    > "$d/hardhat/contracts/Pool.sol/Pool.json"
  printf '{"_format": "hh-sol-dbg-1", "buildInfo": "../../build-info/x.json"}\n' > "$d/hardhat/contracts/Pool.sol/Pool.dbg.json"
  printf '{"output": {"contracts": {}}}\n' > "$d/hardhat/build-info/x.json"
  run opcodes "$d/foundry" --evm shanghai > "$T/shape-foundry.out" 2>&1
  [ $? -eq 1 ] && grep -qx 'opcode Guard creation TSTORE needs cancun' "$T/shape-foundry.out" \
    && ! grep -q 'Guard runtime' "$T/shape-foundry.out" || return 1
  run opcodes "$d/hardhat" --evm shanghai > "$T/shape-hardhat.out" 2>&1
  [ $? -eq 1 ] && grep -qx 'opcode Pool runtime MCOPY needs cancun' "$T/shape-hardhat.out" \
    && ! grep -q 'Pool creation MCOPY' "$T/shape-hardhat.out" \
    && grep -Eq '^opcodes: .* in 1 contract$' "$T/shape-hardhat.out" || return 1
  run opcodes "$d/foundry/Guard.sol/Guard.json" --evm cancun > "$T/shape-file.out" 2>&1 || return 1
  run opcodes "$d/foundry" --evm fusaka2 > "$T/shape-unknown.out" 2>&1
  [ $? -eq 2 ] && grep -q 'osaka' "$T/shape-unknown.out"
}
check "opcodes reads Foundry and Hardhat artifacts, checks creation code, and refuses an unknown EVM version" opcodes_shapes

no_urls() {
  [ "$(find "$ITEMS" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')" -ge 5 ] || return 1
  ! grep -rIlE 'https?://|www\.' "$ITEMS" > /dev/null || return 1
  ! grep -rL '^source: .\{8,\}' "$ITEMS" | grep -q .
}
check "no release-check item holds a URL" no_urls

skill_rules() {
  local phrase
  [ -f "$SKILL" ] || return 1
  for phrase in \
    'Read the versions with the solidity-code skill' \
    'Run `list`' \
    're-check it against the official document' \
    '`git worktree add`' \
    '`--extra-output storageLayout`' \
    'Run `layout`' \
    'Run `abi`' \
    'Run `opcodes`' \
    '`npx @openzeppelin/upgrades-core validate`' \
    '`@custom:storage-location`' \
    '`forge snapshot --diff`' \
    '`forge build --sizes`' \
    'EIP-7825' \
    'use the evm-standards skill' \
    'the solidity-code skill' \
    'Remove the temporary worktree' \
    'Never read a private key or a mnemonic' \
    'never sign' \
    'refuse a command that passes a key' \
    'Never read `.env` files' \
    'Never edit the items in the plugin'; do
    grep -qF -- "$phrase" "$SKILL" || return 1
  done
}
check "the release-check SKILL.md keeps its rules" skill_rules

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
check "the release-check SKILL.md stays within its size limits" skill_size

# Each case has a case.yaml and an executable fixture.sh that runs the way claude plugin eval runs it
# (in home/cwd with HOME at home). The upgrade case holds the deployed version's layout and ABI and a
# build whose layout breaks; the opcodes case holds a build that a Shanghai chain cannot run.
CASES=(upgrade-layout-check chain-opcodes-check release-unrelated-request)
eval_suite() {
  local c home
  for c in "${CASES[@]}"; do
    [ -f "$EVALS/$c/case.yaml" ] && [ -x "$EVALS/$c/fixture.sh" ] || return 1
    home="$T/fixture-$c/home"
    mkdir -p "$home/cwd"
    (cd "$home/cwd" && HOME="$home" bash "$EVALS/$c/fixture.sh") > /dev/null 2>&1 || return 1
    [ -s "$home/cwd/foundry.toml" ] && [ -s "$home/cwd/src/Vault.sol" ] && [ -s "$home/cwd/out/Vault.sol/Vault.json" ] || return 1
    case "$c" in
      upgrade-layout-check)
        run layout "$home/cwd/snapshots/Vault.storage.json" "$home/cwd/out/Vault.sol/Vault.json" > /dev/null 2>&1
        [ $? -eq 1 ] || return 1
        run abi "$home/cwd/snapshots/Vault.abi.json" "$home/cwd/out/Vault.sol/Vault.json" > /dev/null 2>&1
        [ $? -eq 1 ] || return 1 ;;
      chain-opcodes-check)
        run opcodes "$home/cwd/out" --evm shanghai > /dev/null 2>&1
        [ $? -eq 1 ] || return 1 ;;
      release-unrelated-request)
        grep -q 'name: skill-not-loaded' "$EVALS/$c/case.yaml" && grep -q "input_match: 'release-check'" "$EVALS/$c/case.yaml" || return 1
        continue ;;
    esac
    grep -q 'name: skill-fired' "$EVALS/$c/case.yaml" && grep -q "input_match: 'release-check'" "$EVALS/$c/case.yaml" || return 1
  done
  git -C "$PLUGIN" check-ignore -q "evals/results/run.json"
}
check "the eval suite has its release-check cases and each fixture builds its state" eval_suite

readmes_list() {
  grep -qF '/evm-dev:release-check' "$REPO/README.md" && grep -qF '/evm-dev:release-check' "$REPO/README.ja.md"
}
check "the root READMEs list /evm-dev:release-check" readmes_list

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
    && bash "$PLUGIN/skills/wallet-design/tests/test-wallet-design.sh" > "$T/wallet-design.out" 2>&1 \
    && bash "$PLUGIN/skills/dapp-architecture/tests/test-dapp-architecture.sh" > "$T/dapp-architecture.out" 2>&1 \
    && bash "$PLUGIN/skills/multichain-design/tests/test-multichain-design.sh" > "$T/multichain-design.out" 2>&1 \
    && bash "$PLUGIN/skills/contract-deploy/tests/test-contract-deploy.sh" > "$T/contract-deploy.out" 2>&1
}
check "the other evm-dev skills still pass their tests with release-check" others_kept

printf '%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
