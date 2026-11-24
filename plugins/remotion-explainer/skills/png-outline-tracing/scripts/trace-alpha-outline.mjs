#!/usr/bin/env node
// Traces the outline of the opaque core of a transparent PNG into SVG paths and a JSON record, for an
// object that is drawn in before its PNG paint appears (formats/outline-timing.md). A pixel is solid when
// its alpha is above --threshold (210 by default). The edges between solid and clear pixels are followed
// into closed contours; contours of fewer than 16 points are dropped, each one left is simplified with a
// tolerance of 1.6 px, and --mode main keeps the one that encloses the largest area while --mode all keeps
// every one.
// PNG files are read with Node.js's own zlib; 8-bit, non-interlaced PNGs of every color type are read.
// Writes only the --svg and --data files, making their folders when needed, and prints a JSON summary.
// Exits 0 when it wrote both, 1 when no closed silhouette is found, 2 when called wrongly or the PNG
// cannot be read.
import fs from "node:fs";
import path from "node:path";
import zlib from "node:zlib";

const usage = "usage: trace-alpha-outline.mjs --input <png> --svg <svg> --data <json> [--mode main|all] [--threshold 210]";
const wrong = (message) => {
  console.error(message);
  console.error(usage);
  process.exit(2);
};

const options = {};
const args = process.argv.slice(2);
for (let index = 0; index < args.length; index += 1) {
  const name = args[index].replace(/^--/, "");
  if (!args[index].startsWith("--") || !["input", "svg", "data", "mode", "threshold"].includes(name)) {
    wrong(`unknown argument: ${args[index]}`);
  }
  const value = args[index + 1];
  if (value === undefined || value.startsWith("--")) wrong(`--${name} needs a value`);
  options[name] = value;
  index += 1;
}
if (!options.input || !options.svg || !options.data) wrong("give --input, --svg, and --data");
const threshold = Number(options.threshold ?? 210);
const mode = options.mode ?? "main";
if (!Number.isFinite(threshold) || threshold < 1 || threshold > 255) wrong("--threshold must be a number from 1 to 255");
if (!["main", "all"].includes(mode)) wrong("--mode must be main or all");

// The PNG reader below is copied from the check-timing-boundary check of the remotion-frame-checks skill.
function readPng(bytes, file) {
  const signature = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  if (bytes.length < 8 || !bytes.subarray(0, 8).equals(signature)) throw new Error(`${file} is not a PNG`);
  let offset = 8;
  let header = null;
  let palette = null;
  let transparency = null;
  const data = [];
  while (offset + 8 <= bytes.length) {
    const length = bytes.readUInt32BE(offset);
    const type = bytes.toString("latin1", offset + 4, offset + 8);
    const body = bytes.subarray(offset + 8, offset + 8 + length);
    offset += 12 + length;
    if (type === "IHDR") {
      header = {width: body.readUInt32BE(0), height: body.readUInt32BE(4), depth: body[8], color: body[9], interlace: body[12]};
    } else if (type === "PLTE") palette = body;
    else if (type === "tRNS") transparency = body;
    else if (type === "IDAT") data.push(body);
    else if (type === "IEND") break;
  }
  if (!header || !header.width || !header.height) throw new Error(`${file} has no image header`);
  const channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[header.color];
  if (header.depth !== 8 || !channels || header.interlace !== 0) {
    throw new Error(`${file} is not an 8-bit, non-interlaced PNG; save it as an 8-bit RGBA PNG`);
  }
  if (header.color === 3 && !palette) throw new Error(`${file} uses a palette it does not hold`);
  const raw = zlib.inflateSync(Buffer.concat(data));
  const stride = header.width * channels;
  if (raw.length < (stride + 1) * header.height) throw new Error(`${file} is cut short`);
  const pixels = Buffer.alloc(stride * header.height);
  for (let y = 0; y < header.height; y += 1) {
    const filter = raw[y * (stride + 1)];
    const line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    const row = pixels.subarray(y * stride, (y + 1) * stride);
    const up = y > 0 ? pixels.subarray((y - 1) * stride, y * stride) : null;
    for (let i = 0; i < stride; i += 1) {
      const a = i >= channels ? row[i - channels] : 0;
      const b = up ? up[i] : 0;
      const c = up && i >= channels ? up[i - channels] : 0;
      let predicted;
      if (filter === 0) predicted = 0;
      else if (filter === 1) predicted = a;
      else if (filter === 2) predicted = b;
      else if (filter === 3) predicted = (a + b) >> 1;
      else if (filter === 4) {
        const pa = Math.abs(b - c);
        const pb = Math.abs(a - c);
        const pc = Math.abs(a + b - 2 * c);
        predicted = pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
      } else throw new Error(`${file} uses the unknown row filter ${filter}`);
      row[i] = (line[i] + predicted) & 0xff;
    }
  }
  return {...header, channels, pixels, palette, transparency};
}

