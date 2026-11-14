# Changelog

Releases of the secure-dotfile plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

## [0.3.0] - 2026-11-14

- `scan` lists passwords under names ending in `PASSWORD` or `PASSWD` without an underscore, such as `PGPASSWORD`, and in `_PASS`, `_PWD`, or `_PIN`, such as `MYSQL_PWD`. Before, these names were not read as secrets at all
- Values under those password names are listed at any length, and one shorter than 8 characters has the kind `short password`, with a suggestion in the report to make it longer. Before, every value shorter than 8 characters was skipped
- The report step, the README, and How it works say that a move takes a value out of the file, not out of the environment of the programs the shell starts, that a key with wide access is safer read only for the command that needs it, and that a key a team shares belongs in the team's password manager

## [0.2.0] - 2026-11-12

- Works in GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`, and the README shows how to install it there

## [0.1.0] - 2026-11-12

First public release.

- Lists API keys, tokens, and passwords written as literal values in zsh, bash, and fish startup files, `.envrc`, direnv `env.d` files, and the files they source, by name, location, kind, and length, without printing any part of a value
- Says whether each value is in the git history of its file, so you know which keys to rotate
- Moves only the items you pick into the macOS Keychain, reading each value back before changing the line to load it from the Keychain at shell startup
- Skips an item with a reason when its line changed, when the Keychain holds a different value under the same name, or when its value cannot be stored exactly
- Runs the shell's syntax check on every edited file and leaves the file as it was when the check fails
- Moves a secret in the chezmoi source file instead of the file chezmoi generates
- Starts when you mention a secret in your shell configuration, or when you call it, in Claude Code and in Codex

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/secure-dotfile--v0.3.0...HEAD
[0.3.0]: https://github.com/cardene777/agent-shuriken/releases/tag/secure-dotfile--v0.3.0
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/secure-dotfile--v0.2.0
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/secure-dotfile--v0.1.0
