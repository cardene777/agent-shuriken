/**
 * The sound of the videos, mixed with ffmpeg into one WAV file: the voice, a press and a release for
 * each click, a short tick for each key, and music under it all that goes quieter while the voice speaks.
 *
 * The music is made by ffmpeg each time from the same notes, a slow pad that moves between two
 * chords, so it needs no file, no download, and no licence, and sounds the same on every remake. A
 * flow can name its own music file instead. The press and key sounds are from Kenney's UI Audio pack
 * (CC0), in `data/sounds/`.
 */
import { join } from "node:path";
import { writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";

import { ffmpegPath, filterScriptArgs, SKILL_DIR } from "./runtime.mjs";

const SOUNDS = join(SKILL_DIR, "data", "sounds");
const PRESS = join(SOUNDS, "mouseclick1.ogg");
const RELEASE = join(SOUNDS, "mouserelease1.ogg");
const KEYS = ["switch13.ogg", "switch14.ogg", "switch12.ogg"].map((name) => join(SOUNDS, name));

/** Two chords (A major and F sharp minor) whose notes swell and fade at their own slow pace. */
const CHORDS = [
  [110, 164.81, 220, 277.18, 329.63],
  [92.5, 138.59, 185, 220, 277.18],
];
const LEVELS = [0.5, 0.36, 0.3, 0.22, 0.17];

/** The made music as an `aevalsrc` expression of `t`: about -24 dB, all of it below 400 Hz. */
function musicExpression() {
  const chord = (notes, offset) =>
    notes
      .map((f, i) => `${LEVELS[i]}*sin(2*PI*${f}*t)*(0.55+0.45*sin(2*PI*t/${7 + 2 * i}+${(offset + i * 1.3).toFixed(2)}))`)
      .join("+");
  // The chords cross over every 8 seconds
  const weight = "(0.5+0.5*cos(2*PI*t/16))";
  return `0.18*(${weight}*(${chord(CHORDS[0], 0)})+(1-${weight})*(${chord(CHORDS[1], 0.7)}))`;
}

const ms = (seconds) => Math.max(0, Math.round(seconds * 1000));
const n3 = (value) => Number(value.toFixed(3)).toString();

/**
 * Writes `output`, a 48 kHz stereo WAV of `duration` seconds.
 *
 * - `voices`: `{ file, at, duration }`, each voice clip and the second it starts
 * - `presses`: seconds of each click; `typed`: seconds of each key
 * - `music`: `false`, `"made"`, or `{ file, volume }` for a file of the user's
 */
export function mixSound({ output, duration, voices = [], presses = [], typed = [], music = "made", work }) {
  const inputs = [];
  const lines = [];
  const mixed = [];
  const input = (file, options = []) => {
    inputs.push(...options, "-i", file);
    return inputs.filter((arg) => arg === "-i").length - 1;
  };
  const shape = "aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo";

  voices.forEach((voice, i) => {
    const index = input(voice.file);
    lines.push(`[${index}:a]${shape},adelay=delays=${ms(voice.at)}:all=1[voice${i}]`);
    mixed.push(`[voice${i}]`);
  });

  const placeAll = (file, times, label, volume) => {
    if (times.length === 0) return;
    const index = input(file);
    const outs = times.map((_, i) => `[${label}${i}]`);
    lines.push(`[${index}:a]${shape},volume=${volume},asplit=${times.length}${times.map((_, i) => `[${label}s${i}]`).join("")}`);
    times.forEach((t, i) => lines.push(`[${label}s${i}]adelay=delays=${ms(t)}:all=1${outs[i]}`));
    mixed.push(...outs);
  };
  placeAll(PRESS, presses, "press", 0.55);
  placeAll(RELEASE, presses.map((t) => t + 0.09), "release", 0.35);
  KEYS.forEach((file, k) => placeAll(file, typed.filter((_, i) => i % KEYS.length === k), `key${k}_`, 0.3));

  if (music !== false) {
    // Quieter by 10 dB while a voice speaks, easing over 0.2 seconds at each end
    const spans = voices.map((v) => [v.at, v.at + v.duration]);
    const ramp = 0.2;
    const terms = spans.map(([a, b]) => `clip(min((t-${n3(a - ramp)})/${ramp},(${n3(b + ramp)}-t)/${ramp}),0,1)`);
    const duck = terms.length === 0 ? "0" : terms.reduce((acc, term) => `max(${acc},${term})`);
    const fades = `afade=t=in:st=0:d=1.2,afade=t=out:st=${n3(Math.max(0, duration - 2))}:d=2`;
    if (music === "made") {
      lines.push(`aevalsrc='${musicExpression()}':s=48000:d=${n3(duration)},${shape},volume='1-0.68*${duck}':eval=frame,${fades}[music]`);
    } else {
      const index = input(music.file, ["-stream_loop", "-1"]);
      lines.push(`[${index}:a]${shape},atrim=0:${n3(duration)},volume=${music.volume ?? 0.35},volume='1-0.68*${duck}':eval=frame,${fades}[music]`);
    }
    mixed.push("[music]");
  }

  if (mixed.length === 0) lines.push(`anullsrc=r=48000:cl=stereo,atrim=0:${n3(duration)}[out]`);
  else {
    lines.push(
      `${mixed.join("")}amix=inputs=${mixed.length}:normalize=0:duration=longest,apad=whole_dur=${n3(duration)},atrim=0:${n3(duration)},alimiter=limit=0.95:level=false[out]`,
    );
  }
  const graph = join(work, `sound-${Date.now()}-${Math.random().toString(36).slice(2)}.txt`);
  writeFileSync(graph, lines.join(";\n"));
  const result = spawnSync(ffmpegPath(), ["-hide_banner", "-loglevel", "error", "-y", ...inputs, ...filterScriptArgs(graph), "-map", "[out]", "-c:a", "pcm_s16le", output], {
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
  if (result.status !== 0) throw new Error(`ffmpeg failed to mix the sound: ${(result.stderr ?? "").trim().split("\n").slice(-3).join(" / ")}`);
  return output;
}
