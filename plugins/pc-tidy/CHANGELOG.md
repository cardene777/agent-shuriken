# Changelog

Releases of the pc-tidy plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

## [0.1.1] - 2026-11-12

- Add an icon, used as the icon and the logo in the plugin directories

## [0.1.0] - 2026-11-12

First public release.

- Lists work folders, apps, leftovers of removed apps, old tool versions, AI models, Docker images, and growing logs that have gone unused for 30 days
- Opens a pick page with a description and a recommendation for each item, and deletes only the items you pick
- Re-checks each item for uncommitted changes and running processes right before deleting it
- Runs only when you call it, in Claude Code and in Codex
- The page offers an English / 日本語 switch

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/pc-tidy--v0.1.1...HEAD
[0.1.1]: https://github.com/cardene777/agent-shuriken/releases/tag/pc-tidy--v0.1.1
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/pc-tidy--v0.1.0
