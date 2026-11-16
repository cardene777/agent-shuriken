---
status: specified
checked: 2026-11-11
source: ethereum/EIPs: the EIP-7523 document
---

# EIP-7523 (Declare that there are no empty accounts)

A standard that forbids the state of a post-merge network from containing empty accounts.
Outside of tests there are no empty accounts, and there is no way to create new ones, so in practice it is already met.
It forbids them explicitly so that clients can drop their legacy handling.

| Point | What the document says |
|---|---|
| Networks that went through the merge | The state before the merge block must not contain empty accounts |
| Networks that were post-merge from the start | No account in the initial state may be empty |
| Requires | EIP-161 |

## Current status

The document's status is `Last Call`, with a deadline given as 2024-03-26, and it was created on 2023-09-19.
The deadline has passed, but as of 2026-11-11 the document's status was still `Last Call`.

## Not yet shipped

It has not become `Final`.
