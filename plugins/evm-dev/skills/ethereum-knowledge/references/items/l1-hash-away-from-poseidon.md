---
status: announced
checked: 2026-11-11
source: The X post of Ethereum Foundation researcher Justin Drake (2026-08-13) and the post-quantum page of ethereum.org (updated 2026-10-23)
---

# Moving L1 hash functions from Poseidon to SHA or BLAKE

A direction an Ethereum Foundation researcher wrote down: future L1 designs will use long-established hash functions such as SHA or BLAKE instead of Poseidon.
Poseidon is a hash function designed to be fast to prove inside a SNARK; it came out in 2019 and has been widely used in zk rollups and zkVMs.

| Point | What the statement says |
|---|---|
| Statement | Written on X on 2026-08-13 by the Foundation researcher Justin Drake |
| Reason | SNARKs that prove over binary fields (Binius and Flock) can now prove ordinary hash functions such as SHA2 and BLAKE2s as fast as Poseidon |
| Speed | Says a laptop can prove about one million calls of an ordinary hash function per second. This is a trial figure, not the amount Ethereum processes |
| Timing | A production-ready `leanVM` in 2027, brought into the consensus, data, and execution layers in 2028. Reports say both years are estimates |
| What happens to Poseidon | Reports say Poseidon has not been broken, and that neither an order to move nor a fork to move in has come out |

## Current status

The post-quantum page of ethereum.org (updated 2026-10-23) says validator signatures change from BLS to `leanXMSS`, a signature built from hash functions, and that `leanVM` is used as a small zkVM that aggregates signatures.
The same page names no hash function to be used on L1, and gives a goal of building the post-quantum foundation by around 2029.
A search on 2026-11-11 found no EIP and no Foundation blog post that says L1 moves to SHA or BLAKE.
The document of the standard that moves the state tree to a binary tree (EIP-7864) also keeps Poseidon2 among its candidate hash functions (the `state-tree-binary-trie` item).
The status therefore stays `announced`.
When an EIP or a Foundation article that sets out the move comes out, the status becomes `specified`, and the facts come from that document.

## Not yet shipped

- Which versions of SHA and BLAKE are used. Reports differ, some saying SHA-2 and BLAKE2s and others only SHA and BLAKE
- The specification of `leanVM`
