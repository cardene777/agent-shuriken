/**
 * Writes the storyboard: one page that shows each step of a rehearsal with its picture, what it does,
 * its caption, and whether it ran, so the user can check the flow before anything is recorded.
 * The page reads only files next to it and switches between English and Japanese.
 */
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

import { describeStep } from "./flow.mjs";

const TEMPLATE = join(import.meta.dirname, "..", "..", "templates", "storyboard.html");

/** The English labels the page shows first. The page's script holds both languages. */
const EN = {
  purpose: "What it is for", audience: "Who watches it", length: "Length", outputs: "Videos", start: "Starts at",
  ok: "Rehearsed", missing: "Failed", skipped: "Not rehearsed", sends: "Sends something", pays: "Pays", step: "Step",
};

const escape = (text) => String(text).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

function summary(flow) {
  const rows = [
    ["purpose", flow.purpose],
    ["audience", flow.audience],
    ["length", flow.length],
    ["outputs", (flow.outputs ?? ["16:9"]).join(", ")],
    ["start", new URL(flow.url).origin],
  ].filter(([, value]) => value !== undefined && value !== "");
  return `<dl class="summary">${rows.map(([key, value]) => `<div><dt data-i18n="${key}">${EN[key]}</dt><dd>${escape(value)}</dd></div>`).join("")}</dl>`;
}

function notice(flow) {
  const marked = flow.steps.map((step, index) => ({ step, number: index + 1 })).filter(({ step }) => step.effect !== undefined);
  if (marked.length === 0) return "";
  const items = marked.map(({ step, number }) => `<li><span data-i18n="step">Step</span> ${number}: <span data-i18n="${step.effect.kind}">${EN[step.effect.kind]}</span>${step.effect.note ? ` - ${escape(step.effect.note)}` : ""}</li>`);
  return `<div class="notice"><span data-i18n="marked">These steps send something or pay each time the video is recorded. The rehearsal stopped before the first one.</span><ul>${items.join("")}</ul></div>`;
}

function card(step, result) {
  const status = result?.status ?? "skipped";
  const figure = result?.frame
    ? `<figure><img src="frames/${escape(result.frame)}" alt="Step ${result.number}" loading="lazy"></figure>`
    : `<figure><span data-i18n="noFrame">No picture: this step was not rehearsed</span></figure>`;
  const effect = step.effect === undefined ? "" : `<span class="badge effect" data-i18n="${step.effect.kind}">${EN[step.effect.kind]}</span>`;
  const caption = step.caption ? `<div class="caption">${escape(step.caption)}</div>` : `<div class="caption none" data-i18n="noCaption">No caption</div>`;
  const why = result?.message ?? result?.note;
  return `<article class="card" data-step="${result.number}" data-status="${status}">
      ${figure}
      <div class="body">
        <div class="top"><span class="no">${result.number}</span><span class="badge state" data-i18n="${status}">${EN[status]}</span>${effect}</div>
        ${caption}
        <div class="action">${escape(describeStep(step))}</div>
        ${why ? `<div class="why">${escape(why)}</div>` : ""}
      </div>
    </article>`;
}

export function writeStoryboard({ flow, results, file }) {
  const html = readFileSync(TEMPLATE, "utf8")
    .replaceAll("{{TITLE}}", escape(flow.title ?? flow.name))
    .replace("{{SUMMARY}}", summary(flow))
    .replace("{{NOTICE}}", notice(flow))
    .replace("{{CARDS}}", flow.steps.map((step, index) => card(step, results[index])).join("\n    "))
    .replace("{{GENERATED}}", escape(new Date().toISOString().replace("T", " ").slice(0, 16)));
  writeFileSync(file, html);
}
