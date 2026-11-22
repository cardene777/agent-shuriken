/**
 * How the edited videos are timed, cut, and framed, decided from the recording's records.
 *
 * | Function | What it does |
 * |---|---|
 * | `readingTime` | Seconds needed to read a caption: 15 characters a second in English, 8 in Japanese, at least 1.2 |
 * | `dwellOf` | How long a recording stays on a step: long enough to read its caption and to hear its voice, with a pause after |
 * | `captionCues` | Captions in recording time, each from its step's start to 0.3 seconds before the next caption or chapter |
 * | `planEdit` | The whole edit of a recording: the frames kept, waits played fast, still frames under the cards, the cards, the captions, the page dissolves, the zoom, the sounds, and the length |
 * | `zoomedBox` | Where an action's box shows on the screen when fully zoomed in on it |
 * | `segmentsWithout`, `cutsForFreezes`, `toEdited`, `mapCues` | Cuts of still stretches, for recordings the user made (`render`) |
 *
 * Every time in a plan counts frames of 30 a second, so the ffmpeg filters that carry the plan out
 * land on the same frames.
 */
import { HEIGHT, WIDTH } from "./media.mjs";

export const FPS = 30;
const FULL = { z: 1, ox: 0, oy: 0 };
/** Seconds a zoom or pan takes. Long enough to follow, eased at both ends. */
const MOVE = 0.9;
/**
 * The closest zoom on an action, and the least worth making: a target large enough to need less
 * than `min` is shown with the whole screen, since a slight zoom only looks like a wobble.
 */
const ZOOM = { min: 1.25, max: 1.6 };
/** The vertical video's window: this many pixels wide of the 1920x1080 screen, its full height. */
export const VERTICAL_CROP = 864;
/** Card lengths in seconds, and the shortest they become when the video must fit a planned length. */
const CARD = { title: 2.4, chapter: 1.5, end: 3.2 };
const CARD_MIN = { title: 1.4, chapter: 0.9, end: 1.8 };
/** Seconds the screen stays still after a card fades, before the recording moves on. */
const TAIL = 0.45;
const DISSOLVE = 0.6;

const round3 = (value) => Number(value.toFixed(3));

export function readingTime(text, language) {
  return Math.max(1.2, [...text].length / (language === "ja" ? 8 : 15));
}

/** Seconds from a step's start to when the next step may begin. */
export function dwellOf(text, language, voice) {
  return Math.max(readingTime(text, language) + 0.3, voice === undefined ? 0 : voice + 0.5);
}

/**
 * Captions in recording time: each captioned step's caption from its `from` to 0.3 seconds before the
 * next caption or chapter, so one has faded before the next appears. The last stays for its dwell, up
 * to the end of the recording.
 */
export function captionCues(steps, duration, language, clips = []) {
  const voiceOf = new Map(clips.map((clip) => [clip.step, clip.duration]));
  const cues = [];
  steps.forEach((step, index) => {
    if ((step.caption ?? "") === "") return;
    const start = step.from ?? step.t;
    const next = steps.slice(index + 1).find((later) => (later.caption ?? "") !== "" || later.chapter !== undefined);
    const end = next === undefined ? Math.min(duration, start + Math.max(3, dwellOf(step.caption, language, voiceOf.get(step.step)))) : (next.from ?? next.t) - 0.3;
    cues.push({ step: step.step, start: round3(start), end: round3(Math.max(start + 0.3, end)), text: step.caption, ...(step.box ? { box: step.box } : {}) });
  });
  return cues;
}

/** The zoom (`z`) and the top left of the view, scaled (`ox`, `oy`), that fit a box large on the screen. */
function framing(box) {
  const wanted = Math.max(box.width * 2.4, (box.height * 2.4 * WIDTH) / HEIGHT, WIDTH / ZOOM.max);
  if (WIDTH / wanted < ZOOM.min) return FULL;
  const z = Math.min(ZOOM.max, WIDTH / wanted);
  const halfW = WIDTH / z / 2;
  const halfH = HEIGHT / z / 2;
  const cx = Math.min(WIDTH - halfW, Math.max(halfW, box.x + box.width / 2));
  const cy = Math.min(HEIGHT - halfH, Math.max(halfH, box.y + box.height / 2));
  return { z, ox: z * (cx - halfW), oy: z * (cy - halfH) };
}

