---
status: live
checked: 2026-11-18
source: ethereum/EIPs: the EIP-1153 document and EIP-7569 (the Dencun meta EIP)
can: Contracts can read and write values with TSTORE and TLOAD that are discarded when the transaction ends, without the cost of permanent storage.
---

# EIP-1153 (Storage that lasts only for one transaction)

A standard that adds opcodes to read and write a place that behaves like storage and is discarded when the transaction ends.
It does not read or write disk, so it is cheaper than ordinary storage.

| Point | What the document says |
|---|---|
| Opcodes | `TLOAD` (`0x5c`) and `TSTORE` (`0x5d`) |
| When it is cleared | Discarded at the end of every transaction |
| Gas handling | `TSTORE` is not subject to the EIP-2200 gas stipend check |
| Required EIPs | EIP-2200, EIP-3529 |

## Current status

The document's status is `Final`, and it was created on 2018-06-15.
It is included in the Dencun meta EIP (EIP-7569) and went live on mainnet at epoch 269568.
The timestamp is 1710338135, which falls on 2024-03-13.

## Not yet shipped

Nothing in the standard remains.
Which contracts use it has not been checked.
