/**
 * Runs a flow's steps on a page through the recorder, for a rehearsal or a recording.
 *
 * A rehearsal saves a picture for each step (the target outlined, just before it is clicked or typed
 * into), stops before the first step marked as sending something or paying, and keeps going past
 * nothing once a step fails: the steps after it are left as not rehearsed. A recording stops at the
 * first failing step with a `StepError`.
 *
 * A recording stays on each step long enough to read its caption and hear its voice before the next
 * step begins (`dwellOf`), and leaves 0.6 seconds of quiet after a click or the last key, so each
 * caption's voice starts on its own.
 *
 * An app's recorder (`app-recorder.mjs`) finds targets and waits with its own `locate` and
 * `waitUntil`, and runs `swipe` steps; a browser's recorder leaves them to the page.
 */
import { join } from "node:path";

import { dwellOf } from "./edit.mjs";
import { describeTarget, languageOf, locate } from "./flow.mjs";

export class StepError extends Error {
  constructor(number, message) {
    super(`step ${number}: ${message}`);
    this.number = number;
  }
}

const VERBS = { sends: "sends something", pays: "pays" };
const frameName = (number) => `${String(number).padStart(3, "0")}.png`;

function messageOf(error, step) {
  const text = error instanceof Error ? error.message.split("\n")[0] : String(error);
  if (/Timeout .*exceeded|waiting for/i.test(text)) {
    if (step.target !== undefined) return `cannot find ${describeTarget(step.target)} on the page (waited ${step.timeout ?? 20}s)`;
    if (step.do === "open") return `the page ${step.url} did not finish loading`;
    return `the wait did not end (waited ${step.timeout ?? 60}s)`;
  }
  return text;
}

async function waitUntil(page, until, timeout) {
  const [kind, value] = Object.entries(until)[0];
  switch (kind) {
    case "text":
      return page.getByText(value).first().waitFor({ state: "visible", timeout });
    case "url":
      return page.waitForURL((url) => url.toString().includes(value), { timeout });
    case "visible":
      return (await locate(page, value, timeout)).waitFor({ state: "visible", timeout });
    case "hidden": {
      // A target whose iframe is already gone is hidden
      const locator = await locate(page, value, 0).catch(() => undefined);
      return locator?.waitFor({ state: "hidden", timeout });
    }
    case "settled":
      // The page has had no change (other than the drawn pointer) for `value` seconds
      return page.waitForFunction((ms) => performance.now() - (window.__svLastChange ?? 0) >= ms, value * 1000, { polling: 100, timeout });
    case "enabled": {
      const locator = await locate(page, value, timeout);
      await locator.waitFor({ state: "visible", timeout });
      const until = Date.now() + timeout;
      while (!(await locator.isEnabled())) {
        if (Date.now() > until) throw new Error(`Timeout ${timeout}ms exceeded waiting for ${describeTarget(value)} to be enabled`);
        await page.waitForTimeout(200);
      }
      return undefined;
    }
    default:
      throw new Error(`unknown wait "${kind}"`);
  }
}

/**
 * Runs the steps. Returns one result per step: `ok`, `missing` (it failed), or `skipped` (not run),
 * with `frame` (the picture's name in `framesDir`) for rehearsed steps and `note` or `message` saying why.
 */
export async function runFlow({ flow, rec, rehearse = false, framesDir, env, voices = [] }) {
  const { page } = rec;
  const find = rec.locate ?? ((target, timeout) => locate(page, target, timeout));
  const until = rec.waitUntil ?? ((condition, timeout) => waitUntil(page, condition, timeout));
  const results = [];
  const language = languageOf(flow);
  const voiceOf = new Map(voices.map((clip) => [clip.step, clip.duration]));
  let readyAt = 0;
  let stopped;
  for (const [index, step] of flow.steps.entries()) {
    const number = index + 1;
    if (!rehearse) await rec.until(readyAt);
    if (stopped !== undefined) {
      results.push({ number, status: "skipped", note: stopped });
      continue;
    }
    if (rehearse && step.effect !== undefined) {
      stopped = `Not rehearsed: step ${number} ${VERBS[step.effect.kind]}, and a rehearsal stops before it.`;
      results.push({ number, status: "skipped", note: stopped });
      continue;
    }
    const frame = rehearse ? frameName(number) : undefined;
    const ready = rehearse ? (box) => rec.frame(join(framesDir, frame), box) : undefined;
    const caption = step.caption ?? "";
    const timeout = (step.timeout ?? (step.do === "wait" ? 60 : 20)) * 1000;
    const kept = { number, chapter: step.chapter };
    try {
      switch (step.do) {
        case "open":
          await rec.open(step.url === undefined ? undefined : new URL(step.url, flow.url).toString(), caption, kept);
          break;
        case "click":
          await rec.click(await find(step.target, timeout), caption, { timeout, ready, ...kept });
          break;
        case "fill": {
          const secret = step.env !== undefined;
          const text = secret ? env(step.env) : step.text;
          await rec.fill(await find(step.target, timeout), text, caption, { clear: step.clear === true, timeout, ready, secret, ...kept });
          break;
        }
        case "select":
          await rec.select(await find(step.target, timeout), step.value, caption, { timeout, ready, ...kept });
          break;
        case "key":
          await rec.key(step.key, caption, kept);
          break;
        case "wait":
          await rec.waitFor(caption, () => until(step.until, timeout), kept);
          break;
        case "hold":
          await rec.hold(step.seconds, caption, kept);
          break;
        case "swipe":
          await rec.swipe(step.from, step.to, step.seconds ?? 0.5, caption, kept);
          break;
      }
      const entry = rec.steps.at(-1);
      if (!rehearse && entry !== undefined) {
        const sounds = [...(["click", "fill"].includes(entry.kind) ? [entry.t] : []), ...(entry.keys ?? [])];
        readyAt = Math.max(
          readyAt,
          entry.end,
          caption === "" ? 0 : entry.from + dwellOf(caption, language, voiceOf.get(number)),
          sounds.length === 0 ? 0 : Math.max(...sounds) + 0.6,
        );
      }
      if (rehearse && !["click", "fill", "select"].includes(step.do)) await rec.frame(join(framesDir, frame));
      results.push({ number, status: "ok", ...(frame === undefined ? {} : { frame }) });
    } catch (error) {
      const message = messageOf(error, step);
      if (!rehearse) throw new StepError(number, message);
      await rec.frame(join(framesDir, frame));
      results.push({ number, status: "missing", message, frame });
      stopped = `Not rehearsed, because step ${number} failed.`;
    }
  }
  // The last caption stays until it has been read and heard, and the screen rests a moment after
  if (!rehearse) await rec.until(readyAt + 0.4);
  return results;
}
