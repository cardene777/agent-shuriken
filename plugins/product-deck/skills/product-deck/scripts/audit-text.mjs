#!/usr/bin/env node
/* Checks the wording of the slides by machine. It reads only the deck data, without opening a
   page, so it runs before rendering.

   Usage
     node audit-text.mjs <deck-data.mjs> [--terms <path>] [--prose-words <path>] [--report <path>]
     node audit-text.mjs --list-checks [--prose-words <path>]   # names of the checks only

   The deck data exports `faces`, an array with one object per slide (`export const faces = [...]`).

   Two word lists are read, and neither ships with the plugin:
     --prose-words  the words to drop from the text, default ~/.product-deck/prose-words.txt
     --terms        the deck's own terms, default ~/.product-deck/writing-terms.txt
   When a list is missing, no check runs and the script exits 2, naming the place it looked.

   Exits 1 when any slide is flagged; fix and run again until none is.
   Exits 2 when a count is 0 (no slide, no term, or a slide without text), because then the
   checks exist but look at nothing, and "0 slides flagged" would mean nothing.

   `audit.mjs` checks the rendered slides (text size, text leaving its box); this checks the
   data (the choice of words and how sentences are built). The checks follow the sections of
   `references/writing-rules.md`. The kind names are read in English and in Japanese, so the
   lists of a Japanese deck can keep their Japanese kind names. */

