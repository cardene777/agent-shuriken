# Changelog

This file lists the releases of the repository as a whole, newest first.
Each plugin lists its own releases in `plugins/<name>/CHANGELOG.md`.
A repository release records which plugin versions the marketplace offered at that point, along with changes to the repository itself.
Versions follow semantic versioning, as [Releasing](docs/releasing.md) describes.

## [Unreleased]

### Added

- The repository has an icon in `assets/icon.svg`, shown at the top of the README

### Changed

- The plugin table in the README shows how to run each plugin in Claude Code and Codex

## [0.2.1] - 2026-11-12

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.1.1 |
| pc-tidy | 0.1.1 |

### Added

- Each plugin has an icon in `assets/icon.svg`, so it can be listed in OpenAI's plugin directory

## [0.2.0] - 2026-11-12

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.1.0 |
| pc-tidy | 0.1.0 |

### Changed

- Each plugin now lives in its own folder under `plugins/`, so installing a plugin copies only that plugin
- Each plugin has its own version, changelog, README in English and Japanese, license, and manifests for Claude Code and Codex
- The root README describes the collection instead of each plugin

### Added

- Docs for getting started, safety, creating a plugin, releasing, and publishing, in English and Japanese
- `scripts/release.sh` releases a single plugin or the repository

## [0.1.0] - 2026-11-12

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.1.0 |
| pc-tidy | 0.1.0 |

### Added

- First public release with the account-cleanup and pc-tidy plugins, installable from this marketplace in Claude Code and Codex

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/v0.2.1...HEAD
[0.2.1]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.2.1
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.2.0
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.1.0
