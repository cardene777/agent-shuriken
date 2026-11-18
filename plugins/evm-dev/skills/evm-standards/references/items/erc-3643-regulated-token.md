---
status: live
checked: 2026-11-18
source: ethereum/ERCs: the ERC-3643 document; ERC3643 Association: the documentation page `Official factories and gateways`; Ethereum mainnet: the code at the `TREXFactory` and `TREXGateway` addresses
can: Security tokens can be sent only to investors whose on-chain identity is verified, and only when the token's compliance rules allow the transfer.
---

# ERC-3643 (regulated security tokens, T-REX)

A standard for security tokens that can be sent only to investors whose on-chain identity is verified.
It assumes ERC-20 and ERC-173 (the ownership standard), and the owner appoints agents who manage the token.

| Point | What the document says |
|---|---|
| Components | The token, the identity registry (`Identity Registry`) and its storage, the compliance contract (`Compliance`), and the registries of trusted issuers and of required claims |
| Recipient check | `transfer`, `transferFrom`, `mint`, and `forcedTransfer` call `isVerified`, which checks that the recipient's identity contract holds the required claims signed by a trusted issuer |
| Transfer rules | `transfer` and `transferFrom` also require `canTransfer` of the compliance contract to return true. `mint` and `forcedTransfer` bypass these rules, and `burn` bypasses all eligibility checks |
| Freezing | `setAddressFrozen` freezes a whole address, and `freezePartialTokens` freezes part of an amount |
| Recovery | An agent can move tokens with `forcedTransfer`, and `recoveryAddress` moves them from a lost address to a new one |
| Pausing | `pause` pauses the token, and `transfer` and `transferFrom` fail while it is paused |

## Current status

The document's status is `Final`, and it was created on 2021-07-09.

The ERC3643 Association's documentation names Ethereum among its production networks and gives one address for every chain: the factory that deploys the token suite, `TREXFactory` at `0x7F1fD450a5c4d91286f00F3297dCD5C12767f17f`, and its gateway, `TREXGateway` at `0x5FCC3D713dbc8252095E62Af98e62D14D0Be27dB`.
Both addresses had code on mainnet on 2026-11-18.

## Not yet shipped

Nothing remains open within the standard.
Which tokens were deployed through the factory, and which issuers issue tokens under this standard, have not been checked.
