#!/bin/bash
# Write one run of a motion-diagram picture as an MP4 video and a GIF, and its finished state as a
# PNG image.
#
# Usage:
#   export.sh <spec.json> --out <folder> [--width <px>] [--fps <frames per second>]
#
# The spec is checked and rendered first (motion_diagram.py), then a headless browser opens the
# page, draws each moment of the run, and ffmpeg joins the frames. The files are named after the
# spec: <name>.mp4, <name>.gif, and <name>.png.
#
# Needs Node.js 20 or later. On first use, playwright-core is installed with npm into node/ of the
# data folder (~/.local/share/motion-diagram, or $MOTION_DIAGRAM_DATA), and ffmpeg-static as well
# when no ffmpeg is on PATH. The browser is the one browser.py finds; when there is none,
# Playwright's chrome-headless-shell is downloaded into Playwright's cache.
#
# Exit codes: 0 written, 1 a step failed (the reason is printed), 2 called wrongly.
set -u

PLAYWRIGHT_VERSION=1.65.0
FFMPEG_STATIC_VERSION=5.3.0
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${MOTION_DIAGRAM_DATA:-$HOME/.local/share/motion-diagram}"
NODE_DIR="$DATA_DIR/node"

usage() { sed -n '5,6p' "$0" | sed 's/^# *//' >&2; exit 2; }

spec="" out="" width=1000 fps=15
while [ $# -gt 0 ]; do
  case "$1" in
    --out) out="${2:-}"; shift 2 ;;
    --width) width="${2:-}"; shift 2 ;;
    --fps) fps="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    -*) echo "motion-diagram: unknown option $1" >&2; usage ;;
    *) spec="$1"; shift ;;
  esac
done
[ -n "$spec" ] && [ -n "$out" ] || usage
[ -f "$spec" ] || { echo "motion-diagram: no spec at $spec" >&2; exit 2; }
case "$width$fps" in *[!0-9]*) echo "motion-diagram: --width and --fps take whole numbers" >&2; exit 2 ;; esac

if ! command -v node > /dev/null 2>&1; then
  echo "motion-diagram: export needs Node.js 20 or later to drive the browser. Install Node.js from nodejs.org, then run export again. The page itself (render) and check work without it." >&2
  exit 1
fi
major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
if [ "$major" -lt 20 ]; then
  echo "motion-diagram: export needs Node.js 20 or later, and this is Node.js $major. Install a newer Node.js from nodejs.org, then run export again." >&2
  exit 1
fi

name="$(basename "$spec")"; name="${name%.json}"
work="$(mktemp -d "${TMPDIR:-/tmp}/motion-diagram-export.XXXXXX")"
trap 'rm -rf "$work"' EXIT

python3 "$HERE/motion_diagram.py" render "$spec" --out "$work/page.html" > "$work/render.out" 2>&1 || { cat "$work/render.out" >&2; exit 1; }

packages=()
[ -f "$NODE_DIR/node_modules/playwright-core/package.json" ] || packages+=("playwright-core@$PLAYWRIGHT_VERSION")
ffmpeg="$(command -v ffmpeg || true)"
if [ -z "$ffmpeg" ] && [ ! -f "$NODE_DIR/node_modules/ffmpeg-static/package.json" ]; then
  packages+=("ffmpeg-static@$FFMPEG_STATIC_VERSION")
fi
if [ "${#packages[@]}" -gt 0 ]; then
  command -v npm > /dev/null 2>&1 || { echo "motion-diagram: npm, which comes with Node.js, was not found" >&2; exit 1; }
  mkdir -p "$NODE_DIR" && chmod 700 "$DATA_DIR"
  echo "motion-diagram: installing ${packages[*]} into $NODE_DIR (first run only)" >&2
  npm install --prefix "$NODE_DIR" --no-audit --no-fund "${packages[@]}" > /dev/null || { echo "motion-diagram: npm could not install ${packages[*]}" >&2; exit 1; }
fi
if [ -z "$ffmpeg" ]; then
  ffmpeg="$(node -e 'process.stdout.write(require(process.argv[1]) || "")' "$NODE_DIR/node_modules/ffmpeg-static" 2>/dev/null || true)"
  [ -x "$ffmpeg" ] || { echo "motion-diagram: no ffmpeg on PATH and ffmpeg-static has no binary; install ffmpeg, then run export again" >&2; exit 1; }
fi

browser="$(python3 "$HERE/browser.py" path 2>/dev/null || true)"
if [ -z "$browser" ]; then
  echo "motion-diagram: no browser found; downloading Playwright's headless browser" >&2
  node "$NODE_DIR/node_modules/playwright-core/cli.js" install chromium-headless-shell >&2 || exit 1
  browser="$(python3 "$HERE/browser.py" path 2>/dev/null || true)"
  [ -n "$browser" ] || { echo "motion-diagram: the headless browser could not be found after the download" >&2; exit 1; }
fi

mkdir -p "$work/frames" "$out"
NODE_PATH="$NODE_DIR/node_modules" node "$HERE/export.mjs" "$work/page.html" "$work/frames" "$browser" "$width" "$fps" "$NODE_DIR/node_modules/playwright-core/index.js" || exit 1

"$ffmpeg" -loglevel error -y -framerate "$fps" -i "$work/frames/frame-%05d.png" \
  -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -c:v libx264 -pix_fmt yuv420p -movflags +faststart "$work/$name.mp4" || { echo "motion-diagram: ffmpeg could not write the video" >&2; exit 1; }
"$ffmpeg" -loglevel error -y -framerate "$fps" -i "$work/frames/frame-%05d.png" \
  -vf "scale=960:-2:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" "$work/$name.gif" || { echo "motion-diagram: ffmpeg could not write the GIF" >&2; exit 1; }
cp "$work/frames/end.png" "$work/$name.png"

for ext in mp4 gif png; do mv "$work/$name.$ext" "$out/$name.$ext"; done
echo "wrote $out/$name.mp4, $out/$name.gif, and $out/$name.png"
