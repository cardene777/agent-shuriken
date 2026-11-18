---
tool: solc
since: 0.8.35
checked: 2026-11-18
source: Solidity 0.8.35 release announcement; forge 1.5.1 and cast 1.5.1 with solc 0.8.38 run on a throwaway project
---

# erc7201() computes a namespaced storage slot, but inline assembly and forge 1.5.1's linter refuse it

Solidity 0.8.35 (2026-04-29) added the builtin `function erc7201(string memory id) returns (uint)`, "equivalent to `keccak256(keccak256(id) - 1) & ~0xff`", the ERC-7201 formula.

```solidity
contract MyContract layout at erc7201("openzeppelin.storage.MyContract") { }
```

In checks with forge 1.5.1 and solc 0.8.38:

- `layout at erc7201("<namespace>")` on a contract builds
- inline assembly cannot read a constant set with the builtin: `bytes32 private constant LOCATION = bytes32(erc7201("<namespace>"));` followed by `$.slot := LOCATION` fails to compile with Error (7615), "Only direct number constants and references to such constants are supported by inline assembly"
- forge 1.5.1's linter, which runs during `forge build`, fails the whole build with "unresolved symbol `erc7201`" wherever the builtin sits in an expression, in a constant or in a function body, although solc compiled it

So for a namespaced struct that a function reaches through inline assembly, write the slot as a number: get it with `cast index-erc7201 <namespace>`, which prints the same value as the builtin, keep it in a `bytes32 private constant`, and put the formula and the namespace in a comment above it, as OpenZeppelin does.
Use `erc7201(...)` in an expression only after building it with the project's forge; with forge 1.5.1 that takes `lint_on_build = false` under `[lint]` in `foundry.toml`, which turns the linter off.
Follow the project's existing style where one is set.

The same release warns when `at`, `error`, `layout`, `leave`, `super`, `this`, or `transient` are used as names in declarations, since they are planned to become keywords in 0.9.0.
