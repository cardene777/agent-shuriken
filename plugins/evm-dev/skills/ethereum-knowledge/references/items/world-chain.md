---
status: live
checked: 2026-11-11
source: World's blog (the announcement of PBH on mainnet), World's official documentation (World Chain network information and its own features), World Chain's repository (the contract descriptions, the PBH specification, and the commit history of worldcoin/world-chain), and the World Chain page of L2BEAT (now named ETHBEAT)
---

# World Chain and PBH

World Chain is an Ethereum L2 built with the OP Stack that puts transactions of users verified as human with World ID at the top of the block with priority.
This priority mechanism is called PBH (Priority Blockspace for Humans).
World's blog announced that PBH went live on mainnet on 2025-06-26, but the official documentation page still says it is "being worked on".

| Point | What the official documents say |
|---|---|
| Architecture | The documentation says mainnet is built with the OP Stack, settles and keeps its data on Ethereum, and has chain ID 480 |
| Mainnet | L2BEAT's timeline says World Chain mainnet went live on 2024-10-17 |
| How PBH works | Part of the top of the block is reserved for transactions of people with a World ID. They get in without bidding up the priority fee |
| The PBH entry point | `PBHEntryPoint` is a contract that stands in front of ERC-4337's EntryPoint, and the builder recognizes PBH transactions by whether they are addressed to this contract. The World ID proof is verified by the builder before inclusion or on chain |
| Transactions not using 4337 | With a World ID proof attached to `pbhMulticall()`, transactions that do not use 4337 also get into the top of the block |
| The launch of PBH | World's blog wrote on 2025-06-26 that PBH went live on World Chain mainnet. It says Nethermind audited the World Chain builder, the PBH contracts, and Rollup Boost |
| How the documentation reads | The documentation's page on its own features calls PBH the first feature being worked on, and also calls a gas allowance per human "upcoming" |

The ERC-4337 framework is in the `erc-4337-account-abstraction` item of the `evm-standards` skill, and where World Chain sits in the Superchain is in the `op-stack-superchain` item.

## Current status

World Chain runs on mainnet as an OP Stack L2.
L2BEAT places World Chain under Others with no stage, because fewer than 5 parties can challenge fraud.
PBH is taken as live, because World's blog announced its launch on mainnet and the repository was still fixing the checks of PBH transactions in 2026-08.

The 2024 post only announced the launch of a chain for humans; PBH reached mainnet more than a year later.

## Not yet shipped

The L2BEAT page does not mention PBH, and the address of the PBH contract on mainnet and the volume of transactions that get in through PBH have not been checked.
Whether the gas allowance per human runs has not been checked.
