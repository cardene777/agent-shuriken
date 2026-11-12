# Changelog

Releases of the root-cause plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

## [0.1.0] - 2026-11-12

First public release.

- Records the symptom, reproduces it, and reads the code the reproduction runs through before forming any hypothesis
- Lists up to three hypotheses that an experiment could prove wrong, tests each one, and tries to refute it before trusting it
- Fixes only the cause, starting with a test that fails, and checks that undoing the fix brings the bug back
- Reports the symptom, the cause and its evidence, the fix, and other places the same cause affects
- Starts when you describe a bug, or when you call it, in Claude Code and in Codex

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/root-cause--v0.1.0...HEAD
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/root-cause--v0.1.0
