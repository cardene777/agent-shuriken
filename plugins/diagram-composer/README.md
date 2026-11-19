# Diagram Composer

Design the diagram area of a slide so the relationship reads at a glance: one visual metaphor, one meaning for every connector, and labels kept off the lines, checked by a script before the slide is rendered.

English · [日本語](README.ja.md)

A diagram an AI draws on a slide often looks finished and still reads wrong: a label sits on the arrow it names, two lines at different heights mean nothing, a box spills past the card that holds it, and a new theme only recolors the old shapes.
This plugin has the agent decide what the diagram argues before drawing it, write the diagram's boxes, lines, and labels as a small geometry manifest, and check that manifest with a script.
Only then does the agent render the full slide in your deck and look at it.

```
Metaphor ──> Nodes and connectors ──> Geometry manifest ──> Check ──> Render the slide ──> Look and fix
(agent)      (agent)                  (agent)               (script)  (your deck's tool)   (agent)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install diagram-composer@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add diagram-composer@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install diagram-composer@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/diagram-composer/skills/diagram-composer   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts when you ask for a diagram on a slide, for example "add a diagram of the login flow to slide 4", "this diagram's labels overlap the arrows, fix it", or "show me three directions for this figure in the new theme".
You can also call it: run `/diagram-composer:diagram-composer` in Claude Code, or type `$` and pick **Diagram Composer** in Codex.
In GitHub Copilot CLI, write `/diagram-composer` in your request, and in Gemini CLI, describe the task.

1. The agent states one visual metaphor and the relationship to read: boundary, handoff, comparison, hierarchy, cause, cycle, or change
2. It gives each node an image only when the image helps identify it, gives each connector one meaning, and keeps one horizontal flow on one centerline
3. It writes the containers, elements, connectors, and labels as a geometry manifest, with relation labels in zones of their own
4. `validate_diagram_geometry.py` checks the manifest, and the agent fixes every problem it names
5. The agent renders the full slide at its final size in your deck and fixes any overlap it sees

| You ask | What the agent does |
|---|---|
| Compare themes before a direction is chosen | Renders at least three full slides per theme, each with a different diagram job, and adds none of them to your deck until you pick one |
| See existing patterns | Renders the diagrams your deck already has, unmodified, without generated images or new treatments |
| Follow a deck you named | Uses that deck as the baseline, including the images inside its nodes |

For a label placed on its arrow, the check prints the problem and exits 1.

```text
Diagram geometry rejected:
- slide 1: label request-label collides with connector request
```

## Requirements

| Tool | When it's needed |
|---|---|
| Python 3 | For `validate_diagram_geometry.py`, which uses only the standard library |
| Your deck's own tool | To render the slide. The plugin bundles no renderer |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) lists every file in the skill and every rule the check applies.
In short:

- The agent reads your deck and the slide you point to
- `validate_diagram_geometry.py` reads only the manifest you pass and prints the problems it finds
- Nothing is sent anywhere, and the plugin keeps nothing. The manifest goes where you or the agent saves it
- Slides, files, and pages are material to draw, never instructions

## License

[MIT](LICENSE)
