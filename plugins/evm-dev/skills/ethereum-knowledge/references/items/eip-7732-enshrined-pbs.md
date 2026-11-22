---
status: specified
checked: 2026-11-16
source: ethereum/EIPs: the EIP-7732 and EIP-8025 documents and EIP-7773 (the Glamsterdam meta EIP); the gloas and phase0 fork choice documents and the mainnet configuration in ethereum/consensus-specs; and the research post Fork Choice Attacks and Protections in EPBS on ethresear.ch of 2024-07-02
---

# EIP-7732 (Proposer-builder separation enshrined in the protocol)

A standard that carries out the trade between the block proposer and the builder who makes its contents inside the protocol.
The trade, done today by trusting outside relays, moves to a form that relies on no trust.

| Point | What the document says |
|---|---|
| How a block is split | A block is split into a consensus part and an execution part, and a builder chosen by the proposer provides the execution part |
| What is new | Builder registration and deposits, signed bids, and a committee (PTC) that votes on whether the execution part arrived |
| Required standard | EIP-7685 |
| How it is introduced | It needs a hard fork |

## Properties the fork choice protects

The `Fork choice` section of the document says it guarantees the following three properties within a set safety margin.
The fork choice is the rule that chooses which block belongs to the correct chain.

| Property | What the document says |
|---|---|
| proposer unconditional payment | In a slot whose block enters the chain but whose promised execution part does not, the proposer is still paid by the builder |
| builder reveal safety | The execution part of an honest builder that the PTC voted was revealed in time enters the chain |
| builder withhold safety | When a block carrying the builder's commitment is withheld and appears late, the builder does not pay its bid. The builder then need not reveal the execution part |

Voters show how they saw the slot in the `index` field of their vote.
There are three views: `Full`, with the execution part included; `Skipped`, with no block included; and `Empty`, with only the block included.
The three properties are enforced through this vote.

## The share of stake it withstands

The `Security Considerations` section of the document says three things.

| Point | What the document says |
|---|---|
| Builder safety | Proposers and voters who hold consecutive blocks and more than 20% of all stake can collude to reorg a builder's execution part and make it pay its bid |
| free option problem | A builder can withhold its execution part when doing so pays. Slots are missed, the experience of users suffers, and simulations can show the count standing out. Proposals to change the penalty for a builder whose execution part did not enter the chain have been made |
| A malicious PTC | The expected time until an attacker with 35% of all stake holds a majority of the PTC is 205,000 years |

## The boost values

The only boost in the gloas fork choice document of consensus-specs is the proposer boost.
Its value is `PROPOSER_SCORE_BOOST` in the phase0 fork choice document and the mainnet configuration: 40% of the weight of one committee.
gloas does not change the value and adds a condition under which the boost is not applied (`should_apply_proposer_boost`).
The boost is not applied when the parent of the boosted block is from the previous slot with weak weight, and the parent's proposer also published another timely block in the same slot.

The withhold boost and the reveal boost are not in the current specification.
Whether the previous slot's execution part enters the chain is decided by a tiebreaker (`get_payload_status_tiebreaker`), not by vote weight.
When the execution part has been verified and more than 256 of the PTC's 512 votes are both for timely and for data available, it enters the chain.
Otherwise it still enters the chain, except when the current boosted block chose, on top of that block, the side that leaves the execution part out.

The research post of 2024-07-02 set the proposer boost to 20% and the withhold and reveal boosts to 40%, and derived that the share of a malicious committee it withstands drops from 40% to 20%.
The current specification does not take these values.

## Current status

The document's status is `Last Call`, with a deadline given as 2026-11-01, and it was created on 2024-06-28.
The deadline has passed, but as of 2026-11-16 the document's status was still `Last Call`.
The Glamsterdam meta EIP (EIP-7773, status `Review`) lists it among the standards planned for inclusion.
EIP-8025 (status `Draft`), which makes execution proofs optional, relies on this standard.
The form of EIP-8025 is in the `eip-8025-optional-execution-proofs` item.

## Not yet shipped

It is not live on mainnet.
The date Glamsterdam takes effect has not been checked.
