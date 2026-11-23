/**
 * Reads and writes video with ffmpeg.
 *
 * | Function | What it does |
 * |---|---|
 * | `normalize` | Turns a recording into a 1920x1080, 30 frames a second `mp4`, with black bars when the shape differs |
 * | `joinRecordings` | Puts a part recorded later into another recording at a given second |
 * | `probe` | Width, height, and length in seconds of a video |
 * | `renderEdited` | Makes an edited video from the recording and a plan (`planEdit`): the frames kept, still frames under the cards, page dissolves, the zoom or the vertical window, the frame, captions, the fast-forward mark, the cards, and the sound |
 * | `renderOver` | The recording with captions laid over it and the sound, at the recording's own times |
 * | `burn` | Joins kept parts of a recording and lays caption pictures over them, for recordings the user made |
 * | `stillFrame` | One frame of a video as a PNG |
 * | `toGif` | A GIF of a video, 960 pixels wide at 12 frames a second |
 * | `toSrt` | Captions as the text of an SRT file |
 * | `detectScenes` | Pictures and times of the scene changes |
 * | `detectFreezes` | Stretches where the picture stays still |
 * | `composeApp` | Places an app's recording on the 1920x1080 screen, blurring its masked areas, for `raw.mp4` |
 * | `pictureApp` | A picture of an app with its masked areas blurred and a target outlined, for the storyboard |
 * | `drawPresses` | Lays the pointer and press rings (macOS) or touch marks (phones) over an app's recording |
 * | `joinSegments` | Joins the parts of a recording made one after another, keeping the gaps between them |
 *
 * Captions and cards are drawn as pictures and laid over with `overlay`, because many ffmpeg builds
 * cannot draw text (`drawtext`, `libass`).
 */
import { spawnSync } from "node:child_process";
import { mkdirSync, renameSync, writeFileSync } from "node:fs";
import { join } from "node:path";

import { ffmpegPath, filterScriptArgs } from "./runtime.mjs";

export const WIDTH = 1920;
export const HEIGHT = 1080;
export const FPS = 30;
/** Top of the band at the bottom where captions go in `burn`: the band is the bottom 200px. */
export const BAND_Y = 880;

const ENCODE = ["-c:v", "libx264", "-preset", "veryfast", "-crf", "20", "-pix_fmt", "yuv420p", "-movflags", "+faststart"];
const AUDIO = ["-c:a", "aac", "-b:a", "160k"];

function ffmpeg(args, { quiet = true } = {}) {
  const result = spawnSync(ffmpegPath(), ["-hide_banner", ...(quiet ? ["-loglevel", "error"] : []), "-y", ...args], {
    encoding: "utf8",
    maxBuffer: 256 * 1024 * 1024,
  });
  if (result.status !== 0) {
    const tail = (result.stderr ?? "").trim().split("\n").slice(-3).join(" / ");
    throw new Error(`ffmpeg failed: ${tail}`);
  }
  return result;
}

const num = (value) => Number(value.toFixed(4)).toString();
const graphFile = (dir, name) => join(dir, `${name}-${Date.now()}-${Math.random().toString(36).slice(2)}.txt`);

export function probe(file) {
  const text = spawnSync(ffmpegPath(), ["-hide_banner", "-i", file], { encoding: "utf8" }).stderr ?? "";
  const duration = /Duration: (\d+):(\d+):([\d.]+)/.exec(text);
  const size = /Video: .*?, (\d{2,5})x(\d{2,5})/.exec(text);
  if (duration === null || size === null) throw new Error(`cannot read the video ${file}`);
  return {
    width: Number(size[1]),
    height: Number(size[2]),
    duration: Number(duration[1]) * 3600 + Number(duration[2]) * 60 + Number(duration[3]),
  };
}

export const durationOf = (file) => probe(file).duration;

export function normalize(input, output) {
  const fit = `scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=decrease,pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2:color=black`;
  ffmpeg(["-i", input, "-vf", `fps=${FPS},${fit},setsar=1`, "-an", ...ENCODE, output]);
}

/**
 * Writes `output` from the recording `other` up to `cut` seconds, then all of the recording `part`,
 * then the rest of `other`. Both are recordings `normalize` wrote, so they share size and rate.
 */
