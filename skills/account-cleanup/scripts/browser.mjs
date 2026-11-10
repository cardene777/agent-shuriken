// アカウントの削除に使うブラウザを動かす本体。browser.sh から呼ぶ (使い方は browser.sh の冒頭)。
//
// start は常駐の処理 (serve) を1つ起こし、常駐の処理が Playwright で Chromium の窓を開いて持ち続ける。
// ほかの命令は、置き場の browser.sock (利用者だけが読み書きできる) を通して常駐の処理に頼むだけにし、
// 命令ごとに Playwright を読み込まない。ブラウザとはパイプで繋ぎ、TCP のポートを開けない。
//
// 守ること:
//   - 画面を読む命令 (look) は入力欄の値を出さない。入っているかだけを出す
//   - パスワードの入力欄には type で文字を入れない。login だけが1Passwordから入れる
//   - login は、開いているページとその枠のドメインが1Passwordの項目のURLのドメインと一致した時だけ入れる
//     (同じ会社がログインの画面を別のドメインに置く組は same-owner.mjs が持ち、その組も一致とみなす)
//   - login は1Passwordから読んだ値を、出力にも、ファイルにも、失敗の文にも出さない
//   - 1Passwordは常駐の処理が読む。アプリの承認は読んだ処理ごとに効くので、命令ごとの処理で読むと毎回承認を求められる
//   - Chromium のパスワードの保存を切り、macOS のキーチェーンに触らない

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
// ソケットは置き場へ移ってから相対の名前で開く。絶対 path だと、深い置き場でソケットの名前の長さの上限 (約100文字) を超えるため
process.chdir(dataDir);
const sockPath = "browser.sock";

class Refusal extends Error {
  constructor(code, msg) {
    super(msg);
    this.code = code;
  }
}

