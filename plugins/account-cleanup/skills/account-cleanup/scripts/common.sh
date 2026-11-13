#!/bin/bash
# Shared values and functions that every script loads first.
# Every file it creates is readable only by the user (files 600, the data directory 700).

set -euo pipefail
umask 077

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SKILL_DIR=$(dirname "$SCRIPT_DIR")
DATA_DIR="${ACCOUNT_CLEANUP_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/account-cleanup}"
SITES_FILE="${ACCOUNT_CLEANUP_SITES:-$SKILL_DIR/data/sites.json}"
ADDITIONS_FILE="$DATA_DIR/additions.json"
CANDIDATES_FILE="$DATA_DIR/candidates.jsonl"
MANUAL_FILE="$DATA_DIR/manual.jsonl"
MATCHED_FILE="$DATA_DIR/matched.json"
DESCRIPTIONS_FILE="$DATA_DIR/descriptions.json"
SHEET_FILE="$DATA_DIR/sheet.html"
# Where the user lives (eu, uk, california, japan or other). Picks the erasure request template in plan.sh
REGION_FILE="$DATA_DIR/region"
# Things the user cleans up later, such as payment methods that could not be removed. cleanup.sh keeps it
FOLLOWUPS_FILE="$DATA_DIR/followups.tsv"
# Browser profile used for deletion (holds the sites that are still signed in). cleanup.sh removes it
BROWSER_PROFILE_DIR="$DATA_DIR/browser"

ensure_data_dir() {
  mkdir -p "$DATA_DIR"
  chmod 700 "$DATA_DIR"
}

# Stop with a hint about what to install when a command is missing
need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'account-cleanup: %s not found. %s\n' "$1" "$2" >&2
    exit 3
  fi
}

# Take the host from a URL (lowercase, without a leading www.)
JQ_HOST='def host:
  if . == null or . == "" then ""
  else ascii_downcase
    | sub("^[a-z][a-z0-9+.-]*://"; "")
    | sub("[/?#].*$"; "")
    | sub("^[^@]*@"; "")
    | sub(":[0-9]+$"; "")
    | sub("^www[.]"; "")
  end;'

# Hosts that are not web services: the local machine, local network names, and IP addresses.
# triage.sh gives them the dev-address reason and never contacts them, and regdomain keeps each one whole
LOCAL_RE='^(localhost|.*\.localhost|.*\.local|.*\.internal|.*\.lan|.*\.home\.arpa|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|\[[0-9a-f:]+\])$'

# Take the registrable domain from a host (example.co.jp for accounts.example.co.jp).
# A local host or an IP address is returned as it is, so two devices on one network stay two candidates.
# browser.mjs has the same rules in its regdomain
JQ_REGDOMAIN='def regdomain:
  if test("'"${LOCAL_RE//\\/\\\\}"'") or contains(":") then .
  else split(".") as $p
    | if ($p | length) < 3 then ($p | join("."))
      else ($p[-2:] | join(".")) as $two
        | if ($two | IN("co.jp","ne.jp","or.jp","ac.jp","go.jp","gr.jp","ed.jp","lg.jp","co.uk","org.uk","ac.uk","gov.uk","me.uk","com.au","net.au","org.au","co.nz","com.br","com.cn","com.tw","com.hk","co.kr","com.sg","co.in","com.mx","co.za","com.tr"))
          then ($p[-3:] | join(".")) else $two end
      end
  end;'
