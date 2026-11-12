#!/bin/bash
# Drive the browser used for deleting accounts. The implementation is browser.mjs in the same directory.
# The browser opens a window on the user's machine, and the AI reads, clicks and types in it through this command.
# login fills in the username and password from 1Password directly into the fields and never passes them to the AI or to the output.
#
# Usage:
#   browser.sh start                         Open the browser window
#   browser.sh open <URL>                    Open a page
#   browser.sh look                          Print the page text and the clickable elements and fields, numbered (field values are never printed)
#   browser.sh click <number>                Click
#   browser.sh clicktext <text> [--after <text>]
#                                            Click an element that has no number, by its text on the page
#                                            --after <text> only matches elements after that text (when each row has the same button)
#   browser.sh type <number> <text>          Type text into a field (refuses password fields)
#   browser.sh select <number> <value>       Choose a value in a select field
#   browser.sh press <key>                   Press a key (e.g. Enter)
#   browser.sh login <1Password item ID> [--account <account>] [--user-ref <number>] [--pass-ref <number>] [--site <domain>]
#                                            Fill in the username and password only when the page's domain matches the item's URL
#                                            --user-ref <number> and --pass-ref <number> name the fields to fill
#                                            --site passes the official domain you looked up, only when the item has no URL
#   browser.sh shot <path to save>           Save a screenshot of the page
#   browser.sh stop                          Close the window
#
# On first use, Playwright (the tool that drives the browser) is installed into node/ in the data directory.

. "$(dirname "$0")/common.sh"
need node "Install Node.js."

PLAYWRIGHT_VERSION=1.65.0
export ACCOUNT_CLEANUP_NODE_DIR="${ACCOUNT_CLEANUP_NODE_DIR:-$DATA_DIR/node}"
export ACCOUNT_CLEANUP_DATA_DIR="$DATA_DIR"
ensure_data_dir

if [ ! -f "$ACCOUNT_CLEANUP_NODE_DIR/node_modules/playwright-core/package.json" ]; then
  mkdir -p "$ACCOUNT_CLEANUP_NODE_DIR"
  echo "account-cleanup: installing the tool that drives the browser (first run only)" >&2
  if command -v pnpm >/dev/null 2>&1; then
    (cd "$ACCOUNT_CLEANUP_NODE_DIR" && pnpm add "playwright-core@$PLAYWRIGHT_VERSION" >/dev/null) || exit 1
  else
    need npm "npm, which comes with Node.js, was not found."
    npm install --prefix "$ACCOUNT_CLEANUP_NODE_DIR" --no-audit --no-fund "playwright-core@$PLAYWRIGHT_VERSION" >/dev/null || exit 1
  fi
fi

exec node "$SCRIPT_DIR/browser.mjs" "$@"
