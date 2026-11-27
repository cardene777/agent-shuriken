# Changelog

Releases of the motion-explainer plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- The narrator is now a cast of one to four pixel-art bodies the skill ships (robot, android, guide, and drone), each a sheet of four poses: wait, explain, surprised, and cheer. A spec names a body per cast member instead of drawing a narrator, and each scene names its `speaker` and `pose`; the speaker talks in a speech bubble beside it, large under the stage or next to the parts when the spec places it on the stage, and the rest of the cast waits
- A scene can name an effect: a burst behind a part and one sound-effect word next to it. Moved parts land in smoke puffs without any field. The effects come from the core of Sakuga VFX by finktheartist, bundled unmodified under the MIT license with its license and the commit it was copied from, and bursts are drawn behind the parts so they never hide a drawing. Reduced motion and opening a chapter fire no effect
- `motion_explainer.py check` refuses an unknown body, a body cast twice, more than four cast members, a cast member placed past the edge of the stage, an unknown speaker or pose, an effect on an unknown part or with an unknown word, and the old `narrator` field, naming the field of each problem

## [0.1.0] - 2026-11-27

- The `motion-explainer` skill picks one running example that passes the whole mechanism, splits it into scenes that change one thing each, writes an art direction for the subject, and draws the narrator and every part as SVG in that direction, with every state of a drawing in one file
- `motion_explainer.py check` refuses a scene that names an unknown part or state, a scene without a line, a scene that changes nothing, a part placed past the edge of the stage, text wider than its limit, and art that would load from outside, run a script, restyle the page, or show a state its part does not declare, naming the field of each problem
- `motion_explainer.py render` writes one HTML page that loads nothing from the network: a player that plays the scenes once with play, pause, replay, and a chapter per scene that opens the scene at its end, marks only the parts that changed at the moment they change, and shows the narrator in the state of each scene with its line. A reader who asks for reduced motion sees each scene at its end without movement
- Figures under the player answer one question each, drawn from the same art: the stage at the end of a scene with numbered labels, the order of states joined by arrows, two cases side by side, and a table
- The page works at a phone width without sideways scroll, reads in light and dark, and names its colors and fonts after the keys of the shared theme file

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/motion-explainer--v0.1.0...HEAD
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/motion-explainer--v0.1.0
