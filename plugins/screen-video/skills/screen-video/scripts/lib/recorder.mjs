/**
 * Drives a page with Playwright, records the screen, and keeps the second at which each action happened.
 *
 * | Method | Record kept (`kind`) | What it does |
 * |---|---|---|
 * | `open` | `open` | Opens a page and keeps its address |
 * | `click` | `click` | Moves the pointer on a curve and clicks. Keeps the box clicked, the pointer's path, and whether the page moved (`navigates`) |
 * | `fill` | `fill` | Clicks a field and types at a person's pace. Keeps the field's box and the time of each key. Never keeps what was typed |
 * | `select` | `select` | Chooses an option in a select field |
 * | `key` | `key` | Presses a key |
 * | `waitFor` | `wait` | Waits for a condition. Keeps when the wait began and ended |
 * | `hold` | `hold` | Stays still so the screen can be seen |
 *
 * Each record has `step` (the flow's step number), `from` (when the step began, where its caption
 * starts), `t` (the moment of the action), and `end`. The browser does not draw the pointer, so an
 * arrow is drawn on top of the page; a press shows a ring and pushes the pressed button in a little.
 * Times count from the first frame of the recording: the recording's zero is when the first frame
 * arrives, which differs from when the page or the recording was started by up to a few tenths of a second.
 * With `record: false` nothing is recorded, for rehearsals.
 */
import { join } from "node:path";

import { HEIGHT, WIDTH } from "./media.mjs";
import { playwright } from "./runtime.mjs";

/**
 * Draws the pointer and the ring shown on a press, pushes a pressed button in, and keeps when the
 * page last changed (for waits until the page settles). Changes to what this draws are not counted.
 * Not drawn inside iframes.
 */
/** The pointer's arrow, 30 pixels square with its tip at (5, 3), as SVG. The edit of an app draws the same arrow. */
export const POINTER_SVG =
  '<svg xmlns="http://www.w3.org/2000/svg" width="30" height="30" viewBox="0 0 30 30"><path d="M5 3 L5 24 L10.6 18.6 L14.4 27 L18 25.4 L14.3 17.3 L22 17.3 Z" fill="#102A43" stroke="#fff" stroke-width="1.8" stroke-linejoin="round"/></svg>';

function installCursor(accent) {
  if (window.top !== window) return;
  const own = (node) => node !== null && node.nodeType === 1 && typeof node.id === "string" && node.id.startsWith("__sv_");
  const inOwn = (node) => {
    for (let at = node; at !== null && at !== undefined; at = at.parentNode) if (own(at)) return true;
    return false;
  };
  window.__svLastChange = performance.now();
  new MutationObserver((records) => {
    const counted = records.some((r) => {
      if (inOwn(r.target)) return false;
      if (r.type === "childList") return ![...r.addedNodes, ...r.removedNodes].every(own);
      return true;
    });
    if (counted) window.__svLastChange = performance.now();
  }).observe(document, { subtree: true, childList: true, characterData: true, attributes: true });
  const install = () => {
    if (document.getElementById("__sv_cursor") !== null) return;
    const cursor = document.createElement("div");
    cursor.id = "__sv_cursor";
    cursor.innerHTML = accent.pointer;
    Object.assign(cursor.style, { position: "fixed", left: "0", top: "0", zIndex: "2147483647", pointerEvents: "none", transform: "translate(960px,540px)" });
    const ring = document.createElement("div");
    ring.id = "__sv_ring";
    Object.assign(ring.style, {
      position: "fixed", left: "-60px", top: "-60px", width: "120px", height: "120px", borderRadius: "50%",
      background: accent.fill, boxShadow: `0 0 0 3px ${accent.line}`, zIndex: "2147483646", pointerEvents: "none", opacity: "0",
    });
    document.documentElement.append(ring, cursor);
  };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", install);
  else install();
  const place = (x, y) => {
    install();
    document.getElementById("__sv_cursor").style.transform = `translate(${x}px,${y}px)`;
  };
  window.__svCursor = place;
  /**
   * Moves the pointer through `points` (taken at equal times) in `ms`, every 16 milliseconds. Timers,
   * not animation frames, keep it going: a headless browser may hold animation frames back.
   */
  window.__svGlide = (points, ms) =>
    new Promise((resolve) => {
      const started = performance.now();
      const frame = () => {
        const u = Math.min(1, (performance.now() - started) / ms);
        const f = u * (points.length - 1);
        const i = Math.min(points.length - 2, Math.floor(f));
        const k = f - i;
        place(points[i][0] + (points[i + 1][0] - points[i][0]) * k, points[i][1] + (points[i + 1][1] - points[i][1]) * k);
        if (u < 1) setTimeout(frame, 16);
        else resolve();
      };
      frame();
    });
  /** The ring at (x, y), and the button there pushed in for a moment. */
  window.__svPress = (x, y) => {
    install();
    // Position and size move in one transform: scaling separately would shrink the translate too.
    // The ring stays strong for the first half and fades in the second; easing each keyframe rather
    // than the whole effect keeps the fade from starting a tenth of a second after the press.
    document.getElementById("__sv_ring").animate(
      [
        { opacity: 1, transform: `translate(${x}px,${y}px) scale(0.5)`, easing: "cubic-bezier(.2,.7,.3,1)" },
        { opacity: 0.9, transform: `translate(${x}px,${y}px) scale(0.85)`, offset: 0.5, easing: "ease-in" },
        { opacity: 0, transform: `translate(${x}px,${y}px) scale(1)` },
      ],
      { duration: 600 },
    );
    const hit = document.elementFromPoint(x, y);
    const button = hit?.closest?.('button,a,summary,label,[role="button"],[role="link"],[role="tab"],[role="menuitem"],[role="checkbox"],[role="switch"],input[type="submit"],input[type="button"],input[type="checkbox"],input[type="radio"]');
    // Added to whatever transform the page gives it, so the page's own layout stays as it is
    button?.animate(
      [{ transform: "scale(1)" }, { transform: "scale(0.955)", offset: 0.12 }, { transform: "scale(0.955)", offset: 0.62 }, { transform: "scale(1)" }],
      { duration: 340, composite: "add", easing: "ease-out" },
    );
  };
}

