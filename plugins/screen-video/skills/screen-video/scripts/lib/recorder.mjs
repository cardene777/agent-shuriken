/**
 * Drives a page with Playwright, records the screen, and keeps the second at which each action happened.
 *
 * | Method | Record kept (`kind`) | What it does |
 * |---|---|---|
 * | `open` | `open` | Opens a page and keeps its address |
 * | `click` | `click` | Moves the pointer and clicks. Keeps the box clicked and whether the page moved (`navigates`) |
 * | `fill` | `fill` | Clicks a field and types. Keeps the field's box and when the typing ended. Never keeps what was typed |
 * | `select` | `select` | Chooses an option in a select field |
 * | `key` | `key` | Presses a key |
 * | `waitFor` | `wait` | Waits for a condition. Keeps when the wait began and ended |
 * | `hold` | `hold`, only with a caption | Stays still so the screen can be seen |
 *
 * The browser does not draw the pointer, so an arrow is drawn on top of the page and moved.
 * Times count from the first frame of the recording: the recording's zero is when the first frame
 * arrives, which differs from when the page or the recording was started by up to a few tenths of a second.
 * With `record: false` nothing is recorded, for rehearsals.
 */
import { join } from "node:path";

import { HEIGHT, WIDTH } from "./media.mjs";
import { playwright } from "./runtime.mjs";

