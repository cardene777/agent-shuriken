#!/usr/bin/env node
/**
 * The screen-video commands. `screen-video.sh` installs the runtime on first use and runs this file.
 *
 * | Command | What it does | Files written |
 * |---|---|---|
 * | `doctor [--json]` | Says which ffmpeg and Playwright it uses and where the data folder is | none |
 * | `inspect <flow> [--path <path>]` | Opens a page of the flow's site and lists its headings, buttons, links, and fields | `inspect.png` in the data folder |
 * | `check <flow>` | Checks a flow file, names its theme, and lists the steps that send something or pay | none |
 * | `rehearse <flow> [--out <dir>]` | Runs the flow without recording, up to the first step that sends something or pays, and writes the storyboard | `storyboard.html`, `frames/`, `rehearsal.json` |
 * | `voices <flow> [--out <dir>]` | Makes the flow's narration, installing the local voice engine the first time | `voice/`, `voice.json`, `credits.txt` |
 * | `record <flow> [--out <dir>] [--confirm-effects]` | Makes the narration, records the flow, and makes the videos. A flow with `addsTo` records only its own steps into `part/` and joins them into the other flow's recording; with `login.forget`, the saved login is removed when it ends | `raw.mp4`, `captioned.mp4`, `edited.mp4`, `vertical.mp4`, `edited.gif`, `timeline.json`, `captions.srt`, `edited.srt`, `edit.json`, `voice/`, `voice.json`, `credits.txt` |
 * | `remake <flow> [--out <dir>]` | Makes the narration and the videos again from `raw.mp4` and `timeline.json` in the flow's current look, without recording; for a flow with `addsTo`, joins the two recordings again first | the same as `record`, except `raw.mp4` and `timeline.json` |
 * | `compare <flow> [--out <dir>] [--before <dir>]` | Shows the plain video and the edited one side by side for each point the edit improves | `compare/compare.html`, `compare/plain.mp4` |
 * | `login <flow> [--until <text in the address>] [--start <address>]` | Opens a browser to log in by hand, at `--start` when given, keeping the logins already saved, and saves the login for the flow's `login.session` | `sessions/<project>--<session>.json` in the data folder |
 * | `logout <flow>` | Removes the saved login of the flow's `login.session` | none |
 * | `scenes <recording> [--out <dir>]` | Finds the scene changes and still stretches in a recording the user made | `scenes/`, `scenes.json`, `freezes.json` |
 * | `render <recording> [--out <dir>]` | Makes the captioned and edited videos from `captions.json` the agent wrote | `captioned.mp4`, `edited.mp4`, `captions.srt` |
 *
 * Login values are read from the env file a flow names and are never printed or written.
 */
import { chmodSync, existsSync, mkdtempSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, extname, join, resolve } from "node:path";

import { captionImages } from "./lib/captions.mjs";
import { writeCompare } from "./lib/compare.mjs";
import { captionCues, cutsForFreezes, mapCues, planEdit, segmentsWithout, VERTICAL_CROP } from "./lib/edit.mjs";
import { envLookup, languageOf, loadFlow, markedSteps, readLogin } from "./lib/flow.mjs";
import { joinedFlow, joinTimelines } from "./lib/join.mjs";
import { LAYOUTS, openDrawer } from "./lib/look.mjs";
import { burn, detectFreezes, detectScenes, durationOf, HEIGHT, joinRecordings, normalize, renderEdited, renderOver, stillFrame, toGif, toSrt, WIDTH } from "./lib/media.mjs";
import { startRecording } from "./lib/recorder.mjs";
import { runFlow, StepError } from "./lib/runner.mjs";
import { dataDir, ensureDir, ffmpegChoice, nodeDir, playwright, playwrightVersion, projectName, projectRoot, sessionFile } from "./lib/runtime.mjs";
import { mixSound } from "./lib/sound.mjs";
import { writeStoryboard } from "./lib/storyboard.mjs";
import { loadTheme } from "./lib/theme.mjs";
import { makeVoices } from "./lib/voice.mjs";

