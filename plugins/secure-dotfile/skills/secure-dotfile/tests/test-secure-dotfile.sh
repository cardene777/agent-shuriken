#!/usr/bin/env bash
# Tests for secure_dotfile.py against a throwaway HOME, a throwaway keychain, and stand-ins for
# secret-tool, pass, and op that keep their values in a temporary folder.
#
# The test secrets are generated when the test runs, so no key-shaped text is kept in the
# repository. Every check prints only its name and the result, never a value.
# The keychain move checks need macOS. The secret service checks use the stand-in and run on
# any system.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../scripts/secure_dotfile.py"
PASS=0
FAIL=0
T="$(mktemp -d)"
REAL_HOME="$HOME"
KC="$T/test.keychain-db"
OUT="$T/out"
mkdir -p "$OUT"
# The scan also reads the .env files of the folder it runs in, so it runs in an empty one.
cd "$T" || exit 1

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }

KEYCHAINS_BEFORE=""
if [ "$(uname)" = Darwin ]; then
  KEYCHAINS_BEFORE="$(security list-keychains -d user)"
fi

cleanup() {
  if [ "$(uname)" = Darwin ] && [ -f "$KC" ]; then
    HOME="$REAL_HOME" security delete-keychain "$KC" >/dev/null 2>&1
  fi
  rm -rf "$T"
}
trap cleanup EXIT

# Random values. Name-based ones start with "Qz9" so their first characters never occur in
# the plugin's own words.
rand() { python3 -c 'import secrets,string,sys; a=string.ascii_letters+string.digits; print(sys.argv[1]+"".join(secrets.choice(a) for _ in range(int(sys.argv[2]))))' "$1" "$2"; }
export S_GH="$(rand ghp_ 36)"
export S_OAI="$(rand sk-proj- 48)"
export S_NAME="$(rand Qz9 30)"
export S_AWS="AKIA$(python3 -c 'import secrets,string; print("".join(secrets.choice(string.ascii_uppercase+string.digits) for _ in range(16)))')"
export S_SPACE="Qz9 $(rand '' 10) $(rand '' 10)"
export S_SOURCED="$(rand Qz9 28)"
export S_GIT="$(rand Qz9 26)"
export S_FISH="$(rand Qz9 24)"
export S_ENVD="$(rand Qz9 22)"
export S_CONFLICT="$(rand Qz9 20)"
export S_CONFLICT_OTHER="$(rand Qz9 20)"
export S_SHARED="$(rand Qz9 32)"
export S_CZ="$(rand Qz9 25)"
export S_BACKSLASH="Qz9$(rand '' 10)\\$(rand '' 5)"
export S_NONASCII="Qz9$(rand '' 10)ä"
# Short passwords: names ending in a password word are listed at any length.
export S_PG="$(rand Qz9 3)"
export S_MYSQL="$(rand Qz9 2)"
export S_DBPASS="$(rand Qz 1)"
export S_PIN="$(rand Qz9 1)"
export S_LOCAL="Q$((RANDOM % 10))"
export S_MYPASSWD="$(rand Qz9 20)"
# Values moved into the stand-in secret service.
export S_LXA="$(rand Qz9 27)"
export S_LXC="$(rand Qz9 23)"
export S_LXC_OTHER="$(rand Qz9 23)"
export S_LXD="$(rand Qz9 21)"
export S_LXF="$(rand Qz9 29)"
# Values moved into the stand-in pass.
export S_PA="$(rand Qz9 26)"
export S_PC="$(rand Qz9 24)"
export S_PC_OTHER="$(rand Qz9 24)"
export S_PL="$(rand Qz9 22)"
export S_PF="$(rand Qz9 28)"
# Values moved into the stand-in 1Password.
export S_OA="$(rand Qz9 31)"
export S_OS="$(rand Qz9 25)"
export S_OC="$(rand Qz9 27)"
export S_OC_OTHER="$(rand Qz9 27)"
export S_OT="$(rand Qz9 23)"
export S_ON="$(rand Qz9 21)"
export S_OF="$(rand Qz9 29)"
# Values in files that tools read on their own.
export S_NPM="$(rand npm_ 36)"
export S_NPMGH="$(rand ghp_ 36)"
export S_NPM2="$(rand npm_ 36)"
keyid() { python3 -c 'import secrets,string,sys; print(sys.argv[1]+"".join(secrets.choice(string.ascii_uppercase+string.digits) for _ in range(16)))' "$1"; }
export S_AK="$(keyid AKIA)"
export S_SK="$(rand Qz9 37)"
export S_AK2="$(keyid AKIA)"
export S_SK2="$(rand Qz9 37)"
export S_AKT="$(keyid ASIA)"
export S_SKT="$(rand Qz9 37)"
export S_ST="$(rand Qz9 60)"
export S_NETRC="$(rand Qz9 20)"
export S_ENV="$(rand Qz9 26)"
export S_ENVLOCAL="$(rand Qz9 24)"
export S_ENVSUB="$(rand Qz9 22)"
ALL_SECRETS=(S_GH S_OAI S_NAME S_AWS S_SPACE S_SOURCED S_GIT S_FISH S_ENVD S_CONFLICT S_CONFLICT_OTHER S_SHARED S_CZ S_BACKSLASH S_NONASCII
  S_PG S_MYSQL S_DBPASS S_PIN S_LOCAL S_MYPASSWD S_LXA S_LXC S_LXC_OTHER S_LXD S_LXF S_PA S_PC S_PC_OTHER S_PL S_PF
  S_OA S_OS S_OC S_OC_OTHER S_OT S_ON S_OF
  S_NPM S_NPMGH S_NPM2 S_AK S_SK S_AK2 S_SK2 S_AKT S_SKT S_ST S_NETRC S_ENV S_ENVLOCAL S_ENVSUB)

H="$T/home"
mkdir -p "$H/.config/fish" "$H/.config/direnv/env.d" "$H/dotfiles" "$H/.local/share/chezmoi"

# ~/.zshrc: several kinds of literal secrets and lines that must be ignored.
python3 - "$H/.zshrc" <<'PY'
import os, sys
e = os.environ
lines = [
    "# shell setup",
    'export PATH="$HOME/bin:$PATH"',
    'export GH_TOKEN="%s"' % e["S_GH"],
    "export OPENAI_API_KEY=%s" % e["S_OAI"],
    "export MY_SERVICE_TOKEN='%s'  # work account" % e["S_NAME"],
    "export AWS_ACCESS_KEY_ID=%s" % e["S_AWS"],
    'export DB_PASSWORD="%s"' % e["S_SPACE"],
    "export CONFLICT_TOKEN=%s" % e["S_CONFLICT"],
    "export SHARED_TOKEN=%s" % e["S_SHARED"],
    "export BAD_SECRET='%s'" % e["S_BACKSLASH"],
    'export ODD_SECRET="%s"' % e["S_NONASCII"],
    "export PLACEHOLDER_TOKEN=REPLACE_ME",
    'export DYNAMIC_TOKEN="$(cat ~/.token)"',
    "export SSH_KEY=~/.ssh/id_ed25519",
    "export SHORT_KEY=abc",
    "export EMPTY_TOKEN= notavalue",
    "[ -f ~/.secrets.sh ] && source ~/.secrets.sh",
    "export PGPASSWORD=%s" % e["S_PG"],
    'export MYSQL_PWD="%s"' % e["S_MYSQL"],
    "export DB_PASS='%s'" % e["S_DBPASS"],
    "export SIM_PIN=%s" % e["S_PIN"],
    "export LOCAL_PASSWORD=%s" % e["S_LOCAL"],
    "export MYPASSWD=%s" % e["S_MYPASSWD"],
    "export SINGLE_PASSWORD=x",
    "export TEST_PASSWORD=todo",
    "export FEATURE_KEY=abcdef",
    "export COMPASS=abcdef",
]
open(sys.argv[1], "w").write("\n".join(lines) + "\n")
PY
chmod 600 "$H/.zshrc"
printf "export SOURCED_API_KEY='%s'\n" "$S_SOURCED" > "$H/.secrets.sh"
printf 'set -gx FISH_TOKEN %s\n' "$S_FISH" > "$H/.config/fish/config.fish"
printf 'export WORK_SECRET="%s"\n' "$S_ENVD" > "$H/.config/direnv/env.d/work"

# ~/.bashrc is a link into a git repository whose history holds the secret.
printf 'export GIT_TOKEN=%s\nexport SHARED_TOKEN=%s\n' "$S_GIT" "$S_SHARED" > "$H/dotfiles/bashrc"
git -C "$H/dotfiles" init -q
git -C "$H/dotfiles" -c user.name=test -c user.email=test@example.com add bashrc
git -C "$H/dotfiles" -c user.name=test -c user.email=test@example.com commit -qm init
ln -s "$H/dotfiles/bashrc" "$H/.bashrc"

