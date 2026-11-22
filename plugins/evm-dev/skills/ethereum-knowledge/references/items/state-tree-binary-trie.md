---
status: specified
checked: 2026-11-11
source: ethereum/EIPs: the EIP-6800 and EIP-7864 documents, EIP-7773 (the Glamsterdam meta EIP), and EIP-8081 (the Hegotá meta EIP)
---

# Moving the state tree from a Verkle tree to a binary tree

A set of proposals that replace the 16-way Patricia tree holding Ethereum's state with another tree.
They make proofs smaller, and make it easier to build stateless clients and proofs of block validity.

| Standard | Status | What the document says |
|---|---|---|
| EIP-6800 | `Stagnant` | Adds a Verkle tree. With today's tree, the witness for reading one account is about 3 kB on average, and it makes that smaller |
| EIP-7864 | `Draft` | Adds a binary tree. It puts the account header, code, and storage in one tree, grouping account data 256 entries at a time |

## What EIP-7864 says

The document gives, as reasons today's tree does not suit validity proofs, RLP encoding, Keccak hashing, the tree-within-a-tree shape, and code not being part of the state.
Going to two branches also makes ordinary Merkle proofs smaller.
The hash function is not decided; the current draft uses BLAKE3 because it is easy to try, and names Keccak and Poseidon2 as candidates too.
A Foundation researcher wrote that L1 drops Poseidon and moves to SHA or BLAKE, but that is not in the document yet (the `l1-hash-away-from-poseidon` item).
The document says a Verkle tree would eventually need replacing with a form that withstands quantum computers, while this tree could be the last state tree.

## Current status

EIP-6800 was created on 2023-03-17, and EIP-7864 on 2025-01-20.
Neither the Glamsterdam meta EIP (EIP-7773) nor the Hegotá meta EIP (EIP-8081) lists either standard.

## Not yet shipped

Neither is `Final`, and neither is live on mainnet.
The hash function of EIP-7864 is not decided.
