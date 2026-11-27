---
name: release-check
description: Checks Solidity contracts before a release by comparing the storage layout and ABI with the deployed version, naming opcodes the target chains' EVM lacks, and running OpenZeppelin's upgrade check when the project has it. Use before deploying or upgrading contracts.
---

# Release check

Check contracts before they go on chain: that an upgrade keeps the deployed storage and interface, and that the bytecode runs on every target chain.
Talk to the user in the language they write in.

The script is `scripts/release-check.py` next to this `SKILL.md`.
Run it as a shell command, `python3 <folder of this SKILL.md>/scripts/release-check.py <command>`; `--help` describes every command and line.

## 1. Read the project

Read the versions with the solidity-code skill: its `project` prints them.
Run the `commands` of the `solidity-code` skill: open the `solidity-code` skill by name and run the file it names for `commands`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `solidity-code` skill is not installed, do not start: tell the user that `solidity-code` is missing and how to install it, then stop.
Run `list` for the items on EVM versions, the gas cap, storage layouts, and the tools.
When an item is marked `stale`, re-check it against the official document and tell the user what changed; when the document cannot be reached, say the item is unconfirmed, with its checked date.
Ask which chains the contracts go to and, for an upgrade, which git tag or commit is deployed now.

## 2. Build both versions

Check out the deployed ref in a new temporary folder with `git worktree add`, then `git -C <folder> submodule update --init` when it has submodules.
Build both versions the same way, each into an empty folder, passing the source folder from `foundry.toml` (default `src`) so only it and what it imports are built: `forge build --root <folder> --out <empty folder> --extra-output storageLayout --ast <folder>/src`.
`layout` needs `--extra-output storageLayout` and `--ast`.
The storage-layout-output item covers Hardhat.

## 3. Run the checks

Run `layout` on the two builds; for a renamed contract, add `--contract` and `--new-contract`.
Every `removed`, `moved`, `retyped`, `gap`, or `slot` line would corrupt the deployed state: never call such an upgrade safe.
A `renamed` line is safe for storage only when the new name means the same value.
A `not-compared` line means that namespaced storage was not compared: rebuild as above or compare those structs by hand before calling it safe.
Run `abi` with the same builds; each line breaks callers such as frontends and indexers, so name who must change.
Run `opcodes` with the new build and `--evm` set to each target chain's EVM version from the items.
When the source never names the opcode, compiling with that chain's `evm_version` fixes it; when the code relies on it (`transient` variables, `tload`, `tstore`, or `mcopy` in assembly), the code must change or the chain must wait.

## 4. OpenZeppelin's check

When the project's `node_modules` has `@openzeppelin/upgrades-core`, also run `npx @openzeppelin/upgrades-core validate` with the reference as the openzeppelin-upgrades-validate item describes, and report both results; never install it.
It also covers `@custom:storage-location` structs.

## 5. Gas, size, and the transaction cap

Compare gas with `forge snapshot --diff` against a snapshot taken in the deployed version's folder, and sizes with `forge build --sizes`.
Simulate the upgrade script without `--broadcast` against the chain the proxy lives on (`--rpc-url`); when no reachable chain has it, first deploy the worktree's version to `anvil` with its deploy script.
In that simulation, check each transaction's gas limit against the chain's per-transaction cap (EIP-7825).

## 6. Report and clean up

When the `page-design` skill is installed, write the report in the `structure` format of the `page-design` skill: open the `page-design` skill by name and read the file it names for `structure`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `page-design` skill is not installed, go on without the `structure` of `page-design`.

Report each finding with the contract, the script's line, and what to do.
For whether an ERC or EIP is final or live, use the evm-standards skill.
Fixes belong to the solidity-code skill, and deployments to the contract-deploy skill.
Remove the temporary worktree with `git worktree remove --force <folder>`; submodules need `--force`.

## Rules

- Never read a private key or a mnemonic, never sign, and refuse a command that passes a key, such as `--private-key` or `--mnemonic`
- Never read `.env` files or print environment variable values
- Never edit the items in the plugin; a newer fact goes into your answer