# ~/.zprofile is generated by chezmoi from its source file.
printf 'export CZ_TOKEN=%s\n' "$S_CZ" > "$H/.local/share/chezmoi/dot_zprofile"
cp "$H/.local/share/chezmoi/dot_zprofile" "$H/.zprofile"

# A stand-in secret-tool. It records its arguments, keeps each value in
# FAKE_SECRET_DIR/NAME.ACCOUNT, and answers like the real one: a missing value exits 1 with no
# output, and FAKE_SECRET_DOWN=1 makes it fail the way it does when no D-Bus session is running.
: "${USER:=$(id -un)}"
export USER
LH="$T/linux/home"
LS="$T/linux/store"
FAKEBIN="$T/linux/bin"
NOST="$T/linux/no-secret-tool"
mkdir -p "$LS" "$FAKEBIN" "$NOST"
cat > "$FAKEBIN/secret-tool" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_SECRET_DIR/args"
if [ "${FAKE_SECRET_DOWN:-}" = 1 ]; then
  printf '%s\n' 'secret-tool: Cannot autolaunch D-Bus without X11 $DISPLAY' >&2
  exit 1
fi
cmd="$1"
shift
case "${1:-}" in --label=*) shift ;; esac
if [ "$#" -ne 4 ] || [ "$1" != service ] || [ "$3" != account ]; then
  echo "secret-tool: unexpected arguments" >&2
  exit 2
fi
f="$FAKE_SECRET_DIR/$2.$4"
case "$cmd" in
  store) cat > "$f" ;;
  lookup) [ -f "$f" ] || exit 1; cat "$f" ;;
  *) exit 2 ;;
esac
SH
chmod 755 "$FAKEBIN/secret-tool"
for c in bash zsh git; do
  p="$(command -v "$c")" && ln -s "$p" "$NOST/$c"
done
PY3="$(command -v python3)"
# Elsewhere than macOS the scan reports the secret service, so the stand-in answers for it.
if [ "$(uname)" != Darwin ]; then
  export PATH="$FAKEBIN:$PATH" FAKE_SECRET_DIR="$LS"
fi

export HOME="$H"
run() { python3 "$SCRIPT" "$@"; }

# ---------------------------------------------------------------------------
# scan

run scan > "$OUT/scan.txt" 2> "$OUT/scan.err"
check "scan exits 0" "[ $? -eq 0 ]"
run scan --json > "$OUT/scan.json" 2>> "$OUT/scan.err"
J="$OUT/scan.json"
has() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if any(i["name"]==sys.argv[2] for i in d["items"]) else 1)' "$J" "$1"; }
field() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(next(str(i[sys.argv[3]]) for i in d["items"] if i["name"]==sys.argv[2] and (len(sys.argv)<5 or sys.argv[4] in i["path"])))' "$J" "$1" "$2" "${3:-}"; }

for n in GH_TOKEN OPENAI_API_KEY MY_SERVICE_TOKEN AWS_ACCESS_KEY_ID DB_PASSWORD CONFLICT_TOKEN SOURCED_API_KEY GIT_TOKEN FISH_TOKEN WORK_SECRET BAD_SECRET ODD_SECRET CZ_TOKEN; do
  check "scan finds $n" "has $n"
done
for n in PATH PLACEHOLDER_TOKEN DYNAMIC_TOKEN SSH_KEY SHORT_KEY EMPTY_TOKEN; do
  check "scan ignores $n" "! has $n"
done
check "scan lists a six-character PGPASSWORD as a movable short password" \
  "[ \"\$(field PGPASSWORD kind 2>/dev/null)\" = 'short password' ] && [ \"\$(field PGPASSWORD movable 2>/dev/null)\" = True ] && [ \"\$(field PGPASSWORD length 2>/dev/null)\" = 6 ]"
for n in MYSQL_PWD DB_PASS SIM_PIN LOCAL_PASSWORD; do
  check "scan finds $n" "has $n"
done
check "scan finds MYPASSWD as a password" "[ \"\$(field MYPASSWD kind 2>/dev/null)\" = password ]"
for n in SINGLE_PASSWORD TEST_PASSWORD FEATURE_KEY COMPASS; do
  check "scan ignores $n" "! has $n"
done
check "a long DB_PASSWORD keeps the kind password" "[ \"\$(field DB_PASSWORD kind)\" = password ]"
docs_name() {
  local f
  for f in skills/secure-dotfile/SKILL.md README.md README.ja.md docs/how-it-works.md docs/how-it-works.ja.md; do
    grep -q "short password" "$HERE/../../../$f" && grep -q "PGPASSWORD" "$HERE/../../../$f" || return 1
  done
}
check "the docs name the short password kind and the names" "docs_name"
check "kind of a GitHub token" "[ \"\$(field GH_TOKEN kind)\" = 'GitHub token' ]"
check "kind of an AWS key ID found by its value" "[ \"\$(field AWS_ACCESS_KEY_ID kind)\" = 'AWS access key ID' ]"
check "length is reported" "[ \"\$(field GH_TOKEN length)\" = 40 ]"
check "value in git history is reported" "[ \"\$(field GIT_TOKEN in_git_history)\" = yes ]"
check "file outside git is reported" "[ \"\$(field GH_TOKEN in_git_history)\" = 'not in a git repository' ]"
check "backslash cannot be moved" "[ \"\$(field BAD_SECRET movable)\" = False ]"
check "non-ASCII cannot be moved" "[ \"\$(field ODD_SECRET movable)\" = False ]"
check "trailing comment is kept in the new line" "field MY_SERVICE_TOKEN becomes | grep -q '  # work account\$'"
check "fish line uses fish command substitution" "field FISH_TOKEN becomes | grep -Eq '^set -gx FISH_TOKEN \\((security|secret-tool) '"
if command -v chezmoi >/dev/null 2>&1; then
  check "chezmoi target cannot be moved" "[ \"\$(field CZ_TOKEN movable .zprofile)\" = False ]"
  check "chezmoi source is scanned too" "field CZ_TOKEN path dot_zprofile | grep -q dot_zprofile"
fi

# ---------------------------------------------------------------------------
# move (macOS only)

if [ "$(uname)" = Darwin ]; then
  security create-keychain -p test "$KC" >/dev/null 2>&1
  security unlock-keychain -p test "$KC" >/dev/null 2>&1
  export SECURE_DOTFILE_KEYCHAIN="$KC"
  run scan --json > "$J" 2>> "$OUT/scan.err"
  item() { field "$1" item "${2:-}"; }
  python3 - <<'PY'
import os, subprocess
cmd = 'add-generic-password -a "%s" -s CONFLICT_TOKEN -w "%s" "%s"\n' % (
    os.environ["USER"], os.environ["S_CONFLICT_OTHER"], os.environ["SECURE_DOTFILE_KEYCHAIN"])
subprocess.run(["security", "-i"], input=cmd.encode(), capture_output=True)
PY

  before="$(shasum "$H/.zshrc")"
  run move --dry-run --item "$(item GH_TOKEN)" > "$OUT/dry.txt" 2>&1
  check "dry run leaves the file as it was" "[ \"\$(shasum \"$H/.zshrc\")\" = \"$before\" ]"
  check "dry run stores nothing" "! security find-generic-password -a \"$USER\" -s GH_TOKEN \"$KC\" >/dev/null 2>&1"

  run move --json \
    --item "$(item GH_TOKEN)" --item "$(item OPENAI_API_KEY)" --item "$(item MY_SERVICE_TOKEN)" \
    --item "$(item AWS_ACCESS_KEY_ID)" --item "$(item DB_PASSWORD)" --item "$(item CONFLICT_TOKEN)" \
    --item "$(item SHARED_TOKEN .zshrc)" --item "$(item SHARED_TOKEN .bashrc)" --item "$(item SOURCED_API_KEY)" \
    --item "$(item GIT_TOKEN)" --item "$(item FISH_TOKEN)" --item "$(item WORK_SECRET)" \
    --item "$(item BAD_SECRET)" --item "~/.zshrc:1:GH_TOKEN" \
    > "$OUT/move.json" 2> "$OUT/move.err"
  check "move exits 0" "[ $? -eq 0 ]"
  M="$OUT/move.json"
  status() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(" ".join(r["status"] for r in d["results"] if r["name"]==sys.argv[2] and str(r["line"])==sys.argv[3]))' "$M" "$1" "$2"; }
  note() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(" ".join(r["note"] for r in d["results"] if r["name"]==sys.argv[2] and str(r["line"])==sys.argv[3]))' "$M" "$1" "$2"; }
  for n in GH_TOKEN OPENAI_API_KEY MY_SERVICE_TOKEN AWS_ACCESS_KEY_ID DB_PASSWORD SOURCED_API_KEY GIT_TOKEN FISH_TOKEN WORK_SECRET; do
    line="$(field "$n" line)"
    check "move moves $n" "[ \"\$(status $n $line)\" = moved ]"
  done
  check "move moves the same value in two files" "[ \"\$(status SHARED_TOKEN 9)\" = moved ] && [ \"\$(status SHARED_TOKEN 2)\" = moved ]"
  check "move skips a name that holds a different value" "note CONFLICT_TOKEN 8 | grep -q 'a different value is already stored'"
  check "move skips a backslash" "note BAD_SECRET 10 | grep -q backslash"
  check "move skips a line that changed" "note GH_TOKEN 1 | grep -q 'no longer sets'"
  check "syntax check ran on the zsh file" "note GH_TOKEN 3 | grep -q 'zsh -n'"

  # The edited files hold no value and load the same values from the keychain.
  python3 - "$H" > "$OUT/files.txt" <<'PY'
