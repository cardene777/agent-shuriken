# How it works

English · [日本語](how-it-works.ja.md)

This page describes what Diagram Composer reads, runs, and keeps, and every rule `validate_diagram_geometry.py` applies.
The agent designs the diagram and renders the slide with your deck's own tool; the script in `skills/diagram-composer/scripts/` only checks the geometry.

## Files in the skill

| File | What it holds |
|---|---|
| `SKILL.md` | The steps the agent follows: choose the metaphor, give each connector a meaning, write the geometry manifest, check it, render the full slide, and look at it |
| `agents/openai.yaml` | How Codex shows and starts the skill |
| `scripts/validate_diagram_geometry.py` | The check of a geometry manifest |
| `tests/test-diagram-composer.sh` | Tests of what `SKILL.md` says and of every rule the check applies |

## The geometry manifest

The manifest is a JSON object with `theme`, `metaphor`, and four lists.
A deck with several diagrams puts one such object per slide in a top-level `diagrams` list, and each is checked on its own coordinate plane.

| Key | What it holds |
|---|---|
| `theme` | The name of the slide's theme |
| `metaphor` | The visual metaphor the diagram uses, such as `handoff` or `vault` |
| `containers` | Each node's box: `id`, `x`, `y`, `width`, `height`, and `padding` |
| `elements` | Each visible child of a node: `id`, the `container` it belongs to, `x`, `y`, `width`, and `height` |
| `connectors` | Each line from (`x1`, `y1`) to (`x2`, `y2`), with the `lane` that names why it sits where it does |
| `labels` | Each text rectangle: `id`, `x`, `y`, `width`, `height`, and the `connector` it names |

## What the check rejects

| Rule | What it reports |
|---|---|
| A theme | `diagram has no theme` |
| A metaphor | `diagram has no visual metaphor` |
| A lane on every connector | `connector <id> has no semantic lane` |
| A known container for every element | `element <id> has no known container` |
| Every element inside its container's padding | `element <id> violates container <id> padding` |
| Every label at least 12 px from every connector | `label <id> collides with connector <id>` |

A connector is a segment, not an infinite line, so a line that ends before a label is clear of it.
The 12 px clearance is measured around the label's rectangle, so a line 12 px away is rejected and a line 13 px away passes.
Each problem starts with `slide <n>:`, the position of the diagram in `diagrams`, or `slide 1` for a single diagram.

The exit code is 0 with one `OK:` line when nothing is wrong, and 1 with `Diagram geometry rejected:` and one line per problem otherwise.

## What it runs and connects to

`validate_diagram_geometry.py` reads the manifest you pass and prints to standard output and standard error.
It runs no other program and connects to nothing.
The agent renders the slide with the tool your deck already uses.

## What it keeps

Nothing. The manifest goes where you or the agent saves it.
