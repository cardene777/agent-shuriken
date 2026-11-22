---
status: live
checked: 2026-11-16
source: ZKsync's official documentation (ZK chains, ZKsync Connect, Airbender, and Validium in ZKsync Stack), Matter Labs' reports for the first and second quarters of 2026, ZIP-16 (v31) on ZK Nation's governance forum, the zksync-era repository of matter-labs, the ZKsync Era page of L2BEAT (now named ETHBEAT), ZKsync's blog (Introducing ZKsync Prividium), Matter Labs' Prividium page, the Prividium announcements (the press release for Commander, Introducing Prividium Connect, and the press release for Connect), two posts on ZK Nation's governance forum (ZK Token Fee Flow System v1.0 Overview, and Connecting the Dots), and the code of the Fee Flow contracts read through the ZKsync Era RPC
---

# ZK Stack and the Elastic Network

ZK Stack is the set of parts that lets anyone build ZK rollups and validiums with the same parts as ZKsync Era.
Chains built with ZK Stack (ZK chains) are connected by a shared bridge on Ethereum, and ZKsync calls that group the Elastic Network.
Communication between chains is built so that both the sending and receiving chains settle their proofs on L1.

| Point | What the official documents say |
|---|---|
| How they connect | ZK chains settle through the shared bridge contracts on Ethereum, and keep upgrades and responses to weaknesses in step through a governance framework placed on L1. Using ZK Stack is the condition for trusted mutual communication inside the Elastic Network |
| The message flow | When the sending chain settles its proof on L1, the shared message root (the interop root) is updated. The receiving chain takes that root through its consensus mechanism, a relayer submits the message and an inclusion proof, and the receiving chain verifies and executes it. Finally the receiving chain's proof also settles on L1 |
| How it is verified | Cross-chain transactions are verified by a contract that checks Merkle proofs |
| Rollout stages | The ZKsync Connect documentation says it ships in three stages. The first stage, messages, is out. The second stage, asset transfers and call bundles, and the third stage, automatic cross-chain transactions, communication with L1, and shadow accounts, are at the planning stage |
| The upgrade that added messages | The v29 upgrade added messages between chains connected to ZKsync Gateway. L2BEAT lists it as an event of 2025-10-06 |
| The upgrade that dropped bundles | v31 (ZIP-16) first held call bundles and fees, but the version Matter Labs put out on 2026-07-06 dropped them. On the governance forum, Matter Labs answered that public mutual communication using Gateway is postponed, and that its code is audited and stays unused |
| The proving parts | The list of ZK Stack parts names ZKsync OS for the execution layer and ZKsync Airbender for producing proofs. ZKsync OS runs virtual machines such as the EVM, and Airbender proves that execution as RISC-V instructions |
| Airbender's form | It produces proofs with STARKs and FRI, and at the end wraps them in an FFLONK proof verified on chain. It runs on consumer GPUs |
| Rollup data | State changes go to L1, in whichever of calldata or blobs is cheaper |
| Validium data | The organization running the chain controls where the data is kept. Funds cannot be stolen, but they freeze if the data stops coming out |
| The three forms of validium | Stage 0 keeps the data only in the database of the node running the chain. Stage 1 sends it to an outside DA layer but does not check inclusion on L1. Stage 2 sends it to an outside DA layer and checks inclusion on L1 |
| Outside DA layers | The documentation names Avail, Celestia, and EigenDA as the first DA layers to connect with ZK Stack. It says "planned to connect", not that they are connected |
| The validium feature | PR #1461 (feat: Validium) of the zksync-era repository was merged on 2024-03-28 |

## The three products for institutions (Prividium)

Matter Labs splits its products for institutions into three under the name Prividium.
Matter Labs' Prividium page describes Prividium as an institutional platform made of three parts: Prividium Commander, Prividium Ledger, and Prividium Connect.

| Product | Role | Release date |
|---|---|---|
| Prividium Ledger | A private ZK chain an institution runs on its own infrastructure or in the cloud. Balances and transactions stay inside the institution, and only ZK proofs showing it ran correctly go to Ethereum | ZKsync's blog announced the first Prividium on 2025-05-27. Matter Labs now calls this chain Prividium Ledger |
| Prividium Commander | A system for managing token issuance, user registration, permissions, and approvals on chains that already exist. It checks each transaction request against the institution's rules and records each decision and its reason, including refused requests. It can be used on supported public chains and on private networks such as Hyperledger Besu | Matter Labs announced it at Money20/20 USA on 2026-10-21 |
| Prividium Connect | A system for institutions to exchange assets with each other across separate chains. Both transfers either succeed together or neither does, and a ZK proof shows that the agreed conditions were met. It shows no ledger to the other side and uses no intermediary or bridge | Matter Labs released it on 2026-11-10 and announced that it reached mainnet |

