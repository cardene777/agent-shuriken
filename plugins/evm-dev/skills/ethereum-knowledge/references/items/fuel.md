---
status: live
checked: 2026-11-11
source: The Fuel Ignition page of L2BEAT (now named ETHBEAT) (its timeline and update log), EigenLabs' blog (the mainnet announcement of EigenDA V2), and Fuel's official documentation (the Fuel and Ethereum page of the Fuel Book)
---

# Fuel Ignition

Fuel Ignition is an Ethereum L2 built by Fuel Labs that runs on FuelVM.
FuelVM fixes in advance, in the form of UTXOs, the state a transaction touches, and executes transactions in parallel.
Its data store moved from Ethereum blobs to the outside EigenDA.

| Point | What the official documents say |
|---|---|
| Execution model | Fuel's documentation says the UTXO form strictly fixes the state a transaction touches, so transactions execute in parallel |
| Mainnet | L2BEAT's timeline says Fuel Ignition mainnet went live on 2024-10-16 |
| Data store | L2BEAT's timeline says it stopped posting to Ethereum blobs on 2025-07-03 and moved to EigenDA. It uses no bridge that verifies EigenDA certificates on L1 |
| EigenDA V2 | EigenLabs' blog said on 2025-07-30 that Fuel Ignition is the first chain to use EigenDA V2 on mainnet |
| State validation | The L2BEAT page says the current system lets even an invalid state root pass. The challenge period was shortened from 7 days to 1 day on 2025-08-29 |
| Sequencer and proposer | There is one sequencer, and only a permissioned party can post state roots to L1. When the sequencer stops, users can force transactions in from L1 |
| Bridge outage | The L2BEAT page says the bridge stopped for about a week in 2026-07, halting deposits and withdrawals, and then came back |

The facts on the EigenDA side are in the `eigenda` item.

## Current status

Fuel Ignition runs on mainnet.
L2BEAT places Fuel Ignition under Others, with no stage, because its proof system does not work and it has no bridge that checks its data store.
Fuel's official documentation still names Ethereum blobs as the data store and does not mention the move to EigenDA.

A post from 2023 introduces Fuel as a modular execution layer, but today's Fuel Ignition settles on Ethereum and keeps its data on EigenDA.

## Not yet shipped

The move to EigenDA has not been checked in an announcement from Fuel, because Fuel's blog could not be read.
Fuel's documentation says a proof that shows fraud in one step with a RISC-V zkVM is in development, but no date it went live has been given.
The reason the bridge stopped in 2026-07 has not been checked.
The L2BEAT page gives different dates for when it stopped and came back in two places, and the correct dates have not been checked.
