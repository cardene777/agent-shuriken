---
status: live
checked: 2026-11-18
source: ethereum/EIPs: the EIP-6780, EIP-6049, and EIP-8246 documents, plus EIP-7569 (the Dencun meta EIP) and EIP-7773 (the Glamsterdam meta EIP); the Ethereum Foundation blog: the Glamsterdam post of 2026-10-22
can: SELFDESTRUCT only sends the account's ETH to the target, unless it runs in the same transaction that created the contract.
---

# EIP-6780 (SELFDESTRUCT limited to the same transaction)

A standard that narrows `SELFDESTRUCT` to only sending all of the account's ETH to the target.
Only when it is called in the same transaction that created the contract does it delete the contract as before.

| Point | What the document says |
|---|---|
| Normal case | Only sends ETH to the target, and does not delete the code or the storage |
| Created in the same transaction | Deletes the contract as before. If the target is the contract itself, its ETH is burned |
| Required EIPs | EIP-2681, EIP-2929, EIP-3529 |

## Current status

The document's status is `Final`, and it was created on 2023-03-25.
It is included in the Dencun meta EIP (EIP-7569) and went live on mainnet at epoch 269568.
The timestamp is 1710338135, which falls on 2024-03-13.
EIP-6049 (status `Final`), which went into Shanghai, only gave advance notice that `SELFDESTRUCT` would be phased out and did not change its behavior.

## Not yet shipped

The Glamsterdam meta EIP (EIP-7773) lists EIP-8246 (`Remove SELFDESTRUCT Burn`, status `Last Call`) under `Scheduled for Inclusion`.
It keeps the balance of a contract that self-destructs in its creation transaction, clearing only its code, storage, and nonce, so no ETH is burned.
Glamsterdam has no mainnet date (Ethereum Foundation blog, 2026-10-22).
