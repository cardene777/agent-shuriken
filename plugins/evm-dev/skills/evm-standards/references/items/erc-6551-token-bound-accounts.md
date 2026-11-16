---
status: specified
checked: 2026-11-11
source: ethereum/ERCs: the ERC-6551 document
---

# ERC-6551 (accounts owned by NFTs)

A standard that assigns an Ethereum account to every NFT, so that the NFT can own assets and use apps.
It works without changing existing NFT contracts or infrastructure.

| Point | What the document says |
|---|---|
| Registry | An ownerless, immutable registry deployed with Nick's factory at `0x000000006551c19487814612e58FE06813775758` |
| Registry interface | `createAccount` creates an account, and `account` computes its address before it is created |
| Account form | Each account is deployed as an ERC-1167 minimal proxy, with the implementation address, the chain, the NFT address, and the token ID appended to the bytecode |
| Signatures | Every account implementation supports ERC-1271 signature validation |
| Required standards | ERC-165, ERC-721, ERC-1167, ERC-1271 |

## Current status

The document's status is `Review`, and it was created on 2023-02-23.
It has still not reached `Final` since the time of a 2023 post.

## Not yet shipped

Since it is not `Final`, the interface may change.
Whether code exists at the registry address on mainnet, and which apps use it, have not been checked.
