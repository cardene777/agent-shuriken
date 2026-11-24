# Video quality review

Use this after the geometry checks pass, such as those of the `svg-geometry` and `layout` formats of the `remotion-frame-checks` skill.
Passing geometry is needed, but it does not make an explainer worth watching.
It covers structure, staging, and pacing.

## Reject at once

- Every important object is visible before its role is introduced
- The primary object does not change its state, owner, location, amount, time, or constraint during a beat
- An object appears and disappears without creating a later state
- A movement repeats what an arrow or a label already says
- A line or an annotation is used as the proof instead of an object with a state
- A heading at the top left supplies the meaning of the scene
- A frame is free of collisions but has no focal order to the eye

## Score each beat, not only the whole video

Score from 1 to 5.
A score below 4 forces `revise`.
`formats/beat-review.md` records the scores of every beat.

| Axis | Field | A 5 means |
|---|---|---|
| Question clarity | `questionClarity` | The question can be inferred from the picture before the annotation is read |
| Visual proof | `visualProof` | A specific object or state answers the question without prose |
| Hierarchy | `hierarchy` | One primary is unmistakable, and the supporting objects each have a causal purpose |
| Operation | `operation` | The motion shows a real change of state, owner, or location |
| Reading rhythm | `readingRhythm` | The movement is anticipated, completed, then held long enough to read |
| Handoff | `handoff` | A named object or state causes the entry of the next beat |

## The whole video

1. Does each beat bring a new causal claim, rather than a new arrangement?
2. Can the video be understood at normal speed without depending on text alone?
3. Are the first five seconds a concrete problem or result, rather than a title?
4. Does every exit transform, carry, record, or explain why it leaves?
5. Is every change of camera tied to the handoff of an object, rather than decoration?

When a reviewer can only describe a section as "objects move around", go back to the beat dossier and define the question, the proof, and the operation again, not the easing.
