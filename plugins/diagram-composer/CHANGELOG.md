# Changelog

Releases of the diagram-composer plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

## [0.1.1] - 2026-11-23

- The test that scans the plugin for private names looks only for general shapes: a home folder path, a local agent configuration folder, and an issue reference

## [0.1.0] - 2026-11-19

First public release.

- Designs the diagram area of a slide in your own deck: one visual metaphor and the relationship to read, one meaning per connector, a separate lane only for a named return path, state, or responsibility, and relation labels in zones of their own at least 12 px from any line and its arrowhead
- `validate_diagram_geometry.py` checks the diagram's JSON geometry manifest before the slide is rendered. It rejects a label on or within 12 px of a line, including diagonal lines, a box outside its container's padding or in an unknown container, a line without a lane, and a diagram without a theme or metaphor, and names the slide of a multi-slide deck
- When you compare themes, it renders at least three full slides per theme with different diagram jobs and adds none of them to your deck until you pick one; when you ask for existing patterns, it renders the diagrams your deck already has, unmodified

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/diagram-composer--v0.1.1...HEAD
[0.1.1]: https://github.com/cardene777/agent-shuriken/releases/tag/diagram-composer--v0.1.1
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/diagram-composer--v0.1.0
