# How EVM Dev works

English · [日本語](how-it-works.ja.md)

The plugin has ten skills. `evm-standards` answers questions about ERCs and EIPs from items bundled with it, `solidity-code` writes Solidity for the versions a project uses from items about its tools, `contract-tests` writes tests for a project's contracts from items about its test tools, `contract-deploy` writes deploy scripts, checks how a project handles keys, and records what was deployed, from items about keystores, hardware wallets, deployment files, and verification, `release-check` checks contracts before a release against the deployed version and the target chains, from items about EVM versions, the transaction gas cap, storage layouts, and the tools, `contract-design` writes a design for a set of contracts from items about the libraries and services they rely on, `wallet-design` writes a design for an app's wallets and signing from items about accounts, permissions, approvals, gas sponsorship, and payments, `multichain-design` writes a design for an app on more than one chain from items about deployment tools, bridges, message protocols, and token standards, `dapp-architecture` writes a design for how a dApp's parts fit together from items about the services it may use, and `financial-standards` writes a design for an app built on financial standards from items about their versions.
This page describes the skills' items, when an item counts as out of date, the scripts, and what the agent may do with them.

## The ERC and EIP items

Each item is one Markdown file in `skills/evm-standards/references/items/`, named after its standard, such as `eip-7702-set-code-for-eoas.md` or `erc-4337-account-abstraction.md`.
Its front matter holds four fields.

| Field | What it holds |
|---|---|
| `status` | One of `announced`, `specified`, `live`, `stopped` |
| `checked` | The date the status was confirmed against the official document, as `YYYY-MM-DD` |
| `source` | The organization and the documents the item comes from, by name. Items hold no URLs |
| `can` | One sentence on what the standard lets contracts, wallets, or dApps do, which `find` searches |

The body says what the standard is, what it lets contracts, wallets, or dApps do, its current status, and what has not shipped yet.
Items cover ERCs and the EIPs that change what contracts and wallets can do; EIPs that change only consensus and the state of L2 networks are left out.

## Statuses

| Status | Meaning | Out of date after |
|---|---|---|
| `announced` | Said to be coming; no specification or code confirmed | 30 days |
| `specified` | A specification or code is out, but it is not confirmed running. `Stagnant` documents stay here, since their authors can revive them | 90 days |
| `live` | Confirmed running on mainnet or in use | 180 days |
| `stopped` | Withdrawn, or its authors stopped work on it | 180 days |

An item exactly that many days old is still current; from the next day `list` marks it `stale`.
Days are counted in UTC, so a daylight saving change cannot shorten a day.

## The evm-standards script

`skills/evm-standards/scripts/evm-standards.sh` runs on the Bash that macOS ships and reads only the items.

| Command | What it does |
|---|---|
| `check` | Checks that every item has the three fields, a known status, and a real date. It names each item that does not and exits 1 |
| `list` | Prints one line per item: `ok` or `stale`, the status, the date it was checked, and its name, then a count |

`--dir` points either command at another folder of items, and `list --today` counts from another date; the plugin's test uses both.

`find` and `article` run `skills/evm-standards/scripts/standards.py`, which uses only the Python standard library.

| Command | What it does |
|---|---|
| `find <word>...` | Prints the items that hold any of the words in their name, heading, `can` field, or body, and the bitsumi articles that hold any of them in their title or description, the ones that hold more words first. An item line gives the status and the date it was checked; an article line gives its link |
| `article <number>` | Prints the bitsumi articles whose title starts with `[ERC<number>]` or `[EIP<number>]`. Other titles, such as `[ACP209]`, and articles that only mention the number later in the title are left out |

The article index is https://cardene.dev/llms.txt, the list of the maintainer's bitsumi site.
The script downloads it with a plain GET of that fixed address, so no word of the question is sent, and keeps it as `bitsumi-llms.txt` in `~/.local/share/evm-dev/` (`EVM_DEV_HOME` changes it), a folder only the user can read, for one day before it downloads it again.
When the index cannot be downloaded, it uses the copy it kept and says so; with no copy, `find` still prints the items and says it could not read the article index.
It prints only titles, descriptions, and links that start with `https://cardene.dev/articles/`, and the agent reads them as data, not instructions.
`EVM_DEV_INDEX_URL` points it at another index; the plugin's test uses a `file://` copy.

## How the agent answers about a standard

