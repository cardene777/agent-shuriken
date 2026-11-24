#!/usr/bin/env node
// Checks a storyboard/svg-geometry.json against the SVG geometry contract (formats/svg-geometry.md):
// element bounds, ports on the outer edge, connectors that start and end on their ports and miss what
// they avoid, clearances between elements, arrivals at their target, and the review samples.
// Prints the result as JSON. Exits 0 when it passes, 1 when the file needs revising, 2 when called wrongly.
import fs from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
if (args.length !== 1 || args[0].startsWith("-")) {
  console.error("usage: check-svg-geometry.mjs <svg-geometry.json>");
  process.exit(2);
}
const source = path.resolve(args[0]);
let spec;
try {
  spec = JSON.parse(fs.readFileSync(source, "utf8"));
} catch (error) {
  console.error(`cannot read ${args[0]}: ${error.message}`);
  process.exit(2);
}

const issues = [];
const add = (rule, where, message) => issues.push({rule, ...where, message});
const finite = (value) => Number.isFinite(value);
const isPoint = (value) => value && finite(value.x) && finite(value.y);
const isBounds = (value) =>
  value && [value.x, value.y, value.width, value.height].every(finite) && value.width > 0 && value.height > 0;
const right = (box) => box.x + box.width;
const bottom = (box) => box.y + box.height;
const containsPoint = (box, value, tolerance = 0) =>
  value.x >= box.x - tolerance && value.x <= right(box) + tolerance &&
  value.y >= box.y - tolerance && value.y <= bottom(box) + tolerance;
const containsBounds = (outer, inner, tolerance = 0) =>
  inner.x >= outer.x - tolerance && inner.y >= outer.y - tolerance &&
  right(inner) <= right(outer) + tolerance && bottom(inner) <= bottom(outer) + tolerance;
const distance = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
const gap = (a, b) =>
  Math.hypot(Math.max(a.x - right(b), b.x - right(a), 0), Math.max(a.y - bottom(b), b.y - bottom(a), 0));
const intersects = (a, b) => a.x < right(b) && right(a) > b.x && a.y < bottom(b) && bottom(a) > b.y;
const side = (a, b, c) => Math.sign((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x));
const segmentsCross = (a, b, c, d) => side(a, b, c) !== side(a, b, d) && side(c, d, a) !== side(c, d, b);
const segmentCrossesBox = (a, b, box) => {
  if (containsPoint(box, a) || containsPoint(box, b)) return true;
  const corners = [
    {x: box.x, y: box.y},
    {x: right(box), y: box.y},
    {x: right(box), y: bottom(box)},
    {x: box.x, y: bottom(box)},
  ];
  return corners.some((corner, index) => segmentsCross(a, b, corner, corners[(index + 1) % corners.length]));
};

if (spec.schemaVersion !== 1) add("schema-version", {}, "schemaVersion must be 1");
if (!isBounds({x: 0, y: 0, width: spec.coordinateSystem?.width, height: spec.coordinateSystem?.height})) {
  add("coordinate-system", {}, "coordinateSystem needs a positive width and height");
}
if (spec.renderedFromGeometrySpec !== true) {
  add("geometry-source", {}, "renderedFromGeometrySpec must be true: the components read their coordinates from this file");
}

const elements = new Map();
const ports = new Map();
for (const [index, item] of (spec.elements ?? []).entries()) {
  const id = item.id ?? `elements[${index}]`;
  if (!item.id || !item.role || !isBounds(item.bounds)) {
    add("element-shape", {element: id}, `${id} needs an id, a role, and positive bounds`);
  }
  if (elements.has(id)) add("duplicate-element", {element: id}, `${id} is listed twice`);
  elements.set(id, item);
  for (const port of item.ports ?? []) {
    const key = `${id}:${port.id}`;
    if (!port.id || !isPoint(port) || !["left", "right", "top", "bottom"].includes(port.edge)) {
      add("port-shape", {element: id}, `${key} needs an id, a point, and an edge of left, right, top, or bottom`);
      continue;
    }
    if (ports.has(key)) add("duplicate-port", {element: id}, `${key} is listed twice`);
    ports.set(key, {...port, elementId: id});
    const tolerance = port.tolerance ?? 1;
    if (!isBounds(item.bounds) || !containsPoint(item.bounds, port, tolerance)) {
      add("port-outside-element", {element: id}, `${key} is outside the bounds of ${id}`);
      continue;
    }
    const edge = {left: item.bounds.x, right: right(item.bounds), top: item.bounds.y, bottom: bottom(item.bounds)}[port.edge];
    const actual = port.edge === "left" || port.edge === "right" ? port.x : port.y;
    if (Math.abs(actual - edge) > tolerance) {
      add("port-not-on-edge", {element: id}, `${key} is ${Math.abs(actual - edge).toFixed(2)}px from the ${port.edge} edge`);
    }
  }
}

