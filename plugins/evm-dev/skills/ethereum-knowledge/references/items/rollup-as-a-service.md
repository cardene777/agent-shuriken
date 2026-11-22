---
status: live
checked: 2026-11-11
source: Caldera's official documentation (the rollup description, the Alt-DA page, and Metalayer), Conduit's official documentation (the Chains overview), and AltLayer's official documentation and official RaaS page
---

# Rollup-as-a-service providers (RaaS)

A form in which, instead of assembling a rollup yourself, you ask a provider to launch and run it (Rollup as a Service, RaaS).
Providers launch chains with existing frameworks (such as the OP Stack, Arbitrum Nitro, and ZK Stack), and let the customer choose the data store and where to settle.
This item holds which frameworks three providers, Caldera, Conduit, and AltLayer, launch chains with today.

| Point | What the official documents say |
|---|---|
| Caldera's frameworks | Says optimistic rollups can be launched with Arbitrum Nitro and the OP Stack, and ZK rollups with ZK Stack and Polygon CDK |
| Caldera's data stores | Ethereum by default, with Celestia, Near, and Arbitrum's AnyTrust named as other stores (Alt-DA). A later section of the same page says what it offers today is Celestia and Near, and does not name AnyTrust |
| Caldera's Metalayer | A mechanism that connects Caldera's chains with each other and with the outside, with bridge aggregation and tokens that span chains |
| Conduit's frameworks | Says it launches chains with the production-ready frameworks of Optimism, Arbitrum, and Polygon, working with Optimism through the Superchain, with Arbitrum through Orbit, and with Polygon through AggLayer |
| Conduit's stores | Says the customer chooses where to settle and the data store, and names no store. The entry page of its documentation names OP Succinct and the ordering mechanism G2 as available technology |
| AltLayer's frameworks | The official RaaS page says it supports the main frameworks, including the OP Stack, Arbitrum Orbit, and ZKsync's ZK Stack. The documentation also names Polygon zkEVM and Starkware |
| AltLayer's data stores | The official RaaS page says it supports EigenDA, Celestia, Avail, and NEAR DA |
| AltLayer's restaking | For each rollup it can combine three AVSs (mechanisms verified on EigenLayer): state verification (VITAL), fast finality (MACH), and decentralized ordering (SQUAD) |

## Current status

All three list in their documentation a way to launch chains with the OP Stack and Arbitrum frameworks.
Caldera and AltLayer also say they can launch ZK Stack chains.
The table of contents of AltLayer's documentation puts the X402 product suite and 8004 scan sections before the Rollup as a service section.

A 2023 post compared the frameworks, settlement, and stores providers use, and counted nine companies competing.
Do not use the number and the lineup of companies at that time as the current state.

## Not yet shipped

How many chains each provider runs today, and which of them are on the OP Stack and which on Arbitrum, have not been checked.
L2BEAT's list page has no column for the provider running a chain, so counts by provider have not been checked on L2BEAT.
Whether AnyTrust can still be chosen remains contradictory within Caldera's documentation and has not been checked.
Whether chains can still be launched with Polygon zkEVM and Starkware, which AltLayer's documentation names, has not been checked.
