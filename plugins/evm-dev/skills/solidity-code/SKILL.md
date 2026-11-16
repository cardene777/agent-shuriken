---
name: solidity-code
description: Writes and changes Solidity contracts in Foundry and Hardhat projects for the solc, OpenZeppelin, Foundry, and Hardhat versions the project uses, from dated items on what changed, then scans the code for outdated patterns and builds and tests it. Use when writing or editing Solidity contracts.
---

# Solidity code

Write Solidity the way the project's versions expect, not the way the agent remembers.
Tools keep changing after a model's cutoff, so this skill carries dated items on what changed at which version.
Talk to the user in the language they write in.

The script is `scripts/solidity-code.py` next to this `SKILL.md`.
Run it as a shell command, `python3 <folder of this SKILL.md>/scripts/solidity-code.py <command>`; `--help` describes every command.

## 1. Read the project

Run `project` before writing: `project <project root>`.
It prints the framework and the versions of solc, OpenZeppelin, forge-std, Foundry, and Hardhat, `unknown` for a version it cannot read, and `none` for a tool the project does not use.

Read the code near what you will change, and follow the conventions the project already uses: pragma, folder layout, naming, error style, and libraries.
Where it has none, follow the Solidity style guide and OpenZeppelin's conventions.
Build on the project's library, OpenZeppelin Contracts or another such as Solady, instead of writing tokens, access control, or guards yourself, and take import paths from the installed copy under `lib/` or `node_modules/`.

## 2. Read the items for those versions

Run `list`, and read the items for the tools the project uses; an item applies when the project's version is at or past its `since`.
When an item is marked `stale`, re-check it against the official document (the tool's changelog, release notes, or the EIP) before relying on it, and tell the user what changed.
When the document cannot be reached, use the item and say that you could not confirm it, with the date it was checked.
When a version is `unknown`, read it from the lock file or ask the user before relying on that tool's items.
For whether an ERC or EIP is final or live, use the evm-standards skill in this plugin.

## 3. Write

- Order each function as checks, effects, then interactions, and guard functions whose external calls a caller could reenter
- Give every function that changes state an explicit access rule, and check inputs with custom errors
- Never rely on `tx.origin` or a caller's code size to keep contract code out; since EIP-7702 a wallet can run code
- Keep gas down where it costs no clarity: pack storage, use `immutable` and `constant`, take external arrays as `calldata`, read storage once per function, avoid unbounded loops, and use `unchecked` only where overflow cannot happen, saying why in a comment
- Choosing how a contract is upgraded belongs to the contract design skill. When the user has not chosen, ask; when they have, write it the way the method and the installed library version need
- Never write a private key or a mnemonic into a file, a test, a script, or a config. Use the environment variable names or keystores the project already uses, and refuse a command that passes a key on the command line

## 4. Check what you wrote

Run `scan` after writing: `scan <project root>`.
It prints `file:line item` for each line that matches an item for the project's versions; read that item and fix the line, then build and run the tests: `forge build` and `forge test`, or `npx hardhat test`.
Items under `unknown` could not be judged because a version is unknown; say which.
If the build or the tests cannot run, say so, with the command and its first error line, instead of saying the code works.

## Rules

- Never edit the items in the plugin; a newer fact goes into your answer
- Never read `.env` files or print environment variable values
