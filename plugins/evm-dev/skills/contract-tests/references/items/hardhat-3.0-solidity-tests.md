---
tool: hardhat
since: 3.0.0
checked: 2026-11-18
source: Hardhat 3 documentation, the guide on writing Solidity tests and the configuration reference
---

# Hardhat 3 runs Solidity tests, with fuzz and invariant runs, next to TypeScript tests

A Solidity file is a test file when it is under `test/`, or under `contracts/` with a name ending in `.t.sol`.
A contract in it with a function whose name starts with `test` is a test contract; `setUp()` runs before each test, and a revert fails the test.
A test function that takes parameters is a fuzz test.
Tests extend forge-std's `Test` and use its assertions and cheatcodes such as `vm.prank`.
`hardhat test solidity` runs them.

The settings are under `test.solidity` in the Hardhat config.
`fuzz.runs` defaults to 256.
`invariant` takes `runs` (256), `depth` (500), and `failOnRevert` (`false`).
`allowInternalExpectRevert` defaults to `false`, so `expectRevert` does not apply to a call at the test's own depth, as in Foundry 1.0.
`ffi` defaults to `false`; leave it off.
