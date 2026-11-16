---
tool: hardhat
since: 3.0.0
checked: 2026-11-16
source: Hardhat migration guide from Hardhat 2
detect: module\.exports|require\(\s*.(hardhat|@nomicfoundation)
files: hardhat.config.*
---

# Hardhat 3 config is an ES module with its plugins listed

The Hardhat migration guide says: "Your Hardhat config must be an ES module." and "Hardhat 3 requires your project to be an ES module", with `"type": "module"` in `package.json`.
Plugins are both imported and listed: "Unlike Hardhat 2, you need to both import the plugin and add it to the list of plugins".

```ts
import { defineConfig } from "hardhat/config";

export default defineConfig({
  plugins: [],
  solidity: "0.8.28",
});
```

`defineConfig` (from 3.0.11) only returns the config it is given; the documentation uses it, and exporting the object works too.
A `module.exports` config is Hardhat 2.
