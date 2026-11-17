---
topic: messaging
subject: LayerZero V2 verifier (DVN) configuration
checked: 2026-11-17
source: LayerZero, V2 documentation (DVN and executor configuration, integration checklist); LayerZero, incident report on the KelpDAO rsETH exploit; The Block, LayerZero's apology for its Kelp DAO response (May 2026)
---

# A LayerZero app with one required verifier lost about 292 million dollars in April 2026

In LayerZero V2 each app sets which decentralized verifier networks (DVNs) must confirm a message, and how many. LayerZero's documentation says a production app should require several DVNs run by independent operators. On 18 April 2026 an attacker forged a message to the KelpDAO rsETH bridge, which required a single DVN, and minted about 116,500 rsETH, roughly 292 million dollars. LayerZero said Kelp had chosen the one-verifier setup; Kelp said it matched LayerZero's documented default and moved rsETH to Chainlink's Cross-Chain Token standard. In May 2026 LayerZero said its DVN should not have been the only verifier for high-value transfers.

For a design:

- Require at least two, and for high-value transfers three or more, DVNs from independent operators, and write the configuration per pathway in the design
- Read the live configuration from the endpoint contract on every chain after deployment, instead of trusting a default
- Add rate limits at the token or app level, so a forged message cannot move more than one window's limit
