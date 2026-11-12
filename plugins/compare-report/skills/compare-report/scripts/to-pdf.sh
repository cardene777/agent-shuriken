#!/bin/bash
# Prints a report to PDF with a Chromium-based browser that is already installed.
# Usage: to-pdf.sh <report.html> [output.pdf]
# The browser runs headless with a throwaway profile, so it never touches the user's own browser profile,
# and the profile is removed when the script ends. Set COMPARE_REPORT_BROWSER to the browser's executable
# to choose one. Prints the path of the PDF.
set -euo pipefail

in="${1:-}"
if [ -z "$in" ] || [ ! -f "$in" ]; then
  echo "usage: to-pdf.sh <report.html> [output.pdf]" >&2
  exit 2
fi
in="$(cd "$(dirname "$in")" && pwd)/$(basename "$in")"
out="${2:-${in%.html}.pdf}"

find_browser() {
  local app cmd
  if [ -n "${COMPARE_REPORT_BROWSER:-}" ]; then
    [ -x "$COMPARE_REPORT_BROWSER" ] && { printf '%s\n' "$COMPARE_REPORT_BROWSER"; return 0; }
    command -v "$COMPARE_REPORT_BROWSER" 2>/dev/null && return 0
    return 1
  fi
  for app in \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium" \
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
    "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"; do
    [ -x "$app" ] && { printf '%s\n' "$app"; return 0; }
  done
  for cmd in google-chrome google-chrome-stable chromium chromium-browser microsoft-edge brave-browser; do
    command -v "$cmd" 2>/dev/null && return 0
  done
  return 1
}

if ! browser="$(find_browser)"; then
  echo "No Chromium-based browser was found. Install Chrome, Chromium, Edge, or Brave, or set COMPARE_REPORT_BROWSER to its executable" >&2
  exit 3
fi

profile="$(mktemp -d "${TMPDIR:-/tmp}/compare-report-browser.XXXXXX")"
trap 'rm -rf "$profile"' EXIT
url="$(python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).as_uri())' "$in")"
rm -f "$out"

"$browser" --headless --disable-gpu --no-first-run --no-default-browser-check \
  --disable-extensions --disable-background-networking \
  --user-data-dir="$profile" --no-pdf-header-footer --print-to-pdf-no-header \
  --print-to-pdf="$out" "$url" >/dev/null 2>&1 || true

if [ ! -s "$out" ]; then
  echo "The browser did not write $out. Browser used: $browser" >&2
  exit 4
fi
printf '%s\n' "$out"
