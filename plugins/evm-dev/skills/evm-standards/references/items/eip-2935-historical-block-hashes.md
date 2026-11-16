---
status: live
checked: 2026-11-11
source: ethereum/EIPs: the EIP-2935 document and EIP-7600 (the Pectra meta EIP)
---

# EIP-2935 (Past block hashes kept in state)

A standard that writes recent block hashes into the storage of a system contract each time a block is processed.
It lets proofs about past blocks be built and verified against the current state.

| Point | What the document says |
|---|---|
| Location | The contract at `0x0000F90827F1C53a10cb7A02335B175320002935` |
| How many it keeps | 8191 entries (`HISTORY_SERVE_WINDOW`) |
| Relation to `BLOCKHASH` | Does not change the range or the gas of the `BLOCKHASH` opcode |

## Current status

The document's status is `Final`, and it was created on 2020-09-03.
It is included in the Pectra meta EIP (EIP-7600, status `Final`) and went live on mainnet at epoch 364032.
The timestamp is 1746612311, which falls on 2025-05-07.

## Not yet shipped

Nothing in the standard remains.
Whether any application reads the contract has not been checked.