import os, sys
h = sys.argv[1]
names = ["S_GH", "S_OAI", "S_NAME", "S_AWS", "S_SPACE", "S_SOURCED", "S_GIT", "S_FISH", "S_ENVD", "S_SHARED"]
files = [".zshrc", ".secrets.sh", "dotfiles/bashrc", ".config/fish/config.fish", ".config/direnv/env.d/work"]
text = "".join(open(os.path.join(h, f)).read() for f in files)
print("values left in files:", sum(1 for n in names if os.environ[n] in text))
PY
  check "moved values are gone from the files" "grep -q 'values left in files: 0' \"$OUT/files.txt\""
  check "the conflicting value stays in its file" "grep -qF \"\$S_CONFLICT\" \"$H/.zshrc\""
  check "the link to the git repository is kept" "[ -L \"$H/.bashrc\" ]"
  check "the file mode is kept" "[ \"\$(stat -f %Lp \"$H/.zshrc\")\" = 600 ]"
  check "no temporary file is left" "! ls -a \"$H\" | grep -q secure-dotfile"
  loaded() {
    zsh -fc 'source ~/.zshrc 2>/dev/null; printf "%s\n%s\n%s\n%s\n%s\n%s" "$GH_TOKEN" "$OPENAI_API_KEY" "$MY_SERVICE_TOKEN" "$AWS_ACCESS_KEY_ID" "$DB_PASSWORD" "$SOURCED_API_KEY"' \
      | python3 -c 'import os,sys; got=sys.stdin.read().split("\n"); want=[os.environ[n] for n in ("S_GH","S_OAI","S_NAME","S_AWS","S_SPACE","S_SOURCED")]; sys.exit(0 if got==want else 1)'
  }
  check "a new zsh loads the moved values" "loaded"
  check "a new bash loads the value from the linked file" "bash --norc -c 'source ~/.bashrc; [ \"\$GIT_TOKEN\" = \"\$S_GIT\" ]'"

  # Short passwords move like any other value.
  run scan --json > "$J" 2>> "$OUT/scan.err"
  run move --json --item "$(item PGPASSWORD 2>/dev/null)" --item "$(item DB_PASS 2>/dev/null)" > "$OUT/move-short.json" 2>> "$OUT/move.err"
  short_status() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(" ".join(r["status"] for r in d["results"] if r["name"]==sys.argv[2]))' "$OUT/move-short.json" "$1" 2>/dev/null; }
  for n in PGPASSWORD DB_PASS; do
    check "move moves $n" "[ \"\$(short_status $n)\" = moved ]"
  done
  short_loaded() {
    zsh -fc 'source ~/.zshrc 2>/dev/null; printf "%s\n%s" "$PGPASSWORD" "$DB_PASS"' \
      | python3 -c 'import os,sys; sys.exit(0 if sys.stdin.read().split("\n") == [os.environ["S_PG"], os.environ["S_DBPASS"]] else 1)'
  }
  check "a new zsh loads the short passwords" "short_loaded && ! grep -qF \"\$S_PG\" \"$H/.zshrc\""

  if command -v chezmoi >/dev/null 2>&1; then
    run move --json --item "~/.zprofile:1:CZ_TOKEN" --item "~/.local/share/chezmoi/dot_zprofile:1:CZ_TOKEN" > "$M" 2>> "$OUT/move.err"
    check "move skips the chezmoi target" "note CZ_TOKEN 1 | grep -q 'managed by chezmoi'"
    check "move moves the chezmoi source" "status CZ_TOKEN 1 | grep -q moved"
  fi

  run move --item "~/.zshrc:3:GH_TOKEN" > "$OUT/again.txt" 2>&1
  check "a moved line is not moved twice" "grep -q 'no longer sets' \"$OUT/again.txt\""
  same_keychains() { [ "$(HOME="$REAL_HOME" security list-keychains -d user)" = "$KEYCHAINS_BEFORE" ]; }
  check "the keychain search list is unchanged" "same_keychains"
fi

# ---------------------------------------------------------------------------
# move into the secret service, through the stand-in secret-tool
#
# SECURE_DOTFILE_KEYCHAIN still names the throwaway keychain, so nothing can reach the default
# keychain.

mkdir -p "$LH/.config/fish"
printf 'export LX_TOKEN="%s"\nexport LX_CONFLICT_TOKEN=%s\nexport LX_DOWN_TOKEN=%s\n' "$S_LXA" "$S_LXC" "$S_LXD" > "$LH/.bashrc"
printf 'set -gx LX_FISH_TOKEN %s\n' "$S_LXF" > "$LH/.config/fish/config.fish"
printf '%s' "$S_LXC_OTHER" > "$LS/LX_CONFLICT_TOKEN.$USER"
lx() { HOME="$LH" PATH="$FAKEBIN:$PATH" FAKE_SECRET_DIR="$LS" SECURE_DOTFILE_STORE=secret-service SECURE_DOTFILE_KEYCHAIN="$KC" "$@"; }
jfield() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(next(str(i[sys.argv[3]]) for i in d["items"] if i["name"]==sys.argv[2]))' "$@" 2>/dev/null; }
jnote() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(" ".join(r["status"]+" "+r["note"] for r in d["results"] if r["name"]==sys.argv[2]))' "$@" 2>/dev/null; }
stored() { printf '%s' "$2" | cmp -s - "$LS/$1.$USER"; }
lookups() { local n; n="$(grep -c "^lookup service $1 " "$LS/args" 2>/dev/null)"; echo "${n:-0}"; }
want_bash='export LX_TOKEN="$(secret-tool lookup service LX_TOKEN account "$USER" 2>/dev/null)"'
want_fish='set -gx LX_FISH_TOKEN (secret-tool lookup service LX_FISH_TOKEN account "$USER" 2>/dev/null)'

LJ="$OUT/lx-scan.json"
lx python3 "$SCRIPT" scan --json > "$LJ" 2>> "$OUT/scan.err"
lx_scan() { [ "$(jfield "$LJ" LX_TOKEN movable)" = True ] && [ "$(jfield "$LJ" LX_TOKEN becomes)" = "$want_bash" ]; }
check "on Linux, scan shows the secret-tool line as what the line becomes" "lx_scan"

lx_before="$(cksum < "$LH/.bashrc")"
lx env FAKE_SECRET_DOWN=1 python3 "$SCRIPT" move --json --item "$(jfield "$LJ" LX_DOWN_TOKEN item)" > "$OUT/lx-down.json" 2>> "$OUT/lx-move.err"
lx_after_down="$(cksum < "$LH/.bashrc")"
lx_down() {
  jnote "$OUT/lx-down.json" LX_DOWN_TOKEN | grep -q '^skipped .*Cannot autolaunch D-Bus' &&
    [ "$lx_after_down" = "$lx_before" ] && [ ! -e "$LS/LX_DOWN_TOKEN.$USER" ]
}
check "on Linux, an unreachable secret service skips the item and leaves the file as it was" "lx_down"

lx python3 "$SCRIPT" move --json --item "$(jfield "$LJ" LX_TOKEN item)" --item "$(jfield "$LJ" LX_CONFLICT_TOKEN item)" \
  --item "$(jfield "$LJ" LX_FISH_TOKEN item)" > "$OUT/lx-move.json" 2>> "$OUT/lx-move.err"
