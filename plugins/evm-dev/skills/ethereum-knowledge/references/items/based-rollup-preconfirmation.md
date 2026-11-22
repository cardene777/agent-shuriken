---
status: live
checked: 2026-11-11
source: Taiko's official documentation (the FAQ, preconfirmations, contract addresses, and the table of contents), the gwyneth repository of taikoxyz, the preconfirmations repository of cairoeth, the EIP-7917 and EIP-7607 (the Fusaka meta EIP) documents in ethereum/EIPs, and the list of L2BEAT (now named ETHBEAT)
---

# Based rollups and preconfirmations

A based rollup lets Ethereum L1 decide the order of its transactions.
Since no single operator decides the order, it is harder to stop, but slower by the time spent waiting for L1 blocks.
A preconfirmation closes that gap: the one who builds the block promises in advance to include a transaction.

| Point | What the official documents say |
|---|---|
| Ordering in Taiko | A based rollup; L1 decides the final order of proposals |
| Taiko's preconfirmations | Three launch partners, Nethermind, Chainbound, and Gattaca, are listed in the contract as permissioned preconfirmers. One preconfirmer is chosen for each epoch of 32 slots and decides the order during it |
| Bypassing the preconfirmer | Users can bypass the preconfirmer by sending a transaction directly to the `Inbox` contract, which forces its inclusion |
| Taiko's next stage | In the next stage, L1 validators put down collateral and register with `PreconfServiceManager` to become preconfirmers. A preconfirmer that breaks a promise has its collateral slashed |
| Taiko's contracts | The current mainnet setup has `Inbox` (`0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f`) and `PreconfWhitelist` (`0xFD019460881e6EeC632258222393d5821029b2ac`). `PreconfRouter` (`0xD5AA0e20e8A6e9b04F080Cf8797410fafAa9688a`) moved to the list of contracts no longer used |
| Support from L1 | EIP-7917 fixes the lineup of upcoming block proposers at the start of an epoch and keeps it in state. It was included so that preconfirmation mechanisms can know the proposer lineup in advance |
| Booster rollup (Gwyneth) | Taiko's current table of contents has no page on Gwyneth or booster rollups. The last commit on the default branch of the gwyneth repository of taikoxyz is from 2025-03-05 and merges the preparation of a test network |
| A prototype of preconfirmations secured by restaking | The preconfirmations repository of cairoeth is a prototype that holds proposers to their promises with EigenLayer slashing and Relic Protocol proofs, and calls itself experimental software. It runs on a local `anvil` network, and its last commit is from 2024-04-17 |

Preconfirmations of L1 transactions, shortening the slot, and the stopped bolt are in the `l1-fast-confirmation` item.
Whether to choose one preconfirmer or have several compete, and the two ways a promise can go unkept, are in the same item.

## Current status

Taiko's preconfirmations run with only the three permissioned partners.
EIP-7917's status is `Final`; it is included in the Fusaka meta EIP (EIP-7607) and took effect on 2025-12-03.

The booster rollup of posts from 2024 could not be confirmed to have reached mainnet under the name Gwyneth.
Gwyneth is not on the list of L2BEAT (now named ETHBEAT) either.
The prototype of preconfirmations secured by restaking has not been updated since its commit of 2024-04-17.

## Not yet shipped

A form of Taiko's preconfirmations that anyone can provide.
An official announcement of whether Taiko stopped or postponed Gwyneth has not been checked.
