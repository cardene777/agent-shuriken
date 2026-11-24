# How Remotion Explainer works

English · [日本語](how-it-works.ja.md)

This page explains what each check of `remotion-frame-checks` reads, how it decides, and what it writes.
The checks are four Node.js scripts in `skills/remotion-frame-checks/scripts/` that use only the modules built into Node.js 18 or later.

## How a check runs

Each check reads the files named on its command line and nothing else.
It prints one JSON object to standard output with `check`, `decision`, `issueCount`, and `issues`, where each issue holds the `rule` it breaks, the `element`, `scene`, or `frame` it is about, and a `message`.

| Exit code | Means |
|---|---|
| 0 | The files pass, and `decision` is `pass` |
| 1 | The files need revising, and `decision` is `revise` |
| 2 | The check was called the wrong way or could not read a file; the reason is on standard error and nothing is printed to standard output |

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
| Writes | The audit files where `--audit-dir` or `--out` points, nothing else |
| Runs | Nothing but itself; rendering frames is done by Remotion in your project |
| Sends | Nothing; the checks make no network connection |
| Keeps | Nothing outside your project |
