#!/usr/bin/env node
/* Checks the rendered slides by machine, because looking misses defects.

   Usage
     node audit.mjs <viewer HTML> <style name> [style name ...] [--report <path>] [--words <path>]

   Pass each style name exactly as the viewer's tab shows it.
   Exits 1 when any slide is flagged; fix and run again until none is.
   Exits 2 when a check counted nothing, because then it looked at nothing.

   The checks follow the sections of `references/layout-rules.md`. When a section is added,
   add a check here for whatever a machine can see.
   Playwright is resolved from PLAYWRIGHT_FROM (see load-playwright.mjs). */

import { readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { loadChromium } from "./load-playwright.mjs";

const args = process.argv.slice(2);
/* Write the details to a file only when `--report <path>` is passed, so the folder it runs in stays clean. */
const reportAt = args.indexOf("--report");
const reportPath = reportAt === -1 ? undefined : resolve(args[reportAt + 1] ?? "audit-report.json");
let rest = reportAt === -1 ? args : [...args.slice(0, reportAt), ...args.slice(reportAt + 2)];
/* The words that must not appear on a slide. They differ per deck, so they can be replaced. */
const wordsAt = rest.indexOf("--words");
const here = dirname(fileURLToPath(import.meta.url));
const wordsPath = wordsAt === -1
  ? resolve(here, "../references/banned-words.txt")
  : resolve(rest[wordsAt + 1] ?? "");
if (wordsAt !== -1) rest = [...rest.slice(0, wordsAt), ...rest.slice(wordsAt + 2)];
const banned = await readFile(wordsPath, "utf8")
  .then((t) => t.split("\n").map((l) => l.replace(/#.*$/, "").trim()).filter((l) => l !== ""))
  /* Without a list only the word check is skipped; the other checks run. */
  .catch(() => []);
const [htmlArg, ...tabs] = rest;
if (htmlArg === undefined || tabs.length === 0) {
  console.error("usage: node audit.mjs <viewer HTML> <style name> [style name ...]"
    + " [--report <path>] [--words <path>]");
  process.exit(2);
}
const html = resolve(htmlArg);

/* The limits. Each copies a rule of `references/layout-rules.md`. */
const LIMITS = {
  /* Below this share of the height used, the slide is thin. */
  usedHeight: Number(process.env.AUDIT_MIN_USED_HEIGHT ?? 55),
  /* On a 1920x1080 slide, text smaller than this cannot be read. */
  fontSize: Number(process.env.AUDIT_MIN_FONT_SIZE ?? 22),
  /* A screenshot smaller than this share of the slide does not say what screen it is.
     A tall cutout does not grow in width, so the larger of width and height counts. */
  shotSize: Number(process.env.AUDIT_MIN_SHOT_SIZE ?? 40),
  /* How many source pixels a screenshot has per pixel of its size on the slide. Below 1 it is
     stretched and its text blurs; 1.5 is the floor for zooming and printing (cutting from a 2x
     source dropped it to 0.85). */
  shotDensity: Number(process.env.AUDIT_MIN_SHOT_DENSITY ?? 1.5),
  /* How much of the bottom margin text may take. A little is part of the design; beyond half,
     the text looks stuck to the bottom edge (a slide that took 59px of a 96px margin was called cramped). */
  bottomBite: Number(process.env.AUDIT_MAX_BOTTOM_BITE ?? 0.5),
  /* Text boxes overlapping by more than this many pixels in both directions overlap.
     Rounding of line heights makes a few pixels common, and those pass. */
  spill: Number(process.env.AUDIT_MAX_SPILL ?? 4),
};

/* Character classes of Japanese text, written as code points so that this file stays in English.
   KANA is katakana and the long vowel mark; JP adds hiragana, kanji, the iteration mark, and the
   comma, period, and corner brackets; JP_HEAD is JP without the comma and period. */
const KANA = "[\\u30A1-\\u30F4\\u30FC]";
const JP = "[\\u3041-\\u3093\\u30A1-\\u30F6\\u4E00-\\u9FA5\\u3005\\u30FC\\u3001\\u3002\\u300C\\u300D]";
const JP_HEAD = "[\\u3041-\\u3093\\u30A1-\\u30F6\\u4E00-\\u9FA5\\u3005\\u30FC\\u300C\\u300D]";
const PATTERNS = { KANA, JP, JP_HEAD };

const chromium = await loadChromium();
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
const out = [];

for (const tab of tabs) {
  await page.goto(`${pathToFileURL(html).href}#${encodeURIComponent(tab)}`, { waitUntil: "load", timeout: 60_000 });
  /* When the name is not found the viewer keeps showing its first style, and measuring it
     returns "0 slides flagged" for another style. A deck once passed that way. */
  const opened = await page.evaluate((want) => {
    const names = [...document.querySelectorAll(".tab")].map((t) => t.textContent);
    const on = document.querySelector(".tab.on")?.textContent ?? "";
    return { names, on, ok: on === want };
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
  /* The scale is for the overview only; the checks run at full size. */
  await page.addStyleTag({ content: ".panel.on { display: block !important; } .topbar { display: none !important; }"
    + " .panel.on .stage { width: 1920px !important; height: 1080px !important; aspect-ratio: auto !important; overflow: visible !important; }"
    + " .panel.on .stage > .slide { transform: none !important; }" });
  await page.waitForTimeout(400);

  const found = await page.evaluate(([limits, banned, patterns]) => {
    const result = [];
    const slides = [...document.querySelectorAll(".panel.on section.slide")];
    slides.forEach((slide, index) => {
      const sr = slide.getBoundingClientRect();
      /* The bottom margin of the type area. A style without `pad` uses the slide's bottom edge. */
      const pad = slide.querySelector(".pad");
      const padRoom = pad === null ? 0 : Number.parseFloat(getComputedStyle(pad).paddingBottom);
      const padLine = (pad === null ? sr.bottom : pad.getBoundingClientRect().bottom) - padRoom;
      limits = { ...limits, padLine, padRoom };
      const textLeafOf = (el) => el.children.length === 0 && el.textContent.trim() !== "";
      /* Shapes meant to run to the slide's edge. Text inside an svg is not counted either. */
      const frameOf = (el) => el.closest('[class*="bleed"]') !== null
        || el.closest(".sa-frame") !== null || el.closest(".blobs") !== null;
      const bleedOf = (el) => frameOf(el) || el.closest("svg") !== null;
      /* One box per check, so that the report says what to fix. */
      const hit = { cut: [], out: [], small: [], head: [], space: [], shot: [], rough: [], word: [], tail: [], orphan: [], split: [], bite: [], glyph: [], spill: [], svgbox: [], rule: [] };
      let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
      let biggestShot = 0;
      let hasShot = false;
      /* A slide whose design has no text says so with a data attribute, so that a slide the
         DOM walk missed is not mistaken for a slide of screenshots only. */
      const allowsNoText = slide.hasAttribute("data-audit-textless");
      /* Text boxes checked for overlaps. 0 means the check looked at nothing (the slides changed shape). */
      let textBoxes = 0;
      /* Texts in figures matched against their boxes. 0 means the check looked at nothing. */
      let svgTexts = 0;
      /* Boxes with a rule seen. 0 means the check looked at nothing. */
      let ruleBoxes = 0;
      /* Explanations wrapped to two lines or more. Text that does not wrap has no last line,
         so it is not counted. 0 over all slides means the check looked at nothing. */
      let wrapped = 0;
      /* Of those, the ones measured letter by letter for line breaks. A box that holds its text
         only through child tags cannot be measured, so this is at most `wrapped`. 0 means nothing was seen. */
      let kanaText = 0;
      const kana = new RegExp(patterns.KANA);

      /* Words that must not appear on a slide. */
      const whole = slide.textContent ?? "";
      for (const w of banned) if (whole.includes(w)) hit.word.push(w);

      /* An explanation is a sentence, not a noun phrase. Items in a list (`.d`) are left out:
         they are written without a period, and adding them would flag over a hundred places. */
      for (const el of slide.querySelectorAll(".lead, .sa-note, .lin-note, .note")) {
        const t = el.textContent.trim();
        if (t !== "" && !/[。.!?]$/.test(t)) hit.tail.push(t.slice(-24));
      }

      /* When a wrapped line ends with two letters or so on its last line, they look left behind.
         Each line's rectangle is measured, and a very short last line is flagged.

         Items in a list (`.d`) are checked too: a slide has four to seven of them, more than any
         other text, and six of them kept a single letter on their last line while they were not checked. */
      for (const el of slide.querySelectorAll(".lead, .sa-note, .lin-note, .note, .d")) {
        const t = el.textContent.trim();
        if (t === "") continue;
        const range = document.createRange();
        range.selectNodeContents(el);
        /* The rectangles are fragments of boxes, not lines: a tag inside the text splits a line
           into two or three. Rectangles with the same top are joined back into one line, or the
           box of a word at the end of a line is read as the last line and called short. */
        const lines = [];
        for (const r of range.getClientRects()) {
          if (r.width === 0 || r.height === 0) continue;
          const same = lines.find((line) => Math.abs(line.top - r.top) <= 2);
          if (same === undefined) lines.push({ top: r.top, left: r.left, right: r.right });
          else { same.left = Math.min(same.left, r.left); same.right = Math.max(same.right, r.right); }
        }
        if (lines.length < 2) continue;
        wrapped += 1;
        const last = lines[lines.length - 1];
        const lastWidth = last.right - last.left;
        const size = Number.parseFloat(getComputedStyle(el).fontSize);
        if (Number.isFinite(size) && lastWidth < size * 3.6) {
          hit.orphan.push(`${Math.round(lastWidth / size)} letters on the last line: ${t.slice(-16)}`);
        }

        /* A katakana word split across two lines loses the reader at the break.
           Each letter's position is measured, and a break with katakana on both sides is flagged.
           Letters sit in several text nodes, because words are wrapped in boxes of their own,
           so every descendant text node is walked; looking only at direct children drops them. */
        const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
        const cells = [];
        for (let n = walker.nextNode(); n !== null; n = walker.nextNode()) {
          for (let i = 0; i < n.textContent.length; i += 1) cells.push({ node: n, at: i, c: n.textContent[i] });
        }
        if (cells.length === 0) continue;
        kanaText += 1;
        const letters = cells.map((cell) => cell.c).join("");
        const isKana = (c) => c !== undefined && kana.test(c);
        let top = null;
        let prev;
        cells.forEach((cell, i) => {
          const one = document.createRange();
          one.setStart(cell.node, cell.at);
          one.setEnd(cell.node, cell.at + 1);
          const box = one.getBoundingClientRect();
          /* A letter with no width (an invisible joiner) does not decide a line; keeping it makes
             it the letter after the katakana, and no split is ever found. */
          if (box.width === 0 || box.height === 0) return;
          const lineStart = top !== null && Math.abs(box.top - top) > 2;
          if (lineStart && isKana(prev) && isKana(cell.c)) {
            hit.split.push(`${prev}/${cell.c}: ${letters.slice(Math.max(0, i - 10), i + 6)}`);
          }
          top = box.top;
          prev = cell.c;
        });
      }

      /* Punctuation in headings: no period at the end and no comma inside (Japanese marks). */
      for (const el of slide.querySelectorAll(".claim, h2")) {
        const t = el.textContent.trim();
        if (t === "") continue;
        if (t.includes("、")) hit.head.push(`comma: ${t.slice(0, 30)}`);
        if (t.endsWith("。")) hit.head.push(`period at the end: ${t.slice(0, 30)}`);
      }

      for (const el of slide.querySelectorAll("*")) {
        const style = getComputedStyle(el);
        if (style.display === "none" || style.visibility === "hidden" || Number(style.opacity) === 0) continue;
        const r = el.getBoundingClientRect();
        if (r.width === 0 || r.height === 0) continue;

        /* An svg taller than a clipping parent cuts its picture. It happens when the viewBox's
           aspect ratio differs from the displayed one. */
        if (el.tagName === "svg") {
          const box = el.viewBox?.baseVal;
          const parent = el.parentElement;
          if (box && box.height > 0 && parent !== null) {
            const pr = parent.getBoundingClientRect();
            const ps = getComputedStyle(parent);
            const clip = ps.overflowY !== "visible";
            if (clip && r.bottom > pr.bottom + 1) {
              hit.out.push(`svg runs below its parent: ${String(el.getAttribute("class") ?? "").slice(0, 24)}`);
            }
          }
        }

        /* An icon running into the inner padding of its card. A card that does not clip
           (overflow: visible) escapes the check above. It happens when the container is made
           smaller (a row set to 330px overflowed by 24px). */
        if (el.tagName === "svg" && !frameOf(el) && el.parentElement?.closest("svg") === null) {
          const card = el.parentElement?.closest('[class*="ls"], [class*="lp"], [class*="mo"], [class*="cell"]');
          if (card !== null && card !== undefined && card !== el.parentElement?.closest("svg")) {
            const cr = card.getBoundingClientRect();
            const cs2 = getComputedStyle(card);
            const inner = cr.bottom - Number.parseFloat(cs2.paddingBottom || "0");
            if (r.bottom > inner + 1) {
              hit.glyph.push(`${Math.round(r.bottom - inner)}px: ${card.querySelector(".t")?.textContent.trim().slice(0, 14) ?? card.className}`);
            }
          }
        }

        /* SVG text has no box, so overflow cannot catch it. Text outside its svg is counted separately. */
        if (el.tagName === "text") {
          const svg = el.closest("svg");
          if (svg !== null) {
            const sr2 = svg.getBoundingClientRect();
            if (r.left < sr2.left - 1 || r.right > sr2.right + 1) {
              hit.cut.push(`svg text: ${el.textContent.trim().slice(0, 26)}`);
            }
          }
        }

        /* How far text runs into the bottom margin. Screenshots and decoration leave the slide by design and are not counted. */
        if (textLeafOf(el) && !bleedOf(el)) {
          const bite = r.bottom - limits.padLine;
          if (bite > limits.padRoom * limits.bottomBite) {
            hit.bite.push(`${Math.round(bite)}px: ${el.textContent.trim().slice(0, 22)}`);
          }
        }

        /* The size of a screenshot. Too small for the slide, it does not say what screen it is. */
        if (el.tagName === "IMG") {
          hasShot = true;
          biggestShot = Math.max(biggestShot, r.width / sr.width, r.height / sr.height);
          /* Whether the source has enough pixels for its size on the slide; without them it is
             stretched and only the screen's text blurs. */
          if (el.naturalWidth > 0 && r.width > 0) {
            const density = el.naturalWidth / r.width;
            if (density < limits.shotDensity) {
              hit.rough.push(`the source is only ${density.toFixed(2)} times its size: ${el.dataset.shot ?? el.getAttribute("alt") ?? "screenshot"}`);
            }
          }
        }

        /* Text that does not fit its box. It is cut only when overflow is not visible. */
        const clipX = style.overflowX !== "visible" && el.scrollWidth > el.clientWidth + 1;
        const clipY = style.overflowY !== "visible" && el.scrollHeight > el.clientHeight + 1;
        /* A container that stretches images sideways grows its scrollWidth without cutting any
           text, so only the elements that hold the text are checked. */
        const textLeaf = el.children.length === 0 && el.textContent.trim() !== "";
        if ((clipX || clipY) && textLeaf) {
          hit.cut.push(`${el.className || el.tagName}: ${el.textContent.trim().slice(0, 26)}`);
        }

        /* Text size, and spaces around Latin letters and digits in Japanese text. Both look at the elements that hold text. */
        if (textLeaf) {
          const text = el.textContent.trim();
          const size = Number.parseFloat(style.fontSize);
          if (Number.isFinite(size) && size < limits.fontSize) {
            hit.small.push(`${Math.round(size)}px: ${text.slice(0, 22)}`);
          }
          /* A space between Latin letters or digits and Japanese. A space after a Japanese comma or
             period separates sentences and is left alone. */
          const EN = "[A-Za-z0-9_%)\\]]";
          const gap = new RegExp(`(${EN} +${patterns.JP}|${patterns.JP_HEAD} +[A-Za-z0-9_(\\[])`);
          const m = gap.exec(text);
          if (m !== null) hit.space.push(`${m[0]} — ${text.slice(0, 26)}`);
        }

        /* Elements outside the slide, except decoration. Some styles cut a screenshot at the
           slide's edge, and the round background of the cover (`.blobs`) leaves the slide by design;
           those are not defects. A shape meant to run to the edge says so with `bleed` in its class
           name, so that the check need not know every style's class names. */
        const bleed = el.closest('[class*="bleed"]') !== null
          || el.closest(".sa-frame") !== null || el.closest(".blobs") !== null;
        const deco = bleed || el.tagName === "svg" || el.closest("svg") !== null
          || /ribbon|blob|cluster|band|::/.test(String(el.className));
        /* Running out sideways is an intended form in every style (a screenshot to the edge);
           only running out vertically is a defect. */
        if (!deco && (r.top < sr.top - 2 || r.bottom > sr.bottom + 2)) {
          hit.out.push(`${el.className || el.tagName}: ${el.textContent.trim().slice(0, 22)}`);
        }

        /* How much of the slide the content uses. Counting containers that fill the slide makes
           every slide 100%, so only leaves count; a panel with a color or a border fills the slide
           even when its text is centered, so it counts too. */
        const painted = (style.backgroundColor !== "rgba(0, 0, 0, 0)" && style.backgroundColor !== "transparent")
          || style.backgroundImage !== "none"
          || style.borderTopWidth !== "0px" || style.borderLeftWidth !== "0px";
        const isSlide = el === slide || el.classList.contains("pad") || el.classList.contains("sheet");
        const fills = painted && !isSlide && r.width < sr.width * 0.99 && r.height < sr.height * 0.99;
        const leaf = el.tagName === "IMG" || el.tagName === "svg"
          || (el.children.length === 0 && el.textContent.trim() !== "");
        if (leaf || fills) {
          minX = Math.min(minX, Math.max(r.left, sr.left));
          minY = Math.min(minY, Math.max(r.top, sr.top));
          maxX = Math.max(maxX, Math.min(r.right, sr.right));
          maxY = Math.max(maxY, Math.min(r.bottom, sr.bottom));
        }
      }

      /* Whether the text of a row stays above that row's rule.

         When rows share the slide's height and their basis is 0, a row shrinks below its content.
         A row whose explanation wraps to two lines puts text below its own rule, and the rule runs
         through the text. A rule is neither text nor image, so neither the overlap check nor the
         outside check sees it (three places of 18 to 21px passed all three checks). */
      for (const box of slide.querySelectorAll("*")) {
        const bs = getComputedStyle(box);
        if (bs.borderBottomWidth === "0px" || bs.overflowY !== "visible") continue;
        const br = box.getBoundingClientRect();
        if (br.height === 0) continue;
        ruleBoxes += 1;
        for (const leafEl of box.querySelectorAll("*")) {
          if (leafEl.children.length > 0 || (leafEl.textContent ?? "").trim() === "") continue;
          const over = leafEl.getBoundingClientRect().bottom - br.bottom;
          if (over > 1) {
            hit.rule.push(`${Math.round(over)}px: ${leafEl.textContent.trim().slice(0, 20)}`);
          }
        }
      }

      /* Whether text in a figure stays inside the box it sits on.

         Figures are svg and their text is `<text>`, which does not wrap: long text runs out of
         its box. The cut check looks at CSS boxes and the outside check looks only at the svg's
         own edge, so text 364 wide on a box 330 wide, 66px out to the right, passed every check. */
      for (const svg of slide.querySelectorAll("svg")) {
        const rects = [...svg.querySelectorAll("rect")].map((el) => el.getBBox());
        if (rects.length === 0) continue;
        for (const text of svg.querySelectorAll("text")) {
          const t = text.getBBox();
          if (t.width === 0) continue;
          /* The owner is the smallest box that holds the text's center. */
          const cx = t.x + t.width / 2;
          const cy = t.y + t.height / 2;
          const owner = rects
            .filter((b) => cx >= b.x && cx <= b.x + b.width && cy >= b.y && cy <= b.y + b.height)
            .sort((a, z) => a.width * a.height - z.width * z.height)[0];
          if (owner === undefined) continue;
          svgTexts += 1;
          const over = Math.max(t.x + t.width - (owner.x + owner.width), owner.x - t.x);
          if (over > 1) hit.svgbox.push(`${Math.round(over)}px: ${text.textContent.trim().slice(0, 20)}`);
        }
      }

      /* Whether texts overlap.

         It happens when more cards are placed than the container holds, in two ways. A style
         that shrinks its rows lets a card's content overflow onto the text of the card below.
         A style that keeps its rows lets the whole row of cards overflow onto the note below it.
         No other check catches either: the text is not cut (that needs overflow other than
         visible), it does not leave the slide, and the slide's height is filled. Seven cards
         overflowing into three rows hid two identifiers and a note while all 69 slides passed.

         Panel colors are not used: in some styles a card's background is 4% opaque and cannot
         count as covering. Overlapping text is unreadable in every style.

         Screenshots count too: text on a screenshot makes both unreadable (the last line of a list
         sat 5px on a screenshot, and a check of text alone missed it).

         Ancestors and descendants are not compared (nested lines always overlap), and decoration
         and shapes meant to run to the edge are left out. */
      const inked = [];
      const shots = [];
      /* The line rectangles of the text nodes themselves, not of elements: headings and
         explanations with span, br, or b children are text too, and looking only at leaf
         elements would drop them entirely. */
      const walker = document.createTreeWalker(slide, NodeFilter.SHOW_TEXT);
      for (let node = walker.nextNode(); node !== null; node = walker.nextNode()) {
        const el = node.parentElement;
        if (el === null || node.textContent.trim() === "" || frameOf(el)) continue;
        const s3 = getComputedStyle(el);
        if (s3.display === "none" || s3.visibility === "hidden" || Number(s3.opacity) === 0) continue;
        const range = document.createRange();
        range.selectNodeContents(node);
        for (const rect of range.getClientRects()) {
          if (rect.width > 0 && rect.height > 0) inked.push({ el, rect, text: node.textContent.trim() });
        }
      }
      for (const el of slide.querySelectorAll("img")) {
        const s3 = getComputedStyle(el);
        if (s3.display === "none" || s3.visibility === "hidden" || Number(s3.opacity) === 0) continue;
        const rect = el.getBoundingClientRect();
        if (rect.width === 0 || rect.height === 0) continue;
        /* A screenshot declares that it runs to the edge (`bleed`), but it still counts as
           something text must not sit on; leaving it out lets text on a screenshot pass every check. */
        shots.push({ el, rect, text: el.dataset.shot ?? el.getAttribute("alt") ?? "unnamed" });
      }
      textBoxes = inked.length;
      const pairsOf = [];
      for (let i = 0; i < inked.length; i += 1) {
        for (let j = i + 1; j < inked.length; j += 1) pairsOf.push([inked[i], inked[j]]);
        for (const shot of shots) pairsOf.push([inked[i], shot]);
      }
      for (const [a, b] of pairsOf) {
        const { el: ea, rect: ra } = a;
        const { el: eb, rect: rb } = b;
        /* The lines of one heading split into several spans cross the line height by a few
           pixels of ink; within one heading that is not a collision. */
        const claimA = ea.closest(".claim");
        const claimB = eb.closest(".claim");
        if (ea === eb || ea.contains(eb) || eb.contains(ea)
          || (claimA !== null && claimA === claimB)) continue;
        const w = Math.min(ra.right, rb.right) - Math.max(ra.left, rb.left);
        const h = Math.min(ra.bottom, rb.bottom) - Math.max(ra.top, rb.top);
        if (w > limits.spill && h > limits.spill) {
          const nameFor = (box) => (box.el.tagName === "IMG"
            ? `screenshot (${box.text})`
            : `"${box.text.slice(0, 12)}"`);
          hit.spill.push(`${Math.round(w)}x${Math.round(h)}px: ${nameFor(a)} and ${nameFor(b)}`);
        }
      }

      /* Only a slide with a screenshot has its size checked. */
      if (hasShot) {
        const pct = Math.round(biggestShot * 100);
        if (pct < limits.shotSize) hit.shot.push(`takes only ${pct}% of the slide`);
      }

      const usedH = maxY > minY ? Math.round(((maxY - minY) / sr.height) * 100) : 0;
      const usedW = maxX > minX ? Math.round(((maxX - minX) / sr.width) * 100) : 0;
      const trimmed = {};
      for (const [k, v] of Object.entries(hit)) trimmed[k] = [...new Set(v)].slice(0, 4);
      result.push({ n: index + 1, ...trimmed, usedH, usedW, textBoxes, svgTexts, ruleBoxes, wrapped, kanaText, allowsNoText });
    });
    return result;
  }, [LIMITS, banned, PATTERNS]);
  for (const f of found) out.push({ tab, ...f });
}

await browser.close();
if (reportPath !== undefined) await writeFile(reportPath, JSON.stringify(out, null, 1));

/* The name of each check, and how a slide is found flagged by it. */
const CHECKS = [
  ["text is cut off", (f) => f.cut],
  ["outside the slide", (f) => f.out],
  ["text is too small", (f) => f.small],
  ["heading punctuation", (f) => f.head],
  ["space around Latin letters and digits", (f) => f.space],
  ["screenshot is too small", (f) => f.shot],
  ["screenshot is too coarse", (f) => f.rough],
  ["text sits on the bottom margin", (f) => f.bite],
  ["icon spills out of its card", (f) => f.glyph],
  ["text and screenshots overlap", (f) => f.spill],
  ["text in a figure spills out of its box", (f) => f.svgbox],
  ["text runs below its rule", (f) => f.rule],
  ["banned word", (f) => f.word],
  ["explanation does not end as a sentence", (f) => f.tail],
  ["last line of a wrapped explanation is too short", (f) => f.orphan],
  ["katakana word split across lines", (f) => f.split],
];

/* The cover gathers its content in the middle by design, so its height used is not measured. */
const flagsOf = (f) => {
  const flags = CHECKS
    .map(([name, pick]) => [name, pick(f)])
    .filter(([, hits]) => hits.length > 0)
    .map(([name, hits]) => `${name}[${hits.join(" | ")}]`);
  if (f.n > 1 && f.usedH < LIMITS.usedHeight) flags.push(`uses only ${f.usedH}% of the height`);
  return flags;
};

const bad = out.filter((f) => flagsOf(f).length > 0);
/* How many items each check looked at. Without these counts a reader cannot tell whether
   "0 slides flagged" means no defects or nothing looked at. */
const textBoxes = out.reduce((n, f) => n + (f.textBoxes ?? 0), 0);
const empty = out.filter((f) => (f.textBoxes ?? 0) === 0 && !f.allowsNoText);
const svgTexts = out.reduce((n, f) => n + (f.svgTexts ?? 0), 0);
const ruleBoxes = out.reduce((n, f) => n + (f.ruleBoxes ?? 0), 0);
const wrapped = out.reduce((n, f) => n + (f.wrapped ?? 0), 0);
const kanaText = out.reduce((n, f) => n + (f.kanaText ?? 0), 0);
console.log(`checked ${out.length} slides / flagged ${bad.length} slides / text checked for overlaps ${textBoxes}`
  + ` / text measured in figures ${svgTexts} / boxes with a rule ${ruleBoxes} / wrapped explanations ${wrapped}`
  + ` / explanations measured at line breaks ${kanaText}`);
if (svgTexts === 0) {
  console.error("measured no text in any figure: the figures changed shape, or the check cannot find their boxes");
  process.exit(2);
}
if (ruleBoxes === 0) {
  console.error("saw no box with a rule: the rows changed shape, or the check cannot find their rules");
  process.exit(2);
}
if (wrapped === 0) {
  console.error("saw no wrapped explanation: the explanations' classes changed, or the check cannot find their text");
  process.exit(2);
}
if (kanaText === 0) {
  console.error("measured no line break: no explanation holds its text directly, or the check cannot find the text");
  process.exit(2);
}
/* A slide where the overlap check saw no text also stops the run, so that one style whose DOM
   changed cannot pass while the other slides have text. */
if (empty.length > 0) {
  console.error(`the overlap check saw no text on: ${empty.map((f) => `${f.tab} ${f.n}`).join(" / ")}`);
  console.error("for a slide of screenshots only, set auditTextless: true in the deck data");
  process.exit(2);
}
for (const f of bad) console.log(`${f.tab} ${String(f.n).padStart(2, "0")}  ${flagsOf(f).join("  ")}`);
if (bad.length > 0) console.log("\nFix and run again until none is flagged. Render again after every fix before checking.");
process.exit(bad.length === 0 ? 0 : 1);
