---
name: techdebt
description: Measures technical debt in any git repository without downloading anything and ranks the files most worth fixing, by combining how often each file changes with its size, TODO and FIXME comments and their age, missing tests, long functions, and duplicated code. Writes one HTML report with the agent's notes on the top files. Use when the user asks where the technical debt is, what to refactor first, or for a health check of a codebase. It never changes code.
---

# Tech debt

This skill measures technical debt in a repository and ranks the files where fixing it pays off first: files that people keep changing, that are large, and that carry long functions, old TODO comments, duplicated code, or no tests.
It reads the code and the git history, and never changes a file in the project.

Talk to the user in the language they write in.
The commands and their output are the same in every language.

All commands live in `scripts/` next to this `SKILL.md`.
Below, `S` stands for the absolute path of that folder.
When running a command, put `S=<folder that contains this SKILL.md>/scripts` at the start of the same shell command.

This skill works in Claude Code, Codex, and other agents that read `SKILL.md`, such as GitHub Copilot CLI and Gemini CLI.
The report is written to `~/.local/share/techdebt/`, outside the project folder, so request approval for the commands when a sandbox blocks them, as Codex can.

## 1. Scan

Run it on the folder the user names, or on the current repository.
A folder inside a repository, such as one package of a monorepo, can be scanned on its own.

```bash
python3 "$S/techdebt.py" scan <folder>
```

It measures these things and prints a summary, the ranked files, and the paths of `scan.json` and `report.html`.

| Measure | How |
|---|---|
| Hotspots | Commits per file in the last 12 months (`--months N` changes the window) and non-blank lines |
| Markers | `TODO`, `FIXME`, `HACK`, `XXX`, and deprecation markers in comments, aged with `git blame` |
| Untested | Source files of 20 or more lines with no test file of a matching name, such as `foo.py` and `test_foo.py` |
| Long functions | Functions over 60 lines. Python is measured exactly with `ast`; brace languages (JavaScript, TypeScript, Go, Rust, Java, Kotlin, C, C++, C#, Swift, PHP, Solidity) by matching braces |
| Large files | Source files over 500 non-blank lines |
| Duplication | Blocks of 8 or more lines, ignoring whitespace, imports, and comments, that appear in two places |
| Unused dependencies | Names in the `dependencies` and `devDependencies` of each `package.json` that no import, require, config file, or `scripts` entry uses, counting a package that a used package needs as a peer, a plugin named by its short name, and `@types/<name>` of a used name. This is approximate. When `knip` ran, its findings are used instead |
| Installed tools | `knip` from `node_modules/.bin` and `ruff` from `.venv/bin` or `PATH`, only when already installed. Nothing is downloaded |

It skips dependencies, build output, lockfiles, minified files, and files whose first lines say they are generated.
Each file gets a score from 0 to 1: 40% hotspot, 20% long functions, 15% markers, 15% duplication, and 10% for having no test file, weighted by how often it changes.

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

Open `report.html` and show it to the user.
The page has a tab for the ranking and one per measure, an English and Japanese switch, and pages of 50 rows.
In the chat, give the top 3 to 5 files with the `why` and `action` of each, and the totals per measure.
Say which measures are approximate (function length outside Python, and unused dependencies found without `knip`) and which tools did not run and why.
For unused dependencies found by name, tell the user to check each one before removing it, since a package can be used in ways the search does not see, such as a name built at run time.

Do not change any code unless the user asks.
When the user asks to track the work, open issues only for the files they name, in the project's own tracker.
In an issue, quote a marker line only as `scan.json` or the report shows it, where text that looks like a key, a token, or a password is replaced with `***` and the home folder with `~`, and never copy it from the source file.
Read the line before quoting it, because text that the patterns miss stays as it is.

## When something fails

| What happens | What to do |
|---|---|
| Exit code 2 | `--months` is below 1, the notes name a file that is not ranked or leave a field empty, or `explain` ran before any scan. Fix it and run again |
| "run scan again" | The last `scan.json` was written by another version of techdebt. Run `scan` again, then `explain` |
| Exit code 3 | The folder does not exist |
| The folder is not a git repository | The scan still runs, without hotspots, ages, or the history part of the ranking |
| A tool shows "not run" | It is not installed in the project. Install it only if the user wants it; the scan never installs anything |

## Not covered

- Security findings and vulnerable dependencies
- Outdated dependencies, since checking them needs the package registry
- Code quality that only reading reveals, such as unclear names or wrong abstractions. The agent's notes cover what it sees in the top files
