# Changelog

Releases of the evm-dev plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

## [0.1.0] - 2026-11-16

- Answers whether an ERC is final or an EIP is live on Ethereum mainnet, and what it lets contracts and wallets do, from 41 items checked against the official ERC and EIP documents, each with the date it was checked and its source
- Covers ERCs and the EIPs that change what contracts, wallets, and dApps can do, such as new opcodes, precompiles, gas costs, and EIP-7702, and leaves out the state of L2 networks and changes that stay inside consensus
- `evm-standards.sh list` marks the items checked longer ago than their status allows (30 days when announced, 90 when specified, 180 when live or stopped), and the agent re-checks those against the official document before answering, or says it could not
- The agent never edits the items, and searches only with a standard's number or name
- Starts when you ask about the status of an ERC or EIP, or when you call it, in Claude Code, Codex, GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`
- The plugin has `claude plugin eval` cases under `evals/` that measure the skill, run by hand

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/evm-dev--v0.1.0...HEAD
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/evm-dev--v0.1.0
