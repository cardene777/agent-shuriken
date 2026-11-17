---
topic: verification
subject: Where forge verify-contract and Hardhat 3's verify send source code by default
checked: 2026-11-17
source: Foundry, forge verify-contract reference; forge 1.5.1 help output; Hardhat, hardhat-verify plugin and the guide to verifying smart contracts
---

# Foundry verifies on Sourcify by default; Hardhat 3 verifies on Etherscan, Blockscout, and Sourcify

In forge 1.5.1, `forge verify-contract <address> <path>:<contract>` uses `--verifier sourcify` unless told otherwise; the other verifiers are `etherscan`, `blockscout`, `oklink`, and `custom`. `--verifier etherscan` needs the Etherscan API key, from `--etherscan-api-key` or `ETHERSCAN_API_KEY`, and the chain from `--chain`. `forge script --verify` verifies what a broadcast deployed. In Hardhat 3, `@nomicfoundation/hardhat-verify` verifies on Etherscan, Blockscout, and Sourcify when `hardhat verify` runs without a subtask; Blockscout and Sourcify need no key, Etherscan uses its V2 API with one key, and each service can be turned off under `verify` in the config. In Hardhat 2 the plugin left Sourcify off by default.

For a deployment:

- Verify every contract in the deployment record, including libraries and contracts created by a factory
- Pass the same constructor arguments, compiler version, and optimizer settings that the deployment used
- Report each address with the verifier that accepted it, and say which ones failed
