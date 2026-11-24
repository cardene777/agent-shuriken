# Motion language

Motion in an explainer is not decoration that moves things around; it is how the viewer reads cause and effect.
Each scene chooses one main recipe for its question, and at most one supporting recipe.
A scene that puts everything on screen from the start and makes it drift does not pass.

Each choice rests on an entry of the motion evidence library, as the motion evidence contract describes.
To use a recipe no verified entry shows, watch a real video first and add it to the library.
A recipe that a verified entry already shows is not researched again for every video.

## Main recipes

| ID | What happens on screen | Answers | How it is built |
|---|---|---|---|
| `focus-push` | The view moves from the whole to one place, and on to the next place to understand once it is read | Which limit, condition, or part matters | A camera transform with `spring()` or `interpolate()` |
| `object-handoff` | The same object is carried into the next scene and takes a new role there | What starts the next step | A shared object and overlapping scenes |
| `morph-state` | The shape, content, or state of one object changes | How the same object is updated | An SVG path, a mask, or a staged swap of art |
| `build-through` | Parts assemble in the order they are needed | What it is made of | A staged reveal along an assembly route |
| `branch-prune` | Candidates appear and the ones a condition rules out fall away | What the choice rests on | Conditional appearance and a camera reframe |
| `aggregate-into-container` | Several different things go into one container and become one unit | How the results come together | Routed objects and the container's state |
| `reveal-through-mask` | A door, a window, a boundary, or a cross section opens and the visible part changes | How much is shown | An SVG or CSS mask and `clip-path` |
| `parallel-contrast` | Two states or routes run side by side in the same rhythm, so only the difference stands out | How A and B differ | Synchronized transforms on a shared baseline |
| `spatial-journey` | The camera or the main object travels through a space, a cross section, or a stage | Which ground it covers | A camera rig following a path |
| `live-inspection` | A record, a card, or part of a screen opens and its items are read in order | What is checked | An aperture or a crop with staged notes |
| `character-causes-system` | What a presenter or an agent does really changes the state of an object | Who causes what | A character pose and the object's response |
| `return-and-resolve` | An update that arrives later goes back to the first object and settles its state | Why it can be traced | A curved path and a change of the target's state |

A video of eight scenes or more uses at least six main recipes, neighboring scenes do not share a main recipe, and `object-handoff` is the main recipe of at most two scenes.

## Supporting means

- `spring()` gives entrances, stops, and bounces their feel. Set `durationInFrames` for a motion whose time must match others
- `interpolate()` changes the camera, crop, scale, rotation, and opacity on one timeline. Always clamp outside the range
- `@remotion/paths` is for the routes of objects, growing boundaries, and changing shapes, not a replacement for straight lines
- `Trail` and `CameraMotionBlur` of `@remotion/motion-blur` are only for the moment of a fast move or a camera move, never decoration of a still screen
- `@remotion/transitions` never replaces clearing the screen. Keep the carried object, and use an iris, a wipe, a clock wipe, or a zoom blur only at a scene boundary that means something
- `@remotion/three`, Lottie, and Rive are considered only when a solid, a ready-made state machine, or an outside animation is needed for the explanation, after checking the dependency, render compatibility, and license

The mechanism a scene names is one of `spring-interpolate`, `svg-paths`, `motion-blur`, `transitions`, `three`, `lottie`, `rive`, `css-mask`, or `asset-sequence`.

## What does not pass

- Every element on screen from the start, with constant drifting, pulsing, or small scaling to fill the time
- A sender on the left, an arrow, and a receiver on the right as the standard composition; a sideways send is used in at most two scenes
- A scene that ends by clearing everything, and a next scene that starts as a new still layout
- An explanatory arrow drawn over the route an object really travels
- A transition used only to say that the content changed; decide first what the next scene carries over

## The plan

Write `storyboard/motion-language-plan.json` in the Remotion project.

| Field | Holds |
|---|---|
| `schemaVersion` | `1` |
| `scenes[].id`, `viewerQuestion` | The scene and the question it answers |
| `scenes[].primaryRecipe` | One main recipe from the table above |
| `scenes[].supportingRecipe` | At most one other recipe, or left out |
| `scenes[].evidenceIds` | The library entries the choice rests on; at least one is `verified` and shows the main recipe |
| `scenes[].visualReason` | Why this motion answers the question |
| `scenes[].officialMechanism` | The mechanism it is built with |
| `scenes[].entry`, `operation`, `result` | What appears, what changes, and what stays, at the three moments of the camera |
| `scenes[].proofFrames` | `entry`, `operation`, and `result` |

## What the check reports

Run the `check-motion-language` check of this skill with the plan and the user's library.
Each issue names its `rule` and the `scene`, or no scene when it is about the whole plan.

| Rule | Means |
|---|---|
| `schema-version`, `scenes`, `scene-field` | The plan is not version 1, has fewer than two scenes, or a scene lacks a field |
| `recipe`, `supporting-duplicates-primary`, `mechanism` | A recipe or a mechanism is unknown, or the supporting recipe repeats the main one |
| `missing-evidence` | The scene cites no library entry |
| `unknown-evidence` | The scene cites an entry the library does not hold |
| `unverified-evidence` | No verified entry the scene cites shows its main recipe |
| `proof-frames` | `proofFrames` lacks entry, operation, or result |
| `repeated-recipe` | The scene uses the main recipe of the scene before it |
| `recipe-variety`, `object-handoff-limit` | A long video uses fewer than six main recipes, or more than two scenes hand an object on as their main recipe |
