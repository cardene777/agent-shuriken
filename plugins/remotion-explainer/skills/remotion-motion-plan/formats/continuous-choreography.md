# Continuous choreography

A long explainer is not a row of small demos, one per scene.
It is one video in one space, where the main objects, the point of view, and the cause and effect pass from beat to beat.
Continuity here does not mean the same background; it means that the result of one beat reads as the input of the next.

## The plan

Write `storyboard/continuous-choreography-plan.json` in the Remotion project before the rough cut.

| Field | Holds |
|---|---|
| `schemaVersion` | `1` |
| `persistentSubjects` | The objects followed through the whole video, the ones that carry its cause and effect, such as a parcel, a request, a document, or a key |
| `scenes[].id` | The scene's ID |
| `scenes[].role` | `summary` for the scene that sums the video up; left out otherwise |
| `scenes[].subjects` | The objects the scene shows |
| `scenes[].entryFrom` | The `subject` and the `state` the scene takes over from the scene before it; left out in the first scene |
| `scenes[].operation` | What actually happens to the object: it unfolds, opens or closes, comes apart, is matched, changes shape, is gathered, is hidden, is moved, or switches state |
| `scenes[].exitTo` | The `subject` and the `state` handed to the next scene, and `becomes` when the subject turns into another object; left out in the last scene |
| `scenes[].cameraRelation` | `push-in`, `pull-out`, `orbit`, `follow`, or `reframe` |
| `scenes[].continuityMode` | `object-transform`, `camera-follow`, `container-reveal`, `spatial-reframe`, `state-carry`, or `return-route` |
| `scenes[].primaryAxis` | The main direction things move in: `horizontal`, `vertical`, or `none` |

## Rules

1. The `exitTo` of one scene and the `entryFrom` of the next name the same subject, or the object it `becomes`. Clearing the screen or swapping the background is not a handoff
2. At least half of the scenes show a persistent subject. A scene does not open with everything finished on screen; each part appears when the explanation needs it
3. Moving sideways or up and down is used only as a route whose cause can be read, and neighboring scenes do not both move mainly along the same axis. Of any three scenes in a row, at least one transforms, opens, gathers, or changes the view
4. Each scene has an entry that takes over the scene before it, an operation that changes the structure, and an exit that leaves something for the next. Reordering still pictures, a short back and forth, or a swapped label is not an operation
5. The summary uses only objects that earlier scenes made. A new abstract symbol added at the end does not stand in for the whole picture
6. The rough cut keeps the camera, the routes, the order of appearance, the transforms, and the handoffs of the final cut; only the art is simplified

A scene transforms, opens, gathers, or changes the view when its `continuityMode` is `object-transform`, `container-reveal`, or `spatial-reframe`, or its `cameraRelation` is `push-in`, `pull-out`, or `orbit`.

## Review questions

- Cut out as a still, does each scene show what it takes from the scene before and what it hands to the next
- Does the relation the viewer understands change between before and after the object moves
- Is the video more than a run of moves to the left and right, or up and down
- Do the scenes connect by transforming, opening, gathering, moving, or the camera moving in and out, instead of by a cut

## What the check reports

Run the `check-continuous-choreography` check of this skill on the plan.
Each issue names its `rule` and the `scene`, or no scene when it is about the whole plan.

| Rule | Means |
|---|---|
| `schema-version`, `scenes`, `persistent-subjects` | The plan is not version 1, has fewer than two scenes, or names no persistent subject |
| `scene-field`, `handoff-shape` | A scene lacks its id, operation, or subjects, or its `entryFrom` or `exitTo` lacks the subject or the state |
| `camera-relation`, `continuity-mode`, `primary-axis` | A value is not one of those listed here |
| `handoff-not-carried` | The scene starts from a subject the scene before it did not hand on (rule 1) |
| `persistent-subject-share` | Fewer than half of the scenes show a persistent subject (rule 2) |
| `repeated-axis` | The scene moves mainly along the axis of the scene before it (rule 3) |
| `three-scenes-without-change` | Three scenes in a row only carry or follow (rule 3) |
| `summary-new-subject` | The summary shows an object no earlier scene showed (rule 5) |
