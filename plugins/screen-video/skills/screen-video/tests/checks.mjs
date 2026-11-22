// Checks for the screen-video skill, run by test-screen-video.sh.
//
// A sample site is served on 127.0.0.1 by this file, flow files are written into a throwaway project,
// and the data folder is a throwaway folder too, so no real site, account, or video folder is touched.
// The browser and ffmpeg come from an installed runtime: SCREEN_VIDEO_TEST_NODE_DIR, or the data
// folder's node/ after `screen-video.sh setup`.
//
// Each check prints `ok    <name>` or `FAIL  <name>` with the reason on the next line, and the run
// ends with `<passed> passed, <failed> failed (<ran> ran)`.

import { spawn, spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { createServer } from "node:http";
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { dirname, extname, join } from "node:path";

const HERE = import.meta.dirname;
const SKILL = join(HERE, "..");
const PLUGIN = join(SKILL, "..", "..");
const SCRIPT = join(SKILL, "scripts", "screen-video.sh");
const SITE = join(HERE, "fixtures", "site");
const NODE_DIR = process.env.SCREEN_VIDEO_TEST_NODE_DIR || join(homedir(), ".local", "share", "screen-video", "node");

const T = mkdtempSync(join(tmpdir(), "screen-video-test-"));
const DATA = join(T, "data");
const PROJECT = join(T, "project");
const FLOWS = join(PROJECT, ".screen-video", "flows");
mkdirSync(FLOWS, { recursive: true });

// Canary login values. They must never appear in output or in any written file.
const USER = "canary-user-5512";
const PASS = "canary-pass-9031";
writeFileSync(join(PROJECT, ".env.test"), `SV_TEST_USER=${USER}\nSV_TEST_PASS=${PASS}\n`);

let passed = 0;
let failed = 0;

async function check(name, fn) {
  let reason;
  try {
    const result = await fn();
    if (result !== true) reason = typeof result === "string" ? result : "the check returned false";
  } catch (error) {
    reason = error instanceof Error ? error.message.split("\n")[0] : String(error);
  }
  if (reason === undefined) {
    passed++;
    process.stdout.write(`ok    ${name}\n`);
  } else {
    failed++;
    process.stdout.write(`FAIL  ${name}\n#   ${reason}\n`);
  }
}

// --- the sample site ---------------------------------------------------------------------------

const counts = { pay: 0 };
const TYPES = { ".html": "text/html; charset=utf-8", ".png": "image/png" };
const server = createServer((req, res) => {
  const url = new URL(req.url, "http://127.0.0.1");
  if (url.pathname === "/api/pay" && req.method === "POST") {
    counts.pay++;
    res.setHeader("content-type", "application/json");
    res.end('{"paid":true}');
    return;
  }
  if (url.pathname.startsWith("/secure/")) {
    const expected = `Basic ${Buffer.from(`${USER}:${PASS}`).toString("base64")}`;
    if (req.headers.authorization !== expected) {
      res.statusCode = 401;
      res.setHeader("www-authenticate", 'Basic realm="members"');
      res.end("Members only");
      return;
    }
  }
  if (url.pathname === "/login") {
    res.statusCode = 302;
    res.setHeader("set-cookie", "sv_session=ok; Path=/; HttpOnly");
    res.setHeader("location", "/account");
    res.end();
    return;
  }
  if (url.pathname === "/account") {
    const signedIn = (req.headers.cookie ?? "").split(/;\s*/).includes("sv_session=ok");
    res.statusCode = signedIn ? 200 : 401;
    res.setHeader("content-type", "text/html; charset=utf-8");
    res.end(
      signedIn
        ? '<!doctype html><title>Account</title><body style="font:20px system-ui;padding:40px"><h1>Signed in with a saved session</h1><button type="button">Open profile</button></body>'
        : '<!doctype html><title>Log in</title><body style="font:20px system-ui;padding:40px"><h1>Please log in</h1></body>',
    );
    return;
  }
  let path = join(SITE, url.pathname);
  if (url.pathname.endsWith("/")) path = join(path, "index.html");
  if (!path.startsWith(SITE) || !existsSync(path) || statSync(path).isDirectory()) {
    res.statusCode = 404;
    res.end("not found");
    return;
  }
  res.setHeader("content-type", TYPES[extname(path)] ?? "application/octet-stream");
  res.end(readFileSync(path));
});
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const BASE = `http://127.0.0.1:${server.address().port}`;

// --- helpers -----------------------------------------------------------------------------------

/**
 * Runs screen-video.sh and waits for it without blocking, so the sample site above keeps answering
 * the browser the command drives.
 */
function run(args, { env = {}, cwd = PROJECT, timeout = 300_000 } = {}) {
  return new Promise((resolve) => {
    const child = spawn("bash", [SCRIPT, ...args], {
      cwd,
      env: { ...process.env, SCREEN_VIDEO_HOME: DATA, SCREEN_VIDEO_NODE_DIR: NODE_DIR, ...env },
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => (stdout += chunk));
    child.stderr.on("data", (chunk) => (stderr += chunk));
    const timer = setTimeout(() => child.kill("SIGKILL"), timeout);
    child.on("close", (status) => {
      clearTimeout(timer);
      resolve({ status, stdout, stderr, all: `${stdout}${stderr}` });
    });
  });
}

function flow(name, body) {
  const file = join(FLOWS, `${name}.json`);
  writeFileSync(file, `${JSON.stringify({ version: 1, name, url: BASE, ...body }, null, 2)}\n`);
  return file;
}

// The ffmpeg the skill uses, read once from `doctor`, for looking into the videos it wrote.
let FFMPEG = "ffmpeg";
try {
  FFMPEG = JSON.parse((await run(["doctor", "--json"])).stdout).ffmpeg.path ?? "ffmpeg";
} catch {
  FFMPEG = "ffmpeg";
}
const ffmpeg = () => FFMPEG;

/** Width, height, and duration of a video, read from ffmpeg's banner. */
function probe(file) {
  const text = spawnSync(ffmpeg(), ["-hide_banner", "-i", file], { encoding: "utf8" }).stderr ?? "";
  const duration = /Duration: (\d+):(\d+):([\d.]+)/.exec(text);
  const size = /Video: .*?, (\d{2,5})x(\d{2,5})/.exec(text);
  if (duration === null || size === null) throw new Error(`cannot read ${file}`);
  return {
    width: Number(size[1]),
    height: Number(size[2]),
    duration: Number(duration[1]) * 3600 + Number(duration[2]) * 60 + Number(duration[3]),
  };
}

/** Mean absolute difference between horizontal neighbours in a gray crop of one frame: how much detail the box holds. */
function detail(file, at, box) {
  const bytes = spawnSync(
    ffmpeg(),
    ["-hide_banner", "-loglevel", "error", "-ss", at.toFixed(3), "-i", file, "-frames:v", "1", "-vf", `crop=${box.w}:${box.h}:${box.x}:${box.y},format=gray`, "-f", "rawvideo", "-"],
    { maxBuffer: 1 << 26 },
  ).stdout;
  if (bytes.length !== box.w * box.h) throw new Error(`cannot read a frame of ${file} at ${at}s`);
  let sum = 0;
  for (let y = 0; y < box.h; y++) for (let x = 1; x < box.w; x++) sum += Math.abs(bytes[y * box.w + x] - bytes[y * box.w + x - 1]);
  return sum / (box.h * (box.w - 1));
}

/** Times at which the brightness of the top-left patch crosses the middle, in order. */
function flips(file) {
  const text = spawnSync(ffmpeg(), ["-hide_banner", "-i", file, "-vf", "crop=200:200:100:100,signalstats,metadata=print:key=lavfi.signalstats.YAVG", "-f", "null", "-"], { encoding: "utf8" }).stderr ?? "";
  const lines = text.split("\n");
  const times = [];
  let dark;
  for (let i = 0; i < lines.length; i++) {
    const time = /pts_time:([0-9.]+)/.exec(lines[i]);
    const luma = /YAVG=([0-9.]+)/.exec(lines[i + 1] ?? "");
    if (time === null || luma === null) continue;
    const now = Number(luma[1]) < 128;
    if (dark !== undefined && now !== dark) times.push(Number(time[1]));
    dark = now;
  }
  return times;
}

function readText(file) {
  return existsSync(file) ? readFileSync(file, "utf8") : "";
}

function filesUnder(dir) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name);
    return entry.isDirectory() ? filesUnder(path) : [path];
  });
}

