# Changelog

Releases of the docs-publish plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

## [0.1.0] - 2026-11-12

First public release.

- Writes the public documentation of an open source project in five parts, a Quickstart, Concepts, an API reference, a Cookbook, and an FAQ, in English and a second language you pick, with one file per page in each language at the same path
- Lays out the docs folder from a plan you approve, with a starter page for every page in every language and a translation map, and never overwrites a file
- Records with `translated` which translations match the current source page, and refuses a translation that still has to-do notes or whose headings, code blocks, or table rows differ from its source
- Checks with `check` that every page has its counterpart, that no to-do note is left, that concept pages have a diagram and reference and task pages have code, that translations keep their source's structure and are not older than it, that every relative link resolves with the right letter case and stays in its language, that every page links its counterpart, and that every page can be reached from the index
- Adds and removes pages with `add` and `drop`, and never deletes a file
- Writes only inside the docs folder, keeps nothing outside the project, and commits nothing
- Starts when you ask for documentation for your project, or when you call it, in Claude Code, Codex, GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/docs-publish--v0.1.0...HEAD
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/docs-publish--v0.1.0
