#!/usr/bin/env node
/* Measures whether icons fit their containers.

   Judging by eye enlarges the icon and the container by the same ratio, so the ratio never changes.
   This runs the formula of `references/layout-rules.md`, "Enlarge only the container of an icon".

   Usage
     node glyph-fit.mjs <icons JSON> [--size <side of the coordinate system>]
       How far each icon reaches from its center. The default coordinate system is 24.

     node glyph-fit.mjs <icons JSON> --diamond <half width>x<half height> --glyph <size> [--stroke <width>]
       The room left when the icon sits on the top face of an isometric box. Aim for 0.73; above 0.95 it touches the edge.

     node glyph-fit.mjs <icons JSON> --circle <radius> --glyph <size>
     node glyph-fit.mjs <icons JSON> --square <side> --glyph <size>

   The icons JSON is `{ "key": "<path .../>", ... }`, exported from the code that builds the slides.
   Playwright is resolved from PLAYWRIGHT_FROM (see load-playwright.mjs). */

import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { loadChromium } from "./load-playwright.mjs";

const argv = process.argv.slice(2);
const flag = (name) => {
  const at = argv.indexOf(name);
  return at === -1 ? undefined : argv[at + 1];
};
const jsonPath = argv.find((a, i) => !a.startsWith("--") && !argv[i - 1]?.startsWith("--"));
if (jsonPath === undefined) {
  console.error("usage: node glyph-fit.mjs <icons JSON> [--size N]"
    + " [--diamond WxH | --circle R | --square S] [--glyph N] [--stroke N]");
  process.exit(2);
}

const size = Number(flag("--size") ?? 24);
const glyphs = JSON.parse(await readFile(resolve(jsonPath), "utf8"));

const chromium = await loadChromium();
const browser = await chromium.launch();
const page = await browser.newPage();
await page.setContent(`<svg id="s" width="${size * 10}" height="${size * 10}" viewBox="0 0 ${size} ${size}"></svg>`);

const rows = [];
for (const [name, body] of Object.entries(glyphs)) {
  const bb = await page.evaluate((html) => {
    const s = document.getElementById("s");
    s.innerHTML = html;
    const b = s.getBBox();
    return { x: b.x, y: b.y, w: b.width, h: b.height };
  }, body);
  const c = size / 2;
  /* How far the icon reaches up, down, left, and right from the center. For a diamond or a circle,
     the farthest point is the one that touches the edge. */
  const half = Math.max(Math.abs(bb.x - c), Math.abs(bb.x + bb.w - c),
    Math.abs(bb.y - c), Math.abs(bb.y + bb.h - c));
  rows.push({ name, half, ratio: half / c });
}
await browser.close();

rows.sort((a, b) => b.half - a.half);
for (const r of rows) {
  console.log(`  ${r.name.padEnd(10)} reaches ${r.half.toFixed(2).padStart(6)} from the center (${Math.round(r.ratio * 100)}% of the box)`);
}
const worst = rows[0];
console.log(`\nfarthest reaching icon = ${worst.name}, ${Math.round(worst.ratio * 100)}% of the box`);
console.log(`radius reached when placed = ${(worst.ratio / 2).toFixed(3)} x icon size + half the stroke`);

/* With a container, print the room too. */
const glyphSize = Number(flag("--glyph") ?? NaN);
const stroke = Number(flag("--stroke") ?? 0);
const shapes = [
  ["--diamond", (v) => {
    const [a, b] = v.split("x").map(Number);
    return { what: `diamond, half width ${a}, half height ${b}`, allow: (a * b) / (a + b) };
  }],
  ["--circle", (v) => ({ what: `circle, radius ${v}`, allow: Number(v) / Math.SQRT2 })],
  ["--square", (v) => ({ what: `square, side ${v}`, allow: Number(v) / 2 })],
];
for (const [name, make] of shapes) {
  const v = flag(name);
  if (v === undefined) continue;
  if (!Number.isFinite(glyphSize)) {
    console.error(`\n${name} also needs --glyph <icon size>`);
    process.exit(2);
  }
  const { what, allow } = make(v);
  const reach = (worst.ratio / 2) * glyphSize + stroke / 2;
  const room = reach / allow;
  const verdict = room > 0.95 ? "touches the edge" : room > 0.8 ? "a little tight" : "good";
  console.log(`\ncontainer = ${what}`);
  console.log(`  allowed radius  ${allow.toFixed(2)}`);
  console.log(`  reached radius  ${reach.toFixed(2)}  (icon ${glyphSize}, stroke ${stroke})`);
  console.log(`  room            ${room.toFixed(2)}  ${verdict} (aim for 0.73)`);
  if (room > 0.8) {
    /* The icon stays as it is; the container is enlarged. */
    const need = reach / 0.73;
    console.log(`  to reach 0.73, enlarge the allowed radius to ${need.toFixed(1)}`);
    if (name === "--diamond") {
      const [a, b] = v.split("x").map(Number);
      const k = need / allow;
      console.log(`  for a diamond: half width ${Math.ceil(a * k)}, half height ${Math.ceil(b * k)} (${k.toFixed(2)} times the current size)`);
    }
  }
}
