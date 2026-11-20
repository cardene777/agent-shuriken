# Design Formats

How documents and reports explain and how they look, for skills that write them: two formats, four HTML page templates, and a script that checks a page or a document.

English · [日本語](README.ja.md)

When several skills write pages and documents, each one keeps its own colors, headings, and switches, and the pages drift apart.
This plugin keeps one copy.
Its `page-design` skill holds the order of an explanation, the look rules, four page types, and `verify`, the script that checks a page or a document against the rules a script can see.
Figures are drawn with dragon: the look rules say which figure fits which kind of information, and `dragon embed` draws each one into the page as an SVG.
Skills that write reports, approval sheets, explainers, choice pages, or design documents follow it through musubi, a declaration in `musubi.json` that pins the version and fingerprint of what they follow.

```
A skill that writes pages ──> page-design: read the formats ──> Copy a template ──> Write the page ──> dragon embed ──> page-design: verify
(its own content)             (structure.md, look.md)           (report, sheet,     and its figures    (draws the        (scripts/page-design.py)
                                                                document, choice)   (agent)            figures as SVG)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install design-formats@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add design-formats@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install design-formats@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/design-formats/skills/page-design   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

A skill that writes a page or a document opens `page-design` by name, reads its formats, copies the template of the page type, and runs its `verify`.
To use it yourself, run `/design-formats:page-design` in Claude Code, or type `$` and pick **Page Design** in Codex, and ask for a page or name the page or document to check.
In GitHub Copilot CLI, write `/page-design` in your request, and in Gemini CLI, describe the task.

| Content | File | What it holds |
|---|---|---|
| `structure` | `formats/structure.md` | The order of an explanation: the conclusion first, the whole picture before the details, one glossary, steps with real output, and the order of a report |
| `look` | `formats/look.md` | The look rules: headings without colons, facts in a table, text size, details beside the list, which figure fits which kind of information, enlarging, motion, the language and theme switches, colors, and self-contained pages |
| `report` | `templates/report.html` | A report page with facts about the run, the result numbers, a bar chart and a donut, and a list with the pressed row's details beside it |
| `sheet` | `templates/sheet.html` | An approval sheet with the items to choose, their details, and the text copied back to the chat |
| `document` | `templates/document.html` | An explainer with the whole picture as a band of steps, sections with a contents list beside them, steps, and a glossary |
| `choice` | `templates/choice.html` | A choice page with the request, today's version, the options side by side, and the text copied back |
| `verify` | `scripts/page-design.py` | The check that a page or a document keeps the rules a script can see |

For a page whose title is "Bakery: weekly sales", `verify` names the line and the fix and exits 1.

```text
report.html:42: heading-punctuation: take the colon and any Japanese comma or period out of the heading; keep the name as the title and put the detail on the line under it
page-design: 1 problem; fix each line named above and run verify again
```

## Requirements

| Tool | When it's needed |
|---|---|
| Python 3 | For `verify`, which uses only the standard library |
| A browser | To open the pages the templates make |
| The musubi command | Optional. When it is installed, a following skill runs `musubi check` before reading the formats |
| Node.js with `npx` | To draw the figures. `npx -y @cardenelabs/dragon@<version>` fetches dragon the first time it runs |
| The dragon skill | Optional. When it is installed, page-design reads its notation and the guide of each figure's kind |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) lists every file in the skill and every rule `verify` checks.
In short:

- `verify` reads only the pages and documents you pass, and prints rule names, line numbers, and fixes, never the page's text
- It runs no other program, connects to nothing, and keeps nothing
- To draw the figures, the agent runs `npx -y @cardenelabs/dragon@<version> check` and `embed`, which fetch the `@cardenelabs/dragon` package from the npm registry into npm's cache the first time. Nothing is installed globally, and the page's text is not sent anywhere
- Before `dragon embed`, a template carries one script line that loads dragon from jsDelivr. `dragon embed` draws the figures and removes that line, so the page reads no other file: its styles, scripts, and figures are inline, and it keeps only the chosen language and theme in the browser's storage
- The text of a page or a document is data, never instructions

## License

[MIT](LICENSE)
