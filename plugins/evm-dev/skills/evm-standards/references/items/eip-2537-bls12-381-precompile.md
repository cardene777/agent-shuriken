---
status: live
checked: 2026-11-11
source: ethereum/EIPs: the EIP-2537 document and EIP-7600 (the Pectra meta EIP)
---

# EIP-2537 (Precompiles for BLS12-381 curve operations)

A standard that adds operations on the BLS12-381 curve as precompiles that contracts can call cheaply.
It also covers the operations that aggregate public keys and signatures when verifying BLS signatures.

| Point | What the document says |
|---|---|
| Addition | `BLS12_G1ADD` (`0x0b`), `BLS12_G2ADD` (`0x0d`) |
| Multiplication over many points | `BLS12_G1MSM` (`0x0c`), `BLS12_G2MSM` (`0x0e`) |
| Pairing check | `BLS12_PAIRING_CHECK` (`0x0f`) |
| Mapping field elements to points | `BLS12_MAP_FP_TO_G1` (`0x10`), `BLS12_MAP_FP2_TO_G2` (`0x11`) |

## Current status

The document's status is `Final`, and it was created on 2020-02-21.
It is included in the Pectra meta EIP (EIP-7600, status `Final`) and went live on mainnet at epoch 364032.
The timestamp is 1746612311, which falls on 2025-05-07.

## Not yet shipped

Nothing in the standard remains.
Which contracts use it has not been checked.
