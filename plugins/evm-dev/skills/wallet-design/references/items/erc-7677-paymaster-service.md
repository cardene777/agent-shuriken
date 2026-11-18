---
topic: gas
subject: EIP-5792 wallet_sendCalls and the ERC-7677 paymaster service
checked: 2026-11-18
source: Ethereum, ERC-7677 specification; Candide, Batch and Sponsor Transactions (via ERC-5792); Dynamic, EIP-5792 reference
---

# Apps sponsor gas through the wallet with `wallet_sendCalls` and the ERC-7677 paymaster capability

EIP-5792 lets an app send a batch of calls to the wallet with `wallet_sendCalls` and learn what the wallet supports with `wallet_getCapabilities`, including whether it runs a batch atomically. ERC-7677 adds a `paymasterService` capability: the app passes the URL of its paymaster web service, and a wallet that supports the capability asks that service to sponsor the batch. Support differs by wallet; Candide lists wallets that batch calls but do not sponsor gas, such as the MetaMask extension. Dynamic advises reading the capabilities first and falling back to sending transactions one by one.

For a design:

- Read `wallet_getCapabilities` before sending, and say what the app does when a wallet cannot batch atomically or cannot use a paymaster
- Keep the sponsorship rules and limits, per user and in total, in the paymaster service the app runs or rents
- Do not count on sponsorship in every wallet; say who pays when it is missing
