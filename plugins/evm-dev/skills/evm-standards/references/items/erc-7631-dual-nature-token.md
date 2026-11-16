---
status: specified
checked: 2026-11-16
source: ethereum/ERCs: the ERC-7631 document; Guardian: the results of its DN404 audit
---

# ERC-7631 (a fungible token paired with an NFT)

A standard that links an ERC-20 contract and an ERC-721 contract, and mirrors operations on one side to the other.
It turns the form known in 2024 by the name `DN404` into a standard.

| Point | What the document says |
|---|---|
| Pair | Links two contracts, an ERC-20 and an ERC-721 |
| Mirroring | Reflects an operation on one side in the balances and owners on the other side |
| Prerequisites | Has ERC-20 and ERC-721 in `requires` |
| Skipping NFT minting | The optional `IERC7631BaseNFTSkippable` has `getSkipNFT(owner)`, `setSkipNFT(status)`, and the `SkipNFTSet` event. It lets each account skip the minting and sending of ERC-721 tokens that accompanies ERC-20 transfers |
| Recommendation to skip contracts by default | The document cites, as a convenient form, having `getSkipNFT` return true by default when `owner` is a smart contract |

The skipping mechanism exists for accounts that move large amounts of ERC-20 at once.
The document mentions large transfers between allocation contracts, sale contracts, liquidity pools, and treasury accounts.
`getSkipNFT` may revert, but once it has returned true or false for an `owner`, it must not revert for that `owner`.
It recommends making `setSkipNFT` callable by anyone.

## The security section

The Security Considerations section of the document covers three points.

| Point | Content |
|---|---|
| Who calls the mirroring functions | Guard the external functions used for mirroring so that only the other contract in the pair can call them |
| Targeting rare NFTs | In pairs that issue NFTs of varying rarity, make sure the reveal of an NFT cannot be manipulated through metadata reads and ERC-20 transfers. It recommends revealing after the same account has held the NFT for a while |
| Gas growth | Because one ERC-20 transfer can involve minting, sending, and burning several ERC-721 tokens, gas is O(n) rather than O(1). Account for the gas of choosing token IDs too, so that operations do not stop by running out of gas |

## A real case found in an audit

In its DN404 audit, Guardian reported a bug in an implementation of the recommended form.
Contract accounts were put in the category that skips NFT minting, but the category was decided by whether code existed at the first touch, and afterwards only the account's owner could change it.
An attacker could send a small amount of ERC-20 to an address that can be computed in advance, such as a Uniswap liquidity pool, before it is deployed, and fix it in the category of an account without code.
NFTs are then minted to the pool and cannot be moved, and the gas of large swaps grows.
It was fixed after the audit.

The same audit also reported a mismatch between the store that collects burned NFT IDs and a separate minting path, and an order in which ERC-20 sales burn the NFTs that arrived later first.

## Current status

The document's status is `Final`, and it was created on 2024-02-21.
The statement "still `Draft`" in a 2024 post differs from the current status.

## Not yet shipped

Nothing remains open within the standard.
The standard does not define the internals of the mirroring or the procedure for linking the two contracts, and leaves them to implementations.
Which tokens use it has not been checked.
