---
status: specified
checked: 2026-11-11
source: ethereum/ERCs: the ERC-3643 document
can: Security tokens can move only between investors who have completed identity verification.
---

# ERC-3643 (regulated security tokens, T-REX)

A standard for security tokens that move only between investors who have completed identity verification.
It assumes ERC-20 and ERC-173 (the ownership standard).

| Point | What the document says |
|---|---|
| Components | The token, the identity registry (`Identity Registry`) and its storage, the compliance contract (`Compliance`), and the registries of trusted issuers and of required claims |
| Recipient check | On every transfer, `isVerified` checks that the recipient's on-chain identity record (ONCHAINID) holds the required claims |
| Transfer rules | On every transfer, `canTransfer` checks that the transfer meets the overall rules |
| Freezing | `setAddressFrozen` freezes a whole address, and `freezePartialTokens` freezes part of an amount |
| Recovery | `forcedTransfer` moves tokens from the issuer side, and `recoveryAddress` moves them from a lost address to a new one |
| Pausing | `pause` stops all transfers of the token |

## Current status

The document's status is `Final`, and it was created on 2021-07-09.

## Not yet shipped

Nothing remains open within the standard.
Which issuers issue tokens under this standard has not been checked.
