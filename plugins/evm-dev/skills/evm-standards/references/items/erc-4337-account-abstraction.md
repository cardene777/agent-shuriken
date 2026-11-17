---
status: live
checked: 2026-11-11
source: ethereum/ERCs: the ERC-4337 document; ethereum/EIPs: the EIP-2938 document; eth-infinitism/account-abstraction: the release notes
can: Accounts can keep their validation logic in a contract, with bundlers, paymasters that pay gas, and batched calls, without protocol changes.
---

# ERC-4337 (account abstraction without protocol changes)

A standard that lets each account's validation logic be written in a contract.
It works on a layer above transactions, without changing the consensus layer.

| Point | What the document says |
|---|---|
| What is sent | A transaction-like object called a `UserOperation`, sent to a separate mempool |
| Bundler | A `bundler` bundles `UserOperation`s and passes them to the `EntryPoint` in one transaction |
| Validator | The `EntryPoint` calls each account's validation logic and executes the ones that pass |
| Gas fees | A `paymaster` can pay on the user's behalf |
| Relation to EIP-7702 | Has 7702 in `requires`. `eth_sendUserOperation` accepts `eip7702Auth`, and the bundler puts it in the transaction |

## The two loops in `handleOps`

The `EntryPoint`'s `handleOps` runs two loops, a validation loop and an execution loop.

| Phase | What the document says |
|---|---|
| Validation loop | For each `UserOperation`, creates the account if it does not exist, calls `validateUserOp`, and checks that the deposit covers the maximum cost |
| Execution loop | Calls the account with each `UserOperation`'s `calldata`, and refunds what is left of the prepaid cost |
| `validationData` | Returns the validation result as one value that packs the `aggregator` address or a signature success flag, together with the `validUntil` and `validAfter` times. When the signature does not match, it returns `SIG_VALIDATION_FAILED` (`1`) instead of reverting |
| Penalty for unused gas | Charges 10% (`UNUSED_GAS_PENALTY_PERCENT`) of the unused part of `callGasLimit` and `paymasterPostOpGasLimit`. It applies only when the unused part is 40000 (`PENALTY_GAS_THRESHOLD`) or more |

The penalty exists to stop a `UserOperation` from reserving a large share of the bundle's gas without using it, which would keep other `UserOperation`s out of the bundle.

## The earlier proposal, EIP-2938

EIP-2938, account abstraction through protocol changes, has the status `Withdrawn`.
The reason given for withdrawal is "outdated and needs rewriting".
The current proposals that change the protocol are in the `eip-7701-native-account-abstraction` item.
The precompile that checks passkey signatures in contracts is in the `eip-7951-secp256r1-precompile` item.

## Current status

The document's status is `Final`, and it was created on 2021-09-29.
The statement "the spec is not settled" in a 2024 post differs from the current status.
The `EntryPoint` is deployed at a different address for each version, and the latest in the release notes is v0.9 from 2025-11-16.
The v0.7 and v0.8 addresses listed in the release notes were confirmed on 2026-11-09 to have code on mainnet.

## Not yet shipped

Nothing remains open within the standard.
The v0.9 address, and which wallets and `bundler`s use which version, have not been checked.
