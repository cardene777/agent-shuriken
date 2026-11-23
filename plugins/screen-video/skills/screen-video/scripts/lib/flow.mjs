/**
 * Flow files: what a video shows, in order. The format is described in `references/flow-format.md`.
 *
 * | Function | What it does |
 * |---|---|
 * | `loadFlow` | Reads a flow file and returns the flow and its problems, each with the step it is about |
 * | `markedSteps` | The steps marked as sending something or paying, with their notes |
 * | `describeTarget` | A short text naming a target, such as `button "Save"` |
 * | `locate` | The Playwright locator for a target, inside the iframe that holds it when the target names one |
 * | `readLogin` | The login values and saved session a flow names. The values are never printed |
 * | `languageOf` | The language the flow is narrated and paced in: its `language`, or Japanese when a caption is written in Japanese |
 * | `parseEnvFile` | The `KEY=value` lines of an env file, for logins and the keys of cloud voices |
 */
import { existsSync, readFileSync } from "node:fs";
import { isAbsolute, join } from "node:path";

import { sessionFile } from "./runtime.mjs";

export const ACTIONS = ["open", "click", "fill", "select", "key", "wait", "hold", "swipe"];
export const OUTPUTS = ["16:9", "9:16", "gif"];
/** What an app flow records: a macOS app, an app on the iOS Simulator, or an app on the Android emulator. */
export const PLATFORMS = ["mac", "ios", "android"];
const APP_LOCATORS = ["role", "label", "text", "testId", "point"];
/** Targets a browser has and an app does not: CSS, a field's placeholder, and iframes. */
const BROWSER_ONLY = ["css", "placeholder", "frame"];
const BUNDLE_ID = /^[A-Za-z][A-Za-z0-9_-]*(\.[A-Za-z0-9_-]+)+$/;
/** Voice engines: `local` picks Kokoro for English and AivisSpeech for Japanese; `kokoro`, `aivisspeech`, and `voicevox` run on this machine, and the others are cloud services. */
export const ENGINES = ["local", "kokoro", "aivisspeech", "voicevox", "openai", "elevenlabs", "azure", "google"];
export const LANGUAGES = ["en", "ja"];
const LOCATORS = ["role", "label", "placeholder", "text", "testId", "css"];
const EFFECTS = ["sends", "pays"];
const ENV_NAME = /^[A-Za-z_][A-Za-z0-9_]*$/;
/** Field names that hold a secret. Typing a literal value into one is refused. */
const SECRET_FIELD = /pass(word|code|phrase)?|pwd|secret|token|api[ _-]?key|\botp\b|one[ -]?time|\bpin\b|security code|パスワード|暗証|認証コード/i;

const isObject = (value) => value !== null && typeof value === "object" && !Array.isArray(value);
const isText = (value) => typeof value === "string" && value.trim() !== "";
const isSeconds = (value) => typeof value === "number" && Number.isFinite(value) && value > 0;

/** A point `[x, y]` of an app's own coordinates. */
const isPoint = (value) => Array.isArray(value) && value.length === 2 && value.every((v) => typeof v === "number" && Number.isFinite(v) && v >= 0);

/** What is wrong with a target, or undefined. `platform` is the app flow's platform, undefined in a browser flow. */
function targetProblem(target, platform) {
  if (platform === undefined) {
    if (!isObject(target)) return "needs a target (role, label, placeholder, text, testId, or css)";
    if (target.point !== undefined) return "has a point target, which only an app flow takes";
    const named = LOCATORS.filter((key) => target[key] !== undefined);
    if (named.length !== 1) return `needs exactly one of role, label, placeholder, text, testId, or css in its target, not ${named.length}`;
    if (!isText(target[named[0]])) return `has an empty ${named[0]} in its target`;
  } else {
    if (!isObject(target)) return "needs a target (role, label, text, testId, or point)";
    const browser = BROWSER_ONLY.find((key) => target[key] !== undefined);
    if (browser !== undefined) return `has a ${browser} target, which an app flow cannot use (use role, label, text, testId, or point)`;
    const named = APP_LOCATORS.filter((key) => target[key] !== undefined);
    if (named.length !== 1) return `needs exactly one of role, label, text, testId, or point in its target, not ${named.length}`;
    if (named[0] === "point") {
      if (!isPoint(target.point)) return "has a point that is not [x, y] in the app's own coordinates";
    } else if (!isText(target[named[0]])) return `has an empty ${named[0]} in its target`;
  }
  if (target.name !== undefined && !isText(target.name)) return "has an empty name in its target";
  if (target.nth !== undefined && !(Number.isInteger(target.nth) && target.nth >= 0)) return "has a target nth that is not a whole number";
  if (target.frame !== undefined && !isText(target.frame)) return "has an empty frame in its target";
  return undefined;
}

