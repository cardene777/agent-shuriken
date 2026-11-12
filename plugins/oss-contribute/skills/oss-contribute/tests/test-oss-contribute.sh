#!/usr/bin/env bash
# Tests for oss_contribute.py against throwaway git remotes under a throwaway HOME.
# Stand-ins for gh and docker answer from local files, git may use only file:// remotes, and a gh or
# docker found on PATH fails the run, so nothing reaches the network.
#
# Set OSS_CONTRIBUTE_TEST_IMAGE to an image that is already on this machine (it is never pulled) to
# also run the checks in a real Docker container and confirm the isolation.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../scripts/oss_contribute.py"
PASS=0
FAIL=0
T="$(mktemp -d)"
T="$(cd "$T" && pwd -P)"
REAL_DOCKER="$(command -v docker || true)"
REAL_HOME="$HOME"
trap 'rm -rf "$T"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }

export HOME="$T/home"
export GIT_CONFIG_NOSYSTEM=1
export GIT_ALLOW_PROTOCOL=file
export OSS_CONTRIBUTE_HOME="$T/state"
export OSS_CONTRIBUTE_GH="$T/bin/gh"
export OSS_CONTRIBUTE_DOCKER="$T/bin/docker"
export OSS_CONTRIBUTE_GIT_BASE="file://$T/remotes"
export MOCK_STATE="$T/mock/state.json"
export MOCK_LOG="$T/mock/gh.log"
export MOCK_POSTS="$T/mock/posts.jsonl"
export MOCK_REMOTES="$T/remotes"
export DOCKER_LOG="$T/mock/docker.jsonl"
export GH_TOKEN=fake-token-for-tests
mkdir -p "$HOME" "$T/bin" "$T/mock" "$T/remotes" "$T/work" "$T/trap"
ln -s "$T/remotes" "$T/remotes/ssh"

# A real gh or docker on PATH would mean the script ignored its stand-in.
for c in gh docker; do
  printf '#!/bin/sh\necho "real %s was called" >> "%s/trap.log"\nexit 99\n' "$c" "$T" > "$T/trap/$c"
  chmod +x "$T/trap/$c"
done
export PATH="$T/trap:$PATH"

git config --global user.name "Ada Example"
git config --global user.email ada@example.com
git config --global init.defaultBranch main

# --- stand-ins -------------------------------------------------------------

cat > "$T/bin/gh" <<'PY'
#!/usr/bin/env python3
# Stand-in for gh: answers `gh api` and `gh config get` from $MOCK_STATE and records every POST.
import json, os, subprocess, sys, urllib.parse
args = sys.argv[1:]
with open(os.environ["MOCK_LOG"], "a") as f:
    f.write(" ".join(args) + "\n")
state_path = os.environ["MOCK_STATE"]
remotes = os.environ["MOCK_REMOTES"]
with open(state_path) as f:
    s = json.load(f)
def save():
    with open(state_path, "w") as f:
        json.dump(s, f, indent=1)
def out(value):
    print(json.dumps(value))
    sys.exit(0)
def fail(message):
    print("gh: " + message, file=sys.stderr)
    sys.exit(1)
if args[:2] == ["config", "get"]:
    print(s.get("protocol", "https"))
    sys.exit(0)
if not args or args[0] != "api":
    fail("unexpected command " + " ".join(args))
method, rest = "GET", args[1:]
if rest[:1] == ["-X"]:
    method, rest = rest[1], rest[2:]
endpoint = rest[0]
payload = json.loads(sys.stdin.read()) if "--input" in rest else None
if method == "POST":
    with open(os.environ["MOCK_POSTS"], "a") as f:
        f.write(json.dumps({"endpoint": endpoint, "payload": payload}) + "\n")
if s.get("fail_all"):
    fail("HTTP 503")
path, _, query = endpoint.partition("?")
params = dict(urllib.parse.parse_qsl(query))
if path == "user":
    out({"login": s["login"]})
parts = path.split("/")
if len(parts) < 3 or parts[0] != "repos":
    fail("unexpected endpoint " + endpoint)
repo = parts[1] + "/" + parts[2]
info = s["repos"].get(repo)
if info is None:
    fail("Not Found (HTTP 404)")
tail = parts[3:]
base = "https://github.com/" + repo
if not tail:
    out({"full_name": info.get("full_name", repo), "archived": info.get("archived", False),
         "has_issues": info.get("has_issues", True)})
if tail == ["private-vulnerability-reporting"]:
    out({"enabled": info.get("pvr", False)})
if tail == ["forks"] and method == "POST":
    full = s["login"] + "/" + parts[2]
    bare = os.path.join(remotes, full + ".git")
    if not os.path.isdir(bare):
        subprocess.run(["git", "clone", "-q", "--bare", os.path.join(remotes, repo + ".git"), bare], check=True)
    out({"full_name": full, "clone_url": "file://" + bare, "ssh_url": "file://" + remotes + "/ssh/" + full + ".git"})
def new_number():
    n = s["next"]
    s["next"] += 1
    return n
if tail == ["pulls"]:
    if method == "POST":
        n = new_number()
        pr = {"number": n, "title": payload["title"], "body": payload["body"], "state": "open",
              "user": {"login": s["login"]}, "head": {"label": payload["head"]}, "html_url": base + "/pull/%d" % n}
        s["pulls"].setdefault(repo, []).append(pr)
        save()
        out(pr)
    items = [p for p in s["pulls"].get(repo, []) if p["state"] == params.get("state", "open")]
    if "head" in params:
        items = [p for p in items if p["head"]["label"] == params["head"]]
    out(items)
