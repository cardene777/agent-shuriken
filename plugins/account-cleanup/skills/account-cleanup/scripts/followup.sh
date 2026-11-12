#!/bin/bash
# Record things the user has to clean up later by themselves, such as payment methods that could not be removed during deletion.
# Each record is one line in followups.tsv in the data directory (readable only by the user); cleanup.sh keeps it.
# The list is shown as a page in the user's browser. Service names are never listed in the chat.
#
# Usage:
#   followup.sh add <key> <what is left>   Add one line (e.g. followup.sh add example.com "A Visa card is still saved as a payment method and cannot be removed")
#   followup.sh page                       Build the list page (followups.html) and print the count and its path
#   followup.sh done <key>                 Remove the lines the user has cleaned up

. "$(dirname "$0")/common.sh"
need jq "Install jq."

FOLLOWUPS_PAGE="$DATA_DIR/followups.html"

# Tabs and newlines would break the one-record-per-line format, so turn them into spaces
flat() { printf '%s' "$1" | tr '\t\n\r' '   '; }

case "${1:-}" in
  add)
    if [ $# -lt 3 ]; then
      echo "Usage: followup.sh add <key> <what is left>" >&2
      exit 2
    fi
    ensure_data_dir
    printf '%s\t%s\t%s\n' "$(date +%Y-%m-%d)" "$(flat "$2")" "$(flat "${*:3}")" >> "$FOLLOWUPS_FILE"
    chmod 600 "$FOLLOWUPS_FILE"
    echo "Recorded for later: $(flat "$2")"
    ;;
  done)
    if [ $# -lt 2 ] || [ ! -f "$FOLLOWUPS_FILE" ]; then
      echo "Usage: followup.sh done <key>" >&2
      exit 2
    fi
    tmp=$(mktemp "$DATA_DIR/followups.XXXXXX")
    awk -F '\t' -v k="$2" '$2 != k' "$FOLLOWUPS_FILE" > "$tmp" || true
    mv "$tmp" "$FOLLOWUPS_FILE"
    chmod 600 "$FOLLOWUPS_FILE"
    echo "Removed from the follow-up list: $2"
    ;;
  page)
    ensure_data_dir
    [ -f "$FOLLOWUPS_FILE" ] || : > "$FOLLOWUPS_FILE"
    count=$(grep -c . "$FOLLOWUPS_FILE" || true)
    rows=$(mktemp "$DATA_DIR/followups-rows.XXXXXX")
    trap 'rm -f "$rows"' EXIT
    jq -R -r 'split("\t") | "<tr><td>\(.[0] // "" | @html)</td><td>\(.[1] // "" | @html)</td><td>\(.[2:] | join(" ") | @html)</td></tr>"' "$FOLLOWUPS_FILE" > "$rows"
    tmp=$(mktemp "$DATA_DIR/followups-page.XXXXXX")
    # The page template has the user's list on its own __ROWS__ line, and the count (a number) in __COUNT__
    awk -v rowsfile="$rows" -v count="$count" '
      $0 == "__ROWS__" { while ((getline line < rowsfile) > 0) print line; next }
      { gsub(/__COUNT__/, count); print }' "$SKILL_DIR/templates/followups.html" > "$tmp"
    mv "$tmp" "$FOLLOWUPS_PAGE"
    chmod 600 "$FOLLOWUPS_PAGE"
    echo "Things to clean up later: ${count}"
    echo "$FOLLOWUPS_PAGE"
    ;;
  *)
    echo "Usage: followup.sh add <key> <what is left> | page | done <key>" >&2
    exit 2
    ;;
esac
