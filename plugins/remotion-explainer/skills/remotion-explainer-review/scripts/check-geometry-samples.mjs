#!/usr/bin/env node
// Checks an out/review/geometry-samples.json against the geometry samples contract
// (formats/geometry-samples.md): at every sampled frame, each object has valid bounds and stays in the
// safe area, objects overlap only as allowed pairs, connected objects meet edge to edge on a shared
// center line, and stable tracks do not move between their frames.
// Prints the result as JSON. Exits 0 when it passes, 1 when the samples need revising, 2 when called
// wrongly or the file cannot be read.
import fs from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
if (args.length !== 1 || args[0].startsWith("-")) {
  console.error("usage: check-geometry-samples.mjs <geometry-samples.json>");
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
const overlapArea = (a, b) => {
  const width = Math.max(0, Math.min(a.x + a.width, b.x + b.width) - Math.max(a.x, b.x));
  const height = Math.max(0, Math.min(a.y + a.height, b.y + b.height) - Math.max(a.y, b.y));
  return width * height;
};
const EDGES = ["left", "right", "top", "bottom"];
const edge = (box, side) => ({left: box.x, right: box.x + box.width, top: box.y, bottom: box.y + box.height})[side];
// A connection across left and right edges lines up the vertical centers; across top and bottom, the horizontal ones.
const crossCenter = (box, side) => (side === "left" || side === "right" ? box.y + box.height / 2 : box.x + box.width / 2);

const viewport = report.viewport;
const safe = viewport?.safeArea;
const margins = safe && ["left", "right", "top", "bottom"].every((side) => finite(safe[side]));
if (!finite(viewport?.width) || !finite(viewport?.height) || viewport.width <= 0 || viewport.height <= 0 || !margins) {
  add("viewport", {}, "viewport needs a positive width and height and a safeArea with left, right, top, and bottom");
}
const frames = records(report.frames);
if (frames.length === 0) add("frames", {}, "frames needs at least one sampled frame");

for (const sample of frames) {
  const frame = sample.frame;
  const objects = records(sample.objects);
  const byId = new Map();
  for (const object of objects) {
    const id = object.id ?? "unknown";
    const where = {frame, element: id};
    if (!object.id || !isBounds(object.bounds)) {
      add("object-bounds", where, `frame ${frame}: ${id} needs an id and positive bounds`);
      continue;
    }
    if (byId.has(object.id)) add("duplicate-object", where, `frame ${frame}: ${id} has more than one bounds entry`);
    byId.set(object.id, object);
    const b = object.bounds;
    if (margins && object.allowOutsideSafeArea !== true &&
      (b.x < safe.left || b.y < safe.top || b.x + b.width > viewport.width - safe.right || b.y + b.height > viewport.height - safe.bottom)) {
      add("safe-area", where, `frame ${frame}: ${id} leaves the safe area`);
    }
  }

  const permitted = new Set((sample.allowedOverlaps ?? []).filter(Array.isArray).map((pair) => [...pair].sort().join("|")));
  const placed = [...byId.values()];
  for (let index = 0; index < placed.length; index += 1) {
    for (let other = index + 1; other < placed.length; other += 1) {
      const a = placed[index];
      const b = placed[other];
      const area = overlapArea(a.bounds, b.bounds);
      if (area > 0.5 && !permitted.has([a.id, b.id].sort().join("|"))) {
        add("overlap", {frame, element: `${a.id}/${b.id}`}, `frame ${frame}: ${a.id} and ${b.id} overlap by ${area.toFixed(1)} square pixels`);
      }
    }
  }

  for (const connection of records(sample.connections)) {
    const pair = `${connection.from}/${connection.to}`;
    const where = {frame, element: pair};
    const from = byId.get(connection.from);
    const to = byId.get(connection.to);
    if (!from || !to) {
      add("connection-object", where, `frame ${frame}: ${pair} names an object that is not sampled at this frame`);
      continue;
    }
    if (!EDGES.includes(connection.fromEdge) || !EDGES.includes(connection.toEdge)) {
      add("connection-edge", where, `frame ${frame}: ${pair} needs fromEdge and toEdge of left, right, top, or bottom`);
      continue;
    }
    const gap = Math.abs(edge(from.bounds, connection.fromEdge) - edge(to.bounds, connection.toEdge));
    const alignment = Math.abs(crossCenter(from.bounds, connection.fromEdge) - crossCenter(to.bounds, connection.fromEdge));
    const maxGap = connection.maxGap ?? 0;
    const centerTolerance = connection.centerTolerance ?? 0;
    if (gap > maxGap) add("connection-gap", where, `frame ${frame}: the edges of ${pair} are ${gap.toFixed(2)}px apart, above ${maxGap}px`);
    if (alignment > centerTolerance) {
      add("connection-alignment", where, `frame ${frame}: the centers of ${pair} differ by ${alignment.toFixed(2)}px, above ${centerTolerance}px`);
    }
  }
}

for (const [index, track] of records(report.stableTracks).entries()) {
  const id = track.id ?? `stableTracks[${index}]`;
  const trackFrames = Array.isArray(track.frames) ? track.frames : [];
  const bounds = trackFrames.map((frame) => records(frames.find((sample) => sample.frame === frame)?.objects).find((item) => item.id === track.id)?.bounds);
  if (!track.id || trackFrames.length < 2 || !bounds.every(isBounds)) {
    add("stable-track-samples", {element: id}, `${id} needs an id and positive bounds sampled at each of at least two frames`);
    continue;
  }
  const maxDelta = track.maxDelta ?? 0;
  const origin = bounds[0];
  for (const [step, current] of bounds.entries()) {
    const delta = Math.max(...["x", "y", "width", "height"].map((key) => Math.abs(current[key] - origin[key])));
    if (delta > maxDelta) {
      add("stable-track-jitter", {frame: trackFrames[step], element: id}, `${id} moves ${delta.toFixed(2)}px at frame ${trackFrames[step]}, above ${maxDelta}px`);
    }
  }
}

const result = {check: "geometry-samples", decision: issues.length ? "revise" : "pass", issueCount: issues.length, source, issues};
console.log(JSON.stringify(result, null, 2));
process.exit(issues.length ? 1 : 0);
