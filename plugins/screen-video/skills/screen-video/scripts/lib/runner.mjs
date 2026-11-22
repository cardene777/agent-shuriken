/**
 * Runs a flow's steps on a page through the recorder, for a rehearsal or a recording.
 *
 * A rehearsal saves a picture for each step (the target outlined, just before it is clicked or typed
 * into), stops before the first step marked as sending something or paying, and keeps going past
 * nothing once a step fails: the steps after it are left as not rehearsed. A recording stops at the
 * first failing step with a `StepError`.
 */
import { join } from "node:path";

import { describeTarget, locate } from "./flow.mjs";

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
    case "hidden":
      return locate(page, value).waitFor({ state: kind, timeout });
    case "enabled": {
      const locator = locate(page, value);
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
export async function runFlow({ flow, rec, rehearse = false, framesDir, env }) {
  const { page } = rec;
  const results = [];
  let stopped;
  for (const [index, step] of flow.steps.entries()) {
    const number = index + 1;
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
    try {
      switch (step.do) {
        case "open":
          await rec.open(new URL(step.url, flow.url).toString(), caption);
          break;
        case "click":
          await rec.click(locate(page, step.target), caption, { timeout, ready });
          break;
        case "fill": {
          const secret = step.env !== undefined;
          const text = secret ? env(step.env) : step.text;
          await rec.fill(locate(page, step.target), text, caption, { clear: step.clear === true, timeout, ready, secret });
          break;
        }
        case "select":
          await rec.select(locate(page, step.target), step.value, caption, { timeout, ready });
          break;
        case "key":
          await rec.key(step.key, caption);
          break;
        case "wait":
          await rec.waitFor(caption, () => waitUntil(page, step.until, timeout));
          break;
        case "hold":
          await rec.hold(step.seconds, caption);
          break;
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
  return results;
}
