---
name: remotion-explainer-production
description: Builds a Remotion explainer video whose pictures belong to its subject, from the approved rough, art direction, and beat dossier that remotion hands over - one shared layout, named anchors on the edges of objects, a safe area, one global frame clock, and scenes that hand objects on - and writes the layout, continuity, and spatial audit samples the review reads. Holds the explainer and spatial layout contracts. Use when remotion asks to implement or fix a Remotion explainer composition.
---

# Remotion explainer production

`remotion` calls this skill to implement the video, and Remotion is the only renderer.
Remotion does not draw the original art: the diagrams, people, documents, objects, and states of the subject arrive as approved PNGs with transparency, and Remotion handles only the placement, the time, the connections, the camera, and the scene transitions.
When the project has `production.json`, it is the one record to edit.
Talk to the user in the language they write in.

The files are next to this `SKILL.md`, and other skills follow them through musubi.

| Content | File | What it holds |
|---|---|---|
| `explainer` | `formats/explainer.md` | The layout, richness, scene handoff, and geometry rules of an explainer composition |
| `spatial-layout` | `formats/spatial-layout.md` | The geometry of each PNG, the one function that returns the layout of a frame, connectors, the frame audit, and chapter boundaries |

## Before building

1. Read `formats/explainer.md`, `formats/spatial-layout.md`, and the formats of other skills that "What it follows" names, when the step below needs them.
2. Use the official Remotion skills for every Remotion API the build needs. Open `remotion-best-practices` by name, `remotion-markup` for compositions, layout, animation, typography, and timing, and `remotion-docs` to check the current API and the version that brought it in; for a new project or composition, also `remotion-create`. When they are not installed, tell the user that `npx remotion skills add` in the Remotion project, or `npx skills add remotion-dev/skills` elsewhere, installs them, and meanwhile read the official Remotion documentation page of each API before using it. Never install the old Remotion MCP server.
3. Read `production.json`, the approved brief, the script, `beat-dossier.json`, and the art direction `remotion` asks for. Run `check-beat-dossier` on `beat-dossier.json`; when it does not pass, ask the user for the subject, the audience, the length, the visual direction, and whether there is a voice, and build no renderer.
4. Confirm that `production.json.compositionRough.approved` is `true`, and that the rough MP4, its compiled hash, and every beat of `out/review/composition-rough/index.json` exist. When any is missing, build no final art, still board, or voice, and send the work back to the rough of `remotion`.
5. Record in the visual fields of `production.json` the visual direction, the colors, the type, each scene's primary object, its before, operation, and after, and its connections, camera, and transitions. When the design pattern, the pattern adaptation, the visual premise, the object lexicon, the motion lexicon, or the scene promise is missing, build no renderer and send the work back to `remotion`. Never start a second record to edit.
6. When `production.json.visual.staticAssets[]` has entries, read the `static-art` format. When `artDirection.stageTheme.id` is `felt-applique`, read the `felt-applique` format. When the visual language is `paper-scribe`, read the `paper-scribe` and `paperboard` formats and run `check-paperboard` on `paperboard.json`. When the design pattern is `hand-drawn-narrative`, read that format and use only the `ink-primitives` template as the base of the drawing, drawing the subject's own scenery, people, and props anew.

## How to build

