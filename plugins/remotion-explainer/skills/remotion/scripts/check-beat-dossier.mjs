#!/usr/bin/env node
// Checks a beat-dossier.json against the beat dossier contract (formats/beat-dossier.md): every beat has a
// stage mode, a viewer question, a concrete primary and proof object, a before, an operation, and an after
// where the operation is a causal action rather than a presentation word, an annotation on a visible object
// with a frame range, a reading hold, and a handoff whose result object is used by the beat it goes to.
// Prints the result as JSON; when the dossier passes, the result also holds dossierHash, the SHA-256 of the
// file, which beat-review.json cites. Exits 0 when it passes, 1 when the dossier needs revising, and 2 when
// called wrongly or the file cannot be read.
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
if (args.length !== 1 || args[0].startsWith("-")) {
  console.error("usage: check-beat-dossier.mjs <beat-dossier.json>");
  process.exit(2);
}
const source = path.resolve(args[0]);
let bytes;
let dossier;
try {
  bytes = fs.readFileSync(source);
  dossier = JSON.parse(bytes.toString("utf8"));
} catch (error) {
  console.error(`cannot read ${args[0]}: ${error.message}`);
  process.exit(2);
}

const modes = new Set(["aperture", "exchange", "inspection", "consequence", "handoff"]);
// Words that present something instead of saying what happens to it.
const presentation = /\b(?:show|display|fade|slide|transition|title|card|nice animation)\b|\b(?:just|merely|only)\s+(?:moves?|appears?|disappears?)\b/i;
const issues = [];
const add = (rule, where, message) => issues.push({rule, ...where, message});
const text = (value) => typeof value === "string" && value.trim() !== "";
const range = (frames) => Number.isFinite(frames?.start) && Number.isFinite(frames?.end) && frames.end > frames.start;
const list = (value) => (Array.isArray(value) ? value : []);

const beats = list(dossier?.beats);
if (beats.length === 0) add("beats", {}, "beats must be a non-empty list");

const ids = new Set();
for (const [index, beat] of beats.entries()) {
  const id = beat?.id ?? `beats[${index}]`;
  const where = {beat: id};
  if (!beat?.id) add("beat-id", where, `${id} needs an id`);
  else if (ids.has(beat.id)) add("duplicate-id", where, `${id} is used by two beats`);
  ids.add(beat?.id);
  if (!modes.has(beat?.stageMode)) {
    add("stage-mode", where, `${id}: stageMode must be aperture, exchange, inspection, consequence, or handoff`);
  }
  for (const key of ["viewerQuestion", "primary", "proofObject", "before", "operation", "after", "attentionAction"]) {
    if (!text(beat?.[key])) add("beat-field", where, `${id} has no ${key}`);
  }
  if (presentation.test(String(beat?.operation))) {
    add("presentation-verb", where, `${id}: the operation is a presentation word, not a causal action`);
  }
  if (presentation.test(String(beat?.primary)) || presentation.test(String(beat?.proofObject))) {
    add("generic-object", where, `${id}: a title, a card, or another presentation element cannot be the primary or the proof object`);
  }
  if (!range(beat?.frames)) add("frame-range", where, `${id}: frames.end must come after frames.start`);
  if (!(beat?.readingHoldMs > 0)) add("reading-hold", where, `${id}: readingHoldMs must be above zero`);

  const annotation = beat?.annotation;
  if (!text(annotation?.text) || !text(annotation?.target)) add("annotation-field", where, `${id}: the annotation needs text and a target`);
  if (!range(annotation?.frames)) add("annotation-frames", where, `${id}: the annotation needs a frame range whose end comes after its start`);
  const visible = annotation?.target === beat?.primary
    || list(beat?.counterparts).includes(annotation?.target)
    || String(beat?.proofObject).startsWith(`${annotation?.target}:`);
  if (!visible) {
    add("annotation-target", where, `${id}: the annotation target ${annotation?.target} is not the primary, a counterpart, or the object of the proof`);
  }

  const handoff = beat?.handoff;
  if (!handoff?.object || !handoff?.resultObject || !handoff?.toBeatId || !handoff?.change) {
    add("handoff-field", where, `${id}: the handoff needs object, resultObject, toBeatId, and change`);
  }

  const previous = beats[index - 1];
  if (previous && range(previous.frames) && range(beat?.frames) && beat.frames.start < previous.frames.end) {
    add("beat-overlap", where, `${id} starts at frame ${beat.frames.start}, before ${previous.id} ends at ${previous.frames.end}`);
  }
  if (previous && text(beat?.primary) && beat.primary === previous.primary && beat.viewerQuestion === previous.viewerQuestion) {
    add("repeated-primary", where, `${id} repeats the primary and the question of ${previous.id} without a new visual job`);
  }
}

for (const [index, beat] of beats.entries()) {
  const id = beat?.id ?? `beats[${index}]`;
  const where = {beat: id};
  const handoff = beat?.handoff;
  if (handoff?.toBeatId === "end" && handoff?.terminalState === true) continue;
  const next = beats.find((candidate) => candidate?.id === handoff?.toBeatId);
  if (!next) {
    add("handoff-target", where, `${id}: handoff.toBeatId ${handoff?.toBeatId} names no beat; only the last beat may hand off to end with terminalState true`);
    continue;
  }
  if (range(next.frames) && range(beat.frames) && next.frames.start < beat.frames.end) {
    add("handoff-timing", where, `${id}: ${next.id}, which the handoff goes to, starts before this beat ends`);
  }
  const nextObjects = new Set([next.primary, ...list(next.counterparts), String(next.proofObject).split(":")[0]]);
  if (!nextObjects.has(handoff?.resultObject)) {
    add("handoff-result", where, `${id}: the handoff result ${handoff?.resultObject} is not the primary, a counterpart, or the proof object of ${next.id}`);
  }
}

const result = {check: "beat-dossier", decision: issues.length ? "revise" : "pass", issueCount: issues.length, source};
if (!issues.length) result.dossierHash = crypto.createHash("sha256").update(bytes).digest("hex");
result.issues = issues;
console.log(JSON.stringify(result, null, 2));
process.exit(issues.length ? 1 : 0);
