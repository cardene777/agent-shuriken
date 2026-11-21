#!/bin/bash
# Record things the user has to clean up later by themselves, such as payment methods that could not be removed during deletion.
# Each record is one line in followups.tsv in the data directory (readable only by the user); cleanup.sh keeps it.
# A line holds the date, the key, what is left, and the service name taken from the candidates when it was recorded.
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
    # The service name the sheet shows for the key goes with the record. It can be read only now:
    # cleanup.sh removes the candidates, and a deleted account is not among the next round's candidates
    name=""
    if [ -f "$MATCHED_FILE" ]; then
      name=$(jq -r --arg k "$2" 'first(.[] | select(.key == $k) | (.service // .names[0] // empty)) // empty' "$MATCHED_FILE" 2>/dev/null) || name=""
    fi
    printf '%s\t%s\t%s\t%s\n' "$(date +%Y-%m-%d)" "$(flat "$2")" "$(flat "${*:3}")" "$(flat "$name")" >> "$FOLLOWUPS_FILE"
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
    # Each record is the date, the key, what is left, and the service name (records written before
    # the name was kept have none, and show the key). The key goes under the name only when it says
    # something the name does not, the same rule as on the candidate sheet
    jq -R -r 'split("\t") as $f
      | ($f[1] // "") as $key
      | (if ($f[3] // "") != "" then $f[3] else $key end) as $name
      | ($name | ascii_downcase) as $n | ($key | ascii_downcase) as $k
      | (if $k != "" and $n != $k and ($n | endswith("." + $k) | not) then "<small>\($key | @html)</small>" else "" end) as $under
      | "<tr><td>\($f[0] // "" | @html)</td><td><span class=\"service\">\($name | @html)</span>\($under)</td><td>\($f[2] // "" | @html)</td></tr>"' "$FOLLOWUPS_FILE" > "$rows"
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
