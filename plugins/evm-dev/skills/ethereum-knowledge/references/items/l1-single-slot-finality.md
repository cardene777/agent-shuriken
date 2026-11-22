---
status: specified
checked: 2026-11-16
source: The source text (in the vbuterin/blog repository) of Vitalik Buterin's blog posts Possible futures of the Ethereum protocol, part 1: The Merge (2024-10-14) and Epochs and slots all the way down (2024-06-30); the single slot finality page in ethereum/ethereum-org-website; the leanSpec repository of leanEthereum; and the documents of EIP-7773 (the Glamsterdam meta EIP) and EIP-8081 (the Hegotá meta EIP) in ethereum/EIPs
---

# Speeding L1 finality up to one slot

A direction to shorten the wait until an Ethereum block is final from today's 2 to 3 epochs (about 15 minutes) to one slot.
It is discussed together with the aim of lowering the minimum stake from 32 ETH to 1 ETH.
It looks for a way to meet both while keeping the property that an attacker cannot revert finality without burning a large amount of ETH (economic finality).

| Point | What the posts say |
|---|---|
| Today's form | Today's consensus, Gasper, combines a vote in every 12-second slot with finality per epoch of 32 slots (6.4 minutes), so finality takes 2 epochs (12.8 minutes) |
| Reasons to change | Many bugs arise between the two mechanisms, and 12.8 minutes is longer than anyone waits |
| The three aims clash | Growing the number of validators (lowering the minimum), speeding finality, and keeping node load down clash with each other, because economic finality needs every validator to send two signatures for each finalization |
| The form of single slot finality | Close to Tendermint: block N is finalized before N+1 is made |
| The condition of keeping the inactivity leak | Keeping the inactivity leak, which lets the chain advance and recover even when more than a third of validators go offline, is a condition. Tendermint lacks this property, but the post says Tendermint-like consensus proposals with an inactivity leak already exist |
| Path 1 (brute force in signature aggregation) | Refine the aggregation of signatures with ZK-SNARKs and the like, and process the signatures of millions of validators every slot. More than a million signatures must be aggregated in 5 to 10 seconds. Its weakness is that it makes the slot hard to shorten |
| Path 2 (Orbit committees) | Leave finality to a randomly chosen committee of medium size while keeping the property of the cost of attack. It uses the unevenness of deposit sizes to make economic finality larger, and rotates committees slowly to keep neighboring quorums overlapping. The cost of attack could fall to about a tenth of today's (for example from 25 billion dollars to 2.5 billion) |
| Path 3 (two-tier staking) | Split a tier with large deposits from a tier with small ones, and let only the large tier carry economic finality. Proposed rights for the small tier include delegating to the large tier, a randomly chosen subset voting on each block as required for finality, and the right to build inclusion lists. Which right is given creates weaknesses such as concentrated delegation, or finality stoppable with a small amount |
| Link to EIP-7251 | The post says the consolidation of validator balances brought in by EIP-7251 lowers the verification load a little right away and is the first stage of bringing in Orbit |
| Combinations | It also names lowering only the minimum by brute force without single slot finality, and bringing in Orbit with conservative values (committees of 128 thousand instead of 8 thousand or 32 thousand) while raising efficiency by brute force |
| The wait for confirmation | The post of 2024-06-30 says that even if Orbit cuts the number of signers to speed finality, the 5 to 20 seconds users wait do not shrink |

The single slot finality page of ethereum.org says that for a block that does not reach 2/3, the fork choice rule takes over, which leaves room to keep the inactivity leak.
The direction of speeding transaction confirmation is in the `l1-fast-confirmation` item.

## Current status

The single slot finality page of ethereum.org says it is at the research stage and expected to ship many years from now.
ethereum/EIPs has no standard document that defines single slot finality.
It is in neither the Glamsterdam meta EIP (EIP-7773, status `Review`) nor the Hegotá meta EIP (EIP-8081, status `Draft`).

The leanSpec repository of the leanEthereum organization is a consensus specification for research.
It sets `SECONDS_PER_SLOT` to 4 seconds and decides which slots are candidates for finality following the `3SF-mini` specification.
The repository was created on 2025-07-28 and was not archived as of 2026-11-16.

EIP-7251 went live in Pectra on 2025-05-07, and its form is in the `eip-7251-max-effective-balance` item.

## Not yet shipped

Single slot finality is not live on mainnet.
An official document deciding which of the three paths to take has not been checked.
An official document giving a plan and timing for bringing the leanSpec specification to mainnet has not been checked.