1. It runs `list` and reads the items the question needs
2. When an item is `stale`, it re-checks the official ERC or EIP document before answering, and says what changed
3. When the document cannot be reached, it answers from the item and says it could not confirm it, with the date the item was checked
4. When no item covers the question, it says so, and answers from the official document or says it could not be checked
5. When asked which standard does a job, it runs `find` with words in English and in the user's language, and takes the status of each standard from its item or the official document, never from an article
6. For each standard it names, it runs `article` and gives the title and link of each article

## The tool items

`solidity-code` keeps its own items in `skills/solidity-code/references/items/`, one Markdown file per fact about a tool, such as `openzeppelin-5.7-erc4337-drops-draft.md`.
Its front matter holds these fields.

| Field | What it holds |
|---|---|
| `tool` | One of `solc`, `openzeppelin`, `forge-std`, `foundry`, `hardhat`, `ethereum` |
| `since` | The version the fact starts at. Items for `ethereum` have none and always apply |
| `checked` | The date the fact was confirmed against the official document, as `YYYY-MM-DD` |
| `source` | The organization and the documents the item comes from, by name. Items hold no URLs |
| `detect` | Optional. A regular expression for a line written the old way, matched one line at a time |
| `files` | Optional. File name patterns `detect` looks in, separated by spaces. `*.sol` when left out |

The body says what changed, from which version, and how to write it now.
A tool item counts as out of date 90 days after it was checked, since the tools release every few weeks.

## The solidity-code script

`skills/solidity-code/scripts/solidity-code.py` runs on Python 3 with its standard library only.

| Command | What it does |
|---|---|
| `check` | Checks that every item has its fields, a known tool, a version in `since`, a real date, and a `detect` that is a regular expression. It names each item that does not and exits 1 |
| `list` | Prints one line per item: `ok` or `stale`, the tool, the version, the date it was checked, and its name, then a count |
| `project <folder>` | Prints the framework and the versions of solc, OpenZeppelin, forge-std, Foundry, and Hardhat, read from `foundry.toml`, the Hardhat config, the `package.json` files under `lib/` and `node_modules/`, and `forge --version`. A version it cannot read is `unknown`, and a tool the project does not use is `none` |
| `scan <folder>` | Matches each line of the project's files against the `detect` of the items whose tool version is at or past their `since`, and prints `file:line item`. Items whose tool version is `unknown` are listed under `unknown` instead of being counted as clean |

`scan` exits 0 when nothing matches, 1 when something matches, and 3 when nothing matches but some items could not be judged.
It never prints the text of a line, and never reads `lib/`, `node_modules/`, `out/`, `cache/`, hidden folders, or files whose names start with `.env`.

## How the agent writes a contract

1. It runs `project`, reads the code near the change, and follows the project's pragma, layout, naming, error style, and libraries
2. It runs `list` and reads the items for the tools the project uses, re-checking the ones marked `stale`
3. It writes the contract with the project's library, and asks the user how a contract is upgraded when that has not been chosen
4. It runs `scan`, fixes each line it names, then builds and runs the tests, and says so when they cannot run

## The test tool items

`contract-tests` keeps its items in `skills/contract-tests/references/items/`, one Markdown file per fact about a test tool, such as `hardhat-3.0-network-helpers.md`.
Its front matter holds `tool` (one of `forge-std`, `foundry`, `hardhat`), `since`, `checked`, and `source`, with the same meanings as the tool items above, and no `detect`.
Facts about writing Solidity, such as Foundry 1.0 dropping `testFail`, stay in the `solidity-code` items, which `contract-tests` reads through that skill.
A test tool item counts as out of date 90 days after it was checked.

## The contract-tests script

`skills/contract-tests/scripts/contract-tests.py` runs on Python 3 with its standard library only.

| Command | What it does |
|---|---|
| `check` | Checks that every item has its four fields, a known tool, a version in `since`, and a real date. It names each item that does not and exits 1 |
| `list` | Prints one line per item: `ok` or `stale`, the tool, the version, the date it was checked, and its name, then a count |
| `points <folder>` | Reads the contracts under `src` in `foundry.toml` (default `src`) and under `contracts` in a Hardhat project, leaving out interfaces and `.t.sol` and `.s.sol` files, and prints one line per point: its kind, its name, and `file:line` |
| `uncovered <folder>` | Reads the tests under the test folder and every `.t.sol` file, and prints each point no test touches. It exits 1 when one is left and 0 when every point has a test |