/** Draws the pointer and the ring shown on a click. Not drawn inside iframes. */
function installCursor() {
  if (window.top !== window) return;
  const install = () => {
    if (document.getElementById("__sv_cursor") !== null) return;
    const cursor = document.createElement("div");
    cursor.id = "__sv_cursor";
    cursor.innerHTML =
      '<svg width="30" height="30" viewBox="0 0 30 30"><path d="M5 3 L5 24 L10.6 18.6 L14.4 27 L18 25.4 L14.3 17.3 L22 17.3 Z" fill="#102A43" stroke="#fff" stroke-width="1.8" stroke-linejoin="round"/></svg>';
    Object.assign(cursor.style, { position: "fixed", left: "0", top: "0", zIndex: "2147483647", pointerEvents: "none", transform: "translate(960px,540px)" });
    const ring = document.createElement("div");
    ring.id = "__sv_ring";
    Object.assign(ring.style, {
      position: "fixed", left: "-24px", top: "-24px", width: "48px", height: "48px", borderRadius: "50%",
      border: "3px solid rgba(35,133,104,.95)", zIndex: "2147483646", pointerEvents: "none", opacity: "0",
    });
    document.documentElement.append(ring, cursor);
  };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", install);
  else install();
  window.__svCursor = (x, y) => {
    install();
    document.getElementById("__sv_cursor").style.transform = `translate(${x}px,${y}px)`;
  };
  window.__svPulse = (x, y) => {
    install();
    // Position and size move in one transform: scaling separately would shrink the translate too
    document.getElementById("__sv_ring").animate(
      [
        { opacity: 1, transform: `translate(${x}px,${y}px) scale(0.4)` },
        { opacity: 0, transform: `translate(${x}px,${y}px) scale(1.5)` },
      ],
      { duration: 650, easing: "ease-out" },
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

export async function startRecording({ record = true, videoDir, credentials, storageState, masks = [] }) {
  const { chromium } = playwright();
  const browser = await chromium.launch();
  const context = await browser.newContext({
    ...(credentials === undefined ? {} : { httpCredentials: credentials }),
    ...(storageState === undefined ? {} : { storageState }),
    viewport: { width: WIDTH, height: HEIGHT },
    deviceScaleFactor: 1,
  });
  await context.addInitScript(installCursor);
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
    const safe = (b) => b !== null && b.y >= 90 && b.y + b.height <= HEIGHT - 220;
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

  /** Moves the drawn pointer smoothly from where it is to (x, y). */
  async function glide(x, y) {
    const from = pointer;
    const count = 16;
    for (let i = 1; i <= count; i++) {
      const s = i / count;
      const e = s * s * (3 - 2 * s);
      const px = from.x + (x - from.x) * e;
      const py = from.y + (y - from.y) * e;
      await page.mouse.move(px, py);
      await page.evaluate(([a, b]) => window.__svCursor?.(a, b), [px, py]).catch(() => undefined);
      await page.waitForTimeout(22);
    }
    pointer = { x, y };
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
    await page.waitForTimeout(350);
    for (let i = 0; i < 3; i++) {
      await glide(box.x + box.width / 2, box.y + box.height / 2);
      await page.waitForTimeout(150);
      const again = await locator.boundingBox();
      if (again === null) break;
      const moved = Math.abs(again.x - box.x) + Math.abs(again.y - box.y) > 3;
      box = again;
      if (!moved) break;
    }
    for (let i = 0; i < 30 && !(await reaches(locator, box.x + box.width / 2, box.y + box.height / 2)); i++) {
      await page.waitForTimeout(500);
      box = await reveal(locator, 15000);
      await glide(box.x + box.width / 2, box.y + box.height / 2);
    }
    if (ready !== undefined) await ready(box);
    const x = box.x + box.width / 2;
    const y = box.y + box.height / 2;
    const t = now();
    await page.evaluate(([a, b]) => window.__svPulse?.(a, b), [x, y]).catch(() => undefined);
    await page.mouse.click(x, y);
    return { t, box };
  }

  return {
    page,
    steps,
    async open(url, caption) {
      steps.push({ kind: "open", t: now(), end: now(), url, caption });
      await page.goto(url, { waitUntil: "load", timeout: 90000 });
      await page.evaluate(([a, b]) => window.__svCursor?.(a, b), [pointer.x, pointer.y]).catch(() => undefined);
    },
    async click(locator, caption, { timeout = 20000, ready } = {}) {
      const before = page.url();
      const { t, box } = await press(locator, await reveal(locator, timeout), ready);
      const step = { kind: "click", t, end: Number((t + 0.3).toFixed(3)), caption, box: round(box), navigates: false };
      steps.push(step);
      // A click that changes the address within 0.8 seconds is kept as one that moves the page (the edit leaves it sooner)
      await page.waitForURL((url) => url.toString() !== before, { timeout: 800, waitUntil: "commit" }).then(
        () => (step.navigates = true),
        () => undefined,
      );
    },
    async fill(locator, text, caption, { clear = false, timeout = 20000, ready, secret = false } = {}) {
      const { t, box } = await press(locator, await reveal(locator, timeout), ready);
      if (!secret && (await locator.getAttribute("type").catch(() => null)) === "password") {
        throw new Error('types into a password field as plain text; use "env" for the value');
      }
      if (clear) {
        await page.keyboard.press("ControlOrMeta+A");
        await page.keyboard.press("Backspace");
      }
      await page.keyboard.type(text, { delay: 55 });
      steps.push({ kind: "fill", t, end: now(), caption, box: round(box) });
    },
    async select(locator, value, caption, { timeout = 20000, ready } = {}) {
      const box = await reveal(locator, timeout);
      if (ready !== undefined) await ready(box);
      const t = now();
      await locator.selectOption(value);
      steps.push({ kind: "select", t, end: now(), caption, box: round(box) });
    },
    async key(name, caption) {
      const t = now();
      await page.keyboard.press(name);
      steps.push({ kind: "key", t, end: Number((t + 0.3).toFixed(3)), caption });
    },
    async waitFor(caption, until) {
      const t = now();
      await until();
      steps.push({ kind: "wait", t, end: now(), caption });
    },
    async hold(sec, caption) {
      const t = now();
      await page.waitForTimeout(sec * 1000);
      if (caption !== undefined && caption !== "") steps.push({ kind: "hold", t, end: now(), caption });
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
        step.t = align(step.t);
        step.end = align(step.end);
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
