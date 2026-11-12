#!/bin/bash
# Read only the site URL and dates from the saved-password database of Chromium browsers (Chrome, Dia, Arc, Brave, Edge).
# The database (`Login Data`) is copied to a temporary directory and read there; the copy is deleted when done.
# Only origin_url and the date columns are selected; the password column (password_value) and the username column are not.
# Passwords are stored encrypted by the browser, and this script never touches the key.
# When ACCOUNT_CLEANUP_CHROME_DIR is set, only that directory is read, as Chrome.
#
# Usage: inventory-chrome.sh
# Output: one JSON object per line (source, id, name, url, domain, updated). source is the browser name, id is the profile name

. "$(dirname "$0")/common.sh"
need sqlite3 "Install sqlite3."
need jq "Install jq."

# Print one `browser name<TAB>directory` per line
browser_dirs() {
  if [ -n "${ACCOUNT_CLEANUP_CHROME_DIR:-}" ]; then
    printf 'chrome\t%s\n' "$ACCOUNT_CLEANUP_CHROME_DIR"
    return
  fi
  local home=${ACCOUNT_CLEANUP_BROWSER_HOME:-$HOME}
  printf 'chrome\t%s\n' "$home/Library/Application Support/Google/Chrome" "$home/.config/google-chrome"
  printf 'dia\t%s\n' "$home/Library/Application Support/Dia/User Data"
  printf 'arc\t%s\n' "$home/Library/Application Support/Arc/User Data"
  printf 'brave\t%s\n' "$home/Library/Application Support/BraveSoftware/Brave-Browser" "$home/.config/BraveSoftware/Brave-Browser"
  printf 'edge\t%s\n' "$home/Library/Application Support/Microsoft Edge" "$home/.config/microsoft-edge"
  if [ -n "${LOCALAPPDATA:-}" ]; then
    printf 'chrome\t%s\n' "$LOCALAPPDATA/Google/Chrome/User Data"
  fi
}

work=$(mktemp -d "${TMPDIR:-/tmp}/account-cleanup-chrome.XXXXXX")
trap 'rm -rf "$work"' EXIT

found=0
while IFS=$'\t' read -r browser base; do
  [ -d "$base" ] || continue
  for db in "$base"/*/"Login Data" "$base"/*/"Login Data For Account"; do
    [ -f "$db" ] || continue
    found=1
    profile=$(basename "$(dirname "$db")")
    cp "$db" "$work/db"
    sqlite3 -json "$work/db" "SELECT origin_url, date_created, date_last_used FROM logins WHERE blacklisted_by_user = 0" \
      | jq -c --arg b "$browser" --arg p "$profile" "$JQ_HOST"'
        def chrome_day: if . == null or . == 0 then "" else ((. / 1000000) - 11644473600 | floor | todate | .[0:10]) end;
        .[]?
        | .origin_url as $u
        | {source: $b, id: $p, name: ($u | host), url: $u, domain: ($u | host),
           updated: (if (.date_last_used // 0) > 0 then (.date_last_used | chrome_day) else (.date_created | chrome_day) end)}'
    rm -f "$work/db" "$work/db-journal"
  done
done < <(browser_dirs)

if [ "$found" = 0 ]; then
  echo "account-cleanup: no browser saved-password database was found." >&2
fi
