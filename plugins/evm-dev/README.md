# EVM Dev

Know whether an ERC is final or an EIP is live on Ethereum mainnet, and write Solidity for the versions your project uses, from items checked against the official documents instead of what the agent remembers.

English · [日本語](README.ja.md)

An agent's knowledge stops at its training cutoff, while standards and tools keep moving: an EIP ships in a network upgrade, a widely cited "ERC" turns out never to have been merged, a library renames the files you import, a framework deprecates the call your script makes.
This plugin ships dated items on both, each with the date it was checked against the official document and the document it came from.

| Skill | What it does |
|---|---|
| `evm-standards` | Answers whether an ERC is final or an EIP is live, and what it lets contracts and wallets do, from 41 items on ERCs and EIPs |
| `solidity-code` | Writes and changes contracts in Foundry and Hardhat projects for the solc, OpenZeppelin, forge-std, Foundry, and Hardhat versions the project uses, then scans the code for outdated patterns and builds and tests it |

```
evm-standards:  List the items ──> Read the ones asked about ──> Re-check stale ones ──> Answer with date and source
solidity-code:  Read the project's versions ──> Read the items for them ──> Write ──> Scan, build, and test
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install evm-dev@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add evm-dev@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install evm-dev@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/evm-standards   # Gemini CLI
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/evm-dev/skills/solidity-code
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

`evm-standards` starts when you ask about the status of a standard, for example "is EIP-7702 live on mainnet?" or "can I cite ERC-7281 as final?".
`solidity-code` starts when you ask for a contract to be written or changed, for example "add a pausable ERC-20 token to this Foundry project".
You can also call them: run `/evm-dev:evm-standards` or `/evm-dev:solidity-code` in Claude Code, or type `$` and pick **EVM Standards** or **Solidity Code** in Codex.
In GitHub Copilot CLI, write `/evm-standards` or `/solidity-code` in your request, and in Gemini CLI, describe the task.

### Check a standard

1. The agent lists the items with the date each was checked, and marks the ones that are out of date
2. The agent reads the items your question needs
3. For an out-of-date item, the agent re-checks the official ERC or EIP document, or says it could not
4. The agent answers with the status, the date it was checked, and the source

The list looks like this.

```text
ok     specified  2026-11-10 eip-7692-eof
ok     live       2026-11-09 eip-7702-set-code-for-eoas
ok     live       2026-11-11 eip-7951-secp256r1-precompile
ok     announced  2026-11-10 erc-7281-xerc20
41 items, 0 stale as of 2026-11-16
```

An answer looks like this.

```text
Yes. EIP-7951 adds a P256VERIFY precompile at 0x100 that costs 6900 gas.
It went live on mainnet with the Fusaka upgrade on 2025-12-03.
Status: live, checked 2026-11-11, source: the EIP-7951 document and EIP-7607 (the Fusaka meta EIP).
```

### Write a contract

1. The agent reads which framework and which versions the project uses, and follows the project's own conventions
2. The agent reads the items for those versions, and re-checks the ones that are out of date
3. The agent writes the contract with the project's library, OpenZeppelin or another it already uses
4. The agent scans what it wrote for patterns the project's versions changed, then builds and runs the tests, and says so when it cannot

The project's versions look like this.

```text
framework     foundry
solc          0.8.34
openzeppelin  5.7.0
forge-std     1.17.0
foundry       1.9.0
hardhat       none
pragma        ^0.8.24
```

A scan names the file, the line, and the item, never the line's text.

```text
src/UserOpInspector.sol:4 openzeppelin-5.7-erc4337-drops-draft
src/Pass.sol:16 ethereum-eip-7702-eoa-checks
scan: 2 matches; 0 items not judged
```

## What it covers

| Covered | Not covered |
|---|---|
| ERCs, such as ERC-20, ERC-1271, ERC-4337, ERC-6551, ERC-7683 | The state of L2 networks, which dedicated trackers follow |
| EIPs that change what contracts and wallets can do: opcodes, precompiles, gas costs, transaction types, EIP-7702, native account abstraction | EIPs that change only consensus, such as validator rules |
| How an EIP gets into a network upgrade (EIP-7723) | Choosing how a contract is upgraded, which a later contract design skill covers |
| Writing Solidity for the versions of solc, OpenZeppelin, forge-std, Foundry, and Hardhat a project uses | Writing tests, deploying, and comparing storage layouts or ABIs before a release |

## Requirements

| Tool | When it's needed |
|---|---|
| `bash` | Always |
| `python3` | For `solidity-code` |
| Foundry (`forge`) or Hardhat | To build and test what `solidity-code` writes. Without them the agent says the code was not built |
| Web access in the agent | To re-check an out-of-date item. Without it the agent answers from the item and says it could not confirm it |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) explains the items, the statuses, the scan, and when an item counts as out of date.
In short:

- It reads the items bundled with the plugin
- `evm-standards` runs `evm-standards.sh list`, which reads the items and prints one line each
- `solidity-code` runs `solidity-code.py`, which reads the project's config files and the `package.json` files of its libraries for their versions, and the project's source files for the scan. It never reads `.env` files, dependencies, or build output, and never prints the text of a line
- `solidity-code` writes only the contracts you ask for, and runs the project's build and tests
- To re-check an out-of-date item, the agent searches the web and opens the official document with only a standard's number or name, or a tool's name and version
- It never edits its items and keeps nothing

## License

[MIT](LICENSE)
