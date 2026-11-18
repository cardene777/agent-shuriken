---
tool: solc
since: 0.8.28
checked: 2026-11-18
source: Solidity 0.8.28 release announcement
---

# Transient state variables

Solidity 0.8.28 (2024-10-09) fully supports transient storage state variables of value types, in both the IR and legacy pipelines.

```solidity
bool transient locked;
```

A transient variable is cleared at the end of each transaction, which makes it fit reentrancy locks; OpenZeppelin's `ReentrancyGuardTransient` keeps its lock in transient storage.
Transient storage needs a chain at the Cancun EVM version or later.
See the item on 0.8.34 before clearing a transient variable with `delete` on the via-IR pipeline.
