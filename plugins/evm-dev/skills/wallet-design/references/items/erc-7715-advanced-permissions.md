---
topic: signatures
subject: MetaMask Advanced Permissions (ERC-7715) and the Smart Accounts Kit
checked: 2026-11-18
source: MetaMask, Smart Accounts Kit documentation (Advanced Permissions concepts and the Wallet Client actions reference)
---

# MetaMask grants permissions through the ERC-7715 method `wallet_requestExecutionPermissions`

MetaMask's Smart Accounts Kit, formerly the Delegation Toolkit, lets an app or an AI agent ask the MetaMask extension for permission to act for a user with the ERC-7715 method `wallet_requestExecutionPermissions`. The user sees a readable confirmation and can sometimes adjust it. It needs MetaMask 13.23.0 or later and a MetaMask smart account. The permission is granted to a session account that holds no tokens, which redeems it under ERC-7710. The permission types include periodic ERC-20 transfers and native token transfers, differ by version, and are listed by `getSupportedExecutionPermissions`.

For a design:

- Give an agent or an automated job a session account with a permission that has an amount, a period, and an expiry, instead of the user's key
- Check which permission types the user's wallet supports before relying on one, and fall back to asking for each transaction
- Check the status of ERC-7715 and ERC-7710 with the evm-standards skill; other wallets may not support them
