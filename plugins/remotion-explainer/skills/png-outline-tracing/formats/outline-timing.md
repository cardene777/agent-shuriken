# Outline timing

The outline exists so the viewer can read how an object comes into being.
Never squeeze it into a flash.
This contract sets the minimum timing of a traced entrance, what to review, and `outline-handoff.json`, the record handed to the video and to the asset manifest.

## Minimum timing

At 30 fps, one important object takes at least this long:

| Stage | Minimum | Rule |
|---|---:|---|
| Contour draw | 42 frames, 1.4 s | Starts with no PNG paint at all |
| Contour hold | 6 frames, 0.2 s | The contour reaches 100% before the paint takes over |
| PNG paint | 21 frames, 0.7 s | Starts after the contour is complete and has held for 6 frames |
| Contour release | 12 frames, 0.4 s | Fades after the PNG paint is at least 75% complete |

The draw, the hold, and the paint make the entrance at least 2.3 seconds long.
Give a central or unfamiliar object longer.
The traces of several objects may overlap only when their silhouettes do not compete to be read.

## Parameters in the composition

Use this shape in the composition that draws the object:

```ts
const trace = interpolate(localFrame, [0, 42], [0, 1], {extrapolateLeft: "clamp", extrapolateRight: "clamp"});
const paint = interpolate(localFrame, [48, 69], [0, 1], {extrapolateLeft: "clamp", extrapolateRight: "clamp"});
const contourOpacity = interpolate(localFrame, [0, 42, 69, 81], [0, 1, 1, 0], {extrapolateRight: "clamp"});
```

The easing may differ, but never start the paint before the complete contour has held for 200 ms, never hide the line at the moment it becomes readable, and never approve the entrance from one still screenshot.

Draw the paths inline from the JSON the tracer writes, animating `strokeDasharray` and `strokeDashoffset`; the SVG file is for inspection and a fallback.
Follow the `timing-boundary` format of the `remotion-frame-checks` skill for paths that draw in, so the contour shows no pixel at a progress of 0.
The contour goes away once the PNG is settled, unless the art direction explicitly keeps it; it never becomes a generic box, an arrow, or a lasting UI border.

## The tracer

Run the `trace-alpha-outline` script of this skill on the accepted alpha PNG, never on its raw chroma source:

```bash
node <trace-alpha-outline> --input public/artwork/parcel.png \
  --svg public/artwork/parcel-outline.svg --data src/artwork/parcel-outline.json --mode main
```

| Option | Holds |
|---|---|
| `--input` | The alpha PNG, 8-bit and non-interlaced, of any color type |
| `--svg` | The SVG file to write |
| `--data` | The JSON file to write |
| `--mode` | `main`, the default, keeps the closed contour with the largest area; `all` keeps every closed contour, only when disconnected parts must each be drawn |
| `--threshold` | The alpha above which a pixel counts as solid, from 1 to 255, 210 by default |

It writes only the two files, and makes their folders when needed.
The SVG has the `viewBox` of the PNG and one unfilled `<path>` per contour, stroked in `currentColor`.
The JSON holds `schemaVersion` `1`, the `input` path, the `width` and `height`, the `threshold`, the `mode`, and `paths[]`, the same path data as the SVG.
Contours of fewer than 16 points are dropped, and each one kept is simplified with a tolerance of 1.6 px.
It exits 0 when it wrote both files, 1 when no closed silhouette is found, and 2 when it is called wrongly or cannot read the PNG.

## Frames to review

Render and look at four real frames of the entrance:

| Stage | Frame |
|---|---|
| `early-trace` | Early in the contour draw |
| `trace-70` | When the contour is 70% drawn |
| `partial-paint` | While the PNG paint is partly in |
| `settled` | After the object has settled |

Answer each of these questions with a yes before accepting the entrance:

1. Does the line describe the intended silhouette, not a background matte or a bounding rectangle?
2. Can a viewer read the silhouette before the paint fills it?
3. Is the paint kept apart from the trace long enough to feel built rather than flashed?
4. Is the settled object free of an unwanted lasting outline or UI treatment?
5. Are all four frames inside the safe margins and clear of other foreground elements?

## outline-handoff.json

Record the outline files and the real timing in `outline-handoff.json`, then put its path in `outlineHandoff` of the object's asset manifest, which `png-asset-production` writes and checks.
Paths are relative to the folder that holds the handoff.

| Field | Holds |
|---|---|
| `schemaVersion` | `1` |
| `assetId` | The asset's ID, as in its manifest |
| `assetManifest` | The path of the asset manifest |
| `alphaPng` | The accepted alpha PNG that was traced |
| `outline` | The `svg` and `data` files the tracer wrote, the `mode` and `threshold` it ran with, and the `pathCount` it kept |
| `fps` | The frames per second the timing counts in |
| `startFrame` | The composition frame where local frame 0 of the entrance falls |
| `timing` | `draw`, `hold`, `paint`, and `release`, each with the local frames `from` and `to` it runs between |
| `contourStays` | `false`, or `true` only when the art direction explicitly keeps the contour |
| `reviewFrames[]` | The four reviewed frames: `stage`, the local `frame`, and the rendered `image` |
| `review` | The five answers, `describesSilhouette`, `readableBeforePaint`, `paintSeparated`, `noLastingOutline`, and `framesSafeAndClear`, and `accepted` |

`examples/outline-handoff.json` shows a parcel's entrance at the minimum timing.
