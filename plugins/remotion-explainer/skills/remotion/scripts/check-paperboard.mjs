#!/usr/bin/env node
// Checks a paperboard.json against the paperboard contract (formats/paperboard.md): the paper-scribe language,
// a renderer named for its subject, a 1920x1080 canvas with a safe margin, a reference study of abstract traits,
// at least two approved subject objects and two beats, and in every beat a purposeful paper structure, the
// drawing order structure, outline, paint, annotation, a concrete operation, a reading hold of at least 500 ms,
// a focus that moves after the first beat, and a handoff the next beat uses. Prints the result as JSON.
// Exits 0 when it passes, 1 when the paperboard needs revising, and 2 when called wrongly or the file cannot be read.
import fs from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
if (args.length !== 1 || args[0].startsWith("-")) {
  console.error("usage: check-paperboard.mjs <paperboard.json>");
  process.exit(2);
}
const source = path.resolve(args[0]);
let board;
try {
  board = JSON.parse(fs.readFileSync(source, "utf8"));
} catch (error) {
  console.error(`cannot read ${args[0]}: ${error.message}`);
  process.exit(2);
}

const issues = [];
const add = (rule, where, message) => issues.push({rule, ...where, message});
const empty = (value) => value === undefined || value === null || value === "" || (Array.isArray(value) && value.length === 0);
const isId = (value) => typeof value === "string" && /^[a-z][a-z0-9-]{2,79}$/.test(value);
// Operations that present something instead of saying what happens to it.
const generic = /(?:fade|slide|title card|generic card|auto silhouette|automatic (?:silhouette|outline)|generic arrow)/i;
const sequence = ["paper-structure", "object-outline", "object-paint", "annotation"];

if (board?.version !== 1) add("version", {field: "version"}, "version must be 1");
if (board?.visualLanguage !== "paper-scribe") add("visual-language", {field: "visualLanguage"}, "visualLanguage must be paper-scribe");
if (typeof board?.rendererId !== "string" || !/^paper-scribe-[a-z0-9-]+-v[1-9][0-9]*$/.test(board.rendererId)) {
  add("renderer-id", {field: "rendererId"}, "rendererId must name a renderer made for the subject, as paper-scribe-<subject>-v<n>");
}
const canvas = board?.canvas;
if (canvas?.width !== 1920 || canvas?.height !== 1080 || !Number.isInteger(canvas?.safeMargin) || canvas.safeMargin < 72) {
  add("canvas", {field: "canvas"}, "canvas must be 1920x1080 with a whole-number safeMargin of at least 72");
}
const study = board?.referenceStudy;
if (!Array.isArray(study?.transferableTraits) || study.transferableTraits.length < 3) {
  add("transferable-traits", {field: "referenceStudy.transferableTraits"}, "referenceStudy.transferableTraits needs at least three traits");
}
if (!Array.isArray(study?.prohibitedTransfers) || study.prohibitedTransfers.length < 3) {
  add("prohibited-transfers", {field: "referenceStudy.prohibitedTransfers"}, "referenceStudy.prohibitedTransfers needs at least three transfers that are not allowed");
}

const objects = Array.isArray(board?.objects) ? board.objects : [];
const beats = Array.isArray(board?.beats) ? board.beats : [];
if (objects.length < 2) add("objects", {field: "objects"}, "list at least two approved PNG subject objects");
if (beats.length < 2) add("beats", {field: "beats"}, "list at least two connected beats");

const objectIds = new Set();
for (const [index, object] of objects.entries()) {
  const where = {field: `objects[${index}]`};
  const name = String(object?.id);
  if (!isId(object?.id) || objectIds.has(object?.id)) add("object-id", where, `object id ${name} is not valid or is used twice`);
  objectIds.add(object?.id);
  for (const key of ["assetId", "businessRole", "state"]) {
    if (empty(object?.[key])) add("object-field", where, `object ${name} has no ${key}`);
  }
}

