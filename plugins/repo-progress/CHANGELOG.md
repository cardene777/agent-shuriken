# Changelog

Releases of the repo-progress plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

## [0.1.1] - 2026-11-13

- The README's one-repository sample lists all 13 waiting issues, as the script prints them, instead of only the first

## [0.1.0] - 2026-11-12

First public release.

- Lists every repository with your commits under the root folders in one table: linked worktrees, open issues and pull requests, uncommitted files, the time since the last commit, and an idle score that puts stalled repositories first
- Shows one repository's branches in progress with their pull requests, the branches and worktrees to clean up, and the open issues no branch points at
- Shows values that cannot be read from GitHub as unknown instead of 0, and then never marks numbered branches for clean-up
- Remembers the root folders with `--save-roots` in `~/.local/share/repo-progress/roots`, readable only by you, and prints the same values as JSON with `--json`
- Never changes a repository, a branch, a worktree, or an issue
- Starts when you ask what you were working on or which repositories have stalled, or when you call it, in Claude Code, Codex, GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/repo-progress--v0.1.1...HEAD
[0.1.1]: https://github.com/cardene777/agent-shuriken/releases/tag/repo-progress--v0.1.1
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/repo-progress--v0.1.0
