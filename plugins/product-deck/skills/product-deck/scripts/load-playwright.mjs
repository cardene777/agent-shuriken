/* Resolves Playwright for the scripts that drive a browser.

   The plugin ships no node_modules, so the browser comes from the user's project:
   PLAYWRIGHT_FROM names a folder from which `@playwright/test` resolves.
   Without PLAYWRIGHT_FROM, the usual resolution from this folder is tried.
   When neither finds it, the script stops with exit 2 and names PLAYWRIGHT_FROM,
   before it opens a page or writes a file. */

import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";

export async function loadChromium() {
  const from = process.env.PLAYWRIGHT_FROM;
  try {
    let mod;
    if (from === undefined) {
      mod = await import("@playwright/test");
    } else {
      const require = createRequire(from.endsWith("/") ? from : `${from}/`);
      mod = await import(pathToFileURL(require.resolve("@playwright/test")).href);
    }
    /* A CommonJS module has no named exports; its contents are in `default`. */
    return mod.chromium ?? mod.default.chromium;
  } catch (error) {
    const where = from === undefined ? "PLAYWRIGHT_FROM is not set" : `PLAYWRIGHT_FROM=${from}`;
    console.error(`Playwright was not found (${where}).`);
    console.error("Set PLAYWRIGHT_FROM to a project folder where @playwright/test is installed.");
    console.error(`error=${error instanceof Error ? error.message : String(error)}`);
    process.exit(2);
  }
}
