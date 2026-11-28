# Changelog

Releases of the motion-explainer plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- A video is now built from a theme folder and a script by `build.py <theme-folder> <script.json> <page.html>`, which replaces `motion_explainer.py check` and `render` and the spec format. The theme holds the colors, the font, the characters with their faces, and its pictures with their anchors; the script holds the cast, the things on screen, the scenes of beats, and the figures. `references/theme.md` and `references/script.md` describe every field
- The skill ships `themes/pixel`, the four pixel-art bodies (robot, android, guide, and drone) with the faces wait, explain, surprised, and cheer, and `build.py` takes the theme folder of another plugin
- The things on screen can be a picture with states, things in rows joined by lines that stay in place while nodes pop in, things hung on a rail or standing in a tray on the line of an anchor, a captured page that zooms to one rect, and a small screen made of buttons, checks, slots, counters, and fields. The engine places the cast at the edges and the things between them so nothing overlaps
- Each beat says what happens: a line in a speech bubble, a face, a move, a thing that turns to another state, a picture that flies, a stamp, a pointer that taps, and slots that fill. A beat can fire an effect from the core of Sakuga VFX by finktheartist, bundled unmodified under the MIT license; a jump and reduced motion fire none
- Scenes with the same chapter make one step, and the bar under the video has one segment per step that plays the step from its start. The play button pauses and plays again from the same moment, and at a phone width the current line shows under the video
- `build.py` refuses an unknown field, character, face, thing, or state, and a picture that loads from outside or runs a script, naming the field. It runs through `uv run --with Pillow==13.0.0`, and without `uv` it says how to install it
- `capture.py scenes` saves the middle and the end of every scene, and `capture.py sheet` saves one picture with a frame every few hundred milliseconds; both print every error the page threw

## [0.1.0] - 2026-11-27

- The `motion-explainer` skill picks one running example that passes the whole mechanism, splits it into scenes that change one thing each, writes an art direction for the subject, and draws the narrator and every part as SVG in that direction, with every state of a drawing in one file
- `motion_explainer.py check` refuses a scene that names an unknown part or state, a scene without a line, a scene that changes nothing, a part placed past the edge of the stage, text wider than its limit, and art that would load from outside, run a script, restyle the page, or show a state its part does not declare, naming the field of each problem
- `motion_explainer.py render` writes one HTML page that loads nothing from the network: a player that plays the scenes once with play, pause, replay, and a chapter per scene that opens the scene at its end, marks only the parts that changed at the moment they change, and shows the narrator in the state of each scene with its line. A reader who asks for reduced motion sees each scene at its end without movement
- Figures under the player answer one question each, drawn from the same art: the stage at the end of a scene with numbered labels, the order of states joined by arrows, two cases side by side, and a table
- The page works at a phone width without sideways scroll, reads in light and dark, and names its colors and fonts after the keys of the shared theme file

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/motion-explainer--v0.1.0...HEAD
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/motion-explainer--v0.1.0
