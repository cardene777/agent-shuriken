# Changelog

Releases of the evm-dev plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

### Added

- The `contract-tests` skill writes unit, fuzz, and invariant tests for a project's contracts in Foundry and Hardhat, or has kiwa write them when the kiwa plugin's skills are installed. It first lists what each contract needs a test for (external and public functions, custom errors, events, access rules, functions that take integers, and balances that must add up), then names each point no test touches, runs the tests, and reports a bug a test shows instead of changing the contract
- Seven items on Hardhat 3's test runners, network helpers, Chai matchers, viem assertions, Solidity tests, and coverage, and on Foundry's invariant runs that drop reverted calls, each checked on 2026-11-17
- The `contract-design` skill designs smart contracts before they are written. It asks the decisions one at a time, records the recommended choice as an assumption when it cannot ask, and writes one design document from a template with nine sections: purpose and scope, contracts, token standards, state and invariants, roles and governance, upgrades, prices, ordering, and randomness, external calls and failures, and open decisions. For services that run scheduled calls, relay transactions, or watch contracts, such as Chainlink Automation and OpenZeppelin Defender, it reads the items of `dapp-architecture` and never chooses a deprecated or retired service
- Six items on OpenZeppelin 5.x proxies and access control, Chainlink Data Feeds deprecations, Chainlink VRF v2 shutting down on 30 November 2026 in favor of v2.5, private transaction relays, and SafeERC20, each checked on 2026-11-17; `contract-design.py verify` names each unfinished section and a Contracts section without the date the libraries were checked, and a checklist holds the rules a contract design must never break
- The `dapp-architecture` skill plans how a dApp's parts fit together. It asks the decisions one at a time, records the recommended choice as an assumption when it cannot ask, and writes one design document from a template with nine sections: purpose and users, components, transactions and gas, reading chain data, data placement, environments, keys and admin, monitoring and operations, and open decisions
- Nine items on indexers, relayers, automation, monitoring, testnets, multisigs, and storage, each checked on 2026-11-17, such as OpenZeppelin Defender's retirement on 1 July 2026, the deprecation of Chainlink Automation, Holesky's shutdown, and the rate limits on the public IPFS gateways; `list` marks the ones checked more than 90 days ago
- `dapp-architecture.py verify` names each section of a design that is missing, out of order, empty, still holding a `Fill in:` line, or, for Components, without the date the services were checked, and never prints the design's text
- A checklist of the rules a dApp design must never break, such as a sender and a payer for every write path, relayer keys kept apart from admin keys, indexing that survives reorganizations, and admin roles in a multisig behind a timelock

## [0.3.0] - 2026-11-16

### Added

- The `financial-standards` skill designs apps with on-chain and off-chain parts built on ISO 20022, FIX, FpML, CDM, LEI, and XBRL. It asks the decisions one at a time, records the recommended choice as an assumption when it cannot ask, and writes one design document from a template with nine sections
- Items on the version of each standard in force, such as CBPR+ SR2025 while Swift has deferred the payments part of SR2026, FIX Latest EP312, FpML 5.14, and CDM 7.10.0, each with the date it was checked against the official source and its source; `list` marks the ones checked more than 180 days ago
- `financial-standards.py verify` names each section of a design that is missing, out of order, empty, still holding a `Fill in:` line, or, for Standard and business, without the date the version was checked, and never prints the design's text
- A checklist of the rules a design must never break, such as keeping the original messages and personal data off chain, accepting only signed evidence that cannot be replayed, and appending corrections instead of overwriting them
- `claude plugin eval` cases for the skill under `evals/`, run by hand

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

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/evm-dev--v0.3.0...HEAD
[0.3.0]: https://github.com/cardene777/agent-shuriken/releases/tag/evm-dev--v0.3.0
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/evm-dev--v0.2.0
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/evm-dev--v0.1.0
