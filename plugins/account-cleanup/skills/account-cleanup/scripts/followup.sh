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
    today=${ACCOUNT_CLEANUP_TODAY:-$(date +%Y-%m-%d)}
    rows=$(mktemp "$DATA_DIR/followups-rows.XXXXXX")
    cards=$(mktemp "$DATA_DIR/followups-cards.XXXXXX")
    trap 'rm -f "$rows" "$cards"' EXIT
    # Each record is the date, the key, what is left, and the service name (records written before
    # the name was kept have none, and show the key). The key goes under the name only when it says
    # something the name does not, the same rule as on the candidate sheet. The newest record comes
    # first, and of two records from one day the one recorded later
    records='split("\n") | map(select(length > 0) | split("\t")) | to_entries | sort_by(.value[0] // "", .key) | reverse | .[].value
      | . as $f | ($f[1] // "") as $key
      | (if ($f[3] // "") != "" then $f[3] else $key end) as $name
      | ($name | ascii_downcase) as $n | ($key | ascii_downcase) as $k
      | {date: ($f[0] // "" | @html), left: ($f[2] // "" | @html),
         name: "<span class=\"service\">\($name | @html)</span>\(if $k != "" and $n != $k and ($n | endswith("." + $k) | not) then "<small>\($key | @html)</small>" else "" end)"}'
    jq -R -s -r "$records"' | "<tr><th scope=\"row\">\(.name)</th><td>\(.left)</td><td>\(.date)</td></tr>"' "$FOLLOWUPS_FILE" > "$rows"
    # Below 600px the page shows the same records as cards
    jq -R -s -r "$records"' | "<li class=\"card\"><h2>\(.name)</h2><dl><dt data-i18n=\"colLeft\">What&#39;s left</dt><dd>\(.left)</dd><dt data-i18n=\"colDate\">Recorded</dt><dd>\(.date)</dd></dl></li>"' "$FOLLOWUPS_FILE" > "$cards"
    tmp=$(mktemp "$DATA_DIR/followups-page.XXXXXX")
    # The page template has the user's records on their own __ROWS__ and __CARDS__ lines, the count (a
    # number) in __COUNT__, and the date in __DATE__. It keeps the part between <!-- list --> and
    # <!-- /list --> when there are records, and the part between <!-- empty --> and <!-- /empty --> when there are none
    awk -v rowsfile="$rows" -v cardsfile="$cards" -v count="$count" -v today="$today" '
      $0 == "<!-- list -->" { skip = (count == 0); next }
      $0 == "<!-- empty -->" { skip = (count != 0); next }
      $0 == "<!-- /list -->" || $0 == "<!-- /empty -->" { skip = 0; next }
      skip { next }
      $0 == "__ROWS__" { while ((getline line < rowsfile) > 0) print line; next }
      $0 == "__CARDS__" { while ((getline line < cardsfile) > 0) print line; next }
      { gsub(/__COUNT__/, count); gsub(/__DATE__/, today); print }' "$SKILL_DIR/templates/followups.html" > "$tmp"
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
