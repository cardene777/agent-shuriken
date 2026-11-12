# How Compare Report works

English · [日本語](how-it-works.ja.md)

This page lists the steps the agent follows, what goes in the report, what is checked before you see it, and where files are kept.
The procedure is in `skills/compare-report/SKILL.md`, and the pages it points to are in `skills/compare-report/references/`.

## The steps

| Step | Who | What happens |
|---|---|---|
| List candidates | Agent | Searches the web for the topic and lists ten to fifteen candidates with one line each |
| Agree on candidates | You | Keep, add, or drop candidates. Usually three to eight are compared |
| Choose axes | Agent | Suggests five to eight evaluation axes that fit the topic, such as performance, cost, reliability, ease of use, ecosystem, and risk |
| Agree on axes | You | Confirm or change the axes |
| Research | Agent | Collects official information, figures, adopters, and risks for each candidate, with a source and a date for every claim. Claude Code researches the candidates in parallel |
| Write | Agent | Fills the report template |
| Check | Agent | Runs the report check and fixes everything it reports, then rereads the report for fairness and consistency |
| Print | Agent | Prints the PDF and opens the report |
| Revise | You and the agent | You ask for changes, and the agent updates the HTML and the PDF |

## What is in the report

| Section | Contents |
|---|---|
| Cover | Title, what was compared, the number of candidates, axes, and sources, and the date |
| Summary | Why the comparison was needed, the top three picks, and five to seven findings |
| Candidates | A table of every candidate, and a card per candidate with a strength and a weakness |
| One section per axis | A table with a score and a rationale for every candidate, a bar chart when there are numbers, and a note on where the data came from |
| Risks | Each risk with its severity, a mitigation, and a rationale |
| Ranking | A scorecard of every score with an overall comment, and the first choice, alternative, and fallback with the conditions for each |
| Sources | Every source, numbered in the order it is cited, with the date it was read |

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

## Where files are kept

Each report has its own folder, `~/.local/share/compare-report/<topic>-<date>/`, holding `report.html` and `report.pdf`.
Set `COMPARE_REPORT_HOME` to keep reports somewhere else, or ask the agent to put a report in a folder you name.
The folder is readable only by you, and an existing report is never overwritten.

## What it runs and connects to

- Your agent's web search and web page reading, with only the topic and the names of candidates and vendors in searches
- `python3` to check the report
- A Chromium-based browser already on your computer (Chrome, Chromium, Edge, or Brave), in headless mode with a throwaway profile that is removed afterwards, to print the PDF. Set `COMPARE_REPORT_BROWSER` to choose one
- `open` on macOS or `xdg-open` on Linux to show you the report

The plugin installs nothing, and the report it writes loads nothing from the network.
