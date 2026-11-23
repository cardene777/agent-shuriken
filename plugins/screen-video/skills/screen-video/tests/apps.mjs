// Checks for recording macOS apps, the iOS Simulator, and the Android emulator, run from checks.mjs
// after its own checks.
//
// No app, simulator, emulator, or installer really runs. The Swift tool, xcrun, xcodebuild, idb,
// idb_companion, brew, python3, swiftc, adb, emulator, avdmanager, and sdkmanager are launchers of the
// stand-in in fixtures/apps/stand-in.mjs, which answers from a scenario file, logs every command, and
// draws its recordings with ffmpeg. Each scenario has a folder of its own with its launchers, its log,
// its data folder, its Android SDK, and the Android emulator's storage. The project and the temporary
// folder are throwaway folders too.

import { spawn, spawnSync } from "node:child_process";
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";

export async function appsChecks({ check, FFMPEG }) {
  const HERE = import.meta.dirname;
  const SKILL = join(HERE, "..");
  const PLUGIN = join(SKILL, "..", "..");
  const SCRIPT = join(SKILL, "scripts", "screen-video.sh");
  const FIXTURES = join(HERE, "fixtures", "apps");
  const STAND_IN = join(FIXTURES, "stand-in.mjs");
  const NODE_DIR = process.env.SCREEN_VIDEO_TEST_NODE_DIR || join(process.env.HOME ?? "", ".local", "share", "screen-video", "node");

  const A = mkdtempSync(join(tmpdir(), "screen-video-apps-"));
  const PROJECT = join(A, "project");
  const FLOWS = join(PROJECT, ".screen-video", "flows");
  // The skill's working folders go here, so the checks can see that it leaves no capture behind
  const TMP = join(A, "tmp");
  mkdirSync(FLOWS, { recursive: true });
  mkdirSync(TMP, { recursive: true });
  // The builds the phone flows install
  mkdirSync(join(PROJECT, "build", "Notes.app"), { recursive: true });
  writeFileSync(join(PROJECT, "build", "Notes.app", "Info.plist"), "<plist/>\n");
  writeFileSync(join(PROJECT, "build", "notes.apk"), "PK\n");

  // --- helpers ---------------------------------------------------------------------------------

  const readText = (file) => (existsSync(file) ? readFileSync(file, "utf8") : "");
  const last = (r) => r.all.trim().split("\n").at(-1);

  function filesUnder(dir) {
    if (!existsSync(dir)) return [];
    return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
      const path = join(dir, entry.name);
      return entry.isDirectory() ? filesUnder(path) : [path];
    });
  }

  function launcher(file, tool, scenarioFile, extra = []) {
    mkdirSync(dirname(file), { recursive: true });
    const quoted = [process.execPath, STAND_IN, scenarioFile, tool, ...extra].map((a) => `'${a}'`).join(" ");
    writeFileSync(file, `#!/bin/sh\nexec ${quoted} "$@"\n`);
    chmodSync(file, 0o755);
  }

  /**
   * A scenario: a folder with the scenario file, launchers of the tools on PATH, an Android SDK of
   * launchers, and a data folder. With `idb` and `mac` (the defaults), idb and the Swift tool are
   * already in the data folder, as `setup` leaves them; with `companion`, idb_companion is on PATH.
   */
  function scenario(name, body, { idb = true, mac = true, companion = true } = {}) {
    const dir = join(A, "scenarios", name);
    const bin = join(dir, "bin");
    const sdk = join(dir, "sdk");
    const data = join(dir, "data");
    const file = join(dir, "scenario.json");
    mkdirSync(data, { recursive: true });
    writeFileSync(file, JSON.stringify({ ffmpeg: FFMPEG, bin, ...body }, null, 2));
    for (const tool of ["xcrun", "xcodebuild", "brew", "python3", "swiftc"]) launcher(join(bin, tool), tool, file);
    if (companion) launcher(join(bin, "idb_companion"), "idb_companion", file);
    launcher(join(sdk, "platform-tools", "adb"), "adb", file);
    launcher(join(sdk, "emulator", "emulator"), "emulator", file);
    launcher(join(sdk, "cmdline-tools", "latest", "bin", "avdmanager"), "avdmanager", file);
    launcher(join(sdk, "cmdline-tools", "latest", "bin", "sdkmanager"), "sdkmanager", file);
    if (idb) launcher(join(data, "apps", "idb", "bin", "idb"), "idb", file);
    if (mac) launcher(join(data, "apps", "mac", "screen-video-mac"), "screen-video-mac", file);
    return {
      dir,
      data,
      storage: join(dir, "device"),
      env: {
        PATH: `${bin}:${dirname(process.execPath)}:/usr/bin:/bin`,
        ANDROID_HOME: sdk,
        ANDROID_SDK_ROOT: "",
        SCREEN_VIDEO_HOME: data,
        SCREEN_VIDEO_NODE_DIR: NODE_DIR,
        SCREEN_VIDEO_FFMPEG: FFMPEG,
        TMPDIR: TMP,
      },
      lines: () => readText(join(dir, "log.txt")).split("\n").filter(Boolean),
      state: () => JSON.parse(readText(join(dir, "state.json")) || "{}"),
      /** Replaces parts of the scenario, such as the macOS permissions. */
      set: (patch) => writeFileSync(file, JSON.stringify({ ...JSON.parse(readFileSync(file, "utf8")), ...patch }, null, 2)),
    };
  }

  function run(args, s, { timeout = 300_000 } = {}) {
    return new Promise((resolve) => {
      const child = spawn("bash", [SCRIPT, ...args], { cwd: PROJECT, env: { ...process.env, ...s.env } });
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
    writeFileSync(file, `${JSON.stringify({ version: 1, name, voice: false, music: false, ...body }, null, 2)}\n`);
    return file;
  }

  function probe(file) {
    const text = spawnSync(FFMPEG, ["-hide_banner", "-i", file], { encoding: "utf8" }).stderr ?? "";
    const size = /Video: .*?, (\d{2,5})x(\d{2,5})/.exec(text);
    if (size === null) throw new Error(`cannot read ${file}`);
    return { width: Number(size[1]), height: Number(size[2]) };
  }

  /** Mean absolute difference between horizontal neighbours in a gray crop of one frame: how much detail the box holds. */
  function detail(file, at, box) {
    const b = { x: Math.round(box.x), y: Math.round(box.y), w: Math.round(box.w), h: Math.round(box.h) };
    const bytes = spawnSync(
      FFMPEG,
      ["-hide_banner", "-loglevel", "error", "-ss", Math.max(0, at).toFixed(3), "-i", file, "-frames:v", "1", "-vf", `crop=${b.w}:${b.h}:${b.x}:${b.y},format=gray`, "-f", "rawvideo", "-"],
      { maxBuffer: 1 << 26 },
    ).stdout;
    if (bytes.length !== b.w * b.h) throw new Error(`cannot read a frame of ${file} at ${at.toFixed(2)}s`);
    let sum = 0;
    for (let y = 0; y < b.h; y++) for (let x = 1; x < b.w; x++) sum += Math.abs(bytes[y * b.w + x] - bytes[y * b.w + x - 1]);
    return sum / (b.h * (b.w - 1));
  }

  /** One frame as RGB, with a reader of the pixel at (x, y). */
  function frameAt(file, at) {
    const { width, height } = probe(file);
    const bytes = spawnSync(FFMPEG, ["-hide_banner", "-loglevel", "error", "-ss", Math.max(0, at).toFixed(3), "-i", file, "-frames:v", "1", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], {
      maxBuffer: 1 << 27,
    }).stdout;
    if (bytes.length !== width * height * 3) throw new Error(`cannot read a frame of ${file} at ${at.toFixed(2)}s`);
    return {
      width,
      height,
      pixel: (x, y) => {
        const i = (y * width + x) * 3;
        return [bytes[i], bytes[i + 1], bytes[i + 2]];
      },
    };
  }

  const isAccent = ([r, g, b]) => r < 130 && g > 140 && b > 200 && b - r > 90;
  const isDark = ([r, g, b]) => 0.299 * r + 0.587 * g + 0.114 * b < 90;
  const isWhite = ([r, g, b]) => Math.min(r, g, b) > 225;
  const isGreen = ([r, g, b]) => g > 150 && r < 90 && b < 90;

  function within(frame, x, y, w, h, fn) {
    for (let j = Math.max(0, y); j < Math.min(frame.height, y + h); j++) for (let i = Math.max(0, x); i < Math.min(frame.width, x + w); i++) fn(frame.pixel(i, j), i, j);
  }
  /** The middle of the pixels that pass `test`, or undefined when fewer than 8 do. */
  function middleOf(frame, test) {
    let sx = 0;
    let sy = 0;
    let n = 0;
    within(frame, 0, 0, frame.width, frame.height, (p, x, y) => {
      if (!test(p)) return;
      sx += x;
      sy += y;
      n++;
    });
    return n < 8 ? undefined : { x: Math.round(sx / n), y: Math.round(sy / n) };
  }
  function share(frame, test, x, y, w, h) {
    let n = 0;
    let all = 0;
    within(frame, x, y, w, h, (p) => {
      all++;
      if (test(p)) n++;
    });
    return all === 0 ? 0 : n / all;
  }
  function count(frame, test, x, y, w, h) {
    let n = 0;
    within(frame, x, y, w, h, (p) => {
      if (test(p)) n++;
    });
    return n;
  }
  function boundsOf(frame, test) {
    let left = Infinity;
    let right = -1;
    let top = Infinity;
    let bottom = -1;
    within(frame, 0, 0, frame.width, frame.height, (p, x, y) => {
      if (!test(p)) return;
      left = Math.min(left, x);
      right = Math.max(right, x);
      top = Math.min(top, y);
      bottom = Math.max(bottom, y);
    });
    return { left, right, top, bottom, width: right - left + 1, height: bottom - top + 1 };
  }

  /** Where a point of the app's own coordinates is in raw.mp4, from timeline.json's `app` and `screen`. */
  function inVideo(timeline, x, y) {
    const { app, screen } = timeline;
    return { x: screen.x + (x * screen.width) / app.width, y: screen.y + (y * screen.height) / app.height };
  }
  /** A frame of the app as a box in raw.mp4, `inset` pixels in from each side. */
  function boxInVideo(timeline, [x, y, w, h], inset = 8) {
    const a = inVideo(timeline, x, y);
    const b = inVideo(timeline, x + w, y + h);
    return { x: a.x + inset, y: a.y + inset, w: b.x - a.x - 2 * inset, h: b.y - a.y - 2 * inset };
  }
  /** A box of raw.mp4 as the edited video shows it while it shows the whole screen, in the window of edit.json's `frame`. */
  function boxInEdited(edit, box) {
    const k = edit.frame.width / 1920;
    return { x: edit.frame.x + box.x * k, y: edit.frame.y + box.y * k, w: box.w * k, h: box.h * k };
  }
  const editedAt = (edit, step) => edit.steps.find((e) => e.step === step);

  // --- the screens of the stand-ins --------------------------------------------------------------

  const MAC = {
    bundle: "com.example.notes",
    window: { id: 77, x: 120, y: 90, width: 800, height: 500, scale: 2 },
    color: "0xc8c8c8",
    permissions: { screenRecording: true, accessibility: true },
    parts: [
      { role: "text", name: "Notes", frame: [24, 12, 160, 28] },
      { role: "button", name: "New note", id: "new_note", frame: [24, 56, 140, 36], look: "button" },
      { role: "textbox", name: "Title", id: "title", frame: [24, 116, 360, 34], look: "button" },
      { role: "button", name: "Save", id: "save", frame: [404, 116, 110, 34], look: "button" },
      { role: "text", name: "Saved", frame: [24, 170, 120, 24], after: 3 },
      // The card number moves to the left once the first press is made
      { role: "text", name: "Card 4111 1111 1111 1111", frame: [540, 210, 220, 70], look: "detail", before: 1 },
      { role: "text", name: "Card 4111 1111 1111 1111", frame: [40, 210, 220, 70], look: "detail", after: 1 },
      { role: "text", name: "Milk, eggs, bread", frame: [40, 310, 300, 70], look: "detail" },
    ],
  };
  const MAC_CENTRES = [
    [94, 74],
    [204, 133],
    [459, 133],
  ];

  const RUNTIME = { identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2", name: "iOS 18.2", version: "18.2" };
  const IOS = {
    screen: { width: 390, height: 844, scale: 2 },
    color: "0x00c800",
    devices: [
      { name: "iPhone 16", udid: "USER-UDID-0001", state: "Booted", runtime: RUNTIME.identifier },
      { name: "screen-video-ios", udid: "SV-UDID-0002", state: "Shutdown", runtime: RUNTIME.identifier },
    ],
    runtimes: [RUNTIME],
    download: RUNTIME,
    devicetypes: [{ identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16", name: "iPhone 16", productFamily: "iPhone" }],
    parts: [
      { role: "text", name: "Notes", frame: [20, 60, 200, 34] },
      { role: "button", name: "New note", id: "new_note", frame: [20, 110, 160, 50], look: "button" },
      { role: "textbox", name: "Title", id: "title", frame: [20, 180, 350, 50], look: "button" },
      { role: "button", name: "Save", id: "save", frame: [250, 250, 120, 50], look: "button" },
      { role: "text", name: "Saved", frame: [20, 320, 120, 30], after: 3 },
      { role: "text", name: "Body", frame: [20, 520, 350, 70], look: "detail" },
    ],
  };
  const IOS_CENTRES = [
    [100, 135],
    [195, 205],
    [310, 275],
  ];

  const ANDROID = {
    package: "com.example.notes",
    screen: { width: 720, height: 1600 },
    color: "0x00c800",
    // The user's own emulator is running; the skill must leave it alone
    devices: [{ serial: "emulator-5554", avd: "Pixel_8_API_35" }],
    avds: ["Pixel_8_API_35", "screen-video-android"],
    packages: ["platform-tools", "emulator", "system-images;android-35;google_apis;arm64-v8a"],
    parts: [
      { role: "text", name: "Status", frame: [200, 0, 320, 60], look: "detail" },
      { role: "text", name: "Notes", frame: [40, 100, 300, 60] },
      { role: "button", name: "New note", id: "new_note", frame: [40, 200, 320, 100], look: "button" },
      { role: "textbox", name: "Title", id: "title", frame: [40, 360, 640, 100], look: "button" },
      { role: "button", name: "Save", id: "save", frame: [440, 520, 240, 100], look: "button" },
      { role: "text", name: "Saved", frame: [40, 680, 200, 60], after: 3 },
      { role: "text", name: "Secret", id: "secret", value: "sk-test-1234", frame: [40, 800, 640, 140], look: "detail" },
      { role: "text", name: "Body", frame: [40, 1100, 640, 140], look: "detail" },
    ],
  };
  const ANDROID_CENTRES = [
    [200, 250],
    [360, 410],
    [560, 570],
  ];

  // --- flows -----------------------------------------------------------------------------------

  const STEPS = [
    { do: "open", caption: "Open Notes" },
    { do: "click", target: { role: "button", name: "New note" }, caption: "Start a note" },
    { do: "fill", target: { label: "Title" }, text: "Groceries", caption: "Name it" },
    { do: "click", target: { testId: "save" }, caption: "Save it" },
  ];
  const MAC_FLOW = flow("mac-notes", {
    app: { platform: "mac", id: "com.example.notes" },
    mask: [{ text: "4111" }],
    steps: [...STEPS, { do: "wait", until: { text: "Saved" }, timeout: 5 }, { do: "hold", seconds: 1 }],
  });
  const IOS_FLOW = flow("ios-notes", {
    app: { platform: "ios", id: "com.example.notes", install: "build/Notes.app" },
    steps: [...STEPS, { do: "swipe", from: [195, 600], to: [195, 300], caption: "Scroll the note" }, { do: "wait", until: { text: "Saved" }, timeout: 5 }, { do: "hold", seconds: 1 }],
  });
  const ANDROID_FLOW = flow("android-notes", {
    app: { platform: "android", id: "com.example.notes", install: "build/notes.apk" },
    outputs: ["16:9", "9:16"],
    mask: [{ target: { testId: "secret" } }, { rect: [200, 0, 320, 60] }],
    steps: [
      ...STEPS,
      { do: "swipe", from: [360, 1300], to: [360, 500], caption: "Scroll the note" },
      { do: "wait", until: { text: "Saved" }, timeout: 5 },
      { do: "hold", seconds: 1.5 },
    ],
  });
  const MAC_POINT = flow("mac-point", { app: { platform: "mac", id: "com.example.notes" }, steps: [{ do: "open" }, { do: "click", target: { point: [94, 74] } }] });
  const MARKED = flow("android-marked", {
    app: { platform: "android", id: "com.example.notes" },
    steps: [
      ...STEPS.slice(0, 3),
      { do: "click", target: { testId: "save" }, caption: "Save it", effect: { kind: "sends", note: "saves the note to the account" } },
      { do: "hold", seconds: 1 },
    ],
  });
  const NOT_THERE = flow("android-not-there", {
    app: { platform: "android", id: "com.example.notes" },
    steps: [{ do: "open", caption: "Open Notes" }, { do: "click", target: { role: "button", name: "Nope" }, timeout: 1, caption: "Press a part that is not there" }],
  });

  const mac = scenario("mac", { mac: MAC });
  const ios = scenario("ios", { ios: IOS });
  const android = scenario("android", { android: ANDROID });
  const MAC_OUT = join(A, "record-mac");
  const IOS_OUT = join(A, "record-ios");
  const ANDROID_OUT = join(A, "record-android");
  const macRun = {};
  const iosRun = {};
  const androidRun = {};
  /** The serial of the emulator the skill started. */
  const ownSerial = (s) => (s.state().running ?? []).find((d) => d.avd === "screen-video-android")?.serial;

  // --- checks ----------------------------------------------------------------------------------

  await check("check accepts app flows and refuses what an app flow cannot run", async () => {
    for (const file of [MAC_FLOW, IOS_FLOW, ANDROID_FLOW, MAC_POINT]) {
      const r = await run(["check", file], mac);
      if (r.status !== 0) return `check exited ${r.status} for ${file}: ${last(r)}`;
    }
    const app = { platform: "mac", id: "com.example.notes" };
    const phone = { platform: "android", id: "com.example.notes" };
    const open = { do: "open" };
    const refused = [
      ["both", { url: "http://127.0.0.1:9/", app, steps: [open] }, /flow:.*(\burl\b.*\bapp\b|\bapp\b.*\burl\b)/],
      ["windows", { app: { platform: "windows", id: "com.example.notes" }, steps: [open] }, /flow:.*platform/],
      ["mac-install", { app: { ...app, install: "build/Notes.app" }, steps: [open] }, /flow:.*install/],
      ["outside-install", { app: { ...phone, install: "../notes.apk" }, steps: [open] }, /flow:.*install/],
      ["mac-swipe", { app, steps: [open, { do: "swipe", from: [1, 1], to: [2, 2] }] }, /step 2\b.*swipe/],
      ["css", { app: phone, steps: [open, { do: "click", target: { css: "#save" } }] }, /step 2\b.*css/],
      ["placeholder", { app: phone, steps: [open, { do: "fill", target: { placeholder: "Title" }, text: "x" }] }, /step 2\b.*placeholder/],
      ["in-frame", { app: phone, steps: [open, { do: "click", target: { role: "button", name: "Save", frame: "pay" } }] }, /step 2\b.*frame/],
      ["open-url", { app: phone, steps: [{ do: "open", url: "/" }] }, /step 1\b.*url/],
      ["select", { app: phone, steps: [open, { do: "select", target: { label: "Size" }, value: "L" }] }, /step 2\b.*select/],
      ["wait-url", { app: phone, steps: [open, { do: "wait", until: { url: "/done" } }] }, /step 2\b.*url/],
      ["wait-settled", { app: phone, steps: [open, { do: "wait", until: { settled: 1 } }] }, /step 2\b.*settled/],
      ["login", { app: phone, login: { session: "app" }, steps: [open] }, /flow:.*login/],
    ];
    for (const [name, body, pattern] of refused) {
      const r = await run(["check", flow(`refused-${name}`, body)], mac);
      if (r.status !== 1) return `check exited ${r.status} for the ${name} flow`;
      if (!pattern.test(r.all)) return `check did not say ${pattern} for the ${name} flow: ${last(r)}`;
    }
    return true;
  });

  await check("app targets find the same part in the macOS, iOS, and Android lists", async () => {
    const { readParts, findPart } = await import(join(SKILL, "scripts", "lib", "app-parts.mjs"));
    const lists = {
      mac: readParts("mac", readText(join(FIXTURES, "mac-parts.json"))),
      ios: readParts("ios", readText(join(FIXTURES, "ios-describe-all.json"))),
      android: readParts("android", readText(join(FIXTURES, "android-dump.xml"))),
    };
    const frames = {
      save: { mac: [352, 96, 80, 28], ios: [322, 170, 52, 44], android: [860, 420, 180, 120] },
      heading: { mac: [20, 12, 120, 24], ios: [16, 60, 120, 34], android: [42, 140, 300, 80] },
    };
    const points = { mac: [100, 64], ios: [86, 132], android: [232, 320] };
    const byId = [
      [{ role: "button", name: "Save" }, "save"],
      [{ testId: "save" }, "save"],
      [{ label: "Title" }, "title"],
      [{ text: "Milk, eggs, bread" }, "body"],
      [{ role: "button", name: "Share", nth: 1 }, "share_bottom"],
      [{ role: "switch", name: "Sync" }, "sync"],
    ];
    const same = (a, b) => Array.isArray(a) && a.length === 4 && a.every((v, i) => Math.abs(v - b[i]) < 0.5);
    for (const [system, parts] of Object.entries(lists)) {
      if (!Array.isArray(parts) || parts.length === 0) return `no parts read from the ${system} list`;
      for (const part of parts) {
        for (const key of ["role", "name", "value", "id", "frame"]) if (!(key in part)) return `a ${system} part has no ${key}: ${JSON.stringify(part)}`;
      }
      for (const [target, id] of byId) {
        const found = findPart(parts, target);
        if (typeof found?.id !== "string" || !(found.id === id || found.id.endsWith(`/${id}`))) return `${system}: ${JSON.stringify(target)} found ${JSON.stringify(found)}`;
      }
      if (!same(findPart(parts, { testId: "save" }).frame, frames.save[system])) return `${system}: the frame of Save is ${JSON.stringify(findPart(parts, { testId: "save" }).frame)}`;
      const heading = findPart(parts, { text: "Notes" });
      if (heading === undefined || !same(heading.frame, frames.heading[system])) return `${system}: text "Notes" found ${JSON.stringify(heading)}`;
      const point = findPart(parts, { point: points[system] });
      const [x, y, w, h] = point?.frame ?? [];
      if (Math.abs(x + w / 2 - points[system][0]) > 0.5 || Math.abs(y + h / 2 - points[system][1]) > 0.5) return `${system}: the point target is at ${JSON.stringify(point?.frame)}`;
      for (const target of [{ role: "button", name: "Nope" }, { text: "Nope" }, { testId: "nope" }]) {
        if (findPart(parts, target) !== undefined) return `${system}: ${JSON.stringify(target)} was found`;
      }
    }
    if (findPart(lists.mac, { role: "button", name: "Hidden" }) !== undefined) return "a part with no size on the screen was found";
    // A target found nowhere fails its step, naming the step and the target
    const s = scenario("not-there", { android: ANDROID });
    const r = await run(["rehearse", NOT_THERE, "--out", join(A, "rehearse-not-there")], s);
    if (r.status !== 1) return `rehearse with a missing target exited ${r.status}: ${last(r)}`;
    if (!/step 2\b/.test(r.stderr) || !r.stderr.includes('button "Nope"')) return `rehearse did not name step 2 and its target: ${last(r)}`;
    return true;
  });

  await check("record drives a macOS app window and writes the videos", async () => {
    const r = await run(["record", MAC_FLOW, "--out", MAC_OUT], mac);
    Object.assign(macRun, r);
    if (r.status !== 0) return `record exited ${r.status}: ${last(r)}`;
    const log = mac.lines();
    if (!log.includes("screen-video-mac launch com.example.notes")) return "the app was not launched by its bundle id";
    const recorded = log.filter((l) => l.startsWith("screen-video-mac record "));
    if (recorded.length !== 1 || recorded[0].split(" ")[2] !== "77") return `the recording was not of the app's window: ${recorded.join(" | ")}`;
    const presses = log.filter((l) => l.startsWith("screen-video-mac press ")).map((l) => l.split(" ").slice(2).map(Number));
    const wrong = presses.length !== MAC_CENTRES.length || presses.some((p, i) => p[0] !== 77 || Math.abs(p[1] - MAC_CENTRES[i][0]) > 0.5 || Math.abs(p[2] - MAC_CENTRES[i][1]) > 0.5);
    if (wrong) return `presses at ${JSON.stringify(presses)}, not at the centres ${JSON.stringify(MAC_CENTRES)} of window 77`;
    if (!log.some((l) => l === "screen-video-mac type Groceries")) return "the title was not typed";
    for (const name of ["raw.mp4", "captioned.mp4", "edited.mp4"]) {
      const size = probe(join(MAC_OUT, name));
      if (size.width !== 1920 || size.height !== 1080) return `${name} is ${size.width}x${size.height}`;
    }
    const timeline = JSON.parse(readText(join(MAC_OUT, "timeline.json")));
    if (timeline.app?.platform !== "mac") return "timeline.json does not name the app";
    const pressed = timeline.steps.filter((step) => step.press !== undefined);
    if (pressed.length !== MAC_CENTRES.length) return `timeline.json keeps ${pressed.length} press positions`;
    for (const [i, step] of pressed.entries()) {
      const want = inVideo(timeline, ...MAC_CENTRES[i]);
      if (Math.abs(step.press.x - want.x) > 2 || Math.abs(step.press.y - want.y) > 2) return `step ${step.step} keeps the press at ${JSON.stringify(step.press)}, not ${JSON.stringify(want)}`;
    }
    const swift = readText(join(SKILL, "scripts", "mac", "screen-video-mac.swift"));
    if (!swift.includes("SCContentFilter(desktopIndependentWindow:")) return "the Swift tool does not capture with a filter of one window";
    if (swift.includes("SCContentFilter(display:")) return "the Swift tool captures a whole display";
    return true;
  });

  await check("record drives the iOS Simulator and writes the videos", async () => {
    const r = await run(["record", IOS_FLOW, "--out", IOS_OUT], ios);
    Object.assign(iosRun, r);
    if (r.status !== 0) return `record exited ${r.status}: ${last(r)}`;
    const log = ios.lines();
    const own = "SV-UDID-0002";
    if (!log.includes(`xcrun simctl boot ${own}`)) return "the simulator screen-video-ios was not booted";
    if (!log.some((l) => / install /.test(` ${l} `) && l.includes(own) && l.includes(join("build", "Notes.app")))) return "the flow's build was not installed";
    if (!log.some((l) => /\blaunch\b/.test(l) && l.includes(own) && l.includes("com.example.notes"))) return "the app was not launched";
    const taps = log.filter((l) => l.startsWith("idb ui tap ")).map((l) => l.split(" ").filter((w) => /^-?\d+(\.\d+)?$/.test(w)).map(Number));
    const wrong = taps.length !== IOS_CENTRES.length || taps.some((p, i) => Math.abs(p[0] - IOS_CENTRES[i][0]) > 0.5 || Math.abs(p[1] - IOS_CENTRES[i][1]) > 0.5);
    if (wrong) return `taps at ${JSON.stringify(taps)}, not at the centres ${JSON.stringify(IOS_CENTRES)}`;
    if (!log.some((l) => l.startsWith("idb ui swipe ") && l.includes("195 600 195 300"))) return "the swipe was not sent through idb";
    if (!log.some((l) => l.startsWith("idb ui text ") && l.includes("Groceries"))) return "the title was not typed through idb";
    if (!log.some((l) => l.startsWith("idb record-video ") && l.includes(own))) return "the recording was not made with idb record-video";
    for (const name of ["raw.mp4", "captioned.mp4", "edited.mp4"]) {
      const size = probe(join(IOS_OUT, name));
      if (size.width !== 1920 || size.height !== 1080) return `${name} is ${size.width}x${size.height}`;
    }
    const timeline = JSON.parse(readText(join(IOS_OUT, "timeline.json")));
    const pressed = timeline.steps.filter((step) => step.press !== undefined && ["click", "fill"].includes(step.kind));
    if (timeline.app?.platform !== "ios" || pressed.length !== IOS_CENTRES.length) return `timeline.json keeps ${pressed.length} presses of ${timeline.app?.platform}`;
    return true;
  });

  await check("record drives the Android emulator and writes the videos", async () => {
    const r = await run(["record", ANDROID_FLOW, "--out", ANDROID_OUT], android);
    Object.assign(androidRun, r);
    if (r.status !== 0) return `record exited ${r.status}: ${last(r)}`;
    const log = android.lines();
    if (!log.some((l) => l.startsWith("emulator ") && l.includes("-avd screen-video-android"))) return "the emulator screen-video-android was not started";
    const own = ownSerial(android);
    if (own === undefined) return "no emulator of screen-video-android is running";
    const sent = (pattern) => log.some((l) => l.startsWith(`adb -s ${own} `) && pattern.test(l));
    if (!sent(/ install .*notes\.apk/)) return "the flow's build was not installed";
    if (!sent(/ shell (monkey|am start).*com\.example\.notes/)) return "the app was not launched";
    const taps = log.filter((l) => l.startsWith(`adb -s ${own} shell input tap `)).map((l) => l.split(" ").slice(-2).map(Number));
    const wrong = taps.length !== ANDROID_CENTRES.length || taps.some((p, i) => Math.abs(p[0] - ANDROID_CENTRES[i][0]) > 0.5 || Math.abs(p[1] - ANDROID_CENTRES[i][1]) > 0.5);
    if (wrong) return `taps at ${JSON.stringify(taps)}, not at the centres ${JSON.stringify(ANDROID_CENTRES)}`;
    if (!sent(/ shell input swipe 360 1300 360 500\b/)) return "the swipe was not sent through adb shell input";
    if (!sent(/ shell input text Groceries$/)) return "the title was not typed through adb shell input";
    if (!sent(/ shell screenrecord /)) return "the recording was not made with adb shell screenrecord";
    if (!sent(/ pull /)) return "the recording was not pulled from the emulator";
    for (const name of ["raw.mp4", "captioned.mp4", "edited.mp4"]) {
      const size = probe(join(ANDROID_OUT, name));
      if (size.width !== 1920 || size.height !== 1080) return `${name} is ${size.width}x${size.height}`;
    }
    const vertical = probe(join(ANDROID_OUT, "vertical.mp4"));
    if (vertical.width !== 1080 || vertical.height !== 1920) return `vertical.mp4 is ${vertical.width}x${vertical.height}`;
    const timeline = JSON.parse(readText(join(ANDROID_OUT, "timeline.json")));
    const pressed = timeline.steps.filter((step) => step.press !== undefined && ["click", "fill"].includes(step.kind));
    if (timeline.app?.platform !== "android" || pressed.length !== ANDROID_CENTRES.length) return `timeline.json keeps ${pressed.length} presses of ${timeline.app?.platform}`;
    return true;
  });

  await check("phone flows run only on the skill's own simulator and emulator", async () => {
    // Without the skill's own simulator or emulator, nothing is sent to any device
    const noIos = scenario("no-ios", { ios: { ...IOS, devices: [IOS.devices[0]] } });
    const noAndroid = scenario("no-android", { android: { ...ANDROID, avds: ["Pixel_8_API_35"] } });
    for (const [s, file, setup] of [
      [noIos, IOS_FLOW, "setup ios"],
      [noAndroid, ANDROID_FLOW, "setup android"],
    ]) {
      for (const command of ["rehearse", "record"]) {
        const r = await run([command, file, "--out", join(A, `${command}-without-${setup.split(" ")[1]}`)], s);
        if (r.status !== 1) return `${command} without the skill's own device exited ${r.status}: ${last(r)}`;
        if (!r.stderr.includes(setup)) return `${command} did not name ${setup}: ${last(r)}`;
      }
      const asked = /^(xcrun simctl list\b|emulator -list-avds$|adb (devices|start-server|version)$|avdmanager list\b|sdkmanager --list_installed)/;
      const sent = s.lines().filter((l) => !asked.test(l));
      if (sent.length > 0) return `without the skill's own device, these were sent: ${sent.join(" | ")}`;
    }
    // With them, no other simulator or emulator gets a command
    if (iosRun.status !== 0 || androidRun.status !== 0) return "the iOS or the Android recording failed";
    for (const l of ios.lines()) {
      if (l.includes("USER-UDID-0001")) return `a command went to the user's simulator: ${l}`;
      if (l.startsWith("idb ") && !l.includes("SV-UDID-0002")) return `an idb command did not name screen-video-ios: ${l}`;
      if (/^xcrun simctl (boot|bootstatus|install|launch|terminate|io|shutdown|openurl)\b/.test(l) && !l.includes("SV-UDID-0002")) return `a simctl command did not name screen-video-ios: ${l}`;
    }
    const own = ownSerial(android);
    for (const l of android.lines()) {
      if (l.includes("emulator-5554")) return `a command went to the user's emulator: ${l}`;
      if (l.startsWith("adb ") && !/^adb (devices|start-server|version)$/.test(l) && !l.startsWith(`adb -s ${own} `)) return `an adb command did not name the skill's emulator: ${l}`;
    }
    return true;
  });

  const MAC_REHEARSAL = join(A, "rehearse-mac");
  await check("rehearse writes a storyboard for an app flow and stops before the first marked step", async () => {
    const s = scenario("rehearse-android", { android: ANDROID });
    const out = join(A, "rehearse-android");
    const r = await run(["rehearse", MARKED, "--out", out], s);
    if (r.status !== 0) return `rehearse exited ${r.status}: ${last(r)}`;
    const html = readText(join(out, "storyboard.html"));
    for (let step = 1; step <= 3; step++) {
      if (!new RegExp(`data-step="${step}"[^>]*data-status="ok"`).test(html)) return `the storyboard does not show step ${step} as rehearsed`;
      if (!existsSync(join(out, "frames", `00${step}.png`))) return `no picture of step ${step}`;
    }
    for (const step of [4, 5]) if (!new RegExp(`data-step="${step}"[^>]*data-status="skipped"`).test(html)) return `the storyboard does not show step ${step} as not rehearsed`;
    if (existsSync(join(out, "frames", "004.png"))) return "rehearse took a picture of the marked step";
    const log = s.lines();
    if (log.some((l) => / shell input tap 560 570$/.test(l))) return "rehearse pressed the marked step's target";
    if (log.some((l) => / shell screenrecord /.test(l))) return "rehearse recorded the screen";
    if (!log.some((l) => / exec-out screencap/.test(l))) return "the pictures are not screenshots of the emulator";
    // A macOS app is pictured by its window
    const m = scenario("rehearse-mac", { mac: MAC });
    const mr = await run(["rehearse", MAC_FLOW, "--out", MAC_REHEARSAL], m);
    if (mr.status !== 0) return `rehearse of the macOS flow exited ${mr.status}: ${last(mr)}`;
    for (let step = 1; step <= 6; step++) if (!existsSync(join(MAC_REHEARSAL, "frames", `00${step}.png`))) return `no picture of step ${step} of the macOS flow`;
    if (!m.lines().some((l) => l.startsWith("screen-video-mac screenshot 77 "))) return "the pictures are not screenshots of the app's window";
    if (m.lines().some((l) => l.startsWith("screen-video-mac record "))) return "rehearse recorded the window";
    return true;
  });

  await check("the edit draws each press of an app at its recorded position", async () => {
    if (macRun.status !== 0 || androidRun.status !== 0) return "the macOS or the Android recording failed";
    for (const [label, out, arrow] of [
      ["macOS", MAC_OUT, true],
      ["Android", ANDROID_OUT, false],
    ]) {
      const timeline = JSON.parse(readText(join(out, "timeline.json")));
      const edit = JSON.parse(readText(join(out, "edit.json")));
      const taps = timeline.steps.filter((step) => step.press !== undefined && ["click", "fill"].includes(step.kind));
      if (taps.length < 3) return `${label}: timeline.json keeps ${taps.length} presses`;
      for (const step of taps) {
        const at = editedAt(edit, step.step).t;
        const frame = frameAt(join(out, "edited.mp4"), at + 0.12);
        const mark = middleOf(frame, isAccent);
        if (mark === undefined) return `${label} step ${step.step}: no press mark at ${at.toFixed(2)}s of edited.mp4`;
        // The part pressed is drawn black: it shows through the mark up and to the left of its middle
        if (share(frame, isDark, mark.x - 14, mark.y - 14, 11, 11) < 0.6) return `${label} step ${step.step}: the mark at (${mark.x}, ${mark.y}) is not on the part pressed`;
        const white = count(frame, isWhite, mark.x + 2, mark.y + 2, 26, 26);
        if (arrow && white < 6) return `macOS step ${step.step}: no arrow at the press`;
        if (!arrow && white > 0) return `Android step ${step.step}: an arrow is drawn over a phone`;
        if (!arrow) {
          // A phone is never zoomed into, so the mark's place before the tap shows the screen without it
          const before = frameAt(join(out, "edited.mp4"), at - 0.45);
          if (count(before, isAccent, mark.x - 40, mark.y - 40, 80, 80) > 0) return `Android step ${step.step}: the mark shows before the tap`;
        }
      }
    }
    return true;
  });

  await check("masked parts of an app are blurred in every video and no unblurred capture is kept", async () => {
    if (macRun.status !== 0 || androidRun.status !== 0) return "the macOS or the Android recording failed";
    const blurred = (file, at, masked, plain, what) => {
      const m = detail(file, at, masked);
      const p = detail(file, at, plain);
      if (p < 3) return `${what}: the unmasked part shows no detail (${p.toFixed(2)})`;
      if (m > p * 0.35) return `${what}: the masked part keeps detail (${m.toFixed(2)} against ${p.toFixed(2)})`;
      return undefined;
    };
    // macOS: the card number is masked by its text, before and after it moves
    const mt = JSON.parse(readText(join(MAC_OUT, "timeline.json")));
    const me = JSON.parse(readText(join(MAC_OUT, "edit.json")));
    const first = mt.steps.find((step) => step.press !== undefined);
    const RIGHT = boxInVideo(mt, [540, 210, 220, 70]);
    const LEFT = boxInVideo(mt, [40, 210, 220, 70]);
    const PLAIN = boxInVideo(mt, [40, 310, 300, 70]);
    for (const name of ["raw.mp4", "captioned.mp4"]) {
      const problem = blurred(join(MAC_OUT, name), first.t - 0.5, RIGHT, PLAIN, `${name} before the card moves`) ?? blurred(join(MAC_OUT, name), first.t + 0.9, LEFT, PLAIN, `${name} after the card moves`);
      if (problem !== undefined) return problem;
    }
    // In edited.mp4, while the whole window shows, before the first zoom
    const zoomed = (me.keys ?? []).find((k) => k.z !== 1);
    const whole = Math.min(editedAt(me, first.step).t - 1.2, zoomed === undefined ? Infinity : zoomed.t - 1);
    const problem = blurred(join(MAC_OUT, "edited.mp4"), Math.max(0.2, whole), boxInEdited(me, RIGHT), boxInEdited(me, PLAIN), "edited.mp4");
    if (problem !== undefined) return problem;
    // Android: a named part and a fixed area
    const at = JSON.parse(readText(join(ANDROID_OUT, "timeline.json")));
    const ae = JSON.parse(readText(join(ANDROID_OUT, "edit.json")));
    const hold = at.steps.find((step) => step.kind === "hold");
    const SECRET = boxInVideo(at, [40, 800, 640, 140], 4);
    const STATUS = boxInVideo(at, [200, 0, 320, 60], 4);
    const BODY = boxInVideo(at, [40, 1100, 640, 140], 4);
    for (const name of ["raw.mp4", "captioned.mp4"]) {
      const t = (hold.from + hold.end) / 2;
      const found = blurred(join(ANDROID_OUT, name), t, SECRET, BODY, `${name}, the part named by testId`) ?? blurred(join(ANDROID_OUT, name), t, STATUS, BODY, `${name}, the fixed area`);
      if (found !== undefined) return found;
    }
    const held = editedAt(ae, hold.step);
    const edited = blurred(join(ANDROID_OUT, "edited.mp4"), (held.from + held.end) / 2, boxInEdited(ae, SECRET), boxInEdited(ae, BODY), "edited.mp4 of the phone");
    if (edited !== undefined) return edited;
    // The storyboard's pictures are blurred too
    const picture = join(MAC_REHEARSAL, "frames", "001.png");
    if (!existsSync(picture)) return "the macOS rehearsal left no picture";
    const k = probe(picture).width / MAC.window.width;
    const box = ([x, y, w, h]) => ({ x: x * k + 8, y: y * k + 8, w: w * k - 16, h: h * k - 16 });
    const still = blurred(picture, 0, box([540, 210, 220, 70]), box([40, 310, 300, 70]), "the storyboard picture");
    if (still !== undefined) return still;
    // Nothing captured before the blur is left
    const made = /^(raw|captioned|edited|vertical)\.mp4$|^edited\.gif$/;
    for (const out of [MAC_OUT, IOS_OUT, ANDROID_OUT]) {
      const other = filesUnder(out).filter((f) => /\.(mp4|mov|webm|mkv|gif)$/i.test(f) && !made.test(f.split("/").at(-1)));
      if (other.length > 0) return `a capture is left in the output: ${other.join(", ")}`;
    }
    for (const s of [mac, ios, android]) {
      const left = filesUnder(s.data).filter((f) => /\.(mp4|mov|webm|mkv|png)$/i.test(f));
      if (left.length > 0) return `a capture is left in the data folder: ${left.join(", ")}`;
    }
    const kept = filesUnder(TMP).filter((f) => /\.(mp4|mov|webm|mkv|png)$/i.test(f));
    if (kept.length > 0) return `a capture is left in the temporary folder: ${kept.join(", ")}`;
    if (filesUnder(android.storage).length > 0) return `the recording is left on the emulator: ${filesUnder(android.storage).join(", ")}`;
    return true;
  });

  await check("a phone recording fills the vertical video and sits whole in the middle of the wide one", async () => {
    if (androidRun.status !== 0) return "the Android recording failed";
    const timeline = JSON.parse(readText(join(ANDROID_OUT, "timeline.json")));
    const edit = JSON.parse(readText(join(ANDROID_OUT, "edit.json")));
    const hold = editedAt(edit, timeline.steps.find((step) => step.kind === "hold").step);
    const shape = ANDROID.screen.width / ANDROID.screen.height;
    const place = (file, at) => boundsOf(frameAt(join(ANDROID_OUT, file), at), isGreen);
    const middle = (hold.from + hold.end) / 2;
    const tall = place("vertical.mp4", middle);
    if (tall.top > 2 || tall.bottom < 1917) return `the phone takes rows ${tall.top} to ${tall.bottom} of the vertical video`;
    if (Math.abs((tall.left + tall.right) / 2 - 540) > 4) return `the phone is not in the middle of the vertical video (${tall.left} to ${tall.right})`;
    if (Math.abs(tall.width / tall.height - shape) > 0.02) return `the phone is cut in the vertical video (${tall.width}x${tall.height})`;
    const wide = place("edited.mp4", middle);
    if (Math.abs((wide.left + wide.right) / 2 - 960) > 4) return `the phone is not in the middle of the wide video (${wide.left} to ${wide.right})`;
    if (Math.abs(wide.width / wide.height - shape) > 0.02) return `the phone is cut in the wide video (${wide.width}x${wide.height})`;
    if (wide.top < 1 || wide.bottom > 1078) return `the phone runs off the wide video (rows ${wide.top} to ${wide.bottom})`;
    // Neither video zooms into the phone: at each tap it keeps its size and place
    for (const step of timeline.steps.filter((s) => s.press !== undefined)) {
      const at = editedAt(edit, step.step).t + 0.12;
      for (const [file, still] of [
        ["vertical.mp4", tall],
        ["edited.mp4", wide],
      ]) {
        const now = place(file, at);
        if (["left", "right", "top", "bottom"].some((key) => Math.abs(now[key] - still[key]) > 3)) return `${file} zooms into the phone at step ${step.step}`;
      }
    }
    return true;
  });

  await check("setup prepares each app system only with --yes and names the macOS permissions to turn on", async () => {
    const s = scenario(
      "setup",
      {
        ios: { ...IOS, devices: [IOS.devices[0]], runtimes: [] },
        android: { ...ANDROID, avds: ["Pixel_8_API_35"], packages: ["platform-tools", "emulator"] },
        mac: { ...MAC, permissions: { screenRecording: false, accessibility: true } },
      },
      { idb: false, mac: false, companion: false },
    );
    const changes = /venv|pip install|brew install|-downloadPlatform|simctl create|sdkmanager .*system-images|avdmanager create|^swiftc /;
    for (const [system, named] of [
      ["ios", "screen-video-ios"],
      ["android", "screen-video-android"],
      ["mac", "screen-video-mac"],
    ]) {
      const r = await run(["setup", system], s);
      if (r.status !== 0) return `setup ${system} exited ${r.status}: ${last(r)}`;
      if (!r.stdout.includes(named)) return `setup ${system} did not name ${named}`;
      if (!/\d+(\.\d+)? ?(KB|MB|GB)\b/.test(r.stdout)) return `setup ${system} did not say the size`;
      const changed = s.lines().filter((l) => changes.test(l));
      if (changed.length > 0) return `setup ${system} without --yes ran: ${changed.join(" | ")}`;
      if (existsSync(join(s.data, "apps"))) return `setup ${system} without --yes wrote into the data folder`;
    }
    const sent = (pattern) => s.lines().some((l) => pattern.test(l));
    const iosYes = await run(["setup", "ios", "--yes"], s);
    if (iosYes.status !== 0) return `setup ios --yes exited ${iosYes.status}: ${last(iosYes)}`;
    for (const [what, pattern] of [
      ["the virtual environment for idb", new RegExp(`^python3 -m venv ${join(s.data, "apps", "idb").replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}$`)],
      ["idb", /^pip install fb-idb\b/],
      ["idb_companion", /^brew install \S*idb-companion$/],
      ["the iOS runtime", /^xcodebuild -downloadPlatform iOS\b/],
      ["screen-video-ios", /^xcrun simctl create screen-video-ios /],
    ]) {
      if (!sent(pattern)) return `setup ios --yes did not install ${what}`;
    }
    if (!existsSync(join(s.data, "apps", "idb", "bin", "idb"))) return "idb is not in the data folder";
    const androidYes = await run(["setup", "android", "--yes"], s);
    if (androidYes.status !== 0) return `setup android --yes exited ${androidYes.status}: ${last(androidYes)}`;
    if (!sent(/^sdkmanager .*system-images;android-/)) return "setup android --yes did not install a system image";
    if (!sent(/^avdmanager create avd .*screen-video-android/)) return "setup android --yes did not create screen-video-android";
    const macYes = await run(["setup", "mac", "--yes"], s);
    if (!sent(/^swiftc .*screen-video-mac\.swift/) || !sent(new RegExp(`-o ${join(s.data, "apps", "mac", "screen-video-mac").replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`))) return "setup mac --yes did not build the Swift tool into the data folder";
    if (!existsSync(join(s.data, "apps", "mac", "screen-video-mac"))) return "the Swift tool is not in the data folder";
    if (!macYes.all.includes("Screen Recording")) return `setup mac did not say to turn on Screen Recording: ${last(macYes)}`;
    if (!s.lines().includes("screen-video-mac open-settings screen-recording")) return "setup mac did not open the Screen Recording settings";
    if (s.lines().includes("screen-video-mac open-settings accessibility")) return "setup mac opened the Accessibility settings, which were on";
    // record of a macOS flow stops before the app is launched when a permission is off
    s.set({ mac: { ...MAC, permissions: { screenRecording: true, accessibility: false } } });
    const rec = await run(["record", MAC_FLOW, "--out", join(A, "record-mac-permission")], s);
    if (rec.status !== 1) return `record without the Accessibility permission exited ${rec.status}`;
    if (!rec.stderr.includes("Accessibility")) return `record did not say to turn on Accessibility: ${last(rec)}`;
    if (!s.lines().includes("screen-video-mac open-settings accessibility")) return "record did not open the Accessibility settings";
    if (s.lines().some((l) => l.startsWith("screen-video-mac launch "))) return "record launched the app without the permission";
    return true;
  });

  await check("the SKILL.md and the docs describe recording apps and simulators", async () => {
    const skill = readText(join(SKILL, "SKILL.md"));
    for (const phrase of [
      "An app flow is planned, rehearsed, and recorded the same way as a browser flow",
      "Before running `setup mac`, `setup ios`, or `setup android` with `--yes`, tell the user what it installs and its size, and ask",
      "Screen Recording",
      "Accessibility",
      "`screen-video-ios`",
      "`screen-video-android`",
    ]) {
      if (!skill.includes(phrase)) return `SKILL.md lacks: ${phrase}`;
    }
    const docs = [
      join(SKILL, "references", "flow-format.md"),
      join(PLUGIN, "docs", "how-it-works.md"),
      join(PLUGIN, "docs", "how-it-works.ja.md"),
      join(PLUGIN, "README.md"),
      join(PLUGIN, "README.ja.md"),
    ];
    for (const file of docs) {
      const text = readText(file);
      for (const word of ["`app`", "`point`", "`swipe`", "`rect`", "setup mac", "setup ios", "setup android"]) {
        if (!text.includes(word)) return `${file.slice(PLUGIN.length + 1)} lacks ${word}`;
      }
    }
    return true;
  });

  rmSync(A, { recursive: true, force: true });
}
