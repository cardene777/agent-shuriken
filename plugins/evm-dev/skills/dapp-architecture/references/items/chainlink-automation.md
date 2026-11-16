---
topic: automation
subject: Chainlink Automation and Chainlink CRE
checked: 2026-11-17
source: Chainlink, Migrate from Chainlink Automation to Chainlink CRE (updated 2026-05-25)
---

# Chainlink Automation is deprecated; Chainlink points to CRE

Chainlink deprecated Automation: version 1.x on 30 June 2026 and version 2.1 on 31 July 2026, with testnets on 24 June 2026. Chainlink names the Chainlink Runtime Environment (CRE) as the replacement and publishes a migration guide. Chainlink Functions was deprecated in the same way (mainnet 30 June 2026).

Chainlink also publishes a guide for moving Gelato Web3 Functions to CRE (updated 2026-02-16); check Gelato's own documents for the state of Web3 Functions before choosing them.

For a design:

- Do not register new upkeeps or plan on Chainlink Automation or Functions
- Choose CRE, a self-hosted keeper that the team runs, or a contract design that needs no scheduled call, and say who pays for each run
- Make every scheduled call safe to run twice or late, since any automation can miss or repeat a run
