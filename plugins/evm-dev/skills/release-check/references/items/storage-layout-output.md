---
topic: layout
subject: Getting the storage layout from Foundry and Hardhat, and the rules an upgrade must keep
checked: 2026-11-17
source: Solidity documentation, Layout of State Variables in Storage and the storageLayout output; Foundry, forge build and forge inspect reference; Hardhat, solidity settings reference; OpenZeppelin, Writing Upgradeable Contracts; forge 1.5.1 and solc 0.8.30 run on a throwaway project
---

# solc writes each variable's slot, offset, and type; an upgrade must keep them for every old variable

solc's `storageLayout` output lists each state variable in order, with `label`, `slot`, `offset` (bytes into the slot), `type`, and `contract`, plus a `types` table that describes each type, including struct members and a mapping's key and value.

Ways to get it:

- Foundry, one contract: `forge inspect <Contract> storageLayout --json`
- Foundry, every artifact: `forge build --extra-output storageLayout`, or `extra_output = ["storageLayout"]` in `foundry.toml`; each `out/<File>.sol/<Contract>.json` then holds `storageLayout`
- Foundry, another version: build it into its own folder with `forge build --root <folder> --out <folder>/out`, so the project's own `out/` stays as it is
- Hardhat: add `storageLayout` to `outputSelection` in the solidity settings; the layout lands in the build-info under `artifacts/build-info/`, not in the artifacts, so take the contract's `storageLayout` object from there with `jq` and save it as a file

Rules an upgrade keeps:

- Never remove, reorder, or retype an existing variable, also inside a struct that is stored in a mapping or an array
- Add new variables after the last one, or take them from a `__gap` array by shrinking it by the slots used, so the gap still ends at the same slot
- Never change the order of inherited contracts, since the base contracts' variables come first
- Renaming keeps the slot and is safe for storage, but the new name must still mean the same value
- `immutable` and `constant` values live in the code, not in storage, and do not appear in the layout