// 理由を添えて断る。失敗の元の文 (Playwright や op の文) は値を含みうるので出さない
function refuse(code, msg) {
  throw new Refusal(code, msg);
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function withTimeout(p, ms) {
  return Promise.race([p, sleep(ms).then(() => null)]);
}

// 登録できる単位のドメイン。common.sh の JQ_REGDOMAIN と同じ2段の一覧に、誰でも名前を借りられる置き場を足した物
const THREE_LEVEL = new Set([
  "co.jp", "ne.jp", "or.jp", "ac.jp", "go.jp", "gr.jp", "ed.jp", "lg.jp", "co.uk", "org.uk", "ac.uk", "gov.uk",
  "me.uk", "com.au", "net.au", "org.au", "co.nz", "com.br", "com.cn", "com.tw", "com.hk", "co.kr", "com.sg", "co.in",
  "com.mx", "co.za", "com.tr", "github.io", "vercel.app", "netlify.app", "pages.dev", "herokuapp.com", "web.app",
  "firebaseapp.com", "blogspot.com",
]);

function regdomain(host) {
  if (!host) return "";
  if (/^\d+\.\d+\.\d+\.\d+$/.test(host) || host.includes(":") || host.startsWith("[")) return host;
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

// ページの URL に1Passwordの値を入れてよいか。https か、手元 (127.0.0.1) の http だけを許す
function allowedFor(pageUrl, sites) {
  const u = parseUrl(pageUrl);
  if (!u) return false;
  const host = u.hostname.toLowerCase();
  if (!(u.protocol === "https:" || (u.protocol === "http:" && LOOPBACK.has(host)))) return false;
  return sites.has(regdomain(host));
}

// ---- 常駐の処理 (serve) ------------------------------------------------------------

// ページの中で動かす。押せる物と入力欄に番号を付け、値を含まない説明を返す
function describe(prefix) {
  // 影の領域 (shadow DOM) の中も探す。ログインの部品を影の領域に入れるサイトがあるため
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
  // 前に出ている窓 (ログインや確認の窓) の部品を先に数える。
  // 投稿の並ぶページでは窓がページの最後に置かれ、300件の上限の外に落ちるため
  const modals = deep(document, 'dialog[open],[aria-modal="true"],[role=dialog],[role=alertdialog]').filter(visible);
  // 窓の印を持たない窓もある。画面の中央に重なる固定表示の箱を、前に出ている窓とみなす
  let overlay = document.elementFromPoint(innerWidth / 2, innerHeight / 2);
  while (overlay && overlay !== document.body && overlay !== document.documentElement && getComputedStyle(overlay).position !== "fixed") overlay = overlay.parentElement;
  if (overlay && overlay !== document.body && overlay !== document.documentElement && !modals.some((m) => m.contains(overlay))) modals.push(overlay);
  const inModal = (el) => modals.some((m) => m.contains(el));
  // 窓の次は、今の画面に見えている部品。画面の外の部品は最後に回す
  const onScreen = (el) => {
    let r = el.getBoundingClientRect();
    // 隠したチェックの欄は、見えているラベルの位置で決める
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
    // 見た目だけの欄で隠したチェックの欄は、見えているラベルを押す先にする
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
      if (el.checked) marks.push("選択済み");
    } else if (tag === "input" || tag === "textarea") {
      role = "入力欄 " + (tag === "textarea" ? "textarea" : type || "text");
      name = label || clean(el.getAttribute("name"));
      if (el.value) marks.push("入力済み");
    } else if (tag === "select") {
      role = "選ぶ欄";
      name = label || clean(el.getAttribute("name"));
      marks.push("選べる値 " + [...el.options].map((o) => clean(o.text)).slice(0, 15).join(" / "));
      if (el.selectedIndex >= 0) marks.push("今は " + clean(el.options[el.selectedIndex].text));
    } else if (tag === "a") {
      role = "link";
      name = clean(el.innerText) || label;
      try {
        marks.push("→ " + new URL(el.href).pathname.slice(0, 60));
      } catch {
        // 読めないリンクは行き先を添えない
      }
    } else {
      role = el.getAttribute("role") || (tag === "summary" || tag === "button" ? "button" : "編集欄");
      name = clean(el.innerText) || label;
      if (el.getAttribute("aria-checked") === "true") marks.push("選択済み");
    }
    if (el.disabled || el.getAttribute("aria-disabled") === "true") marks.push("押せない");
    lines.push(`[${ref}] ${role} "${(name || "").replace(/"/g, "'")}"${marks.length ? " (" + marks.join("、") + ")" : ""}`);
  }
  // 文字も窓の分を先に置く。ページ全体の文字は4000字で切るので、窓の文字が落ちないように
  const squeeze = (s) => (s || "").replace(/[ \t]+/g, " ").replace(/\n\s*\n+/g, "\n").trim();
  const modalText = modals.map((m) => squeeze(m.innerText)).filter(Boolean).join("\n");
  const pageText = prefix === 0 && document.body ? squeeze(document.body.innerText) : "";
  const text = prefix !== 0 ? "" : (modalText ? `(前に出ている窓)\n${modalText}\n(ページ全体)\n${pageText}` : pageText).slice(0, 4000);
  return { lines, text, more: n >= 300 };
}

// ページの中で動かす。ログインの入力欄を探して印を付け、見つかったかだけを返す
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
  // パスワードの欄と同じフォームか、同じ窓 (確かめの窓など) の中だけからIDの欄を探す
  const scope = (pw && (pw.form || pw.closest("[role=dialog],dialog,[aria-modal=true]") || (pw.getRootNode() !== document ? pw.getRootNode() : null))) || document;
  const texts = deep(scope, "input").filter((e) => ["", "text", "email", "tel"].includes((e.getAttribute("type") || "").toLowerCase()) && usable(e));
  const score = (e) => {
    const a = (e.getAttribute("autocomplete") || "").toLowerCase();
    const k = ((e.getAttribute("name") || "") + " " + (e.id || "")).toLowerCase();
    // 案内の文とラベルにだけ書かれていることもある (例 Enter your email or username)
    const labels = e.labels ? [...e.labels].map((l) => l.innerText).join(" ") : "";
    const t = ((e.getAttribute("placeholder") || "") + " " + (e.getAttribute("aria-label") || "") + " " + labels).toLowerCase();
    if (/username|email/.test(a)) return 3;
    if ((e.getAttribute("type") || "").toLowerCase() === "email") return 2;
    if (/user|login|mail|account|email|id/.test(k)) return 1;
    if (/user ?name|e-?mail|login|メール|ユーザー|ログインid|アカウント/.test(t)) return 1;
    return 0;
  };
  const pool = pw ? texts.filter((e) => e.compareDocumentPosition(pw) & Node.DOCUMENT_POSITION_FOLLOWING) : texts;
  let user = null;
  for (const e of pool) if (!user || score(e) >= score(user)) user = e;
  // IDの欄と分かる物だけに入れる。プロフィールの名前の欄や退会の理由の欄に入れないため。
  // ただしログインのフォームに文字の欄が1つしか無い時は、それをIDの欄とみなす
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
  // パスワードの保存を切る。保存するとキーチェーンの鍵を使い、1Passwordとは別の置き場に値が残るため
  const prefs = join(profileDir, "Default", "Preferences");
  if (!existsSync(prefs)) {
    writeFileSync(prefs, JSON.stringify({ credentials_enable_service: false, profile: { password_manager_enabled: false } }), { mode: 0o600 });
  }
  const ctx = await chromium.launchPersistentContext(profileDir, {
    headless,
    viewport: null,
    // 自動で動かしている印を外す。印が在るとログインの画面で画像認証が増える
    ignoreDefaultArgs: ["--enable-automation"],
    // 窓が狭いとスマホ向けの画面になり、ログインのボタンがメニューの中に隠れるので、広く開く
    args: ["--disable-blink-features=AutomationControlled", "--password-store=basic", "--no-first-run", "--no-default-browser-check", "--window-size=1500,1000"],
  });
  ctx.on("close", () => process.exit(0));

  // 押した後に出た確認の窓 (「本当に退会しますか」など) は OK を押し、何と出たかを返事に添える。
  // 窓を出したのは AI が押したボタンなので、押した操作を確かめる窓として扱う。
  // 何もしないと Playwright が窓を閉じ、退会などの操作が取り消される
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
    return seen.length ? `${msg}\n確認の窓で OK を押しました: ${seen.map((m) => "「" + m + "」").join(" ")}` : msg;
  };

  const current = async () => {
    const pages = ctx.pages().filter((p) => !p.isClosed());
    return pages.length ? pages[pages.length - 1] : ctx.newPage();
  };
  const settle = async (page) => {
    await page.waitForLoadState("domcontentloaded", { timeout: 10000 }).catch(() => {});
  };
  const find = async (page, ref) => {
    if (!/^\d+-\d+$/.test(ref || "")) refuse(2, "番号は look が出した [0-3] の形の中身で渡してください");
    for (const f of page.frames()) {
      const loc = f.locator(`[data-ac-ref="${ref}"]`);
      if ((await loc.count().catch(() => 0)) > 0) return loc.first();
    }
    refuse(4, `番号 ${ref} が見つかりません。画面が変わったので look を打ち直してください`);
  };

  const handlers = {
    ping: async () => "ok",
    async open({ url }) {
      const u = parseUrl(url);
      if (!u || !/^https?:$/.test(u.protocol)) refuse(2, "開けるのは http か https の URL だけです");
      const page = await current();
      try {
        await page.goto(u.href, { waitUntil: "domcontentloaded", timeout: 45000 });
      } catch {
        refuse(4, "ページを開けませんでした");
      }
      await page.bringToFront().catch(() => {});
      return `開きました: ${await page.title().catch(() => "")} (${page.url().split(/[?#]/)[0]})`;
    },
    async look() {
      const page = await current();
      const out = [`ページ: ${(await page.title().catch(() => "")).slice(0, 120)}`, `URL: ${page.url().split(/[?#]/)[0]}`];
      const frames = page.frames();
      const sections = [];
      for (let i = 0; i < frames.length; i++) {
        const f = frames[i];
        if (i > 0 && !/^https?:/.test(f.url())) continue;
        const r = await withTimeout(f.evaluate(describe, i).catch(() => null), 3000);
        if (!r) continue;
        if (i === 0) out.push("--- 画面の文字 ---", r.text);
        if (r.lines.length) sections.push({ i, url: f.url(), r });
      }
      out.push("--- 押せる物と入力欄 (入力欄の値は出さない) ---");
      for (const s of sections) {
        if (s.i > 0) out.push(`(枠 ${s.i}: ${parseUrl(s.url)?.hostname || ""})`);
        out.push(...s.r.lines);
        if (s.r.more) out.push("(多いので300件で打ち切った)");
      }
      return out.join("\n");
    },
    async click({ ref }) {
      const page = await current();
      const loc = await find(page, ref);
      // 隠したチェックの欄は、look がラベルに番号を付ける。ラベルが指す欄も同じに扱う
      const choice = await loc
        .evaluate((el) => {
          const input = el.tagName === "LABEL" ? el.control : el;
          return !!input && input.tagName === "INPUT" && (input.type === "checkbox" || input.type === "radio");
        })
        .catch(() => false);
      try {
        await loc.click({ timeout: choice ? 3000 : 10000 });
      } catch {
        // 見た目の箱が上に重なったチェックの欄は、画面の上からは押せない。欄そのものに押す動きを送る。
        // ボタンでは行わない (重なった窓の下のボタンを、利用者に見えないまま押すことになるため)
        const done = choice && (await loc.evaluate((el) => (el.click(), true)).catch(() => false));
        if (!done) refuse(4, `番号 ${ref} を押せませんでした`);
      }
      await settle(page);
      return withDialogs(`押しました: ${ref}`);
    },
    // 番号の付かない押せる物 (ただの枠に押す動きを付けた物) を、画面の文字で押す。完全に一致する物を先に探す。
    // after を渡すと、その文字より後ろに在る物だけを探す (同じ「変更する」が行ごとに並ぶ画面で、行を名指すため)
    async clicktext({ text, after }) {
      if (!text) refuse(2, "押す物の文字を渡してください");
      const page = await current();
      const xq = (s) => (s.includes('"') ? `'${s}'` : `"${s}"`);
      if (after && ((text.includes('"') && text.includes("'")) || (after.includes('"') && after.includes("'")))) refuse(2, "文字に \" と ' の両方を含む時は after を使えません");
      for (const exact of [true, false]) {
        for (const f of page.frames()) {
          const loc = after
            ? f
                .getByText(after, { exact: true })
                .first()
                // 同じ文字を持つ外側の枠でなく、その文字を直に持つ一番内側の要素を選ぶ (外側の枠の中央を押すと何も起きないため)
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
            return withDialogs(`押しました: 「${text}」`);
          }
        }
      }
      refuse(4, `「${text}」と書かれた押せる物が見つかりません`);
    },
    async type({ ref, text }) {
      const page = await current();
      const loc = await find(page, ref);
      const isPassword = await loc.evaluate((el) => el.tagName === "INPUT" && el.type === "password").catch(() => true);
      if (isPassword) refuse(3, "パスワードの入力欄には入れられません。browser.sh login で1Passwordから入れてください");
      try {
        await loc.fill(text, { timeout: 10000 });
      } catch {
        refuse(4, `番号 ${ref} に入れられませんでした`);
      }
      return `入れました: ${ref}`;
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
          refuse(4, `番号 ${ref} で「${value}」を選べませんでした`);
        }
      }
      return `選びました: ${ref}`;
    },
    async press({ key }) {
      const page = await current();
      try {
        await page.keyboard.press(key);
      } catch {
        refuse(4, `キー ${key} を押せませんでした`);
      }
      await settle(page);
      return withDialogs(`押しました: ${key}`);
    },
    async shot({ path }) {
      if (!path || !isAbsolute(path)) refuse(2, "保存する path は絶対 path で渡してください");
      const page = await current();
      await page.screenshot({ path });
      chmodSync(path, 0o600);
      return `画像を残しました: ${path}`;
    },
    async login({ id, account, userRef, passRef, site }) {
      const { username, email, password, sites: itemSites } = await readItem(id, account);
      // 項目にURLが無い時だけ、調べた公式のドメインを --site で渡せる。項目にURLが在る時は項目のURLだけを信じる
      if (site && itemSites.length > 0) refuse(2, "1Passwordの項目にURLが在る時は --site を使えません");
      const siteHost = site ? parseUrl(/^https?:\/\//.test(site) ? site : `https://${site}`)?.hostname?.toLowerCase() : "";
      if (site && !siteHost) refuse(2, "--site にはドメインを渡してください (例 example.com)");
      const sites = itemSites.length > 0 ? itemSites : siteHost ? withSameOwner([regdomain(siteHost)]) : [];
      if (sites.length === 0) refuse(3, "1Passwordの項目にURLが無いので、ドメインを確かめられません。調べた公式のドメインを --site で渡すか、ログインは利用者が入れてください");
      const allowed = new Set(sites);
      const page = await current();
      const pageHost = parseUrl(page.url())?.hostname || "";
      if (!allowedFor(page.url(), allowed)) {
        refuse(3, `開いているページのドメイン (${regdomain(pageHost) || "無し"}) が1Passwordの項目のドメイン (${[...allowed].join("、")}) と一致しないので入れません`);
      }
      // 入れる欄を番号で名指した時は、その欄に入れる。退会の画面でパスワードの欄が普通の文字の欄になっているサイトがあるため。
      // 名指した欄の枠のドメインも確かめ、入れた後は欄の値を画面の画像に残さないよう、AI は shot を打たずに次へ進む
      if (userRef || passRef) {
        const put = async (ref, value, isUser) => {
          const loc = await find(page, ref);
          const frameUrl = await loc.evaluate(() => location.href).catch(() => "");
          if (!allowedFor(frameUrl, allowed)) refuse(3, `番号 ${ref} の欄はドメインが一致しない枠に在るので入れません`);
          // メールの欄には、ユーザー名がメールの形でなく項目にメールの欄が在る時、メールの欄の値を入れる
          if (isUser && email && !value.includes("@")) {
            const type = await loc.evaluate((el) => (el.getAttribute("type") || "").toLowerCase()).catch(() => "");
            if (type === "email") value = email;
          }
          try {
            await loc.fill(value, { timeout: 5000 });
          } catch {
            refuse(4, `番号 ${ref} に入れられませんでした`);
          }
        };
        // 名指した欄に入れる値が項目に無い時は、入れたと返さずに断る
        if (userRef && !username && !email) refuse(4, "1Passwordの項目にIDがありません。IDは利用者が入れてください");
        if (passRef && !password) refuse(4, "1Passwordの項目にパスワードがありません。パスワードは利用者が入れてください");
        if (userRef) await put(userRef, username || email, true);
        if (passRef) await put(passRef, password, false);
        const named = userRef && passRef ? "IDとパスワード" : passRef ? "パスワード" : "ID";
        return `入れました: ${named} (名指した欄に入れました。値は出していません)`;
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
          refuse(4, "ログインの入力欄に入れられませんでした");
        }
        await f.evaluate(() => document.querySelectorAll("[data-ac-login]").forEach((el) => el.removeAttribute("data-ac-login"))).catch(() => {});
      }
      if (filled.size === 0) refuse(4, "ログインの入力欄が見つかりません。ログインの画面を開いてから打ち直してください");
      const what = filled.has("user") && filled.has("pass") ? "IDとパスワード" : filled.has("pass") ? "パスワード" : "ID";
      return `入れました: ${what} (値は出していません。ログインのボタンは look で番号を見て click で押す)`;
    },
    async stop() {
      setTimeout(() => ctx.close().finally(() => process.exit(0)), 50);
      return "ブラウザの窓を閉じました";
    },
  };

  // 頼まれた順に1つずつ行う。並べると画面の番号が入れ違う
  let queue = Promise.resolve();
  const server = createServer({ allowHalfOpen: true }, (sock) => {
    let buf = "";
    sock.setEncoding("utf8");
    sock.on("data", (d) => (buf += d));
    sock.on("end", () => {
      // 生きているかの確かめは待ちの列に並べない。ログインが1Passwordの承認を待つ間も、開いていると答える
      if (/^\{"cmd":"ping"\}$/.test(buf)) {
        sock.end(JSON.stringify({ code: 0, out: "ok" }));
        return;
      }
      queue = queue.then(async () => {
        let res;
        try {
          const req = JSON.parse(buf);
          buf = "";
          if (!handlers[req.cmd]) refuse(2, "知らない命令です");
          res = { code: 0, out: await handlers[req.cmd](req) };
        } catch (e) {
          res = e instanceof Refusal ? { code: e.code, err: e.message } : { code: 1, err: "命令が途中で失敗しました" };
        }
        sock.end(JSON.stringify(res));
      });
    });
    sock.on("error", () => {});
  });
  rmSync(sockPath, { force: true });
  server.listen(sockPath, () => chmodSync(sockPath, 0o600));
}

