---
topic: transactions
subject: Gelato Relay SDK
checked: 2026-11-17
source: Gelato, README of the relay-sdk package 5.7.0
---

# Gelato's relay SDK is deprecated in favor of a new gasless package

The `@gelatonetwork/relay-sdk` package is marked deprecated, and its README points to `@gelatocloud/gasless` as the replacement.

For a design:

- Do not build a new relay path on `@gelatonetwork/relay-sdk`
- Check in Gelato's current documents which call types the new package supports before choosing a sponsored or ERC-2771 flow, since the old SDK's call types may not all carry over
- Whatever relay is chosen, the contract must still check the signature, nonce, and deadline itself
