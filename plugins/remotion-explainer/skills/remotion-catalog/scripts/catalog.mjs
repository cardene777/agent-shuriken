#!/usr/bin/env node
// Fetches outside Remotion examples into the plugin's data folder and searches them one layer at a time.
// sync   fetches each listed source at its pinned commit with git, after checking that its license is one
//        that allows the use, and leaves out a source whose license evidence is missing at that commit
// build  indexes the fetched sources by form, composition, typography, and motion into catalog.json
// search returns the entries of one layer that match the words, each with its source and file
// It never runs code from a source, and writes only under
// ${REMOTION_EXPLAINER_HOME:-~/.local/share/remotion-explainer}/catalog, readable only by the user.
// Prints one JSON object. Exits 0 when it did everything, 1 when sync left a source out, and 2 when
// called wrongly or a file could not be read.
import {execFileSync} from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {fileURLToPath} from "node:url";

process.umask(0o077);
const usage = [
  "usage: catalog.mjs sync [--sources <file>]",
  "       catalog.mjs build [--sources <file>]",
  "       catalog.mjs search --layer <form|composition|typography|motion> [--limit <n>] <words>...",
].join("\n");
const wrong = (message) => {
  console.error(message);
  console.error(usage);
  process.exit(2);
};
const print = (data) => console.log(JSON.stringify(data, null, 2));

const skill = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const home = process.env.REMOTION_EXPLAINER_HOME || path.join(os.homedir(), ".local", "share", "remotion-explainer");
const catalogDir = path.join(home, "catalog");
const sourcesDir = path.join(catalogDir, "sources");
const catalogFile = path.join(catalogDir, "catalog.json");
const LAYERS = ["form", "composition", "typography", "motion"];
const ALLOWED = ["MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC", "0BSD", "CC0-1.0", "Unlicense"];

const [command, ...rest] = process.argv.slice(2);
const flags = {};
const words = [];
for (let index = 0; index < rest.length; index += 1) {
  const arg = rest[index];
  if (["--sources", "--layer", "--limit"].includes(arg)) {
    if (rest[index + 1] === undefined) wrong(`${arg} needs a value`);
    flags[arg.slice(2)] = rest[++index];
  } else if (arg.startsWith("--")) wrong(`unknown option: ${arg}`);
  else words.push(arg);
}

const makeDir = (dir) => {
  fs.mkdirSync(dir, {recursive: true, mode: 0o700});
  fs.chmodSync(dir, 0o700);
};
const readJson = (file) => {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (error) {
    console.error(`cannot read ${file}: ${error.message}`);
    process.exit(2);
  }
};
const toPosix = (value) => value.split(path.sep).join("/");
const inside = (value) => typeof value === "string" && value !== "" && !path.isAbsolute(value) && !value.split(/[\\/]/).includes("..");
// True when rel names a path inside root that is reached through no symbolic link, so a source cannot
// point the catalog at a file outside it.
const within = (root, rel) => {
  if (rel !== "." && !inside(rel)) return false;
  try {
    return fs.realpathSync(path.join(root, rel)) === path.resolve(fs.realpathSync(root), rel);
  } catch {
    return false;
  }
};
const fileWithin = (root, rel) => inside(rel) && within(root, rel) && fs.lstatSync(path.join(root, rel)).isFile();
// Lists the regular files under dir, skipping .git and every symbolic link.
const walk = (dir, keep) => {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir, {withFileTypes: true}).sort((a, b) => a.name.localeCompare(b.name)).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return entry.name === ".git" ? [] : walk(full, keep);
    return entry.isFile() && keep(full) ? [full] : [];
  });
};

function readSources() {
  const file = path.resolve(flags.sources ?? path.join(skill, "data", "sources.json"));
  const list = readJson(file);
  if (list.schemaVersion !== 1 || !Array.isArray(list.sources)) wrong(`${file} is not a source list of schemaVersion 1`);
  return list.sources;
}

// Returns why a source may not be fetched, or null.
function refusal(source) {
  if (!/^[a-z0-9][a-z0-9-]*$/.test(source.id ?? "")) return "the id must be lowercase words joined by -";
  if (!/^(https|file):\/\/\S+$/.test(source.repository ?? "")) return "the repository must be an https or file address";
  if (!/^[0-9a-f]{40}$/.test(source.commit ?? "")) return "the commit is not pinned to a full commit hash";
  if (!ALLOWED.includes(source.license)) {
    return `the license ${source.license ?? "(none)"} is not one that allows the use; allowed are ${ALLOWED.join(", ")}`;
  }
  if (!inside(String(source.licenseEvidence ?? "").split("#")[0])) return "the license evidence must be a path inside the repository";
  if (!["files", "cards"].includes(source.adapter?.kind)) return "the adapter kind must be files or cards";
  if (source.exclude !== undefined && (!Array.isArray(source.exclude) || !source.exclude.every(inside))) {
    return "exclude must list paths inside the repository";
  }
  return null;
}

