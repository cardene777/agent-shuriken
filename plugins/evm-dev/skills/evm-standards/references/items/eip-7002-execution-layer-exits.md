---
status: live
checked: 2026-11-18
source: ethereum/EIPs: the EIP-7002, EIP-7685, and EIP-7600 (the Pectra meta EIP) documents
can: A validator with an execution layer withdrawal credential can trigger exits and partial withdrawals through an execution layer transaction.
---

# EIP-7002 (Execution layer triggered exits and withdrawals)

A standard that lets a validator with an execution layer withdrawal credential (`0x01`) trigger exits and partial withdrawals through an execution layer transaction.
Before it, only the holder of the key that signs validator duties could trigger an exit, and the holder of the withdrawal credential, who owns the funds, could not.

| Point | What the document says |
|---|---|
| Where requests go | Call the contract at `0x00000961Ef480Eb55e80D19ad83579A64c007002` |
| How they are passed | The request goes into an execution layer block, and the consensus layer processes it as an EIP-7685 request |
| Limit per block | `MAX_WITHDRAWAL_REQUESTS_PER_BLOCK` requests, which is 16, are taken from the queue |
| Fee | The caller pays a fee that rises as there are more requests. Overpaid fees are not returned, so a calling contract can read the current fee (a call with empty input) and pay exactly that; an EOA always overpays |
| Requires | EIP-7685 |

## Current status

The document's status is `Final`, and it was created on 2023-05-09.
It is part of the Pectra meta EIP (EIP-7600, status `Final`) and was activated on mainnet at epoch 364032.
The timestamp is 1746612311, which falls on 2025-05-07.

## Not yet shipped

Nothing remains within the standard.
Which staking systems call this contract has not been checked.
