/**
 * Flow files: what a video shows, in order. The format is described in `references/flow-format.md`.
 *
 * | Function | What it does |
 * |---|---|
 * | `loadFlow` | Reads a flow file and returns the flow and its problems, each with the step it is about |
 * | `markedSteps` | The steps marked as sending something or paying, with their notes |
 * | `describeTarget` | A short text naming a target, such as `button "Save"` |
 * | `locate` | The Playwright locator for a target, inside an iframe when the target names one |
 * | `readLogin` | The login values and saved session a flow names. The values are never printed |
 */
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

import { sessionFile } from "./runtime.mjs";

export const ACTIONS = ["open", "click", "fill", "select", "key", "wait", "hold"];
export const OUTPUTS = ["16:9", "9:16", "gif"];
const LOCATORS = ["role", "label", "placeholder", "text", "testId", "css"];
const EFFECTS = ["sends", "pays"];
const ENV_NAME = /^[A-Za-z_][A-Za-z0-9_]*$/;
/** Field names that hold a secret. Typing a literal value into one is refused. */
const SECRET_FIELD = /pass(word|code|phrase)?|pwd|secret|token|api[ _-]?key|\botp\b|one[ -]?time|\bpin\b|security code|パスワード|暗証|認証コード/i;

const isObject = (value) => value !== null && typeof value === "object" && !Array.isArray(value);
const isText = (value) => typeof value === "string" && value.trim() !== "";
const isSeconds = (value) => typeof value === "number" && Number.isFinite(value) && value > 0;

function targetProblem(target) {
  if (!isObject(target)) return "needs a target (role, label, placeholder, text, testId, or css)";
  const named = LOCATORS.filter((key) => target[key] !== undefined);
  if (named.length !== 1) return `needs exactly one of role, label, placeholder, text, testId, or css in its target, not ${named.length}`;
  if (!isText(target[named[0]])) return `has an empty ${named[0]} in its target`;
  if (target.name !== undefined && !isText(target.name)) return "has an empty name in its target";
  if (target.nth !== undefined && !(Number.isInteger(target.nth) && target.nth >= 0)) return "has a target nth that is not a whole number";
  if (target.frame !== undefined && !isText(target.frame)) return "has an empty frame in its target";
  return undefined;
}

function stepProblems(step) {
  if (!isObject(step)) return ["is not an object"];
  if (!ACTIONS.includes(step.do)) return [`has an unknown action "${String(step.do)}" (use one of ${ACTIONS.join(", ")})`];
  const problems = [];
  if (step.caption !== undefined && typeof step.caption !== "string") problems.push("has a caption that is not text");
  if (step.timeout !== undefined && !isSeconds(step.timeout)) problems.push("has a timeout that is not a positive number of seconds");
  if (step.effect !== undefined) {
    if (!isObject(step.effect) || !EFFECTS.includes(step.effect.kind)) problems.push('has an effect whose kind is not "sends" or "pays"');
    else if (step.effect.note !== undefined && typeof step.effect.note !== "string") problems.push("has an effect note that is not text");
  }
  switch (step.do) {
    case "open":
      if (!isText(step.url)) problems.push("needs a url");
      break;
    case "click":
    case "fill":
    case "select": {
      const problem = targetProblem(step.target);
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
        problems.push("needs until (text, url, visible, enabled, or hidden)");
        break;
      }
      const kinds = ["text", "url", "visible", "enabled", "hidden"].filter((key) => until[key] !== undefined);
      if (kinds.length !== 1) problems.push("needs exactly one of text, url, visible, enabled, or hidden in until");
      else if (["text", "url"].includes(kinds[0]) && !isText(until[kinds[0]])) problems.push(`has an empty ${kinds[0]} in until`);
      else if (["visible", "enabled", "hidden"].includes(kinds[0])) {
        const problem = targetProblem(until[kinds[0]]);
        if (problem !== undefined) problems.push(problem.replace("its target", `until.${kinds[0]}`));
      }
      break;
    }
    case "hold":
      if (!isSeconds(step.seconds)) problems.push("needs seconds, a positive number");
      break;
  }
  return problems;
}

/** Problems with the flow as a whole and with each step. `step` is 0 for the flow itself. */
export function validate(flow) {
  const problems = [];
  const top = (message) => problems.push({ step: 0, message });
  if (!isObject(flow)) return [{ step: 0, message: "the flow is not a JSON object" }];
  if (flow.version !== 1) top("version must be 1");
  if (!(typeof flow.name === "string" && /^[a-z0-9][a-z0-9-]*$/.test(flow.name))) top("name must be lowercase letters, digits, and hyphens");
  try {
    const url = new URL(flow.url);
    if (!["http:", "https:"].includes(url.protocol)) top("url must start with http:// or https://");
  } catch {
    top("url must be the address the flow starts from");
  }
  if (flow.outputs !== undefined && !(Array.isArray(flow.outputs) && flow.outputs.length > 0 && flow.outputs.every((o) => OUTPUTS.includes(o)))) {
    top(`outputs must list some of ${OUTPUTS.join(", ")}`);
  }
  if (flow.mask !== undefined && !(Array.isArray(flow.mask) && flow.mask.every((m) => isObject(m) && (isText(m.css) || isText(m.text))))) {
    top('mask must list objects with "css" or "text"');
  }
  if (flow.login !== undefined) {
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
    }
  }
  if (!Array.isArray(flow.steps) || flow.steps.length === 0) top("steps must list at least one step");
  else flow.steps.forEach((step, index) => stepProblems(step).forEach((message) => problems.push({ step: index + 1, message })));
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
  return `element "${target.css}"`;
}

/** What a step does, in a few words, for the storyboard and for messages. */
export function describeStep(step) {
  switch (step.do) {
    case "open":
      return `Open ${step.url}`;
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
      return typeof value === "string" ? `Wait for ${kind} "${value}"` : `Wait until ${describeTarget(value)} is ${kind}`;
    }
    case "hold":
      return `Hold for ${step.seconds}s`;
    default:
      return String(step.do);
  }
}

export function locate(page, target) {
  let scope = page;
  if (target.frame !== undefined) {
    const frame = page.frames().find((f) => f !== page.mainFrame() && f.url().includes(target.frame));
    if (frame === undefined) throw new Error(`no frame whose address holds "${target.frame}"`);
    scope = frame;
  }
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
function parseEnvFile(file) {
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