const git = (dir, args) => execFileSync("git", ["-c", "core.hooksPath=/dev/null", "-c", "advice.detachedHead=false", ...args], {
  cwd: dir,
  env: {...process.env, GIT_TERMINAL_PROMPT: "0"},
  stdio: ["ignore", "pipe", "pipe"],
}).toString().trim();
const headOf = (dir) => {
  try {
    return git(dir, ["rev-parse", "HEAD"]);
  } catch {
    return null;
  }
};
const sparseOf = (source) => source.exclude?.length
  ? `/*\n${source.exclude.map((item) => `!/${item.replace(/^\/+/, "")}`).join("\n")}\n`
  : null;

function fetchSource(source, dir) {
  const sparse = sparseOf(source);
  const sparseFile = path.join(dir, ".git", "info", "sparse-checkout");
  const current = fs.existsSync(sparseFile) ? fs.readFileSync(sparseFile, "utf8") : null;
  if (headOf(dir) === source.commit && current === sparse) return;
  fs.rmSync(dir, {recursive: true, force: true});
  makeDir(dir);
  git(dir, ["init", "-q"]);
  git(dir, ["remote", "add", "origin", source.repository]);
  if (sparse) {
    git(dir, ["config", "core.sparseCheckout", "true"]);
    fs.mkdirSync(path.dirname(sparseFile), {recursive: true});
    fs.writeFileSync(sparseFile, sparse);
  }
  git(dir, ["fetch", "-q", "--depth", "1", "--no-tags", "origin", source.commit]);
  git(dir, ["checkout", "-q", "--detach", source.commit]);
  if (headOf(dir) !== source.commit) throw new Error(`the checkout is not at ${source.commit}`);
}

function sync() {
  const sources = readSources();
  makeDir(home);
  makeDir(catalogDir);
  makeDir(sourcesDir);
  const fetched = [];
  const leftOut = [];
  for (const source of sources) {
    const id = source.id ?? "(no id)";
    const reason = refusal(source);
    if (reason) {
      leftOut.push({id, reason});
      continue;
    }
    const dir = path.join(sourcesDir, source.id);
    try {
      fetchSource(source, dir);
    } catch (error) {
      fs.rmSync(dir, {recursive: true, force: true});
      const detail = String(error.stderr ?? error.message).trim().split("\n").at(-1);
      leftOut.push({id, reason: `git could not fetch it at the pinned commit: ${detail}`});
      continue;
    }
    if (!fileWithin(dir, source.licenseEvidence.split("#")[0])) {
      fs.rmSync(dir, {recursive: true, force: true});
      leftOut.push({id, reason: `the license evidence ${source.licenseEvidence} is missing at the pinned commit`});
      continue;
    }
    fetched.push({id, commit: source.commit, license: source.license, folder: dir});
  }
  const listed = new Set(sources.map((source) => source.id));
  const unlisted = fs.readdirSync(sourcesDir).filter((name) => !listed.has(name));
  print({command: "sync", folder: catalogDir, fetched, leftOut, unlisted});
  process.exit(leftOut.length ? 1 : 0);
}

