---
name: remotion
description: The one entry point for making a Remotion explainer video whose pictures belong to its subject, precise and continuous from scene to scene. Runs, in order, an art direction for the subject, a 12 to 15 second reference scene, a silent rough of every beat, still boards, the full build, and an independent check of real frames, with the person's approval at each gate, and never leans on stock UI or past compositions. Calls remotion-explainer-production, remotion-explainer-review, png-asset-production, and png-outline-tracing, and follows the contracts of remotion-motion-plan, remotion-frame-checks, and remotion-catalog. Use when making an explainer video with Remotion.
---

# Remotion

This skill is the one entry point for a Remotion explainer video.
The user calls only this skill, and the four skills it calls are never used alone for a video handed to the user.
Talk to the user in the language they write in.
Whenever a step asks the person to choose or approve, ask in Claude Code with AskUserQuestion, and in other agents in the chat, waiting for the answer.

The files are next to this `SKILL.md`, and other skills follow them through musubi.

| Content | File | What it holds |
|---|---|---|
| `engineering` | `formats/engineering.md` | What quality means, the choice of renderer, the composition structure, the rules for text, paths, effects, and transitions, micro benchmarks, and how to judge a render |
| `art-direction` | `formats/art-direction.md` | The fields of `production.json` these skills read and write, `artDirection` among them |
| `explainer-direction` | `formats/explainer-direction.md` | The narrative and what every beat needs before it is rendered |
| `composition-and-staging` | `formats/composition-and-staging.md` | Beats, roles on screen, stage modes, space in 16:9, and rhythm |
| `rough-proxy` | `formats/rough-proxy.md` | The stand-in shapes of the rough and the two-second test |
| `reference-beats` | `formats/reference-beats.md` | Abstract staging patterns a beat may borrow |
| `beat-dossier` | `formats/beat-dossier.md` | `beat-dossier.json`, the state machine of the video, and the rules of videos of five minutes or longer |
| `check-beat-dossier` | `scripts/check-beat-dossier.mjs` | The check of a beat dossier |
| `beat-review` | `formats/beat-review.md` | `out/review/beat-review.json`, the evidence that each beat was looked at in real frames |
| `check-beat-review` | `scripts/check-beat-review.mjs` | The check of a beat review |
| `video-quality-review` | `formats/video-quality-review.md` | What to reject at once, and how to score each beat and the whole video |
| `static-art` | `formats/static-art.md` | How a video uses approved PNG art and its outlines |
| `felt-applique` | `formats/felt-applique.md` | The felt applique stage theme |
| `check-stage-theme` | `scripts/check-stage-theme.mjs` | The check of a stage theme in `production.json` |
| `hand-drawn-narrative` | `formats/hand-drawn-narrative.md` | The hand-drawn narrative design pattern |
| `ink-primitives` | `templates/InkPrimitives.tsx` | The ink primitives the hand-drawn pattern draws with |
| `paper-scribe` | `formats/paper-scribe.md` | The paper scribe visual language |
| `paperboard` | `formats/paperboard.md` | `paperboard.json` of a paper scribe video |
| `check-paperboard` | `scripts/check-paperboard.mjs` | The check of a paperboard |
| `paper-scribe-review` | `formats/paper-scribe-review.md` | What a review of a paper scribe video looks at |

The `examples/` folder holds a valid file of each kind the checks read, about a parcel taken from a warehouse through a sorter to a door.
The checks run with Node.js 18 or later and only its built-in modules; when `node` is missing, tell the user to install it and stop.
Each prints one JSON object with `decision` (`pass` or `revise`) and exits 0, 1 for issues, or 2 for a wrong call.
"What it follows" at the end names each content of another skill this skill reads or runs, and how to open it.

## Before starting

