---
status: live
checked: 2026-11-11
source: ethereum/EIPs: the EIP-3855 document and EIP-7568 (the meta EIP covering upgrades up to Shapella); ethereum/execution-specs: the Shanghai specification
---

# EIP-3855 (PUSH0, an opcode that pushes 0)

A standard that adds the `PUSH0` opcode, which pushes the constant 0 onto the stack.

| Point | What the document says |
|---|---|
| Opcode | `PUSH0` (`0x5f`) |
| What it does | Pushes 0 onto the stack |
| Gas | 2 (`base`) |
| Difference from the earlier way | Before, 0 was pushed with `PUSH1 0`, paying 3 gas to run and 2 bytes when deployed |

## Current status

The document's status is `Final`, and it was created on 2021-02-19.
It is included in the Shanghai specification in execution-specs and went live on mainnet at epoch 194048.
The timestamp is 1681338455, which falls on 2023-04-12.

## Not yet shipped

Nothing in the standard remains.
Which L2s support `PUSH0` has not been checked.
