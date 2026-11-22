---
status: live
checked: 2026-11-11
source: Scroll's official documentation (Rollup Process, Euclid Upgrade, Feynman Upgrade, and Galileo Upgrade), the notice on Scroll's governance forum of 2026-04-13 (Governance Update), and the Scroll page of L2BEAT (now named ETHBEAT)
---

# Scroll

Scroll is a ZK rollup that aims to behave the same as the EVM.
With the Euclid upgrade of 2025-04, it changed its proof system from halo2 circuits to a prover on OpenVM, and its state tree from zkTrie to the same MPT as Ethereum.
L2BEAT raised it to Stage 1 at the same time, but moved it back to Stage 0 when the Security Council was removed in 2026-06.

| Point | What the official documents say |
|---|---|
| How blocks are made | The sequencer takes transactions from the queue of messages from L1 and from the L2 mempool, and makes L2 blocks |
| How they are bundled | The rollup node bundles blocks into chunks and chunks into batches. The coordinator hands chunk proofs to the zkEVM prover and batch proofs to the aggregation prover |
| What goes to L1 | The relayer sends a batch's data in blobs (commit), and later finalizes it with a validity proof (finalize). Withdrawals are made from L1 with Merkle proofs against the state root of a finalized batch |
| Euclid's dates | On mainnet, phase 1 was applied on 2025-04-16 and phase 2 on 2025-04-22 |
| The move to OpenVM | It dropped the halo2 circuits and moved to a prover built on OpenVM, to lower the cost and latency of proving and to remove the circuit capacity checks that limited the sequencer's throughput |
| The move to MPT | Scroll dropped zkTrie and uses Ethereum's MPT. Node operators resync from scratch with the MPT version of l2geth, and apps that rely on zkTrie proofs move to MPT proofs |
| How Stage 1 works | Users can put transactions in the queue from Ethereum and make the sequencer include them. When the sequencer posts no batch for a long time, anyone can post and finalize a batch |
| The council | At Euclid, an independent council of 12 held it with a 9/12 multisig, and Euclid was the council's first upgrade |
| Account features | It brought in EIP-7702 and RIP-7212, adding contract features to existing accounts and letting them sign with passkeys |
| Data cost | It moves blob checks into the circuits, moves L2 block headers into blobs, and posts several blobs in one transaction. It expects to lower the cost of posting batches by up to 90% |
| Feynman | Applied on mainnet on 2025-08-19. BLOCKHASH returns the real block hash, EIP-2935 and EIP-7623 were brought in, and the feature that skips transactions was removed |
| Galileo | The documentation says it is planned for mainnet in two phases, on 2025-12-16 and 2025-12-18. It cuts the prover's ZK work by about 50%, brings in Fusaka's EIP-7823, EIP-7883, EIP-7951, and EIP-7939, and ships scroll-reth, based on Reth |
| The notice removing the council | On 2026-04-13, Scroll's governance forum announced that the council would be dissolved and control of ScrollOwner and the governance contracts moved to the Scroll Admin multisig. The Scroll Foundation agreed, and says it is looking for a new form of council that fits today's market |

## Current status

Scroll is live, with proofs on OpenVM, the MPT as its state tree, and data posted in Ethereum blobs.
L2BEAT places Scroll at Stage 0, giving as the reason that on 2026-06-01 the independent 9/12 council was replaced by the team's 3/4 admin multisig.
L2BEAT says the contracts can be upgraded immediately, so there is no window to leave an unwanted upgrade, and that users can post on their own when the sequencer and proposer stop.
L2BEAT also lists that on 2026-02-23 the verifier contract was replaced in a hurry because of a bug in the prover program.

A 2023 post, and the 2022 Scroll article it points to, described an architecture with a geth-based sequencer and parallel Rollers making proofs.
Today's documentation calls the proof makers the zkEVM prover and the aggregation prover, and the circuits changed from halo2 to OpenVM, the data from calldata to blobs, and the state tree from zkTrie to MPT.
The post's "a Stage 1 ZK rollup" held from 2025-04 to 2026-06; it is now Stage 0.

## Not yet shipped

Whether the Galileo upgrade was applied on mainnet on the planned dates has not been checked in the official documentation.
The signers of the Scroll Admin multisig and the number of signatures it needs are not in Scroll's notice; 3/4 is the value L2BEAT gives.
The form of a new council and when it will return to Stage 1 have not been given.
Scroll's own post-incident report on the replacement of the verifier contract on 2026-02-23 has not been checked.
