/**
 * Themes: the colours, fonts, and corners of the frame around the screen, the cards, and the captions
 * of the edited videos. Every theme fills the same layout; only these values change.
 *
 * | Value | What it sets |
 * |---|---|
 * | `background` | Behind the screen: a colour, or two colours for a gradient from the top left |
 * | `window` | The screen's corners (`radius`), its shadow (`shadow`, 0 to 1), and its edge line (`border`, `borderOpacity`) |
 * | `caption` | `font`, `size`, `weight`, text `color`, the `band` behind the text, its `opacity`, and its `radius` |
 * | `card` | The title, chapter, and end cards: `font`, `background`, `color`, `muted` (small text), and `accent` |
 * | `accent` | The click ring and the fast-forward mark |
 *
 * A flow names a theme with `"theme"`. It is looked up first in the project's
 * `.screen-video/themes/<name>.json`, then among the bundled themes in `themes/`. A theme lists only
 * what it changes; everything else comes from the bundled `default` theme.
 */
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const BUNDLED_DIR = join(import.meta.dirname, "..", "..", "themes");
export const BUNDLED = ["default", "midnight", "paper"];
const NAME = /^[a-z0-9][a-z0-9-]*$/;
const COLOR = /^#(?:[0-9a-f]{3}|[0-9a-f]{6})$/i;

const isObject = (value) => value !== null && typeof value === "object" && !Array.isArray(value);
const isColor = (value) => typeof value === "string" && COLOR.test(value);
const isText = (value) => typeof value === "string" && value.trim() !== "";
const between = (value, low, high) => typeof value === "number" && Number.isFinite(value) && value >= low && value <= high;

function merge(base, over) {
  const out = { ...base };
  for (const [key, value] of Object.entries(over)) out[key] = isObject(value) && isObject(base[key]) ? merge(base[key], value) : value;
  return out;
}

/** The six-digit form of a colour. */
export function fullHex(color) {
  return color.length === 4 ? `#${[...color.slice(1)].map((c) => c + c).join("")}` : color;
}

/** Red, green, and blue of a colour, 0 to 255. */
export function rgb(color) {
  const hex = fullHex(color);
  return [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16));
}

/** A colour with see-through `alpha`, as CSS. */
export const rgba = (color, alpha) => `rgba(${rgb(color).join(",")},${alpha})`;

const luminance = (color) => {
  const [r, g, b] = rgb(color).map((v) => v / 255);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
};
/** Dark or light text, whichever reads better on `color`. */
const textOn = (color) => (luminance(color) > 0.45 ? "#111827" : "#f8fafc");

function problems(look) {
  const found = [];
  const colorAt = (value, path) => {
    if (!isColor(value)) found.push(`${path} must be a colour such as #0f172a`);
  };
  if (Array.isArray(look.background)) {
    if (look.background.length !== 2 || !look.background.every(isColor)) found.push("background must be a colour such as #0f172a, or a list of two colours for a gradient");
  } else if (!isColor(look.background)) found.push("background must be a colour such as #0f172a, or a list of two colours for a gradient");
  for (const part of ["window", "caption", "card"]) if (!isObject(look[part])) found.push(`${part} must be an object`);
  if (found.length > 0) return found;
  if (!between(look.window.radius, 0, 80)) found.push("window.radius must be a number of pixels from 0 to 80");
  if (!between(look.window.shadow, 0, 1)) found.push("window.shadow must be a number from 0 to 1");
  colorAt(look.window.border, "window.border");
  if (!between(look.window.borderOpacity, 0, 1)) found.push("window.borderOpacity must be a number from 0 to 1");
  if (!isText(look.caption.font)) found.push("caption.font must name a font");
  if (!between(look.caption.size, 14, 80)) found.push("caption.size must be a number of pixels from 14 to 80");
  if (!between(look.caption.weight, 100, 900)) found.push("caption.weight must be a font weight from 100 to 900");
  colorAt(look.caption.color, "caption.color");
  colorAt(look.caption.band, "caption.band");
  if (!between(look.caption.opacity, 0, 1)) found.push("caption.opacity must be a number from 0 to 1");
  if (!between(look.caption.radius, 0, 60)) found.push("caption.radius must be a number of pixels from 0 to 60");
  if (!isText(look.card.font)) found.push("card.font must name a font");
  for (const key of ["background", "color", "muted", "accent"]) colorAt(look.card[key], `card.${key}`);
  colorAt(look.accent, "accent");
  return found;
}

/**
 * Finds and reads the theme `name` for the project at `root`. Returns `{ name, source, look }`, with
 * `source` `project` or `bundled` and `look` the full set of values. Throws, naming the theme and the
 * value, when it cannot be found or a value is wrong.
 */
export function loadTheme(name = "default", root = process.cwd()) {
  if (!(typeof name === "string" && NAME.test(name))) throw new Error("theme must be lowercase letters, digits, and hyphens");
  const own = join(root, ".screen-video", "themes", `${name}.json`);
  let file;
  let source;
  if (existsSync(own)) {
    file = own;
    source = "project";
  } else if (BUNDLED.includes(name)) {
    file = join(BUNDLED_DIR, `${name}.json`);
    source = "bundled";
  } else {
    throw new Error(`theme "${name}" is not in .screen-video/themes/ of the project, and no bundled theme has that name (${BUNDLED.join(", ")})`);
  }
  let values;
  try {
    values = JSON.parse(readFileSync(file, "utf8"));
  } catch (error) {
    throw new Error(`theme "${name}": cannot read ${file} as JSON (${error instanceof Error ? error.message : error})`);
  }
  if (!isObject(values)) throw new Error(`theme "${name}" is not a JSON object`);
  const base = name === "default" && source === "bundled" ? {} : JSON.parse(readFileSync(join(BUNDLED_DIR, "default.json"), "utf8"));
  const look = merge(base, values);
  const found = problems(look);
  if (found.length > 0) throw new Error(`theme "${name}": ${found.join("; ")}`);
  // A theme that changes a background but not the text on it gets the text colour that reads on it
  if (values.caption?.band !== undefined && values.caption?.color === undefined) look.caption.color = textOn(look.caption.band);
  if (values.card?.background !== undefined && values.card?.color === undefined) {
    look.card.color = textOn(look.card.background);
    look.card.muted = look.card.color;
  }
  return { name, source, look };
}
