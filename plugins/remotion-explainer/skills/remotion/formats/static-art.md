# Static art

Static art is a supporting layer approved on its own.
It never chooses the video's visual premise, the type of a screen, the geometry of a cause, the layout, or a transition.

## The record

`visual.staticAssets[]` of `production.json` is the only way static art reaches the video.
`png-asset-production` writes the entries, after the composition rough is approved.
Each entry does all of the following.

- It points to one or more existing `visual.assignments[]`
- It says why a shape drawn natively in Remotion is not enough
- It names one approved PNG material style, `felt-applique` by default
- It carries the raw and transparent paths, the manifest path, the light, dark, and scene composites, and the agent's and the person's pass
- It declares `motionBoundary: "whole-image"`, the whole-image motions it allows, and the explanation work it must not do

| Field | Holds |
|---|---|
| `assetId` | The asset's ID |
| `assignmentIds` | The `visual.assignments[]` it serves |
| `styleId` | The approved PNG material style |
| `staticRoleReason` | Why a shape drawn in Remotion is not enough |
| `rawPng`, `alphaPng` | The raw PNG and the transparent PNG |
| `manifestPath` | The asset manifest that `png-asset-production` writes |
| `review` | `lightComposite`, `darkComposite`, `sceneComposite`, and the `agent` and `human` pass |
| `motionBoundary` | `"whole-image"` |
| `allowedMotion` | The whole-image motions allowed, from entering, translating, scaling, fading, and cropping |
| `forbiddenExplanationWork` | The explanation work the asset must not do, such as drawing a route |
| `outline` | The outline handoff below, or `null` |

The compiled Remotion project exposes the accepted entries as `project.staticArtAssets[]`.
A renderer uses an asset only through this collection, and never guesses or imports an asset of an earlier project.

## Outlines

Use `png-outline-tracing` only when the entrance of an object should be seen being built.
Its `outline` handoff has four reviewed frames and at least these timings.

| Step | Timing |
|---|---|
| The contour is drawn | 1,400 ms |
| The finished contour holds before the paint begins | 200 ms after it reaches 100%, so the paint starts at 1,600 ms at the earliest |
| The object settles | No earlier than 2,300 ms |
| The contour recedes | After the PNG is established, unless the approved art direction keeps it |

Draw the paths inline from the generated JSON.
The SVG file is for inspection and a fallback, never a permanent rectangle, arrow, or piece of interface.

## Rules for the renderer

- Add static art after the scene's native geometry of cause and its named anchors exist
- Place it through the bounds and anchor IDs of the project's layout source, such as `layout.ts`, and include it in the geometry and continuity samples
- A static asset may enter, translate, scale, fade, or crop only as declared. Never deform its inner parts
- When it disappears at a boundary, record why; when it stays, list it as `persistent` or `handoff`
- Delete it rather than forcing it into a scene where it does not help the current visual job