// --- flows -------------------------------------------------------------------------------------

const SHOP = flow("shop", {
  title: "Create a project and pay",
  purpose: "Show how a project is created and paid for",
  audience: "people trying the shop",
  length: "about 20 seconds",
  outputs: ["16:9", "9:16", "gif"],
  mask: [{ css: ".private" }],
  steps: [
    { do: "open", url: "/", caption: "Open the shop" },
    { do: "hold", seconds: 1 },
    { do: "fill", target: { label: "Project name" }, text: "Demo project", caption: "Name the project" },
    { do: "click", target: { role: "button", name: "Create project" }, caption: "Create the project" },
    { do: "wait", until: { text: "Project created" }, timeout: 10, caption: "Wait for the project" },
    { do: "click", target: { role: "button", name: "Pay now" }, caption: "Pay for the plan", effect: { kind: "pays", note: "one test payment on the local sample" } },
    { do: "wait", until: { text: "Paid" }, timeout: 10 },
    { do: "hold", seconds: 1, caption: "The plan is paid" },
  ],
});
const SHOP_CAPTIONS = 6;
const SHOP_MARKED = 6;

const PLAIN = flow("plain", {
  title: "Create a project",
  steps: [
    { do: "open", url: "/", caption: "Open the shop" },
    { do: "fill", target: { label: "Project name" }, text: "Demo project", caption: "Name the project" },
    { do: "click", target: { role: "button", name: "Create project" }, caption: "Create the project" },
    { do: "wait", until: { text: "Project created" }, timeout: 10, caption: "Wait for the project" },
    { do: "hold", seconds: 1 },
  ],
});
const PLAIN_STEPS = 5;