// Tags of the four layers, read from the words of an entry. A layer with no tag is not offered for it.
const RULES = {
  form: [
    ["illustration", /illustrat|character|avatar|mascot|person|people/],
    ["document", /document|paper|invoice|receipt|ticket|card/],
    ["device-screen", /phone|device|screen|browser|dashboard|laptop|monitor|\bui\b/],
    ["diagram", /diagram|flow|network|node|chart|graph|path|route|\bmap\b/],
    ["media", /image|photo|video|gallery|media|footage/],
    ["symbolic-shape", /shape|morph|polygon|circle|rect|icon|logo/],
  ],
  composition: [
    ["comparison", /compar|before.?after|split.?screen|side.?by.?side|versus/],
    ["sequence", /sequence|stagger|step|list|timeline/],
    ["path-flow", /path|route|bezier|travel|flow|converge/],
    ["transformation", /morph|transform|materiali|assemble|fracture/],
    ["camera-stage", /camera|zoom|\bpan\b|orbit|perspective|\b3d\b/],
    ["data-display", /chart|counter|progress|gauge|metric|\bdata\b/],
    ["media-frame", /image|photo|video|gallery|footage/],
    ["interface-demonstration", /\bui\b|panel|dashboard|cursor|input|interface/],
    ["layered-depth", /depth|parallax|layer|stack|carousel|pile/],
  ],
  typography: [
    ["title", /title|headline|heading/],
    ["caption", /caption|subtitle/],
    ["label", /label|\btag\b|badge/],
    ["body-text", /\btext\b|\bwords?\b|letter|paragraph|font|typograph|typewriter/],
  ],
  motion: [
    ["reveal", /reveal|appear|fade|wipe|draw|typewriter/],
    ["translate", /slide|move|\bpan\b|travel|fly|push/],
    ["scale", /scale|zoom|grow|shrink|pulse|expand/],
    ["rotate-3d", /rotate|flip|\b3d\b|orbit|spin/],
    ["path-trace", /path|stroke|bezier|trace|underline|dash/],
    ["shape-change", /morph|fracture|split|assemble|materiali/],
    ["focus-effect", /blur|glow|spotlight|focus|vignette/],
    ["rhythmic-stagger", /stagger|rhythm|beat|sequence|cascade/],
  ],
};
const layersOf = (text) => {
  const lower = text.toLowerCase();
  return Object.fromEntries(LAYERS.map((layer) => [layer, RULES[layer].filter(([, rule]) => rule.test(lower)).map(([tag]) => tag)]));
};

