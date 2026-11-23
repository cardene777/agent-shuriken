// A stand-in for every tool the screen-video skill drives when it records an app: its Swift tool
// (screen-video-mac), xcrun, xcodebuild, idb, idb_companion, brew, python3 and pip, swiftc, adb,
// emulator, avdmanager, and sdkmanager. apps.mjs writes a launcher for each tool that runs this file
// with a scenario file and the tool's name, so no app, simulator, emulator, or installer really runs.
//
// The scenario (scenario.json) holds the screen of each system and the parts on it, the devices and
// packages already there, and the ffmpeg to draw with. Each command is appended to log.txt next to it
// as one line, `<tool> <arguments>`. state.json keeps what the commands changed: the presses so far
// (each with its time), booted simulators, running emulators, created devices, installed packages,
// and a recording asked to stop. A recording is drawn with ffmpeg when it stops, from the moment it
// began: the screen's colour, each part drawn as its `look` says (`button`, a black box; `detail`, a
// moving pattern) while it is on the screen. A part with `after: n` shows from the n-th press, and one
// with `before: n` until it.

import { spawnSync } from "node:child_process";
import { appendFileSync, chmodSync, copyFileSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

const [scenarioFile, tool, ...rest] = process.argv.slice(2);
const DIR = dirname(scenarioFile);
const scenario = () => JSON.parse(readFileSync(scenarioFile, "utf8"));
const LOG = join(DIR, "log.txt");
const STATE = join(DIR, "state.json");
/** The Android emulator's storage: `/sdcard/x.mp4` is `<DIR>/device/sdcard/x.mp4`. */
const STORAGE = join(DIR, "device");

// pip is launched with the folder of its virtual environment first
const venv = tool === "pip" ? rest.shift() : undefined;
const args = rest;
appendFileSync(LOG, `${[tool, ...args].join(" ")}\n`);

function state() {
  return existsSync(STATE)
    ? JSON.parse(readFileSync(STATE, "utf8"))
    : { presses: [], booted: [], running: [], avds: [], devices: [], runtimes: [], installed: [], stop: false };
}
function change(fn) {
  const s = state();
  fn(s);
  writeFileSync(STATE, JSON.stringify(s));
  return s;
}
const out = (text) => process.stdout.write(text.endsWith("\n") ? text : `${text}\n`);
function fail(text, code = 1) {
  process.stderr.write(`${text}\n`);
  process.exit(code);
}
/** Writes a launcher at `file` that runs this stand-in as `name`. */
function launcher(file, name, extra = []) {
  mkdirSync(dirname(file), { recursive: true });
  const quoted = [process.execPath, import.meta.filename, scenarioFile, name, ...extra].map((a) => `'${a}'`).join(" ");
  writeFileSync(file, `#!/bin/sh\nexec ${quoted} "$@"\n`);
  chmodSync(file, 0o755);
}
const press = (x, y) => change((s) => s.presses.push({ at: Date.now(), x: Number(x), y: Number(y) }));

/** The parts on the screen of `system` after `count` presses. */
function partsOf(system, count = state().presses.length) {
  return (scenario()[system].parts ?? []).filter((p) => (p.after === undefined || count >= p.after) && (p.before === undefined || count < p.before));
}

// --- the lists each system prints ---------------------------------------------------------------

const AX = { button: "AXButton", textbox: "AXTextField", text: "AXStaticText", switch: "AXCheckBox", img: "AXImage", link: "AXLink" };
const IOS = { button: "Button", textbox: "TextField", text: "StaticText", switch: "Switch", img: "Image", link: "Link" };
const ANDROID = { button: "android.widget.Button", textbox: "android.widget.EditText", text: "android.widget.TextView", switch: "android.widget.Switch", img: "android.widget.ImageView" };

function macList() {
  return partsOf("mac").map((p) => ({
    role: AX[p.role] ?? "AXGroup",
    subrole: p.role === "switch" ? "AXSwitch" : null,
    title: p.role === "button" ? p.name ?? null : null,
    description: ["textbox", "img", "switch"].includes(p.role) ? p.name ?? null : null,
    value: p.role === "text" ? p.value ?? p.name ?? null : p.value ?? null,
    identifier: p.id ?? null,
    enabled: true,
    frame: p.frame,
  }));
}

function iosList() {
  const s = scenario().ios.screen;
  const element = (type, label, value, id, [x, y, w, h], role) => ({
    AXFrame: `{{${x}, ${y}}, {${w}, ${h}}}`,
    AXUniqueId: id ?? null,
    frame: { y, x, width: w, height: h },
    role_description: role,
    AXLabel: label ?? null,
    content_required: false,
    type,
    title: null,
    help: null,
    custom_actions: [],
    AXValue: value ?? null,
    enabled: true,
    role: `AX${type}`,
    subrole: null,
    pid: 4242,
  });
  return [
    element("Application", "Notes", null, null, [0, 0, s.width, s.height], "application"),
    ...partsOf("ios").map((p) => element(IOS[p.role] ?? "Other", p.role === "text" ? p.value ?? p.name : p.name, p.role === "text" ? null : p.value, p.id, p.frame, p.role)),
  ];
}

function androidDump() {
  const s = scenario().android.screen;
  const pkg = scenario().android.package;
  const attr = (v) => String(v ?? "").replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;");
  const node = (index, p) => {
    const [x, y, w, h] = p.frame;
    const text = p.role === "textbox" ? p.value ?? "" : p.role === "text" ? p.value ?? p.name ?? "" : p.role === "button" ? p.name ?? "" : "";
    const desc = ["textbox", "img", "switch"].includes(p.role) ? p.name ?? "" : "";
    return `<node index="${index}" text="${attr(text)}" resource-id="${p.id ? attr(`${pkg}:id/${p.id}`) : ""}" class="${ANDROID[p.role] ?? "android.view.View"}" package="${pkg}" content-desc="${attr(desc)}" checkable="false" checked="false" clickable="${p.role === "button" || p.role === "textbox"}" enabled="true" focusable="true" focused="false" scrollable="false" long-clickable="false" password="false" selected="false" bounds="[${x},${y}][${x + w},${y + h}]" />`;
  };
  return `<?xml version='1.0' encoding='UTF-8' standalone='yes' ?><hierarchy rotation="0"><node index="0" text="" resource-id="" class="android.widget.FrameLayout" package="${pkg}" content-desc="" checkable="false" checked="false" clickable="false" enabled="true" focusable="false" focused="false" scrollable="false" long-clickable="false" password="false" selected="false" bounds="[0,0][${s.width},${s.height}]">${partsOf("android")
    .map((p, i) => node(i, p))
    .join("")}</node></hierarchy>`;
}

// --- drawing the screen -------------------------------------------------------------------------

/** The size of the screen in pixels, and pixels per point of the system's coordinates. */
function pixels(system) {
  const sc = scenario();
  if (system === "mac") return { width: sc.mac.window.width * sc.mac.window.scale, height: sc.mac.window.height * sc.mac.window.scale, scale: sc.mac.window.scale };
  const screen = sc[system].screen;
  return { width: screen.width * (screen.scale ?? 1), height: screen.height * (screen.scale ?? 1), scale: screen.scale ?? 1 };
}

/**
 * Draws the screen of `system` into `file`: a video from `started` (milliseconds since the epoch) to
 * now, or one picture of this moment when `started` is undefined.
 */
function draw(system, file, started) {
  const sc = scenario();
  const { width, height, scale } = pixels(system);
  const still = started === undefined;
  const seconds = still ? 0.04 : Math.max(0.6, (Date.now() - started) / 1000);
  const presses = still ? [] : state().presses.map((p) => (p.at - started) / 1000);
  const count = state().presses.length;
  const inputs = ["-f", "lavfi", "-i", `color=c=${sc[system].color}:s=${width}x${height}:r=30:d=${seconds.toFixed(3)}`];
  const lines = [];
  let current = "0:v";
  let n = 0;
  for (const part of sc[system].parts ?? []) {
    if (part.look === undefined) continue;
    let from = 0;
    let to = seconds + 1;
    if (still) {
      if ((part.after !== undefined && count < part.after) || (part.before !== undefined && count >= part.before)) continue;
    } else {
      if (part.after !== undefined) from = presses[part.after - 1] ?? seconds + 1;
      if (part.before !== undefined) to = presses[part.before - 1] ?? seconds + 1;
    }
    const [x, y, w, h] = part.frame.map((v) => Math.round(v * scale));
    const enable = `between(t,${from.toFixed(3)},${to.toFixed(3)})`;
    const next = `p${n++}`;
    if (part.look === "button") lines.push(`[${current}]drawbox=x=${x}:y=${y}:w=${w}:h=${h}:color=black:t=fill:enable='${enable}'[${next}]`);
    else {
      inputs.push("-f", "lavfi", "-i", `testsrc2=s=${w}x${h}:r=30:d=${seconds.toFixed(3)}`);
      const index = inputs.filter((a) => a === "-i").length - 1;
      lines.push(`[${current}][${index}:v]overlay=${x}:${y}:enable='${enable}'[${next}]`);
    }
    current = next;
  }
  lines.push(`[${current}]format=yuv420p[v]`);
  const encode = still ? ["-frames:v", "1"] : ["-c:v", "libx264", "-preset", "ultrafast", "-pix_fmt", "yuv420p"];
  const made = spawnSync(sc.ffmpeg, ["-hide_banner", "-loglevel", "error", "-y", ...inputs, "-filter_complex", lines.join(";"), "-map", "[v]", ...encode, file]);
  if (made.status !== 0) fail(`stand-in: could not draw ${file}: ${made.stderr}`);
}

/** Keeps a recording going until it is told to stop (a signal, or `stop` in the state), then draws it into `file`. */
function recordUntilStopped(system, file, { announce = false } = {}) {
  const started = Date.now();
  change((s) => (s.stop = false));
  if (announce) out(JSON.stringify({ started }));
  let done = false;
  const stop = () => {
    if (done) return;
    done = true;
    draw(system, file, started);
    process.exit(0);
  };
  process.on("SIGINT", stop);
  process.on("SIGTERM", stop);
  setInterval(() => {
    if (state().stop) stop();
  }, 50);
}

const option = (list, name) => {
  const i = list.indexOf(name);
  return i < 0 ? undefined : list[i + 1];
};
const positional = (list, names) => list.filter((a, i) => !a.startsWith("--") && !names.includes(list[i - 1]));

// --- the tools ----------------------------------------------------------------------------------

function mac() {
  const sc = scenario().mac;
  const [command, ...a] = args;
  switch (command) {
    case "permissions":
      return out(JSON.stringify({ screenRecording: sc.permissions?.screenRecording ?? true, accessibility: sc.permissions?.accessibility ?? true }));
    case "open-settings":
      return undefined;
    case "launch":
      if (a[0] !== sc.bundle) fail(`no app with the bundle id ${a[0]}`);
      return out(JSON.stringify({ pid: 4242, window: sc.window }));
    case "activate":
      return undefined;
    case "parts":
      return out(JSON.stringify(macList()));
    case "press":
      if (Number(a[0]) !== sc.window.id) fail(`no window ${a[0]}`);
      return press(a[1], a[2]);
    case "type":
    case "key":
      return undefined;
    case "screenshot":
      return draw("mac", a[1]);
    case "record":
      if (Number(a[0]) !== sc.window.id) fail(`no window ${a[0]}`);
      return recordUntilStopped("mac", a[1], { announce: true });
    default:
      return fail(`stand-in screen-video-mac: unknown command ${command}`, 2);
  }
}

function devicesOf() {
  const sc = scenario().ios;
  const s = state();
  return [...sc.devices, ...s.devices].map((d) => ({ ...d, state: s.booted.includes(d.udid) ? "Booted" : d.state }));
}
function runtimesOf() {
  return [...(scenario().ios.runtimes ?? []), ...state().runtimes];
}
const known = (udid) => devicesOf().some((d) => d.udid === udid) || fail(`Invalid device: ${udid}`);

function xcrun() {
  if (args[0] !== "simctl") return fail(`stand-in xcrun: ${args[0]} is not served`, 2);
  const [command, ...a] = args.slice(1);
  switch (command) {
    case "list": {
      if (a[0] === "devices") {
        const byRuntime = {};
        for (const d of devicesOf()) (byRuntime[d.runtime] ??= []).push({ name: d.name, udid: d.udid, state: d.state, isAvailable: true });
        return out(JSON.stringify({ devices: byRuntime }));
      }
      if (a[0] === "runtimes") return out(JSON.stringify({ runtimes: runtimesOf().map((r) => ({ ...r, platform: "iOS", isAvailable: true })) }));
      if (a[0] === "devicetypes") return out(JSON.stringify({ devicetypes: scenario().ios.devicetypes }));
      return fail(`stand-in simctl list ${a[0]}`, 2);
    }
    case "create": {
      const [name, type, runtime] = a;
      if (!runtimesOf().some((r) => r.identifier === runtime)) fail(`Invalid runtime: ${runtime}`);
      const udid = "SV-CREATED-UDID";
      change((s) => s.devices.push({ name, udid, state: "Shutdown", runtime, type }));
      return out(udid);
    }
    case "boot":
      known(a[0]);
      return change((s) => s.booted.push(a[0]));
    case "bootstatus":
    case "terminate":
    case "shutdown":
      return known(a.find((x) => !x.startsWith("-")));
    case "install":
      known(a[0]);
      if (!existsSync(a[1])) fail(`no app at ${a[1]}`);
      return undefined;
    case "launch": {
      const [udid, bundle] = a.filter((x) => !x.startsWith("--"));
      known(udid);
      return out(`${bundle}: 4242`);
    }
    case "io":
      known(a[0]);
      if (a[1] !== "screenshot") return fail(`stand-in simctl io ${a[1]}`, 2);
      return draw("ios", a.at(-1));
    default:
      return fail(`stand-in simctl ${command}`, 2);
  }
}

function idb() {
  const udid = option(args, "--udid");
  const target = devicesOf().find((d) => d.udid === udid);
  if (args[0] !== "connect" && target === undefined) fail(`idb: no target ${udid}`);
  const words = positional(args, ["--udid", "--duration"]);
  if (words[0] === "ui") {
    switch (words[1]) {
      case "describe-all":
        return out(JSON.stringify(iosList()));
      case "tap":
        return press(words[2], words[3]);
      case "swipe":
        return press(words[2], words[3]);
      case "text":
      case "key":
        return undefined;
      default:
        return fail(`stand-in idb ui ${words[1]}`, 2);
    }
  }
  if (words[0] === "record-video") return recordUntilStopped("ios", words[1]);
  if (words[0] === "connect" || words[0] === "launch" || words[0] === "install") return undefined;
  if (words[0] === "screenshot") return draw("ios", words[1]);
  return fail(`stand-in idb ${words[0]}`, 2);
}

function androidDevices() {
  return [...scenario().android.devices, ...state().running];
}

function adb() {
  const serial = option(args, "-s");
  const a = serial === undefined ? args : args.filter((_, i) => i !== args.indexOf("-s") && i !== args.indexOf("-s") + 1);
  const [command, ...more] = a;
  if (["devices", "start-server", "version"].includes(command)) {
    if (command === "devices") out(`List of devices attached\n${androidDevices().map((d) => `${d.serial}\tdevice`).join("\n")}\n`);
    return undefined;
  }
  const device = androidDevices().find((d) => d.serial === serial);
  if (device === undefined) fail(`adb: device '${serial ?? ""}' not found`);
  const pkg = scenario().android.package;
  switch (command) {
    case "wait-for-device":
      return undefined;
    case "emu":
      if (more.join(" ") === "avd name") return out(`${device.avd}\r\nOK\r\n`);
      return fail(`stand-in adb emu ${more.join(" ")}`, 2);
    case "install":
      if (!existsSync(more.at(-1))) fail(`adb: no file ${more.at(-1)}`);
      return out("Success");
    case "pull": {
      const from = join(STORAGE, more[0]);
      if (!existsSync(from)) fail(`adb: remote object '${more[0]}' does not exist`);
      return copyFileSync(from, more[1]);
    }
    case "exec-out": {
      const line = more.join(" ");
      if (line.startsWith("uiautomator dump")) return out(`${androidDump()}UI hierchary dumped to: /dev/tty`);
      if (line.startsWith("screencap")) {
        const file = join(DIR, `screencap-${Date.now()}.png`);
        draw("android", file);
        process.stdout.write(readFileSync(file));
        return rmSync(file);
      }
      return fail(`stand-in adb exec-out ${line}`, 2);
    }
    case "shell": {
      const words = more.join(" ").split(/\s+/);
      switch (words[0]) {
        case "getprop":
          return out(words[1] === "sys.boot_completed" ? "1" : "");
        case "wm":
          return out(`Physical size: ${scenario().android.screen.width}x${scenario().android.screen.height}`);
        case "monkey":
          if (!words.includes(pkg)) fail(`** No activities found to run, monkey aborted.`);
          return out("Events injected: 1");
        case "am":
          return out("Starting: Intent");
        case "input":
          if (words[1] === "tap" || words[1] === "swipe") return press(words[2], words[3]);
          return undefined;
        case "screenrecord": {
          const path = words.at(-1);
          mkdirSync(dirname(join(STORAGE, path)), { recursive: true });
          return recordUntilStopped("android", join(STORAGE, path));
        }
        case "pkill":
          return change((s) => (s.stop = true));
        case "rm":
          return rmSync(join(STORAGE, words.at(-1)), { force: true });
        default:
          return fail(`stand-in adb shell ${words[0]}`, 2);
      }
    }
    default:
      return fail(`stand-in adb ${command}`, 2);
  }
}

function emulator() {
  if (args[0] === "-list-avds") return out([...scenario().android.avds, ...state().avds].join("\n"));
  const avd = option(args, "-avd");
  if (![...scenario().android.avds, ...state().avds].includes(avd)) fail(`PANIC: Unknown AVD name [${avd}]`);
  const port = option(args, "-port") ?? "5554";
  return change((s) => s.running.push({ serial: `emulator-${port}`, avd }));
}

function avdmanager() {
  if (args[0] === "create") return change((s) => s.avds.push(option(args, "-n") ?? option(args, "--name")));
  if (args[0] === "list") return out([...scenario().android.avds, ...state().avds].join("\n"));
  return fail(`stand-in avdmanager ${args[0]}`, 2);
}

function sdkmanager() {
  const installed = [...(scenario().android.packages ?? []), ...state().installed];
  if (args.includes("--list_installed")) return out(`Installed packages:\n${installed.map((p) => `  ${p} | 1 | x`).join("\n")}`);
  if (args.includes("--licenses")) return out("All SDK package licenses accepted.");
  const wanted = args.filter((a) => !a.startsWith("--"));
  if (wanted.length > 0) return change((s) => s.installed.push(...wanted));
  return fail("stand-in sdkmanager: nothing to do", 2);
}

switch (tool) {
  case "screen-video-mac":
    mac();
    break;
  case "xcrun":
    xcrun();
    break;
  case "xcodebuild":
    if (args.includes("-downloadPlatform")) change((s) => s.runtimes.push(scenario().ios.download));
    break;
  case "idb":
    idb();
    break;
  case "idb_companion":
    break;
  case "brew":
    if (args[0] === "install" && args.some((a) => a.endsWith("idb-companion"))) launcher(join(scenario().bin, "idb_companion"), "idb_companion");
    break;
  case "python3":
    if (args[0] === "-m" && args[1] === "venv") launcher(join(args[2], "bin", "pip"), "pip", [args[2]]);
    else if (args[0] === "--version") out("Python 3.12.0");
    break;
  case "pip":
    if (args[0] === "install" && args.some((a) => a.startsWith("fb-idb"))) launcher(join(venv, "bin", "idb"), "idb");
    break;
  case "swiftc":
    launcher(option(args, "-o"), "screen-video-mac");
    break;
  case "adb":
    adb();
    break;
  case "emulator":
    emulator();
    break;
  case "avdmanager":
    avdmanager();
    break;
  case "sdkmanager":
    sdkmanager();
    break;
  default:
    fail(`stand-in: ${tool} is not served`, 2);
}