const MISSING = flow("missing", {
  steps: [
    { do: "open", url: "/", caption: "Open the shop" },
    { do: "hold", seconds: 0.5 },
    { do: "click", target: { role: "button", name: "Start the tour" }, timeout: 3, caption: "Start the tour" },
    { do: "hold", seconds: 0.5 },
  ],
});

// The payment form's fields are in an iframe that arrives a second late, nested in another, after an
// iframe from the same address that holds no field
const IN_FRAME = { frame: "pay-form" };
const FRAMES = flow("frames", {
  steps: [
    { do: "open", url: "/frames/index.html", caption: "Open the checkout" },
    { do: "fill", target: { label: "Card name", ...IN_FRAME }, text: "Tour Demo", timeout: 10, caption: "Type the name on the card" },
    { do: "wait", until: { visible: { role: "button", name: "Pay", ...IN_FRAME } }, timeout: 10 },
    { do: "click", target: { role: "button", name: "Pay", ...IN_FRAME }, caption: "Pay" },
    { do: "wait", until: { visible: { text: "Paid", ...IN_FRAME } }, timeout: 10 },
  ],
});
const FRAME_MISSING = flow("frame-missing", {
  steps: [
    { do: "open", url: "/frames/index.html", caption: "Open the checkout" },
    { do: "click", target: { role: "button", name: "Pay", frame: "no-such-frame" }, timeout: 2, caption: "Pay" },
  ],
});

const UNKNOWN = flow("unknown", { steps: [{ do: "open", url: "/" }, { do: "teleport", to: "/settings.html" }] });
const NO_TARGET = flow("no-target", { steps: [{ do: "open", url: "/" }, { do: "click", caption: "Press something" }] });
const SECRET = flow("secret", {
  steps: [
    { do: "open", url: "/settings.html" },
    { do: "fill", target: { label: "Password" }, text: "hunter2-but-longer", caption: "Type the password" },
  ],
});

const TOGGLE = flow("toggle", {
  steps: [
    { do: "open", url: "/toggle.html", caption: "Open the page" },
    { do: "hold", seconds: 1 },
    { do: "click", target: { role: "button", name: "Press" }, caption: "Press once" },
    { do: "hold", seconds: 1 },
    { do: "click", target: { role: "button", name: "Press" }, caption: "Press twice" },
    { do: "hold", seconds: 1 },
    { do: "click", target: { role: "button", name: "Press" }, caption: "Press three times" },
    { do: "hold", seconds: 1 },
  ],
});

const BASIC = flow("basic", {
  login: { envFile: ".env.test", basic: { username: "SV_TEST_USER", password: "SV_TEST_PASS" } },
  steps: [
    { do: "open", url: "/secure/", caption: "Open the members page" },
    { do: "wait", until: { text: "Signed in through basic auth" }, timeout: 10, caption: "The members page opens" },
    { do: "click", target: { role: "button", name: "Continue" }, caption: "Continue" },
  ],
});

const SESSION = flow("session", {
  login: { session: "test", start: "/login" },
  steps: [
    { do: "open", url: "/account", caption: "Open the account" },
    { do: "wait", until: { text: "Signed in with a saved session" }, timeout: 10, caption: "The account opens signed in" },
  ],
});

// --- checks ------------------------------------------------------------------------------------

