# EVM Dev

Know whether an ERC is final or an EIP is live on Ethereum mainnet and how L2 networks and the Ethereum L1 roadmap stand, design contracts, wallets, and apps across chains, write Solidity and its tests for the versions your project uses, deploy contracts while the key stays with you, check a release against the deployed version and the target chains, plan a dApp's architecture, and design apps built on financial standards such as ISO 20022 and FIX, from items checked against the official documents instead of what the agent remembers.

English · [日本語](README.ja.md)

An agent's knowledge stops at its training cutoff, while standards and tools keep moving: an EIP ships in a network upgrade, an L2 replaces the system that proves its state, a widely cited "ERC" turns out never to have been merged, a library renames the files you import, a framework deprecates the call your script makes, a hosted relayer or automation service shuts down, a payments standard release is deferred.
This plugin ships dated items on all of them, each with the date it was checked against the official document and the document it came from.
`contract-deploy` signs deploys to production chains only with a Ledger or Trezor hardware wallet, and deploys to test chains with an encrypted keystore.

| Skill | What it does |
|---|---|
| `evm-standards` | Answers whether an ERC is final or an EIP is live, and what it lets contracts and wallets do, from 41 items on ERCs and EIPs. It also finds standards by what they do, and links the article on each standard it names from an article index you name |
| `ethereum-knowledge` | Answers how L2 networks and rollup frameworks work and stand, what is planned for Ethereum L1, and whether EIPs that change only consensus are live, from 51 items. It leaves ERCs and the EIPs that change what contracts and wallets can do to `evm-standards` |
| `solidity-code` | Writes and changes contracts in Foundry and Hardhat projects for the solc, OpenZeppelin, forge-std, Foundry, and Hardhat versions the project uses, then scans the code for outdated patterns and builds and tests it |
| `contract-tests` | Writes unit, fuzz, and invariant tests for a project's contracts in Foundry or Hardhat, or has kiwa write them when it is installed, from a list of what each contract needs tested, then names what no test covers and runs the tests |
| `contract-deploy` | Writes Foundry and Hardhat Ignition deploy scripts that never touch keys, names every place a project handles a key unsafely, hands you the command to sign with a hardware wallet on production chains and an encrypted keystore on test chains, then records each chain's deployed addresses and checks them |
| `release-check` | Checks contracts before a release: compares the storage layout and ABI with the deployed version, names each opcode a target chain's EVM cannot run, runs OpenZeppelin's upgrade check when the project has it, and compares gas and contract sizes |
| `contract-design` | Designs contracts before they are written: asks the decisions one at a time and writes one design document on how contracts are split, token standards, invariants, roles, upgrades, prices, transaction ordering, randomness, and external calls, then checks its sections and reviews it against a checklist |
| `wallet-design` | Designs wallets and signing: asks the decisions one at a time and writes one design document on how keys are held and recovered, ERC-4337 and EIP-7702 accounts, signed permissions, approvals, who pays gas, and payments by AI agents, then checks its sections and reviews it against a checklist |
| `multichain-design` | Designs apps that run on more than one chain: asks the decisions one at a time and writes one design document on same-address deployment, moving assets between chains, verifying cross-chain messages, and what happens when only one side completes, then checks its sections and reviews it against a checklist |
| `dapp-architecture` | Plans how a dApp's parts fit together: asks the decisions one at a time and writes one design document on who sends and pays for each transaction, how the app reads chain data, where data lives, the environments, the admin keys, and monitoring, then checks its sections and reviews it against a checklist |
| `financial-standards` | Designs an app with on-chain and off-chain parts built on ISO 20022, FIX, FpML, CDM, LEI, or XBRL: asks the decisions one at a time, writes one design document from a template, checks its sections, and reviews it against a checklist |

