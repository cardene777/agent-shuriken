---
status: specified
checked: 2026-11-16
source: The source text (in the vbuterin/blog repository) of Vitalik Buterin's blog posts Possible futures of the Ethereum protocol, part 1: The Merge (2024-10-14) and Epochs and slots all the way down (2024-06-30); the documents of EIP-7782, EIP-8198, EIP-7773 (the Glamsterdam meta EIP), and EIP-8081 (the Hegotá meta EIP) in ethereum/EIPs; the research texts on ethresear.ch Strawmanning Based Preconfirmations (2024-05-31), Avoiding Accidental Liveness Faults for Based Preconfs (2024-06-22), and Leaderless and Leader-Based Preconfirmations (2024-07-04); the LongHash Ventures article Preconfirmations: Credible Promise of Future Execution (2024-06-12); and the repositories chainbound/bolt, Commit-Boost/commit-boost-client, and primev/mev-commit
---

# Faster confirmation of L1 transactions

A direction to make the wait until it is known that an L1 transaction is in a block shorter than today's 12-second slot.
Unlike speeding finality, it deals with how fast it is known, before finality, that a transaction "gets in".
The post of 2024-10-14 says that shortening 12 seconds to, for example, 4 seconds improves the experience of L1 and based rollups and also the efficiency of DeFi.
It says L2s would also have less need to build decentralized sequencers with their own committees.

| Point | What the posts and documents say |
|---|---|
| Form 1 (shorter slots) | Shorten the slot from 12 seconds to 8 or 4 seconds. It does not mean finality in 4 seconds, but if the three rounds of messages finality needs go into separate blocks, at least a tentative confirmation comes in 4 seconds |
| The fear in shortening | A 4-second slot needs the bound on network delay (delta) shortened to 2 seconds. The post says it becomes hard to keep validating outside limited regions, and validators may concentrate |
| Why the slot can be shortened | A 12-second slot has three stages: publishing and spreading the block, attestations, and aggregating them. The post of 2024-06-30 says that if the number of voters falls sharply it can become two stages of 8 seconds, and that leaving tentative consensus to a subset of skilled nodes can bring it to about 2 seconds |
| Form 2 (proposer preconfirmations) | During the slot, the proposer puts transactions it sees into the block on the spot and issues a preconfirmation for each. A proposer that issues two conflicting confirmations is slashed, or the attesters vote on which came first |
| The weakness of preconfirmations | The average wait shrinks, but the worst wait does not. If the current proposer is online a preconfirmation comes in 0.5 seconds; if it is offline the wait is up to 12 seconds until the next slot. The post also calls how to reward preconfirmations an open question |
| What preconfirmations rely on | In practice, proposer preconfirmations rely on a mechanism that separates attesters from proposers (such as execution tickets). Without one, issuing preconfirmations on the spot is a heavy load for ordinary validators and could lead to concentration |
| When confirmation is not sped up | The post says that if finality stays at 12 seconds or more, weight shifts to the preconfirmation mechanisms L2s build, and interaction between L2s also takes long |
| A stopped attempt (bolt) | Chainbound's bolt is a fork of the MEV-Boost stack in which users ask the proposer for promises like preconfirmations and the proposer issues promises to include transactions in a form that can be verified on chain. Its repository `chainbound/bolt` is archived, and its last push was on 2025-05-05 |

The direction of speeding finality to one slot is in the `l1-single-slot-finality` item.
Taiko's form of issuing preconfirmations for a based rollup is in the `based-rollup-preconfirmation` item.

## Three forms of fast confirmation

The post of 2024-06-30 assumes single slot finality on L1 provides finality, and sorts the forms of fast confirmation into three.

| Form | What the post says |
|---|---|
| Separating slots and epochs inside L1 | Inside L1, fast tentative consensus and slow finality become separate mechanisms. The post says that once confirmation is down to one second, committee forms are needed far less |
| Preconfirmations from an L2's server | Plasma and validiums, which do not keep their data on L1, cannot use the `based` form, so the post says this form remains |
| Preconfirmations from an L2's committee | A fast chain of about a hundred nodes, with Ethereum adding interoperability and security. The form of decentralized sequencers is in the `shared-sequencer` item |

The post describes based preconfirmations as follows.
A user pays an extra fee, and the proposer issues a promise to include the transaction in the next block and a promise about the result of execution.
A proposer that breaks its promise is slashed.
If a rollup is `based`, its L2 blocks are L1 transactions, so the same mechanism also gives L2 preconfirmations.

## How preconfirmations are sorted

The LongHash Ventures article of 2024-06-12 sorts preconfirmations by the following two axes and by what is promised.
The article discloses that LongHash Ventures has invested in Primev.

| Axis | What the article says |
|---|---|
| What is promised | Three kinds: a promise to include a transaction, a promise about the result of execution, and a promise that the transaction succeeds |
| Where it is built | Outside the protocol or inside it. For L1 transactions it names inclusion lists and execution tickets as ways inside, and Primev's `mev-commit` as a way outside |
| What it is issued for | L1 transactions, L2 transactions, or L2 blobs |
| What based preconfirmations need | Three things: the issuer can always include the promised transaction, an issuer that breaks a promise is punished, and an offchain mechanism through which the user receives the promise and others can read it |
| Preconfirmations from builders | A builder can keep a promise only when it wins the auction. The top three builders make more than 90% of blocks, so the article says promises from all three are kept with a likelihood of more than 90% |
| Proposals of the same period | It lists Commit-Boost, which standardizes how proposers register and hand over promises, Chainbound's bolt, and Primev's proposal to give certainty that L2 blobs get in with mev-commit and inclusion lists |

