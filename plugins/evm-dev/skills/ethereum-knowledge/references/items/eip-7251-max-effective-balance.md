---
status: live
checked: 2026-11-10
source: ethereum/EIPs: the EIP-7251 document, EIP-7600 (the Pectra meta EIP), and EIP-7773 (the Glamsterdam meta EIP)
---

# EIP-7251 (Raise the maximum effective balance of a validator)

A standard that raises the cap on the effective balance one validator can hold, so that large operators can consolidate their validators.
The minimum stake stays at 32 ETH.

| Point | What the document says |
|---|---|
| Minimum | `MIN_ACTIVATION_BALANCE` is 32 ETH |
| Cap | `MAX_EFFECTIVE_BALANCE_ELECTRA` is 2048 ETH |
| Compounding prefix | A validator whose withdrawal credentials carry the prefix `0x02` (`COMPOUNDING_WITHDRAWAL_PREFIX`) counts the balance above 32 ETH toward its effective balance |
| Consolidation requests | Sent to the contract at `0x0000BBdDc7CE488642fb579F8B00f3a590007251`; up to 2 are processed per block |
| Churn limit | The validator churn limit is now set by balance weight instead of by count |

## Current status

The document's status is `Final`, and it is included in the Pectra meta EIP (EIP-7600, status `Final`).
It went live on mainnet at epoch 364032.
The timestamp is 1746612311, which falls on 2025-05-07.

The "it should go into Pectra" of posts from 2024 is now the state it shipped in.
Where this standard sits in the plan to speed finality up to one slot is in the `l1-single-slot-finality` item.

## Not yet shipped

The Glamsterdam meta EIP (EIP-7773, status `Review`) lists EIP-8061, which raises the churn limits of withdrawals and consolidations, as planned for inclusion.
The meta EIP does not give a mainnet date for Glamsterdam yet.
