# Example: Shared treasury wallet for a small team

This design lets a team of five hold its operating funds in one shared wallet, where no payment leaves without several members signing. It covers the account, who holds each key, what members sign, the one kind of approval, who pays gas, and the environments. It leaves out payroll tools, accounting exports, and each member's personal wallet.

Each section decides one part and points to the others instead of repeating them. Open decisions holds every decision, assumption, and open question; other sections link to it.

## Purpose and users

Five members are signers: any of them proposes a payment in the team's treasury dashboard, and the others review and sign it there. A bookkeeper sees balances and history but signs nothing. The treasury holds ETH and one USD stablecoin, and pays vendors and contributors.
Limits: no transfer, approval, or change of signers runs without three of the five signatures (D4); the dashboard and its servers can never move funds; no approval outlives the transaction that needs it. Out of scope: AI agents with spending power, and card or bank payments.

## Accounts

The treasury is a Safe multisig used as an ERC-4337 account through `Safe4337Module` 0.3.0, whose newest release supports only EntryPoint v0.7.0 (item on ERC-4337 EntryPoint v0.8 and v0.9, checked 2026-11-18). An account is built for one EntryPoint version, so the treasury stays on v0.7 until it moves to an account that supports a later one. The Safe release itself is not covered by this skill's items (D1).
Signers keep their own externally owned accounts on hardware wallets; the dashboard never asks them to sign an EIP-7702 authorization, and their wallets choose any delegate. The bundler must list v0.7; Alchemy's Bundler API listed v0.6, v0.7, and v0.8 when checked on 2026-11-18, and the provider is chosen in D3.
Status from the evm-standards items checked 2026-11-18: ERC-4337 is `Final`; ERC-1271 is `Final`; EIP-7702 is `Final` and live on mainnet since 2025-05-07. EIP-712 and ERC-6492 have no item (D2).

## Keys and recovery

Each signer's key lives on that signer's hardware wallet. The dashboard, its servers, and the bookkeeper hold no key, and no key is kept in a `.env` file, an environment variable, code, a database, or browser storage.
A lost or stolen key is replaced by the other signers: three of them sign a change that removes the old signer and adds the new one, so no single person can take over. The name of each call is taken from the source of the chosen Safe release before the runbook is used (D1). Signers are rotated when a member leaves and reviewed each year; losing three keys at once would lock the funds, so signers keep their devices in separate places.

## Signatures and permissions

Members sign only treasury operations, each as EIP-712 typed data whose domain holds the chain ID and the Safe's address as the verifying contract, with the Safe's nonce and an expiry of seven days (D2). Contracts that check the treasury's signature call ERC-1271 `isValidSignature`, as Permit2 does when the signer has code (evm-standards item on ERC-1271); ERC-6492 is not needed, since the Safe is deployed before its first signature.
No session key or delegated permission exists: every operation needs the threshold. MetaMask's ERC-7715 permissions need a MetaMask smart account (item checked 2026-11-18), so they do not apply to a Safe.

## Approvals

Payments are plain transfers and need no approval. The one exception is a deposit into a vendor's escrow contract, sent as one batched operation that approves the exact deposit amount and then makes the deposit, so no allowance remains afterwards.
The treasury never signs Permit2 permits and never approves the largest amount. The dashboard reads the treasury's allowances from the chain and lists each spender, amount, and expiry; a revoke is an ordinary operation that sets the allowance to zero. Before signing, each member sees the spender, amount, and recipient in words, next to the raw call.

## Gas and sponsorship

The treasury pays the gas of its own operations from its ETH balance through the EntryPoint, so no paymaster or sponsor is involved and members' accounts need no ETH. The dashboard alerts when the gas reserve falls below the amount set in D4.
The dashboard builds each batch as one operation for the treasury itself, so members' wallets never need `wallet_sendCalls`. When the bundler is down, one signer sends the signed operation as a direct transaction and pays its gas (D3).

## Agent payments

The treasury has no agent payments: every payment needs three human signatures, which an agent cannot provide without holding a member's key. An assistant may draft proposals in the dashboard, holding no key and no permission.
If agents later pay for services, for example with x402, which the x402 Foundation has run since 14 July 2026 (item checked 2026-11-18), each gets its own capped and expiring permission from a separate account funded by the treasury (D5).

## Chains and environments

Production runs on Ethereum mainnet, and testing on a public test network (D6). Chain IDs are recorded from each network at deployment, and the Safe, the module, and the EntryPoint address read from the deployed module are kept in one record per environment. Because the domain binds the chain ID and the Safe's address, a signature on the test network cannot run on mainnet.
The test Safe has its own test keys, signers, and dashboard settings; no mainnet hardware key signs on a test network, and test keys never join the mainnet Safe.

## Open decisions

| ID | Decision or assumption | Candidates | Affects | Who decides | By when |
|---|---|---|---|---|---|
| D1 | Which Safe release, and the names of its signer-change calls, read from its source | The newest release that `Safe4337Module` 0.3.0 works with | Accounts, Keys and recovery | Engineering lead | Before deployment |
| D2 | Assumed: the signed operation is EIP-712 typed data and can carry an expiry; confirm EIP-712 and ERC-6492 status and how the expiry is enforced | Enforced on chain by the module; refused by the dashboard and cancelled by reusing the nonce | Signatures and permissions | Engineering lead | Before deployment |
| D3 | The bundler, and whether a signer may send directly when it is down | A hosted bundler that lists v0.7; a second hosted bundler as fallback | Accounts, Gas and sponsorship | Engineering lead | Before deployment |
| D4 | Assumed: 3 of 5 signers, and a gas reserve of 0.2 ETH | 2 of 3; 4 of 7 | Purpose and users, Gas and sponsorship | Team | Before deployment |
| D5 | Whether agents ever pay from treasury funds, and the cap | No agents; a separate account with a monthly cap | Agent payments | Team | When an agent use case appears |
| D6 | Assumed: Ethereum mainnet, and Sepolia as the test network, which this skill's items do not cover | A rollup for lower fees | Chains and environments | Team | Before deployment |
