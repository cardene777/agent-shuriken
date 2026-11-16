---
status: specified
checked: 2026-11-11
source: ethereum/ERCs: the ERC-7546 document
---

# ERC-7546 (proxies that can be cloned and upgraded)

A standard that lets many proxies of the same form be cloned and upgraded together.

| Point | What the document says |
|---|---|
| Per-function upgrades | Like ERC-2535 (Diamond), the implementation contract can be swapped for each function call |
| Upgrading together | Following ERC-1967's Beacon pattern, cloned proxies are updated at once, while each clone keeps its own state |
| Problem it solves | Because implementations are split by function, contracts are less likely to hit the contract size limit |
| Required standards | ERC-165, ERC-1967, ERC-7201 |

## Current status

The document's status is `Draft`, and it was created on 2023-10-25.
Another standard for deploying minimal proxies is in the `erc-7760-minimal-upgradeable-proxies` item.
ERC-7760 swaps a single implementation, which differs from this standard, which splits implementations by function.

## Not yet shipped

Since it is not `Final`, its rules may change.
Which apps use it has not been checked.
