---
status: specified
checked: 2026-11-18
source: ethereum/EIPs: the record of PR #7281; ethereum/ERCs: the record of PR #961 and the draft it adds
can: Token issuers can let several bridges mint and burn their token on other chains.
---

# ERC-7281 (xERC20, cross-chain tokens minted through bridges, with no merged standard)

A proposal for cross-chain tokens in which the token issuer lets several bridges mint and burn the token.
It was submitted under the name `Sovereign Bridged Token`.

## Current status

There is no merged standard document for xERC20.
PR #7281 to ethereum/EIPs (`Add EIP: Sovereign Bridged Token`) was opened on 2023-07-05 and closed without being merged on 2023-10-25.
PR #961 to ethereum/ERCs (`Create erc (minimal xERC20)`) was opened on 2025-03-12, and was still open after an update on 2026-09-01.
It adds a `Draft` document numbered ERC-7905, `Minimal Sovereign Bridged Token (Minimal xERC20)`, which requires ERC-20 and ERC-165 and leaves out the lockbox wrappers and the extensive configuration functions of the earlier proposal.
ERC-7905 is not in ethereum/ERCs until that PR is merged.

A 2024 post says "xERC20 based on EIP-7281", but 7281 is a PR number, not the number of a finalized standard.

## Not yet shipped

Merging and finalization as a standard document.
Which bridges and tokens use xERC20 has not been checked.
