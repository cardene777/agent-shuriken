---
topic: randomness
subject: Chainlink VRF
checked: 2026-11-17
source: Chainlink, Migrating from VRF v2 (VRF v2.5 documentation)
---

# Chainlink VRF v2 shuts down on 30 November 2026; use v2.5

VRF v2.5 replaced VRF v1 and v2 on 29 November 2024. VRF v2 was deprecated that day, had a 48-hour brownout on 28 to 30 October 2026 in which it fulfilled no requests, and is permanently shut down on 30 November 2026. VRF v2.5 takes requests by subscription or by direct funding, and can be paid in LINK or the chain's native token.

For a design:

- Use VRF v2.5, never the v2 coordinator or the v2 consumer base contract
- Say who funds the subscription or each request, and what happens while a request is pending or if it is never fulfilled (a timeout and a way to request again)
- Do not let the requester or a validator choose the outcome: the result must not be used in the same transaction that requested it, and the callback must not revert