| Kind | The point | A test touches it when |
|---|---|---|
| `function` | An external or public function | It calls `.<name>` |
| `error` | A custom error | It names the error |
| `event` | An event | It names the event |
| `access` | A function guarded by a modifier whose name starts with `only`, or by a comparison with `msg.sender` | It expects a revert on a call to the function: in Solidity, the first call after `expectRevert` that is not a `vm.` cheatcode; in TypeScript, a call in the same statement as the revert check |
| `fuzz` | A function that changes state and takes an integer | A Solidity test function with parameters, or a fast-check property, calls it |
| `invariant` | A contract with a mapping to an unsigned integer and a function that changes state | A Solidity test file that names the contract has a function whose name starts with `invariant`, or a fast-check `fc.commands` test names it |

Names inside comments do not count.
Both commands print only kinds, names, and `file:line`, never the text of a contract or a test, and never read `lib/`, `node_modules/`, `out/`, `cache/`, `artifacts/`, hidden folders, or files whose names start with `.env`.

## How the agent writes tests

1. It reads the versions and the Solidity items with the `solidity-code` skill, runs `list` for the test tool items, re-checks the ones marked `stale`, and follows the project's existing tests
2. It runs `points`, and adds rules the script cannot see, such as limits stated in comments or by the user
3. When the kiwa-design and kiwa-forge skills (kiwa-hardhat for Hardhat) are available, it gives the points to kiwa-design and has kiwa write the tests, without writing test files itself. Otherwise it writes unit, fuzz, and invariant tests with forge, or with the Hardhat runner the project uses
4. It runs `uncovered` and adds tests until no point is left, or tells the user which stay uncovered and why
5. It runs the project's tests and the `solidity-code` scan, and says so when the tests cannot run. When a test shows a bug, it reports the bug and leaves the contract as it was

## The deployment items

`contract-deploy` keeps its items in `skills/contract-deploy/references/items/`, one Markdown file per tool, file format, or service, such as `foundry-keystore.md` or `foundry-broadcast.md`.
Its front matter holds the same four fields as the dApp service items, with these topics.

| Field | What it holds |
|---|---|
| `topic` | One of `keys`, `records`, `verification` |
| `subject` | The tool, file format, or service the item is about, such as `Foundry encrypted keystores (cast wallet import and --account)` |
| `checked` | The date the item was confirmed against the official source, as `YYYY-MM-DD` |
| `source` | The organization and the documents the item comes from, by name. Items hold no URLs |

The body says how the tool, file, or service worked when it was checked, and what a deployment must respect.
A deployment item counts as out of date 90 days after it was checked.

## The contract-deploy script

`skills/contract-deploy/scripts/contract-deploy.py` runs on Python 3 with its standard library only, and asks `git` about `.env` files when the project is a git repository.

| Command | What it does |
|---|---|
| `check` | Checks that every item has its four fields, a known topic, and a real date. It names each item that does not and exits 1 |
| `list` | Prints one line per item: `ok` or `stale`, the topic, the date it was checked, its name, and its subject, then a count |
| `keys <folder>` | Names each place the project handles a key unsafely, one line per finding with its kind and `file:line`, and exits 1 when there is one |
| `record <folder>` | Prints each deployed contract and each transaction to look at, from Foundry's broadcast files and Hardhat Ignition's journals. With `--write` it also writes `deployments/<chain id>.json`. It exits 1 when a transaction needs a look |

`keys` reports four kinds.

| Kind | What it means |
|---|---|
| `env-key` | A private key or mnemonic read from an environment variable (`vm.envUint` and the other `vm.env` calls, `process.env`, `$NAME` in shell and Make), or from a Hardhat 2 configuration variable, which is stored in plain text |
| `key-flag` | A command that passes `--private-key`, `--private-keys`, `--mnemonic`, `--mnemonics`, or `--password` |
| `key-literal` | 64 hex digits, or a quoted phrase of 12 to 24 lowercase words, on a line that speaks of a key, a mnemonic, a seed, accounts, or broadcasting |
| `env-file` | A file whose name starts with `.env`, other than `.env.example`, `.env.sample`, and `.env.template`, that git tracks or does not ignore |

