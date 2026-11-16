# EVM Dev

Know whether an ERC is final or an EIP is live on Ethereum mainnet, write Solidity and its tests for the versions your project uses, plan a dApp's architecture, and design apps built on financial standards such as ISO 20022 and FIX, from items checked against the official documents instead of what the agent remembers.

English · [日本語](README.ja.md)

An agent's knowledge stops at its training cutoff, while standards and tools keep moving: an EIP ships in a network upgrade, a widely cited "ERC" turns out never to have been merged, a library renames the files you import, a framework deprecates the call your script makes, a hosted relayer or automation service shuts down, a payments standard release is deferred.
This plugin ships dated items on all of them, each with the date it was checked against the official document and the document it came from.

| Skill | What it does |
|---|---|
| `evm-standards` | Answers whether an ERC is final or an EIP is live, and what it lets contracts and wallets do, from 41 items on ERCs and EIPs |
| `solidity-code` | Writes and changes contracts in Foundry and Hardhat projects for the solc, OpenZeppelin, forge-std, Foundry, and Hardhat versions the project uses, then scans the code for outdated patterns and builds and tests it |
| `contract-tests` | Writes unit, fuzz, and invariant tests for a project's contracts in Foundry or Hardhat, or has kiwa write them when it is installed, from a list of what each contract needs tested, then names what no test covers and runs the tests |
| `dapp-architecture` | Plans how a dApp's parts fit together: asks the decisions one at a time and writes one design document on who sends and pays for each transaction, how the app reads chain data, where data lives, the environments, the admin keys, and monitoring, then checks its sections and reviews it against a checklist |
| `financial-standards` | Designs an app with on-chain and off-chain parts built on ISO 20022, FIX, FpML, CDM, LEI, or XBRL: asks the decisions one at a time, writes one design document from a template, checks its sections, and reviews it against a checklist |

