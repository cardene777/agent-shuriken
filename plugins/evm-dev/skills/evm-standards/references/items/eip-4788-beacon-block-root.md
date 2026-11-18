---
status: live
checked: 2026-11-18
source: ethereum/EIPs: the EIP-4788 document and EIP-7569 (the Dencun meta EIP)
can: Contracts can read the parent beacon block root, so they can check facts about the consensus layer against it with proofs.
---

# EIP-4788 (Beacon block root readable from the EVM)

A standard that puts the parent beacon block root into each execution layer block and makes it readable by contracts.
The root allows proofs of any consensus layer state, and the document names staking pools, restaking, bridges, and MEV mitigations as uses.

| Point | What the document says |
|---|---|
| Location | The contract at `0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02` |
| How to query | Pass the timestamp of an execution block, and it returns the parent beacon block root stored with that block. It reverts when that timestamp is not stored |
| How long it is kept | Kept in a ring of 8191 entries (`HISTORY_BUFFER_LENGTH`), overwriting the oldest first |

## Current status

The document's status is `Final`, and it was created on 2022-02-10.
It is included in the Dencun meta EIP (EIP-7569) and went live on mainnet at epoch 269568.
The timestamp is 1710338135, which falls on 2024-03-13.

## Not yet shipped

Nothing in the standard remains.
Which contracts use it has not been checked.