`keys` reads Solidity, JavaScript, TypeScript, shell scripts, Makefiles, justfiles, `package.json`, and TOML and YAML files, and leaves out comments except for `key-literal`, since a key in a comment is still in the file.
It never opens a file whose name starts with `.env`, and never reads dependencies, build output, `broadcast/`, `deployments/`, Foundry's `cache/`, or hidden folders.

`record` reads `broadcast/<script>/<chain id>/run-latest.json`, leaving out the `dry-run/` folders, and `ignition/deployments/<deployment id>/journal.jsonl`.
It prints these lines.

| Line | What it means |
|---|---|
| `contract` | A contract that went on chain: the chain, its name, address, transaction, block, the account that sent it, and the source (`foundry:<script>` or `ignition:<deployment id>`) |
| `failed` | A transaction whose receipt says it reverted |
| `pending` | A transaction that was sent but has no receipt |
| `mismatch` | A transaction recorded as creating a contract whose receipt does not show that contract being created |

A record file holds `format` (1), `chainId`, `contracts` (name, address, tx, block, deployer, source, commit), and `problems` (kind, name, tx, source).
It is rebuilt from the files each time, and the commit comes from Foundry's run file or is `null`.

## How the agent deploys

1. It reads the project's versions through `solidity-code`, runs `list`, and re-checks the items marked `stale`; for the status of an ERC or EIP the contracts rely on, it uses `evm-standards`
2. It asks which chains to deploy to, which of them are production chains, and who should own each contract
3. It writes a Foundry script that calls `vm.startBroadcast()` with no argument, or an Ignition module with every key behind `configVariable`, then runs `keys`, fixes each finding in what it wrote, and names the others to the user
4. It simulates the deployment, then gives the user the command for each chain: `--ledger` or `--trezor` with `--slow` on a production chain, and an encrypted keystore (`cast wallet import` and `--account`, or the Hardhat 3 keystore) on a test chain. The user runs it
5. It runs `record --write`, follows up each `failed`, `pending`, or `mismatch` line, checks each address with `cast code`, and verifies the source with `forge verify-contract` or `ignition verify` once the user agrees

## The release items

`release-check` keeps its items in `skills/release-check/references/items/`, one Markdown file per subject, such as `chain-evm-support.md` or `openzeppelin-upgrades-validate.md`.
Its front matter holds the same four fields as the deployment items, with these topics.

| Field | What it holds |
|---|---|
| `topic` | One of `layout`, `evm`, `tools` |
| `subject` | What the item is about, such as `The EVM version each major chain runs` |
| `checked` | The date the item was confirmed against the official source, as `YYYY-MM-DD` |
| `source` | The organization and the documents the item comes from, by name. Items hold no URLs |

The body says what held when the item was checked, and what a release must respect.
A release item counts as out of date 90 days after it was checked.

## The release-check script

`skills/release-check/scripts/release-check.py` runs on Python 3 with its standard library only, and reads only the JSON files it is given or finds in a build folder.

| Command | What it does |
|---|---|
| `check` | Checks that every item has its four fields, a known topic, and a real date. It names each item that does not and exits 1 |
| `list` | Prints one line per item: `ok` or `stale`, the topic, the date it was checked, its name, and its subject, then a count |
| `layout <old> <new>` | Compares two storage layouts, from `forge inspect <Contract> storageLayout --json`, from artifacts built with `--extra-output storageLayout`, or from two `out/` folders contract by contract, and exits 1 when it finds a problem |
| `abi <old> <new>` | Compares two ABIs, from `forge inspect <Contract> abi --json`, from artifacts, or from two `out/` folders, and exits 1 when a function, event, or error was removed or changed |
| `opcodes <build> --evm <version>` | Names each opcode in the runtime code and the constructor that the EVM version lacks, and exits 1 when there is one |

`layout` prints these lines.

| Line | What it means |
|---|---|
| `removed` | A variable of the deployed version is gone, and no variable of the same type took its place |
| `moved` | A variable now sits at another slot or offset |
| `retyped` | A variable's type changed; a change inside a struct, a mapping's value, or an array's element prints `changed inside` |
| `gap` | A `__gap` array no longer ends at the slot where it ended, so the variables after it moved |
| `renamed` | A variable of the same type sits where the old one did under a new name. It is not counted as a problem |

