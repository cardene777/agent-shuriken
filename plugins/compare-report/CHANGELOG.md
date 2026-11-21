# Changelog

Releases of the compare-report plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- `musubi.json` follows the `structure` and `look` formats, the `report` page type, and `verify` of page-design in the design-formats plugin through musubi, as optional follows. When page-design is installed, the agent writes the report on them and runs page-design's verify on `report.html`; when the `musubi` command is installed, it runs `musubi check` first. Without design-formats, the report is written in the plugin's own template as before
- The report has two switches at the top right of its cover: English / 日本語 for the words of the switches, and Light / Dark for the colors. Until you choose, the colors follow your system, and your browser keeps your choice in its local storage under `compare-report-theme` and `compare-report-lang`. The PDF always prints in the light colors, without the switches
- The ranking gives the first choice, the alternative, and the fallback as a table with the conditions for each, and recommendations by use case as a second table. The guide's example rationale and its new rule on figures in text keep at most two figures between commas in one cell, so a report written from the guide passes page-design's verify on the first run
- The report uses the width of a wide screen. The body is up to 1200px wide, like page-design's report page, and the cover's text starts at the body's left edge, with the title running as wide as the body and the date right under the numbers; the PDF cover still fills the first page. Candidate cards sit three to a row, with a last row of two where three would leave one card alone, so two to six candidates fill every row. Scores and "Not scored" stay on one line, and columns of a few words, marked `short` in the guide's examples, stay on one line and only as wide as they need, so pricing, mitigation, and rationale columns share the rest by the length of their text. On a narrow screen those columns keep at least 11em, and a table that does not fit scrolls sideways inside its box. Bar chart names sit on the left in a column as wide as the longest name

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
