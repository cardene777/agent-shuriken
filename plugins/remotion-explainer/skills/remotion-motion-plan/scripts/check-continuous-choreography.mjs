#!/usr/bin/env node
// Checks a storyboard/continuous-choreography-plan.json against the continuous choreography contract
// (formats/continuous-choreography.md): each scene takes over the subject the scene before it handed on,
// at least half of the scenes hold a subject followed through the whole video, neighboring scenes do
// not move along the same axis, every three scenes in a row change a form or the view, and the summary
// uses only subjects that appeared before it.
// Prints the result as JSON. Exits 0 when it passes, 1 when the plan needs revising, 2 when called wrongly.
import fs from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
if (args.length !== 1 || args[0].startsWith("-")) {
  console.error("usage: check-continuous-choreography.mjs <continuous-choreography-plan.json>");
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

const cameraRelations = new Set(["push-in", "pull-out", "orbit", "follow", "reframe"]);
const continuityModes = new Set(["object-transform", "camera-follow", "container-reveal", "spatial-reframe", "state-carry", "return-route"]);
const axes = new Set(["horizontal", "vertical", "none"]);
const changingModes = new Set(["object-transform", "container-reveal", "spatial-reframe"]);
const changingCameras = new Set(["push-in", "pull-out", "orbit"]);
const issues = [];
const add = (rule, where, message) => issues.push({rule, ...where, message});
const text = (value) => typeof value === "string" && value.trim() !== "";
const isHandoff = (value) => value && text(value.subject) && text(value.state);

if (plan.schemaVersion !== 1) add("schema-version", {}, "schemaVersion must be 1");
const scenes = Array.isArray(plan.scenes) ? plan.scenes : [];
if (scenes.length < 2) add("scenes", {}, "list at least two scenes");
const persistent = new Set(Array.isArray(plan.persistentSubjects) ? plan.persistentSubjects : []);
if (!persistent.size) add("persistent-subjects", {}, "persistentSubjects names no subject followed through the video");

const seen = new Set();
let holding = 0;
for (const [index, scene] of scenes.entries()) {
  const id = scene.id ?? `scenes[${index}]`;
  const where = {scene: id};
  const previous = scenes[index - 1];
  if (!text(scene.id)) add("scene-field", where, `${id} has no id`);
  if (!text(scene.operation)) add("scene-field", where, `${id} has no operation`);
  const subjects = Array.isArray(scene.subjects) ? scene.subjects : [];
  if (!subjects.length) add("scene-field", where, `${id} lists no subjects`);
  if (index > 0 && !isHandoff(scene.entryFrom)) add("handoff-shape", where, `${id}: entryFrom needs the subject and the state it takes over`);
  if (index < scenes.length - 1 && !isHandoff(scene.exitTo)) add("handoff-shape", where, `${id}: exitTo needs the subject and the state it hands on`);
  if (!cameraRelations.has(scene.cameraRelation)) add("camera-relation", where, `${id} has the unknown cameraRelation ${scene.cameraRelation}`);
  if (!continuityModes.has(scene.continuityMode)) add("continuity-mode", where, `${id} has the unknown continuityMode ${scene.continuityMode}`);
  if (!axes.has(scene.primaryAxis)) add("primary-axis", where, `${id}: primaryAxis must be horizontal, vertical, or none`);

  if (previous && isHandoff(previous.exitTo) && isHandoff(scene.entryFrom)) {
    const carried = [previous.exitTo.subject, previous.exitTo.becomes].filter(text);
    if (!carried.includes(scene.entryFrom.subject)) {
      add("handoff-not-carried", where,
        `${id} starts from ${scene.entryFrom.subject}, but ${previous.id} hands on ${carried.join(" or ")}; carry the subject instead of clearing the board`);
    }
  }
  if (previous && axes.has(scene.primaryAxis) && scene.primaryAxis !== "none" && previous.primaryAxis === scene.primaryAxis) {
    add("repeated-axis", where, `${previous.id} and ${id} both move mainly ${scene.primaryAxis}ly`);
  }
  if (index >= 2) {
    const window = scenes.slice(index - 2, index + 1);
    if (!window.some((item) => changingModes.has(item.continuityMode) || changingCameras.has(item.cameraRelation))) {
      add("three-scenes-without-change", where,
        `${window.map((item) => item.id).join(", ")} only carry or follow; one of three scenes in a row transforms, opens, gathers, or changes the view`);
    }
  }
  if (scene.role === "summary") {
    const fresh = subjects.filter((subject) => !seen.has(subject));
    if (fresh.length) add("summary-new-subject", where, `${id} brings in ${fresh.join(", ")}, which no earlier scene showed`);
  }
  if (subjects.some((subject) => persistent.has(subject))) holding += 1;
  for (const subject of subjects) seen.add(subject);
  if (isHandoff(scene.exitTo) && text(scene.exitTo.becomes)) seen.add(scene.exitTo.becomes);
}
if (scenes.length >= 2 && holding * 2 < scenes.length) {
  add("persistent-subject-share", {}, `${holding} of ${scenes.length} scenes hold a persistent subject; at least half must`);
}

const result = {check: "continuous-choreography", decision: issues.length ? "revise" : "pass", issueCount: issues.length, source, issues};
console.log(JSON.stringify(result, null, 2));
process.exit(issues.length ? 1 : 0);
