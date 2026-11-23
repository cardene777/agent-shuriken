/**
 * Where screen-video keeps its files, and how it finds Playwright and ffmpeg.
 *
 * | Place | What it holds |
 * |---|---|
 * | `dataDir()` | `$SCREEN_VIDEO_HOME`, or `$XDG_DATA_HOME/screen-video`, or `~/.local/share/screen-video` |
 * | `nodeDir()` | `$SCREEN_VIDEO_NODE_DIR`, or `node/` in the data folder: `playwright-core` and `ffmpeg-static`, installed by `screen-video.sh setup` |
 * | `<data>/sessions/` | Saved logins, one file per project and session name, readable only by the user |
 * | `<data>/apps/` | What app flows use, installed by `setup mac` and `setup ios`: `mac/` (screen-video's Swift tool) and `idb/` (idb in a Python virtual environment) |
 * | `<data>/voices/` | The local voice engines, installed the first time a flow is narrated: `kokoro/` (kokoro-js and its model), `aivisspeech/` (AivisSpeech Engine, its voice models, and its language model), and `voicevox/` (VOICEVOX CORE, its models, and a Python virtual environment) |
 * | `<data>/<project>/<name>/` | Videos and records of a flow or a recording, unless `--out` names another folder |
 */
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync } from "node:fs";
import { createRequire } from "node:module";
import { homedir } from "node:os";
import { basename, delimiter, dirname, join, resolve } from "node:path";

/** Folder names in the data folder that a project's videos must not take. */
const RESERVED = new Set(["node", "sessions", "voices", "apps"]);

export function dataDir() {
  return process.env.SCREEN_VIDEO_HOME || join(process.env.XDG_DATA_HOME || join(homedir(), ".local", "share"), "screen-video");
}

export function nodeDir() {
  return process.env.SCREEN_VIDEO_NODE_DIR || join(dataDir(), "node");
}

/** Creates a folder readable only by the user and returns it. */
export function ensureDir(dir) {
  mkdirSync(dir, { recursive: true, mode: 0o700 });
  return dir;
}

function runtimeRequire() {
  return createRequire(join(nodeDir(), "package.json"));
}

/** The `playwright-core` module installed in the data folder. */
export function playwright() {
  try {
    return runtimeRequire()("playwright-core");
  } catch {
    throw new Error(`Playwright is not installed in ${nodeDir()}. Run: screen-video.sh setup`);
  }
}

export function playwrightVersion() {
  try {
    return runtimeRequire()("playwright-core/package.json").version;
  } catch {
    return undefined;
  }
}

function which(name) {
  for (const dir of (process.env.PATH ?? "").split(delimiter)) {
    if (dir === "") continue;
    const path = join(dir, name);
    if (existsSync(path)) return path;
  }
  return undefined;
}

/**
 * Which ffmpeg to use. `$SCREEN_VIDEO_FFMPEG` wins; then an ffmpeg on PATH that can encode H.264
 * (`libx264`); then the one `ffmpeg-static` downloaded into the data folder.
 */
export function ffmpegChoice() {
  if (process.env.SCREEN_VIDEO_FFMPEG) return { path: process.env.SCREEN_VIDEO_FFMPEG, source: "env" };
  const system = which("ffmpeg");
  if (system !== undefined) {
    const encoders = spawnSync(system, ["-hide_banner", "-encoders"], { encoding: "utf8" });
    if (encoders.status === 0 && /\blibx264\b/.test(encoders.stdout ?? "")) return { path: system, source: "system" };
  }
  let bundled;
  try {
    bundled = runtimeRequire()("ffmpeg-static");
  } catch {
    bundled = undefined;
  }
  return { path: bundled ?? null, source: "bundled" };
}

let chosen;
export function ffmpegPath() {
  if (chosen === undefined) {
    const choice = ffmpegChoice();
    if (choice.path === null || !existsSync(choice.path)) throw new Error("No ffmpeg that can write H.264 was found. Run: screen-video.sh setup");
    chosen = choice.path;
  }
  return chosen;
}

let scriptFlag;
/**
 * The arguments that hand ffmpeg a filter graph written in a file: `-/filter_complex <file>` from
 * ffmpeg 7, `-filter_complex_script <file>` before it (the bundled ffmpeg is 6).
 */
export function filterScriptArgs(file) {
  if (scriptFlag === undefined) {
    const banner = spawnSync(ffmpegPath(), ["-hide_banner", "-version"], { encoding: "utf8" }).stdout ?? "";
    const major = Number((/ffmpeg version n?(\d+)/.exec(banner) ?? [])[1]);
    scriptFlag = Number.isFinite(major) && major < 7 ? "-filter_complex_script" : "-/filter_complex";
  }
  return [scriptFlag, file];
}

/** The skill's own folder, which holds `themes/`, `data/`, and `templates/`. */
export const SKILL_DIR = join(import.meta.dirname, "..", "..");

/**
 * The project a flow belongs to: the folder holding `.screen-video/` when the flow sits in
 * `.screen-video/flows/`, otherwise the current folder.
 */
export function projectRoot(flowFile) {
  if (flowFile !== undefined) {
    const dir = dirname(resolve(flowFile));
    if (basename(dir) === "flows" && basename(dirname(dir)) === ".screen-video") return dirname(dirname(dir));
  }
  return process.cwd();
}

/** The project's folder name in the data folder. */
export function projectName(root) {
  const name = basename(root).replace(/[^A-Za-z0-9._-]/g, "-").replace(/^[.-]+/, "") || "project";
  return RESERVED.has(name) ? `${name}-project` : name;
}

export function sessionFile(root, session) {
  return join(dataDir(), "sessions", `${projectName(root)}--${session}.json`);
}
