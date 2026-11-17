---
topic: records
subject: Foundry broadcast files (run-latest.json) and the cache folder
checked: 2026-11-17
source: Foundry, forge script reference and the Foundry 1.0 upgrade notes; forge 1.5.1 run against a local Anvil node
---

# forge script writes what it sent to broadcast/ and keeps RPC URLs in cache/

Each `forge script` run writes `broadcast/<script>/<chain id>/run-latest.json` and a copy named `run-<milliseconds>.json`. A run without `--broadcast` only simulates and writes under `dry-run/` in the same folder. The file holds `transactions` (each with `hash`, `transactionType` such as `CREATE`, `CREATE2`, or `CALL`, `contractName`, `contractAddress`, `function`, `arguments`, `transaction` with `from` and `nonce`, and `additionalContracts` created inside it), `receipts` (each with `transactionHash`, `status`, `blockNumber`, and `contractAddress`), `pending` hashes without a receipt, `chain`, `timestamp`, and `commit`. Since Foundry 1.0 the values that may be secret, such as RPC URLs, go to `cache/<script>/<chain id>/run-latest.json`, which is git-ignored, and the broadcast files are meant to be committed. `--slow` sends each transaction only after the one before it is confirmed and succeeded. In a check with forge 1.5.1 against a local node, a run sent without `--slow` recorded two transactions' hashes swapped relative to their receipts; with `--slow` they matched.

For a deployment:

- Match each `CREATE` transaction to its receipt by hash, and check that the receipt shows the same new contract
- Treat a receipt with a `status` other than `0x1`, and every hash in `pending`, as not deployed; `--resume` sends what is left
- Commit `broadcast/`, keep `cache/` out of git, and never read `cache/`