- One scene, one visual job. One primary object; supporting objects are there only to show its cause.
- Build each beat as one of `aperture`, `exchange`, `inspection`, `consequence`, or `handoff`. Keep on screen only the primary object, its counterpart, the evidence, and the object carried on. Never start or wait on a finished row of three.
- Each operation really changes who owns something, where it is, how much there is, when it is, a constraint, or an object's state. An appearance or a disappearance by opacity alone, a decorative move, or an arrow that repeats what is shown is no operation.
- For each primary object of the object lexicon, design the silhouette, the inner structure, the difference of state, and the result of the operation first, and ask for each shape as its own approved PNG. Never put a stock house, person, document, or arrow on screen under the subject's name.
- Every visual object of the subject uses the approved PNG of `production.json.visual.staticAssets[]`. Never use art as a whole scene; place each PNG on its own from the named anchors and bounds of `layout.ts`. Never import a PNG the manifest lacks, and never let a style ID decide a background, UI, or composition.
- Use the stage primitives of a stage theme only when the theme was chosen. With `felt-applique`, only the board, pockets, sewn tags, connectors, and annotations are allowed, and every pocket has a reason to hold something in the beat dossier. Pockets of one kind share their top, height, and label offset through one layout token, and never stretch to the aspect ratio of a PNG canvas.
- Remotion may draw only text, the traced outlines of PNGs, connector lines, arrows, masks, highlights, the frame of a screen, the camera, and transitions. Never draw people, companies, money, ledgers, state icons, shapes of the subject, cards, charts, or the main explaining diagram with DOM, SVG, CSS, or Canvas; send it back to `png-asset-production` for a PNG of each state.
- Static art with an outline handoff draws in the order trace for at least 1,400 ms, hold for at least 200 ms so it can be read, PNG paint, and outline release. Never show the PNG when the trace starts, keep an outline as a lasting frame, or replace a PNG with SVG alone.
- With `hand-drawn-narrative`, build each scene as an illustrated board of separate PNG art. Text and abstract signs in the middle, a single outline icon, or every object fading in at once fails.
- Each scene makes clear the order things are found: never place every PNG at the start, but bring in the primary object, then its counterpart in the cause, then the change of state. Art before its entrance has an opacity of 0 or sits off screen, and never keep the viewer waiting on a still finished layout.
- No slide with a chapter number and a big heading at the top left, repeated scene after scene. Text is only the state, condition, value, deadline, or result read next to the primary object at that moment. Define at least two annotations specific to the subject per scene in `layout.ts`, with their time, bounds, target, and source, and put text bounds into the same full-frame collision audit as PNGs and routes.
- When an object moving shows its route, no arrow lies on the same route. A connector is allowed only to explain a static relation the first time. A route keeps its own clear lane in the layout contract, apart from the PNGs, annotations, and moving lanes, and never crosses them in any frame, arrowhead included.
- Before the long video, build the 12 to 15 second reference scene `remotion` approved. While it is not approved, never build or hand over the whole video. The whole video shares only the visual grammar, and each scene finds and composes something new.
- Lay out the screen with DOM grid or flex, separating the safe area, the title, and the content. Use SVG only inside the parts of a diagram.
- Make one `layout.ts` that computes the viewport, the safe area, the named anchors, the object bounds, and the connections; never scatter coordinates through JSX. Give it a pure `frameLayoutAt()` that takes only the root's absolute frame, and use its result both in the renderer and in the review export.
- With `paper-scribe`, draw the paper structure, the outline, the paint, and the annotations of `paperboard.json` in that order on the root frame clock. Every structure connects to its object with a purpose in the explanation, and the camera moves to the next evidence of the handoff object. A finished board, generic cards, fades alone, a camera reset to the center, or an automatic silhouette trace nobody approved is never allowed.
- Connectors are only the primitive that implements `artDirection.connectorGrammar`. A connector belongs to the video's visual vocabulary: never a bare stroke, the standard `marker-end`, or a stock triangle arrow. Define its outer edge, body, texture line, port, and arrowhead apart. Draw it in front of the PNGs, stop its end before the outer anchor of the art, and never let it enter the art's silhouette or hide it under the art with z-index.
- A `felt-applique` connector is one piece: outer edge, fabric core, stitch, and sewn arrowhead, with no arrowhead delayed on its own. In a beat where an object moving along a route shows the cause, draw no connector; use connectors only for static relations, in a lane reserved beforehand.
- An outline handoff uses only the trace of the accepted alpha PNG. Before the PNG paints, never show a hand-drawn curve that does not match the object, an outline alone, or loose yarn. When the trace does not identify the primary object within 1.4 seconds, use a PNG entrance instead.
- `layout.ts` holds the visible bounds of each PNG, the real silhouette rather than the image canvas, and its padding, generated with the canvas size and the edge anchors from the accepted alpha PNG. Check PNG against PNG, route against PNG, and text against PNG in every scene, both in the still layout and in real frames at entry, turning, exit, and boundaries, and fail before rendering on any contact that is not written down. A route through art, an overlap hidden by z-index, or a contact fixed only by nudging coordinates is never allowed.
- Prove an arrival with coordinates. Give each transfer a `sourceZone`, `targetZone`, `routeAxis`, and `arrivalFrame` in the layout. Audit the real bounds at 0, 25, 50, 75, and 100%, keep the same y for a sideways move and the same x for a vertical one, and at the arrival keep the whole alpha visible bounds of the object inside the target zone, never stopping in front of, beside, or on the lane of the target. When the object goes into a pocket or a container, the target zone is the inner bounds of the container.
- Audit the visual center of the composition at entry, turning, and exit from the weighted bounds of the primary object, the support, the annotations, and the needed stage. Unless the dossier records an intended one-sided composition and what the empty space is for, a center outside 40 to 60% across and 38 to 62% down the safe content is `revise`. In an exchange, the left and right support differ in weight by no more than 25%. Use visible bounds, never the PNG canvas.
- Never fake the detail of a long video by repeating. Each beat of `beat-dossier.json` has a `learningLayer`; a video of five minutes or more needs at least six different layers, and a layer that comes back needs a new condition, evidence, or result.
- Draw the whole video as one root composition on one global frame clock. Scenes that clear and redraw the whole screen on their own, a separate background per scene, or a reset per chapter is never allowed; when scene modules are split, pass them the same stage, layout, and state from the parent.
- Every boundary has at least one primary object that is carried on, or that changes form as it is handed on: a record, an amount, a duty, a route, a container, or the camera changes, moves, or is rebuilt in the next chapter for a reason.
- Never swap objects by switching the chapter heading alone. The exit of a scene overlaps the entry of the next in time and continues from the same anchor source.
- Connect objects at their outer edges or ports, never at their visual centers, and use another outer anchor after a rotation.
- The camera, masks, transforms, and state transitions read the same layout source. The camera moves to where the object is handed on and never resets to the origin in the next scene. Never leave the animation to CSS keyframes or to outside files that depend on time.
- Build richness in this order: the PNG art's silhouette, inner structure, edge, accent, state PNGs, and then the camera. Never add decorations, cards, fake icons, or constant animation drawn in Remotion.
- When an object, a motion, or a scene could be reused for another subject unchanged, it is not specific enough: make the art direction and the scene dossier again.
- Motion is only an entrance, a real change of state, or a scene transition. Hold 100 to 500 ms at chapter boundaries. Drifting, breathing, or pulsing without meaning is never allowed.
- Give the `Composition` a Zod schema and default props so it can be adjusted in Remotion Studio.
- Never quietly change the viewer question, primary object, operation, handoff, or scene order approved in the rough while building. When one must change, do not treat it as a coordinate fix of one scene: send it back to `remotion` to update the whole rough.

