# Blockchain Diagram

Design and review animated diagrams that explain blockchain mechanics, built in React and SVG and animated with GSAP or Motion.

English · [日本語](README.ja.md)

A diagram of a mechanism such as an ERC-20 transfer is easy to get wrong in two ways: the drawing puts things where they do not happen, such as a token flying between wallets when the balances live in the contract's storage, and the screen shows every step at once with long text inside the diagram.
This skill gives the agent a scene model to write before any code, one active phase at a time, state changes shown as badges where they happen, and the prose kept in a separate panel.
It then reviews desktop and mobile screenshots against gates for protocol structure, causality, state, focus, composition, and mobile framing, and keeps fixing until no material issue remains.
The diagram takes your colors, fonts, text size, and corners from a theme file when you place one, and keeps your project's own look otherwise.

```
Theme file ──> Scene model ──> Render ──> Lint, build, screenshots ──> Review gates ──> Hand off
 (script)       (agent)        (agent)     (your project's commands)     (agent)          (agent)
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

Run `/chainome-diagram:chainome-diagram` in Claude Code, or pick **Blockchain Diagram** after typing `$` in Codex.
It also starts when you ask for an animated diagram of a blockchain mechanism, for example:

```
Design an animated diagram that explains an ERC-20 transfer, with the contract as the main boundary
```

When the concept or a simplification of the protocol is unclear, the agent asks you in the chat before drawing.

## Your own look

Before drawing, the skill runs `diagram-theme.py`, which reads the first of these two files that exists.
It uses the same theme file as the `page-design` skill of design-formats, so your diagrams and pages share one look.

| Order | File | Use |
|---|---|---|
| 1 | `.design-theme.json` at the root of the repository | The look of one project |
| 2 | `~/.design-theme.json` | The look of everything you make |

A full theme file holds every key.
Any key may be left out, and a key left out keeps your project's value.

```json
{
  "light": {
    "bg": "#fafaf7", "surface": "#ffffff", "ink": "#111111", "sub": "#444444", "line": "#dddddd",
    "accent": "#0b6e4f", "accent-ink": "#ffffff", "accent-soft": "#e3f2ec", "bar": "#eeeeee", "label": "#f2f2f2"
  },
  "dark": {
    "bg": "#101312", "surface": "#181c1a", "ink": "#eeeeee", "sub": "#b0b8b4", "line": "#2c3330",
    "accent": "#5fd0a5", "accent-ink": "#0b1410", "accent-soft": "#1b3a2f", "bar": "#232a27", "label": "#1f2523"
  },
  "font": { "sans": "\"Inter\", sans-serif", "mono": "\"JetBrains Mono\", monospace", "size": 16, "line-height": 1.75 },
  "space": { "page-width": 1100, "radius-small": 4, "radius": 6, "radius-large": 8 }
}
```

The agent writes the values as CSS custom properties of the diagram: `accent` colors the active path and the moving token, `line` the resting paths and borders, `mono` the function names and storage keys, and `radius-large` the contract boundary.
[How it works](docs/how-it-works.md#the-theme-file) maps every key.
`light.bar`, `dark.bar`, and `space.page-width` belong to pages and are not used in a diagram.
Without a theme file, the diagram keeps your project's own look, as before.
A theme file with an unknown key or a bad value is refused, with each key named, and the agent asks you whether to fix it first.

## Requirements

- A React project that draws the diagram in SVG, with GSAP or Motion for the timeline
- Playwright in the project, for the desktop and mobile screenshots the review reads
- Python 3, which runs the script that reads your theme file

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) describes the scene model and the review gates.
In short:

- The plugin has one script, `diagram-theme.py`. It reads only your theme file and prints the values a diagram uses
- The agent reads and writes the files of your project only
- It runs your project's own commands, such as `pnpm lint`, `pnpm typecheck`, `pnpm build`, and Playwright screenshots
- It keeps nothing and sends nothing anywhere

## License

[MIT](LICENSE)
