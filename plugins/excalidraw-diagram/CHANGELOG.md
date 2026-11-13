# Changelog

Releases of the excalidraw-diagram plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- The README opens with a diagram the plugin drew, and ships its `.excalidraw` file and spec in `assets/` so you can open it in the editor
- The SVG and PNG are drawn the way the Excalidraw editor draws the file: hand-drawn strokes that bow and are drawn twice, hand-drawn fills and hatching, and Excalidraw's own fonts, Excalifont and Nunito, embedded in the SVG
- A spec picks one of eight themes with `"theme"`: `sketch`, `hatch`, `pencil`, `soft`, `marker`, `dark`, `clean`, and `friendly`, all defined in `themes.json`. `build --theme` draws a spec in another theme without editing it
- Diagrams are drawn in the hand-drawn `sketch` theme unless the spec picks another; `"theme": "clean"` gives straight lines and system fonts as before. `style` and `fill` still work and now adjust the theme
- Arrows end 5 px from their shapes instead of 12 px, in filled arrowheads, boxes in one diagram widen toward one width so the columns line up, and arrows leaving one side of a box for different shapes share one line before they split
- Boxes have smaller rounded corners, and arrows and their labels are dark gray instead of black

## [0.1.0] - 2026-11-12

First public release.

- Draws architecture, flow, and entity-relationship diagrams from a JSON spec of nodes, edges, groups, and labels, flowing down or to the right, and sequence diagrams from participants and messages
- Computes every coordinate: tiers centered on one line and ordered so that fewer arrows cross (or kept in the listed order with `"order": "listed"`), zones around groups, arrows bound to their shapes and routed in horizontal and vertical stretches around other shapes and around arrows already drawn, and labels placed beside their arrows, clear of zone outlines
- Checks the scene before writing anything: overlapping shapes, shapes closer than 40 px, zones with less than 50 px around their nodes, text that does not fit or is not centered, text under 16 px, labels crossed by lines or sitting on a zone's outline, arrows through shapes, arrow ends inside or next to shapes without a binding, bent arrows that Excalidraw would draw as curves, and arrows on top of each other. It widens the spacing up to 2.25 times before it stops with the reasons, and warns about arrows that cross or touch without failing
- Draws each node's name in bold in the SVG and PNG
- Writes an `.excalidraw` file, an SVG drawn by the script itself, and a PNG when Chrome, Chromium, or Edge is already installed, and says when the PNG was skipped
- Converts a documented subset of Mermaid flowcharts and sequence diagrams into a spec, and stops with the line number on anything outside it
- Checks and re-exports `.excalidraw` files edited in the Excalidraw editor, and never replaces a file that it did not write or that changed since without `--replace`
- Downloads nothing, uses no network, and keeps no files besides the diagrams you ask for
- Starts when you ask for a diagram, or when you call it, in Claude Code, Codex, GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/excalidraw-diagram--v0.1.0...HEAD
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/excalidraw-diagram--v0.1.0
