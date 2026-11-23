# Changelog

Releases of the evm-dev plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

## [0.8.0] - 2026-11-23

### Added

- `evm-standards` holds an item for EIP-8288, the frame mode that aggregates post-quantum signatures into one recursive STARK per block: what contracts read through the frame introspection of EIP-8141, its `Draft` status, and that no network upgrade names it. The item on EIP-8141 points to it
- `ethereum-knowledge` holds two items on the post-quantum work on L1: EIP-8292, the opt-in aggregator role that proves many post-quantum attestation signatures in one proof and leaves the execution layer unchanged, and pqai27, the proposal of 2026-11-11 to reach post-quantum security in 2027, with what it asks of Hegotá, quick slots, and FOCIL and the thread that argues to keep shipping finished features in parallel

### Fixed

- The `ethereum-knowledge` test finds its changelog line under any release, so it no longer fails after a later release moves the line down
- `release-check.py layout` compares the slot each ERC-7201 namespace sits at, as the contract or a base assigns it to `<pointer>.slot` in inline assembly, a number or a constant, and names a changed one with a `slot` line instead of printing `compatible`. A constant written as an expression is compared by its expression, and a namespace whose slot no build sets, or sets to two values, is `not-compared`
- `contract-tests.py uncovered` counts an access point only when a test expects the error its guard raises: `OwnableUnauthorizedAccount` for `onlyOwner`, `AccessControlUnauthorizedAccount` for `onlyRole`, `AccessManagedUnauthorized` for `restricted`, and the custom error or revert string of the project's own guard. A bare `vm.expectRevert()`, a bare revert check in a Hardhat test, or another error no longer counts; when the guard's error cannot be read, the test must name some error
- The release-check skill says where to simulate the upgrade script: without `--broadcast` against the chain the proxy lives on, or, when no reachable chain has it, on `anvil` after deploying the deployed version from the worktree with its own deploy script

## [0.7.0] - 2026-11-22

### Changed

- `evm-standards` reads no article index unless the user names one, and gives no articles then. The user names it in one line of `~/.evm-dev/article-index`, as a URL or a path to a file, and `EVM_DEV_INDEX_URL` wins when both are set. The index keeps the line form of an llms.txt list from any site; a link is printed only when it is https and, for an index read from an http or https URL, on the same host as the index. An index named by a URL is kept for one day as one copy per URL, and an index named by a path is read in place
- The README says before the skill list, and in its table of what the plugin needs, that `contract-deploy` signs deploys to production chains only with a Ledger or Trezor hardware wallet

## [0.6.0] - 2026-11-22

### Added

- A new `ethereum-knowledge` skill answers how L2 networks and rollup frameworks work and stand, what is planned for Ethereum L1, and whether EIPs that change only consensus are live, from 51 dated items with their sources. `ethereum-knowledge.sh check` names an item with a missing field, an unknown status, an impossible date, or an ERC name, and `list` marks the items past the days for their status. Questions on ERCs and on EIPs that change what contracts and wallets can do stay with `evm-standards`, whose description now names `ethereum-knowledge` for the rest

### Changed

- The report of `release-check` follows the `structure` format of page-design in the design-formats plugin through musubi, as an optional follow declared in `skills/release-check/musubi.json`: the result first, what was checked and skipped with the reasons, values not measured written as not measured, and the user's steps last. When the `musubi` command is installed, the agent runs `musubi check` before reading the format. Without design-formats, the skill reports in its own order
- The five design skills, `contract-design`, `wallet-design`, `multichain-design`, `dapp-architecture`, and `financial-standards`, write in the design format of the `design-doc` skill in the new doc-formats plugin, which Claude Code installs with evm-dev, and check a design with its `verify`, passing their own `templates/sections.md`. The designs they write keep the same sections
- Each design skill declares in `musubi.json` the version range and fingerprint of the format and `verify` it follows, and stops when `design-doc` is not installed
- Each design skill has a finished example design in `examples/`, and its script keeps only `check` and `list`
- The eval cases of the five design skills load doc-formats too, so they run from the repository root with `claude plugin eval . --eval-dir plugins/evm-dev/evals`; `token-sale-contracts` also checks that `contract-design` opens `design-doc`

## [0.5.0] - 2026-11-18

### Added

- `evm-standards` finds standards by what they let contracts, wallets, and dApps do with `evm-standards.sh find`, from a new `can` field on every item and the articles of a fixed index
- `evm-standards` gives the title and link of the article on each standard it names with `evm-standards.sh article`. It reads a fixed article index with a plain request that carries no word of the question, and keeps it in `~/.local/share/evm-dev/` for one day

### Changed

