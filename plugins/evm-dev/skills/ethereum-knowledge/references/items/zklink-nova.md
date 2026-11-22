---
status: stopped
checked: 2026-11-11
source: zkLink's official documentation (Architecture Overview and Settlement Layer) and the zkLink Nova page of L2BEAT (now named ETHBEAT)
---

# zkLink Nova

zkLink Nova is an L3 chain built with ZK Stack, with Linea as the chain it settles to.
zkLink calls it an aggregated L3: it gathers the assets of many L2s on one chain and keeps its state in line with each L2 through Linea.
It was attacked and stopped on 2026-10-28, and L2BEAT moved it to an entry kept only as a record.

| Point | What the official documents say |
|---|---|
| Layers | Split into four layers, for ordering, execution, settlement, and data, each upgradable separately |
| Primary chain | The documentation says Linea is the primary chain "for now", because Linea can verify zk-SNARK proofs and settles on Ethereum quickly |
| Secondary chains | Chains other than the primary do not verify proofs; they rely on the primary chain's checks through messages that arrive over the canonical rollup bridge |
| The settlement flow | The sequencer posts proofs and batches of transactions to the verifier contract on the primary chain, and zkLink's contract verifies the proofs. When the sync values from the secondary chains match, the batch is finalized, its root is sent to the secondary chains, and users can withdraw on each chain |
| Finality | Onchain actions such as deposits reach Nova at once, but a transaction becomes irreversible only once settlement on several chains is done |
| How L2BEAT places it | L2BEAT puts its type under Others and describes it as an L3 zkEVM Validium using ZK Stack, with Linea as its base chain |
| L2BEAT's data field | L2BEAT says transaction data is not posted to Ethereum and is held by a data committee. It warns that there is no data bridge |
| L2BEAT's connected chains | Ethereum, Linea, OP Mainnet, Arbitrum One, Base, Manta Pacific, Mantle, Scroll, Blast, and ZKsync Era |
| L2BEAT's verifier field | L2BEAT says the contract that verifies proofs is on Linea, and Linea's owner can replace it with no waiting time |
| L2BEAT's fast path field | L2BEAT says permitted validators can relay messages without going through the canonical bridge, and these are later reconciled with the slow path |
| L2BEAT's risk fields | State is checked with validity proofs, data is outside, there is no exit window (contracts can be upgraded immediately), and withdrawals are impossible if the proposer stops |
| L2BEAT's update log | zkLink's core contract was paused on 2025-03-10 (pausing only deposits), and on 2025-05-30 an upgrade to an unverified implementation went in |

## Current status

The L2BEAT page says an attacker drained funds from the escrow contract on Ethereum on 2026-10-28, and zkLink stopped the network and halted withdrawals.
It lists the amount drained as about 800 thousand dollars, using a fake batch root, and warns against depositing.
L2BEAT moved this entry to an unmaintained record.

A 2024-03 post introduced Nova as the first aggregated L3 gathering the liquidity of every L2, but it is now stopped, and by L2BEAT's fields withdrawals from the L3 are not possible.
The network stopped and L2BEAT moved it to an unmaintained record, so the status is `stopped`.

## Not yet shipped

zkLink's own post-incident report and when the network will be restored have not been checked in official announcements.
Which parts of ZK Stack it uses, and whether it follows the current ZKsync version, have not been checked in zkLink's documentation.
The members of the data committee and the number of signatures it needs have not been checked.
