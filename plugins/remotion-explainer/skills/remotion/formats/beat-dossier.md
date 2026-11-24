# Beat dossier

Write `beat-dossier.json` before a renderer is created or changed.
It is the contract that carries the research and the storyboard into the Remotion layout.
No Remotion code is written until it passes its check.

## The dossier

```json
{
  "topic": "How a parcel reaches the door",
  "fps": 30,
  "beats": [
    {
      "id": "unsorted",
      "frames": {"start": 0, "end": 120},
      "stageMode": "aperture",
      "viewerQuestion": "Why can the parcel not leave the warehouse yet?",
      "primary": "parcel",
      "counterparts": ["warehouse-shelf"],
      "proofObject": "parcel:no-route",
      "before": "The parcel sits on the shelf with a blank label",
      "operation": "The scanner beam crosses the blank label and finds no route",
      "after": "The parcel needs a route before it can leave",
      "annotation": {"text": "No route yet", "target": "parcel", "frames": {"start": 66, "end": 114}},
      "attentionAction": "Only the blank label is lit while the shelf dims",
      "readingHoldMs": 700,
      "handoff": {"object": "parcel", "resultObject": "parcel", "toBeatId": "route", "change": "The parcel moves under the printer to get its route"}
    }
  ]
}
```

| Field | Holds |
|---|---|
| `topic`, `fps` | What the video explains, and its frame rate |
| `beats[].id` | The beat's ID, used once |
| `beats[].frames` | The `start` and `end` frame; beats do not overlap |
| `beats[].stageMode` | One of the stage modes of `formats/composition-and-staging.md`: `aperture`, `exchange`, `inspection`, `consequence`, or `handoff` |
| `beats[].viewerQuestion` | What the viewer is trying to understand now |
| `beats[].primary`, `counterparts` | The object whose state answers the question, and the actors or destinations that make the operation mean something |
| `beats[].proofObject` | The object and its state that prove the answer, written `<object>:<state>` |
| `beats[].before`, `operation`, `after` | The visible causal change |
| `beats[].annotation` | The exact words on screen, the object they are attached to (`target`), and the frames they are shown in |
| `beats[].attentionAction` | What changes in the frame, and why it earns attention |
| `beats[].readingHoldMs` | How long the motion stops so the viewer can read |
| `beats[].handoff` | The `object` carried, the `resultObject` it becomes, the beat it goes to (`toBeatId`), and the `change` |

## Rules

- `primary`, `proofObject`, `before`, `operation`, `after`, `attentionAction`, and `handoff` are concrete. An operation that is only `show`, `fade`, `display`, `slide`, `nice animation`, or `transition` is not an operation
- `annotation.target` names a visible primary, counterpart, or proof object, and its text says a state, a condition, a quantity, an owner, a time, or a result
- `handoff.toBeatId` names the next beat, and `handoff.resultObject` is the next beat's primary, a counterpart, or its proof object. Only the last beat may use `toBeatId: "end"` with `terminalState: true`
- Every beat has a `readingHoldMs` above zero
- The same object is not the primary of two beats in a row unless its state or the question changes
- A chapter title, a title card, or a generic piece of interface is never the `primary` or the `proofObject`

## Videos of five minutes or longer

A long video is not a short reference scene repeated.
Define these in `beat-dossier.json` and in the same layout source, and check them before rendering.

1. No repeated explanation. Each beat has its own `learningLayer`, a layer that updates what the viewer understands, such as the definition, where it is used, the conditions, the cost and time, who takes part, the record, the transfer, the keeping, the ending, the risks, and how it differs from the alternatives. Never repeat the same conclusion or visual job to fill time. A long video has at least six different layers, and a layer that comes back says what condition, evidence, or result changed since its last appearance
2. Arrival. A moving object has a `sourceZone`, a `targetZone`, a `routeAxis`, and an `arrivalFrame`. At the start, 25%, 50%, 75%, and arrival, check its distance from the axis, its crossing with another moving object, and its collisions with annotations, labels, and connectors. At the arrival frame the whole visible bounds of its PNG lie inside `targetZone`; stopping near the destination or on the lane does not count
3. Continuous boundaries. Neighboring beats share one carry object, or a stated source and result of a transformation. The exit of a beat and the entry of the next overlap by at least 12 frames, and the carry object's screen position or the camera target is continuous. Clearing the whole board, swapping in a board of the same shape, and a boundary that is only a fade or a cut fail
4. Balance. For every entry, turning, and exit frame, weigh together the bounds of the visible PNGs, the annotations, and the stage primitives they need. Unless the dossier records a one-sided composition on purpose, the center of weight lies between 40% and 60% across and between 38% and 62% down the safe content area. In an exchange with pockets on both sides, the weights of the two sides differ by at most 25%. An empty area is explained as the lane where the next move goes
5. Changing the composition. Even within one stage theme, when the `stageMode` of a beat changes, change at least one of the camera, the aperture, or the containment. Keep the style, but do not show the same large board with the same two pockets beat after beat

Keep the results in `out/review/spatial-route-audit.json` and `out/review/composition-balance-audit.json`, with the frame, the object, the source and target, the bounds, the center of weight, and the reason for any exception, as the `layout` format of the `remotion-frame-checks` skill describes.
One issue in either file means `revise`.

## The check

Run the `check-beat-dossier` check of this skill on the file.
When it passes, it also prints `dossierHash`, the SHA-256 of the file, which `formats/beat-review.md` cites.
Each issue names its `rule` and the `beat`, or no beat when it is about the whole file.

| Rule | Means |
|---|---|
| `beats` | The dossier has no beats |
| `beat-id`, `duplicate-id` | A beat has no ID, or its ID is used twice |
| `stage-mode` | `stageMode` is not one of the five modes |
| `beat-field` | `viewerQuestion`, `primary`, `proofObject`, `before`, `operation`, `after`, or `attentionAction` is missing or empty |
| `presentation-verb` | The operation is a presentation word such as `show`, `display`, `fade`, `slide`, `transition`, or "just moves", not a causal action |
| `generic-object` | The primary or the proof object is a title, a card, or another presentation element |
| `frame-range`, `beat-overlap` | The beat's `end` is not after its `start`, or the beat starts before the previous one ends |
| `reading-hold` | `readingHoldMs` is not above zero |
| `annotation-field`, `annotation-frames`, `annotation-target` | The annotation lacks its text or target, its frame range does not end after it starts, or its target is not the primary, a counterpart, or the object of the proof |
| `handoff-field` | The handoff lacks `object`, `resultObject`, `toBeatId`, or `change` |
| `handoff-target`, `handoff-timing`, `handoff-result` | `toBeatId` names no beat and is not a terminal `end`, the target beat starts before this one ends, or the target beat does not use `resultObject` |
| `repeated-primary` | The beat has the same primary and the same question as the beat before it |

The words of `presentation-verb` and `generic-object` are matched in English only.