The research text on ethresear.ch of 2024-07-04, `Leaderless and Leader-Based Preconfirmations`, compares two forms by the number of issuers.

| Form | What the research text says |
|---|---|
| One issuer | One issuer decided in advance for each block. Commit-Boost, which uses the L1 proposer, is the example; one preconfirmation makes inclusion certain unless the slot is missed or reorged |
| Several issuers compete | Several builders issue at once. mev-commit is the example; competition makes pricing work, but one builder's promise holds only when that builder wins the block |
| How issuers are chosen | Issuers are chosen before the preconfirmation bids come in, so the auction for the issuer can be bid only on expected value. One party good at pricing could keep winning and hold a monopoly, so it proposes choosing by lottery |
| Aggregating | It names a role (sourcing leader) that has no power to enforce promises itself but takes users' bids, gathers promises from all issuers, and returns a certain preconfirmation to the user |

## Two ways a promise goes unkept

The research text on ethresear.ch of 2024-06-22, `Avoiding Accidental Liveness Faults for Based Preconfs`, sorts the ways a promise goes unkept into two, for preconfirmations of based rollups.
It says it does not cover preconfirmations of L1 transactions.

| Point | What the research text says |
|---|---|
| liveness fault | Failing to publish a block. It is caused by accidents such as a power cut, a lost connection, or a reorg, and it is hard to decide who is responsible |
| safety fault | Publishing a block that does not keep the promise. It happens only when the issuer or its delegate acts maliciously |
| The penalty issuers want to avoid | To a user both are the same in that the promise is not kept. The fear of having collateral slashed for an accidental liveness fault makes proposers hesitate to join with high collateral |
| preconf chaining | The current issuer's promises pass to the next issuer as the same request. If the current issuer fails to publish its block but the next issuer keeps the promise in the same L2 block number, no one is punished. Only an issuer that published a block and did not keep its promise is punished |
| How many to pass to | If two in a row both fail to publish, both are punished, so passing to three or more avoids it |
| The condition for passing | The next issuer must be able to read the previous issuer's promises. Using an outside DA layer means relying on that DA's sequencer. It says this can be added without changing how preconfirmations are built today |

The form in which Taiko's next stage slashes the collateral of preconfirmers is in the `Taiko's next stage` row of the `based-rollup-preconfirmation` item.

## Six problems of naive preconfirmations

`Strawmanning Based Preconfirmations`, written on ethresear.ch on 2024-05-31 by Nethermind researchers, posits a naive form in which the L1 proposer or its delegate issues preconfirmations in the order requests arrive, and names six problems.
It says how to solve them is left for future research.

| Problem | What the research text says |
|---|---|
| Latency races | The party closest to the issuer learns the latest state first and takes MEV by getting transactions that follow in first. Searchers place their machines in the same place as the issuer or merge with it, harming geographic decentralization |
| Congestion | With low fees, rather than race on latency, searchers spray arbitrage transactions that revert when they fail. It says about 58% of validators' time on Solana went to failed arbitrage transactions |
| Pricing tips | The issuer decides whether to issue a preconfirmation or wait based on the tip it received, without seeing the other transactions that compete for the same position |
| Withholding promises | The issuer has a reason to delay returning promises, to gain more room for reordering and front-running |
| Uptime | With one delegate, uptime and censorship resistance during its slots depend on that one party |
| Early auctions | With preconfirmations of L1 transactions, preconfirmed transactions must go at the top of the block, so the issuer and the builder merge. The proposer would delegate the rights to preconfirmations and to block building to the same party before the slot, a change from today's MEV-Boost, which chooses the builder within the slot |

## Current status

There are two standards that shorten the slot, and both have the status `Draft`.
EIP-7782 shortens the slot from 12 seconds to 6 seconds and was created on 2024-10-05.
EIP-7782 is in neither the Glamsterdam meta EIP (EIP-7773, status `Review`) nor the Hegotá meta EIP (EIP-8081, status `Draft`).
EIP-8198 (Quick Slots) holds the slot length in a schedule by epoch (`SLOT_DURATION_SCHEDULE`) and shortens it from 12 seconds to 10 seconds; it was created on 2026-03-17.
EIP-8198 is under `Considered for Inclusion` in the Hegotá meta EIP.
The EIP-8198 document says preconfirmation mechanisms exist to make up for the slowness of 12 seconds, and that shortening the slot removes the root cause.

Inclusion lists are under `Scheduled for Inclusion` in the Hegotá meta EIP as EIP-7805 (FOCIL).
Their form is in the `eip-7805-focil` item.

bolt stopped.
Its repository `chainbound/bolt` is archived; its last push was on 2025-05-05, the last commit on its default branch on 2025-02-12, and its last release `v0.4.0-alpha` on 2025-01-17.
A Chainbound announcement giving the reason it stopped has not been checked.

The repositories of the proposals of the same period were both not archived as of 2026-11-16.
The last push to `Commit-Boost/commit-boost-client` was on 2026-11-05, and to `primev/mev-commit` on 2026-05-15.

## Not yet shipped

No standard that shortens the slot is live on mainnet, and none is in the Glamsterdam meta EIP.
A standard that defines inside the protocol a form in which the L1 proposer issues preconfirmations has not been checked.
How much the preconfirmations of mev-commit and Commit-Boost are used on mainnet has not been checked.
The figure posts give as bolt's aim, bringing an average confirmation of 7 seconds below one second, is not in the repository's README and has not been checked.
CantelopePeel's X post (2024-07-04) takes up the claim that chains with a small ratio of slot length to round-trip time (s2p) tend to concentrate, and says it is not a good measure and offers another one.
The value of the ratio and the content of the other measure have not been checked in the follow-up posts.
