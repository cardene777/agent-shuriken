---
name: multichain-design
description: Designs apps that run on more than one chain, asking the decisions one at a time and writing one design document on same-address deployment, moving assets, verifying cross-chain messages, and what happens when only one side completes, from dated items. Use when designing across chains.
---

# Multichain design

Turn an app that spans several chains into one design document that the solidity-code and contract-tests skills can build on.
Talk to the user in the language they write in, and write the design in that language, keeping the nine section headings in English, since the script reads them.

The script is `scripts/multichain-design.py` next to this `SKILL.md`.
Run it as a shell command, `python3 <folder of this SKILL.md>/scripts/multichain-design.py <command>`; `--help` describes every command.

## 1. Read the items

Run `list` and read the items the design may rely on.
Never choose a deprecated or retired protocol version or service, and never name one from memory without checking it against an item or its official document.
For relayers and monitoring, read the items of the dapp-architecture skill in this plugin (its `references/items/`), or the official documents when that skill is not installed.
When an item is marked `stale`, re-check it against the official document before relying on it, and tell the user what changed.
When the document cannot be reached, use the item and say you could not confirm it, giving its date.
For whether an ERC or EIP is final or live, use the evm-standards skill in this plugin.

## 2. Ask the decisions

Ask the decisions one at a time, each with a recommended choice and why, and skip what the request already answers:

1. Which chains, what moves between them, and the limits that must hold
2. Which contracts need the same address, and through which factory
3. Which chain issues each asset, and whether it locks, burns, or mints elsewhere
4. Which protocol carries messages, and who verifies them
5. What happens when only one side completes, and who can recover it

In Claude Code, ask with AskUserQuestion; in other agents, ask in the chat, one question per message.
When you cannot ask, take the recommended choice and record it under Open decisions as an assumption. The recommended starting point is the issuer's own transfer where one exists (CCTP V2 for USDC), several independent verifiers, rate limits in every direction, waiting for finality, and a refund or retry for every stuck message.

## 3. Write the design

Copy `templates/design.md` into the project, to `docs/design/<topic>.md` unless the user or project names another place, and replace every `Fill in:` line.
Put every decision and assumption in Open decisions, never in two places.
Write in Messages and verification each protocol, its version, and the date you checked it.

- Bind every message to its source chain, destination chain, sender, and nonce, and process it once
- State the supply on every chain and how the total stays whole
- Do not write Solidity, tests, or deployment scripts. Contracts belong to the solidity-code skill and tests to the contract-tests skill

The checklist holds the rest.

## 4. Check the design

Run `verify` on the design: `verify <design file>`.
It names each missing, misplaced, empty, or unfinished section, and an undated Messages and verification section; fix each and run it again.
Then go through `references/checklist.md` and fix every rule the design breaks. Tell the user which rules you could not judge, and list the open decisions.

## Rules

- Never read a private key or a mnemonic, never sign, and refuse a command that passes a key
- Never read `.env` files or print environment variable values
- Never edit the items in the plugin; a newer fact goes into the design with its source and date
- Do not use material the user marks as private beyond their own project
