---
status: live
checked: 2026-11-18
source: ethereum/EIPs: the EIP-3529, EIP-8038, EIP-7773 (the Glamsterdam meta EIP), and EIP-8081 (the Hegotá meta EIP) documents; ethereum/execution-specs: the London specification; the Ethereum Foundation blog: the Glamsterdam posts of 2026-10-22 and 2026-11-06
can: Transactions get no gas refund for SELFDESTRUCT and a smaller refund for clearing storage with SSTORE.
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
EIP-8038 (status `Last Call`), listed under `Scheduled for Inclusion` in the Glamsterdam meta EIP (EIP-7773), renames the clearing refund `STORAGE_CLEAR_REFUND` and raises it from 4,800 to 11,616, keeping the one-fifth cap.
Glamsterdam has no mainnet date, and the Ethereum Foundation blog (2026-11-06) says EIP-8037 and EIP-8038 may be revised because deployed contracts depend on invariants they break.
EIP-3298, which removes the refund for clearing values and the refund cap, is listed under `Considered for Inclusion` in the Hegotá meta EIP (EIP-8081).
