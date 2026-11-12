#!/bin/bash
# From the browser history, take only the date each candidate domain was last opened, and attach it to the candidates.
# It reads History from Chromium browsers (Chrome, Dia, Arc, Brave, Edge) and History.db from Safari.
# Each history database is copied to a temporary directory and reduced, inside this script, to the last date per candidate domain.
# History for domains that are not candidates is never written to the output or to any file. Copies are deleted after reading.
# Fields added: last_visit (the last date opened, or null) and history_since (the oldest date in the history that could be read).
# Chromium browsers keep only about 90 days of history, so "not opened" does not mean "not used".
#
# Usage: usage.sh < matched.json > with-usage.json

. "$(dirname "$0")/common.sh"
need jq "Install jq."

input=$(mktemp "${TMPDIR:-/tmp}/account-cleanup-usage-in.XXXXXX")
visits=$(mktemp "${TMPDIR:-/tmp}/account-cleanup-usage-visits.XXXXXX")
work=$(mktemp -d "${TMPDIR:-/tmp}/account-cleanup-usage.XXXXXX")
trap 'rm -rf "$input" "$visits" "$work"' EXIT
cat > "$input"

home=${ACCOUNT_CLEANUP_BROWSER_HOME:-$HOME}
keys=$(jq -c '[.[].key]' "$input")

# From one history copy, append the last visit per candidate domain (UNIX seconds) to visits as `{"key": seconds}`
collect() {
  local query=$1 offset=$2 divisor=$3
  command -v sqlite3 >/dev/null 2>&1 || return 0
  sqlite3 -json "$work/h" "$query" 2>/dev/null \
    | jq -c --argjson keys "$keys" --argjson off "$offset" --argjson div "$divisor" "$JQ_HOST $JQ_REGDOMAIN"'
        ($keys | map({(.): true}) | add // {}) as $want
        | [.[]? | (.u | host) as $h | select($h != "")
            | ($h | regdomain) as $r
            | (if $want[$h] then $h elif $want[$r] then $r else empty end) as $k
            | {k: $k, s: ((.t / $div) - $off | floor)}]
        | group_by(.k) | map({(.[0].k): (map(.s) | max)}) | add // {}' >> "$visits" || true
}

oldest=""
note_oldest() {
  local q=$1 off=$2 div=$3 s
  s=$(sqlite3 "$work/h" "$q" 2>/dev/null || true)
  [ -n "$s" ] || return 0
  s=$(awk -v t="$s" -v o="$off" -v d="$div" 'BEGIN { printf "%d", (t / d) - o }')
  if [ -z "$oldest" ] || [ "$s" -lt "$oldest" ]; then oldest=$s; fi
}

for rel in \
  "Library/Application Support/Google/Chrome" \
  "Library/Application Support/Dia/User Data" \
  "Library/Application Support/Arc/User Data" \
  "Library/Application Support/BraveSoftware/Brave-Browser" \
  "Library/Application Support/Microsoft Edge" \
  ".config/google-chrome" \
  ".config/chromium" \
  ".config/BraveSoftware/Brave-Browser" \
  ".config/microsoft-edge"; do
  for db in "$home/$rel"/*/History; do
    [ -f "$db" ] || continue
    cp "$db" "$work/h" 2>/dev/null || continue
    collect "SELECT url AS u, last_visit_time AS t FROM urls WHERE last_visit_time > 0" 11644473600 1000000
    note_oldest "SELECT min(last_visit_time) FROM urls WHERE last_visit_time > 0" 11644473600 1000000
    rm -f "$work/h" "$work/h-journal"
  done
done

safari="$home/Library/Safari/History.db"
if [ -f "$safari" ] && cp "$safari" "$work/h" 2>/dev/null; then
  collect "SELECT i.url AS u, max(v.visit_time) AS t FROM history_items i JOIN history_visits v ON v.history_item = i.id GROUP BY i.id" -978307200 1
  note_oldest "SELECT min(visit_time) FROM history_visits" -978307200 1
  rm -f "$work/h" "$work/h-journal"
fi

jq -c --slurpfile v "$visits" --arg oldest "$oldest" '
  (reduce $v[] as $x ({}; reduce ($x | to_entries[]) as $e (.; .[$e.key] = ([.[$e.key] // 0, $e.value] | max)))) as $seen
  | (if $oldest == "" then null else ($oldest | tonumber | todate | .[0:10]) end) as $since
  | map(. + {
      last_visit: (if $seen[.key] then ($seen[.key] | todate | .[0:10]) else null end),
      history_since: $since
    })' "$input"
