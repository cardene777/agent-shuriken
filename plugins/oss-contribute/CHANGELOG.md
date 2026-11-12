# Changelog

Releases of the oss-contribute plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

## [0.1.0] - 2026-11-12

First public release.

- Clones an outside project and lists the files that hold its rules: the contributing guide, the security policy, the templates, whether it asks for a sign-off or a CLA, what it says about AI tools, and the check commands its CI runs
- Runs the project's dependency, lint, format, and test commands in Docker containers that get the clone read-only, none of your environment, keys, or sign-ins, and no network during the checks
- Drafts issues, pull requests, comments, and follow-up pushes with a translation for you, and flags credentials, home folder paths, email addresses, co-author lines, and missing sign-offs without printing any credential
- Records your approval as a fingerprint of the title, body, commits, and diff, refuses to send a draft that changed after the approval, checks the target again right before sending, and never sends a draft twice
- Keeps security problems out of public issues and pull requests, and points to the project's private reporting channel instead
- Keeps clones and drafts in `~/.local/share/oss-contribute/`, readable only by you, until you clean them up, and never touches your fork on GitHub
- Starts when you ask to send a fix to a project you name, or when you call it, in Claude Code, Codex, GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/oss-contribute--v0.1.0...HEAD
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/oss-contribute--v0.1.0
