# Changelog

This file lists the releases of the repository as a whole, newest first.
Each plugin lists its own releases in `plugins/<name>/CHANGELOG.md`.
A repository release records which plugin versions the marketplace offered at that point, along with changes to the repository itself.
Versions follow semantic versioning, as [Releasing](docs/releasing.md) describes.

## [Unreleased]

### Changed

- The link check in `scripts/check.sh` no longer reads links inside fenced code blocks, so a README can show a sample page with its own relative links

## [0.7.0] - 2026-11-13

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.2.0 |
| compare-report | 0.2.0 |
| diagram-explainer | 0.2.0 |
| docs-publish | 0.1.0 |
| excalidraw-diagram | 0.1.0 |
| feedback-loop | 0.1.0 |
| init-project | 0.1.0 |
| learning-to-skill | 0.1.0 |
| oss-contribute | 0.1.0 |
| portman | 0.1.0 |
| repo-progress | 0.1.0 |
| secure-dotfile | 0.2.0 |
| session-handoff | 0.1.0 |
| techdebt | 0.2.0 |

### Added

- The repo-progress plugin, which shows every repository you work on in one table, with worktrees, open issues and pull requests, uncommitted files, and the ones that have stalled first, without changing anything
- The learning-to-skill plugin, which writes a lesson from a session into the instruction files your agents read, such as AGENTS.md, CLAUDE.md, GEMINI.md, Copilot's instructions, or a skill's SKILL.md, once and in the place that reaches the right agents, only after you approve the diff
- The feedback-loop plugin, which turns a correction you give the agent into fixed files, a review by an evaluator that edits nothing that passes every criterion, and a check or rule that keeps the mistake from coming back
- The session-handoff plugin, which writes a short message to paste into a new agent session and saves the options already rejected, the current phase, delegated work, and things not to do for the project, refusing anything that looks like a secret
- The docs-publish plugin, which writes the public documentation of an open source project in five parts, Quickstart, Concepts, API reference, Cookbook, and FAQ, in English and a second language you pick, and checks that every page has its translation and every link resolves
- The portman plugin, which keeps one registry of the localhost ports each project uses, shows what holds each port right now, suggests free ports that avoid common defaults, finds collisions, and writes a project's ports to `.env.local` and a Docker Compose override after you approve
- The init-project plugin, which sets up a project for local work: a free local port that no other project set up with it gets, a Docker setup for Node and Python web apps and Foundry and Hardhat local chains, and env files linked to 1Password with `op://` references, each file shown before it is written
- The oss-contribute plugin, which prepares a fix for an outside open source project by that project's own rules, runs its checks in a container, and sends only the exact draft you approve
- The excalidraw-diagram plugin, which draws architecture, flow, sequence, and entity-relationship diagrams as Excalidraw files laid out by a script and checked for overlaps, crowded spacing, and labels on lines, with SVG and PNG copies

### Removed

- The root-cause, doc-review, and pc-tidy plugins are no longer offered in the marketplace, because they are no longer maintained here. Copies already installed keep working, and their past releases and tags stay available

## [0.6.0] - 2026-11-12

### Plugins

| Plugin | Version |
|---|---|
| account-cleanup | 0.2.0 |
| compare-report | 0.2.0 |
| diagram-explainer | 0.2.0 |
| doc-review | 0.2.0 |
| pc-tidy | 0.2.0 |
| root-cause | 0.2.0 |
| secure-dotfile | 0.2.0 |
| techdebt | 0.2.0 |

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

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/v0.7.0...HEAD
[0.7.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.7.0
[0.6.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.6.0
[0.5.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.5.0
[0.4.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.4.0
[0.3.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.3.0
[0.2.1]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.2.1
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.2.0
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.1.0
