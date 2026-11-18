---
status: specified
checked: 2026-11-18
source: ethereum/EIPs: the EIP-4444 document; the Ethereum Foundation blog: the partial history expiry announcement (2025-07-08)
can: Execution clients can stop serving old block data to the network, so old blocks and receipts may have to come from another source.
---

# EIP-4444 (Expiry of past data held by execution clients)

A standard that lets execution clients stop serving old data to the network.

| Point | What the document says |
|---|---|
| Target | Block headers, block bodies, and receipts older than 14,299 epochs |
| What it decides | They are not served over p2p. Clients may delete them locally |
| Node operators | Can reduce disk usage |
| Users and application developers | Old history can no longer be fetched over p2p, so they fetch it from other providers |

## Current status

The document's status is `Draft`, and it was created on 2021-11-02.
The document was read and checked on 2026-11-18.

On 2025-07-08, the Ethereum Foundation blog announced that every execution client can now delete pre-Merge blocks.
Only mainnet and Sepolia, which have a pre-Merge range, can delete them.

| Client | Version named in the announcement |
|---|---|
| Go-ethereum | v1.16.0 |
| Nethermind | 1.32.2 |
| Besu | 25.7.0 |
| Erigon | v3.0.12 |
| Reth | v1.5.0 |

The announcement names three places to get old history after it is deleted: providers that store history, a torrent anyone can join, and the current p2p network.

## Not yet shipped

It is not `Final`, and the document does not say which upgrade activates it.
The announcement says that deleting history older than a set period on a rolling basis is still being worked on.
Serving old history as era files is not mentioned in the announcement and has not been checked.
