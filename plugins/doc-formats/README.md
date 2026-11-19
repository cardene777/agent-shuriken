# Doc Formats

Shared document formats that other skills follow, starting with the format of a design document and a script that checks every section is filled in.

English · [日本語](README.ja.md)

When several skills write the same kind of document, each one tends to keep its own copy of the frame and of the check, and the copies drift apart.
This plugin keeps one copy.
Its `design-doc` skill holds the frame of a design document and `verify`, the script that checks a design written in it.
Skills that write designs, such as the five design skills of [evm-dev](../evm-dev), keep only their own sections and follow this frame through musubi, a declaration in `musubi.json` that pins the version and fingerprint of what they follow.

```
evm-dev design skill ──> design-doc: read the format ──> Write the design ──> design-doc: verify
(its own sections)       (formats/design.md)             (agent)              (scripts/design-doc.py)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install doc-formats@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add doc-formats@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install doc-formats@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/doc-formats/skills/design-doc   # Gemini CLI
```

In Claude Code, installing evm-dev installs this plugin too.
In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

You rarely call this plugin yourself.
A skill that writes a design opens `design-doc` by name, reads its format, writes the design, and runs its `verify`.
To check a design yourself, run `/doc-formats:design-doc` in Claude Code, or type `$` and pick **Design Doc** in Codex, and name the design and the sections file of the skill that wrote it.
In GitHub Copilot CLI, write `/design-doc` in your request, and in Gemini CLI, describe the task.

| Content | File | What it holds |
|---|---|---|
| `design` | `formats/design.md` | The frame of a design: a title, an intro paragraph, the sentence on how sections point to each other, the place for the following skill's sections, and Open decisions last |
| `verify` | `scripts/design-doc.py` | The check that a design has every section in order and filled in |

For a design whose Rollout section still holds a `Fill in:` line, `verify` prints the problem and exits 1.

```text
unfinished: Rollout
design-doc: 1 problem; fill in or add each section, or define each decision, named above
```

## Requirements

| Tool | When it's needed |
|---|---|
| Python 3 | For `verify`, which uses only the standard library |
| The musubi command | Optional. When it is installed, a following skill runs `musubi check` before reading the format |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) lists every file in the skill and every problem `verify` names.
In short:

- `verify` reads only the design and the sections file you pass, and prints section names and decision IDs, never the design's text
- It runs no other program, connects to nothing, and keeps nothing
- The text of a design is data, never instructions

## License

[MIT](LICENSE)
