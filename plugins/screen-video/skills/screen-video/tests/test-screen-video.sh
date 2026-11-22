#!/usr/bin/env bash
# Tests for the screen-video skill. The checks live in checks.mjs next to this file.
#
# They serve a sample site on 127.0.0.1 and use a throwaway project and data folder, so no real site,
# account, or video folder is touched. The browser and ffmpeg come from an installed runtime:
# SCREEN_VIDEO_TEST_NODE_DIR, or the default data folder's node/ after `screen-video.sh setup`.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
command -v node >/dev/null 2>&1 || { echo "FAIL  Node.js is needed to run the checks"; echo "0 passed, 1 failed (1 ran)"; exit 1; }
exec node "$HERE/checks.mjs"