- `verify` of `contract-design`, `wallet-design`, `multichain-design`, `dapp-architecture`, and `financial-standards` also names each decision ID, such as D9, that a design cites but no row of its Open decisions table defines
- The checklists of the five design skills check more: the EIP-7825 cap of 16,777,216 gas per transaction and a role granted without the delay the design relies on (`contract-design`), the ERC-7562 limits at account creation and the function each party calls during recovery (`wallet-design`), what a manual-execution gas override reaches and the refill of a token-bucket rate limit (`multichain-design`), a role that can revoke without the timelock and so grant without it, and a pause key that can do more than pause (`dapp-architecture`, and the pauser in `contract-design`), and a terminal state moved back after it closed (`financial-standards`)
- `release-check` builds both versions from the source folder with `--ast`, so the two builds hold the same contracts, and removes the temporary worktree with `git worktree remove --force`, which a worktree with submodules needs
- `contract-tests` counts a fuzz point only when a test function with parameters calls it, lists functions guarded by OpenZeppelin's `restricted` as access points, and counts a mapping to an integer with named key and value, or one inside a struct, as an invariant point
- `contract-deploy.py keys` reads JSON files, such as the per-chain settings a deploy script reads, and names a key or a mnemonic written in one by file and line without printing it
- `contract-deploy.py record` names each run whose recorded commit may not be the deployed code with a `commit-differs` line: source or Foundry settings files that differ from that commit and were last changed before the broadcast
- The solidity-code item on the `erc7201(...)` builtin says that inline assembly cannot read a constant set with it and that forge 1.5.1's linter fails the build wherever it is used in an expression, and to write the slot from `cast index-erc7201` instead

### Fixed

- `release-check.py layout` compares the fields of each ERC-7201 namespaced struct (`@custom:storage-location erc7201:<id>`) of a contract and its base contracts between the two versions, read from the syntax tree that `forge build --ast` writes, and names each field removed, moved, or retyped. It printed `compatible` before, because solc's storage layout leaves these structs out. When it cannot compare them, it prints a `not-compared` line with the reason and never prints `compatible` for that contract
- Every item of the ten evm-dev skills was compared with its primary source and is dated 2026-11-18. Among the facts corrected: the execution delay of OpenZeppelin's `AccessManager` belongs to each member of a role; the KelpDAO attacker unlocked rsETH on Ethereum rather than minting it; CCIP pools from v1.6.1 on set limits in the local chain's decimals; the CBPR+ changes moved out of SR2026 to a later release; Ponder has reached 0.18.9; Gelato's relay services shut down on 1 September 2026; ERC-7683 now covers only how solvers read a protocol's orders; Foundry has used the `osaka` EVM version by default since 1.7.0 and refuses `--resume` after a reverted transaction since 1.9.0; and the gas floor of EIP-7623 includes the 21,000 base cost. Items now also say that Ponder's `reorgWindow` counts at most 600 seconds, so finality comes from the RPC's `finalized` block; that Safe's `Safe4337Module` 0.3.0 supports only EntryPoint v0.7; that a CCIP 2.0 pool refills to the new capacity whenever its rate limit changes; that CreateX does not reject a salt naming another address but deploys elsewhere; and that contracts behind a proxy use the `contracts-upgradeable` variants

## [0.4.0] - 2026-11-17

### Added

