---
status: live
checked: 2026-11-11
source: The OP Stack specification (Alt-DA Mode), Optimism's official documentation (Blockspace Charter), Optimism's superchain-registry repository, Optimism's blog (Redstone Mainnet is live featuring Plasma Mode), Lattice's wind-down announcement (Winding down), and the Redstone page of L2BEAT
---

# OP Stack Alt-DA

Alt-DA in the OP Stack (formerly named Plasma Mode) keeps transaction data in an outside data store instead of Ethereum mainnet, and puts only a commitment on L1.
When the data does not appear, anyone can challenge in the `DataAvailabilityChallenge` contract on L1.
If a challenge stays unanswered, the L2 blocks derived from that data are rolled back.

| Point | What the official documents say |
|---|---|
| Status of the specification | The OP Stack specification calls Alt-DA a Beta feature, still under testing, in which bugs may remain |
| What goes on L1 | The batcher posts the commitment as calldata of a transaction to the inbox on L1 only after it has saved the data to the outside store |
| Kinds of commitment | Type 0 is the keccak256 of the content and can be handled by the challenge contract. Type 1 is a commitment whose shape the outside DA layer decides; there is no way to check it on chain, and the challenge contract cannot handle it |
| How to challenge | For a set number of L1 blocks after the commitment lands on L1, anyone can call `challenge`, with a bond at least as large as the cost of answering |
| How to answer | Within a set number of L1 blocks, someone calls `resolve` and puts the data on L1 as calldata |
| When there is no answer | The bond goes back to the challenger, and the L2 blocks derived from the challenged input are rolled back and derivation is redone |
| Link to fraud proofs | Two hints are added to the preimage oracle, passing to the proof program the data matching a commitment and the challenge status as of a given L1 block |
| How safety is treated | Blocks derived from commitments carry the "safe" label but can be rolled back if the DA provider fails. They are final when the L1 block holding the commitment is finalized and the commitment can no longer be overturned |
| Relation to the standard | The Standard Rollup Charter requires the default way of storing data for standard rollups, so Alt-DA chains are not standard |
| Redstone | Lattice's chain, which went to mainnet on 2024-05-01 as the first chain to use Plasma Mode |

## Current status

There are chains running on Alt-DA.
The list in Optimism's superchain-registry marks the data store field as `alt-da` for mainnets such as Celo, Fraxtal, Cyber, Lyra, and Automata.
Lattice's announcement of 2026-04 said Redstone stops at 23:59 UTC on 2026-05-15, and that afterward only ETH and WETH held by EOAs can be recovered through the withdrawal contract on L1.

The L2BEAT page (now appearing under the name ETHBEAT) places Redstone under Others, because its proof system does not work well enough.
The same page says there is no state validation, that DA is a custom provider with no attestation, that the owner of the challenge contract can change the bond amount, and that the contracts can be upgraded with no waiting time.
L2BEAT keeps the Redstone page as one that has served its purpose, and the registry's list also marks Redstone's fraud proofs as none.

The 2023 post's "Redstone launches on a testnet, and mainnet comes later" was true when posted; Redstone went to mainnet on 2024-05-01 and was scheduled to stop on 2026-05-15.

## Not yet shipped

Whether Redstone actually stopped on 2026-05-15 and whether the withdrawal contract on L1 was deployed have not been checked.
The specification gives no values for the length of the challenge and answer periods, and the values of each chain have not been checked.
Whether any challenge has been raised on Redstone, and how it was answered, have not been checked.
