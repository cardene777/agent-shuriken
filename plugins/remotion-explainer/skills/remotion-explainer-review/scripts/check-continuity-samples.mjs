#!/usr/bin/env node
// Checks an out/review/continuity-samples.json against the continuity samples contract
// (formats/continuity-samples.md): every scene boundary has before, during, and after samples with a
// camera that does not jump, and carries at least one persistent object or one handoff. Persistent
// objects and handoffs stay within their limits of center movement and change of size, and each
// handoff states its cause.
// Prints the result as JSON. Exits 0 when it passes, 1 when the samples need revising, 2 when called
// wrongly or the file cannot be read.
import fs from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
if (args.length !== 1 || args[0].startsWith("-")) {
  console.error("usage: check-continuity-samples.mjs <continuity-samples.json>");
  process.exit(2);
}
const source = path.resolve(args[0]);
let report;
try {
  report = JSON.parse(fs.readFileSync(source, "utf8"));
} catch (error) {
  console.error(`cannot read ${args[0]}: ${error.message}`);
  process.exit(2);
}
if (!report || typeof report !== "object" || Array.isArray(report)) {
  console.error(`cannot read ${args[0]}: the file is not a JSON object`);
  process.exit(2);
}

const issues = [];
const add = (rule, where, message) => issues.push({rule, ...where, message});
const finite = (value) => Number.isFinite(value);
const records = (list) => (Array.isArray(list) ? list : []).filter((item) => item && typeof item === "object" && !Array.isArray(item));
const isBounds = (box) => box && [box.x, box.y, box.width, box.height].every(finite) && box.width > 0 && box.height > 0;
const isCamera = (camera) => camera && [camera.x, camera.y, camera.scale].every(finite);
const center = (box) => ({x: box.x + box.width / 2, y: box.y + box.height / 2});
const distance = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
const scaleDelta = (a, b) => Math.max(Math.abs(a.width / b.width - 1), Math.abs(a.height / b.height - 1));
const boundsOf = (sample, id) => {
  const bounds = records(sample?.objects).find((item) => item.id === id)?.bounds;
  return isBounds(bounds) ? bounds : null;
};

const samples = new Map(records(report.frames).map((sample) => [sample.frame, sample]));
const boundaries = records(report.boundaries);
if (boundaries.length === 0) add("boundaries", {}, "boundaries needs at least one scene boundary");

for (const [index, boundary] of boundaries.entries()) {
  const id = boundary.id ?? `boundaries[${index}]`;
  const where = {boundary: id};
  const frames = boundary.frames && typeof boundary.frames === "object" ? boundary.frames : {};
  const before = samples.get(frames.before);
  const during = samples.get(frames.during);
  const after = samples.get(frames.after);
  if (!before || !during || !after) {
    add("boundary-frames", where, `${id} needs samples at its before, during, and after frames`);
    continue;
  }

  if (!boundary.camera || !isCamera(before.camera) || !isCamera(during.camera) || !isCamera(after.camera)) {
    add("camera-data", where, `${id} needs camera limits, and a camera x, y, and scale at its before, during, and after frames`);
  } else {
    const maxCenter = boundary.camera.maxCenterDelta ?? 0;
    const maxScale = boundary.camera.maxScaleDelta ?? 0;
    const moved = Math.max(distance(before.camera, during.camera), distance(during.camera, after.camera));
    const scaled = Math.max(Math.abs(before.camera.scale - during.camera.scale), Math.abs(during.camera.scale - after.camera.scale));
    if (moved > maxCenter) add("camera-jump", where, `${id}: the camera moves ${moved.toFixed(2)}px in one step, above ${maxCenter}px; it resets or jumps`);
    if (scaled > maxScale) add("camera-scale-jump", where, `${id}: the camera scale changes by ${scaled.toFixed(3)} in one step, above ${maxScale}`);
  }

  const persistent = records(boundary.persistent);
  const handoffs = records(boundary.handoffs);
  if (persistent.length + handoffs.length === 0) {
    add("nothing-carried", where, `${id} has no persistent object and no handoff`);
  }

  for (const item of persistent) {
    const start = boundsOf(before, item.id);
    const end = boundsOf(after, item.id);
    if (!start || !end) {
      add("persistent-missing", where, `${id}: the persistent object ${item.id} needs bounds at the before and after frames`);
      continue;
    }
    const maxCenter = item.maxCenterDelta ?? 0;
    const maxScale = item.maxScaleDelta ?? 0;
    const moved = distance(center(start), center(end));
    const scaled = scaleDelta(start, end);
    if (moved > maxCenter) add("persistent-jump", where, `${id}: the persistent object ${item.id} moves ${moved.toFixed(2)}px, above ${maxCenter}px`);
    if (scaled > maxScale) add("persistent-scale-jump", where, `${id}: the persistent object ${item.id} changes size by ${scaled.toFixed(3)}, above ${maxScale}`);
  }

  for (const item of handoffs) {
    const chain = `${item.from} -> ${item.via} -> ${item.to}`;
    const start = boundsOf(before, item.from);
    const bridge = boundsOf(during, item.via);
    const end = boundsOf(after, item.to);
    if (!start || !bridge || !end) {
      add("handoff-chain", where, `${id}: the handoff ${chain} needs from at the before frame, via at the during frame, and to at the after frame`);
      continue;
    }
    if (typeof item.reason !== "string" || !item.reason.trim()) {
      add("handoff-reason", where, `${id}: the handoff ${chain} has no reason stating its cause`);
    }
    const maxCenter = item.maxCenterDelta ?? 0;
    const maxScale = item.maxScaleDelta ?? 0;
    const moved = Math.max(distance(center(start), center(bridge)), distance(center(bridge), center(end)));
    const scaled = Math.max(scaleDelta(start, bridge), scaleDelta(bridge, end));
    if (moved > maxCenter) add("handoff-jump", where, `${id}: the handoff ${chain} moves ${moved.toFixed(2)}px in one step, above ${maxCenter}px`);
    if (scaled > maxScale) add("handoff-scale-jump", where, `${id}: the handoff ${chain} changes size by ${scaled.toFixed(3)} in one step, above ${maxScale}`);
  }
}

const result = {check: "continuity-samples", decision: issues.length ? "revise" : "pass", issueCount: issues.length, source, issues};
console.log(JSON.stringify(result, null, 2));
process.exit(issues.length ? 1 : 0);
