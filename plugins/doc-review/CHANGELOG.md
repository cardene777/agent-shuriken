# Changelog

Releases of the doc-review plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

## [0.2.0] - 2026-11-12

- Works in GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`, and the README shows how to install it there

## [0.1.0] - 2026-11-12

First public release.

- Checks the form of Markdown documents with Python alone: heading levels, numbered headings, relative links and anchors made the way GitHub makes them, table rows, and unclosed code blocks, ignoring code and front matter and never opening web links
- Guesses each document's kind, such as a specification, design document, or decision record, so the content review checks what that kind needs
- Has the agent start a content reviewer and a form reviewer without the conversation, or review both aspects itself one after the other in Codex when sub-agents are not available
- Has the agent check every finding and fix the section or reject it with a reason, in one round
- Refuses to record a finding without a decision, a rejection without a reason, or a fix to a file that did not change
- Keeps a readable record of each review on your machine, readable only by you
- Starts when you ask for a review of a document, or when you call it, in Claude Code and in Codex

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/doc-review--v0.2.0...HEAD
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/doc-review--v0.2.0
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/doc-review--v0.1.0
