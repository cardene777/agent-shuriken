#!/bin/bash
# Checks the musubi declarations (musubi.json) of every skill: the follows inside the repository, and
# the follows of the dragon skill, which lives in cardene777/dragon. scripts/check.sh runs this script.
# Usage: bash scripts/check-musubi.sh
# Prints one line per check. Exits 0 when no check fails and 1 when any check fails.
# A check whose tool is missing, or the dragon check when dragon cannot be fetched, is reported as
# "skip" with the reason and does not fail the run.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root" || exit 1

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

pass=0 fail=0 skip=0

# run <name> <function>: the check fails when the function exits non-zero, and is skipped on 77.
# Whatever the function prints is shown under a failing or skipped check as the reason.
run() {
  local name="$1" out status
  out="$("$2" 2>&1)"
  status=$?
  if [ "$status" -eq 0 ]; then
    printf 'ok    %s\n' "$name"
    pass=$((pass + 1))
  elif [ "$status" -eq 77 ]; then
    printf 'skip  %s (%s)\n' "$name" "$(printf '%s' "$out" | tail -1)"
    skip=$((skip + 1))
  else
    printf 'FAIL  %s\n' "$name"
    printf '%s\n' "$out" | grep -v '^warning:' | head -20 | sed 's/^/        /'
    fail=$((fail + 1))
  fi
}

# The skills folder of every plugin.
skills_folders() {
  local d
  for d in plugins/*/skills; do
    [ -d "$d" ] && printf '%s\n' "$d"
  done
}

need_npx() {
  command -v npx > /dev/null 2>&1 || { echo "npx is not installed"; return 77; }
}

check_inside() {
  need_npx || return $?
  local folders=() f
  while IFS= read -r f; do folders+=("$f"); done < <(skills_folders)
  musubi_check "${folders[@]}"
}

check_dragon() {
  dragon_check "$DRAGON_URL"
}

# A copy of a provider whose content changed after the consumer's last check is refused, and the
# refusal names the consumer and the content.
check_refuses_stale() {
  need_npx || return $?
  local d="$work/stale" out status
  mkdir -p "$d/provider" "$d/consumer"
  cp -R plugins/japanese-writing/skills/japanese-writing "$d/provider/" || return 1
  cp -R plugins/convey/skills/convey "$d/consumer/" || return 1
  printf '\nA changed line.\n' >> "$d/provider/japanese-writing/references/connecting.md"
  out="$(musubi_check "$d/provider" "$d/consumer" 2>&1)"
  status=$?
  [ "$status" -eq 1 ] || { echo "musubi check exited $status after connecting.md of japanese-writing changed, not 1"; return 1; }
  printf '%s\n' "$out" | grep -q 'convey: the fingerprint of japanese-writing/connecting does not match' \
    || { echo "convey was not refused after connecting.md of japanese-writing changed:"; printf '%s\n' "$out" | tail -3; return 1; }
}

# When dragon cannot be fetched, the dragon check is skipped and names where it tried to fetch from.
check_dragon_skip() {
  local url="file://$work/no-such-repository" out status
  out="$(dragon_check "$url" 2>&1)"
  status=$?
  [ "$status" -eq 77 ] || { echo "the dragon check exited $status for $url, not 77 (skip)"; return 1; }
  printf '%s\n' "$out" | grep -qF "could not fetch the dragon skill from $url" \
    || { echo "the skip does not name $url: $out"; return 1; }
}

check_run_by_check_sh() {
  grep -qF 'bash scripts/check-musubi.sh' scripts/check.sh \
    && grep -qE '^run "[^"]+" check_musubi$' scripts/check.sh \
    || { echo "scripts/check.sh does not run scripts/check-musubi.sh as a check"; return 1; }
}

run "musubi declarations inside the repository match" check_inside
run "musubi follows of dragon match the dragon skill" check_dragon
run "musubi check refuses a stale fingerprint" check_refuses_stale
run "the dragon check skips when dragon cannot be fetched" check_dragon_skip
run "scripts/check.sh runs these checks" check_run_by_check_sh

printf 'check-musubi: ran %d checks, %d passed, %d failed, %d skipped\n' "$((pass + fail + skip))" "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ]