export function joinRecordings({ other, part, cut, start = 0, output }) {
  const end = durationOf(other);
  // The part is taken from `start`, just before its first step, as `joinTimelines` moved its steps
  const piece = `[1:v]trim=start=${num(start)},setpts=PTS-STARTPTS[b]`;
  const graph =
    cut >= end - 1 / FPS
      ? `[0:v]setpts=PTS-STARTPTS[a];${piece};[a][b]concat=n=2:v=1:a=0,setsar=1[v]`
      : `[0:v]split[x][y];[x]trim=end=${num(cut)},setpts=PTS-STARTPTS[a];${piece};[y]trim=start=${num(cut)},setpts=PTS-STARTPTS[c];[a][b][c]concat=n=3:v=1:a=0,setsar=1[v]`;
  ffmpeg(["-i", other, "-i", part, "-filter_complex", graph, "-map", "[v]", "-an", "-r", String(FPS), ...ENCODE, output]);
}

/** Frame `index` (30 a second) of a video as a PNG. */
export function stillFrame(input, index, output) {
  ffmpeg(["-i", input, "-vf", `select='eq(n,${index})'`, "-frames:v", "1", "-fps_mode", "passthrough", output]);
  return output;
}

/** A value of the filter's time `v` that eases from 0 to 1 between a and b seconds, gently at both ends (smootherstep). */
function ease(a, b, v) {
  const s = `clip((${v}-${num(a)})/${num(b - a)},0,1)`;
  return `(${s}*${s}*${s}*(10-15*${s}+6*${s}*${s}))`;
}

/** One value of the keys (pairs of `t` and the value, sorted by `t`) as an expression that eases from key to key. */
function curve(keys, prop, v) {
  let expr = num(keys[0][prop]);
  for (let i = 0; i + 1 < keys.length; i++) {
    const delta = keys[i + 1][prop] - keys[i][prop];
    if (Math.abs(delta) < 1e-6 || keys[i + 1].t <= keys[i].t) continue;
    expr += `${delta >= 0 ? "+" : "-"}${num(Math.abs(delta))}*${ease(keys[i].t, keys[i + 1].t, v)}`;
  }
  return expr;
}

/** The `select` expression keeping the plan's frames: all of each normal part, every s-th frame of a part played s times as fast. */
function keepExpression(plan) {
  const terms = [];
  let cursor = plan.bodyStart;
  for (const part of plan.fastFrames) {
    if (part.a > cursor) terms.push(`between(n,${cursor},${part.a - 1})`);
    terms.push(`between(n,${part.a},${part.b - 1})*not(mod(n-${part.a},${part.speed}))`);
    cursor = part.b;
  }
  if (plan.lastFrame >= cursor) terms.push(`between(n,${cursor},${plan.lastFrame})`);
  return terms.join("+");
}

/** The kept frames, still frames under the cards, and the end card's still frame: the edited video's own clock starts here. */
function bodyChain(plan) {
  const offset = plan.freezes.map((f) => `${f.frames}*gte(N,${f.after + 1})`).join("+") || "0";
  const chain = [`select='${keepExpression(plan)}'`, `setpts='(N+${offset})/${FPS}/TB'`, `fps=${FPS}`];
  if (plan.endFrames > 0) chain.push(`tpad=stop_mode=clone:stop_duration=${num(plan.endFrames / FPS)}`);
  chain.push("format=yuv420p");
  return chain.join(",");
}

/** The corners of the part of the screen shown, as `perspective` takes them, for the zoom keys. */
function zoomCorners(keys) {
  const t = `in/${FPS}`;
  const z = curve(keys, "z", t);
  const ox = curve(keys, "ox", t);
  const oy = curve(keys, "oy", t);
  const left = `(${ox})/(${z})`;
  const right = `(${ox}+${WIDTH})/(${z})`;
  const top = `(${oy})/(${z})`;
  const bottom = `(${oy}+${HEIGHT})/(${z})`;
  return `x0='${left}':y0='${top}':x1='${right}':y1='${top}':x2='${left}':y2='${bottom}':x3='${right}':y3='${bottom}'`;
}

/** The corners of the vertical window, `width` pixels wide, sliding along the keys. */
function sideCorners(keys, width) {
  const cx = curve(keys, "cx", `in/${FPS}`);
  const left = `(${cx})-${width / 2}`;
  const right = `(${cx})+${width / 2}`;
  return `x0='${left}':y0=0:x1='${right}':y1=0:x2='${left}':y2=${HEIGHT}:x3='${right}':y3=${HEIGHT}`;
}

