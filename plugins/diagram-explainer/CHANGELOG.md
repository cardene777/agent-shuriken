# Changelog

Releases of the diagram-explainer plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- When design-formats is installed, the document takes the user's colors and fonts from a theme file, `.design-theme.json` at the root of the repository or else `~/.design-theme.json`: after the build, the agent runs page-design's `theme --keys light,dark,font.sans,font.mono` on the finished page. `assets/doc.css` names its base colors after the keys of the theme file, adding `--surface` and `--sub`, and mixes the other shades (`--panel-2`, `--line-2`, `--rule`, `--ink-2`, `--ink-3`, `--ink-faint`, `--track`) from them with `color-mix()`, so a page without a theme looks as before. `musubi.json` follows `page-design/theme` at `^1.0.0` as an optional follow
- `musubi.json` follows `look`, `document`, and `verify` of page-design at `^2.0.0`, the version that adds the pattern rules
- `musubi.json` follows the `structure` and `look` formats, the `document` page type, and `verify` of page-design in the design-formats plugin through musubi, as optional follows. When page-design is installed, the agent writes the document on them and runs page-design's verify on the finished page; when the `musubi` command is installed, it runs `musubi check` first. Without design-formats, the document is built from the plugin's own template as before
- The document header holds a language switch (English / 日本語) for the interface text, such as the contents button, the previous and next buttons, the PDF menu, and chart units, and a light and dark switch. The document's own text stays in the language it was written in, and printing always uses light colors. The browser remembers the reader's choices in its local storage under `diagram-explainer-lang` and `diagram-explainer-theme`
- The interface words in English and Japanese live only in `assets/ui.json`. The page is written with them and carries them, and the language switch reads them from the page, so the words shown before and after a switch cannot disagree
- Figures read cleanly at desktop and phone widths. The number at the start of a caption is its own element with a gap after it, so Japanese captions keep the space that `despace.py` used to remove. Step ladders sit in the middle of their frame with the names of the lines going back beside them. Charts are drawn at the width of their frame, so their text keeps its size; a chart or ladder that would need text under 12px scrolls sideways inside its frame, with the cut edge faded and a line under it that says so. Grid lines no longer cross chart text, bars are opaque and keep their contrast in light and dark colors, the capped bar's limit line is drawn over the parts, boxes in the sample's first figure take the height of their own text, and Japanese headings in the page and the ladder no longer get the wide letter spacing meant for English capitals
- The default Japanese names of a step ladder's line going back and of its note put no space between the step number and the words after it
- The page follows the page-design patterns. Every document has a header band with the title, the page tabs when there are two or more pages, the switches, the Save PDF button, and a `?` button that opens the help in a dialog; the date above the contents list is gone
- A facts table under the first title gives the time the document describes and, from the new `facts` field, the specification and version it follows and the date its sources were read
- The page tabs are a tab list that the arrow keys, Home, and End move through, and the chosen tab scrolls into view. On a phone, opening the contents list moves the focus into it and closing it moves the focus back
- Every figure has an enlarge button that opens it at twice its size in a dialog, and closing the dialog returns the focus to the button
- Tables need a `caption`, take a `num` list of number columns aligned right, and scroll in a box that keeps the header row and the first column in view. Boxes that scroll sideways are named regions that the keyboard can reach
- Cards are a list in a grid of columns at least 260px wide, colored only for a state. A warning note is a framed box with an icon and needs a `title`; other notes are titled paragraphs. `--critical` and `--critical-soft` replace `--bad`
- A `details` block cannot hold another, `check.py` fails a block of fewer than 10 lines, a summary that says only "More" or "Details", and a section with three or more warnings, printing opens every block, and a run of four or more blocks gets buttons that open or close them all
- Chart view buttons mark the chosen view with `aria-pressed`, and `render.py` refuses more than five views. The PDF button is named "Save PDF"
- The PDF of a document with charts no longer ends with a blank sheet. The hidden chart tooltip stayed in the page and started a sheet of its own after the last section
- The README's screenshot comes from the bundled English sample, so it can be taken again from the repository, and shows the header band with the switches and the help button, the facts table, and the enlarge button on a figure, at desktop and phone widths

## [0.2.2] - 2026-11-16

- The skill's description is under half as long, so every session that lists the installed skills reads less, and its instructions are shorter. The rules on searches, sources, the network, the outline, and editing are unchanged. An eval suite under `evals/` measures it with `claude plugin eval`, and every case kept its score

## [0.2.1] - 2026-11-13

- The README's requirements name Playwright's headless shell, which the layout check and the PDF already use when it is installed

## [0.2.0] - 2026-11-12

- Works in GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`, and the README shows how to install it there

## [0.1.0] - 2026-11-12

First public release.

- Agrees on the outline with you, with a figure planned for every section, before writing
- Keeps the content as JSON and builds one HTML file with a contents list that shows one section at a time, header tabs for several topics, a slide-in contents list on phones, and a print layout
- Draws every figure in the page: boxes and arrows in HTML, time bands, capped bars, bar charts, and period charts, and step ladders
- Shows the document's buttons and labels in English or Japanese, following the document's language
- Checks that the document loads nothing from the network, that every section has a figure or a stated reason, that captions, contents, and tables agree, and that the layout does not shift or overflow at several widths
- Applies full wording rules to Japanese documents, and term tables to documents in any language
- Prints the document to PDF with a browser already installed
- Starts when you ask for an explainer, or when you call it, in Claude Code and in Codex

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/diagram-explainer--v0.2.2...HEAD
[0.2.2]: https://github.com/cardene777/agent-shuriken/releases/tag/diagram-explainer--v0.2.2
[0.2.1]: https://github.com/cardene777/agent-shuriken/releases/tag/diagram-explainer--v0.2.1
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/diagram-explainer--v0.2.0
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/diagram-explainer--v0.1.0