/** Problems of a step that a browser can run and an app cannot, or that only a phone can run. */
function appStepProblems(step, platform) {
  if (platform === undefined) return step.do === "swipe" ? ["has a swipe step, which only a phone app flow takes"] : [];
  switch (step.do) {
    case "open":
      return step.url === undefined ? [] : ["has a url, but an app flow's open brings the app up and takes no url"];
    case "select":
      return ["has a select step, which an app flow cannot run (open the choices and pick one with two click steps)"];
    case "swipe":
      return platform === "mac" ? ["has a swipe step, which a macOS app flow cannot run (swipe is for phones)"] : [];
    case "wait": {
      const kind = isObject(step.until) ? ["url", "settled"].find((key) => step.until[key] !== undefined) : undefined;
      return kind === undefined ? [] : [`waits on ${kind}, which an app flow cannot (wait on text, visible, hidden, or enabled)`];
    }
    default:
      return [];
  }
}

function stepProblems(step, platform) {
  if (!isObject(step)) return ["is not an object"];
  if (!ACTIONS.includes(step.do)) return [`has an unknown action "${String(step.do)}" (use one of ${ACTIONS.join(", ")})`];
  const app = appStepProblems(step, platform);
  if (app.length > 0) return app;
  const problems = [];
  if (step.caption !== undefined && typeof step.caption !== "string") problems.push("has a caption that is not text");
  if (step.say !== undefined && !isText(step.say)) problems.push("has a say that is not text to read aloud");
  if (step.chapter !== undefined && !isText(step.chapter)) problems.push("has an empty chapter");
  if (step.timeout !== undefined && !isSeconds(step.timeout)) problems.push("has a timeout that is not a positive number of seconds");
  if (step.effect !== undefined) {
    if (!isObject(step.effect) || !EFFECTS.includes(step.effect.kind)) problems.push('has an effect whose kind is not "sends" or "pays"');
    else if (step.effect.note !== undefined && typeof step.effect.note !== "string") problems.push("has an effect note that is not text");
  }
  switch (step.do) {
    case "open":
      if (platform === undefined && !isText(step.url)) problems.push("needs a url");
      break;
    case "click":
    case "fill":
    case "select": {
      const problem = targetProblem(step.target, platform);
      if (problem !== undefined) problems.push(problem);
      if (step.do === "fill") {
        const hasText = step.text !== undefined;
        const hasEnv = step.env !== undefined;
        if (hasText === hasEnv) problems.push('needs either "text" or "env" to type');
        if (hasText && typeof step.text !== "string") problems.push("has text that is not text");
        if (hasEnv && !(typeof step.env === "string" && ENV_NAME.test(step.env))) problems.push("has an env that is not a variable name");
        if (hasText && problem === undefined && SECRET_FIELD.test(Object.values(step.target).join(" "))) {
          problems.push('types a secret into a password field as plain text; put the value in an env variable and use "env"');
        }
      }
      if (step.do === "select" && !isText(step.value)) problems.push("needs a value to choose");
      break;
    }
    case "key":
      if (!isText(step.key)) problems.push("needs a key, such as Enter");
      break;
    case "wait": {
      const until = step.until;
      if (!isObject(until)) {
        problems.push("needs until (text, url, visible, enabled, hidden, or settled)");
        break;
      }
      const kinds = ["text", "url", "visible", "enabled", "hidden", "settled"].filter((key) => until[key] !== undefined);
      if (kinds.length !== 1) problems.push("needs exactly one of text, url, visible, enabled, hidden, or settled in until");
      else if (["text", "url"].includes(kinds[0]) && !isText(until[kinds[0]])) problems.push(`has an empty ${kinds[0]} in until`);
      else if (kinds[0] === "settled" && !(isSeconds(until.settled) && until.settled <= 30)) problems.push("has an until.settled that is not a number of seconds from 0 to 30");
      else if (["visible", "enabled", "hidden"].includes(kinds[0])) {
        const problem = targetProblem(until[kinds[0]], platform);
        if (problem !== undefined) problems.push(problem.replace("its target", `until.${kinds[0]}`));
      }
      break;
    }
    case "hold":
      if (!isSeconds(step.seconds)) problems.push("needs seconds, a positive number");
      break;
    case "swipe":
      if (!isPoint(step.from) || !isPoint(step.to)) problems.push("needs from and to, each [x, y] in the app's own coordinates");
      if (step.seconds !== undefined && !(isSeconds(step.seconds) && step.seconds <= 5)) problems.push("has seconds that are not a number above 0, up to 5");
      break;
  }
  return problems;
}

