---
name: evm-standards
description: Answers whether an ERC is final or an EIP is live on Ethereum mainnet, and what it lets contracts and wallets do, from dated items with their sources, re-checking items that are out of date. Use when the user asks about the status of an ERC or EIP, or which standard to rely on.
---

# EVM standards

A model's knowledge stops at its cutoff, and the status of standards keeps moving after it.
This skill answers from items checked against the official ERC and EIP documents, each with the date it was checked and its source.
It covers ERCs and the EIPs that change what contracts, wallets, and dApps can do, such as new opcodes, precompiles, gas costs, and EIP-7702.
It does not cover the state of L2 networks or changes that stay inside consensus.

Talk to the user in the language they write in.

The script lives in `scripts/` next to this `SKILL.md`, and the items in `references/items/`.
Below, `S` stands for the absolute path of the `scripts` folder; put `S=<folder that contains this SKILL.md>/scripts` at the start of the same shell command.

## 1. Find the items

Run `list` before answering.

```bash
S=<skill folder>/scripts; bash "$S/evm-standards.sh" list
```

Each line is `ok` or `stale`, the status, the date the item was checked, and the item's name, such as `eip-7702-set-code-for-eoas`.
Read the items the question needs from `references/items/<name>.md`.

| Status | Meaning |
|---|---|
| `announced` | Said to be coming; no specification or code confirmed |
| `specified` | A specification or code is out, but it is not confirmed running. `Stagnant` documents stay here |
| `live` | Confirmed running on mainnet or in use |
| `stopped` | Withdrawn, or its authors stopped work on it |

For whether an EIP is in a network upgrade, read the upgrade's meta EIP named in the item, and `eip-7723-network-upgrade-inclusion-stages` for what each inclusion stage means.

## 2. Answer

Answer from the item, and give its status, the date it was checked, and its source.
When the item is `stale`, re-check it against the official ERC or EIP document before you answer, and say what changed.
When the document cannot be reached, for example without a network, say that you could not confirm it, with the date the item was checked.
When no item covers the question, say so, and answer from the official document or say that it could not be checked; never present a fact from memory as checked.
Search with the standard's number or name only.

Never edit the items in the plugin.
They are the dated record the plugin ships; a newer fact belongs in your answer, not in its files.
