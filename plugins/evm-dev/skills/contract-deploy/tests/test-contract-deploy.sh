#!/usr/bin/env bash
# Tests for contract-deploy.py, the bundled items, the SKILL.md, and the eval suite. Projects,
# deployment records, and items written here live in a throwaway folder; nothing reaches the network,
# nothing runs forge or Hardhat, and the key-shaped strings are built here from repeated letters, so
# no real key is written anywhere.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
SCRIPT="$SKILL_DIR/scripts/contract-deploy.py"
ITEMS="$SKILL_DIR/references/items"
SKILL="$SKILL_DIR/SKILL.md"
PLUGIN="$(cd "$SKILL_DIR/../.." && pwd)"
REPO="$(cd "$PLUGIN/../.." && pwd)"
EVALS="$PLUGIN/evals"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'chmod -R u+rwX "$T" 2>/dev/null; rm -rf "$T"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }

run() { python3 "$SCRIPT" "$@"; }

TOPICS=(keys records verification)
# A key-shaped value (64 hex digits) and a mnemonic-shaped value (12 lowercase words), made of
# repeated letters so that they are not keys.
KEYHEX="$(printf 'ab%.0s' $(seq 1 32))"
WORDS="$(printf 'word%.0s ' $(seq 1 11))junk"

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

# line_of <file> <text>: the number of the first line of <file> that holds <text>.
line_of() { grep -nF -- "$2" "$1" | head -1 | cut -d: -f1; }

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
check "check passes on the bundled contract-deploy items and covers every topic" bundled_check

bad_items_named() {
  local d="$T/bad" code
  item "$d" good-item 'topic: keys' 'subject: A keystore' 'checked: 2026-11-01' 'source: The tool, documentation'
  item "$d" no-source 'topic: records' 'subject: A deployment record' 'checked: 2026-11-01'
  item "$d" no-subject 'topic: verification' 'checked: 2026-11-01' 'source: The explorer, documentation'
  item "$d" unknown-topic 'topic: gas' 'subject: Gas prices' 'checked: 2026-11-01' 'source: The tool'
  item "$d" bad-date 'topic: keys' 'subject: A hardware wallet' 'checked: 2026-02-30' 'source: The vendor, guide'
  run check --dir "$d" > "$T/bad.out" 2>&1
  code=$?
  [ "$code" -eq 1 ] || return 1
  grep -q 'no-source' "$T/bad.out" && grep -q 'no-subject' "$T/bad.out" && grep -q 'unknown-topic' "$T/bad.out" \
    && grep -q 'bad-date' "$T/bad.out" && ! grep -q 'good-item' "$T/bad.out"
}
check "check names a contract-deploy item with a missing field, an unknown topic, or an impossible date" bad_items_named

# Counted to 2026-05-01: 2026-01-31 is exactly 90 days old (still ok), 2026-01-30 is 91 (stale).
stale_marked() {
  local d="$T/stale"
  item "$d" edge-item 'topic: keys' 'subject: Encrypted keystore' 'checked: 2026-01-31' 'source: The tool, documentation'
  item "$d" old-item 'topic: verification' 'subject: Explorer API' 'checked: 2026-01-30' 'source: The explorer, changelog'
  run list --dir "$d" --today 2026-05-01 > "$T/list.out" 2>&1 || return 1
  grep -Eq '^ok +keys +2026-01-31 +edge-item +Encrypted keystore$' "$T/list.out" \
    && grep -Eq '^stale +verification +2026-01-30 +old-item +Explorer API$' "$T/list.out" \
    && grep -Eq '^2 items, 1 stale as of 2026-05-01$' "$T/list.out"
}
check "list marks the contract-deploy items checked more than 90 days ago" stale_marked

# A project that handles keys in every way the skill must name.
leaky_project() {
  local p="$1"
  mkdir -p "$p/script" "$p/src" "$p/scripts"
  printf '[profile.default]\nsrc = "src"\n\n[etherscan]\nsepolia = { key = "${ETHERSCAN_API_KEY}" }\n' > "$p/foundry.toml"
  cat > "$p/script/Deploy.s.sol" <<'SOL'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);
        vm.stopBroadcast();
    }
}
SOL
  cat > "$p/script/Hardcoded.s.sol" <<SOL
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Hardcoded {
    uint256 constant DEPLOYER_PRIVATE_KEY = 0x$KEYHEX;
}
SOL
  cat > "$p/Makefile" <<'MK'
# Deploy targets.
deploy-sepolia:
	forge script script/Deploy.s.sol --rpc-url sepolia --broadcast --private-key $(PRIVATE_KEY)

