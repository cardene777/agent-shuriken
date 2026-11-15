# Changelog

Releases of the feedback-loop plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- The skill's description is shorter, so every session that lists the installed skills reads less, and its instructions are shorter: the tables of exit codes for `where`, `check`, and `review`, the table of `open` options, and the list of files in the records folder are gone, since each command's messages say why it stopped and what to do, and `open --help` describes `--mode` and `--max-iterations`. The rules that keep the review independent are unchanged. An eval suite under `evals/` measures it with `claude plugin eval`, and no case scored lower
- When `git` cannot run, as with the macOS `/usr/bin/git` shim inside a sandbox, the script finds the repository by reading `.git` instead of stopping with "not inside a git repository". Linked worktrees still share the records of their main clone. Where `git` runs, nothing changes

## [0.1.1] - 2026-11-13

- The README shows the files a correction leaves: the case with the texts a file must and must not contain, the review of each round, and a rule in `rules.md`

## [0.1.0] - 2026-11-12

First public release.

- Records each correction you give the agent for its repository, with a hash of your words instead of the words, the corrected files, the skill that produced them, and the criteria a review must judge
- Runs the checks the agent picks together with texts a file must or must not contain, and counts a check only for the files exactly as they were when it ran
- Saves the verdicts of an evaluator that edits nothing, one line per criterion, sends a failing review back for another round, and asks you after 3 rounds whether to keep going, accept, or withdraw
- Closes a correction only when the checks passed on the final files, the last review passed every criterion on those same files, and the lesson is kept as a case for the file or a rule file
- Keeps the records in `~/.local/share/feedback-loop/`, readable only by you, or in a folder of the project you choose, and lets the worktrees of one clone share them
- Changes your project's agent instructions, a skill, or your user-level instruction file only after you agree, and sends nothing over the network
- Starts when you correct earlier output or when you call it, in Claude Code, Codex, GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/feedback-loop--v0.1.1...HEAD
[0.1.1]: https://github.com/cardene777/agent-shuriken/releases/tag/feedback-loop--v0.1.1
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/feedback-loop--v0.1.0
