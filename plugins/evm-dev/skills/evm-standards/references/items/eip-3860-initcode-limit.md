---
status: live
checked: 2026-11-11
source: ethereum/EIPs: the EIP-3860 document, EIP-7568 (the meta EIP covering upgrades up to Shapella), and EIP-7773 (the Glamsterdam meta EIP); ethereum/execution-specs: the Shanghai specification
---

# EIP-3860 (Size limit and gas for contract creation code)

A standard that puts a size limit on the code run when a contract is created (`initcode`) and charges gas according to its size.

| Point | What the document says |
|---|---|
| Limit | `MAX_INITCODE_SIZE` is 49152 bytes, twice `MAX_CODE_SIZE` |
| Gas | Charges 2 gas per 32 bytes (`INITCODE_WORD_COST`) |
| When the limit is exceeded | A creation transaction is invalid. `CREATE` and `CREATE2` stop the same way as when they run out of gas |
| Reason | Makes the cost of jump destination analysis paid for with gas |
| Required EIPs | EIP-170 |

## Current status

The document's status is `Final`, and it was created on 2021-07-16.
It is included in the Shanghai specification in execution-specs and went live on mainnet at epoch 194048.
The timestamp is 1681338455, which falls on 2023-04-12.

## Not yet shipped

Nothing in the standard remains.
EIP-7954, which raises the contract size limit, is listed under `Scheduled for Inclusion` in the Glamsterdam meta EIP (EIP-7773).