deploy-base:
	forge script script/Deploy.s.sol --rpc-url base --broadcast --mnemonics words.txt --password hunter2
MK
  cat > "$p/scripts/deploy.sh" <<'SH'
#!/bin/sh
forge script script/Deploy.s.sol --broadcast --private-key "$DEPLOYER_PRIVATE_KEY"
SH
  cat > "$p/hardhat.config.ts" <<TS
import { defineConfig } from "hardhat/config";

export default defineConfig({
  networks: {
    sepolia: { type: "http", url: "https://rpc.example", accounts: [process.env.SEPOLIA_PRIVATE_KEY!] },
    local: { type: "http", url: "http://127.0.0.1:8545", accounts: { mnemonic: "$WORDS" } },
  },
});
TS
}

keys_named() {
  local p="$T/leaky" code
  leaky_project "$p"
  run keys "$p" > "$T/keys.out" 2>&1
  code=$?
  [ "$code" -eq 1 ] || return 1
  grep -qx "env-key script/Deploy.s.sol:$(line_of "$p/script/Deploy.s.sol" 'vm.envUint')" "$T/keys.out" \
    && grep -qx "key-literal script/Hardcoded.s.sol:$(line_of "$p/script/Hardcoded.s.sol" 'DEPLOYER_PRIVATE_KEY')" "$T/keys.out" \
    && grep -qx "key-flag Makefile:$(line_of "$p/Makefile" '--private-key')" "$T/keys.out" \
    && grep -qx "env-key Makefile:$(line_of "$p/Makefile" '--private-key')" "$T/keys.out" \
    && grep -qx "key-flag Makefile:$(line_of "$p/Makefile" '--mnemonics')" "$T/keys.out" \
    && grep -qx "key-flag scripts/deploy.sh:$(line_of "$p/scripts/deploy.sh" '--private-key')" "$T/keys.out" \
    && grep -qx "env-key scripts/deploy.sh:$(line_of "$p/scripts/deploy.sh" '--private-key')" "$T/keys.out" \
    && grep -qx "env-key hardhat.config.ts:$(line_of "$p/hardhat.config.ts" 'process.env')" "$T/keys.out" \
    && grep -qx "key-literal hardhat.config.ts:$(line_of "$p/hardhat.config.ts" 'mnemonic')" "$T/keys.out" \
    && ! grep -q 'foundry.toml' "$T/keys.out" \
    && ! grep -q 'Makefile:1$' "$T/keys.out" \
    && ! grep -qF "$KEYHEX" "$T/keys.out" && ! grep -qF 'word word' "$T/keys.out" && ! grep -qF 'hunter2' "$T/keys.out"
}
check "keys names each key read from the environment, key flag, and key literal by file and line without printing the value" keys_named

# A project that signs with an encrypted keystore or a Ledger. Key-shaped values sit only where the
# script must not look: .env files, Foundry's cache/, lib/, and node_modules/. A salt is 64 hex
# digits too, but nothing on its line speaks of a key.
clean_project() {
  local p="$1"
  mkdir -p "$p/script" "$p/src" "$p/lib/forge-std/src" "$p/node_modules/pkg" "$p/cache/Deploy.s.sol/1"
  printf '[profile.default]\nsrc = "src"\n' > "$p/foundry.toml"
  cat > "$p/script/Deploy.s.sol" <<SOL
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";

// Never pass --private-key; sign with --account or --ledger.
contract Deploy is Script {
    bytes32 constant SALT = 0x$KEYHEX;

    function run() external {
        vm.startBroadcast();
        vm.stopBroadcast();
    }
}
SOL
  cat > "$p/Makefile" <<'MK'
# Never use --private-key here.
deploy-sepolia:
	forge script script/Deploy.s.sol --rpc-url sepolia --broadcast --account deployer --sender $(SENDER)

deploy-mainnet:
	forge script script/Deploy.s.sol --rpc-url mainnet --broadcast --ledger --slow --password-file pw.txt
MK
  cat > "$p/hardhat.config.ts" <<'TS'
import { configVariable, defineConfig } from "hardhat/config";

export default defineConfig({
  networks: {
    sepolia: { type: "http", url: configVariable("SEPOLIA_RPC_URL"), accounts: [configVariable("SEPOLIA_PRIVATE_KEY")] },
  },
});
TS
  printf 'PRIVATE_KEY=0x%s\nMNEMONIC="%s"\n' "$KEYHEX" "$WORDS" > "$p/.env"
  printf 'PRIVATE_KEY=0x%s\n' "$KEYHEX" > "$p/.env.example"
  printf '{"transactions":[{"rpc":"https://rpc.example/%s"}],"private_key":"0x%s"}\n' "$KEYHEX" "$KEYHEX" > "$p/cache/Deploy.s.sol/1/run-latest.json"
  printf 'contract L { uint256 constant PRIVATE_KEY = 0x%s; function f() external { vm.envUint("PRIVATE_KEY"); } }\n' "$KEYHEX" > "$p/lib/forge-std/src/Leak.sol"
  printf 'module.exports = { accounts: [process.env.PRIVATE_KEY], key: "0x%s" };\n' "$KEYHEX" > "$p/node_modules/pkg/index.js"
}

