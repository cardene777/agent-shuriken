#!/usr/bin/env node
/**
 * The screen-video commands. `screen-video.sh` installs the runtime on first use and runs this file.
 *
 * | Command | What it does | Files written |
 * |---|---|---|
 * | `doctor [--json]` | Says which ffmpeg and Playwright it uses and where the data folder is | none |
 * | `inspect <flow> [--path <path>]` | Opens a page of the flow's site and lists its headings, buttons, links, and fields | `inspect.png` in the data folder |
 * | `check <flow>` | Checks a flow file and lists the steps that send something or pay | none |
 * | `rehearse <flow> [--out <dir>]` | Runs the flow without recording, up to the first step that sends something or pays, and writes the storyboard | `storyboard.html`, `frames/`, `rehearsal.json` |
 * | `record <flow> [--out <dir>] [--confirm-effects]` | Records the flow and makes the videos | `raw.mp4`, `captioned.mp4`, `edited.mp4`, `vertical.mp4`, `edited.gif`, `timeline.json`, `captions.srt`, `edit.json` |
 * | `remake <flow> [--out <dir>]` | Makes the captioned and edited videos again from `raw.mp4` and `timeline.json`, without recording | the same as `record`, except `raw.mp4` and `timeline.json` |
 * | `login <flow> [--until <text in the address>]` | Opens a browser to log in by hand and saves the login for the flow's `login.session` | `sessions/<project>--<session>.json` in the data folder |
 * | `scenes <recording> [--out <dir>]` | Finds the scene changes and still stretches in a recording the user made | `scenes/`, `scenes.json`, `freezes.json` |
 * | `render <recording> [--out <dir>]` | Makes the captioned and edited videos from `captions.json` the agent wrote | `captioned.mp4`, `edited.mp4`, `captions.srt` |
 *
 * Login values are read from the env file a flow names and are never printed or written.
 */
import { chmodSync, existsSync, mkdtempSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, extname, join, resolve } from "node:path";

import { captionImages, FRAMES } from "./lib/captions.mjs";
import { cutsForFreezes, cutsForWaits, mapCues, segmentsWithout, toEdited, verticalKeys, zoomedBox, zoomKeys } from "./lib/edit.mjs";
import { envLookup, loadFlow, markedSteps, readLogin } from "./lib/flow.mjs";
import { burn, burnVertical, detectFreezes, detectScenes, durationOf, HEIGHT, normalize, toGif, toSrt, WIDTH } from "./lib/media.mjs";
import { startRecording } from "./lib/recorder.mjs";
import { runFlow, StepError } from "./lib/runner.mjs";
import { dataDir, ensureDir, ffmpegChoice, nodeDir, playwright, playwrightVersion, projectName, projectRoot, sessionFile } from "./lib/runtime.mjs";
import { writeStoryboard } from "./lib/storyboard.mjs";

/** Files a run may remove when it empties its folder. Anything else stops the run. */
const ARTIFACT = /\.(mp4|webm|mov|gif|json|srt|png|html|txt)$/iu;

class Refusal extends Error {}
const refuse = (message) => {
  throw new Refusal(message);
};
const say = (text) => process.stdout.write(`${text}\n`);

function parse(argv) {
  const [command, ...rest] = argv;
  const options = { command, args: [], flags: new Set() };
  for (let i = 0; i < rest.length; i++) {
    const arg = rest[i];
    if (arg === "--out" || arg === "--until" || arg === "--path") options[arg.slice(2)] = rest[++i];
    else if (arg.startsWith("--")) options.flags.add(arg.slice(2));
    else options.args.push(arg);
  }
  if (options.out !== undefined) options.out = resolve(options.out);
  return options;
}

/** Empties `dir` for a new run. Stops, naming them, when it holds files or folders that are not this skill's. */
function clearDir(dir, { folders = [], keep = [] } = {}) {
  if (!existsSync(dir)) {
    ensureDir(dir);
    return;
  }
  const names = readdirSync(dir);
  const foreign = names.filter((name) => {
    if (keep.includes(name)) return false;
    if (statSync(join(dir, name)).isDirectory()) return !folders.includes(name);
    return !ARTIFACT.test(name);
  });
  if (foreign.length > 0) {
    refuse(`Not emptying ${dir}: it holds ${foreign.map((name) => (statSync(join(dir, name)).isDirectory() ? `${name}/` : name)).join(", ")}, which screen-video did not write. Move them or pass another --out.`);
  }
  for (const name of names) if (!keep.includes(name)) rmSync(join(dir, name), { recursive: true, force: true });
}

