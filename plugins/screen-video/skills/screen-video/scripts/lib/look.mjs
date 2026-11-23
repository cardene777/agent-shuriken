/**
 * Draws the pictures the edited videos are built from, in the flow's theme: the frame around the
 * screen, the captions, the title, chapter, and end cards, the fast-forward mark, and the pointer,
 * press ring, and touch mark drawn over an app's recording.
 *
 * Every picture is drawn by Playwright's Chromium, because many ffmpeg builds cannot draw text, and
 * a browser lays out every script and wraps long lines on its own. Captions and cards are drawn in a
 * page whose `lang` is the flow's language, and their lines are evened out (`text-wrap: balance`) and
 * broken between phrases (`word-break: auto-phrase`, which Chromium applies to Japanese), so a long
 * title never leaves one or two characters on its last line. All themes share one layout
 * (`LAYOUTS`); a theme changes only colours, fonts, and corners.
 *
 * | Layout | Size | Where the screen sits | Where captions go |
 * |---|---|---|---|
 * | `wide` | 1920x1080 | 1568x882, 40px from the top | the band below the screen |
 * | `tall` | 1080x1920 | 960x1200, 250px from the top | below the screen |
 * | `phoneLayout(screen)` | 1080x1920 | a phone's whole screen at the full height, in the middle | over the screen |
 */
import { renameSync } from "node:fs";
import { join } from "node:path";

import { POINTER_SVG } from "./recorder.mjs";
import { rgba } from "./theme.mjs";
import { playwright } from "./runtime.mjs";

export const LAYOUTS = {
  wide: { width: 1920, height: 1080, window: { x: 176, y: 40, width: 1568, height: 882 }, captions: { top: 922, height: 158, maxWidth: 1500, scale: 1 } },
  tall: { width: 1080, height: 1920, window: { x: 60, y: 250, width: 960, height: 1200 }, captions: { top: 1470, height: 300, maxWidth: 960, scale: 1.3 } },
};
/**
 * The vertical layout of a phone's recording: the phone's screen (`screen`, its place on the
 * 1920x1080 recording) fills the video's height in its middle, uncut, with captions laid over it.
 */
export function phoneLayout(screen) {
  const width = Math.round((LAYOUTS.tall.height * screen.width) / screen.height / 2) * 2;
  return { ...LAYOUTS.tall, window: { x: Math.round((LAYOUTS.tall.width - width) / 2), y: 0, width, height: LAYOUTS.tall.height } };
}
/** Frames, 30 a second, of the ring a macOS press shows (as a browser press does) and of a phone's touch mark. */
const RING = { size: 132, frames: 18 };
const TOUCH = { size: 72, frames: 14 };
/** Captions laid over the recording itself (the captioned video): at the bottom, or at the top when they would cover the action. */
const OVER = { width: 1920, height: 1080, maxWidth: 1500, margin: 24, scale: 1 };
const CLEARANCE = 24;

const escape = (text) => String(text).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
/** Lines of about the same length, broken between phrases where the language allows. */
const EVEN_LINES = "text-wrap:balance;word-break:auto-phrase";

/** The page a caption is drawn from, its text in a `<p>`. */
export function captionPage(text, look, maxWidth, scale, language = "en") {
  const c = look.caption;
  return `<!doctype html><html lang="${escape(language)}"><head><meta charset="utf-8"><style>
html,body{margin:0;background:transparent}
p{display:inline-block;margin:0;max-width:${maxWidth}px;box-sizing:border-box;padding:${Math.round(12 * scale)}px ${Math.round(30 * scale)}px;${EVEN_LINES};
border-radius:${c.radius}px;background:${rgba(c.band, c.opacity)};color:${c.color};
font:${c.weight} ${Math.round(c.size * scale)}px/1.32 ${c.font};text-align:center;letter-spacing:.01em}
</style></head><body><p>${escape(text)}</p></body></html>`;
}

