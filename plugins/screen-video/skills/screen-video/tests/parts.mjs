// Checks for logging in to an outside service and for parts added to a recording later, run from
// checks.mjs after its own checks, or on their own with `node parts.mjs`.
//
// Two sites are served on this machine: the app on 127.0.0.1 and an "outside service" on localhost,
// a different host, each with a page that sets a login cookie. Flows are written into a throwaway
// project and the data folder is a throwaway folder, so no real site, account, or video is touched.

import { spawn, spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { createServer } from "node:http";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";

const page = (title, body) => `<!doctype html><title>${title}</title><body style="font:20px system-ui;padding:40px">${body}</body>`;
const signedIn = (req, name) => (req.headers.cookie ?? "").split(/;\s*/).includes(`${name}=ok`);

export async function partsChecks({ check }) {
  const HERE = import.meta.dirname;
  const SKILL = join(HERE, "..");
  const SCRIPT = join(SKILL, "scripts", "screen-video.sh");
  const NODE_DIR = process.env.SCREEN_VIDEO_TEST_NODE_DIR || join(homedir(), ".local", "share", "screen-video", "node");
  const T = mkdtempSync(join(tmpdir(), "screen-video-parts-"));
  const DATA = join(T, "data");
  const PROJECT = join(T, "project");
  const FLOWS = join(PROJECT, ".screen-video", "flows");
  mkdirSync(FLOWS, { recursive: true });

  // The app: a page with a button, and a login page that sets a cookie
  const app = { requests: 0 };
  const appServer = createServer((req, res) => {
    app.requests++;
    const url = new URL(req.url, "http://127.0.0.1");
    res.setHeader("content-type", "text/html; charset=utf-8");
    if (url.pathname === "/login") {
      res.statusCode = 302;
      res.setHeader("set-cookie", "app=ok; Path=/; HttpOnly");
      res.setHeader("location", "/account");
      return res.end();
    }
    if (url.pathname === "/account") return res.end(page("Account", signedIn(req, "app") ? "<h1>Signed in to the app</h1>" : "<h1>Please log in</h1>"));
    if (url.pathname === "/") {
      return res.end(
        page(
          "Counter",
          '<h1>Counter</h1><p id="n">0</p><button type="button" onclick="document.getElementById(\'n\').textContent=Number(document.getElementById(\'n\').textContent)+1">Press</button>',
        ),
      );
    }
    res.statusCode = 404;
    res.end("not found");
  });
  // The outside service: a dashboard that shows its records only after its own login
  const outside = { requests: 0 };
  const outsideServer = createServer((req, res) => {
    outside.requests++;
    const url = new URL(req.url, "http://localhost");
    res.setHeader("content-type", "text/html; charset=utf-8");
    if (url.pathname === "/login") {
      res.statusCode = 302;
      res.setHeader("set-cookie", "outside=ok; Path=/; HttpOnly");
      res.setHeader("location", "/dashboard");
      return res.end();
    }
    if (url.pathname === "/dashboard") {
      return res.end(page("Dashboard", signedIn(req, "outside") ? '<h1>Records</h1><button type="button">Open the record</button>' : "<h1>Sign in to the dashboard</h1>"));
    }
    res.statusCode = 404;
    res.end("not found");
  });
  await new Promise((resolve) => appServer.listen(0, "127.0.0.1", resolve));
  await new Promise((resolve) => outsideServer.listen(0, "localhost", resolve));
  const APP = `http://127.0.0.1:${appServer.address().port}`;
  const OUTSIDE = `http://localhost:${outsideServer.address().port}`;

  function run(args, { env = {}, timeout = 600_000 } = {}) {
    return new Promise((resolve) => {
      const child = spawn("bash", [SCRIPT, ...args], { cwd: PROJECT, env: { ...process.env, SCREEN_VIDEO_HOME: DATA, SCREEN_VIDEO_NODE_DIR: NODE_DIR, ...env } });
      let all = "";
      child.stdout.on("data", (chunk) => (all += chunk));
      child.stderr.on("data", (chunk) => (all += chunk));
      const timer = setTimeout(() => child.kill("SIGKILL"), timeout);
      child.on("close", (status) => {
        clearTimeout(timer);
        resolve({ status, all });
      });
    });
  }
  // The login pages here redirect at once, so a login that is still waiting after 90 seconds opened
  // the wrong page; stopping it keeps a broken login from holding the run for its 15 minutes
  const headless = { env: { SCREEN_VIDEO_HEADLESS: "1" }, timeout: 90_000 };
  const last = (r) => r.all.trim().split("\n").at(-1);
  function flow(name, body) {
    const file = join(FLOWS, `${name}.json`);
    writeFileSync(file, `${JSON.stringify({ version: 1, name, url: APP, ...body }, null, 2)}\n`);
    return file;
  }
  const sessionsDir = join(DATA, "sessions");
  const sessionOf = (session) => (existsSync(sessionsDir) ? readdirSync(sessionsDir).find((name) => name.endsWith(`--${session}.json`)) : undefined);
  const folderOf = (name) => {
    const project = existsSync(DATA) ? readdirSync(DATA).find((entry) => existsSync(join(DATA, entry, name))) : undefined;
    return project === undefined ? join(DATA, "missing", name) : join(DATA, project, name);
  };
  const fingerprints = (dir) =>
    Object.fromEntries(
      readdirSync(dir, { recursive: true })
        .map((name) => join(dir, String(name)))
        .filter((file) => statSync(file).isFile())
        .map((file) => [file, createHash("sha256").update(readFileSync(file)).digest("hex")]),
    );
  const readJson = (file) => JSON.parse(readFileSync(file, "utf8"));
  // The ffmpeg the skill uses, read once from `doctor`, for reading the length of a video
  let FFMPEG = "ffmpeg";
  try {
    FFMPEG = JSON.parse(last(await run(["doctor", "--json"]))).ffmpeg.path ?? "ffmpeg";
  } catch {
    FFMPEG = "ffmpeg";
  }
  const lengthOf = (file) => {
    const banner = spawnSync(FFMPEG, ["-hide_banner", "-i", file], { encoding: "utf8" }).stderr ?? "";
    const r = /Duration: (\d+):(\d+):([\d.]+)/.exec(banner);
    return r === null ? Number.NaN : Number(r[1]) * 3600 + Number(r[2]) * 60 + Number(r[3]);
  };

  // The flow a part is added to, and the part: the outside dashboard after the first press
  const BASE = flow("counter", {
    title: "Press the counter",
    steps: [
      { do: "open", url: "/", caption: "Open the counter" },
      { do: "click", target: { role: "button", name: "Press" }, caption: "Press once" },
      { do: "hold", seconds: 1 },
      { do: "click", target: { role: "button", name: "Press" }, caption: "Press twice" },
    ],
  });
  const PART = flow("counter-check", {
    url: OUTSIDE,
    addsTo: { flow: "counter", after: 2 },
    login: { session: "dashboard", forget: true },
    steps: [
      { do: "open", url: "/dashboard", caption: "Open the outside dashboard" },
      { do: "hold", seconds: 1 },
    ],
  });

  try {
    await check("the skill plans where a result is checked and how to add a part left out", () => {
      const skill = readFileSync(join(SKILL, "SKILL.md"), "utf8");
      const format = readFileSync(join(SKILL, "references", "flow-format.md"), "utf8");
      if (!/where the result/i.test(skill)) return "SKILL.md does not ask where the result of the main action can be checked";
      for (const word of ["addsTo", "login.forget", "--start", "logout"]) {
        if (!skill.includes(word)) return `SKILL.md does not say how to use ${word}`;
      }
      for (const word of ["addsTo", "forget"]) {
        if (!format.includes(word)) return `the flow format does not describe ${word}`;
      }
      return true;
    });

    await check("check refuses a bad addsTo or login.forget", async () => {
      const cases = [
        [{ login: { forget: true }, steps: [{ do: "open", url: "/" }] }, "login.forget"],
        [{ addsTo: { flow: "Not a name" }, steps: [{ do: "open", url: "/" }] }, "addsTo.flow"],
        [{ addsTo: { flow: "counter", after: 0 }, steps: [{ do: "open", url: "/" }] }, "addsTo.after"],
        [{ addsTo: { flow: "counter", after: 1.5 }, steps: [{ do: "open", url: "/" }] }, "addsTo.after"],
      ];
      for (const [body, word] of cases) {
        const r = await run(["check", flow("bad-part", body)]);
        if (r.status === 0) return `check passed a flow with ${JSON.stringify(body.login ?? body.addsTo)}`;
        if (!r.all.includes(word)) return `check refused ${JSON.stringify(body.login ?? body.addsTo)} without naming ${word}: ${last(r)}`;
      }
      const good = await run(["check", flow("good-part", { addsTo: { flow: "counter" }, steps: [{ do: "open", url: "/" }] })]);
      if (good.status !== 0) return `check refused an addsTo without after: ${last(good)}`;
      if (!/adds to counter/.test(good.all)) return "check does not say which flow the part is added to";
      return true;
    });

    await check("login opens an address on another site and keeps the logins already saved", async () => {
      const file = flow("two-logins", { login: { session: "two" }, steps: [{ do: "open", url: "/" }] });
      const first = await run(["login", file, "--until", "/account", "--start", `${APP}/login`], headless);
      if (first.status !== 0) return `the first login exited ${first.status}: ${last(first)}`;
      const second = await run(["login", file, "--until", "/dashboard", "--start", `${OUTSIDE}/login`], headless);
      if (second.status !== 0) return `the login to the outside service exited ${second.status}: ${last(second)}`;
      const saved = sessionOf("two");
      if (saved === undefined) return "no login was saved";
      const cookies = readJson(join(sessionsDir, saved)).cookies.map((cookie) => `${cookie.name}@${cookie.domain}`);
      if (!cookies.includes("app@127.0.0.1")) return `the first login was lost: ${cookies.join(", ")}`;
      if (!cookies.includes("outside@localhost")) return `the outside login was not saved: ${cookies.join(", ")}`;
      return true;
    });

    await check("logout removes the saved login", async () => {
      const file = join(FLOWS, "two-logins.json");
      if (sessionOf("two") === undefined) return "there is no saved login to remove";
      const r = await run(["logout", file]);
      if (r.status !== 0) return `logout exited ${r.status}: ${last(r)}`;
      if (sessionOf("two") !== undefined) return "the saved login is still there";
      if (!/Removed the saved login "two"/.test(r.all)) return `logout did not say it removed the login: ${last(r)}`;
      const again = await run(["logout", file]);
      if (again.status !== 0) return `logout without a saved login exited ${again.status}`;
      if (!/No saved login "two"/.test(again.all)) return `logout without a saved login said: ${last(again)}`;
      return true;
    });

    await check("record removes a login marked forget when it ends, even after a failed step", async () => {
      const file = flow("forget-on-failure", {
        url: OUTSIDE,
        login: { session: "brief", forget: true },
        steps: [
          { do: "open", url: "/dashboard" },
          { do: "click", target: { role: "button", name: "A button that is not there" }, timeout: 2 },
        ],
      });
      const login = await run(["login", file, "--until", "/dashboard", "--start", `${OUTSIDE}/login`], headless);
      if (login.status !== 0 || sessionOf("brief") === undefined) return `the login was not saved: ${last(login)}`;
      const r = await run(["record", file]);
      if (r.status === 0) return "the recording passed a step whose target is not there";
      if (sessionOf("brief") !== undefined) return "the login is still saved after the failed recording";
      if (!/Removed the saved login "brief"/.test(r.all)) return "record did not say it removed the login";
      return true;
    });

    let baseRecorded = false;
    await check("a flow without addsTo records and remakes as before", async () => {
      const recorded = await run(["record", BASE]);
      if (recorded.status !== 0) return `record exited ${recorded.status}: ${last(recorded)}`;
      const dir = folderOf("counter");
      if (existsSync(join(dir, "part"))) return "a flow without addsTo got a part/ folder";
      const steps = readJson(join(dir, "timeline.json")).steps;
      if (steps.length !== 4) return `the recording holds ${steps.length} steps`;
      const remade = await run(["remake", BASE]);
      if (remade.status !== 0) return `remake exited ${remade.status}: ${last(remade)}`;
      if (!existsSync(join(dir, "edited.mp4"))) return "remake wrote no edited.mp4";
      baseRecorded = true;
      return true;
    });

    let baseBefore;
    let partRun;
    let appRequestsDuringPart = 0;
    await check("a part added later is recorded alone and joined after the step it names", async () => {
      if (!baseRecorded) {
        const base = await run(["record", BASE]);
        if (base.status !== 0) return `the recording of the other flow exited ${base.status}: ${last(base)}`;
      }
      const baseDir = folderOf("counter");
      baseBefore = fingerprints(baseDir);
      const login = await run(["login", PART, "--until", "/dashboard", "--start", `${OUTSIDE}/login`], headless);
      if (login.status !== 0) return `the login to the outside service exited ${login.status}: ${last(login)}`;
      const appBefore = app.requests;
      partRun = await run(["record", PART]);
      appRequestsDuringPart = app.requests - appBefore;
      if (partRun.status !== 0) return `the recording of the part exited ${partRun.status}: ${last(partRun)}`;
      const dir = folderOf("counter-check");
      for (const name of ["part/raw.mp4", "part/timeline.json", "raw.mp4", "timeline.json", "edited.mp4", "captioned.mp4"]) {
        if (!existsSync(join(dir, name))) return `the part's folder has no ${name}`;
      }
      if (appRequestsDuringPart !== 0) return `the part's recording opened the other flow's site ${appRequestsDuringPart} times`;
      const after = fingerprints(baseDir);
      const changed = Object.keys(baseBefore).filter((file) => after[file] !== baseBefore[file]);
      if (changed.length > 0 || Object.keys(after).length !== Object.keys(baseBefore).length) return `the other flow's folder changed: ${changed.join(", ") || "files were added or removed"}`;
      const joined = readJson(join(dir, "timeline.json"));
      // A step without a caption is recorded with an empty one
      const captions = joined.steps.map((step) => step.caption || "-").join(" | ");
      if (captions !== "Open the counter | Press once | Open the outside dashboard | - | - | Press twice") return `the joined steps are ${captions}`;
      if (joined.steps.map((step) => step.step).join(",") !== "1,2,3,4,5,6") return `the joined steps are numbered ${joined.steps.map((step) => step.step).join(",")}`;
      const times = joined.steps.map((step) => step.t);
      if (times.some((t, i) => i > 0 && t < times[i - 1])) return `the joined times go back: ${times.join(", ")}`;
      const baseTimeline = readJson(join(baseDir, "timeline.json"));
      const partTimeline = readJson(join(dir, "part", "timeline.json"));
      if (joined.steps[2].t < baseTimeline.steps[1].end) return "the part starts before the step it comes after ends";
      const got = lengthOf(join(dir, "raw.mp4"));
      if (Math.abs(joined.duration - got) > 0.2) return `timeline.json says ${joined.duration}s for a ${got.toFixed(2)}s recording`;
      if (partTimeline.steps.length !== 2) return `the part's own timeline holds ${partTimeline.steps.length} steps`;
      if (joined.joined?.flow !== "counter" || joined.joined?.after !== 2) return `timeline.json does not say what it joins: ${JSON.stringify(joined.joined)}`;
      if (sessionOf("dashboard") !== undefined) return "the login marked forget is still saved after the recording";
      return true;
    });

    // The part's own recording begins with the browser starting before its first step; a recording's
    // edit never shows that, so the joined recording must not either
    await check("an added part starts at its first step, without the browser's start before it", async () => {
      if (partRun?.status !== 0) return "the part was not recorded";
      const dir = folderOf("counter-check");
      const baseDir = folderOf("counter");
      const joined = readJson(join(dir, "timeline.json"));
      const baseTimeline = readJson(join(baseDir, "timeline.json"));
      const partTimeline = readJson(join(dir, "part", "timeline.json"));
      const lead = partTimeline.steps[0].from ?? partTimeline.steps[0].t;
      if (!(lead > 0.3)) return `the part's recording has no start before its first step to leave out (${lead}s)`;
      const cut = baseTimeline.steps[2].from ?? baseTimeline.steps[2].t;
      const first = joined.steps[2].from ?? joined.steps[2].t;
      if (!(first - cut >= 0 && first - cut <= 0.1)) return `the part's first step begins ${(first - cut).toFixed(2)}s after the cut`;
      const expected = lengthOf(join(baseDir, "raw.mp4")) + lengthOf(join(dir, "part", "raw.mp4")) - (lead - 0.05);
      const got = lengthOf(join(dir, "raw.mp4"));
      if (!(Math.abs(got - expected) < 0.5)) return `the joined recording is ${got.toFixed(2)}s, not ${expected.toFixed(2)}s`;
      return true;
    });

    await check("remake of an added part joins it again", async () => {
      if (partRun?.status !== 0) return "the part was not recorded";
      const dir = folderOf("counter-check");
      const before = readJson(join(dir, "timeline.json"));
      const r = await run(["remake", PART]);
      if (r.status !== 0) return `remake exited ${r.status}: ${last(r)}`;
      if (!existsSync(join(dir, "edited.mp4"))) return "remake wrote no edited.mp4";
      const again = readJson(join(dir, "timeline.json"));
      if (JSON.stringify(again.steps) !== JSON.stringify(before.steps)) return "remake joined the steps differently";
      return true;
    });

    await check("an added part needs the other flow's recording and one of its steps", async () => {
      const outsideBefore = outside.requests;
      const late = await run(["record", flow("late-part", { url: OUTSIDE, addsTo: { flow: "counter", after: 9 }, steps: [{ do: "open", url: "/dashboard" }] })]);
      if (late.status === 0) return "record joined a part after a step the other flow does not have";
      if (!/step 9/.test(late.all) || !/4 steps/.test(late.all)) return `record refused the late part without naming the step: ${last(late)}`;
      flow("never-recorded", { steps: [{ do: "open", url: "/" }] });
      const orphan = await run(["record", flow("orphan-part", { url: OUTSIDE, addsTo: { flow: "never-recorded" }, steps: [{ do: "open", url: "/dashboard" }] })]);
      if (orphan.status === 0) return "record joined a part to a flow that was never recorded";
      if (!/never-recorded/.test(orphan.all) || !/no recording/i.test(orphan.all)) return `record refused the part without saying the other flow has no recording: ${last(orphan)}`;
      const missing = await run(["record", flow("lost-part", { url: OUTSIDE, addsTo: { flow: "no-such-flow" }, steps: [{ do: "open", url: "/dashboard" }] })]);
      if (missing.status === 0 || !/no-such-flow/.test(missing.all)) return `record did not refuse a part of a flow file that does not exist: ${last(missing)}`;
      if (outside.requests !== outsideBefore) return "record opened the outside service before refusing";
      return true;
    });
  } finally {
    appServer.close();
    outsideServer.close();
  }
}

// Run on their own: `node parts.mjs`
if (import.meta.filename === process.argv[1]) {
  let passed = 0;
  let failed = 0;
  const check = async (name, fn) => {
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
  };
  await partsChecks({ check });
  process.stdout.write(`${passed} passed, ${failed} failed (${passed + failed} ran)\n`);
  process.exit(failed === 0 ? 0 : 1);
}
