#!/usr/bin/env bash
# Checks the knowledge items on L2 networks, the L1 roadmap, and consensus-only EIPs, and lists them
# with the items that are due to be checked again.
#
# Usage
#   bash ethereum-knowledge.sh check [--dir <items folder>]
#   bash ethereum-knowledge.sh list  [--dir <items folder>] [--today <YYYY-MM-DD>]
#
# Each item is one Markdown file whose front matter, between the first two `---` lines, holds
# `status`, `checked`, and `source`. `_days_for` alone owns how many days each status stays fresh.
# An item exactly that many days old is still fresh; one day more and `list` marks it `stale`.
#
# ERCs belong to the evm-standards skill of the same plugin, so an item whose file name starts with
# `erc-` is refused even when its fields are complete.
#
# Exit codes
#   0  every item has its fields (`list` exits 0 whether or not items are stale)
#   1  an item lacks a field, has an unknown status or an impossible date, or is named after an ERC,
#      or there are no items
#   2  wrong usage
#
# Dates are turned into days in UTC, so a daylight saving change cannot make a day one hour short.
# Written for the bash 3.2 that macOS ships.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: ethereum-knowledge.sh check [--dir <items folder>]
       ethereum-knowledge.sh list  [--dir <items folder>] [--today <YYYY-MM-DD>]

check  Checks that every item has status, checked, and source, that status is announced,
       specified, live, or stopped, that checked is a real date, and that no file name starts
       with erc-, since ERCs belong to the evm-standards skill.
list   Prints one line per item: stale or ok, the status, the date it was checked, and its name.
       An item is stale once more days have passed since it was checked than its status allows:
       announced 30, specified 90, live 180, stopped 180.

--dir    The folder of items. Defaults to the items bundled with this skill.
--today  The date to count from. Defaults to today.
EOF
}

# Announced work changes fast; stopped work rarely changes, so it is checked as often as live work.
_days_for() {
  case "$1" in
    announced) echo 30 ;;
    specified) echo 90 ;;
    live) echo 180 ;;
    stopped) echo 180 ;;
    *) return 1 ;;
  esac
}

# Prints a YYYY-MM-DD date as seconds at 00:00 UTC; returns 1 for a date that does not exist.
_epoch() {
  local d="$1" e back
  case "$d" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
    *) return 1 ;;
  esac
  if e="$(TZ=UTC date -j -f '%Y-%m-%d %H:%M:%S' "$d 00:00:00" +%s 2>/dev/null)"; then
    back="$(TZ=UTC date -j -r "$e" +%Y-%m-%d)"
  elif e="$(TZ=UTC date -d "$d 00:00:00" +%s 2>/dev/null)"; then
    back="$(TZ=UTC date -d "@$e" +%Y-%m-%d)"
  else
    return 1
  fi
  [ "$back" = "$d" ] || return 1
  printf '%s' "$e"
}

# Prints the value of one front matter field.
_field() {
  local file="$1" key="$2" line n=0
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$line" = "---" ]; then
      n=$((n + 1))
      [ "$n" -ge 2 ] && return 0
      continue
    fi
    [ "$n" -eq 0 ] && return 0
    case "$line" in
      "$key: "*) printf '%s' "${line#"$key: "}"; return 0 ;;
    esac
  done < "$file"
}

DIR="$SCRIPT_DIR/../references/items"
TODAY=""
cmd="${1:-}"
[ $# -gt 0 ] && shift
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) DIR="${2:-}"; shift 2 ;;
    --today) TODAY="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ethereum-knowledge: unknown argument $1; run with --help to see the options" >&2; exit 2 ;;
  esac
done
case "$cmd" in
  check|list) ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
if [ ! -d "$DIR" ]; then
  echo "ethereum-knowledge: no items folder at $DIR; pass --dir with the folder that holds the items"
  exit 1
fi

bad=0
count=0
for f in "$DIR"/*.md; do
  [ -f "$f" ] || continue
  count=$((count + 1))
  name="$(basename "$f" .md)"
  status="$(_field "$f" status)"
  checked="$(_field "$f" checked)"
  source="$(_field "$f" source)"
  [ -n "$status" ] || { echo "ethereum-knowledge: $name has no status field; add one of announced, specified, live, stopped"; bad=1; }
  [ -n "$checked" ] || { echo "ethereum-knowledge: $name has no checked field; add the date the status was confirmed"; bad=1; }
  [ -n "$source" ] || { echo "ethereum-knowledge: $name has no source field; name the organization and the document"; bad=1; }
  if [ -n "$status" ] && ! _days_for "$status" > /dev/null; then
    echo "ethereum-knowledge: $name has the unknown status $status; use announced, specified, live, or stopped"
    bad=1
  fi
  if [ -n "$checked" ] && ! _epoch "$checked" > /dev/null; then
    echo "ethereum-knowledge: $name has checked $checked, which is not a real YYYY-MM-DD date"
    bad=1
  fi
  case "$name" in
    erc-*)
      echo "ethereum-knowledge: $name is an ERC; ERCs belong to the evm-standards skill, so move the item there"
      bad=1
      ;;
  esac
done

if [ "$count" -eq 0 ]; then
  echo "ethereum-knowledge: no items in $DIR"
  exit 1
fi
[ "$bad" -eq 0 ] || exit 1

if [ "$cmd" = "check" ]; then
  echo "ethereum-knowledge: ok ($count items)"
  exit 0
fi

[ -n "$TODAY" ] || TODAY="$(date -u +%Y-%m-%d)"
if ! today_epoch="$(_epoch "$TODAY")"; then
  echo "ethereum-knowledge: --today $TODAY is not a real YYYY-MM-DD date" >&2
  exit 2
fi

stale=0
for f in "$DIR"/*.md; do
  [ -f "$f" ] || continue
  status="$(_field "$f" status)"
  checked="$(_field "$f" checked)"
  limit="$(_days_for "$status")"
  days=$(( (today_epoch - $(_epoch "$checked")) / 86400 ))
  mark=ok
  if [ "$days" -gt "$limit" ]; then
    mark=stale
    stale=$((stale + 1))
  fi
  printf '%-6s %-10s %s %s\n' "$mark" "$status" "$checked" "$(basename "$f" .md)"
done
echo "$count items, $stale stale as of $TODAY"
exit 0