/** Files a run may remove when it empties its folder. Anything else stops the run. */
const ARTIFACT = /\.(mp4|webm|mov|gif|json|srt|png|html|txt|wav)$/iu;

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
    if (arg === "--out" || arg === "--until" || arg === "--path" || arg === "--before" || arg === "--start") options[arg.slice(2)] = rest[++i];
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
  let theme;
  try {
    theme = loadTheme(flow.theme ?? "default", root);
  } catch (error) {
    refuse(`flow: ${error instanceof Error ? error.message : error}`);
  }
  return { flow, root, theme, defaultOut: join(dataDir(), projectName(root), flow.name) };
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
  const { flow, theme } = openFlow(file);
  say(`${flow.name}: ${flow.steps.length} steps, videos ${flow.outputs.join(", ")}`);
  say(`theme: ${theme.name} (${theme.source})`);
  if (flow.addsTo !== undefined) say(`A part: it adds to ${flow.addsTo.flow} after ${flow.addsTo.after === undefined ? "its last step" : `step ${flow.addsTo.after}`}`);
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
  const { flow, root, theme, defaultOut } = openFlow(file);
  const dir = out ?? join(defaultOut, "rehearsal");
  clearDir(dir, { folders: ["frames"] });
  const framesDir = ensureDir(join(dir, "frames"));
  const login = readLogin(flow, root);
  const env = envLookup(flow, root);
  const rec = await startRecording({ record: false, credentials: login.credentials, storageState: login.storageState, masks: flow.mask, accent: theme.look.accent });
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

/** The music a flow asks for: `false`, `"made"` (the default), or the project's file. */
function musicOf(flow, root) {
  if (flow.music === false) return false;
  if (flow.music === undefined || flow.music === true) return "made";
  const file = join(root, flow.music.file);
  if (!existsSync(file)) refuse(`The music file ${flow.music.file} named by the flow does not exist in the project.`);
  return { file, volume: flow.music.volume };
}

const MADE_FILES = ["captioned.mp4", "edited.mp4", "vertical.mp4", "edited.gif", "captions.srt", "edited.srt", "edit.json", "credits.txt"];

/**
 * Makes every video after `raw.mp4` and `timeline.json`, in the flow's current look: the captioned
 * video at the recording's own times, the edited video, and the vertical video and GIF when the flow
 * asks for them, with `edit.json` saying how the edit was laid out.
 */