// ---- 命令を打った処理 (client) ------------------------------------------------------

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
  if (await running()) return "ブラウザは既に開いています";
  // 窓を開く Chromium が無ければ入れる (初回だけ)。検査の窓を出さない形は別の小さな Chromium を使うので見ない
  if (!headless) {
    const { chromium } = createRequire(join(nodeDir, "package.json"))("playwright-core");
    if (!existsSync(chromium.executablePath())) {
      process.stderr.write("account-cleanup: ブラウザ (Chromium) を入れます (初回だけ)\n");
      await new Promise((resolve) => spawn(process.execPath, [join(nodeDir, "node_modules/playwright-core/cli.js"), "install", "chromium"], { stdio: ["ignore", 2, 2] }).on("exit", resolve));
    }
  }
  const st = readState();
  if (st && st.pid) {
    try {
      process.kill(st.pid, "SIGTERM");
    } catch {
      // 既に閉じている
    }
  }
  rmSync(sockPath, { force: true });
  const child = spawn(process.execPath, [fileURLToPath(import.meta.url), "serve"], { detached: true, stdio: "ignore", env: process.env });
  child.unref();
  for (let i = 0; i < 600; i++) {
    await sleep(100);
    if (await running()) {
      writeFileSync(stateFile, JSON.stringify({ pid: child.pid }), { mode: 0o600 });
      return "ブラウザの窓を開きました";
    }
  }
  refuse(3, "ブラウザが起きませんでした。初めての時は、ブラウザ (Chromium) を入れてから打ち直してください");
}