1. Confirm the subject, the audience, the target length, whether there is a voice, and the approved plan, script, and storyboard. When the project has `production.json`, it is the one record to edit, and no gate it holds is passed before its approval.
2. Read `formats/engineering.md` whole, and apply its definition of quality, choice of renderer, composition structure, rules for text, paths, effects, and transitions, micro benchmarks, and judgment of the render.
3. Use the official Remotion skills. Open `remotion-best-practices` by name, and for a new composition `remotion-create`. Open `remotion-markup` for the DOM layout, PNG layers, connecting SVG, animation driven by the frame, and structure of many scenes. Check every `@remotion/*` package and API the video uses, and the version that brought it in, with `remotion-docs`. When they are not installed, tell the user that `npx remotion skills add` in the Remotion project, or `npx skills add remotion-dev/skills` elsewhere, installs them, and meanwhile read the official Remotion documentation page of each API before using it.
4. Search the catalog in four layers. Follow the `selection` format of `remotion-catalog`, and search the form, the composition, the typography, and the motion of each scene apart with its `catalog` command. When no form in the catalog is a concrete object of the subject, never settle for a generic round icon or card: design it as `bespoke`, and record why in `storyboard/scene-design-layers.json` by the `scene-layers` format of `remotion-frame-checks`. Implement motion only after `check-scene-layers` passes and the still boards are approved. When the catalog cannot be built or searched, say what is missing and stop instead of falling back to an old composition.
5. When the video needs bespoke SVG, connectors, badges, or moving heads, make `storyboard/svg-geometry.json` the source of truth by the `svg-geometry` format of `remotion-frame-checks`: every visible element with its inner shapes, outer ports, connector ends, what to avoid, clearances, arrival frames, and final targets, read by the TSX from the same source. Implement no motion until `check-svg-geometry` passes and the still frames at 100% and 50% show the connections and strokes.
6. Read, in this order, `formats/art-direction.md`, `formats/explainer-direction.md`, `formats/composition-and-staging.md`, `formats/rough-proxy.md`, the `choreography` and `continuous-choreography` formats of `remotion-motion-plan`, `formats/reference-beats.md`, and `formats/beat-dossier.md`. When an approved reference beat is close to the subject, cite only its abstract staging properties in the dossier. Write in `production.json` the `designPattern` the user chose and the `artDirection` of the subject.
   - When the user explicitly chose a physical stage theme, read its format. For `felt-applique`, read `formats/felt-applique.md` and record in `artDirection.stageTheme` its `id`, `assetStyleId`, allowed primitives, and container, label, connector, and trace policies. A PNG style ID never chooses a stage theme by itself.
   - When the user chose the hand-drawn narrative, read `formats/hand-drawn-narrative.md`.
   - When the user chose `paper-scribe`, also read `formats/paper-scribe.md`, `formats/paperboard.md`, and `formats/paper-scribe-review.md`, write `paperboard.json`, and run `check-paperboard` on it until it passes.
   - Never choose from past compositions, stock UI, PNG themes, or theme names that only change colors.
