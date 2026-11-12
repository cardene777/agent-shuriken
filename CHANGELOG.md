# Changelog

Every release is listed here, newest first.
Versions follow semantic versioning: a major bump breaks how a skill is called or what it stores, a minor bump adds behavior, and a patch fixes behavior.
Both skills share the repository version.

## [Unreleased]

## [0.1.0] - 2026-11-12

First public release.

### account-cleanup

- Collects service names, URLs, and dates from 1Password, Bitwarden, and Chromium browsers without reading any passwords
- Tags likely-unused accounts with reasons and opens a candidate sheet where you mark each one OK or Keep
- Cancels subscriptions, removes payment methods, and deletes the accounts you approve, signing in from 1Password without showing credentials to the agent
- Drafts erasure requests under GDPR, CCPA, or Japan's APPI for services that cannot delete accounts
- Bundles the JustDeleteMe deletion directory

### pc-tidy

- Lists work folders, apps, leftovers of removed apps, old tool versions, AI models, Docker images, and growing logs that have gone unused for 30 days
- Opens a pick page with a description and a recommendation for each item, and deletes only the items you pick
- Re-checks each item for uncommitted changes and running processes right before deleting it

### Repository

- Installs as a plugin in both Claude Code and Codex from the same marketplace
- Adds Codex metadata in `agents/openai.yaml`, so pc-tidy runs only when you call it in Codex too
- Pages offer an English / 日本語 switch

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/v0.1.0
