# Spatial layout

Use this contract whenever Remotion places approved PNG art.
It makes the coordinates, silhouettes, anchors, and frame timing something you can inspect, instead of something judged by eye.
Each PNG comes with its manifest, as the `asset-manifest` format of the `png-asset-production` skill describes.

## The geometry of each PNG

Each PNG has a geometry sidecar generated from its alpha channel: a pixel with an alpha above 16 counts as visible.
The sidecar records the size of the original canvas and the visible bounds, normalized to that canvas.

```ts
type AssetGeometry = {
  canvas: {width: number; height: number};
  visible: {left: number; top: number; right: number; bottom: number};
};
```

| Value | Comes from |
|---|---|
| Rendered canvas width | `placement.width` |
| Rendered canvas height | The rendered width and the aspect ratio of the original image |
| Collision box | `visible`, never the square canvas or a guess from `objectFit` |

## One function returns the layout of a frame

Use one root `absoluteFrame`.
Derive each chapter's local frame from it once, and expose a pure function `frameLayoutAt(absoluteFrame)` that returns:

| Part | Holds |
|---|---|
| PNG layers | The visible layers with their IDs, opacity, placement, visual bounds, and z order |
| Copy | The bounds of the title and the captions |
| Camera | The camera state |
| Connectors | The routes, derived from object IDs and edge names |

The JSX renderer and the review exporter both call this same function.
Do not keep a second list of coordinates in JSX.
The review exporter writes the `geometry-samples` and `continuity-samples` formats of the `remotion-explainer-review` skill from it.

## Connectors

A connector rule names the source object, the target object, the source edge, the target edge, and the visual grammar.
Resolve its end points from the outside of the alpha silhouette at render time.
The connector begins and ends outside the silhouette.
Sample its cubic path, plus the clearance of its arrowhead, against the bounds of every visible PNG, all copy, and the safe area.
A route is never hidden under an object to get around an overlap.

## Frame audit

Sample each chapter's entry, operation, and exit, every turning point of a motion, and each boundary before, during, and after.
A sample fails when any of these is true:

- Visual bounds leave the safe area
- Two PNGs intersect, unless they are a morph pair named as one
- A PNG intersects copy, including the title safe area and any caption visible at that frame; a low opacity does not excuse the overlap
- A route or an arrowhead intersects a PNG, the title, or a caption
- A visible object has no registered geometry
- A route is still visible after the operation it stands for has finished

## Chapter boundaries

At every chapter boundary, record an object that persists or a causal handoff, together with the camera state.
No chapter uses a timing range it cannot reach: every handoff ends before the root frame reaches the next chapter boundary.

## Staging order

Do not fill a chapter by showing every available PNG at once.
Its participants enter in causal order, while any declared story anchor stays continuous across the boundary.
When a caption would compete with a moving object, show it only after the operation clears.
The same placement function exposes the caption's visibility, so the audit sees it.

## Pitfalls

- `useCurrentFrame()` counts from the start of the enclosing `Sequence`; pass the root frame down where continuity across the whole video matters
- `getBoundingClientRect()` is scaled in the Studio and the Player; divide the measures by `useCurrentScale()` before comparing them with video coordinates
- Alpha bounds remove transparent padding, but do not follow a rotating silhouette exactly; reject with a conservative rotated axis-aligned box, then look at the real frame
- An arrow that looks good is still wrong when a control point of its cubic curve loops through an object; check the sampled path, not only its end points
