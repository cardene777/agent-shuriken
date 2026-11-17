---
status: live
checked: 2026-11-11
source: ethereum/EIPs: the EIP-6780 and EIP-6049 documents, plus EIP-7569 (the Dencun meta EIP) and EIP-7773 (the Glamsterdam meta EIP)
can: SELFDESTRUCT only sends the account's ETH to the target, unless it runs in the same transaction that created the contract.
---

# EIP-6780 (SELFDESTRUCT limited to the same transaction)

A standard that narrows `SELFDESTRUCT` to only sending all of the account's ETH to the target.
Only when it is called in the same transaction that created the contract does it delete the contract as before.

| Point | What the document says |
|---|---|
| Normal case | Only sends ETH to the target, and does not delete the code or the storage |
| Created in the same transaction | Deletes the contract as before |
| Required EIPs | EIP-2681, EIP-2929, EIP-3529 |

## Current status

The document's status is `Final`, and it was created on 2023-03-25.
It is included in the Dencun meta EIP (EIP-7569) and went live on mainnet at epoch 269568.
The timestamp is 1710338135, which falls on 2024-03-13.
EIP-6049 (status `Final`), which went into Shanghai, only gave advance notice that `SELFDESTRUCT` would be phased out and did not change its behavior.

## Not yet shipped

The Glamsterdam meta EIP (EIP-7773) lists EIP-8246 (titled `Remove SELFDESTRUCT Burn`) under `Scheduled for Inclusion`.
The contents of EIP-8246 have not been checked.