7. While the rough is being made, never load `production.json.visual.staticAssets[]`. List the roles the beat dossier needs, and make stand-in shapes and two-second tests by `formats/rough-proxy.md`. Finished art never makes up for a rough that does not read.
8. Confirm that the plan does not explain mainly with stock UI, rows of cards, background images, or PNG collages. Only after the rough is approved, load the subject's primary objects, states, operations, and results as separate approved PNGs with transparency from `production.json.visual.staticAssets[]`. Art without a manifest, transparency, a composite review, and the person's approval is never loaded; send it back to `png-asset-production`.
9. Before scenes, make one state machine and `beat-dossier.json` by `formats/beat-dossier.md`. Implement nothing while any chapter boundary cannot say what stays on screen, what changes form as it is handed on, why something leaves, why the next thing appears, and how the camera moves, or while any beat lacks its viewer question, proof object, before, operation, and after, annotation, attention action, reading hold, handoff, and stage mode. With `paper-scribe`, connect the same beats to `paperboard.json` and fix the drawing order paper structure, object outline, approved PNG paint, annotation, with its focus and handoff. Write no Remotion code until `check-beat-dossier`, and `check-paperboard` when it applies, pass.
10. Before implementing, put the visible bounds of every PNG and the route of every connector of every scene into the layout contract. Contacts between PNGs that are not registered, routes into the margins of PNGs, and text in the safe area of other text must be zero. When a contact is allowed, write its meaning, the range it touches, and the states before and after. In a scene with SVG, register the inner shapes, labels, badges, connectors, and moving objects with their own IDs, not only the parent frame; end lines at outer ports instead of piercing to the center and hiding the end by draw order, and check the arrival by the distance between the real end at the arrival frame and the target port, never by a progress of 1.
11. In a video with positions, margins, alignment, containment, or routes, make `storyboard/layout-spec.json` the source of truth of the layout by the `layout` format of `remotion-frame-checks`, and have the Remotion source read its coordinates from the same geometry source. Never pass a layout on its overall center alone: check each element's real bounds, baseline, aspect ratio, minimum clearance, and route at entry, operation 25%, 50%, 75%, settled, and handoff. Show no normal MP4 until `check-layout` passes and its audit files tied to the current source hash, with the spatial route and composition balance audits, all have zero issues.
12. In a video that brings paths, connectors, masks, text, or scene layers in and out over time, follow the `timing-boundary` format of `remotion-frame-checks`. Render the two frames before and after every start and end in a row, and check that before the start the opacity, drawn length, mask opening, and visible pixel count are zero, and that no short-lived segment, dot, piece of text, or shadow appears during an entry or exit. Normalize SVG path reveals with `pathLength="1"` or `@remotion/paths` instead of guessing fixed dashes, and set the opacity to 0 at a progress of 0. Show no MP4 until `check-timing-boundary` has zero issues for the current source.

## Text and routes on screen

1. No slide that repeats a chapter number, a chapter name, and a big heading at the top left. Text in the video is a short annotation next to the primary object that is changing, for reading its state, condition, amount, deadline, or result. A value the subject needs is defined in the brief before it is used.
2. Each scene designs at least two of these as text tied to the primary object: the condition read before the operation, the claim read during it, the result read after it. Text never stands in for a cause; the PNG and the motion of the same state always come first.
3. When an object moving shows its route, no arrow lies on the same route. A connector is used only to explain a relation that does not move, the first time. Every needed connector has its own clear lane in the layout contract, apart from the objects, the text, and the moving lanes, with zero crossings in every frame.
4. A chapter spends its time on discovery, operation, reading, and handing over to the next chapter, and never keeps the viewer waiting on a still finished layout. Constant drifting, zooming, or decorative pulsing never fills the time.

## Long videos

Never make a long video by repeating the short reference scene.
For an explainer of five minutes or more, define the learning layers, arrivals, continuous boundaries, visual center, and changes of composition that `formats/beat-dossier.md` sets for videos of five minutes or longer, in `beat-dossier.json` and the same layout source, and check them before rendering.
Record the result in `out/review/spatial-route-audit.json` and `out/review/composition-balance-audit.json` with the frame, the object, the source and target, the bounds, the center, and the reason for each exception; one issue in either is `revise`.

## The rough choreography gate

Before drawing the rough, write `storyboard/choreography-plan.json` by the `choreography` format of `remotion-motion-plan`: each scene's viewer question, view grammar, camera at entry, operation, and result, each object's appearance, operation, result, and route, the motion beats, the handoff, and what must match the final cut. Show no rough until `check-choreography` passes.

The rough may leave out only the material of the art.
The camera, the order of appearance, the routes, the transformations, comparisons, branches, and the handoffs between scenes are the same staging as the final cut.
A plain sender on the left, connector, and receiver on the right is allowed in at most two scenes of the whole video, and the same view grammar never comes twice in a row.
No scene places its primary object complete at entry; each has an object with meaning appear, get operated on, and end in a different result.
The whole video needs `storyboard/continuous-choreography-plan.json` by the `continuous-choreography` format of `remotion-motion-plan`, where each scene's result is the next scene's input; clearing the board, resetting coordinates, or swapping the background is never a handoff. Show no rough until `check-continuous-choreography` passes.