function openFlow(file) {
  if (file === undefined || !existsSync(file)) refuse("Pass the flow file, such as .screen-video/flows/<name>.json");
  const { flow, problems } = loadFlow(file);
  if (problems.length > 0) {
    refuse(problems.map((p) => (p.step === 0 ? `flow: ${p.message}` : `step ${p.step}: ${p.message}`)).join("\n"));
  }
  const root = projectRoot(file);
  return { flow, root, defaultOut: join(dataDir(), projectName(root), flow.name) };
}

function verbOf(kind) {
  return kind === "pays" ? "pays" : "sends something";
}

function listMarked(marked) {
  return marked.map((m) => `  step ${m.number} ${verbOf(m.kind)}${m.note ? `: ${m.note}` : ""}${m.caption ? ` (${m.caption})` : ""}`).join("\n");
}

function doctor(json) {
  const ffmpeg = ffmpegChoice();
  const info = {
    data: dataDir(),
    node: nodeDir(),
    playwright: { version: playwrightVersion() ?? null },
    ffmpeg: { path: ffmpeg.path, source: ffmpeg.source, found: ffmpeg.path !== null && existsSync(ffmpeg.path) },
  };
  if (json) say(JSON.stringify(info));
  else {
    say(`data folder: ${info.data}`);
    say(`Playwright: ${info.playwright.version ?? "not installed (run: screen-video.sh setup)"}`);
    say(`ffmpeg: ${info.ffmpeg.found ? `${info.ffmpeg.path} (${info.ffmpeg.source})` : "not found (run: screen-video.sh setup)"}`);
  }
}

function check(file) {
  const { flow } = openFlow(file);
  say(`${flow.name}: ${flow.steps.length} steps, videos ${flow.outputs.join(", ")}`);
  const marked = markedSteps(flow);
  if (marked.length === 0) say("No step sends anything or pays.");
  else say(`Steps that send something or pay each time the video is recorded:\n${listMarked(marked)}`);
}

async function inspect(file, path) {
  const { flow, root } = openFlow(file);
  const login = readLogin(flow, root);
  const { chromium } = playwright();
  const browser = await chromium.launch();
  try {
    const context = await browser.newContext({
      viewport: { width: WIDTH, height: HEIGHT },
      ...(login.credentials === undefined ? {} : { httpCredentials: login.credentials }),
      ...(login.storageState === undefined ? {} : { storageState: login.storageState }),
    });
    const page = await context.newPage();
    await page.goto(new URL(path ?? flow.url, flow.url).toString(), { waitUntil: "load", timeout: 90000 });
    await page.waitForTimeout(800);
    const listed = await page.evaluate(() => {
      const name = (el) => (el.getAttribute("aria-label") || el.innerText || el.getAttribute("title") || el.getAttribute("placeholder") || "").trim().replace(/\s+/g, " ").slice(0, 80);
      const visible = (el) => el.getClientRects().length > 0 && getComputedStyle(el).visibility !== "hidden";
      const labelOf = (el) => (el.labels?.[0]?.innerText || el.getAttribute("aria-label") || el.getAttribute("placeholder") || el.name || "").trim();
      return {
        title: document.title,
        headings: [...document.querySelectorAll("h1,h2,h3")].filter(visible).map((h) => `${h.tagName.toLowerCase()} ${name(h)}`),
        buttons: [...document.querySelectorAll('button,[role="button"],input[type="submit"]')].filter(visible).map(name).filter(Boolean),
        links: [...document.querySelectorAll("a[href]")].filter(visible).map(name).filter(Boolean),
        fields: [...document.querySelectorAll("input:not([type=hidden]):not([type=submit]),textarea,select")]
          .filter(visible)
          .map((el) => `${el.tagName.toLowerCase()}${el.type ? `[${el.type}]` : ""} ${labelOf(el)}`),
      };
    });
    const shot = join(ensureDir(join(dataDir(), projectName(root))), "inspect.png");
    await page.screenshot({ path: shot });
    say(`page: ${page.url()}\ntitle: ${listed.title}`);
    for (const [label, items] of [["headings", listed.headings], ["buttons", listed.buttons], ["links", listed.links], ["fields (values are not shown)", listed.fields]]) {
      say(`${label}:${items.length === 0 ? " none" : ""}`);
      for (const item of [...new Set(items)].slice(0, 60)) say(`  ${item}`);
    }
    say(`picture: ${shot}`);
  } finally {
    await browser.close();
  }
}

