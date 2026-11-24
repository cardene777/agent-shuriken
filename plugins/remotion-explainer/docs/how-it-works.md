# How Remotion Explainer works

English · [日本語](how-it-works.ja.md)

This page explains what each check of `remotion-motion-plan` and `remotion-frame-checks` reads, how it decides, and what it writes.
The checks are eight Node.js scripts, four in `skills/remotion-motion-plan/scripts/` and four in `skills/remotion-frame-checks/scripts/`, that use only the modules built into Node.js 18 or later.

## How a check runs

Each check reads the files named on its command line and nothing else.
It prints one JSON object to standard output with `check`, `decision`, `issueCount`, and `issues`, where each issue holds the `rule` it breaks, the `element`, `scene`, `frame`, or library `entry` it is about, and a `message`.

| Exit code | Means |
|---|---|
| 0 | The files pass, and `decision` is `pass` |
| 1 | The files need revising, and `decision` is `revise` |
| 2 | The check was called the wrong way or could not read a file; the reason is on standard error and nothing is printed to standard output |

## Choreography

`check-choreography.mjs` reads `storyboard/choreography-plan.json`.
For each scene it checks the fields of the scene, its camera, each object, and each motion beat, then three things that make a scene a scene rather than a still picture.

| Rule | How it decides |
|---|---|
| `no-late-introduction` | Every object's `introducedAt` is `entry` |
| `no-state-change` | Every object's `resultState` equals its `entryState` |
| `motion-variety` | The motion beats have fewer than two different kinds |

Across the plan, it compares each scene's view grammar with the one before it, counts the scenes that carry sideways, which may be at most two, and counts the grammars used, which must be at least four, or one per scene in a plan of fewer than four scenes.
Each of the six keys of `finalMotionParity` must be `true`.

## Continuous choreography

`check-continuous-choreography.mjs` reads `storyboard/continuous-choreography-plan.json` and walks the scenes in order.

| Rule | How it decides |
|---|---|
| `handoff-not-carried` | The subject of a scene's `entryFrom` is neither the subject nor the `becomes` of the `exitTo` of the scene before it |
| `persistent-subject-share` | Fewer than half of the scenes list one of `persistentSubjects` among their subjects |
| `repeated-axis` | A scene and the scene before it have the same `primaryAxis`, other than `none` |
| `three-scenes-without-change` | In three scenes in a row, no `continuityMode` is `object-transform`, `container-reveal`, or `spatial-reframe`, and no `cameraRelation` is `push-in`, `pull-out`, or `orbit` |
| `summary-new-subject` | The scene with the role `summary` lists a subject that no earlier scene listed or became |

## Motion language

`check-motion-language.mjs` reads `storyboard/motion-language-plan.json` and the user's motion evidence library.
It indexes the library's entries by ID and checks each scene's recipe and mechanism against the lists of the contract.
A scene that cites no entry is `missing-evidence`, one that cites an ID the library lacks is `unknown-evidence`, and one whose cited entries include no `verified` entry listing its main recipe is `unverified-evidence`.
Neighboring scenes may not share a main recipe, a plan of eight scenes or more needs six main recipes, and at most two scenes have `object-handoff` as their main recipe.

## Motion evidence

`check-motion-evidence.mjs` reads the library named on its command line, which the skill keeps as `motion-evidence-library.json` in `~/.local/share/remotion-explainer/` or in the folder `REMOTION_EXPLAINER_HOME` names.
Each entry needs a unique ID, a status of `verified` or `candidate`, a source with a platform, a title, and an `http` or `https` address, at least one observation with a range and a description, the recipes it shows, `useWhen`, `avoidWhen`, and a `reviewedAt` day.
Every observation of a verified entry must have a time range such as `00:13-00:45` or `1:02:10-1:02:30`, because only a played video can be verified.
An empty library passes; a plan that cites nothing from it does not.

## SVG geometry

