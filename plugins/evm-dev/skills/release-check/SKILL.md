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

Read the versions with the solidity-code skill in this plugin: its `project` prints them.
Run `list` here for the items on each chain's EVM version, the per-transaction gas cap, storage layouts, and the tools.
When an item is marked `stale`, re-check it against the official document before relying on it, and tell the user what changed; when the document cannot be reached, use the item and say it is unconfirmed, with its checked date.
Ask which chains the contracts go to and, for an upgrade, which git tag or commit is deployed now.

## 2. Build both versions

When the user already has the deployed version's layout and ABI from `forge inspect`, use those files.
Otherwise check out the deployed ref in a new temporary folder with `git worktree add`, run `git -C <folder> submodule update --init` when the project has submodules, and build it with `forge build --root <folder> --out <folder>/out`.
Build both versions with `--extra-output storageLayout` and `--skip test --skip script`, so only deployed code is compared; the storage-layout-output item covers Hardhat.

## 3. Run the checks

Run `layout` with the deployed and the new build; for a renamed contract, pass the two artifacts with `--contract` and `--new-contract`.
Every `removed`, `moved`, `retyped`, or `gap` line would corrupt the deployed state: never call such an upgrade safe.
A `renamed` line is safe for storage only when the new name means the same value.
Run `abi` with the same builds; each line breaks callers such as frontends, indexers, and other contracts, so name who must change.
Run `opcodes` with the new build and `--evm` set to each target chain's EVM version from the items.
When the source never names the opcode, compiling with that chain's `evm_version` fixes it; when the code relies on it (`transient` variables, `tload`, `tstore`, or `mcopy` in assembly), the code must change or the chain must wait.

## 4. OpenZeppelin's check

When the project's `node_modules` has `@openzeppelin/upgrades-core`, also run `npx @openzeppelin/upgrades-core validate` with the reference as the openzeppelin-upgrades-validate item describes, and report both results; never install it.
Variables in `@custom:storage-location` (ERC-7201 namespaced) structs are not in solc's layout, so `layout` does not see them: compare those structs by reading both versions, or rely on OpenZeppelin's check.

## 5. Gas, size, and the transaction cap

Compare gas with `forge snapshot --diff` against a snapshot taken in the deployed version's folder, and sizes with `forge build --sizes`.
In the deployment's simulation, check each transaction's gas limit against the chain's per-transaction cap (EIP-7825).

## 6. Report and clean up

Report each finding with the contract, the script's line, and what to do.
For whether an ERC or EIP is final or live, use the evm-standards skill.
Fixing the contracts belongs to the solidity-code skill, and deploying them to the contract-deploy skill.
Remove the temporary worktree with `git worktree remove` and delete its folder.

## Rules

- Never read a private key or a mnemonic, never sign, and refuse a command that passes a key, such as `--private-key` or `--mnemonic`
- Never read `.env` files or print environment variable values
- Never edit the items in the plugin; a newer fact goes into your answer
