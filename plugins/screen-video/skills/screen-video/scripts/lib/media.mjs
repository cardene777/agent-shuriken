/**
 * Reads and writes video with ffmpeg.
 *
 * | Function | What it does |
 * |---|---|
 * | `normalize` | Turns a recording into a 1920x1080, 30 frames a second `mp4`, with black bars when the shape differs |
 * | `probe` | Width, height, and length in seconds of a video |
 * | `burn` | Joins the kept parts, zooms along the zoom keys, and lays the caption pictures over at their times |
 * | `burnVertical` | The same as `burn` for a 1080x1920 video, following the actions sideways instead of zooming |
 * | `toGif` | A GIF of a video, 960 pixels wide at 12 frames a second |
 * | `toSrt` | Captions as the text of an SRT file |
 * | `detectScenes` | Pictures and times of the scene changes |
 * | `detectFreezes` | Stretches where the picture stays still |
 *
 * Captions are drawn as pictures and laid over with `overlay`, because many ffmpeg builds cannot draw
 * text (`drawtext`, `libass`).
 */
import { spawnSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

import { ffmpegPath } from "./runtime.mjs";

export const WIDTH = 1920;
export const HEIGHT = 1080;
export const FPS = 30;
/** Top of the band at the bottom where captions go: the band is the bottom 200px. */
export const BAND_Y = 880;
export const VERTICAL = { width: 1080, height: 1920 };
/** Width of the window cut from the 1920x1080 picture for the vertical video. */
const CROP_WIDTH = 608;

const ENCODE = ["-c:v", "libx264", "-preset", "veryfast", "-crf", "20", "-pix_fmt", "yuv420p", "-movflags", "+faststart"];

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

const num = (value) => Number(value.toFixed(3)).toString();

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

/** A value that goes smoothly from 0 to 1 between a and b seconds (smoothstep). `v` is the time variable of the filter. */
function ease(a, b, v) {
  const s = `clip((${v}-${num(a)})/${num(b - a)},0,1)`;
  return `(${s}*${s}*(3-2*${s}))`;
}

/** One value of the keys (sorted by `t`) as an expression that moves smoothly from key to key. */
function curve(keys, prop, v = "it") {
  let expr = num(keys[0][prop]);
  for (let i = 0; i + 1 < keys.length; i++) {
    const delta = keys[i + 1][prop] - keys[i][prop];
    if (Math.abs(delta) < 1e-6) continue;
    expr += `${delta >= 0 ? "+" : "-"}${num(Math.abs(delta))}*${ease(keys[i].t, keys[i + 1].t, v)}`;
  }
  return expr;
}

function keepOnly(segments) {
  const keep = segments.map((s) => `between(t,${num(s.start)},${num(s.end)})`).join("+");
  return [`select='${keep}'`, `setpts=N/(${FPS}*TB)`];
}

function render({ input, output, workDir, chain, overlays, fallbackY }) {
  const lines = [`[0:v]${chain.length ? chain.join(",") : "null"}[v0]`];
  overlays.forEach((overlay, index) => {
    const enable = `between(t,${num(overlay.start)},${num(overlay.end)})`;
    lines.push(`[v${index}][${index + 1}:v]overlay=0:${overlay.y ?? fallbackY}:enable='${enable}'[v${index + 1}]`);
  });
  const graph = join(workDir, `graph-${Date.now()}-${Math.random().toString(36).slice(2)}.txt`);
  writeFileSync(graph, lines.join(";\n"));
  const inputs = ["-i", input, ...overlays.flatMap((overlay) => ["-i", overlay.file])];
  ffmpeg([...inputs, "-/filter_complex", graph, "-map", `[v${overlays.length}]`, "-r", String(FPS), "-an", ...ENCODE, output]);
}

/**
 * Writes a video again.
 *
 * - With `segments`, only those parts (input times) are kept and joined
 * - With `keys`, it zooms along the keys (`t` in edited time, scale `z`, centre `cx`, `cy`), scaling
 *   up twice first to keep the zoom steady
 * - Each of `overlays` (caption picture `file`) is laid over from `start` to `end` (edited time), at top `y`
 */
export function burn({ input, output, workDir, segments, keys, overlays = [] }) {
  const chain = segments === undefined ? [] : keepOnly(segments);
  if (keys !== undefined && keys.length > 1) {
    const z = curve(keys, "z");
    const x = `clip(2*(${curve(keys, "cx")})-iw/zoom/2,0,iw-iw/zoom)`;
    const y = `clip(2*(${curve(keys, "cy")})-ih/zoom/2,0,ih-ih/zoom)`;
    chain.push(`scale=${WIDTH * 2}:${HEIGHT * 2}`, `zoompan=z='${z}':x='${x}':y='${y}':d=1:s=${WIDTH}x${HEIGHT}:fps=${FPS}`);
  }
  render({ input, output, workDir, chain, overlays, fallbackY: BAND_Y });
}

/**
 * Writes a 1080x1920 video: a 608x1080 window that moves sideways to each action (`keys` with `t`
 * in edited time and centre `cx`), scaled up to fill the frame. Captions lie over it as in `burn`.
 */
export function burnVertical({ input, output, workDir, segments, keys, overlays = [] }) {
  const chain = segments === undefined ? [] : keepOnly(segments);
  const half = CROP_WIDTH / 2;
  const cx = keys !== undefined && keys.length > 0 ? curve(keys, "cx", "t") : String(WIDTH / 2);
  chain.push(`crop=${CROP_WIDTH}:${HEIGHT}:x='clip(${cx}-${half},0,${WIDTH - CROP_WIDTH})':y=0`, `scale=${VERTICAL.width}:${VERTICAL.height}:flags=lanczos`, "setsar=1");
  render({ input, output, workDir, chain, overlays, fallbackY: VERTICAL.height - 420 });
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