/**
 * Lays timed pictures over `from`. Each `{ file, start, end, fadeIn, fadeOut, x, y }` shows from
 * `start` to `end` seconds of the video, fading in and out. Returns the label of the result.
 */
function layer(lines, inputs, from, items, label) {
  let current = from;
  items.forEach((item, i) => {
    const length = Math.max(1 / FPS, item.end - item.start);
    inputs.push("-loop", "1", "-framerate", String(FPS), "-t", num(length), "-i", item.file);
    const index = inputs.filter((arg) => arg === "-i").length - 1;
    const fades = [
      ...(item.fadeIn > 0 ? [`fade=t=in:st=0:d=${num(item.fadeIn)}:alpha=1`] : []),
      ...(item.fadeOut > 0 ? [`fade=t=out:st=${num(Math.max(0, length - item.fadeOut))}:d=${num(item.fadeOut)}:alpha=1`] : []),
    ];
    lines.push(`[${index}:v]format=rgba,${[...fades, `setpts=PTS+${num(item.start)}/TB`].join(",")}[${label}${i}]`);
    const next = `${label}o${i}`;
    lines.push(`[${current}][${label}${i}]overlay=${item.x ?? 0}:${item.y ?? 0}:eof_action=pass[${next}]`);
    current = next;
  });
  return current;
}

/**
 * Writes an edited video: 16:9 (`layout.width` 1920) zooms along the plan's zoom keys, 9:16 slides a
 * window along its side keys. `pictures` holds the drawn `frame`, `captions` and `marks` (each
 * `{ file, box, start, end }`), `cards` (`{ file, show }`), and `stills` (`{ file, start, end }`,
 * the old page of each dissolve). `sound` is the WAV file to put under it.
 */
export function renderEdited({ raw, output, plan, layout, pictures, sound, work }) {
  const inputs = ["-i", raw, "-i", pictures.frame];
  const lines = [`[0:v]${bodyChain(plan)}[body]`];
  // Dissolves are laid over the recording itself, before the zoom, so both pages zoom alike
  let current = layer(lines, inputs, "body", pictures.stills.map((s) => ({ ...s, fadeIn: 0, fadeOut: s.end - s.start })), "still");
  const w = layout.window;
  const wide = layout.width > layout.height;
  const corners = wide ? zoomCorners(plan.zoomKeys) : sideCorners(plan.sideKeys, pictures.cropWidth);
  // In 9:16 the window is scaled to another shape, and ffmpeg then marks the pixels as wide so the old
  // shape is kept; setsar=1 makes them square again, or players show the video stretched to 5:4
  lines.push(`[${current}]perspective=${corners}:interpolation=linear:eval=frame,scale=${w.width}:${w.height}:flags=bicubic,setsar=1,pad=${layout.width}:${layout.height}:${w.x}:${w.y}:color=black[shown]`);
  lines.push("[shown][1:v]overlay=0:0[framed]");
  current = layer(lines, inputs, "framed", pictures.captions.map((c) => ({ ...c, x: c.box.x, y: c.box.y, fadeIn: 0.25, fadeOut: 0.25 })), "caption");
  current = layer(lines, inputs, current, pictures.marks.map((m) => ({ ...m, x: m.box.x, y: m.box.y, fadeIn: 0.2, fadeOut: 0.2 })), "mark");
  // A later card is laid first, so a card that ends where the next begins fades out over it
  const cards = [...pictures.cards].reverse().map((c) => ({ file: c.file, start: c.show.from, end: c.show.to, fadeIn: c.show.fadeIn, fadeOut: c.show.fadeOut }));
  current = layer(lines, inputs, current, cards, "card");
  lines.push(`[${current}]format=yuv420p[video]`);
  inputs.push("-i", sound);
  const soundIndex = inputs.filter((arg) => arg === "-i").length - 1;
  const graph = graphFile(work, "edited");
  writeFileSync(graph, lines.join(";\n"));
  ffmpeg([...inputs, ...filterScriptArgs(graph), "-map", "[video]", "-map", `${soundIndex}:a`, "-r", String(FPS), "-t", num(plan.frames / FPS), ...ENCODE, ...AUDIO, output]);
}

