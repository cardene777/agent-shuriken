#!/usr/bin/env node
/* Reads the user's theme file and prints the values a deck takes from it, as a CSS :root block.

   Usage
     node theme.mjs        # run in the user's repository

   The theme is the first of these that exists: .design-theme.json at the root of the git
   repository the command runs in, or else ~/.design-theme.json. The repository's file is used as
   it is, and the home file is not merged into it. It is the same file, with the same keys, as the
   theme of the page-design skill of design-formats, so one file gives the user's pages and decks
   the same look. This script reads it with its own code, because a plugin reads nothing outside
   its own folder.

   A deck takes the main color (light.accent, light.accent-ink, light.accent-soft), the neutrals
   (light.bg, light.surface, light.ink, light.sub, light.line), the type (font.sans, font.mono,
   font.line-height), and the corners (space.radius-small, space.radius, space.radius-large).
   The other keys are not used on slides: dark.* (a handout has one look), light.bar and
   light.label (parts of pages), font.size (slide text is sized for 1920x1080 and stays at 22px or
   more), and space.page-width (a slide is 1920 wide). They are still checked, so that a file both
   plugins read is refused by both or by neither.

   Output
     stdout  the :root block of the keys the theme sets that a deck takes; nothing without a theme
     stderr  which file was read and which of its keys are not used, or that there is no theme

   Exits 0 when the theme was read or there is none. Exits 2 when the file is not JSON, holds a key
   that is not listed, or holds a value of the wrong kind or out of range; each such key is named,
   and nothing is printed to apply.

   Reads only the theme file, writes nothing, runs no other program, and connects to nothing. */

import { existsSync, readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";

const NAME = ".design-theme.json";
const COLOR_KEYS = ["bg", "surface", "ink", "sub", "line", "accent", "accent-ink", "accent-soft", "bar", "label"];
/* key: kind, and for a number its smallest and largest value. Text stays at 12px or more. */
const FONT_KEYS = { sans: ["font"], mono: ["font"], size: ["px", 12, 40], "line-height": ["number", 1, 3] };
const SPACE_KEYS = { "page-width": ["px", 320, 4000], "radius-small": ["px", 0, 64], radius: ["px", 0, 64],
  "radius-large": ["px", 0, 64] };
const GROUPS = { light: COLOR_KEYS, dark: COLOR_KEYS, font: Object.keys(FONT_KEYS), space: Object.keys(SPACE_KEYS) };
const COLOR = /^(#([0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})|(rgb|rgba|hsl|hsla)\([0-9.,%\s/+-]+\))$/;

/* The keys a deck takes, in the order they are printed, with the CSS variable each one sets. */
const USED = [
  ...["accent", "accent-ink", "accent-soft", "bg", "surface", "ink", "sub", "line"].map((k) => ["light", k, k]),
  ["font", "sans", "sans"], ["font", "mono", "mono"], ["font", "line-height", "line-height"],
  ["space", "radius-small", "radius-small"], ["space", "radius", "radius"], ["space", "radius-large", "radius-large"],
];

const isFile = (path) => existsSync(path) && statSync(path).isFile();

/* The theme file to use: the repository's, else the home one, else null. */
const themeFile = () => {
  let folder = resolve(process.cwd());
  for (;;) {
    if (existsSync(join(folder, ".git"))) {
      if (isFile(join(folder, NAME))) return join(folder, NAME);
      break;
    }
    const parent = dirname(folder);
    if (parent === folder) break;
    folder = parent;
  }
  const home = join(homedir(), NAME);
  return isFile(home) ? home : null;
};

const shown = (value) => JSON.stringify(value);

/* One line per key the theme file may not hold, naming the key. */
const problemsOf = (theme) => {
  if (theme === null || typeof theme !== "object" || Array.isArray(theme)) {
    return [`the theme file holds ${shown(theme)}, not an object of light, dark, font, and space`];
  }
  const problems = [];
  for (const [group, values] of Object.entries(theme)) {
    const known = GROUPS[group];
    if (known === undefined) {
      problems.push(`${group}: not a key; the keys are light, dark, font, and space`);
      continue;
    }
    if (values === null || typeof values !== "object" || Array.isArray(values)) {
      problems.push(`${group}: holds ${shown(values)}, not an object`);
      continue;
    }
    for (const [key, value] of Object.entries(values)) {
      const name = `${group}.${key}`;
      if (!known.includes(key)) {
        problems.push(`${name}: not a key; ${group} takes ${known.join(", ")}`);
      } else if (group === "light" || group === "dark") {
        if (typeof value !== "string" || !COLOR.test(value.trim())) {
          problems.push(`${name}: ${shown(value)} is not a color such as #2a5bd7 or rgb(42, 91, 215)`);
        }
      } else {
        const [kind, low, high] = (group === "font" ? FONT_KEYS : SPACE_KEYS)[key];
        if (kind === "font") {
          if (typeof value !== "string" || value.trim() === "" || /[;{}<>\\]/.test(value) || value.length > 300) {
            problems.push(`${name}: ${shown(value)} is not a font list such as "Inter", sans-serif`);
          }
        } else if (typeof value !== "number" || !Number.isFinite(value) || value < low || value > high) {
          problems.push(`${name}: ${shown(value)} is not a number from ${low} to ${high}`);
        }
      }
    }
  }
  return problems;
};

const cssValue = (group, key, value) => {
  if (group === "light" || (group === "font" && FONT_KEYS[key][0] === "font")) return value.trim();
  const kind = (group === "font" ? FONT_KEYS : SPACE_KEYS)[key][0];
  return kind === "px" ? `${value}px` : String(value);
};

const path = themeFile();
if (path === null) {
  console.error(`no theme file (${NAME} at the root of the repository, or ~/${NAME}): the deck keeps its own look`);
  process.exit(0);
}

let theme;
try {
  const raw = readFileSync(path, "utf8");
  theme = raw.trim() === "" ? {} : JSON.parse(raw);
} catch (error) {
  console.error(`cannot read the theme file ${path} (${error.message}); fix it and run again`);
  process.exit(2);
}
const problems = problemsOf(theme);
if (problems.length > 0) {
  for (const line of problems) console.error(`theme: ${line}`);
  console.error(`the theme file ${path} was not applied; fix it and run again`);
  process.exit(2);
}

const lines = USED
  .filter(([group, key]) => theme[group]?.[key] !== undefined)
  .map(([group, key, token]) => `  --${token}: ${cssValue(group, key, theme[group][key])};`);
const usedNames = new Set(USED.map(([group, key]) => `${group}.${key}`));
const unused = Object.entries(theme)
  .flatMap(([group, values]) => Object.keys(values).map((key) => `${group}.${key}`))
  .filter((name) => !usedNames.has(name));

console.error(`theme: ${path}`);
if (unused.length > 0) console.error(`not used on slides: ${unused.join(", ")}`);
if (lines.length === 0) {
  console.error("the theme sets no key a deck takes: the deck keeps its own look");
  process.exit(0);
}
console.log([":root {", ...lines, "}"].join("\n"));
