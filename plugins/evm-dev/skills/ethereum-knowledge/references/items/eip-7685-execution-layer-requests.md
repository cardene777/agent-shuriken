---
status: live
checked: 2026-11-11
source: ethereum/EIPs: the EIP-7685, EIP-6110, EIP-7002, and EIP-7251 documents and EIP-7600 (the Pectra meta EIP)
---

# EIP-7685 (A general framework for requests from the execution layer to the consensus layer)

A standard for a general framework that carries requests raised by contracts in execution layer blocks to the consensus layer.
Each kind of request gets a type number, so kinds can be added without changing the framework.

| Point | What the document says |
|---|---|
| What the header gains | A 32-byte commitment, `requests_hash` |
| Shape of a request | One type byte (`request_type`) followed by the content bytes (`request_data`); each type defines the shape of its content |
| Layer that processes it | The execution layer collects the requests while processing a block, and the consensus layer later processes them one by one |
| Standards built on it | EIP-6110 (deposits), EIP-7002 (exits and withdrawals), and EIP-7251 (consolidation requests) |

## Current status

The document's status is `Final`, and it was created on 2024-04-14.
It is included in the Pectra meta EIP (EIP-7600, status `Final`) and went live on mainnet at epoch 364032.
The timestamp is 1746612311, which falls on 2025-05-07.

## Not yet shipped

EIP-7732, which brings in the separation of block-building roles, also relies on this framework.
The current status of EIP-7732 is in the `eip-7732-enshrined-pbs` item.