/** The recording with captions laid over it (`{ file, box, start, end }` in recording time) and `sound` under it. */
export function renderOver({ raw, output, captions, sound, work }) {
  const inputs = ["-i", raw];
  const lines = ["[0:v]format=yuv420p[base]"];
  const current = layer(lines, inputs, "base", captions.map((c) => ({ ...c, x: c.box.x, y: c.box.y, fadeIn: 0.2, fadeOut: 0.2 })), "caption");
  lines.push(`[${current}]format=yuv420p[video]`);
  inputs.push("-i", sound);
  const soundIndex = inputs.filter((arg) => arg === "-i").length - 1;
  const graph = graphFile(work, "over");
  writeFileSync(graph, lines.join(";\n"));
  ffmpeg([...inputs, ...filterScriptArgs(graph), "-map", "[video]", "-map", `${soundIndex}:a`, "-r", String(FPS), ...ENCODE, ...AUDIO, "-shortest", output]);
}

function keepOnly(segments) {
  const keep = segments.map((s) => `between(t,${num(s.start)},${num(s.end)})`).join("+");
  return [`select='${keep}'`, `setpts=N/(${FPS}*TB)`];
}

/**
 * Writes a video again, for recordings the user made and for the plain video of `compare`.
 *
 * - With `segments`, only those parts (input times) are kept and joined
 * - Each of `overlays` (caption picture `file`) is laid over from `start` to `end` (edited time), at top `y`
 */
export function burn({ input, output, workDir, segments, overlays = [] }) {
  const chain = segments === undefined ? [] : keepOnly(segments);
  const lines = [`[0:v]${chain.length ? chain.join(",") : "null"}[v0]`];
  overlays.forEach((overlay, index) => {
    const enable = `between(t,${num(overlay.start)},${num(overlay.end)})`;
    lines.push(`[v${index}][${index + 1}:v]overlay=0:${overlay.y ?? BAND_Y}:enable='${enable}'[v${index + 1}]`);
  });
  const graph = graphFile(workDir, "graph");
  writeFileSync(graph, lines.join(";\n"));
  const inputs = ["-i", input, ...overlays.flatMap((overlay) => ["-i", overlay.file])];
  ffmpeg([...inputs, ...filterScriptArgs(graph), "-map", `[v${overlays.length}]`, "-r", String(FPS), "-an", ...ENCODE, output]);
}

export function toGif(input, output) {
  ffmpeg([
    "-i", input,
    "-filter_complex", "fps=12,scale=960:-2:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4",
    output,
  ]);
}

function stamp(seconds) {
  const ms = Math.max(0, Math.round(seconds * 1000));
  const pad = (value, width) => String(value).padStart(width, "0");
  return `${pad(Math.floor(ms / 3600000), 2)}:${pad(Math.floor(ms / 60000) % 60, 2)}:${pad(Math.floor(ms / 1000) % 60, 2)},${pad(ms % 1000, 3)}`;
}

export function toSrt(cues) {
  return cues.map((cue, index) => `${index + 1}\n${stamp(cue.start)} --> ${stamp(cue.end)}\n${cue.text}\n`).join("\n");
}

/**
 * Writes the first picture and each scene change (where the difference from the previous picture
 * passes `threshold`) as 1280-wide pictures into `dir`. Returns each picture's time and its path
 * from `dir`'s parent.
 */
export function detectScenes(input, dir, { threshold = 0.3 } = {}) {
  mkdirSync(dir, { recursive: true });
  const result = ffmpeg(
    ["-i", input, "-vf", `select='eq(n,0)+gt(scene,${threshold})',showinfo,scale=1280:-2`, "-fps_mode", "vfr", join(dir, "%04d.png")],
    { quiet: false },
  );
  const times = [...(result.stderr ?? "").matchAll(/Parsed_showinfo.*?pts_time:\s*([0-9.]+)/g)].map((m) => Number(m[1]));
  return times.map((t, index) => ({ t: Number(t.toFixed(3)), file: join("scenes", `${String(index + 1).padStart(4, "0")}.png`) }));
}

