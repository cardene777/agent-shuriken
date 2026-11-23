// Draws each moment of one run of a motion-diagram page into PNG frames, and the finished state into
// end.png, for export.sh to join with ffmpeg.
//
// Usage: node export.mjs <page.html> <frames folder> <browser> <width> <fps> <playwright-core index.js>
//
// The page opens with #export, so it does not run on its own; window.__md.prepare() plans the run and
// window.__md.seek(t) draws the moment t seconds into it. Only the picture (the page's main element)
// is captured. The browser is started without a network connection to anything but the local file.
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
import path from 'node:path';

const [page, frames, browserPath, widthText, fpsText, playwrightIndex] = process.argv.slice(2);
if (!playwrightIndex) {
  console.error('motion-diagram: export.mjs needs the page, the frames folder, the browser, the width, the fps, and playwright-core');
  process.exit(2);
}
const require = createRequire(import.meta.url);
const { chromium } = require(playwrightIndex);
const width = Number(widthText);
const fps = Number(fpsText);

const browser = await chromium.launch({ executablePath: browserPath, headless: true });
try {
  const context = await browser.newContext({ viewport: { width, height: 900 }, deviceScaleFactor: 2, reducedMotion: 'no-preference' });
  await context.route(url => !url.toString().startsWith('file:'), route => route.abort());
  const tab = await context.newPage();
  await tab.goto(pathToFileURL(page).href + '#export');
  const total = await tab.evaluate(() => window.__md.prepare());
  const height = await tab.evaluate(() => Math.ceil(document.querySelector('[data-md]').getBoundingClientRect().height));
  await tab.setViewportSize({ width, height: Math.max(height, 200) });
  await tab.evaluate(() => window.__md.prepare());
  const main = tab.locator('[data-md]');
  const count = Math.ceil(total * fps) + 1;
  for (let i = 0; i < count; i++) {
    await tab.evaluate(t => window.__md.seek(t), i / fps);
    await main.screenshot({ path: path.join(frames, 'frame-' + String(i).padStart(5, '0') + '.png'), animations: 'disabled' });
  }
  for (let i = 0; i < fps; i++) {
    await main.screenshot({ path: path.join(frames, 'frame-' + String(count + i).padStart(5, '0') + '.png'), animations: 'disabled' });
  }
  await tab.evaluate(t => window.__md.seek(t), total);
  await main.screenshot({ path: path.join(frames, 'end.png'), animations: 'disabled' });
} finally {
  await browser.close();
}