/**
 * Blurs the elements a flow masks before they are painted: CSS selectors, elements whose text holds
 * a masked text, and fields whose value holds one. Runs again whenever the page changes.
 */
function installMasks(masks) {
  const blur = (element) => element.style.setProperty("filter", "blur(14px)", "important");
  let queued = false;
  const apply = () => {
    queued = false;
    for (const mask of masks) {
      if (mask.css) document.querySelectorAll(mask.css).forEach(blur);
      if (mask.text) {
        const walker = document.createTreeWalker(document.documentElement, NodeFilter.SHOW_TEXT);
        for (let node = walker.nextNode(); node !== null; node = walker.nextNode()) {
          if (node.nodeValue.includes(mask.text) && node.parentElement !== null) blur(node.parentElement);
        }
        document.querySelectorAll("input, textarea").forEach((field) => {
          if (field.value.includes(mask.text)) blur(field);
        });
      }
    }
  };
  const schedule = () => {
    if (queued) return;
    queued = true;
    queueMicrotask(apply);
  };
  new MutationObserver(schedule).observe(document, { subtree: true, childList: true, characterData: true, attributes: true });
  document.addEventListener("input", schedule, true);
  document.addEventListener("DOMContentLoaded", apply);
}

const round = (box) => ({ x: Math.round(box.x), y: Math.round(box.y), width: Math.round(box.width), height: Math.round(box.height) });
const seconds = (ms) => Number((ms / 1000).toFixed(3));
const minimumJerk = (u) => u * u * u * (10 - 15 * u + 6 * u * u);
/** Gaps between keys, in milliseconds, repeated: a person types unevenly. */
const KEY_GAPS = [118, 96, 142, 104, 126, 92, 137, 110, 99, 131, 115, 94];

/**
 * The pointer's way from `from` to `to`: a gentle arc, taken quickly at first and slowly near the
 * target, over a time that grows with the distance and shrinks with the target's size (Fitts' law).
 */
