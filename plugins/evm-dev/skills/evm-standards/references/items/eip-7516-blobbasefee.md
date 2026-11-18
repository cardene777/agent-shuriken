---
status: live
checked: 2026-11-18
source: ethereum/EIPs: the EIP-7516 and EIP-7569 (the Dencun meta EIP) documents
can: Contracts can read the blob base fee of the current block with the BLOBBASEFEE opcode.
---

# EIP-7516 (BLOBBASEFEE, an opcode that reads the blob base fee)

A standard that adds an opcode returning the blob base fee of the block being executed.
It has the same form as `BASEFEE` from EIP-3198 and returns the EIP-4844 blob base fee.

| Point | What the document says |
|---|---|
| Opcode | `BLOBBASEFEE` (`0x4a`) |
| Requires | EIP-3198, EIP-4844 |

## Current status

The document's status is `Final`, and it was created on 2023-09-11.
It is part of the Dencun meta EIP (EIP-7569) and was activated on mainnet at epoch 269568.
The timestamp is 1710338135, which falls on 2024-03-13.
How the blob fee is set is covered by the `eip-4844-blob-transactions` item.

## Not yet shipped

Nothing remains within the standard.