```
evm-standards:  List the items ──> Read the ones asked about ──> Re-check stale ones ──> Answer with date and source
ethereum-knowledge:  List the items ──> Read the ones asked about ──> Re-check stale ones ──> Answer with date and source
solidity-code:  Read the project's versions ──> Read the items for them ──> Write ──> Scan, build, and test
contract-tests:  Read the versions and items ──> List what needs a test ──> Write the tests, or have kiwa write them ──> Name what no test covers ──> Run the tests
contract-deploy:  Read the versions and items ──> Write the deploy script ──> Check the key handling ──> Simulate, then the user broadcasts ──> Record and verify
release-check:  Read the versions and items ──> Build the deployed version ──> Compare layouts and ABIs ──> Find opcodes the chains lack ──> Report and clean up
contract-design:  Read the items ──> Ask the decisions ──> Write the design ──> Verify the sections ──> Review against the checklist
wallet-design:  Read the items ──> Ask the decisions ──> Write the design ──> Verify the sections ──> Review against the checklist
multichain-design:  Read the items ──> Ask the decisions ──> Write the design ──> Verify the sections ──> Review against the checklist
dapp-architecture:  Read the items ──> Ask the decisions ──> Write the design ──> Verify the sections ──> Review against the checklist
financial-standards:  Read the items ──> Ask the decisions ──> Write the design ──> Verify the sections ──> Review against the checklist
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install evm-dev@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add evm-dev@agent-shuriken
codex plugin add doc-formats@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install evm-dev@agent-shuriken
copilot plugin install doc-formats@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/evm-standards   # Gemini CLI
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/ethereum-knowledge
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/solidity-code
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/contract-tests
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/contract-deploy
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/release-check
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/contract-design
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/wallet-design
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/multichain-design
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/dapp-architecture
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/financial-standards
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/doc-formats/skills/design-doc
```

The five design skills write in the design format of the `design-doc` skill in the [doc-formats](../doc-formats) plugin.
Claude Code installs doc-formats with evm-dev; in Codex, GitHub Copilot CLI, and Gemini CLI, install it with the lines above that name it.
In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

`evm-standards` starts when you ask about the status of a standard, for example "is EIP-7702 live on mainnet?" or "can I cite ERC-7281 as final?", or which standard does a job, for example "which standard lets a contract verify a passkey signature?".
`ethereum-knowledge` starts when you ask how an L2 or the Ethereum L1 roadmap stands, or whether an EIP that changes only consensus is live, for example "is PeerDAS live on mainnet?" or "how does the OP Stack prove withdrawals now?".
`solidity-code` starts when you ask for a contract to be written or changed, for example "add a pausable ERC-20 token to this Foundry project".
`contract-tests` starts when you ask for tests of a contract, for example "add tests for src/Vault.sol".
`contract-deploy` starts when you ask for contracts to be deployed or a deployment to be recorded, for example "deploy src/Vault.sol to Sepolia and then Base" or "write down what my last forge script deployed".
`release-check` starts when you ask whether contracts are ready to release or an upgrade is safe, for example "is upgrading the Vault to the code in src/ safe?" or "will this build run on a chain that is still on Shanghai?".
`contract-design` starts when you ask for contracts to be designed before they are written, for example "design the contracts of this token sale: the roles, the upgrades, and how prices are read".
`wallet-design` starts when you ask for the wallets or the signing of an app to be designed, for example "should our users get ERC-4337 smart accounts or EIP-7702, and who pays their gas?".
`multichain-design` starts when you ask for an app on more than one chain to be designed, for example "plan how our token moves between Ethereum and Base".
`dapp-architecture` starts when you ask how a dApp should be put together, for example "plan the architecture of this marketplace: who pays the gas, how it reads chain data, and who holds the admin keys".
`financial-standards` starts when you ask for a design built on a financial standard, for example "design how this project maps ISO 20022 payment messages onto a settlement contract".
You can also call them: run `/evm-dev:evm-standards`, `/evm-dev:ethereum-knowledge`, `/evm-dev:solidity-code`, `/evm-dev:contract-tests`, `/evm-dev:contract-deploy`, `/evm-dev:release-check`, `/evm-dev:contract-design`, `/evm-dev:wallet-design`, `/evm-dev:multichain-design`, `/evm-dev:dapp-architecture`, or `/evm-dev:financial-standards` in Claude Code, or type `$` and pick **EVM Standards**, **Ethereum Knowledge**, **Solidity Code**, **Contract Tests**, **Contract Deploy**, **Release Check**, **Contract Design**, **Wallet Design**, **Multichain Design**, **dApp Architecture**, or **Financial Standards** in Codex.
In GitHub Copilot CLI, write `/evm-standards`, `/ethereum-knowledge`, `/solidity-code`, `/contract-tests`, `/contract-deploy`, `/release-check`, `/contract-design`, `/wallet-design`, `/multichain-design`, `/dapp-architecture`, or `/financial-standards` in your request, and in Gemini CLI, describe the task.

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

