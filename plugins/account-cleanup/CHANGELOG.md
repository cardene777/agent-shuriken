# Changelog

Releases of the account-cleanup plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

## [0.1.0] - 2026-11-12

First public release.

- Collects service names, URLs, and dates from 1Password, Bitwarden, and Chromium browsers without reading any passwords
- Tags likely-unused accounts with reasons and opens a candidate sheet where you mark each one OK or Keep
- Cancels subscriptions, removes payment methods, and deletes the accounts you approve, signing in from 1Password without showing credentials to the agent
- Drafts erasure requests under GDPR, CCPA, or Japan's APPI for services that cannot delete accounts
- Bundles the JustDeleteMe deletion directory
- The pages offer an English / 日本語 switch

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/account-cleanup--v0.1.0...HEAD
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/account-cleanup--v0.1.0
