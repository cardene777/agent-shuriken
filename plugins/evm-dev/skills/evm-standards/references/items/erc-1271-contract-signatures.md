---
status: specified
checked: 2026-11-11
source: ethereum/ERCs: the ERC-1271 and ERC-7739 documents; Alchemy: the disclosure of the ERC-1271 signature replay weakness
---

# ERC-1271 (validating signatures from contracts)

A standard for checking from outside, in one common way, whether a contract account signed something.
Smart accounts that have no private key can still answer dapps that ask for a signature.

| Point | What the document says |
|---|---|
| Interface | Call `isValidSignature(bytes32,bytes)` |
| Success value | Returns `0x1626ba7e` when the signature is valid |
| Which to use | If the signer is an EOA, check with `ecrecover`; if it is a contract, check with this interface |

## The signature replay weakness

When one EOA owns several smart accounts and the checked value does not include the account's address, the same signature can be replayed on another account.
The ERC-7739 document says this pattern exists even in widely used apps.

ERC-7739 (status `Draft`) defines a procedure that rewraps the signed content so that it includes the account.
Even after rewrapping, the content stays readable in the EIP-712 display, so wallets can show what is being signed.

Alchemy found this weakness on 2023-10-27, and its disclosure on 2024-03-29 gave two fixes on the smart account side.

| Fix | What the disclosure says |
|---|---|
| Wrapping in an EIP-712 structure | Makes it easier for wallets to show the signed content in a readable form |
| A lighter form | Wallets end up showing a hash whose content cannot be read |

The disclosure says many smart accounts adopted the former, and that Alchemy's LightAccount also adopted the former.
As affected apps, it named transfers made with Permit2 signatures and Cowswap trades that use ERC-1271.

## Current status

The ERC-1271 document's status is `Final`, and it was created on 2018-07-25.
ERC-7739 is still `Draft`, and it was created on 2024-05-28.

## Not yet shipped

ERC-7739 is not finalized.
Whether the disclosure's former fix and the ERC-7739 procedure are the same, and which smart accounts use ERC-7739, have not been checked.
