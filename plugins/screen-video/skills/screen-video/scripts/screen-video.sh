#!/usr/bin/env bash
# Entry point of the screen-video skill. The commands are in screen_video.mjs next to this file.
#
# Usage:
#   screen-video.sh setup                                   Install Playwright, its headless browser, and ffmpeg into the data folder
#   screen-video.sh doctor [--json]                         Say which ffmpeg and Playwright are used
#   screen-video.sh inspect <flow> [--path <path>]          List the headings, buttons, links, and fields of a page
#   screen-video.sh check <flow>                            Check a flow file and list the steps that send something or pay
#   screen-video.sh rehearse <flow> [--out <dir>]           Run the flow without recording and write the storyboard
#   screen-video.sh voices <flow> [--out <dir>]             Make the flow's narration (installs the local voice engine once)
#   screen-video.sh record <flow> [--out <dir>] [--confirm-effects]
#                                                           Record the flow and make the videos
#   screen-video.sh remake <flow> [--out <dir>]             Make the videos again from the last recording, in the flow's current look
#   screen-video.sh compare <flow> [--out <dir>] [--before <dir>]
#                                                           Show the plain and the edited video side by side for each point
#   screen-video.sh login <flow> [--until <text>] [--start <address>]
#                                                           Log in by hand once and save the login for the flow, keeping earlier ones
#   screen-video.sh logout <flow>                           Remove the flow's saved login
#   screen-video.sh scenes <recording> [--out <dir>]        Find the scenes of a recording the user made
#   screen-video.sh render <recording> [--out <dir>]        Caption and edit that recording from captions.json
#
# The data folder is $SCREEN_VIDEO_HOME, or $XDG_DATA_HOME/screen-video, or ~/.local/share/screen-video.
# On first use, playwright-core and ffmpeg-static are installed into node/ there (or $SCREEN_VIDEO_NODE_DIR).
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PLAYWRIGHT_VERSION=1.65.0
FFMPEG_STATIC_VERSION=5.3.0
DATA_DIR="${SCREEN_VIDEO_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/screen-video}"
NODE_DIR="${SCREEN_VIDEO_NODE_DIR:-$DATA_DIR/node}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "screen-video: $2" >&2; exit 1; }; }
need node "Node.js 20 or later is needed. Install it from your package manager or nodejs.org."
node -e 'const [a,b]=process.versions.node.split(".").map(Number); process.exit(a>20||(a===20&&b>=11)?0:1)' \
  || { echo "screen-video: Node.js 20.11 or later is needed (found $(node --version))." >&2; exit 1; }

installed() {
  [ -f "$NODE_DIR/node_modules/playwright-core/package.json" ] && [ -f "$NODE_DIR/node_modules/ffmpeg-static/package.json" ]
}

install_runtime() {
  mkdir -p "$NODE_DIR" && chmod 700 "$DATA_DIR" 2>/dev/null
  echo "screen-video: installing Playwright and ffmpeg into $NODE_DIR (first run only)" >&2
  local packages=("playwright-core@$PLAYWRIGHT_VERSION" "ffmpeg-static@$FFMPEG_STATIC_VERSION")
  if command -v pnpm >/dev/null 2>&1 && (cd "$NODE_DIR" && pnpm add --allow-build=ffmpeg-static "${packages[@]}" >/dev/null 2>&1); then
    :
  else
    need npm "npm, which comes with Node.js, was not found."
    npm install --prefix "$NODE_DIR" --no-audit --no-fund "${packages[@]}" >/dev/null || exit 1
  fi
}

finish_runtime() {
  # ffmpeg-static downloads its binary in an install script, which some package managers skip
  local static="$NODE_DIR/node_modules/ffmpeg-static"
  if [ -f "$static/install.js" ] && ! node -e 'process.exit(require("node:fs").existsSync(require(process.argv[1]))?0:1)' "$static" 2>/dev/null; then
    (cd "$static" && node install.js >/dev/null) || echo "screen-video: could not download ffmpeg; an ffmpeg on PATH with libx264 will be used instead" >&2
  fi
  echo "screen-video: installing the headless browser if it is missing" >&2
  node "$NODE_DIR/node_modules/playwright-core/cli.js" install chromium-headless-shell >&2 || exit 1
}

if [ "${1:-}" = "setup" ]; then
  if ! installed; then install_runtime; fi
  finish_runtime
  echo "screen-video: ready ($NODE_DIR)"
  exit 0
fi

if ! installed; then
  install_runtime
  finish_runtime
fi

export SCREEN_VIDEO_HOME="$DATA_DIR" SCREEN_VIDEO_NODE_DIR="$NODE_DIR"
exec node "$HERE/screen_video.mjs" "$@"