A variable is matched by name, then by place.
Struct and enum names are compared without the contract that declares them, so renaming the contract changes nothing.
In folders, test and script artifacts (`*.t.sol/`, `*.s.sol/`), `build-info/`, and Hardhat's `*.dbg.json` files are left out, and `--contract` with `--new-contract` compares two contracts with different names.
Variables in ERC-7201 namespaced storage are not in solc's layout output, so `layout` does not see them.

`abi` prints `removed-function`, `changed-function` (outputs or state mutability), `removed-event`, `changed-event` (which parameters are indexed, or whether it is anonymous), and `removed-error`.
Additions are compatible and are not printed, and `receive` and `fallback` count as functions.

`opcodes` reads Foundry and Hardhat artifacts, leaves out solc's metadata at the end of the code, skips the data of each `PUSH`, and counts library placeholders as zero bytes.
For the creation code it reads only the part before the runtime code, which runs the constructor.
The EVM versions run from `homestead` to `osaka`, and an unknown version exits 2.

## How the agent checks a release

1. It reads the project's versions through `solidity-code`, runs `list`, and re-checks the items marked `stale`; for the status of an ERC or EIP, it uses `evm-standards`
2. It asks which chains the contracts go to and, for an upgrade, which git tag or commit is deployed
3. It checks out that version with `git worktree add` in a temporary folder and builds both versions with `--extra-output storageLayout`, unless the user gives the deployed version's layout and ABI
4. It runs `layout` and `abi` on the two versions and `opcodes` with each target chain's EVM version, and runs `npx @openzeppelin/upgrades-core validate` as well when the project has it
5. It compares gas with `forge snapshot --diff` and sizes with `forge build --sizes`, checks each deployment transaction against the chain's per-transaction gas cap (EIP-7825), reports each finding with what to do, and removes the temporary worktree

## The contract design items

`contract-design` keeps its items in `skills/contract-design/references/items/`, one Markdown file per library, service, or practice, such as `openzeppelin-5-proxies.md` or `chainlink-vrf.md`.
Its front matter holds the same four fields as the dApp service items, with these topics.

| Field | What it holds |
|---|---|
| `topic` | One of `upgrades`, `access`, `oracles`, `randomness`, `ordering`, `tokens` |
| `subject` | The library, service, or practice the item is about, such as `Chainlink VRF` |
| `checked` | The date the item was confirmed against the official source, as `YYYY-MM-DD` |
| `source` | The organization and the documents the item comes from, by name. Items hold no URLs |

The body says the state of the library or service when it was checked, such as a version that shut down, and what a contract design must respect.
A contract design item counts as out of date 90 days after it was checked.
The services that run scheduled calls, relay transactions, or watch contracts, such as Chainlink Automation and OpenZeppelin Defender, are dated in the dApp service items.
`contract-design` therefore sends the agent to the items of `dapp-architecture` for those services and keeps no copies.
When that skill is not installed, the agent checks those services against their official documents.

## The contract-design script

`skills/contract-design/scripts/contract-design.py` runs on Python 3 with its standard library only.

| Command | What it does |
|---|---|
| `check` | Checks that every item has its four fields, a known topic, and a real date. It names each item that does not and exits 1 |
| `list` | Prints one line per item: `ok` or `stale`, the topic, the date it was checked, its name, and its subject, then a count |
| `verify <file>` | Checks that a design has the nine sections of the template in order, each with text and no `Fill in:` line left, and a date in Contracts. It names each section that does not, and each decision ID, such as D9, that the design cites but no row of its Open decisions table defines, and exits 1 |

`verify` reads only the design file it is given, and prints section names, decision IDs, and what is wrong with them, never the design's text.

## How the agent designs contracts

1. It runs `list`, reads the items the design may rely on, and re-checks the ones marked `stale`; for the status of an ERC or EIP, such as ERC-4626, it uses `evm-standards`
2. It asks the decisions one at a time, each with a recommended choice, and skips what the request already answers. When it cannot ask, it takes the recommended choice and records it as an assumption under Open decisions
3. It copies `templates/design.md` to `docs/design/<topic>.md`, or where the user or the project keeps designs, replaces every `Fill in:` line, and writes in Contracts the library and compiler versions and the date it checked each service
4. It runs `verify`, fixes each section it names, then goes through `references/checklist.md` and fixes every rule the design breaks
5. It tells the user the rules it could not judge and the open decisions