lx_moved() {
  jnote "$OUT/lx-move.json" LX_TOKEN | grep -q '^moved stored in the secret service as LX_TOKEN' &&
    stored LX_TOKEN "$S_LXA" && [ "$(sed -n 1p "$LH/.bashrc")" = "$want_bash" ] &&
    awk '/^store .*service LX_TOKEN /{s=1} s && /^lookup service LX_TOKEN /{f=1} END{exit !f}' "$LS/args"
}
check "on Linux, move stores the value in the secret service, reads it back, and rewrites the line" "lx_moved"
lx_stdin_only() {
  [ -s "$LS/args" ] && stored LX_TOKEN "$S_LXA" && stored LX_FISH_TOKEN "$S_LXF" &&
    python3 -c 'import os,sys; t=open(sys.argv[1]).read(); sys.exit(1 if any(os.environ[n] in t or os.environ[n][:4] in t for n in sys.argv[2:]) else 0)' \
      "$LS/args" S_LXA S_LXC S_LXC_OTHER S_LXD S_LXF
}
check "on Linux, the value reaches secret-tool only on standard input" "lx_stdin_only"
lx_fish() { [ "$(sed -n 1p "$LH/.config/fish/config.fish")" = "$want_fish" ] && stored LX_FISH_TOKEN "$S_LXF"; }
check "on Linux, a fish line reads the value with fish command substitution" "lx_fish"
lx_conflict() {
  jnote "$OUT/lx-move.json" LX_CONFLICT_TOKEN | grep -q '^skipped a different value is already stored as LX_CONFLICT_TOKEN' &&
    stored LX_CONFLICT_TOKEN "$S_LXC_OTHER" && grep -qF "$S_LXC" "$LH/.bashrc"
}
check "on Linux, a name that holds a different value is skipped and not overwritten" "lx_conflict"
lx_loaded() {
  local before
  before="$(lookups LX_TOKEN)"
  HOME="$LH" PATH="$FAKEBIN:$PATH" FAKE_SECRET_DIR="$LS" bash --norc -c 'source ~/.bashrc; [ "$LX_TOKEN" = "$S_LXA" ]' &&
    [ "$(lookups LX_TOKEN)" -gt "$before" ]
}
check "on Linux, a new bash loads the moved value through secret-tool" "lx_loaded"

# Without secret-tool on PATH. Only the commands the scan runs are linked into it.
HOME="$LH" PATH="$NOST" SECURE_DOTFILE_STORE=secret-service SECURE_DOTFILE_KEYCHAIN="$KC" \
  "$PY3" "$SCRIPT" move --item "~/.bashrc:3:LX_DOWN_TOKEN" > "$OUT/lx-none.txt" 2> "$OUT/lx-none.err"
lx_none_rc=$?
HOME="$LH" PATH="$NOST" SECURE_DOTFILE_STORE=secret-service SECURE_DOTFILE_KEYCHAIN="$KC" \
  "$PY3" "$SCRIPT" scan --json > "$OUT/lx-none.json" 2>> "$OUT/scan.err"
lx_none() {
  [ "$lx_none_rc" -eq 3 ] && grep -q secret-tool "$OUT/lx-none.err" &&
    [ "$(jfield "$OUT/lx-none.json" LX_DOWN_TOKEN movable)" = False ] &&
    jfield "$OUT/lx-none.json" LX_DOWN_TOKEN reason | grep -q secret-tool
}
check "without secret-tool, move exits 3 and names it, and scan says why it cannot move" "lx_none"
docs_linux() {
  local f
  for f in skills/secure-dotfile/SKILL.md README.md README.ja.md docs/how-it-works.md docs/how-it-works.ja.md; do
    grep -q "secret-tool" "$HERE/../../../$f" || return 1
  done
}
check "the docs describe moving on Linux with secret-tool" "docs_linux"

# ---------------------------------------------------------------------------
# move into pass, through a stand-in pass
#
# The stand-in records its arguments and keeps each entry as plain text in
# PASSWORD_STORE_DIR/NAME.gpg, where the real pass keeps the encrypted file. `insert -e` stores
# one line from standard input followed by a newline, as the real one does, and
# FAKE_PASS_LOCKED=1 makes `show` fail the way gpg does when the key cannot be used.

PH="$T/pass/home"
PS="$T/pass/store"
PASSBIN="$T/pass/bin"
PLOG="$T/pass/args"
mkdir -p "$PH/.config/fish" "$PS" "$PASSBIN" "$T/pass/empty"
printf 'stand-in-key\n' > "$PS/.gpg-id"
cat > "$PASSBIN/pass" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_PASS_LOG"
case "${1:-} ${2:-}" in
  "insert -e")
    IFS= read -r line
    printf '%s\n' "$line" > "$PASSWORD_STORE_DIR/$3.gpg"
    ;;
  show\ *)
    f="$PASSWORD_STORE_DIR/$2.gpg"
    if [ ! -f "$f" ]; then
      echo "Error: $2 is not in the password store." >&2
      exit 1
    fi
    if [ "${FAKE_PASS_LOCKED:-}" = 1 ]; then
      echo "gpg: decryption failed: No secret key" >&2
      exit 2
    fi
    cat "$f"
    ;;
  *)
    echo "pass: unexpected arguments" >&2
    exit 2
    ;;
esac
SH
chmod 755 "$PASSBIN/pass"
printf 'export PA_TOKEN="%s"\nexport PA_CONFLICT_TOKEN=%s\nexport PA_LOCKED_TOKEN=%s\n' "$S_PA" "$S_PC" "$S_PL" > "$PH/.bashrc"
printf 'set -gx PA_FISH_TOKEN %s\n' "$S_PF" > "$PH/.config/fish/config.fish"
printf '%s\n' "$S_PC_OTHER" > "$PS/PA_CONFLICT_TOKEN.gpg"
pz() { HOME="$PH" PATH="$PASSBIN:$PATH" PASSWORD_STORE_DIR="$PS" FAKE_PASS_LOG="$PLOG" SECURE_DOTFILE_KEYCHAIN="$KC" "$@"; }
in_pass() { printf '%s\n' "$2" | cmp -s - "$PS/$1.gpg"; }
shows() { local n; n="$(grep -c "^show $1\$" "$PLOG" 2>/dev/null)"; echo "${n:-0}"; }
want_pass_bash='export PA_TOKEN="$(pass show PA_TOKEN 2>/dev/null)"'
want_pass_fish='set -gx PA_FISH_TOKEN (pass show PA_FISH_TOKEN 2>/dev/null)'

PJ="$OUT/pass-scan.json"
pz python3 "$SCRIPT" scan --store pass --json > "$PJ" 2>> "$OUT/pass-scan.err"
pass_scan() { [ "$(jfield "$PJ" PA_TOKEN movable)" = True ] && [ "$(jfield "$PJ" PA_TOKEN becomes)" = "$want_pass_bash" ]; }
check "with --store pass, scan shows the pass line as what the line becomes" "pass_scan"

pz python3 "$SCRIPT" scan --json > "$OUT/pass-stores.json" 2>> "$OUT/pass-scan.err"
pz env PASSWORD_STORE_DIR="$T/pass/empty" python3 "$SCRIPT" scan --json > "$OUT/pass-stores-empty.json" 2>> "$OUT/pass-scan.err"
pz python3 "$SCRIPT" scan > "$OUT/pass-stores.txt" 2>> "$OUT/pass-scan.err"
has_store() { python3 -c 'import json,sys; sys.exit(0 if sys.argv[2] in json.load(open(sys.argv[1])).get("stores", []) else 1)' "$1" "$2" 2>/dev/null; }
pass_stores() {
  has_store "$OUT/pass-stores.json" pass && ! has_store "$OUT/pass-stores-empty.json" pass &&
    grep -q -- '--store pass' "$OUT/pass-stores.txt"
}
check "scan lists pass as a store to choose only when the password store is initialized" "pass_stores"

pass_before="$(cksum < "$PH/.bashrc")"
pz env FAKE_PASS_LOCKED=1 python3 "$SCRIPT" move --store pass --json --item "$(jfield "$PJ" PA_LOCKED_TOKEN item)" > "$OUT/pass-locked.json" 2>> "$OUT/pass-move.err"
pass_after_locked="$(cksum < "$PH/.bashrc")"
pass_locked() {
  jnote "$OUT/pass-locked.json" PA_LOCKED_TOKEN | grep -q '^skipped .*could not be read back.*gpg: decryption failed' &&
    [ "$pass_after_locked" = "$pass_before" ]
}
check "with --store pass, a value that cannot be read back is skipped and the file is left as it was" "pass_locked"

pz python3 "$SCRIPT" move --store pass --json --item "$(jfield "$PJ" PA_TOKEN item)" --item "$(jfield "$PJ" PA_CONFLICT_TOKEN item)" \
  --item "$(jfield "$PJ" PA_FISH_TOKEN item)" > "$OUT/pass-move.json" 2>> "$OUT/pass-move.err"