/** Problems with an app flow's `app`, `url`, `login`, `addsTo`, and `mask`, and the flow's first step. */
function appProblems(flow, top) {
  const app = flow.app;
  if (flow.url !== undefined) top("an app flow has no url: name what it records with either url or app");
  if (!isObject(app)) return top('app must be an object such as {"platform": "mac", "id": "com.example.notes"}');
  if (!PLATFORMS.includes(app.platform)) top(`app.platform must be one of ${PLATFORMS.join(", ")}`);
  if (!(typeof app.id === "string" && BUNDLE_ID.test(app.id))) top("app.id must be the app's bundle id or package name, such as com.example.notes");
  if (app.install !== undefined) {
    if (app.platform === "mac") top("app.install is for phone apps; a macOS app is launched as it is installed on this Mac");
    else {
      const kind = app.platform === "ios" ? ".app" : ".apk";
      const inside = typeof app.install === "string" && !isAbsolute(app.install) && !app.install.split(/[\\/]/).includes("..");
      if (!inside || !app.install.endsWith(kind)) top(`app.install must be a path inside the project to the ${kind} build to install`);
    }
  }
  if (flow.login !== undefined) top("an app flow cannot use login; sign in with the flow's own steps");
  if (flow.addsTo !== undefined) top("addsTo joins parts of browser flows; an app flow records all its steps itself");
  const platform = PLATFORMS.includes(app.platform) ? app.platform : "mac";
  const maskOk = (m) => isObject(m) && (isText(m.text) || (isObject(m.target) && targetProblem(m.target, platform) === undefined) || (Array.isArray(m.rect) && m.rect.length === 4 && isPoint(m.rect.slice(0, 2)) && isPoint(m.rect.slice(2)) && m.rect[2] > 0 && m.rect[3] > 0));
  if (flow.mask !== undefined && !(Array.isArray(flow.mask) && flow.mask.every(maskOk))) top('mask must list objects with "target" (a part), "text", or "rect" ([x, y, width, height])');
  if (Array.isArray(flow.steps) && isObject(flow.steps[0]) && flow.steps[0].do !== "open") top("an app flow starts with an open step, which brings the app up");
}