keys_clean() {
  local p="$T/clean"
  clean_project "$p"
  run keys "$p" > "$T/keys-clean.out" 2>&1 || return 1
  ! grep -Eq '^(env-key|key-flag|key-literal|env-file) ' "$T/keys-clean.out" \
    && ! grep -qF "$KEYHEX" "$T/keys-clean.out"
}
check "keys passes a project that signs with --account or --ledger and never opens .env files or cache/" keys_clean

env_files_named() {
  local p="$T/envgit"
  command -v git > /dev/null || return 1
  clean_project "$p"
  rm -f "$p/.env"
  printf 'X=1\n' > "$p/.env"
  printf 'X=1\n' > "$p/.env.local"
  printf 'X=1\n' > "$p/.env.production"
  printf '.env.production\ncache/\nout/\n' > "$p/.gitignore"
  git -C "$p" init -q || return 1
  git -C "$p" add -f .env .gitignore || return 1
  run keys "$p" > "$T/keys-env.out" 2>&1
  [ $? -eq 1 ] || return 1
  grep -Eq '^env-file \.env \(tracked by git\)$' "$T/keys-env.out" \
    && grep -Eq '^env-file \.env\.local \(not ignored by git\)$' "$T/keys-env.out" \
    && ! grep -q '\.env\.production' "$T/keys-env.out" \
    && ! grep -q '\.env\.example' "$T/keys-env.out"
}
check "keys names an env file that git tracks or does not ignore" env_files_named

# Per-chain settings that a deploy script reads with vm.readFile: a key under a field named for it, a
# key in an accounts list on its own line, and a mnemonic one level down.
json_keys_project() {
  local p="$1"
  mkdir -p "$p/config" "$p/script"
  printf '[profile.default]\nsrc = "src"\nfs_permissions = [{ access = "read", path = "./config" }]\n' > "$p/foundry.toml"
  cat > "$p/config/11155111.json" <<JSON
{
  "owner": "0x00000000000000000000000000000000000000a1",
  "deployerPrivateKey": "0x$KEYHEX",
  "accounts": [
    "0x$KEYHEX"
  ]
}
JSON
  cat > "$p/config/84532.json" <<JSON
{
  "owner": "0x00000000000000000000000000000000000000b2",
  "signer": {
    "mnemonic": "$WORDS"
  }
}
JSON
}

keys_in_json() {
  local p="$T/json-keys" out="$T/keys-json.out" code
  json_keys_project "$p"
  run keys "$p" > "$out" 2>&1
  code=$?
  [ "$code" -eq 1 ] || return 1
  grep -qx "key-literal config/11155111.json:$(line_of "$p/config/11155111.json" 'deployerPrivateKey')" "$out" \
    && grep -qx "key-literal config/11155111.json:$(( $(line_of "$p/config/11155111.json" '"accounts"') + 1 ))" "$out" \
    && grep -qx "key-literal config/84532.json:$(line_of "$p/config/84532.json" '"mnemonic"')" "$out" \
    && ! grep -Eq '^(env-key|key-flag) config/' "$out" \
    && [ "$(grep -c '^key-literal config/' "$out")" -eq 3 ] \
    && ! grep -qF "$KEYHEX" "$out" && ! grep -qF 'word word' "$out"
}
check "keys names a key or a mnemonic written in a JSON file by file and line without printing it" keys_in_json

# Settings with addresses, a salt, and a transaction hash, each 40 or 64 hex digits under a field that
# does not speak of a key.
keys_json_clean() {
  local p="$T/json-clean" out="$T/keys-json-clean.out"
  mkdir -p "$p/config"
  printf '[profile.default]\nsrc = "src"\n' > "$p/foundry.toml"
  cat > "$p/config/1.json" <<JSON
{
  "owner": "0x00000000000000000000000000000000000000c3",
  "salt": "0x$KEYHEX",
  "deployed": {
    "points": "0x00000000000000000000000000000000000000d4",
    "txHash": "0x$KEYHEX"
  }
}
JSON
  run keys "$p" > "$out" 2>&1 || return 1
  ! grep -Eq '^(env-key|key-flag|key-literal|env-file) ' "$out" && ! grep -qF "$KEYHEX" "$out"
}
check "keys does not name addresses or hashes in a JSON file" keys_json_clean

