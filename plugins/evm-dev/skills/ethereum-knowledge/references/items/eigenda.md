---
status: live
checked: 2026-11-11
source: EigenLabs' blog (the mainnet announcements of EigenLayer and EigenDA, the dual quorum announcement, and the EigenDA V2 announcement), the data availability risk page and the project pages of L2BEAT (now named ETHBEAT), the release notes of the mantle-v2 repository of mantlenetworkio, and Mantle's announcement of 2026-01-22
---

# EigenDA

EigenDA is a data store for rollups (a DA layer) that runs on EigenLayer's restaking.
A rollup keeps its transaction data on EigenDA instead of Ethereum blobs, and sends commitments to its state or proofs to Ethereum.
The data is guarded by the operators who joined EigenDA, not by Ethereum's validators as a whole.

| Point | What the official documents say |
|---|---|
| Mainnet | Went to mainnet with EigenLayer on 2024-04-09. EigenDA was then in beta and did not include payments from AVSs to operators or slashing. Rollups were to be onboarded once operators and delegation had settled |
| Two quorums | The announcement of 2024-05-21 made the first quorum ETH restaking and the second EIGEN staking. A blob can be retrieved as long as at least one quorum is not compromised |
| Production traffic | The same announcement of 2024-05-21 said it accepts production traffic from any rollup |
| A rollup's own token | As of 2024-05, a form in which a rollup secures its blobs with its own token was planned. The V2 announcement of 2025-07 says a rollup can secure its own EigenDA with its own token |
| V2 | Went to mainnet on 2025-07-30. The disperser now sends only batches of blob headers to the nodes, and the nodes fetch the data themselves. It says V2 runs at 100 MB/s with a latency of 5 seconds on average and 10 seconds at p99 |
| V2 users | At the V2 announcement, Fuel and Aevo used it in production, and MegaETH and Celo were on test networks |
| L2s using it now | L2BEAT lists Aevo, Celo, Fuel Ignition, MegaETH, RISE, Ronin, and Soon Alpha Mainnet as L2s whose data store is EigenDA |
| Checks on L1 | L2BEAT says Celo and RISE verify EigenDA certificates in an L1 contract (DACert Verifier), and that Fuel Ignition has no DA bridge |
| Mantle | Mantle moved from MantleDA to EigenDA in 2025-03 and removed the EigenDA path in the Arsia upgrade of 2026-04. It now posts to Ethereum blobs. The `mantle` item holds the history |

## Current status

EigenDA runs on mainnet as V2.
L2BEAT places most L2s that keep their data on EigenDA under Others, and places Celo as an Optimium.
An explanatory post from 2023 names Mantle as a user of EigenDA, but Mantle moved to Ethereum blobs in 2026-04 and no longer uses EigenDA.
The claim in outside explanations that "Mantle moved to blobs in 2026" matches Mantle's announcement of 2026-01-22 and the timeline of L2BEAT.

## Not yet shipped

Whether slashing has been enabled on EigenDA has not been checked.
No rollup actually using a quorum of its own token has been confirmed.
The pages of EigenDA's official documentation could not be opened, and the quorum numbers (0 for ETH, 1 for EIGEN) were seen only in a search summary.
What the "EigenDA V3 certificate" on L2BEAT's page refers to has not been checked in EigenDA's own documents.