if tail == ["issues"]:
    if method == "POST":
        n = new_number()
        it = {"number": n, "title": payload["title"], "body": payload["body"], "state": "open", "locked": False,
              "user": {"login": s["login"]}, "html_url": base + "/issues/%d" % n}
        s["issues"].setdefault(repo, []).append(it)
        save()
        out(it)
    items = [i for i in s["issues"].get(repo, []) if i["state"] == params.get("state", "open")]
    if "creator" in params:
        items = [i for i in items if i["user"]["login"] == params["creator"]]
    out(items)
if len(tail) == 2 and tail[0] == "issues":
    for it in s["issues"].get(repo, []):
        if it["number"] == int(tail[1]):
            out(it)
    for pr in s["pulls"].get(repo, []):
        if pr["number"] == int(tail[1]):
            out(dict(pr, pull_request={}, locked=False))
    fail("Not Found (HTTP 404)")
if len(tail) == 3 and tail[0] == "issues" and tail[2] == "comments" and method == "POST":
    out({"html_url": base + "/issues/%s#issuecomment-1" % tail[1]})
fail("unexpected endpoint " + endpoint)
PY
chmod +x "$T/bin/gh"

cat > "$T/bin/docker" <<'PY'
#!/usr/bin/env python3
# Stand-in for docker: records every call and exits as the test asks.
import json, os, sys
args = sys.argv[1:]
with open(os.environ["DOCKER_LOG"], "a") as f:
    f.write(json.dumps(args) + "\n")
if args[:1] == ["info"]:
    sys.exit(int(os.environ.get("DOCKER_INFO_RC", "0")))
if args[:1] == ["run"]:
    net = args[args.index("--network") + 1] if "--network" in args else ""
    if net == "none":
        print("fake check phase")
        sys.exit(int(os.environ.get("DOCKER_TEST_RC", "0")))
    print("fake dependency phase")
    sys.exit(int(os.environ.get("DOCKER_DEPS_RC", "0")))
sys.exit(0)
PY
chmod +x "$T/bin/docker"

cat > "$MOCK_STATE" <<'JSON'
{"login": "ada", "protocol": "https", "next": 100,
 "repos": {"acme/shop": {"pvr": true}},
 "issues": {"acme/shop": [
   {"number": 12, "title": "Typo in the install guide", "state": "open", "locked": false, "user": {"login": "bob"}, "html_url": "https://github.com/acme/shop/issues/12"},
   {"number": 13, "title": "Old discussion", "state": "open", "locked": true, "user": {"login": "bob"}, "html_url": "https://github.com/acme/shop/issues/13"},
   {"number": 14, "title": "Existing report", "state": "open", "locked": false, "user": {"login": "ada"}, "html_url": "https://github.com/acme/shop/issues/14"}]},
 "pulls": {}}
JSON