async function stop() {
  let out = "ブラウザの窓を閉じました";
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
      // 既に閉じている
    }
  }
  rmSync(stateFile, { force: true });
  rmSync(sockPath, { force: true });
  return out;
}

// 1Passwordから項目を読む。常駐の処理の中だけで呼び、値をソケットの返事にもファイルにも出さない
async function readItem(id, account) {
  const args = ["item", "get", id, "--format", "json", "--reveal"];
  if (account) args.push("--account", account);
  const run = (a) => new Promise((resolve) => execFile(opBin, a, { maxBuffer: 8 * 1024 * 1024 }, (err, out) => resolve(err ? null : out)));
  let stdout = await run(args);
  if (!stdout) {
    // 1Passwordのアプリの承認が切れた後の最初の1回は、承認を待たずに失敗する。
    // signin でアプリの承認 (Touch ID) を待ってから、1回だけ読み直す
    await run(account ? ["signin", "--account", account] : ["signin"]);
    stdout = await run(args);
  }
  if (!stdout) refuse(5, "1Passwordから項目を読めませんでした。アプリの承認と、--account のアカウントを確かめてください");
  let item;
  try {
    item = JSON.parse(stdout);
  } catch {
    refuse(5, "1Passwordの項目を読み取れませんでした");
  }
  const fields = Array.isArray(item.fields) ? item.fields : [];
  const pick = (purpose) => (fields.find((f) => f.purpose === purpose) || {}).value || "";
  // IDをユーザー名の欄でなく、メールの欄 (purpose を持たない) に置いた項目もある
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
  if (!(await running())) refuse(2, "ブラウザが開いていません。先に browser.sh start を打ってください");
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
      if (!/^[A-Za-z0-9-]{1,64}$/.test(id || "")) refuse(2, "1Passwordの項目のIDを渡してください (plan.sh の「パスワード管理の項目」の欄に在る)");
      const at = rest.indexOf("--account");
      const opt = (name) => (rest.indexOf(name) >= 0 ? rest[rest.indexOf(name) + 1] : "");
      req = { cmd, id, account: at >= 0 ? rest[at + 1] : "", userRef: opt("--user-ref"), passRef: opt("--pass-ref"), site: opt("--site") };
      break;
    }
    default:
      refuse(2, "使い方は browser.sh の冒頭を見てください (start、open、look、click、clicktext、type、select、press、login、shot、stop)");
  }
  // login は1Passwordのアプリの承認を待つことがあるので長く待つ
  const res = await send(req, cmd === "login" ? 300000 : 120000);
  if (!res) refuse(1, "ブラウザから返事がありません。browser.sh stop と start を打ち直してください");
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
    res = e instanceof Refusal ? { code: e.code, err: e.message } : { code: 1, err: `${cmd} が途中で失敗しました` };
  }
  if (res.out) process.stdout.write(res.out + "\n");
  if (res.err) process.stderr.write("account-cleanup: " + res.err + "\n");
  process.exit(res.code);
}
