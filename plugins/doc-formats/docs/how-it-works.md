# How it works

English · [日本語](how-it-works.ja.md)

This page describes what Doc Formats reads, runs, and keeps, and every problem `verify` names.
The agent of a following skill writes the design; the script in `skills/design-doc/scripts/` only checks it.

## Files in the skill

| File | What it holds |
|---|---|
| `SKILL.md` | The content the skill provides, how to write a design in the format, and how to run `verify` |
| `agents/openai.yaml` | How Codex shows and starts the skill |
| `musubi.json` | The content the skill provides through musubi: `design` and `verify`, each at version 1.0.0 |
| `formats/design.md` | The frame of a design document |
| `checks/design.json` | The rules `musubi check` applies to the example designs of following skills: an `## Open decisions` heading and no `Fill in:` line |
| `scripts/design-doc.py` | `verify`, the check of a design |
| `tests/test-design-doc.sh` | Tests of `verify`, the format, the declaration, and the plugin |

## How a skill follows the format

A following skill keeps its own sections, with their `Fill in:` guidance, in a sections file such as `templates/sections.md`.
Its `musubi.json` names `design-doc/design` and `design-doc/verify` with a version range and the fingerprint of the content it last checked, and its `SKILL.md` has three lines: read the `design` format of `design-doc`, run `musubi check` first when the command is installed, and stop when `design-doc` is not installed.
The agent copies the format, puts the skill's sections where its comment says, replaces every `Fill in:` line, and then runs `verify` with the sections file.

| File | Which plugin | What it holds |
|---|---|---|
| `formats/design.md` | doc-formats | The title, the intro, the fixed sentence, and Open decisions |
| `templates/sections.md` | The following skill | The skill's own sections and their guidance |
| `musubi.json` | The following skill | The range and fingerprint of `design-doc/design` and `design-doc/verify`, and the example design `musubi check` applies the rules to |

When the format or the script changes, its fingerprint changes, and `musubi check` refuses every following skill until that skill is checked again and its fingerprint is updated.

## What verify names

`verify --sections <sections file> [--dated "<section>"]... <design file>` reads the level-two headings of the sections file, outside fenced code, as the sections the design must hold, in that order, followed by Open decisions.

| Problem | What it reports |
|---|---|
| A required section is not in the design | `missing: <section>` |
| A required section comes before one it should follow | `out of order: <section>` |
| A section holds only blank lines, headings, or HTML comments | `empty: <section>` |
| A section, or the text before the first section, still holds `Fill in:` | `unfinished: <section>` or `unfinished: title` |
| A section named by `--dated` holds no real YYYY-MM-DD date | `no checked date: <section>` |
| A section cites an ID, such as D9, that no row of the Open decisions table starts with | `undefined decision: <ID>` |

Other level-two headings may sit between the required ones.
Only letters that begin a row's ID in the Open decisions table count as ID letters, so names such as ERC-20 or SR2025 are not read as IDs.

The exit code is 0 with one `design-doc: ok (<n> sections)` line when nothing is wrong, and 1 with one line per problem otherwise.
It is 2, with the reason on standard error, when the design or the sections file cannot be read, when the sections file has no sections or holds Open decisions, and when `--dated` names a section the sections file does not hold.

## What it runs and connects to

`verify` reads the design and the sections file you pass and prints to standard output and standard error.
It prints only section names and IDs, never the text of the design.
It runs no other program and connects to nothing.

## What it keeps

Nothing. The design goes where the following skill or you save it.
