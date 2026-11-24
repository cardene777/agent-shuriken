# Flow Format

Explain how a flow, a procedure, or a workflow goes as numbered steps, each with one action and a short paragraph of details.

English · [日本語](README.ja.md)

Asked how something proceeds, an agent often answers with bold headings and indented bullets, arrows between names, or a Mermaid block that a terminal shows as raw code.
This plugin gives the agent one answer form instead: numbered steps, each an action sentence that starts with a verb, a blank line, and an unindented paragraph of one to three sentences.
A plain-text diagram may follow the steps when the flow branches or loops.

```text
1. Create a branch for the issue from the latest main branch.

The branch keeps the change apart from other work until it is reviewed.
Name it after the issue so that anyone can find it.
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install flow-format@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add flow-format@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install flow-format@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/flow-format/skills/flow-format   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts when you ask how something goes from start to end, for example "how does a change get from an issue to main?", "what happens when the release script runs?", or "walk me through the setup".
You can also call it: run `/flow-format:flow-format` in Claude Code, or type `$` and pick **Flow Format** in Codex.
In GitHub Copilot CLI, write `/flow-format` in your request, and in Gemini CLI, describe the task.

| You ask about | What the answer holds |
|---|---|
| A flow, a procedure, a chain of steps, or a workflow | Numbered steps, each an action sentence and a paragraph of one to three sentences |
| A flow that branches or loops | The same steps, then a plain-text diagram of boxes and arrows |
| One file or one idea, such as what a function returns | An ordinary answer, since the plugin does not start |

The answer is written in the language you write in.
Mermaid is written only in a file you asked for, such as a pull request description, never in the chat answer.

## What it reads, runs, and sends

The plugin is one instruction file and runs nothing.
It reads only the conversation, stores nothing, and sends nothing anywhere.

## License

[MIT](LICENSE)
