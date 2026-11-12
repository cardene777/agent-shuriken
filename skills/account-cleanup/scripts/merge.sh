#!/bin/bash
# Merge the candidates from every source (one JSON object per line) into one group per registrable domain.
# accounts.example.com, www.example.com and example.com become one example.com group.
# Candidates without a URL are grouped by name.
#
# Usage: merge.sh < candidates.jsonl > groups.json
# Output: an array of groups (key, names, urls, hosts, sources, updated)

. "$(dirname "$0")/common.sh"
need jq "Install jq."

jq -s -c "$JQ_REGDOMAIN"'
  map(. + {key: (if (.domain // "") != "" then (.domain | regdomain) else "name:" + ((.name // "") | ascii_downcase) end)})
  | group_by(.key)
  | map({
      key: .[0].key,
      names: (map(.name // "") | map(select(. != "")) | unique),
      urls: (map(.url // "") | map(select(. != "")) | unique),
      hosts: (map(.domain // "") | map(select(. != "")) | unique),
      sources: (map({source, id}) | unique),
      updated: (map(.updated // "") | max)
    })'