export function zoomedBox(box) {
  const { z, ox, oy } = framing(box);
  return { x: box.x * z - ox, y: box.y * z - oy, width: box.width * z, height: box.height * z };
}

/** Whether two views show nearly the same place, so moving between them is not worth a move. */
function near(a, b) {
  const centre = (v) => ({ x: (v.ox + WIDTH / 2) / v.z, y: (v.oy + HEIGHT / 2) / v.z });
  const ca = centre(a);
  const cb = centre(b);
  return Math.abs(a.z - b.z) < 0.06 && Math.abs(ca.x - cb.x) < 90 && Math.abs(ca.y - cb.y) < 90;
}

/** Moves `start` later until `[start, start + length]` misses every block. */
function clear(start, length, blocks) {
  let at = start;
  for (let moved = true; moved; ) {
    moved = false;
    for (const block of blocks) {
      if (at < block.end && at + length > block.start) {
        at = block.end;
        moved = true;
      }
    }
  }
  return at;
}

/** Parts of `[a, b]` outside every interval of `taken`. */
function outside(a, b, taken) {
  let parts = [[a, b]];
  for (const [s, e] of taken) {
    parts = parts.flatMap(([x, y]) => (e <= x || s >= y ? [[x, y]] : [...(s > x ? [[x, s]] : []), ...(e < y ? [[e, y]] : [])]));
  }
  return parts;
}

/**
 * The parts of waits played fast, in recording time. Captions keep their reading time and voice at
 * normal speed, and a quarter of a second stays at each end of the wait. With `boost`, shorter waits
 * and holds without a caption are sped up too, up to 16 times.
 */
function fastParts(steps, cues, clips, language, boost) {
  const voiceOf = new Map(clips.map((clip) => [clip.step, clip.duration]));
  const taken = cues.map((cue) => [cue.start - 0.1, cue.start + Math.max(readingTime(cue.text, language), (voiceOf.get(cue.step) ?? 0) + 0.3)]);
  const parts = [];
  for (const step of steps) {
    const holdable = boost && step.kind === "hold" && (step.caption ?? "") === "";
    if (step.kind !== "wait" && !holdable) continue;
    const margin = step.kind === "wait" ? 0.35 : 0.25;
    for (const [a, b] of outside(step.t + margin, step.end - margin, taken)) {
      const length = b - a;
      if (length < (boost ? 0.6 : 1.2)) continue;
      const speed = Math.min(boost ? 16 : 8, Math.max(2, Math.ceil(length / (boost ? 0.3 : 0.9))));
      parts.push({ start: round3(a), end: round3(b), speed });
    }
  }
  return parts.sort((x, y) => x.start - y.start);
}

/**
 * Lays out the edit for one set of choices: `scale` from 1 (cards at full length) to 0 (shortest
 * cards), and `boost` for speeding up more of the waits.
 */