await check("SKILL.md plans the flow and shows the storyboard before recording", async () => {
  const text = readText(join(SKILL, "SKILL.md"));
  for (const phrase of [
    "Ask what the video is for, who will watch it, and how long it should be",
    "`.screen-video/flows/`",
    "storyboard",
    "Do not run `record` until the user has seen the storyboard and answered",
    "In agents without a question tool, ask in the chat",
  ]) {
    if (!text.includes(phrase)) return `SKILL.md lacks: ${phrase}`;
  }
  const rehearse = text.indexOf("rehearse");
  const record = text.indexOf("--confirm-effects");
  if (rehearse < 0 || record < 0 || rehearse > record) return "SKILL.md does not rehearse before recording";
  return true;
});

await check("check accepts a flow and lists its marked steps", async () => {
  const r = await run(["check", SHOP]);
  if (r.status !== 0) return `check exited ${r.status}: ${r.all.trim().split("\n").at(-1)}`;
  if (!new RegExp(`step ${SHOP_MARKED}\\b.*pays`, "i").test(r.stdout)) return "check did not list the paying step";
  if (!r.stdout.includes("one test payment on the local sample")) return "check did not show the step's note";
  return true;
});

await check("check refuses unknown steps, missing targets, and literal secrets", async () => {
  for (const [file, pattern] of [
    [UNKNOWN, /step 2\b.*unknown action/i],
    [NO_TARGET, /step 2\b.*target/i],
    [SECRET, /step 2\b.*(secret|password)/i],
  ]) {
    const r = await run(["check", file]);
    if (r.status !== 1) return `check exited ${r.status} for ${file}`;
    if (!pattern.test(r.all)) return `check did not say ${pattern} for ${file}`;
  }
  return true;
});

const PLAIN_REHEARSAL = join(T, "rehearse-plain");
await check("rehearse writes a storyboard with a frame for each step", async () => {
  const r = await run(["rehearse", PLAIN, "--out", PLAIN_REHEARSAL]);
  if (r.status !== 0) return `rehearse exited ${r.status}: ${r.all.trim().split("\n").at(-1)}`;
  const html = readText(join(PLAIN_REHEARSAL, "storyboard.html"));
  if (html === "") return "no storyboard.html";
  const cards = html.match(/data-step="\d+"/g) ?? [];
  if (cards.length !== PLAIN_STEPS) return `${cards.length} cards for ${PLAIN_STEPS} steps`;
  if (!html.includes("日本語") || !html.includes("English")) return "the storyboard has no English / 日本語 switch";
  for (let i = 1; i <= PLAIN_STEPS; i++) {
    const frame = join(PLAIN_REHEARSAL, "frames", `${String(i).padStart(3, "0")}.png`);
    if (!existsSync(frame)) return `no frame for step ${i}`;
  }
  if (existsSync(join(PLAIN_REHEARSAL, "raw.mp4"))) return "rehearse recorded a video";
  return true;
});

await check("rehearse stops before the first marked step", async () => {
  const before = counts.pay;
  const out = join(T, "rehearse-shop");
  const r = await run(["rehearse", SHOP, "--out", out]);
  if (r.status !== 0) return `rehearse exited ${r.status}: ${r.all.trim().split("\n").at(-1)}`;
  if (counts.pay !== before) return "rehearse paid";
  const html = readText(join(out, "storyboard.html"));
  if (!new RegExp(`data-step="${SHOP_MARKED}"[^>]*data-status="skipped"`).test(html)) return "the storyboard does not show the marked step as not rehearsed";
  if (existsSync(join(out, "frames", `${String(SHOP_MARKED).padStart(3, "0")}.png`))) return "rehearse took a frame of the marked step";
  return true;
});

await check("rehearse names a target it cannot find", async () => {
  const out = join(T, "rehearse-missing");
  const r = await run(["rehearse", MISSING, "--out", out]);
  if (r.status !== 1) return `rehearse exited ${r.status}`;
  if (!/step 3\b/.test(r.stderr) || !r.stderr.includes("Start the tour")) return "rehearse did not name step 3 and its target";
  if (!/data-step="3"[^>]*data-status="missing"/.test(readText(join(out, "storyboard.html")))) return "the storyboard does not mark step 3 as missing";
  return true;
});

await check("targets in a late iframe are found in the iframe that holds them", async () => {
  const out = join(T, "rehearse-frames");
  const r = await run(["rehearse", FRAMES, "--out", out]);
  if (r.status !== 0) return `rehearse exited ${r.status}: ${r.all.trim().split("\n").at(-1)}`;
  const html = readText(join(out, "storyboard.html"));
  for (let step = 1; step <= 5; step++) {
    if (!new RegExp(`data-step="${step}"[^>]*data-status="ok"`).test(html)) return `the storyboard does not mark step ${step} as ok`;
  }
  const missing = join(T, "rehearse-frame-missing");
  const started = Date.now();
  const m = await run(["rehearse", FRAME_MISSING, "--out", missing]);
  if (m.status !== 1) return `rehearse with a frame that never appears exited ${m.status}`;
  if (!m.stderr.includes("no-such-frame")) return "rehearse did not name the frame it looked for";
  if (Date.now() - started < 2000) return "rehearse gave up on the frame before its timeout";
  return true;
});

