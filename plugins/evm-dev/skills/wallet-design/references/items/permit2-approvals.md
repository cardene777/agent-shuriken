---
topic: approvals
subject: Permit2 allowances and signature phishing
checked: 2026-11-17
source: Uniswap, Permit2 documentation (AllowanceTransfer); Revoke.cash, What is Permit2; MetaMask Support, Signature phishing
---

# Permit2 allowances expire, but a phished signature still moves the tokens

Permit2 gives each allowance an amount and an expiration, and treats the largest uint160 amount as unlimited. A user approves Permit2 once per token and then signs EIP-712 permits for each spender, so a malicious site can take tokens by getting one permit signed, with no transaction from the user. Revoke.cash advises revoking Permit2 allowances that are no longer used, and MetaMask advises checking the site and reading what a signature grants before signing.

For a design:

- Ask for the amount the action needs and an expiration of minutes or hours, never the largest amount
- Show the spender, the amount, and the expiration in words before asking for a permit
- Let users see and revoke their allowances, including those given through Permit2