for (const [index, value] of beats.entries()) {
  const beat = value ?? {};
  const id = String(beat.id ?? `beats[${index}]`);
  const where = {beat: id};
  if (!isId(beat.id)) add("beat-id", where, `beat ${index + 1} needs a valid id`);
  if (!Number.isInteger(beat.frames?.start) || !Number.isInteger(beat.frames?.end) || beat.frames.end <= beat.frames.start) {
    add("frame-range", where, `${id} needs whole-number frames with the end after the start`);
  }
  if (!objectIds.has(beat.primaryObjectId)) add("primary-object", where, `${id}: primaryObjectId must name a listed object`);
  if (!objectIds.has(beat.annotation?.targetObjectId)) add("annotation-target", where, `${id}: the annotation target must name a listed object`);
  if (!objectIds.has(beat.handoff?.objectId)) add("handoff-object", where, `${id}: the handoff object must name a listed object`);

  if (!Array.isArray(beat.structures) || beat.structures.length === 0) add("structures", where, `${id} needs a paper structure with a purpose`);
  const structureIds = new Set();
  for (const structure of Array.isArray(beat.structures) ? beat.structures : []) {
    if (!isId(structure?.id) || structureIds.has(structure?.id)) {
      add("structure-id", where, `${id}: structure id ${String(structure?.id)} is not valid or is used twice`);
    }
    structureIds.add(structure?.id);
    if (!objectIds.has(structure?.targetObjectId)) add("structure-target", where, `${id}: structure ${String(structure?.id)} must target a listed object`);
    if (!/[a-z-]+/.test(structure?.kind ?? "") || !structure?.purpose) {
      add("structure-field", where, `${id}: structure ${String(structure?.id)} needs a kind and a purpose`);
    }
  }

  const steps = Array.isArray(beat.drawOrder) ? beat.drawOrder : [];
  const kinds = steps.map((step) => step?.kind);
  const ordered = sequence.every((kind) => kinds.includes(kind))
    && sequence.every((kind, position) => kinds.indexOf(kind) === Math.min(...sequence.slice(position).map((later) => kinds.indexOf(later))));
  if (!ordered) add("draw-order", where, `${id} must draw paper-structure, then object-outline, then object-paint, then annotation`);
  for (const step of steps) {
    const known = step?.kind === "paper-structure"
      ? structureIds.has(step?.targetId)
      : step?.kind === "annotation"
        ? step?.targetId === beat.annotation?.id
        : objectIds.has(step?.targetId);
    if (!known) add("draw-target", where, `${id}: the ${String(step?.kind)} step targets ${String(step?.targetId)}, not a structure, object, or annotation of the beat`);
  }

  if (!beat.operation || generic.test(beat.operation)) add("operation", where, `${id}: the operation is missing, generic, or not allowed`);
  if (!Number.isInteger(beat.readingHoldMs) || beat.readingHoldMs < 500) add("reading-hold", where, `${id} needs a reading hold of at least 500 ms`);
  const focus = beat.focus;
  const moves = focus && (focus.from?.x !== focus.to?.x || focus.from?.y !== focus.to?.y || focus.from?.zoom !== focus.to?.zoom);
  if (index > 0 && !moves) add("focus-change", where, `${id} must move the focus; only the opening beat may keep it still`);

  const next = beats[index + 1];
  if (next) {
    if (beat.handoff?.toBeatId !== next.id) add("handoff-target", where, `${id} must hand off to ${String(next.id)}`);
    if (beat.frames?.end > next.frames?.start) add("frame-order", where, `${id} ends after ${String(next.id)} starts`);
    const nextTargets = [next.primaryObjectId, next.annotation?.targetObjectId,
      ...(Array.isArray(next.structures) ? next.structures : []).map((structure) => structure?.targetObjectId)];
    if (!nextTargets.includes(beat.handoff?.objectId)) {
      add("handoff-relevance", where, `${id}: the handoff object must be the primary, the annotation target, or a structure target of ${String(next.id)}`);
    }
  } else if (beat.handoff?.toBeatId !== "end" || beat.handoff?.terminalState !== true) {
    add("terminal-handoff", where, `${id} is the last beat and must hand off to end with terminalState true`);
  }
}

const result = {check: "paperboard", decision: issues.length ? "revise" : "pass", issueCount: issues.length, source, issues};
console.log(JSON.stringify(result, null, 2));
process.exit(issues.length ? 1 : 0);
