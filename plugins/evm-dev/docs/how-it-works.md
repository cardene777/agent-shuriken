# How EVM Dev works

English · [日本語](how-it-works.ja.md)

The plugin has three skills. `evm-standards` answers questions about ERCs and EIPs from items bundled with it, `solidity-code` writes Solidity for the versions a project uses from items about its tools, and `financial-standards` writes a design for an app built on financial standards from items about their versions.
This page describes the skills' items, when an item counts as out of date, the scripts, and what the agent may do with them.

## The ERC and EIP items

Each item is one Markdown file in `skills/evm-standards/references/items/`, named after its standard, such as `eip-7702-set-code-for-eoas.md` or `erc-4337-account-abstraction.md`.
Its front matter holds three fields.

| Field | What it holds |
|---|---|
| `status` | One of `announced`, `specified`, `live`, `stopped` |
| `checked` | The date the status was confirmed against the official document, as `YYYY-MM-DD` |
| `source` | The organization and the documents the item comes from, by name. Items hold no URLs |

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

## How the agent answers about a standard

1. It runs `list` and reads the items the question needs
2. When an item is `stale`, it re-checks the official ERC or EIP document before answering, and says what changed
3. When the document cannot be reached, it answers from the item and says it could not confirm it, with the date the item was checked
4. When no item covers the question, it says so, and answers from the official document or says it could not be checked

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
| `verify <file>` | Checks that a design has the nine sections of the template in order, each with text and no `Fill in:` line left, and a date in Standard and business. It names each section that does not and exits 1 |

`verify` reads only the design file it is given, and prints section names and what is wrong with them, never the design's text.

## How the agent writes a design

1. It runs `list`, reads the items for the standards in the request, and re-checks the ones marked `stale`; for the status of an ERC or EIP, such as ERC-3643, it uses `evm-standards`
2. It asks the decisions one at a time, each with a recommended choice, and skips what the request already answers. When it cannot ask, it takes the recommended choice and records it as an assumption under Open decisions
3. It copies `templates/design.md` to `docs/design/<topic>.md`, or where the user or the project keeps designs, and replaces every `Fill in:` line
4. It runs `verify`, fixes each section it names, then goes through `references/checklist.md` and fixes every rule the design breaks
5. It tells the user the rules it could not judge and the open decisions

The checklist holds the rules a design must never break: nothing private on chain, salted commitments bound to a domain instead of bare hashes, a contract that accepts only signed evidence and never parses XML, correlation by an internal case ID, reports that are not settlement, a ledger that is not legal finality, revocable permissions, corrections that append, a pinned version and profile, separated off-chain responsibilities, evidence that cannot be replayed, and idempotent writes.

## What it never does

- It never edits its items; a newer fact goes into the answer, not into the plugin's files
- It searches only with a standard's number or name, or a tool's name and version, and sends nothing about your project
- It never writes a private key or a mnemonic into a file, and refuses a command that passes a key
- `financial-standards` never reads a key, never signs, and writes no contracts, schemas, ABIs, API definitions, tests, or scripts
- It never reads `.env` files
- It keeps nothing after it answers