await check("record refuses marked steps without confirmation", async () => {
  const before = counts.pay;
  const out = join(T, "record-unconfirmed");
  const r = await run(["record", SHOP, "--out", out]);
  if (r.status !== 1) return `record exited ${r.status}`;
  if (!r.stderr.includes("--confirm-effects") || !new RegExp(`step ${SHOP_MARKED}\\b`).test(r.stderr)) return "record did not name the marked step and the flag";
  if (counts.pay !== before) return "record paid without confirmation";
  if (existsSync(join(out, "raw.mp4"))) return "record wrote a video";
  return true;
});

const SHOP_OUT = join(T, "record-shop");
const shopRun = { status: undefined };
await check("record writes the raw, captioned, and edited videos and the timeline", async () => {
  const before = counts.pay;
  const r = await run(["record", SHOP, "--out", SHOP_OUT, "--confirm-effects"]);
  Object.assign(shopRun, r);
  if (r.status !== 0) return `record exited ${r.status}: ${r.all.trim().split("\n").at(-1)}`;
  for (const name of ["raw.mp4", "captioned.mp4", "edited.mp4"]) {
    const size = probe(join(SHOP_OUT, name));
    if (size.width !== 1920 || size.height !== 1080) return `${name} is ${size.width}x${size.height}`;
  }
  const timeline = JSON.parse(readText(join(SHOP_OUT, "timeline.json")));
  if (!Array.isArray(timeline.steps) || timeline.steps.length < 6) return "timeline.json has too few steps";
  const cues = readText(join(SHOP_OUT, "captions.srt")).split(/\n\n+/).filter((block) => block.includes("-->"));
  if (cues.length !== SHOP_CAPTIONS) return `${cues.length} captions for ${SHOP_CAPTIONS} captioned steps`;
  if (counts.pay !== before + 1) return `the recording paid ${counts.pay - before} times`;
  // The cards stand on still frames added to the recording, so only the rest is compared with raw.mp4
  const added = (JSON.parse(readText(join(SHOP_OUT, "edit.json"))).freezes ?? []).reduce((sum, f) => sum + f.seconds, 0);
  if (probe(join(SHOP_OUT, "edited.mp4")).duration - added > probe(join(SHOP_OUT, "raw.mp4")).duration + 0.05) return "edited.mp4 without its cards is longer than raw.mp4";
  return true;
});

const PLAIN_OUT_DEFAULT = join(DATA, "project", "plain");
await check("record writes the vertical video and the GIF only when the flow asks", async () => {
  if (shopRun.status !== 0) return "the shop recording failed";
  const vertical = probe(join(SHOP_OUT, "vertical.mp4"));
  if (vertical.width !== 1080 || vertical.height !== 1920) return `vertical.mp4 is ${vertical.width}x${vertical.height}`;
  if (readFileSync(join(SHOP_OUT, "edited.gif")).subarray(0, 6).toString() !== "GIF89a") return "edited.gif is not a GIF";
  const r = await run(["record", PLAIN]);
  if (r.status !== 0) return `record of a flow without outputs exited ${r.status}: ${r.all.trim().split("\n").at(-1)}`;
  if (existsSync(join(PLAIN_OUT_DEFAULT, "vertical.mp4")) || existsSync(join(PLAIN_OUT_DEFAULT, "edited.gif"))) return "a flow without outputs got a vertical video or a GIF";
  return true;
});

await check("masked elements are blurred in the recording", async () => {
  if (shopRun.status !== 0) return "the shop recording failed";
  const timeline = JSON.parse(readText(join(SHOP_OUT, "timeline.json")));
  const opened = timeline.steps.find((step) => step.kind === "open");
  const at = opened.t + 1.2;
  const masked = detail(join(SHOP_OUT, "raw.mp4"), at, { x: 1196, y: 192, w: 420, h: 50 });
  const plain = detail(join(SHOP_OUT, "raw.mp4"), at, { x: 1196, y: 312, w: 420, h: 50 });
  if (plain < 3) return `the unmasked line shows no detail (${plain.toFixed(2)})`;
  if (masked > plain * 0.35) return `the masked line keeps detail (${masked.toFixed(2)} against ${plain.toFixed(2)})`;
  return true;
});

