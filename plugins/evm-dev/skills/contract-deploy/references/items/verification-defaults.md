---
topic: verification
subject: Where forge verify-contract and Hardhat 3's verify send source code by default
checked: 2026-11-18
source: Foundry, forge verify-contract reference, the verify source code of 1.5.1 and 1.9.0, and the 1.8.0 release notes; Hardhat, hardhat-verify 3.1.5 plugin and the guide to verifying smart contracts
---

# Foundry verifies on Sourcify when no Etherscan key is set; Hardhat 3 verifies on Etherscan, Blockscout, and Sourcify

`forge verify-contract <address> <path>:<contract>` picks the verifier from `--verifier`: `sourcify`, `etherscan`, `blockscout`, `oklink`, or `custom`. Without `--verifier`, it uses Sourcify when no Etherscan API key is set, and Etherscan when a key is set (from `--etherscan-api-key`, `ETHERSCAN_API_KEY`, or the config) and Etherscan covers the chain. `--verifier etherscan` needs that key and the chain from `--chain`. Since Foundry 1.8.0, verifying on Etherscan also submits the source to Sourcify, unless a `--verifier-url` is given or the chain is a local one; `--verifier sourcify` submits only to Sourcify. `forge script --verify` verifies what a broadcast deployed. In Hardhat 3, `@nomicfoundation/hardhat-verify` verifies on Etherscan, Blockscout, and Sourcify when `hardhat verify` runs without a subtask; Blockscout and Sourcify need no key, Etherscan uses its V2 API with one key, and each service can be turned off under `verify` in the config. In Hardhat 2 the plugin left Sourcify off by default.

For a deployment:

- Verify every contract in the deployment record, including libraries and contracts created by a factory
- Pass the same constructor arguments, compiler version, and optimizer settings that the deployment used
- Report each address with the verifier that accepted it, and say which ones failed
