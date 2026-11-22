/**
 * Narration: each caption (or the step's `say`) read aloud, made before the flow is recorded so the
 * recording can stay on each step until its voice ends.
 *
 * | Engine | Where the voice is made | What is installed, once, into `<data>/voices/` |
 * |---|---|---|
 * | `local` | Kokoro for English, VOICEVOX for Japanese | as below |
 * | `kokoro` | On this machine, with kokoro-js | `kokoro/`: kokoro-js through npm, and its model on first use |
 * | `voicevox` | On this machine, with VOICEVOX CORE | `voicevox/`: a Python virtual environment, VOICEVOX CORE through pip, and its downloader, models, and dictionary |
 * | `openai`, `elevenlabs`, `azure`, `google` | At that company. Each line's text is sent to it | nothing |
 *
 * Keys for the cloud voices are read from the env file the flow's `voice.envFile` names, or from the
 * environment, and are never printed or written. VOICEVOX's models come with terms of use the user
 * must agree to first (the flow says so with `voice.terms: "agreed"`), and each video made with a
 * VOICEVOX voice names the voice, as `VOICEVOX:<character>`, on its end card and in `credits.txt`.
 *
 * With `SCREEN_VIDEO_TTS_FAKE=1` no voice is made: each line becomes a quiet 3000 Hz tone as long as
 * the line would take to read, for tests. `SCREEN_VIDEO_TTS_URL` sends every cloud request to one
 * address instead of the companies', also for tests.
 */