async function finish({ out, timeline, flow, root, theme, voice, work }) {
  const raw = join(out, "raw.mp4");
  const { steps, duration } = timeline;
  const language = languageOf(flow);
  const outputs = flow.outputs ?? ["16:9"];
  const look = theme.look;
  const cues = captionCues(steps, duration, language, voice.clips);
  writeFileSync(join(out, "captions.srt"), toSrt(cues));
  const plan = planEdit({ steps, duration, cues, clips: voice.clips, language, flow, planned: flow.seconds });
  if (plan.note !== undefined) say(plan.note);
  const end = plan.cards.find((card) => card.kind === "end");
  if (end !== undefined && voice.credit !== undefined) end.credit = voice.credit;
  // Each clip starts where its step's caption starts in the recording
  const startOf = new Map(steps.map((step) => [step.step, step.from ?? step.t]));
  const clips = voice.clips.map((clip) => ({ ...clip, start: startOf.get(clip.step) ?? 0 }));
  writeFileSync(join(out, "voice.json"), `${JSON.stringify({ ...voice, clips }, null, 2)}\n`);

  const music = musicOf(flow, root);
  const sounds = flow.sounds !== false;
  const soundFor = (name, length, at) =>
    mixSound({
      output: join(work, name),
      duration: length,
      voices: plan.voices.map((v) => ({ file: join(out, v.file), at: at(v), duration: v.duration })),
      presses: sounds ? plan.presses.map(at) : [],
      typed: sounds ? plan.typed.map(at) : [],
      music,
      work,
    });
  const editedSound = soundFor("edited.wav", plan.seconds, (event) => event.at);

  const drawer = await openDrawer(look, work, language);
  try {
    // The captioned video: the recording with captions over it and the sound at the recording's times
    const over = [];
    for (const cue of cues) over.push({ ...(await drawer.over(cue.text, cue.box ? [cue.box] : [])), start: cue.start, end: cue.end });
    const rawSound = soundFor("raw.wav", duration, (event) => event.raw);
    renderOver({ raw, output: join(out, "captioned.mp4"), captions: over, sound: rawSound, work });
    say(`Captioned video: ${join(out, "captioned.mp4")}`);

    const stills = plan.dissolves.map((d, i) => ({ file: stillFrame(raw, d.frame, join(work, `still-${i}.png`)), start: d.start, end: d.end }));
    const draw = async (layout) => {
      const captions = [];
      for (const caption of plan.captions) captions.push({ ...(await drawer.caption(caption.text, layout)), start: caption.start, end: caption.end, text: caption.text });
      const marks = [];
      for (const part of plan.fast) marks.push({ ...(await drawer.mark(part.speed, layout)), start: part.editedStart, end: part.editedEnd });
      const cards = [];
      let chapter = 0;
      for (const card of plan.cards) cards.push({ ...card, file: await drawer.card(card, layout, card.kind === "chapter" ? ++chapter : 0) });
      return { frame: await drawer.frame(layout), captions, marks, cards, stills, cropWidth: VERTICAL_CROP };
    };

    const wide = await draw(LAYOUTS.wide);
    renderEdited({ raw, output: join(out, "edited.mp4"), plan, layout: LAYOUTS.wide, pictures: wide, sound: editedSound, work });
    writeFileSync(join(out, "edited.srt"), toSrt(wide.captions));
    const edit = {
      theme: { name: theme.name, source: theme.source },
      frame: LAYOUTS.wide.window,
      length: plan.length,
      segments: plan.segments,
      // Still frames added under the cards, the end card's last
      freezes: [
        ...plan.freezes.map(({ at, seconds }) => ({ at, seconds })),
        ...(plan.endFrames > 0 ? [{ at: Number(((plan.lastFrame + 1) / 30).toFixed(3)), seconds: Number((plan.endFrames / 30).toFixed(3)) }] : []),
      ],
      cards: wide.cards.map(({ kind, text, url, note, credit, start, end }) => ({ kind, text, ...(url ? { url } : {}), ...(note ? { note } : {}), ...(credit ? { credit } : {}), start, end })),
      captions: wide.captions.map(({ start, end, text, box }) => ({ start, end, text, box })),
      fast: plan.fast.map((part, i) => ({ start: part.editedStart, end: part.editedEnd, speed: part.speed, box: wide.marks[i].box, raw: { start: part.start, end: part.end } })),
      dissolves: plan.dissolves.map(({ at, start, end }) => ({ at, start, end })),
      zooms: plan.actions,
      keys: plan.zoomKeys,
      steps: steps.map((step) => ({ step: step.step, from: plan.at(step.from ?? step.t), t: plan.at(step.t), end: plan.at(step.end) })),
      voices: plan.voices.map(({ step, at, duration: length }) => ({ step, at, duration: length })),
    };
    writeFileSync(join(out, "edit.json"), `${JSON.stringify(edit, null, 2)}\n`);
    say(`Edited video: ${join(out, "edited.mp4")} (${durationOf(join(out, "edited.mp4")).toFixed(1)}s)`);

    if (outputs.includes("9:16")) {
      const tall = await draw(LAYOUTS.tall);
      renderEdited({ raw, output: join(out, "vertical.mp4"), plan, layout: LAYOUTS.tall, pictures: tall, sound: editedSound, work });
      say(`Vertical video: ${join(out, "vertical.mp4")}`);
    }
  } finally {
    await drawer.close();
  }
  if (outputs.includes("gif")) {
    toGif(join(out, "edited.mp4"), join(out, "edited.gif"));
    say(`GIF: ${join(out, "edited.gif")}`);
  }
  if (voice.credit !== undefined) say(`Credit for the voice (in credits.txt and on the end card): ${voice.credit}`);
}

