#!/usr/bin/env node
// Checks an out/review/beat-review.json against the beat review contract (formats/beat-review.md): it names
// the beat dossier and its exact SHA-256, a SHA-256 compiled hash, a review of every beat of the dossier
// with a real file for each of the orient, operation, read, and handoff frames, every score at 4 or 5, and a
// concrete reviewNote. Paths are read relative to the review file. It cannot judge visual quality; a pass
// only allows an independent reviewer's candidate. Prints the result as JSON. Exits 0 when it passes,
// 1 when the review needs revising, and 2 when called wrongly or the review or the dossier cannot be read.
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
if (args.length !== 1 || args[0].startsWith("-")) {
  console.error("usage: check-beat-review.mjs <beat-review.json>");
  process.exit(2);
}
const source = path.resolve(args[0]);
let review;
try {
  review = JSON.parse(fs.readFileSync(source, "utf8"));
} catch (error) {
  console.error(`cannot read ${args[0]}: ${error.message}`);
  process.exit(2);
}

const folder = path.dirname(source);
const resolve = (candidate) => path.resolve(folder, candidate);
const isFile = (file) => {
  try {
    return fs.statSync(file).isFile();
  } catch {
    return false;
  }
};
const frameKinds = ["orient", "operation", "read", "handoff"];
const scoreKeys = ["questionClarity", "visualProof", "hierarchy", "operation", "readingRhythm", "handoff"];
// A verdict that names nothing the frames show.
const vague = /\b(?:ok|okay|looks good|no problems?)\b/i;
const issues = [];
const add = (rule, where, message) => issues.push({rule, ...where, message});
const list = (value) => (Array.isArray(value) ? value : []);

let dossier = null;
let dossierHash = "";
const dossierFile = typeof review?.dossierPath === "string" && review.dossierPath ? resolve(review.dossierPath) : null;
if (!dossierFile || !isFile(dossierFile)) {
  add("dossier-path", {field: "dossierPath"}, "dossierPath must name the beat dossier, relative to this file");
} else {
  try {
    const bytes = fs.readFileSync(dossierFile);
    dossier = JSON.parse(bytes.toString("utf8"));
    dossierHash = crypto.createHash("sha256").update(bytes).digest("hex");
  } catch (error) {
    console.error(`cannot read ${review.dossierPath}: ${error.message}`);
    process.exit(2);
  }
  if (review.dossierHash !== dossierHash) {
    add("dossier-hash", {field: "dossierHash"}, "dossierHash is not the SHA-256 of the dossier; run check-beat-dossier again and copy its dossierHash");
  }
}
if (typeof review?.compiledHash !== "string" || !/^[a-f0-9]{64}$/.test(review.compiledHash)) {
  add("compiled-hash", {field: "compiledHash"}, "compiledHash must be the SHA-256 of the renderer source and output contract, 64 lowercase hex digits");
}

const expected = new Set(list(dossier?.beats).map((beat) => beat?.id));
const seen = new Set();
for (const [index, beat] of list(review?.beats).entries()) {
  const id = beat?.id ?? `beats[${index}]`;
  seen.add(beat?.id);
  if (dossier && !expected.has(beat?.id)) add("unknown-beat", {beat: id}, `${id} is not a beat of the dossier`);
  const frames = list(beat?.frames);
  const kinds = new Set(frames.map((frame) => frame?.kind));
  for (const kind of frameKinds) {
    if (!kinds.has(kind)) add("frame-kind", {beat: id, frame: kind}, `${id} has no ${kind} frame`);
  }
  for (const frame of frames) {
    if (typeof frame?.path !== "string" || !frame.path || !isFile(resolve(frame.path))) {
      add("frame-file", {beat: id, frame: String(frame?.kind)}, `${id}: the ${frame?.kind} frame ${frame?.path} is not a rendered file`);
    }
  }
  for (const key of scoreKeys) {
    const score = beat?.scores?.[key];
    if (!(score >= 4 && score <= 5)) add("score", {beat: id}, `${id}: ${key} is ${score}; every score must be 4 or 5`);
  }
  if (typeof beat?.reviewNote !== "string" || !beat.reviewNote.trim() || vague.test(beat.reviewNote)) {
    add("review-note", {beat: id}, `${id}: reviewNote must say what the frames show, not a general verdict`);
  }
}
for (const id of expected) {
  if (!seen.has(id)) add("missing-review", {beat: String(id)}, `${id} of the dossier has no review`);
}

const result = {check: "beat-review", decision: issues.length ? "revise" : "pass", issueCount: issues.length, source};
if (!issues.length) result.dossierHash = dossierHash;
result.issues = issues;
console.log(JSON.stringify(result, null, 2));
process.exit(issues.length ? 1 : 0);
