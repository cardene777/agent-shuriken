---
topic: automation
subject: Chainlink Automation and Chainlink CRE
checked: 2026-11-18
source: Chainlink, Migrate from Chainlink Automation to Chainlink CRE (updated 2026-05-25), Migrate from Chainlink Functions to Chainlink CRE, and Migrate from Gelato Web3 Functions to Chainlink CRE; KeeperHub, Migrate from Gelato Functions
---

# Chainlink Automation is deprecated; Chainlink points to CRE

Chainlink deprecated Automation: version 1.x on 30 June 2026 and version 2.1 on 31 July 2026 (testnet: 24 June 2026). Chainlink names the Chainlink Runtime Environment (CRE) as the replacement and publishes a migration guide. Chainlink Functions was deprecated in the same way (mainnet 30 June 2026, testnet 15 June 2026).

Chainlink also publishes a guide for moving Gelato Web3 Functions to CRE (updated 2026-02-16). Gelato's own documents could not be reached when this item was checked; KeeperHub's migration guide says Gelato Web3 Functions shut down on 31 March 2026.

For a design:

- Do not register new upkeeps or plan on Chainlink Automation, Chainlink Functions, or Gelato Web3 Functions
- Choose CRE, a self-hosted keeper that the team runs, or a contract design that needs no scheduled call, and say who pays for each run
- Make every scheduled call safe to run twice or late, since any automation can miss or repeat a run
