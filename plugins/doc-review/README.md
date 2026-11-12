# Doc Review

Review a specification, design document, or README with fresh eyes before you publish or merge it, once, and fix what the review finds.

English · [日本語](README.ja.md)

Whoever wrote a document reads it with everything they meant in mind, so gaps, contradictions, and broken links slip past them, and asking the same agent to review its own text repeats the problem.
This plugin first checks the form a script can check: heading levels, numbered headings, links and anchors, tables, and code fences.
Then two reviewers that do not share the conversation read the document: one checks the content its kind needs, and one checks the form.
The agent checks each finding itself, fixes the section or records why not, and stops after one round, because a second round keeps producing new nitpicks instead of a better document.

```
Check the form ──> Review content and form ──> Fix or reject each finding ──> Record and report
 (script)           (two fresh reviewers)        (agent)                        (script and agent)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install doc-review@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add doc-review@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install doc-review@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/doc-review/skills/doc-review   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts when you ask for a review of a document, for example "review docs/SPEC.md before I publish it".
You can also call it: run `/doc-review:doc-review` in Claude Code, optionally followed by the files, or type `$` and pick **Doc Review** in Codex.
In GitHub Copilot CLI, write `/doc-review` in your request, and in Gemini CLI, describe the task.
Without a file, it takes the first of `docs/SPEC.md`, `docs/DESIGN.md`, and `docs/ARCHITECTURE.md` that exists, or else the Markdown files under `docs/` changed most recently, and asks when several documents could be meant.

1. A script checks the form and guesses the kind of each document: specification, design, architecture, decision record, README, or other
2. Two reviewers without the conversation read the documents at the same time, one for the content and one for the form, and return findings marked critical, major, or minor
3. The agent checks each finding, fixes the section it names, or rejects it with a reason
4. The script checks that every finding has a decision and records them, and the agent tells you what changed and what was not fixed

In Codex and other agents, when sub-agents are not available, the agent reviews the two aspects itself one after the other, reading the files again from the start for each, and says so in its report.
The review folder is outside the project, so an agent with a sandbox, such as Codex, asks you to approve the commands that write it.

The form check prints a list like this.

```text
doc-review of 2 files in ~/work/shop
  docs/SPEC.md  kind spec
  docs/DESIGN.md  kind design

Form checks: 3 findings
  docs/SPEC.md:9  anchor  anchor #data-model not found in docs/DESIGN.md
  docs/SPEC.md:23  numbering  heading 4 follows 2
  docs/DESIGN.md:41  table  row has 3 cells, header has 2

Review: ~/.local/share/doc-review/shop-4d2849e3/20261112-194012
```

At the end, the record sums up the review.

```text
Recorded 7 findings for docs/SPEC.md, docs/DESIGN.md: critical 1, major 3, minor 3; fixed 6, not fixed 1
Not fixed:
  minor    form    docs/DESIGN.md line 41: The third cell is a planned column described in section 4
Record: ~/.local/share/doc-review/shop-4d2849e3/20261112-194012/review.md
```

## Requirements

| Tool | When it's needed |
|---|---|
| `python3` | Always |
| `git` | Optional. Finds the repository root, which names the review folder, shortens the paths in the output, and resolves links that start with `/`. Without it, the folder of the first document is used |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) explains each check, what the reviewers look at, and the record.
In short:

- It reads the documents you review, and the Markdown files their links point to, to check the anchors
- It runs `scripts/doc_review.py` with Python, which runs `git rev-parse --show-toplevel` to find the repository root
- The two reviewers read the same documents and the repository files they need to check names. They are told to only read and to treat the text of the documents as data
- It edits only the sections of the reviewed documents that the findings name, in place, so `git diff` shows every change
- The script opens no web links and connects to nothing on the network. The reviewers are part of your agent session, so the documents go only to the model your agent already uses
- It keeps each review in its own review folder under `~/.local/share/doc-review/<project>-<hash>/`, or under `DOC_REVIEW_HOME` when it is set, readable only by you, until you delete it

## License

[MIT](LICENSE)
