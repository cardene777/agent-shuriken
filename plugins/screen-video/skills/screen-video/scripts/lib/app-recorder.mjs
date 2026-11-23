/**
 * Drives an app with a driver (`devices.mjs`), records it, and keeps the second at which each action
 * happened, with the same methods and records as the browser's recorder (`recorder.mjs`), so
 * `runFlow` runs a flow on either. It adds `locate` (the part a target names), `waitUntil`, and
 * `swipe`.
 *
 * The app's screen is placed on the 1920x1080 screen of `raw.mp4` as large as it fits, in the middle
 * (`screen`), and each record keeps where the action was on that screen: `press` (the middle of the
 * part pressed), `box` and `path` (the part and the pointer's way, macOS only, so the edit zooms in
 * on a window's part and draws the pointer), and `swipe`. A phone keeps no `box`: its screen is
 * never zoomed into.
 *
 * Each time the parts are read, and right after each action, it keeps where the flow's masked parts
 * are. A place is blurred from the reading before it to the reading after it, so a part that moved
 * between two readings is blurred at both places. `stop()` returns the recording, which still shows
 * the masked parts, and the areas to blur, for `composeApp` to blur at once.
 */
import { readFileSync, rmSync } from "node:fs";
import { join } from "node:path";

import { findPart, partsHolding } from "./app-parts.mjs";
import { openDriver } from "./devices.mjs";
import { describeTarget } from "./flow.mjs";
import { HEIGHT, pictureApp, WIDTH } from "./media.mjs";
import { pointerPath } from "./recorder.mjs";

const sleep = (ms) => new Promise((done) => setTimeout(done, ms));
const round3 = (value) => Number(value.toFixed(3));
const round1 = (value) => Math.round(value * 10) / 10;
/** Pixels around a masked part that are blurred too. */
const MASK_MARGIN = 6;

/** Where an app's screen of `size` sits on the 1920x1080 screen: as large as it fits, in the middle. */
function screenPlace(size) {
  const scale = Math.min(WIDTH / size.width, HEIGHT / size.height);
  const width = Math.round(size.width * scale);
  const height = Math.round(size.height * scale);
  return { x: Math.round((WIDTH - width) / 2), y: Math.round((HEIGHT - height) / 2), width, height };
}

const even = (value) => Math.max(0, Math.floor(value / 2) * 2);
/** The width of a PNG, read from its header. */
const pngWidth = (file) => readFileSync(file).readUInt32BE(16);

/**
 * Starts the app of `flow` on `driver` (by default the platform's, which checks first that the
 * system is ready) and, when `record`, its recording. `work` is the folder for the recording and the
 * pictures on their way.
 */
