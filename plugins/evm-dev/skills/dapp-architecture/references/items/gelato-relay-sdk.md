---
topic: transactions
subject: Gelato Relay and its SDKs
checked: 2026-11-18
source: Gelato, npm registry notices of relay-sdk 5.7.0 and gasless 0.0.12; GMX, SDK changelog 1.8.2 and 2.0.0; Safe, Relay Kit guide for Gelato Relay
---

# Gelato's relay SDKs are deprecated, and its relay services are reported shut down

The `@gelatonetwork/relay-sdk` package is marked deprecated and points to `@gelatocloud/gasless`, and `@gelatocloud/gasless` is now also marked deprecated and no longer maintained.
GMX's SDK changelog says Gelato shut its relay services down on 1 September 2026, and Safe's Relay Kit guide says transactions cannot be relayed through Gelato from that date. Gelato's documentation site could not be reached when this item was checked.

For a design:

- Do not build a relay path on Gelato Relay, `@gelatonetwork/relay-sdk`, or `@gelatocloud/gasless`
- Choose a relayer the team runs, or an ERC-4337 bundler and paymaster, and check that provider's current documents before relying on it
- Whatever relay is chosen, the contract must still check the signature, nonce, and deadline itself