Before the rough, read the `motion-evidence` format of `remotion-motion-plan` and the user's motion evidence library it names, and run `check-motion-evidence` on the library. Choose verified entries that fit the questions of this video instead of studying new videos for every project; only when the library lacks a recipe, watch real videos and add to the library. Then read the `motion-language` format of `remotion-motion-plan`, and record each scene's main recipe, supporting means, evidence IDs, Remotion mechanism, and proof frame in `storyboard/motion-language-plan.json`. Make no rough until `check-motion-language` passes on the plan and the library. More kinds of composition are not enough: the rough reproduces the beats of timing learned from real examples.

## The gate of the moving rough of the whole video

Before final art, finished decoration, and the voice, make once a silent moving rough that joins every beat.
Still storyboards, roughs of single scenes, and candidates with final art do not stand in for it.

1. From `beat-dossier.json`, write into `out/review/composition-rough/` a rough MP4 that plays the whole length, `index.json`, and the real entry, operation, read, and handoff frames of each beat. The rough may use stand-in shapes, temporary labels, and a temporary camera, but the same framing, scene order, global frame clock, and handoffs between scenes as the final.
2. Each beat of `index.json` records its `id`, viewer question, primary object, starting state, physical operation, state read, object carried on, handoff to the next beat, stage mode, and the intent of its composition. When a beat cannot say in one sentence what it makes understood and why its primary object moves, make the rough again.
3. Audit the rough for repeated compositions, a center pulled to one side, empty space without meaning, the same action said again, waiting without a primary object, and boards cleared between scenes. Even when each scene reads, the same screen structure or the same move repeated through the video is `revise`.
4. The person first watches the rough of the whole video for the order of the explanation, the continuity, and how each scene is shown. This approves the whole structure, not the art, the text sizes, or the final layout. Go on to visual boards with final art only after `production.json.compositionRough` records the rough MP4, its compiled hash, the review result, and `approved: true`.
   - Only after the approval, settle `production.json.visual.staticAssets[]`, and order and review final art that keeps each stand-in's role, visible ports, states, and operations, by `png-asset-production`. When the final art changes the reading order, go back to the stand-in design, not to the still board.
5. After the structure is approved, check the still layouts scene by scene. When one scene is fixed later, render again only that scene's still board and a short motion review. When a viewer question, a primary object, an operation, a handoff, or the scene order changes, make the whole rough again and have it approved again.

## The art direction gate

Before the whole video, make one reference scene per subject.
What is reused is the process of design and checking, never the look of houses, people, cards, or arrows.

1. Record in `production.json.artDirection` every field `formats/art-direction.md` lists. While one is missing, implement nothing.
2. Implement the 12 to 15 second reference scene that holds the hardest cause, with the same renderer, the same global frame clock, and the same way of making art as the whole video. It has at least three changes of state of the primary object, two changes of form that the subject explains, and one exit that can be handed on.
   - When it uses approved static art, use only one piece in this scene. When it has an outline, draw the outline for at least 1.4 seconds, let it be read for 200 ms, then settle the PNG, by the `outline-timing` format of `png-outline-tracing`. Never place the art finished from the start, or show the outline and the PNG in the same frame.
3. Run `remotion-explainer-review` on the reference scene too. Beyond geometry, score each beat's question, evidence, hierarchy, operation, reading, and handoff by `formats/video-quality-review.md`; when specificity, composition, motion, or visual discovery is below 4 of 5, it is `revise`. Never fix it by changing colors, nudging coordinates, or adding text: go back to the art direction, the beat dossier, or the object and motion lexicons.
4. Show the person the real MP4 of the reference scene and its entry, turning, and exit frames, and never extend to the whole video until they approve its style and density. Record the approval as a gate in `production.json`.
5. Only after the approval, keep the same art direction and design a different visual job for each chapter. Share only the visual grammar and the object lexicon, never copy the reference scene's composition or parts.

