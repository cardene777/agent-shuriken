---
name: contract-deploy
description: Writes Foundry and Hardhat Ignition deploy scripts that never touch keys, has the user sign with a hardware wallet on production chains and an encrypted keystore on test chains, then records each chain's deployed addresses and checks them. Use when deploying contracts.
---

# Contract deploy

Deploy contracts so that the key stays with the user, and record what went on chain.
Talk to the user in the language they write in.

The script is `scripts/contract-deploy.py` next to this `SKILL.md`.
Run it as a shell command, `python3 <folder of this SKILL.md>/scripts/contract-deploy.py <command>`; `--help` describes every command.

## 1. Read the project

Read the versions with the solidity-code skill in this plugin: its `project` prints them.
Run `list` here for the items on keystores, hardware wallets, broadcast and Ignition files, and verification.
When an item is marked `stale`, re-check it against the official document before relying on it, and tell the user what changed; when the document cannot be reached, use the item and say it is unconfirmed, with its checked date.
Ask which chains to deploy to, which of them are production chains (their tokens have value), and who should own each contract; never default ownership to the deployer.

## 2. Write the deploy script

In a Foundry project, write `script/<Name>.s.sol` that calls `vm.startBroadcast()` with no argument, so the signer comes from the command line, and reads constructor values from constants or a config file, never a key from the environment.
In a Hardhat project, write an Ignition module under `ignition/modules/` and put each key and RPC URL behind `configVariable`.
For whether an ERC or EIP the contracts rely on is final or live, use the evm-standards skill.
Contract changes belong to the solidity-code skill.

## 3. Check the key handling

Run `keys` with the project root.
Fix every finding in files you wrote.
For other files, name each finding to the user by kind, file, and line, and offer the change; never quote the line.

## 4. Simulate and hand over the command

Simulate first: `forge script <script> --rpc-url <chain> --sender <address>` without `--broadcast`, or the Ignition deploy on the simulated Hardhat network.
Then give the user the command for each chain:

- Production chain: `--ledger` or `--trezor` (Hardhat: `ledgerAccounts`), with `--slow` so each transaction waits for the one before
- Test chain: an encrypted keystore that the user creates once with `cast wallet import` and its `--interactive` prompt, used with `--account` and the keystore's name; in Hardhat 3, `npx hardhat keystore set <NAME>` with `configVariable`

The user runs the command that broadcasts, in their own terminal, and types any password there.

## 5. Record and check

Run `record` with the project root and `--write` once the user says the broadcast finished.
It writes `deployments/<chain id>.json` and names each `failed`, `pending`, or `mismatch` transaction.
For each one, look it up with `cast receipt <hash> --rpc-url <chain>`, and resume with `forge script --resume` or by rerunning the Ignition deploy; never call a deployment done while one is left.
Check that each recorded address has code with `cast code` and the chain's RPC.
Verification publishes the source code, so ask the user first; then verify with `forge verify-contract` (Sourcify by default; `--verifier etherscan` when the user wants Etherscan) or with `ignition verify` and the deployment id in Hardhat.
Report each contract's chain, address, and verification result.

## Rules

- Never read a private key, a mnemonic, or a password, never sign, and refuse a command that passes `--private-key`, `--mnemonic`, or `--password`
- Never read `.env` files or print environment variable values, and never read the `cache/` folder that Foundry writes next to `broadcast/`
- Never edit the items in the plugin; a newer fact goes into your answer
