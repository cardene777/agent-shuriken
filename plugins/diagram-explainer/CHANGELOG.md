# Changelog

Releases of the diagram-explainer plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- Works in GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`, and the README shows how to install it there

## [0.1.0] - 2026-11-12

First public release.

- Agrees on the outline with you, with a figure planned for every section, before writing
- Keeps the content as JSON and builds one HTML file with a contents list that shows one section at a time, header tabs for several topics, a slide-in contents list on phones, and a print layout
- Draws every figure in the page: boxes and arrows in HTML, time bands, capped bars, bar charts, and period charts, and step ladders
- Shows the document's buttons and labels in English or Japanese, following the document's language
- Checks that the document loads nothing from the network, that every section has a figure or a stated reason, that captions, contents, and tables agree, and that the layout does not shift or overflow at several widths
- Applies full wording rules to Japanese documents, and term tables to documents in any language
- Prints the document to PDF with a browser already installed
- Starts when you ask for an explainer, or when you call it, in Claude Code and in Codex

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/diagram-explainer--v0.1.0...HEAD
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/diagram-explainer--v0.1.0
