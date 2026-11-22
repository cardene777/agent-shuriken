---
status: live
checked: 2026-11-11
source: Arbitrum's official documentation (the BoLD overview, dispute economics, and FAQ, the Stylus introduction, the Timeboost overview, and the Arbitrum chains introduction), the Arbitrum Foundation's list of network upgrades, the governance proposals on the ArbitrumDAO forum (the BoLD AIP, the AIP to move to PGA, and the AIP to scale down Nova), and the Nova page of L2BEAT (now named ETHBEAT)
---

# Arbitrum BoLD and Stylus

BoLD is the dispute protocol that lets anyone challenge a claim on an optimistic rollup.
Stylus lets contracts be written in languages that compile to WASM, such as Rust, C, and C++.
This item also covers how Arbitrum orders transactions (Timeboost), the chains built on Arbitrum's technology (Arbitrum chains), and what happens to Nova.

| Point | What the official documents say |
|---|---|
| Before BoLD | Only permissioned validators could challenge a claim |
| BoLD now | Enabled on Arbitrum One, Arbitrum Nova, and Arbitrum Sepolia |
| When BoLD was enabled | The Arbitrum Foundation's list gives 2025-02-12 at 14:00 UTC for Arbitrum One and Nova, and 2024-12-11 for Arbitrum Sepolia |
| Bond for a claim | Posting a state claim takes a one-time bond of 3600 ETH. The dispute economics page and the BoLD AIP give the same amount |
| Bond for a challenge | The dispute economics page and the BoLD AIP give 555 ETH and 79 ETH per level. The FAQ gives 1110 ETH to see a dispute through on Arbitrum One, so the amounts disagree |
| How the bond amounts changed | The BoLD AIP says an update on 2024-04-25 set the challenge bonds to three levels of 1000 ETH, 100 ETH, and 10 ETH, and a later update lowered them to 555 ETH and 79 ETH. The 1110 ETH of the FAQ equals the sum of the earlier three levels |
| How bonds are returned | The honest side's bond is returned when its claim is confirmed, and the dishonest side's bond is confiscated. Parties who do not trust each other can pool a bond |
| BoLD on Nova | The FAQ and the BoLD AIP say Nova's validators stay on an allowlist held by the DAO |
| Timeboost | The winner of a sealed-bid second-price auction holds an express lane for 60 seconds. Other transactions are ordered as they arrive and, while the express lane has a holder, are delayed by 200 milliseconds. It has run on Arbitrum One since April 2025 |
| The proposal to move to PGA | Ends Timeboost and orders Arbitrum One's transactions by the priority fee of each transaction, highest first (PGA). It orders every 125 milliseconds and produces a block every 250 milliseconds. On Nova it ends the express lane and the 200-millisecond delay but does not bring in PGA |
| Progress of the PGA proposal | A Snapshot temperature check started on 2026-06-18. An update on 2026-08-17 says it will go to one onchain vote together with another proposal (Fast Feed) as a constitutional proposal. The Timeboost documentation says PGA is enabled after the vote passes and the express lane ends that day |
| Arbitrum chains | The documentation now calls dedicated chains built on Arbitrum's technology Arbitrum chains; the word Orbit does not appear in its text. Data can go to a rollup, to AnyTrust (data held by a committee), or to another store (Alt-DA) |
| Stylus paused | Arbitrum's Security Council has paused the activation of new Stylus contracts on Arbitrum One and Nova |
| Stylus expiry | An activated contract must be activated again every 365 days or after a Stylus upgrade; otherwise it can no longer be called |
| The proposal to scale down Nova | Scales Nova down instead of shutting it, with a 90-day transition from 2026-06-04 and a plan to move to a form that retires the committee on 2026-09-02. The sequencer is set to post transaction data directly to Ethereum blobs, and the committee members stay on the committee on record after they turn off the signing mechanism |

## Current status

BoLD is live.
Anyone can validate Arbitrum One, but only those on the allowlist validate Nova.
Stylus contracts already activated run until they expire, but new activations are paused.
The Timeboost documentation has a section on why it moves to PGA and is written on the premise of the move.

L2BEAT (renamed ETHBEAT on 2026-11-04) records that Nova stopped using the committee on 2026-08-31 and moved to posting every batch as Ethereum blobs.
L2BEAT places Nova at Stage 0 of optimistic rollups and says about 10 parties on the allowlist can post claims and challenges.
The L2BEAT page warns that ArbitrumDAO decided to scale Nova down to maintenance only, and recommends moving to Arbitrum One.

The posts from 2023 and 2024 saying "a proposal to bring in BoLD", "Stylus makes gas cheaper", and "Nova keeps its data with a committee" differ from the current state.

## Not yet shipped

The documentation does not say when new Stylus activations will resume.
The result of the onchain vote on the PGA proposal and the date PGA was enabled have not been checked on an official page.
The result of the vote on scaling down Nova and the date Nova moved to blobs have not been checked on Arbitrum's official pages.
Which amount is the current challenge bond still differs between Arbitrum's documents and has not been checked.
The date Timeboost started on Nova has not been checked.
