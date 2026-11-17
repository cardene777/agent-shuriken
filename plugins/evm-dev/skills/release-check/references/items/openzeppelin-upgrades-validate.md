---
topic: tools
subject: OpenZeppelin's upgrade safety check from the command line and from Foundry and Hardhat
checked: 2026-11-17
source: OpenZeppelin, Upgrades Core documentation (validate command), OpenZeppelin Foundry Upgrades documentation, and Hardhat Upgrades documentation and changelog
---

# OpenZeppelin's check also catches unsafe code that the storage layout does not show

OpenZeppelin's upgrade check compares storage layouts, including ERC-7201 namespaced structs, and flags code that is unsafe behind a proxy: a constructor that sets state, `selfdestruct`, `delegatecall`, and immutable variables. It reads solc's build-info files.

Command line, when `@openzeppelin/upgrades-core` is in the project's `node_modules`:

- `npx @openzeppelin/upgrades-core validate [<build-info folder>]`; the folder defaults to `out/build-info` (Foundry) or `artifacts/build-info` (Hardhat)
- `--contract <name>` checks one contract, `--reference <name>` names the version it upgrades from, and `--requireReference` fails when no reference is known
- `--referenceBuildInfoDirs <folder>` adds the build-info of a previous version; name its contracts as `<folder name>:<Contract>` in `--reference` or in the annotation
- The reference can also come from `/// @custom:oz-upgrades-from <Contract>` on the new contract
- `--unsafeAllow`, `--unsafeAllowRenames`, and `--unsafeSkipStorageCheck` turn checks off; never add them to make the check pass

Foundry needs `build_info = true` and `extra_output = ["storageLayout"]` in `foundry.toml`, then `forge clean` and `forge build`.

From code:

- Foundry, with `openzeppelin-foundry-upgrades`: `Upgrades.validateUpgrade("Vault.sol", opts)` in a script or test; it also needs `ffi = true` and `ast = true`, and Node.js. `Upgrades.sol` is for OpenZeppelin Contracts 5, `LegacyUpgrades.sol` for 4
- Hardhat, with `@openzeppelin/hardhat-upgrades`: `upgrades.validateUpgrade(<old factory or address>, <new factory>)`; version 4 supports Hardhat 3, registered in `plugins` and used through `upgradesApi`

Never install the package or change the build settings for the check without asking the user.
