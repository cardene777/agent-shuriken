#!/bin/bash
# Publishes a release: tags vX.Y.Z on main, then creates a GitHub Release whose notes are the
# version's section of CHANGELOG.md, with one zip per skill attached.
#
# Usage: bash scripts/release.sh <X.Y.Z> [--dry-run]
#
# Before running it, merge a pull request that moves the entries under "## [X.Y.Z] - <date>"
# in CHANGELOG.md and sets every plugin version in .claude-plugin/marketplace.json to X.Y.Z.
# --dry-run builds the notes and zips from HEAD and prints what would be published,
# without tagging, pushing, or creating the release.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

die() { printf 'release: %s\n' "$1" >&2; exit 1; }

version="${1:-}"
dry_run=false
[ "${2:-}" = "--dry-run" ] && dry_run=true
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "usage: scripts/release.sh <X.Y.Z> [--dry-run]"
tag="v$version"

for tool in git jq gh; do
  command -v "$tool" >/dev/null || die "$tool is not installed"
done

bash scripts/check.sh >/dev/null || die "scripts/check.sh failed; run it to see why"

newest="$(sed -nE 's/^## \[([0-9]+\.[0-9]+\.[0-9]+)\] - [0-9-]+$/\1/p' CHANGELOG.md | head -1)"
[ "$newest" = "$version" ] || die "the newest release in CHANGELOG.md is $newest, not $version"

if [ "$dry_run" = false ]; then
  [ "$(git branch --show-current)" = main ] || die "check out main first"
  [ -z "$(git status --porcelain)" ] || die "commit or stash the changes in the working tree first"
  git fetch --quiet origin main
  [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || die "main is not the same as origin/main; pull or push first"
  git rev-parse --quiet --verify "refs/tags/$tag" >/dev/null && die "tag $tag already exists locally"
  [ -z "$(git ls-remote --tags origin "refs/tags/$tag")" ] || die "tag $tag already exists on origin"
fi

out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT

# Release notes: the lines between this version's heading and the next release heading,
# or the link definitions at the end of the file.
# Command substitution drops the trailing blank lines; sed drops the leading ones.
notes="$(awk -v heading="## [$version]" '
  index($0, heading) == 1 { found = 1; next }
  found && (/^## \[/ || /^\[[^]]+\]: /) { exit }
  found { print }
' CHANGELOG.md | sed -e '/./,$!d')"
[ -n "$notes" ] || die "the section for $version in CHANGELOG.md is empty"
printf '%s\n\nSee the README for how to install and update: https://github.com/cardene777/agent-shuriken#install\n' \
  "$notes" > "$out/notes.md"

# One zip per skill, holding the skill folder at the top level so it unzips into a skills folder.
assets=()
for dir in skills/*/; do
  name="$(basename "$dir")"
  [ -f "$dir/SKILL.md" ] || continue
  git archive --format=zip --prefix="$name/" -o "$out/$name-$tag.zip" "HEAD:skills/$name"
  assets+=("$out/$name-$tag.zip")
done

if [ "$dry_run" = true ]; then
  printf 'Would tag %s at %s and publish this release.\n\n' "$tag" "$(git rev-parse --short HEAD)"
  cat "$out/notes.md"
  printf '\nAssets:\n'
  for asset in "${assets[@]}"; do
    printf '  %s (%s files)\n' "$(basename "$asset")" "$(unzip -Z1 "$asset" | grep -vc '/$')"
  done
  exit 0
fi

git tag -a "$tag" -m "$tag"
git push --quiet origin "refs/tags/$tag"
gh release create "$tag" --verify-tag --title "$tag" --notes-file "$out/notes.md" "${assets[@]}"
