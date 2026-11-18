---
status: specified
checked: 2026-11-18
source: ethereum/ERCs: the ERC-7760 document
can: Upgradeable proxies that follow ERC-1967 can be deployed with minimal bytecode.
---

# ERC-7760 (minimal upgradeable proxies)

A standard for deploying ERC-1967 compliant upgradeable proxies with minimal bytecode.

| Point | What the document says |
|---|---|
| Variants | Three: `transparent`, `UUPS`, and `beacon` |
| What can be added | Immutable arguments can be appended to the end of the bytecode |
| Variants with `I` | The implementation address can be queried on chain |
| What it enables | Deploys with less gas and smaller bytecode, and passes block explorers' automatic verification more easily |
| Required standards | ERC-1967 |

## Current status

The document's status is `Draft`, and it was created on 2024-08-19.
This was confirmed by reading the document on 2026-11-18.

## Not yet shipped

Since it is not `Final`, the bytecode rules may change.
Which wallets use it has not been checked.
