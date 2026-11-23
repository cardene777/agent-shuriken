# Changelog

Releases of the motion-diagram plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- The `motion-diagram` skill reads what the user wants explained, lists the parts of the picture and the lines between them, agrees on them with the user, and only then writes them as a JSON spec
- `motion_diagram.py check` refuses a spec with a line to an unknown part, a check or a person that keeps more cards than it receives, a line back to a part that does not come earlier, a line that crosses a boundary, lines that go round without a line back, or text wider than its limit (80 for the opening sentence, 24 for a part name, 200 for details, a CJK character counting 2), naming the field of each problem
- `motion_diagram.py render` writes one HTML page that loads nothing from the network. Each part sits one column after the parts that send it cards; cards run through the flow once when the page opens, drop out at each check in the proportion of its counts, and stop with each count at the number of the spec. A replay button runs them again, a reader who asks for reduced motion sees the final counts at once, and a pressed part shows its details and example
- The page runs left to right, and top to bottom when it is narrower than 600 pixels or too narrow for its columns. It reads in light and dark, names its colors and fonts after the keys of the shared theme file, and switches its interface words between English and Japanese from one dictionary
- `export.sh` writes one run of the picture as an MP4 video and a GIF, and its finished state as a PNG image. On first use it installs `playwright-core` 1.65.0, and `ffmpeg-static` 5.3.0 when no ffmpeg is on `PATH`, into `node/` of the data folder; without Node.js 20 or later it writes nothing and says how to install Node.js
