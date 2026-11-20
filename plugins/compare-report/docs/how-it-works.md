# How Compare Report works

English · [日本語](how-it-works.ja.md)

This page lists the steps the agent follows, what goes in the report, what is checked before you see it, and where files are kept.
The procedure is in `skills/compare-report/SKILL.md`, and the pages it points to are in `skills/compare-report/references/`.

## The steps

| Step | Who | What happens |
|---|---|---|
| List candidates | Agent | Searches the web for the topic and lists ten to fifteen candidates with one line each |
| Agree on candidates | You | Keep, add, or drop candidates. Usually three to eight are compared. In the same question, give the name to put on the cover, or choose none |
| Choose axes | Agent | Suggests five to eight evaluation axes that fit the topic, such as performance, cost, reliability, ease of use, ecosystem, and risk |
| Agree on axes | You | Confirm or change the axes |
| Research | Agent | Collects official information, figures, adopters, and risks for each candidate, with a source and a date for every claim. Claude Code researches the candidates in parallel |
| Write | Agent | Fills the report template |
| Check | Agent | Runs the report check and fixes everything it reports, then rereads the report for fairness and consistency |
| Print | Agent | Prints the PDF, with the page of each section in the contents, and opens the report |
| Revise | You and the agent | You ask for changes, and the agent updates the HTML and the PDF |

## What is in the report

| Section | Contents |
|---|---|
| Cover | Title, what was compared, the number of candidates, axes, and sources, the date, and the author's name when you gave one |
| Summary | Why the comparison was needed, the top three picks, and five to seven findings |
| Candidates | A table of every candidate, and a card per candidate with a strength and a weakness |
| One section per axis | A table with a score and a rationale for every candidate, a bar chart when there are numbers, and a note on where the data came from |
| Risks | Each risk with its severity, a mitigation, and a rationale |
| Ranking | A scorecard of every score with an overall comment, and the first choice, alternative, and fallback with the conditions for each |
| Sources | Every source, numbered in the order it is cited, with the date it was read |

In the PDF, each contents entry is joined by a dot leader to the page its section starts on, and every page but the cover shows its page number at the bottom.
Pages are counted from the cover, which is page 1, the same way a PDF viewer counts them.
The HTML keeps the contents without numbers.

Scores run from S (outstanding) to D (weak).
A candidate that cannot be judged fairly on an axis, because no comparable figure exists, is marked as not scored instead of guessed.

## How the data is kept honest

- Figures that are not published are written as "Not disclosed"
- Figures measured under different conditions are noted, and not drawn on one chart as if they were comparable
- Vendor claims and independent measurements are kept apart
- Every claim cites its numbered source

## What is checked before you see it

`scripts/check-report.py` fails the report until all of these hold:

- No placeholder from the template is left
- Nothing is loaded from the network: no script, stylesheet, web font, or image from a URL
- The summary, candidates, risks, ranking, and sources sections exist and are filled, with at least one section per axis
- Every table with a score or a risk label has a rationale column
- Every score letter matches its grade, every risk label has a level, and every bar has a width from 0% to 100%
- The sources section links at least one page
- The author line on the cover is either empty, and so hidden, or holds a name, not only spaces

## The report page and its switches

The agent writes the report into the template of the skill. Paths in the table are relative to `skills/compare-report/`.

| File | What it holds |
|---|---|
| `templates/base.html` | The report page, with its styles, its light and dark colors, and the script of the switches inside |
| `musubi.json` | The optional follows of `page-design/structure`, `page-design/look`, `page-design/report`, and `page-design/verify` through musubi: for each, the version range `^1.0.0`, the fingerprint of the content at the last check, and `"optional": true` |

The report has two switches at the top right of its cover: English / 日本語, which changes the words of the switches, and Light / Dark, which changes the colors.
The report's own text stays in the language it was written in.
Until you choose, the colors follow your system, and your browser remembers your choice in its local storage under `compare-report-theme` and `compare-report-lang`; nothing is sent anywhere.
The PDF always prints in the light colors, without the switches.

- When the page-design skill of the design-formats plugin is installed, the agent reads its `structure` and `look` formats and its `report` page type, which `musubi.json` follows as optional follows. After `scripts/check-report.py` passes, it runs page-design's `verify` on the report and fixes each line it names in the text it wrote until it prints `ok`. It reads nothing else from other plugins
- When the `musubi` command is installed, the agent runs `musubi check` before reading them and stops if it fails; the check skips the follows with a warning when design-formats is not installed. When a followed content changes, `musubi check` refuses compare-report until its fingerprint is checked again
- Without page-design, the report is written in `templates/base.html` alone. Nothing in the plugin requires design-formats

## Where files are kept

Each report has its own folder, `~/.local/share/compare-report/<topic>-<date>/`, holding `report.html` and `report.pdf`.
Set `COMPARE_REPORT_HOME` to keep reports somewhere else, or ask the agent to put a report in a folder you name.
The folder is readable only by you, and an existing report is never overwritten.

The author's name you gave for the cover is kept in `author.txt` in the same place, `~/.local/share/compare-report/` or `COMPARE_REPORT_HOME`, readable only by you.
An empty file means you chose no name.
The agent offers the saved answer first for the next report, and removes the file when you ask it to forget the name.
The name comes only from your answer, never from `git config`, your system's user name, or your account.

## What it runs and connects to

- Your agent's web search and web page reading, with only the topic and the names of candidates and vendors in searches
- `python3` to check the report
- A Chromium-based browser already on your computer (Chrome, Chromium, Edge, or Brave), in headless mode with a throwaway profile that is removed afterwards, to print the PDF. Set `COMPARE_REPORT_BROWSER` to choose one
- `python3` to find the page numbers. `scripts/toc-pages.py` reads the page of each section from the destinations the browser writes into the first PDF, then writes a hidden copy of the report with the numbers, `.print-*.html`, next to it. The copy is printed and removed, and the new PDF replaces the first only when every section is still on the same page. When the pages cannot be found, the first PDF is kept with titles only, and one line says why
- `open` on macOS or `xdg-open` on Linux to show you the report

The plugin installs nothing, and the report it writes loads nothing from the network.