/** Problems with the flow as a whole and with each step. `step` is 0 for the flow itself. */
export function validate(flow) {
  const problems = [];
  const top = (message) => problems.push({ step: 0, message });
  if (!isObject(flow)) return [{ step: 0, message: "the flow is not a JSON object" }];
  if (flow.version !== 1) top("version must be 1");
  if (!(typeof flow.name === "string" && /^[a-z0-9][a-z0-9-]*$/.test(flow.name))) top("name must be lowercase letters, digits, and hyphens");
  const app = flow.app !== undefined;
  if (app) appProblems(flow, top);
  else {
    try {
      const url = new URL(flow.url);
      if (!["http:", "https:"].includes(url.protocol)) top("url must start with http:// or https://");
    } catch {
      top("url must be the address the flow starts from");
    }
    if (flow.mask !== undefined && !(Array.isArray(flow.mask) && flow.mask.every((m) => isObject(m) && (isText(m.css) || isText(m.text))))) {
      top('mask must list objects with "css" or "text"');
    }
  }
  if (flow.outputs !== undefined && !(Array.isArray(flow.outputs) && flow.outputs.length > 0 && flow.outputs.every((o) => OUTPUTS.includes(o)))) {
    top(`outputs must list some of ${OUTPUTS.join(", ")}`);
  }
  if (flow.login !== undefined && !app) {
    const login = flow.login;
    if (!isObject(login)) top("login must be an object");
    else {
      if (login.envFile !== undefined && !isText(login.envFile)) top("login.envFile must be a path inside the project");
      if (login.basic !== undefined && !(isObject(login.basic) && ENV_NAME.test(login.basic.username ?? "") && ENV_NAME.test(login.basic.password ?? ""))) {
        top("login.basic must name the env variables that hold the username and the password");
      }
      if (login.session !== undefined && !(typeof login.session === "string" && /^[a-z0-9][a-z0-9-]*$/.test(login.session))) {
        top("login.session must be lowercase letters, digits, and hyphens");
      }
      if (login.start !== undefined && !isText(login.start)) top("login.start must be the page where the login begins");
      if (login.forget !== undefined && typeof login.forget !== "boolean") top("login.forget must be true or false");
      if (login.forget === true && login.session === undefined) top("login.forget needs login.session, the saved login it removes when record ends");
    }
  }
  if (flow.addsTo !== undefined && !app) {
    const adds = flow.addsTo;
    if (!isObject(adds)) top("addsTo must be an object naming the flow the part is added to and the step it comes after");
    else {
      if (!(typeof adds.flow === "string" && /^[a-z0-9][a-z0-9-]*$/.test(adds.flow))) top("addsTo.flow must be the name of the flow the part is added to");
      else if (adds.flow === flow.name) top("addsTo.flow must name another flow");
      if (adds.after !== undefined && !(Number.isInteger(adds.after) && adds.after >= 1)) top("addsTo.after must be a step number of 1 or more");
    }
  }
  if (flow.title !== undefined && !isText(flow.title)) top("title must be text");
  if (flow.theme !== undefined && !(typeof flow.theme === "string" && /^[a-z0-9][a-z0-9-]*$/.test(flow.theme))) top("theme must be lowercase letters, digits, and hyphens");
  if (flow.language !== undefined && !LANGUAGES.includes(flow.language)) top(`language must be one of ${LANGUAGES.join(", ")}`);
  if (flow.voice !== undefined && flow.voice !== false) {
    const voice = flow.voice;
    if (!isObject(voice) || !ENGINES.includes(voice.engine)) top(`voice must be false or an object whose engine is one of ${ENGINES.join(", ")}`);
    else {
      if (voice.voice !== undefined && !isText(voice.voice)) top("voice.voice must name a voice of the engine");
      if (voice.envFile !== undefined && !isText(voice.envFile)) top("voice.envFile must be a path inside the project");
      if (voice.terms !== undefined && voice.terms !== "agreed") top('voice.terms must be "agreed" once the user has agreed to the VOICEVOX terms');
      if (voice.keyEnv !== undefined && !(typeof voice.keyEnv === "string" && ENV_NAME.test(voice.keyEnv))) top("voice.keyEnv must be an env variable name");
    }
  }
  if (flow.music !== undefined && typeof flow.music !== "boolean") {
    const music = flow.music;
    if (!isObject(music) || !isText(music.file)) top('music must be true, false, or {"file": a sound file inside the project}');
    else if (music.volume !== undefined && !(typeof music.volume === "number" && music.volume > 0 && music.volume <= 2)) top("music.volume must be a number above 0, up to 2");
  }
  if (flow.sounds !== undefined && typeof flow.sounds !== "boolean") top("sounds must be true or false");
  if (flow.end !== undefined && flow.end !== false) {
    const end = flow.end;
    if (!isObject(end)) top("end must be false or an object with title, url, and note");
    else for (const key of ["title", "url", "note"]) if (end[key] !== undefined && !isText(end[key])) top(`end.${key} must be text`);
  }
  if (flow.seconds !== undefined && !isSeconds(flow.seconds)) top("seconds must be the planned length, a positive number of seconds");
  if (!Array.isArray(flow.steps) || flow.steps.length === 0) top("steps must list at least one step");
  else {
    const platform = app ? (PLATFORMS.includes(flow.app?.platform) ? flow.app.platform : "mac") : undefined;
    flow.steps.forEach((step, index) => stepProblems(step, platform).forEach((message) => problems.push({ step: index + 1, message })));
  }
  return problems;
}

export function loadFlow(file) {
  let flow;
  try {
    flow = JSON.parse(readFileSync(file, "utf8"));
  } catch (error) {
    return { flow: undefined, problems: [{ step: 0, message: `cannot read ${file} as JSON (${error instanceof Error ? error.message : error})` }] };
  }
  return { flow: { outputs: ["16:9"], mask: [], ...flow }, problems: validate(flow) };
}

const JAPANESE = /[\u3040-\u30ff\u3400-\u9fff\uff66-\uff9f]/u;

export function languageOf(flow) {
  if (flow.language !== undefined) return flow.language;
  const texts = [flow.title, ...flow.steps.flatMap((step) => [step.caption, step.say, step.chapter])];
  return texts.some((text) => typeof text === "string" && JAPANESE.test(text)) ? "ja" : "en";
}

export function markedSteps(flow) {
  return flow.steps
    .map((step, index) => ({ number: index + 1, step }))
    .filter(({ step }) => step.effect !== undefined)
    .map(({ number, step }) => ({ number, kind: step.effect.kind, note: step.effect.note ?? "", caption: step.caption ?? "" }));
}

export function describeTarget(target) {
  if (target.role !== undefined) return target.name === undefined ? target.role : `${target.role} "${target.name}"`;
  if (target.label !== undefined) return `field labelled "${target.label}"`;
  if (target.placeholder !== undefined) return `field with placeholder "${target.placeholder}"`;
  if (target.text !== undefined) return `text "${target.text}"`;
  if (target.testId !== undefined) return `test id "${target.testId}"`;
  if (target.point !== undefined) return `point (${target.point.join(", ")})`;
  return `element "${target.css}"`;
}