async function rehearse(file, out) {
  const { flow, root, defaultOut } = openFlow(file);
  const dir = out ?? join(defaultOut, "rehearsal");
  clearDir(dir, { folders: ["frames"] });
  const framesDir = ensureDir(join(dir, "frames"));
  const login = readLogin(flow, root);
  const env = envLookup(flow, root);
  const rec = await startRecording({ record: false, credentials: login.credentials, storageState: login.storageState, masks: flow.mask });
  let results;
  try {
    results = await runFlow({ flow, rec, rehearse: true, framesDir, env });
  } finally {
    await rec.abort();
  }
  writeFileSync(join(dir, "rehearsal.json"), `${JSON.stringify({ flow: flow.name, results, steps: rec.steps.map(({ kind, url, caption }) => ({ kind, url, caption })) }, null, 2)}\n`);
  const storyboard = join(dir, "storyboard.html");
  writeStoryboard({ flow, results, file: storyboard });
  say(`Storyboard: ${storyboard}`);
  const failed = results.find((r) => r.status === "missing");
  const skipped = results.filter((r) => r.status === "skipped");
  if (skipped.length > 0 && failed === undefined) say(`Not rehearsed: steps ${skipped.map((r) => r.number).join(", ")} (from the first step that sends something or pays)`);
  if (failed !== undefined) refuse(`step ${failed.number}: ${failed.message}`);
}

/** Captions for the steps that have one: from the step's time to the next caption, or 4 seconds. Each keeps the step's box to avoid. */
function cuesFromSteps(steps, duration) {
  const captioned = steps.filter((step) => (step.caption ?? "") !== "");
  return captioned.map((step, index) => ({
    start: step.t,
    end: Number(Math.min(duration, captioned[index + 1]?.t ?? step.t + 4).toFixed(3)),
    text: step.caption,
    ...(step.box ? { box: step.box } : {}),
  }));
}

/** Makes every video after `raw.mp4` and `timeline.json` from the recording's steps. */
async function finish(out, timeline, work) {
  const raw = join(out, "raw.mp4");
  const { steps, duration } = timeline;
  const outputs = timeline.outputs ?? ["16:9"];
  const cues = cuesFromSteps(steps, duration);
  writeFileSync(join(out, "captions.srt"), toSrt(cues));
  const images = await captionImages(cues.map((cue) => ({ ...cue, avoid: cue.box ? [cue.box] : [] })), work);
  burn({ input: raw, output: join(out, "captioned.mp4"), workDir: work, overlays: images });
  say(`Captioned video: ${join(out, "captioned.mp4")}`);

  const segments = segmentsWithout(cutsForWaits(steps), duration);
  const actions = steps.filter((step) => step.box !== undefined);
  const zooms = actions.map((step) => ({ at: step.t, end: step.end, box: step.box, caption: step.caption, navigates: step.navigates === true }));
  const edited = zooms.map((zoom) => ({ t: toEdited(segments, zoom.at), end: toEdited(segments, zoom.end, "back"), box: zoom.box, navigates: zoom.navigates }));
  const keys = zoomKeys(edited);
  const editedCues = await captionImages(
    mapCues(segments, cues).map((cue) => ({ ...cue, avoid: cue.box ? [cue.box, zoomedBox(cue.box)] : [] })),
    work,
    { prefix: "edited" },
  );
  writeFileSync(join(out, "edit.json"), `${JSON.stringify({ segments, zooms, keys }, null, 2)}\n`);
  burn({ input: raw, output: join(out, "edited.mp4"), workDir: work, segments, keys, overlays: editedCues });
  say(`Edited video: ${join(out, "edited.mp4")} (${durationOf(join(out, "edited.mp4")).toFixed(1)}s)`);

  if (outputs.includes("9:16")) {
    const verticalCues = await captionImages(mapCues(segments, cues), work, { prefix: "vertical", frame: FRAMES.vertical });
    burnVertical({ input: raw, output: join(out, "vertical.mp4"), workDir: work, segments, keys: verticalKeys(edited), overlays: verticalCues });
    say(`Vertical video: ${join(out, "vertical.mp4")}`);
  }
  if (outputs.includes("gif")) {
    toGif(join(out, "edited.mp4"), join(out, "edited.gif"));
    say(`GIF: ${join(out, "edited.gif")}`);
  }
}