import { spawnSync } from "node:child_process";
import { chmodSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

import { languageOf, parseEnvFile } from "./flow.mjs";
import { dataDir, ensureDir, ffmpegPath, SKILL_DIR } from "./runtime.mjs";

const KOKORO_PACKAGE = "kokoro-js@1.2.1";
const KOKORO_MODEL = "onnx-community/Kokoro-82M-v1.0-ONNX";
const VOICEVOX_VERSION = "0.16.4";
const VOICEVOX_RELEASES = `https://github.com/VOICEVOX/voicevox_core/releases/download/${VOICEVOX_VERSION}`;
/** The calm VOICEVOX narrator used when the flow names none: 冥鳴ひまり (Meimei Himari), normal style, in model 1. */
const VOICEVOX_DEFAULT = { model: 1, style: 14, character: "冥鳴ひまり" };

/** Each cloud engine's address, key variables, and default voices. */
const CLOUD = {
  openai: { host: "https://api.openai.com", keys: ["OPENAI_API_KEY"], voice: { en: "alloy", ja: "alloy" } },
  elevenlabs: { host: "https://api.elevenlabs.io", keys: ["ELEVENLABS_API_KEY"], voice: { en: "21m00Tcm4TlvDq8ikWAM", ja: "21m00Tcm4TlvDq8ikWAM" } },
  azure: { host: undefined, keys: ["AZURE_SPEECH_KEY", "AZURE_SPEECH_REGION"], voice: { en: "en-US-AvaMultilingualNeural", ja: "ja-JP-NanamiNeural" } },
  google: { host: "https://texttospeech.googleapis.com", keys: ["GOOGLE_TTS_API_KEY"], voice: { en: "en-US-Neural2-F", ja: "ja-JP-Neural2-B" } },
};

const fake = () => process.env.SCREEN_VIDEO_TTS_FAKE === "1";

/** The lines a flow reads aloud: each step with a caption or a `say`, by its step number. */
export function narrationLines(flow) {
  if (flow.voice === undefined || flow.voice === false) return [];
  return flow.steps
    .map((step, index) => ({ step: index + 1, text: (step.say ?? step.caption ?? "").trim() }))
    .filter((line) => line.text !== "");
}

/** The engine that makes the flow's voice: `local` becomes `voicevox` for Japanese and `kokoro` otherwise. */
export function engineOf(flow) {
  const engine = flow.voice?.engine;
  if (engine !== "local") return engine;
  return languageOf(flow) === "ja" ? "voicevox" : "kokoro";
}

function run(command, args, { input, cwd, what }) {
  const result = spawnSync(command, args, { cwd, input, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
  if (result.error !== undefined) throw new Error(`${what}: ${command} could not be started (${result.error.message})`);
  if (result.status !== 0) {
    const tail = `${result.stderr ?? ""}${result.stdout ?? ""}`.trim().split("\n").slice(-3).join(" / ");
    throw new Error(`${what} failed${tail ? `: ${tail}` : ""}`);
  }
  return result;
}

const say = (text) => process.stderr.write(`screen-video: ${text}\n`);

// --- installs -------------------------------------------------------------------------------------

function kokoroHome() {
  return join(dataDir(), "voices", "kokoro");
}

/** Installs kokoro-js into the data folder the first time. */
function installKokoro() {
  const home = ensureDir(kokoroHome());
  if (existsSync(join(home, "node_modules", "kokoro-js", "package.json"))) return home;
  say(`installing ${KOKORO_PACKAGE} into ${home} (first narrated English flow only)`);
  run("npm", ["install", "--prefix", home, "--no-audit", "--no-fund", "--loglevel", "error", KOKORO_PACKAGE], { what: "Installing kokoro-js" });
  return home;
}

function voicevoxHome() {
  return join(dataDir(), "voices", "voicevox");
}

/** The wheel and downloader names of VOICEVOX CORE for this machine. */
function voicevoxBuild() {
  const builds = {
    "darwin-arm64": { wheel: "macosx_11_0_arm64", downloader: "download-osx-arm64" },
    "darwin-x64": { wheel: "macosx_10_12_x86_64", downloader: "download-osx-x64" },
    "linux-x64": { wheel: "manylinux_2_34_x86_64", downloader: "download-linux-x64" },
    "linux-arm64": { wheel: "manylinux_2_34_aarch64", downloader: "download-linux-arm64" },
  };
  const build = builds[`${process.platform}-${process.arch}`];
  if (build === undefined) throw new Error(`VOICEVOX CORE has no build for ${process.platform} ${process.arch}. Choose a cloud voice for Japanese narration.`);
  return build;
}

/**
 * Installs VOICEVOX CORE the first time: a Python virtual environment with the `voicevox_core` wheel,
 * then its downloader, which fetches the voice model, ONNX Runtime, and the dictionary. The
 * downloader asks to agree to the models' terms; the answer is given only when the flow says the user
 * agreed.
 */
function installVoicevox(agreed) {
  const home = ensureDir(voicevoxHome());
  const venv = join(home, "venv");
  const python = join(venv, "bin", "python");
  const build = voicevoxBuild();
  if (!existsSync(python)) {
    const version = spawnSync("python3", ["-c", "import sys; print(sys.version_info >= (3, 10))"], { encoding: "utf8" });
    if (version.error !== undefined || version.stdout.trim() !== "True") {
      throw new Error("Japanese narration with a local voice needs Python 3.10 or later as python3 for VOICEVOX CORE. Install it, or choose a cloud voice in the flow's voice.engine.");
    }
    say(`making a Python environment for VOICEVOX CORE in ${venv} (first narrated Japanese flow only)`);
    run("python3", ["-m", "venv", venv], { what: "Making the Python environment for VOICEVOX CORE" });
  }
  const coreMark = join(home, `.core-${VOICEVOX_VERSION}`);
  if (!existsSync(coreMark)) {
    const wheel = `${VOICEVOX_RELEASES}/voicevox_core-${VOICEVOX_VERSION}-cp310-abi3-${build.wheel}.whl`;
    say(`installing VOICEVOX CORE ${VOICEVOX_VERSION} into ${venv}`);
    run(python, ["-m", "pip", "install", "--quiet", "--disable-pip-version-check", wheel], { what: "Installing VOICEVOX CORE" });
    writeFileSync(coreMark, "");
  }
  const modelsMark = join(home, `.models-${VOICEVOX_DEFAULT.model}`);
  if (!existsSync(modelsMark)) {
    if (!agreed) {
      throw new Error(
        'Japanese narration uses VOICEVOX, whose voice models have terms of use. Show the user the terms of VOICEVOX and of the voice, and that each video names the voice as "VOICEVOX:<character>" on its end card. Once the user agrees, add "terms": "agreed" to the flow\'s voice.',
      );
    }
    const downloader = join(home, "download");
    say("downloading the VOICEVOX voice model, ONNX Runtime, and the dictionary");
    run("curl", ["-fsSL", "-o", downloader, `${VOICEVOX_RELEASES}/${build.downloader}`], { what: "Downloading the VOICEVOX downloader" });
    chmodSync(downloader, 0o755);
    run(downloader, ["-o", join(home, "core"), "--only", "onnxruntime", "dict", "models", "--models-pattern", `${VOICEVOX_DEFAULT.model}.vvm`], {
      input: "y\n",
      cwd: home,
      what: "Downloading the VOICEVOX models",
    });
    writeFileSync(modelsMark, "");
  }
  return { home, python };
}

// --- sound files ----------------------------------------------------------------------------------

/** A mono 16-bit WAV of `samples` (numbers from -1 to 1). */
function wav(samples, rate) {
  const data = Buffer.alloc(samples.length * 2);
  samples.forEach((v, i) => data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, v)) * 32767), i * 2));
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

