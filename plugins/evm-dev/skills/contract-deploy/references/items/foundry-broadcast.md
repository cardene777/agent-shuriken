---
topic: records
subject: Foundry broadcast files (run-latest.json) and the cache folder
checked: 2026-11-18
source: Foundry, forge script reference, the script sequence source code, the forge init .gitignore template, and the 1.8.3, 1.8.4, and 1.9.0 release notes; forge 1.5.1 run against a local Anvil node
---

# forge script writes what it sent to broadcast/ and keeps RPC URLs in cache/

Each `forge script` run writes `broadcast/<script>/<chain id>/run-latest.json` and a copy named `run-<milliseconds>.json`. A run without `--broadcast` only simulates and writes under `dry-run/` in the same folder. The file holds `transactions` (each with `hash`, `transactionType` such as `CREATE`, `CREATE2`, or `CALL`, `contractName`, `contractAddress`, `function`, `arguments`, `transaction` with `from` and `nonce`, and `additionalContracts` created inside it), `receipts` (each with `transactionHash`, `status`, `blockNumber`, and `contractAddress`), `pending` hashes without a receipt, `chain`, `timestamp`, and `commit`. Values that may be secret, such as RPC URLs, go to `cache/<script>/<chain id>/run-latest.json`; the `.gitignore` that `forge init` writes ignores `cache/` and keeps `broadcast/` except chain 31337 and dry runs. Since Foundry 1.8.4 the state `--resume` needs is also kept in `cache/`, so both folders must stay until the deployment is complete. `--slow` sends each transaction only after the one before it is confirmed and succeeded. Before Foundry 1.8.3, a run sent without `--slow` could record a hash under the wrong transaction, because hashes were saved in the order the RPC answered. Since Foundry 1.9.0, `--resume` stops when the run has a reverted transaction and transactions left to send, and `--broadcast` refuses to replace an unfinished run; `--broadcast --start-fresh` archives that run and sends the whole script again.

For a deployment:

- Match each `CREATE` transaction to its receipt by hash, and check that the receipt shows the same new contract
- Treat a receipt with a `status` other than `0x1`, and every hash in `pending`, as not deployed; `--resume` sends what is pending
- Commit `broadcast/`, keep `cache/` out of git, never read `cache/`, and do not delete it before the deployment is complete
