# Changelog

Releases of the chainome-diagram plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- The diagram takes its colors, fonts, text size, and corners from your theme file, `.design-theme.json` at the root of the repository or `~/.design-theme.json`, in the format design-formats uses. The new `diagram-theme.py` reads it, refuses an unknown key or a bad value with each key named, and without a theme file the diagram keeps your project's own look
- The skill and its listings describe the diagrams in general words, and the display name is now Blockchain Diagram

## [0.1.0] - 2026-11-22

- The `chainome-diagram` skill guides the design of animated React and SVG diagrams that explain blockchain mechanics: a scene model before rendering, one active phase and one moving path at a time, state changes shown as transient badges where they happen, and the prose kept in a separate panel
- It checks protocol structure, with an ERC-20 transfer gate that keeps the function, the storage write, and the event inside the contract boundary, and reviews desktop and mobile screenshots until no material issue remains
- When the concept or a simplification of the protocol is unclear, it asks the user in the chat, which works in every agent

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/chainome-diagram--v0.1.0...HEAD
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/chainome-diagram--v0.1.0
