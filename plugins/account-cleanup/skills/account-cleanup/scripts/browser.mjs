// Drives the browser used for deleting accounts. Called from browser.sh (usage is at the top of browser.sh).
//
// start launches one long-running process (serve), which opens a Chromium window with Playwright and keeps it.
// Every other command only sends a request to that process through browser.sock in the data directory
// (readable and writable only by the user), so Playwright is not loaded per command. The browser is connected
// over a pipe; no TCP port is opened.
//
// Guarantees:
//   - The command that reads the page (look) never prints field values, only whether a field is filled
//   - type never types into a password field. Only login fills it, from 1Password
//   - login fills in only when the domain of the open page and of its frame matches the domain of the 1Password item's URL
//     (groups where one company puts sign-in on another domain are listed in same-owner.mjs and also count as a match)
//   - login never puts a value read from 1Password into the output, a file, or an error message
//   - 1Password is read by the long-running process. App approval applies per process, so reading it from each
//     command's own process would ask for approval every time
//   - Chromium's password saving is turned off, so the macOS keychain is never touched

import { createRequire } from "node:module";
import { spawn, execFile } from "node:child_process";
import { createServer, connect as netConnect } from "node:net";
import { readFileSync, writeFileSync, existsSync, rmSync, mkdirSync, chmodSync } from "node:fs";
import { join, isAbsolute } from "node:path";
import { fileURLToPath } from "node:url";
import { withSameOwner } from "./same-owner.mjs";

const nodeDir = process.env.ACCOUNT_CLEANUP_NODE_DIR;
const dataDir = process.env.ACCOUNT_CLEANUP_DATA_DIR;
const headless = process.env.ACCOUNT_CLEANUP_BROWSER_HEADLESS === "1";
const opBin = process.env.ACCOUNT_CLEANUP_OP || "op";

const profileDir = join(dataDir, "browser");
const stateFile = join(dataDir, "browser-state.json");
// Open the socket by a relative name after moving into the data directory. With an absolute path, a deep data directory exceeds the socket path length limit (about 100 characters)
process.chdir(dataDir);
const sockPath = "browser.sock";

class Refusal extends Error {
  constructor(code, msg) {
    super(msg);
    this.code = code;
  }
}

