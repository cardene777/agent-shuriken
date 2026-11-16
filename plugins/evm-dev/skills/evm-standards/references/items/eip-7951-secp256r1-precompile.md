---
status: live
checked: 2026-11-11
source: ethereum/EIPs: the EIP-7951 and EIP-7607 (the Fusaka meta EIP) documents
---

# EIP-7951 (A precompile that verifies secp256r1 signatures)

A standard that adds a precompile so that contracts can cheaply verify ECDSA signatures on the secp256r1 (P-256) curve.
Signatures made by Apple's Secure Enclave, Android's Keystore, and FIDO2 and WebAuthn devices (passkeys) can be verified as they are.

| Point | What the document says |
|---|---|
| Interface | `P256VERIFY` at `0x100` |
| Gas | 6900 |
| Input | 160 bytes |
| Relation to the earlier proposal | It replaces RIP-7212, which is deployed on several L2s. The interface is the same, and bytecode that works with RIP-7212 works unchanged |
| What it fixes | It fixes two weaknesses that RIP-7212 had. One is that RIP-7212 did not check whether the recovered point was the point at infinity |

## Current status

The document's status is `Final`, and it was created on 2025-05-27.
It is part of the Fusaka meta EIP (EIP-7607, status `Final`) and was activated on mainnet at epoch 411392.
The timestamp is 1764798551, which falls on 2025-12-03.
ethereum/EIPs has no EIP-7212 document, and 7212 is the number of an RIP (Rollup Improvement Proposal).

ERC-4337 account validation (`validateUserOp`) is contract code, so it can call this precompile to verify passkey signatures.
The shape of ERC-4337 is covered by the `erc-4337-account-abstraction` item.

## Not yet shipped

Nothing remains within the standard.
Which wallets use this precompile has not been checked.
