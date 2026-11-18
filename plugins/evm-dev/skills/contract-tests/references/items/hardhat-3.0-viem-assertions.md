---
tool: hardhat
since: 3.0.0
checked: 2026-11-18
source: Hardhat 3 documentation, the hardhat-viem-assertions plugin reference
---

# Hardhat 3 projects on viem check reverts and events with viem.assertions

The `hardhat-viem-assertions` plugin adds these to `viem.assertions`: `revert`, `revertWith` (a reason string), `revertWithCustomError`, `revertWithCustomErrorWithArgs`, `emit`, `emitWithArgs`, and `balancesHaveChanged`.
Values are checked with `node:assert/strict`.

```ts
await viem.assertions.revertWithCustomError(vault.write.withdraw([1n]), vault, "InsufficientBalance");
await viem.assertions.revertWithCustomErrorWithArgs(vault.write.withdraw([1n]), vault, "InsufficientBalance", [0n, 1n]);
await viem.assertions.emitWithArgs(vault.write.deposit({ value: 1n }), vault, "Deposited", [owner, 1n]);
```

Write calls take their arguments as one array (`vault.write.withdraw([1n])`), and a call from another account passes `{ account: other.account }` after it.
