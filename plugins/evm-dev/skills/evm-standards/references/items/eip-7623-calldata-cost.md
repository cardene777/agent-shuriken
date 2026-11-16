---
status: live
checked: 2026-11-11
source: ethereum/EIPs: the EIP-7623, EIP-7600 (the Pectra meta EIP), and EIP-7773 (the Glamsterdam meta EIP) documents
---

# EIP-7623 (Raise the calldata cost of transactions that mainly carry data)

A standard that raised the cost only for transactions that mainly carry data, by putting a floor on the calldata cost.
It reduces the maximum block size and its variance without changing the cost of ordinary users' transactions.

| Point | What the document says |
|---|---|
| Problem it solves | Under the earlier calldata price, an execution layer block could grow to 7.15 MB, while the average was about 100 KB |
| Standard value | `STANDARD_TOKEN_COST` is 4 |
| Floor value | `TOTAL_COST_FLOOR_PER_TOKEN` is 10, and a transaction's cost is never below its number of calldata tokens times 10 |
| Transactions affected | Transactions that use little gas for execution and carry a lot of calldata |

## Current status

The document's status is `Final`, and it was created on 2024-02-13.
It is part of the Pectra meta EIP (EIP-7600, status `Final`) and was activated on mainnet at epoch 364032.
The timestamp is 1746612311, which falls on 2025-05-07.

## Not yet shipped

The Glamsterdam meta EIP (EIP-7773) lists EIP-7976, which raises the calldata floor further, as `Scheduled for Inclusion`.
