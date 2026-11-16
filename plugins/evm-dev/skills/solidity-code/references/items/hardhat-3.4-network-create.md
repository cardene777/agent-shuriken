---
tool: hardhat
since: 3.4.0
checked: 2026-11-16
source: Hardhat changelog, 3.4.0 and 3.7.0, and the Hardhat network manager reference
detect: network\.connect\(
files: *.ts *.js *.mjs *.cjs *.mts *.cts
---

# Hardhat scripts and tests get a network with network.create()

Hardhat 3.4.0 deprecated `hre.network.connect()` "in favour of `hre.network.create()`, exactly the same method but more clearly indicating that it will create a new connection."
The reference says "`network.connect()` is deprecated and will be removed in a future version."
Hardhat 3.7.0 declared Hardhat 3 stable.

```ts
import { network } from "hardhat";

const { viem } = await network.create();
```

`network.create("localhost")` connects to a named network.