# Deployment records. The Foundry run file follows what forge 1.5 writes: transactions with their
# hashes and receipts listed separately. The Ignition journal follows the message types of
# ignition-core 3: one JSON object per line, the first line empty, numbers too big for JSON written as
# {"_kind": "bigint"}.
records_project() {
  local p="$1" mode="$2"
  python3 - "$p" "$mode" <<'PYEOF'
import json, os, sys
root, mode = sys.argv[1], sys.argv[2]
def h(n):
    return "0x" + ("%064x" % n)
def a(n):
    return "0x" + ("%040x" % n)
DEPLOYER = a(0xD0)

def tx(n, kind, name, address, fn=None, to=None):
    t = {"from": DEPLOYER, "gas": "0x3aa99", "value": "0x0", "nonce": hex(n), "chainId": "0xaa36a7"}
    if to:
        t["to"] = to
    return {"hash": h(n), "transactionType": kind, "contractName": name, "contractAddress": address,
            "function": fn, "arguments": [], "transaction": t, "additionalContracts": [],
            "isFixedGasLimit": False}

def receipt(n, block, status="0x1", created=None, to=None):
    return {"status": status, "transactionHash": h(n), "blockNumber": hex(block), "from": DEPLOYER,
            "to": to, "contractAddress": created, "gasUsed": "0x2d200"}

def write(path, data, lines=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        if lines:
            for message in data:
                f.write("\n" + json.dumps(message, sort_keys=True))
        else:
            json.dump(data, f, indent=2)

def run_file(transactions, receipts, pending=()):
    return {"transactions": transactions, "receipts": receipts, "libraries": [], "pending": list(pending),
            "returns": {}, "timestamp": 1794881159088, "chain": 11155111, "commit": "abc1234"}

ok_txs = [tx(1, "CREATE", "Vault", a(0x11)),
          tx(2, "CALL", "Vault", a(0x11), fn="transferOwnership(address)", to=a(0x11)),
          tx(3, "CREATE2", "Registry", a(0x33), to="0x4e59b44847b379578588920ca78fbf26c0b4956c")]
ok_txs[0]["additionalContracts"] = [{"transactionType": "CREATE", "contractName": "Child", "address": a(0x12), "initCode": "0x00"}]
ok_receipts = [receipt(2, 6, to=a(0x11)), receipt(1, 5, created=a(0x11)),
               receipt(3, 7, to="0x4e59b44847b379578588920ca78fbf26c0b4956c")]
journal = [{"type": "DEPLOYMENT_INITIALIZE", "chainId": 84532},
           {"type": "RUN_START", "chainId": 84532},
           {"type": "DEPLOYMENT_EXECUTION_STATE_INITIALIZE", "futureId": "VaultModule#Vault", "futureType": "NAMED_ARTIFACT_CONTRACT_DEPLOYMENT",
            "strategy": "basic", "strategyConfig": {}, "dependencies": [], "artifactId": "VaultModule#Vault", "contractName": "Vault",
            "constructorArgs": [], "libraries": {}, "value": {"_kind": "bigint", "value": "0"}, "from": DEPLOYER},
           {"type": "NETWORK_INTERACTION_REQUEST", "futureId": "VaultModule#Vault", "networkInteraction": {"id": 1, "type": "ONCHAIN_INTERACTION"}},
           {"type": "TRANSACTION_PREPARE_SEND", "futureId": "VaultModule#Vault", "networkInteractionId": 1, "nonce": 0},
           {"type": "TRANSACTION_SEND", "futureId": "VaultModule#Vault", "networkInteractionId": 1, "nonce": 0,
            "transaction": {"hash": h(0x41), "fees": {"maxFeePerGas": {"_kind": "bigint", "value": "2"}, "maxPriorityFeePerGas": {"_kind": "bigint", "value": "1"}}}},
           {"type": "TRANSACTION_CONFIRM", "futureId": "VaultModule#Vault", "networkInteractionId": 1, "hash": h(0x41),
            "receipt": {"blockHash": h(0x99), "blockNumber": 21, "contractAddress": a(0x41), "status": "SUCCESS", "logs": []}},
           {"type": "DEPLOYMENT_EXECUTION_STATE_COMPLETE", "futureId": "VaultModule#Vault", "result": {"type": "SUCCESS", "address": a(0x41)}}]

if mode == "ok":
    write(os.path.join(root, "broadcast/Deploy.s.sol/11155111/run-latest.json"), run_file(ok_txs, ok_receipts))
    write(os.path.join(root, "ignition/deployments/chain-84532/journal.jsonl"), journal, lines=True)
    write(os.path.join(root, "ignition/deployments/chain-84532/deployed_addresses.json"), {"VaultModule#Vault": a(0x41)})
elif mode == "problems":
    bad_txs = [tx(4, "CREATE", "Token", a(0x44)), tx(5, "CREATE", "Pool", a(0x55)), tx(6, "CREATE", "Swapped", a(0x66)),
               tx(7, "CALL", "Token", a(0x44), fn="mint(address,uint256)", to=a(0x44))]
    # Token's deployment reverted; Pool was sent but never got a receipt; Swapped's receipt is the
    # receipt of a call, so it does not show Swapped being created.
    bad_receipts = [receipt(4, 8, status="0x0", created=None), receipt(6, 9, to=a(0x44)), receipt(7, 10, status="0x0", to=a(0x44))]
    write(os.path.join(root, "broadcast/Upgrade.s.sol/11155111/run-latest.json"), run_file(bad_txs, bad_receipts, pending=[h(5)]))
    more = journal[:2] + [
        {"type": "DEPLOYMENT_EXECUTION_STATE_INITIALIZE", "futureId": "VaultModule#Oracle", "contractName": "Oracle", "from": DEPLOYER,
         "futureType": "NAMED_ARTIFACT_CONTRACT_DEPLOYMENT", "strategy": "basic", "strategyConfig": {}, "dependencies": [],
         "artifactId": "VaultModule#Oracle", "constructorArgs": [], "libraries": {}, "value": {"_kind": "bigint", "value": "0"}},
        {"type": "TRANSACTION_SEND", "futureId": "VaultModule#Oracle", "networkInteractionId": 1, "nonce": 1,
         "transaction": {"hash": h(0x42), "fees": {}}},
        {"type": "DEPLOYMENT_EXECUTION_STATE_INITIALIZE", "futureId": "VaultModule#Router", "contractName": "Router", "from": DEPLOYER,
         "futureType": "NAMED_ARTIFACT_CONTRACT_DEPLOYMENT", "strategy": "basic", "strategyConfig": {}, "dependencies": [],
         "artifactId": "VaultModule#Router", "constructorArgs": [], "libraries": {}, "value": {"_kind": "bigint", "value": "0"}},
        {"type": "TRANSACTION_SEND", "futureId": "VaultModule#Router", "networkInteractionId": 1, "nonce": 2,
         "transaction": {"hash": h(0x43), "fees": {}}},
        {"type": "TRANSACTION_CONFIRM", "futureId": "VaultModule#Router", "networkInteractionId": 1, "hash": h(0x43),
         "receipt": {"blockHash": h(0x98), "blockNumber": 22, "status": "FAILURE", "logs": []}},
        {"type": "DEPLOYMENT_EXECUTION_STATE_COMPLETE", "futureId": "VaultModule#Router", "result": {"type": "REVERTED_TRANSACTION", "error": "reverted"}}]
    write(os.path.join(root, "ignition/deployments/chain-84532/journal.jsonl"), more, lines=True)
elif mode == "dry":
    write(os.path.join(root, "broadcast/Deploy.s.sol/11155111/run-latest.json"), run_file(ok_txs, ok_receipts))
    dry = run_file([tx(8, "CREATE", "DryOnly", a(0x88))], [])
    write(os.path.join(root, "broadcast/Deploy.s.sol/11155111/dry-run/run-latest.json"), dry)
    write(os.path.join(root, "cache/Deploy.s.sol/11155111/run-latest.json"), {"transactions": [{"rpc": "https://rpc.example/SECRET_RPC_MARKER"}]})
PYEOF
}

addr() { printf '0x%040x' "$1"; }
hash() { printf '0x%064x' "$1"; }

record_built() {
  local p="$T/rec-ok" deployer
  mkdir -p "$p"
  records_project "$p" ok || return 1
  deployer="$(addr 208)"
  run record "$p" --write > "$T/record.out" 2>&1 || return 1
  grep -qx "contract 11155111 Vault $(addr 17) tx $(hash 1) block 5 from $deployer source foundry:Deploy.s.sol" "$T/record.out" \
    && grep -qx "contract 11155111 Child $(addr 18) tx $(hash 1) block 5 from $deployer source foundry:Deploy.s.sol" "$T/record.out" \
    && grep -qx "contract 11155111 Registry $(addr 51) tx $(hash 3) block 7 from $deployer source foundry:Deploy.s.sol" "$T/record.out" \
    && grep -qx "contract 84532 Vault $(addr 65) tx $(hash 65) block 21 from $deployer source ignition:chain-84532" "$T/record.out" \
    && ! grep -q 'transferOwnership' "$T/record.out" || return 1
  python3 - "$p" "$(addr 17)" "$(addr 65)" <<'PYEOF'
import json, sys
root, vault, ignition_vault = sys.argv[1:4]
sepolia = json.load(open(root + "/deployments/11155111.json"))
base = json.load(open(root + "/deployments/84532.json"))
assert sepolia["format"] == 1 and sepolia["chainId"] == 11155111 and sepolia["problems"] == []
names = sorted(c["name"] for c in sepolia["contracts"])
assert names == ["Child", "Registry", "Vault"], names
vault_entry = [c for c in sepolia["contracts"] if c["name"] == "Vault"][0]
assert vault_entry["address"] == vault and vault_entry["block"] == 5 and vault_entry["commit"] == "abc1234"
assert vault_entry["source"] == "foundry:Deploy.s.sol" and vault_entry["tx"].endswith("01")
assert base["format"] == 1 and base["chainId"] == 84532
assert [c["address"] for c in base["contracts"]] == [ignition_vault] and base["contracts"][0]["commit"] is None
PYEOF
}
check "record builds one record per chain from Foundry broadcast files and Ignition journals" record_built

record_problems() {
  local p="$T/rec-bad"
  mkdir -p "$p"
  records_project "$p" problems || return 1
  run record "$p" > "$T/record-bad.out" 2>&1
  [ $? -eq 1 ] || return 1
  grep -qx "failed 11155111 Token tx $(hash 4) source foundry:Upgrade.s.sol" "$T/record-bad.out" \
    && grep -qx "pending 11155111 Pool tx $(hash 5) source foundry:Upgrade.s.sol" "$T/record-bad.out" \
    && grep -qx "mismatch 11155111 Swapped tx $(hash 6) source foundry:Upgrade.s.sol" "$T/record-bad.out" \
    && grep -qx "failed 11155111 Token tx $(hash 7) source foundry:Upgrade.s.sol" "$T/record-bad.out" \
    && grep -qx "pending 84532 Oracle tx $(hash 66) source ignition:chain-84532" "$T/record-bad.out" \
    && grep -qx "failed 84532 Router tx $(hash 67) source ignition:chain-84532" "$T/record-bad.out" \
    && ! grep -q '^contract ' "$T/record-bad.out"
}
check "record names failed, pending, and mismatched transactions and exits 1" record_problems

record_dry_cache() {
  local p="$T/rec-dry"
  mkdir -p "$p"
  records_project "$p" dry || return 1
  chmod 000 "$p/cache/Deploy.s.sol/11155111/run-latest.json"
  run record "$p" > "$T/record-dry.out" 2>&1 || return 1
  grep -q '^contract 11155111 Vault ' "$T/record-dry.out" \
    && ! grep -q 'DryOnly' "$T/record-dry.out" && ! grep -q 'SECRET_RPC_MARKER' "$T/record-dry.out" \
    && ! grep -qi 'permission' "$T/record-dry.out"
}
check "record skips dry runs and never reads cache/" record_dry_cache

# commit_project <folder>: a git repository with one commit (a contract, a script, a test, and
# foundry.toml) and a Foundry run file that names that commit and was written 500 seconds ago, as
# forge writes it: the short hash in `commit`, milliseconds in `timestamp`. Prints the short hash.
commit_project() {
  local p="$1"
  mkdir -p "$p/src" "$p/script" "$p/test"
  printf '[profile.default]\nsrc = "src"\n' > "$p/foundry.toml"
  printf 'contract Vault { uint256 public total; }\n' > "$p/src/Vault.sol"
  printf 'contract Deploy { function run() external {} }\n' > "$p/script/Deploy.s.sol"
  printf 'contract VaultTest { function test_total() public {} }\n' > "$p/test/Vault.t.sol"
  git -C "$p" init -q || return 1
  git -C "$p" add -A || return 1
  git -C "$p" -c user.name=test -c user.email=test -c commit.gpgsign=false -c core.hooksPath=/dev/null \
    commit -q -m "first" || return 1
  python3 - "$p" "$(git -C "$p" rev-parse --short HEAD)" <<'PYEOF'
import json, os, sys, time
root, commit = sys.argv[1], sys.argv[2]
sent = time.time() - 500
tx = {"hash": "0x" + "%064x" % 1, "transactionType": "CREATE", "contractName": "Vault",
      "contractAddress": "0x" + "%040x" % 0x11, "transaction": {"from": "0x" + "%040x" % 0xD0}, "additionalContracts": []}
receipt = {"status": "0x1", "transactionHash": tx["hash"], "blockNumber": "0x5", "contractAddress": tx["contractAddress"]}
run = {"transactions": [tx], "receipts": [receipt], "pending": [], "chain": 11155111,
       "commit": commit, "timestamp": int(sent * 1000)}
path = os.path.join(root, "broadcast/Deploy.s.sol/11155111/run-latest.json")
os.makedirs(os.path.dirname(path))
json.dump(run, open(path, "w"), indent=2)
print(commit)
PYEOF
}

# touch_at <file> <seconds from now>: sets the file's modification time.
touch_at() { python3 -c 'import os, sys, time; t = time.time() + int(sys.argv[2]); os.utime(sys.argv[1], (t, t))' "$1" "$2"; }

record_commit_differs() {
  local p="$T/rec-commit" out="$T/record-commit.out" commit
  command -v git > /dev/null || return 1
  commit="$(commit_project "$p")" || return 1
  # The contract and foundry.toml changed 1000 seconds ago, before the broadcast, and stayed that way.
  printf 'contract Vault { uint256 public total; uint256 public cap; }\n' > "$p/src/Vault.sol"
  printf '[profile.default]\nsrc = "src"\noptimizer = true\n' > "$p/foundry.toml"
  touch_at "$p/src/Vault.sol" -1000
  touch_at "$p/foundry.toml" -1000
  run record "$p" --write > "$out" 2>&1
  [ $? -eq 1 ] || return 1
  grep -q "^commit-differs 11155111 $commit source foundry:Deploy.s.sol " "$out" \
    && grep '^commit-differs ' "$out" | grep -q 'src/Vault.sol' \
    && grep '^commit-differs ' "$out" | grep -q 'foundry.toml' \
    && grep -q "^contract 11155111 Vault " "$out" || return 1
  python3 - "$p/deployments/11155111.json" "$commit" <<'PYEOF'
import json, sys
record = json.load(open(sys.argv[1]))
found = [p for p in record["problems"] if p["kind"] == "commit-differs"]
assert len(found) == 1, record["problems"]
assert found[0]["source"] == "foundry:Deploy.s.sol" and found[0]["commit"] == sys.argv[2], found
assert sorted(found[0]["files"]) == ["foundry.toml", "src/Vault.sol"], found
PYEOF
}
check "record names a run whose commit differs from files changed before the broadcast" record_commit_differs

record_commit_kept() {
  local p="$T/rec-commit-kept" out="$T/record-commit-kept.out"
  command -v git > /dev/null || return 1
  commit_project "$p" > /dev/null || return 1
  # A test changed before the broadcast; the contract and a new script changed after it.
  printf 'contract VaultTest { function test_total() public {} function test_cap() public {} }\n' > "$p/test/Vault.t.sol"
  touch_at "$p/test/Vault.t.sol" -1000
  printf 'contract Vault { uint256 public total; uint256 public cap; }\n' > "$p/src/Vault.sol"
  printf 'contract Other { function run() external {} }\n' > "$p/script/Other.s.sol"
  touch_at "$p/src/Vault.sol" -100
  touch_at "$p/script/Other.s.sol" -100
  run record "$p" > "$out" 2>&1 || return 1
  ! grep -q '^commit-differs ' "$out" && grep -q "^contract 11155111 Vault " "$out"
}
check "record does not name files changed after the broadcast or under test/" record_commit_kept

no_urls() {
  [ "$(find "$ITEMS" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')" -ge 5 ] || return 1
  ! grep -rIlE 'https?://|www\.' "$ITEMS" > /dev/null || return 1
  ! grep -rL '^source: .\{8,\}' "$ITEMS" | grep -q .
}
check "no contract-deploy item holds a URL" no_urls

skill_rules() {
  local phrase
  [ -f "$SKILL" ] || return 1
  for phrase in \
    'Read the versions with the solidity-code skill' \
    'Run `list`' \
    're-check it against the official document' \
    '`vm.startBroadcast()` with no argument' \
    'Simulate first' \
    'Run `keys`' \
    '`--ledger` or `--trezor`' \
    '`cast wallet import`' \
    '`--account`' \
    '`configVariable`' \
    '`--slow`' \
    'The user runs the command that broadcasts' \
    'Run `record` with the project root and `--write`' \
    '`cast code`' \
    '`forge verify-contract`' \
    '`ignition verify`' \
    'use the evm-standards skill' \
    'the solidity-code skill' \
    'Never read a private key, a mnemonic, or a password' \
    'never sign' \
    'refuse a command that passes `--private-key`, `--mnemonic`, or `--password`' \
    'Never read `.env` files' \
    'the `cache/` folder' \
    'Never edit the items in the plugin'; do
    grep -qF -- "$phrase" "$SKILL" || return 1
  done
}
check "the contract-deploy SKILL.md keeps its rules" skill_rules

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
check "the contract-deploy SKILL.md stays within its size limits" skill_size

# Each case has a case.yaml and an executable fixture.sh that runs the way claude plugin eval runs it
# (in home/cwd with HOME at home). Every fixture builds a Foundry project with no key in it; the
# record case also holds broadcast files, and the unrelated case grades that the skill did not start.
CASES=(foundry-deploy-script deployment-record deploy-unrelated-request)
eval_suite() {
  local c home
  for c in "${CASES[@]}"; do
    [ -f "$EVALS/$c/case.yaml" ] && [ -x "$EVALS/$c/fixture.sh" ] || return 1
    home="$T/fixture-$c/home"
    mkdir -p "$home/cwd"
    (cd "$home/cwd" && HOME="$home" bash "$EVALS/$c/fixture.sh") > /dev/null 2>&1 || return 1
    [ -s "$home/cwd/foundry.toml" ] && [ -s "$home/cwd/src/Vault.sol" ] || return 1
    ! find "$home/cwd" -name '.env*' | grep -q . || return 1
    run keys "$home/cwd" > "$T/fixture-$c.keys" 2>&1
    ! grep -q '^key-literal ' "$T/fixture-$c.keys" || return 1
    if [ "$c" = deploy-unrelated-request ]; then
      grep -q 'name: skill-not-loaded' "$EVALS/$c/case.yaml" && grep -q "input_match: 'contract-deploy'" "$EVALS/$c/case.yaml" || return 1
      continue
    fi
    grep -q 'name: skill-fired' "$EVALS/$c/case.yaml" && grep -q "input_match: 'contract-deploy'" "$EVALS/$c/case.yaml" || return 1
    if [ "$c" = deployment-record ]; then
      [ -s "$home/cwd/broadcast/DeployVault.s.sol/11155111/run-latest.json" ] || return 1
    fi
  done
  git -C "$PLUGIN" check-ignore -q "evals/results/run.json"
}
check "the eval suite has its contract-deploy cases and each fixture builds its state" eval_suite

readmes_list() {
  grep -qF '/evm-dev:contract-deploy' "$REPO/README.md" && grep -qF '/evm-dev:contract-deploy' "$REPO/README.ja.md"
}
check "the root READMEs list /evm-dev:contract-deploy" readmes_list

# A reader learns that production deploys need a hardware wallet before reading which skills exist.
# The skill list is the first table of each README, so its separator row marks where it starts.
readme_needs_first() {
  local f wallet table
  for f in README.md README.ja.md; do
    wallet="$(grep -nE 'Ledger' "$PLUGIN/$f" | grep -E 'Trezor' | grep -F 'contract-deploy' | head -1 | cut -d: -f1)"
    table="$(grep -nE '^\|---' "$PLUGIN/$f" | head -1 | cut -d: -f1)"
    [ -n "$wallet" ] && [ -n "$table" ] && [ "$wallet" -lt "$table" ] \
      || { echo "      $f does not say before the skill list that contract-deploy uses a Ledger or Trezor"; return 1; }
  done
}
check "the README says before the skill list what production deploys need" readme_needs_first

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
    && bash "$PLUGIN/skills/multichain-design/tests/test-multichain-design.sh" > "$T/multichain-design.out" 2>&1
}
check "the other evm-dev skills still pass their tests with contract-deploy" others_kept

# This skill runs the project command of solidity-code, so it follows solidity-code/commands through
# musubi (agent-shuriken#553).
follows_solidity_commands() {
  python3 - "$SKILL_DIR/musubi.json" <<'PY' || return 1
import json, re, sys
try:
    declaration = json.load(open(sys.argv[1], encoding="utf-8"))
except OSError:
    sys.exit(1)
follow = declaration.get("follows", {}).get("solidity-code/commands", {})
ok = (
    declaration.get("musubi") == "2026-11-21"
    and follow.get("version") == "^1.0.0"
    and "optional" not in follow
    and re.fullmatch(r"sha256-[A-Za-z0-9+/]{43}=", str(follow.get("integrity", ""))) is not None
)
sys.exit(0 if ok else 1)
PY
  local line
  for line in \
    'Run the `commands` of the `solidity-code` skill: open the `solidity-code` skill by name and run the file it names for `commands`.' \
    'If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.' \
    'If the `solidity-code` skill is not installed, do not start: tell the user that `solidity-code` is missing and how to install it, then stop.'; do
    grep -qxF -- "$line" "$SKILL_DIR/SKILL.md" || return 1
  done
}
check "contract-deploy follows commands of solidity-code" follows_solidity_commands

printf '%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
