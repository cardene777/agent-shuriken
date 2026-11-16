---
tool: solc
since: 0.8.31
checked: 2026-11-16
source: Solidity changelog, 0.8.30 and 0.8.31
---

# The default EVM version is osaka

Solidity 0.8.30 (2025-05-07) set the default EVM version to `prague`, and 0.8.31 (2025-12-03) set it to `osaka`.
A contract built without an explicit EVM version may use opcodes that a chain on an older version does not have.

When the target chain is not on the same version as Ethereum mainnet, set the EVM version in `foundry.toml` (`evm_version`) or in the Hardhat config, and do not change one the project already sets.
