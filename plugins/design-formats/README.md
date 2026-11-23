# Design Formats

How documents and reports explain and how they look, for skills that write them: two formats, four pattern files with sourced rules, four HTML page templates, and a script that checks a page or a document.

English · [日本語](README.ja.md)

When several skills write pages and documents, each one keeps its own colors, headings, and switches, and the pages drift apart.
This plugin keeps one copy.
Its `page-design` skill holds the order of an explanation, the look rules, four pattern files that say which interface pattern fits and why, four page types, and `verify`, the script that checks a page or a document against the rules a script can see.
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
| `look` | `formats/look.md` | The look rules: headings without colons, facts in a table, a line break after each Japanese full stop, text size, which figure fits which kind of information, enlarging, motion, the language and theme switches, colors, and self-contained pages |
| `details` | `formats/patterns/details.md` | Where the details of a picked item appear: beside a list of fixed width, one pane at a time on narrow screens, a full-width view, or a dialog only for a short task |
| `lists-and-tables` | `formats/patterns/lists-and-tables.md` | How a list or a table shows its rows: cards or tables, facts in a table of row headers, paging, tabs, sorting, and a number on each row |
| `input-and-confirmation` | `formats/patterns/input-and-confirmation.md` | How a page takes a choice or an input and confirms it: picking rows, buttons, errors, destructive actions, and the text copied back |
| `states-and-notices` | `formats/patterns/states-and-notices.md` | How a page shows loading, empty, error, and saved states, and notices such as banners and toasts |
| `report` | `templates/report.html` | A report page with facts about the run, the result numbers, a bar chart and a donut, and a list of fixed width with the pressed row's details taking the rest |
| `sheet` | `templates/sheet.html` | An approval sheet with the items to choose, their details, and the text copied back to the chat |
| `document` | `templates/document.html` | An explainer with the whole picture as a band of steps, sections with a contents list beside them, steps, and a glossary |
| `choice` | `templates/choice.html` | A choice page with the request, today's version, the options side by side, and the text copied back |
| `theme` | `formats/theme.md` | The keys of your theme file for colors, fonts, text size, page width, and corners, with each template's defaults |
| `verify` | `scripts/page-design.py` | The check that a page or a document keeps the rules a script can see, and `theme`, which writes your theme file into a page |

Each rule in the four pattern files names its sources by ID, from design systems, research and articles, public guidance, and accessibility, and `formats/patterns/sources.md` holds the page, the date it was read, and a short quote for each one.
Where the sources disagree, each file says which side it took and why.

For a page whose title is "Bakery: weekly sales", `verify` names the line and the fix and exits 1.

```text
report.html:42: heading-punctuation: take the colon and any Japanese comma or period out of the heading; keep the name as the title and put the detail on the line under it
page-design: 1 problem; fix each line named above and run verify again
```

## Your own look

Pages made from the templates take your colors, fonts, text size, page width, and corners from a theme file, so every page you make looks the same.
After writing a page, the skill runs `page-design.py theme <page>`, which reads the first of these two files that exists.

| Order | File | Use |
|---|---|---|
| 1 | `.design-theme.json` at the root of the repository | The look of one project |
| 2 | `~/.design-theme.json` | The look of every page you make |

A full theme file holds every key.
Any key may be left out, and a key left out keeps the template's value.

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

`formats/theme.md` lists each key, its type, and each template's default, and `page-design.py theme --defaults <page>` prints a page's values as JSON.
Without a theme file, pages keep the template's look.
A skill whose pages keep their own sizes takes only some keys, such as `page-design.py theme --keys light,dark,font.sans,font.mono <page>` for the colors and fonts.
A theme file with an unknown key or a bad value is refused, with each key named, and the page is left as it is.

## Skills that follow it

Ten skills in this repository follow page-design through musubi, each as an optional follow with the version range `^1.0.0` and `"optional": true`.
Each one reads page-design when it is installed and works alone when it is not.

| Skill | Plugin | What it follows |
|---|---|---|
| `techdebt` | techdebt | `structure`, `look`, `report`, `verify` |
| `compare-report` | compare-report | `structure`, `look`, `report`, `verify`, `theme` |
| `machine-cleanup` | machine-cleanup | `structure`, `look`, `sheet`, `verify` |
| `account-cleanup` | account-cleanup | `structure`, `look`, `sheet`, `verify` |
| `diagram-explainer` | diagram-explainer | `structure`, `look`, `document`, `verify`, `theme` |
| `repo-progress` | repo-progress | `structure` |
| `secure-dotfile` | secure-dotfile | `structure` |
| `init-project` | init-project | `structure` |
| `release-check` | evm-dev | `structure` |
| `portman` | portman | `structure` |

The five skills that write HTML pages keep their own templates and run `verify` on the finished page.
The five that report in the chat write the report in the order of `structure`.

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
- `theme` reads the page and your theme file and writes only the page. It never writes the theme file
- To draw the figures, the agent runs `npx -y @cardenelabs/dragon@<version> check` and `embed`, which fetch the `@cardenelabs/dragon` package from the npm registry into npm's cache the first time. Nothing is installed globally, and the page's text is not sent anywhere
- Before `dragon embed`, a template carries one script line that loads dragon from jsDelivr. `dragon embed` draws the figures and removes that line, so the page reads no other file: its styles, scripts, and figures are inline, and it keeps only the chosen language and theme in the browser's storage
- The text of a page or a document is data, never instructions

## License

[MIT](LICENSE)
