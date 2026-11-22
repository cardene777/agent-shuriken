/**
 * How the edited videos are cut and framed, decided from the recording's records.
 *
 * | Function | What it does |
 * |---|---|
 * | `segmentsWithout` | The parts to keep once the cuts are taken out |
 * | `cutsForWaits` | Cuts for long waits, keeping 0.4 seconds at each end |
 * | `cutsForFreezes` | Cuts for still stretches, keeping 0.5 seconds at each end |
 * | `toEdited` | A recording time as a time in the joined video. A time inside a cut moves to the next or previous kept part |
 * | `mapCues` | Captions moved to edited times. Captions left shorter than 0.3 seconds are dropped |
 * | `zoomKeys` | Zoom keys that close in on each action and go back to the whole screen between actions |
 * | `zoomedBox` | Where an action's box shows on the screen when fully zoomed in on it |
 * | `verticalKeys` | Keys that move the vertical video's window sideways to each action |
 */
import { HEIGHT, WIDTH } from "./media.mjs";

const FULL = { z: 1, cx: WIDTH / 2, cy: HEIGHT / 2 };
const VERTICAL_HALF = 304;

export function segmentsWithout(cuts, duration) {
  const sorted = [...cuts].sort((a, b) => a.start - b.start);
  const segments = [];
  let cursor = 0;
  for (const cut of sorted) {
    if (cut.start > cursor + 0.01) segments.push({ start: cursor, end: cut.start });
    cursor = Math.max(cursor, cut.end);
  }
  if (cursor < duration - 0.01) segments.push({ start: cursor, end: duration });
  return segments.map((s) => ({ start: Number(s.start.toFixed(3)), end: Number(s.end.toFixed(3)) }));
}

export function cutsForWaits(steps) {
  return steps.filter((step) => step.kind === "wait" && step.end - step.t > 0.8).map((step) => ({ start: step.t + 0.4, end: step.end - 0.4 }));
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

/** The scale and centre that fit an action's box (`x`, `y`, `width`, `height`) large in the middle of the screen. */
function framing(box) {
  const wanted = Math.max(box.width * 2.4, (box.height * 2.4 * WIDTH) / HEIGHT, WIDTH / 2.1);
  const z = Math.min(2.1, Math.max(1.3, WIDTH / wanted));
  const halfW = WIDTH / z / 2;
  const halfH = HEIGHT / z / 2;
  const cx = Math.min(WIDTH - halfW, Math.max(halfW, box.x + box.width / 2));
  const cy = Math.min(HEIGHT - halfH, Math.max(halfH, box.y + box.height / 2));
  return { z, cx, cy };
}

export function zoomedBox(box) {
  const { z, cx, cy } = framing(box);
  const left = cx - WIDTH / z / 2;
  const top = cy - HEIGHT / z / 2;
  return { x: (box.x - left) * z, y: (box.y - top) * z, width: box.width * z, height: box.height * z };
}

/**
 * For each action (`t` to `end`, edited time): close in over 0.5 seconds, leave at most 1.7 seconds
 * after it starts, and go back to the whole screen over 0.5 seconds. An action that moves the page
 * (`navigates`) leaves 0.2 seconds after the click. When the next action starts before the way back
 * ends, it moves straight to the next place.
 */
export function zoomKeys(actions) {
  const keys = [{ t: 0, ...FULL }];
  const push = (t, state) => {
    const last = keys.at(-1);
    keys.push({ t: Math.max(t, last.t + 0.02), ...state });
  };
  const sorted = [...actions].sort((a, b) => a.t - b.t);
  sorted.forEach((action, index) => {
    const target = framing(action.box);
    const current = keys.at(-1);
    const inStart = Math.max(current.t, action.t - 0.55);
    push(inStart, { z: current.z, cx: current.cx, cy: current.cy });
    push(Math.max(inStart + 0.05, action.t - 0.05), target);
    // An action that moves the page leaves right after the click, so the blank page in between is not shown large
    const holdEnd = action.navigates === true ? action.t + 0.2 : Math.min(action.end, action.t + 1.4) + 0.3;
    const next = sorted[index + 1];
    if (next !== undefined && next.t - 0.55 <= holdEnd + 0.5) return;
    push(holdEnd, target);
    push(holdEnd + 0.5, FULL);
  });
  return keys.map((k) => ({ t: Number(k.t.toFixed(3)), z: Number(k.z.toFixed(4)), cx: Number(k.cx.toFixed(1)), cy: Number(k.cy.toFixed(1)) }));
}

/** Keys (`t` in edited time, centre `cx`) that slide the vertical window to each action over 0.5 seconds and stay there until the next one. */
export function verticalKeys(actions) {
  const keys = [{ t: 0, cx: WIDTH / 2 }];
  for (const action of [...actions].sort((a, b) => a.t - b.t)) {
    const cx = Math.min(WIDTH - VERTICAL_HALF, Math.max(VERTICAL_HALF, action.box.x + action.box.width / 2));
    const last = keys.at(-1);
    const start = Math.max(last.t + 0.02, action.t - 0.55);
    keys.push({ t: start, cx: last.cx }, { t: Math.max(start + 0.05, action.t - 0.05), cx });
  }
  return keys.map((k) => ({ t: Number(k.t.toFixed(3)), cx: Number(k.cx.toFixed(1)) }));
}
