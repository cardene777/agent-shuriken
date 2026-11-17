---
status: specified
checked: 2026-11-11
source: ethereum/EIPs: the EIP-7706, EIP-7999, EIP-8037, EIP-7773 (Glamsterdam meta), and EIP-8081 (Hegotá meta) documents
can: Calldata, state creation, and other resources would each be counted and priced as a separate kind of gas.
---

# EIP-7706 (separate gas pricing for each resource)

A group of proposals that count calldata, state creation, and other resources as separate kinds of gas in addition to execution and blobs, and price each kind separately.

| Standard | Status | What the document says |
|---|---|---|
| EIP-7706 | `Stagnant` | Makes calldata gas a separate kind. Adds a new transaction that holds `max_basefee` and `priority_fee` as tuples for three kinds (execution, blob, and calldata), and moves the base fees of all three kinds with the same mechanism |
| EIP-7999 | `Draft` | Sets the maximum ETH a transaction can pay with a single `max_fee`, and charges it across all kinds of gas. Funds no longer have to be held separately for each kind |
| EIP-8037 | `Last Call` | Raises the cost of state creation. Sets the cost per byte of new state, `CPSB`, to the value at which the state grows by 120 GiB per year on average with a block gas limit of 150 million. State creation is counted separately, so large contracts can be deployed without being bound by the gas limit of a single transaction |

## Current status

EIP-7706 was created on 2024-05-13, EIP-7999 on 2025-08-04, and EIP-8037 on 2025-10-01.
The EIP-8037 document gives a `Last Call` deadline of 2026-11-01, and it was still in `Last Call` as of 2026-11-11.

The Glamsterdam meta (EIP-7773, status `Review`) lists EIP-8037 as `Scheduled for Inclusion`.
EIP-7706 and EIP-7999 appear in neither the Glamsterdam meta nor the Hegotá meta (EIP-8081).
The table in the Glamsterdam meta gives activation on Sepolia on 2026-10-06 and on Hoodi on 2026-10-26.

## Not yet shipped

The Glamsterdam meta does not yet give the mainnet activation date.
Paying for per-kind pricing with a single `max_fee` is not in the Glamsterdam or Hegotá meta.
