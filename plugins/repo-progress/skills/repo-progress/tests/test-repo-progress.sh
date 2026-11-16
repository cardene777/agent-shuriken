#!/usr/bin/env bash
# Tests for repo_progress.py against throwaway repositories under a throwaway HOME.
# A stand-in for gh prints fixed JSON, so nothing reaches the network.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../scripts/repo_progress.py"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }

export HOME="$T/home"
export GIT_CONFIG_NOSYSTEM=1
export REPO_PROGRESS_HOME="$T/state"
export REPO_PROGRESS_GH="$T/bin/gh"
export REPO_PROGRESS_NOW=2000000000
export MOCK_DIR="$T/mock"
export MOCK_LOG="$T/mock.log"
unset REPO_PROGRESS_ROOTS REPO_PROGRESS_AUTHOR
mkdir -p "$HOME" "$T/bin" "$MOCK_DIR" "$T/root1/group/sub" "$T/root2" "$T/wt" "$T/empty"
git config --global user.name "Ada Example"
git config --global user.email ada@example.com
git config --global init.defaultBranch main

# The stand-in for gh: `gh -R <slug> <issue|pr> list ...` prints mock/<slug>.<kind>.json or fails.
cat > "$T/bin/gh" <<'SH'
#!/usr/bin/env bash
slug="$2"; kind="$3"
printf '%s %s\n' "$slug" "$kind" >> "$MOCK_LOG"
f="$MOCK_DIR/$(printf '%s' "$slug" | tr '/' '_').$kind.json"
[ -f "$f" ] || exit 1
cat "$f"
SH
chmod +x "$T/bin/gh"

day=86400
# make_repo <folder> <origin url> <days before NOW of the last commit> [author name]
make_repo() {
  local dir="$1" url="$2" days="$3" who="${4:-Ada Example}" when
  when="@$((REPO_PROGRESS_NOW - days * day)) +0000"
  git init -q "$dir"
  printf 'x\n' > "$dir/README.md"
  git -C "$dir" add README.md
  GIT_AUTHOR_DATE="$when" GIT_COMMITTER_DATE="$when" \
    git -C "$dir" -c user.name="$who" -c user.email=someone@example.com commit -qm init
  git -C "$dir" remote add origin "$url"
}

# An SSH remote such as git@<host>:<owner>/<name>.git, built here so the file holds no address-like text.
ssh_remote() { printf '%s@%s:%s.git' git "$1" "$2"; }

A="$T/root1/alpha"
make_repo "$A" "$(ssh_remote github.com acme/alpha)" 10
git -C "$A" worktree add -q -b feat/2-login "$T/wt/alpha-login"
git -C "$A" worktree add -q -b fix/9-old "$T/wt/alpha-old"
git -C "$A" worktree add -q -b chore/5-gone "$T/wt/alpha-gone"
rm -rf "$T/wt/alpha-gone"
printf 'draft\n' > "$A/notes.txt"
git clone -q "$A" "$T/root1/alpha-copy"
git -C "$T/root1/alpha-copy" remote set-url origin https://github.com/acme/alpha.git

B="$T/root1/beta"
make_repo "$B" https://github.com/acme/beta.git 2
git -C "$B" switch -q -c feature/4-search

G="$T/root1/group/gamma"
make_repo "$G" "$(ssh_remote github.com acme/gamma)" 30
git -C "$G" switch -q -c feat/8-sync

make_repo "$T/root1/group/sub/deep" "$(ssh_remote github.com acme/deep)" 1
make_repo "$T/root1/other" "$(ssh_remote github.com acme/other)" 1 "Bob Example"
make_repo "$T/root2/delta" "$(ssh_remote gitlab.com acme/delta)" 5

cat > "$MOCK_DIR/acme_alpha.issue.json" <<'JSON'
[{"number": 1, "title": "Write the docs", "updatedAt": "2033-05-01T00:00:00Z"},
 {"number": 2, "title": "Add login", "updatedAt": "2033-05-02T00:00:00Z"},
 {"number": 3, "title": "Fix the footer", "updatedAt": "2033-05-03T00:00:00Z"}]
