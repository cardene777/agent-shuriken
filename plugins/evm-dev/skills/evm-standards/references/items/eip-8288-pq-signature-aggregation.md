---
status: specified
checked: 2026-11-23
source: ethereum/EIPs: the EIP-8288, EIP-8141, EIP-8081 (the Hegotá meta EIP), and EIP-8512 documents
can: Contracts could read the post-quantum signatures a transaction declares, which one recursive STARK per block proves, instead of verifying each signature in the EVM.
---

# EIP-8288 (aggregating post-quantum signatures and STARKs in the mempool)

A standard that adds a frame mode to EIP-8141 frame transactions, so that signatures and STARK proofs are proven off-chain and aggregated into one recursive STARK per block.
A transaction declares what it depends on, and block validity requires the recursive STARK that proves all of those dependencies.

| Point | What the document says |
|---|---|
| New frame mode | `DEP_VERIFY_FRAME_MODE` (`4`). A frame in this mode runs no EVM code; its `data` holds 1 to 256 triples of `(scheme, data_hash, verification_key_hash)`, 96 bytes each |
| Schemes | `LEANSPHINCS_SCHEME` (`0x10`) for leanSPHINCS signatures. `LEANSTARK_SCHEME` (`0x11`) is reserved, and a frame that uses it is invalid for now |
| Gas of the frame | 3000 per signature dependency (`LEANSPHINCS_VERIFICATION_GAS`), and 30000 per STARK dependency (`LEANSTARK_VERIFICATION_GAS`) |
| What contracts read | Contracts walk the frames with `FRAMEPARAM`, find the frames whose mode (`FRAMEPARAM(0x02, i)`) is `DEP_VERIFY_FRAME_MODE`, and copy the declared triples with `FRAMEPARAM(0x04, i)` and `FRAMEDATACOPY`. This is the frame introspection that EIP-8141 already has |
| Block | A new top-level header field, `recursive_stark`, holds the aggregated proof of all dependencies of all transactions in the block |
| Mempool | Transactions travel in a wrapper with their dependencies and proofs, and mempool nodes may combine proofs to cut bandwidth. The document says the scheme works with FOCIL (EIP-7805) |
| Why | The document's motivation puts current hash-based signature proposals at about 2 to 3 kB and 150,000 to 200,000 gas to verify, and STARKs at 128 kB or more. These are the EIP's own estimates, not measurements made here |

## Current status

The document's status is `Draft` (Standards Track, Core), it was created on 2026-06-03, and it requires EIP-2718 and EIP-8141.
EIP-8288 is not in any list of the Hegotá meta (EIP-8081), so no network upgrade names it.
EIP-8141 itself is `Scheduled for Inclusion` in the Hegotá meta (the `eip-7701-native-account-abstraction` item).

EIP-8512 (`Draft`, Networking, created 2026-11-22) adds `eth/74` messages that let peers request and serve these proofs.
It describes the header as carrying only a 32-byte commitment, `dependency_proof_hash`, with the proof itself in the `ExecutionPayload`, while the EIP-8288 document puts the proof in the header field `recursive_stark`.
The two documents differ on this point as of 2026-11-23.

## Not yet shipped

Nothing of it runs on mainnet, and no meta EIP schedules it.
The aggregated verification key (`AGGREGATED_VK`) and the dependency hash (`DEPS_HASH`) are still `TBD` in the document.
Which clients implement it has not been checked.