The checklist holds the rules a design must never break: an owner for every state change, invariants a test can check, exact decimals and rounding, locked initializers, a storage layout that survives upgrades, checked prices and sequencer uptime, randomness nobody can choose, slippage limits and deadlines, no reentrancy, pull payments where pushing can fail, SafeERC20 and fee-on-transfer tokens, no single key in control with a two-step transfer and a pauser, changes delayed by a timelock, no dependence on one keeper, and bounded loops.

## The wallet design items

`wallet-design` keeps its items in `skills/wallet-design/references/items/`, one Markdown file per contract, standard, service, or practice, such as `entrypoint-versions.md` or `permit2-approvals.md`.
Its front matter holds the same four fields as the dApp service items, with these topics.

| Field | What it holds |
|---|---|
| `topic` | One of `accounts`, `signatures`, `approvals`, `gas`, `payments` |
| `subject` | The contract, standard, service, or practice the item is about, such as `x402 payments over HTTP` |
| `checked` | The date the item was confirmed against the official source, as `YYYY-MM-DD` |
| `source` | The organization and the documents the item comes from, by name. Items hold no URLs |

The body says the state of the contract, standard, or service when it was checked, such as which EntryPoint versions a bundler runs, and what a wallet design must respect.
A wallet design item counts as out of date 90 days after it was checked.
Relayers and monitoring services are dated in the dApp service items, so `wallet-design` sends the agent to the items of `dapp-architecture` for them, or to their official documents when that skill is not installed.

## The wallet-design script

`skills/wallet-design/scripts/wallet-design.py` runs on Python 3 with its standard library only.

| Command | What it does |
|---|---|
| `check` | Checks that every item has its four fields, a known topic, and a real date. It names each item that does not and exits 1 |
| `list` | Prints one line per item: `ok` or `stale`, the topic, the date it was checked, its name, and its subject, then a count |
| `verify <file>` | Checks that a design has the nine sections of the template in order, each with text and no `Fill in:` line left, and a date in Accounts. It names each section that does not, and each decision ID, such as D9, that the design cites but no row of its Open decisions table defines, and exits 1 |

`verify` reads only the design file it is given, and prints section names, decision IDs, and what is wrong with them, never the design's text.

## How the agent designs wallets

1. It runs `list`, reads the items the design may rely on, and re-checks the ones marked `stale`; for the status of an ERC or EIP, such as ERC-4337 or EIP-7702, it uses `evm-standards`
2. It asks the decisions one at a time, each with a recommended choice, and skips what the request already answers. When it cannot ask, it takes the recommended choice and records it as an assumption under Open decisions
3. It copies `templates/design.md` to `docs/design/<topic>.md`, or where the user or the project keeps designs, replaces every `Fill in:` line, and writes in Accounts the account contract, the EntryPoint version, and the date it checked each service
4. It runs `verify`, fixes each section it names, then goes through `references/checklist.md` and fixes every rule the design breaks
5. It tells the user the rules it could not judge and the open decisions

The checklist holds the rules a design must never break: no key in a `.env` file, an environment variable, or code, a recovery path and a way to rotate keys, EIP-712 signatures with the chain ID, a nonce, and a deadline, ERC-1271 and ERC-6492 for smart account signatures, permissions and approvals bounded in scope, amount, and time and revocable by users, a pinned EntryPoint version, EIP-7702 delegates that nobody else can initialize and that leave no traps in old storage, sponsorship with limits, agents with spending limits and allowed payees, and signing requests users can read.

## The multichain design items

`multichain-design` keeps its items in `skills/multichain-design/references/items/`, one Markdown file per tool, protocol, standard, or practice, such as `circle-cctp-v2.md` or `layerzero-dvn-config.md`.
Its front matter holds the same four fields as the dApp service items, with these topics.

| Field | What it holds |
|---|---|
| `topic` | One of `deployment`, `bridges`, `messaging`, `tokens` |
| `subject` | The tool, protocol, standard, or practice the item is about, such as `Circle CCTP V1 (Legacy) and V2` |
| `checked` | The date the item was confirmed against the official source, as `YYYY-MM-DD` |
| `source` | The organization and the documents the item comes from, by name. Items hold no URLs |

The body says the state of the tool, protocol, or standard when it was checked, such as a version being retired or an incident that changed the advice, and what a design across chains must respect.
A multichain design item counts as out of date 90 days after it was checked.
Relayers and monitoring services are dated in the dApp service items, so `multichain-design` sends the agent to the items of `dapp-architecture` for them, or to their official documents when that skill is not installed.

