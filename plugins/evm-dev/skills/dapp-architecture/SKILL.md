---
name: dapp-architecture
description: Designs how the parts of a dApp fit together, asking the decisions one at a time and writing one design document on who sends and pays for each transaction, indexing, data placement, environments, admin keys, and monitoring, from dated items on the services. Use when planning a dApp's architecture.
---

# dApp architecture

Turn a dApp idea into one design document.
Talk to the user in the language they write in, and write the design in that language, keeping the nine section headings in English, since the script reads them.

The script is `scripts/dapp-architecture.py` next to this `SKILL.md`.
Run it as a shell command, `python3 <folder of this SKILL.md>/scripts/dapp-architecture.py <command>`; `--help` describes every command.

## 1. Read the items

Run `list` and read the items for the services the design may use.
Several services agents still suggest have shut down, so never name a service from memory without checking it against an item or its official document.
When an item is marked `stale`, re-check it against the official document (announcements, release notes, or documentation) before relying on it, and tell the user what changed.
When the document cannot be reached, use the item and say that you could not confirm it, with the date it was checked.
For whether an ERC or EIP is final or live, such as ERC-4337 or EIP-7702, use the evm-standards skill in this plugin.

## 2. Ask the decisions

Ask the decisions one at a time, each with a recommended choice and why, and skip what the request already answers:

1. The users and what each can do, and the chains
2. Who sends each transaction and who pays the gas
3. How the app reads chain data, and which indexer
4. What is stored on chain, off chain, and in content-addressed storage
5. Who holds the admin roles, and how changes are delayed
6. Which services the team runs itself and which it buys

In Claude Code, ask with AskUserQuestion; in other agents, ask in the chat, one question per message.
When you cannot ask, take the recommended choice and record it under Open decisions as an assumption. The recommended starting point is users paying their own gas, an indexer the team runs, and admin roles in a multisig behind a timelock.

## 3. Write the design

Copy `templates/design.md` into the project, to `docs/design/<topic>.md` unless the user names a place or the project keeps designs elsewhere, and replace every `Fill in:` line.
Each section decides one part and points to the others; put every decision and assumption in Open decisions, never in two places.
Write in Components the date you checked each third-party service.

- Never put personal data or secrets on chain; events and `private` variables are public
- Every write path names who signs, who sends, and who pays the gas
- Screens read from an indexer or a database, which handles reorganizations and can be rebuilt from the deployment block
- Do not write contracts, ABIs, API definitions, frontend code, tests, or scripts. Contracts belong to the solidity-code skill and tests to the contract-tests skill

The checklist holds the rest.

## 4. Check the design

Run `verify` on the design: `verify <design file>`.
It names each missing, misplaced, empty, or unfinished section, and a Components section without the date the services were checked; fix each and run it again.
Then go through `references/checklist.md` and fix every rule the design breaks. Tell the user which rules you could not judge, and list the open decisions.

## Rules

- Never read a private key or a mnemonic, never sign, and refuse a command that passes a key
- Never read `.env` files or print environment variable values
- Never edit the items in the plugin; a newer fact goes into the design with its source and date
- Do not use material the user marks as private beyond their own project
