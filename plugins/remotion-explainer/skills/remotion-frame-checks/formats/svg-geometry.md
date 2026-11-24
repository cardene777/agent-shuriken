# SVG geometry

This contract covers what a Remotion composition draws and moves as SVG: rough stand-ins, connectors, moving heads, frames, and badges.
It does not allow an SVG stand-in to replace finished art drawn for the subject.

A catalog search does not promise a finished SVG for every subject.
Use what it finds as grammar for form, composition, type, and motion, and when nothing fits, design a bespoke SVG.
Never type coordinates into the components by feel.

## One file holds the geometry

`storyboard/svg-geometry.json` in the Remotion project is the source of every SVG coordinate.
The components read the same geometry: they import the JSON, or the JSON is generated from the typed object the components import.
The same number is never written in the JSON and again in a component.

| Field | Holds |
|---|---|
| `schemaVersion` | `1` |
| `renderedFromGeometrySpec` | `true`, stating that the components read their coordinates from this file |
| `coordinateSystem` | The `width` and `height` of the component's own coordinates |
| `elements[]` | Every part on its own, not only the outer frame: `id`, `role`, `bounds` (`x`, `y`, `width`, `height`), and `ports[]`. Inner shapes, labels, badges, and moving heads each get an entry |
| `elements[].ports[]` | Named points on the outer edge where a connector touches: `id`, `edge` (`left`, `right`, `top`, or `bottom`), `x`, `y`, and an optional `tolerance` in pixels (1 by default) |
| `connectors[]` | `id`, `from` and `to` (`elementId` and `portId`), the `points` of the drawn path, the element IDs it must `avoid`, and an optional `endpointTolerance` |
| `clearanceRules[]` | Pairs `a` and `b` with the `minimum` gap in pixels, or `allowOverlap: true` for an overlap that is meant |
| `arrivals[]` | For each thing that moves to a target: `id`, the `frame` it arrives at, the `target` port, the `actualPoint` it reaches at that frame, a `tolerance`, and optionally its final `actualBounds` with the `targetZone` they must fit |
| `review` | `scales`, which include `1` and `0.5`, and at least three `frames`: an entry, an operation, and a settled frame |

## Connect to ports on the outer edge

A connector to a circle, a rectangle, a frame, or the visible part of a PNG ends on the outer edge of the target, never at its center.
Define the point where the path meets the edge as a port, and put the first and last points of the path on the ports.

| Target | Where the port sits |
|---|---|
| Circle | The radius away from the center, in the direction the line comes from |
| Rectangle | Where the line meets the edge of its bounds |
| Rounded rectangle | Where the line meets the straight part or the corner arc |
| PNG | On the edge of the visible pixels, not the edge of the canvas |

When a line passes behind its target on purpose, the visible part still ends on the outer port.
Hiding a line that pierces its target by drawing order does not pass.

## Bounds and appearance

- Keep the ratio of the `viewBox` and the drawn bounds, so the inner coordinates hold when a parent scales the component
- Use visible bounds that include the stroke, the shadow, and the line caps
- Check labels, badges, and inner shapes themselves; the parent frame's bounds do not cover them
- Derive frame bounds, label baselines, and badge insets of components of one family from shared values
- When lines blur at 50%, a circle looks like an oval, or the text and the picture swap in importance, go back to the still design

## Arrivals of moving things

A moving head, a progress line, an object, or a mask has an end port and an `arrivalFrame`, not only a start.
A progress value of 1 is not proof of arrival; compare the real position at the last frame with the target port.
When a progress line stops short of its background rail on purpose, give the stop its own meaning and its own target port, not an offset such as `width - 40` chosen by eye.

## Order of work

1. Choose the form, composition, type, and motion of the scene apart, as the scene layers contract describes
2. When no catalog entry fits, record why the design is bespoke in `storyboard/scene-design-layers.json`
3. Write `storyboard/svg-geometry.json` and render the still SVG from the same geometry
4. Run the `check-svg-geometry` check of this skill on the file until it passes
5. Look at the still frame at 100% and 50% for connections, gaps, optical centers, and strokes
6. Add the motion, and check the geometry again at the real entry, operation, and arrival frames
7. Keep bespoke SVG drawn for one subject in the project; only what a person approved and what fits other subjects becomes a catalog entry

## What the check reports

Each issue names its `rule` and the `element`, the pair `a/b`, or the `frame` it is about.

| Rule | Means |
|---|---|
| `schema-version`, `coordinate-system` | The file is not version 1, or has no positive width and height |
| `geometry-source` | `renderedFromGeometrySpec` is not `true` |
| `element-shape`, `duplicate-element` | An element lacks an id, a role, or positive bounds, or is listed twice |
| `port-shape`, `duplicate-port` | A port lacks an id, a point, or an edge, or is listed twice |
| `port-outside-element`, `port-not-on-edge` | A port is outside its element, or not on the edge it names |
| `unknown-port` | A connector or an arrival names a port that does not exist |
| `connector-points`, `connector-start`, `connector-end` | A connector has fewer than two points, or does not start or end on its port |
| `connector-avoid`, `connector-collision` | A connector avoids an unknown element, or crosses one it must avoid |
| `clearance-target`, `element-collision`, `element-clearance` | A rule names an unknown element, two elements overlap, or their gap is below the minimum |
| `arrival-frame`, `arrival-point`, `arrival-miss` | An arrival has no valid frame or point, or stops away from its target |
| `arrival-bounds`, `arrival-outside-target` | The final bounds or the target zone are missing, or the bounds leave the zone |
| `review-scales`, `review-frames` | The review lacks the 100% and 50% scales or the three frames |

A pass does not prove that the shapes mean the right thing, fit the subject, or look good.
Watching the video at normal speed and a person's approval of the still design stay.
