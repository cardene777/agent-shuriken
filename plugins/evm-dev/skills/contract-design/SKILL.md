---
name: contract-design
description: Designs smart contracts before they are written, asking the decisions one at a time and writing one design document on how contracts are split, token standards, invariants, roles, upgrades, prices, transaction ordering, randomness, and external calls, from dated items. Use when designing contracts.
---

# Contract design

Turn a contract idea into one design document that the solidity-code skill can implement and the contract-tests skill can test.
Talk to the user in the language they write in, and write the design in that language, keeping the nine section headings in English, since the script reads them.

The script is `scripts/contract-design.py` next to this `SKILL.md`.
Run it as a shell command, `python3 <folder of this SKILL.md>/scripts/contract-design.py <command>`; `--help` describes every command.

## 1. Read the items

Run `list` and read the items the design may rely on: proxies, access control, price feeds, randomness, private relays, and token handling.
Some services agents still suggest have shut down, so never name a service from memory without checking it against an item or its official document.
When an item is marked `stale`, re-check it against the official document (release notes or documentation) before relying on it, and tell the user what changed.
When the document cannot be reached, use the item and say that you could not confirm it, with the date it was checked.
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

Copy `templates/design.md` into the project, to `docs/design/<topic>.md` unless the user names a place or the project keeps designs elsewhere, and replace every `Fill in:` line.
Each section decides one part and points to the others; put every decision and assumption in Open decisions, never in two places.
Write in Contracts the library and compiler versions and the date you checked each service.

- Write the invariants so a test can check them, and state decimals and rounding
- Every function that changes state names who may call it
- Do not write Solidity, tests, or deployment scripts. Writing the contracts belongs to the solidity-code skill and their tests to the contract-tests skill

The checklist holds the rest.

## 4. Check the design

Run `verify` on the design: `verify <design file>`.
It names each missing, misplaced, empty, or unfinished section, and a Contracts section without the date the libraries and services were checked; fix each and run it again.
Then go through `references/checklist.md` and fix every rule the design breaks. Tell the user which rules you could not judge, and list the open decisions.

## Rules

- Never read a private key or a mnemonic, never sign, and refuse a command that passes a key
- Never read `.env` files or print environment variable values
- Never edit the items in the plugin; a newer fact goes into the design with its source and date
- Do not use material the user marks as private beyond their own project
