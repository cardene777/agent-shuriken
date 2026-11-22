#!/usr/bin/env node
/* Opens one style of the viewer HTML and renders each of its slides at 1920x1080.
   Defects do not show in the reduced overview, so this renders full size for looking at.

   Usage
     node shoot.mjs <viewer HTML> <style name> <output folder> [slide number ...]

   Without slide numbers every slide is rendered; with them, only those slides are rendered again.
   Playwright is resolved from PLAYWRIGHT_FROM (see load-playwright.mjs). */

import { mkdir } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { loadChromium } from "./load-playwright.mjs";

const [htmlArg, tab, outArg, ...want] = process.argv.slice(2);
if (htmlArg === undefined || tab === undefined || outArg === undefined) {
  console.error("usage: node shoot.mjs <viewer HTML> <style name> <output folder> [slide number ...]");
  process.exit(2);
}
const chromium = await loadChromium();
const html = resolve(htmlArg);
const outDir = resolve(outArg);
await mkdir(outDir, { recursive: true });

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
await page.goto(`${pathToFileURL(html).href}#${encodeURIComponent(tab)}`, { waitUntil: "load", timeout: 60_000 });
/* When the name is not found, the viewer keeps showing its first style. Rendering then fills the
   output folder with another style's slides, and a fixed slide looks unfixed. */
const opened = await page.evaluate((name) => {
  const names = [...document.querySelectorAll(".tab")].map((t) => t.textContent);
  const on = document.querySelector(".tab.on")?.textContent ?? "";
  return { names, on, ok: on === name };
}, tab);
if (!opened.ok) {
  console.error(`cannot open the style: ${tab} (the viewer opened ${opened.on})`);
  console.error(`styles: ${opened.names.join(" / ")}`);
  await browser.close();
  process.exit(2);
}
await page.evaluate(() => document.fonts.ready);
await page.evaluate(() => Promise.all(Array.from(document.images)
  .filter((i) => !i.complete).map((i) => new Promise((d) => { i.onload = d; i.onerror = d; }))));
/* The scale is for the overview only; rendering goes back to full size. */
await page.addStyleTag({ content: ".panel.on { display: block !important; } .topbar { display: none !important; }"
  + " .panel.on .stage { width: 1920px !important; height: 1080px !important; aspect-ratio: auto !important; overflow: visible !important; }"
  + " .panel.on .stage > .slide { transform: none !important; }" });
await page.waitForTimeout(500);

const slides = await page.locator(".panel.on section.slide").all();
let written = 0;
for (const [index, slide] of slides.entries()) {
  const number = index + 1;
  if (want.length > 0 && !want.includes(String(number))) continue;
  await slide.screenshot({ path: `${outDir}/${String(number).padStart(2, "0")}.png` });
  written += 1;
}
console.log(`style=${tab} slides=${slides.length} rendered=${written}`);
await browser.close();
