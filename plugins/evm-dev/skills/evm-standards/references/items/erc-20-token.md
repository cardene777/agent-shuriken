---
status: specified
checked: 2026-11-11
source: ethereum/ERCs: the ERC-20 document; OpenZeppelin/openzeppelin-contracts: the changelog
can: Tokens can be transferred, hold balances, and give allowances to other addresses through one common interface.
---

# ERC-20 (fungible tokens)

A token standard that gives transfers, balances, and allowances for other addresses one common form.

| Point | What the document says |
|---|---|
| Allowance | `approve(_spender, _value)` sets the maximum the spender can withdraw |
| Changing it | Calling `approve` again overwrites the previous allowance with `_value` |
| Front-running problem | The document cites the attack on overwriting an allowance through a link to an outside document. If the spender uses the previous allowance before the overwriting transaction, it can withdraw both the previous and the new amount |
| What the document recommends | User interfaces SHOULD reset the allowance to `0` before setting a different value for the same spender |
| Contracts | For compatibility with contracts deployed earlier, the contract side does not enforce resetting to `0` |

## Current status

The document's status is `Final`, and it was created on 2015-11-19.

OpenZeppelin Contracts 5.0.0 (2023-10-05) removed `increaseAllowance` and `decreaseAllowance`, which are not in the standard, from `ERC20`.
`safeIncreaseAllowance` and `safeDecreaseAllowance`, used to increase and decrease an allowance, remain in `SafeERC20`.

## Not yet shipped

Nothing remains open within the standard.
Which tokens require resetting to `0` first has not been checked.