function layout({ steps, duration, cues, clips, language, flow, scale, boost }) {
  const len = (kind) => CARD_MIN[kind] + (CARD[kind] - CARD_MIN[kind]) * scale;
  const tail = boost ? 0.3 : TAIL;
  const lastFrame = Math.max(0, Math.floor(duration * FPS) - 1);
  const first = steps[0];
  const bodyStart = Math.min(lastFrame, Math.max(0, Math.round(((first?.from ?? 0) - 0.05) * FPS)));
  const fast = fastParts(steps, cues, clips, language, boost);
  const fastFrames = fast.map((part) => ({ ...part, a: Math.round(part.start * FPS), b: Math.round(part.end * FPS) }));

  // The raw frames kept, in order; a part played s times as fast keeps every s-th frame
  const kept = [];
  let f = 0;
  for (let i = bodyStart; i <= lastFrame; i++) {
    while (f < fastFrames.length && i >= fastFrames[f].b) f++;
    const part = fastFrames[f];
    if (part !== undefined && i >= part.a && (i - part.a) % part.speed !== 0) continue;
    kept.push(i);
  }
  const positionAt = (frame) => {
    let low = 0;
    let high = kept.length;
    while (low < high) {
      const mid = (low + high) >> 1;
      if (kept[mid] < frame) low = mid + 1;
      else high = mid;
    }
    return low;
  };

  // Still frames under the cards: after the first kept frame for the title card (and a first chapter), at each chapter's start for its card
  const titled = flow.title !== undefined;
  const cardsAt = [];
  const freezes = new Map();
  const firstChapter = first?.chapter;
  if (titled || firstChapter !== undefined) {
    const opening = (titled ? len("title") : 0) + (firstChapter !== undefined ? len("chapter") : 0);
    freezes.set(0, Math.round((opening + tail) * FPS));
    cardsAt.push({ position: 0, titled, chapter: firstChapter });
  }
  for (const step of steps.slice(1)) {
    if (step.chapter === undefined) continue;
    const position = Math.min(kept.length - 1, positionAt(Math.round((step.from ?? step.t) * FPS)));
    if (freezes.has(position)) continue;
    freezes.set(position, Math.round((len("chapter") + tail) * FPS));
    cardsAt.push({ position, chapter: step.chapter });
  }
  const positions = [...freezes.keys()].sort((a, b) => a - b);
  /** The output frame where kept frame `p` first shows. */
  const shows = (p) => p + positions.filter((q) => q < p).reduce((sum, q) => sum + freezes.get(q), 0);
  /** The output frame where the recording moves on from kept frame `p`. */
  const resumes = (p) => shows(p) + (freezes.get(p) ?? 0);
  const bodyFrames = kept.length + positions.reduce((sum, q) => sum + freezes.get(q), 0);
  const ending = flow.end !== undefined && flow.end !== false;
  const endFrames = ending ? Math.round(len("end") * FPS) : 0;
  const total = bodyFrames + endFrames;

  /** A recording time as a time of the edited video. An event at a still frame happens as the recording moves on. */
  const at = (t) => {
    const frame = t * FPS;
    const p = positionAt(frame - 0.5);
    if (p >= kept.length) return round3(Math.min(bodyFrames, resumes(kept.length - 1) + 1) / FPS);
    if (p === 0 || kept[p] - frame < 0.5) return round3(resumes(p) / FPS);
    const share = (frame - kept[p - 1]) / (kept[p] - kept[p - 1]);
    return round3((resumes(p - 1) + share * (shows(p) - resumes(p - 1))) / FPS);
  };

  // Cards, with the times each one shows and fades
  const cards = [];
  for (const place of cardsAt) {
    let start = shows(place.position) / FPS;
    if (place.titled) {
      cards.push({ kind: "title", text: flow.title, start: round3(start), end: round3(start + len("title")) });
      start += len("title");
    }
    if (place.chapter !== undefined) cards.push({ kind: "chapter", text: place.chapter, start: round3(start), end: round3(start + len("chapter")) });
  }
  if (ending) {
    const end = flow.end;
    cards.push({ kind: "end", text: end.title ?? "Thanks for watching", ...(end.url ? { url: end.url } : {}), ...(end.note ? { note: end.note } : {}), start: round3(bodyFrames / FPS), end: round3(total / FPS) });
  }
  for (const [i, card] of cards.entries()) {
    const joined = i > 0 && Math.abs(cards[i - 1].end - card.start) < 1e-6;
    const joinsNext = i + 1 < cards.length && Math.abs(cards[i + 1].start - card.end) < 1e-6;
    // Next to another card, the later card waits fully drawn under the earlier one, which fades out over it
    card.show = {
      from: round3(joined ? card.start - 0.15 : card.start),
      to: round3(joinsNext ? card.end + 0.15 : card.end),
      fadeIn: joined || card.start === 0 ? 0 : 0.3,
      fadeOut: card.end >= total / FPS - 1e-6 ? 0 : 0.3,
    };
  }

  // Page changes: the last picture of the old page fades out over the new one
  const dissolves = [];
  for (const step of steps) {
    if (!step.navigates) continue;
    const painted = step.paintedAt ?? (step.navigatedAt ?? step.t + 0.2) + 0.1;
    const still = Math.max(0, Math.min(step.navigatedAt ?? painted, painted - 0.1) - 0.03);
    const start = at(still + 1 / FPS);
    dissolves.push({ at: round3(still), frame: Math.round(still * FPS), start, end: round3(start + DISSOLVE) });
  }

  const blocks = [
    ...cards.map((card) => ({ start: card.show.from - 0.05, end: card.show.to + 0.05 })),
    ...dissolves.map((d) => ({ start: d.start - 0.05, end: d.end + 0.05 })),
  ];

  // Zoom: close in on each action, stay through it, and go back to the whole screen, or straight on to the next action
  const actions = steps
    .filter((step) => step.box !== undefined)
    .map((step) => ({ t: at(step.t), end: at(step.end), box: step.box, navigates: step.navigates === true, dissolved: dissolves.find((d) => Math.abs(d.at - step.t) < 2)?.end }));
  const keys = [{ t: 0, ...FULL }];
  let view = FULL;
  let free = 0;
  const move = (start, target) => {
    const begin = clear(Math.max(start, free, keys.at(-1).t), MOVE, blocks);
    keys.push({ t: begin, ...view }, { t: begin + MOVE, ...target });
    view = target;
    free = begin + MOVE;
  };
  actions.forEach((action, index) => {
    const target = framing(action.box);
    if (!near(view, target)) move(action.t - 0.95, target);
    // A click that moves the page stays close in until the new page has dissolved in
    const holdEnd = action.navigates ? Math.max(free, action.dissolved ?? action.t + 0.2) : Math.max(free, Math.min(action.end, action.t + 1.4) + 0.3);
    free = holdEnd;
    const next = actions[index + 1];
    if (next !== undefined && next.t - 0.95 <= holdEnd + MOVE + 0.25) return;
    move(holdEnd, FULL);
  });
  const zoomKeys = keys.map((k) => ({ t: round3(k.t), z: Number(k.z.toFixed(4)), ox: Number(k.ox.toFixed(1)), oy: Number(k.oy.toFixed(1)) }));

  // The vertical window slides sideways to each action
  const half = VERTICAL_CROP / 2;
  const sideKeys = [{ t: 0, cx: WIDTH / 2 }];
  let side = WIDTH / 2;
  let sideFree = 0;
  for (const action of actions) {
    const cx = Math.min(WIDTH - half, Math.max(half, action.box.x + action.box.width / 2));
    if (Math.abs(cx - side) < 80) continue;
    const begin = clear(Math.max(action.t - 0.95, sideFree), MOVE, blocks);
    sideKeys.push({ t: round3(begin), cx: side }, { t: round3(begin + MOVE), cx: Number(cx.toFixed(1)) });
    side = cx;
    sideFree = begin + MOVE;
  }

  const voiceOf = new Map(clips.map((clip) => [clip.step, clip]));
  const captions = cues
    .map((cue) => ({ ...cue, start: at(cue.start), end: at(cue.end) }))
    .filter((cue) => cue.end - cue.start >= 0.3);
  const voices = cues.filter((cue) => voiceOf.has(cue.step)).map((cue) => ({ step: cue.step, file: voiceOf.get(cue.step).file, at: at(cue.start), raw: cue.start, duration: voiceOf.get(cue.step).duration }));
  const presses = steps.filter((step) => ["click", "fill"].includes(step.kind)).map((step) => ({ at: at(step.t), raw: step.t }));
  const typed = steps.flatMap((step) => (step.keys ?? []).map((k) => ({ at: at(k), raw: k })));

  // The recording's parts with their speeds, from the first frame kept to the last
  const segments = [];
  let cursor = bodyStart / FPS;
  for (const part of fast) {
    if (part.start > cursor + 0.01) segments.push({ start: round3(cursor), end: part.start, speed: 1 });
    segments.push({ start: part.start, end: part.end, speed: part.speed });
    cursor = part.end;
  }
  if ((lastFrame + 1) / FPS > cursor + 0.01) segments.push({ start: round3(cursor), end: round3((lastFrame + 1) / FPS), speed: 1 });

  return {
    frames: total,
    seconds: round3(total / FPS),
    segments,
    bodyStart,
    fast: fast.map((part) => ({ ...part, editedStart: at(part.start), editedEnd: at(part.end) })),
    fastFrames,
    freezes: positions.map((p) => ({ after: p, frames: freezes.get(p), at: round3(kept[p] / FPS), seconds: round3(freezes.get(p) / FPS) })),
    endFrames,
    keptCount: kept.length,
    lastFrame,
    cards,
    captions,
    dissolves,
    zoomKeys,
    sideKeys,
    actions: steps.filter((step) => step.box !== undefined).map((step) => ({ at: step.t, end: step.end, box: step.box })),
    voices,
    presses,
    typed,
    at,
  };
}

