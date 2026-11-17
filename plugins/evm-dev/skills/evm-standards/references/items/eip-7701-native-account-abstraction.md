---
status: specified
checked: 2026-11-11
source: ethereum/RIPs: the RIP-7560 document; ethereum/ERCs: the ERC-7562 document; ethereum/EIPs: the EIP-7701, EIP-8141, and EIP-8081 (Hegotá meta) documents
can: Accounts could have their validation and gas payment handled by the protocol as a transaction type, instead of through ERC-4337.
---

# EIP-7701 (native account abstraction in the protocol)

A group of proposals that put per-account validation and gas payment into the protocol as a transaction type, rather than into ERC-4337 on the layer above.

| Standard | Status | What the document says |
|---|---|---|
| RIP-7560 | `Draft` | For rollups. Combines EIP-2938 and ERC-4337 and adds a new transaction type (`AA_TX_TYPE`, number not yet assigned) that splits a transaction into a validation phase, an execution phase, and a phase after that. It assumes EIP-7702 |
| ERC-7562 | `Review` | Rules imposed on code that validates ERC-4337 `UserOperation`s. Bundlers and block builders enforce them off-chain to prevent attacks that stall nodes with unpaid computation |
| EIP-7701 | `Withdrawn` | Account abstraction for L1. The reason given for withdrawal is "replaced by EIP-8141" |
| EIP-8141 | `Draft` | A new transaction that is split into a sequence of frames with roles such as validating, approving gas payment, and executing. A frame's `mode` is one of three: `DEFAULT`, `VERIFY`, and `SENDER` |

## Current status

RIP-7560 was created on 2023-09-01, ERC-7562 on 2023-09-01, EIP-7701 on 2024-05-01, and EIP-8141 on 2026-01-29.
The Hegotá meta (EIP-8081, status `Draft`) lists EIP-8141 as `Scheduled for Inclusion`.
The L1 proposal has moved from EIP-7701 to EIP-8141.

## Not yet shipped

None of them is `Final`, and none runs on mainnet.
The Hegotá meta gives no activation date.
Which rollups run RIP-7560 has not been checked.
