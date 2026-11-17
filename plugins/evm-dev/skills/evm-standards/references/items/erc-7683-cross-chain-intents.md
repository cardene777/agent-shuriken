---
status: specified
checked: 2026-11-09
source: ethereum/ERCs: the ERC-7683 document
can: Users can place cross-chain orders in a common format that solvers on other chains can read and fill.
---

# ERC-7683 (a common format for cross-chain orders)

A standard that lets the parties who execute orders (solvers) read orders that users placed across chains in a common format.
Because order formats differ between protocols, it defines rules for a `resolver` that converts each format into a common representation of "steps, variables, and payments".

| Point | What the document says |
|---|---|
| What it enables | A solver operator who allows a verified `resolver` address can handle orders from a new protocol without building execution logic for each protocol |
| Protocol side | Provides the `resolver` and the order format |
| Required standards | ERC-7930 |
| Change of scope | Earlier versions defined the life of an order broadly, but the current version is narrowed to the resolution layer |

## Current status

The document's status is `Draft`, and it was created on 2024-04-11.
This was confirmed by reading the document on 2026-11-09.

## Not yet shipped

Since it is not `Final`, its contents may change.
Which protocols use the current version has not been checked.