## What the build writes

Write these into the project, with values from the layout functions the renderer really uses.

| File | Holds |
|---|---|
| `src/.../layout.ts` | The named anchors, bounds, camera track, and safe area of each scene |
| `out/review/geometry-samples.json` | The real bounds and connections at each sampled frame, entry, turning, exit, and camera transitions included, in the `geometry-samples` format of `remotion-explainer-review` |
| `out/review/continuity-samples.json` | The before, during, and after of every boundary, the persistent objects, the handoffs, and the camera track, in the `continuity-samples` format of `remotion-explainer-review` |
| `out/review/spatial-route-audit.json` | For each transfer, the source and target zones, the bounds at 0, 25, 50, 75, and 100%, the deviation from the axis, collisions, and the arrival |
| `out/review/composition-balance-audit.json` | The visible-bounds center at each entry, turning, and exit, the left and right support ratio, and the reason for each intended exception |
| `out/review/<scene>-<frame>.png` | The real renders of the same sample frames and of every boundary |
| `production.quality-loop.json` | One appended entry per iteration: the compiled hash, the issues, where each fix went, and the evidence |
| `out/review/stage-theme-audit.json` | With a stage theme: the theme ID, the asset style ID, each scene's primitives and reasons to hold, the shared label token, and each connector's route, clear lane, and arrowhead |
| `beat-dossier.json` | The dossier the renderer read, passing its check |
| `out/review/beat-review.json` | The current compiled hash, the dossier hash, the four real frames of each beat, and each beat's six scores, passing `check-beat-review` before it goes back to `remotion` |
| `out/review/composition-rough/index.json` | The beat IDs, compiled hash, and approval time of the approved rough, and whether each final scene matches its viewer question, primary object, operation, and handoff |