## The multichain-design script

`skills/multichain-design/scripts/multichain-design.py` runs on Python 3 with its standard library only.

| Command | What it does |
|---|---|
| `check` | Checks that every item has its four fields, a known topic, and a real date. It names each item that does not and exits 1 |
| `list` | Prints one line per item: `ok` or `stale`, the topic, the date it was checked, its name, and its subject, then a count |
| `verify <file>` | Checks that a design has the nine sections of the template in order, each with text and no `Fill in:` line left, and a date in Messages and verification. It names each section that does not, and each decision ID, such as D9, that the design cites but no row of its Open decisions table defines, and exits 1 |

`verify` reads only the design file it is given, and prints section names, decision IDs, and what is wrong with them, never the design's text.

## How the agent designs across chains

1. It runs `list`, reads the items the design may rely on, and re-checks the ones marked `stale`; for the status of an ERC or EIP, such as ERC-7802 or ERC-7955, it uses `evm-standards`
2. It asks the decisions one at a time, each with a recommended choice, and skips what the request already answers. When it cannot ask, it takes the recommended choice and records it as an assumption under Open decisions
3. It copies `templates/design.md` to `docs/design/<topic>.md`, or where the user or the project keeps designs, replaces every `Fill in:` line, and writes in Messages and verification each protocol, its version, and the date it checked it
4. It runs `verify`, fixes each section it names, then goes through `references/checklist.md` and fixes every rule the design breaks
5. It tells the user the rules it could not judge and the open decisions

The checklist holds the rules a design must never break: the same code at the same address, messages bound to their chains, sender, and nonce and processed once, a whole supply and one canonical token, respect for finality, no single verifier, rate limits in every direction, recovery for stuck and failed messages, a pause on every chain, admin keys not shared across chains, matching decimals, and destination gas that someone pays.

## The dApp service items

`dapp-architecture` keeps its items in `skills/dapp-architecture/references/items/`, one Markdown file per service, network, or tool, such as `openzeppelin-defender-relayer.md` or `ethereum-testnets.md`.
Its front matter holds these fields.

| Field | What it holds |
|---|---|
| `topic` | One of `indexing`, `transactions`, `automation`, `monitoring`, `networks`, `admin`, `storage` |
| `subject` | The service, network, or tool the item is about, such as `Chainlink Automation and Chainlink CRE` |
| `checked` | The date the item was confirmed against the official source, as `YYYY-MM-DD` |
| `source` | The organization and the documents the item comes from, by name. Items hold no URLs |

The body says the state of the service when it was checked, such as a shutdown or a deprecation, and what a design that uses it must respect.
A service item counts as out of date 90 days after it was checked, since hosted services change their products more often than standards do.

## The dapp-architecture script

`skills/dapp-architecture/scripts/dapp-architecture.py` runs on Python 3 with its standard library only.

| Command | What it does |
|---|---|
| `check` | Checks that every item has its four fields, a known topic, and a real date. It names each item that does not and exits 1 |
| `list` | Prints one line per item: `ok` or `stale`, the topic, the date it was checked, its name, and its subject, then a count |
| `verify <file>` | Checks that a design has the nine sections of the template in order, each with text and no `Fill in:` line left, and a date in Components. It names each section that does not, and each decision ID, such as D9, that the design cites but no row of its Open decisions table defines, and exits 1 |

`verify` reads only the design file it is given, and prints section names, decision IDs, and what is wrong with them, never the design's text.

## How the agent plans an architecture

1. It runs `list`, reads the items for the services the design may use, and re-checks the ones marked `stale`; for the status of an ERC or EIP, such as ERC-4337 or EIP-7702, it uses `evm-standards`
2. It asks the decisions one at a time, each with a recommended choice, and skips what the request already answers. When it cannot ask, it takes the recommended choice and records it as an assumption under Open decisions
3. It copies `templates/design.md` to `docs/design/<topic>.md`, or where the user or the project keeps designs, replaces every `Fill in:` line, and writes in Components the date it checked each third-party service
4. It runs `verify`, fixes each section it names, then goes through `references/checklist.md` and fixes every rule the design breaks
5. It tells the user the rules it could not judge and the open decisions