JSON
printf '[{"number": 7, "title": "Add login", "headRefName": "feat/2-login"}]\n' > "$MOCK_DIR/acme_alpha.pr.json"
printf '[{"number": 4, "title": "Search", "updatedAt": "2033-05-04T00:00:00Z"}]\n' > "$MOCK_DIR/acme_beta.issue.json"
printf '[]\n' > "$MOCK_DIR/acme_beta.pr.json"
cat > "$MOCK_DIR/acme_other.issue.json" <<'JSON'
[{"number": 1, "title": "Other work", "updatedAt": "2033-05-01T00:00:00Z"}]
JSON
printf '[]\n' > "$MOCK_DIR/acme_other.pr.json"

run() { python3 "$SCRIPT" --root "$T/root1" --root "$T/root2" "$@"; }

before_status="$(git -C "$A" status --porcelain; git -C "$A" worktree list --porcelain; ls -A "$A")"

# --- the table
table="$(run)"; rc=$?
check "the table exits 0" '[ "$rc" = 0 ]'
order="$(printf '%s\n' "$table" | awk 'NR > 1 && NF { print $1 }' | head -6 | tr '\n' ' ')"
check "stalled repositories come first: alpha (idle 30) before beta (idle 2)" '[[ "$order" == "alpha alpha-copy beta "* ]]'
check "repositories that cannot be measured come last" '[[ "$order" == *"delta group/gamma "* ]]'
check "a count line names the repositories that could not be measured" \
  'printf "%s\n" "$table" | grep -q "^2 repositories could not be measured and are listed last (idle is ?)."'
check "a repository one level deeper is found and named by its relative path" 'printf "%s\n" "$table" | grep -q "^group/gamma "'
check "a repository two levels deeper is not scanned" '! printf "%s\n" "$table" | grep -q "deep"'
check "a repository without your commits is not listed" '! printf "%s\n" "$table" | grep -qE "^other "'
alpha_row="$(printf '%s\n' "$table" | grep -E '^alpha ')"
check "alpha shows 3 worktrees, 3 issues, 1 pull request, 1 uncommitted file, and idle 30" \
  '[[ "$(printf "%s" "$alpha_row" | awk "{print \$2, \$3, \$4, \$5, \$6}")" == "3 3 1 1 30" ]]'
check "the default branch is shown as such" 'printf "%s\n" "$alpha_row" | grep -q "default branch"'
check "beta shows the issue its branch points at" 'printf "%s\n" "$table" | grep -E "^beta " | grep -q "#4 Search"'
check "gh is asked once per repository even when it is cloned twice" '[ "$(grep -c "^acme/alpha issue$" "$MOCK_LOG")" = 1 ]'

# --- JSON
json="$(run --json)"
check "every JSON line parses" 'printf "%s\n" "$json" | python3 -c "import json,sys; [json.loads(l) for l in sys.stdin]"'
check "a failed gh call gives null issues, null pull requests, and null idle" \
  'printf "%s\n" "$json" | python3 -c "import json,sys; r=[json.loads(l) for l in sys.stdin]; g=[x for x in r if x[\"repo\"]==\"group/gamma\"][0]; sys.exit(0 if (g[\"issues\"], g[\"prs\"], g[\"idle\"]) == (None, None, None) else 1)"'
check "a remote outside GitHub is read as unknown" \
  'printf "%s\n" "$json" | python3 -c "import json,sys; r=[json.loads(l) for l in sys.stdin]; d=[x for x in r if x[\"repo\"]==\"delta\"][0]; sys.exit(0 if d[\"issues\"] is None and d[\"slug\"]==\"gitlab.com/acme/delta\" else 1)"'
check "alpha has idle 30 in JSON" \
  'printf "%s\n" "$json" | python3 -c "import json,sys; r=[json.loads(l) for l in sys.stdin]; a=[x for x in r if x[\"repo\"]==\"alpha\"][0]; sys.exit(0 if a[\"idle\"]==30 else 1)"'

# --- one repository
detail="$(run --repo alpha)"
section() { printf '%s\n' "$detail" | awk -v s="[$1]" 'index($0, s) { on = 1; next } /^  \[/ { on = 0 } on'; }
check "a branch whose issue is open is in progress, with its pull request" \
  'section "In progress" | grep -q "feat/2-login .*#2 Add login  (pull request #7)"'
