---
status: live
checked: 2026-11-11
source: Aztec's documentation (the zk.money guide, Networks, Blocks, and Accounts), Aztec's contract repository (`RollupCore.sol` and `DeployRollupForUpgradeV6.s.sol` at version 6.0.0 of aztec-packages, and `EpochProofLib.sol` on the default branch), and the 2025-05-28 post on Aztec's forum (Update on Proving Coordination)
---

# Aztec

Aztec is an Ethereum L2 whose transactions are proven on the user's device.
Today's Aztec network is separate from Aztec Connect, the older rollup whose sequencer Aztec announced it would stop on 2024-03-31.
Today's network advances its state with both the signatures of a committee chosen for each epoch (a set of consecutive slots) and a validity proof for each epoch.

| Point | What the official documents say |
|---|---|
| Aztec Connect stopped | The guide says Aztec Connect, which Aztec ran, stopped taking deposits on 2023-03-21, processed transactions and withdrawals until 2024-03-31, and stops its sequencer then. The guide says the code is public, so anyone can produce blocks or run it themselves |
| Today's network | Alpha (mainnet) is deployed on Ethereum mainnet at version 6.0.0 (Tierra) and takes user transactions. The documentation says Alpha is live but at an early stage, and that severe bugs may occur |
| Block producer | For each slot, one of the validators who put down a stake is chosen with Ethereum's RANDAO, and that validator builds the block |
| Committee signatures | One committee is chosen from the validators for each epoch. A block needs the signatures of more than two thirds of the committee |
| What the signatures do | The signatures do two things: they show that the transaction data not posted to L1 was received, and they sign the state root after re-executing everything. The contract's comments call the second training wheels for public execution and the proving system of the AVM (Aztec's virtual machine) |
| When a proof is verified | When an epoch proof is submitted, the contract checks the committee signatures on the last block of the epoch and verifies the proof cryptographically |
| Provers | Provers need no stake. Several proofs can be submitted for the same epoch, and proofs of part of an epoch are accepted. Those who proved the longest run share the reward, which is 30% of the reward of each checkpoint; the other 70% and the transaction fees go to the sequencer |
| Proof deadline | Blocks with no proof by the deadline are removed and must be produced again |
| Production values | The script in the code tagged 6.0.0 that deploys to mainnet sets a slot of 72 seconds, an epoch of 32 slots, a target committee size of 48, and a proof deadline of one epoch |
| The update of 2025-05 | The 2025-05-28 post on Aztec's forum removed the earlier registration and stake, so that anyone can submit a proof and those who submit a correct proof by the deadline share the reward equally. It replaces the two-stage form in which provers put down a large stake and submitted quotes |
| Accounts | Every account is a contract; there are no EOAs. Checks such as signatures run inside a zero-knowledge proof on the user's device, and the sequencer verifies only the proof |
| Replay protection and fees | How replays of the same transaction are prevented and how fees are paid are decided by each account contract, not by the protocol |

## Current status

Alpha runs on Ethereum mainnet and takes user transactions.
The zk.money guide in Aztec's documentation asks Aztec Connect users to withdraw their funds now.

A post from 2023 proposed training wheels that guard against bugs in the ZK proofs with an aggregate signature of L2 stakers.
In the 6.0.0 contracts, the committee signatures play the role of training wheels.
What they are training wheels for is public execution and the AVM proving system.

The three options for assigning provers listed in a 2023 post differ from the form of today's contracts.
The 6.0.0 contracts are written so that anyone can submit a proof without a stake and several proofs are accepted.

## Not yet shipped

Whether the values of the contracts deployed on mainnet match those of the deployment script has not been checked on chain.
The date Alpha mainnet started has not been checked in Aztec's documentation.
Where L2BEAT places Aztec has not been checked.

That the Aztec Connect sequencer was actually stopped on 2024-03-31 has not been checked in an official report after the fact.
What date the original announcement of 2023-03 gave for stopping the sequencer has not been checked.
Reports that Aztec Connect's closed bridge was attacked in 2026 have not been checked.