await check("press times line up with the video", async () => {
  const out = join(T, "record-toggle");
  const r = await run(["record", TOGGLE, "--out", out]);
  if (r.status !== 0) return `record exited ${r.status}: ${r.all.trim().split("\n").at(-1)}`;
  const pressed = JSON.parse(readText(join(out, "timeline.json"))).steps.filter((step) => step.kind === "click").map((step) => step.t);
  const changed = flips(join(out, "raw.mp4"));
  if (pressed.length !== 3 || changed.length !== 3) return `${pressed.length} presses and ${changed.length} changes`;
  const delays = pressed.map((t, i) => changed[i] - t).sort((a, b) => a - b);
  const middle = delays[1];
  if (middle < -1 / 30 || middle > 0.12) return `the middle delay is ${middle.toFixed(3)}s (${delays.map((d) => d.toFixed(3)).join(", ")})`;
  return true;
});

await check("login values never appear in output or files", async () => {
  const rehearsal = join(T, "rehearse-basic");
  const recording = join(T, "record-basic");
  const a = await run(["rehearse", BASIC, "--out", rehearsal]);
  if (a.status !== 0) return `rehearse exited ${a.status}: ${a.all.trim().split("\n").at(-1)}`;
  const b = await run(["record", BASIC, "--out", recording]);
  if (b.status !== 0) return `record exited ${b.status}: ${b.all.trim().split("\n").at(-1)}`;
  const texts = [a.all, b.all, ...[...filesUnder(rehearsal), ...filesUnder(recording)].filter((f) => /\.(json|html|srt|txt)$/.test(f)).map(readText)];
  if (texts.some((text) => text.includes(USER) || text.includes(PASS))) return "a login value appeared";
  return true;
});

await check("a saved session signs in and stays private", async () => {
  const login = await run(["login", SESSION, "--until", "/account"], { env: { SCREEN_VIDEO_HEADLESS: "1" } });
  if (login.status !== 0) return `login exited ${login.status}: ${login.all.trim().split("\n").at(-1)}`;
  const file = join(DATA, "sessions", "project--test.json");
  if (!existsSync(file)) return "no session file";
  if ((statSync(file).mode & 0o777) !== 0o600) return `the session file has mode ${(statSync(file).mode & 0o777).toString(8)}`;
  const r = await run(["rehearse", SESSION, "--out", join(T, "rehearse-session")]);
  if (r.status !== 0) return `rehearse with the session exited ${r.status}: ${r.all.trim().split("\n").at(-1)}`;
  return true;
});

await check("videos go to the data folder unless --out is given", async () => {
  if (!existsSync(join(PLAIN_OUT_DEFAULT, "raw.mp4"))) return `no raw.mp4 in ${PLAIN_OUT_DEFAULT}`;
  if (!existsSync(join(SHOP_OUT, "raw.mp4"))) return "--out was not used";
  if (existsSync(join(DATA, "project", "shop", "raw.mp4"))) return "a recording with --out also wrote to the data folder";
  return true;
});

await check("record refuses to clear a folder holding other files", async () => {
  const out = join(T, "record-occupied");
  mkdirSync(join(out, "notes"), { recursive: true });
  writeFileSync(join(out, "keep.md"), "keep me\n");
  const r = await run(["record", PLAIN, "--out", out]);
  if (r.status === 0) return "record cleared a folder holding other files";
  if (!r.stderr.includes("keep.md")) return "record did not name the file it would not remove";
  if (!existsSync(join(out, "keep.md")) || !existsSync(join(out, "notes"))) return "record removed the other files";
  if (existsSync(join(out, "raw.mp4"))) return "record wrote a video into the folder";
  return true;
});

