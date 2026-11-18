---
status: live
checked: 2026-11-18
source: ethereum/EIPs: the EIP-7623, EIP-7976, EIP-7600 (the Pectra meta EIP), and EIP-7773 (the Glamsterdam meta EIP) documents; the Ethereum Foundation blog: the Glamsterdam post of 2026-10-22
can: Transactions that mainly carry calldata pay a higher floor price for it, while other transactions pay as before.
---

# EIP-7623 (Raise the calldata cost of transactions that mainly carry data)

A standard that raised the cost only for transactions that mainly carry data, by putting a floor on the calldata cost.
It reduces the maximum block size and its variance without changing the cost of ordinary users' transactions.

| Point | What the document says |
|---|---|
| Problem it solves | Under the earlier calldata price, an execution layer block could grow to 7.15 MB, while the average was about 100 KB |
| Standard value | `STANDARD_TOKEN_COST` is 4 |
| Floor value | `TOTAL_COST_FLOOR_PER_TOKEN` is 10. Tokens are zero bytes plus four times nonzero bytes, and gas used is never below 21000 plus 10 per token |
| Gas limit | A transaction whose gas limit is below that floor is invalid, so wallets estimating gas must include it |
| Transactions affected | Transactions that use little gas for execution and carry a lot of calldata |

## Current status

The document's status is `Final`, and it was created on 2024-02-13.
It is part of the Pectra meta EIP (EIP-7600, status `Final`) and was activated on mainnet at epoch 364032.
The timestamp is 1746612311, which falls on 2025-05-07.

## Not yet shipped

The Glamsterdam meta EIP (EIP-7773) lists EIP-7976 (status `Last Call`) as `Scheduled for Inclusion`.
It raises `TOTAL_COST_FLOOR_PER_TOKEN` to 16 and counts every calldata byte as four tokens, a floor of 64 gas per byte.
Glamsterdam has no mainnet date (Ethereum Foundation blog, 2026-10-22).
