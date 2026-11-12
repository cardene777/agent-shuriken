# Changelog

This file lists the releases of the repository as a whole, newest first.
Each plugin lists its own releases in `plugins/<name>/CHANGELOG.md`.
A repository release records which plugin versions the marketplace offered at that point, along with changes to the repository itself.
Versions follow semantic versioning, as [Releasing](docs/releasing.md) describes.

## [Unreleased]

### Changed

- Every plugin works in GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`, and the READMEs and Getting started show how to install, run, update, and remove them there

## [0.5.0] - 2026-11-12

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.1.1 |
| compare-report | 0.1.0 |
| diagram-explainer | 0.1.0 |
| doc-review | 0.1.0 |
| pc-tidy | 0.1.1 |
| root-cause | 0.1.0 |
| secure-dotfile | 0.1.0 |
| techdebt | 0.1.0 |

### Added

- The secure-dotfile plugin, which moves the API keys and tokens written into shell startup files into the macOS Keychain without the agent seeing any value
- The techdebt plugin, which ranks the files most worth fixing by combining how often they change with their size, old TODO comments, missing tests, long functions, and duplication
- The doc-review plugin, which reviews a specification, design document, or README once with two reviewers that do not share the conversation, then fixes each finding or records why not

## [0.4.0] - 2026-11-12

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.1.1 |
| compare-report | 0.1.0 |
| diagram-explainer | 0.1.0 |
| pc-tidy | 0.1.1 |
| root-cause | 0.1.0 |

### Added

- The diagram-explainer plugin, which writes an explainer with a figure drawn in every section as one HTML file

### Changed

- The publishing page lists root-cause and compare-report, and `scripts/check.sh` fails when a plugin is missing from its tables

## [0.3.0] - 2026-11-12

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.1.1 |
| compare-report | 0.1.0 |
| pc-tidy | 0.1.1 |
| root-cause | 0.1.0 |

### Added

- The compare-report plugin, which researches the candidates for a choice and writes an HTML and PDF comparison report
- The root-cause plugin, which finds the cause of a bug from evidence before fixing it
- The repository has an icon in `assets/icon.svg`, shown at the top of the README

### Changed

- The plugin table in the README shows how to run each plugin in Claude Code and Codex
- The marketplace describes the collection as careful plugins for Claude Code and Codex, no longer only housekeeping ones
- The safety page says that the pick page applies to plugins that delete or cancel something, and the rules for kept files to plugins that keep files

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

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.5.0
[0.4.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.4.0
[0.3.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.3.0
[0.2.1]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.2.1
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.2.0
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.1.0
