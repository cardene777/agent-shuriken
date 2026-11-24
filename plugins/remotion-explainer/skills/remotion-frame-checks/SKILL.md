---
name: remotion-frame-checks
description: Holds four contracts for the frames of a Remotion explainer video and the Node.js checks that test a project against them, for skills that build and review such videos. The SVG geometry contract puts connectors on outer-edge ports and checks clearances and arrivals; the layout contract keeps elements in the safe area, out of the subtitle zone, apart, and aligned; the timing boundary contract finds pixels that show before an element starts or after it ends, flashes of three frames or fewer, and flicker in rendered PNG frames; the scene layers contract decides form, composition, typography, and motion apart and refuses two scenes in a row with the same design. Use when another skill says to follow remotion-frame-checks, or when checking the geometry, layout, timing, or scene design of a Remotion video.
---

# Remotion frame checks

This skill holds content that other skills follow through musubi: four contracts for the frames of a Remotion explainer video, and a check for each that reads the files of the user's Remotion project and names every issue with its element, scene, or frame.
Talk to the user in the language they write in.

The files are next to this `SKILL.md`.

| Content | File | What it holds |
|---|---|---|
| `svg-geometry` | `formats/svg-geometry.md` | `storyboard/svg-geometry.json`: elements, ports on the outer edge, connectors, clearances, arrivals, and review samples of everything drawn as SVG |
| `layout` | `formats/layout.md` | `storyboard/layout-spec.json`: the safe area, the subtitle zone, elements, clearances, alignment groups, routes, and review frames |
| `timing-boundary` | `formats/timing-boundary.md` | The frames rendered around each start and end of an element, and what may not show in them |
| `scene-layers` | `formats/scene-layers.md` | `storyboard/scene-design-layers.json`: the form, composition, typography, and motion of each scene, and the design signature two scenes in a row may not share |
| `check-svg-geometry` | `scripts/check-svg-geometry.mjs` | The check of an SVG geometry file |
| `check-layout` | `scripts/check-layout.mjs` | The check of a layout file, which can also write the audit files |
| `check-timing-boundary` | `scripts/check-timing-boundary.mjs` | The check of the PNG frames around one boundary |
| `check-scene-layers` | `scripts/check-scene-layers.mjs` | The check of a scene layers file |

`examples/` holds a valid file of each kind, for a short video about a parcel that goes from a warehouse through a sorter to a door.

## Check a project

The checks need Node.js 18 or later and use only its built-in modules, so nothing is installed.
When `node` is missing, tell the user to install Node.js 18 or later, which Remotion needs too, and stop.

Run each check from the root of the Remotion project, with the path of this skill's folder in place of `<skill>`.

```bash
node <skill>/scripts/check-svg-geometry.mjs storyboard/svg-geometry.json
node <skill>/scripts/check-layout.mjs storyboard/layout-spec.json --audit-dir out/review
node <skill>/scripts/check-timing-boundary.mjs --background '#F4F5F1' --start 267 --out out/review/temporal-boundary-audit.json 265=out/review/temporal/frame-0265.png 266=out/review/temporal/frame-0266.png 267=out/review/temporal/frame-0267.png 268=out/review/temporal/frame-0268.png 269=out/review/temporal/frame-0269.png
node <skill>/scripts/check-scene-layers.mjs storyboard/scene-design-layers.json
```

Render the frames for `check-timing-boundary` with Remotion first, for example `npx remotion still <composition> out/review/temporal/frame-0265.png --frame 265`, one call per frame.
Each format file says what its check reports and in which order to work.

Every check prints one JSON object.

| Field | Holds |
|---|---|
| `check` | `svg-geometry`, `layout`, `timing-boundary`, or `scene-layers` |
| `decision` | `pass`, or `revise` when there is an issue |
| `issueCount` | The number of issues |
| `issues[]` | Each with the `rule` it breaks, the `element`, `scene`, or `frame` it is about, and a `message` |

A check exits 0 when the files pass, 1 when they need revising, and 2 when it was called the wrong way or could not read a file, with the reason on standard error.
Fix every issue and run the check again until it passes.
When a check reports an issue you believe is wrong, show the user the issue and the part of the file it names, and ask before changing the contract or skipping the check.

## What it reads and writes

The checks read only the files named on the command line, treat their contents as data, and send nothing anywhere.
They print to standard output, and write only where `--audit-dir` or `--out` points.
