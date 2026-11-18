---
status: live
checked: 2026-11-18
source: ethereum/ERCs: the ERC-7631 document; Vectorized/dn404: the README; Guardian: the report of its DN404 audit (2024-05-13); Ethereum mainnet: calls to `mirrorERC721()` and `baseERC20()` on the `MORSE` DN404 pair
can: An ERC-20 contract and an ERC-721 contract can be linked so that operations on one side are mirrored on the other.
---

# ERC-7631 (a fungible token paired with an NFT)

A standard that links an ERC-20 contract and an ERC-721 contract, and mirrors operations on one side to the other.
The README of `DN404` (Vectorized/dn404) calls it an implementation of such a pair and points to this standard.

| Point | What the document says |
|---|---|
| Pair | The ERC-20 (base) must implement `mirrorERC721()` and the ERC-721 (mirror) must implement `baseERC20()`, each returning the other contract. A non-zero address signals support, so ERC-165 is not required |
| Mirroring | Transfers on the ERC-20 can trigger transfers on the ERC-721 and the other way round. The standard does not define this synchronization logic |
| Prerequisites | Has ERC-20 and ERC-721 in `requires` |
| Skipping NFT minting | The optional `IERC7631BaseNFTSkippable` has `getSkipNFT(owner)`, `setSkipNFT(status)`, and the `SkipNFTSet` event. It lets an account skip the ERC-721 mints and transfers that accompany ERC-20 transfers |
| Recommendation to skip contracts by default | The document calls it a useful pattern to have `getSkipNFT` return true by default when `owner` is a smart contract |

The skipping mechanism exists for accounts that move large amounts of ERC-20 at once.
The document mentions loading vesting contracts, loading contracts that sell ERC-721 tokens, moving tokens in and out of liquidity pools, and moving tokens between admin accounts.
`getSkipNFT` and `setSkipNFT` may revert, so an ERC-20 without them still complies.
The pairing may be linked by any mechanism, but it must not change once it is established.

## The security section

The Security Considerations section of the document covers three points.

| Point | Content |
|---|---|
| Who calls the mirroring functions | Guard the external functions used for mirroring so that only the other contract in the pair can call them |
| Targeting rare NFTs | In pairs that issue NFTs of varying rarity, make sure the reveal of an NFT cannot be manipulated through metadata reads and ERC-20 transfers. It recommends revealing after the same account has held the NFT for a while |
| Gas growth | Because one ERC-20 transfer can involve minting, sending, and burning several ERC-721 tokens, gas is O(n) rather than O(1). Account for the gas of choosing token IDs too, so that operations do not stop by running out of gas |

## A real case found in an audit

In its DN404 audit, Guardian reported a bug in how contracts were put in the category that skips NFT minting.
The category was set at the first interaction with an address, by whether the address had code at that time, and it was not set again when code was deployed there later.
An attacker could send tokens to the address where a pool for the token was about to be deployed, so that NFTs are minted to and burned from the pool on liquidity changes and swaps, and many of them may be unable to move.
The report marks it resolved.

The same audit also reported that a separate minting path (`_mintNext`) ignored the pool of burned NFT IDs (resolved).
It also reported that NFTs leave a holder last in, first out, so selling ERC-20 can burn an NFT the wallet has just received from an accepted bid; the DN404 team acknowledged this without changing it.

## Current status

The document's status is `Final`, and it was created on 2024-02-21.
The statement "still `Draft`" in a 2024 post differs from the current status.

It is in use on mainnet: on 2026-11-18, the ERC-20 `MorseDN404` (`MORSE`) at `0xe591293151fFDadD5E06487087D9b0E2743de92E` returned `0x027DA47D6a5692c9b5cB64301A07d978cE3cB16c` from `mirrorERC721()`, and that ERC-721 returned the ERC-20 from `baseERC20()`, with a `totalSupply` of 3236 NFTs.
This pair was found from a block explorer listing, not named by its issuer.

## Not yet shipped

Nothing remains open within the standard.
The standard does not define the internals of the mirroring or the procedure for linking the two contracts, and leaves them to implementations.
Which other tokens use it has not been checked.
