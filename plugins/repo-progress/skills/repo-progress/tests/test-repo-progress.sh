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

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
