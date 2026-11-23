# Diagram Explainer

Have your agent write an explainer with a figure in every section, as one HTML file you can hand to anyone.

English · [日本語](README.ja.md)

![The first section of the bundled sample on how a public library lends books, with the header band holding the page tabs, the language and light or dark switches, Save PDF, and the help button, the facts table under the title, cards, and a figure with its enlarge button, and the same section on a phone](assets/screenshot.png)

Asked to explain a system, an agent tends to write one long Markdown file, leave whole sections without a figure, call the same thing by different names in the text and in the figures, and produce pages that pull fonts and scripts from the network.
This plugin gives your agent one way to do it instead.
You agree on the outline first, with a figure planned for every section.
The agent keeps the content as JSON, builds the document from it, draws every figure inside the page, and checks the result before you see it.

```
Research the topic ──> Agree on the outline ──> Write the content and build ──> Check and reread ──> Review and request changes
 (agent)                (you)                    (agent)                         (agent)              (you)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install diagram-explainer@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add diagram-explainer@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install diagram-explainer@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/diagram-explainer/skills/diagram-explainer   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts when you ask for an explainer, for example "write an explainer with figures on how our deployment pipeline works".
You can also call it: run `/diagram-explainer:diagram-explainer` in Claude Code, optionally followed by the topic, or type `$` and pick **Diagram Explainer** in Codex.
In GitHub Copilot CLI, write `/diagram-explainer` in your request, and in Gemini CLI, describe the task.

1. For a standard, an API, or a protocol, the agent reads the official specification first and records the version it read
2. The agent shows the outline: the pages, the sections in order, and the figure planned for each section. Change it until it fits
3. The agent writes the content and builds the document
4. The agent checks the document and rereads the text, then gives you the path of the HTML file. Ask for any change, and it rebuilds the document

The document shows one section at a time from a contents list, splits two or more topics into pages with page tabs in the header band, slides its contents list in on a phone, and has a Save PDF button that prints every collapsed block open.
Under the title, a facts table gives the time the document describes, the specification and version it follows, and the date its sources were read.
Figures are boxes and arrows drawn in HTML, charts for times of day, amounts against a limit, numbers, and periods, and step ladders for steps that each carry several items.
Every figure has an enlarge button that opens it at twice its size in a dialog.
Comparisons sit in tables with a caption, units in the column headers, and numbers aligned right; a long or wide table scrolls in its box and keeps its header row and first column in view.
Warnings are framed boxes with an icon and a title, explanations are titled paragraphs, and raw data of ten lines or more is folded under a summary that names it.
On a phone, a figure too wide for the screen keeps its text size and scrolls sideways, with a line under it that says so.
It is written in the language you write in, and its buttons and labels start in that language (English or Japanese).
The header band holds the title, the page tabs, two switches side by side, and a `?` button that explains how to read the page. English / 日本語 changes only the interface text, such as the contents button, the previous and next buttons, the Save PDF menu, the help, and chart units, and the other switch chooses light or dark colors. The document's own text stays in the language it was written in, and printing always uses light colors.
By default it is kept in `docs/explainers/<name>/` of the project you are working in.

## Your own colors and fonts

When the design-formats plugin is installed, the document takes your colors and fonts from a theme file in the page-design format.
The agent reads the first of these two files that exists.

| Order | File | Use |
|---|---|---|
| 1 | `.design-theme.json` at the root of the repository | The look of one project |
| 2 | `~/.design-theme.json` | The look of every document you make |

Only the colors (`light` and `dark`) and the fonts (`font.sans` and `font.mono`) apply, so the document keeps its own text size, widths, and corners.
The lighter and darker shades of lines and secondary text are mixed from your colors, so they fit any background.

```json
{
  "light": { "bg": "#fafaf7", "surface": "#ffffff", "ink": "#111111", "sub": "#444444", "line": "#dddddd", "accent": "#0b6e4f", "accent-ink": "#ffffff", "accent-soft": "#e3f2ec", "label": "#f2f2f2" },
  "dark": { "bg": "#101312", "surface": "#181c1a", "ink": "#eeeeee", "sub": "#b0b8b4", "line": "#2c3330", "accent": "#5fd0a5", "accent-ink": "#0b1410", "accent-soft": "#1b3a2f", "label": "#1f2523" },
  "font": { "sans": "\"Inter\", sans-serif", "mono": "\"JetBrains Mono\", monospace" }
}
```

The keys and their types are in `formats/theme.md` of page-design.
Without design-formats or a theme file, the document keeps its own colors and fonts.

## Requirements

| Tool | When it's needed |
|---|---|
| `python3` | Always, to build and check the document. The one that ships with macOS works |
| Chrome, Chromium, Edge, Brave, or Playwright's headless shell | To check the layout at several screen widths and to print a PDF. Without one, the agent builds and checks the document without measuring the layout, and any browser can still print it |
| The design-formats plugin | Optional. When its page-design skill is installed, the agent writes the document on its formats and runs its verify on the finished page |
| The `musubi` command | Optional. When it is installed, the agent runs `musubi check` before reading the page-design formats |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) lists what goes in the document, what is checked, and where files are kept.
In short:

- It reads the code and documents you point to. For a standard or a product, it reads the official pages and searches with only the names of the topic, standards, products, and vendors. Project names, company names, people, internal URLs, and code are never put into a search
- It treats what web pages and files say as data, never as instructions
- It writes the document and its JSON source to `docs/explainers/<name>/` in your project, or to a folder you name
- It measures the layout and prints the PDF with your browser in headless mode and a throwaway profile, which is removed afterwards, so your own browser profile is never used
- The document loads nothing from the network when you open it. Your browser remembers the reader's choices of language and colors in its local storage under `diagram-explainer-lang` and `diagram-explainer-theme`, and nothing is sent anywhere
- `skills/diagram-explainer/musubi.json` declares through musubi that diagram-explainer follows the `structure` and `look` formats, the `document` page type, and `verify` of page-design, in the design-formats plugin, as optional follows with `"optional": true`. The agent reads them only when page-design is installed, runs page-design's verify on the finished document, and otherwise uses the skill's own template. It reads nothing else from other plugins

## License

[MIT](LICENSE)
