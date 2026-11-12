#!/bin/bash
# Read only the name, URL and revision date of each Login item in the Bitwarden vault.
# `bw list items` also returns passwords, usernames and notes, so the fields are narrowed inside this script.
# The unfiltered output is never written to a file or shown on screen.
# Run `export BW_SESSION="$(bw unlock --raw)"` in the terminal before starting the agent.
#
# Usage: inventory-bitwarden.sh
# Output: one JSON object per line (source, id, name, url, domain, updated)

. "$(dirname "$0")/common.sh"
need bw "Install the Bitwarden CLI (bw)."
need jq "Install jq."

if ! bw list items | jq -c "$JQ_HOST"'
  .[]
  | select(.type == 1)
  | ((.login.uris // []) | .[0].uri // "") as $u
  | {source: "bitwarden", id: .id, name: (.name // ""), url: $u, domain: ($u | host), updated: ((.revisionDate // "")[0:10])}'; then
  echo "account-cleanup: could not read the Bitwarden vault. Run export BW_SESSION=\"\$(bw unlock --raw)\" in the terminal, then restart the agent." >&2
  exit 4
fi
