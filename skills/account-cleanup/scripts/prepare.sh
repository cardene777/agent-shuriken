#!/bin/bash
# Collect candidates from the chosen sources, merge them, attach deletion pages and build the candidate sheet.
# Prints a summary of counts and the path to the sheet at the end. It never prints the candidates themselves (service names).
#
# Usage:
#   prepare.sh --sources 1password,bitwarden,chrome [--op-account <1Password account>] [--region <region>] [--history]
#   prepare.sh --rebuild [--region <region>] [--history]   (rebuild with the hand-added candidates, without reading the sources again)
#   --region saves where the user lives (eu, uk, california, japan or other) to the data directory.
#            plan.sh uses it to pick the erasure request template. Without --region the saved value is kept
#   --history reads, from the browser history, the date each candidate was last opened (pass it only when the user allows it)

. "$(dirname "$0")/common.sh"
need jq "Install jq."

sources=""
op_account=""
region=""
rebuild=0
history=0
while [ $# -gt 0 ]; do
  case "$1" in
    --sources) sources=${2:-}; shift 2 ;;
    --op-account) op_account=${2:-}; shift 2 ;;
    --region) region=${2:-}; shift 2 ;;
    --rebuild) rebuild=1; shift ;;
    --history) history=1; shift ;;
    *) echo "account-cleanup: unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ -n "$region" ]; then
  case "$region" in
    eu|uk|california|japan|other) ;;
    *) echo "account-cleanup: --region must be one of eu, uk, california, japan, other: $region" >&2; exit 2 ;;
  esac
fi
if [ "$rebuild" = 0 ] && [ -z "$sources" ]; then
  echo "Usage: prepare.sh --sources 1password,bitwarden,chrome [--op-account <account>] [--region <region>] [--history]" >&2
  exit 2
fi

ensure_data_dir

if [ -n "$region" ]; then
  printf '%s\n' "$region" > "$REGION_FILE"
  chmod 600 "$REGION_FILE"
fi

if [ "$rebuild" = 0 ]; then
  : > "$CANDIDATES_FILE"
  chmod 600 "$CANDIDATES_FILE"
  IFS=',' read -r -a list <<<"$sources"
  for s in "${list[@]}"; do
    case "$s" in
      1password)
        if [ -n "$op_account" ]; then
          "$SCRIPT_DIR/inventory-1password.sh" --account "$op_account" >> "$CANDIDATES_FILE" || echo "account-cleanup: skipped 1Password" >&2
        else
          "$SCRIPT_DIR/inventory-1password.sh" >> "$CANDIDATES_FILE" || echo "account-cleanup: skipped 1Password" >&2
        fi ;;
      bitwarden) "$SCRIPT_DIR/inventory-bitwarden.sh" >> "$CANDIDATES_FILE" || echo "account-cleanup: skipped Bitwarden" >&2 ;;
      chrome) "$SCRIPT_DIR/inventory-chrome.sh" >> "$CANDIDATES_FILE" || echo "account-cleanup: skipped Chrome" >&2 ;;
      *) echo "account-cleanup: unknown source: $s (choose from 1password, bitwarden, chrome)" >&2; exit 2 ;;
    esac
  done
elif [ ! -f "$CANDIDATES_FILE" ]; then
  : > "$CANDIDATES_FILE"
  chmod 600 "$CANDIDATES_FILE"
fi

groups=$(mktemp "$DATA_DIR/groups.XXXXXX")
trap 'rm -f "$groups"' EXIT
if [ -f "$MANUAL_FILE" ]; then
  cat "$CANDIDATES_FILE" "$MANUAL_FILE"
else
  cat "$CANDIDATES_FILE"
fi | "$SCRIPT_DIR/merge.sh" > "$groups"

tmp=$(mktemp "$DATA_DIR/matched.XXXXXX")
if [ "$history" = 1 ]; then
  "$SCRIPT_DIR/match.sh" < "$groups" | "$SCRIPT_DIR/triage.sh" | "$SCRIPT_DIR/usage.sh" > "$tmp"
else
  "$SCRIPT_DIR/match.sh" < "$groups" | "$SCRIPT_DIR/triage.sh" > "$tmp"
fi
mv "$tmp" "$MATCHED_FILE"
chmod 600 "$MATCHED_FILE"
# If the AI wrote descriptions earlier, attach them to the rebuilt candidates too
if [ -f "$DESCRIPTIONS_FILE" ]; then
  "$SCRIPT_DIR/annotate.sh" "$DESCRIPTIONS_FILE" >/dev/null
fi
sheet=$("$SCRIPT_DIR/build-sheet.sh" "$MATCHED_FILE")
saved_region=$(cat "$REGION_FILE" 2>/dev/null || true)

jq -r --arg sheet "$sheet" --arg region "${saved_region:-not set (pass --region)}" '
  def count_reason($r): map(select((.reasons // []) | index($r))) | length;
  "Candidates: \(length) (after merging the same service)",
  "Not updated in a long time: \(count_reason("stale"))",
  "Site not found: \(map(select(.alive == false)) | length)",
  "Development addresses: \(count_reason("dev-address"))",
  "Browser extensions: \(count_reason("browser-extension"))",
  "Found in the browser history: \(map(select(.last_visit != null)) | length) (\(if .[0].history_since then "history from \(.[0].history_since)" else "history not read" end))",
  "Deletion page known: \(map(select(.deletion != null)) | length)",
  "Listed as impossible to delete: \(map(select(.deletion.difficulty == "impossible")) | length)",
  "Items per source: " + ([.[].sources[].source] | group_by(.) | map("\(.[0]) \(length)") | join(", ")),
  "Region for erasure requests: \($region)",
  "Candidate sheet: \($sheet)"' "$MATCHED_FILE"
