---
topic: accounts
subject: ERC-4337 EntryPoint v0.8 and v0.9
checked: 2026-11-18
source: eth-infinitism, account-abstraction release notes for v0.8.0 and v0.9.0; Alchemy, Bundler API documentation; Candide, Simple 7702 Account (EntryPoint v0.9); Safe, safe-modules 4337 module changelog and `Safe4337Module` source
---

# EntryPoint v0.8 supports EIP-7702; v0.9 adds parallel paymaster signing, but not every bundler runs it

EntryPoint v0.8 accepts EIP-7702 authorizations, and the hash of a UserOperation from a delegated account covers the delegation address. EntryPoint v0.9 keeps the ABI of v0.8 and adds a `paymasterSignature` field, so a paymaster can sign in parallel with the account, a `getCurrentUserOpHash` function, and a rule that `handleOps` and `handleAggregatedOps` run only from a top-level transaction sent by an externally owned account. Candide's v0.9 account targets the EntryPoint at 0x433709009B8330FDa32311DF1C2AFA402eD8D009. Hosted bundlers differ: Alchemy's Bundler API lists v0.6, v0.7, and v0.8, so support for v0.9 depends on the provider. Safe's `Safe4337Module` 0.3.0, its newest release, supports only EntryPoint v0.7.0.

For a design:

- Use EntryPoint v0.8 or later for an account that relies on EIP-7702, and write the version in Accounts
- Choose v0.9 only when every bundler and paymaster the app uses lists it
- An account is built for one EntryPoint version; moving to a newer version needs an account contract that supports it
- A design that uses a Safe as its ERC-4337 account pins EntryPoint v0.7, the version `Safe4337Module` 0.3.0 supports
