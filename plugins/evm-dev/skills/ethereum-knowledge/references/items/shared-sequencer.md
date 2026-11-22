---
status: live
checked: 2026-11-11
source: Espresso's official documentation (What is Espresso?, the network overview, and the release history), the announcements of Astria's official account and the posts of its co-founder, the astria repository of astriaorg, and Radius' official site and the design post it published on ethresear.ch
---

# Shared sequencers

A form in which several rollups share the role that decides the order of transactions (the sequencer) through one decentralized set.
It aims not to leave ordering to a single operator, and to tie rollups together in the same order.
As of 2026-11-11, the main networks that advertised this form have stopped, or now describe themselves as handling only finality, not ordering.

| Point | What the official documents say |
|---|---|
| How Espresso describes itself now | As a decentralized settlement layer |
| Espresso's role | Each connected environment keeps its own execution environment and sequencer, and that sequencer decides the order and streams it to Espresso. Espresso does not execute transactions; it finalizes the outputs that stream in with Proof of Stake consensus |
| Mainnet | Says instant settlement, backed by a decentralized set of validators, is available on mainnet |
| Validators | The top 100 nodes by delegated stake serve for each epoch of about 24 hours. The permissionless form of joining took effect on mainnet on 2026-03-04 |
| A market for ordering rights | The design shown in a 2024-05 post, a market in which rollups sell their ordering rights, is not in Espresso's current documentation |
| The end of Astria | A commit adding a height at which Flame stops was merged on 2025-10-10. On 2025-11-12 the co-founder announced the development company would close, and on 2025-12-01 (UTC) the official account announced the network was intentionally stopped, with block 15,360,577 as the last block |
| Radius' design | On 2024-02-23, it posted on ethresear.ch, as a preliminary proposal, a design that executes bundles across rollups atomically. It has three stages: ordering the proposed blocks, executing and deciding whether to return a bundle, and ordering the final blocks without the failed bundles |
| Radius now | Its official site shows neither a shared sequencer nor atomic execution across rollups, and names solvers and arbitrage operations as its running business |

## Current status

Espresso runs on mainnet, but ordering stays with each environment's sequencer, and Espresso handles only finality.
Posts from 2023 and 2024 assume the idea of a shared sequencer, but Espresso now describes itself as a settlement layer.
The Astria network stopped on 2025-12-01.
Radius' atomic execution across rollups could not be confirmed in official documents to have gone beyond design.

## Not yet shipped

A shared sequencer running on mainnet the feature that ties rollups in the same order and executes bundles atomically has not been confirmed.
The prototype Radius is said to have shown between two chains has not been checked in official documents.
Which rollups were connected to the Astria network and how their assets were handled have not been checked.