/** The page a title, chapter, or end card is drawn from, its text in an `<h1>`. */
export function cardPage(card, look, size, number, language = "en") {
  const k = look.card;
  const tall = size.height > size.width;
  const unit = tall ? 1.15 : 1;
  const big = card.kind === "chapter" ? 64 : card.kind === "end" ? 68 : 76;
  const lines = [];
  if (card.kind === "chapter") lines.push(`<div class="kicker">${String(number).padStart(2, "0")}</div>`);
  else lines.push('<div class="bar"></div>');
  lines.push(`<h1>${escape(card.text)}</h1>`);
  if (card.url) lines.push(`<div class="url">${escape(card.url)}</div>`);
  if (card.note) lines.push(`<div class="note">${escape(card.note)}</div>`);
  const credit = card.credit ? `<div class="credit">${escape(card.credit)}</div>` : "";
  return `<!doctype html><html lang="${escape(language)}"><head><meta charset="utf-8"><style>
html,body{margin:0;width:${size.width}px;height:${size.height}px;background:${k.background};overflow:hidden}
body{display:flex;flex-direction:column;align-items:center;justify-content:center;font-family:${k.font};color:${k.color};text-align:center;${EVEN_LINES}}
main{max-width:${Math.round(size.width * 0.8)}px;display:flex;flex-direction:column;align-items:center;gap:${Math.round(22 * unit)}px}
.bar{width:${Math.round(72 * unit)}px;height:${Math.round(6 * unit)}px;border-radius:3px;background:${k.accent}}
.kicker{font-weight:700;font-size:${Math.round(30 * unit)}px;letter-spacing:.2em;color:${k.accent}}
h1{margin:0;font-weight:700;font-size:${Math.round(big * unit)}px;line-height:1.2;letter-spacing:-.01em}
.url{font-size:${Math.round(34 * unit)}px;font-weight:600;color:${k.accent}}
.note{font-size:${Math.round(28 * unit)}px;color:${k.muted}}
.credit{position:absolute;left:0;right:0;bottom:${Math.round(56 * unit)}px;font-size:${Math.round(24 * unit)}px;color:${k.muted}}
</style></head><body><main>${lines.join("")}</main>${credit}</body></html>`;
}

function framePage(look, size) {
  const w = size.window;
  const [from, to] = Array.isArray(look.background) ? look.background : [look.background, look.background];
  const r = look.window.radius;
  const s = look.window.shadow;
  return `<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;background:transparent}svg{display:block}</style></head><body>
<svg xmlns="http://www.w3.org/2000/svg" width="${size.width}" height="${size.height}">
<defs>
<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${from}"/><stop offset="1" stop-color="${to}"/></linearGradient>
<filter id="near" x="-10%" y="-10%" width="120%" height="120%"><feGaussianBlur stdDeviation="8"/></filter>
<filter id="far" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="28"/></filter>
<mask id="hole"><rect width="${size.width}" height="${size.height}" fill="#fff"/><rect x="${w.x}" y="${w.y}" width="${w.width}" height="${w.height}" rx="${r}" fill="#000"/></mask>
</defs>
<g mask="url(#hole)">
<rect width="${size.width}" height="${size.height}" fill="url(#bg)"/>
<rect x="${w.x}" y="${w.y + 4}" width="${w.width}" height="${w.height}" rx="${r}" fill="#000" opacity="${(s * 0.8).toFixed(2)}" filter="url(#near)"/>
<rect x="${w.x}" y="${w.y + 16}" width="${w.width}" height="${w.height}" rx="${r}" fill="#000" opacity="${(s * 0.8).toFixed(2)}" filter="url(#far)"/>
<rect x="${w.x - 0.75}" y="${w.y - 0.75}" width="${w.width + 1.5}" height="${w.height + 1.5}" rx="${r + 0.75}" fill="none" stroke="${look.window.border}" stroke-opacity="${look.window.borderOpacity}" stroke-width="1.5"/>
</g>
</svg></body></html>`;
}

function markPage(speed, look) {
  return `<!doctype html><html><head><meta charset="utf-8"><style>
html,body{margin:0;background:transparent}
.mark{display:inline-grid;grid-template-columns:56px 16px 56px;align-items:center;height:52px;padding:0 11px;border-radius:26px;background:${look.accent};color:${look.card.background};font:700 24px/1 ${look.card.font}}
.mark svg{justify-self:end}
.mark b{justify-self:start}
</style></head><body><div class="mark"><svg width="34" height="22" viewBox="0 0 34 22"><path d="M2 2 L15 11 L2 20 Z M17 2 L30 11 L17 20 Z" fill="currentColor"/></svg><span></span><b>${speed}×</b></div></body></html>`;
}

const overlaps = (a, b) =>
  a.x < b.x + b.width + CLEARANCE && b.x - CLEARANCE < a.x + a.width && a.y < b.y + b.height + CLEARANCE && b.y - CLEARANCE < a.y + a.height;