## The visual board approval gate

After the moving rough of the whole video is approved, the person checks the still layout of each visual board on its own.
Existing diagrams, components, and catalog entries are constraints and candidates, never fixed templates.
Define the viewer question first, and choose the clearest diagram or scene structure; when a new structure fits better than the candidates, show the new proposal for review.

1. Build the board in the same Remotion composition as the final, with the primary PNGs, the text, the containment, the connectors, and the visible bounds contract. Implement no entrance, move, trace, camera, or exit animation yet.
2. Render each scene's still read frame, put it in an HTML review with the viewer question, the structure chosen and why, the compiled hash, and the geometry result, and show it to the person. This is a review of work in progress, not a candidate.
3. Add no animation to a board until its still layout of the same compiled hash is approved. When animation would change a readable structure such as the layout, connectors, text, containment, or scale, go back to the still review.
4. Only after the still approval, add the changes of state, operations, and handoffs of the motion lexicon to the same layout. The entry, operation, turning, and exit frames, the full watch, and the geometry, continuity, and quality reviews come after this.

Keep `out/review/static-layouts/index.json` for each video. Each entry has the scene ID, the viewer question, the structure decision (catalog candidate, new proposal, or not a diagram), the read frame, the compiled hash, the still PNG, the visible-bounds audit, the geometry result, and the person's approval. A board whose approval and compiled hash do not match goes no further.

## Build and review

1. Run `remotion-explainer-production`. From the approved rough, the art direction, and the scene dossier, it implements the shared layout, visible bounds taken from alpha, named exterior anchors, the safe area, one global frame clock, and the handoff of state between scenes, and writes the real frames, `geometry-samples.json`, `continuity-samples.json`, and the spatial audit of each frame. It does not start without `compositionRough.approved` and the rough's compiled hash. With a stage theme, it implements the theme's contract while the subject stays approved PNGs, and Remotion handles only the board, pockets, labels, connectors, annotations, and transitions. With `paper-scribe`, it registers only a renderer for this subject, named `paper-scribe-<subject>-v<n>`, and applies the paperboard's focus, structure, drawing order, and handoffs to the real frame clock; it never falls back to a generic paperboard renderer.
   - With a stage theme, run `check-stage-theme` on `production.json` first. Without `out/review/stage-theme-audit.json`, or when each scene's containment, labels, and routes cannot be matched to real frames, it is no candidate.
2. Run `remotion-explainer-review` on its own. It checks geometry, boundary continuity, entry, turning, exit, and camera transitions, the full video, and six scores, and appends the result to `production.quality-loop.json`. It writes `out/review/beat-review.json` by `formats/beat-review.md`, with each beat's orient, operation, read, and handoff frames, the dossier hash, the compiled hash, and the scores of each beat; go no further until `check-beat-review` passes on it.
3. When `issueCount` is above 0, the decision is `revise`, any of the six scores is below 4, a hash does not match, or a real frame is missing, send the work back to the skill that owns the cause. After a fix, always render again from step 1 and run step 2 again.
4. When the same issue comes in two iterations in a row, stop fixing only coordinates or colors: make the scene composition, the primary object, the anchor model, the component API, or the storyboard again.
5. Hand the video to the user, or to the skill that called this one, only when everything tied to the current compiled hash is in: `issueCount: 0`, `decision: candidate`, the geometry and continuity checks passing, a spatial audit with alpha visible bounds and route and arrowhead paths passing, the timing boundary check passing, the four real frames of each scene, the before, during, and after of every boundary, and a full watch.

## Never

