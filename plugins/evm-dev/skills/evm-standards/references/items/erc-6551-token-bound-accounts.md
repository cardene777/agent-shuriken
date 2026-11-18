---
status: live
checked: 2026-11-18
source: ethereum/ERCs: the ERC-6551 document; Ethereum mainnet: the code at the registry address
can: Every NFT can have its own account, so the NFT can own assets and use apps.
---

# ERC-6551 (accounts owned by NFTs)

A standard that assigns an Ethereum account to every NFT, so that the NFT can own assets and use apps.
It works without changing existing NFT contracts or infrastructure.

| Point | What the document says |
|---|---|
| Registry | An ownerless, immutable registry deployed with Nick's factory at `0x000000006551c19487814612e58FE06813775758` |
| Registry interface | `createAccount` creates an account, and `account` computes its address before it is created |
| Account form | Each account is deployed with `create2` as an ERC-1167 minimal proxy to its implementation, with the salt, the chain ID, the NFT contract address, and the token ID appended to the bytecode |
| Signatures | Every account implementation must implement ERC-1271 signature validation |
| Required standards | ERC-165, ERC-721, ERC-1167, ERC-1271 |

## Current status

The document's status is `Review`, and it was created on 2023-02-23.
It has still not reached `Final` since the time of a 2023 post.
The registry address had code on mainnet on 2026-11-18, so the registry runs there although the document is not `Final`.

## Not yet shipped

Since it is not `Final`, the interface may change.
Which apps use it has not been checked.
