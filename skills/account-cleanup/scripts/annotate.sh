#!/bin/bash
# Attach the descriptions the AI wrote to the candidates and rebuild the candidate sheet.
# The descriptions file is JSON keyed by candidate key, with these 4 fields per key.
#   description  A short description of what the site is
#   category     One of: email, bank, brokerage, card, government, work, domain, cloud,
#                password-manager, telecom, shopping, social, dev, other
#                (any other value is stored as other, so the sheet can show a label in every language)
#   suggestion   The AI's take: ok (looks safe to delete) or ng (better to keep)
#   why          The reason for the suggestion
# Candidates that could not be deleted in an earlier round can also have the following (they gather in the first tab of the sheet).
#   previous     {"round": round number, "label": short label, "detail": why it stopped and what to do next}
# Candidates without a description are left as they are.
#
# Usage: annotate.sh <descriptions file> [matched.json]

. "$(dirname "$0")/common.sh"
need jq "Install jq."

# Category keys. The sheet (templates/sheet.html) has a label for each one in every language
CATEGORIES='["email","bank","brokerage","card","government","work","domain","cloud","password-manager","telecom","shopping","social","dev","other"]'

desc=${1:-}
target=${2:-$MATCHED_FILE}
if [ -z "$desc" ] || [ ! -f "$desc" ]; then
  echo "Usage: annotate.sh <descriptions file> [matched.json]" >&2
  exit 2
fi
if [ ! -f "$target" ]; then
  echo "account-cleanup: no matched candidates: $target" >&2
  exit 2
fi

ensure_data_dir
# Also merge the descriptions into descriptions.json in the data directory, so they are attached again when the candidates are rebuilt
if [ "$desc" != "$DESCRIPTIONS_FILE" ]; then
  merged=$(mktemp "$DATA_DIR/descriptions.XXXXXX")
  if [ -f "$DESCRIPTIONS_FILE" ]; then
    jq -s '.[0] + .[1]' "$DESCRIPTIONS_FILE" "$desc" > "$merged"
  else
    jq . "$desc" > "$merged"
  fi
  mv "$merged" "$DESCRIPTIONS_FILE"
  chmod 600 "$DESCRIPTIONS_FILE"
fi

# Warn only for a newly written file; prepare.sh re-applies descriptions.json on every rebuild
if [ "$desc" != "$DESCRIPTIONS_FILE" ]; then
  unknown=$(jq --argjson cats "$CATEGORIES" '[.[] | objects | .category // empty | select((type == "string" and (ascii_downcase | IN($cats[]))) | not)] | length' "$desc")
  if [ "$unknown" -gt 0 ]; then
    echo "account-cleanup: stored ${unknown} unknown category value(s) as other" >&2
  fi
fi

tmp=$(mktemp "$DATA_DIR/matched.XXXXXX")
jq -c --slurpfile d "$desc" --argjson cats "$CATEGORIES" '
  ($d[0] // {}) as $desc
  | map(. as $g
      | ($desc[$g.key] // null) as $x
      | if $x == null then $g
        else $g + {
          description: ($x.description // null),
          category: (($x.category // null) as $c
                     | if $c == null then null
                       elif ($c | type) == "string" and ($c | ascii_downcase | IN($cats[])) then ($c | ascii_downcase)
                       else "other" end),
          suggestion: (if ($x.suggestion // "") | IN("ok", "ng") then $x.suggestion else null end),
          why: ($x.why // null),
          previous: (if ($x.previous | type) == "object" and (($x.previous.label // "") | length) > 0
                     then $x.previous | {round: (.round // null), label, detail: (.detail // null)} else null end)
        } end)' "$target" > "$tmp"
mv "$tmp" "$target"
chmod 600 "$target"
count=$(jq --slurpfile d "$desc" '[.[] | select(.key as $k | $d[0] | has($k))] | length' "$target")
if [ "$target" = "$MATCHED_FILE" ]; then
  "$SCRIPT_DIR/build-sheet.sh" "$target" >/dev/null
fi
echo "Attached descriptions to ${count} candidate(s)."
