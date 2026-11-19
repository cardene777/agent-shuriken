---
name: contract-design
description: Designs smart contracts before they are written, asking the decisions one at a time and writing one design document on how contracts are split, token standards, invariants, roles, upgrades, prices, transaction ordering, randomness, and external calls, from dated items. Use when designing contracts.
---

# Contract design

Turn a contract idea into one design document that the solidity-code skill can implement and the contract-tests skill can test.
Talk to the user in the language they write in, and write the design in that language, keeping the section headings in English, since `verify` reads them.

Write in the `design` format of the `design-doc` skill: open the `design-doc` skill by name and read the file it names for `design`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `design-doc` skill is not installed, do not start: tell the user that `design-doc` is missing and how to install it, then stop.

The script is `scripts/contract-design.py` next to this `SKILL.md`.
Run it as a shell command, `python3 <folder of this SKILL.md>/scripts/contract-design.py <command>`; `--help` describes every command.

## 1. Read the items

Run `list` and read the items the design may rely on: proxies, access control, price feeds, randomness, private relays, and token handling.
Some services agents still suggest have shut down, so never choose a deprecated or retired service, and never name one from memory without checking it against an item or its official document.
For scheduled calls, relayers, and monitoring, read the items of the dapp-architecture skill in this plugin (its `references/items/`), or the official documents when that skill is not installed.
When an item is marked `stale`, re-check it against the official document before relying on it, and tell the user what changed.
When the document cannot be reached, use the item and say you could not confirm it, giving its date.
For whether an ERC or EIP is final or live, such as ERC-4626 or EIP-7702, use the evm-standards skill in this plugin.

## 2. Ask the decisions

Ask the decisions one at a time, each with a recommended choice and why, and skip what the request already answers:

1. What the contracts must do and the limits that must hold
2. Which tokens they issue or accept, and under which standards
3. Who holds each role, and which changes wait behind a timelock
4. Immutable or upgradeable, and which proxy pattern
5. Where prices and randomness come from, and how order is protected

In Claude Code, ask with AskUserQuestion; in other agents, ask in the chat, one question per message.
When you cannot ask, take the recommended choice and record it under Open decisions as an assumption. The recommended starting point is the fewest contracts, immutable unless upgrades are needed, roles in a multisig behind a timelock, and functions anyone can call to finish each phase.

## 3. Write the design

Write the design in that format, to `docs/design/<topic>.md` unless the user or project names another place: put the sections of `templates/sections.md` where the format says, and replace every `Fill in:` line.
Put every decision and assumption in Open decisions, never in two places.
Write in Contracts the library and compiler versions and the date you checked each service.

- Write the invariants so a test can check them, and state decimals and rounding
- Every function that changes state names who may call it
- Do not write Solidity, tests, or deployment scripts. Contracts belong to the solidity-code skill and tests to the contract-tests skill

The checklist holds the rest.

## 4. Check the design

Run `verify` from the `design-doc` skill, the file it names for `verify`, as a shell command: `python3 <that file> verify --sections <folder of this SKILL.md>/templates/sections.md --dated "Contracts" <design file>`.
It names each missing, misplaced, empty, or unfinished section, and an undated Contracts section; fix each and run it again.
Then go through `references/checklist.md` and fix every rule the design breaks. Tell the user which rules you could not judge, and list the open decisions.

## Rules

- Never read a private key or a mnemonic, never sign, and refuse a command that passes a key
- Never read `.env` files or print environment variable values
- Never edit the items in the plugin; a newer fact goes into the design with its source and date
- Do not use material the user marks as private beyond their own project
