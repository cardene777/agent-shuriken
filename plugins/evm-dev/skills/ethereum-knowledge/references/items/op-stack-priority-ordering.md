---
status: live
checked: 2026-11-16
source: Optimism's official documentation (Differences from Ethereum), Base's official documentation (Transaction Ordering, the Denim overview, and Migrate From Flashblocks), Uniswap's developer changelog (Live on Unichain: Fair Transaction Ordering and MEV Protection), Uniswap's blog (the announcement of fair ordering and MEV protection on Unichain), and Paradigm's research article (Priority Is All You Need)
---

# Transaction ordering in the OP Stack

On OP Stack chains, the party that orders transactions (the sequencer) orders them by priority fee, highest first.
This item holds, separately, the ordering of the OP Stack and of Base and Unichain, which grew from it, and a research argument on MEV taxes that relies on this ordering.
Arbitrum's ordering is in the `Timeboost` and `The proposal to move to PGA` rows of the `arbitrum-bold-stylus` item.

| Chain | What the official documents say |
|---|---|
| OP Stack | The `Mempool rules` section of Optimism's documentation `Differences from Ethereum` says OP Stack chains have no public mempool, and that only the sequencer sees the mempool today. The sequencer executes the transactions in the mempool by priority fee, highest first |
| Base | Base's documentation `Transaction Ordering` says Base makes a full block every 200 milliseconds. `base-reth-node` builds the blocks and orders the transactions within a block by priority fee |
| Base's Denim | The Denim upgrade replaced one block every 2 seconds with a full block every 200 milliseconds. Base's documentation says it took effect at 18:00 UTC on 2026-10-21 on Base Sepolia and on 2026-11-05 on Base Mainnet |
| Base's Flashblocks | Base stopped producing Flashblocks on both networks at activation. Flashblocks subscriptions, streams, and pending state no longer return data |
| Unichain | Uniswap's developer changelog says that from 2025-05-01 Unichain builds blocks inside a TEE (trusted execution environment) and strengthened ordering by priority fee. The block-building part was made by Uniswap Labs and Flashbots with Rollup-Boost |
| Unichain's revert protection | The same upgrade added protection against failing transactions (revert protection). Uniswap's blog says transactions are simulated in advance, and those expected to fail are not put in a block. Users of apps that enable this feature do not pay gas for failed transactions |

World Chain's form of reserving the top of the block for transactions of people with a World ID is in the `world-chain` item.
The record of Base leaving the OP Stack for a stack it runs itself is in the `op-stack-superchain` item.

## A research argument

This section is not a standard document; it is the argument of Paradigm's research article `Priority Is All You Need`.
The article was published by Dan Robinson and Dave White on 2024-06-04.

| Point | What the article says |
|---|---|
| MEV tax | A contract charges a fee in proportion to a transaction's priority fee. Charging 99 dollars per dollar of priority fee lets the app take 99% of the MEV decided by competition over that transaction |
| The ordering it relies on | The article calls `competitive priority ordering` a form in which the block builder orders transactions by priority fee and does not shut out, peek at, or delay transactions |
| Where it works | The Ethereum protocol does not require ordering by priority fee, but the article says the OP Stack sequencer, geth, and reth take this ordering by default. It says it can be used today on OP Stack L2s such as OP Mainnet, Base, and Blast |
| Where it does not work | If the block builder breaks the rule, it can escape the MEV tax and take the value itself, so the MEV tax relies on trusting the L2 sequencer. It says it probably does not work at all on Ethereum L1, where builder auctions that maximize the proposer's income dominate block building |

Uniswap's blog says building Unichain blocks inside a TEE strengthens the basis for mechanisms that capture value, such as the MEV tax.

## Current status

The OP Stack sequencer orders by priority fee, highest first, as Optimism's documentation says.
Base orders by priority fee in its own `base-reth-node`, and since 2026-11-05 has produced a full block every 200 milliseconds on mainnet.
Unichain builds blocks inside a TEE and orders them by priority fee.
The MEV tax is a research argument; there is no standard document.

The 2024 article names Base as an OP Stack L2, but Base has now moved to a stack it runs itself.

## Not yet shipped

Uniswap's blog said Flashbots would soon publish, at an endpoint it runs, proofs that let anyone check that Unichain blocks were built inside a TEE.
Whether that endpoint runs has not been checked.
Which apps use an MEV tax on mainnet, and how much, has not been checked.