check "a branch whose issue is not open is to clean up" 'section "To clean up" | grep -q "fix/9-old .*#9 is not an open issue"'
check "a worktree whose folder is gone is to clean up" 'section "To clean up" | grep -q "chore/5-gone .*prunable"'
check "waiting lists the open issues no branch points at" \
  'printf "%s\n" "$detail" | grep -q "\[Waiting\] 2 issues" && printf "%s\n" "$detail" | grep -q "#1 " && printf "%s\n" "$detail" | grep -q "#3 "'
check "an issue in progress is not repeated as waiting" '! printf "%s\n" "$detail" | grep -qE "^    #2 "'

detail="$(run --repo group/gamma)"
check "when gh fails, a numbered branch is unknown, not to clean up" \
  'section "Unknown" | grep -q "feat/8-sync" && section "To clean up" | grep -q "none"'
check "when gh fails, waiting is unknown" 'printf "%s\n" "$detail" | grep -q "\[Waiting\] unknown"'
run --repo missing >/dev/null 2>&1; rc=$?
check "an unknown --repo exits 1" '[ "$rc" = 1 ]'

# --- author
other="$(run --author "Bob Example")"
check "--author lists only that author's repositories" \
  '[ "$(printf "%s\n" "$other" | awk "NR > 1 && NF { print \$1 }" | tr "\n" " ")" = "other " ]'
HOME="$T/nobody" python3 "$SCRIPT" --root "$T/root1" >/dev/null 2>"$T/err"; rc=$?
check "without any author it exits 2 before scanning" '[ "$rc" = 2 ] && grep -q "Cannot tell which commits are yours" "$T/err"'

# --- roots
python3 "$SCRIPT" --root "$T/empty" >/dev/null 2>&1; rc=$?
check "a root with no repository exits 1" '[ "$rc" = 1 ]'
python3 "$SCRIPT" --root "$T/root2" --save-roots >/dev/null; rc=$?
check "--save-roots exits 0" '[ "$rc" = 0 ]'
check "the saved roots file is readable only by you" \
  '[ "$(python3 -c "import os,sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))" "$REPO_PROGRESS_HOME/roots")" = 0o600 ]'
check "the state folder is readable only by you" \
  '[ "$(python3 -c "import os,sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))" "$REPO_PROGRESS_HOME")" = 0o700 ]'
saved="$(python3 "$SCRIPT")"
check "a scan without --root uses the saved roots" \
  '[ "$(printf "%s\n" "$saved" | awk "NR > 1 && !NF { exit } NR > 1 { print \$1 }" | tr "\n" " ")" = "delta " ]'
check "--show-roots names where the roots come from" 'python3 "$SCRIPT" --show-roots | grep -q "from $REPO_PROGRESS_HOME/roots"'
python3 "$SCRIPT" --save-roots >/dev/null 2>&1; rc=$?
check "--save-roots without --root exits 2" '[ "$rc" = 2 ]'

# --- read-only
after_status="$(git -C "$A" status --porcelain; git -C "$A" worktree list --porcelain; ls -A "$A")"
check "scans leave the repository unchanged" '[ "$before_status" = "$after_status" ]'

# --- the SKILL.md and its eval suite
# The checks below run through eval in check(), so they read globals, not a function's arguments.
PLUGIN="$(cd "$HERE/../../.." && pwd)"
EVALS="$PLUGIN/evals"
SKILL="$HERE/../SKILL.md"
CASES=(asks-name asks-folders sums-up-saved-table deletes-nothing unrelated-request)

eval_cases() {
  local c
  for c in "${CASES[@]}"; do
    [ -f "$EVALS/$c/case.yaml" ] && [ -x "$EVALS/$c/fixture.sh" ] || return 1
  done
}
check "the eval suite has the five cases" eval_cases

# In the eval sandbox git fails, so the agent's scan reads no name and no repository. This git does the same.
mkdir -p "$T/nogit"
printf '#!/bin/sh\nexit 128\n' > "$T/nogit/git"
chmod +x "$T/nogit/git"

