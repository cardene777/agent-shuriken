---
topic: records
subject: Hardhat Ignition deployment folders (journal.jsonl and deployed_addresses.json)
checked: 2026-11-17
source: Hardhat, Ignition deployment artifacts, deploying a module, and verifying your deployment; Nomic Foundation, ignition-core 3.1.2 journal message types
---

# Hardhat Ignition records every step of a deployment in a journal it can resume from

Ignition keeps each deployment in `ignition/deployments/<deployment id>/`; the id defaults to `chain-<chain id>` and is set with `--deployment-id`. `journal.jsonl` holds one JSON message per line, written before each action and after its result: `DEPLOYMENT_INITIALIZE` with the `chainId`, `DEPLOYMENT_EXECUTION_STATE_INITIALIZE` with the `futureId`, `contractName`, and `from`, `TRANSACTION_SEND` with the transaction `hash`, `TRANSACTION_CONFIRM` with the `receipt` (`status` `SUCCESS` or `FAILURE`, `blockNumber`, `contractAddress`), and `DEPLOYMENT_EXECUTION_STATE_COMPLETE` with the result and address. Numbers too large for JSON are written as `{"_kind": "bigint", "value": "..."}`. `deployed_addresses.json` maps each `Module#Future` that succeeded to its address, and `artifacts/` holds the compiled contracts. Running the same deploy again resumes from the journal. Hardhat recommends committing the whole deployments folder, or at least `deployed_addresses.json`.

For a deployment:

- A future with a `TRANSACTION_SEND` and no `TRANSACTION_CONFIRM` is still pending; rerun the deploy to resume instead of starting over
- Verify with `npx hardhat ignition verify <deployment id>`, or pass `--verify` to the deploy
- Use a new `--deployment-id` for a deployment that must not reuse an earlier one's contracts
