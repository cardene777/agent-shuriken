---
topic: bridges
subject: Circle CCTP V1 (Legacy) and V2
checked: 2026-11-18
source: Circle, CCTP documentation (Migration from V1 to V2, supported blockchains, 2026 release notes); Circle blog, CCTP version updates, Migrate to CCTP V2 ahead of CCTP V1 Legacy deprecation, and the notice ending USDC and CCTP V1 on Noble
---

# Circle retires CCTP V1 between 31 October and 1 December 2026; use V2

Circle's Cross-Chain Transfer Protocol burns USDC on one chain and mints native USDC on another. Circle began deprecating CCTP V1, now called Legacy, on 31 October 2026 and completes it on 1 December 2026; an earlier schedule named 31 July 2026. V2 uses separate contracts and APIs and is not backward compatible with V1, so moving to it is a migration, not an upgrade. V2 is on every V1 chain except Noble, which will not get V2: Circle is ending USDC support there and fully pauses its CCTP routes on 12 January 2027. Sui got V2 on 8 October 2026, without Fast Transfer. V2 adds Fast Transfer, which makes the attestation available before hard finality for a fee, and hooks, which run an action on the destination chain after the USDC arrives.

For a design:

- Move USDC with CCTP V2, never V1 contracts or APIs, and never a lock-and-mint bridge that issues a wrapped USDC
- Say whether a transfer waits for finality or uses Fast Transfer, and who pays the Fast Transfer fee
- When a hook acts on the destination chain, say what happens to the USDC if the hook fails
