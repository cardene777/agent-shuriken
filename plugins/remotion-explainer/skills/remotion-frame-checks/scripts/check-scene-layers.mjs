#!/usr/bin/env node
// Checks a storyboard/scene-design-layers.json against the four-layer scene contract
// (formats/scene-layers.md): every scene chooses its form, composition, typography, and motion apart,
// each layer says where it came from, and no two scenes in a row repeat the same design.
// Prints the result as JSON. Exits 0 when it passes, 1 when the file needs revising, 2 when called wrongly.
import fs from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
if (args.length !== 1 || args[0].startsWith("-")) {
  console.error("usage: check-scene-layers.mjs <scene-design-layers.json>");
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
const layers = ["form", "composition", "typography", "motion"];
const signature = ["silhouetteFamily", "spatialGrammar", "revealGrammar"];

if (spec.schemaVersion !== 1) add("schema-version", {}, "schemaVersion must be 1");
if (!Array.isArray(spec.scenes) || spec.scenes.length < 2) add("scenes", {}, "list at least two scenes");

for (const [index, scene] of (spec.scenes ?? []).entries()) {
  const id = scene.id ?? `scenes[${index}]`;
  const where = {scene: id};
  if (!scene.id) add("scene-id", where, `${id} needs an id`);
  if (!scene.viewerQuestion) add("viewer-question", where, `${id} needs the viewerQuestion the scene answers`);
  for (const layer of layers) {
    const choice = scene[layer];
    if (!choice) {
      add("missing-layer", where, `${id} has no ${layer} layer`);
      continue;
    }
    if (!["catalog", "bespoke", "none"].includes(choice.mode)) {
      add("layer-mode", where, `${id}: ${layer}.mode must be catalog, bespoke, or none`);
    } else if (choice.mode === "catalog" && (!choice.id || !choice.adaptation)) {
      add("catalog-selection", where, `${id}: ${layer} from the catalog needs the entry id and what was adapted`);
    } else if (choice.mode === "bespoke" && !choice.rationale) {
      add("bespoke-selection", where, `${id}: a bespoke ${layer} needs the rationale for not using a catalog entry`);
    } else if (choice.mode === "none" && layer !== "typography") {
      add("missing-required-layer", where, `${id}: only typography may be none, not ${layer}`);
    }
  }
  for (const key of signature) {
    if (!scene[key]) add("design-signature", where, `${id} needs ${key}`);
  }
  const previous = spec.scenes[index - 1];
  if (previous && signature.every((key) => scene[key] && previous[key] === scene[key])) {
    add("repeated-design-system", where,
      `${previous.id} and ${id} repeat the same silhouette family, spatial grammar, and reveal grammar`);
  }
}

const result = {check: "scene-layers", decision: issues.length ? "revise" : "pass", issueCount: issues.length, source, issues};
console.log(JSON.stringify(result, null, 2));
process.exit(issues.length ? 1 : 0);