# fixture <case>: runs the case's fixture.sh the way claude plugin eval does (in home/cwd with HOME at
# home, which is a git repository, and none of this test's REPO_PROGRESS_ settings) and prints the workspace.
fixture() {
  local home="$T/fixture-$1/home"
  mkdir -p "$home/cwd"
  git init -q "$home"
  (cd "$home/cwd" && unset REPO_PROGRESS_HOME REPO_PROGRESS_GH REPO_PROGRESS_NOW && HOME="$home" bash "$EVALS/$1/fixture.sh") > /dev/null 2>&1 || return 1
  printf '%s\n' "$home/cwd"
}
# sandbox_scan <case> <args...>: runs the scan as the agent's run sees it and prints its exit code.
sandbox_scan() {
  local home="$T/fixture-$1/home"
  shift
  (cd "$home/cwd" && unset REPO_PROGRESS_HOME REPO_PROGRESS_GH REPO_PROGRESS_NOW && HOME="$home" PATH="$T/nogit:$PATH" python3 "$SCRIPT" "$@") > /dev/null 2>&1
  printf '%s\n' "$?"
}
fixtures_ready() {
  local c ws
  for c in "${CASES[@]}"; do
    ws="$(fixture "$c")" || return 1
    [ ! -e "$ws/.git" ] && [ ! -e "$T/fixture-$c/home/.gitconfig" ] || return 1
    case "$c" in
      asks-name) [ "$(sandbox_scan "$c")" = 2 ] || return 1 ;;
      asks-folders) [ "$(sandbox_scan "$c" --author "Dana Kim")" = 1 ] || return 1 ;;
      sums-up-saved-table)
        python3 - "$ws/progress.txt" <<'PYEOF' || return 1
import sys
lines = [l.split() for l in open(sys.argv[1]).read().splitlines() if l.strip()]
head = lines[0]
rows = [l for l in lines[1:] if not l[0][0].isdigit()]
issues, prs = head.index("issues"), head.index("prs")
sys.exit(0 if head[0] == "repo" and len(rows) >= 2 and all(r[issues] == "?" and r[prs] == "?" for r in rows) else 1)
PYEOF
        ;;
      deletes-nothing)
        [ -d "$ws/shop/.git" ] || return 1
        git -C "$ws/shop" rev-parse -q --verify refs/heads/fix/15-typo > /dev/null || return 1
        [ "$(git -C "$ws/shop" branch --merged main --format='%(refname:short)' | grep -v '^main$')" = feat/12-login ] || return 1 ;;
    esac
  done
}
check "the eval fixtures build the states their cases start from" fixtures_ready

results_ignored() {
  local repo
  repo="$(git -C "$PLUGIN" rev-parse --show-toplevel 2>/dev/null)" || return 1
  git -C "$repo" check-ignore -q "${EVALS#"$repo"/}/results/run.json"
}
check "eval results are ignored by git" results_ignored

# The body is counted in words and the description in characters, as the size the agent reads.
SKILL_WORDS_MAX=576
SKILL_DESCRIPTION_MAX=288
skill_size() {
  python3 - "$SKILL" "$SKILL_WORDS_MAX" "$SKILL_DESCRIPTION_MAX" <<'PYEOF'
import re, sys
front, body = open(sys.argv[1], encoding="utf-8").read().split("---", 2)[1:]
words = len(body.split())
chars = len(re.search(r"^description: (.*)$", front, re.M).group(1))
print("      SKILL.md body %d words (max %s), description %d characters (max %s)" % (words, sys.argv[2], chars, sys.argv[3]))
sys.exit(0 if words <= int(sys.argv[2]) and chars <= int(sys.argv[3]) else 1)
PYEOF
}
check "the SKILL.md stays within its size limits" skill_size

skill_rules() {
  local phrase
  for phrase in \
    'It never changes a repository, a branch, a worktree, or an issue' \
    'The skill never deletes anything' \
    'Say that it is unknown, never that it is 0' \
    'Ask the user which folders hold their repositories' \
    'Ask the user for the name or email they commit with' \
    'never guess it from an account or address you know' \
    'name each item, confirm it with the user, and check that its work is merged before removing it'; do
    grep -qF -- "$phrase" "$SKILL" || return 1
  done
}
check "the SKILL.md keeps its rules on changing nothing, unknown values, and asking first" skill_rules

printf '%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
