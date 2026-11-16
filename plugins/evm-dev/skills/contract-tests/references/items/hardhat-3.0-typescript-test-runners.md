---
tool: hardhat
since: 3.0.0
checked: 2026-11-17
source: Hardhat 3 documentation, the guides on testing with viem and with ethers
---

# Hardhat 3 runs TypeScript tests with node:test or Mocha, and each test gets ethers or viem from its connection

A project on `@nomicfoundation/hardhat-toolbox-viem` writes its TypeScript tests with `node:test` (`describe` and `it` come from `node:test`) and checks values with `node:assert/strict`.
A project on `@nomicfoundation/hardhat-toolbox-mocha-ethers` writes Mocha tests with Chai.
Read `package.json` and the tests the project already has, and use the same runner.

`ethers`, `viem`, and `networkHelpers` come from the connection the test opens, not from `import { ethers } from "hardhat"` as in Hardhat 2.
The guides open it with `network.create()`; Hardhat before 3.4.0 calls it `network.connect()`.

```ts
import { describe, it } from "node:test";
import { network } from "hardhat";

describe("Counter", async function () {
  const { viem, networkHelpers } = await network.create();

  it("emits Increment", async function () {
    const counter = await viem.deployContract("Counter");
    await viem.assertions.emitWithArgs(counter.write.inc(), counter, "Increment", [1n]);
  });
});
```

`hardhat test` runs every test.
`hardhat test solidity`, `hardhat test nodejs`, and `hardhat test mocha` run one kind, and `hardhat test <file>` runs one file.
