// Checks for how the videos look and sound, run from checks.mjs after its own checks.
//
// It serves its own copy of the sample site on 127.0.0.1, with the routes the quality pages call and
// stand-ins for the cloud voice services, and uses a throwaway project and data folder. Package
// managers on PATH are stand-ins too, so no voice engine is downloaded. With SCREEN_VIDEO_TTS_FAKE=1 the
// skill makes a 3000 Hz tone for each line instead of a voice, so the checks can find the voice in the
// sound; SCREEN_VIDEO_TTS_URL sends every cloud voice request to the stand-ins here.

import { spawn, spawnSync } from "node:child_process";
import { chmodSync, copyFileSync, existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { dirname, extname, join } from "node:path";

export async function qualityChecks({ check, SHOP_OUT, FFMPEG }) {
  const HERE = import.meta.dirname;
  const SKILL = join(HERE, "..");
  const SCRIPT = join(SKILL, "scripts", "screen-video.sh");
  const SITE = join(HERE, "fixtures", "site");
  const NODE_DIR = process.env.SCREEN_VIDEO_TEST_NODE_DIR || join(process.env.HOME ?? "", ".local", "share", "screen-video", "node");
  const THEMES = join(SKILL, "themes");

  const Q = mkdtempSync(join(tmpdir(), "screen-video-quality-"));
  const DATA = join(Q, "data");
  const PROJECT = join(Q, "project");
  const FLOWS = join(PROJECT, ".screen-video", "flows");
  mkdirSync(FLOWS, { recursive: true });
  mkdirSync(join(PROJECT, ".screen-video", "themes"), { recursive: true });
  mkdirSync(join(PROJECT, "assets"), { recursive: true });

  // Canary keys of the cloud voices. They must reach the stand-in services and never appear anywhere else.
  const KEYS = {
    openai: "canary-openai-7731",
    elevenlabs: "canary-eleven-4410",
    azure: "canary-azure-2286",
    google: "canary-google-9054",
  };
  writeFileSync(
    join(PROJECT, ".env.voice"),
    `OPENAI_API_KEY=${KEYS.openai}\nELEVENLABS_API_KEY=${KEYS.elevenlabs}\nAZURE_SPEECH_KEY=${KEYS.azure}\nAZURE_SPEECH_REGION=japaneast\nGOOGLE_TTS_API_KEY=${KEYS.google}\n`,
  );

  // --- a short sine as a WAV file -----------------------------------------------------------------

  function sineWav(seconds, frequency, rate = 24000, level = 0.5) {
    const samples = Math.round(seconds * rate);
    const data = Buffer.alloc(samples * 2);
    for (let i = 0; i < samples; i++) data.writeInt16LE(Math.round(Math.sin((2 * Math.PI * frequency * i) / rate) * level * 32767), i * 2);
    const head = Buffer.alloc(44);
    head.write("RIFF", 0);
    head.writeUInt32LE(36 + data.length, 4);
    head.write("WAVEfmt ", 8);
    head.writeUInt32LE(16, 16);
    head.writeUInt16LE(1, 20);
    head.writeUInt16LE(1, 22);
    head.writeUInt32LE(rate, 24);
    head.writeUInt32LE(rate * 2, 28);
    head.writeUInt16LE(2, 32);
    head.writeUInt16LE(16, 34);
    head.write("data", 36);
    head.writeUInt32LE(data.length, 40);
    return Buffer.concat([head, data]);
  }

  // A song of one 2500 Hz tone, far above anything the made music plays.
  writeFileSync(join(PROJECT, "assets", "song.wav"), sineWav(60, 2500, 24000, 0.5));

  // --- the site and the stand-in services ---------------------------------------------------------

  const times = { streamDone: undefined, next: undefined };
  const voiceCalls = [];
  const TYPES = { ".html": "text/html; charset=utf-8", ".png": "image/png" };
  const readBody = (req) => new Promise((resolve) => {
    let body = "";
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => resolve(body));
  });
  const server = createServer(async (req, res) => {
    const url = new URL(req.url, "http://127.0.0.1");
    if (req.method === "POST" && url.pathname === "/api/stream-done") {
      times.streamDone = Date.now();
      res.end("{}");
      return;
    }
    if (req.method === "POST" && url.pathname === "/api/next") {
      times.next = Date.now();
      res.end("{}");
      return;
    }
    // Stand-ins for the four cloud voices. Each one records the key it was sent and the text to read.
    const audio = sineWav(0.8, 440);
    if (req.method === "POST" && url.pathname === "/v1/audio/speech") {
      const body = JSON.parse((await readBody(req)) || "{}");
      voiceCalls.push({ provider: "openai", key: (req.headers.authorization ?? "").replace(/^Bearer /, ""), text: body.input ?? "" });
      res.setHeader("content-type", "audio/wav");
      res.end(audio);
      return;
    }
    if (req.method === "POST" && url.pathname.startsWith("/v1/text-to-speech/")) {
      const body = JSON.parse((await readBody(req)) || "{}");
      voiceCalls.push({ provider: "elevenlabs", key: req.headers["xi-api-key"] ?? "", text: body.text ?? "" });
      res.setHeader("content-type", "audio/wav");
      res.end(audio);
      return;
    }
    if (req.method === "POST" && url.pathname === "/cognitiveservices/v1") {
      const body = await readBody(req);
      voiceCalls.push({ provider: "azure", key: req.headers["ocp-apim-subscription-key"] ?? "", text: body.replace(/<[^>]+>/g, "").trim() });
      res.setHeader("content-type", "audio/wav");
      res.end(audio);
      return;
    }
    if (req.method === "POST" && url.pathname === "/v1/text:synthesize") {
      const body = JSON.parse((await readBody(req)) || "{}");
      voiceCalls.push({ provider: "google", key: req.headers["x-goog-api-key"] ?? "", text: body.input?.text ?? "" });
      res.setHeader("content-type", "application/json");
      res.end(JSON.stringify({ audioContent: audio.toString("base64") }));
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

  // --- stand-in package managers --------------------------------------------------------------------

  const BIN = join(Q, "bin");
  const INSTALLS = join(Q, "installs.log");
  mkdirSync(BIN, { recursive: true });
  writeFileSync(INSTALLS, "");
  // The user's python3 rather than /usr/bin's, which is 3.9 on macOS and too old for VOICEVOX CORE
  const python = spawnSync("/bin/sh", ["-c", "command -v python3"], { encoding: "utf8", env: { PATH: process.env.PATH ?? "/usr/bin:/bin" } }).stdout.trim() || "/usr/bin/python3";
  const tools = {
    npm: `#!/bin/sh
echo "npm $*" >> "${INSTALLS}"
prefix=""
for arg in "$@"; do
  if [ "$prev" = "--prefix" ]; then prefix="$arg"; fi
  prev="$arg"
done
for arg in "$@"; do
  case "$arg" in
    -*|install|add|"$prefix") ;;
    *) name="\${arg%@*}"; [ -z "$name" ] && name="$arg"; mkdir -p "$prefix/node_modules/$name"; echo '{"name":"'"$name"'","version":"0.0.0"}' > "$prefix/node_modules/$name/package.json" ;;
  esac
done
`,
    python3: `#!/bin/sh
if [ "$1" = "-m" ] && [ "$2" = "venv" ]; then
  shift 2
  for arg in "$@"; do case "$arg" in -*) ;; *) dir="$arg" ;; esac; done
  echo "venv $dir" >> "${INSTALLS}"
  mkdir -p "$dir/bin"
  printf '#!/bin/sh\\necho "pip $*" >> "${INSTALLS}"\\n' > "$dir/bin/pip"
  printf '#!/bin/sh\\nif [ "$1" = "-m" ] && [ "$2" = "pip" ]; then shift 2; echo "pip $*" >> "${INSTALLS}"; exit 0; fi\\nexec "${python}" "$@"\\n' > "$dir/bin/python"
  chmod +x "$dir/bin/pip" "$dir/bin/python"
  exit 0
fi
exec "${python}" "$@"
`,
    curl: `#!/bin/sh
echo "curl $*" >> "${INSTALLS}"
out=""
for arg in "$@"; do
  if [ "$prev" = "-o" ] || [ "$prev" = "--output" ]; then out="$arg"; fi
  prev="$arg"
done
if [ -n "$out" ]; then mkdir -p "$(dirname "$out")"; printf '#!/bin/sh\\nexit 0\\n' > "$out"; chmod +x "$out"; fi
exit 0
`,
  };
  for (const [name, body] of Object.entries(tools)) {
    writeFileSync(join(BIN, name), body);
    chmodSync(join(BIN, name), 0o755);
  }
  const PATH = `${BIN}:${dirname(process.execPath)}:/usr/bin:/bin`;
  const installs = () => readFileSync(INSTALLS, "utf8").split("\n").filter((line) => line !== "");

  // --- helpers ------------------------------------------------------------------------------------

  function run(args, { env = {}, timeout = 600_000 } = {}) {
    return new Promise((resolve) => {
      const started = Date.now();
      const child = spawn("bash", [SCRIPT, ...args], {
        cwd: PROJECT,
        env: {
          ...process.env,
          PATH,
          SCREEN_VIDEO_HOME: DATA,
          SCREEN_VIDEO_NODE_DIR: NODE_DIR,
          SCREEN_VIDEO_TTS_FAKE: "1",
          SCREEN_VIDEO_TTS_URL: BASE,
          // The same ffmpeg as the other checks, since PATH here holds only the stand-ins and Node.js
          SCREEN_VIDEO_FFMPEG: FFMPEG,
          ...env,
        },
      });
      let stdout = "";
      let stderr = "";
      child.stdout.on("data", (chunk) => (stdout += chunk));
      child.stderr.on("data", (chunk) => (stderr += chunk));
      const timer = setTimeout(() => child.kill("SIGKILL"), timeout);
      child.on("close", (status) => {
        clearTimeout(timer);
        resolve({ status, stdout, stderr, all: `${stdout}${stderr}`, seconds: (Date.now() - started) / 1000 });
      });
    });
  }
  const last = (r) => r.all.trim().split("\n").at(-1);

  function flow(name, body) {
    const file = join(FLOWS, `${name}.json`);
    writeFileSync(file, `${JSON.stringify({ version: 1, name, url: BASE, ...body }, null, 2)}\n`);
    return file;
  }

  const ff =(args, options = {}) => spawnSync(FFMPEG, ["-hide_banner", ...args], { maxBuffer: 1 << 28, ...options });

  const readText = (file) => (existsSync(file) ? readFileSync(file, "utf8") : "");
  const readJson = (file) => {
    const text = readText(file);
    if (text === "") throw new Error(`no ${file.split("/").slice(-2).join("/")}`);
    return JSON.parse(text);
  };
  const filesUnder = (dir) =>
    existsSync(dir) ? readdirSync(dir, { withFileTypes: true }).flatMap((e) => (e.isDirectory() ? filesUnder(join(dir, e.name)) : [join(dir, e.name)])) : [];

  function banner(file) {
    return ff(["-i", file], { encoding: "utf8" }).stderr ?? "";
  }
  function duration(file) {
    const m = /Duration: (\d+):(\d+):([\d.]+)/.exec(banner(file));
    if (m === null) throw new Error(`cannot read ${file}`);
    return Number(m[1]) * 3600 + Number(m[2]) * 60 + Number(m[3]);
  }
  const hasAudio = (file) => /Stream #\d+:\d+.*Audio:/.test(banner(file));

  /** The mean colour of a 5x5 patch around (x, y) of the frame at `at` seconds. */
  function pixel(file, at, x, y) {
    const bytes = ff(["-loglevel", "error", "-ss", at.toFixed(3), "-i", file, "-frames:v", "1", "-vf", `crop=5:5:${Math.max(0, Math.round(x) - 2)}:${Math.max(0, Math.round(y) - 2)},format=rgb24`, "-f", "rawvideo", "-"]).stdout;
    if (bytes.length < 75) throw new Error(`cannot read a frame of ${file} at ${at.toFixed(2)}s`);
    const sum = [0, 0, 0];
    for (let i = 0; i < 75; i++) sum[i % 3] += bytes[i];
    return sum.map((v) => v / 25);
  }
  const hex = (color) => [1, 3, 5].map((i) => parseInt(color.slice(i, i + 2), 16));
  const near = (rgb, color, tolerance) => hex(color).every((v, i) => Math.abs(v - rgb[i]) <= tolerance);
  const luma = (rgb) => 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2];
  const show = (rgb) => `rgb(${rgb.map((v) => Math.round(v)).join(",")})`;

  /** RMS level in dB of the sound from `start` for `length` seconds, after `filter`. -120 when silent. */
  function rms(file, start, length, filter) {
    const text = ff(["-ss", start.toFixed(3), "-t", length.toFixed(3), "-i", file, "-vn", "-af", `${filter ? `${filter},` : ""}astats=measure_perchannel=none`, "-f", "null", "-"], { encoding: "utf8" }).stderr ?? "";
    const m = /RMS level dB:\s*(-?[\d.]+|-inf)/.exec(text);
    if (m === null) return -120;
    return m[1] === "-inf" ? -120 : Number(m[1]);
  }

  /** Times where sound starts after at least `gap` seconds below `floor` dB, after `filter`. */
  function onsets(file, filter, floor, gap = 0.05) {
    const text = ff(["-i", file, "-vn", "-af", `${filter},silencedetect=n=${floor}dB:d=${gap}`, "-f", "null", "-"], { encoding: "utf8" }).stderr ?? "";
    return [...text.matchAll(/silence_end: ([\d.]+)/g)].map((m) => Number(m[1]));
  }

  function md5(file, stream) {
    const out = ff(["-loglevel", "error", "-i", file, "-map", `0:${stream}`, "-f", "md5", "-"], { encoding: "utf8" });
    return out.status === 0 ? out.stdout.trim() : "";
  }

  function srt(file) {
    const stamp = (s) => {
      const [h, m, rest] = s.split(":");
      return Number(h) * 3600 + Number(m) * 60 + Number(rest.replace(",", "."));
    };
    return readText(file)
      .split(/\n\n+/)
      .map((block) => block.split("\n"))
      .filter((lines) => lines.some((line) => line.includes("-->")))
      .map((lines) => {
        const at = lines.findIndex((line) => line.includes("-->"));
        const [a, b] = lines[at].split("-->").map((s) => stamp(s.trim()));
        return { start: a, end: b, text: lines.slice(at + 1).join(" ").trim() };
      });
  }

  /** Reads every frame of a video, scaled to w x h, as RGB, and hands each to `onFrame(bytes, index)`. */
  function eachFrame(file, w, h, onFrame) {
    return new Promise((resolve, reject) => {
      const child = spawn(FFMPEG, ["-hide_banner", "-loglevel", "error", "-i", file, "-vf", `scale=${w}:${h}`, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]);
      const size = w * h * 3;
      let pending = Buffer.alloc(0);
      let index = 0;
      child.stdout.on("data", (chunk) => {
        pending = Buffer.concat([pending, chunk]);
        while (pending.length >= size) {
          onFrame(pending.subarray(0, size), index++);
          pending = pending.subarray(size);
        }
      });
      child.on("error", reject);
      child.on("close", () => resolve(index));
    });
  }

  /** The centre of the magenta marker in each frame (null where it is not seen), and the brightness of the middle. */
  async function track(file) {
    const w = 640;
    const h = 360;
    const marker = [];
    const middle = [];
    await eachFrame(file, w, h, (bytes) => {
      let n = 0;
      let sx = 0;
      let sy = 0;
      let mid = 0;
      let midN = 0;
      for (let y = 0; y < h; y++) {
        for (let x = 0; x < w; x++) {
          const i = (y * w + x) * 3;
          const r = bytes[i];
          const g = bytes[i + 1];
          const b = bytes[i + 2];
          if (r > 170 && g < 110 && b > 170) {
            n++;
            sx += x;
            sy += y;
          }
          if (x >= 220 && x < 420 && y >= 120 && y < 240) {
            mid += 0.299 * r + 0.587 * g + 0.114 * b;
            midN++;
          }
        }
      }
      marker.push(n >= 6 ? { x: sx / n, y: sy / n, n } : null);
      middle.push(mid / midN);
    });
    return { marker, middle };
  }

  function theme(name) {
    return JSON.parse(readFileSync(join(THEMES, `${name}.json`), "utf8"));
  }
  const firstColor = (value) => (Array.isArray(value) ? value[0] : value);
  const copyRecording = (from, to) => {
    mkdirSync(to, { recursive: true });
    for (const name of ["raw.mp4", "timeline.json"]) if (existsSync(join(from, name))) copyFileSync(join(from, name), join(to, name));
  };
  /** A time inside the recording part of the edited video, between the first chapter card and the next card. */
  const recordingTime = (edit) => {
    const cards = edit.cards ?? [];
    if (cards.length < 3) throw new Error("edit.json has fewer than 3 cards");
    return (cards[1].end + cards[2].start) / 2;
  };

  // --- flows ----------------------------------------------------------------------------------------

  const LONG = "Press the big blue button in the middle of the page to see what happens next";
  const STEPS = [
    { do: "open", url: "/quality/start.html", caption: "Open the sample page", chapter: "Start" },
    { do: "hold", seconds: 0.5 },
    { do: "fill", target: { label: "Note" }, text: "Hello there", caption: "Type a short note" },
    { do: "click", target: { role: "button", name: "Press me" }, caption: LONG },
    { do: "click", target: { role: "button", name: "Ask" }, caption: "Ask for an answer", chapter: "Answer" },
    { do: "wait", until: { settled: 1 }, timeout: 20, caption: "Wait until the answer settles" },
    { do: "click", target: { role: "button", name: "Thanks" }, caption: "Say thanks" },
    { do: "click", target: { role: "button", name: "Slow" }, caption: "Start the slow part" },
    { do: "wait", until: { text: "Slow done" }, timeout: 15 },
    { do: "click", target: { role: "link", name: "Next page" }, caption: "Go to the next page", chapter: "Next" },
    { do: "wait", until: { url: "next.html" }, timeout: 10 },
    { do: "hold", seconds: 1, caption: "The next page is open" },
  ];
  const FULL_BODY = {
    title: "Make a quality video",
    language: "en",
    outputs: ["16:9", "9:16", "gif"],
    voice: { engine: "local" },
    end: { title: "Thanks for watching", url: "example.org/start" },
    steps: STEPS,
  };
  const FULL = flow("quality", FULL_BODY);
  const FULL_OUT = join(Q, "full");

  const STEADY_BODY = {
    title: "A steady flow",
    language: "en",
    voice: { engine: "local" },
    end: { title: "The end" },
    steps: [
      { do: "open", url: "/quality/start.html", caption: "Open the sample page", chapter: "One" },
      { do: "click", target: { role: "button", name: "Press me" }, caption: "Press the button" },
      { do: "click", target: { role: "link", name: "Next page" }, caption: "Go to the next page", chapter: "Two" },
      { do: "wait", until: { url: "next.html" }, timeout: 10 },
      { do: "hold", seconds: 0.5 },
    ],
  };
  const STEADY = flow("steady", STEADY_BODY);

  writeFileSync(join(PROJECT, ".screen-video", "themes", "brand.json"), JSON.stringify({ background: "#00aa55", card: { background: "#aa0055" }, caption: { band: "#ffcc00" } }));
  writeFileSync(join(PROJECT, ".screen-video", "themes", "broken.json"), JSON.stringify({ background: "notacolor" }));

  const voiceSteps = (captions) => [{ do: "open", url: "/quality/start.html", caption: captions[0] }, { do: "hold", seconds: 1, caption: captions[1] }];
  const V_NONE = flow("voice-none", { steps: voiceSteps(["Open the page", "Look at it"]) });
  const V_EN = flow("voice-en", { language: "en", voice: { engine: "local" }, steps: voiceSteps(["Open the page", "Look at it"]) });
  // VOICEVOX asks the user to agree to its terms before its models are downloaded; the flow keeps the answer
  const V_JA = flow("voice-ja", { language: "ja", voice: { engine: "local", terms: "agreed" }, steps: voiceSteps(["頁を開く", "中身を見る"]) });
  const CLOUD_CAPTIONS = ["Open the page for the cloud", "Look at the cloud page"];
  const V_CLOUD = Object.fromEntries(
    Object.keys(KEYS).map((engine) => [engine, flow(`voice-${engine}`, { language: "en", voice: { engine, envFile: ".env.voice" }, steps: voiceSteps(CLOUD_CAPTIONS) })]),
  );

  // --- checks that need no recording ----------------------------------------------------------------

  await check("smaller targets get a closer zoom", async () => {
    const { zoomedBox } = await import(join(SKILL, "scripts", "lib", "edit.mjs"));
    const small = { x: 420, y: 680, width: 110, height: 44 };
    const large = { x: 200, y: 300, width: 700, height: 200 };
    const scale = (box) => zoomedBox(box).width / box.width;
    if (!(scale(small) > scale(large) + 0.2)) return `a 110px button is zoomed ${scale(small).toFixed(2)}x and a 700px one ${scale(large).toFixed(2)}x`;
    return true;
  });

  await check("check refuses a missing or broken theme", async () => {
    const missing = flow("theme-missing", { theme: "nope", steps: [{ do: "open", url: "/" }] });
    const broken = flow("theme-broken", { theme: "broken", steps: [{ do: "open", url: "/" }] });
    const a = await run(["check", missing]);
    if (a.status !== 1 || !a.all.includes("nope")) return `check of a missing theme exited ${a.status}: ${last(a)}`;
    const b = await run(["check", broken]);
    if (b.status !== 1 || !/background/.test(b.all)) return `check of a broken theme exited ${b.status}: ${last(b)}`;
    return true;
  });

  // Voices are made with the stand-in package managers into a fresh data folder.
  const FRESH = join(Q, "fresh");
  const fresh = { SCREEN_VIDEO_HOME: FRESH };
  const voiceRuns = {};
  await check("voice engines install into the data folder only when a flow needs them", async () => {
    writeFileSync(INSTALLS, "");
    const none = await run(["voices", V_NONE, "--out", join(Q, "voices-none")], { env: fresh });
    if (none.status !== 0) return `voices of a flow without narration exited ${none.status}: ${last(none)}`;
    if (installs().length > 0) return `a flow without narration installed: ${installs()[0]}`;
    voiceRuns.en = await run(["voices", V_EN, "--out", join(Q, "voices-en")], { env: fresh });
    if (voiceRuns.en.status !== 0) return `voices of an English flow exited ${voiceRuns.en.status}: ${last(voiceRuns.en)}`;
    const kokoro = installs().filter((line) => line.startsWith("npm ") && line.includes("kokoro-js@"));
    if (kokoro.length !== 1) return `kokoro-js was installed ${kokoro.length} times for the first English flow`;
    if (!kokoro[0].includes(join(FRESH, "voices"))) return `kokoro-js went outside the data folder: ${kokoro[0]}`;
    const again = await run(["voices", V_EN, "--out", join(Q, "voices-en-again")], { env: fresh });
    if (again.status !== 0) return `the second English voices exited ${again.status}: ${last(again)}`;
    if (installs().filter((line) => line.includes("kokoro-js@")).length !== 1) return "kokoro-js was installed again";
    voiceRuns.ja = await run(["voices", V_JA, "--out", join(Q, "voices-ja")], { env: fresh });
    if (voiceRuns.ja.status !== 0) return `voices of a Japanese flow exited ${voiceRuns.ja.status}: ${last(voiceRuns.ja)}`;
    const venv = installs().find((line) => line.startsWith("venv "));
    if (venv === undefined || !venv.includes(join(FRESH, "voices"))) return `VOICEVOX CORE got no environment in the data folder (${venv ?? "none"})`;
    if (!installs().some((line) => line.startsWith("pip ") && /voicevox[_-]core/i.test(line))) return "VOICEVOX CORE was not installed with pip";
    return true;
  });

  await check("local voices use Kokoro for English and VOICEVOX for Japanese", async () => {
    if (voiceRuns.en?.status !== 0 || voiceRuns.ja?.status !== 0) return "the voices runs failed";
    const en = readJson(join(Q, "voices-en", "voice.json"));
    const ja = readJson(join(Q, "voices-ja", "voice.json"));
    if (en.engine !== "kokoro") return `the English flow used ${en.engine}`;
    if (ja.engine !== "voicevox") return `the Japanese flow used ${ja.engine}`;
    for (const [name, made] of [["English", en], ["Japanese", ja]]) {
      if (!Array.isArray(made.clips) || made.clips.length !== 2) return `the ${name} flow made ${made.clips?.length ?? 0} clips for 2 captions`;
      for (const clip of made.clips) {
        if (!existsSync(join(Q, name === "English" ? "voices-en" : "voices-ja", clip.file))) return `no ${clip.file}`;
        if (!(clip.duration > 0.2)) return `a clip lasts ${clip.duration}s`;
      }
    }
    return true;
  });

  const cloudRuns = [];
  await check("each cloud voice is called only when the flow chooses it", async () => {
    for (const [engine, file] of Object.entries(V_CLOUD)) {
      voiceCalls.length = 0;
      const r = await run(["voices", file, "--out", join(Q, `voices-${engine}`)], { env: { SCREEN_VIDEO_TTS_FAKE: "" } });
      cloudRuns.push(r);
      if (r.status !== 0) return `voices with ${engine} exited ${r.status}: ${last(r)}`;
      const others = voiceCalls.filter((call) => call.provider !== engine);
      if (others.length > 0) return `the ${engine} flow called ${others[0].provider}`;
      if (voiceCalls.length !== CLOUD_CAPTIONS.length) return `the ${engine} flow made ${voiceCalls.length} calls for ${CLOUD_CAPTIONS.length} captions`;
      if (voiceCalls.some((call) => call.key !== KEYS[engine])) return `the ${engine} flow did not send its key from the env file`;
      if (!CLOUD_CAPTIONS.every((text) => voiceCalls.some((call) => call.text.includes(text)))) return `the ${engine} flow did not send each caption to read`;
      const made = readJson(join(Q, `voices-${engine}`, "voice.json"));
      if (made.engine !== engine) return `voice.json names ${made.engine} for the ${engine} flow`;
    }
    return true;
  });

  await check("cloud voice keys never appear in output or files", async () => {
    if (cloudRuns.length !== Object.keys(KEYS).length) return "the cloud voices did not all run";
    const written = Object.keys(KEYS).flatMap((engine) => filesUnder(join(Q, `voices-${engine}`))).filter((f) => /\.(json|txt|srt|html)$/.test(f));
    const texts = [...cloudRuns.map((r) => r.all), ...written.map(readText)];
    for (const [engine, key] of Object.entries(KEYS)) if (texts.some((text) => text.includes(key))) return `the ${engine} key appeared`;
    return true;
  });

  // --- the full recording -----------------------------------------------------------------------------

  voiceCalls.length = 0;
  writeFileSync(INSTALLS, "");
  times.streamDone = undefined;
  times.next = undefined;
  const full = await run(["record", FULL, "--out", FULL_OUT]);
  const localCalls = voiceCalls.length;
  const localInstalls = installs();
  const fullOk = () => (full.status === 0 ? true : `the full recording exited ${full.status}: ${last(full)}`);
  const fullEdit = () => readJson(join(FULL_OUT, "edit.json"));
  const fullTimeline = () => readJson(join(FULL_OUT, "timeline.json"));
  const stepEntry = (timeline, number) => {
    const entry = timeline.steps.find((step) => step.step === number);
    if (entry === undefined) throw new Error(`timeline.json has no entry for step ${number}`);
    return entry;
  };
  let tracked;
  const tracking = async () => (tracked ??= await track(join(FULL_OUT, "edited.mp4")));

  await check("a 30 second flow with every point finishes within 5 minutes", async () => {
    const ok = fullOk();
    if (ok !== true) return ok;
    const length = duration(join(FULL_OUT, "edited.mp4"));
    if (length < 25) return `the edited video is ${length.toFixed(1)}s, shorter than a 30 second flow`;
    if (full.seconds > 300) return `recording and making the videos took ${full.seconds.toFixed(0)}s`;
    return true;
  });

  await check("the zoom eases in and out without jumps", async () => {
    const ok = fullOk();
    if (ok !== true) return ok;
    const { marker } = await tracking();
    const moves = [];
    let current = [];
    for (let i = 1; i < marker.length; i++) {
      const a = marker[i - 1];
      const b = marker[i];
      const step = a && b ? Math.hypot(b.x - a.x, b.y - a.y) : 0;
      if (a && b && step > 0.4) current.push(step);
      else if (current.length > 0) {
        moves.push(current);
        current = [];
      }
    }
    if (current.length > 0) moves.push(current);
    const real = moves.filter((move) => move.reduce((s, v) => s + v, 0) >= 15);
    if (real.length === 0) return "the view never moved over the marker";
    for (const [index, move] of real.entries()) {
      const peak = Math.max(...move);
      if (move.length < 18) return `move ${index + 1} took ${move.length} frames, under 0.6 seconds`;
      const jump = Math.max(...move.slice(1).map((v, i) => Math.abs(v - move[i])));
      if (jump > 0.2 * peak + 0.5) return `move ${index + 1} changed speed by ${jump.toFixed(2)}px in one frame (peak ${peak.toFixed(2)}px)`;
      const ends = [...move.slice(0, 3), ...move.slice(-3)];
      if (Math.max(...ends) > 0.45 * peak) return `move ${index + 1} starts or stops at ${Math.max(...ends).toFixed(2)}px a frame (peak ${peak.toFixed(2)}px)`;
    }
    return true;
  });

  await check("the pointer moves on a curve and slows near the target", async () => {
    const ok = fullOk();
    if (ok !== true) return ok;
    const clicks = fullTimeline().steps.filter((step) => step.kind === "click");
    for (const click of clicks) {
      const path = click.path;
      if (!Array.isArray(path) || path.length < 8) return `the click of step ${click.step} has no pointer path`;
      const a = path[0];
      const b = path.at(-1);
      const length = Math.hypot(b.x - a.x, b.y - a.y);
      if (length < 80) continue;
      const centre = { x: click.box.x + click.box.width / 2, y: click.box.y + click.box.height / 2 };
      if (Math.hypot(b.x - centre.x, b.y - centre.y) > Math.max(8, click.box.width / 2)) return `the pointer of step ${click.step} ends away from its target`;
      const off = Math.max(...path.map((p) => Math.abs((b.x - a.x) * (a.y - p.y) - (a.x - p.x) * (b.y - a.y)) / length));
      if (off < 0.03 * length) return `the pointer of step ${click.step} moves on a straight line (${off.toFixed(1)}px off it over ${length.toFixed(0)}px)`;
      const speeds = path.slice(1).map((p, i) => Math.hypot(p.x - path[i].x, p.y - path[i].y) / Math.max(1e-3, p.t - path[i].t));
      const tail = speeds.slice(Math.floor(speeds.length * 0.8));
      if (tail.reduce((s, v) => s + v, 0) / tail.length > 0.5 * Math.max(...speeds)) return `the pointer of step ${click.step} does not slow before the target`;
    }
    return true;
  });

  await check("a press shows a ring and sinks the button", async () => {
    const ok = fullOk();
    if (ok !== true) return ok;
    const press = stepEntry(fullTimeline(), 4);
    const raw = join(FULL_OUT, "raw.mp4");
    // The width of the blue button along a row near its top, out of the ring's reach
    const width = (at) => {
      const bytes = ff(["-loglevel", "error", "-ss", at.toFixed(3), "-i", raw, "-frames:v", "1", "-vf", "crop=900:1:100:320,format=rgb24", "-f", "rawvideo", "-"]).stdout;
      let n = 0;
      for (let i = 0; i + 2 < bytes.length; i += 3) if (bytes[i] < 80 && bytes[i + 1] < 120 && bytes[i + 2] > 170) n++;
      return n;
    };
    const before = width(press.t - 0.4);
    const sunk = Math.min(width(press.t + 0.03), width(press.t + 0.07), width(press.t + 0.1));
    if (before < 650) return `the button is ${before}px wide before the press`;
    if (sunk > before * 0.98) return `the button stays ${sunk}px wide when pressed (${before}px before)`;
    const centre = { x: press.box.x + press.box.width / 2, y: press.box.y + press.box.height / 2 };
    // On the blue just below the label and left of the pointer: on the white label the see-through ring
    // darkens the letters as much as it lightens the blue between them, so their average hardly moves
    const spot = { x: centre.x - 30, y: centre.y + 24 };
    const ringAt = pixel(raw, press.t + 0.15, spot.x, spot.y);
    const plainAt = pixel(raw, press.t - 0.4, spot.x, spot.y);
    if (Math.abs(luma(ringAt) - luma(plainAt)) < 12 && Math.abs(ringAt[1] - plainAt[1]) < 20) return "no ring shows where the button was pressed";
    return true;
  });

  await check("page changes dissolve into each other", async () => {
    const ok = fullOk();
    if (ok !== true) return ok;
    const { middle } = await tracking();
    // The last change from a white stretch of half a second or more to dark is the move to the dark page
    let change;
    let lastBright = -1;
    let brightRun = 0;
    for (let i = 0; i < middle.length; i++) {
      if (middle[i] > 200) {
        brightRun = lastBright === i - 1 ? brightRun + 1 : 1;
        lastBright = i;
      } else if (middle[i] < 40) {
        if (lastBright >= 0 && brightRun >= 15) change = { from: lastBright, to: i };
        lastBright = -1;
        brightRun = 0;
      }
    }
    if (change === undefined) return "the edited video never goes from the white page to the dark one";
    const between = middle.slice(change.from + 1, change.to).filter((v) => v >= 60 && v <= 180).length;
    if (between < 5) return `the change to the dark page takes ${between} frames in between`;
    return true;
  });

  await check("the edited video sets the screen in a frame on the theme background", async () => {
    const ok = fullOk();
    if (ok !== true) return ok;
    const edit = fullEdit();
    const frame = edit.frame;
    if (frame === undefined) return "edit.json does not say where the screen sits";
    const at = recordingTime(edit);
    const file = join(FULL_OUT, "edited.mp4");
    const background = firstColor(theme("default").background);
    const corner = pixel(file, at, 8, 8);
    if (!near(corner, background, 30)) return `the corner is ${show(corner)}, not the theme background ${background}`;
    const content = pixel(file, at, frame.x + 60, frame.y + frame.height / 2);
    const rounded = pixel(file, at, frame.x + 2, frame.y + 2);
    if (Math.abs(luma(rounded) - luma(content)) < 40) return `the window corner ${show(rounded)} looks like the page ${show(content)}, so it is not rounded`;
    const y = frame.y + frame.height * 0.6;
    const shadow = pixel(file, at, frame.x + frame.width + 8, y);
    const away = pixel(file, at, frame.x + frame.width + 60, y);
    if (luma(shadow) > luma(away) - 4) return `no shadow beside the window (${show(shadow)} next to it, ${show(away)} away)`;
    return true;
  });

  await check("title, chapter, and end cards appear in order", async () => {
    const ok = fullOk();
    if (ok !== true) return ok;
    const edit = fullEdit();
    const cards = edit.cards ?? [];
    const wanted = [["title", "Make a quality video"], ["chapter", "Start"], ["chapter", "Answer"], ["chapter", "Next"], ["end", "Thanks for watching"]];
    if (cards.length !== wanted.length) return `${cards.length} cards for ${wanted.length}`;
    for (const [i, [kind, text]] of wanted.entries()) {
      if (cards[i].kind !== kind || !String(cards[i].text).includes(text)) return `card ${i + 1} is ${cards[i].kind} "${cards[i].text}", not ${kind} "${text}"`;
      if (i > 0 && cards[i].start < cards[i - 1].end) return `card ${i + 1} starts before card ${i} ends`;
    }
    const file = join(FULL_OUT, "edited.mp4");
    const length = duration(file);
    if (Math.abs(cards.at(-1).end - length) > 0.25) return `the end card ends at ${cards.at(-1).end}s of ${length.toFixed(2)}s`;
    const background = theme("default").card.background;
    for (const card of cards) {
      const seen = pixel(file, (card.start + card.end) / 2, 8, 8);
      if (!near(seen, background, 30)) return `the ${card.kind} card shows ${show(seen)}, not ${background}`;
    }
    return true;
  });

  await check("each caption is read aloud when it appears", async () => {
    const ok = fullOk();
    if (ok !== true) return ok;
    const file = join(FULL_OUT, "edited.mp4");
    if (!hasAudio(file)) return "edited.mp4 has no sound";
    const cues = srt(join(FULL_OUT, "edited.srt"));
    if (cues.length < 8) return `edited.srt has ${cues.length} captions`;
    const voice = "highpass=f=2600,lowpass=f=3400";
    for (const cue of cues) {
      const after = rms(file, cue.start + 0.05, 0.3, voice);
      const before = rms(file, Math.max(0, cue.start - 0.45), 0.35, voice);
      if (after < -40 || after - before < 10) return `no voice when "${cue.text}" appears (${after.toFixed(1)} dB after, ${before.toFixed(1)} dB before)`;
    }
    return true;
  });

  await check("each caption lasts until its voice ends", async () => {
    const ok = fullOk();
    if (ok !== true) return ok;
    const voice = readJson(join(FULL_OUT, "voice.json"));
    const timeline = fullTimeline();
    const cues = srt(join(FULL_OUT, "edited.srt"));
    for (const clip of voice.clips ?? []) {
      const next = timeline.steps.find((step) => step.step === clip.step + 1);
      if (next !== undefined && next.t < clip.start + clip.duration - 0.05) return `step ${clip.step + 1} starts ${(clip.start + clip.duration - next.t).toFixed(2)}s before the voice of step ${clip.step} ends`;
      const cue = cues.find((c) => c.text === clip.text);
      if (cue === undefined) return `no caption "${clip.text}" in edited.srt`;
      if (cue.end - cue.start < clip.duration - 0.1) return `"${clip.text}" shows for ${(cue.end - cue.start).toFixed(2)}s and is read for ${clip.duration.toFixed(2)}s`;
    }
    if ((voice.clips ?? []).length < 8) return `voice.json has ${(voice.clips ?? []).length} clips`;
    return true;
  });

  await check("each caption stays long enough to read", async () => {
    const ok = fullOk();
    if (ok !== true) return ok;
    const cues = srt(join(FULL_OUT, "captions.srt"));
    const long = cues.find((cue) => cue.text === LONG);
    if (long === undefined) return "no long caption in captions.srt";
    for (const cue of cues) {
      const needed = Math.max(1.2, cue.text.length / 17) * 0.95;
      if (cue.end - cue.start < needed) return `"${cue.text.slice(0, 30)}" shows for ${(cue.end - cue.start).toFixed(2)}s, under ${needed.toFixed(2)}s`;
    }
    return true;
  });

  await check("a settled wait goes on once the page stops changing", async () => {
    const ok = fullOk();
    if (ok !== true) return ok;
    if (times.streamDone === undefined || times.next === undefined) return "the answer or the thanks never reached the sample server";
    const gap = (times.next - times.streamDone) / 1000;
    if (gap < 0.95) return `the next step came ${gap.toFixed(2)}s after the answer stopped, before it had settled`;
    if (gap > 3) return `the next step came ${gap.toFixed(2)}s after the answer stopped`;
    return true;
  });

  await check("long waits play fast with a mark instead of being cut", async () => {
    const ok = fullOk();
    if (ok !== true) return ok;
    const edit = fullEdit();
    const wait = stepEntry(fullTimeline(), 9);
    const inside = (s) => s.start <= wait.t + 0.1 && s.end >= wait.end - 0.1;
    const covered = (edit.segments ?? []).filter((s) => s.end > wait.t + 0.1 && s.start < wait.end - 0.1);
    const kept = covered.reduce((sum, s) => sum + Math.min(s.end, wait.end - 0.1) - Math.max(s.start, wait.t + 0.1), 0);
    if (kept < wait.end - wait.t - 0.3) return `${(wait.end - wait.t - kept).toFixed(2)}s of the ${(wait.end - wait.t).toFixed(2)}s wait was cut`;
    if (!covered.some((s) => (s.speed ?? 1) > 1.5) && !(edit.segments ?? []).some((s) => inside(s) && (s.speed ?? 1) > 1.5)) return "the long wait does not play fast";
    const fast = (edit.fast ?? [])[0];
    if (fast === undefined || fast.box === undefined) return "edit.json shows no fast-forward mark";
    const file = join(FULL_OUT, "edited.mp4");
    const during = pixel(file, (fast.start + fast.end) / 2, fast.box.x + fast.box.width / 2, fast.box.y + fast.box.height / 2);
    const after = pixel(file, fast.end + 0.6, fast.box.x + fast.box.width / 2, fast.box.y + fast.box.height / 2);
    if (Math.abs(luma(during) - luma(after)) < 25) return `the mark does not show (${show(during)} during, ${show(after)} after)`;
    return true;
  });

  await check("a local voice sends nothing off the machine", async () => {
    if (localCalls > 0) return `the recording with a local voice called a cloud voice ${localCalls} times`;
    const lines = [...localInstalls, ...installs()];
    const captions = STEPS.map((step) => step.caption).filter(Boolean);
    if (lines.some((line) => captions.some((caption) => line.includes(caption)))) return "a caption was handed to a download";
    return true;
  });

  // --- the same recording made again with other looks ------------------------------------------------

  const JA_OUT = join(Q, "full-ja");
  const SONG_OUT = join(Q, "full-song");
  const FIT_OUT = join(Q, "full-fit");
  copyRecording(FULL_OUT, JA_OUT);
  copyRecording(FULL_OUT, SONG_OUT);
  copyRecording(FULL_OUT, FIT_OUT);
  const ja = await run(["remake", flow("quality-ja", { ...FULL_BODY, language: "ja", voice: { engine: "local", terms: "agreed" }, sounds: false }), "--out", JA_OUT]);
  const { voice: _voice, ...withoutVoice } = FULL_BODY;
  const song = await run(["remake", flow("quality-song", { ...withoutVoice, music: { file: "assets/song.wav" } }), "--out", SONG_OUT]);
  const natural = full.status === 0 ? duration(join(FULL_OUT, "edited.mp4")) : 30;
  const planned = Math.floor(natural * 0.85);
  const fit = await run(["remake", flow("quality-fit", { ...FULL_BODY, theme: "brand", seconds: planned }), "--out", FIT_OUT]);

  await check("VOICEVOX voices are credited on the end card and in credits.txt", async () => {
    if (ja.status !== 0) return `remake in Japanese exited ${ja.status}: ${last(ja)}`;
    const voice = readJson(join(JA_OUT, "voice.json"));
    if (voice.engine !== "voicevox") return `the Japanese remake used ${voice.engine}`;
    const credits = readText(join(JA_OUT, "credits.txt"));
    if (!/VOICEVOX:\S+/.test(credits)) return "credits.txt does not credit the VOICEVOX voice";
    const end = (readJson(join(JA_OUT, "edit.json")).cards ?? []).find((card) => card.kind === "end");
    if (end === undefined || !/VOICEVOX:\S+/.test(JSON.stringify(end))) return "the end card does not credit the VOICEVOX voice";
    return true;
  });

  await check("music plays under the video and ducks under the voice", async () => {
    if (ja.status !== 0) return `remake in Japanese exited ${ja.status}: ${last(ja)}`;
    const file = join(JA_OUT, "edited.mp4");
    if (!hasAudio(file)) return "edited.mp4 has no sound";
    const low = "lowpass=f=600,lowpass=f=600,lowpass=f=600";
    const cues = srt(join(JA_OUT, "edited.srt"));
    const clips = readJson(join(JA_OUT, "voice.json")).clips ?? [];
    const voiced = [];
    const quiet = [];
    cues.forEach((cue, i) => {
      const clip = clips.find((c) => c.text === cue.text);
      const end = cue.start + (clip?.duration ?? 1);
      if (end - cue.start > 0.6) voiced.push(rms(file, cue.start + 0.2, 0.4, low));
      const next = cues[i + 1]?.start ?? cue.end + 1;
      if (next - 0.1 - (end + 0.3) >= 0.4) quiet.push(rms(file, end + 0.3, Math.min(1, next - 0.1 - (end + 0.3)), low));
    });
    if (voiced.length < 3 || quiet.length < 2) return `only ${voiced.length} voiced and ${quiet.length} quiet stretches to compare`;
    const mean = (list) => list.reduce((s, v) => s + v, 0) / list.length;
    if (mean(quiet) < -45) return `the music is ${mean(quiet).toFixed(1)} dB between the voices, too quiet to hear`;
    if (mean(voiced) > mean(quiet) - 4) return `the music is ${mean(voiced).toFixed(1)} dB under the voice and ${mean(quiet).toFixed(1)} dB between, so it does not duck`;
    return true;
  });

  await check("a music file from the project replaces the made music", async () => {
    if (song.status !== 0) return `remake with a music file exited ${song.status}: ${last(song)}`;
    if (ja.status !== 0) return `remake in Japanese exited ${ja.status}: ${last(ja)}`;
    const tone = "bandpass=f=2500:width_type=h:w=200";
    const mine = rms(join(SONG_OUT, "edited.mp4"), 1, 6, tone);
    const made = rms(join(JA_OUT, "edited.mp4"), 1, 6, tone);
    if (mine < -30) return `the music file is ${mine.toFixed(1)} dB in the video`;
    if (made > -45) return `the made music already holds the file's tone (${made.toFixed(1)} dB)`;
    return true;
  });

  await check("presses and typing make a sound at their times", async () => {
    if (song.status !== 0) return `remake with a music file exited ${song.status}: ${last(song)}`;
    const file = join(SONG_OUT, "captioned.mp4");
    if (!hasAudio(file)) return "captioned.mp4 has no sound";
    const heard = onsets(file, "highpass=f=6000,highpass=f=6000,highpass=f=6000", -50);
    const timeline = readJson(join(SONG_OUT, "timeline.json"));
    for (const click of timeline.steps.filter((step) => step.kind === "click")) {
      if (!heard.some((t) => t >= click.t - 0.06 && t <= click.t + 0.15)) return `no sound when step ${click.step} clicks at ${click.t.toFixed(2)}s`;
    }
    const typing = stepEntry(timeline, 3);
    const keys = heard.filter((t) => t >= typing.t - 0.05 && t <= typing.end + 0.05);
    if (keys.length < 5) return `${keys.length} sounds while typing "Hello there"`;
    return true;
  });

  await check("a flow picks a bundled theme or one of its own", async () => {
    const shown = async (body) => {
      const r = await run(["check", flow(`theme-${body.theme ?? "none"}`, { ...body, steps: [{ do: "open", url: "/" }] })]);
      return r.status === 0 ? (/theme: (\S+) \((bundled|project)\)/.exec(r.stdout) ?? [])[0] ?? r.stdout : `exit ${r.status}: ${last(r)}`;
    };
    for (const [body, wanted] of [[{}, "theme: default (bundled)"], [{ theme: "midnight" }, "theme: midnight (bundled)"], [{ theme: "brand" }, "theme: brand (project)"]]) {
      const said = await shown(body);
      if (said !== wanted) return `check said "${said}" for ${JSON.stringify(body)}`;
    }
    if (fit.status !== 0) return `remake with the project theme exited ${fit.status}: ${last(fit)}`;
    const edit = readJson(join(FIT_OUT, "edit.json"));
    const file = join(FIT_OUT, "edited.mp4");
    const corner = pixel(file, recordingTime(edit), 8, 8);
    if (!near(corner, "#00aa55", 30)) return `the project theme's background shows as ${show(corner)}`;
    const card = pixel(file, (edit.cards[0].start + edit.cards[0].end) / 2, 8, 8);
    if (!near(card, "#aa0055", 30)) return `the project theme's card shows as ${show(card)}`;
    return true;
  });

  await check("captions fade in and out in the theme look", async () => {
    const ok = fullOk();
    if (ok !== true) return ok;
    const edit = fullEdit();
    const captions = edit.captions ?? [];
    if (captions.length < 3) return `edit.json has ${captions.length} captions`;
    const file = join(FULL_OUT, "edited.mp4");
    const change = (caption, at, base) => {
      const b = caption.box;
      const points = [[b.x + 8, b.y + b.height / 2], [b.x + b.width / 2, b.y + 6], [b.x + b.width - 8, b.y + b.height / 2]];
      return points.reduce((sum, [x, y], i) => sum + Math.abs(luma(pixel(file, at, x, y)) - luma(base[i])), 0) / points.length;
    };
    for (const caption of captions.slice(0, 3)) {
      const b = caption.box;
      const points = [[b.x + 8, b.y + b.height / 2], [b.x + b.width / 2, b.y + 6], [b.x + b.width - 8, b.y + b.height / 2]];
      const base = points.map(([x, y]) => pixel(file, Math.max(0, caption.start - 0.1), x, y));
      const first = change(caption, caption.start + 1 / 30, base);
      const shown = change(caption, caption.start + 0.5, base);
      if (shown < 8) return `the caption "${caption.text}" barely shows (${shown.toFixed(1)})`;
      if (first > 0.6 * shown) return `the caption "${caption.text}" appears at once (${first.toFixed(1)} on the first frame, ${shown.toFixed(1)} later)`;
    }
    if (fit.status !== 0) return `remake with the project theme exited ${fit.status}: ${last(fit)}`;
    const fitCaption = (readJson(join(FIT_OUT, "edit.json")).captions ?? [])[0];
    if (fitCaption === undefined) return "the remake with the project theme has no captions";
    const band = pixel(join(FIT_OUT, "edited.mp4"), (fitCaption.start + fitCaption.end) / 2, fitCaption.box.x + 6, fitCaption.box.y + fitCaption.box.height / 2);
    if (!near(band, "#ffcc00", 45)) return `the project theme's caption band shows as ${show(band)}`;
    return true;
  });

  await check("the edited video fits the planned length", async () => {
    if (fit.status !== 0) return `remake with ${planned} planned seconds exited ${fit.status}: ${last(fit)}`;
    const length = duration(join(FIT_OUT, "edited.mp4"));
    if (Math.abs(length - planned) > planned * 0.1) return `the edited video is ${length.toFixed(1)}s for ${planned} planned seconds (${natural.toFixed(1)}s before)`;
    const edit = readJson(join(FIT_OUT, "edit.json"));
    if (edit.length?.planned !== planned) return "edit.json does not keep the planned length";
    const tooShort = join(Q, "full-too-short");
    copyRecording(FULL_OUT, tooShort);
    const r = await run(["remake", flow("quality-too-short", { ...FULL_BODY, seconds: 3 }), "--out", tooShort]);
    if (r.status !== 0) return `remake with 3 planned seconds exited ${r.status}: ${last(r)}`;
    if (!/longer than the planned 3s/.test(r.stdout)) return `remake with 3 planned seconds did not say how much longer it is: ${last(r)}`;
    return true;
  });

  await check("the vertical video and the GIF get the same look", async () => {
    const ok = fullOk();
    if (ok !== true) return ok;
    const edit = fullEdit();
    const vertical = join(FULL_OUT, "vertical.mp4");
    if (!hasAudio(vertical)) return "vertical.mp4 has no sound";
    const look = theme("default");
    const title = (edit.cards[0].start + edit.cards[0].end) / 2;
    const card = pixel(vertical, title, 10, 10);
    if (!near(card, look.card.background, 30)) return `the vertical title card shows ${show(card)}`;
    const corner = pixel(vertical, recordingTime(edit), 10, 10);
    if (!near(corner, firstColor(look.background), 30)) return `the vertical video's corner is ${show(corner)}, not the theme background`;
    const gif = pixel(join(FULL_OUT, "edited.gif"), title, 10, 10);
    if (!near(gif, look.card.background, 40)) return `the GIF's title card shows ${show(gif)}`;
    return true;
  });

  // --- a short flow recorded twice -------------------------------------------------------------------

  const STEADY_A = join(Q, "steady-a");
  const STEADY_B = join(Q, "steady-b");
  const a = await run(["record", STEADY, "--out", STEADY_A]);
  const b = await run(["record", STEADY, "--out", STEADY_B]);

  await check("recording a flow twice gives the same edit", async () => {
    if (a.status !== 0 || b.status !== 0) return `the steady recordings exited ${a.status} and ${b.status}: ${last(a.status !== 0 ? a : b)}`;
    const one = readJson(join(STEADY_A, "edit.json"));
    const two = readJson(join(STEADY_B, "edit.json"));
    const cards = (edit) => (edit.cards ?? []).map((card) => `${card.kind}:${card.text}`).join("|");
    if (cards(one) === "" || cards(one) !== cards(two)) return `the cards differ: ${cards(one)} and ${cards(two)}`;
    if (JSON.stringify(one.frame) !== JSON.stringify(two.frame)) return "the frame differs";
    if ((one.zooms ?? []).length !== (two.zooms ?? []).length) return `${(one.zooms ?? []).length} and ${(two.zooms ?? []).length} zooms`;
    for (const [i, zoom] of (one.zooms ?? []).entries()) {
      const other = two.zooms[i];
      if (["x", "y", "width", "height"].some((key) => Math.abs(zoom.box[key] - other.box[key]) > 4)) return `zoom ${i + 1} differs`;
    }
    const speeds = (edit) => (edit.segments ?? []).map((s) => s.speed ?? 1).join(",");
    if (speeds(one) !== speeds(two)) return `the cuts differ: ${speeds(one)} and ${speeds(two)}`;
    return true;
  });

  await check("remake makes the same videos twice", async () => {
    if (a.status !== 0) return `the steady recording exited ${a.status}: ${last(a)}`;
    const sums = [];
    for (let i = 0; i < 2; i++) {
      const r = await run(["remake", STEADY, "--out", STEADY_A]);
      if (r.status !== 0) return `remake ${i + 1} exited ${r.status}: ${last(r)}`;
      const file = join(STEADY_A, "edited.mp4");
      if (!hasAudio(file)) return "the remade video has no sound";
      sums.push(`${md5(file, "v")} ${md5(file, "a")}`);
    }
    if (sums[0] !== sums[1]) return "the two remakes differ";
    return true;
  });

  // --- the comparison page ---------------------------------------------------------------------------

  await check("compare shows the plain and new videos side by side for each point", async () => {
    const ok = fullOk();
    if (ok !== true) return ok;
    const r = await run(["compare", FULL, "--out", FULL_OUT]);
    if (r.status !== 0) return `compare exited ${r.status}: ${last(r)}`;
    const page = join(FULL_OUT, "compare", "compare.html");
    const html = readText(page);
    if (html === "") return "no compare/compare.html";
    const points = ["zoom", "pointer", "press", "transition", "frame", "cards", "end", "captions", "narration", "music", "sounds", "sync", "settled", "fastforward", "length", "reading"];
    for (const point of points) {
      const section = new RegExp(`<section[^>]*data-point="${point}"[^>]*>([\\s\\S]*?)</section>`).exec(html);
      if (section === null) return `compare.html has no section for ${point}`;
      const sources = [...section[1].matchAll(/<video[^>]*src="([^"]+)"/g)].map((m) => m[1].split("#")[0]);
      if (sources.length !== 2) return `the ${point} section has ${sources.length} videos`;
      if (!sources[0].includes("plain")) return `the ${point} section does not show the plain video first`;
      for (const source of sources) if (!existsSync(join(dirname(page), source))) return `the ${point} section names ${source}, which does not exist`;
    }
    return true;
  });

  await check("raw.mp4 stays the recording as it is", async () => {
    const raw = join(SHOP_OUT, "raw.mp4");
    if (!existsSync(raw)) return "the shop recording has no raw.mp4";
    if (hasAudio(raw)) return "raw.mp4 has sound";
    const header = pixel(raw, Math.min(2, duration(raw) / 2), 20, 20);
    if (!near(header, "#1d2733", 30)) return `the top left of raw.mp4 is ${show(header)}, not the page`;
    return true;
  });

  server.close();
  rmSync(Q, { recursive: true, force: true });
}