const fmt = (seconds) => Number(seconds.toFixed(1)).toString();

/**
 * The edit of a recording. With `planned` seconds, the cards get shorter and waits play faster until
 * the video fits, and `note` says by how much it is still longer or shorter when it cannot fit
 * within a tenth.
 */
export function planEdit({ steps, duration, cues, clips, language, flow, planned }) {
  const base = { steps, duration, cues, clips, language, flow };
  const natural = layout({ ...base, scale: 1, boost: false });
  let plan = natural;
  if (planned !== undefined && natural.seconds > planned * 1.02) {
    const fit = (boost) => {
      let low = 0;
      let high = 1;
      for (let i = 0; i < 12; i++) {
        const mid = (low + high) / 2;
        if (layout({ ...base, scale: mid, boost }).seconds > planned) high = mid;
        else low = mid;
      }
      return layout({ ...base, scale: low, boost });
    };
    plan = layout({ ...base, scale: 0, boost: false }).seconds <= planned ? fit(false) : fit(true);
  }
  let note;
  if (planned !== undefined && plan.seconds > planned * 1.1) {
    note = `The edited video is ${fmt(plan.seconds)}s, ${fmt(plan.seconds - planned)}s longer than the planned ${fmt(planned)}s. Shorten the flow's waits and holds, or plan a longer video.`;
  } else if (planned !== undefined && plan.seconds < planned * 0.9) {
    note = `The edited video is ${fmt(plan.seconds)}s, ${fmt(planned - plan.seconds)}s shorter than the planned ${fmt(planned)}s. Add holds to the flow, or plan a shorter video.`;
  }
  return { ...plan, length: { ...(planned === undefined ? {} : { planned }), natural: natural.seconds, edited: plan.seconds }, note };
}

