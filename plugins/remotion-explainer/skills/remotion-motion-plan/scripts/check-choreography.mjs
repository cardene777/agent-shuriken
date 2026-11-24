#!/usr/bin/env node
// Checks a storyboard/choreography-plan.json against the choreography contract (formats/choreography.md):
// each scene has a view grammar, a camera for entry, operation, and result, objects that appear when
// they are needed and change state, at least two kinds of motion, review frames, and a rough cut that
// matches the final cut in everything but the art. Neighboring scenes use different grammars.
// Prints the result as JSON. Exits 0 when it passes, 1 when the plan needs revising, 2 when called wrongly.
import fs from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
if (args.length !== 1 || args[0].startsWith("-")) {
  console.error("usage: check-choreography.mjs <choreography-plan.json>");
  process.exit(2);
}
const source = path.resolve(args[0]);
let plan;
try {
  plan = JSON.parse(fs.readFileSync(source, "utf8"));
} catch (error) {
  console.error(`cannot read ${args[0]}: ${error.message}`);
  process.exit(2);
}

const grammars = new Set([
  "overview", "inspection", "state-machine", "branching", "comparison", "aggregation",
  "history", "exception-recovery", "return-path", "progressive-reveal", "horizontal-exchange",
]);
const motionKinds = new Set([
  "reveal", "spatial-route", "transform", "state-transition", "branch", "aggregate", "compare", "camera-reframe", "handoff",
]);
const moments = new Set(["entry", "operation", "result"]);
const parity = ["camera", "blocking", "revealOrder", "objectRoutes", "transforms", "handoff"];
const issues = [];
const add = (rule, where, message) => issues.push({rule, ...where, message});
const empty = (value) => value === undefined || value === null || value === "" || (Array.isArray(value) && value.length === 0);

if (plan.schemaVersion !== 1) add("schema-version", {}, "schemaVersion must be 1");
const scenes = Array.isArray(plan.scenes) ? plan.scenes : [];
if (scenes.length < 2) add("scenes", {}, "list at least two scenes");

let exchanges = 0;
const used = new Set();
for (const [index, scene] of scenes.entries()) {
  const id = scene.id ?? `scenes[${index}]`;
  const where = {scene: id};
  for (const key of ["id", "viewGrammar", "viewerQuestion", "camera", "objectLifecycles", "motionBeats", "handoff", "reviewFrames", "finalMotionParity"]) {
    if (empty(scene[key])) add("scene-field", where, `${id} has no ${key}`);
  }
  if (!grammars.has(scene.viewGrammar)) add("view-grammar", where, `${id} uses the unknown view grammar ${scene.viewGrammar}`);
  used.add(scene.viewGrammar);
  if (scene.viewGrammar === "horizontal-exchange") exchanges += 1;
  for (const key of ["entry", "operation", "result", "movement"]) {
    if (empty(scene.camera?.[key])) add("camera-field", where, `${id} has no camera.${key}`);
  }
  for (const key of parity) {
    if (scene.finalMotionParity?.[key] !== true) {
      add("motion-parity", where, `${id}: finalMotionParity.${key} must be true; the rough cut differs from the final cut`);
    }
  }
  const lifecycles = Array.isArray(scene.objectLifecycles) ? scene.objectLifecycles : [];
  let late = false;
  let changed = false;
  for (const [n, item] of lifecycles.entries()) {
    for (const key of ["object", "role", "entryState", "introducedAt", "operation", "resultState", "resultAt", "sourceZone", "targetZone"]) {
      if (empty(item[key])) add("lifecycle-field", where, `${id}: object ${item.object ?? n + 1} has no ${key}`);
    }
    for (const key of ["introducedAt", "resultAt"]) {
      if (!empty(item[key]) && !moments.has(item[key])) {
        add("lifecycle-moment", where, `${id}: ${key} of ${item.object} must be entry, operation, or result`);
      }
    }
    if (item.introducedAt && item.introducedAt !== "entry") late = true;
    if (item.entryState !== item.resultState) changed = true;
  }
  if (lifecycles.length && !late) {
    add("no-late-introduction", where, `${id} places every object at entry; bring one in when the explanation needs it`);
  }
  if (lifecycles.length && !changed) add("no-state-change", where, `${id} ends with every object in the state it started in`);
  const beats = Array.isArray(scene.motionBeats) ? scene.motionBeats : [];
  for (const beat of beats) {
    if (!motionKinds.has(beat.kind)) add("motion-kind", where, `${id} uses the unknown motion kind ${beat.kind}`);
    if (empty(beat.subject) || empty(beat.effect)) add("motion-beat-field", where, `${id}: every motion beat needs a subject and an effect`);
  }
  if (new Set(beats.map((beat) => beat.kind)).size < 2) add("motion-variety", where, `${id} needs at least two kinds of motion`);
  for (const frame of moments) {
    if (!Array.isArray(scene.reviewFrames) || !scene.reviewFrames.includes(frame)) {
      add("review-frames", where, `${id}: reviewFrames must include ${frame}`);
    }
  }
  const previous = scenes[index - 1];
  if (previous && scene.viewGrammar && previous.viewGrammar === scene.viewGrammar) {
    add("repeated-view-grammar", where, `${previous.id} and ${id} both use ${scene.viewGrammar}`);
  }
}
if (exchanges > 2) add("horizontal-exchange-limit", {}, `horizontal-exchange is used in ${exchanges} scenes; at most two may use it`);
const needed = Math.min(4, scenes.length);
if (scenes.length >= 2 && used.size < needed) {
  add("view-grammar-variety", {}, `the plan uses ${used.size} view grammars; ${scenes.length} scenes need at least ${needed}`);
}

const result = {check: "choreography", decision: issues.length ? "revise" : "pass", issueCount: issues.length, source, issues};
console.log(JSON.stringify(result, null, 2));
process.exit(issues.length ? 1 : 0);
