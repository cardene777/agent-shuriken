#!/bin/bash
# Add the reasons each matched candidate looks unused.
# Reasons are fixed codes added to the candidate's reasons array (the sheet shows a label for each code in every language).
#   browser-extension  The key is a Chromium extension ID (mostly crypto wallets), not a web service account
#   broken-url         The item's URL is broken, so the site cannot be identified
#   dev-address        localhost, an IP address, .local and the like; not a web service account
#   site-not-found     The site's name does not resolve (curl exit 6). The service has likely shut down
#   stale              Last updated more than ACCOUNT_CLEANUP_STALE_DAYS (default 730) days ago; the date is in updated
# Whether the site answered goes in alive (true, false, or null when it cannot be told).
# When the name resolves but the connection still fails (a timeout, for example), alive stays null rather than "not found".
# Development addresses and candidates without a URL are never contacted.
#
# Usage: triage.sh [--no-network] < matched.json > triaged.json

. "$(dirname "$0")/common.sh"
need jq "Install jq."

network=1
if [ "${1:-}" = "--no-network" ]; then
  network=0
fi

today=${ACCOUNT_CLEANUP_TODAY:-$(date +%Y-%m-%d)}
stale_days=${ACCOUNT_CLEANUP_STALE_DAYS:-730}

input=$(mktemp "${TMPDIR:-/tmp}/account-cleanup-triage.XXXXXX")
alive=$(mktemp "${TMPDIR:-/tmp}/account-cleanup-alive.XXXXXX")
trap 'rm -f "$input" "$alive"' EXIT
cat > "$input"

# LOCAL_RE (development addresses) comes from common.sh
# Chromium extension ID (32 lowercase letters from a to p). Most are crypto wallet extensions
EXT_RE='^[a-p]{32}$'

# For each key to contact, write whether the name resolved and the site answered, as `key state`.
# Keys come from vault items, so only keys made of hostname characters are used, and they are passed as arguments rather than embedded in the command string.
if [ "$network" = 1 ] && command -v curl >/dev/null 2>&1; then
  jq -r '.[] | .key' "$input" \
    | grep -E '^[a-z0-9-]+(\.[a-z0-9-]+)+$' \
    | grep -Ev "$LOCAL_RE" \
    | xargs -P 16 -n 1 sh -c 'curl -s -o /dev/null -I --max-time 6 "https://$1/" >/dev/null 2>&1; c=$?; case $c in 0) echo "$1 true" ;; 6) echo "$1 false" ;; *) echo "$1 null" ;; esac' _ \
    > "$alive" || true
  # Parallel lookups sometimes fail to resolve a name temporarily, so retry the not-found keys one at a time.
  # A key counts as not found only when the retry also fails to resolve; if it answers, record it as alive.
  retried=$(mktemp "${TMPDIR:-/tmp}/account-cleanup-alive2.XXXXXX")
  while read -r k state; do
    if [ "$state" = false ]; then
      # common.sh sets set -e, so capture curl's exit status instead of letting a failure end the script
      c=0
      curl -s -o /dev/null -I --max-time 8 "https://$k/" >/dev/null 2>&1 || c=$?
      case $c in 0) echo "$k true" ;; 6) echo "$k false" ;; *) echo "$k null" ;; esac
    else
      echo "$k $state"
    fi
  done < "$alive" > "$retried"
  mv "$retried" "$alive"
fi

jq -c --arg today "$today" --argjson stale "$stale_days" --arg local_re "$LOCAL_RE" --arg ext_re "$EXT_RE" --rawfile alive "$alive" '
  ($alive | split("\n") | map(select(. != "") | split(" ") | {(.[0]): (.[1] | fromjson)}) | add // {}) as $seen
  | ($today | strptime("%Y-%m-%d") | mktime) as $now
  | map(
      . as $g
      | ($g.key | test($local_re)) as $is_local
      | ($g.key | test($ext_re)) as $is_ext
      | ((($g.key | startswith("name:")) or $is_local or $is_ext or ($g.key | contains("."))) | not) as $is_broken
      | (if $is_local or ($seen | has($g.key) | not) then null else $seen[$g.key] end) as $up
      | ((($g.updated // "") | length) == 10 and (($now - ($g.updated | strptime("%Y-%m-%d") | mktime)) / 86400) > $stale) as $old
      | $g + {
          alive: $up,
          reasons: (
            (if $is_ext then ["browser-extension"] else [] end)
            + (if $is_broken then ["broken-url"] else [] end)
            + (if $is_local then ["dev-address"] else [] end)
            + (if $up == false then ["site-not-found"] else [] end)
            + (if $old then ["stale"] else [] end)
          )
        })' "$input"
