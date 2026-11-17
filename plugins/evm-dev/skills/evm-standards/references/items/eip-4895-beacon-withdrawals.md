---
status: live
checked: 2026-11-11
source: ethereum/EIPs: the EIP-4895 document and EIP-7568 (the meta EIP covering upgrades up to Shapella); ethereum/execution-specs: the Shanghai specification; ethereum/consensus-specs: the mainnet configuration
can: Validator withdrawals from the beacon chain arrive at execution layer addresses as a system operation, without a transaction.
---

# EIP-4895 (Beacon chain withdrawals pushed to the execution layer)

A standard that adds validator withdrawals as a system operation pushed from the beacon chain to the execution layer.

| Point | What the document says |
|---|---|
| Form | The block carries a list of withdrawals, handled as a system operation separate from transactions |
| What it does | Increases the balance of the given recipient unconditionally |
| Gas | The operation costs no gas |

## Current status

The document's status is `Final`, and it was created on 2022-03-10.
It is included in the Shanghai specification in execution-specs and went live on mainnet at epoch 194048.
In the consensus-specs mainnet configuration, Capella on the consensus layer went live at the same epoch.
The timestamp is 1681338455, which falls on 2023-04-12.

## Not yet shipped

Nothing in the standard remains.
Triggering withdrawals and exits from the execution layer is covered in the `eip-7002-execution-layer-exits` item.