- Hand over as finished the output of a called skill, an old MP4, a single TSX file, or one still
- Hand over a candidate with `issueCount` above 0 as a comparison or a sample
- Put text, tags, arrows, or labels in place of a state or a cause itself
- Let PNG themes, stock UI, or past compositions pull the composition
- Draw the subject's people, objects, documents, states, or shapes anew with Remotion's DOM, SVG, CSS, or Canvas. Stand-in shapes of the rough, made to check roles, ports, states, and operations before the final art, are the one exception. Remotion handles only placing, moving, scaling, rotating, masking, and tracing approved PNGs, and the connectors, arrows, text, camera, and transitions
- Shrink `felt-applique` to cards in three columns without the subject, labels at different heights, thin arrows, bare outlines, or loose yarn lines. A pocket is allowed only when keeping, matching, or owning something means something in the scene
- Put into the video a PNG whose manifest is not approved, or an SVG outline nobody reviewed
- Extend to a long video without the art direction and the person's approval of the reference scene
- Reuse one silhouette, composition, or motion in every chapter and call it another scene because its colors or headings changed
- Shrink `hand-drawn-narrative` to a white background, thin SVG lines, and an abstract sign in the middle
- Use a fade, wipe, or slide of `TransitionSeries`, a cleared screen, or a swapped background in place of handing a state on. A transition only helps a continuing object change form or move

## Done when

The latest iteration of `production.quality-loop.json` has `issueCount: 0`, `decision: candidate`, all six scores at 4 of 5 or more, a passing frame-level spatial audit of alpha visible bounds, connector routes, and arrowheads, and a current compiled hash, geometry, continuity, every real frame, and the full video that can be traced back.

## Before handing over

1. Does `beat-dossier.json` pass its check, with a concrete operation, evidence, and handoff in every beat?
2. Is the primary object narrowed to one in every turning frame, and is none of them a finished side-by-side board?
3. Does every appearance, move, and exit have a change of state or a reason that makes the next beat?
4. Apart from the geometry, is every beat scored 4 of 5 or more by `formats/video-quality-review.md`?
5. Do the dossier hash, the compiled hash, and the four real frames of every beat in `beat-review.json` match the current output?

## What it follows

Write in the `choreography` format of the `remotion-motion-plan` skill: open the `remotion-motion-plan` skill by name and read the file it names for `choreography`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-motion-plan` skill is not installed, do not start: tell the user that `remotion-motion-plan` is missing and how to install it, then stop.

Run the `check-choreography` of the `remotion-motion-plan` skill: open the `remotion-motion-plan` skill by name and run the file it names for `check-choreography`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-motion-plan` skill is not installed, do not start: tell the user that `remotion-motion-plan` is missing and how to install it, then stop.

Write in the `continuous-choreography` format of the `remotion-motion-plan` skill: open the `remotion-motion-plan` skill by name and read the file it names for `continuous-choreography`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-motion-plan` skill is not installed, do not start: tell the user that `remotion-motion-plan` is missing and how to install it, then stop.

Run the `check-continuous-choreography` of the `remotion-motion-plan` skill: open the `remotion-motion-plan` skill by name and run the file it names for `check-continuous-choreography`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-motion-plan` skill is not installed, do not start: tell the user that `remotion-motion-plan` is missing and how to install it, then stop.

Write in the `motion-evidence` format of the `remotion-motion-plan` skill: open the `remotion-motion-plan` skill by name and read the file it names for `motion-evidence`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-motion-plan` skill is not installed, do not start: tell the user that `remotion-motion-plan` is missing and how to install it, then stop.

Run the `check-motion-evidence` of the `remotion-motion-plan` skill: open the `remotion-motion-plan` skill by name and run the file it names for `check-motion-evidence`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-motion-plan` skill is not installed, do not start: tell the user that `remotion-motion-plan` is missing and how to install it, then stop.

Write in the `motion-language` format of the `remotion-motion-plan` skill: open the `remotion-motion-plan` skill by name and read the file it names for `motion-language`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-motion-plan` skill is not installed, do not start: tell the user that `remotion-motion-plan` is missing and how to install it, then stop.

Run the `check-motion-language` of the `remotion-motion-plan` skill: open the `remotion-motion-plan` skill by name and run the file it names for `check-motion-language`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-motion-plan` skill is not installed, do not start: tell the user that `remotion-motion-plan` is missing and how to install it, then stop.