const portOf = (reference, owner, where) => {
  const key = `${reference?.elementId}:${reference?.portId}`;
  const found = ports.get(key);
  if (!found) add("unknown-port", where, `${owner} names the unknown port ${key}`);
  return found;
};

for (const [index, connector] of (spec.connectors ?? []).entries()) {
  const id = connector.id ?? `connectors[${index}]`;
  const where = {element: id};
  const from = portOf(connector.from, id, where);
  const to = portOf(connector.to, id, where);
  const points = connector.points;
  if (!Array.isArray(points) || points.length < 2 || points.some((item) => !isPoint(item))) {
    add("connector-points", where, `${id} needs at least two points`);
    continue;
  }
  const tolerance = connector.endpointTolerance ?? 1;
  if (from && distance(points[0], from) > tolerance) {
    add("connector-start", where, `${id} starts ${distance(points[0], from).toFixed(2)}px from its source port`);
  }
  if (to && distance(points.at(-1), to) > tolerance) {
    add("connector-end", where, `${id} ends ${distance(points.at(-1), to).toFixed(2)}px from its target port`);
  }
  for (const avoidId of connector.avoid ?? []) {
    const target = elements.get(avoidId);
    if (!target || !isBounds(target.bounds)) {
      add("connector-avoid", where, `${id} avoids the unknown element ${avoidId}`);
      continue;
    }
    if (points.slice(1).some((value, step) => segmentCrossesBox(points[step], value, target.bounds))) {
      add("connector-collision", where, `${id} crosses ${avoidId}`);
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
  if (intersects(a.bounds, b.bounds)) {
    add("element-collision", {element: pair}, `${pair} overlap`);
  } else if (finite(rule.minimum) && gap(a.bounds, b.bounds) < rule.minimum) {
    add("element-clearance", {element: pair}, `${pair} are ${gap(a.bounds, b.bounds).toFixed(2)}px apart, below ${rule.minimum}px`);
  }
}

for (const [index, arrival] of (spec.arrivals ?? []).entries()) {
  const id = arrival.id ?? `arrivals[${index}]`;
  const where = {element: id, frame: arrival.frame};
  if (!Number.isInteger(arrival.frame) || arrival.frame < 0) {
    add("arrival-frame", where, `${id} needs a frame that is a whole number from 0`);
  }
  const target = arrival.target ? portOf(arrival.target, id, where) : null;
  const tolerance = arrival.tolerance ?? 1;
  if (!isPoint(arrival.actualPoint)) add("arrival-point", where, `${id} needs the actualPoint it reaches`);
  else if (target && distance(arrival.actualPoint, target) > tolerance) {
    add("arrival-miss", where, `${id} stops ${distance(arrival.actualPoint, target).toFixed(2)}px from its target at frame ${arrival.frame}`);
  }
  if (arrival.targetZone || arrival.actualBounds) {
    if (!isBounds(arrival.targetZone) || !isBounds(arrival.actualBounds)) {
      add("arrival-bounds", where, `${id} needs both targetZone and actualBounds as positive bounds`);
    } else if (!containsBounds(arrival.targetZone, arrival.actualBounds, tolerance)) {
      add("arrival-outside-target", where, `${id} ends outside its targetZone at frame ${arrival.frame}`);
    }
  }
}

const scales = spec.review?.scales ?? [];
if (!scales.includes(1) || !scales.includes(0.5)) add("review-scales", {}, "review.scales must include 1 and 0.5");
if (!Array.isArray(spec.review?.frames) || spec.review.frames.length < 3) {
  add("review-frames", {}, "review.frames needs at least an entry, an operation, and a settled frame");
}

const result = {check: "svg-geometry", decision: issues.length ? "revise" : "pass", issueCount: issues.length, source, issues};
console.log(JSON.stringify(result, null, 2));
process.exit(issues.length ? 1 : 0);
