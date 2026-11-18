---
status: live
checked: 2026-11-18
source: ethereum/EIPs: the EIP-4844, EIP-7594, EIP-7691, EIP-7892, and EIP-7918 documents, plus EIP-7569 (the Dencun meta EIP) and EIP-7607 (the Fusaka meta EIP); ethereum/consensus-specs: the mainnet configuration and the Deneb and Fulu p2p specifications; the Ethereum Foundation blog: the Fusaka mainnet announcement (2025-11-06) and the summary of the KZG ceremony
can: Rollups can post their data in cheap blobs that the EVM cannot read, paying a separate blob fee.
---

# EIP-4844 (Transactions that carry blobs)

A standard for transactions that carry rollup data in cheap blobs that the EVM cannot read.
Blob gas is priced in a market separate from ordinary gas.

| Point | What the documents say |
|---|---|
| How the price is set | The running total of blob gas above the target (`excess_blob_gas`) is passed through an exponential formula called `fake_exponential` to get the price |
| Dencun values | Per block, the target is `393216` (3 blobs), the maximum is `786432` (6 blobs), and the denominator that moves the price is `3338477` |
| Pectra values | EIP-7691 raised the target to 6 blobs and the maximum to 9, and the denominator became `5007716` |
| Added in Fusaka | EIP-7892 defined small upgrades that change only blob parameters (BPO). EIP-7918 set a reserve price per blob of `BLOB_BASE_COST` (2^13) times the ordinary base fee: while the price of one blob is below it, the excess blob gas stops falling, so the blob price rises |
| What contracts can read | The type `0x03` transaction carries the blobs' versioned hashes, which `BLOBHASH` (`0x49`) returns. The precompile at `0x0a` (50000 gas) verifies a KZG proof of a value in a blob. The blob data itself cannot be read |

## How blobs are distributed and how long they are kept

| Point | What consensus-specs says |
|---|---|
| Distribution in Deneb | Blobs are distributed apart from the block as `BlobSidecar`, on the `blob_sidecar_{subnet_id}` topics |
| Distribution in Fulu | The `blob_sidecar_{subnet_id}` topics are deprecated, and EIP-7594 (PeerDAS) columns are distributed on the `data_column_sidecar_{subnet_id}` topics |
| Retention | `MIN_EPOCHS_FOR_BLOB_SIDECARS_REQUESTS` and `MIN_EPOCHS_FOR_DATA_COLUMN_SIDECARS_REQUESTS` are both 4096 epochs, about 18 days |

The "16 days" and "1 month" found in posts differ from the 4096 epochs in the mainnet configuration.
EIP-7594 (PeerDAS, status `Final`) is included in the Fusaka meta EIP (EIP-7607); this skill has no separate item on it.

## KZG trusted setup

The KZG trusted setup used for blob commitments was produced by a ceremony that anyone could contribute to.
According to the Ethereum Foundation summary (2024-01-23), the ceremony ran from 2023-01-13 to 2023-08-08 and received 141,416 contributions.

## Current status

EIP-4844's status is `Final`, it is included in the Dencun meta EIP (EIP-7569), and it went live on mainnet at epoch 269568.
The timestamp is 1710338135, which falls on 2024-03-13.

The Fusaka meta EIP (EIP-7607, status `Final`) includes EIP-7892 and EIP-7918 and went live on mainnet on 2025-12-03 at epoch 411392.
At BPO1 on 2025-12-09 (epoch 412672) the per-block blob target became 10 and the maximum 15, and at BPO2 on 2026-01-07 (epoch 419072) the target became 14 and the maximum 21.
The maximums come from the consensus-specs mainnet configuration and the targets from the Ethereum Foundation's Fusaka mainnet announcement; the configuration lists no later BPO.

The claim in a 2023 post that "the blob price is set by an exponential formula" still matches the document.

## Not yet shipped

The blob base fee update fractions used at BPO1 and BPO2 are not in the sources above and have not been checked.
Whether the way the ordinary gas price is set has changed has not been checked.
