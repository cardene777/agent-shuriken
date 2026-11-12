#!/bin/bash
# Build the HTML sheet for choosing which accounts to delete from the matched candidates, and print its path.
# The sheet loads nothing from outside (CSP blocks it, and it has no external images or scripts).
# So that a `<` in a candidate name cannot break out of the embedded data, <, > and & are escaped as <, > and & before embedding.
#
# Usage: build-sheet.sh [matched.json]

. "$(dirname "$0")/common.sh"
need jq "Install jq."

src=${1:-$MATCHED_FILE}
if [ ! -f "$src" ]; then
  echo "account-cleanup: no matched candidates: $src" >&2
  exit 2
fi

ensure_data_dir
payload=$(mktemp "$DATA_DIR/sheet-data.XXXXXX")
trap 'rm -f "$payload"' EXIT
jq -c . "$src" | sed -e 's/</\\u003c/g' -e 's/>/\\u003e/g' -e 's/&/\\u0026/g' > "$payload"

tmp=$(mktemp "$DATA_DIR/sheet.XXXXXX")
awk -v datafile="$payload" '
  $0 == "__DATA__" { while ((getline line < datafile) > 0) print line; next }
  { print }' "$SKILL_DIR/templates/sheet.html" > "$tmp"
mv "$tmp" "$SHEET_FILE"
chmod 600 "$SHEET_FILE"
printf '%s\n' "$SHEET_FILE"
