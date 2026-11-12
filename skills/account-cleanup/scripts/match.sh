#!/bin/bash
# Attach a deletion page to each group.
# The additions list (pages the user found by search) is checked first, then the bundled list (JustDeleteMe).
# In each list, an exact host match is tried first, then a match on the registrable domain.
# Groups found in neither list get needs_search. plan.sh prints an erasure request for services listed as impossible to delete.
# Fields from an earlier match are overwritten, so matched.json can be passed in again (plan.sh does this to pick up add-site.sh).
#
# Usage: match.sh < groups.json > matched.json

. "$(dirname "$0")/common.sh"
need jq "Install jq."

additions=$ADDITIONS_FILE
if [ ! -f "$additions" ]; then
  additions=$(mktemp "${TMPDIR:-/tmp}/account-cleanup-additions.XXXXXX")
  trap 'rm -f "$additions"' EXIT
  printf '[]\n' > "$additions"
fi

jq -c \
  --slurpfile sites "$SITES_FILE" \
  --slurpfile adds "$additions" \
  "$JQ_REGDOMAIN"'
  # Turn each list, once, into an index by domain and an index by registrable domain.
  # When several rows have the same domain, the earlier row in the list wins.
  def index_of($list; $origin):
    [$list[] | . + {origin: $origin} | . as $s | ($s.domains // [])[] | {d: ., s: $s}]
    | {exact: (reduce .[] as $x ({}; .[$x.d] //= $x.s)),
       loose: (reduce .[] as $x ({}; .[$x.d | regdomain] //= $x.s))};
  def lookup($idx; $g): (first(([$g.key] + ($g.hosts // []))[] | $idx.exact[.] // empty) // $idx.loose[$g.key]);
  index_of($adds[0]; "addition") as $ai
  | index_of($sites[0]; "bundled") as $si
  | def found($g): lookup($ai; $g) // lookup($si; $g);
  map(. as $g
    | found($g) as $s
    | $g + {
        service: ($s.name // null),
        deletion: (if $s then {url: $s.url, difficulty: ($s.difficulty // "unknown"), notes: ($s.notes // null), email: ($s.email // null), email_subject: ($s.email_subject // null), email_body: ($s.email_body // null), origin: $s.origin} else null end),
        needs_search: ($s == null)
      })'