The checklist holds the rules a design must never break: nothing secret or personal on chain, a sender and a payer for every write path, relayer keys kept apart from admin keys, sponsored signatures bound to the chain ID, a nonce, and a deadline, screens that read from an indexer or a database, reads that survive reorganizations, indexing that is idempotent and can be rebuilt from the deployment block, no single key in control, changes delayed by a timelock, a separate pauser, and one set of keys and addresses per environment.

## The financial standard items

`financial-standards` keeps its items in `skills/financial-standards/references/items/`, one Markdown file per standard, such as `iso-20022-cbpr-plus-release.md` or `fix-latest.md`.
Its front matter holds these fields.

| Field | What it holds |
|---|---|
| `standard` | One of `iso-20022`, `fix`, `fpml`, `cdm`, `lei`, `xbrl` |
| `version` | The version, release, or profile in force when the item was checked, such as `CBPR+ SR2025` or `FIX Latest EP312` |
| `checked` | The date the version was confirmed against the official source, as `YYYY-MM-DD` |
| `source` | The organization and the documents the item comes from, by name. Items hold no URLs |

The body says what is in force, what changed recently, and what a design built on the standard must respect.
A standard item counts as out of date 180 days after it was checked, since these standards release at most a few times a year.

## The financial-standards script

`skills/financial-standards/scripts/financial-standards.py` runs on Python 3 with its standard library only.

| Command | What it does |
|---|---|
| `check` | Checks that every item has its four fields, a known standard, and a real date. It names each item that does not and exits 1 |
| `list` | Prints one line per item: `ok` or `stale`, the standard, the version, the date it was checked, and its name, then a count |
| `verify <file>` | Checks that a design has the nine sections of the template in order, each with text and no `Fill in:` line left, and a date in Standard and business. It names each section that does not, and each decision ID, such as D9, that the design cites but no row of its Open decisions table defines, and exits 1 |

`verify` reads only the design file it is given, and prints section names, decision IDs, and what is wrong with them, never the design's text.

## How the agent writes a design

1. It runs `list`, reads the items for the standards in the request, and re-checks the ones marked `stale`; for the status of an ERC or EIP, such as ERC-3643, it uses `evm-standards`
2. It asks the decisions one at a time, each with a recommended choice, and skips what the request already answers. When it cannot ask, it takes the recommended choice and records it as an assumption under Open decisions
3. It copies `templates/design.md` to `docs/design/<topic>.md`, or where the user or the project keeps designs, and replaces every `Fill in:` line
4. It runs `verify`, fixes each section it names, then goes through `references/checklist.md` and fixes every rule the design breaks
5. It tells the user the rules it could not judge and the open decisions

The checklist holds the rules a design must never break: nothing private on chain, salted commitments bound to a domain instead of bare hashes, a contract that accepts only signed evidence and never parses XML, correlation by an internal case ID, reports that are not settlement, a ledger that is not legal finality, revocable permissions, corrections that append, a pinned version and profile, separated off-chain responsibilities, evidence that cannot be replayed, and idempotent writes.

## What it never does

- It never edits its items; a newer fact goes into the answer, not into the plugin's files
- It searches only with a standard's number or name, or a tool's or service's name and version, and sends nothing about your project
- It never writes a private key or a mnemonic into a file, and refuses a command that passes a key
- `contract-tests` never changes a contract to make a test pass, and writes only test files
- `contract-deploy` never reads a key, a mnemonic, or a password, never signs or broadcasts, refuses a command that passes `--private-key`, `--mnemonic`, or `--password`, never reads Foundry's `cache/`, and verifies source code only after the user agrees
- `release-check` never reads a key or a mnemonic, never signs, refuses a command that passes a key, writes nothing into the project, and removes the temporary worktree it creates
- `contract-design` never reads a key, never signs, and writes no Solidity, tests, or deployment scripts
- `wallet-design` never reads a key, never signs, refuses a command that passes a key, and writes no Solidity, wallet code, tests, or deployment scripts
- `multichain-design` never reads a key, never signs, refuses a command that passes a key, and writes no Solidity, bridge code, tests, or deployment scripts
- `dapp-architecture` never reads a key, never signs, and writes no contracts, ABIs, API definitions, frontend code, tests, or scripts
- `financial-standards` never reads a key, never signs, and writes no contracts, schemas, ABIs, API definitions, tests, or scripts
- It never reads `.env` files
- It keeps nothing after it answers
