/**
 * `setup mac`, `setup ios`, and `setup android`: what a system needs before an app flow records on
 * it. Without `--yes` it lists what it would install, with the size of each, and changes nothing;
 * with `--yes` it installs them.
 *
 * | System | What it installs |
 * |---|---|
 * | `mac` | screen-video's Swift tool, built with `swiftc` into `<data>/apps/mac/`. Then it checks the Screen Recording and Accessibility permissions and opens the settings of each one that is off |
 * | `ios` | the iOS Simulator runtime when Xcode has none, idb in a Python virtual environment in `<data>/apps/idb/`, idb_companion from Homebrew, and the simulator `screen-video-ios` |
 * | `android` | the SDK's platform-tools, emulator, and an Android system image with `sdkmanager`, and the emulator `screen-video-android` |
 *
 * The sizes are what each takes on the disk, rounded up.
 */
import { existsSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";

import { ANDROID_DEVICE, androidHome, androidTool, askForPermissions, IOS_DEVICE, idbTool, MAC_SOURCE, macTool, macToolBuilt, missingPermissions, simulators, tool, which } from "./devices.mjs";
import { dataDir } from "./runtime.mjs";

/** The idb release `setup ios` installs. */
const IDB_VERSION = "1.1.7";
/** The Android version of the emulator `setup android` creates. */
const ANDROID_API = 35;
const HOUR = 3600_000;

const androidImage = () => `system-images;android-${ANDROID_API};google_apis;${process.arch === "arm64" ? "arm64-v8a" : "x86_64"}`;
const byVersion = (a, b) => {
  const [x, y] = [a, b].map((r) => String(r.version ?? "0").split(".").map(Number));
  for (let i = 0; i < Math.max(x.length, y.length); i++) if ((x[i] ?? 0) !== (y[i] ?? 0)) return (x[i] ?? 0) - (y[i] ?? 0);
  return 0;
};

function needs(command, message) {
  if (which(command) === undefined) throw new Error(message);
}

function macPlan() {
  if (process.platform !== "darwin") throw new Error("setup mac runs only on a Mac.");
  const bin = macTool();
  const items = [];
  if (!macToolBuilt(bin)) {
    items.push({
      what: `screen-video's Swift tool screen-video-mac, which opens, reads, presses, and records the app's window, built with swiftc into ${dirname(bin)}`,
      size: "about 1 MB",
      install: () => {
        needs("swiftc", "swiftc is missing. Install Xcode's command line tools (run xcode-select --install), then run setup mac --yes again.");
        mkdirSync(dirname(bin), { recursive: true, mode: 0o700 });
        tool("swiftc", ["-O", "-parse-as-library", "-o", bin, MAC_SOURCE], { timeout: 900_000 });
      },
    });
  }
  return {
    items,
    note: "Then it checks that macOS gives Screen Recording and Accessibility to the app this agent runs in, and opens the settings of each one that is off.",
    after() {
      const missing = missingPermissions(bin);
      if (missing.length > 0) throw new Error(askForPermissions(missing, bin));
    },
  };
}

function iosPlan() {
  if (process.platform !== "darwin") throw new Error("setup ios runs only on a Mac, where the iOS Simulator runs.");
  needs("xcrun", "Xcode is missing. Install Xcode from the App Store, open it once, then run setup ios again.");
  const runtimes = () =>
    JSON.parse(tool("xcrun", ["simctl", "list", "runtimes", "--json"]))
      .runtimes.filter((r) => (r.platform === "iOS" || /SimRuntime\.iOS-/.test(r.identifier ?? "")) && r.isAvailable !== false)
      .sort(byVersion);
  const venv = join(dataDir(), "apps", "idb");
  const items = [];
  if (runtimes().length === 0) {
    items.push({
      what: "the iOS Simulator runtime, downloaded by Xcode (xcodebuild -downloadPlatform iOS)",
      size: "about 8 GB",
      install: () => tool("xcodebuild", ["-downloadPlatform", "iOS"], { timeout: 3 * HOUR }),
    });
  }
  if (!existsSync(idbTool())) {
    items.push({
      what: `idb ${IDB_VERSION}, which drives the simulator, in a Python virtual environment in ${venv}`,
      size: "about 40 MB",
      install: () => {
        needs("python3", "python3 is missing. Install Xcode's command line tools (run xcode-select --install), then run setup ios --yes again.");
        mkdirSync(dirname(venv), { recursive: true, mode: 0o700 });
        tool("python3", ["-m", "venv", venv], { timeout: 300_000 });
        tool(join(venv, "bin", "pip"), ["install", `fb-idb==${IDB_VERSION}`], { timeout: HOUR });
      },
    });
  }
  if (which("idb_companion") === undefined) {
    items.push({
      what: "idb_companion, which idb talks to the simulator through, from Homebrew (brew install facebook/fb/idb-companion)",
      size: "about 30 MB",
      install: () => {
        needs("brew", "Homebrew is missing. Install it, then run setup ios --yes again.");
        tool("brew", ["install", "facebook/fb/idb-companion"], { timeout: HOUR });
      },
    });
  }
  if (!simulators().some((device) => device.name === IOS_DEVICE)) {
    items.push({
      what: `the simulator ${IOS_DEVICE}, an iPhone simulator that only screen-video uses, so the simulators of your own stay as they are`,
      size: "about 1 GB once it has started",
      install: () => {
        const runtime = runtimes().at(-1);
        if (runtime === undefined) throw new Error("Xcode has no iOS Simulator runtime. Open Xcode > Settings > Components, add an iOS runtime, then run setup ios --yes again.");
        const listed = JSON.parse(tool("xcrun", ["simctl", "list", "devicetypes", "--json"])).devicetypes ?? [];
        const iphone = (type) => type.productFamily === "iPhone" || /iPhone/.test(type.identifier ?? "");
        // The newest iPhone the runtime runs
        const types = (runtime.supportedDeviceTypes ?? listed).filter(iphone);
        if (types.length === 0) throw new Error(`Xcode lists no iPhone simulator for ${runtime.name ?? runtime.identifier}.`);
        tool("xcrun", ["simctl", "create", IOS_DEVICE, types.at(-1).identifier, runtime.identifier]);
      },
    });
  }
  return { items };
}

function androidPlan() {
  const root = androidHome();
  const sdkmanager = androidTool("sdkmanager");
  const avdmanager = androidTool("avdmanager");
  if (sdkmanager === undefined || avdmanager === undefined) {
    throw new Error(`The Android SDK's command-line tools (sdkmanager and avdmanager) are missing in ${root}. Install Android Studio and add the command-line tools in its SDK Manager, then run setup android again.`);
  }
  const installed = tool(sdkmanager, [`--sdk_root=${root}`, "--list_installed"], { timeout: 300_000 })
    .split("\n")
    .filter((line) => line.includes("|"))
    .map((line) => line.split("|")[0].trim());
  const image = androidImage();
  const SIZES = { "platform-tools": 15, emulator: 400, [image]: 4000 };
  const wanted = Object.keys(SIZES).filter((name) => !installed.includes(name));
  const items = [];
  if (wanted.length > 0) {
    const megabytes = wanted.reduce((sum, name) => sum + SIZES[name], 0);
    items.push({
      what: `the Android SDK packages ${wanted.join(", ")}, installed by sdkmanager into ${root}, accepting their licenses`,
      size: megabytes >= 1000 ? `about ${(megabytes / 1000).toFixed(1)} GB` : `about ${megabytes} MB`,
      install: () => tool(sdkmanager, [`--sdk_root=${root}`, "--install", ...wanted], { input: "y\n".repeat(50), timeout: 3 * HOUR }),
    });
  }
  const avds = tool(avdmanager, ["list", "avd", "-c"], { timeout: 300_000 })
    .split("\n")
    .map((line) => line.trim());
  if (!avds.includes(ANDROID_DEVICE)) {
    items.push({
      what: `the emulator ${ANDROID_DEVICE}, a Pixel 7 on Android ${ANDROID_API} that only screen-video uses, so the emulators and phones of your own stay as they are`,
      size: "about 2 GB once it has started, growing with use up to 8 GB",
      install: () => tool(avdmanager, ["create", "avd", "-n", ANDROID_DEVICE, "-k", image, "-d", "pixel_7"], { input: "no\n", timeout: 300_000 }),
    });
  }
  return { items };
}

const PLANS = { mac: macPlan, ios: iosPlan, android: androidPlan };
const NAMES = { mac: "macOS", ios: "iOS Simulator", android: "Android emulator" };

/**
 * Runs `setup <system>`. `runtimeMissing` adds Playwright and ffmpeg to the list, which
 * `screen-video.sh` installs before this when `yes`.
 */
export function setup(system, { yes = false, runtimeMissing = false, say }) {
  const plan = PLANS[system];
  if (plan === undefined) throw new Error("setup takes mac, ios, or android: setup mac | setup ios | setup android, each with --yes to install");
  const { items, note, after } = plan();
  const listed = [...(runtimeMissing && !yes ? [{ what: "Playwright, its headless browser, and ffmpeg, which every flow uses", size: "about 250 MB" }] : []), ...items];
  if (!yes) {
    if (listed.length === 0) say(`Everything setup ${system} installs for ${NAMES[system]} app flows is already there.`);
    else {
      say(`setup ${system} --yes installs these for ${NAMES[system]} app flows:`);
      for (const item of listed) say(`  - ${item.what} (${item.size})`);
    }
    if (note !== undefined) say(note);
    if (listed.length > 0) say(`Nothing was installed. Run setup ${system} --yes to install them.`);
    return;
  }
  for (const item of items) {
    say(`Installing ${item.what} (${item.size})`);
    item.install();
  }
  after?.();
  say(`Ready to record ${NAMES[system]} app flows.`);
}
