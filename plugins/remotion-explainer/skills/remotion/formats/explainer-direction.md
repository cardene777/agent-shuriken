# Explainer direction

Every explainer video follows this direction.
It governs what the video must get across; the Remotion documentation governs how it is built.
It is on purpose neither a component library nor a styling preset.

## What it rests on

- Where a platform reports when viewers stop watching, look at the opening, the dips, the spikes, and the strongest moments after publishing. A strong opening means the first 30 seconds meet the expectation that the title and the thumbnail set; a dip needs a diagnosis at the level of the scene
- The opening seconds deliver the value they promise without delay. The moments where viewers stay or leave test the structure and the delivery
- Research on educational video recommends lowering the load that does not serve understanding: signal what matters, cut a process into segments, and let the picture and the words complement each other instead of repeating the same information
- Visual signals point at the relation that matters. Remove detail that is not needed, and cut a complex process into units that can be read

## The narrative

1. Start with the concrete problem, paradox, or visible result, never a title slate, a chapter number, a logo, or a generic overview. Within the opening beat, show the exact object whose state makes the subject worth explaining
2. Treat the whole video as one question being answered, not as a stack of slides. Each beat changes one of the object's state, its owner, a quantity, a time, a location, a constraint, or what the viewer understands. A beat where none of these changes is removed
3. An explainer of 60 to 90 seconds normally needs a new meaningful visual beat whenever the causal claim changes. A beat may be an entrance, a transformation, a handoff, a close inspection, an annotation that appears, or a consequence, never a decorative cut, an idle zoom, a swap of background, or a repeated heading
4. Every causal claim has a visual proof: a PNG of the specific state, a measured movement, or a relation line. Text may name the proof but never replaces it. Use the shortest annotation that lets the viewer read the condition at the moment it matters, such as `Lane 3`, `Held at the depot`, `Scanned 09:12`, or `Delivered`
5. Put text next to the object it qualifies. Do not repeat chapter titles at the top left, and do not put explanatory text where the player's controls sit. A line that must be read stays visible long enough to read after the movement it belongs to stops
6. Before a movement that matters, give a short visual anticipation: the source state or the destination becomes recognizable. After it lands, give a short hold for reading. Do not fill time with endless easing, breathing, or a drifting camera
7. A scene boundary is valid only when the exit causes the next entry: the same object crosses, transforms, is recorded, changes owner, or exposes the next condition. An object that only fades away leaves the scene unresolved

## Every beat before rendering

Record these for every beat in the beat dossier of `formats/beat-dossier.md`, or in `production.json` or the approved scene dossier.

| Field | Holds |
|---|---|
| Viewer question | What the viewer is trying to understand now |
| Proof object | The specific PNG or state that answers it |
| Before, operation, after | The visible causal change |
| Annotation | The exact words on screen, tied to the proof object |
| Attention action | What changes in the frame, and why it earns attention |
| Reading hold | When the motion stops, and how the viewer can read |
| Handoff | The object or state that creates the next beat |

Reject a beat with a title but no proof object, a connector that repeats a moving object, a state that appears fully formed before its cause, or an exit that does not create the next beat.

## Review and iteration

Before the video goes to the user, watch all of it at normal speed and mark every stretch of every beat as `question`, `proof`, `read`, or `handoff`.
A stretch with no mark is dead time and goes back to the storyboard.

After publishing, when the platform reports how long viewers keep watching, read it this way.

- An opening below expectation means the opening picture does not match the promise of the title or the thumbnail
- A dip needs the exact beat diagnosed: too much copy, no proof, a long hold, an unclear change of scene, or a cutaway that does not belong. Revise that beat, not only its colors
- A spike needs to be told apart: a valuable beat, or only a confusing one. Keep valuable proof and bring it earlier; clarify confusing proof
- The strongest moment gives its narrative property to reuse, such as a concrete before and after, never its literal composition or assets
