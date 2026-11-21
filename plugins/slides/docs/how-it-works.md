# How it works

English · [日本語](how-it-works.ja.md)

This page describes what the two skills of Slides read, run, connect to, and write, every rule the outline check applies, and every command the export runs.
The agent writes the outline and the slide pages; the scripts in `skills/slide-builder/scripts/` and `skills/slide-forge/scripts/` check the outline, add the edit toolbar, and export the files.

## Files in the skills

| File | What it holds |
|---|---|
| `slide-builder/SKILL.md` | The steps for an outline: ask what is missing, confirm the structure, write each slide, check, and hand off |
| `slide-builder/references/deck-format.md` | The outline format: the slide blocks, the slide types, tables, and figures in words |
| `slide-builder/references/readability-rules.md` | The readability rules and the general code words the check flags |
| `slide-builder/examples/slides-outline.md` | A complete ten-slide outline that passes the check |
| `slide-builder/scripts/validate.py` | The check of an outline |
| `slide-forge/SKILL.md` | The three phases of a short presentation: design, edit, and export |
| `slide-forge/references/` | The four tones, the edit page, the PowerPoint rules, and the export commands |
| `slide-forge/scripts/inject_edit_mode.py` | Adds the edit toolbar to a slide page |
| `slide-forge/scripts/edit-text.json` | Every string the toolbar shows, in English and Japanese |
| `slide-forge/scripts/build_pptx.py` | Builds the PowerPoint file from `content.json` |
| `slide-forge/scripts/export_html_final.py` | Writes the public page without the toolbar |
| `slide-forge/scripts/export_pdf.py` | Prints the public page to PDF with Playwright's Chromium |
| `slide-forge/scripts/export_all.sh` | Runs the three exports from a deck folder |
| `*/agents/openai.yaml` | How Codex shows and starts each skill |
| `*/tests/` | Tests of what the skills say and of what the scripts do |

## The outline check

`validate.py` reads one outline and uses only the Python standard library.

```
S=<folder that contains SKILL.md>/scripts; python3 "$S/validate.py" [--ban WORD]... slides-outline.md
```

| Rule | Result |
|---|---|
| Every slide starts with `## Slide N / M ─ <title>` | Error when no slide is found |
| Slide numbers count up from 1, and every slide gives the same total | Error |
| Every slide has a `> meta:` line with `type=` | Error |
| A content slide has `### Takeaway` | Error |
| A `### Figure` section has an `Elements:` list with at least one item | Error |
| A figure lists at most five elements | Warning |
| No general code word (function, method, class, struct, variable, API, endpoint, SDK, query, repository) outside code and quotes | Warning |
| No word given with `--ban` outside code and quotes | Warning |

Each problem starts with the slide, like `slide[3/10]`.
The exit code is 0 with one `[VALIDATION OK]` line when there is no error, 1 when there is an error, and 2 when the arguments are wrong or the file does not exist. Warnings do not change the exit code.

## The edit page

`inject_edit_mode.py` adds three things to a static slide page, each between `<!-- slide-forge-inject-start -->` and `<!-- slide-forge-inject-end -->`: the toolbar's dictionary and script at the end of `<head>`, and the toolbar at the end of `<body>`.
It writes nothing when the page has no `</head>` or `</body>`.

The toolbar is in English when the page opens and switches to Japanese with **日本語**.
It saves the text of every element with `data-key` in the browser's localStorage, exports it as `content.json`, replaces the photo, and resets the edits.

| localStorage key | What it holds |
|---|---|
| `slide-forge:<page path>` | The saved edits of the page |
| `slide-forge:lang` | The toolbar language, `en` or `ja` |

Both stay in your browser. The page sends nothing.

## The export

`export_all.sh <deck folder>` reads `content.json` and `edit-mode.html` in the deck folder and writes three files next to them, named after the folder.

| File | Command |
|---|---|
| `<deck>.pptx` | `uv run --with python-pptx --with Pillow --no-project python3 build_pptx.py content.json <deck>.pptx --theme <tone>` |
| `<deck>.html` | `uv run --no-project python3 export_html_final.py edit-mode.html <deck>.html` |
| `<deck>.pdf` | `uv run --with playwright --no-project python3 export_pdf.py <deck>.html <deck>.pdf` |

`--no-project` keeps uv from reading your project's own Python settings.

| Situation | What happens |
|---|---|
| `uv` is not on `PATH` | Nothing is written. The script prints how to install uv and exits 1 |
| Playwright's Chromium is not installed | The PowerPoint and HTML files are written. The PDF is skipped, the script prints `uv run --with playwright --no-project python3 -m playwright install chromium`, and exits 0 |
| `edit-mode.html` is missing | The PowerPoint file is written, and the HTML and PDF are skipped |
| The PDF fails for another reason | The PowerPoint and HTML files are written, and the script exits 1 |

`build_pptx.py` places the title, subtitle, photo, bullets, and footer on one 1280 x 720 slide in one of four tones, crops the photo to a centered square with Pillow, and pins the East Asian, Latin, and complex-script fonts to Hiragino Sans.

## What it runs and connects to

- `python3` runs `validate.py`, `inject_edit_mode.py`, and `export_html_final.py` when you run it on its own
- `uv` runs the export scripts. The first time, and whenever its cache lacks them, it downloads `python-pptx`, `Pillow`, and Playwright from the Python Package Index, asking only for the package names. It keeps them in its own cache and installs nothing into your Python
- Playwright's Chromium, when it is installed, opens only the local public page to print the PDF. The plugin never downloads the browser
- Nothing else is run, and nothing is sent anywhere

## What it writes and keeps

- The outline goes where you or the agent saves it, `slides-outline.md` in the folder you name
- The deck's files go to the deck folder, `decks/<deck-name>/` in your project by default: the mockups, `edit-mode.html`, `content.json`, and the exported files
- `build_pptx.py` writes the cropped photo to a temporary file and deletes it right after adding it to the slide
- The edit page keeps your edits and the toolbar language in your browser's localStorage until you reset them
- The plugin keeps nothing of its own. The packages stay in uv's cache until you clear it