import { existsSync } from "node:fs";
import { readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const args = process.argv.slice(2);
const pick = (flag, fallback) => {
  const at = args.indexOf(flag);
  return at === -1 ? fallback : args[at + 1];
};
const rest = args.filter((a, i) => !a.startsWith("--") && !args[i - 1]?.startsWith("--"));
const dataPath = rest[0];
const listOnly = args.includes("--list-checks");
if (dataPath === undefined && !listOnly) {
  console.error("usage: node audit-text.mjs <deck-data.mjs> [--terms <path>] [--prose-words <path>] [--report <path>]");
  process.exit(2);
}
const reportPath = pick("--report", undefined);

/* Where each list is read from: the path passed, or else the folder in the home directory.
   `shown` is how the refusal names the place, so that the message reads the same on every machine. */
const listAt = (flag, name) => {
  const passed = pick(flag, undefined);
  return passed === undefined
    ? { path: resolve(homedir(), ".product-deck", name), shown: `~/.product-deck/${name}`, flag }
    : { path: resolve(passed), shown: resolve(passed), flag };
};
const prose = listAt("--prose-words", "prose-words.txt");
const terms = listAt("--terms", "writing-terms.txt");
const missing = (listOnly ? [prose] : [prose, terms]).filter(({ path }) => !existsSync(path));
if (missing.length > 0) {
  for (const { shown, flag } of missing) {
    console.error(`no word list at ${shown}: write it there or pass ${flag} <path>`);
  }
  console.error("docs/how-it-works.md of the plugin shows how to write both lists. No check ran.");
  process.exit(2);
}

/* The kind names, in English and in Japanese. */
const BARE_EN_KIND = "bare-english";
const ALLOW_EN_KIND = "allow";
const PROSE_KINDS = new Map([["裸の英単語", BARE_EN_KIND], ["許す", ALLOW_EN_KIND]]);
const TERM_KINDS = new Map([
  ["synonym", "synonym"], ["同義", "synonym"],
  ["except", "except"], ["例外", "except"],
  ["allow", "allow"], ["許す", "allow"],
  ["core", "core"], ["中核", "core"],
]);

/* The words to drop from the text: one per line as `kind  word  instead`; a line starting with
   `#` is a note.

   **The kinds come from the first column of the list.** Only the two kinds matched differently
   are named here. bare-english is matched at word boundaries and ignoring case: a substring match
   finds `alignment` inside `realignment`, and matching case makes `Interface` and `interface`
   two words. allow is not a word to drop; it takes a word out of bare-english. Every other kind
   is matched as a substring, so a new kind in the list needs no change here.

   The list is read before the deck data, because the names of the checks come from its kinds;
   `--list-checks` therefore needs no deck. */
const shared = new Map([[BARE_EN_KIND, []], [ALLOW_EN_KIND, []]]);
const sharedErrors = [];
for (const [index, raw] of (await readFile(prose.path, "utf8")).split("\n").entries()) {
  const line = raw.trim();
  if (line === "" || line.startsWith("#")) continue;
  const [rawKind, word, ...instead] = line.split(/\s+/);
  if (rawKind === undefined || word === undefined || instead.length === 0) {
    sharedErrors.push(`cannot read line ${index + 1} of ${prose.shown}`);
    continue;
  }
  const kind = PROSE_KINDS.get(rawKind) ?? rawKind;
  if (!shared.has(kind)) shared.set(kind, []);
  shared.get(kind).push({ word, instead: instead.join(" ") });
}

/* The kinds whose words are dropped, and of those the ones matched as substrings.
   The two named kinds come first, the rest in the order of the list. */
const dropKinds = [...shared.keys()].filter((kind) => kind !== ALLOW_EN_KIND);
const plainKinds = dropKinds.filter((kind) => kind !== BARE_EN_KIND);

const CHECKS = [
  ["the same thing is called by different words", (h) => h.syn],
  ["a core word comes before its explanation", (h) => h.core],
  ["a person does a thing's action", (h) => h.subject],
  ...dropKinds.map((kind) => [kind, (h) => h[kind]]),
];

if (listOnly) {
  console.log(CHECKS.map(([name]) => name).join("\n"));
  process.exit(0);
}

const { faces } = await import(pathToFileURL(resolve(dataPath)).href);

/* The deck's terms. The first word of a line is its kind:
     synonym  <kept word>  <word that mixes in> ...   another word must not name the kept word's thing
     except   <kept word>  <form> ...                 a text with one of these forms is not checked for that word
     allow    <phrase>                                a phrase kept even when it holds a word to drop
     core     <word>  <slide number>                  the word must not appear before the slide that explains it */
const synonyms = [];
const excepts = new Map();
const core = [];
const allows = [];
const termErrors = [];
for (const [index, raw] of (await readFile(terms.path, "utf8")).split("\n").entries()) {
  const line = raw.replace(/#.*$/, "").trim();
  if (line === "") continue;
  const [rawKind, ...cols] = line.split(/\s+/);
  const kind = TERM_KINDS.get(rawKind);
  if (kind === "synonym") {
    if (cols.length < 2) termErrors.push(`line ${index + 1}: synonym needs a kept word and a word that mixes in`);
    else synonyms.push({ keep: cols[0], avoid: cols.slice(1) });
  } else if (kind === "except") {
    if (cols.length < 2) termErrors.push(`line ${index + 1}: except needs a kept word and a form to allow`);
    else excepts.set(cols[0], [...(excepts.get(cols[0]) ?? []), ...cols.slice(1)]);
  } else if (kind === "allow") {
    if (cols.length < 1) termErrors.push(`line ${index + 1}: allow needs a phrase`);
    else allows.push(cols.join(" "));
  } else if (kind === "core") {
    const from = Number(cols[1]);
    if (cols.length !== 2 || !Number.isInteger(from) || from < 1 || from > faces.length) {
      termErrors.push(`line ${index + 1}: core needs a word and a slide number from 1 to ${faces.length}`);
    } else core.push({ word: cols[0], from });
  } else {
    termErrors.push(`line ${index + 1}: cannot read the kind ${rawKind}`);
  }
}

/* How bare-english is matched. Words listed under allow are taken out first. */
const allowedEn = new Set(shared.get(ALLOW_EN_KIND).map(({ word }) => word.toLowerCase()));
const bareEn = shared.get(BARE_EN_KIND)
  .filter(({ word }) => !allowedEn.has(word.toLowerCase()))
  .map(({ word, instead }) => ({
    word,
    instead,
    re: new RegExp(`(?<![A-Za-z0-9])${word.toLowerCase().replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}(?![A-Za-z0-9])`, "g"),
  }));

/* Phrases the deck keeps are removed before matching, whatever the spaces between their letters. */
const allowPatterns = [...new Set(allows)]
  .sort((a, b) => b.length - a.length)
  .map((a) => new RegExp([...a.replace(/\s+/g, "")].map((c) => c.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("\\s*"), "g"));
const dropAllowed = (text) => allowPatterns.reduce((t, re) => t.replace(re, " "), text);

/* The strings of each slide that appear as text. Layout settings such as `glyph` and `outside`
   are not text and are left out. */
const NOT_TEXT = new Set(["kind", "shot", "box", "glyph", "outside", "stopped", "tone", "same",
  "shotTall", "mark", "blank", "zones", "role", "name"]);
const textOf = (face) => {
  const found = [];
  const walk = (value, key) => {
    if (NOT_TEXT.has(key)) return;
    if (typeof value === "string") { if (value.trim() !== "") found.push(value); return; }
    if (Array.isArray(value)) return value.forEach((v) => walk(v, key));
    if (value !== null && typeof value === "object") Object.entries(value).forEach(([k, v]) => walk(v, k));
  };
  Object.entries(face).forEach(([k, v]) => walk(v, k));
  return found;
};

const lines = faces.map(textOf);

/* A person or an agent doing what a thing does, in Japanese: what remains is the transaction
   the person sent, not the person. A sentence with another subject marked by も or が in between
   is not counted, because that is the real subject. */
const SUBJECT = /(人|Agent)[もは]((?:(?![もが])[^。]){0,10})(残る|返る|通る|残ります|返ります)/;

/* The Japanese passive. It is listed, not flagged: られる is also the potential form, and all five
   cases measured were potential, so the words alone cannot tell them apart. */
const PASSIVE = /[^。]{0,14}(られる|られます|される|されます)/;

const hits = faces.map(() => ({ syn: [], core: [], subject: [],
  ...Object.fromEntries(dropKinds.map((kind) => [kind, []])) }));
const passives = [];

lines.forEach((texts, index) => {
  const whole = texts.join(" ");
  /* The same thing called by different words. */
  for (const { keep, avoid } of synonyms) {
    const allowed = excepts.get(keep) ?? [];
    for (const word of avoid) {
      for (const text of texts) {
        if (!text.includes(word)) continue;
        if (allowed.some((a) => text.includes(a))) continue;
        hits[index].syn.push(`${word} → ${keep}: ${text.slice(0, 26)}`);
      }
    }
  }
  /* A core word on a slide before the one that explains it. */
  for (const { word, from } of core) {
    if (index + 1 >= from) continue;
    if (whole.includes(word)) hits[index].core.push(`${word} (explained on slide ${from})`);
  }
  /* Words to drop. Which kinds apply comes from the first column of the list. */
  for (const text of texts) {
    const kept = dropAllowed(text);
    for (const kind of plainKinds) {
      for (const { word, instead } of shared.get(kind)) {
        if (kept.includes(word)) hits[index][kind].push(`${word} → ${instead}: ${text.slice(0, 26)}`);
      }
    }
    const low = kept.toLowerCase();
    for (const { word, instead, re } of bareEn) {
      re.lastIndex = 0;
      if (re.test(low)) hits[index][BARE_EN_KIND].push(`${word} → ${instead}: ${text.slice(0, 26)}`);
    }
  }
  /* Whether the subject fits the action. */
  for (const text of texts) {
    if (SUBJECT.test(text)) hits[index].subject.push(text.slice(0, 30));
    const p = PASSIVE.exec(text);
    if (p !== null) passives.push(`${String(index + 1).padStart(2, "0")} ${p[0].trim().slice(0, 30)}`);
  }
});

const flagsOf = (h) => CHECKS
  .map(([name, pick2]) => [name, [...new Set(pick2(h))].slice(0, 4)])
  .filter(([, list]) => list.length > 0)
  .map(([name, list]) => `${name}[${list.join(" | ")}]`);

const bad = hits.map((h, i) => [i + 1, flagsOf(h)]).filter(([, f]) => f.length > 0);
if (reportPath !== undefined) await writeFile(resolve(reportPath), JSON.stringify(hits, null, 1));

/* Always print what was counted. Without it a reader cannot tell whether "0 slides flagged"
   means no defects or nothing looked at. */
const seen = lines.reduce((n, texts) => n + texts.length, 0);
console.log(`checked ${faces.length} slides / flagged ${bad.length} slides`
  + ` / texts seen ${seen} / terms: synonym ${synonyms.length}, core ${core.length}, allow ${allows.length}`
  + ` / words to drop: ${[...shared.keys()].map((kind) => `${kind} ${shared.get(kind).length}`).join(", ")}`
  + ` (bare-english words checked after allow: ${bareEn.length})`);

/* A count of 0 means a check that guards nothing. It can happen at three entrances.
   No slide: the data failed to load or changed shape. No term: the list changed its format and
   every line dropped out (an empty list once silenced the synonym and core checks and exited 0).
   A slide without text: too many keys in NOT_TEXT dropped the slide from the walk. */
const blind = [];
if (faces.length === 0) blind.push("no slide");
if (synonyms.length === 0) blind.push("no synonym term");
if (core.length === 0) blind.push("no core term");
if (termErrors.length > 0) blind.push(`unreadable terms in ${terms.shown}: ${termErrors.join(" / ")}`);
if (sharedErrors.length > 0) blind.push(sharedErrors.join(" / "));
for (const kind of shared.keys()) {
  if (sharedErrors.length === 0 && shared.get(kind).length === 0) blind.push(`no word of the kind ${kind} in ${prose.shown}`);
}
/* allow cancelling every bare-english word leaves a check that looks at no word. */
if (sharedErrors.length === 0 && shared.get(BARE_EN_KIND).length > 0 && bareEn.length === 0) {
  blind.push("allow cancels every bare-english word");
}
const noText = lines.map((texts, i) => [i + 1, texts.length]).filter(([, n]) => n === 0);
if (noText.length > 0) blind.push(`slides without text: ${noText.map(([n]) => n).join(" / ")}`);
if (blind.length > 0) {
  console.error(`the wording check looked at nothing (a defect of the check, not of the deck): ${blind.join("; ")}`);
  process.exit(2);
}

for (const [n, flags] of bad) console.log(`${String(n).padStart(2, "0")}  ${flags.join("  ")}`);

console.log(`\npassive or potential: ${passives.length} (not flagged; if passive, bring the subject back)`);
console.log([...new Set(passives)].map((l) => `  ${l}`).join("\n"));

/* Katakana words are counted, not flagged, because the words of a field (such as blockchain) are not shortened. */
const katakana = new Map();
for (const texts of lines) {
  for (const text of texts) {
    for (const m of text.matchAll(/[ァ-ヶー]{3,}/g)) katakana.set(m[0], (katakana.get(m[0]) ?? 0) + 1);
  }
}
console.log(`\nkatakana words: ${katakana.size} (not flagged; open the ones that are not words of the field)`);
console.log([...katakana].sort((a, b) => b[1] - a[1]).map(([w, n]) => `  ${String(n).padStart(2)} ${w}`).join("\n"));

if (bad.length > 0) console.log("\nFix and run again until none is flagged.");
process.exit(bad.length === 0 ? 0 : 1);
