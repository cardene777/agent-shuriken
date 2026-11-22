# Changelog

Releases of the compare-report plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- `musubi.json` follows `look`, `report`, and `verify` of page-design at `^2.0.0`, the version that adds the pattern rules
- `musubi.json` follows the `structure` and `look` formats, the `report` page type, and `verify` of page-design in the design-formats plugin through musubi, as optional follows. When page-design is installed, the agent writes the report on them and runs page-design's verify on `report.html`; when the `musubi` command is installed, it runs `musubi check` first. Without design-formats, the report is written in the plugin's own template as before
- The report has two switches at the top right of its cover: the language switch, English / 日本語, for the words of the frame, such as the labels of the facts table and the buttons of the candidate list, and Light / Dark for the colors. Until you choose, the colors follow your system, and your browser keeps your choice in its local storage under `compare-report-theme` and `compare-report-lang`. The PDF always prints in the light colors, without the switches
- The ranking gives the first choice, the alternative, and the fallback as a table with the conditions for each, and recommendations by use case as a second table. The guide's example rationale and its new rule on figures in text keep at most two figures between commas in one cell, so a report written from the guide passes page-design's verify on the first run
- The report uses the width of a wide screen. The body is up to 1200px wide, like page-design's report page, and the cover's text starts at the body's left edge, with the title running as wide as the body and the facts table under it; the PDF cover still fills the first page. Candidate cards fill each row at 260px or wider. Scores and "Not scored" stay on one line, and columns of a few words, marked `short` in the guide's examples, stay on one line and only as wide as they need, so pricing, mitigation, and rationale columns share the rest by the length of their text. On a narrow screen those columns keep at least 11em, and a table that does not fit scrolls sideways inside its box. Bar chart names sit on the left in a column as wide as the longest name
- On screen, the candidates section is a candidate list beside the details of the candidate you press: its summary, type, users, score and rationale on every axis, and risks, with links to the previous and the next candidate. The address keeps the candidate as `#item-<key>`, so the back button returns to it, and `#item-<key>/full` shows the details alone. On a screen 860px wide or narrower, the list and the details take turns. The PDF shows the cards in order
- The cover gives the number of candidates, axes, and sources, the research date, and the author in a facts table. `check-report.py` fails when a number differs from the report, when the date is not written as YYYY-MM-DD, or when the author row holds only spaces
- Each candidate card has a key in `data-candidate`, and the table rows name their candidate by it. `check-report.py` fails on a card without a key, on two cards with one key, and on a row whose key no card has
- Risks are ordered most severe first, with an icon for each level, and the caution is titled with the risk itself. `check-report.py` fails on a caution titled only "Risk" or "Caution" and on a caution with `role="alert"`
- When page-design is installed, the agent draws the bar charts with dragon and runs `dragon embed`, which draws them into the report as SVG. `check-report.py` fails while a dragon block is left undrawn. Without Node.js, the report keeps the CSS bar charts, which show the numbers only, with the unit in the chart title
- The README's screenshot comes from a new report on the same four static site generators, made by the skill's steps, and shows the facts table on the cover, the build-time charts, and the candidate list on screen
- Tables have captions and keep their header row in view inside a box that scrolls. In the PDF, a table's caption and header row stay on the page of its first row, and the sentence under a section heading stays with what follows it. Tables of six or more columns and tables that scroll sideways are striped, and a table that scrolls sideways keeps its name column in view and shows a shadow on the side that has more to scroll. A chart or a figure opens larger in a dialog when you press it

## [0.5.0] - 2026-11-16

- The template is `templates/base.html`, so that no file in the plugin is named `report.html`; `new-report.sh` still writes the report as `report.html`
- When `to-pdf.sh` finds no browser, or the browser writes no PDF, it says to give the user `report.html`, which any browser prints to PDF
- The `SKILL.md` is shorter: the list of files, the overview of the steps, and what `to-pdf.sh` prints are gone, and the description says only what the skill does and when to use it
- The plugin has `claude plugin eval` cases under `evals/` that measure the skill, run by hand

## [0.4.0] - 2026-11-14

- The PDF contents give the page each section starts on, joined to the title by a dot leader, and every page but the cover shows its page number at the bottom. Pages are counted from the cover. The HTML keeps the contents without numbers. When the pages cannot be found, the PDF keeps titles only and `to-pdf.sh` prints one line saying why

## [0.3.0] - 2026-11-14

- The cover can show the author's name under the date. The agent asks for it together with the candidates, puts on the cover only a name you gave, never one from `git config` or your system, and keeps your answer in `author.txt` next to the reports to offer it first next time. With no name, the line is left out

## [0.2.1] - 2026-11-13

- The PDF is written readable only by you, like the HTML report. Before, it could be read by other users once copied out of the report's folder
- The README's screenshot comes from a new report on the same four static site generators with five axes, as the steps ask, and shows each page larger

## [0.2.0] - 2026-11-12

- Works in GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`, and the README shows how to install it there

## [0.1.0] - 2026-11-12

First public release.

- Lists candidates from web searches, and agrees on the candidates and on five to eight evaluation axes with you before researching
- Researches each candidate with a source and a date for every claim, and marks figures that are not published as not disclosed
- Writes an HTML report with a summary, a card per candidate, a section per axis, the risks, a scorecard with a recommendation, and the sources
- Checks that every score has a rationale and that the report loads nothing from the network, then prints it to PDF with a browser already installed
- Starts when you ask for a comparison, or when you call it, in Claude Code and in Codex

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/compare-report--v0.5.0...HEAD
[0.5.0]: https://github.com/cardene777/agent-shuriken/releases/tag/compare-report--v0.5.0
[0.4.0]: https://github.com/cardene777/agent-shuriken/releases/tag/compare-report--v0.4.0
[0.3.0]: https://github.com/cardene777/agent-shuriken/releases/tag/compare-report--v0.3.0
[0.2.1]: https://github.com/cardene777/agent-shuriken/releases/tag/compare-report--v0.2.1
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/compare-report--v0.2.0
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/compare-report--v0.1.0
