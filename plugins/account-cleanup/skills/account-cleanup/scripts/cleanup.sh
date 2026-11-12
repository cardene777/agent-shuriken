#!/bin/bash
# After the cleanup is finished, remove the candidates, the candidate sheet and the saved region.
# The additions list (deletion pages found by search) holds no personal data, so it is kept and used next time.
# The follow-up list (followups.tsv) is kept because the user needs it until they finish cleaning up.
#
# Usage: cleanup.sh

. "$(dirname "$0")/common.sh"

removed=0
for f in "$CANDIDATES_FILE" "$MANUAL_FILE" "$MATCHED_FILE" "$SHEET_FILE" "$DESCRIPTIONS_FILE" "$REGION_FILE"; do
  if [ -e "$f" ]; then
    rm -f "$f"
    removed=$((removed + 1))
  fi
done
# The browser profile used for deletion holds the sites that are still signed in, so close the window and then remove it
if [ -d "$BROWSER_PROFILE_DIR" ]; then
  if [ -f "$DATA_DIR/browser-state.json" ]; then
    "$SCRIPT_DIR/browser.sh" stop >/dev/null 2>&1 || true
  fi
  rm -rf "$BROWSER_PROFILE_DIR"
  removed=$((removed + 1))
fi
echo "Removed ${removed} candidate and sheet files."
if [ -s "$FOLLOWUPS_FILE" ]; then
  echo "Kept the follow-up list: $FOLLOWUPS_FILE"
fi
