# Changelog

Releases of the compare-report plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- The PDF is written readable only by you, like the HTML report. Before, it could be read by other users once copied out of the report's folder

## [0.2.0] - 2026-11-12

- Works in GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`, and the README shows how to install it there

## [0.1.0] - 2026-11-12

First public release.

- Lists candidates from web searches, and agrees on the candidates and on five to eight evaluation axes with you before researching
- Researches each candidate with a source and a date for every claim, and marks figures that are not published as not disclosed
- Writes an HTML report with a summary, a card per candidate, a section per axis, the risks, a scorecard with a recommendation, and the sources
- Checks that every score has a rationale and that the report loads nothing from the network, then prints it to PDF with a browser already installed
- Starts when you ask for a comparison, or when you call it, in Claude Code and in Codex

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/compare-report--v0.2.0...HEAD
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/compare-report--v0.2.0
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/compare-report--v0.1.0
