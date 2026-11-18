---
topic: messaging
subject: LayerZero V2 verifier (DVN) configuration
checked: 2026-11-18
source: LayerZero, V2 documentation (DVN and executor configuration, production DVN configuration); LayerZero, KelpDAO incident statement, incident report on the KelpDAO rsETH exploit, and An Overdue Apology (May 2026); The Block, Kelp DAO's move to Chainlink CCIP (May 2026)
---

# A LayerZero app with one required verifier lost about 292 million dollars in April 2026

In LayerZero V2 each app sets which decentralized verifier networks (DVNs) must confirm a message, and how many. LayerZero's documentation says a production app should require several DVNs run by independent operators. On 18 April 2026 an attacker forged a message to the KelpDAO rsETH bridge, which required a single DVN, and unlocked about 116,500 rsETH held by the bridge on Ethereum, roughly 292 million dollars. LayerZero said Kelp had chosen the one-verifier setup; Kelp said it was LayerZero's default for onboarding and announced a move of rsETH to Chainlink CCIP and its Cross-Chain Token standard. In May 2026 LayerZero said it had been a mistake to let its DVN act as the only verifier for high-value transfers, and its DVN no longer signs as the only required verifier on any pathway.

For a design:

- Require at least two, and for high-value transfers three or more, DVNs from independent operators, and write the configuration per pathway in the design
- Read the live configuration from the endpoint contract on every chain after deployment, instead of trusting a default
- Add rate limits at the token or app level, and size them for the loss the design can take: a token-bucket limit lets a forged message take the full capacity at once and then each refill, so in 24 hours it can move the capacity plus a day of refill
