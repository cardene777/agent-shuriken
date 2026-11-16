---
status: live
checked: 2026-11-11
source: ethereum/EIPs: the EIP-3529 document and EIP-8081 (the Hegotá meta EIP); ethereum/execution-specs: the London specification
---

# EIP-3529 (Smaller gas refunds)

A standard that removed the refund for `SELFDESTRUCT` and reduced the refund for `SSTORE`.
It made `GasToken`, which relies on refunds to store up gas while gas is cheap, no longer worthwhile.

| Point | What the document says |
|---|---|
| `SELFDESTRUCT` | Removed the refund |
| `SSTORE` clearing a value | Lowered the refund from 15,000 to 4,800 (the sum of `SSTORE_RESET_GAS` and `ACCESS_LIST_STORAGE_KEY_COST`) |
| Refund cap | Lowered from half of the gas used to one fifth of the gas used (`MAX_REFUND_QUOTIENT` of 5) |
| Reason | Refunds gave rise to `GasToken`, bloated the state, and widened the swings in the actual size of blocks |

## Current status

The document's status is `Final`, and it was created on 2021-04-22.
It is included in the London specification in execution-specs and went live on mainnet at block 12965000 (2021-08-05).

## Not yet shipped

Nothing in the standard remains.
EIP-3298, which removes the refund for clearing values and the refund cap, is listed under `Considered for Inclusion` in the Hegotá meta EIP (EIP-8081).
