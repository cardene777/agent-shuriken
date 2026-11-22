---
status: live
checked: 2026-11-11
source: Ronin's blog (Ronin is Home and Ronin's Homecoming to Ethereum), Ronin's official documentation (Run a node), and the Ronin Network page of L2BEAT (now named ETHBEAT) (its timeline and risk section)
---

# Ronin

Ronin is a chain for games that moved in 2026-05 from an Ethereum sidechain to an L2 on the OP Stack.
Conduit runs its L2 infrastructure, and gas is still paid in RON.

| Point | What the official documents say |
|---|---|
| The plan to move | Ronin's blog said on 2025-08-15 that it would go from a game-focused Ethereum sidechain to an L2 aligned with Ethereum. The same post said it would choose its technical base again, and asked Polygon CDK, among others, for proposals as L2 builders |
| The date it moved | L2BEAT's timeline says it hard forked at block 55,577,490 on 2026-05-12 and became an OP Stack chain. Ronin's blog announced on 2026-05-13 that the move was complete |
| Architecture | The documentation describes Ronin as an Ethereum L2 built with the OP Stack, says Conduit runs its L2 infrastructure, and says its nodes run the same op-node and reth as other OP Stack chains |
| Gas | Ronin's blog says gas is still paid in RON, not ETH |
| Data store | The L2BEAT page says all data is kept on EigenDA and only the transaction roots go to Ethereum. It uses no contract that verifies EigenDA certificates on L1 |
| Proofs | The L2BEAT page says withdrawals are checked with a proof mechanism in which only permissioned parties can dispute (PermissionedDisputeGame). Boundless Kailua ZK proofs were once set as the mechanism that checks withdrawals in 2026-07, but in 2026-09 the Guardian switched back to the permissioned form |
| Operational powers | The L2BEAT page says a multisig wallet held jointly by Ronin and Conduit can upgrade most contracts with no waiting time |

The facts on the EigenDA side are in the `eigenda` item, and the framework of Polygon CDK and Agglayer is in the `polygon-agglayer-cdk` item.

## Current status

Ronin runs on mainnet as an OP Stack L2.
L2BEAT places Ronin under Others with no stage, because its proof system does not work and it has no bridge that checks its data store, and calls it an Optimium that keeps its data outside.
Ronin's blog says it will eventually use ZK fraud proofs through Boundless Kailua.

A 2024 post describes a plan to launch zkEVM chains for each game on top of Ronin, but Ronin itself became an Ethereum L2 with the OP Stack, not with Agglayer.

## Not yet shipped

What became of the Ronin zkEVM chains and the connection to Agglayer announced in 2024 has not been checked in official documents.
That the data store is EigenDA has not been checked in Ronin's own documents.
No date has been given for using Boundless Kailua ZK proofs again.
