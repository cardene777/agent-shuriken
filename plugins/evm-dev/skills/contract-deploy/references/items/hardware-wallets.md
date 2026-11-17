---
topic: keys
subject: Signing deployments with a Ledger or Trezor in Foundry and Hardhat 3
checked: 2026-11-17
source: Foundry, forge script reference and key management best practices; forge 1.5.1 help output; Foundry ZKsync book, using a Ledger device; Hardhat, hardhat-ledger plugin and Ignition guide to deploying with a Ledger; Ledger Academy, blind signing
---

# A hardware wallet keeps the mainnet key off the computer and asks the user to approve each transaction on the device

Foundry signs with `--ledger` or `--trezor` in place of `--account`. `--mnemonic-derivation-paths` sets the derivation path and `--mnemonic-indexes` picks the account, which defaults to index 0. In Hardhat 3, the `@nomicfoundation/hardhat-ledger` plugin signs for the addresses listed in a network's `ledgerAccounts`, with an optional `ledgerOptions.derivationFunction`; Hardhat Ignition then deploys with `hardhat ignition deploy <module> --network <name>`. The device must be plugged in, unlocked, and in the Ethereum app. A contract deployment cannot be shown in full on the device, so the Ethereum app asks for blind signing to be turned on in its settings; Ledger advises turning it on only when needed.

For a deployment:

- Use a hardware wallet for every production chain, and give the address it controls as `--sender`
- Turn blind signing on just before the broadcast and off again after it
- A script that sends many transactions asks for one approval each; keep the user at the device for the whole broadcast, and use `--slow` so each transaction waits for the one before
