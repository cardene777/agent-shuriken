#!/usr/bin/env node
// Checks PNG frames rendered around the start or the end of an element against the timing boundary
// contract (formats/timing-boundary.md). It counts the pixels that differ from the background in each
// frame and reports pixels before the start or after the end, an element that shows for three frames
// or fewer, an element that comes back after hiding, and boundary frames left out.
// PNG files are read with Node.js's own zlib; 8-bit, non-interlaced PNGs of every color type are read.
// Prints the result as JSON, and writes it to --out when given.
// Exits 0 when it passes, 1 when the frames need revising, 2 when called wrongly or a frame cannot be read.
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import zlib from "node:zlib";

const usage =
  "usage: check-timing-boundary.mjs --background <#RRGGBB> (--start <frame> | --end <frame>) " +
  "[--element <id>] [--out <file>] <frame>=<png> ...";
const wrong = (message) => {
  console.error(message);
  console.error(usage);
  process.exit(2);
};

const args = process.argv.slice(2);
let background = null;
let mode = null;
let boundaryText = null;
let element = null;
let out = null;
const entries = [];
for (let index = 0; index < args.length; index += 1) {
  const arg = args[index];
  if (arg === "--background") background = args[++index];
  else if (arg === "--start" || arg === "--end") {
    if (mode) wrong("give --start or --end, once");
    mode = arg.slice(2);
    boundaryText = args[++index];
  } else if (arg === "--element") element = args[++index];
  else if (arg === "--out") out = args[++index];
  else if (/^\d+=./.test(arg)) entries.push(arg);
  else wrong(`unknown argument: ${arg}`);
}
if (!/^#?[0-9a-f]{6}$/i.test(background ?? "")) wrong("--background needs a color such as #F4F5F1");
if (!mode || !/^\d+$/.test(boundaryText ?? "")) wrong("--start or --end needs a frame number");
if (entries.length === 0) wrong("give the frames from two before the boundary to two after it");
if (element === undefined || out === undefined) wrong("--element and --out need a value");

const boundary = Number(boundaryText);
const hex = background.replace(/^#/, "");
const base = [0, 2, 4].map((offset) => Number.parseInt(hex.slice(offset, offset + 2), 16));

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
    throw new Error(`${file} is not an 8-bit, non-interlaced PNG; render the frames as PNG with Remotion`);
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

const hash = crypto.createHash("sha256");
const samples = [];
for (const entry of entries) {
  const at = entry.indexOf("=");
  const frame = Number(entry.slice(0, at));
  const file = entry.slice(at + 1);
  if (samples.some((sample) => sample.frame === frame)) wrong(`frame ${frame} is given twice`);
  let png;
  try {
    const bytes = fs.readFileSync(file);
    hash.update(bytes);
    png = readPng(bytes, file);
  } catch (error) {
    console.error(`cannot read frame ${frame}: ${error.message}`);
    process.exit(2);
  }
  let visiblePixelCount = 0;
  for (let n = 0; n < png.width * png.height; n += 1) {
    const [r, g, b, alpha] = color(png, n);
    const difference = Math.max(Math.abs(r - base[0]), Math.abs(g - base[1]), Math.abs(b - base[2]));
    if (alpha / 255 > 0.02 && difference > 3) visiblePixelCount += 1;
  }
  samples.push({frame, file, visiblePixelCount});
}
samples.sort((a, b) => a.frame - b.frame);

const issues = [];
const where = element ? {element} : {};
const add = (rule, frame, message) => issues.push({rule, ...where, frame, message});
const shown = (sample) => sample.visiblePixelCount > 0;

for (let offset = -2; offset <= 2; offset += 1) {
  const frame = boundary + offset;
  if (frame >= 0 && !samples.some((sample) => sample.frame === frame)) {
    add("missing-boundary-frame", frame, `frame ${frame} is missing; give every frame from ${boundary - 2} to ${boundary + 2}`);
  }
}
for (const sample of samples) {
  if (mode === "start" && sample.frame <= boundary && shown(sample)) {
    add("premature-visible-pixels", sample.frame, `${sample.visiblePixelCount} pixels show at frame ${sample.frame}, at or before the start ${boundary}`);
  }
  if (mode === "end" && sample.frame >= boundary && shown(sample)) {
    add("late-visible-pixels", sample.frame, `${sample.visiblePixelCount} pixels show at frame ${sample.frame}, at or after the end ${boundary}`);
  }
}
// Runs of frames that show the element, with the index of the sample before and after each run.
const runs = [];
for (let i = 0; i < samples.length; i += 1) {
  if (!shown(samples[i])) continue;
  let j = i;
  while (j + 1 < samples.length && shown(samples[j + 1])) j += 1;
  runs.push({first: i, last: j});
  i = j;
}
for (const run of runs) {
  const before = samples[run.first - 1];
  const after = samples[run.last + 1];
  const frames = samples[run.last].frame - samples[run.first].frame + 1;
  if (before && after && frames <= 3) {
    add("short-lived", samples[run.first].frame, `the element shows for ${frames} frame${frames > 1 ? "s" : ""} from frame ${samples[run.first].frame} and hides again`);
  }
}
for (let k = 1; k < runs.length; k += 1) {
  const frame = samples[runs[k - 1].last + 1].frame;
  add("flicker", frame, `the element hides at frame ${frame} and shows again at frame ${samples[runs[k].first].frame}`);
}

const result = {
  check: "timing-boundary",
  decision: issues.length ? "revise" : "pass",
  issueCount: issues.length,
  ...where,
  [mode]: boundary,
  background: `#${hex.toUpperCase()}`,
  frameSetHash: hash.digest("hex"),
  samples,
  issues,
};
const text = `${JSON.stringify(result, null, 2)}\n`;
if (out) {
  fs.mkdirSync(path.dirname(path.resolve(out)), {recursive: true});
  fs.writeFileSync(out, text);
}
process.stdout.write(text);
process.exit(issues.length ? 1 : 0);
