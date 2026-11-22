---
status: live
checked: 2026-11-11
source: The Stages page, the changelog, and the Blast page of L2BEAT (now named ETHBEAT), and Blast's official page
---

# L2BEAT Stages

The framework by which L2BEAT sorts rollups into three stages, Stage 0, Stage 1, and Stage 2, by how far they have left their operators' hands.
The stage depends on whether the proof system runs, who can stop withdrawals, and whether users have a period to leave before an unwanted upgrade.
L2BEAT changed its name to ETHBEAT on 2026-11-04, and its changelog says the people, the research, and the data stay the same.

| Point | What the official documents say |
|---|---|
| Stage 0 | Calls itself a rollup, posts L2 state roots to L1, keeps on L1 the data to rebuild the state, and publishes the node software that rebuilds the state. It has a proof system that judges whether state roots are valid |
| Fraud proofs at Stage 0 | An optimistic rollup lets at least 5 outside parties submit fraud proofs |
| The principle of Stage 1 | Apart from bugs, the only way to keep L2-to-L1 messages (such as withdrawals) stopped or to pass invalid messages is to take over 75% or more of the Security Council |
| The exit window of Stage 1 | Upgrades started by anyone outside the council are allowed only with a period of at least 7 days in which users can leave |
| Stage 2 | Anyone can submit fraud proofs. There is a period of at least 30 days to leave an unwanted upgrade, and upgrades started by the DAO are included |
| The council at Stage 2 | The council can act only when a bug that can be judged onchain is found. If there is an onchain mechanism that finds bugs, immediate upgrades are allowed for the bugs it finds |
| Page updates | The Stages page was last updated on 2025-07-23. The page says the framework has been revised several times since it started and will keep changing |
| Projects with no stage | The Blast and Eclipse pages give reasons such as a proof system that does not run, and place them under Others with no stage |

## Current status

L2BEAT places Blast under Others with no stage, and says it does not reach even Stage 0.
The reasons are that its fraud proof system is unfinished, one permissioned party posts state roots, only a permissioned multisig can challenge, and invalid state roots can pass.
The L2BEAT page says Blast's upgrades have no delay, and there is no period to leave an unwanted upgrade.
The L2BEAT page describes Blast as an OP Stack chain launched on mainnet on 2024-02-29, and keeps the page archived.

The L2BEAT page says Blast is in the middle of winding down; it closed deposits and stopped the OptimismPortal, so withdrawals from the bridge are no longer possible.
The page says ETH and DAI were moved to a claim contract held by the Blast team.
Blast's official page only explains how those who held ETH, WETH, and USDB claim them from a recovery contract on Ethereum.
The L2BEAT page records that the challenge period was shortened from 7 days to 1 day in October 2026.

The claim of a 2023 post that "Blast is only a 3/5 multisig" dates from when it was a deposit contract; today Blast is in the middle of winding down.
The view that "Blast is a Stage 0 optimistic rollup" differs from L2BEAT's current page.

## Not yet shipped

The date Blast decided to wind down and the claim deadline have not been checked in Blast's official announcements.
The text of the forum post that the Stages page says holds "the exact specification" has not been checked.
No framework page that sets out the rule for placing projects under Others was found; this was checked only through the reason fields of the Blast and Eclipse pages.
