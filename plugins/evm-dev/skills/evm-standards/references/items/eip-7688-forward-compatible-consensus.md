---
status: specified
checked: 2026-11-09
source: ethereum/EIPs: the EIP-7688 and EIP-7773 (the Glamsterdam meta EIP) documents
can: Contracts and light clients can verify consensus data with proofs whose shape stays the same across forks.
---

# EIP-7688 (Consensus data structures that stay the same across forks)

A standard that moves the consensus data structures to `ProgressiveContainer` and `ProgressiveList`.
Only merkleization changes, and serialization does not.

| Point | What the document says |
|---|---|
| Problem it solves | The current `Container` changes its merkleization with each fork, so contracts that verify proofs have to keep being updated |
| What it gives | As long as the feature being verified does not change, contracts such as staking pools do not need updates timed to the fork schedule |
| Handling of limits | The fixed limits of `List` and `Bitlist` move to checks at run time, so they can be adjusted without changing the data types or the proofs |
| Requires | EIP-7495, EIP-7607, EIP-7916 |

## Current status

The document's status is `Review`, and it was created on 2024-04-15.
The Glamsterdam meta EIP (EIP-7773, status `Review`) lists it as `Scheduled for Inclusion`.
Records from 2024 said it was unclear whether it would go into Pectra, but it did not enter the Pectra meta EIP and has moved to the next upgrade, Glamsterdam.

## Not yet shipped

It has not become `Final`.
The mainnet activation date of Glamsterdam has not been checked.
