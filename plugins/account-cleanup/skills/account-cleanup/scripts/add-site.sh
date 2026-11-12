#!/bin/bash
# Add a deletion page found by web search to the local additions list.
# From the next match on, this list is checked before the bundled list. An older row for the same domain is replaced.
# cleanup.sh keeps the additions list, so it carries over to the next run.
#
# Usage: add-site.sh <domain> <deletion page URL> [difficulty easy|medium|hard|impossible|ended] [notes on the steps]
# When the service has shut down, set the difficulty to ended and give the shutdown notice as the URL.

. "$(dirname "$0")/common.sh"
need jq "Install jq."

if [ $# -lt 2 ]; then
  echo "Usage: add-site.sh <domain> <deletion page URL> [difficulty] [notes on the steps]" >&2
  exit 2
fi
domain=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
url=$2
difficulty=${3:-unknown}
notes=${4:-}

case "$url" in
  https://*|http://*) ;;
  *) echo "account-cleanup: the deletion page URL must start with https:// or http://: $url" >&2; exit 2 ;;
esac
case "$difficulty" in
  easy|medium|hard|impossible|limited|unknown|ended) ;;
  *) echo "account-cleanup: difficulty must be one of easy, medium, hard, impossible, limited, ended: $difficulty" >&2; exit 2 ;;
esac

ensure_data_dir
[ -f "$ADDITIONS_FILE" ] || printf '[]\n' > "$ADDITIONS_FILE"
tmp=$(mktemp "$DATA_DIR/additions.XXXXXX")
jq --arg d "$domain" --arg u "$url" --arg diff "$difficulty" --arg n "$notes" '
  map(select((.domains // []) | index($d) | not))
  + [{name: $d, url: $u, difficulty: $diff, notes: (if $n == "" then null else $n end), domains: [$d], added: (now | todate | .[0:10])}]' \
  "$ADDITIONS_FILE" > "$tmp"
mv "$tmp" "$ADDITIONS_FILE"
chmod 600 "$ADDITIONS_FILE"
echo "Added to the additions list: $domain → $url"
