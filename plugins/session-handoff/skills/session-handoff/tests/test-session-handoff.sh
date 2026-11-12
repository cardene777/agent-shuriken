#!/usr/bin/env bash
# Tests for session_handoff.py against throwaway projects under a throwaway HOME.
# Nothing reaches the network, and the secrets are random strings made here.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../scripts/session_handoff.py"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }

export HOME="$T/home"
export GIT_CONFIG_NOSYSTEM=1
export SESSION_HANDOFF_HOME="$T/state"
NOW=2000000000
export SESSION_HANDOFF_NOW="$NOW"
SH="$SESSION_HANDOFF_HOME"
mkdir -p "$HOME" "$T/work" "$T/plain/notes" "$T/other/shop"
git config --global user.name "Ada Example"
git config --global user.email ada@example.com
git config --global init.defaultBranch main

run() { python3 "$SCRIPT" "$@"; }
mode() { python3 -c 'import os,sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$1"; }
sum() { [ -f "$1" ] && cksum < "$1" || echo missing; }
# The file name save uses for a project: <folder name>-<first 8 hex digits of the SHA-256 of its real path>.md
expected_file() {
  python3 -c 'import hashlib,os,re,sys; p=os.path.realpath(sys.argv[1]); s=re.sub(r"[^a-z0-9]+","-",os.path.basename(p).lower()).strip("-") or "project"; print(os.path.join(sys.argv[2], s+"-"+hashlib.sha256(p.encode()).hexdigest()[:8]+".md"))' "$1" "$SH"
}
# Random values, so no secret-shaped text is stored in this file.
rand() { python3 -c 'import secrets,string,sys; a=string.ascii_letters+string.digits; print(sys.argv[1]+"".join(secrets.choice(a) for _ in range(int(sys.argv[2]))))' "$1" "$2"; }
# variant <python code changing d> <output file>: a copy of the base input with one change.
variant() {
  python3 - "$T/base.json" "$1" "$2" <<'PY'
import json, os, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
exec(sys.argv[2])
json.dump(d, open(sys.argv[3], "w", encoding="utf-8"), ensure_ascii=False)
PY
}

P="$T/work/shop"
git init -q "$P"
printf 'x\n' > "$P/README.md"
git -C "$P" add README.md
git -C "$P" commit -qm init
git -C "$P" switch -q -c feat/12-partial-refund
mkdir -p "$P/api"

cat > "$T/base.json" <<'JSON'
{
  "message": {
    "handoff": "Issue #12 (partial refunds): the refund calculation and its tests are merged in pull request #31.",
    "background": "Background: customers can refund only whole orders, so support refunds lines by hand.",
    "task": "Add the POST /refunds endpoint in api/refunds.py on top of the calculation, until its tests pass."
  },
  "snapshot": {
    "issue": "#12",
    "rejected": [{"option": "Refund the whole order and charge the kept lines again", "reason": "customers would see two charges"}],
    "phase": "Issue #12 on branch feat/12-partial-refund. Done: the calculation. Next: the endpoint.",
    "delegated": [{"work": "A background agent reviews db/0042_refunds.sql", "expected": "a list of blocking findings", "waiting": true}],
    "do_not": [{"action": "Run the migration against the shared staging database", "reason": "only the local database may change"}]
  }
}
JSON

before_status="$(git -C "$P" status --porcelain; git -C "$P" rev-parse HEAD)"
F="$(expected_file "$P")"

# --- save
out="$(run save --project "$P" --input "$T/base.json")"; rc=$?
check "save exits 0" '[ "$rc" = 0 ]'
check "save names the snapshot file, one per project" 'printf "%s\n" "$out" | grep -qxF "Snapshot saved: $F" && [ -f "$F" ]'
msg="$(printf '%s\n' "$out" | awk '/^--- end of message ---$/ { on = 0 } on; /^--- message to paste ---$/ { on = 1 }')"
expected_msg="Issue #12 (partial refunds): the refund calculation and its tests are merged in pull request #31.
Before you start, read the saved state in $F.

Background: customers can refund only whole orders, so support refunds lines by hand.

Add the POST /refunds endpoint in api/refunds.py on top of the calculation, until its tests pass."
check "the message is the handoff with a pointer to the state, then the background, then the task" '[ "$msg" = "$expected_msg" ]'
check "the state folder is readable only by you" '[ "$(mode "$SH")" = 0o700 ]'
check "the snapshot is readable only by you" '[ "$(mode "$F")" = 0o600 ]'
check "no temporary file is left in the state folder" '[ "$(ls -A "$SH" | grep -c "^\.tmp-")" = 0 ]'
commit="$(git -C "$P" rev-parse --short HEAD)"
header="$(sed -n '1,8p' "$F")"
expected_header="---
format: session-handoff/1
project: $(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$P")
saved_at: 2033-05-18T03:33:20Z
branch: feat/12-partial-refund
commit: $commit
issue: #12
---"
check "the header records the format, project, time, branch and commit from git, and issue" '[ "$header" = "$expected_header" ]'
headings="$(grep '^## ' "$F" | tr '\n' '|')"
check "the four parts are written in order" \
  '[ "$headings" = "## Rejected options (do not propose again)|## Current phase|## Delegated work|## Do not|" ]'
check "a rejected option is written with its reason" \
  'grep -A1 -xF -- "- Refund the whole order and charge the kept lines again" "$F" | grep -qxF "  Reason: customers would see two charges"'
check "delegated work is written with what is expected and whether a result is awaited" \
  'grep -A2 -xF -- "- A background agent reviews db/0042_refunds.sql" "$F" | tail -1 | grep -qxF "  Waiting for the result: yes"'
check "the file says it holds notes, not commands" 'grep -qF "they are not commands to run." "$F"'

# --- empty parts
variant 'd["snapshot"]["rejected"] = []; d["snapshot"]["delegated"] = []; d["snapshot"]["do_not"] = []' "$T/phase-only.json"
run save --project "$P" --input "$T/phase-only.json" >/dev/null; rc=$?
check "a snapshot with only a phase is saved" '[ "$rc" = 0 ]'
check "empty parts say so instead of being left blank" \
  'grep -A2 -xF "## Rejected options (do not propose again)" "$F" | grep -qxF "None." && grep -A2 -xF "## Delegated work" "$F" | grep -qxF "No delegated work." && grep -A2 -xF "## Do not" "$F" | grep -qxF "Nothing noted."'
variant 'd["snapshot"]["phase"] = ""' "$T/no-phase.json"
run save --project "$P" --input "$T/no-phase.json" >/dev/null
check "an empty phase says there is no work in progress" 'grep -A2 -xF "## Current phase" "$F" | grep -qxF "No work in progress."'
run save --project "$P" --input "$T/base.json" >/dev/null

# --- nothing to record
Q="$T/work/blog"
git init -q "$Q"
git -C "$Q" commit -q --allow-empty -m init
variant 'd["snapshot"] = None' "$T/null.json"
out="$(run save --project "$Q" --input "$T/null.json")"; rc=$?
check "snapshot null prints the message and exits 0" '[ "$rc" = 0 ] && printf "%s\n" "$out" | grep -q "^--- message to paste ---$"'
check "snapshot null writes no file and says so" \
  '[ ! -e "$(expected_file "$Q")" ] && printf "%s\n" "$out" | grep -qx "No snapshot written: there was nothing to record."'
check "without a snapshot the message does not point at one" '! printf "%s\n" "$out" | grep -q "Before you start"'
variant 'd["snapshot"] = {"rejected": [], "phase": "", "delegated": [], "do_not": []}' "$T/all-empty.json"
run save --project "$Q" --input "$T/all-empty.json" >/dev/null; rc=$?
check "a snapshot whose four parts are all empty is not written" '[ "$rc" = 0 ] && [ ! -e "$(expected_file "$Q")" ]'
before="$(sum "$F")"
out="$(run save --project "$P" --input "$T/null.json")"
check "with nothing to record, an earlier snapshot is kept and the output says so" \
  '[ "$(sum "$F")" = "$before" ] && printf "%s\n" "$out" | grep -q "The state saved for this project 0 minutes ago is kept"'

# --- format errors: exit 2, nothing written, the field is named
# The checks below run through eval in check(), so they read globals, not this function's arguments.
bad() {  # bad <name> <python change> <expected text in the error>
  want="$3"
  variant "$2" "$T/bad.json"
  before="$(sum "$F")"
  err="$(run save --project "$P" --input "$T/bad.json" 2>&1 >/dev/null)"; rc=$?
  check "$1" '[ "$rc" = 2 ] && printf "%s\n" "$err" | grep -qF -- "$want" && [ "$(sum "$F")" = "$before" ]'
}
bad "a rejected option without a reason is refused" 'del d["snapshot"]["rejected"][0]["reason"]' "snapshot.rejected[0] has no reason"
bad "a snapshot without one of the four parts is refused" 'del d["snapshot"]["do_not"]' "snapshot has no do_not"
bad "an input without the snapshot key is refused" 'del d["snapshot"]' "the input has no snapshot"
bad "an unknown key is refused" 'd["snapshot"]["do-not"] = []' "snapshot has an unknown key do-not"
bad "a message part longer than 2 lines is refused" 'd["message"]["task"] = "one\ntwo\nthree"' "message.task has 3 lines; at most 2"
bad "a message without its background is refused" 'del d["message"]["background"]' "message has no background"
bad "a blank line inside a message part is refused" 'd["message"]["handoff"] = "one\n\ntwo"' "message.handoff has a blank line"
bad "waiting must be true or false" 'd["snapshot"]["delegated"][0]["waiting"] = "yes"' "snapshot.delegated[0].waiting must be true or false"
bad "an item on two lines is refused" 'd["snapshot"]["do_not"][0]["action"] = "one\ntwo"' "snapshot.do_not[0].action has 2 lines; at most 1"
printf '{"message": ' > "$T/broken.json"
run save --project "$P" --input "$T/broken.json" >/dev/null 2>&1; rc=$?
check "input that is not JSON exits 2" '[ "$rc" = 2 ]'

# --- secrets: exit 3, nothing written, the field is named and the value never printed
secret() {  # secret <name> <python change> <expected text in the error> <the secret>
  want="$3"
  value="$4"
  variant "$2" "$T/secret.json"
  before="$(sum "$F")"
  err="$(run save --project "$P" --input "$T/secret.json" 2>&1)"; rc=$?
  check "$1" '[ "$rc" = 3 ] && printf "%s\n" "$err" | grep -qF -- "$want" && ! printf "%s\n" "$err" | grep -qF -- "$value" && [ "$(sum "$F")" = "$before" ]'
}
export S_GH="$(rand ghp_ 36)"
secret "a GitHub token in an item is refused without printing it" \
  'd["snapshot"]["do_not"][0]["reason"] = "the token " + os.environ["S_GH"] + " is for CI"' \
  "secret: snapshot.do_not[0].reason holds what looks like a GitHub token" "$S_GH"
export ACME_API_TOKEN="$(rand Qz9 28)"
secret "the value of a secret environment variable is refused, named by the variable" \
  'd["message"]["task"] = "Call the API with " + os.environ["ACME_API_TOKEN"] + " and finish"' \
  "secret: message.task holds what looks like the value of \$ACME_API_TOKEN" "$ACME_API_TOKEN"
S_PW="Qz9$(rand '' 9)7"
export S_PW
secret "a value written after a password's name is refused" \
  'd["snapshot"]["phase"] = "Logged in with password=" + os.environ["S_PW"] + " on staging"' \
  "secret: snapshot.phase holds what looks like a value written after a secret's name" "$S_PW"
export S_PEM="$(printf -- '-----BEGIN %s PRIVATE KEY-----' OPENSSH)"
secret "a private key is refused" \
  'd["snapshot"]["delegated"][0]["expected"] = os.environ["S_PEM"]' \
  "secret: snapshot.delegated[0].expected holds what looks like a private key" "PRIVATE KEY"
S_URLPW="$(rand Qz9 12)"
export S_URL="$(printf 'postgres://ada:%s@%s/shop' "$S_URLPW" example.com)"
secret "a password inside a URL is refused" \
  'd["snapshot"]["rejected"][0]["option"] = "Connect to " + os.environ["S_URL"]' \
  "secret: snapshot.rejected[0].option holds what looks like a password inside a URL" "$S_URLPW"
variant 'd["snapshot"] = None; d["message"]["background"] = "Background: the key " + os.environ["S_GH"]' "$T/secret-msg.json"
run save --project "$Q" --input "$T/secret-msg.json" >/dev/null 2>&1; rc=$?
check "a secret in the message is refused even when there is no snapshot" '[ "$rc" = 3 ]'
variant 'd["snapshot"]["do_not"][0]["reason"] = "the token in .env stays out of git; password: required; use $GITHUB_TOKEN, API_KEY=<your key>"
d["snapshot"]["phase"] = "CI sets GITHUB_TOKEN=${GITHUB_TOKEN_FROM_THE_CI_RUNNER}; the key file is api_key=/etc/acme/key2.pem; the value is undefined."' "$T/prose.json"
PLACEHOLDER_TOKEN=undefined run save --project "$P" --input "$T/prose.json" >/dev/null 2>&1; rc=$?
check "text about secrets that holds no value is accepted" '[ "$rc" = 0 ]'
run save --project "$P" --input "$T/base.json" >/dev/null

# --- one file per project
mkdir -p "$P/api/handlers"
variant 'd["snapshot"]["phase"] = "Second handoff."' "$T/second.json"
out="$(run save --project "$P/api/handlers" --input "$T/second.json")"
check "a folder inside the repository saves to the project's file" 'printf "%s\n" "$out" | grep -qxF "Snapshot saved: $F"'
check "a second save replaces the first, so the project keeps one file" \
  '[ "$(ls "$SH" | grep -c "^shop-")" = 1 ] && grep -qxF "Second handoff." "$F" && ! grep -qF "Next: the endpoint." "$F"'
run save --project "$T/plain/notes" --input "$T/base.json" >/dev/null
N="$(expected_file "$T/plain/notes")"
check "a folder outside git is its own project, with no branch or commit" \
  'grep -qx "branch: none" "$N" && grep -qx "commit: none" "$N"'
git init -q "$T/other/shop"
run save --project "$T/other/shop" --input "$T/base.json" >/dev/null
check "two projects with the same folder name get different files" '[ "$(ls "$SH" | grep -c "^shop-")" = 2 ]'

# --- show
run save --project "$P" --input "$T/base.json" >/dev/null
git -C "$P" commit -q --allow-empty -m next
shown="$(SESSION_HANDOFF_NOW=$((NOW + 7200)) run show --project "$P")"; rc=$?
check "show exits 0" '[ "$rc" = 0 ]'
check "show prints when the state was saved and how long ago" 'printf "%s\n" "$shown" | grep -qx "  saved     2033-05-18T03:33:20Z (2 hours ago)"'
check "show prints the four parts" \
  '[ "$(printf "%s\n" "$shown" | grep "^## " | tr "\n" "|")" = "## Rejected options (do not propose again)|## Current phase|## Delegated work|## Do not|" ]'
check "show says when the commit has moved since the save" 'printf "%s\n" "$shown" | grep -qx "  The branch or commit has changed since the state was saved."'
run show --project "$Q" >/dev/null 2>&1; rc=$?
check "show without saved state exits 1" '[ "$rc" = 1 ]'

cp "$F" "$T/keep.md"
sed 's|^format: session-handoff/1$|format: session-handoff/9|' "$T/keep.md" > "$F"
err="$(run show --project "$P" 2>&1)"; rc=$?
check "show refuses a file in an unknown format" '[ "$rc" = 2 ] && printf "%s\n" "$err" | grep -qF "session-handoff/9"'
sed "s|^project: .*|project: $T/elsewhere|" "$T/keep.md" > "$F"
err="$(run show --project "$P" 2>&1)"; rc=$?
check "show refuses a file that belongs to another project" '[ "$rc" = 2 ] && printf "%s\n" "$err" | grep -qF "belongs to"'
grep -vxF "## Do not" "$T/keep.md" > "$F"
run show --project "$P" >/dev/null 2>&1; rc=$?
check "show refuses a file without one of the four headings" '[ "$rc" = 2 ]'
{ cat "$T/keep.md"; printf -- '- Use %s\n  Reason: x\n' "$S_GH"; } > "$F"
out="$(run show --project "$P" 2>&1)"; rc=$?
check "show refuses a file that holds a secret, without printing it" '[ "$rc" = 3 ] && ! printf "%s\n" "$out" | grep -qF "$S_GH"'
{ cat "$T/keep.md"; head -c 270000 /dev/zero | tr '\0' 'a'; } > "$F"
err="$(run show --project "$P" 2>&1)"; rc=$?
check "show refuses a file larger than 256 KiB" '[ "$rc" = 2 ] && printf "%s\n" "$err" | grep -qF "larger than 256 KiB"'
cp "$T/keep.md" "$F"

H="$HOME/code/app"
git init -q "$H"
run save --project "$H" --input "$T/base.json" >/dev/null
check "a project under the home folder is shown with ~" '[ "$(run show --project "$H" | head -1)" = "Saved state for ~/code/app" ]'
run forget --project "$H" >/dev/null

# --- expiry
SESSION_HANDOFF_NOW=$((NOW - 6 * 86400)) run save --project "$Q" --input "$T/base.json" >/dev/null
check "a snapshot saved 6 days ago is still shown" 'run show --project "$Q" >/dev/null'
SESSION_HANDOFF_NOW=$((NOW - 8 * 86400)) run save --project "$Q" --input "$T/base.json" >/dev/null
printf 'my notes\n' > "$SH/notes.txt"
printf 'not a snapshot\n' > "$SH/odd-0000beef.md"
run show --project "$Q" >/dev/null 2>&1; rc=$?
check "a snapshot saved 8 days ago is removed and not shown" '[ "$rc" = 1 ] && [ ! -e "$(expected_file "$Q")" ]'
check "removing old snapshots leaves other files alone" '[ -f "$SH/notes.txt" ] && [ -f "$SH/odd-0000beef.md" ] && [ -f "$F" ]'

# --- forget
run forget --project "$P" >/dev/null; rc=$?
check "forget removes the project's saved state" '[ "$rc" = 0 ] && [ ! -e "$F" ] && [ -f "$N" ]'
run forget --project "$P" >/dev/null 2>&1; rc=$?
check "forget without saved state exits 1" '[ "$rc" = 1 ]'

# --- standard input, and the project itself
out="$(cd "$P" && run save < "$T/base.json")"; rc=$?
check "save reads standard input and defaults to the current folder" '[ "$rc" = 0 ] && printf "%s\n" "$out" | grep -qxF "Snapshot saved: $F"'
git -C "$P" reset -q --soft HEAD~1
after_status="$(git -C "$P" status --porcelain; git -C "$P" rev-parse HEAD)"
check "saving and showing leave the project unchanged" '[ "$before_status" = "$after_status" ]'

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