An institution using Commander can keep using Commander and its current integrations as they are if it later moves to Prividium Ledger.
In Connect, the two trading parties choose a settlement layer (Ethereum, another EVM chain, or a private chain), and that layer makes the result final for both.
When an exchange does not complete by its deadline, a party can take back the assets it put in, even if the other side does not respond.
Connect is built on a mutual communication protocol that ZKsync releases as open source and that combines two transfers into one transaction (atomic interop).
Commander and Connect connect to each other, but each can be used alone.

## The new plan for ZK token fees

Gluchowski of Matter Labs posted on ZK Nation's governance forum on 2026-11-13 that the plan for the ZK token ($ZK) economy is being rearranged.
The earlier plan assumed that institutions would connect Prividium Ledger to Ethereum as an L2, and that fees for mutual communication between L2s would flow into the ZK token economy.
In practice most institutions chose their own chains or private shared networks instead of L2s, so Matter Labs dropped the enterprise licensing part of the earlier plan.
In its place, it proposed setting up an official placement of Prividium Connect on public chains (a canonical deployment), and converting the mutual communication fees collected there into ZK tokens through the Fee Flow System.
How the converted ZK tokens are distributed is for governance to decide.

| Point | What the official sources say |
|---|---|
| The fee switch | The code for the switch that collects fees is finished, published, and under audit. After the audit ends, the Fee Flow System will be connected to Connect |
| Governance approval | Setting up the canonical deployment, running it, connecting it to the Fee Flow System, and the fee values all need the approval of ZKsync governance |
| Where the Fee Flow System lives | The contracts are on ZKsync Era. The v1.0 description on the governance forum (2026-05-06) names the auction proxy `0xF135fCd17733689462027bA7AfB210c2cB3C9803` and the Splitter proxy `0x17a78994EfC487577Cd372c966D5b3D1cD67A933`, and on 2026-11-16 the ZKsync Era RPC showed that both addresses hold code |
| How the Fee Flow System works | Fees in approved ERC-20 tokens collect in the auction contract, and anyone who pays the amount of ZK tokens set by the admin can take the collected fees. The ZK tokens paid go to the Splitter contract, which at release is set to burn 100% of them |
| Control | The right to change values belongs to governance through the ZK Token Governor Timelock. In urgent cases, another role (the Emergency Admin) can stop the claims |

## Current status

The ZK Stack chains and the Elastic Network are live.
Messages between chains run between chains connected to Gateway, but asset transfers and call bundles were dropped from v31 and postponed.
L2BEAT lists that v31 went into the shared L1 contracts on 2026-11-03, and that ZKsync Era applied v31 as the first chain on 2026-11-05.

Matter Labs' report for the first quarter of 2026 says the Atlas upgrade runs across the whole Elastic Network.
The report for the second quarter says Memento launched a mainnet with the Atlas upgrade, and that Airbender proofs were also used for an implementation outside ZKsync OS (ethrex).
On the other hand, L2BEAT says ZKsync Era's circuits are built with Boojum, and that Era is not a ZKsync OS chain.
Following L2BEAT, the switch to Airbender concerns chains running on ZKsync OS, and Era still proves with Boojum circuits.

Prividium Connect came out on 2026-11-10, and Matter Labs says it reached mainnet.
Prividium Commander was announced on 2026-10-21.
In the transcript of a video Matter Labs posted on 2026-11-11, Gluchowski says DTCC uses Commander on its collateral app chain.
The Fee Flow System contracts are on ZKsync Era, but the canonical deployment of Connect is still a plan, the fee switch is under audit, and running it needs governance approval.

The 2023 post's "the Boojum upgrade moved from SNARKs to STARKs" and "Hyperchain" were true of that time; today's documentation says ZK chain and Elastic Network.
The 2024 post's "validiums support modular DA layers, starting with Celestia within a few months" is still written as a plan in today's documentation.

## Not yet shipped

Public mutual communication using Gateway (asset transfers, call bundles, and fees) has no release date.
Matter Labs says shipping it to production needs a new proposal on the governance forum.

Which of Avail, Celestia, and EigenDA can be used with ZK Stack today has not been checked in official documentation.
Whether ZKsync Era moves from Boojum to Airbender, and when, has not been checked.
The release date of the Atlas upgrade, and the text of the announcement that Airbender replaces Boojum on new chains, have not been checked, because ZKsync's blog could not be read.

The canonical deployment of Prividium Connect on public chains, and converting its mutual communication fees into ZK tokens, are at the proposal stage.
When the governance forum was searched on 2026-11-16, no proposal (ZIP) putting this plan to a vote was found, and no fee values had come out.
When Connect will reach networks beyond Hyperledger Besu and Prividium Ledger is not stated.
The date Matter Labs began calling the first Prividium Prividium Ledger has not been checked.
Commander's price is not stated in the announcements.
