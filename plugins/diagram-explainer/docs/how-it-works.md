# How Diagram Explainer works

English · [日本語](how-it-works.ja.md)

This page lists the steps the agent follows, what goes in the document, what is checked before you see it, and where files are kept.
The procedure is in `skills/diagram-explainer/SKILL.md`, and the pages it points to are in `skills/diagram-explainer/references/`.

## The steps

| Step | Who | What happens |
|---|---|---|
| Research | Agent | For a standard, an API, or a protocol, reads the official specification and records the version and the date. For your own system, reads the code and documents you point to |
| Outline | Agent | Lists what the reader needs to know and plans the pages, the sections, and a figure for every section |
| Agree on the outline | You | Change the sections or the figures until the outline fits |
| Write | Agent | Writes the content as JSON: pages, sections, text, figures, charts, and tables |
| Build | Agent | Turns the JSON into one HTML file with the scripts in the plugin |
| Check | Agent | Runs the document check, fixes everything it reports in the JSON, and builds again |
| Reread | Agent | Rereads the text for numbers, units, and whether each figure shows what the text says, and looks at every section at a desktop width and a phone width |
| Revise | You and the agent | You ask for changes, and the agent edits the JSON and rebuilds the document |

## What is in the document

| Part | Contents |
|---|---|
| Contents list | The sections of the current page. Picking one shows that section alone |
| Header band | The title, the page tabs when there are two or more topics, the Save PDF button, the language and light or dark switches, and a `?` button that opens the help in a dialog. The page tabs take the arrow keys, Home, and End |
| Facts table | Under the first title: the time the document describes, and when given, the specification and version it follows and the date its sources were read |
| Sections | Text, a figure with an enlarge button, and any of these: key numbers, cards with the same fields in the same order, warnings in a framed box with an icon, explanations as titled paragraphs, a before-and-after comparison, tables with a caption and units in the column headers, code, and raw data of ten lines or more folded under a summary that names it |
| Phone layout | A bar with the current section and a button that slides the contents list in. A chart or step ladder that would need text under 12px to fit keeps its text size and scrolls sideways inside its frame, with the cut edge faded and a line under it that says it scrolls |
| Print layout | Every section in order, one per sheet, in light colors, with the header band, contents, and enlarge buttons hidden and every collapsed block open. The Save PDF button prints the current page or all pages |

Every figure is drawn inside the page:

| Figure | Good for |
|---|---|
| Boxes and arrows in HTML | Parts and how they connect, flows, layers, who owns what |
| Time band | Opening hours and the times things happen, row by row |
| Capped bar | An amount against a limit, before and after trimming |
| Bar chart | Comparing two or more numbers |
| Period chart | Periods on a year axis |
| Step ladder | Steps that each carry several items, such as what is called, the check, and who acts |

Charts are drawn at the width of their frame, so their text keeps its size at every screen width, and step ladders sit in the middle of their frame. Lines in a chart pass under its text, and its bars keep their contrast in light and dark colors.

Every figure has an enlarge button at the right of its caption. It, or a press on the drawing, opens the drawing at twice its size in a dialog, and closing the dialog returns the focus to the button.
A figure or table wider than its box scrolls inside a named region that the keyboard can reach, with the side that continues faded; a long table keeps its header row and first column in view.

The buttons and labels of the document start in its language, English or Japanese.

## The template and its switches

`render.py` puts the content into the template of the skill, and `build.py` copies the styles and scripts of `assets/` into the page. Paths in the table are relative to `skills/diagram-explainer/`.

| File | What it holds |
|---|---|
| `templates/starter-doc.html` | The frame of the document: the header band, the facts table, the contents list, the switches, and the markers where `build.py` puts the assets |
| `assets/` | The styles and scripts copied into every document: the layout and its light and dark colors, charts, step ladders, the print layout, and the script of the switches |
| `assets/ui.json` | The interface words in English and Japanese, defined only here. `render.py` and `ladder.py` read it when they write the page, and `build.py` copies it into the page, where the switches read it |
| `musubi.json` | The optional follows of `page-design/structure`, `page-design/look`, `page-design/document`, `page-design/verify`, and `page-design/theme` through musubi: for each, the version range (`^1.0.0` for `structure` and `theme`, `^2.0.0` for the others), the fingerprint of the content at the last check, and `"optional": true` |