Also write the layout spec of the project and run the layout, SVG geometry, and timing boundary checks of `remotion-frame-checks` on what the build wrote, by their formats.
With static art, tie each asset's manifest, its light, dark, and scene composites, its outline handoff when there is one, and its frames at early trace, 70% trace, paint partway, and settled to the quality loop.

## Hand back to remotion

1. Render the scenes at a low resolution, or only the target scenes, and write the samples and the frames tied to the current source hash.
2. Give `remotion` the implementation, the paths of what it wrote, and the hashes. Never decide `candidate` yourself.
3. Fix only what `remotion-explainer-review` names. After rendering again, `remotion` always sends the build to the review again.

When `node` is missing, tell the user to install Node.js 18 or later and stop.

## Never

- Hand over a candidate from a single TSX file, an old composition, or an MP4 rendered by hand apart from the build
- Let a collision, a breach of the safe area, an anchor that does not match, a cut label, a sign that stays without meaning, or a cleared board, a reset, or a fade alone at a boundary pass as a small visual problem
- Put a triangle marker or an undefined coin, seal, or round sign in place of a cause or of things happening at once; show a cause with a change of state in the art and a two-way route with meaning
- Decide the whole composition from how a PNG or a theme looks
- Decide the whole structure from finished art per scene or from motion trials, without the approved rough of every beat
- Draw with Remotion's SVG, DOM, CSS, or Canvas a primary object or state that has no approved PNG
- Go on to the next step, the voice, versions made from the video, or the user while `issueCount` is above 0

## Before handing back

1. Can the cause, the state, and the condition be read without the voice?
2. Can the role and shape of every object be explained?
3. Is every sample frame inside the safe area, with no overlap that is not allowed?
4. Is every connection within its anchor tolerance?
5. Does every boundary have a persistent object or a handoff, a reason for the change, and a camera track?
6. Can the layout and continuity samples, the real frames, and the source hash go back to `remotion`?

## What it follows

Write in the `art-direction` format of the `remotion` skill: open the `remotion` skill by name and read the file it names for `art-direction`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

Write in the `beat-dossier` format of the `remotion` skill: open the `remotion` skill by name and read the file it names for `beat-dossier`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

Run the `check-beat-dossier` of the `remotion` skill: open the `remotion` skill by name and run the file it names for `check-beat-dossier`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

Write in the `composition-and-staging` format of the `remotion` skill: open the `remotion` skill by name and read the file it names for `composition-and-staging`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

Write in the `reference-beats` format of the `remotion` skill: open the `remotion` skill by name and read the file it names for `reference-beats`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

Write in the `engineering` format of the `remotion` skill: open the `remotion` skill by name and read the file it names for `engineering`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

Write in the `static-art` format of the `remotion` skill: open the `remotion` skill by name and read the file it names for `static-art`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

Write in the `felt-applique` format of the `remotion` skill: open the `remotion` skill by name and read the file it names for `felt-applique`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