/**
 * The flow a part (`addsTo`) is added to, with its last recording and the step the part comes after.
 * Refuses, before anything is opened, when the flow file or its recording is missing or `after` is
 * past its last step.
 */
function otherOf({ flow, root }) {
  const name = flow.addsTo.flow;
  const file = join(root, ".screen-video", "flows", `${name}.json`);
  if (!existsSync(file)) refuse(`The part adds to ${name}, but the project has no flow file ${file}.`);
  const other = openFlow(file);
  const raw = join(other.defaultOut, "raw.mp4");
  const timelineFile = join(other.defaultOut, "timeline.json");
  if (!existsSync(raw) || !existsSync(timelineFile)) refuse(`The part adds to ${name}, which has no recording in ${other.defaultOut}. Record ${name} first.`);
  const timeline = { ...JSON.parse(readFileSync(timelineFile, "utf8")), duration: durationOf(raw) };
  const count = timeline.steps.length;
  const after = flow.addsTo.after ?? count;
  if (after > count) refuse(`The part goes after step ${after}, but the recording of ${name} has ${count} steps.`);
  return { ...other, dir: other.defaultOut, raw, timeline, after };
}

/** Joins the part recorded in `<dir>/part/` into the other flow's recording and makes the joined videos in `dir`. */
async function joinPart({ flow, root, dir, other, work }) {
  const partRaw = join(dir, "part", "raw.mp4");
  const part = { ...JSON.parse(readFileSync(join(dir, "part", "timeline.json"), "utf8")), duration: durationOf(partRaw) };
  const joined = joinTimelines(other.timeline, part, other.after);
  const raw = join(dir, "raw.mp4");
  joinRecordings({ other: other.raw, part: partRaw, cut: joined.cut, start: joined.start, output: raw });
  const timeline = {
    flow: flow.name,
    width: WIDTH,
    height: HEIGHT,
    duration: durationOf(raw),
    outputs: other.flow.outputs,
    joined: { flow: other.flow.name, after: other.after },
    steps: joined.steps,
  };
  writeFileSync(join(dir, "timeline.json"), `${JSON.stringify(timeline, null, 2)}\n`);
  say(`Joined after step ${other.after} of ${other.flow.name}: ${raw} (${timeline.duration.toFixed(1)}s)`);
  const whole = joinedFlow(other.flow, flow, other.after);
  const voice = await makeVoices(whole, root, dir);
  await finish({ out: dir, timeline, flow: whole, root, theme: other.theme, voice, work });
}

/** Removes the saved login of a flow whose `login.forget` is true, and says so. */
function forgetLogin(flow, root) {
  if (flow.login?.forget !== true || flow.login.session === undefined) return;
  const saved = sessionFile(root, flow.login.session);
  if (!existsSync(saved)) return;
  rmSync(saved, { force: true });
  say(`Removed the saved login "${flow.login.session}" (login.forget): ${saved}`);
}

