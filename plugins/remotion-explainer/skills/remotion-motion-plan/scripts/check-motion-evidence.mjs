#!/usr/bin/env node
// Checks a motion evidence library against the motion evidence contract (formats/motion-evidence.md):
// every entry has a unique id, a status of verified or candidate, a source with its platform, title, and
// address, observations with a time range and what moves, the recipes it shows, when to use and avoid
// it, and the day it was reviewed. A verified entry needs a real time range in every observation.
// Prints the result as JSON. Exits 0 when it passes, 1 when the library needs revising, 2 when called wrongly.
import fs from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
if (args.length !== 1 || args[0].startsWith("-")) {
  console.error("usage: check-motion-evidence.mjs <motion-evidence-library.json>");
  process.exit(2);
}
const source = path.resolve(args[0]);
let library;
try {
  library = JSON.parse(fs.readFileSync(source, "utf8"));
} catch (error) {
  console.error(`cannot read ${args[0]}: ${error.message}`);
  process.exit(2);
}

const issues = [];
const add = (rule, where, message) => issues.push({rule, ...where, message});
const text = (value) => typeof value === "string" && value.trim() !== "";
const range = /^\d{1,2}:\d{2}(:\d{2})?-\d{1,2}:\d{2}(:\d{2})?$/;

if (library.schemaVersion !== 1) add("schema-version", {}, "schemaVersion must be 1");
if (!Array.isArray(library.entries)) add("entries", {}, "entries must be a list, empty for a new library");

const ids = new Set();
for (const [index, entry] of (Array.isArray(library.entries) ? library.entries : []).entries()) {
  const id = entry.id ?? `entries[${index}]`;
  const where = {entry: id};
  for (const key of ["id", "status", "useWhen", "avoidWhen"]) {
    if (!text(entry[key])) add("entry-field", where, `${id} has no ${key}`);
  }
  if (ids.has(id)) add("duplicate-entry", where, `${id} is listed twice`);
  ids.add(id);
  if (!["verified", "candidate"].includes(entry.status)) add("status", where, `${id}: status must be verified or candidate`);
  const from = entry.source ?? {};
  if (!text(from.platform) || !text(from.title) || !/^https?:\/\/\S+$/.test(from.url ?? "")) {
    add("source-shape", where, `${id}: source needs the platform, the title, and the address of the video`);
  }
  const observations = Array.isArray(entry.observations) ? entry.observations : [];
  if (!observations.length) add("observation-shape", where, `${id} has no observation`);
  for (const item of observations) {
    if (!text(item.range) || !text(item.description)) add("observation-shape", where, `${id}: every observation needs a range and a description`);
    else if (entry.status === "verified" && !range.test(item.range)) {
      add("verified-without-range", where, `${id} is verified, but the range ${item.range} is not a time range such as 00:13-00:45`);
    }
  }
  if (!Array.isArray(entry.recipes) || !entry.recipes.length || !entry.recipes.every(text)) {
    add("recipes", where, `${id} names no recipe it shows`);
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(entry.reviewedAt ?? "")) add("reviewed-at", where, `${id}: reviewedAt must be a day such as 2026-11-24`);
}

const result = {check: "motion-evidence", decision: issues.length ? "revise" : "pass", issueCount: issues.length, source, issues};
console.log(JSON.stringify(result, null, 2));
process.exit(issues.length ? 1 : 0);