// Refuse with a reason. The original error text (from Playwright or op) may contain values, so it is never shown
function refuse(code, msg) {
  throw new Refusal(code, msg);
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function withTimeout(p, ms) {
  return Promise.race([p, sleep(ms).then(() => null)]);
}

// Registrable domain, by the same rules as JQ_REGDOMAIN in common.sh: a local host or an IP address stays whole,
// and the same two-label suffix list, plus hosting suffixes where anyone can get a subdomain
const LOCAL_NAME = /^(localhost|.*\.localhost|.*\.local|.*\.internal|.*\.lan|.*\.home\.arpa)$/;
const THREE_LEVEL = new Set([
  "co.jp", "ne.jp", "or.jp", "ac.jp", "go.jp", "gr.jp", "ed.jp", "lg.jp", "co.uk", "org.uk", "ac.uk", "gov.uk",
  "me.uk", "com.au", "net.au", "org.au", "co.nz", "com.br", "com.cn", "com.tw", "com.hk", "co.kr", "com.sg", "co.in",
  "com.mx", "co.za", "com.tr", "github.io", "vercel.app", "netlify.app", "pages.dev", "herokuapp.com", "web.app",
  "firebaseapp.com", "blogspot.com",
]);

function regdomain(host) {
  if (!host) return "";
  if (/^\d+\.\d+\.\d+\.\d+$/.test(host) || host.includes(":") || host.startsWith("[") || LOCAL_NAME.test(host)) return host;
  const p = host.split(".");
  if (p.length <= 2) return host;
  return THREE_LEVEL.has(p.slice(-2).join(".")) ? p.slice(-3).join(".") : p.slice(-2).join(".");
}

function parseUrl(u) {
  if (!u) return null;
  try {
    return new URL(u);
  } catch {
    try {
      return new URL("https://" + u);
    } catch {
      return null;
    }
  }
}

const LOOPBACK = new Set(["127.0.0.1", "localhost", "[::1]"]);

// Whether 1Password values may be filled in on this page URL. Only https, or http on the local machine (127.0.0.1), is allowed
function allowedFor(pageUrl, sites) {
  const u = parseUrl(pageUrl);
  if (!u) return false;
  const host = u.hostname.toLowerCase();
  if (!(u.protocol === "https:" || (u.protocol === "http:" && LOOPBACK.has(host)))) return false;
  return sites.has(regdomain(host));
}

// ---- Long-running process (serve) ----------------------------------------------------

// Runs inside the page. Numbers the clickable elements and fields, and returns a description without any values
function describe(prefix) {
  // Also search inside shadow DOM, because some sites put their sign-in components there
  const deep = (root, s) => {
    const out = [...root.querySelectorAll(s)];
    for (const host of root.querySelectorAll("*")) if (host.shadowRoot) out.push(...deep(host.shadowRoot, s));
    return out;
  };
  for (const el of deep(document, "[data-ac-ref]")) el.removeAttribute("data-ac-ref");
  const sel = 'a[href],button,input,select,textarea,summary,[role=button],[role=link],[role=checkbox],[role=radio],[role=tab],[role=menuitem],[role=switch],[role=option],[contenteditable=""],[contenteditable=true]';
  const clean = (s) => (s || "").replace(/\s+/g, " ").trim().slice(0, 80);
  const visible = (el) => {
    const r = el.getBoundingClientRect();
    const s = getComputedStyle(el);
    return r.width > 0 && r.height > 0 && s.visibility !== "hidden" && s.display !== "none";
  };
  // Number the elements of the dialog in front (sign-in or confirmation) first.
  // On pages full of posts the dialog sits at the end of the page and would fall outside the 300-item limit
  const modals = deep(document, 'dialog[open],[aria-modal="true"],[role=dialog],[role=alertdialog]').filter(visible);
  // Some dialogs have no dialog markup. Treat a fixed-position box covering the center of the screen as the dialog in front
  let overlay = document.elementFromPoint(innerWidth / 2, innerHeight / 2);
  while (overlay && overlay !== document.body && overlay !== document.documentElement && getComputedStyle(overlay).position !== "fixed") overlay = overlay.parentElement;
  if (overlay && overlay !== document.body && overlay !== document.documentElement && !modals.some((m) => m.contains(overlay))) modals.push(overlay);
  const inModal = (el) => modals.some((m) => m.contains(el));
  // After the dialog come the elements visible on screen now. Off-screen elements go last
  const onScreen = (el) => {
    let r = el.getBoundingClientRect();
    // For a hidden checkbox, use the position of its visible label
    if (!r.width && el.labels && el.labels.length) r = el.labels[0].getBoundingClientRect();
    return r.bottom > 0 && r.right > 0 && r.top < innerHeight && r.left < innerWidth;
  };
  const found = deep(document, sel);
  const rank = (el) => (inModal(el) ? 0 : onScreen(el) ? 1 : 2);
  const ordered = found.map((el, i) => [rank(el), i, el]).sort((a, b) => a[0] - b[0] || a[1] - b[1]).map((x) => x[2]);
  const lines = [];
  let n = 0;
  for (const el of ordered) {
    const tag = el.tagName.toLowerCase();
    const type = (el.getAttribute("type") || "").toLowerCase();
    if (type === "hidden") continue;
    // When a checkbox is hidden behind a styled replacement, click its visible label instead
    const choice = tag === "input" && (type === "checkbox" || type === "radio");
    const target = !visible(el) && choice && el.labels && el.labels.length && visible(el.labels[0]) ? el.labels[0] : el;
    if (!visible(target)) continue;
    if (n >= 300) break;
    const ref = `${prefix}-${++n}`;
    target.setAttribute("data-ac-ref", ref);
    const labels = el.labels && el.labels.length ? [...el.labels].map((l) => l.innerText).join(" ") : "";
    const label = clean(el.getAttribute("aria-label") || labels || el.getAttribute("placeholder") || el.getAttribute("title") || "");
    const marks = [];
    let role;
    let name;
    if (tag === "input" && ["submit", "button", "reset", "image"].includes(type)) {
      role = "button";
      name = clean(el.value) || label;
    } else if (tag === "input" && (type === "checkbox" || type === "radio")) {
      role = type;
      name = label;
      if (el.checked) marks.push("checked");
    } else if (tag === "input" || tag === "textarea") {
      role = "field " + (tag === "textarea" ? "textarea" : type || "text");
      name = label || clean(el.getAttribute("name"));
      if (el.value) marks.push("filled");
    } else if (tag === "select") {
      role = "select";
      name = label || clean(el.getAttribute("name"));
      marks.push("options: " + [...el.options].map((o) => clean(o.text)).slice(0, 15).join(" / "));
      if (el.selectedIndex >= 0) marks.push("current: " + clean(el.options[el.selectedIndex].text));
    } else if (tag === "a") {
      role = "link";
      name = clean(el.innerText) || label;
      try {
        marks.push("→ " + new URL(el.href).pathname.slice(0, 60));
      } catch {
        // Links that cannot be parsed get no destination
      }
    } else {
      role = el.getAttribute("role") || (tag === "summary" || tag === "button" ? "button" : "editable");
      name = clean(el.innerText) || label;
      if (el.getAttribute("aria-checked") === "true") marks.push("checked");
    }
    if (el.disabled || el.getAttribute("aria-disabled") === "true") marks.push("disabled");
    lines.push(`[${ref}] ${role} "${(name || "").replace(/"/g, "'")}"${marks.length ? " (" + marks.join(", ") + ")" : ""}`);
  }
  // Put the dialog text first too. The page text is cut at 4000 characters, so this keeps the dialog text from being dropped
  const squeeze = (s) => (s || "").replace(/[ \t]+/g, " ").replace(/\n\s*\n+/g, "\n").trim();
  const modalText = modals.map((m) => squeeze(m.innerText)).filter(Boolean).join("\n");
  const pageText = prefix === 0 && document.body ? squeeze(document.body.innerText) : "";
  const text = prefix !== 0 ? "" : (modalText ? `(dialog in front)\n${modalText}\n(whole page)\n${pageText}` : pageText).slice(0, 4000);
  return { lines, text, more: n >= 300 };
}

// Runs inside the page. Finds and marks the sign-in fields, and returns only whether they were found
function markLoginFields() {
  const deep = (root, s) => {
    const out = [...root.querySelectorAll(s)];
    for (const host of root.querySelectorAll("*")) if (host.shadowRoot) out.push(...deep(host.shadowRoot, s));
    return out;
  };
  for (const el of deep(document, "[data-ac-login]")) el.removeAttribute("data-ac-login");
  const usable = (el) => {
    const r = el.getBoundingClientRect();
    const s = getComputedStyle(el);
    return r.width > 0 && r.height > 0 && s.visibility !== "hidden" && s.display !== "none" && !el.disabled && !el.readOnly;
  };
  const pw = deep(document, "input[type=password]").find(usable) || null;
  // Look for the username field only in the same form as the password field, or in the same dialog (a re-authentication dialog, for example)
  const scope = (pw && (pw.form || pw.closest("[role=dialog],dialog,[aria-modal=true]") || (pw.getRootNode() !== document ? pw.getRootNode() : null))) || document;
  const texts = deep(scope, "input").filter((e) => ["", "text", "email", "tel"].includes((e.getAttribute("type") || "").toLowerCase()) && usable(e));
  const score = (e) => {
    const a = (e.getAttribute("autocomplete") || "").toLowerCase();
    const k = ((e.getAttribute("name") || "") + " " + (e.id || "")).toLowerCase();
    // Sometimes the hint is only in the placeholder or label (e.g. Enter your email or username).
    // The Japanese words match Japanese sign-in forms (email, user, login ID, account)
    const labels = e.labels ? [...e.labels].map((l) => l.innerText).join(" ") : "";
    const t = ((e.getAttribute("placeholder") || "") + " " + (e.getAttribute("aria-label") || "") + " " + labels).toLowerCase();
    if (/username|email/.test(a)) return 3;
    if ((e.getAttribute("type") || "").toLowerCase() === "email") return 2;
    if (/user|login|mail|account|email|id/.test(k)) return 1;
    if (/user ?name|e-?mail|login|account|メール|ユーザー|ログインid|アカウント/.test(t)) return 1;
    return 0;
  };
  const pool = pw ? texts.filter((e) => e.compareDocumentPosition(pw) & Node.DOCUMENT_POSITION_FOLLOWING) : texts;
  let user = null;
  for (const e of pool) if (!user || score(e) >= score(user)) user = e;
  // Fill in only a field recognisable as the username field, so nothing goes into a profile name or a cancellation-reason field.
  // But when the sign-in form has only one text field, treat it as the username field
  if (user && score(user) === 0 && !(pw && pw.form && texts.length === 1)) user = null;
  if (user) user.setAttribute("data-ac-login", "user");
  if (pw) pw.setAttribute("data-ac-login", "pass");
  return { user: !!user, pass: !!pw };
}

async function serve() {
  const require = createRequire(join(nodeDir, "package.json"));
  const { chromium } = require("playwright-core");
  mkdirSync(join(profileDir, "Default"), { recursive: true, mode: 0o700 });
  chmodSync(profileDir, 0o700);
  // Turn off password saving. Saving would use the keychain key and leave values somewhere other than 1Password
  const prefs = join(profileDir, "Default", "Preferences");
  if (!existsSync(prefs)) {
    writeFileSync(prefs, JSON.stringify({ credentials_enable_service: false, profile: { password_manager_enabled: false } }), { mode: 0o600 });
  }
  const ctx = await chromium.launchPersistentContext(profileDir, {
    headless,
    viewport: null,
    // Remove the automation flag. With it, sign-in pages show more CAPTCHAs
    ignoreDefaultArgs: ["--enable-automation"],
    // Open a wide window. A narrow one gets the mobile layout, which hides the sign-in button inside a menu
    args: ["--disable-blink-features=AutomationControlled", "--password-store=basic", "--no-first-run", "--no-default-browser-check", "--window-size=1500,1000"],
  });
  ctx.on("close", () => process.exit(0));

  // Press OK on a confirmation dialog that appears after a click ("Are you sure you want to close your account?" and so on),
  // and include what it said in the reply. The dialog came from a button the AI pressed, so it confirms that action.
  // If nothing is done, Playwright dismisses the dialog and the action (closing the account, for example) is cancelled
  let dialogs = [];
  const watch = (p) =>
    p.on("dialog", async (d) => {
      dialogs.push(d.message().replace(/\s+/g, " ").slice(0, 200));
      await d.accept().catch(() => {});
    });
  ctx.pages().forEach(watch);
  ctx.on("page", watch);
  const withDialogs = (msg) => {
    const seen = dialogs;
    dialogs = [];
    return seen.length ? `${msg}\nPressed OK on a confirmation dialog: ${seen.map((m) => '"' + m + '"').join(" ")}` : msg;
  };

  const current = async () => {
    const pages = ctx.pages().filter((p) => !p.isClosed());
    return pages.length ? pages[pages.length - 1] : ctx.newPage();
  };
  const settle = async (page) => {
    await page.waitForLoadState("domcontentloaded", { timeout: 10000 }).catch(() => {});
  };
  const find = async (page, ref) => {
    if (!/^\d+-\d+$/.test(ref || "")) refuse(2, "Pass the number as look prints it inside the brackets (0-3 for [0-3])");
    for (const f of page.frames()) {
      const loc = f.locator(`[data-ac-ref="${ref}"]`);
      if ((await loc.count().catch(() => 0)) > 0) return loc.first();
    }
    refuse(4, `Number ${ref} was not found. The page has changed; run look again`);
  };

  const handlers = {
    ping: async () => "ok",
    async open({ url }) {
      const u = parseUrl(url);
      if (!u || !/^https?:$/.test(u.protocol)) refuse(2, "Only http and https URLs can be opened");
      const page = await current();
      try {
        await page.goto(u.href, { waitUntil: "domcontentloaded", timeout: 45000 });
      } catch {
        refuse(4, "Could not open the page");
      }
      await page.bringToFront().catch(() => {});
      return `Opened: ${await page.title().catch(() => "")} (${page.url().split(/[?#]/)[0]})`;
    },
    async look() {
      const page = await current();
      const out = [`Page: ${(await page.title().catch(() => "")).slice(0, 120)}`, `URL: ${page.url().split(/[?#]/)[0]}`];
      const frames = page.frames();
      const sections = [];
      for (let i = 0; i < frames.length; i++) {
        const f = frames[i];
        if (i > 0 && !/^https?:/.test(f.url())) continue;
        const r = await withTimeout(f.evaluate(describe, i).catch(() => null), 3000);
        if (!r) continue;
        if (i === 0) out.push("--- Page text ---", r.text);
        if (r.lines.length) sections.push({ i, url: f.url(), r });
      }
      out.push("--- Clickable elements and fields (field values are never shown) ---");
      for (const s of sections) {
        if (s.i > 0) out.push(`(frame ${s.i}: ${parseUrl(s.url)?.hostname || ""})`);
        out.push(...s.r.lines);
        if (s.r.more) out.push("(cut off at 300 items)");
      }
      return out.join("\n");
    },
    async click({ ref }) {
      const page = await current();
      const loc = await find(page, ref);
      // For a hidden checkbox, look numbers its label. Treat the field the label points to the same way
      const choice = await loc
        .evaluate((el) => {
          const input = el.tagName === "LABEL" ? el.control : el;
          return !!input && input.tagName === "INPUT" && (input.type === "checkbox" || input.type === "radio");
        })
        .catch(() => false);
      try {
        await loc.click({ timeout: choice ? 3000 : 10000 });
      } catch {
        // A checkbox covered by a styled box cannot be clicked from the screen, so send the click to the field itself.
        // Never do this for buttons: it would press a button hidden under an overlay without the user seeing it
        const done = choice && (await loc.evaluate((el) => (el.click(), true)).catch(() => false));
        if (!done) refuse(4, `Could not click ${ref}`);
      }
      await settle(page);
      return withDialogs(`Clicked: ${ref}`);
    },
    // Click an element that has no number (a plain box with a click handler) by its text on the page. Exact matches are tried first.
    // With after, only elements after that text are searched (to name the row when every row has the same "Change" button)
    async clicktext({ text, after }) {
      if (!text) refuse(2, "Pass the text of the element to click");
      const page = await current();
      const xq = (s) => (s.includes('"') ? `'${s}'` : `"${s}"`);
      if (after && ((text.includes('"') && text.includes("'")) || (after.includes('"') && after.includes("'")))) refuse(2, "--after cannot be used when the text contains both \" and '");
      for (const exact of [true, false]) {
        for (const f of page.frames()) {
          const loc = after
            ? f
                .getByText(after, { exact: true })
                .first()
                // Pick the innermost element that holds the text itself, not an outer box with the same text (clicking the middle of an outer box does nothing)
                .locator(
                  exact
                    ? `xpath=following::*[normalize-space(.)=${xq(text)}][not(.//*[normalize-space(.)=${xq(text)}])]`
                    : `xpath=following::*[contains(normalize-space(.), ${xq(text)})][not(.//*[contains(normalize-space(.), ${xq(text)})])]`,
                )
            : f.getByText(text, { exact });
          const n = await loc.count().catch(() => 0);
          for (let i = 0; i < n; i++) {
            const el = loc.nth(i);
            if (!(await el.isVisible().catch(() => false))) continue;
            try {
              await el.click({ timeout: 10000 });
            } catch {
              continue;
            }
            await settle(page);
            return withDialogs(`Clicked: "${text}"`);
          }
        }
      }
      refuse(4, `No clickable element with the text "${text}" was found`);
    },
    async type({ ref, text }) {
      const page = await current();
      const loc = await find(page, ref);
      const isPassword = await loc.evaluate((el) => el.tagName === "INPUT" && el.type === "password").catch(() => true);
      if (isPassword) refuse(3, "Refusing to type into a password field. Use browser.sh login to fill it from 1Password");
      try {
        await loc.fill(text, { timeout: 10000 });
      } catch {
        refuse(4, `Could not type into ${ref}`);
      }
      return `Typed into: ${ref}`;
    },
    async select({ ref, value }) {
      const page = await current();
      const loc = await find(page, ref);
      try {
        await loc.selectOption({ label: value }, { timeout: 5000 });
      } catch {
        try {
          await loc.selectOption(value, { timeout: 5000 });
        } catch {
          refuse(4, `Could not select "${value}" in ${ref}`);
        }
      }
      return `Selected: ${ref}`;
    },
    async press({ key }) {
      const page = await current();
      try {
        await page.keyboard.press(key);
      } catch {
        refuse(4, `Could not press ${key}`);
      }
      await settle(page);
      return withDialogs(`Pressed: ${key}`);
    },
    async shot({ path }) {
      if (!path || !isAbsolute(path)) refuse(2, "Pass an absolute path to save to");
      const page = await current();
      await page.screenshot({ path });
      chmodSync(path, 0o600);
      return `Saved a screenshot: ${path}`;
    },
    async login({ id, account, userRef, passRef, site }) {
      const { username, email, password, sites: itemSites } = await readItem(id, account);
      // --site with the official domain looked up is allowed only when the item has no URL. When the item has a URL, only that URL is trusted
      if (site && itemSites.length > 0) refuse(2, "--site cannot be used when the 1Password item has a URL");
      const siteHost = site ? parseUrl(/^https?:\/\//.test(site) ? site : `https://${site}`)?.hostname?.toLowerCase() : "";
      if (site && !siteHost) refuse(2, "Pass a domain to --site (e.g. example.com)");
      const sites = itemSites.length > 0 ? itemSites : siteHost ? withSameOwner([regdomain(siteHost)]) : [];
      if (sites.length === 0) refuse(3, "The 1Password item has no URL, so its domain cannot be checked. Pass the official domain you looked up with --site, or have the user sign in");
      const allowed = new Set(sites);
      const page = await current();
      const pageHost = parseUrl(page.url())?.hostname || "";
      if (!allowedFor(page.url(), allowed)) {
        refuse(3, `Not filling in: the open page's domain (${regdomain(pageHost) || "none"}) does not match the 1Password item's domain (${[...allowed].join(", ")})`);
      }
      // When fields are named by number, fill in those fields. Some sites use a plain text field for the password on the account-closing page.
      // The named field's frame domain is checked too. After filling in, the AI moves on without running shot, so the value never ends up in a screenshot
      if (userRef || passRef) {
        const put = async (ref, value, isUser) => {
          const loc = await find(page, ref);
          const frameUrl = await loc.evaluate(() => location.href).catch(() => "");
          if (!allowedFor(frameUrl, allowed)) refuse(3, `Not filling in ${ref}: the field is in a frame whose domain does not match`);
          // For an email field, use the item's email value when the username is not an email address and the item has an email field
          if (isUser && email && !value.includes("@")) {
            const type = await loc.evaluate((el) => (el.getAttribute("type") || "").toLowerCase()).catch(() => "");
            if (type === "email") value = email;
          }
          try {
            await loc.fill(value, { timeout: 5000 });
          } catch {
            refuse(4, `Could not fill in ${ref}`);
          }
        };
        // When the item has no value for a named field, refuse instead of reporting that it was filled in
        if (userRef && !username && !email) refuse(4, "The 1Password item has no username. Have the user enter it");
        if (passRef && !password) refuse(4, "The 1Password item has no password. Have the user enter it");
        if (userRef) await put(userRef, username || email, true);
        if (passRef) await put(passRef, password, false);
        const named = userRef && passRef ? "username and password" : passRef ? "password" : "username";
        return `Filled in: ${named} (into the named fields; values are not shown)`;
      }
      const filled = new Set();
      for (const f of page.frames()) {
        if (!allowedFor(f.url(), allowed)) continue;
        const found = await withTimeout(f.evaluate(markLoginFields).catch(() => null), 3000);
        if (!found) continue;
        try {
          if (found.user && username && !filled.has("user")) {
            await f.locator("[data-ac-login=user]").first().fill(username, { timeout: 5000 });
            filled.add("user");
          }
          if (found.pass && password && !filled.has("pass")) {
            await f.locator("[data-ac-login=pass]").first().fill(password, { timeout: 5000 });
            filled.add("pass");
          }
        } catch {
          refuse(4, "Could not fill in the sign-in fields");
        }
        await f.evaluate(() => document.querySelectorAll("[data-ac-login]").forEach((el) => el.removeAttribute("data-ac-login"))).catch(() => {});
      }
      if (filled.size === 0) refuse(4, "No sign-in fields were found. Open the sign-in page and run this again");
      const what = filled.has("user") && filled.has("pass") ? "username and password" : filled.has("pass") ? "password" : "username";
      return `Filled in: ${what} (values are not shown). Find the sign-in button's number with look and press it with click`;
    },
    async stop() {
      setTimeout(() => ctx.close().finally(() => process.exit(0)), 50);
      return "Closed the browser window";
    },
  };

  // Handle requests one at a time, in order. Running them in parallel would mix up the element numbers
  let queue = Promise.resolve();
  const server = createServer({ allowHalfOpen: true }, (sock) => {
    let buf = "";
    sock.setEncoding("utf8");
    sock.on("data", (d) => (buf += d));
    sock.on("end", () => {
      // Liveness checks skip the queue, so the process still answers that it is open while login waits for 1Password approval
      if (/^\{"cmd":"ping"\}$/.test(buf)) {
        sock.end(JSON.stringify({ code: 0, out: "ok" }));
        return;
      }
      queue = queue.then(async () => {
        let res;
        try {
          const req = JSON.parse(buf);
          buf = "";
          if (!handlers[req.cmd]) refuse(2, "Unknown command");
          res = { code: 0, out: await handlers[req.cmd](req) };
        } catch (e) {
          res = e instanceof Refusal ? { code: e.code, err: e.message } : { code: 1, err: "The command failed" };
        }
        sock.end(JSON.stringify(res));
      });
    });
    sock.on("error", () => {});
  });
  rmSync(sockPath, { force: true });
  server.listen(sockPath, () => chmodSync(sockPath, 0o600));
}

// ---- Process that ran the command (client) ------------------------------------------

function send(req, timeoutMs = 120000) {
  return new Promise((resolve) => {
    const s = netConnect(sockPath);
    let buf = "";
    const timer = setTimeout(() => {
      s.destroy();
      resolve(null);
    }, timeoutMs);
    s.setEncoding("utf8");
    s.on("connect", () => s.end(JSON.stringify(req)));
    s.on("data", (d) => (buf += d));
    s.on("end", () => {
      clearTimeout(timer);
      try {
        resolve(JSON.parse(buf));
      } catch {
        resolve(null);
      }
    });
    s.on("error", () => {
      clearTimeout(timer);
      resolve(null);
    });
  });
}

async function running() {
  if (!existsSync(sockPath)) return false;
  const r = await send({ cmd: "ping" }, 3000);
  return !!(r && r.code === 0);
}

function readState() {
  try {
    return JSON.parse(readFileSync(stateFile, "utf8"));
  } catch {
    return null;
  }
}

async function start() {
  if (await running()) return "The browser is already open";
  // Install the Chromium that opens the window if it is missing (first run only). Headless mode uses a separate, smaller Chromium, so it is not checked
  if (!headless) {
    const { chromium } = createRequire(join(nodeDir, "package.json"))("playwright-core");
    if (!existsSync(chromium.executablePath())) {
      process.stderr.write("account-cleanup: installing the browser (Chromium), first run only\n");
      await new Promise((resolve) => spawn(process.execPath, [join(nodeDir, "node_modules/playwright-core/cli.js"), "install", "chromium"], { stdio: ["ignore", 2, 2] }).on("exit", resolve));
    }
  }
  const st = readState();
  if (st && st.pid) {
    try {
      process.kill(st.pid, "SIGTERM");
    } catch {
      // Already closed
    }
  }
  rmSync(sockPath, { force: true });
  const child = spawn(process.execPath, [fileURLToPath(import.meta.url), "serve"], { detached: true, stdio: "ignore", env: process.env });
  child.unref();
  for (let i = 0; i < 600; i++) {
    await sleep(100);
    if (await running()) {
      writeFileSync(stateFile, JSON.stringify({ pid: child.pid }), { mode: 0o600 });
      return "Opened the browser window";
    }
  }
  refuse(3, "The browser did not start. On first use, install the browser (Chromium) and run this again");
}

async function stop() {
  let out = "Closed the browser window";
  if (await running()) {
    const r = await send({ cmd: "stop" }, 10000);
    if (r && r.out) out = r.out;
  }
  const st = readState();
  if (st && st.pid) {
    for (let i = 0; i < 30; i++) {
      try {
        process.kill(st.pid, 0);
      } catch {
        break;
      }
      await sleep(100);
    }
    try {
      process.kill(st.pid, "SIGTERM");
    } catch {
      // Already closed
    }
  }
  rmSync(stateFile, { force: true });
  rmSync(sockPath, { force: true });
  return out;
}

// Read an item from 1Password. Called only inside the long-running process; values never go into a socket reply or a file
async function readItem(id, account) {
  const args = ["item", "get", id, "--format", "json", "--reveal"];
  if (account) args.push("--account", account);
  const run = (a) => new Promise((resolve) => execFile(opBin, a, { maxBuffer: 8 * 1024 * 1024 }, (err, out) => resolve(err ? null : out)));
  let stdout = await run(args);
  if (!stdout) {
    // The first call after the 1Password app's approval has expired fails without waiting for approval.
    // Wait for the app's approval (Touch ID) with signin, then read once more
    await run(account ? ["signin", "--account", account] : ["signin"]);
    stdout = await run(args);
  }
  if (!stdout) refuse(5, "Could not read the item from 1Password. Check the approval in the app and the account passed with --account");
  let item;
  try {
    item = JSON.parse(stdout);
  } catch {
    refuse(5, "Could not parse the 1Password item");
  }
  const fields = Array.isArray(item.fields) ? item.fields : [];
  const pick = (purpose) => (fields.find((f) => f.purpose === purpose) || {}).value || "";
  // Some items keep the username in an email field (one without a purpose) instead of the username field.
  // The Japanese labels match items created in Japanese (email, user)
  const emailField = () =>
    (
      fields.find((f) => f.type === "EMAIL" && f.value) ||
      fields.find((f) => !f.purpose && f.type !== "CONCEALED" && /^(e-?mail|username|user|login|メール|ユーザー)/i.test(f.label || f.id || "") && f.value) ||
      {}
    ).value || "";
  const sites = withSameOwner(
    (Array.isArray(item.urls) ? item.urls : [])
      .map((u) => parseUrl(u && u.href)?.hostname?.toLowerCase())
      .filter(Boolean)
      .map(regdomain),
  );
  return { username: pick("USERNAME") || emailField(), email: emailField(), password: pick("PASSWORD"), sites };
}

async function client(cmd, rest) {
  if (cmd === "start") return { code: 0, out: await start() };
  if (cmd === "stop") return { code: 0, out: await stop() };
  if (!(await running())) refuse(2, "The browser is not open. Run browser.sh start first");
  let req;
  switch (cmd) {
    case "open":
      req = { cmd, url: rest[0] };
      break;
    case "look":
      req = { cmd };
      break;
    case "click":
      req = { cmd, ref: rest[0] };
      break;
    case "clicktext": {
      const at = rest.indexOf("--after");
      req = at >= 0 ? { cmd, text: rest.slice(0, at).join(" "), after: rest.slice(at + 1).join(" ") } : { cmd, text: rest.join(" ") };
      break;
    }
    case "type":
      req = { cmd, ref: rest[0], text: rest.slice(1).join(" ") };
      break;
    case "select":
      req = { cmd, ref: rest[0], value: rest.slice(1).join(" ") };
      break;
    case "press":
      req = { cmd, key: rest[0] };
      break;
    case "shot":
      req = { cmd, path: rest[0] };
      break;
    case "login": {
      const id = rest[0];
      if (!/^[A-Za-z0-9-]{1,64}$/.test(id || "")) refuse(2, "Pass the 1Password item ID (shown in the \"Password manager items\" row of plan.sh)");
      const at = rest.indexOf("--account");
      const opt = (name) => (rest.indexOf(name) >= 0 ? rest[rest.indexOf(name) + 1] : "");
      req = { cmd, id, account: at >= 0 ? rest[at + 1] : "", userRef: opt("--user-ref"), passRef: opt("--pass-ref"), site: opt("--site") };
      break;
    }
    default:
      refuse(2, "See the top of browser.sh for usage (start, open, look, click, clicktext, type, select, press, login, shot, stop)");
  }
  // login can wait for approval in the 1Password app, so wait longer
  const res = await send(req, cmd === "login" ? 300000 : 120000);
  if (!res) refuse(1, "No reply from the browser. Run browser.sh stop, then browser.sh start");
  return res;
}

const [cmd, ...rest] = process.argv.slice(2);
if (cmd === "serve") {
  await serve();
} else {
  let res;
  try {
    res = await client(cmd, rest);
  } catch (e) {
    res = e instanceof Refusal ? { code: e.code, err: e.message } : { code: 1, err: `${cmd} failed` };
  }
  if (res.out) process.stdout.write(res.out + "\n");
  if (res.err) process.stderr.write("account-cleanup: " + res.err + "\n");
  process.exit(res.code);
}
