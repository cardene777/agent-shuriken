---
tool: solc
since: 0.8.27
checked: 2026-11-16
source: Solidity changelog, 0.8.26 and 0.8.27, and the 0.8.27 release announcement
---

# require takes a custom error

Solidity 0.8.26 introduced `require(bool, Error)` with a custom error, on the via-IR pipeline only.
0.8.27 (2024-09-04) made it available on the legacy pipeline too.

```solidity
require(amount <= balance, InsufficientBalance(amount, balance));
```

On 0.8.27 or later, it is equivalent to `if (!(amount <= balance)) revert InsufficientBalance(amount, balance);`.
Follow the error style the project already uses.
