---
tool: hardhat
since: 3.0.0
checked: 2026-11-18
source: Hardhat 3 documentation, the guides on testing with viem and with ethers
---

# Hardhat 3 tests load fixtures through the connection's networkHelpers

`loadFixture` and the other network helpers (`impersonateAccount`, `setBalance`, and the time helpers) are on the `networkHelpers` object that the test's connection returns.
Tests do not import them from `@nomicfoundation/hardhat-network-helpers` as in Hardhat 2.

```ts
const { ethers, networkHelpers } = await network.create();

async function deployCounterFixture() {
  const counter = await ethers.deployContract("Counter");
  return { counter };
}

const { counter } = await networkHelpers.loadFixture(deployCounterFixture);
```

The first call runs the fixture.
Later calls reset the chain to the state right after it, which is faster than deploying again and undoes what earlier tests changed.
