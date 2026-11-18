---
tool: solc
since: 0.8.27
checked: 2026-11-18
source: Solidity changelog, 0.8.26 and 0.8.27, the 0.8.27 release announcement, the Solidity documentation on error handling, and the Solidity bug list entry SOL-2026-6
---

# require takes a custom error

Solidity 0.8.26 introduced `require(bool, Error)` with a custom error, on the via-IR pipeline only.
0.8.27 (2024-09-04) made it available on the legacy pipeline too.

```solidity
require(amount <= balance, InsufficientBalance(amount, balance));
```

It reverts like `if (!(amount <= balance)) revert InsufficientBalance(amount, balance);`, but the documentation says `require` evaluates its arguments even when the condition is true, so the two forms are equivalent only when the arguments have no side effects.
Before 0.8.37, via-IR encoded an error built with named arguments inside `require`, such as `Err({b: 1, a: 2})`, in call-site order (bug SOL-2026-6, very low severity).
Follow the error style the project already uses.