async function record(file, out, confirmed) {
  const { flow, root, defaultOut } = openFlow(file);
  const marked = markedSteps(flow);
  if (marked.length > 0 && !confirmed) {
    refuse(
      `This flow has steps that send something or pay each time it is recorded:\n${listMarked(marked)}\n` +
        "Show them to the user, and only after the user agrees, run record again with --confirm-effects.",
    );
  }
  const dir = out ?? defaultOut;
  clearDir(dir, { keep: ["rehearsal"] });
  const login = readLogin(flow, root);
  const env = envLookup(flow, root);
  const work = mkdtempSync(join(tmpdir(), "screen-video-"));
  try {
    const rec = await startRecording({ videoDir: work, credentials: login.credentials, storageState: login.storageState, masks: flow.mask });
    try {
      await runFlow({ flow, rec, env });
    } catch (error) {
      await rec.screenshot(join(dir, "failure.png"));
      await rec.abort();
      const message = error instanceof StepError ? error.message : `${error instanceof Error ? error.message.split("\n")[0] : error}`;
      refuse(`${message} (the screen when it stopped: ${join(dir, "failure.png")})`);
    }
    const webm = await rec.stop();
    if (webm === undefined) refuse("The recording has no frames.");
    const raw = join(dir, "raw.mp4");
    normalize(webm, raw);
    const timeline = { flow: flow.name, width: WIDTH, height: HEIGHT, duration: durationOf(raw), outputs: flow.outputs, steps: rec.steps };
    writeFileSync(join(dir, "timeline.json"), `${JSON.stringify(timeline, null, 2)}\n`);
    say(`Raw video: ${raw} (${timeline.duration.toFixed(1)}s)`);
    await finish(dir, timeline, work);
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
}

async function remake(file, out) {
  const dir = out ?? openFlow(file).defaultOut;
  const raw = join(dir, "raw.mp4");
  const timelineFile = join(dir, "timeline.json");
  if (!existsSync(raw) || !existsSync(timelineFile)) refuse(`${dir} has no raw.mp4 and timeline.json. Record the flow first.`);
  const timeline = JSON.parse(readFileSync(timelineFile, "utf8"));
  for (const name of ["captioned.mp4", "edited.mp4", "vertical.mp4", "edited.gif", "captions.srt", "edit.json"]) rmSync(join(dir, name), { force: true });
  const work = mkdtempSync(join(tmpdir(), "screen-video-"));
  try {
    await finish(dir, { ...timeline, duration: durationOf(raw) }, work);
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
}

async function login(file, until) {
  const { flow, root } = openFlow(file);
  if (flow.login?.session === undefined) refuse("The flow has no login.session to save the login under.");
  const credentials = flow.login.basic === undefined ? undefined : readLogin({ ...flow, login: { ...flow.login, session: undefined } }, root).credentials;
  const headless = process.env.SCREEN_VIDEO_HEADLESS === "1";
  const { chromium } = playwright();
  const browser = await chromium.launch({ headless });
  try {
    const context = await browser.newContext({ viewport: null, ...(credentials === undefined ? {} : { httpCredentials: credentials }) });
    const page = await context.newPage();
    await page.goto(new URL(flow.login.start ?? "/", flow.url).toString(), { waitUntil: "load", timeout: 90000 });
    if (until !== undefined) {
      if (!headless) say(`Log in in the browser window. The login is saved once the address holds "${until}".`);
      await page.waitForURL((url) => url.toString().includes(until), { timeout: 15 * 60 * 1000 });
    } else {
      say("Log in in the browser window, then close the window. The login is saved when the window closes.");
      await page.waitForEvent("close", { timeout: 0 });
    }
    const file = sessionFile(root, flow.login.session);
    ensureDir(join(dataDir(), "sessions"));
    writeFileSync(file, JSON.stringify(await context.storageState()), { mode: 0o600 });
    chmodSync(file, 0o600);
    say(`Saved the login "${flow.login.session}" for this project: ${file}`);
  } finally {
    await browser.close();
  }
}

function recordingOut(input, out) {
  return out ?? join(dataDir(), projectName(process.cwd()), basename(input, extname(input)));
}

function scenes(input, out) {
  if (input === undefined || !existsSync(input)) refuse("Pass the recording to look through: scenes <recording>");
  ensureDir(out);
  rmSync(join(out, "scenes"), { recursive: true, force: true });
  const list = detectScenes(input, join(out, "scenes"));
  writeFileSync(join(out, "scenes.json"), `${JSON.stringify(list, null, 2)}\n`);
  const freezes = detectFreezes(input);
  writeFileSync(join(out, "freezes.json"), `${JSON.stringify(freezes, null, 2)}\n`);
  say(`Scene pictures: ${list.length} (${join(out, "scenes.json")})`);
  for (const scene of list) say(`  ${scene.t.toFixed(1)}s ${join(out, scene.file)}`);
  say(`Still stretches: ${freezes.length} (${join(out, "freezes.json")})`);
  say(`Next, read the pictures, write the captions into ${join(out, "captions.json")}, and run render.`);
}

function readCaptions(file) {
  let cues;
  try {
    cues = JSON.parse(readFileSync(file, "utf8"));
  } catch {
    refuse(`Cannot read ${file} as JSON.`);
  }
  const valid = Array.isArray(cues) && cues.every((c) => typeof c?.start === "number" && typeof c?.end === "number" && c.end > c.start && typeof c?.text === "string" && c.text !== "");
  if (!valid) refuse(`${file} must list {"start": seconds, "end": seconds, "text": caption}.`);
  return [...cues].sort((a, b) => a.start - b.start);
}

async function render(input, out) {
  if (input === undefined || !existsSync(input)) refuse("Pass the recording to caption: render <recording>");
  const captionsFile = join(out, "captions.json");
  if (!existsSync(captionsFile)) refuse(`${captionsFile} does not exist, so no captioned video was made. Run scenes first, read the pictures, and write captions.json.`);
  const cues = readCaptions(captionsFile);
  const work = mkdtempSync(join(tmpdir(), "screen-video-"));
  try {
    const base = join(work, "normalized.mp4");
    normalize(input, base);
    const duration = durationOf(base);
    writeFileSync(join(out, "captions.srt"), toSrt(cues));
    const images = await captionImages(cues, work);
    burn({ input: base, output: join(out, "captioned.mp4"), workDir: work, overlays: images });
    say(`Captioned video: ${join(out, "captioned.mp4")}`);
    const freezesFile = join(out, "freezes.json");
    const freezes = existsSync(freezesFile) ? JSON.parse(readFileSync(freezesFile, "utf8")) : detectFreezes(input);
    const segments = segmentsWithout(cutsForFreezes(freezes), duration);
    burn({ input: base, output: join(out, "edited.mp4"), workDir: work, segments, overlays: mapCues(segments, images) });
    say(`Edited video: ${join(out, "edited.mp4")} (${durationOf(join(out, "edited.mp4")).toFixed(1)}s)`);
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
}

const USAGE = "Usage: screen-video.sh setup | doctor | inspect <flow> | check <flow> | rehearse <flow> | record <flow> [--confirm-effects] | remake <flow> | login <flow> [--until <text>] | scenes <recording> | render <recording> (each takes --out <dir> where it writes files)";

const options = parse(process.argv.slice(2));
try {
  const [first] = options.args;
  switch (options.command) {
    case "doctor":
      doctor(options.flags.has("json"));
      break;
    case "inspect":
      await inspect(first, options.path);
      break;
    case "check":
      check(first);
      break;
    case "rehearse":
      await rehearse(first, options.out);
      break;
    case "record":
      await record(first, options.out, options.flags.has("confirm-effects"));
      break;
    case "remake":
      await remake(first, options.out);
      break;
    case "login":
      await login(first, options.until);
      break;
    case "scenes":
      scenes(first, recordingOut(first ?? "", options.out));
      break;
    case "render":
      await render(first, recordingOut(first ?? "", options.out));
      break;
    default:
      process.stderr.write(`${USAGE}\n`);
      process.exit(2);
  }
} catch (error) {
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
  process.exit(1);
}
