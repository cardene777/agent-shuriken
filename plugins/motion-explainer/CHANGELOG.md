# Changelog

Releases of the motion-explainer plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

## [0.1.0] - 2026-11-27

- The `motion-explainer` skill picks one running example that passes the whole mechanism, splits it into scenes that change one thing each, writes an art direction for the subject, and draws the narrator and every part as SVG in that direction, with every state of a drawing in one file
- `motion_explainer.py check` refuses a scene that names an unknown part or state, a scene without a line, a scene that changes nothing, a part placed past the edge of the stage, text wider than its limit, and art that would load from outside, run a script, restyle the page, or show a state its part does not declare, naming the field of each problem
- `motion_explainer.py render` writes one HTML page that loads nothing from the network: a player that plays the scenes once with play, pause, replay, and a chapter per scene that opens the scene at its end, marks only the parts that changed at the moment they change, and shows the narrator in the state of each scene with its line. A reader who asks for reduced motion sees each scene at its end without movement
- Figures under the player answer one question each, drawn from the same art: the stage at the end of a scene with numbered labels, the order of states joined by arrows, two cases side by side, and a table
- The page works at a phone width without sideways scroll, reads in light and dark, and names its colors and fonts after the keys of the shared theme file

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/motion-explainer--v0.1.0...HEAD
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/motion-explainer--v0.1.0
