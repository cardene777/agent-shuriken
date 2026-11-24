# Paperboard

Write `paperboard.json` after the beat dossier and before writing the Remotion renderer for the video.
It records the visual language, the approved subject objects, the path of the focus, the drawing order, the annotation, and the handoff at each boundary of a video in the paper-scribe language of `formats/paper-scribe.md`.
The production record's `visual.paperScribe` keeps the same structure.

## The file

```json
{
  "version": 1,
  "visualLanguage": "paper-scribe",
  "rendererId": "paper-scribe-parcel-route-v1",
  "referenceStudy": {
    "transferableTraits": ["one continuous paperboard", "focus that travels for a reason", "structure before object paint"],
    "prohibitedTransfers": ["the reference's drawing hand", "the reference's templates", "generic title cards"]
  },
  "canvas": {"width": 1920, "height": 1080, "safeMargin": 108},
  "objects": [{
    "id": "labeled-parcel",
    "role": "carry",
    "assetId": "parcel-labeled",
    "businessRole": "The box the customer waits for, now carrying its route",
    "state": "Labeled, with lane 3 readable"
  }],
  "beats": [{
    "id": "route",
    "frames": {"start": 0, "end": 210},
    "stageMode": "inspection",
    "viewerQuestion": "What does the label tell the sorter?",
    "primaryObjectId": "labeled-parcel",
    "focus": {"from": {"x": 420, "y": 460, "zoom": 1}, "to": {"x": 980, "y": 500, "zoom": 1.25}, "reason": "To read the lane on the label"},
    "structures": [{"id": "lane-bracket", "kind": "bracket", "targetObjectId": "labeled-parcel", "purpose": "Ties the lane number to the parcel itself"}],
    "drawOrder": [
      {"kind": "paper-structure", "targetId": "lane-bracket", "startFrame": 0, "endFrame": 36},
      {"kind": "object-outline", "targetId": "labeled-parcel", "startFrame": 38, "endFrame": 82},
      {"kind": "object-paint", "targetId": "labeled-parcel", "startFrame": 90, "endFrame": 124},
      {"kind": "annotation", "targetId": "lane-number", "startFrame": 132, "endFrame": 164}
    ],
    "annotation": {"id": "lane-number", "targetObjectId": "labeled-parcel", "text": "Lane 3", "purpose": "route"},
    "operation": "The focus closes in on the label until its lane can be read",
    "readingHoldMs": 700,
    "handoff": {"objectId": "labeled-parcel", "toBeatId": "sort", "change": "The parcel is carried to the right as the main object of the sorting beat"}
  }]
}
```

The last beat uses `"toBeatId": "end"` and `"terminalState": true`.

| Field | Holds |
|---|---|
| `version` | `1` |
| `visualLanguage` | `paper-scribe` |
| `rendererId` | The composition made for this subject, named `paper-scribe-<subject>-v<n>`; there is no generic paper-scribe renderer to fall back on |
| `referenceStudy` | At least three `transferableTraits`, the abstract traits taken from the reference, and at least three `prohibitedTransfers`, what must not be taken. Optionally a `sourceUrl` of the reference the user studied |
| `canvas` | `width` 1920, `height` 1080, and a whole-number `safeMargin` of at least 72 |
| `objects[]` | At least two approved PNG subject objects, each with an `id`, a `role`, the `assetId` of its PNG, its `businessRole` in the subject, and its `state` |
| `beats[].frames` | The `start` and `end` frame, whole numbers, with the end after the start and not after the next beat's start |
| `beats[].stageMode`, `viewerQuestion` | The stage mode of `formats/composition-and-staging.md`, and the question the beat answers |
| `beats[].primaryObjectId` | The object whose state answers the question |
| `beats[].focus` | The camera's `from` and `to` (`x`, `y`, `zoom`) and the `reason` it moves; every beat after the first moves it |
| `beats[].structures[]` | Frames, underlines, brackets, relation lines, and local remarks drawn on the paper, each with an `id`, a `kind`, the `targetObjectId` it explains, and its `purpose` |
| `beats[].drawOrder[]` | The steps in the order they are drawn: `paper-structure`, `object-outline`, `object-paint`, then `annotation`, each with its `targetId` and its frames |
| `beats[].annotation` | Its `id`, the `targetObjectId`, the `text`, and its `purpose`, such as a condition, a quantity, a time, or a result |
| `beats[].operation` | What happens in the beat, never a fade, a slide, or a generic card |
| `beats[].readingHoldMs` | At least 500 |
| `beats[].handoff` | The `objectId` carried, the next beat (`toBeatId`), and the `change` |

Object and structure IDs start with a lowercase letter and use 3 to 80 lowercase letters, digits, and hyphens.

## The check

Run the `check-paperboard` check of this skill on the file.
Each issue names its `rule` and the `beat`, or the `field` when it is about the whole file or an object.

| Rule | Means |
|---|---|
| `version`, `visual-language`, `renderer-id`, `canvas` | The file is not version 1 or not `paper-scribe`, the renderer is not named for its subject, or the canvas is not 1920 by 1080 with a safe margin of at least 72 |
| `transferable-traits`, `prohibited-transfers` | The reference study lists fewer than three traits or fewer than three prohibited transfers |
| `objects`, `beats` | The file has fewer than two subject objects or fewer than two beats |
| `object-id`, `object-field` | An object's ID is not valid or is used twice, or it lacks its `assetId`, `businessRole`, or `state` |
| `beat-id`, `frame-range` | A beat's ID is not valid, or its frames are not whole numbers with the end after the start |
| `primary-object`, `annotation-target`, `handoff-object` | The primary, the annotation's target, or the handoff object is not a listed object |
| `structures`, `structure-id`, `structure-target`, `structure-field` | A beat has no paper structure, or a structure's ID is not valid or repeated, its target is not an object, or it lacks a kind or a purpose |
| `draw-order`, `draw-target` | The beat does not draw structure, outline, paint, then annotation, or a step's target is not its structure, object, or annotation |
| `operation` | The operation is missing or is a fade, a slide, a title card, a generic card, an automatic silhouette, or a generic arrow |
| `reading-hold` | `readingHoldMs` is not a whole number of at least 500 |
| `focus-change` | A beat after the first does not move the focus |
| `handoff-target`, `frame-order`, `handoff-relevance` | The handoff does not go to the next beat, the beat ends after the next one starts, or the next beat does not use the handoff object as its primary, its annotation target, or a structure's target |
| `terminal-handoff` | The last beat does not hand off to `end` with `terminalState: true` |
