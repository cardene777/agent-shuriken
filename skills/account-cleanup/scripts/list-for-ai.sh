#!/bin/bash
# Print a short list of the candidates so the AI can write what each site is and its suggestion.
# Only the key, names, hosts, last updated date, reasons and the name in the bundled list are printed; URL paths and IDs are not.
# Reasons are fixed codes set by triage.sh: browser-extension, broken-url, dev-address, site-not-found, stale.
#
# Usage: list-for-ai.sh [matched.json]
# Output: one JSON object per line

. "$(dirname "$0")/common.sh"
need jq "Install jq."

src=${1:-$MATCHED_FILE}
jq -c '.[] | {key, names, hosts, updated, reasons: (.reasons // []), known_as: .service}' "$src"
