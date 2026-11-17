---
status: live
checked: 2026-11-10
source: ethereum/EIPs: the EIP-4788 document and EIP-7569 (the Dencun meta EIP)
can: Contracts can read the parent beacon block root, so they can check facts about the consensus layer against it with proofs.
---

# EIP-4788 (Beacon block root readable from the EVM)

A standard that puts the parent beacon block root into each execution layer block and makes it readable by contracts.
Contracts can prove consensus layer state (validator balances and slashings) without a trusted third party.

| Point | What the document says |
|---|---|
| Location | The contract at `0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02` |
| How to query | Pass a timestamp, and it returns the block root for that timestamp |
| How long it is kept | Kept in a ring of 8191 entries (`HISTORY_BUFFER_LENGTH`), overwriting the oldest first |

## Current status

The document's status is `Final`, it is included in the Dencun meta EIP (EIP-7569), and it went live on mainnet at epoch 269568.
The timestamp is 1710338135, which falls on 2024-03-13.

## Not yet shipped

Nothing in the standard remains.
There is a prototype post (2024) that proves a slashed validator, but no implementation in use has been checked.
