---
status: live
checked: 2026-11-11
source: Starknet's official documentation (Transactions, Accounts, and the version notes), the release notes of v0.13.2 of StarkWare's cairo-lang, and Starknet's SNIPs repository (SNIP-6)
---

# Starknet

Starknet is an L2 that has Ethereum verify its state updates with STARK proofs.
Its accounts are not EOAs; it uses only contract accounts whose checks can be written freely.
It puts failed transactions in blocks too and charges them fees, and sends several blocks to Ethereum together as one state update.

| Point | What the official documents say |
|---|---|
| Failed transactions | A transaction that fails in the execution stage enters the block as a failed (reverted) transaction. The fee is what was used up to the point of failure, or the user's set maximum if that is smaller |
| The nonce on failure | The account's nonce advances even on failure |
| Changes that are rolled back | Changes in the validation stage are not rolled back. Changes in the execution stage are all rolled back, including messages to L1 and events |
| Transactions that do not get in | A transaction that fails the checks before the mempool or the validation before execution goes no further |
| The version that began including failed transactions | The version notes list the change that includes failed transactions in v0.12.1 (2023-08-21, active on mainnet) |
| Entry points an account has | An account contract must have `__validate__` and `__execute__`, with the same argument shape for both. Sending `DECLARE` needs `__validate_declare__`, and deploying with `DEPLOY_ACCOUNT` needs `__validate_deploy__` |
| The model for accounts | The account form follows Ethereum's EIP-4337 |
| SNIP-6 | A standard that unifies account interfaces, made by people from OpenZeppelin. The protocol does not require it, and using it is optional. Its status in the SNIPs repository is `Review` (created 2023-07-06) |
| block packing | v0.13.2 (dated 2024-08-28 in the version notes) brought in a form that bundles several consecutive blocks into one L1 state update. Starknet's `core contract` on L1 and the way data is stored also changed |
| applicative recursion | The notes of cairo-lang v0.13.2 say that, where an L1 state update used to be sent for each L2 block, block proofs are now aggregated offchain and one proof is sent for several blocks |

## Current status

Starknet is live.
The form that charges fees for failed transactions and advances their nonce is in the current official documentation.
SNIP-6 remains an optional standard, and its status in the SNIPs repository is `Review`.

The mechanism a 2024-05 post said "applicative recursion (SNAR) is coming" went into production with v0.13.2.
The official version notes list it under the name block packing, and the cairo-lang notes under the name applicative recursion.

## Not yet shipped

The version notes date v0.13.2 to 2024-08-28 but do not say that is the date it took effect on mainnet.
The date it took effect on mainnet has not been checked.
Which version Starknet runs today has not been checked.
Where Starknet falls in the framework that sorts ZK-EVMs by their degree of compatibility with Ethereum has not been checked.
