---
status: specified
checked: 2026-11-23
source: ethereum/EIPs: the EIP-8292 document and EIP-8081 (the Hegotá meta EIP)
---

# EIP-8292 (aggregators of post-quantum attestations)

A standard that adds an opt-in aggregator role to the beacon chain for post-quantum consensus.
Post-quantum consensus replaces BLS signatures with hash-based signatures, which are larger and cannot be combined by adding them together, so an aggregator proves many of them valid in one succinct proof instead.

| Point | What the document says |
|---|---|
| Who aggregates | Any node may opt in as an aggregator if its hardware can prove within the slot. Aggregation is split from block production |
| What an aggregator does | It subscribes to at least one attestation subnet, collects the signed attestations for each attestation message, proves their signatures into one aggregate, and gossips it |
| What the proposer does | The proposer, not the aggregator, folds the per-message aggregates into one block proof, up to `MAX_ATTESTATIONS_DATA` (8) distinct messages per block |
| Proof size | Soft targets, not consensus rules: a hard bound of 512 KiB, and about 185 to 230 KiB in the benchmarks the document cites |
| Proving time | About 2.6 s on 16 cores and about 11 s on 2 cores for 1000 signatures, from the same benchmarks. Core count sets whether an aggregator meets the slot |
| Where the rules live | The signature scheme, the proof system, the wire formats, and the consensus and fork-choice rules are in the post-quantum consensus specification, leanSpec |

## Current status

The document's status is `Draft` (Standards Track, Core), and it was created on 2026-06-07.
The execution layer is unchanged by this EIP; it changes only the consensus layer, and defers the detailed rules to leanSpec.
The document says the fork that activates aggregators is assigned by the relevant meta EIP, and EIP-8292 is not in any list of the Hegotá meta (EIP-8081), so no network upgrade names it.

The post-quantum page of ethereum.org and the move away from Poseidon are covered by the `l1-hash-away-from-poseidon` item, and the proposal to bring the post-quantum work forward by the `l1-pqai27-proposal` item.

## Not yet shipped

Nothing of it runs on mainnet.
The number of subnets (`SUBNET_COMMITTEES`) is still to be decided, in the EIP and in leanSpec.
The document reports the current proof system at about 124-bit classical and 62-bit quantum security, short of the NIST Level 1 target, and calls closing that gap ongoing work.
Whether the hardware envelopes become a published minimum, and the prover centralization that would follow, are open questions in the document.