pass_moved() {
  jnote "$OUT/pass-move.json" PA_TOKEN | grep -q '^moved stored in pass as PA_TOKEN' &&
    in_pass PA_TOKEN "$S_PA" && [ "$(sed -n 1p "$PH/.bashrc")" = "$want_pass_bash" ] &&
    awk '/^insert -e PA_TOKEN$/{s=1} s && /^show PA_TOKEN$/{f=1} END{exit !f}' "$PLOG"
}
check "with --store pass, move stores the value in pass, reads it back, and rewrites the line" "pass_moved"
pass_stdin_only() {
  [ -s "$PLOG" ] && in_pass PA_TOKEN "$S_PA" && in_pass PA_FISH_TOKEN "$S_PF" &&
    python3 -c 'import os,sys; t=open(sys.argv[1]).read(); sys.exit(1 if any(os.environ[n] in t or os.environ[n][:4] in t for n in sys.argv[2:]) else 0)' \
      "$PLOG" S_PA S_PC S_PC_OTHER S_PL S_PF
}
check "with --store pass, the value reaches pass only on standard input" "pass_stdin_only"
pass_fish() { [ "$(sed -n 1p "$PH/.config/fish/config.fish")" = "$want_pass_fish" ] && in_pass PA_FISH_TOKEN "$S_PF"; }
check "with --store pass, a fish line reads the value with fish command substitution" "pass_fish"
pass_conflict() {
  jnote "$OUT/pass-move.json" PA_CONFLICT_TOKEN | grep -q '^skipped a different value is already stored as PA_CONFLICT_TOKEN' &&
    in_pass PA_CONFLICT_TOKEN "$S_PC_OTHER" && grep -qF "$S_PC" "$PH/.bashrc"
}
check "with --store pass, a name that holds a different value is skipped and not overwritten" "pass_conflict"
pass_loaded() {
  local before
  before="$(shows PA_TOKEN)"
  HOME="$PH" PATH="$PASSBIN:$PATH" PASSWORD_STORE_DIR="$PS" FAKE_PASS_LOG="$PLOG" bash --norc -c 'source ~/.bashrc; [ "$PA_TOKEN" = "$S_PA" ]' &&
    [ "$(shows PA_TOKEN)" -gt "$before" ]
}
check "with --store pass, a new bash loads the moved value through pass" "pass_loaded"

# Without pass on PATH. Only the commands the scan runs are linked into it.
HOME="$PH" PATH="$NOST" PASSWORD_STORE_DIR="$PS" SECURE_DOTFILE_KEYCHAIN="$KC" \
  "$PY3" "$SCRIPT" move --store pass --item "~/.bashrc:3:PA_LOCKED_TOKEN" > "$OUT/pass-none.txt" 2> "$OUT/pass-none.err"
pass_none_rc=$?
HOME="$PH" PATH="$NOST" PASSWORD_STORE_DIR="$PS" SECURE_DOTFILE_KEYCHAIN="$KC" \
  "$PY3" "$SCRIPT" scan --store pass --json > "$OUT/pass-none.json" 2>> "$OUT/pass-scan.err"
pass_none() {
  [ "$pass_none_rc" -eq 3 ] && grep -q 'needs the pass command' "$OUT/pass-none.err" && [ ! -s "$OUT/pass-scan.err" ] &&
    [ "$(jfield "$OUT/pass-none.json" PA_LOCKED_TOKEN movable)" = False ] &&
    jfield "$OUT/pass-none.json" PA_LOCKED_TOKEN reason | grep -q 'needs the pass command'
}
check "without pass, move --store pass exits 3 and names it, and scan says why it cannot move" "pass_none"
docs_pass() {
  local f
  for f in skills/secure-dotfile/SKILL.md README.md README.ja.md docs/how-it-works.md docs/how-it-works.ja.md; do
    grep -q "pass show" "$HERE/../../../$f" && grep -q "KWallet" "$HERE/../../../$f" || return 1
  done
  grep -q -- "--store pass" "$HERE/../SKILL.md"
}
check "the docs describe moving into pass and reaching KWallet through secret-tool" "docs_pass"

# ---------------------------------------------------------------------------
# move into 1Password, through a stand-in op
#
# The stand-in follows the help of op 2.42: `vault list` and `item list` print JSON, `item create`
# takes an item JSON template on standard input after `-`, and `read` prints the field named by
# an op://vault/item/field reference, matching names without regard to case. It records its
# arguments and keeps the items as plain JSON in FAKE_OP_DIR/items.json. FAKE_OP_VAULTS names the
# account's vaults, and FAKE_OP_DOWN=1 makes every command fail the way op does with no account.

OH="$T/op/home"
OD="$T/op/data"
OPBIN="$T/op/bin"
OLOG="$T/op/args"
mkdir -p "$OH/.config/fish" "$OD" "$OPBIN"
cat > "$OPBIN/op" <<'PY'
#!/usr/bin/env python3
import json, os, sys

args = sys.argv[1:]
with open(os.environ["FAKE_OP_LOG"], "a") as fh:
    fh.write(" ".join(args) + "\n")
if os.environ.get("FAKE_OP_DOWN") == "1":
    sys.stderr.write("No accounts configured for use with 1Password CLI.\n")
    sys.exit(1)
path = os.path.join(os.environ["FAKE_OP_DIR"], "items.json")
items = json.load(open(path)) if os.path.exists(path) else []
vaults = [v for v in os.environ.get("FAKE_OP_VAULTS", "Personal,Shared").split(",") if v]


def vault(name):
    return {"id": "v%d" % vaults.index(name), "name": name}


def flag(name):
    return args[args.index(name) + 1] if name in args[:-1] else None


def fail(message, code=1):
    sys.stderr.write("[ERROR] 2026/11/14 12:00:00 %s\n" % message)
    sys.exit(code)


if args[:2] == ["vault", "list"] and flag("--format") == "json":
    print(json.dumps([vault(v) for v in vaults]))
elif args[:2] == ["item", "list"] and flag("--format") == "json":
    v = flag("--vault")
    if v is not None and v not in vaults:
        fail("\"%s\" isn't a vault in this account." % v)
    print(json.dumps([{"id": i["id"], "title": i["title"], "vault": vault(i["vault"])}
                      for i in items if v is None or i["vault"] == v]))
elif args[:2] == ["item", "create"]:
    # Assignment statements would put the value on the command line.
    if args[-1] != "-" or any("=" in a for a in args[2:]):
        fail("expected an item template on standard input", 2)
    v = flag("--vault")
    if v not in vaults:
        fail("\"%s\" isn't a vault in this account." % v)
    t = json.load(sys.stdin)
    pw = [f for f in t.get("fields", []) if f.get("id") == "password" and f.get("type") == "CONCEALED"]
    if not t.get("title") or t.get("category") != "LOGIN" or len(pw) != 1 or not pw[0].get("value"):
        fail("invalid item template")
    items.append({"id": "i%d" % len(items), "title": t["title"], "vault": v, "value": pw[0]["value"]})
    json.dump(items, open(path, "w"))
    print("ID: i%d\nTitle: %s\nVault: %s" % (len(items) - 1, t["title"], v))
elif args[:1] == ["read"]:
    refs = [a for a in args[1:] if a.startswith("op://")]
    parts = refs[0][len("op://"):].split("/") if len(refs) == 1 else []
    if len(parts) != 3 or parts[2] != "password":
        fail("invalid secret reference")
    hits = [i for i in items if i["vault"].lower() == parts[0].lower() and i["title"].lower() == parts[1].lower()]
    if len(hits) != 1:
        fail("could not read secret '%s': %s" % (refs[0], "more than one item matches" if hits else "item not found"))
    sys.stdout.write(hits[0]["value"] + ("" if "-n" in args or "--no-newline" in args else "\n"))
else:
    fail("unexpected arguments", 2)
PY
chmod 755 "$OPBIN/op"
printf 'export OP_TOKEN="%s"\nexport OP_SAME_TOKEN=%s\nexport OP_CONFLICT_TOKEN=%s\nexport OP_TWICE_TOKEN=%s\nexport OP_DOWN_TOKEN=%s\n' \
  "$S_OA" "$S_OS" "$S_OC" "$S_OT" "$S_ON" > "$OH/.bashrc"