await check("scenes and render caption a recording the user made", async () => {
  const clip = join(T, "mine.mov");
  const made = spawnSync(ffmpeg(), [
    "-hide_banner", "-loglevel", "error", "-y",
    "-f", "lavfi", "-i", "color=c=red:s=1280x720:r=30:d=2",
    "-f", "lavfi", "-i", "testsrc2=s=1280x720:r=30:d=3",
    "-f", "lavfi", "-i", "color=c=blue:s=1280x720:r=30:d=5",
    "-f", "lavfi", "-i", "testsrc2=s=1280x720:r=30:d=3",
    "-filter_complex", "[0:v][1:v][2:v][3:v]concat=n=4:v=1:a=0[v]", "-map", "[v]",
    "-c:v", "libx264", "-pix_fmt", "yuv420p", clip,
  ]);
  if (made.status !== 0) return "could not make the sample recording";
  const out = join(T, "mine");
  const scenes = await run(["scenes", clip, "--out", out]);
  if (scenes.status !== 0) return `scenes exited ${scenes.status}: ${scenes.all.trim().split("\n").at(-1)}`;
  const listed = JSON.parse(readText(join(out, "scenes.json")));
  for (const change of [2, 5, 10]) {
    if (!listed.some((scene) => Math.abs(scene.t - change) < 0.25 && existsSync(join(out, scene.file)))) return `no scene at ${change}s`;
  }
  const empty = join(T, "mine-without-captions");
  mkdirSync(empty, { recursive: true });
  const refused = await run(["render", clip, "--out", empty]);
  if (refused.status === 0 || !refused.stderr.includes("captions.json") || existsSync(join(empty, "captioned.mp4"))) return "render did not refuse without captions.json";
  writeFileSync(join(out, "captions.json"), JSON.stringify([
    { start: 0.3, end: 1.8, text: "Open the red screen" },
    { start: 2.3, end: 4.7, text: "Watch the pattern" },
    { start: 10.3, end: 12.7, text: "Watch it again" },
  ]));
  const rendered = await run(["render", clip, "--out", out]);
  if (rendered.status !== 0) return `render exited ${rendered.status}: ${rendered.all.trim().split("\n").at(-1)}`;
  const size = probe(join(out, "captioned.mp4"));
  if (size.width !== 1920 || size.height !== 1080) return `captioned.mp4 is ${size.width}x${size.height}`;
  const edited = probe(join(out, "edited.mp4")).duration;
  if (edited < 8 || edited > 9.6) return `edited.mp4 is ${edited.toFixed(1)}s`;
  return true;
});

await check("a capable system ffmpeg is preferred over the bundled one", async () => {
  const bin = join(T, "fake-ffmpeg");
  mkdirSync(join(bin, "capable"), { recursive: true });
  mkdirSync(join(bin, "plain"), { recursive: true });
  mkdirSync(join(bin, "none"), { recursive: true });
  writeFileSync(join(bin, "capable", "ffmpeg"), "#!/bin/sh\necho ' V....D libx264              libx264 H.264 / AVC'\n");
  writeFileSync(join(bin, "plain", "ffmpeg"), "#!/bin/sh\necho ' V....D libvpx               libvpx VP8'\n");
  chmodSync(join(bin, "capable", "ffmpeg"), 0o755);
  chmodSync(join(bin, "plain", "ffmpeg"), 0o755);
  const base = `${dirname(process.execPath)}:/usr/bin:/bin`;
  const read = async (dir) => {
    const r = await run(["doctor", "--json"], { env: { PATH: `${join(bin, dir)}:${base}` } });
    if (r.status !== 0) throw new Error(`doctor exited ${r.status}: ${r.all.trim().split("\n").at(-1)}`);
    return JSON.parse(r.stdout).ffmpeg;
  };
  const capable = await read("capable");
  if (capable.source !== "system" || capable.path !== join(bin, "capable", "ffmpeg")) return `with a capable ffmpeg: ${JSON.stringify(capable)}`;
  const plain = await read("plain");
  if (plain.source !== "bundled") return `with an ffmpeg without libx264: ${JSON.stringify(plain)}`;
  const none = await read("none");
  if (none.source !== "bundled") return `without an ffmpeg: ${JSON.stringify(none)}`;
  return true;
});

await check("setup installs the runtime into the data folder once", async () => {
  const bin = join(T, "fake-npm");
  const log = join(T, "npm.log");
  mkdirSync(bin, { recursive: true });
  writeFileSync(
    join(bin, "npm"),
    `#!/bin/sh
echo "npm $*" >> "${log}"
prefix=""
while [ $# -gt 0 ]; do
  if [ "$1" = "--prefix" ]; then prefix="$2"; shift; fi
  shift
done
mkdir -p "$prefix/node_modules/playwright-core" "$prefix/node_modules/ffmpeg-static"
echo '{"name":"playwright-core","version":"0.0.0"}' > "$prefix/node_modules/playwright-core/package.json"
echo 'require("node:fs").appendFileSync(${JSON.stringify(log)}, "cli " + process.argv.slice(2).join(" ") + String.fromCharCode(10));' > "$prefix/node_modules/playwright-core/cli.js"
echo '{"name":"ffmpeg-static","version":"0.0.0","main":"index.js"}' > "$prefix/node_modules/ffmpeg-static/package.json"
echo 'module.exports = "/nonexistent/ffmpeg";' > "$prefix/node_modules/ffmpeg-static/index.js"
`,
  );
  chmodSync(join(bin, "npm"), 0o755);
  const fresh = join(T, "fresh");
  const env = { SCREEN_VIDEO_HOME: fresh, SCREEN_VIDEO_NODE_DIR: "", PATH: `${bin}:${dirname(process.execPath)}:/usr/bin:/bin` };
  const first = await run(["setup"], { env });
  if (first.status !== 0) return `the first setup exited ${first.status}: ${first.all.trim().split("\n").at(-1)}`;
  const second = await run(["setup"], { env });
  if (second.status !== 0) return `the second setup exited ${second.status}: ${second.all.trim().split("\n").at(-1)}`;
  const installs = readText(log).split("\n").filter((line) => line.startsWith("npm "));
  if (installs.length !== 1) return `npm ran ${installs.length} times`;
  if (!/playwright-core@\d/.test(installs[0]) || !/ffmpeg-static@\d/.test(installs[0])) return `npm was not asked for both packages: ${installs[0]}`;
  if (!installs[0].includes(join(fresh, "node"))) return "npm did not install into the data folder's node/";
  return true;
});