// --- recordings the user made (render) ---------------------------------------------------------------

export function segmentsWithout(cuts, duration) {
  const sorted = [...cuts].sort((a, b) => a.start - b.start);
  const segments = [];
  let cursor = 0;
  for (const cut of sorted) {
    if (cut.start > cursor + 0.01) segments.push({ start: cursor, end: cut.start });
    cursor = Math.max(cursor, cut.end);
  }
  if (cursor < duration - 0.01) segments.push({ start: cursor, end: duration });
  return segments.map((s) => ({ start: round3(s.start), end: round3(s.end) }));
}

export function cutsForFreezes(freezes) {
  return freezes.filter((f) => f.end - f.start >= 1).map((f) => ({ start: f.start + 0.5, end: f.end - 0.5 }));
}

/** With `forward`, a time inside a cut moves to the start of the next kept part; with `back`, to the end of the previous one. */
export function toEdited(segments, at, snap = "forward") {
  let offset = 0;
  let previousEnd;
  for (const segment of segments) {
    if (at < segment.start) return snap === "forward" ? offset : (previousEnd ?? 0);
    if (at <= segment.end) return offset + (at - segment.start);
    offset += segment.end - segment.start;
    previousEnd = offset;
  }
  return offset;
}

export function mapCues(segments, cues) {
  return cues
    .map((cue) => ({ ...cue, start: toEdited(segments, cue.start, "forward"), end: toEdited(segments, cue.end, "back") }))
    .filter((cue) => cue.end - cue.start >= 0.3);
}
