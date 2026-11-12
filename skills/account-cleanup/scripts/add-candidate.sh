#!/bin/bash
# Add a service found on a sign-in connections page or in email to the candidates by hand.
# Added candidates enter the candidate sheet on the next prepare.sh --rebuild.
#
# Usage: add-candidate.sh <service name> <URL>

. "$(dirname "$0")/common.sh"
need jq "Install jq."

if [ $# -lt 2 ]; then
  echo "Usage: add-candidate.sh <service name> <URL>" >&2
  exit 2
fi

ensure_data_dir
jq -nc --arg n "$1" --arg u "$2" "$JQ_HOST"'
  ($u | if test("^[a-z][a-z0-9+.-]*://"; "i") then . else "https://" + . end) as $url
  | {source: "manual", id: "", name: $n, url: $url, domain: ($url | host), updated: ""}' >> "$MANUAL_FILE"
chmod 600 "$MANUAL_FILE"
echo "Added to the candidates: $1"
