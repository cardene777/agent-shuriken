/**
 * Drives the app an app flow records: a macOS app through screen-video's Swift tool
 * (`scripts/mac/screen-video-mac.swift`, built by `setup mac`), an app on the iOS Simulator through
 * `xcrun simctl` and idb, and an app on the Android emulator through adb.
 *
 * Phone flows run only on screen-video's own devices, the simulator `screen-video-ios` and the
 * emulator `screen-video-android`, which `setup ios` and `setup android` create. The simulator is
 * named by its UDID in every command, and the emulator runs on its own port (`ANDROID_PORT`) and is
 * named by its serial in every adb command, so a simulator, emulator, or phone of the user's never
 * gets a command. `openDriver` checks that the system is ready before anything runs, and says which
 * `setup` command makes it ready when it is not.
 *
 * A driver has `start(app, root)` (boots the device, installs the build, and brings the app's screen
 * up for macOS), `open(app)` (brings the app up), `parts()`, `press(x, y)`, `type(text)`, `key(name)`,
 * `swipe(from, to, seconds)`, `screenshot(file)`, `capture(file)`, and `size`, the app's own
 * coordinates: points of the window on macOS, points of the screen on iOS, pixels on Android.
 * `capture` starts recording and returns `{ started, stop(), abort() }`; `started` is the time of
 * the recording's first frame in milliseconds, `stop()` ends it and returns the file, and `abort()`
 * ends it and removes what it wrote, on the device too.
 */
