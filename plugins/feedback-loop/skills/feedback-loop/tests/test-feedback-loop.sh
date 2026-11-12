#!/usr/bin/env bash
# Tests for feedback_loop.py against throwaway repositories under a throwaway HOME.
# Nothing reaches the network; the only commands checked are true, false, test, and sleep.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../scripts/feedback_loop.py"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }

export HOME="$T/home"
export GIT_CONFIG_NOSYSTEM=1
export FEEDBACK_LOOP_HOME="$T/state"
export FEEDBACK_LOOP_NOW=2000000000
export TZ=UTC
mkdir -p "$HOME" "$T/outside"
git config --global user.name "Ada Example"
git config --global user.email ada@example.com
git config --global init.defaultBranch main

fl() { python3 "$SCRIPT" "$@"; }
mode() { python3 -c 'import os,sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$1"; }
# field <file> <python expression on d>: prints a value from a JSON file.
field() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$1" "$2"; }
last_event() { python3 -c 'import json,sys; print(json.dumps(json.loads(open(sys.argv[1]).read().splitlines()[-1])))' "$1"; }
pass_review() { printf -- '- user-feedback: PASS - the correction is resolved\n- regression: PASS - the cases still hold\n'; }

# A repository under HOME, so records must write its path as ~/shop.
R="$HOME/shop"
git init -q "$R"
mkdir -p "$R/docs"
printf 'Intro\nThis step leverages synergy.\n' > "$R/docs/guide.md"
printf 'notes\n' > "$R/notes.md"
git -C "$R" add -A
git -C "$R" commit -qm init
RR="$(cd "$R" && pwd -P)"
clean_status="$(git -C "$R" status --porcelain)"

# --- where
fl where --repo "$T/outside" >/dev/null 2>"$T/err"; rc=$?
check "outside a git repository it exits 2 and says nothing is recorded" '[ "$rc" = 2 ] && grep -q "nothing is recorded" "$T/err"'
where="$(fl where --repo "$R")"; rc=$?
STORE="$(printf '%s\n' "$where" | sed -n 's/^records *\([^ ]*\).*/\1/p')"
check "where exits 0 and names a private records folder under FEEDBACK_LOOP_HOME" \
  '[ "$rc" = 0 ] && [[ "$STORE" == "$FEEDBACK_LOOP_HOME/repos/shop-"* ]] && printf "%s\n" "$where" | grep -q "private, readable only by you"'
check "where creates nothing" '[ ! -e "$FEEDBACK_LOOP_HOME" ]'

# --- open
fl open --repo "$R" --subject "Jargon" --artifact docs/guide.md </dev/null >/dev/null 2>&1; rc=$?
check "open without the user's words exits 2" '[ "$rc" = 2 ]'
echo "wrong" | fl open --repo "$R" --subject "x" --artifact ../outside/x.md >/dev/null 2>&1; rc=$?
check "a file outside the repository is refused" '[ "$rc" = 2 ]'
echo "wrong" | fl open --repo "$R" --subject "x" --artifact "$T/outside/x.md" >/dev/null 2>&1; rc=$?
check "an absolute path outside the repository is refused" '[ "$rc" = 2 ]'
printf 'secret\n' > "$T/outside/secret.md"
ln -s "$T/outside/secret.md" "$R/link.md"
echo "wrong" | fl open --repo "$R" --subject "x" --artifact link.md >/dev/null 2>&1; rc=$?
check "a symbolic link that leads outside the repository is refused" '[ "$rc" = 2 ]'
rm "$R/link.md"
echo "wrong" | fl open --repo "$R" --subject "x" --artifact .git/config >/dev/null 2>&1; rc=$?
check "a file inside .git is refused" '[ "$rc" = 2 ]'
echo "wrong" | fl open --repo "$R" --subject "x" --artifact docs/guide.md --criterion "Bad Id=x" >/dev/null 2>&1; rc=$?
check "a criterion id with spaces or capitals is refused" '[ "$rc" = 2 ]'
echo "wrong" | fl open --repo "$R" --subject "x" --artifact docs/guide.md --criterion "regression=again" >/dev/null 2>&1; rc=$?
check "a criterion id used twice is refused" '[ "$rc" = 2 ]'
check "refused opens leave no record" '[ ! -d "$STORE/pending" ] || [ -z "$(ls -A "$STORE/pending")" ]'

CORRECTION="That word is jargon, not needed. Say it plainly."
out="$(printf '%s\n' "$CORRECTION" | fl open --repo "$R" --subject "Jargon in the guide" --expected "Plain words" \
  --artifact docs/guide.md --criterion "plain=Every sentence uses words a newcomer knows")"; rc=$?
ID=fb-20330518-001
P="$STORE/pending/$ID.json"
check "open exits 0 and names the new id" '[ "$rc" = 0 ] && printf "%s\n" "$out" | grep -q "^Opened $ID: Jargon in the guide"'
check "the record is open with the hash of the user's words" \
  '[ "$(field "$P" "d[\"status\"]")" = open ] && [ "$(field "$P" "d[\"source_sha256\"]")" = "$(printf "%s" "$CORRECTION" | shasum -a 256 | cut -d" " -f1)" ]'
check "the record never holds the user's words" '! grep -q "Say it plainly" "$P"'
check "the criteria are the two fixed ones plus the extra one" \
  '[ "$(field "$P" "\",\".join(r[\"id\"] for r in d[\"loop\"][\"rubric\"])")" = "user-feedback,regression,plain" ]'
check "the repository is written as ~/shop" '[ "$(field "$P" "d[\"target_repository\"]")" = "~/shop" ] && ! grep -q "$HOME" "$P"'
check "the state folder and the records folder are readable only by you" \
  '[ "$(mode "$FEEDBACK_LOOP_HOME")" = 0o700 ] && [ "$(mode "$STORE")" = 0o700 ] && [ "$(mode "$STORE/pending")" = 0o700 ]'
check "the record file is readable only by you" '[ "$(mode "$P")" = 0o600 ]'
check "open writes rules.md for the repository" '[ -f "$STORE/rules.md" ] && [ "$(mode "$STORE/rules.md")" = 0o600 ]'
out="$(printf '%s\n' "$CORRECTION" | fl open --repo "$R" --subject "Again" --artifact docs/guide.md)"
check "the same words again do not open a second record" \
  'printf "%s\n" "$out" | grep -q "Already open as $ID" && [ "$(ls "$STORE/pending" | wc -l | tr -d " ")" = 1 ]'
check "the repository itself is unchanged" '[ "$(git -C "$R" status --porcelain)" = "$clean_status" ]'

# --- scope, case, and rule
fl classify --repo "$R" "$ID" everywhere >/dev/null 2>&1; rc=$?
check "an unknown scope is refused" '[ "$rc" = 2 ]'
fl case --repo "$R" "$ID" --forbid synergy --require "Intro" --question "Does every sentence say who does what?" >/dev/null; rc=$?
CASE="$(field "$P" "d[\"case_files\"][0]")"
check "case exits 0 and notes its file in the record" '[ "$rc" = 0 ] && [ -f "$STORE/$CASE" ]'
check "the case file is readable only by you" '[ "$(mode "$STORE/$CASE")" = 0o600 ]'
fl case --repo "$R" "$ID" >/dev/null 2>&1; rc=$?
check "case without a condition exits 2" '[ "$rc" = 2 ]'
fl rule --repo "$R" "$ID" no-such-file.md >/dev/null 2>&1; rc=$?
check "a rule file that does not exist is refused" '[ "$rc" = 2 ]'

# --- check
fl check --repo "$R" "$ID" >"$T/out" 2>&1; rc=$?
check "the case check fails while the forbidden word is there" \
  '[ "$rc" = 1 ] && grep -q "docs/guide.md must not contain \"synergy\"" "$T/out"'
printf 'This step leverages synergy.\n' > "$R/docs/guide.md"
fl check --repo "$R" "$ID" >"$T/out" 2>&1
check "a required text that is gone is reported" 'grep -q "must contain \"Intro\"" "$T/out"'
printf 'review\n' | fl review --repo "$R" "$ID" --evaluator x --kind independent_llm >/dev/null 2>"$T/err"; rc=$?
check "review is refused until the checks pass" '[ "$rc" = 1 ] && grep -q "failed on the files as they are now" "$T/err"'

printf 'Intro\nThis step shares the work.\n' > "$R/docs/guide.md"
fl check --repo "$R" "$ID" -- test -f docs/guide.md >"$T/out" 2>&1; rc=$?
check "check passes when the cases hold and the command exits 0" '[ "$rc" = 0 ] && grep -q "case checks: 2 of 2 conditions hold" "$T/out"'
fl check --repo "$R" "$ID" -- false >/dev/null 2>&1; rc=$?
check "a failing command makes check exit 1" '[ "$rc" = 1 ]'
pass_review | fl review --repo "$R" "$ID" --evaluator x --kind independent_llm >/dev/null 2>"$T/err"; rc=$?
check "a command whose latest run failed on these files blocks the review" '[ "$rc" = 1 ] && grep -q "false" "$T/err"'
fl check --repo "$R" "$ID" --timeout 1 -- sleep 5 >/dev/null 2>&1; rc=$?
check "a command over its time limit is stopped and counted as failed" \
  '[ "$rc" = 1 ] && [ "$(field "$P" "d[\"verification\"][\"runs\"][-1][\"commands\"][-1][\"exit_code\"]")" = 124 ]'
fl check --repo "$R" "$ID" -- no-such-command-here >/dev/null 2>&1; rc=$?
check "a command that does not exist is counted as failed" '[ "$rc" = 1 ]'
printf 'Intro\nThis step shares the work with you.\n' > "$R/docs/guide.md"
fl check --repo "$R" "$ID" -- test -f docs/guide.md >/dev/null 2>&1; rc=$?
check "after the next change only the new runs count" '[ "$rc" = 0 ]'

# --- review
printf -- '- user-feedback: PASS - fine\n- regression: PASS - fine\n' | fl review --repo "$R" "$ID" --evaluator x --kind independent_llm >/dev/null 2>"$T/err"; rc=$?
check "a review without a line for every criterion exits 2" '[ "$rc" = 2 ] && grep -q "no verdict line for plain" "$T/err"'
printf -- '- user-feedback: PASS - a\n- user-feedback: FAIL - b\n- regression: PASS - c\n- plain: PASS - d\n' \
  | fl review --repo "$R" "$ID" --evaluator x --kind independent_llm >/dev/null 2>"$T/err"; rc=$?
check "a criterion with two verdict lines exits 2" '[ "$rc" = 2 ] && grep -q "more than one verdict line" "$T/err"'
printf -- 'Criteria: user-feedback, regression, plain\nAll PASS\n' | fl review --repo "$R" "$ID" --evaluator x --kind independent_llm >/dev/null 2>&1; rc=$?
check "a review that only lists the criteria exits 2" '[ "$rc" = 2 ]'
{ pass_review; echo "- plain: PASS - ok"; } | fl review --repo "$R" "$ID" --evaluator tests --kind deterministic >/dev/null 2>"$T/err"; rc=$?
check "a hybrid correction refuses a review by tests alone" '[ "$rc" = 2 ] && grep -q "independent_llm or --kind human" "$T/err"'
check "refused reviews record no round" '[ "$(field "$P" "len(d[\"loop\"][\"iterations\"])")" = 0 ]'

printf -- '- user-feedback: PASS - the word is gone\n- regression: PASS - the cases hold\n- plain: FAIL - "shares the work" is still vague\n' \
  | fl review --repo "$R" "$ID" --evaluator "review agent" --kind independent_llm >"$T/out" 2>&1; rc=$?
check "a failing round exits 1 and lists what must change" '[ "$rc" = 1 ] && grep -q "plain: \"shares the work\" is still vague" "$T/out"'
check "the failing round is recorded with its finding" \
  '[ "$(field "$P" "d[\"loop\"][\"iterations\"][0][\"evaluation\"][\"verdict\"]")" = fail ] && [ "$(field "$P" "d[\"loop\"][\"iterations\"][0][\"evaluation\"][\"findings\"][0][\"id\"]")" = plain ]'
check "the review is saved for the round and readable only by you" \
  '[ -f "$STORE/reviews/$ID-1.md" ] && [ "$(mode "$STORE/reviews/$ID-1.md")" = 0o600 ]'
fl close --repo "$R" "$ID" >"$T/out" 2>&1; rc=$?
check "close refuses after a failing round" '[ "$rc" = 1 ] && grep -q "did not pass" "$T/out"'

printf 'Intro\nThis step sends the order to the warehouse.\n' > "$R/docs/guide.md"
{ pass_review; echo "- plain: PASS - ok"; } | fl review --repo "$R" "$ID" --evaluator x --kind independent_llm >/dev/null 2>"$T/err"; rc=$?
check "a review of files changed since the last check is refused" '[ "$rc" = 1 ] && grep -q "No check ran on the files as they are now" "$T/err"'
fl check --repo "$R" "$ID" -- test -f docs/guide.md >/dev/null 2>&1
{ pass_review; echo "- plain: PASS - every sentence says who does what"; } > "$T/review2.md"
fl review --repo "$R" "$ID" --evaluator "review agent" --kind independent_llm --file "$T/review2.md" >"$T/out" 2>&1; rc=$?
check "a passing round exits 0" '[ "$rc" = 0 ] && grep -q "Round 2 of $ID passed" "$T/out"'

# --- close
printf 'Intro\nThis step sends the order to the store.\n' > "$R/docs/guide.md"
fl close --repo "$R" "$ID" >"$T/out" 2>&1; rc=$?
check "close refuses when a file changed after the passing review" '[ "$rc" = 1 ] && grep -q "changed after the last review: docs/guide.md" "$T/out"'
printf 'Intro\nThis step sends the order to the warehouse.\n' > "$R/docs/guide.md"
cp "$STORE/reviews/$ID-2.md" "$T/saved-review"
printf -- '- plain: PASS - edited later\n' >> "$STORE/reviews/$ID-2.md"
fl close --repo "$R" "$ID" >"$T/out" 2>&1; rc=$?
check "close refuses when the review file changed after it was recorded" '[ "$rc" = 1 ] && grep -q "changed after it was recorded" "$T/out"'
cp "$T/saved-review" "$STORE/reviews/$ID-2.md"
fl close --repo "$R" "$ID" >"$T/out" 2>&1; rc=$?
check "close refuses while the scope is not set" '[ "$rc" = 1 ] && grep -q "scope is not set" "$T/out"'
fl classify --repo "$R" "$ID" repository >/dev/null
fl close --repo "$R" "$ID" >"$T/out" 2>&1; rc=$?
check "a repository correction needs a rule file" '[ "$rc" = 1 ] && grep -q "no rule file was noted" "$T/out"'
fl classify --repo "$R" "$ID" artifact >/dev/null
fl case --repo "$R" "$ID" --remove "$ID" >/dev/null
fl close --repo "$R" "$ID" >"$T/out" 2>&1; rc=$?
check "an artifact correction needs a case entry of its own" '[ "$rc" = 1 ] && grep -q "no case holds an entry" "$T/out"'
fl case --repo "$R" "$ID" --forbid synergy >/dev/null
fl check --repo "$R" "$ID" -- test -f docs/guide.md >/dev/null 2>&1
fl close --repo "$R" "$ID" >"$T/out" 2>&1; rc=$?
check "close exits 0 once the last round passed on the files as they are" '[ "$rc" = 0 ] && grep -q "Closed $ID after 2 round(s)" "$T/out"'
check "the open record is removed" '[ ! -e "$P" ]'
E="$STORE/events.jsonl"
ev="$(last_event "$E")"
check "the log holds the resolved correction with a final pass" \
  'printf "%s" "$ev" | python3 -c "import json,sys; e=json.load(sys.stdin); sys.exit(0 if (e[\"id\"], e[\"status\"], e[\"loop\"][\"final_verdict\"], len(e[\"loop\"][\"iterations\"])) == (\"'"$ID"'\", \"resolved\", \"pass\", 2) else 1)"'
check "the log records the checks and the final file hashes" \
  'printf "%s" "$ev" | python3 -c "import json,sys,hashlib; e=json.load(sys.stdin); h=hashlib.sha256(open(sys.argv[1],\"rb\").read()).hexdigest(); sys.exit(0 if e[\"verification\"][\"artifacts\"]==[{\"path\":\"docs/guide.md\",\"sha256\":h}] and all(c[\"exit_code\"]==0 for c in e[\"verification\"][\"commands\"]) else 1)" "$R/docs/guide.md"'
check "the log is readable only by you and never holds the home path" '[ "$(mode "$E")" = 0o600 ] && ! grep -q "$HOME" "$E"'
fl status --repo "$R" "$ID" >/dev/null 2>&1; rc=$?
check "a closed id is no longer open" '[ "$rc" = 2 ]'
check "status says when nothing is open" '[ "$(fl status --repo "$R")" = "No open corrections." ]'

# --- history and repeats
check "history lists the closed correction for its file" \
  'fl history --repo "$R" --artifact docs/guide.md | grep -q "^$ID  2033-05-18  resolved  scope artifact  rounds 2  Jargon in the guide"'
check "history for another file lists nothing" '[ "$(fl history --repo "$R" --artifact notes.md)" = "No closed corrections." ]'
out="$(printf '%s\n' "$CORRECTION" | fl open --repo "$R" --subject "Jargon again" --artifact docs/guide.md)"
ID2=fb-20330518-002
check "the same words after closing open a new record and point at the earlier one" \
  'printf "%s\n" "$out" | grep -q "^Opened $ID2" && printf "%s\n" "$out" | grep -q "closed before as $ID"'
out="$(printf 'The guide is still unclear\n' | fl open --repo "$R" --subject "Unclear guide" --artifact docs/guide.md)"
ID3=fb-20330518-003
check "a new correction to the same file names the earlier ones" 'printf "%s\n" "$out" | grep -q "Earlier correction to these files: $ID"'
check "status lists the open corrections with their next step" \
  'fl status --repo "$R" | grep -qE "^$ID2 +- +0/3 +fix, then check +Jargon again"'
fl drop --repo "$R" "$ID3" --reason "The user withdrew it" >/dev/null; rc=$?
check "drop moves the record to the log with its reason" \
  '[ "$rc" = 0 ] && [ ! -e "$STORE/pending/$ID3.json" ] && last_event "$E" | grep -q "\"drop_reason\": \"The user withdrew it\""'

# --- the round limit
printf 'unneeded\n' > "$R/old.md"
git -C "$R" add old.md
git -C "$R" commit -qm old
out="$(printf 'This file is not needed\n' | fl open --repo "$R" --subject "Unneeded file" --artifact old.md --mode independent-review --max-iterations 1)"
ID4=fb-20330518-004
fl classify --repo "$R" "$ID4" one-off >/dev/null
fl check --repo "$R" "$ID4" -- true >/dev/null
printf -- '- user-feedback: FAIL - the file is still there\n- regression: PASS - nothing else changed\n' \
  | fl review --repo "$R" "$ID4" --evaluator x --kind independent_llm >"$T/out" 2>&1; rc=$?
check "a failing last round exits 3 and says to ask the user" '[ "$rc" = 3 ] && grep -q "last of 1 rounds" "$T/out"'
rm "$R/old.md"
fl check --repo "$R" "$ID4" -- true >/dev/null
pass_review | fl review --repo "$R" "$ID4" --evaluator x --kind independent_llm >/dev/null 2>&1; rc=$?
check "past the limit an agent's review is refused" '[ "$rc" = 3 ]'
fl extend --repo "$R" "$ID4" --rounds 1 >/dev/null
pass_review | fl review --repo "$R" "$ID4" --evaluator x --kind independent_llm >/dev/null 2>&1; rc=$?
check "after extend another round is allowed" '[ "$rc" = 0 ]'
fl close --repo "$R" "$ID4" >/dev/null 2>&1; rc=$?
check "a deleted file closes as missing" \
  '[ "$rc" = 0 ] && last_event "$E" | grep -q "\"path\": \"old.md\", \"sha256\": \"missing\""'

printf 'v1\n' > "$R/limit.md"
printf 'too long\n' | fl open --repo "$R" --subject "Too long" --artifact limit.md --max-iterations 1 >/dev/null
ID5=fb-20330518-005
fl check --repo "$R" "$ID5" -- true >/dev/null
printf -- '- user-feedback: FAIL - long\n- regression: PASS - ok\n' | fl review --repo "$R" "$ID5" --evaluator x --kind independent_llm >/dev/null 2>&1
printf -- '- user-feedback: PASS - the user accepts it\n- regression: PASS - ok\n' | fl review --repo "$R" "$ID5" --evaluator "the user" --kind human >/dev/null 2>&1; rc=$?
check "past the limit the user's own verdict is accepted" '[ "$rc" = 0 ]'

# --- bad case file and bad ids
fl case --repo "$R" "$ID5" --forbid "never" >/dev/null
printf '{"version": 1, "target": "limit.md", "entries": "oops"}\n' > "$STORE/$(field "$STORE/pending/$ID5.json" "d[\"case_files\"][0]")"
fl check --repo "$R" "$ID5" -- true >/dev/null 2>"$T/err"; rc=$?
check "a malformed case file stops the check and is named" '[ "$rc" = 2 ] && grep -q "is not a case file" "$T/err"'
fl status --repo "$R" "not-an-id" >/dev/null 2>&1; rc=$?
check "an id of the wrong form exits 2" '[ "$rc" = 2 ]'

# --- rules outside the repository
fl classify --repo "$R" "$ID2" global >/dev/null
printf '# Rules\n- Write plain words\n' > "$HOME/agent-rules.md"
fl rule --repo "$R" "$ID2" "$HOME/agent-rules.md" "$STORE/rules.md" >/dev/null
check "a rule file under HOME is written as ~/..." \
  '[ "$(field "$STORE/pending/$ID2.json" "d[\"rule_files\"][0]")" = "~/agent-rules.md" ]'

# --- records inside the repository
fl where --repo "$R" --use .feedback >/dev/null; rc=$?
check "where --use keeps the records in a folder inside the repository" \
  '[ "$rc" = 0 ] && fl where --repo "$R" | grep -q "^records *$RR/.feedback  (inside the repository)"'
printf 'Wrong title\n' | fl open --repo "$R" --subject "Title" --artifact notes.md >/dev/null
check "a correction opened then is written inside the repository" '[ -f "$R/.feedback/pending/fb-20330518-001.json" ]'
fl where --repo "$R" --use ../elsewhere >/dev/null 2>&1; rc=$?
check "a records folder outside the repository is refused" '[ "$rc" = 2 ]'
fl where --repo "$R" --private >/dev/null
check "where --private goes back to the private folder" 'fl where --repo "$R" | grep -q "^records *$STORE  (private"'

# --- worktrees share the records of their clone
git -C "$R" worktree add -q -b fix/2-title "$T/wt-title"
check "a linked worktree uses the records of its main clone" 'fl where --repo "$T/wt-title" | grep -q "^records *$STORE "'

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
