# Engineering

Do not list the features of Remotion.
Bring the meaning of the subject, a stable composition, exact geometry, timing that can be read, motion with a purpose, and the right compositing together into one video.

Quality is defined as follows.

```text
quality = clarity of meaning
        x legibility of composition and text
        x accuracy of geometry
        x purpose of motion
        x continuity between scenes
        x quality of the real frames after rendering
```

Using a new API, effect, 3D, or particles does not count toward quality.
When any one factor breaks, the video is not a finished candidate.

## 1. Fix the Remotion environment before implementing

1. In `package.json`, check that `remotion` and every `@remotion/*` package have exactly the same version. Pin them all to that version without a caret
2. Fix the width, height, fps, and duration of the composition first. A landscape video starts at 1920x1080 and 30 fps
3. Load fonts in a shared module outside the composition, and make them available before rendering starts. Never depend on a system font without saying so
4. Derive randomness from `random(seed)` or `@remotion/noise`. Do not use `Math.random()`, `Date.now()`, CSS transitions, or CSS keyframes
5. When using WebGL, WebGPU, `HtmlInCanvas`, or effects, check with a small probe the official documentation for the project's version, the conditions of the Studio preview, and the `--gl` setting at render time

## 2. Design a scene as a change of state, not a screen

Define each scene in these five stages, not as a finished screen.

| Stage | Role on screen | Implementation |
|---|---|---|
| Orient | The primary and its first state are understood | Place the primary first, and attach the explaining text afterwards |
| Tension | What is wrong, or what is not yet connected, is shown | Show distance, absence, occlusion, or contrast through the states of objects |
| Operation | One operation is done to the primary | Make one of moving, connecting, splitting, gathering, or transforming the main motion |
| Read | The result of the operation stops and is read | Hold for at least 45 frames by default |
| Handoff | The state passes to the next scene | Continue the same object, shape, and camera target into the next scene |

Give one scene one main motion and at most two supporting motions.
Do not move the title, the diagram, the caption, a badge, and the background at the same time.

## 3. Choose the means from the meaning

| To explain | First choice | How to use it in Remotion |
|---|---|---|
| The reading order and emphasis of text | DOM, masks, and `@remotion/layout-utils` | Measure the text, and reveal it word by word or line by line |
| A route, a cause, an arrival | SVG, `@remotion/paths`, and `@remotion/shapes` | Derive the line, the moving position, the direction, and the arrowhead from the same path |
| A change of state of the same object | SVG path morph, masks, color interpolation | Keep one identity, without a crossfade |
| Focus, depth, speed | `@remotion/effects`, `HtmlInCanvas` | Use blur, glow, and light trails locally |
| Organic change that can be reproduced | `@remotion/noise` | Make textures and flows from a seed and the frame |
| Layers in depth and camera moves | `@remotion/three` or React Three Fiber | Only for spatial relations that 2D cannot convey |
| Complex 2D illustration | `@remotion/skia` | When drawing on a canvas is more natural than the DOM |
| Approved animation assets | Rive or Lottie | Sync the asset's state and timeline to the Remotion frame |
| Source video, audio, captions | `@remotion/media`, captions | Let a Remotion component manage loading and render sync |

In production, the art direction of `formats/art-direction.md` comes first.
The subject's people, objects, and documents use approved assets; DOM, SVG, and Canvas carry text, masks, traces, connectors, the camera, effects, and rough proxies.
Never give up what belongs to the subject in order to use an API.

## 4. Build the composition so its quality is hard to break

Keep these responsibilities apart.

```text
CompositionRoot
|-- GlobalStage        background, fonts, palette, subtitle safe zone
|-- SceneSequence      makes each scene's local frame from the global frame
|-- SubjectLayer       the primary asset, its state, its operation
|-- RelationshipLayer  paths, connectors, masks, effects
|-- AnnotationLayer    short text attached to the primary
|-- CaptionLayer       in front of everything, in a fixed safe zone
`-- ReviewOverlay      during development only; turned off in a candidate
```

- Do not mix the timeline, the geometry, the style tokens, and the content in one TSX file
- Do not scatter the start frames of scenes through components; gather them in the timeline definition
- Do not define the same pixel coordinates in several components; gather anchors, zones, and paths in one source of geometry
- State the order of the `AbsoluteFill` layers, and do not start needless `z-index` contests
- Derive each scene's local frame from a `Sequence` or a stated scene start, so its relation to the global frame can be traced

## 5. Finish the settled frame first

Before adding motion, render the `Read` frame after the operation.

- In 16:9, start with a safe area of 88 to 156 px on the left and right and 58 to 105 px at the top and bottom
- With subtitles, keep the bottom 180 to 220 px for subtitles alone, with no band of conclusions or small remarks in it
- Start with headlines of 64 to 92 px, body text of 21 to 28 px, and at least 20 px for any label needed to understand
- Use at most three levels: the heading, the main figure, and the supporting text
- Do not push the center of meaning of the primary to the top of the frame alone. Give every empty area a reason: a destination, a contrast, or a pause
- Use `fitText()` with a limit on the largest font size. When the fitted size is below the smallest font size, change the copy or the layout instead of shrinking the text
- A border narrows the width that text fitting gets; consider an outline for the measured box

When the settled frame alone cannot answer the viewer's question, do not rescue it with motion; go back to the layout.

## 6. Drive motion from the frame

Derive every motion value deterministically from `useCurrentFrame()` and `useVideoConfig()`.

```tsx
const frame = useCurrentFrame();
const {fps} = useVideoConfig();

const enter = spring({
  frame: frame - enterAt,
  fps,
  config: {damping: 24, stiffness: 140, mass: 0.9},
});

