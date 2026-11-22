---
status: live
checked: 2026-11-16
source: ethereum/EIPs: the EIP-7045 document and EIP-7569 (the Dencun meta EIP); the Deneb consensus layer specification in ethereum/consensus-specs; and the analysis Deep Diving Attestations - A quantitative analysis posted by Nero_eth on ethresear.ch
---

# EIP-7045 (Attestations includable until the end of the next epoch)

A standard that extends the last slot in which a validator's vote (attestation) can be included in a block to the end of the epoch after the one holding the vote's slot.
The safety proof of LMD-GHOST and a new confirmation rule that confirms blocks in 3 to 4 slots on a normal network rely on this extension.

| Point | What the document says |
|---|---|
| Inclusion range | A vote for a slot of epoch N can be included in a block until the last slot of epoch N+1 |
| The earlier range | Up to `SLOTS_PER_EPOCH` (32 slots) after the vote's slot, the same length for every vote |
| Reward for the target vote | `TIMELY_TARGET_FLAG` is set whatever the inclusion delay, so a vote included within the extended range also earns a nonzero reward |
| What changes | `process_attestation` and `get_attestation_participation_flag_indices` of the consensus layer, and the gossip conditions for spreading votes. The execution layer does not change |

## Current status

The document's status is `Final`, and it was created on 2023-05-18.
It is included in the Dencun meta EIP (EIP-7569, status `Final`) and went live on mainnet at epoch 269568.
The timestamp is 1710338135, which falls on 2024-03-13.

## Not yet shipped

Nothing in the standard remains.
Whether mainnet clients use the confirmation rule that confirms blocks in 3 to 4 slots has not been checked.

## Notes

The analysis `Deep Diving Attestations - A quantitative analysis`, posted by Nero_eth on ethresear.ch on 2024-07-09, counted the votes after Deneb.
It covers slots 9,169,184 to 9,392,415 (2024-05-27 to 2024-06-28), which the analysis gives as 6,975 epochs, or 31 days.
95.85% of the votes were included in the block of the next slot, and about 1.2% in the slot after that.

The analysis says a reward is paid when the source vote is included within 5 slots, the target vote within 32 slots, and the head vote in the next slot.
In the Deneb consensus layer specification, the reward flag is set when the source vote is included within 5 slots and the head vote in the next slot, and the target vote has no condition on its inclusion delay.
The 32-slot condition on the target vote is the rule from before Deneb; the document and the specification are taken as correct.
