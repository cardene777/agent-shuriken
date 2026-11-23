/**
 * Joining a part recorded later into the recording of another flow.
 *
 * | Export | What it gives |
 * |---|---|
 * | `joinTimelines` | The joined steps: the other flow's steps up to `after`, the part's steps moved to where the next step began, and the rest moved by the part's length, numbered in the joined order |
 * | `joinedFlow` | The flow the joined videos are made from: the other flow's title, look, voice, music, cards, and outputs, with the part's steps after step `after` |
 *
 * The part goes where the step after `after` began to move, so the page's answer to step `after`
 * stays in the video, or at the end of the recording when `after` is the last step.
 */

/** Times a timeline step holds, in seconds from the start of its recording. */
const TIMES = ["from", "t", "end", "navigatedAt", "paintedAt"];

const round3 = (value) => Math.round(value * 1000) / 1000;

function moved(step, by, number) {
  const out = { ...step, step: number };
  for (const key of TIMES) if (typeof out[key] === "number") out[key] = round3(out[key] + by);
  if (Array.isArray(out.path)) out.path = out.path.map((point) => ({ ...point, t: round3(point.t + by) }));
  if (Array.isArray(out.keys)) out.keys = out.keys.map((at) => (typeof at === "number" ? round3(at + by) : at));
  return out;
}

/** How long before its first step a recording's edit starts (`lib/edit.mjs`), so a part starts the same way. */
const LEAD = 0.05;

/**
 * `other` and `part` are timelines (`{ steps, duration }`); `after` is a step number of `other`.
 * Returns the joined `steps` and `duration`, `cut`, the second of `other` where the part goes, and
 * `start`, the second of the part it is taken from.
 *
 * The part's recording begins with the browser starting before its first step, which a recording's
 * own edit never shows, so the part is taken from just before its first step.
 */
export function joinTimelines(other, part, after) {
  const next = other.steps[after];
  const cut = next === undefined ? other.duration : (next.from ?? next.t);
  const first = part.steps[0];
  const start = Math.min(part.duration, Math.max(0, (first?.from ?? first?.t ?? 0) - LEAD));
  const length = part.duration - start;
  const steps = [
    ...other.steps.slice(0, after).map((step, i) => moved(step, 0, i + 1)),
    ...part.steps.map((step, i) => moved(step, cut - start, after + i + 1)),
    ...other.steps.slice(after).map((step, i) => moved(step, length, after + part.steps.length + i + 1)),
  ];
  return { steps, duration: round3(other.duration + length), cut: round3(cut), start: round3(start) };
}

/** The other flow with the part's steps after step `after`, named as the part, with both planned lengths added. */
export function joinedFlow(other, part, after) {
  return {
    ...other,
    name: part.name,
    steps: [...other.steps.slice(0, after), ...part.steps, ...other.steps.slice(after)],
    ...(other.seconds !== undefined && part.seconds !== undefined ? { seconds: other.seconds + part.seconds } : {}),
  };
}