### Find a standard by what it does

1. The agent searches the items, and the articles of the index you named, with words for what you want, in English and in your language
2. The agent answers with the standards that match, with the status of each from the items or the official document
3. When you named an article index, for each standard it names, the agent gives the title and link of the article on it, when there is one

The search looks like this.
With no article index named, it prints no article line.

```text
item eip-7951-secp256r1-precompile live 2026-11-11 3 Contracts can cheaply verify P-256 (secp256r1) signatures, such as passkey, WebAuthn, Secure Enclave, and Android Keystore signatures, with P256VERIFY at 0x100.
items: 1 matched
articles: no article index is named
```

To have it link articles, put the URL or the path of an index in `~/.evm-dev/article-index`, or in `EVM_DEV_INDEX_URL`, which wins when both are set.
The index has the line form of an llms.txt list, one article per line, and each title starts with `[ERC<number>]` or `[EIP<number>]`.

```text
- [\[EIP7951\] Verifying passkey signatures](https://example.com/articles/eip-7951.md): How contracts check P-256 signatures.
```

### Check an L2 or the L1 roadmap

1. The agent lists the items with the date each was checked, and marks the ones that are out of date
2. The agent reads the items your question needs
3. For an out-of-date item, the agent re-checks the official documents of the network, framework, or EIP, or says it could not
4. The agent answers with the status, the date it was checked, and the source

A question on an ERC, or on an EIP that changes what contracts and wallets can do, goes to `evm-standards`.
The list looks like this.

```text
ok     live       2026-11-11 eip-7594-peerdas
ok     specified  2026-11-16 eip-7805-focil
ok     live       2026-11-11 l2beat-stages
ok     live       2026-11-16 op-stack-fault-proofs
51 items, 0 stale as of 2026-11-22
```

An answer looks like this.