function indexFiles(source, root) {
  const adapter = source.adapter;
  const metadata = new Map();
  const readme = fileWithin(root, adapter.readme) ? path.join(root, adapter.readme) : null;
  if (readme) {
    let category = "";
    for (const line of fs.readFileSync(readme, "utf8").split(/\r?\n/)) {
      const heading = line.match(/^#{2,4}\s+(.+?)(?:\s+\(\d+\))?\s*$/);
      if (heading) category = heading[1];
      const row = line.match(/^\|\s*([^|]+?)\s*\|\s*`([^`]+)`\s*\|\s*([^|]+?)\s*\|\s*$/);
      if (row) metadata.set(path.basename(row[2]), {title: row[1], description: row[3], category});
    }
  }
  const folder = path.join(root, inside(adapter.folder) ? adapter.folder : ".");
  if (!within(root, path.relative(root, folder) || ".")) return [];
  const extension = adapter.extension ?? ".tsx";
  return walk(folder, (file) => file.endsWith(extension)).map((file) => {
    const rel = toPosix(path.relative(root, file));
    const name = toPosix(path.relative(folder, file)).slice(0, -extension.length).split("/").join("-");
    const meta = metadata.get(path.basename(file)) ?? {title: name.split("-").join(" "), description: "", category: ""};
    const code = fs.readFileSync(file, "utf8");
    return {
      id: `${source.id}:${name}`, title: meta.title, description: meta.description, category: meta.category,
      tags: [], file: rel, files: [rel], layers: layersOf(`${meta.title} ${meta.description} ${meta.category} ${rel} ${code}`),
    };
  });
}

function indexCards(source, root) {
  const adapter = source.adapter;
  if (!fileWithin(root, adapter.library) || !inside(adapter.demos)) return [];
  const libraryFile = path.join(root, adapter.library);
  const library = JSON.parse(fs.readFileSync(libraryFile, "utf8"));
  return (Array.isArray(library.cards) ? library.cards : []).flatMap((card) => {
    const plain = (value) => typeof value === "string" && /^[\w-][\w.-]*$/.test(value);
    if (!plain(card.category) || !plain(card.name)) return [];
    const demo = path.join(root, adapter.demos, card.category, card.name);
    const documentation = fileWithin(root, card.source) ? card.source : undefined;
    const files = !within(root, path.relative(root, demo)) ? [] : walk(demo, (file) => /\.(tsx|ts|json|svg)$/i.test(file)).map((file) => toPosix(path.relative(root, file)));
    const main = files.find((file) => file.endsWith(".tsx")) ?? files[0] ?? documentation;
    if (!main) return [];
    const code = files.filter((file) => /\.tsx?$/.test(file)).map((file) => fs.readFileSync(path.join(root, file), "utf8")).join("\n");
    const tags = Array.isArray(card.tags) ? card.tags.map(String) : [];
    const styles = Array.isArray(card.styles) && card.styles.length ? card.styles : [{key: card.name, label: card.name}];
    return styles.map((style) => ({
      id: `${source.id}:${style.key}`, title: style.label || style.key,
      description: style.description || card.summary || "", category: card.category, tags,
      file: main, files, documentation,
      layers: layersOf([card.name, card.summary, card.use, card.category, ...tags, style.key, style.label, style.description, code].filter(Boolean).join(" ")),
    }));
  });
}

function build() {
  const sources = readSources();
  makeDir(home);
  makeDir(catalogDir);
  const items = [];
  const skipped = [];
  for (const source of sources) {
    const id = source.id ?? "(no id)";
    const reason = refusal(source);
    const dir = reason ? null : path.join(sourcesDir, source.id);
    if (reason) skipped.push({id, reason});
    else if (headOf(dir) !== source.commit || !fileWithin(dir, source.licenseEvidence.split("#")[0])) {
      skipped.push({id, reason: "it is not fetched at its pinned commit; run sync first"});
    } else {
      let found = null;
      try {
        found = source.adapter.kind === "files" ? indexFiles(source, dir) : indexCards(source, dir);
      } catch (error) {
        skipped.push({id, reason: `its files could not be read: ${error.message.split("\n")[0]}`});
      }
      for (const item of found ?? []) {
        items.push({...item, source: source.id, repository: source.repository, commit: source.commit, license: source.license});
      }
    }
  }
  items.sort((a, b) => a.id.localeCompare(b.id));
  const catalog = {
    schemaVersion: 1,
    builtAt: new Date().toISOString(),
    sources: sources.filter((source) => !skipped.some((item) => item.id === source.id))
      .map(({id, repository, commit, license}) => ({id, repository, commit, license})),
    items,
  };
  fs.writeFileSync(catalogFile, `${JSON.stringify(catalog, null, 2)}\n`, {mode: 0o600});
  fs.chmodSync(catalogFile, 0o600);
  const bySource = Object.fromEntries(catalog.sources.map(({id}) => [id, items.filter((item) => item.source === id).length]));
  print({command: "build", catalog: catalogFile, items: items.length, bySource, skipped});
  process.exit(0);
}

function search() {
  const layer = flags.layer;
  if (!LAYERS.includes(layer)) wrong(`--layer must be one of ${LAYERS.join(", ")}`);
  const limit = flags.limit === undefined ? 12 : Number(flags.limit);
  if (!Number.isInteger(limit) || limit < 1) wrong("--limit must be a whole number from 1");
  const query = words.join(" ");
  const tokens = [...new Set(query.toLowerCase().split(/[^a-z0-9-]+/).filter((token) => token.length >= 2))];
  if (!tokens.length) wrong("give the words to search for, in English");
  if (!fs.existsSync(catalogFile)) wrong(`there is no catalog at ${catalogFile}; run sync and build first`);
  const catalog = readJson(catalogFile);
  const results = (catalog.items ?? [])
    .filter((item) => item.layers?.[layer]?.length)
    .map((item) => {
      const tags = item.layers[layer];
      const text = [item.id, item.title, item.description, item.category, item.file, ...(item.tags ?? []),
        ...LAYERS.flatMap((name) => item.layers[name] ?? [])].join(" ").toLowerCase();
      let score = 0;
      const why = [];
      for (const token of tokens) {
        const tagged = tags.some((tag) => tag.includes(token));
        const named = text.includes(token);
        score += (tagged ? 20 : 0) + (named ? 7 : 0);
        if (tagged || named) why.push(token);
      }
      return {
        id: item.id, source: item.source, title: item.title, description: item.description, category: item.category,
        file: item.file, path: path.join(sourcesDir, item.source, item.file), files: item.files, layers: item.layers,
        score, why, license: item.license, repository: item.repository, commit: item.commit,
      };
    })
    .filter((item) => item.score > 0)
    .sort((a, b) => b.score - a.score || a.id.localeCompare(b.id))
    .slice(0, limit);
  print({command: "search", layer, query, catalog: catalogFile, results});
  process.exit(0);
}

if (command === "sync" && !words.length && !flags.layer && !flags.limit) sync();
else if (command === "build" && !words.length && !flags.layer && !flags.limit) build();
else if (command === "search" && !flags.sources) search();
else wrong(command ? `unknown command or option for ${command}` : "give a command");
