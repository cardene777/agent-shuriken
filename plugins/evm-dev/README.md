# EVM Dev

Know whether an ERC is final or an EIP is live on Ethereum mainnet, and what it lets contracts and wallets do, from items checked against the official documents instead of what the agent remembers.

English · [日本語](README.ja.md)

An agent's knowledge stops at its training cutoff, while standards keep moving: an EIP ships in a network upgrade, a proposal is dropped from one, a widely cited "ERC" turns out never to have been merged.
This plugin ships 41 items on ERCs and on the EIPs that change what contracts, wallets, and dApps can do, each with the date it was checked against the official document and the document it came from.
The agent answers from the item, and re-checks an item against the official document when it is older than its status allows.

```
List the items ──> Read the ones asked about ──> Re-check stale ones ──> Answer with date and source
 (script)           (agent)                       (agent, when needed)     (agent)
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
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts when you ask about the status of a standard, for example "is EIP-7702 live on mainnet?" or "can I cite ERC-7281 as final?".
You can also call it: run `/evm-dev:evm-standards` in Claude Code, or type `$` and pick **EVM Standards** in Codex.
In GitHub Copilot CLI, write `/evm-standards` in your request, and in Gemini CLI, describe the task.

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

## What it covers

| Covered | Not covered |
|---|---|
| ERCs, such as ERC-20, ERC-1271, ERC-4337, ERC-6551, ERC-7683 | The state of L2 networks, which dedicated trackers follow |
| EIPs that change what contracts and wallets can do: opcodes, precompiles, gas costs, transaction types, EIP-7702, native account abstraction | EIPs that change only consensus, such as validator rules |
| How an EIP gets into a network upgrade (EIP-7723) | Writing contracts or designing a dApp |

## Requirements

| Tool | When it's needed |
|---|---|
| `bash` | Always |
| Web access in the agent | To re-check an out-of-date item. Without it the agent answers from the item and says it could not confirm it |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) explains the items, the statuses, and when an item counts as out of date.
In short:

- It reads the items bundled with the plugin
- It runs `evm-standards.sh list`, which reads the items and prints one line each
- To re-check an out-of-date item, the agent searches the web and opens the official document with only the standard's number or name
- It never edits its items and keeps nothing

## License

[MIT](LICENSE)
