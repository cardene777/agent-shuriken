/**
 * Draws captions as see-through pictures the size of the caption band.
 *
 * The text is drawn by Playwright's Chromium, because many ffmpeg builds cannot draw text, and a
 * browser lays out every script and wraps long lines on its own.
 *
 * A caption goes at the bottom of the screen. When it would cover something it must avoid (`avoid`,
 * the boxes of what is clicked or typed into), it moves to the top edge; when the top covers one too,
 * it stays at the bottom.
 */
import { join } from "node:path";

import { BAND_Y, HEIGHT, WIDTH } from "./media.mjs";
import { playwright } from "./runtime.mjs";

/** How opaque the caption's background is. The screen behind shows through. */
export const BACKGROUND_ALPHA = 0.6;
/** Space kept between a caption and a box it avoids, wide enough for the click ring. */
const CLEARANCE = 24;
const FONTS = 'system-ui,-apple-system,"Segoe UI","Hiragino Sans","Hiragino Kaku Gothic ProN","Noto Sans CJK JP","Noto Sans JP",sans-serif';

/** The two frames captions are drawn for: the 16:9 videos and the vertical video. */
export const FRAMES = {
  wide: { width: WIDTH, height: HEIGHT, band: HEIGHT - BAND_Y, font: 32, maxWidth: 1500, bottom: 24 },
  vertical: { width: 1080, height: 1920, band: 420, font: 46, maxWidth: 960, bottom: 120 },
};

const escape = (text) => text.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);

function page(text, place, frame) {
  const align = place === "top" ? "flex-start" : "flex-end";
  const margin = place === "top" ? "6px 0 0" : `0 0 ${frame.bottom}px`;
  return `<!doctype html><html><head><meta charset="utf-8"><style>
html,body{margin:0;background:transparent}
body{width:${frame.width}px;height:${frame.band}px;display:flex;align-items:${align};justify-content:center}
p{margin:${margin};max-width:${frame.maxWidth}px;padding:8px 28px;border-radius:12px;background:rgba(16,42,67,${BACKGROUND_ALPHA});
border:1px solid rgba(255,255,255,.18);color:#fff;text-shadow:0 1px 3px rgba(0,0,0,.55);
font:600 ${frame.font}px/1.4 ${FONTS};text-align:center;letter-spacing:.02em}
</style></head><body><p>${escape(text)}</p></body></html>`;
}

const overlaps = (a, b) =>
  a.x < b.x + b.width + CLEARANCE && b.x - CLEARANCE < a.x + a.width && a.y < b.y + b.height + CLEARANCE && b.y - CLEARANCE < a.y + a.height;

async function draw(tab, text, place, frame) {
  await tab.setContent(page(text, place, frame), { waitUntil: "load" });
  const rect = await tab.locator("p").boundingBox();
  const y = place === "top" ? 0 : frame.height - frame.band;
  return { y, box: { x: rect.x, y: rect.y + y, width: rect.width, height: rect.height } };
}

/**
 * Draws a picture for each caption and returns the captions with `file` (the picture), `y` (where its
 * top goes), `place` (`top` or `bottom`), and `box` (the caption's box on the screen) added.
 * `prefix` starts the picture names, to keep two sets apart in one folder.
 */
export async function captionImages(cues, dir, { prefix = "caption", frame = FRAMES.wide } = {}) {
  if (cues.length === 0) return [];
  const { chromium } = playwright();
  const browser = await chromium.launch();
  try {
    const tab = await browser.newPage({ viewport: { width: frame.width, height: frame.band }, deviceScaleFactor: 1 });
    const out = [];
    for (const [index, cue] of cues.entries()) {
      const avoid = cue.avoid ?? [];
      let place = "bottom";
      let drawn = await draw(tab, cue.text, place, frame);
      if (avoid.some((box) => overlaps(drawn.box, box))) {
        const top = await draw(tab, cue.text, "top", frame);
        if (avoid.some((box) => overlaps(top.box, box))) drawn = await draw(tab, cue.text, place, frame);
        else {
          place = "top";
          drawn = top;
        }
      }
      const file = join(dir, `${prefix}-${String(index + 1).padStart(3, "0")}.png`);
      await tab.screenshot({ path: file, omitBackground: true });
      out.push({ ...cue, file, place, y: drawn.y, box: drawn.box });
    }
    return out;
  } finally {
    await browser.close();
  }
}
