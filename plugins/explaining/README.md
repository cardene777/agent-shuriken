# Explaining

Explain how a protocol, a system, or a process works around one running example, so a reader new to the subject can follow it from start to end.

English · [日本語](README.ja.md)

Asked to explain how something works, an agent often lists the parts one by one, switches examples between sections, and draws figures that do not move.
This plugin gives the agent one way to build the explanation instead.
One concrete example runs through every section, a numbered map of the stages comes first, and each later section digs into one stage.
Similar things are told apart in a table, likely misreadings are ruled out where they arise, every combination of conditions is laid out with its result, and a table of roles with one sentence to take away closes it.
Where order, a change of state, or conditions matter, it asks for a figure that steps, takes input, or shows the state before and after.

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install explaining@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add explaining@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install explaining@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/explaining/skills/explaining   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts when you ask for a written explanation of how something works, for example "explain how a payment is confirmed across three servers" or "write up how our deploy pipeline works".
You can also call it: run `/explaining:explaining` in Claude Code, or type `$` and pick **Explaining** in Codex.
In GitHub Copilot CLI, write `/explaining` in your request, and in Gemini CLI, describe the task.

| Part of the explanation | What it holds |
|---|---|
| One running example | One case with names and values, used in every section and figure |
| A map of the stages | A numbered list of the stages, drawn as a figure that steps, before the sections dig into each |
| Pairs told apart | A table that asks the same questions of two similar things |
| Misreadings ruled out | A negative sentence where a part is easy to over-read |
| Every combination of conditions | A table of every combination and its result, and a figure that takes input when there are many |
| A closing table and one sentence | What each part did in the example, and the one thing to remember |

The explanation is written in the format and the language you ask for, Markdown by default.
`skills/explaining/examples/confirmation-protocol.md` is one explanation built this way.

## Use it from another skill

The skill provides its structure as the content `structure` through [musubi](https://github.com/cardene777/musubi).
A skill that writes explanations names `explaining/structure` in its own `musubi.json` and reads `references/structure.md` before planning, while keeping its own format for the page and the figures.

## What it reads, runs, and sends

The plugin is instruction files and runs nothing.
It reads only the conversation and the files you point to, stores nothing, and sends nothing anywhere.

## License

[MIT](LICENSE)
