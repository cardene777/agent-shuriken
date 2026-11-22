---
status: specified
checked: 2026-11-11
source: ethereum/EIPs: the EIP-7684 document
---

# EIP-7684 (Return deposits made with a different withdrawal address)

A standard that automatically withdraws and returns a deposit made to an existing validator's record with an execution layer withdrawal address different from the one on record.

| Point | What the document says |
|---|---|
| The problem it solves | When the party that runs the keys and the party that provides the funds are different, the key party can deposit a small amount with its own withdrawal address first and take the funding party's large deposit |
| Today's workaround | Losses are limited by having the two parties generate the keys together, or by depositing 1 ETH first, waiting for it to land in a block, and then adding the rest |
| What changes | A deposit with a different withdrawal address goes into the withdrawal queue, which limits the loss to a fixed penalty (`RETURN_DEPOSIT_PENALTY`) |
| Layer it changes | Only the consensus layer; the execution layer does not change |

## Current status

The document's status is `Stagnant`, and it was created on 2024-04-12.
It is not included in the Pectra meta EIP (EIP-7600) or the Fusaka meta EIP (EIP-7607).
Passing deposits in execution layer blocks is in the `eip-6110-onchain-deposits` item.

## Not yet shipped

It is not live on mainnet.
`Stagnant` means updates have stopped, and whether it will be revived has not been decided.
