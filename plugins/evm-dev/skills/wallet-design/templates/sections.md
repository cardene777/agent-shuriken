## Purpose and users

Fill in: who uses the wallets (end users, operators, administrators, AI agents), what each does with them, the assets involved, and what is out of scope.
Fill in: the limits that must hold, such as the most a user, a session, or an agent may spend, and what must never be possible without the owner's approval.

## Accounts

Fill in: the kind of account each user or agent holds (an externally owned account, an ERC-4337 smart account, or an externally owned account delegated with EIP-7702), why, and whether the app or the wallet chooses the account contract.
Fill in: the account contract and its version, the EntryPoint version, the bundler and paymaster services the design relies on, and the date each was checked, written as YYYY-MM-DD; the status of each ERC and EIP as checked with the evm-standards skill.

## Keys and recovery

Fill in: who holds each key (the user's wallet, a passkey, a hardware key, a multi-party computation service, a key management service), where it lives, and what the app itself never holds.
Fill in: how a lost or stolen key is recovered or replaced, who can do it and with what delay, and how keys are rotated.

## Signatures and permissions

Fill in: every message users or agents sign, as EIP-712 typed data with the domain (name, version, chain ID, verifying contract), the nonce, and the deadline, and how smart account signatures are checked (ERC-1271, and ERC-6492 for accounts not yet deployed).
Fill in: each permission granted by a signature or a session key: the contracts and functions it may call, the amounts, the period, the expiry, and how it is revoked.

## Approvals

Fill in: each token approval the app asks for, its spender, amount, and expiry, whether it uses `approve`, ERC-2612 permits, or Permit2, and why no approval is unlimited.
Fill in: how users see and revoke approvals and permissions, and what the app shows before a user signs one.

## Gas and sponsorship

Fill in: who pays gas for each kind of transaction (the user, the app through a paymaster, or the user in a token), the sponsorship rules and per-user and total limits, and what happens when the sponsor's balance runs out.
Fill in: how the app asks the wallet to batch calls and to use a paymaster, and what it does when the wallet cannot.

## Agent payments

Fill in: what AI agents pay for and how (for example x402 over HTTP), which key or permission each agent uses, the spending limit per payment and per period, the allowed payees, and when a human must approve.
Fill in: how an agent's permission is revoked, how its payments are recorded and reviewed, or why the app has no agent payments.

## Chains and environments

Fill in: the chains and their chain IDs for each environment (local, test network, mainnet), the account, EntryPoint, and service addresses on each, and how a signature for one chain is kept from being used on another.
Fill in: which keys, accounts, and sponsors are separate in each environment.
