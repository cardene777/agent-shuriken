#!/bin/bash
# Read only the name, URL and modified date of each Login item in the 1Password vaults.
# It calls only `op item list`, never `op item get` or `op read`, which return password fields.
# The `op` output is narrowed to those fields inside this script; the unfiltered output is never written to a file.
#
# Usage: inventory-1password.sh [--account <1Password account>]
# Output: one JSON object per line (source, id, name, url, domain, updated)

. "$(dirname "$0")/common.sh"
need op "Install the 1Password CLI (op) and turn on CLI integration in the 1Password app settings."
need jq "Install jq."

args=(item list --categories Login --format json)
if [ "${1:-}" = "--account" ] && [ -n "${2:-}" ]; then
  args+=(--account "$2")
fi

if ! op "${args[@]}" | jq -c "$JQ_HOST"'
  .[]
  | ((.urls // []) | (map(select(.primary == true)) + .) | .[0].href // "") as $u
  | {source: "1password", id: .id, name: (.title // ""), url: $u, domain: ($u | host), updated: ((.updated_at // "")[0:10])}'; then
  echo "account-cleanup: could not read the 1Password vaults. Open the 1Password app, unlock it, and run this again." >&2
  exit 4
fi
