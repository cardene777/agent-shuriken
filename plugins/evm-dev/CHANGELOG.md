# Changelog

Releases of the evm-dev plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

## [0.2.0] - 2026-11-16

### Added

- The `solidity-code` skill writes and changes Solidity contracts in Foundry and Hardhat projects for the versions of solc, OpenZeppelin, forge-std, Foundry, and Hardhat the project uses, following the project's own conventions and library
- `solidity-code.py project` prints the framework and those versions, `unknown` for a version it cannot read, and `none` for a tool the project does not use
- Items on what changed in those tools, each with the version it starts at, the date it was checked against the official document, and its source; `list` marks the ones checked more than 90 days ago
- `solidity-code.py scan` names each line written in a way the project's versions changed or no longer support, such as an OpenZeppelin import path renamed in 5.7.0 or a `tx.origin` check after EIP-7702, without printing the line, and lists the items it could not judge because a version is unknown
- After writing, the agent builds and runs the tests, and says so when they cannot run
- `claude plugin eval` cases under `evals/` for the skill, run by hand

## [0.1.0] - 2026-11-16

- Answers whether an ERC is final or an EIP is live on Ethereum mainnet, and what it lets contracts and wallets do, from 41 items checked against the official ERC and EIP documents, each with the date it was checked and its source
- Covers ERCs and the EIPs that change what contracts, wallets, and dApps can do, such as new opcodes, precompiles, gas costs, and EIP-7702, and leaves out the state of L2 networks and changes that stay inside consensus
- `evm-standards.sh list` marks the items checked longer ago than their status allows (30 days when announced, 90 when specified, 180 when live or stopped), and the agent re-checks those against the official document before answering, or says it could not
- The agent never edits the items, and searches only with a standard's number or name
- Starts when you ask about the status of an ERC or EIP, or when you call it, in Claude Code, Codex, GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`
- The plugin has `claude plugin eval` cases under `evals/` that measure the skill, run by hand

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/evm-dev--v0.2.0...HEAD
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/evm-dev--v0.2.0
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/evm-dev--v0.1.0
