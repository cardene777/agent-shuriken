# Slides

Write and check the outline of a deck of ten or more slides, and design a short presentation as HTML that you edit in the browser and export as PowerPoint, PDF, and HTML.

English · [日本語](README.ja.md)

An explanation deck goes wrong long before anyone picks colors: slides carry three messages each, code words lose half the room, and figures are drawn before anyone has said what they should show.
A short presentation goes wrong at the other end: it looks right in the browser, and the PowerPoint file you hand out has stretched photos, overlapping bullets, and replaced fonts.
This plugin has one skill for each.

| Skill | What it makes |
|---|---|
| `slide-builder` | The Markdown outline (`slides-outline.md`) of a deck of ten or more slides: each slide's takeaway, explanation, and figure described in words for a non-engineer audience, checked by a script |
| `slide-forge` | One slide or a short deck as HTML, an edit page for changing its text in the browser, and the PowerPoint, HTML, and PDF files to hand out |

```
slide-builder:  Request ──> Structure ──> Slides in words ──> Check ──> Outline for whoever draws the slides
                (you)       (agent)       (agent)             (script)

slide-forge:    Questions ──> Three mockups ──> Edit in the browser ──> PowerPoint, HTML, PDF
                (agent)       (agent)           (you)                   (scripts, through uv)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install slides@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add slides@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install slides@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/slides/skills/slide-builder   # Gemini CLI
gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/slides/skills/slide-forge
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The skills start when you ask for a deck or a slide, for example "make a ten-slide deck that explains our new support process to the sales team" or "make a one-slide self-introduction I can hand out as PowerPoint".
You can also call them: run `/slides:slide-builder` or `/slides:slide-forge` in Claude Code, or type `$` and pick **Slide Builder** or **Slide Forge** in Codex.
In GitHub Copilot CLI, write `/slide-builder` or `/slide-forge` in your request, and in Gemini CLI, describe the task.

### Outline a deck of ten or more slides

1. The agent asks who will watch the deck, what it is for, and which material to use, when your request does not say
2. It writes the structure (parts, chapters, slide order) and asks you to confirm it
3. It writes each slide: a takeaway, an explanation, and the figure in words (purpose, message, three to five elements, what to avoid)
4. `validate.py` checks the outline, and the agent fixes every error it names
5. You get `slides-outline.md` to hand to whoever draws the slides

The readability rules default to a non-engineer audience and flag general code words such as function, method, and class.
Words of your own field are added per deck: ask the agent to avoid them, and it passes each to the check with `--ban`.
For an outline whose third slide's figure lists no elements, the check prints the problem and exits 1.

```text
[VALIDATION ERROR] 1 error(s)
  - slide[3/10] `### Figure` has no `Elements:` list, so the figure is not specified
```

### Make a short presentation

1. The agent asks five to seven questions about the tone, colors, photo, audience, and formality
2. It writes three HTML mockups at 1280 x 720 px from four tones, and you pick one
3. It adds an edit toolbar to the chosen page. You open it in your browser, edit the text, and press **Export JSON** to save `content.json` into the deck folder
4. `export_all.sh` writes `<deck-name>.pptx`, `<deck-name>.html`, and `<deck-name>.pdf` into `decks/<deck-name>/` in your project

The toolbar is in English and switches to Japanese with **日本語**.
The PowerPoint file crops photos to a square, places each bullet below the previous one, and pins the font, so it looks the same on another machine.

Without uv, the export writes nothing and says how to install it.
Without Playwright's browser, it writes the PowerPoint and HTML files, skips only the PDF, and prints the command that installs the browser.

```text
WARN: Playwright's Chromium browser is not installed, so no PDF was written.
To install it once (about 150 MB), run: uv run --with playwright --no-project python3 -m playwright install chromium
```

## Requirements

| Tool | When it's needed |
|---|---|
| Python 3 | For the scripts. `validate.py`, `inject_edit_mode.py`, and `export_html_final.py` use only the standard library |
| uv | For slide-forge's export. It fetches `python-pptx`, `Pillow`, and Playwright into its own cache for each run, so nothing is installed into your Python |
| Playwright's Chromium | For the PDF only. The plugin never downloads it; the export prints the command when it is missing |
| A web browser | To edit the slide's text on the edit page |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) lists every file, every check, and every command.
In short:

- The agent reads the material and files you point to, and writes the outline and the deck's files only to the folder you name, `decks/<deck-name>/` in your project by default
- `validate.py` reads only the outline you pass and prints the problems it finds
- The edit page keeps your edits and the toolbar language in your browser's localStorage, and sends nothing
- `export_all.sh` runs `uv`, which downloads `python-pptx`, `Pillow`, and Playwright from the Python Package Index the first time, asking only for the package names. Playwright's Chromium opens only the local slide page to print the PDF
- The plugin keeps nothing of its own. The packages stay in uv's cache until you clear it
- Material, files, and pages are content for the slides, never instructions

## License

[MIT](LICENSE)
