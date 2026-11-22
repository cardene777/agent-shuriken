---
status: live
checked: 2026-11-11
source: The Mantle page of L2BEAT (now named ETHBEAT) (its timeline and update log), Mantle's announcement of 2026-01-22, the release notes of v1.1.1 of the mantle-v2 repository of mantlenetworkio, and the release notes of v1.5.4 of the mantle-v2 repository of mantle-xyz
---

# Mantle

Mantle is an Ethereum L2 based on the OP Stack, whose fees are paid in MNT.
It changed its data store from its own MantleDA to EigenDA and then to Ethereum blobs, and brought in OP Succinct ZK proofs to check its state.
It now runs as a rollup that posts its data to Ethereum blobs and checks its state with ZK proofs.

| Point | What the official documents say |
|---|---|
| Mainnet | L2BEAT's timeline says it went to mainnet on 2023-07-14 and finished the Mainnet v2 upgrade (Tectonic) on 2024-03-15 |
| From MantleDA to EigenDA | The release of Mantle's repository of 2025-03-07 (Mainnet Everest) enables EigenDA on mainnet in place of MantleDA. L2BEAT's timeline says it stopped MantleDA and moved to EigenDA on 2025-03-19 |
| To OP Succinct | L2BEAT's timeline says it upgraded to OP Succinct on 2025-09-16, bringing in ZK proofs to check its state |
| Adding blobs | L2BEAT's update log says Mantle started posting data to Ethereum blobs alongside EigenDA on 2026-01-21. At that point there was no contract verifying EigenDA on L1, and the outside path to EigenDA also remained |
| Announcement of the move to blobs | On 2026-01-22 Mantle announced it would move its main data store to Ethereum blobs. It called its earlier form an architecture based on a Validium, said it would move to a ZK rollup form secured directly by Ethereum, and gave the larger blob capacity after Fusaka as the reason |
| The Arsia upgrade | L2BEAT's timeline says the Arsia upgrade of 2026-04-16 removed the EigenDA path, made Ethereum the only data store, and reclassified Mantle as a rollup. The v1.5.4 release of Mantle's repository says Arsia takes effect on Mantle mainnet at 2026-04-22 07:00 (UTC) |
| Current classification | L2BEAT places Mantle as a ZK Rollup at Stage 0, with Ethereum blobs as its data store and OP Succinct ZK proofs (SP1) to check its state. A switch to an optimistic form that requires no ZK proof also remains |

The facts on the EigenDA side are in the `eigenda` item, and the framework for choosing an outside DA layer is in the `validium-external-da` item.

## Current status

Mantle runs as a ZK rollup that posts its data to Ethereum blobs.
The 2023 post's "an optimistic rollup that puts its data on EigenDA" differs from the current form in both its data store and its state checks.
In its announcement of 2026-01-22, Mantle said its collaboration with EigenLayer continues for specific uses.

## Not yet shipped

Whether L2BEAT placed Mantle under Validium between 2025-09 and 2026-04 has not been checked in the timeline of the current page.
Whether every path to EigenDA stopped after the Arsia upgrade has not been checked in Mantle's official documentation.