/** The stand-in voice for tests: a 3000 Hz tone of 0.05 seconds a character and 0.3 seconds more, faded at both ends. */
function toneFor(text) {
  const rate = 24000;
  const seconds = 0.05 * [...text].length + 0.3;
  const count = Math.round(seconds * rate);
  const fade = Math.round(0.01 * rate);
  const samples = new Array(count);
  for (let i = 0; i < count; i++) {
    const edge = Math.min(1, i / fade, (count - 1 - i) / fade);
    samples[i] = 0.04 * edge * Math.sin((2 * Math.PI * 3000 * i) / rate);
  }
  return wav(samples, rate);
}

/** Length in seconds of a 16-bit PCM WAV file. */
export function wavSeconds(file) {
  const bytes = readFileSync(file);
  const rate = bytes.readUInt32LE(24);
  const channels = bytes.readUInt16LE(22);
  const bits = bytes.readUInt16LE(34);
  let at = 12;
  while (at + 8 <= bytes.length) {
    const id = bytes.toString("ascii", at, at + 4);
    const size = bytes.readUInt32LE(at + 4);
    if (id === "data") return Number((Math.min(size, bytes.length - at - 8) / (rate * channels * (bits / 8))).toFixed(3));
    at += 8 + size + (size % 2);
  }
  throw new Error(`no sound in ${file}`);
}

/**
 * Turns a voice the engine wrote (any format ffmpeg reads) into a 24 kHz mono WAV whose loudest
 * moment is 3 dB below full scale, so every engine sounds equally loud in the video.
 */
function settleClip(input, output) {
  const probe = spawnSync(ffmpegPath(), ["-hide_banner", "-i", input, "-af", "volumedetect", "-f", "null", "-"], { encoding: "utf8" }).stderr ?? "";
  const peak = Number((/max_volume: (-?[\d.]+) dB/.exec(probe) ?? [])[1]);
  const gain = Number.isFinite(peak) ? Math.min(24, -3 - peak) : 0;
  run(ffmpegPath(), ["-hide_banner", "-loglevel", "error", "-y", "-i", input, "-af", `volume=${gain.toFixed(2)}dB`, "-ac", "1", "-ar", "24000", "-c:a", "pcm_s16le", output], {
    what: "Converting a voice",
  });
}

// --- engines ------------------------------------------------------------------------------------

