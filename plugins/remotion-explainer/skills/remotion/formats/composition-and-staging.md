# Composition and staging

Read this together with `formats/explainer-direction.md` before any new Remotion composition is designed.
It is a contract for staging, not a component library and not a preset of art style.

## The unit of design is a beat, not a scene title

One beat answers one viewer question through a visible change.
It has four states.

| State | What happens |
|---|---|
| Orient | One question and one primary object are established |
| Operate | The causal action is done in a movement lane kept free for it |
| Read | The movement that matters stops, and the condition or the result appears |
| Carry | One state is kept, transformed, or moved into the next beat |

Do not begin a beat with a finished board, and do not end it by fading every object out.
A beat that does neither an operation nor a change of the result state is not a beat.

## Roles on screen

Every visible object has one role.
An object with no role right now is absent, not faded down as background decoration.

| Role | Purpose | When it is visible |
|---|---|---|
| Primary | The object whose state answers the current question | It carries the most visual weight; one per beat |
| Counterpart | The actor or destination that makes the operation mean something | Introduced only after the primary is understood |
| Evidence | A condition, a quantity, a time, or a variant of a state | Appears beside the primary after the movement settles |
| Carry | The object or state that lives on into the next beat | Has a named change or destination |

## Stage modes

Use one of these modes per beat.
A permanent three-column board is never the default mode.

| Mode | Suits the question | Composition |
|---|---|---|
| `aperture` | What is the problem, or the object? | One primary fills the focus area; context enters only after it can be read |
| `exchange` | Who gives what to whom? | The source and the destination take separate sides; the object actually handed over gets a clear lane through the center |
| `inspection` | What condition matters? | The camera or the layout closes in on one object; the evidence annotation touches its neighborhood |
| `consequence` | What changed? | The earlier state or its trace shows briefly, then a distinct result state appears in its place |
| `handoff` | What does the next beat inherit? | The carry object leaves toward the next focus or becomes the next primary; other objects leave for a stated reason |

## Space in a 16:9 explainer

- Keep a safe margin of 5% around the edges, and never place content where the player's controls sit at the bottom
- At rest, show at most one primary and two supporting roles. A crowd of objects with equal weight has no focal order
- Keep a movement lane empty before an object moves, and never route a connector through it
- Give the primary at least 1.35 times the visual width or contrast of the largest supporting object, unless the beat is explicitly an equal exchange
- Place evidence text within one width of the primary from the thing it names. It is never an isolated title band
- Use empty space to show direction and anticipation. An object moves into space prepared for it, not through a packed layout
- When the point is a transformation, replace the old state at the same anchor; do not show a change of state as a disappearance followed by an unrelated entrance

## Motion and rhythm

Motion earns attention only when it changes the owner, the location, the amount, the time, a constraint, or the state of an object.

- Orient: 250 to 700 ms to establish the primary
- Operate: one decisive movement or transformation; avoid several independent entrances at once
- Read: after the operation stops, hold 500 to 1,200 ms for the annotation
- Carry: overlap the exit and the next entry; never reset to an empty stage
- Move the camera only to follow a carry object or to reveal a detail under inspection. Never fill time with ambient drift, breathing, or a slow zoom

## Example: the first four beats of a parcel's trip

| Beat | Mode | Primary | Visible proof | Carry |
|---|---|---|---|---|
| The parcel waits | `aperture` | The parcel on the warehouse shelf | Its blank label | The parcel stays |
| The route is printed | `inspection` | The parcel's label | `Lane 3` next to it | The label becomes the parcel's route |
| The sorter takes it | `exchange` | The labeled parcel | The parcel moves from the belt into lane 3 | Lane 3 now holds the parcel |
| It reaches the door | `consequence` | The doorstep | The parcel arrives, and the empty step changes to a step with a parcel | The delivered parcel leads to the signature |

The warehouse, the parcel, the sorter, and the door are not all present before their roles are introduced.
The move into the lane and the trip to the door are separate causal operations.

## Questions for every turning frame

Answer all of these with a concrete object for every rendered turning frame.

1. What is the one question being answered now?
2. Which object is primary, and why does it dominate the picture?
3. What changed on screen, beyond what text appeared?
4. Why does each supporting object stay visible?
5. What exact object or state creates the next beat?

A missing answer is a defect of structure, not of styling.
