---
status: live
checked: 2026-11-11
source: Fluent Labs' official documentation (Getting Started, Architecture Overview, Rollup Architecture, and Connect to Fluent), its official site, the release notes of version v1.0.0 of the fluentbase repository, and the Fluent page of L2BEAT
---

# Fluent

Fluent is an Ethereum L2 that runs EVM contracts and Wasm contracts (such as Rust) on the same state, on one execution environment based on Wasm.
Fluent calls this blended execution.
The official documentation says a Rust contract can call a Solidity contract directly, with no bridge or state sync.

| Point | What the official documents say |
|---|---|
| Execution base | rWasm (an instruction format based on Wasm, reworked to be easy to prove with zero-knowledge proofs). Its behavior is deterministic, and the engine meters the amount of execution |
| Wasm contracts | Converted to rWasm as they are and run |
| EVM contracts | Run by an EVM execution environment that runs on rWasm. Which environment runs a contract is decided by the code at contract creation |
| State | Every execution environment shares one state. An execution environment does not write the state directly; it asks the host through a fixed procedure, and the host enforces the consensus rules |
| SVM | Says the Solana instruction format (SVM) is to be added later |
| Finality | The sequencer posts batches to L1 and puts the data in EIP-4844 blobs. A TEE (trusted execution environment) in AWS Nitro Enclaves signs and pre-verifies them, and they are finalized after a set delay |
| Disputes | Batches and single blocks can be challenged, and challenges are resolved with SP1 zero-knowledge proofs. Today only a permissioned role can challenge; the documentation calls this a temporary setting and aims for a form anyone can use |
| Mainnet | fluentbase v1.0.0 (2026-03-19) says it is Fluent's first production version and the start of mainnet. The official site announced on 2026-04-24 that mainnet was live. The chain ID is 25363 |

## Current status

L2BEAT (whose pages now appear under the name ETHBEAT) places Fluent under Others, because its proof system does not work well enough.
The same page says no one holds the challenger role (`CHALLENGER_ROLE`), so SP1 proofs cannot be submitted, and the validity of state relies on the signatures of the AWS Nitro TEE and a 2-day delay.
The contracts can be upgraded with no delay, and a multisig of 4 of 5 holds the upgrades.
L2BEAT gives 2026-04-24 as the start of mainnet and says the BLEND token launched the same day.

A post from 2023 introduced Fluent as a zkWasm L2, but the current documentation describes a mix of optimistic and zero-knowledge proofs.
The connection page of the official documentation lists mainnet values but still says it is at the testnet stage, so part of the documentation has not caught up with mainnet.

## Not yet shipped

A form that runs SVM contracts.
A form in which anyone can challenge, and anyone holding the challenger role.
The BLEND token and a mechanism for staking tokens to support validators have not been checked in the official documentation.
The amount of first-day liquidity and the number of apps at launch in reports of 2026-04-24 have not been checked.
