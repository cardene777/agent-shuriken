#!/usr/bin/env bash
# Copies _data/sites.json of the newest commit of jdm-contrib/jdm over the bundled list, unmodified,
# and writes that commit and today's date into the JustDeleteMe table of THIRD_PARTY_NOTICES.md.
# Maintainers of this repository run it before a release; the skill never runs it.
# It asks GitHub, through a signed-in gh, for the newest commit and that one file, and sends nothing.
# When the download is not a site list or gh fails, it stops and changes no file.
#
# Usage: bash tools/update-sites.sh
set -euo pipefail

cd "$(dirname "$0")/.."
list=skills/account-cleanup/data/sites.json
notice=THIRD_PARTY_NOTICES.md
upstream=repos/jdm-contrib/jdm
today=${ACCOUNT_CLEANUP_TODAY:-$(date +%Y-%m-%d)}

command -v gh > /dev/null || { echo "update-sites: gh is not installed" >&2; exit 1; }
command -v jq > /dev/null || { echo "update-sites: jq is not installed" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

sha=$(gh api "$upstream/commits/master" --jq .sha) || { echo "update-sites: gh could not read the newest commit" >&2; exit 1; }
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || { echo "update-sites: the newest commit is not a commit hash: $sha" >&2; exit 1; }

gh api "$upstream/contents/_data/sites.json?ref=$sha" -H 'Accept: application/vnd.github.raw' > "$work/sites.json" \
  || { echo "update-sites: gh could not download _data/sites.json at $sha" >&2; exit 1; }
jq -e 'type == "array" and length > 0 and all(.[]; type == "object" and has("name") and has("domains"))' \
  "$work/sites.json" > /dev/null 2>&1 \
  || { echo "update-sites: the download is not a list of sites with name and domains; nothing changed" >&2; exit 1; }

# Rewrite only the two rows, and stop when the notice does not hold each of them exactly once.
awk -v sha="$sha" -v day="$today" '
  /^\| Source commit \| / { print "| Source commit | `" sha "` |"; c++; next }
  /^\| Copied on \| / { print "| Copied on | " day " |"; d++; next }
  { print }
  END { if (c != 1 || d != 1) exit 3 }
' "$notice" > "$work/notice.md" \
  || { echo "update-sites: $notice does not hold one Source commit row and one Copied on row; nothing changed" >&2; exit 1; }

cp "$work/sites.json" "$list"
cp "$work/notice.md" "$notice"
echo "update-sites: copied $(jq length "$list") sites from commit $sha"
