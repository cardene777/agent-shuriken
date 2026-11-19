# Example: Donation tracker for a community cause

This design lets a team build a dApp where anyone gives ETH to one cause and anyone can follow each donation and each disbursement the cause makes. It covers the parts, who sends and pays for each transaction, how screens read chain data, where data lives, environments, admin keys, and monitoring. It leaves out fiat donations, tax receipts, and more than one cause.

Each section decides one part and points to the others instead of repeating them. Open decisions holds every decision, assumption, and open question; other sections link to it.

## Purpose and users

Donors give ETH from their own wallets and see their gifts and running totals. The cause's stewards disburse funds to named payees and publish a spending report for each disbursement. A guardian pauses donations in an emergency, and anyone can read every screen without a wallet.
The dApp runs on Ethereum mainnet, where donors already hold ETH (D1). Out of scope: other tokens, refunds to donors, and accounts or logins.

## Components

```
donor wallet ──> DonationBox ──> Ponder indexer ──> Postgres ──> read API ──> web app
stewards' Safe ──> timelock ──> DonationBox        reports ──> two pinning services
guardian Safe ──> DonationBox (pause)              OpenZeppelin Monitor ──> on-call alerts
```
Trust boundaries sit between the wallets and the contracts, between the chain and the indexer, and between the team's servers and the browser. `DonationBox` holds ETH and emits `Donated` and `Disbursed`; the web app is static and reads only the read API; the team runs the indexer, the API, the database, and the monitor.
Services and their checked dates: Ponder 0.18.9, self-hosted, checked 2026-11-18; Safe Smart Account 1.5.0 for the stewards and the guardian, checked 2026-11-18; OpenZeppelin Monitor, self-hosted under the AGPL v3, checked 2026-11-18; IPFS pinning, paid and in two places, checked 2026-11-18. RPC providers are chosen in D2.

## Transactions and gas

- Donate: the donor signs, the donor's wallet sends, and the donor pays the gas
- Disburse: the stewards' Safe signers sign, the Safe schedules the call in the timelock, and after the delay one signer sends and pays the gas from their own account
- Pause and unpause: the guardian's signers sign and one of them sends and pays
No transaction is sponsored or relayed, so no meta-transaction signature exists. OpenZeppelin Defender was retired on 1 July 2026 and Gelato's relay services were reported shut down on 1 September 2026 (both items checked 2026-11-18), so sponsoring would need a relayer the team runs (D3).
The web app shows a donation as pending, included, final, failed, or replaced, and counts it in totals only once it is included; it watches the donor's nonce to catch a replaced or dropped transaction.

## Reading chain data

Screens read only the read API, which reads Postgres; the web app never scans logs over RPC.
Ponder, pinned at 0.18.9, reads `Donated`, `Disbursed`, `Paused`, `Unpaused`, and the timelock's events from the deployment block. Each row is keyed by chain ID, transaction hash, and log index, so a re-run writes nothing twice. Ponder's `reorgWindow` is at most 600 seconds, while an Ethereum block takes about 15 minutes to finalize, so the API marks a row final only when its block is at or below the RPC's `finalized` block. A reorg deeper than the window stops Ponder, and the runbook rebuilds the index from the deployment block.
Ponder adjusts its request rate to each RPC provider's limits by itself; the indexer has a primary and a fallback provider (D2).

## Data placement

Contract storage holds the ETH balance, the timelock and role addresses, and the paused flag. Events carry each donor's address and amount, each payee's address and amount, and the content ID of each spending report. The database holds the indexed rows and totals, and the pinned reports hold what was bought and why, written by the stewards. The web app reads reports with `@helia/verified-fetch`, never only through the rate-limited `ipfs.io` or `dweb.link` gateways.
Everything on chain is public. The dApp collects no names, emails, or messages from donors, and reports name payees only as organizations, never people (D4).

## Environments

A local chain for development, Sepolia for testing, since Holesky is shut down, and Ethereum mainnet (Ethereum testnets item, checked 2026-11-18). Each environment has its own contracts, Safes, monitor rules, and database.
A deployment record per environment holds the chain ID, the addresses, and the deployment block; the indexer and the web app read it at start, and contracts are verified on the explorer. Sepolia has a proposed successor with no settled name or dates, so moving is a configuration change and a redeploy (D5).

## Keys and admin

The stewards' Safe, 3 of 5 signers, proposes disbursements and parameter changes through a timelock with a 48-hour delay that donors can watch (D6). The guardian Safe, 2 of 3 signers, can only pause and unpause; it cannot disburse, cancel scheduled changes, or grant roles. The contract is not upgradeable.
No server holds a signing key: the indexer, the API, and the monitor only read. A lost or leaked signer key is removed by the remaining Safe signers, and the RPC keys stay on the servers, never in the web app.

## Monitoring and operations

OpenZeppelin Monitor watches role changes, timelock schedules and executions, pauses, every disbursement, donations above a set amount, and failed Safe transactions. A health check watches indexer lag against the chain head, RPC errors, and the monitor itself, and alerts reach the on-call steward (D7).
Runbooks: on an incident, the guardian pauses donations and the stewards decide in the timelock; on a key leak, the Safe removes that signer. The database is backed up daily and can be rebuilt from the deployment block; if a pinning service stops, the other still serves every report and a new one is added.

## Open decisions

| ID | Decision or assumption | Candidates | Affects | Who decides | By when |
|---|---|---|---|---|---|
| D1 | Assumed: Ethereum mainnet only, ETH only | Add a rollup; add a stablecoin | Purpose and users, Environments | Cause stewards | Before mainnet deployment |
| D2 | The primary and fallback RPC providers, and their rate limits | Two hosted providers; one hosted and one self-run node | Components, Reading chain data | Engineering lead | Before Sepolia deployment |
| D3 | Assumed: donors pay their own gas; a sponsored path would need a relayer the team runs | No sponsorship; a self-hosted OpenZeppelin Relayer | Transactions and gas | Cause stewards | When donors ask for gasless giving |
| D4 | Rules for spending reports so they never name a person | Organizations only; amounts and categories only | Data placement | Cause stewards | Before the first disbursement |
| D5 | Assumed: Sepolia stays until its successor is settled | Move when the successor's dates are announced | Environments | Engineering lead | Each quarter |
| D6 | Assumed: 3 of 5 stewards, 2 of 3 guardians, 48-hour delay | 24 hours; 72 hours | Keys and admin | Cause stewards | Before mainnet deployment |
| D7 | Where alerts go and the donation amount that raises one | A chat channel and paging; a chat channel only | Monitoring and operations | Engineering lead | Before mainnet deployment |