`check-svg-geometry.mjs` reads `storyboard/svg-geometry.json`.
It indexes every element and its ports, then checks five groups in order.

| Group | How it decides |
|---|---|
| Elements and ports | Each element has an id, a role, and positive bounds. Each port lies inside its element and within its tolerance, 1 pixel by default, of the edge it names |
| Connectors | The first point lies within the tolerance of the source port and the last point of the target port. Each segment of the path is tested against the bounds of every element the connector avoids: a segment crosses when an end lies inside the bounds or when it crosses one of the four sides |
| Clearances | For each pair, the bounds must not overlap, and the shortest distance between the two boxes must be at least the minimum |
| Arrivals | The point reached at the arrival frame lies within the tolerance of the target port, and the final bounds fit inside the target zone |
| Review | The review scales include 1 and 0.5, and at least three frames are named |

## Layout

`check-layout.mjs` reads `storyboard/layout-spec.json`.
Every element must lie inside the safe area unless it allows otherwise, and only captions may touch the subtitle zone.
Clearances are decided the same way as for SVG geometry.
An alignment group compares its members' tops, bottoms, widths, heights, or the gaps between neighbors, sorted from left to right, and refuses a spread larger than its tolerance.
A route is a box, and it may not overlap the bounds of an element it avoids.
An element that stands for a video frame has an aspect ratio, and the check refuses one that differs by more than 0.02.

With `--audit-dir <folder>` the check also writes three files there, each holding the SHA-256 of the layout file, so a review can tell whether the audit belongs to the current file.

| File | Holds |
|---|---|
| `layout-samples.json` | The review frames and the elements as the layout file has them |
| `collision-audit.json` | Every clearance rule with the distance found and its decision |
| `spatial-route-audit.json` | Every route and avoided element with its decision |

## Timing boundary

`check-timing-boundary.mjs` reads PNG frames given as `<frame>=<file>`, the background color, and the start or end frame.
It reads each PNG with Node.js's `zlib`: it checks the signature, joins the image data, inflates it, and undoes the five row filters.
It reads 8-bit, non-interlaced images of every color type, including a palette and a transparency chunk, and stops with exit 2 on any other PNG.

A pixel counts as visible when its alpha is above 0.02 and one of its red, green, and blue values differs from the background by more than 3.
The frames are sorted by number, and the check reports these issues.

| Rule | How it decides |
|---|---|
| `missing-boundary-frame` | A frame from two before the boundary to two after it was not given |
| `premature-visible-pixels` | With `--start`, a frame at or before the start has a visible pixel |
| `late-visible-pixels` | With `--end`, a frame at or after the end has a visible pixel |
| `short-lived` | A run of frames with visible pixels spans three frames or fewer and has a frame without any before and after it |
| `flicker` | A frame without visible pixels lies between two runs of frames with them |

The result also holds the count of visible pixels of each frame and the SHA-256 of all the frames read.
With `--out <file>` it writes the same JSON to that file, making its folder when needed.

## Scene layers

`check-scene-layers.mjs` reads `storyboard/scene-design-layers.json`.
Each scene needs an id, the viewer question it answers, and its four layers.
A layer from the catalog names the entry and what was adapted, a bespoke layer gives its reason, and only typography may be left out with `none`.
The silhouette family, spatial grammar, and reveal grammar of each scene are compared with the scene before it, and the check refuses when all three are the same.

## What it reads, writes, and sends

| Kind | What |
|---|---|
| Reads | The files named on the command line |
| Writes | The checks write only the audit files where `--audit-dir` or `--out` points; the agent writes the plans under `storyboard/` and the entries of the library |
| Runs | Nothing but itself; rendering frames is done by Remotion in your project |
| Sends | The checks make no network connection; a search for a video uses only general words for the kind of motion |
| Keeps | The motion evidence library in the data folder, readable only by you, until you delete it; nothing else outside your project |
