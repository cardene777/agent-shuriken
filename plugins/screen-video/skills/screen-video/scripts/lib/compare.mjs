/**
 * Writes the comparison page: for each point the edited video improves, the plain video and the
 * edited one side by side, each starting at the moment that point can be seen.
 *
 * The plain video (`compare/plain.mp4`) is the recording with plain captions and no sound, cut as
 * the first version of screen-video cut it, unless `before` names a folder holding a video made
 * another way: its `edited.mp4`, with its `edit.json` and, when it was recorded on its own, its
 * `timeline.json`, to find the same steps in it.
 */
import { copyFileSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

import { captionImages } from "./captions.mjs";
import { toEdited } from "./edit.mjs";
import { burn } from "./media.mjs";

const TEMPLATE = join(import.meta.dirname, "..", "..", "templates", "compare.html");
export const POINTS = ["zoom", "pointer", "press", "transition", "frame", "cards", "end", "captions", "narration", "music", "sounds", "sync", "settled", "fastforward", "length", "reading"];
const TITLES = {
  zoom: "Zoom and pan", pointer: "Pointer", press: "Press", transition: "Page change", frame: "Frame", cards: "Title and chapters",
  end: "End card", captions: "Captions", narration: "Narration", music: "Music", sounds: "Clicks and typing", sync: "Caption and voice",
  settled: "Waiting for the page", fastforward: "Fast-forward", length: "Length", reading: "Time to read",
};

const escape = (text) => String(text).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
const clamp = (value) => Math.max(0, Number(value.toFixed(2)));

/**
 * The moment of each point, in the recording (`raw`) and in the edited video (`edited`), a little
 * before it happens. A moment tied to a step keeps the step's number, the time it counts from, and
 * the lead, so the same moment can be found in another recording of the flow.
 */
function moments({ timeline, edit, cues, flow }) {
  const steps = timeline.steps;
  const edited = new Map((edit.steps ?? []).map((step) => [step.step, step]));
  /** A step's moment: its `key` time in both videos, `lead` seconds earlier. */
  const of = (step, key = "t", lead = 0.5) =>
    step && { raw: clamp(step[key] - lead), edited: clamp((edited.get(step.step)?.[key] ?? 0) - lead), step: step.step, key, lead };
  const reach = (step) => (step.path ? Math.hypot(step.path.at(-1).x - step.path[0].x, step.path.at(-1).y - step.path[0].y) : 0);
  const clicks = steps.filter((step) => step.kind === "click");
  const longest = [...clicks].sort((a, b) => reach(b) - reach(a))[0];
  const settledNumber = flow.steps.findIndex((step) => step.until?.settled !== undefined) + 1;
  const settled = steps.find((step) => step.step === settledNumber) ?? steps.find((step) => step.kind === "wait");
  const captioned = steps.filter((step) => (step.caption ?? "") !== "");
  const longCue = [...cues].sort((a, b) => b.text.length - a.text.length)[0];
  const longStep = longCue && steps.find((step) => step.step === longCue.step);
  const fast = (edit.fast ?? [])[0];
  const fastStep = fast && steps.find((step) => step.t <= fast.raw.start && fast.raw.start <= step.end);
  const opening = (edit.cards ?? []).find((card) => card.kind !== "end");
  const end = (edit.cards ?? []).find((card) => card.kind === "end");
  return {
    zoom: of(steps.find((step) => step.box !== undefined), "t", 1.2),
    pointer: of(longest, "from", 0.1),
    press: of(longest),
    transition: of(steps.find((step) => step.navigates)),
    frame: of(captioned[0], "from", 0),
    cards: { raw: 0, edited: opening ? clamp(opening.start) : 0 },
    end: { raw: clamp(timeline.duration - 2), edited: end ? clamp(end.start - 1) : 0, fromEnd: 2 },
    captions: of(captioned[0], "from", 0.3),
    narration: of(captioned[0], "from", 0.3),
    music: of(captioned[1] ?? captioned[0], "from", 1),
    sounds: of(steps.find((step) => step.kind === "fill")),
    sync: of(longStep, "from", 0.3),
    settled: of(settled, "t", 0.3),
    fastforward: fast && { raw: clamp(fast.raw.start - 0.5), edited: clamp(fast.start - 0.5), step: fastStep?.step, key: "t", lead: 0.5 },
    length: { raw: 0, edited: 0 },
    reading: of(longStep, "from", 0.3),
  };
}

/**
 * Writes `compare/plain.mp4` (when no `before` is given) and `compare/compare.html` into `out`.
 * Returns the page's path.
 */
export async function writeCompare({ out, before, timeline, edit, cues, flow, work, dir }) {
  let plain = join(dir, "plain.mp4");
  let plainAt = (raw) => raw;
  /** The old recording's timeline, when `before` was recorded on its own, to find each step's moment in it. */
  let oldTimeline;
  if (before !== undefined) {
    if (!existsSync(join(before, "edited.mp4"))) throw new Error(`${before} has no edited.mp4 to compare with`);
    copyFileSync(join(before, "edited.mp4"), plain);
    const old = existsSync(join(before, "edit.json")) ? JSON.parse(readFileSync(join(before, "edit.json"), "utf8")) : {};
    if (Array.isArray(old.segments)) plainAt = (raw) => toEdited(old.segments, raw);
    if (existsSync(join(before, "timeline.json"))) oldTimeline = JSON.parse(readFileSync(join(before, "timeline.json"), "utf8"));
  } else {
    const images = await captionImages(cues.map((cue) => ({ ...cue, avoid: cue.box ? [cue.box] : [] })), work, { prefix: "plain" });
    burn({ input: join(out, "raw.mp4"), output: plain, workDir: work, overlays: images });
  }
  plain = "plain.mp4";
  const found = moments({ timeline, edit, cues, flow });
  // The first version of screen-video wrote its steps in order without their numbers
  const oldSteps = new Map((oldTimeline?.steps ?? []).map((step, index) => [step.step ?? index + 1, step]));
  /** Where a moment is in the plain video: the same step of the old recording when there is one, else the same time. */
  const plainOf = (moment) => {
    if (oldTimeline !== undefined && moment.fromEnd !== undefined) return clamp(plainAt(oldTimeline.duration - moment.fromEnd));
    const old = moment.step === undefined ? undefined : oldSteps.get(moment.step);
    if (old !== undefined) return clamp(plainAt(Math.max(0, (old[moment.key] ?? old.t) - moment.lead)));
    return clamp(plainAt(moment.raw));
  };
  const lengths = edit.length ?? {};
  const sections = POINTS.map((name) => {
    const moment = found[name];
    const where = moment ?? { raw: 0, edited: 0 };
    const plainTime = plainOf(where);
    const extra =
      name === "length"
        ? `<p class="at">${lengths.planned === undefined ? "" : `planned ${lengths.planned}s, `}edited ${lengths.edited ?? "?"}s, recorded ${timeline.duration.toFixed(1)}s</p>`
        : moment === undefined
          ? '<p class="at" data-i18n="missing">This flow has no such moment, so both videos start at the beginning.</p>'
          : "";
    return `<section id="${name}" data-point="${name}">
    <h2 data-i18n="${name}">${TITLES[name]}</h2>
    <p data-i18n="${name}Text"></p>
    ${extra}
    <div class="pair">
      <figure class="before"><figcaption data-i18n="before">Before</figcaption><video src="${plain}#t=${plainTime}" controls preload="metadata" muted></video><span class="at">${plainTime}s</span></figure>
      <figure class="after"><figcaption data-i18n="after">After</figcaption><video src="../edited.mp4#t=${where.edited}" controls preload="metadata"></video><span class="at">${where.edited}s</span></figure>
    </div>
  </section>`;
  });
  const nav = POINTS.map((name) => `<a href="#${name}" data-i18n="${name}">${TITLES[name]}</a>`).join("");
  const html = readFileSync(TEMPLATE, "utf8")
    .replaceAll("{{TITLE}}", escape(flow.title ?? flow.name))
    .replace("{{NAV}}", nav)
    .replace("{{SECTIONS}}", sections.join("\n  "))
    .replace("{{GENERATED}}", escape(new Date().toISOString().replace("T", " ").slice(0, 16)));
  const page = join(dir, "compare.html");
  writeFileSync(page, html);
  return page;
}
