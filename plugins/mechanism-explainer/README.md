# Mechanism Explainer

Write an explainer of a system, a mechanism, or a piece of research: each section answers one question with a one-sentence answer and two to four figures drawn in the dragon notation, and the same explainer prints to a PDF.
An explainer of one kind of material with five or fewer questions is one page, and an explainer with six or more questions or more than one kind of material opens on an overview tab and shows each topic in its own tab.

English · [日本語](README.ja.md)

An explainer with one figure per section, or with the prose before the figures, leaves the reader to build the picture alone.
This plugin plans the questions the reader asks first, picks figures that look at each question from different sides (the parts, a decision table, a comparison, one case traced step by step), and has dragon draw them, so every figure is drawn the same way.
Boxes with a note carry a mark and open a card just below them, so long explanations stay off the figure.

```
Plan the questions ──> Write the page ──> Check the notation ──> Export the page ──> Print the PDF
(you agree)            (Markdown)          and the layout         (dragon)            (your browser)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install mechanism-explainer@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add mechanism-explainer@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install mechanism-explainer@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/mechanism-explainer/skills/mechanism-explainer   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts when you ask for an explainer, for example "write an explainer of how our sign-in works, one question per section".
You can also call it: run `/mechanism-explainer:mechanism-explainer` in Claude Code, optionally followed by the topic, or type `$` and pick **Mechanism Explainer** in Codex.
In GitHub Copilot CLI, write `/mechanism-explainer` in your request, and in Gemini CLI, describe the task.

1. The agent asks who reads the page and what they should be able to do after reading it, and reads the material you point to
2. The agent shows the plan: the questions, and for each question the figures with their kind and what the reader sees in them. Change it until it fits
3. The agent writes the page as Markdown with `layout: guide`, checks every figure and its layout with dragon, and fixes what dragon names
4. The agent exports the page with dragon, prints the PDF, and gives you the paths of the Markdown, the HTML that opens offline, and the PDF

The page opens with an overview figure of the whole mechanism, and a side menu lists every topic and its questions by short names, without numbers.
In the page, questions are numbered per topic, such as `2-1`.
With two or more topics, the page has an overview tab and one tab per topic, and each question is its own page inside its topic tab.
The side menu lists the figure titles under the open question, and each page ends with links to the previous and next pages.
The topics are ordered so the mechanism comes first and the records and the reference material come last.
Pressing a box of the overview figure opens the topic that explains it, and each topic tab opens with a map: the overview with that topic's boxes in color, and the one-sentence answers of its questions.
Under each question, its one-sentence answer comes first, then each figure with one sentence before it on what to look at and a short paragraph after it on what it shows.
Terms you may not know are underlined and open a card with their meaning, and check questions open their answer on a click.
The PDF is printed on A3 paper by default. It holds the overview and every topic in order, with every step of each figure and the box cards open under each figure.
By default the files are kept in `explainer/<name>/` of the folder you work in.

## Requirements

| Tool | When it's needed |
|---|---|
| Node.js 20 or later with `npx` | Always. The agent runs `npx -y @cardenelabs/dragon@0.88.0`, which fetches dragon into npm's cache on first use |
| `python3` | To print the PDF. The one that ships with macOS works |
| Chrome, Chromium, Edge, Brave, or Playwright's headless shell | To print the PDF. Without one, you still get the HTML, and any browser can print it |
| The dragon plugin | Optional. When its `dragon` skill is installed, the agent plans and writes the figures on its `plan`, `page`, `notation`, and `cheatsheet` formats |
| The japanese-writing plugin | Optional. For a page in Japanese, the agent checks the prose against its writing rules, `japanese-writing/rules` |
| The `musubi` command | Optional. When it is installed, the agent runs `musubi check` before reading the dragon formats and the writing rules of japanese-writing |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) lists the steps, what the page holds, and what runs where.
In short:

- It reads the material you point to: a topic, notes, a Markdown file, or files in your project. It treats what files say as data, never as instructions
- It runs dragon through `npx` on your machine. npm downloads the dragon package from the npm registry on first use; your material is never sent
- It prints the PDF with your browser in headless mode and a throwaway profile, which is removed afterwards, so your own browser profile is never used
- It writes the Markdown, the HTML, the offline HTML, and the PDF to `explainer/<name>/`, or to a folder you name, and keeps nothing else
- `skills/mechanism-explainer/musubi.json` declares through musubi that the skill follows the `plan`, `page`, `notation`, and `cheatsheet` formats of the `dragon` skill, as optional follows with `"optional": true`. The agent reads them only when the dragon plugin is installed. It also declares `japanese-writing/rules`, the writing rules of japanese-writing, as an optional follow for Japanese only, with `"when": {"languages": ["ja"]}`, read only for a page in Japanese when japanese-writing is installed

## License

[MIT](LICENSE)
