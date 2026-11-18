---
tool: hardhat
since: 3.0.0
checked: 2026-11-18
source: Hardhat 3 documentation, the hardhat-ethers-chai-matchers plugin reference
---

# Hardhat 3's Chai matchers come from hardhat-ethers-chai-matchers, and some take the ethers instance first

The matchers come from `@nomicfoundation/hardhat-ethers-chai-matchers`.
`.to.be.reverted` is replaced by `.to.revert(ethers)`.
`revertedWithoutReason`, `changeEtherBalance`, `changeEtherBalances`, `changeTokenBalance`, and `changeTokenBalances` take the `ethers` instance as their first argument, because one test can hold several connections.

```ts
await expect(vault.withdraw(1n)).to.be.revertedWithCustomError(vault, "InsufficientBalance").withArgs(0n, 1n);
await expect(vault.deposit({ value: 1n })).to.emit(vault, "Deposited").withArgs(owner.address, 1n);
await expect(vault.sweep(other.address)).to.revert(ethers);
await expect(vault.withdraw(1n)).to.changeEtherBalance(ethers, owner, 1n);
```

`revertedWith`, `revertedWithCustomError(contract, name)`, `revertedWithPanic`, `emit(contract, name)`, and `withArgs` keep their Hardhat 2 shape.
