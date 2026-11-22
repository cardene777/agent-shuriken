---
status: live
checked: 2026-11-10
source: ethereum/EIPs: the EIP-7514 and EIP-7251 documents and EIP-7569 (the Dencun meta EIP)
---

# EIP-7514 (A cap on the validators activated per epoch)

A standard that puts a fixed cap on the number of validators newly activated in one epoch.
It was included to avoid the worst case in which the number of validators keeps growing and makes the beacon chain unstable.

| Point | What the document says |
|---|---|
| The cap | `MAX_PER_EPOCH_ACTIVATION_CHURN_LIMIT` is 8 |
| Where it applies | Only to the activation churn limit; the exit limit does not change |

## Current status

The document's status is `Final`; it is included in the Dencun meta EIP (EIP-7569) and went live on mainnet at epoch 269568.
The timestamp is 1710338135, which falls on 2024-03-13.

EIP-7251, which went live in Pectra, changed the churn limit to be set by balance weight instead of by count.
Read the churn limit together with the EIP-7251 item.

## Not yet shipped

Whether this cap, counted in validators, still applies as it is after Pectra has not been checked.
