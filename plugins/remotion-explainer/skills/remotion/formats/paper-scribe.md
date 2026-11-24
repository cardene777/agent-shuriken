# Paper scribe

Use this visual language when the explanation should unfold as one connected hand-drawn paperboard.
It borrows only the visual grammar seen in public demonstrations of whiteboard explainers.
It never copies their software interface, drawing hand, assets, music, templates, or branded rendering.

## The grammar

1. Keep one paperboard world. A beat leaves an object, a trace, or a camera destination that makes the next beat necessary
2. Draw in reading order: the paper structure, then the outline of the object that carries meaning, then the paint of the approved PNG, then the attached annotation of a condition, quantity, time, or result
3. Use frames, underlines, brackets, relation lines, and local remarks as visual evidence. Each explains a relation; none is ever a generic card, a title band, or decoration
4. Move the focus to follow the carry object or to inspect a concrete state. No ambient drift, no reset to the center, no transition that is only a fade, and no blank wipe
5. Let the subject object move to show an exchange. Add a connector only for a relation that does not move, in its own clearance lane kept apart

## Traits taken from the study of references

The study of public whiteboard explainers was of visible staging only.
It is not a claim that these skills use any such product, and not permission to copy its assets, templates, interface, hand model, or animations.

| Seen | Taken as an abstract rule | Not taken |
|---|---|---|
| Writing and drawing in sequence | Record an explicit drawing order for each beat | The exact drawing, hand, path, or timing |
| One broad sheet with local work areas | Keep one coordinate world for the paperboard, and pan between the regions of the cause | Its board layout or decorative graphics |
| Boxes, lines, and labels that clarify a point | Every structure names its target and the purpose it explains | Generic interface cards or title strips |
| Camera attention that moves to the next drawing | Carry one object, state, or visual trace toward the next focus | Wipes, generic fades, or blank resets |

The same rule holds for explanatory flows: a scene boundary is a change of question around a carried object, not a new slide.

## What Remotion draws, and what it does not

- Every subject object, each of its meaningful state variants, every person, document, and diagram is an approved transparent PNG, generated on its own
- Remotion owns the paperboard, the camera, the structural strokes, the annotations, the timing, and the continuity. It never replaces missing subject art with DOM, CSS, Canvas, or generic SVG icons
- `paperboard.json` of `formats/paperboard.md` is required before any JSX. Its `rendererId` names a composition made for the subject; there is no generic paper-scribe fallback

## Rejected before implementation

Reject the beat before implementing it when any of these is true.

- Every subject PNG is visible before its causal role is introduced
- A chapter title at the top left, a generic card, or a state in text alone stands in for an operation
- The outline is an automatic silhouette trace with no relation to the meaningful structure of the illustration
- An object moves and a second arrow explains the same movement
- The next beat has no handoff object and no deliberate camera destination
- The focus does not change after the opening beat

`formats/paper-scribe-review.md` lists the questions for the rendered frames.
