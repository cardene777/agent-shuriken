# Hand-drawn narrative

`id: hand-drawn-narrative`

A design pattern that builds a small story of the subject by hand on a white sheet of paper.
Its core is not the white background or the line drawing itself, but a setting that appears stroke by stroke and explains a cause.

## What it carries over

- A warm white paper surface, deep black to navy ink, and one blue and one warm color, used once each
- Hand-drawn lines change their weight between the outer shape, the inner structure, and the annotations. Never only a uniform icon stroke
- One screen is one illustration board. Instead of icons under a title, the setting itself shows the problem, the operation, and the result
- Earlier lines and objects become the material of the next picture. No wiping to a blank sheet, no slide changes, no swapping of the background
- Text is small handwriting that helps the objects and the movement read

## Translate it to the subject

Before implementing, write these four as `patternAdaptation` in the art direction of `formats/art-direction.md`.

1. The setting: the place or situation where the subject acts in reality. An abstract dashboard is not allowed
2. The primary: a person, object, or space made for the subject that shows its cause at a glance. Never rename a stock house, person, card, or arrow
3. The metaphor: how the invisible mechanism is made visible as part of the setting
4. The handoff image: the line, object, or space that stays at the end of the scene and is transformed or used in the next one

For a parcel, do not line up a warehouse, a truck, and a box.
Build, in one setting, the place where the parcel waits and the reason it waits, the object that stands for the promise to deliver it, and what the sorter solves there.

## One scene

| Beat | What happens on screen | Not allowed |
|---|---|---|
| Setup | Draw the setting and the primary within three seconds, so the primary's purpose reads from its form | A title screen of text alone |
| Friction | Part of the setting changes and a problem arises | A warning card, a red badge |
| Mechanism | The primary's inside, cross-section, or the hands at work open up and reveal the mechanism | Switching wholly to a new generic diagram |
| Consequence | The result of the operation comes back into the same setting | Replacing the result with sentences |
| Handoff | The last line, object, or gaze becomes the first material of the next scene | An exit that is only a fade |

## Drawing

- Outer shapes 6 to 9 px, important inner structure 4 to 6 px, annotations 3 to 4 px. Mix intended loose curves and double lines in with the straight lines
- Each primary has four layers: the outer shape, the inner structure, the differences of state, and a small trace of the story. A single-outline icon fails
- When people are used, never stick figures or round profile heads. Draw at least four things apart: the posture, what the hands are doing, the clothes or tools, and the gaze
- Draw only props that belong to the subject's cause. No decorative stars, floating arrows, or tags that stay on screen
- A drawn entrance draws real SVG paths in order. The order the paths are drawn in is itself the order in which things are understood

## Motion

- One meaningful action per beat: drawing, opening, handing over, turning over, stacking, taking apart, or reconnecting
- Do not fade every object in at once to fake the speed of drawing. Bring in the outer shape, then the inner structure, then the annotations, then the marks of the operation
- When a hand asset is used, the pen tip follows the tip of the SVG path being drawn right now. Never let the hand slide across the screen on its own
- Drift, breathing, a constant pulse, and a moving background are not allowed

## The reference scene

It is `revise` unless all of these hold.

- The setting of the primary is visible within 1.5 seconds, and what will happen reads within 3 seconds
- Within 12 to 15 seconds, three things happen: a change in the setting, the reveal of the mechanism, and its causal result
- At least one primary is drawn with four or more layers and changes its form at least twice
- Most of the screen is not text, empty space, or generic icons
- The last frame leaves a concrete picture that the next scene can transform as its first

## The template

`templates/InkPrimitives.tsx` provides only ink lines, double lines, and drawing in path order.
It is not a template of settings, people, objects, or props, and none of those are reused from it.
