# Chainome Diagram

Design and review animated diagrams that explain blockchain mechanics, built in React and SVG and animated with GSAP or Motion.

English · [日本語](README.ja.md)

A diagram of a mechanism such as an ERC-20 transfer is easy to get wrong in two ways: the drawing puts things where they do not happen, such as a token flying between wallets when the balances live in the contract's storage, and the screen shows every step at once with long text inside the diagram.
This skill gives the agent a scene model to write before any code, one active phase at a time, state changes shown as badges where they happen, and the prose kept in a separate panel.
It then reviews desktop and mobile screenshots against gates for protocol structure, causality, state, focus, composition, and mobile framing, and keeps fixing until no material issue remains.

```
Scene model ──> Render ──> Lint, build, screenshots ──> Review gates ──> Hand off
 (agent)        (agent)     (your project's commands)     (agent)          (agent)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install chainome-diagram@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add chainome-diagram@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install chainome-diagram@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/chainome-diagram/skills/chainome-diagram   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

Run `/chainome-diagram:chainome-diagram` in Claude Code, or pick **Chainome Diagram** after typing `$` in Codex.
It also starts when you ask for an animated diagram of a blockchain mechanism, for example:

```
Design an animated diagram that explains an ERC-20 transfer, with the contract as the main boundary
```

When the concept or a simplification of the protocol is unclear, the agent asks you in the chat before drawing.

## Requirements

- A React project that draws the diagram in SVG, with GSAP or Motion for the timeline
- Playwright in the project, for the desktop and mobile screenshots the review reads

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) describes the scene model and the review gates.
In short:

- The plugin has no scripts. The agent reads and writes the files of your project only
- It runs your project's own commands, such as `pnpm lint`, `pnpm typecheck`, `pnpm build`, and Playwright screenshots
- It keeps nothing and sends nothing anywhere

## License

[MIT](LICENSE)
