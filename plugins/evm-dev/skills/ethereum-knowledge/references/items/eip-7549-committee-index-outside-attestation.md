---
status: live
checked: 2026-11-11
source: ethereum/EIPs: the EIP-7549 document and EIP-7600 (the Pectra meta EIP)
---

# EIP-7549 (The committee index moved outside the signed attestation)

A standard that moved the committee index (`index`) out of the signed content of an attestation (`Attestation`).
Votes for the same consensus can then be aggregated across committees.

| Point | What the document says |
|---|---|
| What changes | The committee index is removed from the signed content |
| The problem it solves | When the index is signed, the same vote signs a different value in each committee, so the votes cannot be aggregated |
| Votes to verify | The votes verified to reach 2/3 drop from 1366 to 22 (on a network of 262144 or more active validators) |
| What a block carries | One block can carry votes for up to 8 slots instead of 2 |
| Who gains | Every kind of client, and above all the ZK circuits that prove Casper FFG |

## Current status

The document's status is `Final`, and it was created on 2023-11-01.
It is included in the Pectra meta EIP (EIP-7600, status `Final`) and went live on mainnet at epoch 364032.
The timestamp is 1746612311, which falls on 2025-05-07.
Posts from 2024 report that the implementation was heavier than estimated, but the form included in Pectra is the current state.

## Not yet shipped

Nothing in the standard remains.