async function kokoroClips(lines, files, voiceName) {
  const home = installKokoro();
  if (fake()) return;
  const require = createRequire(join(home, "package.json"));
  let entry;
  try {
    entry = require.resolve("kokoro-js");
  } catch {
    entry = join(home, "node_modules", "kokoro-js", "dist", "kokoro.js");
  }
  const { KokoroTTS, env } = await import(pathToFileURL(entry).href);
  if (env !== undefined) env.cacheDir = ensureDir(join(home, "models"));
  const tts = await KokoroTTS.from_pretrained(KOKORO_MODEL, { dtype: "q8", device: "cpu" });
  for (const [index, line] of lines.entries()) {
    const audio = await tts.generate(line.text, { voice: voiceName });
    await audio.save(files[index].made);
  }
}

function voicevoxClips(lines, files, agreed) {
  const { home, python } = installVoicevox(agreed);
  if (fake()) return;
  const jobs = join(home, `jobs-${process.pid}.json`);
  writeFileSync(jobs, JSON.stringify({ model: VOICEVOX_DEFAULT.model, style: VOICEVOX_DEFAULT.style, lines: lines.map((line, i) => ({ text: line.text, file: files[i].made })) }));
  try {
    run(python, ["-I", join(SKILL_DIR, "scripts", "voicevox_tts.py"), join(home, "core"), jobs], { what: "Reading the lines with VOICEVOX" });
  } finally {
    rmSync(jobs, { force: true });
  }
}

/** The key values a cloud engine needs, from the flow's env file or the environment. Never printed. */
function cloudKeys(engine, flow, root) {
  const fromFile = flow.voice.envFile === undefined ? {} : readEnv(join(root, flow.voice.envFile), flow.voice.envFile);
  const names = [...CLOUD[engine].keys];
  if (flow.voice.keyEnv !== undefined) names[0] = flow.voice.keyEnv;
  return names.map((name) => {
    const value = fromFile[name] ?? process.env[name];
    if (value === undefined || value === "") throw new Error(`the ${engine} voice needs ${name}, which is empty or missing${flow.voice.envFile ? ` in ${flow.voice.envFile} and the environment` : " in the environment"}`);
    return value;
  });
}

function readEnv(path, named) {
  if (!existsSync(path)) throw new Error(`the env file ${named} named by voice.envFile does not exist in the project`);
  return parseEnvFile(path);
}

const escapeXml = (text) => text.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&apos;" })[c]);

/** One line from a cloud engine, as the bytes it returned and the file extension they need. */
async function cloudLine(engine, text, language, voiceName, keys) {
  const base = process.env.SCREEN_VIDEO_TTS_URL || undefined;
  let url;
  let init;
  if (engine === "openai") {
    url = `${base ?? CLOUD.openai.host}/v1/audio/speech`;
    init = {
      headers: { authorization: `Bearer ${keys[0]}`, "content-type": "application/json" },
      body: JSON.stringify({ model: "gpt-4o-mini-tts", voice: voiceName, input: text, response_format: "wav" }),
    };
  } else if (engine === "elevenlabs") {
    url = `${base ?? CLOUD.elevenlabs.host}/v1/text-to-speech/${encodeURIComponent(voiceName)}?output_format=mp3_44100_128`;
    init = {
      headers: { "xi-api-key": keys[0], "content-type": "application/json", accept: "audio/mpeg" },
      body: JSON.stringify({ text, model_id: "eleven_multilingual_v2" }),
    };
  } else if (engine === "azure") {
    url = `${base ?? `https://${encodeURIComponent(keys[1])}.tts.speech.microsoft.com`}/cognitiveservices/v1`;
    const lang = language === "ja" ? "ja-JP" : "en-US";
    init = {
      headers: {
        "ocp-apim-subscription-key": keys[0],
        "content-type": "application/ssml+xml",
        "x-microsoft-outputformat": "riff-24khz-16bit-mono-pcm",
        "user-agent": "screen-video",
      },
      body: `<speak version="1.0" xml:lang="${lang}"><voice name="${escapeXml(voiceName)}">${escapeXml(text)}</voice></speak>`,
    };
  } else {
    url = `${base ?? CLOUD.google.host}/v1/text:synthesize`;
    init = {
      headers: { "x-goog-api-key": keys[0], "content-type": "application/json" },
      body: JSON.stringify({
        input: { text },
        voice: { languageCode: language === "ja" ? "ja-JP" : "en-US", name: voiceName },
        audioConfig: { audioEncoding: "LINEAR16", sampleRateHertz: 24000 },
      }),
    };
  }
  let response;
  try {
    response = await fetch(url, { method: "POST", ...init, signal: AbortSignal.timeout(60000) });
  } catch (error) {
    throw new Error(`the ${engine} voice could not be reached (${error instanceof Error ? error.message : error})`);
  }
  if (!response.ok) {
    const detail = (await response.text().catch(() => "")).replace(/\s+/g, " ").slice(0, 200);
    throw new Error(`the ${engine} voice answered ${response.status}${detail ? `: ${detail}` : ""}`);
  }
  if (engine === "google") {
    const body = await response.json();
    if (typeof body.audioContent !== "string") throw new Error("the google voice sent no audioContent");
    return { bytes: Buffer.from(body.audioContent, "base64"), ext: "wav" };
  }
  const type = response.headers.get("content-type") ?? "";
  return { bytes: Buffer.from(await response.arrayBuffer()), ext: /mpeg|mp3/.test(type) ? "mp3" : "wav" };
}