export function pointerPath(from, to, size) {
  const dx = to.x - from.x;
  const dy = to.y - from.y;
  const length = Math.hypot(dx, dy);
  const ms = Math.round(1000 * Math.min(1.05, Math.max(0.45, 0.42 + 0.11 * Math.log2(1 + length / Math.max(24, size)))));
  // The arc bends to one side by up to 14% of the distance, at most 160px
  const bend = length < 4 ? 0 : Math.min(160, 0.14 * length) * (dx >= 0 ? -1 : 1);
  const control = { x: from.x + dx / 2 + (length < 4 ? 0 : (-dy / length) * bend), y: from.y + dy / 2 + (length < 4 ? 0 : (dx / length) * bend) };
  const at = (s) => ({
    x: (1 - s) * (1 - s) * from.x + 2 * s * (1 - s) * control.x + s * s * to.x,
    y: (1 - s) * (1 - s) * from.y + 2 * s * (1 - s) * control.y + s * s * to.y,
  });
  const frames = Math.max(2, Math.round(ms / 16));
  const points = Array.from({ length: frames + 1 }, (_, i) => at(minimumJerk(i / frames)));
  return { ms, points };
}

export async function startRecording({ record = true, videoDir, credentials, storageState, masks = [], accent = "#38bdf8" }) {
  const { chromium } = playwright();
  const browser = await chromium.launch();
  const context = await browser.newContext({
    ...(credentials === undefined ? {} : { httpCredentials: credentials }),
    ...(storageState === undefined ? {} : { storageState }),
    viewport: { width: WIDTH, height: HEIGHT },
    deviceScaleFactor: 1,
  });
  const [r, g, b] = [1, 3, 5].map((i) => parseInt((accent.length === 4 ? `#${[...accent.slice(1)].map((c) => c + c).join("")}` : accent).slice(i, i + 2), 16));
  await context.addInitScript(installCursor, { fill: `rgba(${r},${g},${b},0.36)`, line: `rgba(${r},${g},${b},0.95)`, pointer: POINTER_SVG });
  if (masks.length > 0) await context.addInitScript(installMasks, masks);
  const page = await context.newPage();
  const video = record ? join(videoDir, "recording.webm") : undefined;
  // Times count from `started`; after recording they move by the gap to the first frame (firstFrame)
  let firstFrame;
  const started = Date.now();
  if (record) {
    await page.screencast.start({
      path: video,
      size: { width: WIDTH, height: HEIGHT },
      onFrame: ({ timestamp }) => {
        firstFrame ??= timestamp;
      },
    });
  }
  const steps = [];
  let pointer = { x: WIDTH / 2, y: HEIGHT / 2 };
  const now = () => seconds(Date.now() - started);

  /**
   * Scrolls the page or a dialog until the box is clear of the top 90px and the bottom 220px (where
   * captions go). Brings the element to the middle first, then turns the wheel; stops when two turns
   * in a row do not move the box (the end of the page).
   */
  async function reveal(locator, timeout) {
    await locator.waitFor({ state: "visible", timeout });
    const safe = (box) => box !== null && box.y >= 90 && box.y + box.height <= HEIGHT - 220;
    let box = await locator.boundingBox();
    if (!safe(box)) {
      await locator.evaluate((el) => el.scrollIntoView({ block: "center", behavior: "instant" }), null, { timeout: 3000 }).catch(() => undefined);
      await page.waitForTimeout(300);
      box = await locator.boundingBox();
    }
    let still = 0;
    for (let i = 0; i < 24 && !safe(box) && still < 2; i++) {
      await page.mouse.move(WIDTH / 2, HEIGHT / 2);
      await page.mouse.wheel(0, box === null || box.y > HEIGHT / 2 ? 260 : -260);
      await page.waitForTimeout(380);
      const moved = await locator.boundingBox();
      still = box !== null && moved !== null && Math.abs(moved.y - box.y) < 1 ? still + 1 : 0;
      box = moved;
    }
    if (box === null) throw new Error("the element does not show on the screen");
    const middle = box.y + box.height / 2;
    if (middle < 0 || middle > HEIGHT) throw new Error("the element stays outside the screen");
    return box;
  }

  /** Moves the drawn pointer from where it is to (x, y) and returns the way it took, with times. */
  async function glide(x, y, size) {
    const from = pointer;
    const { ms, points } = pointerPath(from, { x, y }, size);
    const t0 = now();
    if (Math.hypot(x - from.x, y - from.y) >= 4) {
      // Never waits much past the planned time, even when the page stops answering on the way
      const moved = page.evaluate(([list, length]) => window.__svGlide?.(list, length), [points.map((p) => [p.x, p.y]), ms]).catch(() => page.waitForTimeout(ms));
      await Promise.race([moved, new Promise((resolve) => setTimeout(resolve, ms + 1500))]);
    }
    await page.mouse.move(x, y);
    await page.evaluate(([a, b]) => window.__svCursor?.(a, b), [x, y]).catch(() => undefined);
    pointer = { x, y };
    // Sixteen points of the way, enough to see its shape and its speed
    const kept = 16;
    return Array.from({ length: kept + 1 }, (_, i) => {
      const index = Math.round((i / kept) * (points.length - 1));
      const p = points[index];
      return { t: Number((t0 + (index / (points.length - 1)) * (ms / 1000)).toFixed(3)), x: Math.round(p.x * 10) / 10, y: Math.round(p.y * 10) / 10 };
    });
  }

  /** Whether the element at (x, y) is the element or inside it, so a closing dialog's backdrop is not clicked. Elements inside iframes are not checked. */
  function reaches(locator, x, y) {
    return locator
      .evaluate(
        (el, [px, py]) => {
          if (el.ownerDocument !== window.top?.document) return true;
          const hit = document.elementFromPoint(px, py);
          return hit !== null && (hit === el || el.contains(hit));
        },
        [x, y],
      )
      .catch(() => true);
  }

  /**
   * Moves the pointer to the middle of the box and clicks, measuring again when the page moved on the
   * way. Waits up to 15 seconds while another element covers the point. `ready` runs with the box
   * just before the click.
   */
  async function press(locator, first, ready) {
    let box = first;
    let path;
    await page.waitForTimeout(250);
    for (let i = 0; i < 3; i++) {
      path = await glide(box.x + box.width / 2, box.y + box.height / 2, Math.min(box.width, box.height));
      await page.waitForTimeout(120);
      const again = await locator.boundingBox();
      if (again === null) break;
      const moved = Math.abs(again.x - box.x) + Math.abs(again.y - box.y) > 3;
      box = again;
      if (!moved) break;
    }
    for (let i = 0; i < 30 && !(await reaches(locator, box.x + box.width / 2, box.y + box.height / 2)); i++) {
      await page.waitForTimeout(500);
      box = await reveal(locator, 15000);
      path = await glide(box.x + box.width / 2, box.y + box.height / 2, Math.min(box.width, box.height));
    }
    if (ready !== undefined) await ready(box);
    const x = box.x + box.width / 2;
    const y = box.y + box.height / 2;
    const t = now();
    await page.evaluate(([a, b]) => window.__svPress?.(a, b), [x, y]).catch(() => undefined);
    await page.mouse.click(x, y, { delay: 70 });
    return { t, box, path };
  }

  const begin = (number, caption, chapter) => ({ step: number, from: now(), caption, ...(chapter ? { chapter } : {}) });

  return {
    page,
    steps,
    now,
    async open(url, caption, { number, chapter } = {}) {
      await page.goto(url, { waitUntil: "load", timeout: 90000 });
      await page.evaluate(([a, b]) => window.__svCursor?.(a, b), [pointer.x, pointer.y]).catch(() => undefined);
      // The page shows from here, so its caption starts here
      const step = { ...begin(number, caption, chapter), kind: "open", url };
      steps.push({ ...step, t: step.from, end: step.from });
    },
    async click(locator, caption, { timeout = 20000, ready, number, chapter } = {}) {
      const step = begin(number, caption, chapter);
      const before = page.url();
      const { t, box, path } = await press(locator, await reveal(locator, timeout), ready);
      const entry = { ...step, kind: "click", t, end: Number((t + 0.3).toFixed(3)), box: round(box), path, navigates: false };
      steps.push(entry);
      // A click that changes the address within 0.8 seconds moves the page: the edit dissolves into the new one
      await page.waitForURL((url) => url.toString() !== before, { timeout: 800, waitUntil: "commit" }).then(
        async () => {
          entry.navigates = true;
          entry.navigatedAt = now();
          // The new page is drawn once its document has been read
          await page
            .waitForLoadState("domcontentloaded", { timeout: 3000 })
            .then(() => (entry.paintedAt = now()))
            .catch(() => undefined);
        },
        () => undefined,
      );
    },
    async fill(locator, text, caption, { clear = false, timeout = 20000, ready, secret = false, number, chapter } = {}) {
      const step = begin(number, caption, chapter);
      const { t, box, path } = await press(locator, await reveal(locator, timeout), ready);
      if (!secret && (await locator.getAttribute("type").catch(() => null)) === "password") {
        throw new Error('types into a password field as plain text; use "env" for the value');
      }
      if (clear) {
        await page.keyboard.press("ControlOrMeta+A");
        await page.keyboard.press("Backspace");
      }
      await page.waitForTimeout(160);
      const keys = [];
      for (const [index, character] of [...text].entries()) {
        keys.push(now());
        await page.keyboard.type(character);
        await page.waitForTimeout(KEY_GAPS[index % KEY_GAPS.length]);
      }
      steps.push({ ...step, kind: "fill", t, end: now(), box: round(box), path, keys });
    },
    async select(locator, value, caption, { timeout = 20000, ready, number, chapter } = {}) {
      const step = begin(number, caption, chapter);
      const box = await reveal(locator, timeout);
      const path = await glide(box.x + box.width / 2, box.y + box.height / 2, Math.min(box.width, box.height));
      if (ready !== undefined) await ready(box);
      const t = now();
      await locator.selectOption(value);
      steps.push({ ...step, kind: "select", t, end: now(), box: round(box), path });
    },
    async key(name, caption, { number, chapter } = {}) {
      const step = begin(number, caption, chapter);
      await page.keyboard.press(name);
      steps.push({ ...step, kind: "key", t: step.from, end: Number((step.from + 0.3).toFixed(3)) });
    },
    async waitFor(caption, until, { number, chapter } = {}) {
      const step = begin(number, caption, chapter);
      await until();
      steps.push({ ...step, kind: "wait", t: step.from, end: now() });
    },
    async hold(sec, caption, { number, chapter } = {}) {
      const step = begin(number, caption, chapter);
      await page.waitForTimeout(sec * 1000);
      steps.push({ ...step, kind: "hold", t: step.from, end: now() });
    },
    /** Waits, without doing anything, until `at` seconds of the recording. */
    async until(at) {
      const left = at - now();
      if (left > 0) await page.waitForTimeout(Math.round(left * 1000));
    },
    /** Saves a picture of the page, with an outline around `box` when given. */
    async frame(path, box) {
      if (box !== undefined) {
        await page
          .evaluate((b) => {
            const mark = document.createElement("div");
            mark.id = "__sv_mark";
            Object.assign(mark.style, {
              position: "fixed", left: `${b.x - 6}px`, top: `${b.y - 6}px`, width: `${b.width + 12}px`, height: `${b.height + 12}px`,
              border: "4px solid #e8590c", borderRadius: "10px", zIndex: "2147483645", pointerEvents: "none",
            });
            document.documentElement.append(mark);
          }, box)
          .catch(() => undefined);
      }
      await page.screenshot({ path }).catch(() => undefined);
      if (box !== undefined) await page.evaluate(() => document.getElementById("__sv_mark")?.remove()).catch(() => undefined);
    },
    /** Closes the recording, moves the kept times to count from its first frame, and returns the recording's path. */
    async stop() {
      if (record) await page.screencast.stop();
      await context.close();
      await browser.close();
      if (!record || firstFrame === undefined) return undefined;
      // Frames drawn before the recording began are placed at the time Playwright began recording (just after `started`), so the shift is never below 0
      const shift = Math.max(0, (firstFrame - started) / 1000);
      const align = (value) => Number(Math.max(0, value - shift).toFixed(3));
      for (const step of steps) {
        for (const key of ["from", "t", "end", "navigatedAt", "paintedAt"]) if (step[key] !== undefined) step[key] = align(step[key]);
        if (step.path !== undefined) step.path = step.path.map((p) => ({ ...p, t: align(p.t) }));
        if (step.keys !== undefined) step.keys = step.keys.map(align);
      }
      return video;
    },
    /** Saves the screen when something failed. */
    screenshot: (path) => page.screenshot({ path }).catch(() => undefined),
    async abort() {
      await context.close().catch(() => undefined);
      await browser.close().catch(() => undefined);
    },
  };
}
