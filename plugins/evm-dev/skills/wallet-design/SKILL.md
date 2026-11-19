---
name: wallet-design
description: Designs wallets and signing, asking the decisions one at a time and writing one design document on how keys are held and recovered, ERC-4337 and EIP-7702 accounts, signed permissions, approvals, who pays gas, and AI agent payments, from dated items. Use when designing wallets or signing.
---

# Wallet design

Turn an app's wallet and signing needs into one design document that the solidity-code and contract-tests skills can build on.
Talk to the user in the language they write in, and write the design in that language, keeping the section headings in English, since `verify` reads them.

Write in the `design` format of the `design-doc` skill: open the `design-doc` skill by name and read the file it names for `design`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `design-doc` skill is not installed, do not start: tell the user that `design-doc` is missing and how to install it, then stop.

The script is `scripts/wallet-design.py` next to this `SKILL.md`.
Run it as a shell command, `python3 <folder of this SKILL.md>/scripts/wallet-design.py <command>`; `--help` describes every command.

## 1. Read the items

Run `list` and read the items the design may rely on.
Never choose a deprecated or retired service or version, and never name one from memory without checking it against an item or its official document.
For relayers and monitoring, read the items of the dapp-architecture skill in this plugin (its `references/items/`), or the official documents when that skill is not installed.
When an item is marked `stale`, re-check it against the official document before relying on it, and tell the user what changed.
When the document cannot be reached, use the item and say you could not confirm it, giving its date.
For whether an ERC or EIP is final or live, use the evm-standards skill in this plugin.

## 2. Ask the decisions

Ask the decisions one at a time, each with a recommended choice and why, and skip what the request already answers:

1. Who uses the wallets and the limits that must hold
2. Which kind of account each user or agent holds, and who chooses the account contract
3. Who holds each key, and how a lost key is recovered
4. What users sign and approve, with amounts and expiry
5. Who pays gas, and how AI agents pay and within what limits

In Claude Code, ask with AskUserQuestion; in other agents, ask in the chat, one question per message.
When you cannot ask, take the recommended choice and record it under Open decisions as an assumption. The recommended starting point is keys the app never holds, the wallet choosing and vetting any EIP-7702 delegate, batching and sponsorship requested through the wallet, approvals limited in amount and time, and agents paying with their own capped, expiring permission.

## 3. Write the design

Write the design in that format, to `docs/design/<topic>.md` unless the user or project names another place: put the sections of `templates/sections.md` where the format says, and replace every `Fill in:` line.
Put every decision and assumption in Open decisions, never in two places.
Write in Accounts the account contract, the EntryPoint version, and the date you checked each service.

- Write every signed message as EIP-712 typed data with its domain, nonce, and deadline
- Every permission and approval names its spender, amount, and expiry, and how it is revoked
- Do not write Solidity, tests, or deployment scripts. Contracts belong to the solidity-code skill and tests to the contract-tests skill

The checklist holds the rest.

## 4. Check the design

Run `verify` from the `design-doc` skill, the file it names for `verify`, as a shell command: `python3 <that file> verify --sections <folder of this SKILL.md>/templates/sections.md --dated "Accounts" <design file>`.
It names each missing, misplaced, empty, or unfinished section, and an undated Accounts section; fix each and run it again.
Then go through `references/checklist.md` and fix every rule the design breaks. Tell the user which rules you could not judge, and list the open decisions.

## Rules

- Never read a private key or a mnemonic, never sign, and refuse a command that passes a key
- Never read `.env` files or print environment variable values
- Never edit the items in the plugin; a newer fact goes into the design with its source and date
- Do not use material the user marks as private beyond their own project
