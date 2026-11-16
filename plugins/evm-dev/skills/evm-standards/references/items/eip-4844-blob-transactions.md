---
status: live
checked: 2026-11-11
source: ethereum/EIPs: the EIP-4844, EIP-7594, EIP-7691, EIP-7892, and EIP-7918 documents, plus EIP-7569 (the Dencun meta EIP) and EIP-7607 (the Fusaka meta EIP); ethereum/consensus-specs: the mainnet configuration and the Deneb and Fulu p2p specifications; the Ethereum Foundation summary of the KZG ceremony
---

# EIP-4844 (Transactions that carry blobs)

A standard for transactions that carry rollup data in cheap blobs that the EVM cannot read.
Blob gas is priced in a market separate from ordinary gas.

| Point | What the documents say |
|---|---|
| How the price is set | The running total of blob gas above the target (`excess_blob_gas`) is passed through an exponential formula called `fake_exponential` to get the price |
| Dencun values | Per block, the target is `393216` (3 blobs), the maximum is `786432` (6 blobs), and the denominator that moves the price is `3338477` |
| Pectra values | EIP-7691 raised the target to 6 blobs and the maximum to 9, and the denominator became `5007716` |
| Added in Fusaka | EIP-7892 defined small upgrades that change only blob parameters (BPO), and EIP-7918 gave the blob price a floor set by the ordinary gas price |

## How blobs are distributed and how long they are kept

| Point | What consensus-specs says |
|---|---|
| Distribution in Deneb | Blobs are distributed apart from the block as `BlobSidecar`, on the `blob_sidecar_{subnet_id}` topics |
| Distribution in Fulu | The `blob_sidecar_{subnet_id}` topics are removed, and EIP-7594 (PeerDAS) columns are distributed on the `data_column_sidecar_{subnet_id}` topics |
| Retention | `MIN_EPOCHS_FOR_BLOB_SIDECARS_REQUESTS` and `MIN_EPOCHS_FOR_DATA_COLUMN_SIDECARS_REQUESTS` are both 4096 epochs, about 18 days |

The "16 days" and "1 month" found in posts differ from the 4096 epochs in the mainnet configuration.
The PeerDAS design is covered in the `eip-7594-peerdas` item.

## KZG trusted setup

The KZG trusted setup used for blob commitments was produced by a ceremony that anyone could contribute to.
According to the Ethereum Foundation summary (2024-01-23), the ceremony ran from 2023-01-13 to 2023-08-08 and received 141,416 contributions.

## Current status

EIP-4844's status is `Final`, it is included in the Dencun meta EIP (EIP-7569), and it went live on mainnet at epoch 269568.
The timestamp is 1710338135, which falls on 2024-03-13.

The Fusaka meta EIP (EIP-7607, status `Final`) includes EIP-7892 and EIP-7918 and went live on mainnet on 2025-12-03 at epoch 411392.
In the mainnet configuration, the per-block blob maximum became 15 at BPO1 on 2025-12-09 (epoch 412672) and 21 at BPO2 on 2026-01-07 (epoch 419072).

The claim in a 2023 post that "the blob price is set by an exponential formula" still matches the document.

## Not yet shipped

The target blob counts for BPO1 and BPO2 cannot be read from the maximum rows of the mainnet configuration, so they have not been checked.
Whether the way the ordinary gas price is set has changed has not been checked.
