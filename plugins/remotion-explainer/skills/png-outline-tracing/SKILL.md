---
name: png-outline-tracing
description: Turns one approved transparent PNG object into SVG outline paths and a JSON record that a Remotion composition draws in before the PNG paint appears, and records the timing in outline-handoff.json. Reads the PNG with Node.js's own zlib, so nothing is installed. Use when an object of an explainer video should visibly be drawn before it is painted, or when remotion or remotion-explainer-production asks for an outline handoff. Never traces a whole scene or stands in for original art.
---

# PNG outline tracing

This skill turns one accepted alpha PNG into a drawing layer.
The PNG stays the original art; the SVG outline is only its entrance.
It is kept apart from `png-asset-production`, so that an image nobody reviewed never enters a video only because it can be traced.
Talk to the user in the language they write in.

The files are next to this `SKILL.md`, and other skills follow two of them through musubi.

| Content | File | What it holds |
|---|---|---|
| `outline-timing` | `formats/outline-timing.md` | The minimum timing of a traced entrance, the frames to review, and the fields of `outline-handoff.json` |
| `trace-alpha-outline` | `scripts/trace-alpha-outline.mjs` | The tracer, which writes the SVG and the JSON paths of one alpha PNG |

`examples/outline-handoff.json` shows a valid record.

## Inputs

Accept only an approved PNG of one object with transparency, with its entry in the asset manifest that `png-asset-production` writes and checks.
Refuse a raw chroma source, a poster, a full frame, or an object that should be drawn by Remotion itself.

## Trace an object

1. Read `formats/outline-timing.md`.
2. Confirm that the alpha PNG has a clean edge without a fringe and a clear silhouette. Use `--mode main`, the default, for the largest readable silhouette; use `--mode all` only when disconnected parts must each be drawn.
3. Run the tracer with Node.js 18 or later; it needs no package:
   `node <skill>/scripts/trace-alpha-outline.mjs --input public/artwork/parcel.png --svg public/artwork/parcel-outline.svg --data src/artwork/parcel-outline.json --mode main`
   Here `<skill>` is the path of this skill's folder. It exits 0 when it wrote both files, 1 when it found no closed silhouette, and 2 with the reason on standard error when it was called wrongly or cannot read the PNG.
4. Look at the SVG over the alpha PNG. Refuse an outline that takes in leftover background, cuts through the object, makes an accidental rectangle, or holds too much detail to read at the size the video shows. Fix the alpha source or choose a narrower trace instead of editing hundreds of path points by hand.
5. In the composition, draw the paths of the JSON inline with `strokeDasharray` and `strokeDashoffset`, and keep the SVG file for inspection. The PNG paint starts only after the outline is complete and has held for 200 ms, as `formats/outline-timing.md` sets.
6. Render four frames: early trace, 70% trace, PNG paint partway, and the settled object. Check that no part of the outline shows at a progress of 0:

Write in the `timing-boundary` format of the `remotion-frame-checks` skill: open the `remotion-frame-checks` skill by name and read the file it names for `timing-boundary`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-frame-checks` skill is not installed, do not start: tell the user that `remotion-frame-checks` is missing and how to install it, then stop.

7. Record the paths and the real timing in `outline-handoff.json`, and add its path to the object's entry in the asset manifest.

When `node` is missing, tell the user to install Node.js 18 or later and stop.

## Output

`*-outline.svg`, `*-outline.json`, `outline-handoff.json`, and the four frames.
An outline is temporary unless the art direction keeps it on purpose, and it never becomes a generic box, an arrow, or a lasting border.

## What it reads, writes, and sends

It reads only the PNG named with `--input`, and writes only the files named with `--svg` and `--data`, making their folders when needed.
It runs nothing but Node.js and sends nothing anywhere.