/** What a step does, in a few words, for the storyboard and for messages. */
export function describeStep(step) {
  switch (step.do) {
    case "open":
      return step.url === undefined ? "Open the app" : `Open ${step.url}`;
    case "swipe":
      return `Swipe from (${step.from.join(", ")}) to (${step.to.join(", ")})`;
    case "click":
      return `Click ${describeTarget(step.target)}`;
    case "fill":
      return step.env !== undefined ? `Type the value of ${step.env} into ${describeTarget(step.target)}` : `Type "${step.text}" into ${describeTarget(step.target)}`;
    case "select":
      return `Choose "${step.value}" in ${describeTarget(step.target)}`;
    case "key":
      return `Press ${step.key}`;
    case "wait": {
      const [kind, value] = Object.entries(step.until)[0];
      if (kind === "settled") return `Wait until the page stops changing for ${value}s`;
      return typeof value === "string" ? `Wait for ${kind} "${value}"` : `Wait until ${describeTarget(value)} is ${kind}`;
    }
    case "hold":
      return `Hold for ${step.seconds}s`;
    default:
      return String(step.do);
  }
}

/**
 * The locator for a target. A target in the page is returned at once, and Playwright waits for it
 * when it is used. A target that names `frame` is looked for in every iframe whose address holds that
 * text, nested ones too, until one of them holds it or `timeout` milliseconds pass: a payment form
 * loads after the page, and its host often adds several iframes of which only one holds the field.
 */
export async function locate(page, target, timeout) {
  if (target.frame === undefined) return locateIn(page, target);
  const until = Date.now() + timeout;
  for (;;) {
    for (const frame of page.frames()) {
      if (frame === page.mainFrame() || !frame.url().includes(target.frame)) continue;
      const locator = locateIn(frame, target);
      if ((await locator.count().catch(() => 0)) > 0) return locator;
    }
    if (Date.now() >= until) throw new Error(`no frame whose address holds "${target.frame}" shows ${describeTarget(target)} within ${Math.round(timeout / 1000)}s`);
    await page.waitForTimeout(250);
  }
}

function locateIn(scope, target) {
  const exact = target.exact !== false;
  let locator;
  if (target.role !== undefined) locator = scope.getByRole(target.role, target.name === undefined ? {} : { name: target.name, exact });
  else if (target.label !== undefined) locator = scope.getByLabel(target.label, { exact });
  else if (target.placeholder !== undefined) locator = scope.getByPlaceholder(target.placeholder, { exact });
  else if (target.text !== undefined) locator = scope.getByText(target.text, { exact });
  else if (target.testId !== undefined) locator = scope.getByTestId(target.testId);
  else locator = scope.locator(target.css);
  return locator.nth(target.nth ?? 0);
}

/** Reads `KEY=value` lines. Quotes around a value are removed. */
export function parseEnvFile(file) {
  const values = {};
  for (const line of readFileSync(file, "utf8").split(/\r?\n/)) {
    const match = /^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/.exec(line);
    if (match === null) continue;
    let value = match[2].trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) value = value.slice(1, -1);
    values[match[1]] = value;
  }
  return values;
}

/**
 * The values a flow's login and `env` fills need: from the env file the flow names (inside the
 * project), falling back to the environment. Returns a lookup that never prints a value.
 */
export function envLookup(flow, root) {
  let fromFile = {};
  const envFile = flow.login?.envFile;
  if (envFile !== undefined) {
    const path = join(root, envFile);
    if (!existsSync(path)) throw new Error(`the env file ${envFile} named by login.envFile does not exist in the project`);
    fromFile = parseEnvFile(path);
  }
  return (name) => {
    const value = fromFile[name] ?? process.env[name];
    if (value === undefined || value === "") throw new Error(`the env variable ${name} is empty or missing`);
    return value;
  };
}

/** HTTP credentials for basic auth and the saved session file, as Playwright takes them. */
export function readLogin(flow, root) {
  const login = flow.login ?? {};
  const out = {};
  if (login.basic !== undefined) {
    const env = envLookup(flow, root);
    out.credentials = { username: env(login.basic.username), password: env(login.basic.password), origin: new URL(flow.url).origin };
  }
  if (login.session !== undefined) {
    const file = sessionFile(root, login.session);
    if (!existsSync(file)) throw new Error(`no saved login "${login.session}" for this project. Run: screen-video.sh login <flow>`);
    out.storageState = file;
  }
  return out;
}