export async function startAppRecording({ flow, root, driver = openDriver(flow.app.platform), record = true, work }) {
  await driver.start(flow.app, root);
  const size = driver.size;
  const screen = screenPlace(size);
  const scale = screen.width / size.width;
  const onScreen = (x, y) => ({ x: round1(screen.x + x * scale), y: round1(screen.y + y * scale) });
  const boxOf = ([x, y, w, h]) => ({ x: Math.round(screen.x + x * scale), y: Math.round(screen.y + y * scale), width: Math.round(w * scale), height: Math.round(h * scale) });
  const mac = flow.app.platform === "mac";
  const masks = flow.mask ?? [];
  const reads = [];
  let shots = 0;

  /** The frames of the masked parts among `parts`. */
  const masked = (parts) =>
    masks.flatMap((mask) => {
      if (mask.rect !== undefined) return [mask.rect];
      if (mask.text !== undefined) return partsHolding(parts, mask.text).map((part) => part.frame);
      const part = findPart(parts, mask.target);
      return part === undefined ? [] : [part.frame];
    });

  let capture;
  let started = Date.now();
  if (record) {
    capture = await driver.capture(join(work, "capture.mp4"));
    started = capture.started;
  }
  const now = () => round3((Date.now() - started) / 1000);
  const steps = [];
  let pointer = { x: WIDTH / 2, y: HEIGHT / 2 };

  /** Reads the parts, keeping where the masked ones are at this moment. */
  function read() {
    const parts = driver.parts();
    if (masks.length > 0) reads.push({ t: now(), frames: masked(parts) });
    return parts;
  }
  const readAgain = () => {
    if (masks.length > 0) read();
  };
  readAgain();

  /** Finds the part a target names, reading again until `timeout` milliseconds pass. */
  async function locate(target, timeout) {
    const until = Date.now() + timeout;
    for (;;) {
      const part = findPart(read(), target);
      if (part !== undefined) return part;
      if (Date.now() >= until) throw new Error(`cannot find ${describeTarget(target)} on the screen (waited ${Math.round(timeout / 1000)}s)`);
      await sleep(400);
    }
  }

  /**
   * Presses the middle of `part`: on macOS the drawn pointer first travels there at a person's pace;
   * on a phone the finger comes down after a short pause. `ready` runs with the part's frame just
   * before the press.
   */
  async function press(part, ready) {
    const [x, y, w, h] = part.frame;
    const middle = { x: x + w / 2, y: y + h / 2 };
    const at = onScreen(middle.x, middle.y);
    let path;
    if (mac) {
      const { ms, points } = pointerPath(pointer, at, Math.max(24, Math.min(w, h) * scale));
      const t0 = now();
      if (Math.hypot(at.x - pointer.x, at.y - pointer.y) >= 4) await sleep(ms);
      pointer = at;
      const kept = 16;
      path = Array.from({ length: kept + 1 }, (_, i) => {
        const index = Math.round((i / kept) * (points.length - 1));
        return { t: round3(t0 + (index / (points.length - 1)) * (ms / 1000)), x: round1(points[index].x), y: round1(points[index].y) };
      });
    } else await sleep(250);
    if (ready !== undefined) await ready(part.frame);
    const t = now();
    driver.press(middle.x, middle.y);
    return { t, press: at, ...(mac ? { box: boxOf(part.frame), path } : {}) };
  }

  const begin = (number, caption, chapter) => ({ step: number, from: now(), caption, ...(chapter ? { chapter } : {}) });

  /** The areas to blur in the recording scaled to `screen`, each from the reading before it to the reading after it. */
  function blurAreas(end) {
    const areas = new Map();
    reads.forEach((reading, i) => {
      const from = i === 0 ? 0 : reads[i - 1].t;
      const to = i + 1 < reads.length ? reads[i + 1].t : end + 1;
      for (const [x, y, w, h] of reading.frames) {
        const left = even(Math.min(screen.width, Math.max(0, x * scale - MASK_MARGIN)));
        const top = even(Math.min(screen.height, Math.max(0, y * scale - MASK_MARGIN)));
        const width = even(Math.min(screen.width - left, (x + w) * scale + MASK_MARGIN - left + 1));
        const height = even(Math.min(screen.height - top, (y + h) * scale + MASK_MARGIN - top + 1));
        if (width < 4 || height < 4) continue;
        const key = `${left},${top},${width},${height}`;
        const known = areas.get(key);
        // Readings of the same place in a row make one area
        if (known !== undefined && known.to >= from) known.to = Math.max(known.to, to);
        else areas.set(known === undefined ? key : `${key}@${from}`, { x: left, y: top, width, height, from, to });
      }
    });
    return [...areas.values()];
  }

  /** Saves a picture of the app with its masked parts blurred, and `frame` (the app's coordinates) outlined when given. */
  async function picture(path, frame) {
    const shot = join(work, `shot-${++shots}.png`);
    driver.screenshot(shot);
    try {
      const k = pngWidth(shot) / size.width;
      const inPicture = ([x, y, w, h], margin) => ({ x: Math.max(0, Math.round(x * k - margin)), y: Math.max(0, Math.round(y * k - margin)), width: Math.round(w * k + 2 * margin), height: Math.round(h * k + 2 * margin) });
      const shown = masks.length === 0 ? [] : masked(driver.parts());
      pictureApp({ input: shot, output: path, masks: shown.map((f) => inPicture(f, MASK_MARGIN)), outline: frame === undefined ? undefined : inPicture(frame, 0), work });
    } finally {
      rmSync(shot, { force: true });
    }
  }

  return {
    steps,
    now,
    app: { platform: flow.app.platform, id: flow.app.id, width: size.width, height: size.height },
    screen,
    locate,
    async waitUntil(until, timeout) {
      const [kind, value] = Object.entries(until)[0];
      const deadline = Date.now() + timeout;
      for (;;) {
        const parts = read();
        const part = kind === "text" ? findPart(parts, { text: value }) : findPart(parts, value);
        if (kind === "hidden" ? part === undefined : kind === "enabled" ? part?.enabled === true : part !== undefined) return;
        if (Date.now() >= deadline) {
          const what = kind === "text" ? `text "${value}"` : `${describeTarget(value)} to be ${kind}`;
          throw new Error(`the wait for ${what} did not end (waited ${Math.round(timeout / 1000)}s)`);
        }
        await sleep(400);
      }
    },
    async open(_url, caption, { number, chapter } = {}) {
      const step = begin(number, caption, chapter);
      await driver.open(flow.app);
      steps.push({ ...step, kind: "open", t: step.from, end: now() });
      readAgain();
    },
    async click(part, caption, { ready, number, chapter } = {}) {
      const step = begin(number, caption, chapter);
      const pressed = await press(part, ready);
      steps.push({ ...step, kind: "click", ...pressed, end: round3(pressed.t + 0.3) });
      await sleep(150);
      readAgain();
    },
    async fill(part, text, caption, { clear = false, ready, secret = false, number, chapter } = {}) {
      if (!secret && part.secure) throw new Error('types into a password field as plain text; use "env" for the value');
      const step = begin(number, caption, chapter);
      const pressed = await press(part, ready);
      await sleep(300);
      if (clear) {
        if (mac) {
          driver.key("Meta+A");
          driver.key("Backspace");
        } else for (let i = 0; i < Math.min(200, part.value.length); i++) driver.key("Backspace");
      }
      const typing = now();
      driver.type(text);
      const typed = now();
      const count = [...text].length;
      // The Swift tool types at its own pace; a phone takes the text at once, spread here over the time it took
      const gap = driver.keyGap ?? (count > 1 ? (typed - typing) / count : 0);
      const keys = Array.from({ length: count }, (_, i) => round3(typing + i * gap));
      steps.push({ ...step, kind: "fill", ...pressed, end: now(), keys });
      readAgain();
    },
    async select() {
      throw new Error("an app flow cannot choose in a select field");
    },
    async key(name, caption, { number, chapter } = {}) {
      const step = begin(number, caption, chapter);
      driver.key(name);
      steps.push({ ...step, kind: "key", t: step.from, end: round3(step.from + 0.3) });
      readAgain();
    },
    async swipe(from, to, seconds, caption, { number, chapter } = {}) {
      const step = begin(number, caption, chapter);
      await sleep(250);
      const t = now();
      driver.swipe(from, to, seconds);
      steps.push({ ...step, kind: "swipe", t, end: now(), swipe: { from: onScreen(...from), to: onScreen(...to), seconds } });
      readAgain();
    },
    async waitFor(caption, until, { number, chapter } = {}) {
      const step = begin(number, caption, chapter);
      await until();
      steps.push({ ...step, kind: "wait", t: step.from, end: now() });
    },
    async hold(sec, caption, { number, chapter } = {}) {
      const step = begin(number, caption, chapter);
      await sleep(sec * 1000);
      steps.push({ ...step, kind: "hold", t: step.from, end: now() });
    },
    async until(at) {
      const left = at - now();
      if (left > 0) await sleep(Math.round(left * 1000));
    },
    /** Saves a picture of the app, with `frame` outlined when given (a rehearsal's picture of a step). */
    frame: (path, frame) => picture(path, frame),
    /** Ends the recording; returns it and the areas to blur in it. */
    async stop() {
      const end = now();
      const file = await capture.stop();
      return { file, masks: blurAreas(end) };
    },
    /** Saves the screen when something failed. */
    screenshot: (path) => picture(path).catch(() => undefined),
    async abort() {
      await capture?.abort();
    },
  };
}
