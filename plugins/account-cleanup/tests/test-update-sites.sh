#!/usr/bin/env bash
# Tests for tools/update-sites.sh, the command maintainers run to copy the newest JustDeleteMe list.
# Each run works on a throwaway copy of the plugin's tools, notice, and list, and a stand-in for gh
# comes first on PATH and records how it was called, so no real file or network is touched.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$(cd "$HERE/.." && pwd)"
LIST=skills/account-cleanup/data/sites.json
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; [ -n "${why:-}" ] && printf '        %s\n' "$why"; }
check() { why=""; if "$2"; then ok "$1"; else ng "$1"; fi; }

export ACCOUNT_CLEANUP_TODAY=2026-11-30
export GH_LOG="$T/gh.log" GH_FILE="$T/download.json"
export GH_SHA=0123456789abcdef0123456789abcdef01234567
mkdir -p "$T/bin"
export PATH="$T/bin:$PATH"

# --- stand-in for gh: answers the two calls the command makes, and fails on request
cat > "$T/bin/gh" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >> "$GH_LOG"
case "$*" in
  *commits/*) [ "${GH_FAILS:-}" = commit ] && exit 1; printf '%s\n' "$GH_SHA" ;;
  *contents/*) [ "${GH_FAILS:-}" = file ] && exit 1; cat "$GH_FILE" ;;
  *) exit 1 ;;
esac
SH
chmod +x "$T/bin/gh"

# A fresh copy of the parts of the plugin the command reads and writes, and the copies to compare with.
fresh() {
  rm -rf "$T/plugin" "$T/before" "$GH_LOG"
  mkdir -p "$T/plugin/skills/account-cleanup/data" "$T/before"
  [ -d "$PLUGIN/tools" ] && cp -R "$PLUGIN/tools" "$T/plugin/tools"
  cp "$PLUGIN/THIRD_PARTY_NOTICES.md" "$T/plugin/THIRD_PARTY_NOTICES.md"
  cp "$PLUGIN/$LIST" "$T/plugin/$LIST"
  cp "$T/plugin/THIRD_PARTY_NOTICES.md" "$T/before/notice.md"
  cp "$T/plugin/$LIST" "$T/before/sites.json"
}
# run_tool: runs the copied command; status holds its exit.
run_tool() {
  [ -f "$T/plugin/tools/update-sites.sh" ] || { why="tools/update-sites.sh is missing"; return 1; }
  bash "$T/plugin/tools/update-sites.sh" > "$T/out.log" 2>&1
  status=$?
}
unchanged() {
  cmp -s "$T/before/sites.json" "$T/plugin/$LIST" || { why="$1: sites.json changed"; return 1; }
  cmp -s "$T/before/notice.md" "$T/plugin/THIRD_PARTY_NOTICES.md" || { why="$1: THIRD_PARTY_NOTICES.md changed"; return 1; }
}

# A small list in the upstream shape, written with its own spacing so a reformatted copy would differ.
cat > "$T/good.json" <<'JSON'
[
    {"name": "Alpha", "url": "https://a.example/delete", "difficulty": "easy", "domains": ["a.example"]},
    {"name": "Beta", "domains": ["b.example", "beta.example"]}
]
JSON

copies_unmodified() {
  fresh; cp "$T/good.json" "$GH_FILE"
  run_tool || return 1
  [ "$status" = 0 ] || { why="exited $status: $(tail -1 "$T/out.log")"; return 1; }
  cmp -s "$T/good.json" "$T/plugin/$LIST" || { why="sites.json is not the downloaded file byte for byte"; return 1; }
}

writes_notice() {
  fresh; cp "$T/good.json" "$GH_FILE"
  run_tool || return 1
  [ "$status" = 0 ] || { why="exited $status: $(tail -1 "$T/out.log")"; return 1; }
  local n="$T/plugin/THIRD_PARTY_NOTICES.md" changed
  grep -qxF "| Source commit | \`$GH_SHA\` |" "$n" || { why="the Source commit row does not name $GH_SHA"; return 1; }
  grep -qxF "| Copied on | $ACCOUNT_CLEANUP_TODAY |" "$n" || { why="the Copied on row does not say $ACCOUNT_CLEANUP_TODAY"; return 1; }
  changed=$(diff "$T/before/notice.md" "$n" | grep -c '^[<>]')
  [ "$changed" = 4 ] || { why="$changed lines changed in the notice, not the two rows"; return 1; }
}

refuses_bad_download() {
  local body
  for body in '{"name": "Alpha", "domains": ["a.example"]}' '[]' '[{"name": "Alpha"}]' '[{"domains": ["a.example"]}]' 'not json'; do
    fresh; printf '%s\n' "$body" > "$GH_FILE"
    run_tool || return 1
    [ "$status" != 0 ] || { why="exited 0 for the download: $body"; return 1; }
    unchanged "the download $body" || return 1
  done
}

nothing_when_gh_fails() {
  local where
  for where in commit file; do
    fresh; cp "$T/good.json" "$GH_FILE"
    export GH_FAILS=$where
    run_tool || { unset GH_FAILS; return 1; }
    unset GH_FAILS
    [ "$status" != 0 ] || { why="exited 0 when gh failed on the $where"; return 1; }
    unchanged "gh failed on the $where" || return 1
  done
}

asks_only_upstream() {
  fresh; cp "$T/good.json" "$GH_FILE"
  run_tool || return 1
  [ "$status" = 0 ] || { why="exited $status: $(tail -1 "$T/out.log")"; return 1; }
  local calls
  calls=$(wc -l < "$GH_LOG" | tr -d ' ')
  [ "$calls" = 2 ] || { why="gh was called $calls times, not twice"; return 1; }
  grep -q '^api repos/jdm-contrib/jdm/commits/' "$GH_LOG" || { why="no call for the newest commit"; return 1; }
  grep -qF "api repos/jdm-contrib/jdm/contents/_data/sites.json?ref=$GH_SHA" "$GH_LOG" || { why="no call for _data/sites.json at $GH_SHA"; return 1; }
  ! grep -qE '(^| )(-X|--method|-f|-F|--field|--raw-field|--input)( |$)' "$GH_LOG" || { why="a gh call sends data: $(cat "$GH_LOG")"; return 1; }
}

skill_never_runs() {
  local hits
  hits=$(grep -rlF 'update-sites' "$PLUGIN/skills" 2>/dev/null)
  [ -z "$hits" ] || { why="named under skills/: $hits"; return 1; }
}

docs_describe() {
  why=$(python3 -I - "$PLUGIN" <<'PY'
import sys
plugin = sys.argv[1]
# The Japanese word for maintaining is built from its code points, so this test holds no Japanese text.
maintain = chr(0x4FDD) + chr(0x5B88)
words = {"README.md": "maintainer", "docs/how-it-works.md": "maintainer",
         "README.ja.md": maintain, "docs/how-it-works.ja.md": maintain}
for page, word in words.items():
    try:
        text = open(f"{plugin}/{page}", encoding="utf-8").read()
    except OSError:
        print(f"{page} is missing"); sys.exit(1)
    for need in ("tools/update-sites.sh", "GitHub", word):
        if need.lower() not in text.lower():
            print(f"{page} does not name {need.encode('ascii', 'backslashreplace').decode()}"); sys.exit(1)
PY
) || return 1
}

notice_names() {
  grep -qF 'tools/update-sites.sh' "$PLUGIN/THIRD_PARTY_NOTICES.md" || { why="THIRD_PARTY_NOTICES.md does not name tools/update-sites.sh"; return 1; }
}

changelog_names() {
  grep -qF 'tools/update-sites.sh' "$PLUGIN/CHANGELOG.md" || { why="CHANGELOG.md does not name tools/update-sites.sh"; return 1; }
}

check "update-sites copies the newest upstream list unmodified" copies_unmodified
check "update-sites writes the commit and date into the notice" writes_notice
check "update-sites refuses a download that is not a site list" refuses_bad_download
check "update-sites changes nothing when gh fails" nothing_when_gh_fails
check "update-sites asks GitHub only for the upstream commit and file" asks_only_upstream
check "the skill never runs update-sites" skill_never_runs
check "the READMEs and how-it-works pages describe update-sites" docs_describe
check "the notice names update-sites" notice_names
check "the changelog names update-sites" changelog_names

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ]
