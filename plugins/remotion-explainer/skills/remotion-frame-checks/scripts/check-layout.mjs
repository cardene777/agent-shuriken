#!/usr/bin/env node
// Checks a storyboard/layout-spec.json against the layout contract (formats/layout.md): the safe area,
// the subtitle zone, overlaps and clearances, alignment and equal-size groups, frame aspect ratios,
// routes that cross what they avoid, and the review frames. With --audit-dir it also writes
// layout-samples.json, collision-audit.json, and spatial-route-audit.json, tied to the file's SHA-256.
// Prints the result as JSON. Exits 0 when it passes, 1 when the file needs revising, 2 when called wrongly.
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
let input = null;
let auditDir = null;
for (let index = 0; index < args.length; index += 1) {
  if (args[index] === "--audit-dir" && args[index + 1]) auditDir = args[++index];
  else if (!args[index].startsWith("-") && input === null) input = args[index];
  else input = undefined;
}
if (!input) {
  console.error("usage: check-layout.mjs <layout-spec.json> [--audit-dir <folder>]");
  process.exit(2);
}
const source = path.resolve(input);
let bytes;
let spec;
try {
  bytes = fs.readFileSync(source);
  spec = JSON.parse(bytes.toString("utf8"));
} catch (error) {
  console.error(`cannot read ${input}: ${error.message}`);
  process.exit(2);
}

const issues = [];
const collisionChecks = [];
const routeChecks = [];
const add = (rule, where, message) => issues.push({rule, ...where, message});
const finite = (value) => Number.isFinite(value);
const isBounds = (box) => box && [box.x, box.y, box.width, box.height].every(finite) && box.width > 0 && box.height > 0;
const right = (box) => box.x + box.width;
const bottom = (box) => box.y + box.height;
const intersects = (a, b) => a.x < right(b) && right(a) > b.x && a.y < bottom(b) && bottom(a) > b.y;
const contains = (outer, inner) => inner.x >= outer.x && inner.y >= outer.y && right(inner) <= right(outer) && bottom(inner) <= bottom(outer);
const gap = (a, b) => Math.hypot(Math.max(a.x - right(b), b.x - right(a), 0), Math.max(a.y - bottom(b), b.y - bottom(a), 0));
const spread = (values) => Math.max(...values) - Math.min(...values);

if (spec.schemaVersion !== 1) add("schema-version", {}, "schemaVersion must be 1");
if (!isBounds({x: 0, y: 0, width: spec.canvas?.width, height: spec.canvas?.height})) {
  add("canvas", {}, "canvas needs a positive width and height");
}
const safe = isBounds(spec.safeContent) ? spec.safeContent : null;
const subtitles = isBounds(spec.subtitleSafeZone) ? spec.subtitleSafeZone : null;
if (!safe) add("safe-content", {}, "safeContent needs positive bounds");
if (!subtitles) add("subtitle-safe-zone", {}, "subtitleSafeZone needs positive bounds");

const elements = new Map();
for (const [index, item] of (spec.elements ?? []).entries()) {
  const id = item.id ?? `elements[${index}]`;
  const where = {element: id};
  if (!item.id || !item.role || !item.anchor || !isBounds(item.bounds)) {
    add("element-shape", where, `${id} needs an id, a role, an anchor, and positive bounds`);
  }
  if (elements.has(id)) add("duplicate-id", where, `${id} is listed twice`);
  elements.set(id, item);
  if (!isBounds(item.bounds)) continue;
  if (safe && item.allowOutsideSafe !== true && !contains(safe, item.bounds)) {
    add("safe-content", where, `${id} leaves the safe area`);
  }
  if (subtitles && item.role !== "caption" && intersects(item.bounds, subtitles)) {
    add("subtitle-collision", where, `${id} enters the subtitle zone, which only captions may use`);
  }
  if (finite(item.aspectRatio)) {
    const actual = item.bounds.width / item.bounds.height;
    if (Math.abs(actual - item.aspectRatio) > (item.aspectRatioTolerance ?? 0.02)) {
      add("aspect-ratio", where, `${id} has the aspect ratio ${actual.toFixed(3)}, not ${item.aspectRatio}`);
    }
  }
}

