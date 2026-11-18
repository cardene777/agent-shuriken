---
status: specified
checked: 2026-11-18
source: ethereum/ERCs: the ERC-7683 document and its change history
can: Solvers can read and fill orders from any intent protocol, including cross-chain orders, through the protocol's resolver contract, which turns its own order format into a common representation.
---

# ERC-7683 (a common format for cross-chain orders)

A standard that lets the parties who execute orders (solvers) read the orders of intent protocols, such as cross-chain orders, in a common form.
Protocols keep their own order format as an opaque payload, and a `resolver` contract, which solvers call off chain with `eth_call`, converts it into a common representation of "steps, variables, and payments".

| Point | What the document says |
|---|---|
| What it enables | A solver who vets a protocol's `resolver` can handle that protocol's orders without building execution logic for each protocol |
| Protocol side | Provides the `resolver` and the order format. It need not use a common escrow, settlement contract, or fill function |
| Required standards | ERC-7930 (interoperable addresses) |
| Change of scope | The earlier draft defined the order types `OnchainCrossChainOrder` and `GaslessCrossChainOrder`, `IOriginSettler.open` and `openFor`, `ResolvedCrossChainOrder`, and `IDestinationSettler.fill`. The redesign merged on 2026-05-13 drops them, narrows the standard to how solvers read orders, and applies it to intent protocols in general |

## Current status

The document's status is `Draft`, and it was created on 2024-04-11.
This was confirmed by reading the document on 2026-11-18.

## Not yet shipped

Since it is not `Final`, its contents may change.
Which protocols use the current version has not been checked.
