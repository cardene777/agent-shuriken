---
name: remotion-explainer-review
description: Reviews a Remotion explainer video apart from the skill that built it, in real rendered frames - the safe area, overlaps, connections, legibility, continuity across scene boundaries, how specific the art is to the subject, and the purpose of each motion - and sends it back until no issue is left. Holds the geometry and continuity sample contracts and their Node.js checks. Use when remotion asks for an independent review of a build, or when checking whether a Remotion explainer can be handed to the user.
---

# Remotion explainer review

A render that finishes, a type check that passes, or one good-looking still is never a reason to pass.
This skill reviews apart from `remotion-explainer-production`, and never hands a build with a known flaw to the user.
`remotion` calls it after every build and after every fix.
Talk to the user in the language they write in.

The files are next to this `SKILL.md`, and other skills follow them through musubi.

| Content | File | What it holds |
|---|---|---|
| `geometry-samples` | `formats/geometry-samples.md` | `out/review/geometry-samples.json`: the real bounds of every visible object at sampled frames |
| `check-geometry-samples` | `scripts/check-geometry-samples.mjs` | The check of the safe area, overlaps, connections, and objects that must hold still |
| `continuity-samples` | `formats/continuity-samples.md` | `out/review/continuity-samples.json`: the objects, states, and camera at every scene boundary |
| `check-continuity-samples` | `scripts/check-continuity-samples.mjs` | The check that each boundary carries an object or a handoff without a jump |

The `examples/` folder holds a valid file of each kind.

## Check the inputs

1. Read `production.json`, the current renderer source and its compiled hash, `production.quality-loop.json`, `beat-dossier.json`, and `out/review/beat-review.json`. When the art direction has no design pattern, pattern adaptation, visual premise, object lexicon, motion lexicon, or scene promise, decide `revise` at once.
2. Read the direction, the staging, the reference beats, the quality review, and the beat review formats of `remotion` (the lines under "What it follows" name each). When `beat-dossier.json` is missing or fails its check, decide `revise` at once.
3. When `artDirection.stageTheme.id` is `felt-applique`, read the `felt-applique` format and `out/review/stage-theme-audit.json`, and run `check-stage-theme`; when the theme ID, the asset style ID, a primitive, or a reason does not match, decide `revise` at once.
4. When the design pattern is `hand-drawn-narrative`, read that format. When the visual language is `paper-scribe`, read the `paper-scribe-review` format and `paperboard.json`, and run `check-paperboard`; when it does not pass, decide `revise` at once.
5. Check `production.json.compositionRough`, `out/review/composition-rough/index.json`, and the rough MP4. When the human approval of the silent rough of every beat, the rough's compiled hash, or the viewer question, the primary object, the operation, the read, or the handoff of any beat is missing, decide `revise` at once. When the scene order, the primary object, an operation, or a handoff changed after the approval, ask for the whole rough to be approved again, however good each scene looks.
6. Read `formats/geometry-samples.md` and `formats/continuity-samples.md`, and confirm that `out/review/geometry-samples.json` and `out/review/continuity-samples.json` came from the renderer's own layout source. When the source hash and the samples' hash differ, decide `revise`.
7. Run `check-beat-review` on `out/review/beat-review.json`. When the dossier hash, the compiled hash, the four real frames of every beat, or the scores of a beat are missing, decide `revise` at once.

## Review

0. Watch the rough MP4 from start to end, and score whether every beat has collapsed into the same "object in the middle moving sideways", the same row of cards, or the same empty side. Each beat needs its own order of looking or its own physical operation for its viewer question. A centroid pulled to one side, waiting, a cleared board, the same move repeated, or a missing handoff is `composition-rough-breach`, and the decision is `revise`.
1. Run the geometry check on the samples, then the layout, SVG geometry, and timing boundary checks of `remotion-frame-checks` on the files the build wrote:
   `node <skill>/scripts/check-geometry-samples.mjs out/review/geometry-samples.json`
   Here `<skill>` is the path of this skill's folder. A failure of the safe area, the bounds taken from alpha, a collision between PNGs or with a visible title or caption, a route or arrowhead path, a connection, or a stable track decides `revise` at once.
2. Run the continuity check:
   `node <skill>/scripts/check-continuity-samples.mjs out/review/continuity-samples.json`
   A boundary without a persistent object or a handoff, without its before, during, and after frames, or without a camera track decides `revise` at once.
3. When the project has static art, audit it by the `static-art` format of `remotion`: for every asset, the manifest, the alpha source, the three composites, and the agent's and the person's pass. For an asset with an outline, look at the four frames the `outline-timing` format of `png-outline-tracing` names. A trace shorter than 1,400 ms, a PNG that settles before it can be read, an outline left as a lasting border, matte or fringe, or art standing in for an explaining diagram is `static-art-breach`, and the decision is `revise`.
4. Render each scene's entry, turning, and exit frames, and a frame while the camera moves, and look at the before, during, and after frames of every boundary: at least four frames per scene. Check each of these on its own:
   - Nothing but the primary object is left half on screen at an edge
   - No text is cut off, covers the primary object, or is too small to read
   - The scene is not a slide with only a chapter number, a chapter name, and a big heading at the top left; its text belongs to the scene's state, value, deadline, or result, with at least two annotations specific to the subject
   - Nothing covers what it may not, nothing is drawn twice, no line pierces an object, and no connection is off
   - No arrow of the same meaning lies on the route of an object that really moves; a connector has its own clear lane, apart from the moving lane, the PNGs, and the annotations, and does not cross them, arrowhead included
   - With `felt-applique`, the pockets of one kind share their top, height, and label baseline as the shared token sets, every exception has a reason to hold something, and the board supports the subject's operation. A constant three-column grid, a pocket only to show off art, or heights set by the PNG canvas is `felt-stage-breach`
   - With `felt-applique`, an arrow keeps its outer edge, fabric core, stitch, and sewn arrowhead together, its tip and shaft never part, and it stays inside its clear lane in front of its targets. A bare curve, loose yarn, `marker-end`, a route hidden behind its target, or an outline alone that does not match the PNG's shape is `felt-connector-breach`
   - One frame alone tells the state of the subject
   - Cards, tags, arrows, and icons are not only markers to follow