for (const rule of spec.clearanceRules ?? []) {
  const pair = `${rule.a}/${rule.b}`;
  const a = elements.get(rule.a);
  const b = elements.get(rule.b);
  if (!a || !b || !isBounds(a.bounds) || !isBounds(b.bounds)) {
    add("clearance-target", {element: pair}, `${pair} names an unknown element`);
    continue;
  }
  if (rule.allowOverlap === true) continue;
  const apart = gap(a.bounds, b.bounds);
  const overlaps = intersects(a.bounds, b.bounds);
  const passes = !overlaps && (!finite(rule.minimum) || apart >= rule.minimum);
  collisionChecks.push({a: rule.a, b: rule.b, minimum: rule.minimum ?? 0, actualDistance: Number(apart.toFixed(1)),
    intersects: overlaps, decision: passes ? "pass" : "revise"});
  if (overlaps) add("collision", {element: pair}, `${pair} overlap`);
  else if (finite(rule.minimum) && apart < rule.minimum) {
    add("clearance", {element: pair}, `${pair} are ${apart.toFixed(1)}px apart, below ${rule.minimum}px`);
  }
}

for (const [index, group] of (spec.alignmentGroups ?? []).entries()) {
  const id = group.id ?? `alignmentGroups[${index}]`;
  const where = {element: id};
  const members = (group.members ?? []).map((member) => elements.get(member)).filter((item) => item && isBounds(item.bounds));
  if (members.length !== (group.members ?? []).length || members.length < 2) {
    add("alignment-members", where, `${id} needs at least two known members`);
    continue;
  }
  const tolerance = group.tolerance ?? 1;
  const boxes = members.map((item) => item.bounds);
  if (group.sameY && spread(boxes.map((box) => box.y)) > tolerance) add("alignment-y", where, `${id}: the tops differ`);
  if (group.sameBaseline && spread(boxes.map(bottom)) > tolerance) add("alignment-baseline", where, `${id}: the baselines differ`);
  if (group.equalSize) {
    if (spread(boxes.map((box) => box.width)) > tolerance) add("equal-width", where, `${id}: the widths differ`);
    if (spread(boxes.map((box) => box.height)) > tolerance) add("equal-height", where, `${id}: the heights differ`);
  }
  if (group.equalHorizontalGap) {
    const sorted = [...boxes].sort((a, b) => a.x - b.x);
    const gaps = sorted.slice(1).map((box, step) => box.x - right(sorted[step]));
    if (spread(gaps) > tolerance) add("equal-gap", where, `${id}: the gaps differ (${gaps.join(", ")})`);
  }
}

for (const [index, route] of (spec.routes ?? []).entries()) {
  const id = route.id ?? `routes[${index}]`;
  const where = {element: id};
  if (!route.id || !isBounds(route.bounds)) {
    add("route-shape", where, `${id} needs an id and positive bounds`);
    continue;
  }
  for (const target of route.avoid ?? []) {
    const item = elements.get(target);
    if (!item || !isBounds(item.bounds)) {
      add("route-target", where, `${id} avoids the unknown element ${target}`);
      continue;
    }
    const crosses = intersects(route.bounds, item.bounds);
    routeChecks.push({route: id, target, intersects: crosses, decision: crosses ? "revise" : "pass"});
    if (crosses) add("route-collision", where, `${id} crosses ${target}`);
  }
}

if (!Array.isArray(spec.reviewFrames) || spec.reviewFrames.length < 6) {
  add("review-frames", {}, "reviewFrames needs at least six frames: entry, 25%, 50%, 75%, settled, and handoff");
}

if (auditDir) {
  const folder = path.resolve(auditDir);
  const sourceHash = crypto.createHash("sha256").update(bytes).digest("hex");
  const record = (name, data) => fs.writeFileSync(path.join(folder, name), `${JSON.stringify(data, null, 2)}\n`);
  const failed = (checks) => checks.filter((item) => item.decision !== "pass");
  fs.mkdirSync(folder, {recursive: true});
  record("layout-samples.json", {schemaVersion: 1, source, sourceHash, reviewFrames: spec.reviewFrames, elements: spec.elements});
  record("collision-audit.json", {schemaVersion: 1, sourceHash, decision: failed(collisionChecks).length ? "revise" : "pass",
    issueCount: failed(collisionChecks).length, issues: failed(collisionChecks), checks: collisionChecks});
  record("spatial-route-audit.json", {schemaVersion: 1, sourceHash, decision: failed(routeChecks).length ? "revise" : "pass",
    issueCount: failed(routeChecks).length, issues: failed(routeChecks), checks: routeChecks});
}

const result = {check: "layout", decision: issues.length ? "revise" : "pass", issueCount: issues.length, source, issues};
console.log(JSON.stringify(result, null, 2));
process.exit(issues.length ? 1 : 0);