// Returns [red, green, blue, alpha] of pixel number n.
function color(png, n) {
  const p = png.pixels;
  const t = png.transparency;
  switch (png.color) {
    case 0: {
      const g = p[n];
      return [g, g, g, t && t.length >= 2 && t.readUInt16BE(0) === g ? 0 : 255];
    }
    case 2: {
      const [r, g, b] = [p[n * 3], p[n * 3 + 1], p[n * 3 + 2]];
      const clear = t && t.length >= 6 && t.readUInt16BE(0) === r && t.readUInt16BE(2) === g && t.readUInt16BE(4) === b;
      return [r, g, b, clear ? 0 : 255];
    }
    case 3: {
      const i = p[n];
      return [png.palette[i * 3], png.palette[i * 3 + 1], png.palette[i * 3 + 2], t && i < t.length ? t[i] : 255];
    }
    case 4:
      return [p[n * 2], p[n * 2], p[n * 2], p[n * 2 + 1]];
    default:
      return [p[n * 4], p[n * 4 + 1], p[n * 4 + 2], p[n * 4 + 3]];
  }
}
// End of the copied PNG reader.

const inputPath = path.resolve(options.input);
let png;
try {
  png = readPng(fs.readFileSync(inputPath), options.input);
} catch (error) {
  console.error(`cannot read ${options.input}: ${error.message}`);
  process.exit(2);
}
const {width, height} = png;
const alpha = new Uint8Array(width * height);
for (let n = 0; n < alpha.length; n += 1) alpha[n] = color(png, n)[3];

const key = (p) => `${p.x},${p.y}`;
const solid = (x, y) => x >= 0 && y >= 0 && x < width && y < height && alpha[y * width + x] > threshold;
const distance = (p, a, b) => {
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  if (!dx && !dy) return Math.hypot(p.x - a.x, p.y - a.y);
  const t = Math.max(0, Math.min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / (dx * dx + dy * dy)));
  return Math.hypot(p.x - (a.x + dx * t), p.y - (a.y + dy * t));
};
// Removes the points that lie within the tolerance of the line between their neighbors that are kept.
const simplify = (points, tolerance = 1.6) => {
  if (points.length < 4) return points;
  let farthest = 0;
  let index = 0;
  for (let i = 1; i < points.length - 1; i += 1) {
    const current = distance(points[i], points[0], points.at(-1));
    if (current > farthest) {
      farthest = current;
      index = i;
    }
  }
  if (farthest <= tolerance) return [points[0], points.at(-1)];
  return [...simplify(points.slice(0, index + 1), tolerance).slice(0, -1), ...simplify(points.slice(index), tolerance)];
};

// Each solid pixel adds the edges it shares with clear pixels, running clockwise around the solid side.
const next = new Map();
const edge = (from, to) => next.set(key(from), [...(next.get(key(from)) ?? []), to]);
for (let y = 0; y < height; y += 1) {
  for (let x = 0; x < width; x += 1) {
    if (!solid(x, y)) continue;
    if (!solid(x, y - 1)) edge({x, y}, {x: x + 1, y});
    if (!solid(x + 1, y)) edge({x: x + 1, y}, {x: x + 1, y: y + 1});
    if (!solid(x, y + 1)) edge({x: x + 1, y: y + 1}, {x, y: y + 1});
    if (!solid(x - 1, y)) edge({x, y: y + 1}, {x, y});
  }
}

// Follows the edges into closed contours.
const contours = [];
while (next.size) {
  const [startKey, candidates] = next.entries().next().value;
  const first = candidates.pop();
  if (!candidates.length) next.delete(startKey);
  const [x, y] = startKey.split(",").map(Number);
  const points = [{x, y}, first];
  let cursor = first;
  let guard = 0;
  while (key(cursor) !== startKey && guard++ < width * height * 4) {
    const choices = next.get(key(cursor));
    if (!choices?.length) break;
    cursor = choices.pop();
    if (!choices.length) next.delete(key(points.at(-1)));
    points.push(cursor);
  }
  if (key(cursor) !== startKey || points.length < 16) continue;
  const compact = simplify(points).slice(0, -1);
  if (compact.length < 4) continue;
  const area = Math.abs(compact.reduce((sum, p, i) => {
    const q = compact[(i + 1) % compact.length];
    return sum + p.x * q.y - q.x * p.y;
  }, 0) / 2);
  contours.push({area, d: `M ${compact.map((p) => `${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(" L ")} Z`});
}
contours.sort((a, b) => b.area - a.area);
const selected = (mode === "main" ? contours.slice(0, 1) : contours).map(({d}) => d);
if (!selected.length) {
  console.error(`no closed silhouette found in ${options.input}; check its alpha channel, the threshold, or the image`);
  process.exit(1);
}

const svgPath = path.resolve(options.svg);
const dataPath = path.resolve(options.data);
const record = {schemaVersion: 1, input: inputPath, width, height, threshold, mode, paths: selected};
const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}">` +
  `<g fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">` +
  `${selected.map((d) => `<path d="${d}"/>`).join("")}</g></svg>\n`;
fs.mkdirSync(path.dirname(svgPath), {recursive: true});
fs.mkdirSync(path.dirname(dataPath), {recursive: true});
fs.writeFileSync(svgPath, svg);
fs.writeFileSync(dataPath, `${JSON.stringify(record, null, 2)}\n`);
console.log(JSON.stringify({trace: "alpha-outline", input: inputPath, width, height, threshold, mode, pathCount: selected.length, svg: svgPath, data: dataPath}, null, 2));
