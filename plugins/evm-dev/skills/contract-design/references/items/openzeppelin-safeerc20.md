---
topic: tokens
subject: OpenZeppelin SafeERC20 and non-standard ERC-20 tokens
checked: 2026-11-17
source: OpenZeppelin, Contracts 5.x ERC-20 API reference (SafeERC20)
---

# SafeERC20 copes with tokens that return no value or need approval reset

`SafeERC20` reverts when a token returns `false`, and also supports tokens that return no value. Its `forceApprove` is meant for tokens that require the allowance to be set to zero before a new non-zero value, such as USDT. Under ERC-7674, `forceApprove` leaves a temporary allowance in place.

For a design:

- Move every outside token with `SafeERC20`, and approve with `forceApprove`
- List each token the contracts accept and what it may do: return no value, charge a fee on transfer, rebase, pause, block addresses, or be upgraded by its issuer
- When a token may charge a fee or rebase, measure the balance before and after a transfer instead of trusting the amount sent, or refuse such tokens