5. Watch the whole video. Each scene's exit leads by cause into the next scene's entry, and no transition is only a fade or a background swap. A moment when the primary object neither continues, changes form, moves, nor is rebuilt is `continuity-break`. Each beat needs a question, a proof, a read, and a handoff; a heading alone, a still without reason, an arrow that traces the same move, or an object that leaves without making the next state is `explainer-beat-breach`. With `paper-scribe`, check in real frames the order paper structure, outline, paint, annotation, what each structure is for, why the focus moves, and the handoff object's role in the next beat; one broken order, focus, or handoff is `paper-scribe-breach`.
6. Score subject specificity, fit of structure, readable cause, purpose of motion, continuity, and composition from 1 to 5. Also score each beat by the quality review format of `remotion`. Score continuity boundary by boundary, and give no credit for a shared background, a timeline, or fades. Any score below 4, for the whole or for one beat, decides `revise`.
7. Check the reference scene: a real MP4 of 12 to 15 seconds, its entry, turning, and exit frames, three state changes, two changes of form that the subject explains, and an exit the next scene can take over. When any is missing, the whole video is `revise`; when the person's approval of the reference scene is not recorded, the whole video is never a candidate.
8. Audit the art direction scene by scene: (a) the primary object's shape shows its role in the lexicon, (b) the difference from other scenes is more than colors, headings, or background, (c) the motion carries the meaning the lexicon gives it, (d) no composition, silhouette, or motion is reused. One no is `generic-art-direction`, and the decision is `revise`.
9. With `hand-drawn-narrative`, check in real frames that (a) the scene reads within 1.5 seconds, (b) the primary object has an outline, an inner structure, a difference of state, and a trace of its story, (c) text and abstract signs do not replace the story, and (d) paths draw in the order the cause is read. When not, it is `hand-drawn-pattern-breach`, and the decision is `revise`.

## Decide

Append one entry to `production.quality-loop.json`:

```json
{
  "iteration": 3,
  "compiledHash": "...",
  "evidence": {"geometry": "...", "frames": ["..."], "fullVideo": "..."},
  "issues": [{"id": "overlap-01", "owner": "remotion-explainer-production", "frame": 240, "fix": "..."}],
  "scores": {"subject": 5, "structure": 4, "causality": 4, "motion": 4, "continuity": 4, "composition": 4},
  "issueCount": 1,
  "decision": "revise"
}
```

- `candidate` only with `issueCount: 0`, every score 4 or more, a `beat-review.json` that passes its check, the current compiled and dossier hashes, the geometry and continuity checks passing, the real frames, and a full watch
- A long video also needs the reference scene's real files and the person's approval
- Anything else is `revise`. The owner is `remotion-explainer-production` by default, or the skill that owns the script or the storyboard when the cause is there
- When the same kind of issue comes twice in a row, the fix moves from coordinates to the layout API, the scene plan, the component design, or the skill's format

Give `remotion` the entry and the paths of the evidence. This skill never fixes the build itself.

When `node` is missing, tell the user to install Node.js 18 or later and stop.

## What it follows

Write in the `art-direction` format of the `remotion` skill: open the `remotion` skill by name and read the file it names for `art-direction`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

Write in the `explainer-direction` format of the `remotion` skill: open the `remotion` skill by name and read the file it names for `explainer-direction`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

Write in the `composition-and-staging` format of the `remotion` skill: open the `remotion` skill by name and read the file it names for `composition-and-staging`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

Write in the `reference-beats` format of the `remotion` skill: open the `remotion` skill by name and read the file it names for `reference-beats`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

Write in the `video-quality-review` format of the `remotion` skill: open the `remotion` skill by name and read the file it names for `video-quality-review`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

Write in the `beat-dossier` format of the `remotion` skill: open the `remotion` skill by name and read the file it names for `beat-dossier`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

Run the `check-beat-dossier` of the `remotion` skill: open the `remotion` skill by name and run the file it names for `check-beat-dossier`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

Write in the `beat-review` format of the `remotion` skill: open the `remotion` skill by name and read the file it names for `beat-review`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

Run the `check-beat-review` of the `remotion` skill: open the `remotion` skill by name and run the file it names for `check-beat-review`.
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

Write in the `paper-scribe-review` format of the `remotion` skill: open the `remotion` skill by name and read the file it names for `paper-scribe-review`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

Write in the `paperboard` format of the `remotion` skill: open the `remotion` skill by name and read the file it names for `paperboard`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

Run the `check-paperboard` of the `remotion` skill: open the `remotion` skill by name and run the file it names for `check-paperboard`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `remotion` skill is not installed, do not start: tell the user that `remotion` is missing and how to install it, then stop.

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

Write in the `outline-timing` format of the `png-outline-tracing` skill: open the `png-outline-tracing` skill by name and read the file it names for `outline-timing`.
If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.
If the `png-outline-tracing` skill is not installed, do not start: tell the user that `png-outline-tracing` is missing and how to install it, then stop.

## What it reads, writes, and sends

It reads the files of the user's Remotion project and the frames rendered there, and writes only `production.quality-loop.json` and the files under `out/review/`.
The checks read only the files named on their command line and send nothing anywhere.
