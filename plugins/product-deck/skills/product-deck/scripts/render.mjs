#!/usr/bin/env node
/* Renders the slides of a deck HTML into 1920x1080 PNG files.
   `--only` renders a single slide again after one slide was changed.

   Usage
     node render.mjs --html <deck.html> --out <dir> [--only <slide number, from 1>]

   Playwright is resolved from PLAYWRIGHT_FROM (see load-playwright.mjs). */

import { mkdir } from "node:fs/promises";
import { pathToFileURL } from "node:url";
import { resolve } from "node:path";
import { loadChromium } from "./load-playwright.mjs";

function parseArgs(argv) {
  const values = new Map();
  for (let index = 0; index < argv.length; index += 2) {
    values.set(argv[index], argv[index + 1]);
  }
  return values;
}

const args = parseArgs(process.argv.slice(2));
const htmlPath = args.get("--html");
const outDir = args.get("--out");
const only = args.get("--only");

if (!htmlPath || !outDir) {
  console.error("usage: render.mjs --html <deck.html> --out <dir> [--only <slide number, from 1>]");
  process.exit(1);
}

const chromium = await loadChromium();
await mkdir(outDir, { recursive: true });

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 2 });
await page.goto(pathToFileURL(resolve(htmlPath)).href, { waitUntil: "load", timeout: 60_000 });

/* Rendering before the fonts arrive changes the letter spacing; images are awaited for the same reason. */
await page.evaluate(() => document.fonts.ready);
await page.evaluate(() => Promise.all(
  Array.from(document.images)
    .filter((image) => !image.complete)
    .map((image) => new Promise((done) => { image.onload = done; image.onerror = done; })),
));
await page.waitForTimeout(400);

const slides = await page.locator("section.slide").all();
if (slides.length === 0) {
  console.error("the page has no section.slide");
  await browser.close();
  process.exit(1);
}

let written = 0;
for (const [index, slide] of slides.entries()) {
  const number = index + 1;
  if (only !== undefined && Number(only) !== number) continue;
  const name = `${String(number).padStart(2, "0")}.png`;
  await slide.screenshot({ path: `${outDir}/${name}` });
  written += 1;
}

console.log(`slides=${slides.length} written=${written} out=${outDir}`);
await browser.close();
