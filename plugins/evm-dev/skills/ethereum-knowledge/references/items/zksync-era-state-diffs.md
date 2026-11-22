---
status: live
checked: 2026-11-10
source: ZKsync's official documentation (Data availability)
---

# State diffs on ZKsync Era

ZKsync Era is a rollup that sends to Ethereum mainnet not the content of transactions but the storage values changed after them (the state diffs).
Since the amount sent does not depend on the size of a transaction's input, transactions with heavy inputs become cheaper.

| Point | What the official documents say |
|---|---|
| What is sent | Four things: the logs and messages from L2 to L1, the bytecode of published contracts, and the compressed state diffs. The content of transactions is not sent |
| The form of a state diff | Pairs of a storage slot per address and the 32-byte value placed in it |
| Changes to the same slot | When several transactions change the same slot, they are merged into one, and from the second time on the slot's key is replaced with a short index |
| Compression | Everything sent is compressed, including the state diffs |
| Rebuilding | Collecting the state diffs sent to Ethereum mainnet rebuilds the current state, but does not show which transactions produced that state |

## Current status

ZKsync chains run in the form that sends state diffs.
Large inputs such as the biometric signatures attached to account abstraction transactions are part of the transaction content, so they do not go on Ethereum mainnet.
The 2023 post's claim that transactions with heavy signatures are cheaper than on other chains comes from this form.

## Not yet checked

The relevant page of the official documentation does not say whether the data goes in blobs (EIP-4844) or in calldata.
How this ties to the `eip-4844-blob-transactions` item of the `evm-standards` skill has not been checked.