// --- making the voices ------------------------------------------------------------------------------

/**
 * Makes the flow's voice into `outDir`: `voice/NNN.wav` for each line and `voice.json` listing them
 * (`engine`, `voice`, `language`, `credit`, and `clips` with `step`, `text`, `file`, and `duration`).
 * Writes `credits.txt` when the voice must be credited. A flow without narration gets a `voice.json`
 * with no clips, and nothing is installed.
 */
export async function makeVoices(flow, root, outDir) {
  const lines = narrationLines(flow);
  const language = languageOf(flow);
  const dir = join(outDir, "voice");
  rmSync(dir, { recursive: true, force: true });
  rmSync(join(outDir, "credits.txt"), { force: true });
  if (lines.length === 0) {
    const empty = { engine: null, language, clips: [] };
    writeFileSync(join(outDir, "voice.json"), `${JSON.stringify(empty, null, 2)}\n`);
    return empty;
  }
  mkdirSync(dir, { recursive: true });
  const engine = engineOf(flow);
  const files = lines.map((_, i) => {
    const name = String(i + 1).padStart(3, "0");
    return { name, made: join(dir, `${name}-engine.wav`), file: join("voice", `${name}.wav`) };
  });
  let voiceName = flow.voice.voice;
  let credit;
  if (engine === "kokoro") {
    voiceName ??= language === "ja" ? "jf_alpha" : "af_heart";
    await kokoroClips(lines, files, voiceName);
  } else if (engine === "voicevox") {
    voiceName = VOICEVOX_DEFAULT.character;
    credit = `VOICEVOX:${VOICEVOX_DEFAULT.character}`;
    voicevoxClips(lines, files, flow.voice.terms === "agreed");
  } else {
    voiceName ??= CLOUD[engine].voice[language];
    if (!fake()) {
      const keys = cloudKeys(engine, flow, root);
      for (const [index, line] of lines.entries()) {
        const { bytes, ext } = await cloudLine(engine, line.text, language, voiceName, keys);
        files[index].made = join(dir, `${files[index].name}-engine.${ext}`);
        writeFileSync(files[index].made, bytes);
      }
    }
  }
  const clips = lines.map((line, index) => {
    const out = join(outDir, files[index].file);
    if (fake()) writeFileSync(out, toneFor(line.text));
    else {
      settleClip(files[index].made, out);
      rmSync(files[index].made, { force: true });
    }
    return { step: line.step, text: line.text, file: files[index].file, duration: wavSeconds(out) };
  });
  const made = { engine, voice: voiceName, language, ...(credit === undefined ? {} : { credit }), clips };
  writeFileSync(join(outDir, "voice.json"), `${JSON.stringify(made, null, 2)}\n`);
  if (credit !== undefined) writeFileSync(join(outDir, "credits.txt"), `${credit}\n`);
  return made;
}