async function record(file, out, confirmed) {
  const opened = openFlow(file);
  const { flow, root, defaultOut } = opened;
  const marked = markedSteps(flow);
  if (marked.length > 0 && !confirmed) {
    refuse(
      `This flow has steps that send something or pay each time it is recorded:\n${listMarked(marked)}\n` +
        "Show them to the user, and only after the user agrees, run record again with --confirm-effects.",
    );
  }
  const other = flow.addsTo === undefined ? undefined : otherOf(opened);
  // A part is paced and pointed at in the look and voice of the flow it joins
  const theme = other?.theme ?? opened.theme;
  const paced = other === undefined ? flow : { ...flow, voice: other.flow.voice, language: languageOf(other.flow) };
  const dir = out ?? defaultOut;
  clearDir(dir, { keep: ["rehearsal"], folders: ["voice", "compare", "part"] });
  const target = other === undefined ? dir : ensureDir(join(dir, "part"));
  // From here the saved login is used, so a login marked forget is removed however the recording ends
  try {
    const login = readLogin(flow, root);
    const env = envLookup(flow, root);
    const work = mkdtempSync(join(tmpdir(), "screen-video-"));
    try {
      const voice = await makeVoices(paced, root, target);
      const rec = await startRecording({ videoDir: work, credentials: login.credentials, storageState: login.storageState, masks: flow.mask, accent: theme.look.accent });
      try {
        await runFlow({ flow, rec, env, voices: voice.clips });
      } catch (error) {
        await rec.screenshot(join(dir, "failure.png"));
        await rec.abort();
        const message = error instanceof StepError ? error.message : `${error instanceof Error ? error.message.split("\n")[0] : error}`;
        refuse(`${message} (the screen when it stopped: ${join(dir, "failure.png")})`);
      }
      const webm = await rec.stop();
      if (webm === undefined) refuse("The recording has no frames.");
      const raw = join(target, "raw.mp4");
      normalize(webm, raw);
      const timeline = { flow: flow.name, width: WIDTH, height: HEIGHT, duration: durationOf(raw), outputs: flow.outputs, steps: rec.steps };
      writeFileSync(join(target, "timeline.json"), `${JSON.stringify(timeline, null, 2)}\n`);
      say(`Raw video: ${raw} (${timeline.duration.toFixed(1)}s)`);
      if (other === undefined) await finish({ out: dir, timeline, flow, root, theme, voice, work });
      else await joinPart({ flow, root, dir, other, work });
    } finally {
      rmSync(work, { recursive: true, force: true });
    }
  } finally {
    forgetLogin(flow, root);
  }
}

/** Reads the last recording in `dir` (or the flow's folder), refusing when there is none. */
function lastRecording(file, out) {
  const opened = openFlow(file);
  const dir = out ?? opened.defaultOut;
  const raw = join(dir, "raw.mp4");
  const timelineFile = join(dir, "timeline.json");
  if (!existsSync(raw) || !existsSync(timelineFile)) refuse(`${dir} has no raw.mp4 and timeline.json. Record the flow first.`);
  const timeline = JSON.parse(readFileSync(timelineFile, "utf8"));
  return { ...opened, dir, timeline: { ...timeline, duration: durationOf(raw) } };
}

