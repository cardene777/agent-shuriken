#!/bin/bash
# Prints a report to PDF with a Chromium-based browser that is already installed.
# Usage: to-pdf.sh <report.html> [output.pdf]
# The browser runs headless with a throwaway profile, so it never touches the user's own browser profile,
# and the profile is removed when the script ends. Set COMPARE_REPORT_BROWSER to the browser's executable
# to choose one. Prints the path of the PDF, which is readable only by the user, like report.html.
#
# The PDF contents give the page each section starts on. The first print is read with toc-pages.py
# for the page of every contents entry; a hidden copy of the report next to it gets the pages and is
# printed again, and that PDF replaces the first one only when it shows each section on the same page.
# The copy is removed afterwards, and report.html is never changed. When the pages cannot be found,
# the first PDF, with titles only, is kept and one line on standard error says why.
set -euo pipefail
umask 077
here="$(cd "$(dirname "$0")" && pwd)"

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
copy=""
trap 'rm -rf "$profile"; [ -z "$copy" ] || rm -f "$copy"' EXIT
rm -f "$out"

# print_pdf <html> <pdf>
print_pdf() {
  local url
  url="$(python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).as_uri())' "$1")"
  "$browser" --headless --disable-gpu --no-first-run --no-default-browser-check \
    --disable-extensions --disable-background-networking \
    --user-data-dir="$profile" --no-pdf-header-footer --print-to-pdf-no-header \
    --print-to-pdf="$2" "$url" >/dev/null 2>&1 || true
}

print_pdf "$in" "$out"
if [ ! -s "$out" ]; then
  echo "The browser did not write $out. Browser used: $browser" >&2
  exit 4
fi

# number_contents: prints the copy with the pages until its pages hold, at most twice.
# Prints the reason and returns 1 when they cannot be found or keep moving.
number_contents() {
  local pdf="$out" round
  python3 "$here/toc-pages.py" pages "$in" "$pdf" > "$profile/pages" || { cat "$profile/pages"; return 1; }
  for round in 1 2; do
    [ -z "$copy" ] || rm -f "$copy"
    copy="$(python3 "$here/toc-pages.py" copy "$in" "$profile/pages")" || { printf '%s\n' "$copy"; copy=""; return 1; }
    pdf="$profile/numbered-$round.pdf"
    print_pdf "$copy" "$pdf"
    [ -s "$pdf" ] || { echo "the browser did not print the copy with the pages"; return 1; }
    python3 "$here/toc-pages.py" pages "$copy" "$pdf" > "$profile/check" || { cat "$profile/check"; return 1; }
    if cmp -s "$profile/pages" "$profile/check"; then
      mv -f "$pdf" "$out"
      return 0
    fi
    mv -f "$profile/check" "$profile/pages"
  done
  echo "the sections moved to other pages each time the numbers were added"
  return 1
}

# Run in this shell, not in $(...), so that the trap sees the copy and removes it.
if ! number_contents > "$profile/reason"; then
  reason="$(head -n 1 "$profile/reason")"
  echo "The PDF contents show titles only: ${reason:-the pages could not be found}" >&2
fi
printf '%s\n' "$out"
