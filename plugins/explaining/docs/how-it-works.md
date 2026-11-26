# How it works

English · [日本語](how-it-works.ja.md)

This page describes what the explaining skill reads and keeps, and how other skills follow its structure.
The agent writes the explanation; the plugin holds only instruction files.

## Files in the skill

Paths are relative to `skills/explaining/`.

| Path | What it holds |
|---|---|
| `SKILL.md` | The rules and the four steps, from gathering the facts and planning the parts to the check before handing the explanation over |
| `references/structure.md` | The way to build an explanation: six techniques, each with when to use it, the figures chosen by what they do, and the order of the parts |
| `examples/confirmation-protocol.md` | One explanation built this way, with a comment before each part naming the technique it uses |
| `musubi.json` | The content `structure` that other skills follow through musubi, at version 1.0.0 |
| `agents/openai.yaml` | The skill's name and default prompt in Codex |
| `tests/test-explaining.sh` | The plugin's checks |

## The figures it asks for

| Figure | dragon kind | Use it for |
|---|---|---|
| A figure that steps | `sequence` | Messages or work passing between parts in order |
| A figure that takes input | `try` | A result that depends on conditions the reader chooses |
| A figure of the state before and after | `state` | Things that change state |

The skill names a figure by what it does, so a skill that draws figures another way can follow the same rules.
When the page cannot hold a moving figure, the map of the stages becomes a numbered list and the combinations become a table.

## How other skills follow it

- `musubi.json` of this skill provides the content `structure`, the file `references/structure.md`, at version 1.0.0
- A skill that writes explanations names `explaining/structure` with a version range and the fingerprint of the file in its own `musubi.json`, and its `SKILL.md` tells the agent to open the explaining skill and read `references/structure.md` before planning
- When `references/structure.md` changes, `musubi check` refuses the skills that follow it until their fingerprint is checked again
- The following skill keeps its own format for the page, the figures, and the language

## What it runs and connects to

- Nothing runs. The plugin is instruction files
- The agent reads only the conversation and the files you point to
- Nothing is sent anywhere

## What it keeps

Nothing.
The explanation goes to the file you name or into the chat.
