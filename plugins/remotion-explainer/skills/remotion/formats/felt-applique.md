# Felt applique

`felt-applique` is a physical stage structure for placing the subject's own PNGs.
It is not CSS that imitates the surface of the PNGs, and it is not a three-column card interface.
Use it only when the user explicitly set `artDirection.stageTheme.id` to `"felt-applique"` in `production.json` and approved PNG art with `styleId: "felt-applique"` in the same production.

## Who makes what

| Maker | Makes |
|---|---|
| `png-asset-production` | The visible things that explain the subject, one object per PNG: the parcel, the label, people, containers, the sorter, records, and the variants of their states. No background, arrow, frame, label, or route is baked in |
| Remotion | The felt board, the pockets, the sewn labels, the arrows, the annotations, the masks, the camera, and the placement and handoff between scenes. It never draws the subject's diagrams, icons, cards, or documents in their place |

## `artDirection.stageTheme`

```json
{
  "id": "felt-applique",
  "assetStyleId": "felt-applique",
  "stagePrimitives": ["felt-board", "felt-pocket", "felt-tag", "felt-connector", "annotation"],
  "containerPolicy": "Pockets only in scenes where the subject holds, stores, or matches something",
  "labelPolicy": "Pockets of the same kind in one scene share the top offset and the baseline",
  "connectorPolicy": "Static relations only, never laid over the route of a moving object",
  "tracePolicy": "Only outlines made from accepted PNGs, and never an outline shown alone"
}
```

`stagePrimitives` is the list of what is allowed, not a list of what stays on screen in every scene.
Use `felt-board` only when the stage of the scene reads as keeping, exchanging, or matching.
A pocket is not a card for filling the screen, and not a frame for sorting the main objects.

## The look

- A deep teal or forest felt surface, slightly thick dark cut edges, a quiet stitch, and cream, mustard, and vermilion, each for one role
- A label is a small tag sewn onto a pocket. It never becomes a chapter number at the top left, a heading, or a tag floating on its own
- Pockets of the same kind use the same height, the same label offset, and the same padding. A tall PNG does not change the height of its pocket or label. A difference in height is allowed only when the meaning of the containment differs, such as a locker against a shelf of records, and the scene dossier states the reason
- A PNG is centered and set on its baseline by its visible bounds inside the pocket, never by the empty margin of the PNG canvas
- The background is a place that supports the scene's operation, not a display stand for materials. A permanent three-column board, a white void, stitching that is only decoration, and a constant swaying motion are not allowed

## Connectors and arrows

A felt connector has four layers: an outer edge, a fabric core, a stitch, and a sewn arrowhead.
Make one approved transparent PNG master first; every scene places, rotates, and reveals that master along its route.
Do not use an SVG `marker-end`, a thin bare stroke, a triangle head floating apart, a line hidden behind the art, or an arrow improvised per scene.

1. Put `sourceAnchor` and `targetAnchor` on the outer edge of the PNG's alpha visible bounds, or on a meaningful opening of a pocket's edge
2. Reserve a clearance lane for the route first, apart from the PNGs, the annotations, and the movement lanes. Keep at least 24 px of clearance around it, arrowhead included, in every frame
3. When the same object moves to show the cause, do not add a connector. Show one only at the moment a static relation or condition is first read
4. When a connector is hidden by what it points at, rebuild the route instead of hiding it with `z-index`. Any overlap fails

## Outlines

When an outline is used, use only the matching outline made from the accepted alpha PNG by `png-outline-tracing`.
Keep the order: trace for at least 1,400 ms, hold for reading for at least 200 ms, paint the PNG, then release the contour.
A loose curve invented by hand, a contour that does not match the object, and an outline shown alone with no PNG look like yarn or scribbles, and fail.

## In the scenes

- Do not set out the board, every pocket, and every PNG at the start of a scene. Let the viewer find the main object, then the evidence, then the result of the operation, then the handoff
- Between scenes, carry a document, an object, a container, or the focus. A change that only removes the board and shows the next board of the same shape fails
- Annotations sit near the main object and appear only to read a deadline, a quantity, an owner, a condition, or a result. They never stand in for a heading

## Review

- The stage theme and the PNG `styleId` are the same explicit choice
- Every subject object is an approved PNG, with no main diagram drawn in Remotion mixed in
- The scene dossier gives the subject's reason for containment for each pocket
- Pockets of the same kind share their top, height, and label baseline, and every exception has a reason
- No arrow repeats a moving object, the outer edge, core, stitch, and head of each arrow are one piece, and the clearance holds in every frame
- There is no naked outline, loose yarn, board without a use, permanent three-column grid, or slide-like chapter heading

## The check

Run the `check-stage-theme` check of this skill on `production.json` first, whenever a stage theme is chosen.
A record without `artDirection.stageTheme` passes.
A render is not a candidate while `out/review/stage-theme-audit.json` is missing, or while the containment, labels, and routes of each scene cannot be matched to real frames.
Each issue names its `rule` and the `field` it is about.

| Rule | Means |
|---|---|
| `stage-theme-id` | The theme is not `felt-applique` |
| `asset-style-id` | `assetStyleId` differs from the theme's `id` |
| `stage-primitives` | `stagePrimitives` lacks one of `felt-board`, `felt-pocket`, `felt-tag`, `felt-connector`, and `annotation` |
| `stage-policy` | `containerPolicy`, `labelPolicy`, `connectorPolicy`, or `tracePolicy` is missing or shorter than 12 characters |
| `static-assets` | `visual.staticAssets` holds no reviewed subject PNG |
| `asset-style` | A static asset's `styleId` is not the theme's `assetStyleId`; split the project instead of mixing art materials |
