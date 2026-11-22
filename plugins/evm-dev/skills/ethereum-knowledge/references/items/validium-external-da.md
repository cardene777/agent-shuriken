---
status: live
checked: 2026-11-11
source: The developer documentation of ethereum.org (Validium), ZKsync's official documentation (Validium in ZK Stack), and the data availability risk page and the project pages of L2BEAT (now named ETHBEAT)
---

# Validiums and outside DA layers

A validium is an L2 that keeps transaction validity with validity proofs while keeping transaction data outside Ethereum.
The split is that the L2 handles execution, Ethereum handles settlement of the validity of state transitions, and another layer handles the data store (the DA layer).
Outside DA layers include dedicated networks (Avail, Celestia, EigenDA) and small sets of trusted parties (data availability committees, DACs).

| Point | What the official documents say |
|---|---|
| The difference from a ZK rollup | ethereum.org says the main difference from a ZK rollup is that a validium's block producers need not publish transaction data |
| Settlement layer | Execution happens outside Ethereum, and Ethereum as the settlement layer guarantees the validity of state transitions |
| Who holds the data | Data managers hold the data and provide it on request. The managers are a set of trusted parties (a DAC), or parties who stake tokens to take on the role and are slashed if they cannot provide the data |
| When data is withheld | If the managers withhold the data, users cannot build the proofs needed to withdraw, so funds freeze and withdrawals are restricted |
| Volition | A form combining a ZK rollup and a validium, in which the user chooses which to use |
| ZK Stack's stages | ZKsync's documentation splits it into three stages: data kept only in the node's storage, data sent to an outside DA layer but not checked on L1, and data sent and checked on L1 for inclusion. It deploys L1 and L2 verifier contracts for each outside DA layer, and names Avail, Celestia, and EigenDA as the first partners |
| Outside DA layers today | L2BEAT lists seven L2s whose data store is EigenDA (the `eigenda` item); seven whose data store is Celestia: Doma, Eclipse, LightLink, Manta Pacific, Nillion, Orderly Network, and Towns; and two whose data store is Avail: Lens and Sophon |
| DA bridges | L2BEAT says Lens and Sophon have a bridge (Vector) that carries Avail's commitments to Ethereum, and that Celo and RISE verify EigenDA certificates on L1 |
| L2BEAT's classification | L2BEAT places Lens and Sophon as Validiums and Celo as an Optimium, and places most of the rest that use outside DA layers under Others |

The details of the ZK Stack framework are in the `zk-stack-elastic-network` item, and the framework of outside DA in the OP Stack is in the `op-stack-alt-da` item.
The details of EigenDA are in the `eigenda` item.

## Current status

L2s using each of Avail, Celestia, EigenDA, and DACs are on L2BEAT's list as mainnets.
A 2024 post announced that ZK Stack supports the validium form, and today's ZKsync documentation describes validiums in three stages.
On the other hand, some L2s, such as Mantle, moved from an outside DA layer to Ethereum blobs (the `mantle` item).

## Not yet shipped

ZKsync's documentation describes the links to Avail, Celestia, and EigenDA as "planned to connect", and does not say which are usable.
The names of the L2s for each outside DA layer were checked on L2BEAT's project pages, but the list of L2s using DACs has not been checked.
The current state of the Celestia and Avail networks themselves has not been checked in their own official documents.
