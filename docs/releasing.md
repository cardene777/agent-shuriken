# Releasing

English · [日本語](releasing.ja.md)

This page explains the two kinds of version in this repository and how to release each one.

## Two kinds of version

| | Plugin version | Repository version |
|---|---|---|
| What it versions | One plugin | The marketplace as a whole: which plugin versions it offers, and the repository's own docs and scripts |
| Where it is written | `version` in both `plugin.json` files of the plugin | The newest release heading in the root `CHANGELOG.md` |
| Changelog | `plugins/<name>/CHANGELOG.md` | `CHANGELOG.md` |
| Tag | `<name>--v<X.Y.Z>`, for example `techdebt--v0.1.0` | `v<X.Y.Z>`, for example `v0.2.0` |
| Release assets | `<name>-<X.Y.Z>-skill.zip` and `<name>-<X.Y.Z>-plugin.zip` | None |

The agents decide whether a plugin has an update from its plugin version.
Raise it with every release of that plugin, or users keep the copy they have.

## Semantic versioning

| Bump | When |
|---|---|
| Major (`1.0.0` to `2.0.0`) | How a plugin is called or what it stores changes, so users have to adjust |
| Minor (`0.1.0` to `0.2.0`) | A plugin gains behavior, or the repository gains a plugin |
| Patch (`0.1.0` to `0.1.1`) | Behavior is fixed without anything new |

## While you work

Every pull request that changes something a user would notice adds a line under `## [Unreleased]` in the changelog of each plugin it touches.
Changes to the repository itself go under `## [Unreleased]` in the root `CHANGELOG.md`.
Versions are not changed in these pull requests.

## Release a plugin

1. Open a pull request that moves the plugin's `## [Unreleased]` entries into a new `## [X.Y.Z] - YYYY-MM-DD` section, leaves an empty `## [Unreleased]` above it, updates the link definitions at the end of the file, and sets `version` in both of the plugin's `plugin.json` files to `X.Y.Z`
2. Merge it, then check out `main` and pull
3. Run `bash scripts/release.sh <name> X.Y.Z --dry-run` and read the notes and assets it prints
4. Run `bash scripts/release.sh <name> X.Y.Z`

The script refuses unless it runs on an up-to-date `main` with a clean working tree, `scripts/check.sh` passes, and the version matches the plugin's changelog and manifests.
It then tags `<name>--vX.Y.Z`, pushes the tag, and creates a GitHub release with the changelog section as notes and two zips:

| Zip | Contents | For |
|---|---|---|
| `<name>-X.Y.Z-skill.zip` | The skill folder | Unzipping into a skills folder without the marketplace |
| `<name>-X.Y.Z-plugin.zip` | The whole plugin folder | Uploading to OpenAI's plugin directory |

## Release the repository

Release the repository after one or more plugin releases, or after a change to the repository itself.

1. Open a pull request that moves the root `## [Unreleased]` entries into a new `## [X.Y.Z] - YYYY-MM-DD` section with a `### Plugins` table of every plugin and its current version, and updates the link definitions
2. Merge it, then check out `main` and pull
3. Run `bash scripts/release.sh repo X.Y.Z --dry-run`, then `bash scripts/release.sh repo X.Y.Z`

The script checks that the `### Plugins` table matches the plugin versions on `main`.
It tags `vX.Y.Z` and creates a GitHub release that is marked as the latest one.
Plugin releases are never marked as the latest, so the repository release stays on top of the releases page.