```
evm-standards:  List the items ──> Read the ones asked about ──> Re-check stale ones ──> Answer with date and source
solidity-code:  Read the project's versions ──> Read the items for them ──> Write ──> Scan, build, and test
contract-tests:  Read the versions and items ──> List what needs a test ──> Write the tests, or have kiwa write them ──> Name what no test covers ──> Run the tests
dapp-architecture:  Read the items ──> Ask the decisions ──> Write the design ──> Verify the sections ──> Review against the checklist
financial-standards:  Read the items ──> Ask the decisions ──> Write the design ──> Verify the sections ──> Review against the checklist
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install evm-dev@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add evm-dev@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install evm-dev@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/evm-standards   # Gemini CLI
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/solidity-code
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/contract-tests
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/dapp-architecture
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/financial-standards
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

`evm-standards` starts when you ask about the status of a standard, for example "is EIP-7702 live on mainnet?" or "can I cite ERC-7281 as final?".
`solidity-code` starts when you ask for a contract to be written or changed, for example "add a pausable ERC-20 token to this Foundry project".
`contract-tests` starts when you ask for tests of a contract, for example "add tests for src/Vault.sol".
`dapp-architecture` starts when you ask how a dApp should be put together, for example "plan the architecture of this marketplace: who pays the gas, how it reads chain data, and who holds the admin keys".
`financial-standards` starts when you ask for a design built on a financial standard, for example "design how this project maps ISO 20022 payment messages onto a settlement contract".
You can also call them: run `/evm-dev:evm-standards`, `/evm-dev:solidity-code`, `/evm-dev:contract-tests`, `/evm-dev:dapp-architecture`, or `/evm-dev:financial-standards` in Claude Code, or type `$` and pick **EVM Standards**, **Solidity Code**, **Contract Tests**, **dApp Architecture**, or **Financial Standards** in Codex.
In GitHub Copilot CLI, write `/evm-standards`, `/solidity-code`, `/contract-tests`, `/dapp-architecture`, or `/financial-standards` in your request, and in Gemini CLI, describe the task.

### Check a standard

1. The agent lists the items with the date each was checked, and marks the ones that are out of date
2. The agent reads the items your question needs
3. For an out-of-date item, the agent re-checks the official ERC or EIP document, or says it could not
4. The agent answers with the status, the date it was checked, and the source

The list looks like this.

```text
ok     specified  2026-11-10 eip-7692-eof
ok     live       2026-11-09 eip-7702-set-code-for-eoas
ok     live       2026-11-11 eip-7951-secp256r1-precompile
ok     announced  2026-11-10 erc-7281-xerc20
41 items, 0 stale as of 2026-11-16
```

An answer looks like this.

```text
Yes. EIP-7951 adds a P256VERIFY precompile at 0x100 that costs 6900 gas.
It went live on mainnet with the Fusaka upgrade on 2025-12-03.
Status: live, checked 2026-11-11, source: the EIP-7951 document and EIP-7607 (the Fusaka meta EIP).
```

### Write a contract

1. The agent reads which framework and which versions the project uses, and follows the project's own conventions
2. The agent reads the items for those versions, and re-checks the ones that are out of date
3. The agent writes the contract with the project's library, OpenZeppelin or another it already uses
4. The agent scans what it wrote for patterns the project's versions changed, then builds and runs the tests, and says so when it cannot

The project's versions look like this.

```text
framework     foundry
solc          0.8.34
openzeppelin  5.7.0
forge-std     1.17.0
foundry       1.9.0
hardhat       none
pragma        ^0.8.24
```

A scan names the file, the line, and the item, never the line's text.

```text
src/UserOpInspector.sol:4 openzeppelin-5.7-erc4337-drops-draft
src/Pass.sol:16 ethereum-eip-7702-eoa-checks
scan: 2 matches; 0 items not judged
```

### Test a contract

1. The agent reads the project's versions and the items on its test tools, and re-checks the ones that are out of date
2. The agent lists what each contract needs a test for: its external and public functions, custom errors, events, access rules, functions that take numbers, and balances that must add up
3. When the kiwa plugin's skills are installed, the agent gives that list to kiwa and has kiwa write the tests. Otherwise it writes unit, fuzz, and invariant tests with forge, or with the Hardhat runner the project uses
4. The agent names each point that no test touches, adds tests for them, then runs the tests and says so when it cannot. When a test shows a bug, it reports the bug instead of changing the contract

The list looks like this.

```text
invariant Vault src/Vault.sol:6
error Vault.ZeroAmount src/Vault.sol:7
error Vault.InsufficientBalance src/Vault.sol:8
error Vault.NotOwner src/Vault.sol:9
error Vault.Paused src/Vault.sol:10
event Vault.Deposited src/Vault.sol:12
event Vault.Withdrawn src/Vault.sol:13
event Vault.PausedSet src/Vault.sol:14
function Vault.deposit src/Vault.sol:30
function Vault.withdraw src/Vault.sol:37
fuzz Vault.withdraw src/Vault.sol:37
function Vault.setPaused src/Vault.sol:48
access Vault.setPaused src/Vault.sol:48
points: 13 in 1 contract
```

The check names the point, never the text of a test.

```text
uncovered invariant Vault src/Vault.sol:6
uncovered access Vault.setPaused src/Vault.sol:48
uncovered: 2 of 13 points have no test
```

### Plan a dApp's architecture

1. The agent lists the items on indexers, relayers, automation, monitoring, testnets, multisigs, and storage, and re-checks the ones that are out of date
2. The agent asks the decisions one at a time, each with a recommended choice: the users and chains, who sends each transaction and pays the gas, how the app reads chain data, what is stored where, who holds the admin roles, and which services the team runs itself. When it cannot ask, it takes the recommended choice and records it as an assumption
3. The agent copies the template into your project, `docs/design/<topic>.md` by default, and fills in its nine sections: purpose and users, components, transactions and gas, reading chain data, data placement, environments, keys and admin, monitoring and operations, and open decisions
4. The agent checks the sections and reviews the design against the checklist, then tells you the rules it could not judge and the open decisions

The items look like this.

```text
ok     automation   2026-11-17 chainlink-automation Chainlink Automation and Chainlink CRE
ok     networks     2026-11-17 ethereum-testnets Ethereum testnets (Sepolia, Hoodi, Holesky)
ok     storage      2026-11-17 ipfs-gateways-and-pinning IPFS public gateways and pinning services
ok     transactions 2026-11-17 openzeppelin-defender-relayer OpenZeppelin Defender and OpenZeppelin Relayer
ok     indexing     2026-11-17 the-graph-network The Graph Network and Subgraph Studio
9 items, 0 stale as of 2026-11-17
```

The check names sections, never the text of the design.

```text
no checked date: Components
missing: Keys and admin
dapp-architecture: 2 problems; fill in or add each section named above
```

### Design on a financial standard

1. The agent lists the items on the standards' versions, and re-checks the ones that are out of date
2. The agent asks the decisions one at a time, each with a recommended choice: the standard and its profile, the business flow, the chain, what goes on chain and who signs it, where legal finality sits, and whether assets are tokenized. When it cannot ask, it takes the recommended choice and records it as an assumption
3. The agent copies the template into your project, `docs/design/<topic>.md` by default, and fills in its nine sections: standard and business, application, data and storage, on-chain, off-chain, integration, security and operations, verification and delivery, and open decisions
4. The agent checks the sections and reviews the design against the checklist, then tells you the rules it could not judge and the open decisions

The items look like this.

```text
ok     cdm        7.10.0 2026-11-16 cdm-release
ok     fix        FIX Latest EP312 2026-11-16 fix-latest
ok     fpml       5.14 2026-11-16 fpml-recommendation
ok     iso-20022  CBPR+ SR2025 2026-11-16 iso-20022-cbpr-plus-release
ok     lei        ISO 17442-1:2020 2026-11-16 lei-iso-17442
ok     xbrl       XBRL 2.1, Inline XBRL 1.1, OIM 1.0 2026-11-16 xbrl-specifications
6 items, 0 stale as of 2026-11-16
```

The check names sections, never the text of the design.

```text
no checked date: Standard and business
missing: Integration
financial-standards: 2 problems; fill in or add each section named above
```

## What it covers

| Covered | Not covered |
|---|---|
| ERCs, such as ERC-20, ERC-1271, ERC-4337, ERC-6551, ERC-7683 | The state of L2 networks, which dedicated trackers follow |
| EIPs that change what contracts and wallets can do: opcodes, precompiles, gas costs, transaction types, EIP-7702, native account abstraction | EIPs that change only consensus, such as validator rules |
| How an EIP gets into a network upgrade (EIP-7723) | Choosing how a contract is upgraded, which a later contract design skill covers |
| Writing Solidity for the versions of solc, OpenZeppelin, forge-std, Foundry, and Hardhat a project uses | Deploying, and comparing storage layouts or ABIs before a release |
| Writing unit, fuzz, and invariant tests for a project's contracts in Foundry or Hardhat, or having kiwa write them | Mutation testing, coverage targets, and tests of a dApp's screens, which kiwa covers |
| Planning a dApp's parts, who sends and pays for each transaction, indexing, data placement, environments, admin keys, and monitoring, with the state of the services it names | Choosing and signing up for a provider, creating keys, and writing the contracts, frontend, or deployment scripts |
| Designing apps on ISO 20022, FIX, FpML, CDM, LEI, and XBRL, with original messages and personal data off chain and signed evidence on it | Writing the contracts, schemas, or API definitions of the design, ledgers other than EVM chains, and legal or regulatory advice |

## Requirements

| Tool | When it's needed |
|---|---|
| `bash` | Always |
| `python3` | For `solidity-code`, `contract-tests`, `dapp-architecture`, and `financial-standards` |
| Foundry (`forge`) or Hardhat | To build and test what `solidity-code` and `contract-tests` write. Without them the agent says the code was not built |
| The kiwa plugin | Optional. When its skills are installed, `contract-tests` has kiwa write the tests |
| Web access in the agent | To re-check an out-of-date item. Without it the agent answers from the item and says it could not confirm it |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) explains the items, the statuses, the scan, and when an item counts as out of date.
In short:

- It reads the items bundled with the plugin
- `evm-standards` runs `evm-standards.sh list`, which reads the items and prints one line each
- `solidity-code` runs `solidity-code.py`, which reads the project's config files and the `package.json` files of its libraries for their versions, and the project's source files for the scan. It never reads `.env` files, dependencies, or build output, and never prints the text of a line
- `solidity-code` writes only the contracts you ask for, and runs the project's build and tests
- `contract-tests` runs `contract-tests.py`, which reads the project's config files, contracts, and tests, and prints only kinds, names, and `file:line`, never the text of a contract or a test. It writes only test files, never changes a contract, and never reads `.env` files, dependencies, or build output
- `dapp-architecture` runs `dapp-architecture.py`, which reads its items and the design file it writes, and prints only section names when it checks the design. It writes only the design file, and never reads `.env` files or keys
- `financial-standards` runs `financial-standards.py`, which reads its items and the design file it writes, and prints only section names when it checks the design. It writes only the design file, and never reads `.env` files or keys
- To re-check an out-of-date item, the agent searches the web and opens the official document with only a standard's number or name, or a tool's or service's name and version
- It never edits its items and keeps nothing

## License

[MIT](LICENSE)
