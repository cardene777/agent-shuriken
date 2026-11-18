---
status: live
checked: 2026-11-18
source: ethereum/ERCs: the ERC-4906 document; OpenZeppelin/openzeppelin-contracts: the source of `ERC721URIStorage`; OpenSea: the developer documentation page `Updating metadata`
can: Contracts can emit an event when the metadata of an ERC-721 token changes, so marketplaces and indexers can refresh it.
---

# ERC-4906 (signaling that NFT metadata changed)

A standard that emits an event when the metadata JSON of an ERC-721 token changes.
Outside interfaces such as marketplaces can then re-read the metadata of many NFTs without delay.

| Point | What the document says |
|---|---|
| A single change | Emit `MetadataUpdate(uint256 _tokenId)` |
| A change over a consecutive range | Emit `BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId)` |
| When to emit | Must emit whenever the metadata JSON of one token or of a consecutive range changes. It recommends not emitting at mint or burn |
| Support signal | `supportsInterface` returns `true` for `0x49064906` |
| Required standards | ERC-165, ERC-721 |

## Current status

The document's status is `Final`, and it was created on 2022-03-13.

It is in use: OpenZeppelin's `ERC721URIStorage` emits `MetadataUpdate` from `_setTokenURI` and returns `true` for `0x49064906`.
OpenSea's developer documentation tells ERC-721 collections to use the ERC-4906 events for one token or a range of tokens, so that OpenSea can refresh the affected items.
Both were checked on 2026-11-18.

## Not yet shipped

Nothing remains open within the standard.
Which marketplaces other than OpenSea read this event has not been checked.
