---
name: techdebt
description: Measures technical debt in a git repository without downloading anything, ranks the files most worth fixing, and writes an HTML report with notes on the top files. Use when the user asks where the technical debt is, what to refactor first, or for a health check of a codebase. It never changes code.
---

# Tech debt

This skill measures technical debt in a repository and ranks the files where fixing it pays off first: files that people keep changing, that are large, and that carry long functions, old TODO comments, duplicated code, or no tests.
It reads the code and the git history, and never changes a file in the project.

Talk to the user in the language they write in.
The commands and their output are the same in every language.

All commands live in `scripts/` next to this `SKILL.md`.
Below, `S` stands for the absolute path of that folder.
When running a command, put `S=<folder that contains this SKILL.md>/scripts` at the start of the same shell command.

The report is written to `~/.local/share/techdebt/`, outside the project folder, so request approval for the commands when a sandbox blocks them, as Codex can.

When the `page-design` skill is installed, follow the `structure` and `look` formats and the `report` page type of the `page-design` skill: open the `page-design` skill by name and read the files it names for `structure`, `look`, `report`, and `verify`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `page-design` skill is not installed, go on with the templates of this skill, without the formats of `page-design`.

## 1. Scan

Run it on the folder the user names, or on the current repository.
A folder inside a repository, such as one package of a monorepo, can be scanned on its own.

```bash
python3 "$S/techdebt.py" scan <folder>
```

It prints a summary, the ranked files, and the paths of `scan.json` and `report.html`.
It runs only tools that are already installed in the project, and never downloads or installs anything.
The plugin's `docs/how-it-works.md` describes each measure and how the score is made.

## 2. Explain the top files

The ranking says where the debt is; the user also needs to know what each file is and what to do first.
For the top files (up to 10), open the file and its recent history, then write one entry per file in the user's language.

| Field | What to write |
|---|---|
| `what` | One sentence on what the file does |
| `why` | Why it costs the team, from the measures: for example, which long function people keep changing, or which TODO has waited two years |
| `action` | The first concrete step, small enough for one pull request |

Save the entries as JSON, keyed by the file path exactly as the ranking shows it, and attach them.

```json
{"src/billing/invoice.py": {"what": "Builds invoices and applies discounts", "why": "Changed 31 times this year, and apply_discounts() is 140 lines with no test", "action": "Add a test for apply_discounts(), then split the tax step out of it"}}
```

```bash
python3 "$S/techdebt.py" explain --notes <path to the JSON> <folder>
```

If an entry names a file that is not ranked, or leaves a field empty, nothing is saved and the command exits with code 2; fix the entries it names and run it again.
Notes stay attached to the same files in later scans while those files are still ranked.

## 3. Report

When the `page-design` skill is installed, run its `verify` on the finished page: run the file it names for `verify` as a shell command, `python3 <that file> verify <path of report.html>`, fix each line it names in your notes with `explain`, and tell the user about any line it names in the frame of this skill's template.
Open `report.html` and show it to the user.
In the chat, give the top 3 to 5 files with the `why` and `action` of each, and the totals per measure.
Say which measures are approximate (function length outside Python, and unused dependencies found without `knip`) and which tools did not run and why.
For deprecated calls, say which of `ruff`, `semgrep`, and `eslint` looked for them; when none ran, say that the measure was not checked rather than that nothing was found.
For unused dependencies found by name, tell the user to check each one before removing it, since a package can be used in ways the search does not see, such as a name built at run time.

Do not change any code unless the user asks.
When the user asks to track the work, open issues only for the files they name, in the project's own tracker.
In an issue, quote a marker line only as `scan.json` or the report shows it, where text that looks like a key, a token, or a password is replaced with `***` and the home folder with `~`, and never copy it from the source file.
Read the line before quoting it, because text that the patterns miss stays as it is.

## When something fails

When a command exits with code 2 or 3, its message says what to fix; fix it and run the command again.
When the folder is not a git repository, the scan still runs; tell the user that the hotspots and the ages of markers are missing.
A tool that shows "not run" is not installed or not set up in the project. Install or configure it only if the user wants it.
A tool that shows "stopped with exit code" failed, for example on a config error. Tell the user the reason it quotes, and do not count its findings as zero.

## Not covered

- Security findings and vulnerable dependencies
- Outdated dependencies, since checking them needs the package registry
- Code quality that only reading reveals, such as unclear names or wrong abstractions. The agent's notes cover what it sees in the top files