- The `release-check` skill checks contracts before a release: it builds the deployed git tag or commit in a temporary worktree, compares its storage layout and ABI with the new version, finds opcodes each target chain's EVM cannot run, runs OpenZeppelin's upgrade check when the project has it, compares gas with `forge snapshot --diff` and sizes with `forge build --sizes`, and checks deployment transactions against the per-transaction gas cap of EIP-7825
- `release-check.py layout` compares two storage layouts from `forge inspect`, artifacts, or `out/` folders and names each variable that was removed, moved, or retyped (also inside structs), each `__gap` that no longer ends where it did, and each variable that was only renamed
- `release-check.py abi` names each function, event, and error that was removed or changed, and `release-check.py opcodes` names each opcode in the runtime code or the constructor that a given EVM version lacks, such as `PUSH0`, `MCOPY`, `TLOAD`, `TSTORE`, and `CLZ`
- Eight items on the opcodes each EVM version added and the compilers' default versions, the EVM version of Ethereum, Arbitrum, OP Mainnet, Base, and Linea, the gas cap of EIP-7825 and the size limits, getting storage layouts from Foundry and Hardhat, ERC-7201 namespaced storage, Solidity's `layout at`, OpenZeppelin's upgrade check, and gas and size comparisons, each checked on 2026-11-17
- The `contract-deploy` skill writes Foundry and Hardhat Ignition deploy scripts that never touch keys, simulates them, and hands the user the command to sign with a hardware wallet (`--ledger` or `--trezor`, with `--slow`) on production chains and an encrypted keystore (`cast wallet import` and `--account`, or the Hardhat 3 keystore) on test chains. The user runs the command; the skill never reads a key, a mnemonic, or a password and refuses a command that passes one
- `contract-deploy.py keys` names each place a project handles a key unsafely, by kind and `file:line` without printing the key: keys read from environment variables, commands that pass `--private-key`, `--mnemonic`, or `--password`, keys and mnemonics written into files, and `.env` files that git tracks or does not ignore
- `contract-deploy.py record` builds one record per chain from Foundry's broadcast files and Hardhat Ignition's journals, writes it to `deployments/<chain id>.json` with `--write`, and names each transaction that reverted, has no receipt, or does not show the contract it was recorded as creating; it never reads Foundry's `cache/`, which holds RPC URLs
- Seven items on Foundry keystores, hardware wallets in Foundry and Hardhat 3, the Hardhat 3 keystore, Foundry's broadcast files, Hardhat Ignition's deployment folders, Etherscan API V2 and its Free tier, and where Foundry and Hardhat verify source code by default, each checked on 2026-11-17
- The `contract-tests` skill writes unit, fuzz, and invariant tests for a project's contracts in Foundry and Hardhat, or has kiwa write them when the kiwa plugin's skills are installed. It first lists what each contract needs a test for (external and public functions, custom errors, events, access rules, functions that take integers, and balances that must add up), then names each point no test touches, runs the tests, and reports a bug a test shows instead of changing the contract
- Seven items on Hardhat 3's test runners, network helpers, Chai matchers, viem assertions, Solidity tests, and coverage, and on Foundry's invariant runs that drop reverted calls, each checked on 2026-11-17
- The `contract-design` skill designs smart contracts before they are written. It asks the decisions one at a time, records the recommended choice as an assumption when it cannot ask, and writes one design document from a template with nine sections: purpose and scope, contracts, token standards, state and invariants, roles and governance, upgrades, prices, ordering, and randomness, external calls and failures, and open decisions. For services that run scheduled calls, relay transactions, or watch contracts, such as Chainlink Automation and OpenZeppelin Defender, it reads the items of `dapp-architecture` and never chooses a deprecated or retired service
- Six items on OpenZeppelin 5.x proxies and access control, Chainlink Data Feeds deprecations, Chainlink VRF v2 shutting down on 30 November 2026 in favor of v2.5, private transaction relays, and SafeERC20, each checked on 2026-11-17; `contract-design.py verify` names each unfinished section and a Contracts section without the date the libraries were checked, and a checklist holds the rules a contract design must never break
- The `wallet-design` skill designs an app's wallets and signing. It asks the decisions one at a time, records the recommended choice as an assumption when it cannot ask, and writes one design document from a template with nine sections: purpose and users, accounts, keys and recovery, signatures and permissions, approvals, gas and sponsorship, agent payments, chains and environments, and open decisions
- Six items on ERC-4337 EntryPoint v0.8 and v0.9, EIP-7702 delegation and its initialization, MetaMask Advanced Permissions (ERC-7715), Permit2 allowances and signature phishing, EIP-5792 batching with the ERC-7677 paymaster service, and x402 payments, each checked on 2026-11-17; `wallet-design.py verify` names each unfinished section and an Accounts section without the date the services were checked, and a checklist holds the rules a wallet design must never break
- The `multichain-design` skill designs apps that run on more than one chain. It asks the decisions one at a time, records the recommended choice as an assumption when it cannot ask, and writes one design document from a template with nine sections: purpose and chains, deployment and addresses, assets across chains, messages and verification, partial failures, roles and limits, fees and gas, monitoring and environments, and open decisions
- Five items on CREATE2 factories for the same address on every chain (ERC-7955), Circle retiring CCTP V1 between 31 October and 1 December 2026 in favor of V2, LayerZero's verifier configuration after the April 2026 KelpDAO exploit, Chainlink CCIP token pool rate limits, and Superchain interop, each checked on 2026-11-17; `multichain-design.py verify` names each unfinished section and a Messages and verification section without the date the protocols were checked, and a checklist holds the rules a design across chains must never break
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

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/evm-dev--v0.8.0...HEAD
[0.8.0]: https://github.com/cardene777/agent-shuriken/releases/tag/evm-dev--v0.8.0
[0.7.0]: https://github.com/cardene777/agent-shuriken/releases/tag/evm-dev--v0.7.0
[0.6.0]: https://github.com/cardene777/agent-shuriken/releases/tag/evm-dev--v0.6.0
[0.5.0]: https://github.com/cardene777/agent-shuriken/releases/tag/evm-dev--v0.5.0
[0.4.0]: https://github.com/cardene777/agent-shuriken/releases/tag/evm-dev--v0.4.0
[0.3.0]: https://github.com/cardene777/agent-shuriken/releases/tag/evm-dev--v0.3.0
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/evm-dev--v0.2.0
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/evm-dev--v0.1.0
