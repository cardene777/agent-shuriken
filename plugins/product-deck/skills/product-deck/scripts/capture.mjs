#!/usr/bin/env node
/* Takes a screenshot of one page of the product.

   Usage
     node capture.mjs --url <URL> --out <path.png> [--width 1440] [--height 900] [--wait-for <CSS selector>]

   Playwright is resolved from PLAYWRIGHT_FROM (see load-playwright.mjs). */

import { mkdir, stat } from "node:fs/promises";
import { dirname } from "node:path";
import { loadChromium } from "./load-playwright.mjs";

const DEFAULT_WIDTH = 1440;
const DEFAULT_HEIGHT = 900;
const WAIT_TIMEOUT_MS = 30_000;
/* How long to wait after the DOM arrives when there is no `--wait-for`, so that a single page app settles. */
const SETTLE_MS = 4_000;

function usage() {
  return "node capture.mjs --url <URL> --out <path.png> [--width 1440] [--height 900] [--wait-for <CSS selector>]";
}

function parsePositiveInteger(value, option) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error(`${option} must be a positive integer: ${value}`);
  }
  return parsed;
}

function parseArgs(argv) {
  const values = new Map();
  for (let index = 0; index < argv.length; index += 2) {
    const option = argv[index];
    const value = argv[index + 1];
    if (!["--url", "--out", "--width", "--height", "--wait-for"].includes(option) || value === undefined) {
      throw new Error(`cannot read the arguments: ${argv.slice(index).join(" ")}\n${usage()}`);
    }
    values.set(option, value);
  }

  const url = values.get("--url");
  const out = values.get("--out");
  if (url === undefined || out === undefined) {
    throw new Error(`--url and --out are required\n${usage()}`);
  }

  return {
    url,
    out,
    width: parsePositiveInteger(values.get("--width") ?? String(DEFAULT_WIDTH), "--width"),
    height: parsePositiveInteger(values.get("--height") ?? String(DEFAULT_HEIGHT), "--height"),
    waitFor: values.get("--wait-for"),
  };
}

async function describePage(page) {
  if (page === undefined) return "no browser page was opened";
  try {
    return JSON.stringify(await page.evaluate(() => ({
      url: window.location.href,
      title: document.title,
      readyState: document.readyState,
      bodyText: document.body?.innerText.trim().slice(0, 500) ?? "",
    })));
  } catch (error) {
    return `could not read the page state: ${error instanceof Error ? error.message : String(error)}`;
  }
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const chromium = await loadChromium();
  const startedAt = Date.now();
  let browser;
  let page;

  try {
    browser = await chromium.launch({ headless: true });
    page = await browser.newPage({ viewport: { width: options.width, height: options.height } });
    /* Do not wait for `networkidle`: a single page app keeps talking to its server and never
       reaches it, and a real admin screen timed out after 30 seconds that way. Wait a fixed
       time after the DOM arrives, or for the element given with `--wait-for`. */
    await page.goto(options.url, { waitUntil: "domcontentloaded", timeout: WAIT_TIMEOUT_MS });
    if (options.waitFor === undefined) {
      await page.waitForTimeout(SETTLE_MS);
    } else {
      await page.waitForSelector(options.waitFor, {
        state: "visible",
        timeout: WAIT_TIMEOUT_MS,
      });
    }

    await mkdir(dirname(options.out), { recursive: true });
    await page.screenshot({ path: options.out });
    const file = await stat(options.out);
    console.log(`captured=${options.out}`);
    console.log(`bytes=${file.size}`);
    if (options.waitFor === undefined) {
      console.log("warning=no --wait-for, so the content of the page was not checked");
    }
  } catch (error) {
    const elapsedMs = Date.now() - startedAt;
    const state = await describePage(page);
    console.error(`capture failed: URL=${options.url}`);
    console.error(`waited_ms=${elapsedMs}`);
    console.error(`last_state=${state}`);
    console.error(`error=${error instanceof Error ? error.message : String(error)}`);
    process.exitCode = 1;
  } finally {
    await browser?.close();
  }
}

main().catch((error) => {
  console.error(`error=${error instanceof Error ? error.message : String(error)}`);
  process.exitCode = 1;
});
