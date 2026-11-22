---
status: live
checked: 2026-11-16
source: Polygon's Polygon Improvement Proposals repository (PIP-17, PIP-18, PIP-19, PIP-41, PIP-42, and PIP-46), Polygon's official blog (the announcements of the migration from MATIC to POL), Polygon's official documentation (Agglayer, CDK, and Polygon Chain), Polygon's Polygon zkEVM page, and the Astar zkEVM page of L2BEAT (now named ETHBEAT)
---

# Polygon 2.0, Agglayer, and CDK

Polygon 2.0 is the plan Polygon published in 2023 to make POL the common token and bring Polygon's chains together into one network.
Today it centers on Agglayer, which connects chains, and CDK, the parts that build chains; Polygon zkEVM, one of the pillars in 2023, stopped in 2026-07.

| Point | What the official documents say |
|---|---|
| POL (PIP-17) | Moves MATIC to POL one to one. The initial supply is 10 billion, with 2% newly issued each year, split equally between stakers and a community treasury. Status Final |
| The fee token of PoS (PIP-19) | Changes the fee token of the PoS network from MATIC to POL by upgrading the PoS bridge contract. Contracts on PoS do not change. Status Final |
| Staking rewards (PIP-41) | Newly issued POL is sent to the PoS staking contract as POL, instead of being converted back to MATIC first. Two lines of `EmissionManager.sol` change. Status Final |
| The staking token of PoS (PIP-42) | Upgrades the PoS `StakeManager` contract to a new implementation, converts all staked MATIC to POL, and takes new stakes and unstakes in POL. The existing functions called with MATIC remain through a migration contract. Reward rates, the unbonding period, and penalties do not change, and contracts on PoS do not change. Status Final |
| Phase 0 (PIP-18) | Advances in stages the move to POL, making POL the fee and staking token of PoS, and setting up the staking layer. Status Continuous, with the details worked out in other proposals |
| PoS today | The documentation calls PoS the Polygon Chain and describes it as an EVM-compatible Proof of Stake sidechain for Ethereum |
| Agglayer | A messaging mechanism that connects EVM chains. It moves assets without creating wrapped tokens, and makes processing across chains pass or revert as a whole |
| Pessimistic proofs | Proofs that keep a connected chain, even if taken over, from withdrawing more than that chain deposited |
| How chains connect | CDK chains connect to Agglayer from the start. Other chains connect on their own and keep their own architecture and governance after connecting |
| CDK's execution parts | Run with the OP Stack's op-geth or op-reth, or with CDK Besu of Hyperledger Besu. CDK Besu can choose only the sovereign form |
| CDK's forms | The default, sovereign, secures its connection to Agglayer with pessimistic proofs and needs no prover. A Validium checks execution with ZK and keeps data offchain, and today ships with OP Succinct AltDA. There is also a private Validium for institutions |
| How CDK is offered | The documentation describes CDK not as a tool to assemble yourself but as a product Polygon delivers tailored to institutions |
| Polygon zkEVM | The Mainnet Beta sequencer stopped on 2026-07-03 and produces no blocks. Withdrawals through the Agglayer bridge are not possible either |
| Funds left on zkEVM | Funds in accounts whose keys the user holds can be recovered through a claim page on Ethereum. The page closes on 2027-12-31. Funds inside contracts cannot be recovered through this page |
| Astar zkEVM | L2BEAT places it as a Validium built with the Erigon part of the Agglayer CDK, listing it as launched on 2024-03-06 and stopped on 2025-03-31. The entry is kept as an unmaintained record |

## Current status

The changes of POL and of the fee and staking tokens of PoS are live, with their proposals Final.
The PoS staking token changed from MATIC to POL with PIP-42, and newly issued POL reaches the staking contract as POL with PIP-41.
PIP-46 bundled PIP-19, PIP-41, and PIP-42 into one transaction, and Polygon's blog says the migration took effect on 2024-09-04.
Polygon's blog of 2025-09-03 says POL replaced MATIC as the fee and staking token of PoS.
Agglayer and CDK are live; today's CDK runs on the OP Stack or Besu, and connecting to Agglayer with pessimistic proofs is the default.
Polygon zkEVM, a pillar in 2023, and Astar zkEVM, built with CDK, have both stopped.

The 2023 posts' "Polygon 2.0 is a network of L2s that run on ZK" and "with CDK anyone can launch a ZK L2, like with the OP Stack" describe that time.
Today's documentation describes CDK as a product delivered to institutions, and its execution parts changed to the OP Stack and Besu.

## Not yet shipped

The date pessimistic proofs took effect in Agglayer production and the mechanism that makes the proofs (SP1) have not been checked in Polygon's official documents.
Of Phase 0 of PIP-18, the part that changes the staking token and rewards to POL was done with PIP-41 and PIP-42.
That the remaining parts, setting up the Staking Layer and moving PoS staking and rewards to it, have been set up has not been checked in Polygon's official documents.
Polygon's blog of 2024-09-04 says a staking hub was planned for 2025, but its release has not been confirmed.
Polygon's blog does not give the migration's transaction or block, and the upgrade of `StakeManager` has not been checked on chain.
The text of Astar's own shutdown announcement could not be read, so the date it stopped is the one L2BEAT lists.
The list of chains connected to Agglayer today, and whether new chains can still be built with the CDK Erigon part, have not been checked.
