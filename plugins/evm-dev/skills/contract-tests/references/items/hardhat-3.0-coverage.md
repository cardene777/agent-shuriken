---
tool: hardhat
since: 3.0.0
checked: 2026-11-18
source: Hardhat 3 documentation, the guide on computing code coverage, and the Hardhat 3.0.0 pre-release notes
---

# Hardhat 3 measures coverage itself with hardhat test --coverage

`hardhat test --coverage` measures coverage for Solidity and TypeScript tests.
It prints a Markdown report in the terminal and writes LCOV and HTML reports to `coverage/`.
Hardhat 3 does not need the `solidity-coverage` plugin for this.

Coverage shows which lines ran, not whether a test checked the result; this skill's `uncovered` is the check it uses.