# mock '<python statement on s>' changes the stand-in's state.
mock() {
  python3 - "$MOCK_STATE" "$1" <<'PY'
import json, sys
path, code = sys.argv[1], sys.argv[2]
with open(path) as f:
    s = json.load(f)
exec(code)
with open(path, "w") as f:
    json.dump(s, f, indent=1)
PY
}
# posts '<python expression on p>' counts the recorded POSTs for which it is true.
posts() {
  python3 - "$MOCK_POSTS" "$1" <<'PY'
import json, os, sys
path, expr = sys.argv[1], sys.argv[2]
items = [json.loads(l) for l in open(path)] if os.path.exists(path) else []
print(sum(1 for p in items if eval(expr)))
PY
}
# dlog '<python expression on calls>' is true when the expression over the docker calls is true.
dlog() {
  python3 - "$DOCKER_LOG" "$1" <<'PY'
import json, os, sys
path, expr = sys.argv[1], sys.argv[2]
calls = [json.loads(l) for l in open(path)] if os.path.exists(path) else []
sys.exit(0 if eval(expr) else 1)
PY
}
mode() { python3 -c 'import os, sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$1"; }
oc() { python3 "$SCRIPT" "$@"; }

# --- the upstream project ----------------------------------------------------

SEED="$T/seed"
git init -q "$SEED"
mkdir -p "$SEED/.github/workflows"
printf '# Shop\n\nInstal the package with npm.\n' > "$SEED/README.md"
cat > "$SEED/.github/CONTRIBUTING.md" <<'MD'
# Contributing

Open an issue before large changes.
Sign off every commit with `git commit -s` (DCO).
Pull requests written by AI tools must say so in the description.
MD
printf '# Security\n\nReport vulnerabilities through GitHub private reporting.\n' > "$SEED/SECURITY.md"
printf '## What changed\n\n## How it was tested\n' > "$SEED/.github/pull_request_template.md"
cat > "$SEED/.github/workflows/ci.yml" <<'YML'
jobs:
  test:
    steps:
      - uses: actions/setup-node@v4
        with:
          node-version: 22
      - run: npm ci
      - run: npm test
      - name: Lint
        run: |
          npm run lint
          npm run format:check
YML
printf '{"name": "shop", "scripts": {"test": "node --test", "lint": "eslint ."}}\n' > "$SEED/package.json"
printf 'TOPSECRET notes about the AI keys\n' > "$HOME/private.txt"
ln -s "$HOME/private.txt" "$SEED/CODE_OF_CONDUCT.md"
git -C "$SEED" add -A
git -C "$SEED" commit -qm init
mkdir -p "$T/remotes/acme"
git clone -q --bare "$SEED" "$T/remotes/acme/shop.git"
CLONE="$OSS_CONTRIBUTE_HOME/clones/acme/shop"

# --- start -------------------------------------------------------------------

out="$(oc start --repo acme/shop --branch fix/readme-typo 2>&1)"; rc=$?
check "start clones the project and exits 0" '[ "$rc" = 0 ] && [ -d "$CLONE/.git" ]'
check "start names the project's remote upstream and adds no other remote" '[ "$(git -C "$CLONE" remote)" = upstream ]'
check "start creates the branch from the default branch" \
  '[ "$(git -C "$CLONE" branch --show-current)" = fix/readme-typo ] && printf "%s" "$out" | grep -q "default branch  main"'
check "the state folder and the clones folder are readable only by you" \
  '[ "$(mode "$OSS_CONTRIBUTE_HOME")" = 0o700 ] && [ "$(mode "$OSS_CONTRIBUTE_HOME/clones")" = 0o700 ]'
oc start --repo acme >/dev/null 2>&1; rc=$?
check "a repository without an owner exits 2" '[ "$rc" = 2 ]'
oc start --repo ../shop >/dev/null 2>&1; rc=$?
check "a repository name with a path exits 2" '[ "$rc" = 2 ]'
oc start --repo acme/missing >/dev/null 2>&1; rc=$?
check "a project that cannot be cloned exits 1 and leaves no folder" '[ "$rc" = 1 ] && [ ! -e "$OSS_CONTRIBUTE_HOME/clones/acme/missing" ]'
out="$(oc start --repo acme/shop 2>&1)"; rc=$?
check "start on an existing clone updates it" '[ "$rc" = 0 ] && printf "%s" "$out" | grep -q "(updated)"'

# --- rules -------------------------------------------------------------------

rules="$(oc rules --repo acme/shop)"; rc=$?
check "rules exits 0" '[ "$rc" = 0 ]'
check "rules finds CONTRIBUTING under .github, SECURITY.md, and the pull request template" \
  'printf "%s" "$rules" | grep -q "contributing     .github/CONTRIBUTING.md" && printf "%s" "$rules" | grep -q "security         SECURITY.md" && printf "%s" "$rules" | grep -q "pr templates     .github/pull_request_template.md"'
check "rules reports that sign-off is asked for, with the line" \
  'printf "%s" "$rules" | grep -q "sign-off         asked for" && printf "%s" "$rules" | grep -q ".github/CONTRIBUTING.md:4"'
check "rules quotes the AI policy line with its place" \
  'printf "%s" "$rules" | grep -q ".github/CONTRIBUTING.md:5  Pull requests written by AI tools"'
check "rules lists the check commands, including a multi-line run block and package scripts" \
  'printf "%s" "$rules" | grep -q "node-version: 22" && printf "%s" "$rules" | grep -q "run: npm ci" && printf "%s" "$rules" | grep -q "ci.yml:12  npm run format:check" && printf "%s" "$rules" | grep -q "package.json  lint: eslint ."'
check "rules does not follow a symbolic link out of the clone" \
  'printf "%s" "$rules" | grep -q "not read         CODE_OF_CONDUCT.md" && ! printf "%s" "$rules" | grep -q TOPSECRET'
check "rules --json says sign-off is asked for" \
  'oc rules --repo acme/shop --json | python3 -c "import json,sys; sys.exit(0 if json.load(sys.stdin)[\"signoff\"][\"asked\"] else 1)"'

# --- security ----------------------------------------------------------------

check "security points at the private reporting form when it is on" \
  'oc security --repo acme/shop | grep -q "enabled: https://github.com/acme/shop/security/advisories/new"'
mock 's["repos"]["acme/shop"]["pvr"] = False'
check "security says when private reporting is off" 'oc security --repo acme/shop | grep -q "not enabled on GitHub"'
mock 's["fail_all"] = True'
check "security says unknown, not off, when GitHub cannot be asked" 'oc security --repo acme/shop | grep -q "private reporting  unknown"'
mock 's["fail_all"] = False; s["repos"]["acme/shop"]["pvr"] = True'

# --- check -------------------------------------------------------------------

DOCKER_INFO_RC=1 python3 "$SCRIPT" check --repo acme/shop --image node:22 --deps 'npm ci' --test 'npm test' >/dev/null 2>&1; rc=$?
check "check exits 3 when Docker is not running" '[ "$rc" = 3 ]'
check "check runs nothing when Docker is not running" 'dlog "not any(c[0] in (\"run\", \"volume\") for c in calls)"'
: > "$DOCKER_LOG"
out="$(oc check --repo acme/shop --image node:22 --deps 'npm ci' --test 'npm test' 2>&1)"; rc=$?
check "check exits 0 when both phases pass" '[ "$rc" = 0 ] && printf "%s" "$out" | grep -q "The check phase passed."'
check "the dependency phase runs first with the network, the check phase after without it" \
  'dlog "[c[c.index(\"--network\") + 1] for c in calls if c[0] == \"run\"] == [\"bridge\", \"none\"]"'
check "both phases mount the clone read-only" \
  'dlog "all(\"$CLONE:/src:ro\" in c for c in calls if c[0] == \"run\")"'
check "no phase gets the Docker socket or the host environment" \
  'dlog "not any(\"docker.sock\" in a or \"GH_TOKEN\" in a or \"SSH_AUTH_SOCK\" in a for c in calls for a in c)"'
check "both phases drop new privileges and use the cache volume of this project" \
  'dlog "all(\"no-new-privileges\" in c and \"oss-contribute-cache-acme-shop:/cache\" in c for c in calls if c[0] == \"run\")"'
check "the work volume is removed after the run" \
  'dlog "[a for c in calls if c[0] == \"run\" for a in c if a.endswith(\":/work\")][0][:-6] in [c[-1] for c in calls if c[:3] == [\"volume\", \"rm\", \"-f\"]]"'
: > "$DOCKER_LOG"
DOCKER_DEPS_RC=4 python3 "$SCRIPT" check --repo acme/shop --image node:22 --deps 'npm ci' --test 'npm test' >/dev/null 2>&1; rc=$?
check "a failing dependency phase exits 1 and skips the check phase" \
  '[ "$rc" = 1 ] && dlog "[c for c in calls if c[0] == \"run\" and \"none\" in c] == [] and any(c[:3] == [\"volume\", \"rm\", \"-f\"] for c in calls)"'
: > "$DOCKER_LOG"
DOCKER_TEST_RC=1 python3 "$SCRIPT" check --repo acme/shop --image node:22 --test 'npm test' >/dev/null 2>&1; rc=$?
check "a failing check phase exits 1 and still removes the work volume" \
  '[ "$rc" = 1 ] && dlog "any(c[:3] == [\"volume\", \"rm\", \"-f\"] for c in calls)"'
: > "$DOCKER_LOG"
oc check --repo acme/shop --image=--privileged --test 'npm test' >/dev/null 2>&1; rc=$?
check "an image that looks like an option exits 2 before Docker is called" '[ "$rc" = 2 ] && [ ! -s "$DOCKER_LOG" ]'
mkdir -p "$T/elsewhere/repo" "$OSS_CONTRIBUTE_HOME/clones/evil"
git init -q "$T/elsewhere/repo"
ln -s "$T/elsewhere/repo" "$OSS_CONTRIBUTE_HOME/clones/evil/repo"
oc check --repo evil/repo --image node:22 --test 'npm test' >/dev/null 2>&1; rc=$?
check "a clone that is a symbolic link out of the state folder exits 2 before Docker is called" '[ "$rc" = 2 ] && [ ! -s "$DOCKER_LOG" ]'
rm -rf "$OSS_CONTRIBUTE_HOME/clones/evil"

# --- draft a pull request -----------------------------------------------------

printf '# Shop\n\nInstall the package with npm.\n' > "$CLONE/README.md"
printf 'Fix the spelling of "install" in the README\n' > "$T/work/title.txt"
printf '## What changed\n\nFixes a typo in the README.\n\n## How it was tested\n\nRan npm test in a container.\n\nThis change was prepared with an AI coding agent and reviewed by me.\n' > "$T/work/body.md"
printf 'README no tsuzuri wo naoshimashita.\n' > "$T/work/translation.md"
oc draft --repo acme/shop --kind pr --title-file "$T/work/title.txt" --body-file "$T/work/body.md" >/dev/null 2>&1; rc=$?
check "a draft is refused while the clone has changes that are not committed" '[ "$rc" = 1 ]'
printf 'Fix the spelling of install\n' > "$T/work/msg.txt"
git -C "$CLONE" commit -qas -F "$T/work/msg.txt"
HEAD1="$(git -C "$CLONE" rev-parse HEAD)"
git -C "$CLONE" switch -q main
oc draft --repo acme/shop --kind pr --title-file "$T/work/title.txt" --body-file "$T/work/body.md" >/dev/null 2>&1; rc=$?
check "a pull request draft is refused on the default branch" '[ "$rc" = 1 ]'
git -C "$CLONE" switch -q -c empty upstream/main
oc draft --repo acme/shop --kind pr --title-file "$T/work/title.txt" --body-file "$T/work/body.md" >/dev/null 2>&1; rc=$?
check "a pull request draft is refused when the branch has no commits" '[ "$rc" = 1 ]'
git -C "$CLONE" switch -q fix/readme-typo
git -C "$CLONE" branch -q -D empty
oc draft --repo acme/shop --kind issue --body-file "$T/work/body.md" >/dev/null 2>&1; rc=$?
check "an issue draft without a title exits 2" '[ "$rc" = 2 ]'

draft="$(oc draft --repo acme/shop --kind pr --title-file "$T/work/title.txt" --body-file "$T/work/body.md" --translation-file "$T/work/translation.md")"; rc=$?
PR=acme-shop-pr-1
D="$OSS_CONTRIBUTE_HOME/drafts/$PR"
CODE="$(printf '%s\n' "$draft" | awk '$1 == "fingerprint" { print $2 }')"
check "a pull request draft exits 0 and gets the id $PR" '[ "$rc" = 0 ] && printf "%s" "$draft" | grep -q "^Draft $PR$"'
check "the draft shows the branch, the target, the body, the translation, the commit, and the diff" \
  'printf "%s" "$draft" | grep -q "into         main" && printf "%s" "$draft" | grep -q "Fixes a typo in the README." && printf "%s" "$draft" | grep -q "README no tsuzuri" && printf "%s" "$draft" | grep -q "commits (1)" && printf "%s" "$draft" | grep -q "^+Install the package with npm."'
check "the draft quotes the project's AI policy before the approval" \
  'printf "%s" "$draft" | grep -q "say about AI" && printf "%s" "$draft" | grep -q "Pull requests written by AI tools"'
check "a signed-off commit with a clean diff has no findings" 'printf "%s" "$draft" | grep -A1 -- "----- findings -----" | grep -q "  none"'
check "the fingerprint code is 12 hex characters" '[[ "$CODE" =~ ^[0-9a-f]{12}$ ]]'
check "the draft folder is readable only by you" \
  '[ "$(mode "$D")" = 0o700 ] && [ "$(mode "$D/body.md")" = 0o600 ] && [ "$(mode "$D/draft.json")" = 0o600 ] && [ "$(mode "$D/diff.patch")" = 0o600 ]'

# --- approval ----------------------------------------------------------------

oc approve "$PR" --fingerprint 000000000000 >/dev/null 2>&1; rc=$?
check "a wrong fingerprint is refused and records nothing" '[ "$rc" = 1 ] && [ ! -e "$D/approval.json" ]'
oc send "$PR" >/dev/null 2>&1; rc=$?
check "an unapproved draft is not sent" '[ "$rc" = 1 ] && [ "$(posts True)" = 0 ] && [ ! -d "$T/remotes/ada/shop.git" ]'
oc approve "$PR" --fingerprint "$CODE" >/dev/null 2>&1; rc=$?
check "the shown fingerprint approves the draft" '[ "$rc" = 0 ] && [ "$(mode "$D/approval.json")" = 0o600 ]'
check "show says the draft is approved" 'oc show "$PR" | grep -q "status       approved"'

# --- what changed after the approval is not sent ------------------------------

git -C "$CLONE" commit -q --amend -s -m "Fix the spelling of install in the README"
err="$(oc send "$PR" 2>&1)"; rc=$?
check "new commits after the approval stop the send" \
  '[ "$rc" = 1 ] && printf "%s" "$err" | grep -q "the commits" && [ "$(posts True)" = 0 ] && [ ! -d "$T/remotes/ada/shop.git" ]'
check "show says the draft changed since the approval" 'oc show "$PR" | grep -q "changed since approval"'
git -C "$CLONE" reset -q --hard "$HEAD1"
cp "$D/body.md" "$T/work/body.saved"
printf '\nOne more line.\n' >> "$D/body.md"
err="$(oc send "$PR" 2>&1)"; rc=$?
check "a body edited after the approval stops the send" '[ "$rc" = 1 ] && printf "%s" "$err" | grep -q "the body" && [ "$(posts True)" = 0 ]'
cp "$T/work/body.saved" "$D/body.md"
cp "$D/title.txt" "$T/work/title.saved"
printf 'Another title\n' > "$D/title.txt"
err="$(oc send "$PR" 2>&1)"; rc=$?
check "a title edited after the approval stops the send" '[ "$rc" = 1 ] && printf "%s" "$err" | grep -q "the title" && [ "$(posts True)" = 0 ]'
cp "$T/work/title.saved" "$D/title.txt"
printf '\n+extra line\n' >> "$D/diff.patch"
check "the diff file is only for reading; the fingerprint comes from the commits" 'oc show "$PR" | grep -q "status       approved"'

# --- the target is checked again right before sending --------------------------

mock 's["repos"]["acme/shop"]["archived"] = True'
oc send "$PR" >/dev/null 2>&1; rc=$?
check "an archived project is not sent to" '[ "$rc" = 1 ] && [ "$(posts True)" = 0 ]'
mock 's["repos"]["acme/shop"]["archived"] = False; s["repos"]["acme/shop"]["full_name"] = "acme/store"'
oc send "$PR" >/dev/null 2>&1; rc=$?
check "a renamed project is not sent to" '[ "$rc" = 1 ] && [ "$(posts True)" = 0 ]'
mock 'del s["repos"]["acme/shop"]["full_name"]'
mock 's["pulls"]["acme/shop"] = [{"number": 90, "title": "Something else", "state": "open", "user": {"login": "ada"}, "head": {"label": "ada:fix/readme-typo"}, "html_url": "https://github.com/acme/shop/pull/90"}]'
err="$(oc send "$PR" 2>&1)"; rc=$?
check "a pull request already open from the same branch stops the send" \
  '[ "$rc" = 1 ] && printf "%s" "$err" | grep -q "already open" && [ "$(posts True)" = 0 ]'
mock 's["pulls"]["acme/shop"] = [{"number": 91, "title": "Fix the spelling of \"install\" in the README", "state": "open", "user": {"login": "ada"}, "head": {"label": "ada:other"}, "html_url": "https://github.com/acme/shop/pull/91"}]'
err="$(oc send "$PR" 2>&1)"; rc=$?
check "an open pull request of yours with the same title stops the send" \
  '[ "$rc" = 1 ] && printf "%s" "$err" | grep -q "same title\|this title" && [ "$(posts True)" = 0 ]'
mock 's["pulls"]["acme/shop"] = []'
MAIN_SHA="$(git --git-dir="$T/remotes/acme/shop.git" rev-parse refs/heads/main)"
git --git-dir="$T/remotes/acme/shop.git" update-ref -d refs/heads/main
oc send "$PR" >/dev/null 2>&1; rc=$?
check "a target branch that no longer exists upstream stops the send" '[ "$rc" = 1 ] && [ "$(posts True)" = 0 ]'
git --git-dir="$T/remotes/acme/shop.git" update-ref refs/heads/main "$MAIN_SHA"

# --- sending the pull request -------------------------------------------------

mock 's["protocol"] = "ssh"'
out="$(oc send "$PR" 2>&1)"; rc=$?
check "the approved pull request is sent" '[ "$rc" = 0 ] && printf "%s" "$out" | grep -q "Sent $PR: https://github.com/acme/shop/pull/100"'
check "your fork gets the approved commit on the branch" \
  '[ "$(git --git-dir="$T/remotes/ada/shop.git" rev-parse refs/heads/fix/readme-typo)" = "$HEAD1" ]'
check "the fork remote uses the protocol gh is set to" \
  '[ "$(git -C "$CLONE" remote get-url fork)" = "file://$T/remotes/ssh/ada/shop.git" ]'
check "the pull request carries the exact title, body, branch, and target" \
  '[ "$(posts "p[\"endpoint\"] == \"repos/acme/shop/pulls\" and p[\"payload\"][\"title\"] == open(\"$T/work/title.txt\").read().rstrip(\"\\n\") and p[\"payload\"][\"body\"] == open(\"$T/work/body.md\").read() and p[\"payload\"][\"head\"] == \"ada:fix/readme-typo\" and p[\"payload\"][\"base\"] == \"main\"")" = 1 ]'
check "the record of what was sent is readable only by you" '[ "$(mode "$D/sent.json")" = 0o600 ]'
err="$(oc send "$PR" 2>&1)"; rc=$?
check "a sent pull request is not sent twice" \
  '[ "$rc" = 1 ] && printf "%s" "$err" | grep -q "already sent" && [ "$(posts "p[\"endpoint\"] == \"repos/acme/shop/pulls\"")" = 1 ]'

# --- findings ------------------------------------------------------------------

TOKEN="ghp_$(printf 'a%.0s' $(seq 36))"
HOMEPATH="$(printf '/%s/%s/' Users alice)"
MAIL="$(printf '%s@%s' ada acme.dev)"
git -C "$CLONE" switch -q -c feat/config upstream/main
printf 'token = %s\npath = %sproject\ncontact = %s\n' "$TOKEN" "$HOMEPATH" "$MAIL" > "$CLONE/config.txt"
git -C "$CLONE" add config.txt
printf 'Add a config file\n\nCo-authored-by: Helper <helper@example.com>\n' > "$T/work/msg2.txt"
git -C "$CLONE" commit -q -F "$T/work/msg2.txt"
printf 'Add a config file\n' > "$T/work/title2.txt"
printf 'Adds config.txt.\nThe key is %s\n' "$TOKEN" > "$T/work/body2.md"
draft2="$(oc draft --repo acme/shop --kind pr --title-file "$T/work/title2.txt" --body-file "$T/work/body2.md")"; rc=$?
PR2=acme-shop-pr-2
CODE2="$(printf '%s\n' "$draft2" | awk '$1 == "fingerprint" { print $2 }')"
check "a credential in the diff is found with its place" 'printf "%s" "$draft2" | grep -q "config.txt:1  looks like a GitHub token"'
check "a credential in the body is found" 'printf "%s" "$draft2" | grep -q "body line 2  looks like a GitHub token"'
check "a home folder path and an email address in the diff are found" \
  'printf "%s" "$draft2" | grep -q "config.txt:2  has a home folder path" && printf "%s" "$draft2" | grep -q "config.txt:3  has an email address"'
check "a missing sign-off and a co-author line are found" \
  'printf "%s" "$draft2" | grep -q "has no Signed-off-by line" && printf "%s" "$draft2" | grep -q "has a Co-authored-by line"'
check "the credential itself is never printed" '! printf "%s" "$draft2" | grep -qF "$TOKEN" && printf "%s" "$draft2" | grep -q "\[hidden: a GitHub token\]"'
oc approve "$PR2" --fingerprint "$CODE2" >/dev/null 2>&1; rc=$?
check "a draft with findings is not approved without --accept-findings" '[ "$rc" = 1 ] && [ ! -e "$OSS_CONTRIBUTE_HOME/drafts/$PR2/approval.json" ]'
oc approve "$PR2" --fingerprint "$CODE2" --accept-findings >/dev/null 2>&1; rc=$?
check "the user can accept the findings" '[ "$rc" = 0 ]'
git -C "$CLONE" switch -q fix/readme-typo

# --- issues --------------------------------------------------------------------

printf 'Existing report\n' > "$T/work/title3.txt"
printf 'The README says "instal".\n' > "$T/work/body3.md"
out="$(oc draft --repo acme/shop --kind issue --title-file "$T/work/title3.txt" --body-file "$T/work/body3.md")"
CODE3="$(printf '%s\n' "$out" | awk '$1 == "fingerprint" { print $2 }')"
oc approve acme-shop-issue-1 --fingerprint "$CODE3" >/dev/null 2>&1
err="$(oc send acme-shop-issue-1 2>&1)"; rc=$?
check "an open issue of yours with the same title stops the send" \
  '[ "$rc" = 1 ] && printf "%s" "$err" | grep -q "already have an open issue" && [ "$(posts "p[\"endpoint\"] == \"repos/acme/shop/issues\"")" = 0 ]'
printf 'The README misspells install\n' > "$T/work/title4.txt"
out="$(oc draft --repo acme/shop --kind issue --title-file "$T/work/title4.txt" --body-file "$T/work/body3.md")"
CODE4="$(printf '%s\n' "$out" | awk '$1 == "fingerprint" { print $2 }')"
oc approve acme-shop-issue-2 --fingerprint "$CODE4" >/dev/null 2>&1
mock 's["repos"]["acme/shop"]["has_issues"] = False'
oc send acme-shop-issue-2 >/dev/null 2>&1; rc=$?
check "an issue is not sent to a project with issues turned off" '[ "$rc" = 1 ] && [ "$(posts "p[\"endpoint\"] == \"repos/acme/shop/issues\"")" = 0 ]'
mock 's["repos"]["acme/shop"]["has_issues"] = True'
out="$(oc send acme-shop-issue-2 2>&1)"; rc=$?
check "the approved issue is sent with the exact title and body" \
  '[ "$rc" = 0 ] && [ "$(posts "p[\"endpoint\"] == \"repos/acme/shop/issues\" and p[\"payload\"] == {\"title\": \"The README misspells install\", \"body\": open(\"$T/work/body3.md\").read()}")" = 1 ]'

# --- comments ------------------------------------------------------------------

printf 'I opened a pull request for this.\n' > "$T/work/comment.md"
oc draft --repo acme/shop --kind comment --number 13 --body-file "$T/work/comment.md" >/dev/null 2>&1; rc=$?
check "a comment on a locked issue is refused at the draft" '[ "$rc" = 1 ]'
oc draft --repo acme/shop --kind comment --number 999 --body-file "$T/work/comment.md" >/dev/null 2>&1; rc=$?
check "a comment on an issue that does not exist is refused" '[ "$rc" = 1 ]'
out="$(oc draft --repo acme/shop --kind comment --number 12 --body-file "$T/work/comment.md")"; rc=$?
CODE5="$(printf '%s\n' "$out" | awk '$1 == "fingerprint" { print $2 }')"
check "a comment draft names the issue it goes on" '[ "$rc" = 0 ] && printf "%s" "$out" | grep -q "#12 Typo in the install guide (open issue)"'
oc approve acme-shop-comment-1 --fingerprint "$CODE5" >/dev/null 2>&1
mock 's["issues"]["acme/shop"][0]["state"] = "closed"'
err="$(oc send acme-shop-comment-1 2>&1)"; rc=$?
check "a comment is not sent when the issue was closed after the draft" \
  '[ "$rc" = 1 ] && printf "%s" "$err" | grep -q "is closed now" && [ "$(posts "\"comments\" in p[\"endpoint\"]")" = 0 ]'
mock 's["issues"]["acme/shop"][0]["state"] = "open"'
oc send acme-shop-comment-1 >/dev/null 2>&1; rc=$?
check "the approved comment is sent with the exact body" \
  '[ "$rc" = 0 ] && [ "$(posts "p[\"endpoint\"] == \"repos/acme/shop/issues/12/comments\" and p[\"payload\"] == {\"body\": open(\"$T/work/comment.md\").read()}")" = 1 ]'
err="$(oc send acme-shop-comment-1 2>&1)"; rc=$?
check "a sent comment is not sent twice" \
  '[ "$rc" = 1 ] && printf "%s" "$err" | grep -q "already sent" && [ "$(posts "\"comments\" in p[\"endpoint\"]")" = 1 ]'

# --- follow-up pushes ----------------------------------------------------------

oc draft --repo acme/shop --kind push >/dev/null 2>&1; rc=$?
check "a follow-up push with nothing new is refused" '[ "$rc" = 1 ]'
printf 'Thanks for using Shop.\n' >> "$CLONE/README.md"
git -C "$CLONE" commit -qas -m "Thank the reader"
HEAD2="$(git -C "$CLONE" rev-parse HEAD)"
out="$(oc draft --repo acme/shop --kind push)"; rc=$?
CODE6="$(printf '%s\n' "$out" | awk '$1 == "fingerprint" { print $2 }')"
check "a follow-up push shows only the new commit" \
  '[ "$rc" = 0 ] && printf "%s" "$out" | grep -q "adds 1 commit" && printf "%s" "$out" | grep -q "^+Thanks for using Shop." && ! printf "%s" "$out" | grep -q "^+Install the package"'
oc approve acme-shop-push-1 --fingerprint "$CODE6" >/dev/null 2>&1
mock 's["pulls"]["acme/shop"][0]["state"] = "closed"'
err="$(oc send acme-shop-push-1 2>&1)"; rc=$?
check "a follow-up push is not sent when the pull request was closed" \
  '[ "$rc" = 1 ] && printf "%s" "$err" | grep -q "merged or closed" && [ "$(git --git-dir="$T/remotes/ada/shop.git" rev-parse refs/heads/fix/readme-typo)" = "$HEAD1" ]'
mock 's["pulls"]["acme/shop"][0]["state"] = "open"'
git --git-dir="$T/remotes/ada/shop.git" update-ref refs/heads/fix/readme-typo "$MAIN_SHA"
err="$(oc send acme-shop-push-1 2>&1)"; rc=$?
check "a follow-up push is not sent when the branch on the fork changed after the draft" \
  '[ "$rc" = 1 ] && printf "%s" "$err" | grep -q "changed after the draft" && [ "$(git --git-dir="$T/remotes/ada/shop.git" rev-parse refs/heads/fix/readme-typo)" = "$MAIN_SHA" ]'
git --git-dir="$T/remotes/ada/shop.git" update-ref refs/heads/fix/readme-typo "$HEAD1"
oc send acme-shop-push-1 >/dev/null 2>&1; rc=$?
check "the approved follow-up push updates the fork" \
  '[ "$rc" = 0 ] && [ "$(git --git-dir="$T/remotes/ada/shop.git" rev-parse refs/heads/fix/readme-typo)" = "$HEAD2" ]'
git -C "$CLONE" reset -q --soft HEAD~1
git -C "$CLONE" commit -qs -m "Thank the reader of the README"
HEAD3="$(git -C "$CLONE" rev-parse HEAD)"
out="$(oc draft --repo acme/shop --kind push)"; rc=$?
CODE7="$(printf '%s\n' "$out" | awk '$1 == "fingerprint" { print $2 }')"
check "a rewritten branch is shown as a force push" '[ "$rc" = 0 ] && printf "%s" "$out" | grep -q "force push"'
oc approve acme-shop-push-2 --fingerprint "$CODE7" >/dev/null 2>&1
oc send acme-shop-push-2 >/dev/null 2>&1; rc=$?
check "the approved force push replaces the branch on the fork" \
  '[ "$rc" = 0 ] && [ "$(git --git-dir="$T/remotes/ada/shop.git" rev-parse refs/heads/fix/readme-typo)" = "$HEAD3" ]'

# --- list ----------------------------------------------------------------------

listing="$(oc list)"
check "list shows each draft with its state" \
  'printf "%s" "$listing" | grep -E "^$PR " | grep -q "sent https://github.com/acme/shop/pull/100" && printf "%s" "$listing" | grep -E "^$PR2 " | grep -q "approved, not sent"'

# --- clean ---------------------------------------------------------------------

: > "$DOCKER_LOG"
err="$(oc clean --repo acme/shop 2>&1)"; rc=$?
check "clean refuses while a branch has commits on no remote" \
  '[ "$rc" = 1 ] && printf "%s" "$err" | grep -q "commits that are on no remote" && [ -d "$CLONE" ] && [ -d "$D" ]'
git -C "$CLONE" branch -q -D feat/config
out="$(oc clean --repo acme/shop 2>&1)"; rc=$?
check "clean removes the clone and the drafts of the project" \
  '[ "$rc" = 0 ] && [ ! -e "$CLONE" ] && [ ! -e "$D" ] && [ ! -e "$OSS_CONTRIBUTE_HOME/drafts/acme-shop-issue-2" ]'
check "clean removes the project's Docker cache volume" 'dlog "[\"volume\", \"rm\", \"-f\", \"oss-contribute-cache-acme-shop\"] in calls"'
check "clean leaves the fork alone" '[ -d "$T/remotes/ada/shop.git" ] && printf "%s" "$out" | grep -q "fork on GitHub, if any, was not touched"'

# --- nothing reached the network -----------------------------------------------

check "no real gh or docker was called" '[ ! -e "$T/trap.log" ]'

# --- optional: the checks in a real container ----------------------------------

IMAGE="${OSS_CONTRIBUTE_TEST_IMAGE:-}"
if [ -n "$IMAGE" ] && [ -n "$REAL_DOCKER" ] && "$REAL_DOCKER" info >/dev/null 2>&1 && "$REAL_DOCKER" image inspect "$IMAGE" >/dev/null 2>&1; then
  P="isotest$$"
  mkdir -p "$T/remotes/$P"
  git clone -q --bare "$SEED" "$T/remotes/$P/probe.git"
  oc start --repo "$P/probe" >/dev/null 2>&1
  PC="$OSS_CONTRIBUTE_HOME/clones/$P/probe"
  before="$(cd "$PC" && find . -type f | LC_ALL=C sort | xargs shasum)"
  deps='echo built > built.txt; echo x > /src/pwned 2>/dev/null && echo WROTE-SRC; true'
  tst="cat built.txt; ls /sys/class/net | tr '\n' ' '; echo; [ -e /var/run/docker.sock ] && echo SOCKET; env | grep -q GH_TOKEN && echo TOKEN; [ -e '$REAL_HOME/.ssh' ] && echo HOSTSSH; true"
  real="$(OSS_CONTRIBUTE_DOCKER="$REAL_DOCKER" python3 "$SCRIPT" check --repo "$P/probe" --image "$IMAGE" --deps "$deps" --test "$tst" 2>&1)"; rc=$?
  check "real container: both phases ran" '[ "$rc" = 0 ] && printf "%s" "$real" | grep -qx built'
  check "real container: the check phase has only the loopback interface" 'printf "%s" "$real" | grep -qx "lo "'
  check "real container: no socket, no token, no host home, and the clone cannot be written" \
    '! printf "%s" "$real" | grep -qE "^(SOCKET|TOKEN|HOSTSSH|WROTE-SRC)$" && [ "$before" = "$(cd "$PC" && find . -type f | LC_ALL=C sort | xargs shasum)" ]'
  "$REAL_DOCKER" volume rm -f "oss-contribute-cache-$P-probe" >/dev/null 2>&1
else
  printf 'skip  the checks in a real container (set OSS_CONTRIBUTE_TEST_IMAGE to a local image)\n'
fi

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