Write in the `scene-layers` format of the `remotion-frame-checks` skill: open the `remotion-frame-checks` skill by name and read the file it names for `scene-layers`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-frame-checks` skill is not installed, do not start: tell the user that `remotion-frame-checks` is missing and how to install it, then stop.

Run the `check-scene-layers` of the `remotion-frame-checks` skill: open the `remotion-frame-checks` skill by name and run the file it names for `check-scene-layers`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-frame-checks` skill is not installed, do not start: tell the user that `remotion-frame-checks` is missing and how to install it, then stop.

Write in the `svg-geometry` format of the `remotion-frame-checks` skill: open the `remotion-frame-checks` skill by name and read the file it names for `svg-geometry`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-frame-checks` skill is not installed, do not start: tell the user that `remotion-frame-checks` is missing and how to install it, then stop.

Run the `check-svg-geometry` of the `remotion-frame-checks` skill: open the `remotion-frame-checks` skill by name and run the file it names for `check-svg-geometry`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-frame-checks` skill is not installed, do not start: tell the user that `remotion-frame-checks` is missing and how to install it, then stop.

Write in the `layout` format of the `remotion-frame-checks` skill: open the `remotion-frame-checks` skill by name and read the file it names for `layout`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-frame-checks` skill is not installed, do not start: tell the user that `remotion-frame-checks` is missing and how to install it, then stop.

Run the `check-layout` of the `remotion-frame-checks` skill: open the `remotion-frame-checks` skill by name and run the file it names for `check-layout`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-frame-checks` skill is not installed, do not start: tell the user that `remotion-frame-checks` is missing and how to install it, then stop.

Write in the `timing-boundary` format of the `remotion-frame-checks` skill: open the `remotion-frame-checks` skill by name and read the file it names for `timing-boundary`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-frame-checks` skill is not installed, do not start: tell the user that `remotion-frame-checks` is missing and how to install it, then stop.

Run the `check-timing-boundary` of the `remotion-frame-checks` skill: open the `remotion-frame-checks` skill by name and run the file it names for `check-timing-boundary`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-frame-checks` skill is not installed, do not start: tell the user that `remotion-frame-checks` is missing and how to install it, then stop.

Write in the `selection` format of the `remotion-catalog` skill: open the `remotion-catalog` skill by name and read the file it names for `selection`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-catalog` skill is not installed, do not start: tell the user that `remotion-catalog` is missing and how to install it, then stop.

Run the `catalog` of the `remotion-catalog` skill: open the `remotion-catalog` skill by name and run the file it names for `catalog`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-catalog` skill is not installed, do not start: tell the user that `remotion-catalog` is missing and how to install it, then stop.

Write in the `asset-manifest` format of the `png-asset-production` skill: open the `png-asset-production` skill by name and read the file it names for `asset-manifest`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `png-asset-production` skill is not installed, do not start: tell the user that `png-asset-production` is missing and how to install it, then stop.

Run the `check-asset-manifest` of the `png-asset-production` skill: open the `png-asset-production` skill by name and run the file it names for `check-asset-manifest`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `png-asset-production` skill is not installed, do not start: tell the user that `png-asset-production` is missing and how to install it, then stop.

Write in the `outline-timing` format of the `png-outline-tracing` skill: open the `png-outline-tracing` skill by name and read the file it names for `outline-timing`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `png-outline-tracing` skill is not installed, do not start: tell the user that `png-outline-tracing` is missing and how to install it, then stop.

## What it reads, writes, and sends

It reads the files of the user's Remotion project and the frames rendered there, and writes the plans under `storyboard/`, `beat-dossier.json`, `production.json`, `production.quality-loop.json`, and the files under `out/review/` there.
It runs Remotion in the user's project, and Node.js on its checks and on the checks it follows, which read only the files named on their command line and send nothing.
The catalog it searches downloads only the repositories of its own source list, and a search for a video to add to the motion evidence library uses only general words for the kind of motion.
