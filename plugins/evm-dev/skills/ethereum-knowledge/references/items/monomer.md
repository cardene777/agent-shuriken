---
status: stopped
checked: 2026-11-11
source: Monomer's repository (the README, release notes, and commit history of polymerdao/monomer) and Monomer's official documentation (Introduction and Overview)
---

# Monomer

Monomer is a compatibility layer for running Cosmos SDK apps as Ethereum rollups on the OP Stack.
Its repository is under the Polymer Labs organization, and its documentation is published at a Nethermind address.
After the Devnet release of 2024-10-18, development stopped on 2024-12-20, and it remains pre-production.

| Point | What the official documents say |
|---|---|
| As the OP Stack sees it | It replaces the standard Ethereum-compatible execution layer |
| As a Cosmos app sees it | It replaces the CometBFT consensus layer |
| How it connects | It translates between the OP Stack's Engine API and Cosmos' ABCI, passing the consensus layer's instructions to the execution layer |
| Block header | It puts the Cosmos AppHash as data in the EVM state tree |
| Choice of execution | The documentation says it can run EVM, CosmWasm, or Go apps with no VM |
| Releases | v0.1-alpha on 2024-05-09, the Devnet release v0.1.0 on 2024-10-18, and the last release v0.1.7 on 2024-12-20 |
| State of development | The README says active development has stopped, and asks for care in use since it is pre-production software |

The framework of the OP Stack is in the `op-stack-superchain` item.

## Current status

The README, from a change merged on 2024-12-20, says active development of Monomer is stopped for now.
The last commit on the default branch is also from 2024-12-20, and development stopped at the stage where it runs on a Devnet.
The repository shows activity as late as 2026-10-20, but only because an automated dependency update tool (dependabot) created branches and pull requests.
The README and the documentation say it is pre-production and name no chain running on mainnet.
The developer wrote in the README that development stopped, so the status is `stopped`.
The README says "for now", leaving room to resume development.

The 2024 post's "Cosmos SDK apps can launch as Ethereum rollups" stopped at the Devnet stage.

## Not yet shipped

Whether any rollup running on Monomer is on mainnet has not been checked.
The flow of deposits and withdrawals, and support for fraud proofs, are not written in the pages read and have not been checked.
Neither the repository nor the documentation says when development will resume.