Run the `check-stage-theme` of the `remotion` skill: open the `remotion` skill by name and run the file it names for `check-stage-theme`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

Write in the `hand-drawn-narrative` format of the `remotion` skill: open the `remotion` skill by name and read the file it names for `hand-drawn-narrative`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

Write in the `ink-primitives` format of the `remotion` skill: open the `remotion` skill by name and read the file it names for `ink-primitives`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

Write in the `paper-scribe` format of the `remotion` skill: open the `remotion` skill by name and read the file it names for `paper-scribe`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

Write in the `paperboard` format of the `remotion` skill: open the `remotion` skill by name and read the file it names for `paperboard`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

Run the `check-paperboard` of the `remotion` skill: open the `remotion` skill by name and run the file it names for `check-paperboard`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

Write in the `beat-review` format of the `remotion` skill: open the `remotion` skill by name and read the file it names for `beat-review`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

Run the `check-beat-review` of the `remotion` skill: open the `remotion` skill by name and run the file it names for `check-beat-review`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

Write in the `geometry-samples` format of the `remotion-explainer-review` skill: open the `remotion-explainer-review` skill by name and read the file it names for `geometry-samples`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-explainer-review` skill is not installed, do not start: tell the user that `remotion-explainer-review` is missing and how to install it, then stop.

Write in the `continuity-samples` format of the `remotion-explainer-review` skill: open the `remotion-explainer-review` skill by name and read the file it names for `continuity-samples`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-explainer-review` skill is not installed, do not start: tell the user that `remotion-explainer-review` is missing and how to install it, then stop.

Write in the `layout` format of the `remotion-frame-checks` skill: open the `remotion-frame-checks` skill by name and read the file it names for `layout`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-frame-checks` skill is not installed, do not start: tell the user that `remotion-frame-checks` is missing and how to install it, then stop.

Run the `check-layout` of the `remotion-frame-checks` skill: open the `remotion-frame-checks` skill by name and run the file it names for `check-layout`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-frame-checks` skill is not installed, do not start: tell the user that `remotion-frame-checks` is missing and how to install it, then stop.

Write in the `svg-geometry` format of the `remotion-frame-checks` skill: open the `remotion-frame-checks` skill by name and read the file it names for `svg-geometry`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-frame-checks` skill is not installed, do not start: tell the user that `remotion-frame-checks` is missing and how to install it, then stop.

Run the `check-svg-geometry` of the `remotion-frame-checks` skill: open the `remotion-frame-checks` skill by name and run the file it names for `check-svg-geometry`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-frame-checks` skill is not installed, do not start: tell the user that `remotion-frame-checks` is missing and how to install it, then stop.

Write in the `timing-boundary` format of the `remotion-frame-checks` skill: open the `remotion-frame-checks` skill by name and read the file it names for `timing-boundary`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-frame-checks` skill is not installed, do not start: tell the user that `remotion-frame-checks` is missing and how to install it, then stop.

Run the `check-timing-boundary` of the `remotion-frame-checks` skill: open the `remotion-frame-checks` skill by name and run the file it names for `check-timing-boundary`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion-frame-checks` skill is not installed, do not start: tell the user that `remotion-frame-checks` is missing and how to install it, then stop.

Write in the `asset-manifest` format of the `png-asset-production` skill: open the `png-asset-production` skill by name and read the file it names for `asset-manifest`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `png-asset-production` skill is not installed, do not start: tell the user that `png-asset-production` is missing and how to install it, then stop.

Write in the `outline-timing` format of the `png-outline-tracing` skill: open the `png-outline-tracing` skill by name and read the file it names for `outline-timing`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `png-outline-tracing` skill is not installed, do not start: tell the user that `png-outline-tracing` is missing and how to install it, then stop.

## What it reads, writes, and sends

It reads the files of the user's Remotion project, and writes the composition, `layout.ts`, `production.json`, and the files under `out/review/` there.
It runs Remotion in the user's project to render frames, and Node.js on the checks it follows, which send nothing anywhere.
