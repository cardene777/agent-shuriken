---
topic: networks
subject: Ethereum testnets (Sepolia, Hoodi, Holesky)
checked: 2026-11-17
source: Ethereum Foundation blog, Holesky shutdown announcement and Hoodi announcement; Ethereum Magicians, Sepolia testnet replacement thread
---

# Sepolia is the testnet for apps; Holesky is shut down

The Ethereum Foundation shut down Holesky after the Fusaka upgrade. Sepolia is the testnet for applications and tooling, and Hoodi, launched in March 2025, is for validators and staking providers.

A replacement for Sepolia was proposed in May 2026 on Ethereum Magicians: a new network reaching the latest fork by early 2027, with Sepolia shut down in mid or late 2027. Its name and dates were not settled when checked.

For a design:

- Use Sepolia for contracts and dApps, not Holesky or Goerli
- Keep testnet addresses and chain IDs in per-environment configuration, so moving to Sepolia's successor is a configuration change and a redeploy
- Check the state of the Sepolia replacement before planning a long-lived testnet deployment