printf 'set -gx OP_FISH_TOKEN %s\n' "$S_OF" > "$OH/.config/fish/config.fish"
python3 - "$OD/items.json" <<'PY'
import json, os, sys
items = [
    {"id": "s1", "title": "OP_SAME_TOKEN", "vault": "Personal", "value": os.environ["S_OS"]},
    {"id": "s2", "title": "OP_CONFLICT_TOKEN", "vault": "Personal", "value": os.environ["S_OC_OTHER"]},
    {"id": "s3", "title": "OP_TWICE_TOKEN", "vault": "Personal", "value": os.environ["S_OT"]},
    {"id": "s4", "title": "op_twice_token", "vault": "Personal", "value": os.environ["S_OT"]},
    # Another vault's item of the same name is never read or replaced.
    {"id": "s5", "title": "OP_TOKEN", "vault": "Shared", "value": os.environ["S_OC_OTHER"]},
]
json.dump(items, open(sys.argv[1], "w"))
PY
o1() { HOME="$OH" PATH="$OPBIN:$PATH" FAKE_OP_DIR="$OD" FAKE_OP_LOG="$OLOG" SECURE_DOTFILE_KEYCHAIN="$KC" "$@"; }
# How many items in the vault have this title (ignoring case), and how many of them hold the value.
titled() { python3 -c 'import json,sys; print(sum(1 for i in json.load(open(sys.argv[1])) if i["vault"]==sys.argv[2] and i["title"].lower()==sys.argv[3].lower()))' "$OD/items.json" "$1" "$2"; }
in_op() { python3 -c 'import json,os,sys; print(sum(1 for i in json.load(open(sys.argv[1])) if i["vault"]==sys.argv[2] and i["title"]==sys.argv[3] and i["value"]==os.environ[sys.argv[4]]))' "$OD/items.json" "$1" "$2" "$3"; }
op_calls() { local n; n="$(grep -c "$1" "$OLOG" 2>/dev/null)"; echo "${n:-0}"; }
want_op_bash="export OP_TOKEN=\"\$(op read 'op://Personal/OP_TOKEN/password' 2>/dev/null)\""
want_op_same="export OP_SAME_TOKEN=\"\$(op read 'op://Personal/OP_SAME_TOKEN/password' 2>/dev/null)\""
want_op_fish="set -gx OP_FISH_TOKEN (op read 'op://Personal/OP_FISH_TOKEN/password' 2>/dev/null)"

# A scan that does not pick 1Password lists it when op is installed, and never runs op.
o1 python3 "$SCRIPT" scan --json > "$OUT/op-stores.json" 2>> "$OUT/op-scan.err"
o1 python3 "$SCRIPT" scan > "$OUT/op-stores.txt" 2>> "$OUT/op-scan.err"
op_calls_after_plain_scan="$(op_calls .)"
HOME="$OH" PATH="$NOST" SECURE_DOTFILE_KEYCHAIN="$KC" "$PY3" "$SCRIPT" scan --json > "$OUT/op-stores-none.json" 2>> "$OUT/op-scan.err"
op_stores() {
  has_store "$OUT/op-stores.json" 1password && ! has_store "$OUT/op-stores-none.json" 1password &&
    grep -q -- '--store 1password' "$OUT/op-stores.txt" && [ "$op_calls_after_plain_scan" -eq 0 ]
}
check "scan lists 1Password as a store to choose only when op is installed, without running op" "op_stores"

OJ="$OUT/op-scan.json"
o1 python3 "$SCRIPT" scan --store 1password --json > "$OJ" 2>> "$OUT/op-scan.err"
op_scan() {
  [ "$(jfield "$OJ" OP_TOKEN movable)" = True ] && [ "$(jfield "$OJ" OP_TOKEN becomes)" = "$want_op_bash" ] &&
    [ "$(op_calls '^vault list --format json$')" -ge 1 ]
}
check "with --store 1password, scan shows the op read line with the real vault name" "op_scan"

op_file_before="$(cksum < "$OH/.bashrc")"
op_items_before="$(cksum < "$OD/items.json")"
o1 env FAKE_OP_DOWN=1 python3 "$SCRIPT" move --store 1password --json --item "~/.bashrc:5:OP_DOWN_TOKEN" > "$OUT/op-down.json" 2> "$OUT/op-down.err"
op_down_rc=$?
o1 env FAKE_OP_DOWN=1 python3 "$SCRIPT" scan --store 1password --json > "$OUT/op-down-scan.json" 2>> "$OUT/op-scan.err"
op_down() {
  [ "$op_down_rc" -eq 3 ] && grep -q 'op exited with 1: No accounts configured' "$OUT/op-down.err" &&
    jfield "$OUT/op-down-scan.json" OP_DOWN_TOKEN reason | grep -q 'op exited with 1: No accounts configured' &&
    [ "$(cksum < "$OH/.bashrc")" = "$op_file_before" ] && [ "$(cksum < "$OD/items.json")" = "$op_items_before" ]
}
check "with --store 1password, a signed-out op stops the move with a reason that names op and leaves the file as it was" "op_down"

o1 env FAKE_OP_VAULTS=Shared,Work python3 "$SCRIPT" move --store 1password --json --item "~/.bashrc:5:OP_DOWN_TOKEN" > "$OUT/op-novault.json" 2> "$OUT/op-novault.err"
op_novault_rc=$?
o1 env FAKE_OP_VAULTS=Private,Personal python3 "$SCRIPT" move --store 1password --json --item "~/.bashrc:5:OP_DOWN_TOKEN" > "$OUT/op-twovaults.json" 2> "$OUT/op-twovaults.err"
op_twovaults_rc=$?
op_novault() {
  [ "$op_novault_rc" -eq 3 ] && [ "$op_twovaults_rc" -eq 3 ] &&
    grep -q 'op' "$OUT/op-novault.err" && grep -q 'Private, Personal, or Employee' "$OUT/op-novault.err" &&
    grep -q 'Private, Personal, or Employee' "$OUT/op-twovaults.err" &&
    [ "$(cksum < "$OH/.bashrc")" = "$op_file_before" ] && [ "$(cksum < "$OD/items.json")" = "$op_items_before" ]
}
check "with --store 1password, a move that cannot tell the default vault stops and changes nothing" "op_novault"

o1 python3 "$SCRIPT" move --store 1password --json --item "~/.bashrc:1:OP_TOKEN" --item "~/.bashrc:2:OP_SAME_TOKEN" \
  --item "~/.bashrc:3:OP_CONFLICT_TOKEN" --item "~/.bashrc:4:OP_TWICE_TOKEN" \
  --item "~/.config/fish/config.fish:1:OP_FISH_TOKEN" > "$OUT/op-move.json" 2>> "$OUT/op-move.err"
op_moved() {
  jnote "$OUT/op-move.json" OP_TOKEN | grep -q '^moved stored in 1Password as OP_TOKEN' &&
    [ "$(in_op Personal OP_TOKEN S_OA)" -eq 1 ] && [ "$(in_op Shared OP_TOKEN S_OC_OTHER)" -eq 1 ] &&
    [ "$(sed -n 1p "$OH/.bashrc")" = "$want_op_bash" ] &&
    awk '/^item create --vault Personal -$/{s=1} s && /^read -n op:\/\/Personal\/OP_TOKEN\/password$/{f=1} END{exit !f}' "$OLOG"
}
check "with --store 1password, move stores the value in 1Password, reads it back, and rewrites the line" "op_moved"
op_stdin_only() {
  [ -s "$OLOG" ] && [ "$(in_op Personal OP_TOKEN S_OA)" -eq 1 ] && [ "$(in_op Personal OP_FISH_TOKEN S_OF)" -eq 1 ] &&
    python3 -c 'import os,sys; t=open(sys.argv[1]).read(); sys.exit(1 if any(os.environ[n] in t or os.environ[n][:4] in t for n in sys.argv[2:]) else 0)' \
      "$OLOG" S_OA S_OS S_OC S_OC_OTHER S_OT S_ON S_OF
}
check "with --store 1password, the value reaches op only on standard input" "op_stdin_only"
op_fish() { [ "$(sed -n 1p "$OH/.config/fish/config.fish")" = "$want_op_fish" ] && [ "$(in_op Personal OP_FISH_TOKEN S_OF)" -eq 1 ]; }
check "with --store 1password, a fish line reads the value with fish command substitution" "op_fish"
op_same() {
  jnote "$OUT/op-move.json" OP_SAME_TOKEN | grep -q '^moved stored in 1Password as OP_SAME_TOKEN' &&
    [ "$(titled Personal OP_SAME_TOKEN)" -eq 1 ] && [ "$(sed -n 2p "$OH/.bashrc")" = "$want_op_same" ]
}
check "with --store 1password, a name that already holds the same value is not added again" "op_same"
op_conflict() {
  jnote "$OUT/op-move.json" OP_CONFLICT_TOKEN | grep -q '^skipped a different value is already stored as OP_CONFLICT_TOKEN' &&
    [ "$(titled Personal OP_CONFLICT_TOKEN)" -eq 1 ] && [ "$(in_op Personal OP_CONFLICT_TOKEN S_OC_OTHER)" -eq 1 ] &&
    grep -qF "$S_OC" "$OH/.bashrc"
}
check "with --store 1password, a name that holds a different value is skipped and not overwritten" "op_conflict"
op_twice() {
  jnote "$OUT/op-move.json" OP_TWICE_TOKEN | grep -q '^skipped .*more than one' &&
    [ "$(titled Personal OP_TWICE_TOKEN)" -eq 2 ] && grep -qF "$S_OT" "$OH/.bashrc"
}
check "with --store 1password, a name held by more than one item is skipped" "op_twice"
op_loaded() {
  local before
  before="$(op_calls '^read op://Personal/OP_TOKEN/password$')"
  HOME="$OH" PATH="$OPBIN:$PATH" FAKE_OP_DIR="$OD" FAKE_OP_LOG="$OLOG" bash --norc -c 'source ~/.bashrc; [ "$OP_TOKEN" = "$S_OA" ]' &&
    [ "$(op_calls '^read op://Personal/OP_TOKEN/password$')" -gt "$before" ]
}
check "with --store 1password, a new bash loads the moved value through op" "op_loaded"

