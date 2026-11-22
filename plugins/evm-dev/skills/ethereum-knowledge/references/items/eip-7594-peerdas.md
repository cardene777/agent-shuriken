---
status: live
checked: 2026-11-11
source: ethereum/EIPs: the EIP-7594 document, EIP-7600 (the Pectra meta EIP), and EIP-7607 (the Fusaka meta EIP); and the mainnet configuration in ethereum/consensus-specs
---

# EIP-7594 (PeerDAS, nodes sample each other to check that data is available)

A network rule by which a node receives only part of the blob data and checks that the whole was published.
It lets the amount of blobs grow without growing the bandwidth and disk of nodes.

| Point | What the document says |
|---|---|
| How data is extended | Each blob gets an erasure code and becomes a row, and each row is split into the smallest units that can be checked with a KZG commitment (cells) |
| Columns | The cells at the same position taken from every row form a column, and each column has its own gossip network |
| What a node holds | Each node holds the columns set by its node ID, and in every slot samples columns from other nodes to check them |
| Reconstruction | With 50% or more of all columns, the whole can be reconstructed |
| How much a node receives | With the current values, one eighth of the whole |
| Required standard | EIP-4844 |

## Current status

The document's status is `Final`, and it was created on 2024-01-12.
It is not in the Pectra meta EIP (EIP-7600) but is included in the Fusaka meta EIP (EIP-7607, status `Final`).
Fusaka went live on mainnet at epoch 411392.
The timestamp is 1764798551, which falls on 2025-12-03.

In the mainnet configuration of consensus-specs, the column networks (`DATA_COLUMN_SIDECAR_SUBNET_COUNT`) number 128, and columns are kept for 4096 epochs.
The shape and fees of blob transactions are in the `eip-4844-blob-transactions` item of the `evm-standards` skill.

## Not yet shipped

The document says shrinking the sample size can lower what a node receives to one sixteenth or one thirty-second, but no plan to lower it has been confirmed.
