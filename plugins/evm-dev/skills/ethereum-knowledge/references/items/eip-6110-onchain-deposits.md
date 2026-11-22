---
status: live
checked: 2026-11-11
source: ethereum/EIPs: the EIP-6110 and EIP-7685 documents, EIP-7600 (the Pectra meta EIP), and EIP-8081 (the Hegotá meta EIP)
---

# EIP-6110 (Validator deposits passed in execution layer blocks)

A standard that carries validator deposits in execution layer blocks to the consensus layer.
It ends the form in which the consensus layer received the deposit contract's records by a vote (`eth1data`).

| Point | What the document says |
|---|---|
| How deposits are found | It reads the logs that each transaction in the block emitted from the deposit contract |
| Deposit contract | `0x00000000219ab540356cbb839cbe05303d7705fa` on mainnet |
| How they are passed | As one of the request types of EIP-7685 (`DEPOSIT_REQUEST_TYPE`) in the execution layer block |
| Required standard | EIP-7685 |

## Current status

The document's status is `Final`, and it was created on 2022-12-09.
It is included in the Pectra meta EIP (EIP-7600, status `Final`) and went live on mainnet at epoch 364032.
The timestamp is 1746612311, which falls on 2025-05-07.

## Not yet shipped

Nothing in the standard remains.
EIP-8015, which removes the `deposit` and `eth1data` fields from consensus layer blocks, is under `Considered for Inclusion` in the Hegotá meta EIP (EIP-8081).
Returning deposits made with a different withdrawal address is in the `eip-7684-return-deposits` item.
