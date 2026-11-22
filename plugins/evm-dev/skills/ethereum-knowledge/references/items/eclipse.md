---
status: live
checked: 2026-11-11
source: Eclipse's official documentation (What is Eclipse, the architecture overview, and the Stage 0 and Stage 1 pages) and the Eclipse page of L2BEAT (now named ETHBEAT)
---

# Eclipse

Eclipse is an L2 that calls itself one that executes with the Solana virtual machine (SVM) and settles on Ethereum.
Its data is kept on Celestia, not on Ethereum.
L2BEAT gives it no stage and places it under Others, since its proof system does not run and it has no bridge to its data store.

| Point | What the official documents say |
|---|---|
| How it describes itself | A fast L2 that settles on Ethereum and combines Ethereum's security with the parallel execution of the SVM |
| Execution and ordering | A permissioned set of sequencers orders and executes transactions offchain |
| Settlement | It makes a summary of the state for each batch of execution and posts it to a contract on Ethereum |
| Data store | Celestia, chosen because it holds more data than EIP-4844 blobs and costs less |
| Proofs | Built as an optimistic rollup, and says fraud proofs are not out yet. It plans fraud proofs that use zero-knowledge technology, built with RISC Zero's Kailua |
| Censorship resistance | Says a queue that forces transactions in can make it resistant to censorship |
| The path to Stage 0 | Names four parts: the Eclipse Gateway contract that posts state to Ethereum, public verification software that re-executes blocks from the data on Celestia, a way to check from Ethereum that the data is on Celestia, and fraud proofs that fit SVM execution. It does not say which of them run or when |
| Data challenges | Says it built a zero-knowledge data challenge mechanism that uses Celestia's Blobstream, but not whether it runs |
| The path to Stage 1 | Names three conditions: anyone can withdraw funds, contract upgrades have a delay, and the Security Council is spread widely enough |
| The earlier architecture | The documentation keeps the earlier architecture in a separate section on the architecture it dropped |

## Current status

L2BEAT places Eclipse under Others and gives two reasons: its proof system does not run, and it has no bridge to its data store.
The L2BEAT page says there is no state validation, so an invalid state root can pass, and that withdrawals have a 7-day delay.
The L2BEAT page says there is no path back from Celestia to Ethereum, and that the roots the sequencer posts are not compared onchain with the data roots of Blobstream.
The description field of the L2BEAT page calls Eclipse a sidechain that runs the SVM.

The L2BEAT page gives as its most serious warning that a 3/5 multisig can upgrade the contracts holding funds on the Ethereum side with no delay, and that code upgrades have no delay.
The L2BEAT page records that on 2026-10-12 the threshold of the multisig that operates the bridge was lowered from 3/4 to 2/4.
L2BEAT writes that only a permissioned party can post state roots, and that withdrawals freeze if that party stops.

A post from 2023 described the testnet as split into execution on the SVM, data on Celestia, settlement on Ethereum, and proofs with RISC Zero.
The split of execution, data, and settlement is still the same, but fraud proofs do not run yet.

## Not yet shipped

Eclipse's documentation does not say when fraud proofs and the Celestia data challenge mechanism will run.
The date Eclipse mainnet started has not been checked in the official documentation or on the L2BEAT page.
