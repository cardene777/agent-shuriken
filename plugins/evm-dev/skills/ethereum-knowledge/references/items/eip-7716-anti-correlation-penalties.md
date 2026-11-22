---
status: specified
checked: 2026-11-16
source: ethereum/EIPs: the EIP-7716 document, EIP-8081 (the Hegotá meta EIP), and EIP-7569, EIP-7600, EIP-7607, and EIP-7773; and the analysis Deep Diving Attestations - A quantitative analysis posted by Nero_eth on ethresear.ch
---

# EIP-7716 (Heavier penalties for validators that go offline together)

A standard that makes the penalty for a missed vote heavier in proportion to how many validators missed their votes at the same time.
It makes setups that fail together, on the same node, cloud, client, region, or operator, costly, and cuts the scale advantage of large uniform setups.
The penalty of a validator that goes offline alone, unrelated to others, stays as it is.

| Point | What the document says |
|---|---|
| When a validator counts as offline | When an active, unslashed validator submitted neither its source vote nor its target vote in time in that epoch. A validator that submitted its source vote in time and got only its target vote wrong showed it is alive, so it is not counted |
| When the penalty grows | In each slot, when the total balance of offline validators exceeds its moving average (`smoothed_offline_balance`). A factor (`penalty_factor`) in proportion to the excess is computed; without an excess the factor is 1 |
| Slope and cap of the factor | The slope `PENALTY_SLOPE` is 765 and the cap `MAX_PENALTY_FACTOR` is 256. The factor reaches the cap exactly when a third of the total balance is offline |
| Penalties the factor applies to | Only the target vote penalty of offline validators. The source vote penalty, the head vote, the rewards and penalties of proposers and the sync committee, and the inactivity leak (`inactivity leak`) do not change |
| Speed of the moving average | `OFFLINE_BALANCE_SMOOTHING_FACTOR` is 2 to the 16th, a half-life of about 45,500 slots (about 6.3 days). The factor is high when validators first go offline and falls as the moving average catches up |
| Examples of the factor | When 1% of the total goes offline together, the initial factor is about 9; at 5% about 39, at 10% about 78, and at 20% about 154 |
| Where the extra penalty goes | It is burned, not paid to other validators |

## Current status

The document's status is `Draft`, and it was created on 2024-05-25.
The Hegotá meta EIP (EIP-8081, status `Draft`) places EIP-7716 under `Declined for Inclusion`.
The meta EIPs of Dencun, Pectra, Fusaka, and Glamsterdam (EIP-7569, EIP-7600, EIP-7607, and EIP-7773) do not list EIP-7716.
An earlier version counted the excess penalties with `NET_EXCESS_PENALTIES` (with a factor capped at 4), but the document replaced it with the current comparison against a moving average.

## Not yet shipped

It is not `Final` and is not in any network upgrade.
It is not live on mainnet.
Which network upgrade after Hegotá it will be in has not been decided.

## Notes

The analysis `Deep Diving Attestations - A quantitative analysis`, posted by Nero_eth on ethresear.ch on 2024-07-09, counted votes as groundwork for an analysis of EIP-7716.
It covers slots 9,169,184 to 9,392,415 (2024-05-27 to 2024-06-28), which the analysis gives as 6,975 epochs, or 31 days.
139 validators, 0.014% of the total, did not vote once in the four weeks counted.
The analysis uses this number as an upper estimate of the validators that stay offline because their keys were lost.
