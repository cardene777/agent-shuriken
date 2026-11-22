---
status: specified
checked: 2026-11-16
source: ethereum/EIPs: the EIP-7805, EIP-7547, and EIP-8184 documents and EIP-8081 (the Hegotá meta EIP); the mainnet configuration in ethereum/consensus-specs; and, as research arguments, the X article by `_charlienoyes` (2024-06-27) and the research text on ethresear.ch (2024-06-24)
---

# EIP-7805 (FOCIL, inclusion lists enforced by the fork choice)

A standard that uses inclusion lists to make sure transactions are not shut out and reach a block without delay.
It is enforced by the fork choice rule (which block is chosen as the correct chain).

| Point | What the document says |
|---|---|
| Committee | In each slot some validators are chosen for the inclusion list committee; `IL_COMMITTEE_SIZE` is 16 |
| Making a list | Each member builds one inclusion list from the mempool it sees and spreads it. The size limit is 8 KiB |
| Building the block | The proposer or builder of the next slot puts the transactions of the collected lists into the block. Transactions that would be invalid at the end of the block because of the sender's `nonce` or balance, and transactions that do not fit in the block's remaining gas, may be missing |
| Voting | Voters vote only for a block that contains every transaction of the lists they hold, or whose missing transactions fall under the two cases of the row above. When two different lists arrive from the same member, that member's list is not counted |

## The six properties the standard names

The `Rationale` section of EIP-7805 describes FOCIL by these six properties.

| Property | What the document says |
|---|---|
| `Committee-based` | A committee of several validators, not one proposer, builds and spreads the lists. There are fewer targets for bribes and threats |
| `Fork-choice enforced` | Voters vote only for blocks that contain the list transactions and meet the conditions. Blocks that do not meet them are not put in the correct chain |
| `Same-slot` | The lists are built during slot N, so transactions seen in slot N can be made a condition of the block of slot N+1. There is no one-slot delay, as there was in the earlier proposal EIP-7547 |
| `Conditional inclusion` | A block is accepted even if it misses transactions that cannot be appended at the end or that do not fit in a full block |
| `Anywhere-in-block` | It does not decide where in the block the list transactions go. This lowers the incentive to avoid the mechanism through side channels |
| `No incentive mechanism` | Members are not paid; it relies on the premise that it works if one of the members is honest (`1-out-of-N`) |

The document says that `Conditional inclusion` and `Anywhere-in-block` together make it hard for a market outside the mechanism to arise.

## A research argument on one party holding consecutive slots

This section is a researcher's argument, not the content of the document.

The X article `Inclusion Lists Don’t Fix Multi-Block MEV in APS` by `_charlienoyes` (2024-06-27) argues that under APS (a proposal that separates the right to produce the execution part from the validator and sells it), when one party can buy consecutive slots, inclusion lists do not prevent MEV that spans consecutive blocks.
The builder can shut out arbitrage transactions in the earlier slots, fill the remaining space with its own transactions paying only the base fee, and in the last slot place its own transactions before the list transactions.
Preventing this needs list transactions to get priority at the top of the block, or unconditional inclusion that gets in even when the block is full.
The article says a market that sells that priority would arise outside the mechanism, and names FOCIL as a proposal that is conditional and has no top-of-block priority.

The document and the article describe the same combination, conditional and with no fixed position, from opposite sides.
The document calls it an advantage that reduces markets outside the mechanism; the article calls it a weakness that does not fully prevent shutting out when one party holds consecutive slots.

The article's premise is that one party can hold consecutive slots.
The research text on ethresear.ch `Execution Auctions as an Alternative to Execution Tickets` (2024-06-24) compares two ways of selling the right under APS.

| Way of selling | What the research text says |
|---|---|
| `Execution Auctions` | The right to each slot is sold in advance by auction. Who holds which slot is fixed beforehand, and holding x consecutive slots costs about x times the expected value of one slot |
| `Execution Tickets` | The right is sold as lottery tickets. If the winner of the next slot is drawn just before it, one party has a hard time holding slots in a row. If the winner gets the right to a slot several slots ahead, winning tickets can be bought up on a secondary market to hold slots in a row, so the same concern as with auctions remains |

The research text recommends auctions for their simpler design, and in the form it recommends one party can hold consecutive slots in advance.
The same text says inclusion lists (meaning EIP-7547) can curb the concern about concentration in auctions, the opposite of the article's view.
Neither way of selling has become a standard.

## Current status

The document's status is `Draft`, and it was created on 2024-11-01.
The Hegotá meta EIP (EIP-8081, status `Draft`) lists it under `Scheduled for Inclusion`.
The mainnet configuration of consensus-specs holds the inclusion list values in its Heze section and sets `HEZE_FORK_EPOCH` to a value not yet decided (`18446744073709551615`).

EIP-7547, the earlier inclusion list proposal, has the status `Stagnant`.
EIP-7547 had the proposer name the transactions that the next block should include.

## Standards that encrypt transactions and hold them back

EIP-8184 (LUCID) names EIP-7805 as a required standard and carries encrypted transactions in inclusion lists.
Its document says FOCIL relies on transactions being spread in public, so it cannot give censorship resistance to transactions exposed to MEV extraction.
The form of EIP-8184 is in the `eip-8184-lucid-encrypted-mempool` item of the `evm-standards` skill.
EIP-8105, another standard that brings an encrypted mempool into the protocol, is in the `eip-8105-encrypted-mempool` item of the `evm-standards` skill.

## Not yet shipped

It is not `Final` and is not live on mainnet.
The Hegotá meta EIP does not give a date it takes effect.
Talk of expecting Hegotá on mainnet in 2027 has not been checked in official documents.
The answer of FOCIL's authors to the article's argument has not been checked.
