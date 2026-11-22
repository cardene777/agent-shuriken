---
status: live
checked: 2026-11-11
source: The L2Bridge Risk Framework post on the L2BEAT forum (by L2BEAT and Socket), and the Interop pages (the summary, Token frameworks, and Intent bridges) and the changelog of L2BEAT (now named ETHBEAT)
---

# The bridge risk framework (L2BEAT Interop)

The framework by which L2BEAT sorts and shows the mechanisms that move assets between chains (bridges).
The proposal it made with Socket in 2022 measured risk by the verification method and by what happens when a bridge stops.
In 2026 L2BEAT created an Interop section and moved to showing the flow of assets between chains sorted by who issues the token on the destination chain.

| Point | What the official documents say |
|---|---|
| The 2022 proposal | A proposal by L2BEAT and Socket posted to the L2BEAT forum on 2022-07-05. It asked for feedback and dealt mainly with bridges to and from Ethereum |
| How 2022 sorted bridges | Two kinds: token bridges that move value with messages (locking or burning on the source chain and minting on the destination), and liquidity networks that swap assets that already exist |
| Verification methods in 2022 | Five: light clients that check the validity of state (rollups), light clients that check consensus (such as IBC), an external set of validators, optimistic verification with a challenge period, and mixes of these |
| Swap methods in 2022 | Liquidity networks use one of three: HTLCs (atomic swaps locked by a hash and a deadline), conditional transfers in which the provider pays first and is repaid later by a message, and trust in external validators. The safety of a swapped asset follows the message bridge that issued it |
| Risk axes in 2022 | Censorship resistance; what happens to funds when the bridge stops (they return by a slow path, users become validators themselves, or they freeze); the liquidity provider (can mint without limit, permissioned, or anyone); and upgrade powers and permissioned actors |
| Start of Interop | Started on 2026-02-24. For each pair of chains it compares protocols by three ways of sending: Non-minting, Lock & Mint, and Burn & Mint |
| Growth of Interop | A breakdown by way of sending was added on 2026-03-23, controls on the summary page on 2026-04-20, the Token frameworks page on 2026-05-21, and the Intent bridges page on 2026-07-13 |
| Token frameworks | Lists the standards that create tokens spanning chains by way of sending (Lock & Mint or Burn & Mint) and by the volume, count, and speed over 24 hours. LayerZero's OFT, Chainlink CCIP's CCT, Wormhole's NTT, Hyperlane's Warp, and Axelar's ITS are listed |
| Intent bridges | Lists bridges driven by intents by volume and speed, plus four properties: the user's path to recover funds, whether solvers can join, the type of intent, and the settlement method. L2BEAT researches and writes the properties by hand |

## Current status

The Interop summary page and the Token frameworks page show amounts moved, such as volume, count, and transfer time, and have no column on the risk of each protocol.
The columns closest to risk are "the user's path to recover funds" and "the settlement method" on the Intent bridges page.
Across is described with a recovery path filled by a slow path, solvers anyone can join, and optimistic settlement.
Opening the old address of the bridges page shows the Interop summary page.

The differences from the 2022 proposal are three.
The 2022 proposal sorted whom to trust by verification method, while Interop sorts by who issues the token on the destination chain.
The 2022 proposal measured the risk of each bridge, while the Interop pages center on the amounts moved.
Interop has properties of intent-driven bridges, which the 2022 proposal did not.

The standard for intent-driven bridges is in the `erc-7683-cross-chain-intents` item of the `evm-standards` skill.

## Not yet shipped

L2BEAT's changelog has no entry for a framework that measures the risk of each Interop protocol, and whether one has shipped has not been checked.
The content of the talk in which L2BEAT's head of research spoke about a risk framework for Interop has not been checked.
Where the risk ratings shown on the old bridges page moved has not been checked.
