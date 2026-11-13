# Changelog

Releases of the techdebt plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- The README's summary and screenshot come from one scan of one sample repository, so their numbers agree

## [0.2.0] - 2026-11-12

- Works in GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`, and the README shows how to install it there

## [0.1.0] - 2026-11-12

First public release.

- Measures any git repository, or a folder inside one, with Python and `git` alone: changes per file in the last 12 months, TODO, FIXME, HACK, XXX, and deprecation markers in comments aged with `git blame`, source files without a matching test file, functions over 60 lines, files over 500 lines, and duplicated blocks of 8 or more lines
- Runs `knip` and `ruff` when they are already installed in the project or on `PATH`, and never downloads anything
- Ranks the files most worth fixing by combining the measures, weighted toward the files people change most
- Adds the agent's notes on what each top file is, why it costs the team, and the first step to fix it
- Writes one HTML report with a tab per measure, an English and Japanese switch, and pages of 50 rows, which loads nothing from the network
- Starts when you ask about technical debt, or when you call it, in Claude Code and in Codex

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/techdebt--v0.2.0...HEAD
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/techdebt--v0.2.0
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/techdebt--v0.1.0