The header band holds two switches side by side: a language switch (English / 日本語) that changes only the interface text, such as the contents button, the previous and next buttons, the Save PDF menu, the help, and chart units, and a light and dark switch.
The document's own text stays in the language it was written in, and printing always uses light colors.
The page starts in the document's language and the system's light or dark setting, and the browser remembers the reader's choices in its local storage under `diagram-explainer-lang` and `diagram-explainer-theme`; nothing is sent anywhere.

- When the page-design skill of the design-formats plugin is installed, the agent reads its `structure` and `look` formats and its `document` page type, which `musubi.json` follows as optional follows. After `scripts/check.py` passes, it runs page-design's `verify` on the finished `<name>.html`, fixes each line it names in `content.json`, and builds and checks again until it prints `ok`. It reads nothing else from other plugins
- When the `musubi` command is installed, the agent runs `musubi check` before reading them and stops if it fails; the check skips the follows with a warning when design-formats is not installed. When a followed content changes, `musubi check` refuses diagram-explainer until its fingerprint is checked again
- After the build, the agent runs page-design's `theme --keys light,dark,font.sans,font.mono` on the finished `<name>.html`. It writes the colors and fonts of `.design-theme.json` at the root of the repository, or else of `~/.design-theme.json`, into the page, and leaves the page as it is without either. `assets/doc.css` names its base colors after the keys of the theme file (`bg`, `surface`, `ink`, `sub`, `line`, `label`, and the accent colors) and mixes the other shades from them with `color-mix()`, so they follow a theme's colors
- Without page-design, the document is built from `templates/starter-doc.html` and `assets/` alone. Nothing in the plugin requires design-formats

## What is checked before you see it

`scripts/check.py` fails the document until all of these hold:

- Nothing is loaded from the network: no script, stylesheet, web font, or image from a URL
- Every section has a figure, or states why it has none
- The contents list, the section headings, the page tabs, and the pages agree
- Every figure has a caption, and figure numbers on a page have no gaps or repeats
- Every table row has as many cells as the header
- No collapsed block ships open, and nothing but one lead sentence and the facts table sits between a title and its first section
- Every collapsed block holds 10 lines or more, and its summary names what it holds instead of saying only "More" or "Details"
- No section holds more than two warnings
- Ids are unique and every reference inside figures resolves
- Words from the term tables appear neither in the text nor in the figures
- With a browser, at several screen widths: the page height does not move while the page loads, and nothing overflows sideways

For a Japanese document, the text is also checked against bundled word lists: wordy phrases, words readers may not know, progress notes left in the text, spelling variants, commas in headings, and identifiers used as the subject of a figurative verb.
Paragraph and sentence lengths, repeated sentences, and names that appear only in figures are counted, not failed.

## Where files are kept

Each document has its own folder, `docs/explainers/<name>/` in the project you are working in, or a folder you name.
It holds `content.json` (the source), step ladder definitions if any, the term table if any, and the finished `<name>.html`.
A PDF, when you ask for one, is written next to the HTML file.
Nothing is kept anywhere else, and temporary files from checking are removed when the check ends.

## What it runs and connects to

- The code and documents you point to, and for public topics your agent's web search and web page reading, with only the names of the topic, standards, products, and vendors in searches
- `python3` to build and check the document
- A Chromium-based browser already on your computer (Chrome, Chromium, Edge, Brave, or Playwright's headless shell), in headless mode with a throwaway profile that is removed afterwards, to measure the layout and to print the PDF. Set `DIAGRAM_EXPLAINER_BROWSER` to choose one

The plugin installs nothing, and the document it writes loads nothing from the network.
