## Purpose and users

Fill in: what the dApp does, who uses it (wallet users, operators, administrators, other contracts or services), and what each of them can do.
Fill in: the chains it runs on and why, and what is out of scope.

## Components

Fill in: a component diagram of the contracts, the frontend, the backend or API, the indexer, the relayer or bundler, automation, storage, and the RPC providers, with the trust boundary between each.
Fill in: for each component, what it is responsible for, who runs it, whether it is self-hosted or a third-party service, and for each third-party service the date you checked its status, written as YYYY-MM-DD.

## Transactions and gas

Fill in: for each write path, who signs, who sends the transaction, and who pays the gas: the user's own wallet, a relayer, a bundler with a paymaster, or an operator key.
Fill in: what a sponsored or relayed transaction binds in its signature (chain ID, contract, nonce, deadline), the limits on what the sponsor pays for, and what the user sees while a transaction is pending, confirmed, failed, or replaced.

## Reading chain data

Fill in: what the frontend and the backend read, and from where: an indexer and its database, or direct RPC calls, and why.
Fill in: the indexer, the events it reads, the block it starts from, how it waits for confirmations and handles reorganizations, how it stays idempotent, and how it is rebuilt from the deployment block.
Fill in: the RPC providers, their fallbacks, and their rate limits.

## Data placement

Fill in: what goes in contract storage, in events, in the application database, in content-addressed storage, and nowhere at all, with the reason for each.
Fill in: what is public because it is on chain, and how personal data and secrets are kept off it.

## Environments

Fill in: the local chain, the testnets, and the mainnets; which contracts and services exist in each; and how addresses, chain IDs, and configuration are kept per environment.
Fill in: how deployments are recorded and verified, and how the frontend and the indexer pick up new addresses.

## Keys and admin

Fill in: each privileged role (owner, admin, upgrader, pauser, minter, relayer, oracle) and who holds it: a multisig and its signers and threshold, a timelock and its delay, or a service key.
Fill in: which keys are kept apart, how a key is rotated or revoked, and how an upgrade or a parameter change is proposed, reviewed, and executed.

## Monitoring and operations

Fill in: what is watched (admin actions, paused state, large transfers, failed transactions, relayer balance, indexer lag, RPC errors), how alerts reach the people on call, and the runbook for an incident, a pause, and a key compromise.
Fill in: who operates each component, backups, and how the dApp recovers when a third-party service stops.
