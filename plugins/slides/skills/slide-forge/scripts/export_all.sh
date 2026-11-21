#!/bin/bash
# export_all.sh: exports a slide-forge deck folder to PowerPoint, HTML, and PDF.
# Implements references/export-recipes.md.
#
# Usage:
#   bash export_all.sh <deck-folder> [--theme deep-navy|light-mono|mono-accent|vibrant-pop]
#
# Reads, in the deck folder:
#   content.json     written by the edit page's Export JSON button
#   edit-mode.html   written by inject_edit_mode.py
#
# Writes, in the same folder, where <deck> is the folder's name:
#   <deck>.pptx  build_pptx.py, run through uv with python-pptx and Pillow
#   <deck>.html  export_html_final.py, the edit page without its toolbar
#   <deck>.pdf   export_pdf.py, run through uv with Playwright; skipped, with how to install the
#                browser, when Playwright's Chromium is not installed
#
# uv fetches the packages into its cache for this run only, so nothing is installed into the
# user's Python. Without uv, this script writes nothing, says how to install uv, and exits 1.
# It never downloads Playwright's browser.

set -euo pipefail

if ! command -v uv >/dev/null 2>&1; then
  echo "ERROR: uv is not installed, so nothing was written." >&2
  echo "slide-forge runs python-pptx, Pillow, and Playwright through uv for one run, without installing them into your Python." >&2
  echo "Install uv, for example with 'brew install uv' or 'pipx install uv', then run this command again." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "Usage: bash $(basename "$0") <deck-folder> [--theme deep-navy|light-mono|mono-accent|vibrant-pop]"
  echo "The deck folder holds content.json and edit-mode.html."
}

if [ "$#" -lt 1 ]; then
  usage >&2
  exit 1
fi

DECK_DIR="${1%/}"
shift
THEME="deep-navy"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --theme)
      [ "$#" -ge 2 ] || { echo "ERROR: --theme needs a value" >&2; exit 1; }
      THEME="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [ ! -d "$DECK_DIR" ]; then
  echo "ERROR: deck folder not found: $DECK_DIR" >&2
  exit 1
fi

CONTENT_JSON="$DECK_DIR/content.json"
EDIT_HTML="$DECK_DIR/edit-mode.html"
DECK_NAME="$(basename "$DECK_DIR")"
OUT_PPTX="$DECK_DIR/$DECK_NAME.pptx"
OUT_PDF="$DECK_DIR/$DECK_NAME.pdf"
OUT_HTML="$DECK_DIR/$DECK_NAME.html"

if [ ! -f "$CONTENT_JSON" ]; then
  echo "ERROR: content.json not found: $CONTENT_JSON" >&2
  exit 1
fi

echo "=== PowerPoint ==="
uv run --with python-pptx --with Pillow --no-project python3 "$SCRIPT_DIR/build_pptx.py" "$CONTENT_JSON" "$OUT_PPTX" --theme "$THEME"

echo ""
echo "=== HTML ==="
if [ -f "$EDIT_HTML" ]; then
  uv run --no-project python3 "$SCRIPT_DIR/export_html_final.py" "$EDIT_HTML" "$OUT_HTML"
else
  echo "WARN: edit-mode.html not found, so the HTML was skipped" >&2
fi

echo ""
echo "=== PDF ==="
if [ -f "$OUT_HTML" ]; then
  pdf_status=0
  uv run --with playwright --no-project python3 "$SCRIPT_DIR/export_pdf.py" "$OUT_HTML" "$OUT_PDF" || pdf_status=$?
  case "$pdf_status" in
    0) ;;
    3) echo "WARN: the PDF was skipped; the PowerPoint and HTML files are written." >&2 ;;
    *) echo "ERROR: the PDF export failed (exit $pdf_status); the PowerPoint and HTML files are written." >&2; exit 1 ;;
  esac
else
  echo "WARN: no public HTML to print, so the PDF was skipped" >&2
fi

echo ""
echo "=== Done ==="
for out in "$OUT_PPTX" "$OUT_HTML" "$OUT_PDF"; do
  if [ -f "$out" ]; then
    echo "$out"
  fi
done