```text
Yes. PeerDAS (EIP-7594) has each node receive only part of the blob data and sample columns from other nodes to check that the whole was published.
It went live on mainnet with the Fusaka upgrade on 2025-12-03.
Status: live, checked 2026-11-11, source: the EIP-7594 document and EIP-7607 (the Fusaka meta EIP).
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

### Deploy a contract

1. The agent reads the project's versions and the items on keystores, hardware wallets, deployment files, and verification, and re-checks the ones that are out of date
2. The agent writes a Foundry script that leaves the signer to the command line, or a Hardhat Ignition module that keeps each key behind `configVariable`
3. The agent names every place the project handles a key unsafely: a key read from an environment variable, a command that passes `--private-key`, `--mnemonic`, or `--password`, a key written into a file, such as a JSON settings file a deploy script reads, and a `.env` file that git tracks or does not ignore
4. The agent simulates the deployment and hands you the command for each chain: a hardware wallet and `--slow` on a production chain, an encrypted keystore on a test chain. You run it and approve the signature; the agent never sees the key
5. The agent records each chain's contracts in `deployments/<chain id>.json`, names each transaction that failed, has no receipt, or does not show the contract it should have created, says when files changed before the broadcast differ from the commit the record names, checks that each address has code, and verifies the source once you agree

The key check names the kind, the file, and the line, never the line itself.

```text
env-key Makefile:4
key-flag Makefile:4
keys: 2 findings in 6 files read; change each one to an encrypted keystore or a hardware wallet
```

The record lists what went on chain and each transaction to look at.

```text
contract 11155111 Vault 0x234b5a9f35e11c182d81e4e30682b5febcdcc060 tx 0xf12dfc147716ec611d7e1fcc9b6946dfa39421b2af650bba90390d065ee98891 block 7100001 from 0x7e5f4552091a69125d5dfcb7b8c2659029395bdf source foundry:DeployVault.s.sol
contract 8453 Vault 0x1534aac5b2be5f3ce3502106a257c8bc7c1ac23d tx 0xc7eee6b4d5440a8a2d8e6ae851040e23774b242ef147706c0d3b0a83cdb6a747 block 38200001 from 0x7e5f4552091a69125d5dfcb7b8c2659029395bdf source foundry:DeployVault.s.sol
failed 11155111 FeeRouter tx 0xd38e9b9179d8361ea428c5f90b987a1c93fa41744591b611441104ef40fd91b8 source foundry:DeployVault.s.sol
pending 8453 Oracle tx 0xc716db5108b741d36dc98b163ef3864bab9ae80e0e6b33f4141ce4c7378dbbbe source foundry:DeployVault.s.sol
wrote deployments/8453.json
wrote deployments/11155111.json
record: 2 contracts on 2 chains, 2 transactions to look at
```

### Check a release

1. The agent reads the project's versions and the items on each chain's EVM version, the per-transaction gas cap, storage layouts, and the tools, and re-checks the ones that are out of date
2. For an upgrade, the agent checks out the deployed git tag or commit in a temporary worktree and builds it and the new version from the same source folder, with the storage layout and the syntax tree (`--ast`) in the build output
3. The agent compares the two storage layouts and names each variable that was removed, moved, or retyped, also inside structs and inside ERC-7201 namespaced structs, each `__gap` that no longer ends where it did, and each namespace whose slot changed; a contract whose namespaced storage it could not compare is named, never passed. It compares the ABIs and names each function, event, and error that was removed or changed
4. The agent names each opcode the target chain's EVM version lacks, in the runtime code and in the constructor, and says whether a compiler setting fixes it or the code must change
5. When the project has OpenZeppelin's upgrade check, the agent runs it as well and reports both. It compares gas with `forge snapshot --diff` and sizes with `forge build --sizes`, simulates the upgrade on the chain the proxy lives on, or on a local `anvil` after deploying the deployed version there, checks each transaction against the chain's gas cap, and removes the temporary worktree

The layout comparison names each variable that would read the wrong value after the upgrade.

```text
retyped Vault positions mapping(address => struct Position) changed inside
gap Vault __gap ends at slot 51 instead of 50
moved Vault version 50:0 -> 51:0
moved Vault initialized 51:0 -> 52:0
layout: 4 problems in 1 contract compared (0 renamed)
```

The opcode check names what a chain on an older EVM version would reject.

```text
opcode Vault runtime MCOPY needs cancun
opcode Vault runtime TLOAD needs cancun
opcode Vault runtime TSTORE needs cancun
opcodes: 3 opcodes the shanghai EVM lacks in 1 contract
```

### Design contracts

1. The agent lists the items on proxies, access control, price feeds, randomness, private relays, and token handling, and re-checks the ones that are out of date
2. The agent asks the decisions one at a time, each with a recommended choice: what the contracts must do and the limits that must hold, the tokens and their standards, who holds each role, whether the contracts are upgradeable, and where prices and randomness come from. When it cannot ask, it takes the recommended choice and records it as an assumption
3. The agent writes the design in the design format of `design-doc` into your project, `docs/design/<topic>.md` by default, and fills in its nine sections: purpose and scope, contracts, token standards, state and invariants, roles and governance, upgrades, prices, ordering, and randomness, external calls and failures, and open decisions
4. The agent checks the sections and reviews the design against the checklist, then tells you the rules it could not judge and the open decisions

The items look like this.

```text
ok     oracles      2026-11-17 chainlink-data-feeds Chainlink Data Feeds
ok     randomness   2026-11-17 chainlink-vrf Chainlink VRF
ok     ordering     2026-11-17 flashbots-protect Flashbots Protect and private transaction relays
ok     upgrades     2026-11-17 openzeppelin-5-proxies OpenZeppelin Contracts 5.x proxies and upgradeable contracts
6 items, 0 stale as of 2026-11-17
```

The check names sections, never the text of the design.

```text
no checked date: Contracts
missing: Upgrades
contract-design: 2 problems; fill in or add each section named above
```

### Design wallets and signing

1. The agent lists the items on EntryPoint versions, EIP-7702 delegation, wallet permissions, Permit2, paymaster services, and x402, and re-checks the ones that are out of date
2. The agent asks the decisions one at a time, each with a recommended choice: who uses the wallets and the limits that must hold, which kind of account each user or agent holds, who holds each key and how a lost key is recovered, what users sign and approve, and who pays gas and how AI agents pay. When it cannot ask, it takes the recommended choice and records it as an assumption
3. The agent writes the design in the design format of `design-doc` into your project, `docs/design/<topic>.md` by default, and fills in its nine sections: purpose and users, accounts, keys and recovery, signatures and permissions, approvals, gas and sponsorship, agent payments, chains and environments, and open decisions
4. The agent checks the sections and reviews the design against the checklist, then tells you the rules it could not judge and the open decisions

The items look like this.

```text
ok     accounts     2026-11-17 eip-7702-delegation EIP-7702 delegation and its initialization
ok     accounts     2026-11-17 entrypoint-versions ERC-4337 EntryPoint v0.8 and v0.9
ok     gas          2026-11-17 erc-7677-paymaster-service EIP-5792 wallet_sendCalls and the ERC-7677 paymaster service
ok     signatures   2026-11-17 erc-7715-advanced-permissions MetaMask Advanced Permissions (ERC-7715) and the Smart Accounts Kit
6 items, 0 stale as of 2026-11-17
```

The check names sections, never the text of the design.

```text
no checked date: Accounts
missing: Approvals
wallet-design: 2 problems; fill in or add each section named above
```

### Design apps across chains

1. The agent lists the items on CREATE2 factories, Circle's CCTP, LayerZero's verifier configuration, Chainlink's Cross-Chain Token standard, and Superchain interop, and re-checks the ones that are out of date
2. The agent asks the decisions one at a time, each with a recommended choice: which chains and what moves between them, which contracts need the same address, which chain issues each asset, which protocol carries messages and who verifies them, and what happens when only one side completes. When it cannot ask, it takes the recommended choice and records it as an assumption
3. The agent writes the design in the design format of `design-doc` into your project, `docs/design/<topic>.md` by default, and fills in its nine sections: purpose and chains, deployment and addresses, assets across chains, messages and verification, partial failures, roles and limits, fees and gas, monitoring and environments, and open decisions
4. The agent checks the sections and reviews the design against the checklist, then tells you the rules it could not judge and the open decisions

The items look like this.

```text
ok     tokens       2026-11-17 chainlink-ccip-cct Chainlink CCIP Cross-Chain Token (CCT) standard and token pool rate limits
ok     bridges      2026-11-17 circle-cctp-v2 Circle CCTP V1 (Legacy) and V2
ok     deployment   2026-11-17 create2-factories CREATE2 factories for the same address on every chain (ERC-7955, Safe Singleton Factory, CreateX)
ok     messaging    2026-11-17 layerzero-dvn-config LayerZero V2 verifier (DVN) configuration
5 items, 0 stale as of 2026-11-17
```

The check names sections, never the text of the design.

```text
no checked date: Messages and verification
missing: Partial failures
multichain-design: 2 problems; fill in or add each section named above
```

### Plan a dApp's architecture

1. The agent lists the items on indexers, relayers, automation, monitoring, testnets, multisigs, and storage, and re-checks the ones that are out of date
2. The agent asks the decisions one at a time, each with a recommended choice: the users and chains, who sends each transaction and pays the gas, how the app reads chain data, what is stored where, who holds the admin roles, and which services the team runs itself. When it cannot ask, it takes the recommended choice and records it as an assumption
3. The agent writes the design in the design format of `design-doc` into your project, `docs/design/<topic>.md` by default, and fills in its nine sections: purpose and users, components, transactions and gas, reading chain data, data placement, environments, keys and admin, monitoring and operations, and open decisions
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
3. The agent writes the design in the design format of `design-doc` into your project, `docs/design/<topic>.md` by default, and fills in its nine sections: standard and business, application, data and storage, on-chain, off-chain, integration, security and operations, verification and delivery, and open decisions
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
| ERCs, such as ERC-20, ERC-1271, ERC-4337, ERC-6551, ERC-7683 | Live figures of a network, such as fees and the value locked in it, which dedicated trackers follow |
| EIPs that change what contracts and wallets can do: opcodes, precompiles, gas costs, transaction types, EIP-7702, native account abstraction | Running a validator or a node |
| How L2 networks and rollup frameworks work and stand, what is planned for Ethereum L1, and EIPs that change only consensus, such as PeerDAS and FOCIL | ERCs and the EIPs that change what contracts and wallets can do, which `evm-standards` covers |
| How an EIP gets into a network upgrade (EIP-7723) | Choosing how a contract is upgraded, which `contract-design` covers |
| Writing Solidity for the versions of solc, OpenZeppelin, forge-std, Foundry, and Hardhat a project uses | Checking a release, which `release-check` covers |
| Writing unit, fuzz, and invariant tests for a project's contracts in Foundry or Hardhat, or having kiwa write them | Mutation testing, coverage targets, and tests of a dApp's screens, which kiwa covers |
| Writing deploy scripts for Foundry and Hardhat Ignition, checking how a project handles keys, and recording and verifying what was deployed | Signing or broadcasting, holding keys, and proposing transactions to a multisig such as Safe |
| Comparing storage layouts and ABIs with the deployed version, finding opcodes a target chain lacks, and comparing gas and sizes before a release | Reading the code deployed on chain, and comparing ERC-7201 namespaced storage in a Hardhat build or a Foundry build made without `--ast`, which OpenZeppelin's check or reading both versions covers |
| Designing contracts before they are written: the split, token standards, invariants, roles, upgrades, prices, ordering, randomness, and external calls | Writing the contracts, their tests, or deployment scripts, which `solidity-code`, `contract-tests`, and `contract-deploy` cover |
| Designing wallets and signing: keys and recovery, ERC-4337 and EIP-7702 accounts, signed permissions, approvals, gas sponsorship, and AI agent payments | Writing wallet code, holding keys, or signing, which no skill does |
| Designing apps across chains: same-address deployment, moving assets, verifying messages, and partial failures | Writing bridge contracts, which `solidity-code` covers, or deployment scripts, which `contract-deploy` covers |
| Planning a dApp's parts, who sends and pays for each transaction, indexing, data placement, environments, admin keys, and monitoring, with the state of the services it names | Choosing and signing up for a provider, creating keys, and writing the contracts, frontend, or deployment scripts |
| Designing apps on ISO 20022, FIX, FpML, CDM, LEI, and XBRL, with original messages and personal data off chain and signed evidence on it | Writing the contracts, schemas, or API definitions of the design, ledgers other than EVM chains, and legal or regulatory advice |

## Requirements

| Tool | When it's needed |
|---|---|
| `bash` | Always |
| `python3` | For `solidity-code`, `contract-tests`, `contract-deploy`, `release-check`, `contract-design`, `wallet-design`, `multichain-design`, `dapp-architecture`, and `financial-standards` |
| Foundry (`forge`) or Hardhat | To build and test what `solidity-code` and `contract-tests` write, to simulate, look up, and verify what `contract-deploy` deploys, and to build both versions for `release-check`. Without them the agent says the code was not built |
| `git` | Optional. `contract-deploy` asks it whether each `.env` file is tracked or ignored, and `release-check` checks out the deployed version with it. Without it the first check is skipped, and `release-check` needs the deployed version's layout and ABI from you |
| Node.js and `@openzeppelin/upgrades-core` in the project | Optional. When both are there, `release-check` also runs OpenZeppelin's upgrade check |
| The kiwa plugin | Optional. When its skills are installed, `contract-tests` has kiwa write the tests |
| Web access in the agent | To re-check an out-of-date item. Without it the agent answers from the item and says it could not confirm it |
| A Ledger or Trezor hardware wallet | To sign deploys to production chains with `contract-deploy`. Test chains use an encrypted keystore |
| Network access to the host of your article index | Only when `~/.evm-dev/article-index` or `EVM_DEV_INDEX_URL` names a URL. Without it `evm-standards` searches only its items and says it could not read the article index |
| The `musubi` command | Optional. When it is installed, the agent runs `musubi check` before a design skill reads the `design-doc` format and before `release-check` reads the page-design format |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) explains the items, the statuses, the scan, and when an item counts as out of date.
In short:

- It reads the items bundled with the plugin
- `evm-standards` runs `evm-standards.sh list`, which reads the items and prints one line each
- `ethereum-knowledge` runs `ethereum-knowledge.sh list`, which reads its own items and prints one line each
- `evm-standards` runs `standards.py` for `find` and `article`. It reads the items, and the article index you name in `~/.evm-dev/article-index` or `EVM_DEV_INDEX_URL`, if any. An index named by a URL is downloaded with a plain request to that address, so no word of your question is sent, and kept in `~/.local/share/evm-dev/` (`EVM_DEV_HOME` changes it), readable only by you, for one day, one copy per URL. An index named by a path is read in place. It prints only article titles, descriptions, and https links, and for an index from a URL only links on that URL's host
- `solidity-code` runs `solidity-code.py`, which reads the project's config files and the `package.json` files of its libraries for their versions, and the project's source files for the scan. It never reads `.env` files, dependencies, or build output, and never prints the text of a line
- `solidity-code` writes only the contracts you ask for, and runs the project's build and tests
- `contract-tests` runs `contract-tests.py`, which reads the project's config files, contracts, and tests, and prints only kinds, names, and `file:line`, never the text of a contract or a test. It writes only test files, never changes a contract, and never reads `.env` files, dependencies, or build output
- `contract-deploy` runs `contract-deploy.py`, which reads the project's deploy scripts and settings for unsafe key handling, asks `git` whether each `.env` file is tracked or ignored without opening it, and reads `broadcast/` and `ignition/deployments/` to build the record. It prints only kinds and `file:line`, never a key or the text of a line, and writes only `deployments/<chain id>.json`. It never reads `.env` files or Foundry's `cache/`, never signs, and refuses a command that passes a key
- `contract-deploy` writes the deploy script, simulates it, and looks up transactions and code through the project's RPC endpoints. You run the command that broadcasts. Verification sends the contracts' source code to Sourcify, Etherscan, or Blockscout to publish it, so the agent asks before it runs
- `release-check` runs `release-check.py`, which reads only the storage layouts, ABIs, and bytecode in the build output and JSON files it is given, and prints one line per finding. It writes nothing, and never reads `.env` files or keys
- `release-check` checks out the deployed version in a temporary git worktree, builds both versions and runs the tests with the project's tools, and removes the worktree when it is done. OpenZeppelin's check, when the project has it, may download a matching solc from the Solidity binaries server to check namespaced storage
- `skills/release-check/musubi.json` declares through musubi that release-check follows `page-design/structure`, the order of a report, as an optional follow with `"optional": true`. The agent reads the format only when page-design is installed, and reports in its own order otherwise. `release-check` reads nothing else from other plugins
- `contract-design` runs `contract-design.py`, which reads its items and the design file it writes, and prints only section names when it checks the design. It writes only the design file, and never reads `.env` files or keys
- `wallet-design` runs `wallet-design.py`, which reads its items and the design file it writes, and prints only section names when it checks the design. It writes only the design file, never reads `.env` files or keys, never signs, and refuses a command that passes a key
- `multichain-design` runs `multichain-design.py`, which reads its items and the design file it writes, and prints only section names when it checks the design. It writes only the design file, never reads `.env` files or keys, never signs, and refuses a command that passes a key
- `dapp-architecture` runs `dapp-architecture.py`, which reads its items and the design file it writes, and prints only section names when it checks the design. It writes only the design file, and never reads `.env` files or keys
- `financial-standards` runs `financial-standards.py`, which reads its items and the design file it writes, and prints only section names when it checks the design. It writes only the design file, and never reads `.env` files or keys
- To re-check an out-of-date item, the agent searches the web and opens the official document with only a standard's number or name, a network's or framework's name, or a tool's or service's name and version
- It never edits its items, and keeps nothing but the copies of an article index named by a URL

## License

[MIT](LICENSE)
