#!/bin/bash
# Releases one plugin or the repository as a whole.
#
# Usage:
#   bash scripts/release.sh <plugin> <X.Y.Z> [--dry-run]   Tag <plugin>--vX.Y.Z and publish a plugin release
#   bash scripts/release.sh repo <X.Y.Z> [--dry-run]       Tag vX.Y.Z and publish a repository release
#
# Before running it, merge a pull request that moves the changelog entries under "## [X.Y.Z] - <date>",
# as docs/releasing.md describes. --dry-run builds the notes and assets from HEAD and prints what would
# be published, without tagging, pushing, or creating the release.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
REPO_URL="https://github.com/cardene777/agent-shuriken"

die() { printf 'release: %s\n' "$1" >&2; exit 1; }

target="${1:-}"
version="${2:-}"
dry_run=false
[ "${3:-}" = "--dry-run" ] && dry_run=true
[ -n "$target" ] && [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
  || die "usage: scripts/release.sh <plugin|repo> <X.Y.Z> [--dry-run]"

for tool in git jq gh; do
  command -v "$tool" >/dev/null || die "$tool is not installed"
done

if [ "$target" = repo ]; then
  changelog=CHANGELOG.md
  tag="v$version"
  title="v$version"
else
  [ -f "plugins/$target/.claude-plugin/plugin.json" ] || die "no plugin named $target in plugins/"
  changelog="plugins/$target/CHANGELOG.md"
  tag="$target--v$version"
  title="$target $version"
fi

bash scripts/check.sh >/dev/null || die "scripts/check.sh failed; run it to see why"

newest="$(sed -nE 's/^## \[([0-9]+\.[0-9]+\.[0-9]+)\] - [0-9-]+$/\1/p' "$changelog" | head -1)"
[ "$newest" = "$version" ] || die "the newest release in $changelog is $newest, not $version"

# The section of the changelog for this version: the lines between its heading and the next release
# heading or the link definitions at the end. Command substitution drops trailing blank lines, and
# sed drops leading ones.
notes="$(awk -v heading="## [$version]" '
  index($0, heading) == 1 { found = 1; next }
  found && (/^## \[/ || /^\[[^]]+\]: /) { exit }
  found { print }
' "$changelog" | sed -e '/./,$!d')"
[ -n "$notes" ] || die "the section for $version in $changelog is empty"

if [ "$target" = repo ]; then
  # The release records the plugin versions, so its table must match the manifests on this commit.
  for dir in plugins/*/; do
    name="$(basename "$dir")"
    current="$(jq -r .version "$dir.claude-plugin/plugin.json")"
    printf '%s\n' "$notes" | grep -qE "^\| $name \| $current \|$" \
      || die "the Plugins table for $version in CHANGELOG.md does not list $name $current"
  done
  footer="See the README for the plugins and how to install them: $REPO_URL#readme"
else
  footer="See the README for how to install and use the plugin: $REPO_URL/tree/$tag/plugins/$target"
fi

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
printf '%s\n\n%s\n' "$notes" "$footer" > "$out/notes.md"

# A plugin release attaches the skill folders, to unzip into a skills folder, and the plugin
# folder's contents, to upload to OpenAI's plugin directory.
assets=()
if [ "$target" != repo ]; then
  git archive --format=zip -o "$out/$target-$version-skill.zip" "HEAD:plugins/$target/skills"
  git archive --format=zip -o "$out/$target-$version-plugin.zip" "HEAD:plugins/$target"
  assets=("$out/$target-$version-skill.zip" "$out/$target-$version-plugin.zip")
fi

if [ "$dry_run" = true ]; then
  printf 'Would tag %s at %s and publish "%s".\n\n' "$tag" "$(git rev-parse --short HEAD)" "$title"
  cat "$out/notes.md"
  if [ "${#assets[@]}" -gt 0 ]; then
    printf '\nAssets:\n'
    for asset in "${assets[@]}"; do
      printf '  %s (%s files)\n' "$(basename "$asset")" "$(unzip -Z1 "$asset" | grep -vc '/$')"
    done
    printf '\nWould move branch release/%s to this commit.\n' "$target"
  fi
  exit 0
fi

git tag -a "$tag" -m "$title"
git push --quiet origin "refs/tags/$tag"
if [ "$target" = repo ]; then
  gh release create "$tag" --verify-tag --title "$title" --notes-file "$out/notes.md" --latest
else
  # Anthropic's plugin directory follows release/<plugin>, so it picks up only released versions.
  # The push is a fast-forward; it fails rather than rewrite the branch if history diverged.
  git push --quiet origin "refs/tags/$tag^{commit}:refs/heads/release/$target"
  gh release create "$tag" --verify-tag --title "$title" --notes-file "$out/notes.md" --latest=false "${assets[@]}"
fi