const readProgress = interpolate(
  frame,
  [operationAt, operationDoneAt],
  [0, 1],
  {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
);
```

- Clamp `interpolate()` outside its range as a rule
- Use `spring()` only for appearing, landing, and settling, never for a constant bounce
- Use ease-out for arrivals and reveals, ease-in for exits and acceleration, and linear only for a physical reason such as a scan or a constant speed
- Never show a change with opacity alone. Move the value that matches the meaning: the position, a mask, the shape, the scale, or the focus
- Build the reading order with staggering, but not as a plain row of equal steps. Vary the gaps by units of meaning

## 7. Make paths, connectors, and the objects that follow them from one geometry

Never approximate a route with coordinates judged by eye.

```tsx
const d = 'M 180 420 C 520 160 920 700 1440 390';
const length = getLength(d);
const progress = interpolate(frame, [start, end], [0, 1], {
  extrapolateLeft: 'clamp',
  extrapolateRight: 'clamp',
});
const point = getPointAtLength(d, length * progress);
const tangent = getTangentAtLength(d, length * progress);
const angle = Math.atan2(tangent.y, tangent.x) * 180 / Math.PI;
const evolution = evolvePath(progress, d);
```

- Derive the line, the moving object, and the arrowhead from the same `d`
- Check the path's bounds with `getBoundingBox()`, and check that it does not cross text or the subtitle safe zone
- Consider `evolvePath()` or `cutPath()` for drawing a path
- Consider `interpolatePath()` for a shape morph, and never force a morph between different identities
- When the object itself shows the route, do not lay a second arrow on the same route

## 8. Move typography as video

- Do not fade a whole sentence in. Change the mask, weight, color, and position by units of meaning
- Do not turn text into a footer explanation far from the primary; attach it near the state, the condition, or the result
- Do not keep the title as a permanent header. After the orientation, shrink it into the primary, or let it leave once its job is done
- Keep subtitles and scene annotations in different layers with different roles. Never put copy of the scene in the subtitle area
- Do not add punctuation or small Latin-letter labels as decoration. Keep only what the script's meaning and the language need
- No one can start reading text that is moving. Count as reading time only the hold after its position and opacity are stable

## 9. Use effects, compositing, and the camera for a purpose

Adopt an effect only when it improves one of these.

| Purpose | Effect |
|---|---|
| Focus | Blur or desaturate everything but the primary, locally |
| Depth | Separate the foreground, the subject, and the background by scale, blur, or parallax |
| Velocity | Motion blur or a light trail during the operation only |
| State | Show settling, a warning, or a conversion with color grading, glow, or pixelation |
| Material | Build the texture chosen for the subject, such as paper, a screen, or optics, consistently |

Compare with the frame without the effect, and remove the effect when it does not improve the order of attention or how the cause reads.
Record the order in which several effects are applied.
Do not nest `HtmlInCanvas`.
Check that a WebGL effect gives the same result on the local machine, on any build machine, and in the final render.

Move the camera only to change what is in view, to close in on the same primary, or to let the viewer discover a spatial relation.
A constant zoom or parallax that makes a still picture look like video is not allowed.

## 10. Make scene boundaries a handoff of state

Prefer these, in this order.

1. Continue the position, the shape, or the camera target of the same object
2. Use a mask, a scale, or a path morph that keeps the same identity
3. Use a cut or a short transition only at a clear chapter boundary where the question changes
4. Use a crossfade only when the scenes before and after keep their meaning while they overlap half transparent

In `TransitionSeries`, the duration of a transition shortens the total length, and an overlay does not.
Always render the frames before, at 50% of, and after each transition.
Hold the last scene in a state where the conclusion can be read; never empty the screen with a customary fade-out.

## 11. Explore what Remotion can do with small benchmarks per ability

Never decide a new visual foundation with one generic clip.
First build these benchmarks, 10 to 15 seconds each.

1. Type choreography: masks, emphasis, reading time, and living with subtitles
2. Exact route: drawing a path, an object following it, its tangent, and its arrival
3. State transformation: the shape, color, and density of the same primary changing
4. Focus and depth: effects, foreground and background, the camera's focus
5. Spatial mechanism: a spatial explanation that needs Three or Skia

Use a shared light stage, type scale, and subtitle safe zone.
Compare the entry, settled, turning, and exit frames of each benchmark, a contact sheet at one frame per second, and the full MP4.
Adopt the option through which the same content is understood fastest and most exactly, not the most technically striking one.

## 12. Judge quality after rendering

At least these come from the same compiled hash.

- The entry, operation, read, and handoff frames of each scene
- The before, during, and after frames of every transition
- A contact sheet at one frame per second
- The full MP4 with subtitles
- The results of the checks of geometry, the safe area, text overflow, and route collisions

Go back to `revise` when any one of these is found.

- A shape, card, line, or badge whose meaning cannot be explained
- Information that is needed but pushed below 20 px
- An exit before the text could be read
- Content floating only at the top, with empty space at the bottom that has no purpose
- The same left and right placement or the same entrance motion repeated
- A path and the object that follows it drifting apart
- Muddiness, a double title, or a double panel during a transition
- Subtitles competing with the copy of the scene
- Drift, glow, or zoom while the picture is at rest

A successful render, a passing type check, or one good-looking still is never the basis of a candidate.

## Official pages to check

Look these up with `remotion-docs` for the Remotion version of the project: Designing visuals, Transforms, `interpolate()`, `spring()`, `Sequence`, `@remotion/paths`, `@remotion/shapes`, `@remotion/layout-utils`, Effects, HTML-in-canvas, Transitions, Motion blur, Using randomness, Fonts, and Importing assets.
