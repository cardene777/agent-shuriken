# Layout

A layout passes only when every element can be traced, not when the finished frame looks balanced as a whole.
Track the designed coordinates, the real bounds of each element, and the rendered image at the same frame numbers, so you can say where each element is and how many pixels lie between any two.

## One file holds the layout

`storyboard/layout-spec.json` in the Remotion project is the source of the layout.
The composition reads its coordinates from this file, or from the typed object that generates it.
The same number is never written in the JSON and again in a component.

| Field | Holds |
|---|---|
| `schemaVersion` | `1` |
| `canvas` | The video's `width` and `height` |
| `safeContent` | The bounds that every element stays inside |
| `subtitleSafeZone` | The bounds kept for captions; only elements with the role `caption` enter it |
| `elements[]` | `id`, `role` (such as `subject`, `annotation`, `frame`, `caption`), `anchor`, and `bounds` (`x`, `y`, `width`, `height`); optionally `allowOutsideSafe: true`, an `aspectRatio` for an element drawn as a video frame, and an `aspectRatioTolerance` (0.02 by default) |
| `clearanceRules[]` | Pairs `a` and `b` with the `minimum` gap in pixels, or `allowOverlap: true` for an overlap that is meant |
| `alignmentGroups[]` | `id`, `members`, a `tolerance` in pixels, and what they share: `sameY`, `sameBaseline`, `equalSize`, `equalHorizontalGap` |
| `routes[]` | The `id` and `bounds` of a path something moves along, and the elements it must `avoid` |
| `reviewFrames` | At least six frames per beat: entry, 25%, 50%, 75%, settled, and handoff |

## Track each element

Track the main subject, annotations, evidence labels, frames, badges, connectors, and moving heads by their own IDs.
Measure DOM elements with `getBoundingClientRect()` and SVG elements with `getBBox()` plus their stroke and shadow, and keep the visible bounds per frame in `out/review/layout-samples.json`.
A parent board's bounds do not hide a collision of its children.
An overlap that is meant has a clearance rule with `allowOverlap: true`; every other overlap is an issue.

## Frames to check

Check the entry, 25%, 50%, 75%, settled, and handoff frames of each beat, and the frames before, during, and after each scene boundary.
A video whose finished state alone is tidy does not pass.
Record the source, the target, the route, and the arrival of a moving thing on the same frame clock.
A line that happens to cross another line also counts as a collision.

## The check

Run the `check-layout` check of this skill on the file.
With `--audit-dir out/review` it also writes `layout-samples.json`, `collision-audit.json`, and `spatial-route-audit.json`, each tied to the SHA-256 of the layout file.

Each issue names its `rule` and the `element`, the pair `a/b`, the group, or the route it is about.

| Rule | Means |
|---|---|
| `schema-version`, `canvas`, `subtitle-safe-zone` | The file is not version 1, or the canvas or the subtitle zone is missing |
| `element-shape`, `duplicate-id` | An element lacks an id, a role, an anchor, or positive bounds, or is listed twice |
| `safe-content` | The safe area is missing, or an element leaves it without `allowOutsideSafe: true` |
| `subtitle-collision` | An element other than a caption enters the subtitle zone |
| `aspect-ratio` | An element drawn as a video frame has another aspect ratio |
| `clearance-target`, `collision`, `clearance` | A rule names an unknown element, two elements overlap, or their gap is below the minimum |
| `alignment-members`, `alignment-y`, `alignment-baseline` | A group has fewer than two known members, or their tops or baselines differ |
| `equal-width`, `equal-height`, `equal-gap` | Members of an equal-size group differ in size, or the gaps of a row differ |
| `route-shape`, `route-target`, `route-collision` | A route has no bounds, avoids an unknown element, or crosses one it must avoid |
| `review-frames` | Fewer than six review frames |

## The rendered image

Measure the rendered PNG too: the bounds of the pixels that stand out from the background, their center of weight, how much of the frame they fill, and the empty share on each side, kept in `out/review/composition-balance-audit.json`.
It adds what strokes, shadows, and dark text weigh; it does not replace the element checks.

## Debug frames

Apart from the normal video, render frames or a video with the element bounds, centers, anchors, baselines, the safe area, routes, and clearance issues drawn over them.
Never leave the debug overlay in a normal candidate.
Show the normal video to the person only when the layout file, the samples, the collision and route audits, and the image audit all belong to the current source and report no issue.