import { spawn, spawnSync } from "node:child_process";
import { existsSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { basename, delimiter, join, resolve } from "node:path";

import { readParts } from "./app-parts.mjs";
import { joinSegments } from "./media.mjs";
import { dataDir } from "./runtime.mjs";

export const IOS_DEVICE = "screen-video-ios";
export const ANDROID_DEVICE = "screen-video-android";
/** The port screen-video's emulator runs on, so its serial is always `emulator-5600`. */
const ANDROID_PORT = 5600;
/** Seconds between two keys the Swift tool types. */
const MAC_KEY_GAP = 0.11;
/** `adb shell screenrecord` stops by itself after 180 seconds, so a longer recording is made of parts this long. */
const ANDROID_PART_SECONDS = 170;

const IOS_KEYS = { Enter: 40, Escape: 41, Backspace: 42, Tab: 43, Space: 44, ArrowRight: 79, ArrowLeft: 80, ArrowDown: 81, ArrowUp: 82 };
const ANDROID_KEYS = { Enter: 66, Escape: 111, Backspace: 67, Tab: 61, Space: 62, ArrowRight: 22, ArrowLeft: 21, ArrowDown: 20, ArrowUp: 19, Back: 4, Home: 3 };

export const macTool = () => join(dataDir(), "apps", "mac", "screen-video-mac");
/** The source of the Swift tool, which `setup mac` builds. */
export const MAC_SOURCE = join(import.meta.dirname, "..", "mac", "screen-video-mac.swift");
/** Whether the Swift tool is built, and not older than its source (a newer version of the skill brings a newer source). */
export const macToolBuilt = (bin = macTool()) => existsSync(bin) && statSync(bin).mtimeMs >= statSync(MAC_SOURCE).mtimeMs;
export const idbTool = () => join(dataDir(), "apps", "idb", "bin", "idb");

const sleep = (ms) => new Promise((done) => setTimeout(done, ms));
const num = (value) => String(Math.round(value * 10) / 10);

/** The path of an executable named `name` on PATH, or undefined. */
export function which(name) {
  for (const dir of (process.env.PATH ?? "").split(delimiter)) {
    if (dir === "") continue;
    const path = join(dir, name);
    if (existsSync(path) && statSync(path).isFile()) return path;
  }
  return undefined;
}

/** Where the Android SDK is: `$ANDROID_HOME`, `$ANDROID_SDK_ROOT`, or the place Android Studio installs it. */
export function androidHome() {
  const set = process.env.ANDROID_HOME || process.env.ANDROID_SDK_ROOT;
  if (set) return set;
  return process.platform === "darwin" ? join(homedir(), "Library", "Android", "sdk") : join(homedir(), "Android", "Sdk");
}

/** A tool of the Android SDK (`adb`, `emulator`, `sdkmanager`, `avdmanager`), or undefined when it is missing. */
export function androidTool(name) {
  const home = androidHome();
  if (name === "adb" || name === "emulator") {
    const path = join(home, name === "adb" ? "platform-tools" : "emulator", name);
    return existsSync(path) ? path : undefined;
  }
  const tools = join(home, "cmdline-tools");
  const kinds = existsSync(tools) ? ["latest", ...readdirSync(tools).filter((d) => d !== "latest").sort().reverse()] : [];
  for (const kind of kinds) {
    const path = join(tools, kind, "bin", name);
    if (existsSync(path)) return path;
  }
  return which(name);
}

/**
 * Runs a tool and returns what it printed. Throws, naming the tool and its first word and with the
 * last lines it printed, when it fails; the other words are left out, as they may be typed text.
 */
export function tool(command, args, { input, binary = false, timeout = 120_000, env } = {}) {
  const result = spawnSync(command, args, {
    input,
    timeout,
    encoding: binary ? undefined : "utf8",
    maxBuffer: 256 * 1024 * 1024,
    env: env === undefined ? process.env : { ...process.env, ...env },
  });
  const serialAt = args.indexOf("-s");
  const words = args.filter((a, i) => !a.startsWith("-") && (serialAt < 0 || i !== serialAt + 1));
  const what = `${basename(command)} ${words[0] ?? ""}`.trim();
  if (result.error !== undefined) throw new Error(`${what} could not run: ${result.error.message}`);
  if (result.status !== 0) {
    const tail = String(result.stderr ?? "").trim().split("\n").slice(-2).join(" / ");
    throw new Error(`${what} failed${tail === "" ? "" : `: ${tail}`}`);
  }
  return result.stdout;
}

/**
 * Starts a recording process. When `announced`, the process prints `{"started": <ms>}` once its
 * first frame arrives; otherwise the recording counts from its start. `stopWith` ends it, or SIGINT.
 */
function startCapture(command, args, file, { announced = false, stopWith, cleanUp = () => rmSync(file, { force: true }) } = {}) {
  return new Promise((done, failed) => {
    const child = spawn(command, args, { stdio: ["ignore", "pipe", "pipe"] });
    let printed = "";
    let errors = "";
    let started = announced ? undefined : Date.now();
    const ended = new Promise((settle) => child.on("close", (code, signal) => settle(code ?? signal)));
    child.stderr.on("data", (chunk) => (errors += chunk));
    const handle = {
      get started() {
        return started;
      },
      async stop() {
        if (stopWith !== undefined) await stopWith();
        else child.kill("SIGINT");
        const code = await Promise.race([ended, sleep(60_000).then(() => "too slow")]);
        if (code === "too slow") child.kill("SIGKILL");
        if (code !== 0) throw new Error(`the recording did not end cleanly (${code}): ${errors.trim().split("\n").at(-1) ?? ""}`);
        return file;
      },
      async abort() {
        if (stopWith !== undefined) await Promise.resolve(stopWith()).catch(() => undefined);
        child.kill("SIGKILL");
        await Promise.race([ended, sleep(5000)]);
        cleanUp();
      },
    };
    if (!announced) return done(handle);
    const timer = setTimeout(() => {
      child.kill("SIGKILL");
      failed(new Error(`the recording did not start within 30 seconds: ${errors.trim().split("\n").at(-1) ?? ""}`));
    }, 30_000);
    child.stdout.on("data", (chunk) => {
      printed += chunk;
      if (started !== undefined || !printed.includes("\n")) return;
      try {
        started = Number(JSON.parse(printed.split("\n")[0]).started);
        clearTimeout(timer);
        done(handle);
      } catch {
        clearTimeout(timer);
        child.kill("SIGKILL");
        failed(new Error(`the recording started with ${printed.split("\n")[0]}`));
      }
    });
    ended.then((code) => {
      if (started !== undefined) return;
      clearTimeout(timer);
      failed(new Error(`the recording stopped before it began (${code}): ${errors.trim().split("\n").at(-1) ?? ""}`));
    });
  });
}

// --- macOS ----------------------------------------------------------------------------------------

/** The macOS permissions screen-video needs, and the settings page of each. */
const MAC_PERMISSIONS = {
  screenRecording: { name: "Screen Recording", page: "screen-recording" },
  accessibility: { name: "Accessibility", page: "accessibility" },
};

/** The permissions the app this agent runs in lacks, as keys of `MAC_PERMISSIONS`. */
export function missingPermissions(bin = macTool()) {
  const given = JSON.parse(tool(bin, ["permissions"]));
  return Object.keys(MAC_PERMISSIONS).filter((key) => given[key] !== true);
}

/** Opens the settings page of each missing permission and returns what to tell the user. */
export function askForPermissions(missing, bin = macTool()) {
  for (const key of missing) tool(bin, ["open-settings", MAC_PERMISSIONS[key].page]);
  const names = missing.map((key) => MAC_PERMISSIONS[key].name).join(" and ");
  return (
    `macOS has not given ${names} to the app this agent runs in (such as Terminal). ` +
    `Turn on ${names} for that app in System Settings > Privacy & Security; the settings page is open. ` +
    "Then quit and reopen that app, and run the command again."
  );
}

function macDriver() {
  if (process.platform !== "darwin") throw new Error("A macOS app flow records only on a Mac.");
  const bin = macTool();
  if (!macToolBuilt(bin)) throw new Error(`screen-video's Swift tool is ${existsSync(bin) ? "older than the skill" : "not built yet"}. Run: screen-video.sh setup mac`);
  const missing = missingPermissions(bin);
  if (missing.length > 0) throw new Error(askForPermissions(missing, bin));
  let pid;
  let window;
  return {
    platform: "mac",
    keyGap: MAC_KEY_GAP,
    get size() {
      return { width: window.width, height: window.height };
    },
    async start(app) {
      const launched = JSON.parse(tool(bin, ["launch", app.id], { timeout: 90_000 }));
      pid = launched.pid;
      window = launched.window;
    },
    async open(app) {
      tool(bin, ["activate", app.id]);
    },
    parts: () => readParts("mac", tool(bin, ["parts", String(pid)])),
    press: (x, y) => tool(bin, ["press", String(window.id), num(x), num(y)]),
    type: (text) => tool(bin, ["type", text], { timeout: 600_000 }),
    key: (name) => tool(bin, ["key", name]),
    swipe: () => {
      throw new Error("a macOS app flow cannot swipe");
    },
    screenshot: (file) => tool(bin, ["screenshot", String(window.id), file]),
    capture: (file) => startCapture(bin, ["record", String(window.id), file], file, { announced: true }),
  };
}

// --- iOS ------------------------------------------------------------------------------------------

const simctl = (args, options) => tool("xcrun", ["simctl", ...args], options);

/** The simulators Xcode knows, each with its runtime. */
export function simulators() {
  const listed = JSON.parse(simctl(["list", "devices", "--json"])).devices ?? {};
  return Object.entries(listed).flatMap(([runtime, list]) => list.map((device) => ({ ...device, runtime })));
}

function iosDriver() {
  if (process.platform !== "darwin") throw new Error("An iOS app flow records only on a Mac, where the iOS Simulator runs.");
  let own;
  try {
    own = simulators().find((device) => device.name === IOS_DEVICE);
  } catch (error) {
    throw new Error(`The iOS Simulator cannot be listed (${error.message}). Install Xcode, open it once, then run: screen-video.sh setup ios`);
  }
  if (own === undefined) throw new Error(`screen-video's simulator ${IOS_DEVICE} does not exist yet. Run: screen-video.sh setup ios`);
  const idb = idbTool();
  if (!existsSync(idb) || which("idb_companion") === undefined) throw new Error("idb, which drives the simulator, is not installed yet. Run: screen-video.sh setup ios");
  const udid = own.udid;
  const ui = (command, args = [], options) => tool(idb, ["ui", command, "--udid", udid, ...args], options);
  let size;
  return {
    platform: "ios",
    get size() {
      return size;
    },
    async start(app, root) {
      if (own.state !== "Booted") simctl(["boot", udid], { timeout: 300_000 });
      simctl(["bootstatus", udid, "-b"], { timeout: 600_000 });
      tool(idb, ["connect", udid]);
      if (app.install !== undefined) simctl(["install", udid, resolve(root, app.install)], { timeout: 600_000 });
      // The recording starts without the app, which the flow's open step brings up
      try {
        simctl(["terminate", udid, app.id]);
      } catch {
        // The app was not running
      }
      const screen = readParts("ios", ui("describe-all", ["--json"])).find((part) => part.role === "application");
      if (screen === undefined) throw new Error("idb did not say the size of the simulator's screen");
      size = { width: screen.frame[2], height: screen.frame[3] };
    },
    async open(app) {
      simctl(["launch", "--terminate-running-process", udid, app.id], { timeout: 90_000 });
    },
    parts: () => readParts("ios", ui("describe-all", ["--json"])),
    press: (x, y) => ui("tap", [num(x), num(y)]),
    type: (text) => ui("text", [text], { timeout: 600_000 }),
    key: (name) => {
      if (IOS_KEYS[name] === undefined) throw new Error(`the iOS Simulator has no key named ${name} (use one of ${Object.keys(IOS_KEYS).join(", ")})`);
      ui("key", [String(IOS_KEYS[name])]);
    },
    swipe: (from, to, seconds) => ui("swipe", [num(from[0]), num(from[1]), num(to[0]), num(to[1]), "--duration", String(seconds)]),
    screenshot: (file) => simctl(["io", udid, "screenshot", file]),
    capture: (file) => startCapture(idb, ["record-video", "--udid", udid, file], file),
  };
}

// --- Android --------------------------------------------------------------------------------------

/** Text for `adb shell input text`: spaces as `%s`, and the characters the device's shell reads escaped. */
function inputText(text) {
  return text.replace(/[\\"'`$&|;<>()*?#!~{}[\] ]/g, (c) => (c === " " ? "%s" : `\\${c}`));
}

/** The AVDs the emulator knows. */
function emulators(emulator = androidTool("emulator")) {
  return tool(emulator, ["-list-avds"])
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line !== "" && !line.startsWith("INFO"));
}

function androidDriver() {
  const adb = androidTool("adb");
  const emulator = androidTool("emulator");
  if (adb === undefined || emulator === undefined) throw new Error("The Android SDK's adb and emulator are missing. Run: screen-video.sh setup android");
  if (!emulators(emulator).includes(ANDROID_DEVICE)) throw new Error(`screen-video's emulator ${ANDROID_DEVICE} does not exist yet. Run: screen-video.sh setup android`);
  const serial = `emulator-${ANDROID_PORT}`;
  const on = (args, options) => tool(adb, ["-s", serial, ...args], options);
  const shell = (args, options) => on(["shell", ...args], options);
  let size;

  /** Records in parts of `ANDROID_PART_SECONDS`, pulls each from the emulator, removes it there, and joins them into `file`. */
  async function capture(file) {
    const parts = [];
    let current;
    const stopRecording = () => shell(["pkill", "-INT", "screenrecord"]);
    const begin = async () => {
      const remote = `/sdcard/screen-video-${process.pid}-${parts.length + 1}.mp4`;
      current = await startCapture(adb, ["-s", serial, "shell", "screenrecord", "--bit-rate", "8000000", remote], remote, { stopWith: stopRecording, cleanUp: () => undefined });
      parts.push({ remote, local: `${file}.${parts.length + 1}.mp4`, started: current.started });
    };
    await begin();
    let turning = Promise.resolve();
    const timer = setInterval(() => {
      turning = turning.then(async () => {
        await current.stop();
        await begin();
      });
    }, ANDROID_PART_SECONDS * 1000);
    const removeRemote = () => {
      for (const part of parts) {
        try {
          shell(["rm", "-f", part.remote]);
        } catch {
          // Already gone
        }
      }
    };
    return {
      started: parts[0].started,
      async stop() {
        clearInterval(timer);
        await turning;
        await current.stop();
        for (const part of parts) {
          on(["pull", part.remote, part.local], { timeout: 600_000 });
          shell(["rm", "-f", part.remote]);
        }
        joinSegments(
          parts.map((part) => ({ file: part.local, at: (part.started - parts[0].started) / 1000 })),
          file,
        );
        for (const part of parts) rmSync(part.local, { force: true });
        return file;
      },
      async abort() {
        clearInterval(timer);
        await turning.catch(() => undefined);
        await current.abort();
        removeRemote();
        for (const part of parts) rmSync(part.local, { force: true });
      },
    };
  }

  return {
    platform: "android",
    get size() {
      return size;
    },
    async start(app, root) {
      const running = tool(adb, ["devices"])
        .split("\n")
        .some((line) => line.startsWith(`${serial}\t`));
      if (running) {
        const name = on(["emu", "avd", "name"]).split(/\r?\n/)[0].trim();
        if (name !== ANDROID_DEVICE) throw new Error(`Another emulator (${name}) runs on port ${ANDROID_PORT}, which screen-video's emulator uses. Close it and run again.`);
      } else {
        spawn(emulator, ["-avd", ANDROID_DEVICE, "-port", String(ANDROID_PORT), "-no-snapshot-save", "-no-boot-anim", "-no-audio"], { detached: true, stdio: "ignore" }).unref();
      }
      on(["wait-for-device"], { timeout: 300_000 });
      for (let i = 0; shell(["getprop", "sys.boot_completed"]).trim() !== "1"; i++) {
        if (i >= 300) throw new Error(`the emulator ${ANDROID_DEVICE} did not finish starting within 5 minutes`);
        await sleep(1000);
      }
      if (app.install !== undefined) on(["install", "-r", resolve(root, app.install)], { timeout: 600_000 });
      // The recording starts without the app, which the flow's open step brings up
      shell(["am", "force-stop", app.id]);
      const listed = shell(["wm", "size"]);
      const found = /Override size: (\d+)x(\d+)/.exec(listed) ?? /Physical size: (\d+)x(\d+)/.exec(listed);
      if (found === null) throw new Error("adb did not say the size of the emulator's screen");
      size = { width: Number(found[1]), height: Number(found[2]) };
    },
    async open(app) {
      shell(["monkey", "-p", app.id, "-c", "android.intent.category.LAUNCHER", "1"]);
    },
    parts: () => readParts("android", on(["exec-out", "uiautomator", "dump", "/dev/tty"])),
    press: (x, y) => shell(["input", "tap", String(Math.round(x)), String(Math.round(y))]),
    type: (text) => shell(["input", "text", inputText(text)], { timeout: 600_000 }),
    key: (name) => {
      if (ANDROID_KEYS[name] === undefined) throw new Error(`the Android emulator has no key named ${name} (use one of ${Object.keys(ANDROID_KEYS).join(", ")})`);
      shell(["input", "keyevent", String(ANDROID_KEYS[name])]);
    },
    swipe: (from, to, seconds) => shell(["input", "swipe", ...[...from, ...to].map((v) => String(Math.round(v))), String(Math.round(seconds * 1000))]),
    screenshot: (file) => writeFileSync(file, on(["exec-out", "screencap", "-p"], { binary: true })),
    capture,
  };
}

/** The driver of `platform`, after checking that its system is ready; throws, naming the `setup` command, when it is not. */
export function openDriver(platform) {
  if (platform === "mac") return macDriver();
  if (platform === "ios") return iosDriver();
  return androidDriver();
}