/** Stretches of at least `seconds` where the picture stays still. A stretch that lasts to the end closes at the video's length. */
export function detectFreezes(input, { seconds = 3 } = {}) {
  const result = ffmpeg(["-i", input, "-vf", `freezedetect=n=-60dB:d=${seconds}`, "-map", "0:v", "-f", "null", "-"], { quiet: false });
  const text = result.stderr ?? "";
  const starts = [...text.matchAll(/freeze_start:\s*([0-9.]+)/g)].map((m) => Number(m[1]));
  const ends = [...text.matchAll(/freeze_end:\s*([0-9.]+)/g)].map((m) => Number(m[1]));
  const total = durationOf(input);
  return starts.map((start, index) => ({ start: Number(start.toFixed(3)), end: Number((ends[index] ?? total).toFixed(3)) }));
}

/** A colour of a theme (`#rgb` or `#rrggbb`) as ffmpeg takes it. */
export function ffmpegColor(color) {
  const hex = color.replace(/^#/, "");
  return `0x${hex.length === 3 ? [...hex].map((c) => c + c).join("") : hex}`;
}

/**
 * Filter lines that blur each of `areas` (`{ x, y, width, height }`, and `from` and `to` in seconds
 * when the area is blurred only then) of the stream `from`. The area is shrunk to a sixteenth and
 * stretched back, which leaves no readable detail at any size. Returns the label of the result.
 */
function blurAreas(lines, from, areas) {
  let current = from;
  areas.forEach((area, i) => {
    const small = `${Math.max(2, Math.round(area.width / 16))}:${Math.max(2, Math.round(area.height / 16))}`;
    const when = area.from === undefined ? "" : `:enable='between(t,${num(area.from)},${num(area.to)})'`;
    lines.push(`[${current}]split[keep${i}][cut${i}]`);
    lines.push(`[cut${i}]crop=${area.width}:${area.height}:${area.x}:${area.y},scale=${small}:flags=area,scale=${area.width}:${area.height}:flags=bilinear[blur${i}]`);
    lines.push(`[keep${i}][blur${i}]overlay=${area.x}:${area.y}${when}[blurred${i}]`);
    current = `blurred${i}`;
  });
  return current;
}

/**
 * Writes `raw.mp4` of an app: `input` (the window or the phone's screen as recorded) scaled to
 * `screen` (`{ x, y, width, height }` on the 1920x1080 screen) over `background`, at 30 frames a
 * second, with each of `masks` (areas of the scaled recording) blurred while it shows.
 */
export function composeApp({ input, output, screen, background, masks = [], work }) {
  const lines = [`[0:v]fps=${FPS},scale=${screen.width}:${screen.height}:flags=bicubic,setsar=1,format=yuv420p[app]`];
  const blurred = blurAreas(lines, "app", masks);
  lines.push(`color=c=${background}:s=${WIDTH}x${HEIGHT}:r=${FPS}[base]`);
  lines.push(`[base][${blurred}]overlay=${screen.x}:${screen.y}:shortest=1,setsar=1,format=yuv420p[video]`);
  const graph = graphFile(work, "app");
  writeFileSync(graph, lines.join(";\n"));
  ffmpeg(["-i", input, ...filterScriptArgs(graph), "-map", "[video]", "-an", "-r", String(FPS), ...ENCODE, output]);
}

/** Writes a picture of an app with each of `masks` blurred and an orange line around `outline`, in the picture's pixels. */
export function pictureApp({ input, output, masks = [], outline, work }) {
  const lines = ["[0:v]format=rgb24[shot]"];
  let current = blurAreas(lines, "shot", masks);
  if (outline !== undefined) {
    lines.push(`[${current}]drawbox=x=${outline.x - 6}:y=${outline.y - 6}:w=${outline.width + 12}:h=${outline.height + 12}:color=0xe8590c:t=4[outlined]`);
    current = "outlined";
  }
  const graph = graphFile(work, "picture");
  writeFileSync(graph, lines.join(";\n"));
  ffmpeg(["-i", input, ...filterScriptArgs(graph), "-map", `[${current}]`, "-frames:v", "1", output]);
}

/** A position along `points` (`{ t, x, y }`, in time order) at the filter's time `t`, straight between each two, as an expression. */
function along(points, key) {
  const first = points[0];
  const last = points.at(-1);
  const terms = [`lt(t,${num(first.t)})*${num(first[key])}`];
  for (let i = 0; i + 1 < points.length; i++) {
    const a = points[i];
    const b = points[i + 1];
    if (b.t <= a.t) continue;
    terms.push(`gte(t,${num(a.t)})*lt(t,${num(b.t)})*(${num(a[key])}+${num(b[key] - a[key])}*(t-${num(a.t)})/${num(b.t - a.t)})`);
  }
  terms.push(`gte(t,${num(last.t)})*${num(last[key])}`);
  return terms.join("+");
}

/**
 * Writes `output`: `input` with the presses of an app drawn over it. `pictures` holds the drawn
 * `arrow`, the frames of a press `ring` and a `touch` mark (`{ pattern, size }`, 30 a second), and
 * the `touch` mark's `still`. `pointer` lists where the arrow is (`{ t, x, y }`, its picture's top left, as the browser's pointer is placed),
 * `rings` and `touches` the presses (`{ t, x, y }`, their middles), and `swipes` the swipes
 * (`{ t, seconds, from, to }`).
 */
export function drawPresses({ input, output, pictures, pointer = [], rings = [], touches = [], swipes = [], work }) {
  const inputs = ["-i", input];
  const lines = ["[0:v]format=yuv420p[p0]"];
  let n = 0;
  const add = (args) => {
    inputs.push(...args);
    return inputs.filter((arg) => arg === "-i").length - 1;
  };
  const over = (index, prepare, place) => {
    lines.push(`[${index}:v]format=rgba,${prepare}[m${n}]`);
    lines.push(`[p${n}][m${n}]overlay=${place}:eof_action=pass[p${n + 1}]`);
    n++;
  };
  for (const [marks, picture] of [
    [rings, pictures.ring],
    [touches, pictures.touch],
  ]) {
    for (const mark of marks) {
      const index = add(["-framerate", String(FPS), "-i", picture.pattern]);
      const half = picture.size / 2;
      over(index, `setpts=PTS-STARTPTS+${num(mark.t)}/TB`, `${Math.round(mark.x - half)}:${Math.round(mark.y - half)}`);
    }
  }
  for (const swipe of swipes) {
    const half = pictures.touch.size / 2;
    const index = add(["-loop", "1", "-framerate", String(FPS), "-t", num(swipe.seconds + 0.25), "-i", pictures.touch.still]);
    const u = `clip((t-${num(swipe.t)})/${num(swipe.seconds)},0,1)`;
    const x = `${num(swipe.from.x - half)}+${num(swipe.to.x - swipe.from.x)}*${u}`;
    const y = `${num(swipe.from.y - half)}+${num(swipe.to.y - swipe.from.y)}*${u}`;
    over(index, `setpts=PTS-STARTPTS+${num(swipe.t)}/TB`, `x='${x}':y='${y}':eval=frame`);
  }
  if (pointer.length > 0) {
    const index = add(["-loop", "1", "-framerate", String(FPS), "-t", num(durationOf(input)), "-i", pictures.arrow]);
    over(index, "null", `x='${along(pointer, "x")}':y='${along(pointer, "y")}':eval=frame`);
  }
  lines.push(`[p${n}]format=yuv420p[video]`);
  const graph = graphFile(work, "presses");
  writeFileSync(graph, lines.join(";\n"));
  ffmpeg([...inputs, ...filterScriptArgs(graph), "-map", "[video]", "-an", "-r", String(FPS), "-c:v", "libx264", "-preset", "veryfast", "-crf", "16", "-pix_fmt", "yuv420p", output]);
}

/**
 * Writes `output` from recordings made one after another (`{ file, at }`, `at` the seconds from the
 * first one's start), holding each one's first frame over the gap before it, so times stay true.
 */
export function joinSegments(parts, output) {
  if (parts.length === 1) {
    renameSync(parts[0].file, output);
    return;
  }
  const inputs = parts.flatMap((part) => ["-i", part.file]);
  const lines = parts.map((part, i) => {
    const before = i === 0 ? 0 : Math.max(0, part.at - (parts[i - 1].at + durationOf(parts[i - 1].file)));
    return `[${i}:v]fps=${FPS},setpts=PTS-STARTPTS${before > 0 ? `,tpad=start_duration=${num(before)}:start_mode=clone` : ""},setsar=1[s${i}]`;
  });
  lines.push(`${parts.map((_, i) => `[s${i}]`).join("")}concat=n=${parts.length}:v=1:a=0[video]`);
  ffmpeg([...inputs, "-filter_complex", lines.join(";"), "-map", "[video]", "-an", ...ENCODE, output]);
}
