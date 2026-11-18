---
status: live
checked: 2026-11-18
source: ethereum/EIPs: the EIP-3651 document and EIP-7568 (the meta EIP covering upgrades up to Shapella); ethereum/execution-specs: the Shanghai specification
can: Transactions pay less gas to access the block producer's address (COINBASE), which is warm from the start.
---

# EIP-3651 (Block producer address warm from the start)

A standard that treats the `COINBASE` address as already loaded (warm) at the start of transaction execution.
It aligns the gas charged with the actual cost of reading the address.

| Point | What the document says |
|---|---|
| What changes | Adds the `COINBASE` address to the EIP-2929 list of loaded addresses from the start |
| Required EIPs | EIP-2929 |

## Current status

The document's status is `Final`, and it was created on 2021-07-12.
It is included in the Shanghai specification in execution-specs and went live on mainnet at epoch 194048.
The timestamp is 1681338455, which falls on 2023-04-12.
EIP-7568 lists where to find the specification for Shapella, which combines Shanghai and Capella.

## Not yet shipped

Nothing in the standard remains.
