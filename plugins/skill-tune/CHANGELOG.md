# Changelog

Releases of the skill-tune plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- The README says before its steps that measuring needs Claude Code and paid model runs, about 0.44 USD a run in its example, and that the agent shows the estimate before anything is spent
- `copy` warns when the plugin holds a file named `report.html`: `claude plugin eval` names its own report that way and keeps the agent out of such a plugin's folder, so the skill there can read none of its files. The `SKILL.md` says to rename the file before measuring
- The rules for writing cases say that the run's `HOME` is itself a git repository, so a fixture that runs a plugin script that names things by the repository runs it without `git` on the `PATH`. Measuring session-handoff saved its fixture's state under a project that the agent's run, where `git` fails, could not find, and three cases were run again on both sides
- The rules for writing cases say to name the grader that shows the skill started `skill-fired`, which `summary` and `compare` use to average the cost, and that for a skill that starts only when called by name it is the skill's first script call, since no `Skill` call shows in the trace. They also say that a line break in a `tool_used` input arrives as `\n`. Measuring session-handoff found both
- `clean` keeps a copy that `run` is evaluating, in this session or another one, and says so, and the skill removes only the copies it made, by name, instead of running `clean --all`. Before, a `clean --all` in another session removed a copy in the middle of its eval, and `run` stopped with `FileNotFoundError`
- The rules for writing cases say that a prompt asks for what the skill does, not for an exact edit, which the agent makes without the skill. A case that spelled out the line and its place cost a rerun when measuring learning-to-skill
- The rules for writing cases say that the eval sandbox does not let a process listen on a local port, and that `regex` graders are JavaScript regular expressions, without `(?m)`, `\A`, or `\Z`. Both cost a rerun when measuring init-project
- After a failed try, the skill tries again on a copy with a new label, since `copy --replace` also removes the earlier result
- The skill no longer asks how much to spend. It shows the cost estimate and measures, and `run` passes `--max-cost-usd` only when you name a limit
- `run` refuses a second `--case` instead of silently running only the last one, since `claude plugin eval` filters by one glob
- The rules for writing cases say that `tool_used` matches `input_match` against the input as JSON text, where a quote in a command arrives as `\"`
- The rules for writing cases say that a plugin script that runs `git` stops in the eval sandbox, where the macOS `/usr/bin/git` cannot create its cache file

## [0.1.0] - 2026-11-15

First public release.

- Lists the parts of a `SKILL.md` that repeat what its scripts and files already say, and agrees on cases and cuts with you
- Writes `claude plugin eval` cases into the plugin's `evals/` folder, each with a script that builds its starting state, following rules for what the eval sandbox allows and how to grade
- Copies the plugin to a private folder and runs `claude plugin eval` there with a cost ceiling you set, so your files do not change while it runs
- Estimates the cost of measuring from one run per case, and asks before any run
- Scores each case without the graders that only show the skill ran, compares the old and the new `SKILL.md` case by case, and prints the tool calls of a failing run
- Lists the skills in a repository by length, with how many eval cases each has
- Writes the cases in Claude Code, Codex, GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`, and measures in Claude Code, which has `claude plugin eval`

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/skill-tune--v0.1.0...HEAD