# Without op on PATH. Only the commands the scan runs are linked into it.
HOME="$OH" PATH="$NOST" SECURE_DOTFILE_KEYCHAIN="$KC" \
  "$PY3" "$SCRIPT" move --store 1password --item "~/.bashrc:5:OP_DOWN_TOKEN" > "$OUT/op-none.txt" 2> "$OUT/op-none.err"
op_none_rc=$?
HOME="$OH" PATH="$NOST" SECURE_DOTFILE_KEYCHAIN="$KC" \
  "$PY3" "$SCRIPT" scan --store 1password --json > "$OUT/op-none.json" 2>> "$OUT/op-scan.err"
op_none() {
  [ "$op_none_rc" -eq 3 ] && grep -q 'needs the op command' "$OUT/op-none.err" &&
    [ "$(jfield "$OUT/op-none.json" OP_DOWN_TOKEN movable)" = False ] &&
    jfield "$OUT/op-none.json" OP_DOWN_TOKEN reason | grep -q 'needs the op command'
}
check "without op, move --store 1password exits 3 and names it, and scan says why it cannot move" "op_none"
docs_op() {
  local f
  for f in skills/secure-dotfile/SKILL.md README.md README.ja.md docs/how-it-works.md docs/how-it-works.ja.md; do
    grep -q "op read" "$HERE/../../../$f" && grep -q "1Password" "$HERE/../../../$f" || return 1
  done
  for f in README.md README.ja.md; do
    grep -q "op 2.42" "$HERE/../../../$f" || return 1
  done
  grep -q "real 1Password account" "$HERE/../../../README.md" &&
    grep -q "BW_SESSION" "$HERE/../../../docs/how-it-works.md" && grep -q "BW_SESSION" "$HERE/../../../docs/how-it-works.ja.md" &&
    grep -q -- "--store 1password" "$HERE/../SKILL.md"
}
check "the docs describe moving into 1Password and why Bitwarden is not a store" "docs_op"

# ---------------------------------------------------------------------------
# Files that tools read on their own: ~/.npmrc, ~/.aws/credentials, ~/.netrc, and the .env files
# of the folder the scan runs in. Values move into the stand-in secret-tool, so these checks run
# on any system.

TH="$T/tools/home"
TH2="$T/tools/home2"
TS="$T/tools/store"
TP="$T/tools/project"
mkdir -p "$TH/.aws" "$TH2" "$TS" "$TP/sub"
printf 'registry=https://registry.npmjs.org/\n//registry.npmjs.org/:_authToken=%s\n//npm.pkg.github.com/:_authToken=%s\n' "$S_NPM" "$S_NPMGH" > "$TH/.npmrc"
printf '[default]\naws_access_key_id = %s\naws_secret_access_key = %s\n\n[work]\naws_access_key_id = %s\naws_secret_access_key = %s\n\n[temp]\naws_access_key_id = %s\naws_secret_access_key = %s\naws_session_token = %s\n' \
  "$S_AK" "$S_SK" "$S_AK2" "$S_SK2" "$S_AKT" "$S_SKT" "$S_ST" > "$TH/.aws/credentials"
printf 'machine api.example.com login tester password %s\n' "$S_NETRC" > "$TH/.netrc"
printf '# shell setup\n' > "$TH/.zshrc"
printf '# shell setup\n' > "$TH/.bashrc"
# A second home whose startup file already sets NPM_TOKEN.
printf '//registry.npmjs.org/:_authToken=%s\n' "$S_NPM2" > "$TH2/.npmrc"
printf 'export NPM_TOKEN="$(cat ~/.npm-token)"\n' > "$TH2/.zshrc"
# The project: .env is untracked, .env.local was committed, and sub/.env is one folder down.
printf 'API_TOKEN=%s\n' "$S_ENV" > "$TP/.env"
printf 'LOCAL_SECRET_KEY=%s\n' "$S_ENVLOCAL" > "$TP/.env.local"
printf 'SUB_TOKEN=%s\n' "$S_ENVSUB" > "$TP/sub/.env"
git -C "$TP" init -q
git -C "$TP" -c user.name=test -c user.email=test@example.com add -f .env.local
git -C "$TP" -c user.name=test -c user.email=test@example.com commit -qm init
tf() { (cd "$TP" && HOME="$TH" SHELL=/bin/zsh PATH="$FAKEBIN:$PATH" FAKE_SECRET_DIR="$TS" SECURE_DOTFILE_STORE=secret-service SECURE_DOTFILE_KEYCHAIN="$KC" "$@"); }
in_ts() { printf '%s' "$2" | cmp -s - "$TS/$1.$USER"; }
# The fields of the scanned item at this path and line, as JSON.
titem() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(json.dumps(next((i for i in d["items"] if i["path"]==sys.argv[2] and i["line"]==int(sys.argv[3])), {})))' "$1" "$2" "$3" 2>/dev/null; }
# A field of an item read from standard input, following the keys given.
tget() {
  python3 -c '
import json, sys
v = json.loads(sys.stdin.read() or "{}")
for k in sys.argv[1:]:
    v = v.get(k) if isinstance(v, dict) else None
print("" if v is None else v)' "$@"
}
lookup_of() { printf '"$(secret-tool lookup service %s account "$USER" 2>/dev/null)"' "$1"; }
want_npmrc_line='//registry.npmjs.org/:_authToken=${NPM_TOKEN}'
want_npm_export="export NPM_TOKEN=$(lookup_of NPM_TOKEN)"

TJ="$OUT/tf-scan.json"
tf python3 "$SCRIPT" scan --json > "$TJ" 2>> "$OUT/tf-scan.err"
tf_npm_scan() {
  local it
  it="$(titem "$TJ" '~/.npmrc' 2)"
  [ "$(tget name <<< "$it")" = NPM_TOKEN ] && [ "$(tget length <<< "$it")" = "${#S_NPM}" ] && [ "$(tget movable <<< "$it")" = True ] &&
    [ "$(tget becomes <<< "$it")" = "$want_npmrc_line" ] &&
    [ "$(tget adds path <<< "$it")" = '~/.zshrc' ] && [ "$(tget adds line <<< "$it")" = "$want_npm_export" ]
}
check "scan lists the npm token in .npmrc with the line it becomes and the export line it adds" "tf_npm_scan"

tf python3 "$SCRIPT" move --json --item "~/.npmrc:2:NPM_TOKEN" > "$OUT/tf-npm.json" 2>> "$OUT/tf-move.err"
tf env SHELL=/bin/bash python3 "$SCRIPT" move --json --item "~/.npmrc:3:NPM_TOKEN_NPM_PKG_GITHUB_COM" > "$OUT/tf-npmgh.json" 2>> "$OUT/tf-move.err"
tf_npm_moved() {
  jnote "$OUT/tf-npm.json" NPM_TOKEN | grep -q '^moved stored in the secret service as NPM_TOKEN' &&
    in_ts NPM_TOKEN "$S_NPM" && [ "$(sed -n 2p "$TH/.npmrc")" = "$want_npmrc_line" ] &&
    [ "$(tail -n 1 "$TH/.zshrc")" = "$want_npm_export" ] && ! grep -qF "$S_NPM" "$TH/.npmrc"
}
check "move stores the npm token, rewrites .npmrc to the variable, and adds the export line" "tf_npm_moved"
tf_npm_loaded() {
  HOME="$TH" PATH="$FAKEBIN:$PATH" FAKE_SECRET_DIR="$TS" zsh -fc 'source ~/.zshrc; [ "$NPM_TOKEN" = "$S_NPM" ]' &&
    HOME="$TH" PATH="$FAKEBIN:$PATH" FAKE_SECRET_DIR="$TS" bash --norc -c 'source ~/.bashrc; [ "$NPM_TOKEN_NPM_PKG_GITHUB_COM" = "$S_NPMGH" ]'
}
check "a new shell exports the moved npm token" "tf_npm_loaded"
tf_npm_other() {
  jnote "$OUT/tf-npmgh.json" NPM_TOKEN_NPM_PKG_GITHUB_COM | grep -q '^moved ' && in_ts NPM_TOKEN_NPM_PKG_GITHUB_COM "$S_NPMGH" &&
    [ "$(sed -n 3p "$TH/.npmrc")" = '//npm.pkg.github.com/:_authToken=${NPM_TOKEN_NPM_PKG_GITHUB_COM}' ] &&
    [ "$(tail -n 1 "$TH/.bashrc")" = "export NPM_TOKEN_NPM_PKG_GITHUB_COM=$(lookup_of NPM_TOKEN_NPM_PKG_GITHUB_COM)" ]
}
check "a token for another registry gets a variable named after its host" "tf_npm_other"