async function remake(file, out) {
  const opened = openFlow(file);
  if (opened.flow.addsTo !== undefined) {
    const other = otherOf(opened);
    const dir = out ?? opened.defaultOut;
    if (!existsSync(join(dir, "part", "raw.mp4")) || !existsSync(join(dir, "part", "timeline.json"))) refuse(`${join(dir, "part")} has no raw.mp4 and timeline.json. Record the part first.`);
    for (const name of MADE_FILES) rmSync(join(dir, name), { force: true });
    rmSync(join(dir, "compare"), { recursive: true, force: true });
    const work = mkdtempSync(join(tmpdir(), "screen-video-"));
    try {
      await joinPart({ flow: opened.flow, root: opened.root, dir, other, work });
    } finally {
      rmSync(work, { recursive: true, force: true });
    }
    return;
  }
  const { flow, root, theme, dir, timeline } = lastRecording(file, out);
  for (const name of MADE_FILES) rmSync(join(dir, name), { force: true });
  rmSync(join(dir, "compare"), { recursive: true, force: true });
  const work = mkdtempSync(join(tmpdir(), "screen-video-"));
  try {
    const voice = await makeVoices(flow, root, dir);
    await finish({ out: dir, timeline, flow, root, theme, voice, work });
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
}

async function voices(file, out) {
  const { flow, root, defaultOut } = openFlow(file);
  const dir = ensureDir(out ?? join(defaultOut, "voices"));
  const made = await makeVoices(flow, root, dir);
  if (made.clips.length === 0) say("The flow has no narration (no voice, or no captions to read).");
  else say(`Voice: ${made.engine} (${made.voice}), ${made.clips.length} lines, ${made.clips.reduce((sum, clip) => sum + clip.duration, 0).toFixed(1)}s (${join(dir, "voice.json")})`);
  if (made.credit !== undefined) say(`Credit for the voice: ${made.credit}`);
}

async function compare(file, out, before) {
  const { flow, dir, timeline } = lastRecording(file, out);
  const editFile = join(dir, "edit.json");
  if (!existsSync(editFile) || !existsSync(join(dir, "edited.mp4"))) refuse(`${dir} has no edited.mp4 and edit.json. Record or remake the flow first.`);
  const edit = JSON.parse(readFileSync(editFile, "utf8"));
  const voice = existsSync(join(dir, "voice.json")) ? JSON.parse(readFileSync(join(dir, "voice.json"), "utf8")) : { clips: [] };
  const cues = captionCues(timeline.steps, timeline.duration, languageOf(flow), voice.clips ?? []);
  const target = join(dir, "compare");
  rmSync(target, { recursive: true, force: true });
  ensureDir(target);
  const work = mkdtempSync(join(tmpdir(), "screen-video-"));
  try {
    const page = await writeCompare({ out: dir, before: before === undefined ? undefined : resolve(before), timeline, edit, cues, flow, work, dir: target });
    say(`Comparison: ${page}`);
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
}

async function login(file, until, start) {
  const { flow, root } = openFlow(file);
  if (flow.login?.session === undefined) refuse("The flow has no login.session to save the login under.");
  if (start !== undefined && !/^https?:\/\/[^/\s]+/.test(start)) refuse("--start takes a full address that starts with http:// or https://");
  const credentials = flow.login.basic === undefined ? undefined : readLogin({ ...flow, login: { ...flow.login, session: undefined } }, root).credentials;
  const saved = sessionFile(root, flow.login.session);
  const headless = process.env.SCREEN_VIDEO_HEADLESS === "1";
  const { chromium } = playwright();
  const browser = await chromium.launch({ headless });
  try {
    // Starting from the saved login keeps it, so the app and an outside service can each be logged in to once
    const context = await browser.newContext({
      viewport: null,
      ...(credentials === undefined ? {} : { httpCredentials: credentials }),
      ...(existsSync(saved) ? { storageState: saved } : {}),
    });
    const page = await context.newPage();
    await page.goto(start ?? new URL(flow.login.start ?? "/", flow.url).toString(), { waitUntil: "load", timeout: 90000 });
    if (until !== undefined) {
      if (!headless) say(`Log in in the browser window. The login is saved once the address holds "${until}".`);
      await page.waitForURL((url) => url.toString().includes(until), { timeout: 15 * 60 * 1000 });
    } else {
      say("Log in in the browser window, then close the window. The login is saved when the window closes.");
      await page.waitForEvent("close", { timeout: 0 });
    }
    ensureDir(join(dataDir(), "sessions"));
    writeFileSync(saved, JSON.stringify(await context.storageState()), { mode: 0o600 });
    chmodSync(saved, 0o600);
    say(`Saved the login "${flow.login.session}" for this project: ${saved}`);
    if (flow.login.forget === true) say("record removes it when it ends, because the flow says login.forget.");
  } finally {
    await browser.close();
  }
}

function logout(file) {
  const { flow, root } = openFlow(file);
  if (flow.login?.session === undefined) refuse("The flow has no login.session, so it has no saved login.");
  const saved = sessionFile(root, flow.login.session);
  if (!existsSync(saved)) {
    say(`No saved login "${flow.login.session}" for this project.`);
    return;
  }
  rmSync(saved, { force: true });
  say(`Removed the saved login "${flow.login.session}": ${saved}`);
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

const USAGE = "Usage: screen-video.sh setup | doctor | inspect <flow> | check <flow> | rehearse <flow> | voices <flow> | record <flow> [--confirm-effects] | remake <flow> | compare <flow> [--before <dir>] | login <flow> [--until <text>] [--start <address>] | logout <flow> | scenes <recording> | render <recording> (each takes --out <dir> where it writes files)";

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
    case "voices":
      await voices(first, options.out);
      break;
    case "compare":
      await compare(first, options.out, options.before);
      break;
    case "login":
      await login(first, options.until, options.start);
      break;
    case "logout":
      logout(first);
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
