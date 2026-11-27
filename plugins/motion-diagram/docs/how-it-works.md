# How Motion Diagram works

English · [日本語](how-it-works.ja.md)

This page explains how a spec is checked, how the parts are laid out, how the cards run, and how the export draws the video.
`skills/motion-diagram/scripts/motion_diagram.py` checks and renders with the Python standard library, and `export.sh` drives a headless browser with Node.js and joins the frames with ffmpeg.

## Checking the spec

`check` reads the spec in five passes. The first three run together, and the order and the counts are checked only when they find nothing, so each line it prints points at a field that is wrong on its own.

| Pass | What it checks |
|---|---|
| Fields | `version`, `lang`, the opening sentence, and the width of every text against its limit |
| Parts | Each `id` is unique and well formed, each `kind` is known, and `count` and `keep` sit only on the kinds that take them |
| Lines and boundaries | Each line names two parts, a drop goes from a check or a person to a bin, a line to a bin is a drop, a bin and an end send nothing, a source receives nothing, and no line touches a part beyond a boundary |
| Order | The main lines have no cycle, and each line back points to a part that comes earlier |
| Counts | When the spec has numbers, every source has `count`, every check and person has `keep` no larger than what it receives, and a part that sends to more than one part splits its cards by the `count` of its lines |

Width counts 2 for a CJK character and 1 for any other, so a Japanese name of 12 characters and an English name of 24 letters take about the same room on the page.
`render` runs the same passes and writes nothing when any of them fails.

## Laying out the parts

Each part gets a column from the longest path of main lines that reaches it, so it always sits after every part that sends it cards.
Lines back and drops do not count for the column, so a part that sends a line back or drops cards stays where the main flow puts it.

| Part | Where it sits |
|---|---|
| A source that starts the flow | The first column |
| A source that joins a later part | Beside that part's column, under the main row |
| A box, a check, a person, or an end | The column of its longest path, in the main row |
| A bin | Under the main row, across the columns of the parts that drop into it |
| A part outside a boundary | In the boundary below the picture, with no lines |

When two parts under the main row share a column, the later one goes one row lower.
The page runs this layout left to right, and top to bottom when it is narrower than 600 pixels or gives a column less than 92 pixels; then the main row becomes the left lane and the parts under it move to the right.

## Running the cards

The page runs at most 24 cards, so a picture of thousands of items stays readable.
The cards are split among the sources by their counts, each source keeping at least one, and leave in turn 0.16 seconds apart.
Each move from one part to the next takes 0.75 seconds.

At a check or a person, a card goes on or drops into the bin, and the cards that go on are spread evenly over the run, so the share that drops matches the share the spec drops.
A person's cards that go on are marked with a tick, and a line back pulses each time a card passes the part it starts from.
Each part's count rises as cards pass it and reaches the number of the spec when the last card arrives.
Cards that reach a part with no line onward stack inside its top-right corner, clear of its icon, name, and count and of the lines that start or end at its edges.

The run has no randomness: the same spec gives the same run in every browser and in the export.
When the run ends, nothing moves.
The replay button runs it again from the start, and a reader whose system asks for reduced motion sees the final counts without movement.

The run starts the first time the picture is on screen.
A page opened in a tab is on screen as it opens and runs on its first frame.
A page in a frame watches with an `IntersectionObserver`, which also works inside a frame of another origin, so in a frame further down another document, or in a hidden part of it, it runs when the reader reaches it.
Until then it shows the finished picture, so a page never shown prints finished.
With `#end` at the end of its address, the page shows the finished picture and never runs.
When printing starts, which the page learns from the `beforeprint` event or from the print media query, it stops a run in progress and draws the finished picture.
On paper it keeps its colors and leaves out the replay button and the switches.

## The page

The page is one HTML file: the template, the spec as data, and the dictionary of interface words in English and Japanese.
It loads no fonts, scripts, or images from the network.
Its colors are named after the keys of the shared theme file (`bg`, `surface`, `ink`, `sub`, `line`, `accent`, `accent-ink`, `accent-soft`, `bar`, `label`), and its fonts after `--sans` and `--mono`, so the `theme` command of `page-design` replaces them with the user's.
The skill reaches that command through `page-design/verify`, which `musubi.json` declares as an optional musubi follow with its version range `^2.0.0` and fingerprint.
It has light and dark colors of its own; the reader's system picks one, and the buttons in the header switch it, keeping the choice in the browser.

## Exporting

`export.sh` checks Node.js, renders the spec into a temporary folder, and finds what it needs in this order.

| Need | Where it comes from |
|---|---|
| `playwright-core` 1.65.0 | `~/.local/share/motion-diagram/node/`, installed there with `npm` the first time |
| ffmpeg | `ffmpeg` on `PATH`, else `ffmpeg-static` 5.3.0, installed the same way |
| A browser | The path in `MOTION_DIAGRAM_BROWSER`, Playwright's chrome-headless-shell, then Google Chrome, Chromium, Microsoft Edge, and Brave; when there is none, Playwright's headless browser is downloaded into Playwright's cache |

`export.mjs` opens the page in that browser at 1000 pixels wide and twice the pixel density, with every request other than the local file blocked.
The page opens in export mode, where it does not run on its own; the script asks it for the moment of each frame, 15 a second, and saves a picture of the page each time, then holds the last frame for one second.
ffmpeg joins the frames into an MP4 video (H.264) and a GIF 960 pixels wide with a palette made for it, and the last frame is saved as the PNG image.
The three files are moved to the folder you name, and the temporary folder is removed.
`--width` and `--fps` change the width and the frames a second.

## Where files go

| File | Place |
|---|---|
| The spec and the page | The folder you name, or next to the material |
| `<name>.mp4`, `<name>.gif`, `<name>.png` | The folder passed to `export` with `--out` |
| `playwright-core` and `ffmpeg-static` | `~/.local/share/motion-diagram/node/`, or `node/` of `$MOTION_DIAGRAM_DATA`, readable only by you |
| Playwright's headless browser, when downloaded | Playwright's own cache |
| The frames | A temporary folder, removed when `export` ends |
