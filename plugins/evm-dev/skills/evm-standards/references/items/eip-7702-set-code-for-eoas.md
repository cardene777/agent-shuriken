---
status: live
checked: 2026-11-09
source: ethereum/EIPs: the EIP-7702 and EIP-7600 (the Pectra meta EIP) documents
---

# EIP-7702 (Set a code delegation on an ordinary account)

A standard that lets an ordinary account held by a private key (an EOA) delegate its code to another contract through a transaction.

| Point | What the document says |
|---|---|
| New transaction | The `set code` transaction (type `0x04`) |
| Delegation marker | The account's code is set to `0xef0100` followed by an address |
| What it enables | Doing several operations at once, having someone else pay the gas, and using sub-keys with narrowed permissions |
| Caution | Delegated code has unlimited authority over the account, so wallets check the delegation target strictly |

## Current status

The document's status is `Final`, and it was created on 2024-05-07.
It is part of the Pectra meta EIP (EIP-7600, status `Final`) and was activated on mainnet at epoch 364032.
The timestamp is 1746612311, which falls on 2025-05-07.

When reading discussions of ERC-4337 and EIP-3074, assume that this standard, not EIP-3074, is what went into Pectra.

## Not yet shipped

Nothing remains within the standard.
Which wallets use which delegation targets has not been checked.
