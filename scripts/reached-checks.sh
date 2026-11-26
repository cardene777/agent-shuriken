#!/usr/bin/env bash
# The reached checks that the ikkan gates run, as .ikkan/checks.md declares: scripts/check.sh, then
# every plugin test whose code names a root file the branch changed since it left origin/main.
# A plugin test that reads a root file, such as the dependency line of AGENTS.md, can break
# without a change to its own plugin, so it runs here. The tests of the plugins a branch changes
# run at the test step of its issue instead.
#
#   bash scripts/reached-checks.sh                   Run scripts/check.sh and the picked plugin tests
#   bash scripts/reached-checks.sh --list FILE...    Print the plugin tests picked for these changed files
set -u

cd "$(dirname "$0")/.." || exit 2

# Plugin test entry files, one path per line.
plugin_tests() {
  git ls-files 'plugins/*/tests/*' 'plugins/*/skills/*/tests/*' | grep -E '/tests/test-[^/]+\.sh$'
}

# The regular expression of one root path as a test names it: after a variable that holds the
# repository root ($REPO, $TOP, $ROOT, ${REPO}, and the like) or after ../../.
root_pattern() {
  local escaped
  escaped="$(printf '%s' "$1" | sed 's/[][\.*^$()+?{}|]/\\&/g')"
  printf '(REPO|TOP|ROOT)[A-Z_]*\\}?/%s|\\.\\./\\.\\./%s' "$escaped" "$escaped"
}

# pick FILE...: prints, sorted, the plugin tests that name a changed root file. A file under
# plugins/ is skipped. For a file in a folder, a test that names the folder (docs/) counts too.
pick() {
  local file patterns=() tests
  for file in "$@"; do
    case "$file" in
      ''|plugins/*) continue ;;
    esac
    patterns+=("$(root_pattern "$file")")
    case "$file" in
      */*) patterns+=("$(root_pattern "${file%%/*}/")") ;;
    esac
  done
  [ "${#patterns[@]}" -gt 0 ] || return 0
  tests="$(plugin_tests)"
  [ -n "$tests" ] || return 0
  local joined
  joined="$(IFS='|'; printf '%s' "${patterns[*]}")"
  # shellcheck disable=SC2086 # The test paths hold no spaces; git ls-files prints them one per line.
  grep -l -E -- "$joined" $tests | LC_ALL=C sort -u
}

if [ "${1:-}" = "--list" ]; then
  shift
  pick "$@"
  exit 0
fi

base="$(git merge-base HEAD origin/main 2>/dev/null)" \
  || { printf 'reached-checks: cannot find where this branch left origin/main\n' >&2; exit 2; }
changed=()
while IFS= read -r file; do
  [ -n "$file" ] && changed+=("$file")
done < <( { git diff --name-only "$base" HEAD; git diff --name-only HEAD; } | LC_ALL=C sort -u)

bash scripts/check.sh || exit 1

picked="$(pick "${changed[@]+"${changed[@]}"}")"
if [ -z "$picked" ]; then
  printf 'reached-checks: no plugin test reads the root files this branch changes\n'
  exit 0
fi

log="$(mktemp)"
trap 'rm -f "$log"' EXIT
passed=0
failed=0
while IFS= read -r test; do
  if bash "$test" > "$log" 2>&1; then
    printf 'ok    %s\n' "$test"
    passed=$((passed + 1))
  else
    printf 'FAIL  %s\n' "$test"
    tail -20 "$log" | sed 's/^/        /'
    failed=$((failed + 1))
  fi
done <<< "$picked"
printf 'reached-checks: %d plugin tests passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
