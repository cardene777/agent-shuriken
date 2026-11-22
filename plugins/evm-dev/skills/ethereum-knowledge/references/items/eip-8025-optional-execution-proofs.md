---
status: specified
checked: 2026-11-11
source: ethereum/EIPs: the EIP-8025 document and EIP-8081 (the Hegotá meta EIP)
---

# EIP-8025 (Optional execution proofs)

A standard that lets consensus layer nodes verify the contents of execution layer blocks without holding state.
Nodes that make proofs spread execution proofs on the consensus layer's p2p network, and verifying nodes judge whether a block is valid by verifying the proofs.

| Point | What the document says |
|---|---|
| Who makes proofs | Nodes that ask for nothing in return make execution proofs and spread them on the consensus layer's network |
| Who verifies proofs | Nodes verify the spread proofs and judge whether a block is valid without holding execution layer state |
| Cost of verifying | Verification takes a constant time, whatever the block gas limit and the size of the state |
| Required standards | EIP-4844, EIP-6110, EIP-7002, EIP-7251, EIP-7688, EIP-7732, EIP-7928, and EIP-8282 |

## Current status

The document's status is `Draft`, and it was created on 2025-09-17.
The Hegotá meta EIP (EIP-8081, status `Draft`) places EIP-8025 under `Declined for Inclusion`.
The current status of EIP-7732, which it requires, is in the `eip-7732-enshrined-pbs` item.

## Not yet shipped

It is not `Final` and is not live on mainnet.
Which upgrade after Hegotá it will be in has not been decided.
