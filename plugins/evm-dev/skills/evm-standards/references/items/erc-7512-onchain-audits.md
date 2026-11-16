---
status: specified
checked: 2026-11-10
source: ethereum/ERCs: the ERC-7512 document
---

# ERC-7512 (audit reports stored on chain)

A draft standard for putting audit reports on chain in a form that contracts can read.
Contracts can check who did the audit and which standards a contract follows.

| Point | What the document says |
|---|---|
| What is stored | The auditor, the audited target, and the standards it follows |
| Signatures | Has EIP-712 in `requires`, and verifies the auditor with typed signatures |

## Current status

The document's status is `Draft`, and it was created on 2023-09-05.
A 2023 post announced a new standard and did not give its number.
The number is ERC-7512.

## Not yet shipped

Finalization of the standard.
Which audit firms and wallets store reports in this form has not been checked.
