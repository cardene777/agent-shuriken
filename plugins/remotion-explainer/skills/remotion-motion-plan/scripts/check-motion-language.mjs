#!/usr/bin/env node
// Checks a storyboard/motion-language-plan.json against the motion language contract
// (formats/motion-language.md) and the user's motion evidence library: each scene picks one main recipe
// from the catalog, cites a verified library entry that shows it, names the Remotion mechanism, and
// keeps entry, operation, and result frames. Neighboring scenes use different recipes.
// Prints the result as JSON. Exits 0 when it passes, 1 when the plan needs revising, 2 when called wrongly.
import fs from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
if (args.length !== 2 || args.some((arg) => arg.startsWith("-"))) {
  console.error("usage: check-motion-language.mjs <motion-language-plan.json> <motion-evidence-library.json>");
  process.exit(2);
}
const read = (file) => {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (error) {
    console.error(`cannot read ${file}: ${error.message}`);
    process.exit(2);
  }
};
const source = path.resolve(args[0]);
const plan = read(args[0]);
const library = read(args[1]);

const recipes = new Set([
  "focus-push", "object-handoff", "morph-state", "build-through", "branch-prune", "aggregate-into-container",
  "reveal-through-mask", "parallel-contrast", "spatial-journey", "live-inspection", "character-causes-system", "return-and-resolve",
]);
const mechanisms = new Set(["spring-interpolate", "svg-paths", "motion-blur", "transitions", "three", "lottie", "rive", "css-mask", "asset-sequence"]);
const evidence = new Map((Array.isArray(library.entries) ? library.entries : []).map((entry) => [entry.id, entry]));
const issues = [];
const add = (rule, where, message) => issues.push({rule, ...where, message});
const text = (value) => typeof value === "string" && value.trim() !== "";

if (plan.schemaVersion !== 1) add("schema-version", {}, "schemaVersion must be 1");
const scenes = Array.isArray(plan.scenes) ? plan.scenes : [];
if (scenes.length < 2) add("scenes", {}, "list at least two scenes");

const primary = new Set();
let handoffs = 0;
for (const [index, scene] of scenes.entries()) {
  const id = scene.id ?? `scenes[${index}]`;
  const where = {scene: id};
  for (const key of ["id", "viewerQuestion", "primaryRecipe", "visualReason", "officialMechanism", "entry", "operation", "result"]) {
    if (!text(scene[key])) add("scene-field", where, `${id} has no ${key}`);
  }
  if (!recipes.has(scene.primaryRecipe)) add("recipe", where, `${id} uses the unknown primaryRecipe ${scene.primaryRecipe}`);
  if (scene.supportingRecipe !== undefined && !recipes.has(scene.supportingRecipe)) {
    add("recipe", where, `${id} uses the unknown supportingRecipe ${scene.supportingRecipe}`);
  }
  if (scene.supportingRecipe && scene.supportingRecipe === scene.primaryRecipe) {
    add("supporting-duplicates-primary", where, `${id}: the supporting recipe repeats the primary recipe`);
  }
  if (!mechanisms.has(scene.officialMechanism)) add("mechanism", where, `${id} names the unknown officialMechanism ${scene.officialMechanism}`);
  const ids = Array.isArray(scene.evidenceIds) ? scene.evidenceIds : [];
  if (!ids.length) {
    add("missing-evidence", where, `${id} cites no entry of the motion evidence library`);
  } else {
    for (const ref of ids) {
      if (!evidence.has(ref)) add("unknown-evidence", where, `${id} cites ${ref}, which the library does not hold`);
    }
    const shown = ids.map((ref) => evidence.get(ref)).filter(Boolean)
      .some((entry) => entry.status === "verified" && Array.isArray(entry.recipes) && entry.recipes.includes(scene.primaryRecipe));
    if (!shown && ids.every((ref) => evidence.has(ref))) {
      add("unverified-evidence", where, `${id}: no verified entry it cites shows ${scene.primaryRecipe}`);
    }
  }
  if (!Array.isArray(scene.proofFrames) || !["entry", "operation", "result"].every((frame) => scene.proofFrames.includes(frame))) {
    add("proof-frames", where, `${id}: proofFrames must include entry, operation, and result`);
  }
  const previous = scenes[index - 1];
  if (previous && scene.primaryRecipe && previous.primaryRecipe === scene.primaryRecipe) {
    add("repeated-recipe", where, `${previous.id} and ${id} both use ${scene.primaryRecipe}`);
  }
  if (scene.primaryRecipe === "object-handoff") handoffs += 1;
  primary.add(scene.primaryRecipe);
}
if (scenes.length >= 8 && primary.size < 6) add("recipe-variety", {}, `a plan of ${scenes.length} scenes uses ${primary.size} main recipes; it needs six`);
if (handoffs > 2) add("object-handoff-limit", {}, `object-handoff is the main recipe of ${handoffs} scenes; at most two may use it`);

const result = {check: "motion-language", decision: issues.length ? "revise" : "pass", issueCount: issues.length, source, issues};
console.log(JSON.stringify(result, null, 2));
process.exit(issues.length ? 1 : 0);
