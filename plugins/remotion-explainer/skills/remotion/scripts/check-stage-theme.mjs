#!/usr/bin/env node
// Checks the stage theme of a production.json against the stage theme contracts (formats/art-direction.md and
// formats/felt-applique.md): when artDirection.stageTheme is set, it is felt-applique, its assetStyleId equals
// its id, it allows every felt-applique primitive, its four policies are concrete, and visual.staticAssets holds
// reviewed subject PNGs that all use the theme's assetStyleId. A record without a stage theme passes.
// Prints the result as JSON. Exits 0 when it passes, 1 when the record needs revising, and 2 when called
// wrongly or the file cannot be read.
import fs from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
if (args.length !== 1 || args[0].startsWith("-")) {
  console.error("usage: check-stage-theme.mjs <production.json>");
  process.exit(2);
}
const source = path.resolve(args[0]);
let project;
try {
  project = JSON.parse(fs.readFileSync(source, "utf8"));
} catch (error) {
  console.error(`cannot read ${args[0]}: ${error.message}`);
  process.exit(2);
}

const issues = [];
const add = (rule, where, message) => issues.push({rule, ...where, message});
const theme = project?.artDirection?.stageTheme;
const assets = project?.visual?.staticAssets;
const primitives = ["felt-board", "felt-pocket", "felt-tag", "felt-connector", "annotation"];

if (theme) {
  const field = "artDirection.stageTheme";
  if (theme.id !== "felt-applique") add("stage-theme-id", {field: `${field}.id`}, `the stage theme ${String(theme.id)} is not supported; only felt-applique is`);
  if (theme.assetStyleId !== theme.id) add("asset-style-id", {field: `${field}.assetStyleId`}, "assetStyleId must equal the stage theme's id");
  if (!Array.isArray(theme.stagePrimitives) || primitives.some((primitive) => !theme.stagePrimitives.includes(primitive))) {
    add("stage-primitives", {field: `${field}.stagePrimitives`}, `felt-applique needs the stagePrimitives ${primitives.join(", ")}`);
  }
  for (const key of ["containerPolicy", "labelPolicy", "connectorPolicy", "tracePolicy"]) {
    if (typeof theme[key] !== "string" || theme[key].trim().length < 12) {
      add("stage-policy", {field: `${field}.${key}`}, `${key} must state a concrete policy of at least 12 characters`);
    }
  }
  if (!Array.isArray(assets) || assets.length === 0) {
    add("static-assets", {field: "visual.staticAssets"}, "a stage theme needs reviewed subject PNGs in visual.staticAssets");
  } else {
    for (const [index, asset] of assets.entries()) {
      if (asset?.styleId !== theme.assetStyleId) {
        add("asset-style", {field: `visual.staticAssets[${index}].styleId`},
          `${String(asset?.assetId ?? index)} uses the style ${String(asset?.styleId)}, not ${String(theme.assetStyleId)}; split the project instead of mixing art materials`);
      }
    }
  }
}

const result = {
  check: "stage-theme",
  decision: issues.length ? "revise" : "pass",
  issueCount: issues.length,
  source,
  stageTheme: theme ? String(theme.id) : null,
  staticAssetCount: Array.isArray(assets) ? assets.length : 0,
  issues,
};
console.log(JSON.stringify(result, null, 2));
process.exit(issues.length ? 1 : 0);