/** Opens one browser for all the pictures of a run, whose text is in `language`. Close it with `close()`. */
export async function openDrawer(look, dir, language = "en") {
  const { chromium } = playwright();
  const browser = await chromium.launch();
  const tab = await browser.newPage({ viewport: { width: 1920, height: 1920 }, deviceScaleFactor: 1 });
  let count = 0;
  const name = (prefix) => join(dir, `${prefix}-${String(++count).padStart(3, "0")}.png`);

  /** Draws `html` and saves the element `selector` with a see-through background. Returns its file and size. */
  async function shoot(html, selector, prefix, viewport) {
    await tab.setViewportSize(viewport);
    await tab.setContent(html, { waitUntil: "load" });
    const element = tab.locator(selector);
    const box = await element.boundingBox();
    const file = name(prefix);
    await element.screenshot({ path: file, omitBackground: true });
    return { file, width: Math.round(box.width), height: Math.round(box.height) };
  }

  return {
    /** The background, shadow, and edge around the screen, with a see-through hole where the screen goes. */
    async frame(layout) {
      return (await shoot(framePage(look, layout), "svg", "frame", { width: layout.width, height: layout.height })).file;
    },
    /** A caption below the screen. Returns its file and its box in the video. */
    async caption(text, layout) {
      const area = layout.captions;
      const shot = await shoot(captionPage(text, look, area.maxWidth, area.scale, language), "p", "caption", { width: layout.width, height: Math.max(200, area.height * 2) });
      const x = Math.round((layout.width - shot.width) / 2);
      const y = Math.round(area.top + Math.max(0, (area.height - shot.height) / 2));
      return { file: shot.file, box: { x, y, width: shot.width, height: shot.height } };
    },
    /** A caption laid over the recording: at the bottom, or at the top when the bottom would cover a box in `avoid`. */
    async over(text, avoid = []) {
      const shot = await shoot(captionPage(text, look, OVER.maxWidth, OVER.scale, language), "p", "over", { width: OVER.width, height: 400 });
      const x = Math.round((OVER.width - shot.width) / 2);
      const bottom = { x, y: OVER.height - OVER.margin - shot.height, width: shot.width, height: shot.height };
      const top = { ...bottom, y: OVER.margin };
      const box = avoid.some((b) => overlaps(bottom, b)) && !avoid.some((b) => overlaps(top, b)) ? top : bottom;
      return { file: shot.file, box };
    },
    /** A card filling the whole video. `number` is the chapter's number. */
    async card(card, layout, number) {
      return (await shoot(cardPage(card, look, layout, number, language), "body", "card", { width: layout.width, height: layout.height })).file;
    },
    /**
     * The pictures of an app's presses: the browser's pointer (`arrow`), the frames of its press
     * `ring`, which grows and fades over 0.6 seconds, and the frames and the `still` of a phone's
     * `touch` mark, which shows for 0.45 seconds.
     */
    async presses() {
      const fill = rgba(look.accent, 0.36);
      const line = rgba(look.accent, 0.95);
      const page = (size, body) => `<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;background:transparent}</style></head><body><svg id="m" xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">${body}</svg></body></html>`;
      const circle = (size, r, opacity) => `<circle cx="${size / 2}" cy="${size / 2}" r="${(r + 1.5).toFixed(2)}" fill="${fill}" stroke="${line}" stroke-width="3" opacity="${opacity.toFixed(3)}"/>`;
      const arrow = (await shoot(`<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;background:transparent}</style></head><body>${POINTER_SVG.replace("<svg ", '<svg id="m" ')}</body></html>`, "#m", "arrow", { width: 200, height: 200 })).file;
      const series = async (prefix, spec, shape) => {
        for (let k = 0; k < spec.frames; k++) {
          const shot = await shoot(page(spec.size, shape(k / (spec.frames - 1))), "#m", "unused", { width: 200, height: 200 });
          renameSync(shot.file, join(dir, `${prefix}-${String(k + 1).padStart(2, "0")}.png`));
        }
        return { pattern: join(dir, `${prefix}-%02d.png`), size: spec.size };
      };
      // As the browser's ring: strong and growing in the first half, fading in the second
      const ring = await series("ring", RING, (u) => {
        const v = u <= 0.5 ? u / 0.5 : (u - 0.5) / 0.5;
        const e = u <= 0.5 ? 1 - (1 - v) ** 3 : v * v;
        const scale = u <= 0.5 ? 0.5 + 0.35 * e : 0.85 + 0.15 * e;
        const opacity = u <= 0.5 ? 1 - 0.1 * e : 0.9 - 0.9 * e;
        return circle(RING.size, 60 * scale, opacity);
      });
      const touchAt = (u) => circle(TOUCH.size, 30 * (u < 0.15 ? 0.7 + 2 * u : 1), u > 0.65 ? Math.max(0, (1 - u) / 0.35) : 1);
      const touch = await series("touch", TOUCH, touchAt);
      const still = (await shoot(page(TOUCH.size, touchAt(0.3)), "#m", "touch-still", { width: 200, height: 200 })).file;
      return { arrow, ring, touch: { ...touch, still } };
    },
    /** The fast-forward mark, at the top right of the screen. */
    async mark(speed, layout) {
      const shot = await shoot(markPage(speed, look), ".mark", "mark", { width: 400, height: 200 });
      const w = layout.window;
      return { file: shot.file, box: { x: w.x + w.width - 28 - shot.width, y: w.y + 28, width: shot.width, height: shot.height } };
    },
    close: () => browser.close(),
  };
}
