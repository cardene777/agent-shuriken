---
status: specified
checked: 2026-11-11
source: ethereum/EIPs: the EIP-7610 document
---

# EIP-7610 (Make contract creation fail at an address that has storage)

A standard that makes contract creation fail when it targets an address that already has storage.

| Point | What the document says |
|---|---|
| When it fails | When the target address has a nonzero nonce, code of nonzero length, or non-empty storage |
| Ways of creating covered | Creation transactions, `CREATE`, `CREATE2`, and every other way of creating |
| How it fails | It halts the same way as when the first byte of the creation code is an invalid opcode |
| Range applied | It applies retroactively to every existing block |

## Current status

The document's status is `Last Call`, with a deadline given as 2024-11-20, and it was created on 2024-02-02.
The deadline has passed, but as of 2026-11-11 the document's status was still `Last Call`.

## Not yet shipped

It has not become `Final`.
