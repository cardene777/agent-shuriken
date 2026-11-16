# Review checklist for a dApp architecture design

Go through this list after `verify` passes. A design that fails any rule in the first table is not finished: fix it and check again. Say which rules you could not judge and why.

## Rules a design must never break

| Rule | What fails it |
|---|---|
| Nothing secret or personal on chain | Personal data, secrets, API keys, or anything the users expect to stay private is written to contract storage or emitted; `private` variables and events are public to anyone who reads the chain |
| Every write path has a sender and a payer | A write path does not say who signs, who sends the transaction, and who pays the gas |
| Relayer keys are not admin keys | The relayer key or another hot service key also holds an admin key role, or a relayer holds more funds or sends more transactions than its limits allow |
| Sponsored signatures cannot be replayed | A meta-transaction or sponsored operation is signed without the chain ID, the contract, a nonce, and a deadline |
| Screens read from an indexer or a database | The frontend lists or searches on-chain history by scanning logs over RPC on every visit, instead of reading from an indexer or a database |
| Reads survive reorgs | The indexer treats a block as final without a confirmation depth or the chain's finality, or cannot undo what it read from a block that was reorganized away |
| Indexing is idempotent and rebuildable | Events are stored without a key built from the chain ID, the transaction hash, and the log index, or the index cannot be rebuilt from the deployment block |
| No single key controls the protocol | An externally owned account alone holds the owner, admin, or upgrader role on a mainnet |
| Changes are delayed and visible | Upgrades and parameter changes run at once, without a timelock that users can watch, except a pause |
| Pausing is separate | The pauser role is the same as the role that can upgrade, or nobody can pause quickly |
| Environments do not share keys | The same key, address list, or configuration is used on the local chain, a testnet, and a mainnet, instead of one set per environment |

## Rules to check with the team

| Area | Check |
|---|---|
| Monitoring | Admin actions, paused state, large transfers, failed transactions, the relayer balance, indexer lag, and RPC errors each raise an alert that reaches someone on call |
| Third-party services | Each service named in Components carries the date its status was checked, and a service that has shut down or deprecated its product is not chosen; the design says what happens when a service stops |
| RPC | There is more than one RPC provider, with timeouts and rate limits handled, and the frontend never holds a paid provider's secret key |
| Storage | Content referenced on chain is content-addressed, pinned in more than one place that the team controls or pays for, and is not served only through a public gateway |
| Transactions in the UI | Pending, confirmed, failed, dropped, and replaced transactions each show a state, and the UI does not count a transaction as done before it is confirmed |
| Admin process | The multisig signers, the threshold, and the timelock delay are written down, with how a signer is replaced and how an emergency pause is run |
| Upgrades | When contracts are upgradeable, who can upgrade and how storage layout is checked are decided; the code itself belongs to the solidity-code skill |
| Cross-chain | Addresses, chain IDs, and finality are handled per chain, and any bridge or messaging layer is named with the trust it adds |
