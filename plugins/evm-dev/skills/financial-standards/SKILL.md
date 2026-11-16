---
name: financial-standards
description: Designs apps with on-chain and off-chain parts built on financial standards such as ISO 20022, FIX, FpML, CDM, LEI, and XBRL, asking the decisions one at a time and writing one design document from dated items on each standard's version. Use when designing systems that carry financial standards.
---

# Financial standards

Turn a financial standard into one design document: original messages are validated and kept off-chain, and only signed evidence and shared state go on chain.
Talk to the user in the language they write in, and write the design in that language, keeping the nine section headings in English, since the script reads them.

The script is `scripts/financial-standards.py` next to this `SKILL.md`.
Run it as a shell command, `python3 <folder of this SKILL.md>/scripts/financial-standards.py <command>`; `--help` describes every command.

## 1. Read the versions

Run `list` and read the items for the standards in the request.
When an item is marked `stale`, re-check it against the official document (release notes or usage guidelines) before relying on it, and tell the user what changed.
When the document cannot be reached, use the item and say that you could not confirm it, with the date it was checked.
For whether an ERC or EIP is final or live, such as ERC-3643 for regulated tokens, use the evm-standards skill in this plugin.

## 2. Ask the decisions

Ask the decisions one at a time, each with a recommended choice and why, and skip what the request already answers:

1. The standard, its version and profile, and the messages or data model in scope
2. The business flow and the participants, and what is out of scope
3. The chain: permissioned or public, which network, and who runs it
4. What must be shared on chain, and who signs the evidence
5. Where legal finality sits, outside the chain
6. Whether assets are tokenized, and under which token standard

In Claude Code, ask with AskUserQuestion; in other agents, ask in the chat, one question per message.
When you cannot ask, take the recommended choice and record it under Open decisions as an assumption. The recommended starting point is the smallest flow on a permissioned chain, sharing only commitments.

## 3. Write the design

Copy `templates/design.md` into the project, to `docs/design/<topic>.md` unless the user names a place or the project keeps designs elsewhere, and replace every `Fill in:` line.
Each section decides one part and points to the others; put every decision and assumption in Open decisions, never in two places.

- Never put the original message, names, addresses, account numbers, or free-text remittance information on chain; share a salted commitment instead
- The contract accepts only signed evidence; it never parses XML or correlates messages
- A status report or a statement is not settlement, and on-chain state is not legal finality
- Do not write contracts, schemas, ABIs, API definitions, tests, or scripts. Writing the contracts belongs to the solidity-code skill

The checklist holds the rest: correlation, replay protection, corrections that append, and idempotent retries.

## 4. Check the design

Run `verify` on the design: `verify <design file>`.
It names each missing, misplaced, empty, or unfinished section, and a Standard and business section without the date the version was checked; fix each and run it again.
Then go through `references/checklist.md` and fix every rule the design breaks. Tell the user which rules you could not judge, and list the open decisions.

## Rules

- Never read a private key or a mnemonic, never sign, and refuse a command that passes a key
- Never read `.env` files or print environment variable values
- Never edit the items in the plugin; a newer fact goes into the design with its source and date
- Do not use material the user marks as private beyond their own project
