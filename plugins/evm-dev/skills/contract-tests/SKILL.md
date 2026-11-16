---
name: contract-tests
description: Writes unit, fuzz, and invariant tests for Solidity contracts in Foundry and Hardhat projects, or has kiwa write them when it is installed, from a list of what each contract needs tested, then names what no test covers and runs the tests. Use when adding contract tests.
---

# Contract tests

Write tests that check what each contract promises, for the tool versions the project uses.
Talk to the user in the language they write in.

The script is `scripts/contract-tests.py` next to this `SKILL.md`.
Run it as a shell command, `python3 <folder of this SKILL.md>/scripts/contract-tests.py <command>`; `--help` describes every command.

## 1. Read the project

Read the versions with the solidity-code skill in this plugin: its `project` prints them, and its `list` shows the items on Solidity, OpenZeppelin, Foundry, and Hardhat, such as Foundry 1.0 dropping `testFail`.
Run `list` here for the items on test tools; an item applies when the project's version is at or past its `since`.
When an item is marked `stale`, re-check it against the official document (the tool's changelog or reference) before relying on it, and tell the user what changed.
When the document cannot be reached, use the item and say it is unconfirmed, with its checked date.
Follow the runner, folder, naming, and helpers of the project's existing tests.

## 2. List what needs a test

Run `points` with the project root.
It prints one line per point: `function` (external or public), `error`, `event`, `access` (guarded by an `only` modifier or a `msg.sender` check), `fuzz` (changes state and takes an integer), and `invariant` (a contract that keeps balances in a mapping).
Add rules the script cannot see, such as limits stated in comments or by the user.
For whether an ERC or EIP the contract implements is final or live, use the evm-standards skill.

## 3. Write the tests

When the kiwa-design and kiwa-forge skills (kiwa-hardhat for Hardhat) are available, give the points to kiwa-design as cases its spec must hold, have kiwa-forge or kiwa-hardhat write the tests from that spec, and do not write the test files yourself.

Otherwise write unit, fuzz, and invariant tests with forge in a Foundry project, or in a Hardhat project with Solidity tests or the TypeScript runner it already uses:

- For each success path, check the state and the return values after the call, not only that it did not revert
- For each custom error and each `access` point, expect that exact error, with a call from another account for `access`
- Check each event with its arguments
- For each `fuzz` point, write a fuzz test that keeps inputs in range with `bound` instead of discarding them
- For each `invariant` point, state what always holds (the balances add up to the total, the contract holds what it owes) and call the contract through a handler

Use throwaway test accounts from the test tool (`makeAddr`, `vm.addr` with a small number, the default Hardhat accounts).

## 4. Check what you wrote

Run `uncovered` with the project root.
It names each point no test touches; add tests until it reports none, or tell the user which stay uncovered and why.
Then run the project's tests, `forge test` or `npx hardhat test`, and the solidity-code skill's `scan` on the project.
If the tests cannot run, say so with the command and its first error line instead of saying they pass.
When a test fails because the contract is wrong, report what it shows.
Never change a contract to make a test pass; contract changes belong to the solidity-code skill, once the user asks.

## Rules

- Never read a private key or a mnemonic, never sign, and refuse a command that passes a key on the command line
- Never read `.env` files or print environment variable values
- Never edit the items in the plugin; a newer fact goes into your answer