await check("tests open only pages they serve on this machine", async () => {
  // Every page the recordings and rehearsals above opened is on the sample site.
  const records = filesUnder(T).filter((file) => /(timeline|rehearsal)\.json$/.test(file));
  if (records.length === 0) return "no recording or rehearsal left a record of the pages it opened";
  for (const file of records) {
    const opened = (JSON.parse(readText(file)).steps ?? []).filter((step) => typeof step.url === "string");
    if (opened.length === 0) return `${file} names no page it opened`;
    const away = opened.find((step) => !step.url.startsWith(`${BASE}/`));
    if (away !== undefined) return `${file} opened ${away.url}`;
  }
  for (const file of filesUnder(HERE)) {
    if (!/\.(mjs|sh|html|json)$/.test(file)) continue;
    for (const match of readText(file).matchAll(/https?:\/\/([^/\s"'`)]+)/g)) {
      if (!/^(127\.0\.0\.1|localhost)(:|$)/.test(match[1]) && !match[1].startsWith("${")) return `${file} names ${match[0]}`;
    }
  }
  return true;
});

// SHA-256 fingerprints of words from the product this plugin came from, so the check can look for them
// without naming them.
const FORBIDDEN = new Set([
  "80a6ce3690e26dddddf5aba89e1d3dcccc9fed6d6788bd4aea1d4d92efaff95e",
  "a674598126555c8941336ccbc4cf03097a41423af11e2a59c4fb582ba040e27b",
  "d0a35396d4aee8ed50214a0f21354e3a273eec2262c38657c12dcf12828e6432",
  "7e54a90317e49282e757beccec962446fcc850436ec5f1a39dd41fddceed1fd2",
  "ed04da6352487c632aa66e55889603f3c9fe8d6efe1dc49db3b69177037e15a3",
  "ad51d9621519807de9433b6be92705cea640ceb0fd3c83b3ef53c3e77e3a3c1c",
  "251dcbc6c33f62aec5df9cce6355021c2e8deeab0e84afd10fc255017de16b66",
  "d4fd2aa7a6c8b9437e553b6b1131c3fd9a9da3f1db683f21fa69ea666a659c4c",
  "37db61510364330601d9df5212a484a96fdc8d5c5c672cffb1e450759b03bf47",
]);
await check("the plugin names nothing from the product it came from", async () => {
  const files = filesUnder(PLUGIN).filter((file) => !/\.(png|jpe?g|gif|mp4|webm|ico)$/i.test(file));
  for (const name of ["README.md", "README.ja.md", join("skills", "screen-video", "SKILL.md"), join("skills", "screen-video", "scripts", "screen-video.sh")]) {
    if (!existsSync(join(PLUGIN, name))) return `the plugin has no ${name} to look through`;
  }
  for (const file of files) {
    for (const token of readText(file).toLowerCase().match(/[\p{L}\p{N}_.@-]+/gu) ?? []) {
      const parts = new Set([token, ...token.split(/[.@/]/), ...token.split(/[-.@/]/)]);
      for (const part of parts) {
        if (part !== "" && FORBIDDEN.has(createHash("sha256").update(part).digest("hex"))) return `${file} holds a word from the source product`;
      }
    }
  }
  return true;
});

// How the videos look and sound, checked on a site and data folder of their own (quality.mjs)
const { qualityChecks } = await import(join(HERE, "quality.mjs"));
await qualityChecks({ check, SHOP_OUT, FFMPEG });

server.close();
rmSync(T, { recursive: true, force: true });
process.stdout.write(`\n${passed} passed, ${failed} failed (${passed + failed} ran)\n`);
process.exit(failed === 0 ? 0 : 1);