tf2_before="$(cat "$TH2/.npmrc" "$TH2/.zshrc" | cksum)"
(cd "$TP" && HOME="$TH2" SHELL=/bin/zsh PATH="$FAKEBIN:$PATH" FAKE_SECRET_DIR="$TS" SECURE_DOTFILE_STORE=secret-service SECURE_DOTFILE_KEYCHAIN="$KC" \
  python3 "$SCRIPT" move --json --item "~/.npmrc:1:NPM_TOKEN") > "$OUT/tf-npmset.json" 2>> "$OUT/tf-move.err"
tf_npm_set() {
  jnote "$OUT/tf-npmset.json" NPM_TOKEN | grep -q '^skipped .*already sets NPM_TOKEN' &&
    [ "$(cat "$TH2/.npmrc" "$TH2/.zshrc" | cksum)" = "$tf2_before" ] && ! grep -rqF "$S_NPM2" "$TS"
}
check "an npm token whose variable a startup file already sets is skipped and no file changes" "tf_npm_set"

tf_aws_scan() {
  local d w
  d="$(titem "$TJ" '~/.aws/credentials' 3)"
  w="$(titem "$TJ" '~/.aws/credentials' 7)"
  [ "$(tget name <<< "$d")" = AWS_SECRET_ACCESS_KEY_DEFAULT ] && [ "$(tget movable <<< "$d")" = True ] &&
    tget becomes <<< "$d" | grep -q "^credential_process = sh -c .*AWS_ACCESS_KEY_ID_DEFAULT.*AWS_SECRET_ACCESS_KEY_DEFAULT" &&
    [ "$(tget name <<< "$w")" = AWS_SECRET_ACCESS_KEY_WORK ] && tget becomes <<< "$w" | grep -q 'AWS_SECRET_ACCESS_KEY_WORK'
}
check "scan lists each AWS profile's secret key with the credential_process line it becomes" "tf_aws_scan"
tf_temp_listed() {
  local it
  it="$(titem "$TJ" '~/.aws/credentials' 11)"
  [ "$(tget movable <<< "$it")" = False ] && tget reason <<< "$it" | grep -q 'session token'
}

tf python3 "$SCRIPT" move --json --item "~/.aws/credentials:3:AWS_SECRET_ACCESS_KEY_DEFAULT" \
  --item "~/.aws/credentials:11:AWS_SECRET_ACCESS_KEY_TEMP" > "$OUT/tf-aws.json" 2>> "$OUT/tf-move.err"
aws_section() { awk -v s="[$1]" '$0==s{f=1;next} /^\[/{f=0} f' "$TH/.aws/credentials"; }
tf_aws_moved() {
  jnote "$OUT/tf-aws.json" AWS_SECRET_ACCESS_KEY_DEFAULT | grep -q '^moved ' &&
    in_ts AWS_ACCESS_KEY_ID_DEFAULT "$S_AK" && in_ts AWS_SECRET_ACCESS_KEY_DEFAULT "$S_SK" &&
    [ "$(aws_section default | grep -c '^credential_process = ')" -eq 1 ] && ! aws_section default | grep -q '^aws_' &&
    aws_section work | grep -qF "$S_AK2" && aws_section work | grep -qF "$S_SK2" && ! grep -qF "$S_SK" "$TH/.aws/credentials"
}
check "move stores both AWS keys and replaces the two lines with credential_process" "tf_aws_moved"
# Runs the command the way the AWS CLI does: split like a shell, then run without a shell.
tf_aws_process() {
  aws_section default | sed -n 's/^credential_process = //p' |
    PATH="$FAKEBIN:$PATH" FAKE_SECRET_DIR="$TS" python3 -c '
import json, os, shlex, subprocess, sys
cmd = sys.stdin.read().strip()
if not cmd:
    sys.exit(1)
r = subprocess.run(shlex.split(cmd), capture_output=True)
d = json.loads(r.stdout)
sys.exit(0 if r.returncode == 0 and d.get("Version") == 1 and d.get("AccessKeyId") == os.environ["S_AK"] and d.get("SecretAccessKey") == os.environ["S_SK"] else 1)' 2>/dev/null
}
check "the credential_process command prints both AWS keys as the JSON the AWS CLI reads" "tf_aws_process"
tf_aws_temp() {
  tf_temp_listed && jnote "$OUT/tf-aws.json" AWS_SECRET_ACCESS_KEY_TEMP | grep -q '^skipped .*session token' &&
    aws_section temp | grep -qF "$S_SKT" && aws_section temp | grep -qF "$S_ST" && [ ! -e "$TS/AWS_SECRET_ACCESS_KEY_TEMP.$USER" ]
}
check "an AWS profile with a session token is listed as not movable and left as it was" "tf_aws_temp"
tf_stdin_only() {
  [ -s "$TS/args" ] && in_ts NPM_TOKEN "$S_NPM" && in_ts AWS_SECRET_ACCESS_KEY_DEFAULT "$S_SK" &&
    python3 -c 'import os,sys; t=open(sys.argv[1]).read(); sys.exit(1 if any(os.environ[n] in t or os.environ[n][:4] in t for n in sys.argv[2:]) else 0)' \
      "$TS/args" S_NPM S_NPMGH S_AK S_SK
}
check "npm and AWS values reach the store only on standard input" "tf_stdin_only"

netrc_item="$(titem "$TJ" '~/.netrc' 1)"
netrc_before="$(cksum < "$TH/.netrc")"
tf python3 "$SCRIPT" move --json --item "$(tget item <<< "$netrc_item")" > "$OUT/tf-netrc.json" 2>> "$OUT/tf-move.err"
tf_netrc() {
  [ "$(tget movable <<< "$netrc_item")" = False ] && tget reason <<< "$netrc_item" | grep -q 'credential helper' &&
    [ "$(cksum < "$TH/.netrc")" = "$netrc_before" ]
}
check "scan lists a .netrc password as not movable and names git's credential helper" "tf_netrc"

tf_env() {
  [ "$(jfield "$TJ" API_TOKEN movable)" = False ] && jfield "$TJ" API_TOKEN reason | grep -q 'env' &&
    [ "$(jfield "$TJ" API_TOKEN in_git_history)" = 'not tracked by git' ] &&
    [ "$(jfield "$TJ" LOCAL_SECRET_KEY movable)" = False ] && [ "$(jfield "$TJ" LOCAL_SECRET_KEY in_git_history)" = yes ] &&
    [ -z "$(jfield "$TJ" SUB_TOKEN name)" ] && [ ! -s "$OUT/tf-scan.err" ]
}
check "scan lists secrets in the current folder's .env files as not movable, with their git history, and skips subfolders" "tf_env"
docs_tools() {
  local f
  for f in skills/secure-dotfile/SKILL.md README.md README.ja.md docs/how-it-works.md docs/how-it-works.ja.md; do
    grep -q '\.npmrc' "$HERE/../../../$f" && grep -q 'credential_process' "$HERE/../../../$f" &&
      grep -q '\.netrc' "$HERE/../../../$f" && grep -q '\.env\.\*' "$HERE/../../../$f" || return 1
  done
}
check "the docs describe the tool files it scans and how each is moved or why not" "docs_tools"

# ---------------------------------------------------------------------------
# No output holds a value or its first 4 characters.

python3 - "$OUT" "${ALL_SECRETS[@]}" > "$OUT/../leak.txt" <<'PY'
import os, sys
out = sys.argv[1]
text = "".join(open(os.path.join(out, f), errors="replace").read() for f in os.listdir(out) if f != "files.txt")
leaks = [n for n in sys.argv[2:] if os.environ[n] in text or os.environ[n][:4] in text]
print("leaked:", len(leaks), " ".join(leaks))
PY
check "no output contains a value or its first 4 characters" "grep -q '^leaked: 0' \"$T/leak.txt\""
check "the scan wrote nothing to standard error" "[ ! -s \"$OUT/scan.err\" ]"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
