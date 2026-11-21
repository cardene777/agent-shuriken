#!/usr/bin/env bash
# Tests for machine_cleanup.py with a throwaway HOME, a throwaway state folder, and stand-ins for
# every outside command the script runs (ps, du, lsof, df, docker, the package managers, launchctl,
# mdls, flatpak, ...). PATH holds only the stand-ins and links to the few real tools the tests need,
# so nothing on this machine is measured, stopped, or deleted. The only processes signalled are
# `sleep` processes the tests start. Nothing reaches the network; the server test talks to 127.0.0.1.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
SCRIPTS="$SKILL_DIR/scripts"
SCRIPT="$SCRIPTS/machine_cleanup.py"
SHEET="$SKILL_DIR/templates/sheet.html"
REPO="$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null || true)"
PY="$(python3 -c 'import sys; print(sys.executable)')"
REAL_DU="$(command -v du)"
# Node.js runs the page's own functions in one check; that check is skipped when it is missing.
NODE="$(command -v node 2>/dev/null || true)"
# A Chromium-based browser opens the page as a reader does, for the checks on the opened page.
# MACHINE_CLEANUP_TEST_BROWSER names the browser; otherwise the usual apps, the headless browsers
# Playwright downloaded, and then the usual commands are tried, in the order techdebt's test uses,
# all before HOME is replaced below. Without a browser, those checks are skipped.
REAL_BROWSER=""
for b in "${MACHINE_CLEANUP_TEST_BROWSER:-}" \
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  "/Applications/Chromium.app/Contents/MacOS/Chromium" \
  "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
  "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" \
  "$HOME"/Library/Caches/ms-playwright/chromium_headless_shell-*/*/chrome-headless-shell \
  "$HOME"/.cache/ms-playwright/chromium_headless_shell-*/*/chrome-headless-shell \
  "$(command -v google-chrome 2>/dev/null)" "$(command -v chromium 2>/dev/null)" "$(command -v chromium-browser 2>/dev/null)"; do
  if [ -n "$b" ] && [ -x "$b" ]; then REAL_BROWSER="$b"; break; fi
done
PASS=0
FAIL=0
T="$(cd "$(mktemp -d)" && pwd -P)"
SPAWNED=()
cleanup() {
  local p
  for p in "${SPAWNED[@]:-}"; do [ -n "$p" ] && kill -KILL "$p" 2>/dev/null; done
  [ -n "${SERVE_PID:-}" ] && kill "$SERVE_PID" 2>/dev/null
  rm -rf "$T"
}
trap cleanup EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }

# Only the stand-ins and a few real tools are on PATH, so the script cannot reach a real ps, du,
# docker, or package manager on this machine.
BIN="$T/bin"
SYS="$T/sysbin"
MOCK="$T/mock"
mkdir -p "$BIN" "$SYS" "$MOCK"
for tool in bash sh env git cat rm mkdir ls touch sleep kill chmod find grep sed awk head tail wc \
  date mv cp ln tr cut sort uniq dirname basename id uname curl mktemp xargs readlink jq seq; do
  real="$(command -v "$tool" 2>/dev/null || true)"
  [ -n "$real" ] && ln -sf "$real" "$SYS/$tool"
done
ln -sf "$PY" "$SYS/python3"

export HOME="$T/home"
H="$HOME"
export MACHINE_CLEANUP_HOME="$T/state"
export MOCK PY REAL_DU H
export GIT_CONFIG_NOSYSTEM=1 GIT_AUTHOR_NAME=tester GIT_AUTHOR_EMAIL=tester GIT_COMMITTER_NAME=tester GIT_COMMITTER_EMAIL=tester
# Variables that move a cache elsewhere would point the scan at this machine's real caches.
unset XDG_CACHE_HOME XDG_DATA_HOME XDG_CONFIG_HOME XDG_STATE_HOME npm_config_cache NPM_CONFIG_CACHE \
  PNPM_HOME PNPM_STORE_DIR YARN_CACHE_FOLDER BUN_INSTALL BUN_INSTALL_CACHE_DIR PIP_CACHE_DIR UV_CACHE_DIR \
  HOMEBREW_CACHE CARGO_HOME GOPATH GOMODCACHE GOCACHE GRADLE_USER_HOME CP_HOME_DIR DOCKER_HOST DOCKER_CONTEXT \
  NVM_DIR FNM_DIR PYENV_ROOT RBENV_ROOT ASDF_DATA_DIR ASDF_DEFAULT_TOOL_VERSIONS_FILENAME MISE_DATA_DIR MISE_CONFIG_DIR \
  MISE_GLOBAL_CONFIG_FILE RUSTUP_HOME OLLAMA_MODELS HF_HUB_CACHE HF_HOME
mkdir -p "$H"
U="$(id -un)"
UID_NOW="$(id -u)"

# --- stand-ins ------------------------------------------------------------------------------
stub() { printf '#!/bin/bash\n%s\n' "$2" > "$BIN/$1"; chmod +x "$BIN/$1"; }
LOG='echo "$(basename "$0") $*" >> "$MOCK/calls.log"'
# ps prints $MOCK/ps.first once when it exists (the first CPU sample), then $MOCK/ps.
stub ps "$LOG"'
if [ -f "$MOCK/ps.first" ]; then cat "$MOCK/ps.first"; rm -f "$MOCK/ps.first"; else cat "$MOCK/ps" 2>/dev/null; fi'
# du records the niceness it runs at, then prints a size from $MOCK/du.sizes or measures for real.
stub du "$LOG"'
"$PY" -c "import os; print(os.nice(0))" >> "$MOCK/du.nice"
for p in "$@"; do case "$p" in -*) continue;; esac
  kb="$(awk -F "\t" -v p="$p" "\$1 == p { print \$2 }" "$MOCK/du.sizes" 2>/dev/null | tail -1)"
  if [ -n "$kb" ]; then printf "%s\t%s\n" "$kb" "$p"; else "$REAL_DU" -sk "$p"; fi
done'
stub taskpolicy "$LOG"'
[ "$1" = -b ] && shift
exec "$@"'
stub ionice "$LOG"'
while [ "${1#-}" != "$1" ]; do shift; done
exec "$@"'
stub lsof "$LOG"'
cat "$MOCK/lsof" 2>/dev/null'
stub df "$LOG"'
if [ -f "$MOCK/df.first" ]; then cat "$MOCK/df.first"; rm -f "$MOCK/df.first"; else cat "$MOCK/df"; fi'
stub vm_stat "$LOG"'
printf "Mach Virtual Memory Statistics: (page size of 16384 bytes)\nPages free: 100000.\nPages active: 300000.\nPages inactive: 50000.\nPages wired down: 100000.\nPages occupied by compressor: 50000.\n"'
stub sysctl "$LOG"'
echo 17179869184'
stub mdls "$LOG"'
cat "$MOCK/mdls"'
stub launchctl "$LOG"'
exit 0'
stub systemctl "$LOG"'
case "$*" in *list-unit-files*) cat "$MOCK/systemctl" 2>/dev/null;; esac
exit 0'
stub flatpak "$LOG"'
case "$*" in *list*) printf "org.example.Viewer\tViewer\t250.0 MB\n";; esac
exit 0'
stub docker "$LOG"'
case "$1 $2" in
  "system df") cat "$MOCK/docker-df";;
  "ps --format"|"ps "*) cat "$MOCK/docker-ps";;
  "stats --no-stream") cat "$MOCK/docker-stats";;
esac
exit 0'
for tool in brew npm pnpm yarn bun pip uv go pod rustup ollama; do stub "$tool" "$LOG"; done
# git is the real one, with each call recorded, so the tests can tell the scan never fetches.
REAL_GIT="$(command -v git)"
export REAL_GIT
stub git "$LOG"'
exec "$REAL_GIT" "$@"'
export PATH="$BIN:$SYS"

mc() { "$PY" "$SCRIPT" "$@"; }
# mc_as <platform> ...: runs the script as it runs on macOS (darwin), Linux, or WSL.
mc_as() {
  local platform="$1"; shift
  "$PY" -c 'import sys; sys.path.insert(0, sys.argv[1]); import machine_cleanup as m; sys.exit(m.main(sys.argv[3:], platform=sys.argv[2]))' \
    "$SCRIPTS" "$platform" "$@"
}
# old <path>...: makes files 40 days old.
old() { "$PY" -c 'import os, sys, time; t = time.time() - 40 * 86400; [os.utime(p, (t, t)) for p in sys.argv[1:]]' "$@"; }
# sparse <path> <MB>: a file of that size that takes no disk space.
sparse() { mkdir -p "$(dirname "$1")"; "$PY" -c 'import sys; f = open(sys.argv[1], "wb"); f.truncate(int(sys.argv[2]) * 1048576); f.close()' "$1" "$2"; }
fill() { mkdir -p "$1"; printf 'x' > "$1/file"; }
size() { printf '%s\t%s\n' "$1" "$2" >> "$MOCK/du.sizes"; }
gitrepo() { mkdir -p "$1"; git -C "$1" init -q; }

# --- fixtures -------------------------------------------------------------------------------
# Rebuilt caches, one per kind, in their default macOS places.
for d in .npm/_cacache Library/pnpm/store Library/Caches/Yarn .bun/install/cache Library/Caches/pip \
  .cache/uv Library/Caches/Homebrew .cargo/registry/cache go/pkg/mod .gradle/caches .m2/repository \
  Library/Caches/CocoaPods Library/Developer/Xcode/DerivedData Library/Caches/com.example.editor; do
  fill "$H/$d"; size "$H/$d" 81920
done
printf '%s\n' '{"Type":"Images","TotalCount":"5","Active":"1","Size":"4.2GB","Reclaimable":"3.1GB (73%)"}' \
  '{"Type":"Containers","TotalCount":"1","Active":"1","Size":"10MB","Reclaimable":"0B (0%)"}' \
  '{"Type":"Local Volumes","TotalCount":"2","Active":"1","Size":"900MB","Reclaimable":"400MB (44%)"}' \
  '{"Type":"Build Cache","TotalCount":"30","Active":"0","Size":"2.5GB","Reclaimable":"2.5GB"}' > "$MOCK/docker-df"
printf '%s\n' '{"ID":"abc123","Names":"shop-db-1","Image":"postgres:16","RunningFor":"3 days","Labels":"com.docker.compose.project=shop"}' > "$MOCK/docker-ps"
printf '%s\n' '{"ID":"abc123","Name":"shop-db-1","CPUPerc":"0.50%","MemUsage":"120MiB / 7.6GiB"}' > "$MOCK/docker-stats"

# Two projects. shop's ignored build output is free to delete; blog has a program working in it.
SHOP="$H/projects/shop"
gitrepo "$SHOP"
printf 'node_modules/\n.next/\ndist/\n' > "$SHOP/.gitignore"
fill "$SHOP/node_modules/left-pad"; size "$SHOP/node_modules" 204800
fill "$SHOP/.next/cache"; size "$SHOP/.next" 102400
fill "$SHOP/dist"; size "$SHOP/dist" 51200
git -C "$SHOP" add .gitignore && git -C "$SHOP" add -f dist/file && git -C "$SHOP" commit -qm init
BLOG="$H/projects/blog"
gitrepo "$BLOG"
printf 'node_modules/\n' > "$BLOG/.gitignore"
fill "$BLOG/node_modules/react"; size "$BLOG/node_modules" 102400
mkdir -p "$BLOG/src"
# notes has a live agent working in it, and a dev server whose parent has ended.
NOTES="$H/projects/notes"
gitrepo "$NOTES"
mkdir -p "$NOTES/web"
printf 'p4242\nfcwd\nn%s\np1100\nfcwd\nn%s\np1101\nfcwd\nn%s\np1000\nfcwd\nn/\n' "$BLOG/src" "$NOTES" "$NOTES/web" > "$MOCK/lsof"

# archive's last commit is 40 days old, so its ignored build output is recommended; shop's is new.
ARCHIVE="$H/projects/archive"
gitrepo "$ARCHIVE"
printf 'node_modules/\n' > "$ARCHIVE/.gitignore"
fill "$ARCHIVE/node_modules/lodash"; size "$ARCHIVE/node_modules" 102400
OLD_COMMIT="@$(( $(date +%s) - 40 * 86400 )) +0000"
git -C "$ARCHIVE" add .gitignore && GIT_AUTHOR_DATE="$OLD_COMMIT" GIT_COMMITTER_DATE="$OLD_COMMIT" git -C "$ARCHIVE" commit -qm init

# Trash, logs, and installers, old and new.
mkdir -p "$H/.Trash"; printf 'old note' > "$H/.Trash/old-note.txt"
mkdir -p "$H/Library/Logs/Editor" "$H/Library/Logs/DiagnosticReports" "$H/Downloads"
printf 'old' > "$H/Library/Logs/Editor/old.log"; printf 'new' > "$H/Library/Logs/Editor/new.log"
printf 'crash' > "$H/Library/Logs/DiagnosticReports/Editor-2026.crash"
printf 'dmg' > "$H/Downloads/Editor-1.0.dmg"; printf 'dmg' > "$H/Downloads/Editor-2.0.dmg"
old "$H/Library/Logs/Editor/old.log" "$H/Library/Logs/DiagnosticReports/Editor-2026.crash" "$H/Downloads/Editor-1.0.dmg"

# A large file, a duplicate pair, and a small file that is not a duplicate.
sparse "$H/Videos/raw.mov" 600
sparse "$H/Documents/archive.zip" 12
sparse "$H/Backup/archive.zip" 12
sparse "$H/Documents/small.bin" 5
# An old installer over 500 MB, which the large file walk also meets, and an old installer with a
# copy of the same contents in another folder. Each size is used by no other file here.
sparse "$H/Downloads/Big-2.0.dmg" 540
sparse "$H/Downloads/Tool-1.0.dmg" 20
sparse "$H/Archive/Tool-1.0.dmg" 20
old "$H/Downloads/Big-2.0.dmg" "$H/Downloads/Tool-1.0.dmg"

# An app last opened 200 days ago, with its support files.
APP="$H/Applications/Editor.app"
mkdir -p "$APP/Contents/MacOS"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.example.editor</string>
<key>CFBundleName</key><string>Editor</string>
</dict></plist>
PLIST
size "$APP" 409600
mkdir -p "$H/Library/Application Support/com.example.editor" "$H/Library/Preferences"
printf 'data' > "$H/Library/Application Support/com.example.editor/state"
printf 'prefs' > "$H/Library/Preferences/com.example.editor.plist"
"$PY" -c 'import datetime as d; print((d.datetime.now(d.timezone.utc) - d.timedelta(days=200)).strftime("%Y-%m-%d %H:%M:%S +0000"))' > "$MOCK/mdls"

# Sync folders and a symbolic link to a folder outside HOME.
sparse "$H/Library/Mobile Documents/com~apple~CloudDocs/huge.mov" 600
gitrepo "$H/Library/CloudStorage/Dropbox/synced"
printf 'node_modules/\n' > "$H/Library/CloudStorage/Dropbox/synced/.gitignore"
fill "$H/Library/CloudStorage/Dropbox/synced/node_modules/x"
sparse "$H/Dropbox/big.mov" 600
sparse "$H/OneDrive/big.mov" 600
OUT="$T/outside"
gitrepo "$OUT/repo"
printf 'node_modules/\n' > "$OUT/repo/.gitignore"
fill "$OUT/repo/node_modules/x"
sparse "$OUT/huge.mov" 600
ln -s "$OUT" "$H/linked"
fill "$T/outside-cache"; size "$T/outside-cache" 81920
ln -s "$T/outside-cache" "$H/Library/Caches/LinkedCache"

# A login item.
mkdir -p "$H/Library/LaunchAgents"
cat > "$H/Library/LaunchAgents/com.example.updater.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>Label</key><string>com.example.updater</string>
<key>ProgramArguments</key><array><string>/opt/example/updater</string></array>
<key>RunAtLoad</key><true/>
</dict></plist>
PLIST

# Free space before and after, as df prints it.
DF_HEAD='Filesystem 1024-blocks Used Available Capacity iused ifree %iused Mounted on'
printf '%s\n/dev/disk3s1 500000000 490000000 10000000 98%% 1 1 1%% /\n' "$DF_HEAD" > "$MOCK/df"

# Real processes for the signal checks, left to init so they are reaped when they end.
spawn() { ( "$@" >/dev/null 2>&1 & echo $! > "$T/spawned" ); cat "$T/spawned"; }
P_TERM="$(spawn sleep 300)"
P_STUBBORN="$(spawn bash -c 'trap "" TERM; exec sleep 301')"
P_REUSED="$(spawn sleep 302)"
SPAWNED=("$P_TERM" "$P_STUBBORN" "$P_REUSED")

# ps: pid ppid user tty rss(KB) cputime lstart args
psline() { printf '%s %s %s %s %s %s %s %s\n' "$@"; }
LSTART='Sat Nov 15 09:00:00 2026'
write_ps() {
  {
    psline 1 0 root '??' 1000 0:10.00 "$LSTART" /sbin/launchd
    psline 500 1 "$U" '??' 20000 0:01.00 "$LSTART" 'claude --output-format stream-json'
    psline 501 500 "$U" '??' 300000 0:30.00 "$LSTART" 'node /work/shop/node_modules/.bin/next dev'
    psline 600 1 "$U" '??' 250000 0:20.00 "$LSTART" 'node /work/old/node_modules/.bin/vite'
    psline 700 1 "$U" ttys001 150000 0:05.00 "$LSTART" 'npm run dev'
    psline 800 1 "$U" '??' 2500000 "$1" "$LSTART" '/Applications/Browser.app/Contents/MacOS/Browser'
    psline 900 1 root '??' 3000000 50:00.00 "$LSTART" /usr/libexec/heavyd
    psline 4242 1 "$U" '??' 10000 0:00.10 "$LSTART" 'node /work/blog/server.js'
    # Host.app runs an agent session; its renderer helper and the bundled agent are heavy.
    psline 1000 1 "$U" '??' 900000 0:40.00 "$LSTART" '/Applications/Host.app/Contents/MacOS/Host'
    psline 1001 1000 "$U" '??' 800000 0:40.00 "$LSTART" '/Applications/Host.app/Contents/Frameworks/Host Helper (Renderer).app/Contents/MacOS/Host Helper (Renderer) --type=renderer'
    psline 1002 1000 "$U" '??' 700000 0:40.00 "$LSTART" '/Applications/Host.app/Contents/Resources/codex app-server'
    psline 1100 1 "$U" '??' 20000 0:01.00 "$LSTART" 'claude'
    psline 1101 1 "$U" '??' 90000 0:02.00 "$LSTART" 'node /work/notes/node_modules/.bin/vite'
    # A helper whose path has spaces and starts with an agent's name, and a tool shipped inside an app.
    psline 1200 1 "$U" '??' 650000 0:10.00 "$LSTART" '/Applications/Codex.app/Contents/Frameworks/Codex (Renderer).app/Contents/MacOS/Codex (Renderer) --type=renderer'
    psline 1201 1 "$U" '??' 600000 0:10.00 "$LSTART" '/Applications/Xcode.app/Contents/Developer/usr/bin/git status'
    psline 1202 1 "$U" '??' 600000 0:10.00 "$LSTART" '/Applications/Xcode.app/Contents/Developer/Library/Frameworks/Python3.framework/Versions/3.9/Resources/Python.app/Contents/MacOS/Python -B job.py'
    # next-server is also what `next start` is renamed to, so it may be a server in use.
    psline 1300 1 "$U" '??' 80000 0:01.00 "$LSTART" 'next-server (v15.5.29)'
    psline "$P_TERM" 1 "$U" '??' 60000 0:01.00 "$LSTART" 'node /work/a/node_modules/.bin/vite'
    psline "$P_STUBBORN" 1 "$U" '??' 60000 0:01.00 "$LSTART" 'node /work/b/node_modules/.bin/nodemon'
    psline "$P_REUSED" 1 "$U" '??' 60000 0:01.00 "${2:-$LSTART}" 'node /work/c/node_modules/.bin/webpack serve'
    # A Ruby server runs from an rbenv version, and Ollama runs only when OLLAMA_UP is set.
    psline 1401 1 "$U" '??' 10000 0:00.10 "$LSTART" "$H/.rbenv/versions/3.1.4/bin/ruby server.rb"
    [ -n "${OLLAMA_UP:-}" ] && psline 1400 1 "$U" '??' 10000 0:00.10 "$LSTART" 'ollama serve'
  } > "$MOCK/ps"
}
write_ps 9:50.00
cp "$MOCK/ps" "$MOCK/ps.first"
write_ps 10:00.00

# Work folders. Each project is a clone of its own bare repository outside HOME, with one commit
# 40 days old that is pushed, and HEAD and its log 40 days old. The variations make one thing recent,
# changed, or missing from the remote.
idle() { old "$1/.git/HEAD" "$1/.git/logs/HEAD"; }
project() {
  local r="$H/projects/$1" o="$T/remotes/$1.git"
  git init -q --bare "$o"
  git clone -q "$o" "$r" 2>/dev/null
  printf 'readme\n' > "$r/README.md"
  git -C "$r" add README.md
  GIT_AUTHOR_DATE="$OLD_COMMIT" GIT_COMMITTER_DATE="$OLD_COMMIT" git -C "$r" commit -qm init
  git -C "$r" push -q origin HEAD 2>/dev/null
  idle "$r"
}
for p in idle idle2 recentco dirty untracked localonly withwt skipc skipch skipl; do project "$p"; done
IDLE="$H/projects/idle"
IDLE2="$H/projects/idle2"
# recentco was checked out today, dirty has a changed file, untracked has a new file, and
# localonly has a commit that was never pushed.
touch "$H/projects/recentco/.git/HEAD" "$H/projects/recentco/.git/logs/HEAD"
printf 'edit\n' >> "$H/projects/dirty/README.md"
printf 'new\n' > "$H/projects/untracked/notes.txt"
printf 'local\n' >> "$H/projects/localonly/README.md"
GIT_AUTHOR_DATE="$OLD_COMMIT" GIT_COMMITTER_DATE="$OLD_COMMIT" git -C "$H/projects/localonly" commit -qam local
idle "$H/projects/localonly"
# withwt has a second worktree, which is a folder whose .git is a file.
git -C "$H/projects/withwt" worktree add -q "$H/projects/withwt-feature" 2>/dev/null
idle "$H/projects/withwt"
# idlebuild is idle and holds ignored build output and an ignored large file, which are listed as
# rows of their own inside the project's row.
IDLEB="$H/projects/idlebuild"
project idlebuild
printf 'node_modules/\n*.bin\n' > "$IDLEB/.gitignore"
git -C "$IDLEB" add .gitignore && GIT_AUTHOR_DATE="$OLD_COMMIT" GIT_COMMITTER_DATE="$OLD_COMMIT" git -C "$IDLEB" commit -qm ignore
git -C "$IDLEB" push -q origin HEAD 2>/dev/null
fill "$IDLEB/node_modules/lodash"; size "$IDLEB/node_modules" 102400
sparse "$IDLEB/data/dump.bin" 520
idle "$IDLEB"

# Leftovers of a removed app in four Library folders, a second removed app, and folders that must
# not count: a company with an installed app (Editor is com.example), a name a running process has
# (Browser), recent files, Apple's, and a name that is not a bundle id.
LIB="$H/Library"
GONE_AS="$LIB/Application Support/com.oldvendor.gone"
mkdir -p "$GONE_AS" "$LIB/Caches/com.oldvendor.gone" "$LIB/Saved Application State/com.oldvendor.gone.savedState" \
  "$LIB/Application Support/com.gonevendor.app2" "$LIB/Application Support/com.example.helper" \
  "$LIB/Application Support/com.browserco.browser" "$LIB/Application Support/com.newvendor.tool" "$LIB/Application Support/OldThing"
for f in "$GONE_AS/data" "$LIB/Caches/com.oldvendor.gone/blob" "$LIB/Saved Application State/com.oldvendor.gone.savedState/windows.plist" \
  "$LIB/Preferences/com.oldvendor.gone.plist" "$LIB/Application Support/com.gonevendor.app2/data" \
  "$LIB/Application Support/com.example.helper/data" "$LIB/Application Support/com.browserco.browser/data" \
  "$LIB/Application Support/com.newvendor.tool/data" "$LIB/Application Support/OldThing/data" "$LIB/Preferences/com.apple.finder.plist" \
  "$LIB/Preferences/futari.preferences.test.plist" "$LIB/Preferences/com.randomsdk.storage.ezeEu4UqtErfpKf9TpbuQ4UvWgqYL9Ik.plist"; do
  printf 'x' > "$f"
done
# A first part that is not a top-level domain, and a generated part, are not bundle ids of an app.
old "$LIB/Preferences/futari.preferences.test.plist" "$LIB/Preferences/com.randomsdk.storage.ezeEu4UqtErfpKf9TpbuQ4UvWgqYL9Ik.plist"
old "$GONE_AS/data" "$GONE_AS" "$LIB/Caches/com.oldvendor.gone/blob" "$LIB/Caches/com.oldvendor.gone" \
  "$LIB/Saved Application State/com.oldvendor.gone.savedState/windows.plist" "$LIB/Saved Application State/com.oldvendor.gone.savedState" \
  "$LIB/Preferences/com.oldvendor.gone.plist" "$LIB/Application Support/com.gonevendor.app2/data" \
  "$LIB/Application Support/com.example.helper/data" "$LIB/Application Support/com.browserco.browser/data" \
  "$LIB/Application Support/OldThing/data" "$LIB/Preferences/com.apple.finder.plist"

# Tool versions. The unused ones are nvm 18, pyenv 3.9, fnm 16, asdf 18, mise node 21, and rustup
# 1.70. The rest are a default, named by a project, in use, or under a default nobody can resolve.
ver() { mkdir -p "$1/bin"; printf 'x' > "$1/bin/tool"; }
for v in v18.20.4 v20.11.1 v22.1.0; do ver "$H/.nvm/versions/node/$v"; done
mkdir -p "$H/.nvm/alias"; printf '20\n' > "$H/.nvm/alias/default"
for v in 3.9.18 3.11.7 3.12.1; do ver "$H/.pyenv/versions/$v"; done
printf '3.12.1\n' > "$H/.pyenv/version"
for v in 3.1.4 3.3.0; do ver "$H/.rbenv/versions/$v"; done
printf '3.3.0\n' > "$H/.rbenv/version"
FNM="$LIB/Application Support/fnm"
for v in v16.20.2 v20.11.1; do ver "$FNM/node-versions/$v/installation"; done
mkdir -p "$FNM/aliases"; ln -s "$FNM/node-versions/v20.11.1/installation" "$FNM/aliases/default"
for v in 18.19.0 20.11.1; do ver "$H/.asdf/installs/nodejs/$v"; done
printf 'nodejs 20.11.1\n' > "$H/.tool-versions"
MISE="$H/.local/share/mise/installs"
for v in 21.7.3 24.22.1 26.12.1; do ver "$MISE/node/$v"; done
ln -s ./21.7.3 "$MISE/node/21"; ln -s ./21.7.3 "$MISE/node/21.7"; ln -s ./24.22.1 "$MISE/node/24"; ln -s ./26.12.1 "$MISE/node/lts"
ver "$MISE/python/3.10.13"
# mise keeps a command-line tool from npm, "npm:@pen.dev/cli" in its config, in npm-pen-dev-cli.
ver "$MISE/npm-pen-dev-cli/0.3.12"; ln -s ./0.3.12 "$MISE/npm-pen-dev-cli/latest"
mkdir -p "$H/.config/mise"; printf '[tools]\nnode = "24"\npython = "latest"\n"npm:@pen.dev/cli" = "latest"\n' > "$H/.config/mise/config.toml"
for v in stable-aarch64-apple-darwin 1.70.0-aarch64-apple-darwin nightly-2024-01-01-aarch64-apple-darwin; do ver "$H/.rustup/toolchains/$v"; done
printf 'version = "12"\ndefault_toolchain = "stable-aarch64-apple-darwin"\n' > "$H/.rustup/settings.toml"
printf 'v22\n' > "$BLOG/.nvmrc"
printf '[tools]\nnode = "lts"\n' > "$BLOG/mise.toml"
printf '3.11\n' > "$NOTES/.python-version"
printf '[toolchain]\nchannel = "nightly-2024-01-01"\n' > "$NOTES/rust-toolchain.toml"

# AI models. Two Ollama models share one layer, Hugging Face has two models, and LM Studio has one
# model in its folder and one in its old place under ~/.cache.
OLLAMA="$H/.ollama/models"
blob() { mkdir -p "$OLLAMA/blobs"; "$PY" -c 'import sys; open(sys.argv[1], "wb").write(b"x" * int(sys.argv[2]))' "$OLLAMA/blobs/sha256-$(printf "%064d" 0 | tr 0 "$1")" "$2"; }
digest() { printf 'sha256:%s' "$(printf "%064d" 0 | tr 0 "$1")"; }
blob a 10; blob b 1000; blob c 300; blob d 200; blob e 20
manifest() {
  mkdir -p "$(dirname "$1")"
  printf '{"schemaVersion":2,"config":{"digest":"%s","size":%s},"layers":[{"digest":"%s","size":1000},{"digest":"%s","size":%s}]}\n' \
    "$(digest "$2")" "$3" "$(digest b)" "$(digest "$4")" "$5" > "$1"
  old "$1"
}
OLLAMA_LATEST="$OLLAMA/manifests/registry.ollama.ai/library/llama3/latest"
OLLAMA_Q4="$OLLAMA/manifests/registry.ollama.ai/library/llama3/8b-q4"
manifest "$OLLAMA_LATEST" a 10 c 300
manifest "$OLLAMA_Q4" e 20 d 200
hfmodel() {
  mkdir -p "$1/blobs" "$1/snapshots/rev1" "$1/refs"
  printf 'w' > "$1/blobs/abc"; ln -s ../../blobs/abc "$1/snapshots/rev1/model.bin"; printf 'rev1' > "$1/refs/main"
}
HF_TINY="$H/.cache/huggingface/hub/models--acme--tiny-model"
HF_OTHER="$H/.cache/huggingface/hub/models--acme--other-model"
hfmodel "$HF_TINY"; size "$HF_TINY" 204800
hfmodel "$HF_OTHER"; size "$HF_OTHER" 102400
size "$H/.cache/huggingface" 307200
LMS="$H/.lmstudio/models/lmstudio-community/Qwen2-GGUF"
mkdir -p "$LMS"; printf 'g' > "$LMS/qwen2.gguf"; size "$LMS" 102400
LMS_OLD="$H/.cache/lm-studio/models/old-pub/Old-GGUF"
mkdir -p "$LMS_OLD"; printf 'g' > "$LMS_OLD/old.gguf"; size "$LMS_OLD" 51200
size "$H/.cache/lm-studio" 102400

# --- scan -----------------------------------------------------------------------------------
SCAN="$MACHINE_CLEANUP_HOME/scan.json"
: > "$MOCK/calls.log"
mc_as darwin scan --json --sample 0 --apps-dir "$H/Applications" > "$T/scan.out" 2> "$T/scan.err"
cp "$MOCK/calls.log" "$T/scan-calls.log"
[ -s "$SCAN" ] || printf '{"items": [], "skipped": []}' > "$T/empty.json"
[ -s "$SCAN" ] || SCAN="$T/empty.json"

has() { jq -e "$1" "$SCAN" > /dev/null 2>&1; }
id_at() { jq -r --arg p "$1" '[.items[] | select(.path == $p)][0].id // empty' "$SCAN" 2>/dev/null; }
id_pid() { jq -r --argjson p "$1" '[.items[] | select(.pid == $p)][0].id // empty' "$SCAN" 2>/dev/null; }
id_kind() { jq -r --arg k "$1" '[.items[] | select(.kind == $k)][0].id // empty' "$SCAN" 2>/dev/null; }

kinds_ok=true
for k in npm pnpm yarn bun pip uv homebrew cargo go-modules gradle maven cocoapods docker-images \
  docker-build-cache xcode-derived-data app-cache; do
  jq -e --arg k "$k" '.items | any(.kind == $k and .category == "cache" and (.id | type) == "string" and (.size | type) == "number" and .rebuilt == true)' "$SCAN" > /dev/null 2>&1 \
    || { kinds_ok=false; echo "  missing cache kind: $k"; }
done
check "scan lists each kind of rebuilt cache with id, kind, size, and rebuilt" '$kinds_ok'

check "scan lists ignored build output in a git project" \
  '[ -n "$(id_at "$SHOP/node_modules")" ] && [ -n "$(id_at "$SHOP/.next")" ]'
check "scan never lists a build folder that holds a tracked file" \
  '[ -s "$T/scan.out" ] && [ -z "$(id_at "$SHOP/dist")" ]'
check "scan lists trash, old logs, and old installers" \
  'has ".items | any(.category == \"trash\")" && has ".items | any(.category == \"log\" and ((.detail.files // []) | any(endswith(\"old.log\"))) and ((.detail.files // []) | all(endswith(\"new.log\") | not)))" && [ -n "$(id_at "$H/Downloads/Editor-1.0.dmg")" ] && [ -z "$(id_at "$H/Downloads/Editor-2.0.dmg")" ]'
check "scan lists large files and duplicate sets" \
  'has ".items | any(.category == \"large\" and (.path | endswith(\"/Videos/raw.mov\")))" && [ "$(jq "[.items[] | select(.category == \"duplicate\" and (.path | endswith(\"archive.zip\")))] | length" "$SCAN")" = 2 ] && has "[.items[] | select(.category == \"duplicate\" and (.path | endswith(\"archive.zip\")))] | map(.detail.set) | unique | length == 1" && [ -z "$(id_at "$H/Documents/small.bin")" ]'

MACHINE_CLEANUP_HOME="$T/state-linux" mc_as linux scan --json --sample 0 > /dev/null 2>&1
LINUX_SCAN="$T/state-linux/scan.json"
check "scan lists apps with their last-used date and support files" \
  'has ".items | any(.category == \"app\" and .path == \"$APP\" and (.detail.last_used | type) == \"string\" and ((.detail.support // []) | index(\"$H/Library/Application Support/com.example.editor\") != null) and ((.detail.support // []) | index(\"$H/Library/Preferences/com.example.editor.plist\") != null))" && jq -e ".items | any(.category == \"app\" and .kind == \"flatpak\" and .name == \"Viewer\")" "$LINUX_SCAN" > /dev/null 2>&1'

MACHINE_CLEANUP_HOME="$T/state-wsl" mc_as wsl scan --json --sample 0 --root /mnt/c > /dev/null 2>&1
check "scan never enters sync folders or Windows drives" \
  '[ -s "$T/scan.out" ] && ! has ".items | any((.path // \"\") | test(\"Mobile Documents|/CloudStorage/|/Dropbox/|/OneDrive/\"))" && jq -e ".items | all((.path // \"\") | startswith(\"/mnt/\") | not)" "$T/state-wsl/scan.json" > /dev/null 2>&1 && jq -e ".skipped | any(.path == \"/mnt/c\")" "$T/state-wsl/scan.json" > /dev/null 2>&1'
check "scan does not follow symbolic links" \
  '[ -s "$T/scan.out" ] && ! has ".items | any((.path // \"\") | startswith(\"$H/linked\") or startswith(\"$T/outside\") or . == \"$H/Library/Caches/LinkedCache\")"'

MACHINE_CLEANUP_HOME="$T/state-limit" mc_as darwin scan --json --sample 0 --time-limit 0 --apps-dir "$H/Applications" > /dev/null 2>&1
check "scan stops at its time limit and lists what it skipped" \
  'jq -e "(.skipped | any(.reason == \"time limit\")) and (.items | all(.category != \"large\"))" "$T/state-limit/scan.json" > /dev/null 2>&1'
check "scan measures sizes at the lowest priority" \
  '[ -s "$MOCK/du.nice" ] && [ "$(sort -u "$MOCK/du.nice")" = 19 ]'

check "scan lists leftover dev processes, heavy processes, login items, and running containers" \
  'has "(.items | any(.category == \"dev-process\" and .pid == 600 and .locked == null)) and (.items | any(.category == \"heavy-process\" and .pid == 800)) and (.items | all(.pid != 900)) and (.items | any(.category == \"login-item\" and .name == \"com.example.updater\")) and (.items | any(.category == \"container\" and .name == \"shop-db-1\"))"'
check "a process under a live agent session or terminal is locked with a reason" \
  'has "(.items | any(.pid == 501 and (.locked | type) == \"string\" and (.locked | test(\"agent\")))) and (.items | any(.pid == 700 and (.locked | type) == \"string\" and (.locked | test(\"terminal\"))))"'
check "an app a live agent session runs in and a dev server in an agent's project are locked" \
  'has "(.items | any(.pid == 1000 and (.locked // \"\" | test(\"runs under it\")))) and (.items | any(.pid == 1001 and (.locked // \"\" | test(\"belongs to Host\")))) and (.items | any(.pid == 1002 and .name == \"codex\" and .locked == \"is a live agent session\")) and (.items | any(.pid == 1101 and .category == \"dev-process\" and (.locked // \"\" | test(\"project\"))))"'
check "a process is named after its app or its own file, even when the path has spaces" \
  'has "(.items | any(.pid == 1200 and .name == \"Codex\" and .locked == null)) and (.items | any(.pid == 1201 and .name == \"git\")) and (.items | any(.pid == 1202 and .name == \"Python\")) and (.items | any(.pid == 1001 and .name == \"Host\")) and (.items | any(.pid == 1000 and .detail.folder == null)) and (.items | any(.pid == 1101 and .detail.folder == \"$NOTES/web\" and (.detail.started | test(\"^2026-11-1[45]T\"))))"'
# level_is <jq filter for one item> <level> <reason code>: the item exists with that level and reason.
level_is() { has "[.items[] | select($1)] | length > 0 and all(.level == \"$2\" and .reason.code == \"$3\")"; }
check "scan ranks rebuilt caches, the Trash, old logs and installers, and leftover dev processes as recommended" \
  'level_is ".kind == \"npm\"" recommended rebuilt && level_is ".kind == \"docker-images\"" recommended rebuilt && level_is ".kind == \"app-cache\"" recommended rebuilt && level_is ".category == \"trash\"" recommended trash && level_is ".category == \"log\"" recommended old_logs && level_is ".category == \"installer\"" recommended old_installer && level_is ".pid == 600" recommended session_ended'
check "scan ranks large and duplicate files, unused apps, login items, and next-server as check first" \
  'level_is ".category == \"large\"" check own_file && level_is ".category == \"duplicate\"" check duplicate && level_is ".category == \"app\" and .kind == \"mac-app\"" check app_unused && has "[.items[] | select(.category == \"app\" and .kind == \"mac-app\")][0].reason.days >= 199" && level_is ".category == \"login-item\"" check login_item && level_is ".pid == 1300" check next_server'
check "scan ranks heavy processes and running containers as careful" \
  'level_is ".pid == 800" careful running_program && level_is ".category == \"container\"" careful container'
check "build output is recommended only when its project has had no commit for 30 days" \
  'level_is ".path == \"$ARCHIVE/node_modules\"" recommended build_idle && has "[.items[] | select(.path == \"$ARCHIVE/node_modules\")][0].reason.days >= 39" && level_is ".path == \"$SHOP/node_modules\"" check build_recent && has "[.items[] | select(.path == \"$SHOP/node_modules\")][0].reason.days <= 1"'
check "every scanned item has a level and a reason" \
  'has "(.items | length) > 20 and (.items | all((.level | IN(\"recommended\", \"check\", \"careful\")) and (.reason.code | type) == \"string\"))"'
check "build output in a folder a running process works in is locked" \
  'has ".items | any(.path == \"$BLOG/node_modules\" and (.locked | type) == \"string\")" && has ".items | any(.path == \"$SHOP/node_modules\" and .locked == null)"'

# --- one row for each path --------------------------------------------------------------------
check "scan lists each path in one row, an old large installer as an installer" \
  'has "[.items[] | select(.path == \"$H/Downloads/Big-2.0.dmg\")] | length == 1 and .[0].category == \"installer\" and .[0].level == \"recommended\"" && has "[.items[] | .path // empty] | length > 20 and length == (unique | length)"'
# copy_set_ok: the old installer and its copy in another folder carry the same set, which names both.
copy_set_ok() {
  jq -e --arg a "$H/Downloads/Tool-1.0.dmg" --arg b "$H/Archive/Tool-1.0.dmg" '
    [.items[] | select(.path == $a)] as $i | [.items[] | select(.path == $b)] as $d
    | ($i | length) == 1 and ($d | length) == 1 and $i[0].category == "installer" and $d[0].category == "duplicate"
    and ($i[0].detail.set | type) == "string" and $i[0].detail.set == $d[0].detail.set
    and ($i[0].detail.copies | sort) == ([$a, $b] | sort) and ($d[0].detail.copies | sort) == ([$a, $b] | sort)
    and ([.items[] | select(.detail.set == $i[0].detail.set)] | length) == 2' "$SCAN" > /dev/null 2>&1
}
check "a copy that another scan listed keeps its duplicate set" 'copy_set_ok'
# within_ok: the build output and the large file in idlebuild name the project's row, which itself,
# like build output in a project that is not listed, is inside no row. The app's cache and its old
# logs are support files of the unused Editor app, so they name the app's row.
within_ok() {
  jq -e --arg p "$IDLEB" --arg s "$SHOP/node_modules" --arg app "$APP" --arg lib "$H/Library" '
    def within_of(p): [.items[] | select(.path == p)][0].within;
    ([.items[] | select(.category == "project" and .path == $p)][0].id) as $pid
    | ([.items[] | select(.path == $app)][0].id) as $aid
    | ($pid | type) == "string" and ($aid | type) == "string"
    and within_of($p + "/node_modules") == [$pid] and within_of($p + "/data/dump.bin") == [$pid]
    and within_of($p) == [] and within_of($s) == []
    and within_of($lib + "/Caches/com.example.editor") == [$aid] and within_of($lib + "/Logs/Editor") == [$aid]
    and within_of($app) == []' "$SCAN" > /dev/null 2>&1
}
check "a row inside another listed row names the rows that hold it" 'within_ok'
# label_ok: the names the script makes carry a dictionary key and their values; names from the
# machine carry none; the English name stays as it was.
label_ok() {
  jq -e --arg shop "$SHOP/node_modules" --arg app "$APP" '
    def one(f): [.items[] | select(f)][0];
    one(.kind == "npm") as $npm | one(.kind == "docker-images") as $img | one(.path == $shop) as $nm
    | one(.category == "trash") as $trash | one(.category == "log" and (.path | endswith("/Logs/Editor"))) as $log
    | one(.pid == 600) as $vite | one(.path == $app) as $editor | one(.category == "tool") as $tool
    | $npm.label == {"key": "cache_npm"} and $npm.name == "npm cache"
    and $img.label == {"key": "cache_docker_images"} and $img.name == "Docker images no container uses"
    and $nm.label == {"key": "build", "vars": {"folder": "node_modules", "project": "shop"}} and $nm.name == "node_modules in shop"
    and $trash.label == {"key": "trash"} and $trash.name == "Trash"
    and $log.label == {"key": "app_logs", "vars": {"app": "Editor"}} and $log.name == "Editor logs"
    and $vite.label == {"key": "dev_vite"} and $vite.name == "Vite dev server"
    and $editor.label == null and $tool.label == null' "$SCAN" > /dev/null 2>&1
}
check "scan gives the names it makes a dictionary key and keeps the English name" 'label_ok'

mode() { "$PY" -c 'import os, sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$1" 2>/dev/null; }
check "scan state is readable only by the user" \
  '[ "$(mode "$T/state")" = 0o700 ] && [ "$(mode "$T/state/scan.json")" = 0o600 ]'
# The df stand-in prints 500000000 blocks of 1 KiB in all and 10000000 free.
check "scan records the whole disk size with the free space" \
  'jq -e ".measure.disk_total == 512000000000 and .measure.disk_free == 10240000000" "$SCAN" > /dev/null 2>&1'

# --- the four kinds of unused items ---------------------------------------------------------
# cat_at <category> <path>: the id of the row of that category at that path, or nothing.
cat_at() { jq -r --arg c "$1" --arg p "$2" '[.items[] | select(.category == $c and .path == $p)][0].id // empty' "$SCAN" 2>/dev/null; }
listed_project() { [ -n "$(cat_at project "$1")" ]; }
check "scan lists a git project idle for 30 days whose branches are all on the remote" \
  'has ".items | any(.category == \"project\" and .path == \"$IDLE\" and (.size | type) == \"number\" and (.detail.last_used | type) == \"string\")"'
no_project_listed() {
  local p
  for p in "$@"; do ! listed_project "$H/projects/$p" || { echo "  listed $p"; return 1; }; done
}
check "scan never lists a project with recent use, changes, or commits missing from the remote" \
  'listed_project "$IDLE" && no_project_listed recentco dirty untracked localonly shop archive'
check "scan never lists a repository that has another worktree, or a worktree itself" \
  'listed_project "$IDLE" && ! listed_project "$H/projects/withwt" && ! listed_project "$H/projects/withwt-feature"'
check "scan judges the remote from local records and never fetches" \
  'listed_project "$IDLE" && grep -q "^git " "$T/scan-calls.log" && ! grep -qE "^git (fetch|ls-remote|pull|remote update)" "$T/scan-calls.log"'

GONE_PLACES="[\"$GONE_AS\", \"$LIB/Caches/com.oldvendor.gone\", \"$LIB/Preferences/com.oldvendor.gone.plist\", \"$LIB/Saved Application State/com.oldvendor.gone.savedState\"]"
leftover_named() { has ".items | any(.category == \"app\" and .kind == \"leftover\" and .name == \"$1\")"; }
check "scan lists files a removed app left in the eight Library folders, one row per bundle id" \
  'has "[.items[] | select(.kind == \"leftover\" and .name == \"com.oldvendor.gone\")] | length == 1 and (.[0] | ([.path] + (.detail.support // []) | sort) == ($GONE_PLACES | sort) and (.detail.last_used | type) == \"string\")" && leftover_named com.gonevendor.app2'
no_leftover_named() {
  local n
  for n in "$@"; do ! leftover_named "$n" || { echo "  listed $n"; return 1; }; done
}
check "scan never lists a leftover that matches an installed app or process, changed recently, belongs to Apple, or has no bundle id name" \
  'leftover_named com.oldvendor.gone && no_leftover_named com.example.helper com.browserco.browser com.newvendor.tool com.apple.finder OldThing futari.preferences.test com.randomsdk.storage.ezeEu4UqtErfpKf9TpbuQ4UvWgqYL9Ik && ! has ".items | any(.kind == \"leftover\" and ((.path | test(\"com.example|OldThing|com.apple\")) or ((.detail.support // []) | any(test(\"com.example|OldThing|com.apple\")))))"'
check "scan lists no app leftovers on Linux" \
  'leftover_named com.oldvendor.gone && jq -e ".items | all(.kind != \"leftover\")" "$LINUX_SCAN" > /dev/null 2>&1'

tool_at() { cat_at tool "$1"; }
# Arrays, since the fnm folder on macOS has a space in its path.
UNUSED_TOOLS=("$H/.nvm/versions/node/v18.20.4" "$H/.pyenv/versions/3.9.18" "$FNM/node-versions/v16.20.2" "$H/.asdf/installs/nodejs/18.19.0" "$MISE/node/21.7.3" "$H/.rustup/toolchains/1.70.0-aarch64-apple-darwin")
NAMED_TOOLS=("$H/.nvm/versions/node/v20.11.1" "$H/.nvm/versions/node/v22.1.0" "$H/.pyenv/versions/3.12.1" "$H/.pyenv/versions/3.11.7" "$H/.rbenv/versions/3.3.0" "$FNM/node-versions/v20.11.1" "$H/.asdf/installs/nodejs/20.11.1" "$MISE/node/24.22.1" "$MISE/node/26.12.1" "$MISE/npm-pen-dev-cli/0.3.12" "$H/.rustup/toolchains/stable-aarch64-apple-darwin" "$H/.rustup/toolchains/nightly-2024-01-01-aarch64-apple-darwin")
unused_tools_listed() {
  local p
  for p in "${UNUSED_TOOLS[@]}"; do
    has ".items | any(.category == \"tool\" and .path == \"$p\" and .locked == null and (.detail.tool | type) == \"string\" and (.detail.version | type) == \"string\" and (.size | type) == \"number\")" || { echo "  not listed $p"; return 1; }
  done
}
check "scan lists tool versions that are neither the default nor named by a project" 'unused_tools_listed'
no_named_tool_listed() {
  local p
  for p in "${NAMED_TOOLS[@]}"; do [ -z "$(tool_at "$p")" ] || { echo "  listed $p"; return 1; }; done
}
check "scan never lists a default version or one a project names, even by prefix or alias" \
  'unused_tools_listed > /dev/null && no_named_tool_listed'
check "a tool version a running program uses is locked" \
  'has ".items | any(.category == \"tool\" and .path == \"$H/.rbenv/versions/3.1.4\" and (.locked // \"\" | test(\"running program\")))"'

model_at() { cat_at model "$1"; }
models_listed() {
  local p
  for p in "$OLLAMA_LATEST" "$OLLAMA_Q4" "$HF_TINY" "$HF_OTHER" "$LMS" "$LMS_OLD"; do
    has ".items | any(.category == \"model\" and .path == \"$p\" and (.size | type) == \"number\" and (.detail.downloaded | type) == \"string\")" || { echo "  not listed $p"; return 1; }
  done
}
check "scan lists Ollama, Hugging Face, and LM Studio models with size and download date" \
  'models_listed && has ".items | any(.path == \"$OLLAMA_LATEST\" and .name == \"llama3:latest\")"'
check "an Ollama model's size counts only the blobs no other model uses" \
  'has ".items | any(.path == \"$OLLAMA_LATEST\" and .size == 310) and any(.path == \"$OLLAMA_Q4\" and .size == 220)"'
check "scan never lists model folders under the cache folder as rebuilt caches" \
  'jq -e "(.items | any(.category == \"model\" and .path == \"$HF_TINY\")) and (.items | all(.kind != \"app-cache\" or ((.path | endswith(\"/huggingface\")) or (.path | endswith(\"/lm-studio\")) | not)))" "$LINUX_SCAN" > /dev/null 2>&1'
check "scan ranks projects, app leftovers, tool versions, and models as check first" \
  'level_is ".category == \"project\"" check project_idle && level_is ".kind == \"leftover\"" check leftover && level_is ".category == \"tool\" and .locked == null" check tool_unused && level_is ".category == \"model\"" check model'
check "tool versions are locked when the default is unknown or the scan did not read every project" \
  'has ".items | any(.category == \"tool\" and .path == \"$MISE/python/3.10.13\" and (.locked // \"\" | test(\"default\")))" && jq -e "[.items[] | select(.category == \"tool\")] | length > 0 and all(.locked // \"\" | test(\"every project\"))" "$T/state-limit/scan.json" > /dev/null 2>&1'
check "the new kinds stop at the time limit" \
  'jq -e "(.items | all(.category != \"project\" and .category != \"model\" and .kind != \"leftover\")) and (.skipped | any(.reason == \"time limit\" and (.path | test(\"ollama|huggingface|lmstudio|lm-studio\"))))" "$T/state-limit/scan.json" > /dev/null 2>&1 && listed_project "$IDLE"'

# --- the page -------------------------------------------------------------------------------
sheet_ok() {
  "$PY" - "$SHEET" <<'PY'
import json, re, sys
html = open(sys.argv[1], encoding="utf-8").read()
assert '<html lang="en">' in html, "page does not open in English"
m = re.search(r'<script id="i18n" type="application/json">(.*?)</script>', html, re.S)
assert m, "no i18n dictionary"
d = json.loads(m.group(1))
assert set(d) == {"en", "ja"}, "dictionary languages"
assert set(d["en"]) == set(d["ja"]), "en and ja keys differ"
keys = set(re.findall(r'data-i18n(?:-[a-z]+)?="([A-Za-z0-9_]+)"', html)) | set(re.findall(r'\bt\("([A-Za-z0-9_]+)"', html))
missing = keys - set(d["en"])
assert not missing, "keys not in the dictionary: %s" % sorted(missing)
assert re.search(r'id="lang"[^>]*>', html) and 'data-lang="ja"' in html and 'data-lang="en"' in html, "no language switch"
PY
}
check "the sheet opens in English and switches to Japanese from one dictionary" 'sheet_ok'

# confirm_texts: runs the page's own t, human, and sumText in Node.js and prints the confirm dialog's
# lines for 4 disk items of 807.4 MB and for 1 process, in English and then Japanese.
confirm_texts() {
  "$PY" - "$SHEET" <<'PY' | "$NODE" -
import re, sys
html = open(sys.argv[1], encoding="utf-8").read()
words = re.search(r'<script id="i18n" type="application/json">(.*?)</script>', html, re.S).group(1)
code = "".join(re.search(r"^function %s\(.*?^}\n" % name, html, re.S | re.M).group(0) for name in ("t", "human", "sumText"))
print("const I18N = %s;\nlet lang;\n%s" % (words, code))
print('for (const l of ["en", "ja"]) { lang = l; console.log(sumText(4, 807400000, true)); console.log(sumText(1, 0, false)); }')
PY
}
if [ -n "$NODE" ]; then
  check "the confirm dialog shows each count apart from its size" \
    '[ "$(confirm_texts 2>&1 | tr "\n" "|")" = "4 items, 807.4 MB|1 item|4件、807.4 MB|1件|" ]'
else
  printf 'skip  %s (node is not installed)\n' "the confirm dialog shows each count apart from its size"
fi

# page_run <function names> <code>: runs the page's own functions with those names, its dictionary,
# and a small stand-in for the DOM in Node.js, then the given code.
page_run() {
  "$PY" - "$SHEET" "$1" "$2" <<'PY' | "$NODE" -
import re, sys
html = open(sys.argv[1], encoding="utf-8").read()
words = re.search(r'<script id="i18n" type="application/json">(.*?)</script>', html, re.S).group(1)
code = []
for name in sys.argv[2].split():
    m = re.search(r"^function %s\(.*?^}\n" % re.escape(name), html, re.S | re.M)
    if not m:
        print('console.log("the page has no function %s");' % name)
        sys.exit(0)
    code.append(m.group(0))
dom = """function El(tag) { this.tagName = tag.toUpperCase(); this.children = []; this.className = ""; this.textContent = ""; }
El.prototype.appendChild = function (c) { this.children.push(c); return c; };
El.prototype.setAttribute = function () {};
El.prototype.addEventListener = function () {};
El.prototype.all = function () { return this.children.reduce(function (a, c) { return a.concat([c], c.all()); }, []); };
const document = { createElement: function (tag) { return new El(tag); } };
function buttons(el) { return el.all().filter(function (e) { return e.tagName === "BUTTON"; }).length; }
"""
print("const I18N = %s;\nlet lang = \"en\";\n%s%s%s" % (words, dom, "".join(code), sys.argv[3]))
PY
}
GROUP_FNS="t human sumText groupRows groupHeadText groupHead whyText"
GROUPS_JS='lang = "ja";
const g = groupRows([
  { id: "a", group: "disk", level: "recommended", size: 300, locked: null },
  { id: "b", group: "disk", level: "careful", size: 900, locked: null },
  { id: "c", group: "disk", level: "recommended", size: 500, locked: null },
  { id: "d", group: "disk", level: "check", size: 100, locked: null },
  { id: "e", group: "disk", level: "recommended", size: 999, locked: "in use" }]);
console.log(g.map(function (x) { return x.key + ":" + x.items.map(function (i) { return i.id; }).join("") + ":" + groupHeadText(x); }).join("|"));'
PICK_JS='function one(level, locked) { return groupRows([{ id: "x", group: "disk", level: level, size: 1, locked: locked }])[0]; }
console.log(["recommended", "check", "careful"].map(function (l) { return l + "=" + buttons(groupHead(one(l, null))); }).join(" ") + " inuse=" + buttons(groupHead(one("recommended", "busy"))));'
WHY_CODES="$(jq -r '[.items[].reason.code // empty] | unique | join(" ")' "$SCAN" 2>/dev/null)"
WHY_JS="const codes = \"$WHY_CODES\".split(\" \").filter(Boolean);
const bad = [];
codes.forEach(function (c) {
  const it = { reason: { code: c, days: 42 } };
  lang = \"en\"; const en = whyText(it);
  lang = \"ja\"; const ja = whyText(it);
  if (!en || !ja || en === ja || /why_|[{}]/.test(en + ja)) bad.push(c);
});
lang = \"en\"; const enIdle = whyText({ reason: { code: \"build_idle\", days: 42 } });
lang = \"ja\"; const jaIdle = whyText({ reason: { code: \"build_idle\", days: 42 } });
console.log(codes.length + \" codes, bad: \" + bad.join(\",\") + \"|\" + enIdle + \"|\" + jaIdle);"
if [ -n "$NODE" ]; then
  check "the page groups rows by level with counts and totals, and in-use rows last" \
    '[ "$(page_run "$GROUP_FNS" "$GROUPS_JS" 2>&1)" = "recommended:ca:2件、800 B|check:d:1件、100 B|careful:b:1件、900 B|inuse:e:1件、999 B" ]'
  check "only the recommended and check-first groups can be picked all at once" \
    '[ "$(page_run "$GROUP_FNS" "$PICK_JS" 2>&1)" = "recommended=1 check=1 careful=0 inuse=0" ]'
  check "the page has no way to pick careful or in-use rows all at once" \
    '! grep -q "id=\"pick-all\"" "$SHEET" && [ "$(page_run "$GROUP_FNS" "$PICK_JS" 2>&1 | grep -o "careful=[0-9]* inuse=[0-9]*")" = "careful=0 inuse=0" ]'
  check "the page shows each row's reason from the English and Japanese dictionaries" \
    'out="$(page_run "$GROUP_FNS" "$WHY_JS" 2>&1)"; case "$out" in [1-9][0-9]" codes, bad: |The project has had no commit for 42 days. The next install or build makes it again|プロジェクトは42日commitされていません。次のインストールかビルドで作り直されます") true;; *) echo "  $out"; false;; esac'
else
  for name in "the page groups rows by level with counts and totals, and in-use rows last" \
    "only the recommended and check-first groups can be picked all at once" \
    "the page has no way to pick careful or in-use rows all at once" \
    "the page shows each row's reason from the English and Japanese dictionaries"; do
    printf 'skip  %s (node is not installed)\n' "$name"
  done
fi

# page_eval <names> <code>: like page_run, and a name in capitals takes the page's `const NAME = ...;`
# statement instead of a function. texts(el) lists the text of every element without children.
page_eval() {
  "$PY" - "$SHEET" "$1" "$2" <<'PY' | "$NODE" -
import re, sys
html = open(sys.argv[1], encoding="utf-8").read()
words = re.search(r'<script id="i18n" type="application/json">(.*?)</script>', html, re.S).group(1)
code = []
for name in sys.argv[2].split():
    pattern = r"^const %s = .*?;\n" if name.isupper() else r"^function %s\(.*?^}\n"
    m = re.search(pattern % re.escape(name), html, re.S | re.M)
    if not m:
        print('console.log("the page has no %s");' % name)
        sys.exit(0)
    code.append(m.group(0))
dom = """function El(tag) { this.tagName = tag.toUpperCase(); this.children = []; this.className = ""; this.textContent = ""; }
El.prototype.appendChild = function (c) { this.children.push(c); return c; };
El.prototype.setAttribute = function () {};
El.prototype.addEventListener = function () {};
El.prototype.all = function () { return this.children.reduce(function (a, c) { return a.concat([c], c.all()); }, []); };
const document = { createElement: function (tag) { return new El(tag); } };
function buttons(el) { return el.all().filter(function (e) { return e.tagName === "BUTTON"; }).length; }
function texts(el) { return el.all().filter(function (e) { return !e.children.length && e.textContent !== ""; }).map(function (e) { return String(e.textContent); }); }
const DATA = { home: "/h" };
const picked = new Set();
"""
print("const I18N = %s;\nlet lang = \"en\";\n%s%s%s" % (words, dom, "".join(code), sys.argv[3]))
PY
}
ROW_FNS="t human tilde when day effect lockText whyText isProc levelOf nameOf setLines rowEl detailPairs detailEl"
ROW_JS='const disk = { id: "d1", group: "disk", category: "build", name: "node_modules in app", path: "/h/projects/app/node_modules",
  size: 1000000, level: "recommended", reason: { code: "build_idle", days: 42 }, rebuilt: true, locked: null };
const proc = { id: "p1", group: "process", category: "dev-process", name: "Vite dev server", size: 52000000, cpu: 12,
  level: "recommended", reason: { code: "session_ended" }, locked: null,
  detail: { command: "node vite --port 5173", folder: "/h/projects/app", started: "2026-11-15T01:02:00Z" } };
const busy = Object.assign({}, proc, { id: "p2", locked: "runs under a live agent session (codex, pid 9)" });
function show(it) { return detailPairs(it).map(function (p) { return /^(d_reason|d_effect|d_started)$/.test(p[0]) ? p[0] : p[0] + "=" + p[1]; }).join(","); }
const reason = detailPairs(disk)[0][1];
console.log(texts(rowEl(disk.name, "", disk)).join("|") + "#" + texts(rowEl(proc.name, "", proc)).join("|"));
console.log(show(disk) + "#" + show(proc) + "#" + (reason && reason.indexOf("42") >= 0 ? "reason" : "no reason"));
console.log("free=" + buttons(detailEl(disk)) + " busy=" + buttons(detailEl(busy)));'
CHART_FNS="TABS t human isProc levelOf shares freeableSize unionSize partText overviewCharts"
CHART_JS='const items = [
  { id: "c1", group: "disk", category: "cache", size: 300, level: "recommended", locked: null, rebuilt: true },
  { id: "c2", group: "disk", category: "cache", size: 200, level: "recommended", locked: "npm is running", rebuilt: true },
  { id: "b1", group: "disk", category: "build", size: 100, level: "check", locked: null, rebuilt: true },
  { id: "t1", group: "disk", category: "trash", size: 50, level: "recommended", locked: null },
  { id: "l1", group: "disk", category: "log", size: 20, level: "recommended", locked: null },
  { id: "f1", group: "disk", category: "large", size: 400, level: "check", locked: null },
  { id: "u1", group: "disk", category: "duplicate", size: 60, level: "check", locked: null, detail: { set: "s1" } },
  { id: "u2", group: "disk", category: "duplicate", size: 60, level: "check", locked: null, detail: { set: "s1" } },
  { id: "a1", group: "disk", category: "app", size: 70, level: "check", locked: null },
  { id: "p1", group: "process", category: "dev-process", size: 1000, cpu: 5, level: "recommended", locked: null },
  { id: "p2", group: "process", category: "heavy-process", size: 3000, cpu: 80, level: "careful", locked: null },
  { id: "p3", group: "process", category: "heavy-process", size: 2000, cpu: 90, level: "careful", locked: "runs under a live agent session (codex, pid 1)" },
  { id: "p4", group: "process", category: "dev-process", size: 400, cpu: 1, level: "recommended", locked: null },
  { id: "p5", group: "process", category: "heavy-process", size: 300, cpu: 2, level: "careful", locked: null },
  { id: "p6", group: "process", category: "heavy-process", size: 200, cpu: 3, level: "careful", locked: null },
  { id: "p7", group: "process", category: "heavy-process", size: 100, cpu: 4, level: "careful", locked: null },
  { id: "k1", group: "process", category: "container", size: 5000, cpu: 1, level: "careful", locked: null },
  { id: "g1", group: "process", category: "login-item", size: 0, level: "check", locked: null }];
function line(c) {
  if (c.kind === "bars") return c.key + ":" + c.bars.map(function (b) { return b.item.id; }).join(",");
  return c.key + ":" + c.parts.map(function (p) { return p.key + "=" + p.value + (p.tab ? "@" + p.tab : ""); }).join(",") +
    ";center=" + c.center.value + (c.foot ? ";foot=" + c.foot.value : "");
}
const charts = overviewCharts(items, { disk_free: 10000, disk_total: 50000, memory_used: 20000, memory_total: 32000, load: [1.5, 1, 1] }, new Set(["b1", "f1"]));
charts.forEach(function (c) { console.log(line(c)); });
const unknown = overviewCharts(items, { disk_free: 10000, memory_used: 20000, memory_total: 32000 }, new Set());
const other = unknown[2].parts.filter(function (p) { return p.key === "other"; })[0];
console.log("unknown:" + other.value + ":" + partText(other.value) + ":" + unknown[2].unknown);
const keys = [];
charts.forEach(function (c) {
  keys.push(c.title, c.center ? c.center.label : c.title, c.foot ? c.foot.label : c.title);
  (c.parts || []).forEach(function (p) { keys.push(p.label); });
});
const missing = keys.filter(function (k) { return !k || !I18N.en[k] || !I18N.ja[k]; });
console.log("keys:" + keys.length + ":missing=" + missing.join(","));'
chart_line() { printf '%s\n' "$CHART_OUT" | grep "^$1:" | head -1; }
# The freeable chart with a row of each new kind, one tool version in use.
FREE_JS='const items = [
  { id: "c1", group: "disk", category: "cache", size: 300, level: "recommended", locked: null, rebuilt: true },
  { id: "c2", group: "disk", category: "cache", size: 200, level: "recommended", locked: "npm is running", rebuilt: true },
  { id: "b1", group: "disk", category: "build", size: 100, level: "check", locked: null, rebuilt: true },
  { id: "t1", group: "disk", category: "trash", size: 50, level: "recommended", locked: null },
  { id: "l1", group: "disk", category: "log", size: 20, level: "recommended", locked: null },
  { id: "f1", group: "disk", category: "large", size: 400, level: "check", locked: null },
  { id: "u1", group: "disk", category: "duplicate", size: 60, level: "check", locked: null, detail: { set: "s1" } },
  { id: "u2", group: "disk", category: "duplicate", size: 60, level: "check", locked: null, detail: { set: "s1" } },
  { id: "j1", group: "disk", category: "project", size: 80, level: "check", locked: null },
  { id: "a1", group: "disk", category: "app", size: 70, level: "check", locked: null },
  { id: "a2", group: "disk", category: "app", kind: "leftover", size: 5, level: "check", locked: null },
  { id: "v1", group: "disk", category: "tool", size: 30, level: "check", locked: null },
  { id: "v2", group: "disk", category: "tool", size: 99, level: "check", locked: "a running program uses this version" },
  { id: "m1", group: "disk", category: "model", size: 25, level: "check", locked: null }];
const c = overviewCharts(items, { disk_free: 10000, disk_total: 50000, memory_used: 20000, memory_total: 32000, load: [1, 1, 1] }, new Set())[0];
console.log(c.key + ":" + c.parts.map(function (p) { return p.key + "=" + p.value + (p.tab ? "@" + p.tab : ""); }).join(",") + ";center=" + c.center.value + ";foot=" + c.foot.value);'
TAB_JS='const want = { project: 1, app: 1, tools: 1 };
const got = TABS.filter(function (x) { return want[x[0]]; }).map(function (x) { return x[0] + "=" + x[1].join("+"); }).join(" ");
const keys = ["tab_project", "tab_tools", "lead_project", "lead_tools", "why_project_idle", "why_leftover", "why_tool_unused", "why_model"];
const missing = keys.filter(function (k) { return !I18N.en[k] || !I18N.ja[k] || I18N.en[k] === I18N.ja[k]; });
console.log(got + "|" + I18N.ja.tab_project + "|" + I18N.ja.tab_tools + "|missing=" + missing.join(","));'
NEW_ROW_JS='const rows = [
  { id: "j1", group: "disk", category: "project", kind: "git-project", name: "old", path: "/h/projects/old", size: 1000000, level: "check",
    reason: { code: "project_idle", days: 45 }, action: "trash", locked: null, detail: { last_used: "2026-10-01T00:00:00Z" } },
  { id: "l1", group: "disk", category: "app", kind: "leftover", name: "com.gone.app", path: "/h/Library/Application Support/com.gone.app", size: 2000000,
    level: "check", reason: { code: "leftover", days: 60 }, action: "trash-app", locked: null,
    detail: { support: ["/h/Library/Preferences/com.gone.app.plist"], last_used: "2026-09-15T00:00:00Z" } },
  { id: "v1", group: "disk", category: "tool", kind: "tool-version", name: "node 18.20.4 (nvm)", path: "/h/.nvm/versions/node/v18.20.4", size: 3000000,
    level: "check", reason: { code: "tool_unused" }, action: "delete", locked: null, detail: { manager: "nvm", tool: "node", version: "18.20.4" } },
  { id: "m1", group: "disk", category: "model", kind: "hf-model", name: "acme/tiny", path: "/h/.cache/huggingface/hub/models--acme--tiny", size: 4000000,
    level: "check", reason: { code: "model" }, action: "delete", locked: null, detail: { downloaded: "2026-08-01T00:00:00Z" } }];
console.log(rows.map(function (it) {
  return detailPairs(it).map(function (p) { return /^(d_reason|d_effect)$/.test(p[0]) ? p[0] : p[0] + "=" + String(p[1]).split("\n").join(";"); }).join(",");
}).join("#"));'
LIST_FNS="t nameOf groupRows viewGroups"
LIST_JS='const list = [
  { id: "a", name: "Alpha cache", path: "/h/.cache/alpha", size: 300, level: "recommended", locked: null, group: "disk" },
  { id: "b", name: "beta", path: "/h/Archive/beta", size: 100, level: "recommended", locked: null, group: "disk" },
  { id: "c", name: "Gamma", path: "/h/x", size: 200, level: "recommended", locked: null, group: "disk" },
  { id: "g", name: "golf", path: "/h/g", size: 150, level: "check", locked: null, group: "disk" },
  { id: "d", name: "delta", path: "/h/archive/d", size: 50, level: "careful", locked: null, group: "disk" },
  { id: "e", name: "Epsilon", path: "/h/e", size: 999, level: "recommended", locked: "in use", group: "disk" }];
const all = ["recommended", "check", "careful", "inuse"];
function ids(gs) { return gs.map(function (g) { return g.key + ":" + g.items.map(function (i) { return i.id; }).join(""); }).join("|"); }
console.log("path=" + ids(viewGroups(list, { query: "ARCHIVE", levels: all, sort: "size-desc" })) + " name=" + ids(viewGroups(list, { query: "gam", levels: all, sort: "size-desc" })));
console.log("levels=" + ids(viewGroups(list, { query: "", levels: ["check", "inuse"], sort: "size-desc" })));
console.log("desc=" + ids(viewGroups(list, { query: "", levels: all, sort: "size-desc" })) + " asc=" + ids(viewGroups(list, { query: "", levels: all, sort: "size-asc" })) + " name=" + ids(viewGroups(list, { query: "", levels: all, sort: "name" })));'
# Every row of the scan: a row with a dictionary key reads the same as its English name in English and
# differently in Japanese, and a row without one reads the same in both.
SCAN_ITEMS="$(jq -c '.items' "$SCAN" 2>/dev/null || printf '[]')"
NAME_FNS="t nameOf"
NAME_JS="const items = $SCAN_ITEMS;
const bad = [];
let keyed = 0;
items.forEach(function (it) {
  lang = \"en\"; const en = nameOf(it);
  lang = \"ja\"; const ja = nameOf(it);
  if (it.label) {
    keyed += 1;
    const k = \"name_\" + it.label.key;
    if (!I18N.en[k] || !I18N.ja[k]) bad.push(\"no \" + k);
    else if (en !== it.name) bad.push(en + \" is not \" + it.name);
    else if (ja === en || /[{}]/.test(ja)) bad.push(\"ja \" + ja);
  } else if (en !== it.name || ja !== it.name) bad.push(\"changed \" + it.name);
});
console.log((keyed >= 20 ? \"keyed\" : \"keyed \" + keyed) + \", bad: \" + bad.join(\",\"));"
# An old installer and its copy in another tab, a project with build output and a large file inside
# it, and a cache. The freeable chart counts one copy and the project once; the bar counts the union.
TOTAL_FNS="TABS t human isProc levelOf shares freeableSize unionSize partText overviewCharts tallyParts"
TOTAL_JS='const copies = ["/h/Archive/a.dmg", "/h/Downloads/a.dmg"];
const items = [
  { id: "c1", group: "disk", category: "cache", path: "/h/.npm", size: 200, level: "recommended", locked: null, rebuilt: true, within: [] },
  { id: "i1", group: "disk", category: "installer", path: "/h/Downloads/a.dmg", size: 500, level: "recommended", locked: null, within: [], detail: { set: "s1", copies: copies } },
  { id: "d1", group: "disk", category: "duplicate", path: "/h/Archive/a.dmg", size: 500, level: "check", locked: null, within: [], detail: { set: "s1", copies: copies } },
  { id: "p1", group: "disk", category: "project", path: "/h/p", size: 1000, level: "check", locked: null, within: [] },
  { id: "b1", group: "disk", category: "build", path: "/h/p/node_modules", size: 300, level: "recommended", locked: null, rebuilt: true, within: ["p1"] },
  { id: "f1", group: "disk", category: "large", path: "/h/p/data.bin", size: 600, level: "check", locked: null, within: ["p1"] }];
const c = overviewCharts(items, { disk_free: 10000, disk_total: 50000, memory_used: 20000, memory_total: 32000, load: [1, 1, 1] }, new Set(["p1", "b1"]));
function parts(x) { return x.parts.map(function (p) { return p.key + "=" + p.value; }).join(",") + ";center=" + x.center.value; }
console.log(parts(c[0]) + "#" + parts(c[1]) + "#" + parts(c[2]));
function bar(ids) { return tallyParts(items.filter(function (x) { return ids.indexOf(x.id) >= 0; })).map(function (p) { return p.value; }).join("|"); }
console.log(bar(["p1", "b1"]) + "#" + bar(["b1", "f1"]) + "#" + bar(["i1"]));'
TALLY_JS='const its = [{ id: "a", group: "disk", size: 1000, within: [] }, { id: "b", group: "process", size: 5 }];
function show(list) { return tallyParts(list).map(function (p) { return p.label + "|" + p.value; }).join("|"); }
lang = "en"; const en = show(its); const none = tallyParts([]);
lang = "ja"; const ja = show(its);
console.log(en + "#" + ja + "#" + none.length + "#" + (/[:：・]/.test(en + ja) ? "joined" : "apart"));'
# Two copies of one file, a large file, two dev servers with one name, an app, a cache, and a container.
WHERE_FNS="t human tilde nameOf whereFor setLines rowEl"
WHERE_JS='const files = [
  { id: "u1", group: "disk", category: "duplicate", name: "archive.zip", path: "/h/Backup/archive.zip", size: 1, within: [], detail: { set: "s", copies: [] } },
  { id: "u2", group: "disk", category: "duplicate", name: "archive.zip", path: "/h/Documents/archive.zip", size: 1, within: [], detail: { set: "s", copies: [] } },
  { id: "f1", group: "disk", category: "large", name: "raw.mov", path: "/h/Videos/raw.mov", size: 1, within: [] }];
const procs = [
  { id: "p1", group: "process", category: "dev-process", name: "Vite dev server", label: { key: "dev_vite" }, size: 1, cpu: 0, detail: { folder: "/h/projects/app", command: "node vite" } },
  { id: "p2", group: "process", category: "dev-process", name: "Vite dev server", label: { key: "dev_vite" }, size: 1, cpu: 0, detail: { folder: null, command: "node /h/work/b/node_modules/.bin/vite --port 5174" } },
  { id: "p3", group: "process", category: "heavy-process", name: "Browser", size: 1, cpu: 0, detail: { folder: null, command: "/Applications/Browser.app/Contents/MacOS/Browser" } }];
console.log([whereFor(files[0], files), whereFor(files[2], files), whereFor(procs[0], procs), whereFor(procs[1], procs)].join("|"));
console.log(texts(rowEl(files[0].name, whereFor(files[0], files), files[0])).join("|"));'
NO_WHERE_JS='const procs = [
  { id: "p1", group: "process", category: "dev-process", name: "Vite dev server", label: { key: "dev_vite" }, size: 1, cpu: 0, detail: { folder: "/h/projects/app", command: "node vite" } },
  { id: "p3", group: "process", category: "heavy-process", name: "Browser", size: 1, cpu: 0, detail: { folder: null, command: "/Applications/Browser.app/Contents/MacOS/Browser" } }];
const others = [
  { id: "c1", group: "disk", category: "cache", name: "npm cache", label: { key: "cache_npm" }, path: "/h/.npm/_cacache", size: 1, within: [] },
  { id: "a1", group: "disk", category: "app", name: "Editor", path: "/h/Applications/Editor.app", size: 1, within: [] },
  { id: "k1", group: "process", category: "container", name: "shop-db-1", size: 1, cpu: 0, detail: { image: "postgres:16" } }];
console.log("[" + [whereFor(procs[0], procs), whereFor(procs[1], procs), whereFor(others[0], others), whereFor(others[1], others), whereFor(others[2], others)].join("|") + "]");
console.log(texts(rowEl(others[0].name, whereFor(others[0], others), others[0])).length);'
# Two bars of one name among the top processes, and a bar whose name is its own. The stand-in elements
# get a style to write the bar's width into.
BAR_FNS="t human tilde nameOf whereFor setLines node card pressable levelOf COLORS barCard"
BAR_JS='Object.defineProperty(El.prototype, "style", { get: function () { return this.css || (this.css = {}); } });
function vite(id, folder) { return { id: id, group: "process", category: "dev-process", name: "Vite dev server", label: { key: "dev_vite" }, size: 1, cpu: 1, level: "recommended", locked: null, detail: { folder: folder, command: "node vite" } }; }
const browser = { id: "p3", group: "process", category: "heavy-process", name: "Browser", size: 1, cpu: 1, level: "careful", locked: null, detail: { folder: "/h", command: "/Applications/Browser.app/Contents/MacOS/Browser" } };
const box = barCard({ key: "cpuTop", title: "ch_cpuTop", bars: [{ item: vite("p1", "/h/projects/shop"), value: 5 }, { item: vite("p2", "/h/projects/blog"), value: 3 }, { item: browser, value: 2 }] });
console.log(texts(box).slice(1).join("|"));'
# A set of two copies whose names sort apart, among two large files.
SET_FNS="t human nameOf groupRows viewGroups withSets setHeadText"
SET_JS='const copies = ["/h/Backup/archive.zip", "/h/Documents/copy of archive.zip"];
const list = [
  { id: "a", name: "archive.zip", path: copies[0], size: 500, level: "check", locked: null, group: "disk", category: "duplicate", detail: { set: "s1", copies: copies } },
  { id: "b", name: "beta.mov", path: "/h/Videos/beta.mov", size: 600, level: "check", locked: null, group: "disk", category: "large" },
  { id: "c", name: "copy of archive.zip", path: copies[1], size: 500, level: "check", locked: null, group: "disk", category: "duplicate", detail: { set: "s1", copies: copies } },
  { id: "d", name: "delta.iso", path: "/h/d.iso", size: 550, level: "check", locked: null, group: "disk", category: "large" }];
const all = ["recommended", "check", "careful", "inuse"];
function show(items) { return withSets(items).map(function (e) { return e.head ? "head:" + e.head.count + ":" + e.head.size : e.item.id; }).join(","); }
function first(v) { return viewGroups(list, v)[0].items; }
console.log(show(first({ query: "", levels: all, sort: "name" })) + "#" + show(first({ query: "", levels: all, sort: "size-desc" })) + "#" + show(first({ query: "copy", levels: all, sort: "size-desc" })));
lang = "en"; const en = setHeadText({ count: 2, size: 500 });
lang = "ja"; const ja = setHeadText({ count: 2, size: 500 });
console.log(en + "|" + ja);'
if [ -n "$NODE" ]; then
  ROW_OUT="$(page_eval "$ROW_FNS" "$ROW_JS" 2>&1)"
  CHART_OUT="$(page_eval "$CHART_FNS" "$CHART_JS" 2>&1)"
  LIST_OUT="$(page_eval "$LIST_FNS" "$LIST_JS" 2>&1)"
  check "a list row shows only the name, the size, the CPU of a process, and a details button" \
    '[ "$(printf "%s\n" "$ROW_OUT" | sed -n 1p)" = "node_modules in app|1.0 MB|i#Vite dev server|CPU 12%|52.0 MB|i" ] || { echo "  $ROW_OUT"; false; }'
  check "a list row shows no path, command, or reason" \
    'r="$(printf "%s\n" "$ROW_OUT" | sed -n 1p)"; [ -n "$r" ] && case "$r" in *projects*|*5173*|*commit*|*"has no"*) false;; *) true;; esac'
  check "the details dialog shows the reason, the effect, and the path or the process details" \
    '[ "$(printf "%s\n" "$ROW_OUT" | sed -n 2p)" = "d_reason,d_effect,d_size=1.0 MB,d_path=~/projects/app/node_modules#d_reason,d_effect,d_memory=52.0 MB,d_cpu=12%,d_started,d_folder=~/projects/app,d_command=node vite --port 5173#reason" ] || { echo "  $ROW_OUT"; false; }'
  check "the details dialog has a pick button for a row that can be picked" \
    'printf "%s\n" "$ROW_OUT" | grep -qx "free=1 busy=[0-9]*"'
  check "the details dialog has no pick button for a row in use" \
    'printf "%s\n" "$ROW_OUT" | grep -qx "free=[0-9]* busy=0"'
  check "the page opens on the overview tab, placed first" \
    'grep -qx "let tab = \"overview\";" "$SHEET" && [ "$(page_eval "TABS" "console.log(TABS[0][0] + \"/\" + TABS[0][1].length);" 2>&1)" = "overview/0" ]'
  check "the overview has the seven charts in order" \
    '[ "$(printf "%s\n" "$CHART_OUT" | sed -n "1,7p" | cut -d: -f1 | tr "\n" " ")" = "freeable levels disk memory largest memoryTop cpuTop " ] || { echo "  $CHART_OUT"; false; }'
  check "the freeable chart sums each kind without rows in use and links each part to its tab" \
    'out="$(page_eval "$CHART_FNS" "$FREE_JS" 2>&1)"; [ "$out" = "freeable:cache=300@cache,build=100@build,trash=70@trash,files=460@files,project=80@project,app=75@app,tools=55@tools;center=1140;foot=400" ] || { echo "  $out"; false; }'
  check "the page puts projects, leftovers, and tool versions with models in their tabs, named from both dictionaries" \
    'out="$(page_eval "TABS" "$TAB_JS" 2>&1)"; [ "$out" = "project=project app=app tools=tool+model|プロジェクト|道具とモデル|missing=" ] || { echo "  $out"; false; }'
  check "the details dialog shows each new kind's dates and places" \
    'out="$(page_eval "$ROW_FNS" "$NEW_ROW_JS" 2>&1)"; [ "$out" = "d_reason,d_effect,d_size=1.0 MB,d_path=~/projects/old,d_lastTouched=2026-10-01#d_reason,d_effect,d_size=2.0 MB,d_places=~/Library/Application Support/com.gone.app;~/Library/Preferences/com.gone.app.plist,d_newest=2026-09-15#d_reason,d_effect,d_size=3.0 MB,d_path=~/.nvm/versions/node/v18.20.4,d_tool=node 18.20.4 (nvm)#d_reason,d_effect,d_size=4.0 MB,d_path=~/.cache/huggingface/hub/models--acme--tiny,d_downloaded=2026-08-01" ] || { echo "  $out"; false; }'
  check "the level chart sums disk rows by level and rows in use apart" \
    '[ "$(chart_line levels)" = "levels:recommended=370,check=630,careful=0,inuse=200;center=370;foot=10370" ]'
  check "the disk chart splits picked, freeable, other, and free space and shows the free space after freeing the picked rows" \
    '[ "$(chart_line disk)" = "disk:picked=500,freeable=500,other=39000,free=10000;center=10000;foot=10500" ]'
  check "the disk chart says the whole size is unknown instead of drawing zero" \
    '[ "$(chart_line unknown)" = "unknown:null:Not measured:true" ]'
  check "the memory chart splits processes that can end, processes in use, other use, and free memory" \
    '[ "$(chart_line memory)" = "memory:canEnd=5000@process,inUse=2000@process,other=13000,free=12000;center=20000;foot=1.5" ]'
  check "the top charts list the largest disk rows and the processes using the most memory and CPU, each bar holding its row" \
    '[ "$(chart_line largest) $(chart_line memoryTop) $(chart_line cpuTop)" = "largest:f1,c1,c2,b1,a1,u1,u2,t1 memoryTop:p2,p3,p1,p4,p5,p6 cpuTop:p3,p2,p1,p7,p6,p5" ]'
  check "every chart title and part name comes from the English and Japanese dictionaries" \
    'chart_line keys | grep -qx "keys:[1-9][0-9]*:missing="'
  check "the list filters rows by a word in the name or the path" \
    'printf "%s\n" "$LIST_OUT" | grep -qx "path=recommended:b|careful:d name=recommended:c" || { echo "  $LIST_OUT"; false; }'
  check "the list hides the groups switched off" \
    'printf "%s\n" "$LIST_OUT" | grep -qx "levels=check:g|inuse:e"'
  check "the list sorts rows by size either way and by name" \
    'printf "%s\n" "$LIST_OUT" | grep -qx "desc=recommended:acb|check:g|careful:d|inuse:e asc=recommended:bca|check:g|careful:d|inuse:e name=recommended:abc|check:g|careful:d|inuse:e"'
  check "the page names the script's rows from both dictionaries and keeps names from the machine" \
    'out="$(page_eval "$NAME_FNS" "$NAME_JS" 2>&1)"; [ "$out" = "keyed, bad: " ] || { echo "  $out"; false; }'
  check "the totals count each byte once across tabs, nested rows, and copies" \
    'out="$(page_eval "$TOTAL_FNS" "$TOTAL_JS" 2>&1)"; [ "$out" = "cache=200,build=300,trash=500,files=600,project=100,app=0,tools=0;center=1700#recommended=1000,check=700,careful=0,inuse=0;center=1000#picked=1000,freeable=700,other=38300,free=10000;center=10000
2 items|1.0 KB#2 items|900 B#1 item|500 B" ] || { echo "  $out"; false; }'
  check "the bottom bar shows the picked count and the disk to free as two named values" \
    'out="$(page_eval "$TOTAL_FNS" "$TALLY_JS" 2>&1)"; [ "$out" = "Picked|2 items|Disk to free|1.0 KB#選んだ物|2件|空くディスク|1.0 KB#1#apart" ] || { echo "  $out"; false; }'
  check "a list row shows where it is when its name does not tell it apart" \
    'out="$(page_eval "$WHERE_FNS" "$WHERE_JS" 2>&1)"; [ "$out" = "~/Backup|~/Videos|~/projects/app|node ~/work/b/node_modules/.bin/vite --port 5174
archive.zip|~/Backup|1 B|i" ] || { echo "  $out"; false; }'
  check "a list row adds no second line when its name tells it apart" \
    'out="$(page_eval "$WHERE_FNS" "$NO_WHERE_JS" 2>&1)"; [ "$out" = "[||||]
3" ] || { echo "  $out"; false; }'
  check "the copies of one content are listed together under one heading" \
    'out="$(page_eval "$SET_FNS" "$SET_JS" 2>&1)"; [ "$out" = "head:2:500,a,c,b,d#b,d,head:2:500,a,c#head:2:500,c
2 copies with the same contents, 500 B each|同じ中身の写しが2つ、1つ500 B" ] || { echo "  $out"; false; }'
  check "a bar shows where it is when another bar in its chart has the same name" \
    'out="$(page_eval "$BAR_FNS" "$BAR_JS" 2>&1)"; [ "$out" = "Vite dev server|~/projects/shop|5%|Vite dev server|~/projects/blog|3%|Browser|2%" ] || { echo "  $out"; false; }'
else
  for name in "a list row shows only the name, the size, the CPU of a process, and a details button" \
    "a list row shows no path, command, or reason" \
    "the details dialog shows the reason, the effect, and the path or the process details" \
    "the details dialog has a pick button for a row that can be picked" \
    "the details dialog has no pick button for a row in use" \
    "the page opens on the overview tab, placed first" \
    "the overview has the seven charts in order" \
    "the freeable chart sums each kind without rows in use and links each part to its tab" \
    "the page puts projects, leftovers, and tool versions with models in their tabs, named from both dictionaries" \
    "the details dialog shows each new kind's dates and places" \
    "the level chart sums disk rows by level and rows in use apart" \
    "the disk chart splits picked, freeable, other, and free space and shows the free space after freeing the picked rows" \
    "the disk chart says the whole size is unknown instead of drawing zero" \
    "the memory chart splits processes that can end, processes in use, other use, and free memory" \
    "the top charts list the largest disk rows and the processes using the most memory and CPU, each bar holding its row" \
    "every chart title and part name comes from the English and Japanese dictionaries" \
    "the list filters rows by a word in the name or the path" \
    "the list hides the groups switched off" \
    "the list sorts rows by size either way and by name" \
    "the page names the script's rows from both dictionaries and keeps names from the machine" \
    "the totals count each byte once across tabs, nested rows, and copies" \
    "the bottom bar shows the picked count and the disk to free as two named values" \
    "a list row shows where it is when its name does not tell it apart" \
    "a list row adds no second line when its name tells it apart" \
    "the copies of one content are listed together under one heading" \
    "a bar shows where it is when another bar in its chart has the same name"; do
    printf 'skip  %s (node is not installed)\n' "$name"
  done
fi

# A scan written by the previous format has no levels, so serve and apply ask for a new scan.
mkdir -p "$T/state-old"
jq '.version = 1' "$SCAN" > "$T/state-old/scan.json" 2>/dev/null
MACHINE_CLEANUP_HOME="$T/state-old" mc apply --select "machine-cleanup:select d-00000000" > "$T/old-apply.out" 2>&1; OLD_APPLY_RC=$?
MACHINE_CLEANUP_HOME="$T/state-old" mc serve --no-open --wait 1 > "$T/old-serve.out" 2>&1; OLD_SERVE_RC=$?
check "serve and apply refuse a scan from an older version and ask for a new one" \
  '[ "$OLD_APPLY_RC" = 2 ] && [ "$OLD_SERVE_RC" = 2 ] && grep -q "older version" "$T/old-apply.out" && grep -q "older version" "$T/old-serve.out"'
# A version 2 scan has no disk size for the overview, so it is refused the same way.
mkdir -p "$T/state-v2"
jq '.version = 2 | del(.measure.disk_total)' "$SCAN" > "$T/state-v2/scan.json" 2>/dev/null
MACHINE_CLEANUP_HOME="$T/state-v2" mc apply --select "machine-cleanup:select d-00000000" > "$T/v2-apply.out" 2>&1; V2_APPLY_RC=$?
MACHINE_CLEANUP_HOME="$T/state-v2" mc serve --no-open --wait 1 > "$T/v2-serve.out" 2>&1; V2_SERVE_RC=$?
check "serve and apply refuse a version 2 scan, which has no disk size" \
  '[ "$V2_APPLY_RC" = 2 ] && [ "$V2_SERVE_RC" = 2 ] && grep -q "older version" "$T/v2-apply.out" && grep -q "older version" "$T/v2-serve.out"'
# A version 3 scan has no work folders, tool versions, or models, so it is refused the same way.
mkdir -p "$T/state-v3"
jq '.version = 3 | .items |= map(select(.category | IN("project", "tool", "model") | not))' "$SCAN" > "$T/state-v3/scan.json" 2>/dev/null
MACHINE_CLEANUP_HOME="$T/state-v3" mc apply --select "machine-cleanup:select d-00000000" > "$T/v3-apply.out" 2>&1; V3_APPLY_RC=$?
MACHINE_CLEANUP_HOME="$T/state-v3" mc serve --no-open --wait 1 > "$T/v3-serve.out" 2>&1; V3_SERVE_RC=$?
check "serve and apply refuse a version 3 scan, which has no project, tool, or model rows" \
  '[ "$V3_APPLY_RC" = 2 ] && [ "$V3_SERVE_RC" = 2 ] && grep -q "older version" "$T/v3-apply.out" && grep -q "older version" "$T/v3-serve.out"'
# A version 4 scan may list one path in two rows and has no rows inside rows, so it is refused too.
mkdir -p "$T/state-v4"
jq '.version = 4 | .items |= map(del(.within, .label))' "$SCAN" > "$T/state-v4/scan.json" 2>/dev/null
MACHINE_CLEANUP_HOME="$T/state-v4" mc apply --select "machine-cleanup:select d-00000000" > "$T/v4-apply.out" 2>&1; V4_APPLY_RC=$?
MACHINE_CLEANUP_HOME="$T/state-v4" mc serve --no-open --wait 1 > "$T/v4-serve.out" 2>&1; V4_SERVE_RC=$?
check "serve and apply refuse a version 4 scan, which may list a path twice" \
  '[ "$V4_APPLY_RC" = 2 ] && [ "$V4_SERVE_RC" = 2 ] && grep -q "older version" "$T/v4-apply.out" && grep -q "older version" "$T/v4-serve.out"'

PLUGIN_DIR="$(cd "$SKILL_DIR/../.." && pwd)"
check "how-it-works lists the three levels and their rules in both languages" \
  'grep -qx "## How rows are ranked" "$PLUGIN_DIR/docs/how-it-works.md" && grep -q "^| Recommended |" "$PLUGIN_DIR/docs/how-it-works.md" && grep -q "^| Check first |" "$PLUGIN_DIR/docs/how-it-works.md" && grep -q "^| Careful |" "$PLUGIN_DIR/docs/how-it-works.md" && grep -qx "## 行の推奨度" "$PLUGIN_DIR/docs/how-it-works.ja.md" && grep -q "^| おすすめ |" "$PLUGIN_DIR/docs/how-it-works.ja.md" && grep -q "^| 確かめて選ぶ |" "$PLUGIN_DIR/docs/how-it-works.ja.md" && grep -q "^| 慎重に |" "$PLUGIN_DIR/docs/how-it-works.ja.md"'
# docs_rows <file> <heading> <first cells...>: the file has the heading and a table row for each cell.
docs_rows() {
  local f="$1" h="$2" c
  shift 2
  grep -qx "$h" "$f" || return 1
  for c in "$@"; do grep -qF "| $c |" "$f" || { echo "  no row \"$c\" in $f"; return 1; }; done
}
check "how-it-works describes the overview charts and the list tools in both languages" \
  'docs_rows "$PLUGIN_DIR/docs/how-it-works.md" "## The overview tab" "What can be freed" "Size by level" "Disk" "Memory" "Largest items" "Processes using the most memory" "Processes using the most CPU" "Search" "Groups" "Sort" && docs_rows "$PLUGIN_DIR/docs/how-it-works.ja.md" "## 全体のタブ" "空けられる分の内訳" "推奨度ごとの大きさ" "ディスク" "メモリ" "大きい物の上位" "メモリを多く使うプロセス" "CPUを多く使うプロセス" "探す" "段" "並べ替え"'
check "the READMEs and how-it-works describe the four new kinds in both languages" \
  'docs_rows "$PLUGIN_DIR/README.md" "## What it finds" "Projects" "Apps" "Tools and models" && grep -q "left behind by removed apps" "$PLUGIN_DIR/README.md" && docs_rows "$PLUGIN_DIR/README.ja.md" "## 見つける物" "プロジェクト" "アプリ" "道具とモデル" && grep -q "消したアプリの残り" "$PLUGIN_DIR/README.ja.md" && docs_rows "$PLUGIN_DIR/docs/how-it-works.md" "## The scan" "Work folders" "App leftovers" "Tool versions" "AI models" && docs_rows "$PLUGIN_DIR/docs/how-it-works.md" "## How each item is freed" "Work folders and app leftovers" "Tool versions" "AI models" && docs_rows "$PLUGIN_DIR/docs/how-it-works.ja.md" "## 調べ方" "作業フォルダ" "消したアプリの残り" "道具の版" "AIモデル" && docs_rows "$PLUGIN_DIR/docs/how-it-works.ja.md" "## 項目ごとの空け方" "作業フォルダと消したアプリの残り" "道具の版" "AIモデル"'

check "the READMEs and how-it-works say each path is one row and nested rows are freed once" \
  'grep -q "appears in one row" "$PLUGIN_DIR/README.md" && grep -q "1つの行にだけ出" "$PLUGIN_DIR/README.ja.md" && grep -qx "## One row for each path" "$PLUGIN_DIR/docs/how-it-works.md" && grep -qx "## 1つのパスに1つの行" "$PLUGIN_DIR/docs/how-it-works.ja.md" && grep -q "freed with" "$PLUGIN_DIR/docs/how-it-works.md" && grep -q "一緒に空く" "$PLUGIN_DIR/docs/how-it-works.ja.md"'

# --- the opened page --------------------------------------------------------------------------
# The page as serve builds it from this scan, opened in a browser in English and Japanese, light and
# dark, at 1400px and 390px. A script added at the end of the copy presses the language and theme
# buttons, walks every tab, and writes what it measured into the data-measure attribute of <html>:
# tabs that are cut off or hidden, sideways scrolling, text cut with an ellipsis, text under 4.5:1
# against its background, and ring text outside the ring's hole for the largest value and for not
# measured. With copies=1 it also keeps each tab's drawn main area, for verify.
MEASURE_JS='<script>
(function () {
  "use strict";
  var q = {};
  location.hash.slice(1).split("&").forEach(function (p) { var kv = p.split("="); q[kv[0]] = decodeURIComponent(kv[1] || ""); });
  document.querySelector("[data-lang=\"" + q.lang + "\"]").click();
  document.querySelector("[data-theme-choice=\"" + q.theme + "\"]").click();
  var out = { tabs: [], hidden: [], hscroll: [], clipped: [], contrast: [], rings: [], ringTexts: 0, copies: 0 };
  function shown(el) { var s = getComputedStyle(el), b = el.getBoundingClientRect(); return !el.closest("[hidden]") && s.display !== "none" && s.visibility !== "hidden" && b.width > 0 && b.height > 0; }
  function rgb(c) { var m = c.match(/rgba?\(([^)]+)\)/); if (!m) return null; var p = m[1].split(/[ ,\/]+/).filter(Boolean).map(Number); return { r: p[0], g: p[1], b: p[2], a: p.length > 3 ? p[3] : 1 }; }
  function lum(c) { function f(v) { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); } return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b); }
  function blend(fg, bg) { return { r: fg.r * fg.a + bg.r * (1 - fg.a), g: fg.g * fg.a + bg.g * (1 - fg.a), b: fg.b * fg.a + bg.b * (1 - fg.a), a: 1 }; }
  function under(el) { var layers = []; for (var e = el; e; e = e.parentElement) { var c = rgb(getComputedStyle(e).backgroundColor); if (c && c.a > 0) { layers.push(c); if (c.a >= 1) break; } } var base = { r: 255, g: 255, b: 255, a: 1 }; for (var i = layers.length - 1; i >= 0; i--) base = blend(layers[i], base); return base; }
  function tabs() { return Array.prototype.slice.call(document.getElementById("tabs").querySelectorAll("[role=tab]")); }
  function view(name) {
    var strip = document.getElementById("tabs"), sr = strip.getBoundingClientRect();
    tabs().forEach(function (b) { var r = b.getBoundingClientRect(); if (!shown(b) || r.left < sr.left - 1 || r.right > sr.right + 1 || r.right > window.innerWidth || r.top < sr.top - 1 || r.bottom > sr.bottom + 1) out.hidden.push(name + " > " + b.textContent); });
    if (strip.scrollWidth > strip.clientWidth + 1) out.hidden.push(name + " > the tab strip scrolls");
    if (document.documentElement.scrollWidth > document.documentElement.clientWidth + 1) out.hscroll.push(name);
    Array.prototype.forEach.call(document.querySelectorAll("body *"), function (el) {
      if (!shown(el) || el.closest("svg, script, style")) return;
      var s = getComputedStyle(el), own = Array.prototype.filter.call(el.childNodes, function (n) { return n.nodeType === 3; }).map(function (n) { return n.textContent.trim(); }).join(" ").trim();
      if ((s.textOverflow === "ellipsis" || s.overflowX === "hidden") && el.scrollWidth > el.clientWidth + 1 && own) out.clipped.push(name + " > " + own.slice(0, 60));
      if (!own || el.closest(":disabled")) return;
      var fg = rgb(s.color), op = 1;
      for (var e = el; e; e = e.parentElement) op *= Number(getComputedStyle(e).opacity);
      var bg = under(el), f = blend({ r: fg.r, g: fg.g, b: fg.b, a: fg.a * op }, bg);
      var a = lum(f), b2 = lum(bg), ratio = (Math.max(a, b2) + 0.05) / (Math.min(a, b2) + 0.05);
      var size = parseFloat(s.fontSize), need = size >= 24 || (Number(s.fontWeight) >= 700 && size >= 18.66) ? 3 : 4.5;
      if (ratio < need) out.contrast.push(name + " > " + own.slice(0, 40) + " " + ratio.toFixed(2));
    });
  }
  out.tabs = tabs().map(function (b) { return b.textContent; });
  var copies = document.createElement("div");
  for (var i = 0; i < out.tabs.length; i++) {
    tabs()[i].click();
    view(tabs()[i].textContent);
    if (q.copies) { var c = document.createElement("div"); c.innerHTML = document.querySelector("main").innerHTML; copies.appendChild(c); out.copies += 1; }
  }
  tabs()[1].click();
  var group = document.querySelector("#rows .pick-group"); if (group) group.click();
  document.getElementById("free").click();
  view("picked");
  function rings(label) {
    Array.prototype.forEach.call(document.querySelectorAll(".donut"), function (d) {
      var svg = d.querySelector("svg"), circle = svg.querySelector("circle"), box = d.getBoundingClientRect();
      if (!circle) return;
      var scale = box.width / svg.viewBox.baseVal.width, hole = (Number(circle.getAttribute("r")) - parseFloat(getComputedStyle(circle).strokeWidth) / 2) * scale;
      var cx = box.left + box.width / 2, cy = box.top + box.height / 2;
      var walk = document.createTreeWalker(d.querySelector(".mid"), NodeFilter.SHOW_TEXT);
      while (walk.nextNode()) {
        var n = walk.currentNode; if (!n.textContent.trim()) continue;
        out.ringTexts += 1;
        var range = document.createRange(); range.selectNodeContents(n);
        Array.prototype.forEach.call(range.getClientRects(), function (r) {
          [[r.left, r.top], [r.right, r.top], [r.left, r.bottom], [r.right, r.bottom]].forEach(function (p) {
            if (Math.hypot(p[0] - cx, p[1] - cy) > hole + 0.5) out.rings.push(label + " > " + n.textContent.trim());
          });
        });
      }
    });
  }
  tabs()[0].click();
  DATA.measure = { disk_free: 999940000000, disk_total: 999990000000, memory_used: 999940000000, memory_total: 999990000000, load: [1, 1, 1] };
  render(); rings("999.9 GB");
  DATA.measure = { disk_free: null, disk_total: null, memory_used: null, memory_total: null, load: null };
  render(); rings("not measured");
  out.rings = out.rings.filter(function (x, i, a) { return a.indexOf(x) === i; });
  if (q.copies) document.body.appendChild(copies);
  document.documentElement.setAttribute("data-measure", JSON.stringify(out));
})();
</script>'
OPENED_CHECKS=("the opened page shows every tab at 1400px in both languages" \
  "the opened page fits 390px with every tab shown" \
  "the text in each ring stays inside its hole in both languages" \
  "no text on the opened page is cut with an ellipsis" \
  "every text on the opened page has a contrast of 4.5 to 1 in light and dark" \
  "the opened page passes page-design verify on every tab in both languages")
# open_sheet <lang> <theme> <width> [copies]: writes the page as the browser drew it to
# $T/opened/<lang>-<theme>-<width>.dom.html.
open_sheet() {
  "$REAL_BROWSER" --headless --disable-gpu --no-first-run --hide-scrollbars --user-data-dir="$T/browser-profile" \
    --window-size="$3,900" --dump-dom "file://$T/opened/sheet.html#lang=$1&theme=$2${4:+&copies=1}" \
    > "$T/opened/$1-$2-$3.dom.html" 2>/dev/null
}
# opened <names> <key>...: prints each measured list that is not empty, and fails when one is, or when
# a page was not drawn.
opened() {
  "$PY" - "$T/opened" "$@" <<'PY'
import html, json, re, sys
folder, names, keys = sys.argv[1], sys.argv[2].split(), sys.argv[3:]
bad = False
for name in names:
    try:
        dom = open("%s/%s.dom.html" % (folder, name), encoding="utf-8").read()
        data = json.loads(html.unescape(re.search(r'\sdata-measure="([^"]*)"', dom).group(1)))
    except (OSError, AttributeError, ValueError):
        print("  %s: not drawn" % name)
        bad = True
        continue
    for key in keys:
        if key == "tabs":
            ok = len(data["tabs"]) == 12
            value = data["tabs"]
        elif key == "ringTexts":
            ok = data["ringTexts"] >= 16
            value = data["ringTexts"]
        else:
            ok = not data[key]
            value = data[key]
        if not ok:
            print("  %s %s: %s" % (name, key, json.dumps(value, ensure_ascii=False)[:600]))
            bad = True
sys.exit(1 if bad else 0)
PY
}
verify_opened() {
  local f
  for f in "$T/opened/en-light-1400.dom.html" "$T/opened/ja-light-1400.dom.html"; do
    [ "$(grep -o 'copies&quot;:[0-9]*' "$f" | tr -dc 0-9)" = 12 ] || { echo "  $f has no copy of each tab"; return 1; }
    "$PY" "$REPO/plugins/design-formats/skills/page-design/scripts/page-design.py" verify "$f" || return 1
  done
}
if [ -z "$REAL_BROWSER" ]; then
  for name in "${OPENED_CHECKS[@]}"; do printf 'skip  %s (needs a Chromium-based browser)\n' "$name"; done
else
  mkdir -p "$T/opened"
  "$PY" - "$SCRIPTS" "$T/opened/sheet.html" "$MEASURE_JS" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import machine_cleanup as m
ctx = m.Ctx(platform="darwin")
scan = m.load_scan(ctx)
page = m.page_html(ctx, scan, "test-token") if scan else ""
open(sys.argv[2], "w", encoding="utf-8").write(page.replace("</body>", sys.argv[3] + "\n</body>", 1))
PY
  open_sheet en light 1400 copies; open_sheet ja light 1400 copies; open_sheet en dark 1400; open_sheet ja dark 1400
  open_sheet en light 390; open_sheet ja light 390
  check "the opened page shows every tab at 1400px in both languages" 'opened "en-light-1400 ja-light-1400" tabs hidden'
  check "the opened page fits 390px with every tab shown" 'opened "en-light-390 ja-light-390" tabs hidden hscroll'
  check "the text in each ring stays inside its hole in both languages" 'opened "en-light-1400 ja-light-1400" ringTexts rings'
  check "no text on the opened page is cut with an ellipsis" 'opened "en-light-1400 ja-light-1400 en-light-390 ja-light-390" clipped'
  check "every text on the opened page has a contrast of 4.5 to 1 in light and dark" 'opened "en-light-1400 ja-light-1400 en-dark-1400 ja-dark-1400" contrast'
  check "the opened page passes page-design verify on every tab in both languages" 'verify_opened'
fi

# The copied text is built without the dictionary, and apply reads it as it is.
copy_ok() {
  "$PY" - "$SHEET" <<'PY'
import re, sys
html = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'function selectionText\([^)]*\)\s*\{(.*?)\n\}', html, re.S)
assert m, "no selectionText function"
body = m.group(1)
assert "machine-cleanup:select" in body, "copied text has no prefix"
assert "t(" not in body and "I18N" not in body and "lang" not in body, "copied text depends on the language"
PY
}

# --- the server -----------------------------------------------------------------------------
PICK="$(id_at "$SHOP/.next")"
mc serve --wait 20 --no-open > "$T/serve.out" 2> "$T/serve.err" &
SERVE_PID=$!
URL=""
for _ in $(seq 1 50); do
  URL="$(grep -m1 -oE 'http://127\.0\.0\.1:[0-9]+/\?t=[A-Za-z0-9_-]+' "$T/serve.out" 2>/dev/null || true)"
  [ -n "$URL" ] && break
  kill -0 "$SERVE_PID" 2>/dev/null || break
  sleep 0.1
done
BASE="${URL%%/\?t=*}"
TOKEN="${URL##*?t=}"
post() { curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' -H "Origin: $1" --data "$2" "$BASE/select" 2>/dev/null; }
get() { curl -s -o /dev/null -w '%{http_code}' "$1" 2>/dev/null; }
refused_ok=false
if [ -n "$URL" ] \
  && [ "$(get "$BASE/")" = 403 ] \
  && [ "$(post "$BASE" "{\"t\":\"wrong\",\"ids\":[\"$PICK\"]}")" = 403 ] \
  && [ "$(post "http://evil.example" "{\"t\":\"$TOKEN\",\"ids\":[\"$PICK\"]}")" = 403 ] \
  && kill -0 "$SERVE_PID" 2>/dev/null \
  && ! grep -q 'machine-cleanup:select' "$T/serve.out"; then
  refused_ok=true
fi
served_ok=false
if [ -n "$URL" ] && [ "$(get "$URL")" = 200 ] && [ "$(post "$BASE" "{\"t\":\"$TOKEN\",\"ids\":[\"$PICK\"]}")" = 200 ]; then
  wait "$SERVE_PID"; rc=$?
  [ "$rc" = 0 ] && grep -qx "machine-cleanup:select $PICK" "$T/serve.out" && served_ok=true
fi
kill "$SERVE_PID" 2>/dev/null; SERVE_PID=""
check "serve returns the picked ids after one request with the token" '$served_ok'
check "serve refuses a request without the token or from another origin" '$refused_ok'

# --- apply ----------------------------------------------------------------------------------
# The first apply also measures the report: df says 10 GB free before and 30 GB after.
printf '%s\n/dev/disk3s1 500000000 490000000 10000000 98%% 1 1 1%% /\n' "$DF_HEAD" > "$MOCK/df.first"
printf '%s\n/dev/disk3s1 500000000 470000000 30000000 94%% 1 1 1%% /\n' "$DF_HEAD" > "$MOCK/df"
NM="$(id_at "$SHOP/node_modules")"
mc_as darwin apply --select "machine-cleanup:select $NM" > "$T/apply1.out" 2>&1; rc=$?
check "the copied selection is the same in both languages and apply reads it" \
  'copy_ok && [ "$rc" = 0 ] && [ ! -e "$SHOP/node_modules" ]'
check "apply acts only on the passed ids" \
  '[ "$rc" = 0 ] && [ ! -e "$SHOP/node_modules" ] && [ -d "$SHOP/.next" ] && [ -d "$BLOG/node_modules" ] && [ -d "$H/.npm/_cacache" ] && [ -e "$H/Videos/raw.mov" ]'

BLOG_NM="$(id_at "$BLOG/node_modules")"
mc_as darwin apply --select "machine-cleanup:select d-00000000" > "$T/apply-unknown.out" 2>&1; rc_unknown=$?
mc_as darwin apply --select "machine-cleanup:select $BLOG_NM $(id_at "$SHOP/.next")" > "$T/apply-locked.out" 2>&1; rc_locked=$?
check "apply refuses unknown and locked ids" \
  '[ -n "$BLOG_NM" ] && [ "$rc_unknown" = 1 ] && [ "$rc_locked" = 1 ] && [ -d "$BLOG/node_modules" ] && [ -d "$SHOP/.next" ]'

# .next grows after the scan, so the apply skips it.
size "$SHOP/.next" 409600
printf 'more' > "$SHOP/.next/cache/more"
mc_as darwin apply --select "machine-cleanup:select $(id_at "$SHOP/.next")" > "$T/apply-changed.out" 2>&1
check "apply skips an item that changed after the scan" \
  'grep -qE "^skipped +$(id_at "$SHOP/.next") .*changed" "$T/apply-changed.out" && [ -d "$SHOP/.next" ]'

: > "$MOCK/calls.log"
mc_as darwin apply --select "machine-cleanup:select $(id_kind homebrew) $(id_kind npm) $(id_kind cargo)" > "$T/apply-tools.out" 2>&1
check "apply uses the tool's own clean command when it has one" \
  'grep -qx "brew cleanup --prune=all" "$MOCK/calls.log" && grep -qx "npm cache clean --force" "$MOCK/calls.log" && [ ! -e "$H/.cargo/registry/cache" ]'

linux_trash_ok() {
  "$PY" - "$SCRIPTS" "$T/linux-home" <<'PY'
import os, sys
sys.path.insert(0, sys.argv[1])
import machine_cleanup as m
home = sys.argv[2]
os.makedirs(os.path.join(home, "Videos"))
path = os.path.join(home, "Videos", "clip.mov")
open(path, "w").write("x")
m.move_to_trash(path, platform="linux", home=home)
info = os.path.join(home, ".local/share/Trash/info/clip.mov.trashinfo")
assert not os.path.exists(path)
assert os.path.exists(os.path.join(home, ".local/share/Trash/files/clip.mov"))
text = open(info).read()
assert "[Trash Info]" in text and "Path=" + path in text and "DeletionDate=" in text
PY
}
mc_as darwin apply --select "machine-cleanup:select $(id_at "$H/Videos/raw.mov") $(id_at "$APP")" > "$T/apply-trash.out" 2>&1
check "apply moves files and apps to the trash with restore info" \
  '[ ! -e "$H/Videos/raw.mov" ] && [ -e "$H/.Trash/raw.mov" ] && [ ! -e "$APP" ] && [ -e "$H/.Trash/Editor.app" ] && [ ! -e "$H/Library/Preferences/com.example.editor.plist" ] && linux_trash_ok'

mc_as darwin apply --term-wait 1 --select "machine-cleanup:select $(id_pid "$P_TERM") $(id_pid "$P_STUBBORN")" > "$T/apply-term.out" 2>&1
check "apply sends SIGTERM and reports the survivors" \
  '! kill -0 "$P_TERM" 2>/dev/null && kill -0 "$P_STUBBORN" 2>/dev/null && grep -qE "^survived +$(id_pid "$P_STUBBORN")" "$T/apply-term.out"'
mc_as darwin apply --kill "$(id_pid "$P_TERM")" > "$T/kill-other.out" 2>&1; rc_kill_other=$?
mc_as darwin apply --kill "$(id_pid "$P_STUBBORN")" > "$T/kill.out" 2>&1
sleep 0.2
check "apply sends SIGKILL only to survivors picked again" \
  '[ "$rc_kill_other" = 1 ] && ! kill -0 "$P_STUBBORN" 2>/dev/null'

# The pid of P_REUSED now belongs to a process that started at another time.
write_ps 10:00.00 'Sat Nov 15 10:30:00 2026'
mc_as darwin apply --term-wait 1 --select "machine-cleanup:select $(id_pid "$P_REUSED")" > "$T/apply-reused.out" 2>&1
check "apply never signals a reused pid" \
  'kill -0 "$P_REUSED" 2>/dev/null && grep -qE "^skipped +$(id_pid "$P_REUSED")" "$T/apply-reused.out"'
write_ps 10:00.00

LOGIN="$(id_kind launch-agent)"
: > "$MOCK/calls.log"
mc_as darwin apply --select "machine-cleanup:select $LOGIN" > "$T/apply-login.out" 2>&1
stopped=false
[ ! -e "$H/Library/LaunchAgents/com.example.updater.plist" ] && grep -q "^launchctl bootout gui/$UID_NOW" "$MOCK/calls.log" && stopped=true
mc_as darwin restore "$LOGIN" > "$T/restore.out" 2>&1
check "a stopped login item can be restored" \
  '$stopped && [ -f "$H/Library/LaunchAgents/com.example.updater.plist" ] && grep -q "^launchctl bootstrap gui/$UID_NOW" "$MOCK/calls.log"'

mkdir -p "$H/Library/Containers/com.docker.docker/Data/vms/0/data"
printf 'raw' > "$H/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw"
mc_as darwin apply --select "machine-cleanup:select $(id_kind docker-build-cache)" > "$T/apply-docker.out" 2>&1
# The report measures before and after with df, vm_stat, and the load average, and says when
# Docker Desktop's disk image does not give the space back right away.
check "the report shows measured free space, memory, and load before and after" \
  'grep -qE "^Free disk +10\.2 GB -> 30\.7 GB" "$T/apply1.out" && grep -qE "^Memory used +.+ -> .+" "$T/apply1.out" && grep -qE "^Load +.+ -> .+" "$T/apply1.out" && ! grep -q "Docker Desktop" "$T/apply1.out" && grep -q "Docker Desktop" "$T/apply-docker.out" && grep -q "docker builder prune" "$MOCK/calls.log"'

# --- freeing the four kinds -----------------------------------------------------------------
IDLE_ID="$(cat_at project "$IDLE")"
GONE_ID="$(jq -r '[.items[] | select(.kind == "leftover" and .name == "com.oldvendor.gone")][0].id // empty' "$SCAN" 2>/dev/null)"
mc_as darwin apply --select "machine-cleanup:select $IDLE_ID $GONE_ID" > "$T/apply-unused.out" 2>&1
trashed=false
[ -n "$IDLE_ID" ] && [ -n "$GONE_ID" ] && [ ! -e "$IDLE" ] && [ -d "$H/.Trash/idle/.git" ] && [ ! -e "$GONE_AS" ] \
  && [ ! -e "$LIB/Preferences/com.oldvendor.gone.plist" ] && [ -e "$H/.Trash/com.oldvendor.gone.plist" ] && trashed=true
mc_as darwin restore "$IDLE_ID" "$GONE_ID" > "$T/restore-unused.out" 2>&1
check "apply moves picked projects and app leftovers to the Trash and restore puts them back" \
  '$trashed && [ -d "$IDLE/.git" ] && [ -f "$GONE_AS/data" ] && [ -f "$LIB/Preferences/com.oldvendor.gone.plist" ] && [ -d "$LIB/Saved Application State/com.oldvendor.gone.savedState" ] && [ ! -e "$H/.Trash/idle" ]'

# The old installer in Downloads and its copy in Archive are in different tabs; picking both would
# leave no copy, so apply refuses and changes nothing.
TOOL_I="$(cat_at installer "$H/Downloads/Tool-1.0.dmg")"
TOOL_D="$(cat_at duplicate "$H/Archive/Tool-1.0.dmg")"
mc_as darwin apply --select "machine-cleanup:select $TOOL_I $TOOL_D" > "$T/apply-copies.out" 2>&1; rc_copies=$?
check "apply refuses picking every copy of a set, whichever tabs the copies are in" \
  '[ -n "$TOOL_I" ] && [ -n "$TOOL_D" ] && [ "$rc_copies" = 1 ] && grep -q "keep at least one" "$T/apply-copies.out" && [ -e "$H/Downloads/Tool-1.0.dmg" ] && [ -e "$H/Archive/Tool-1.0.dmg" ]'

# idlebuild's node_modules is picked before the project that holds it. The project goes to the Trash
# whole, node_modules inside it, and the node_modules row is skipped instead of deleted first.
IDLEB_ID="$(cat_at project "$IDLEB")"
IDLEB_NM="$(cat_at build "$IDLEB/node_modules")"
mc_as darwin apply --select "machine-cleanup:select $IDLEB_NM $IDLEB_ID" > "$T/apply-nested.out" 2>&1; rc_nested=$?
check "apply frees a folder once and skips the picked rows inside it" \
  '[ -n "$IDLEB_ID" ] && [ -n "$IDLEB_NM" ] && [ "$rc_nested" = 0 ] && grep -qE "^skipped +$IDLEB_NM .*inside" "$T/apply-nested.out" && grep -qE "^done +$IDLEB_ID " "$T/apply-nested.out" && [ ! -e "$IDLEB" ] && [ -f "$H/.Trash/idlebuild/node_modules/lodash/file" ]'

# skipc gains a pushed commit today, skipch a changed file, and skipl an old commit that is not pushed.
SKIPC_ID="$(cat_at project "$H/projects/skipc")"
SKIPCH_ID="$(cat_at project "$H/projects/skipch")"
SKIPL_ID="$(cat_at project "$H/projects/skipl")"
printf 'more\n' >> "$H/projects/skipc/README.md"
git -C "$H/projects/skipc" commit -qam more && git -C "$H/projects/skipc" push -q origin HEAD 2>/dev/null
printf 'edit\n' >> "$H/projects/skipch/README.md"
printf 'local\n' >> "$H/projects/skipl/README.md"
GIT_AUTHOR_DATE="$OLD_COMMIT" GIT_COMMITTER_DATE="$OLD_COMMIT" git -C "$H/projects/skipl" commit -qam local
idle "$H/projects/skipl"
mc_as darwin apply --select "machine-cleanup:select $SKIPC_ID $SKIPCH_ID $SKIPL_ID" > "$T/apply-skip-projects.out" 2>&1
skipped_all() {
  local i
  for i in "$@"; do [ -n "$i" ] && grep -qE "^skipped +$i " "$T/apply-skip-projects.out" || { echo "  not skipped: $i"; return 1; }; done
}
check "apply skips a project that gained a commit, a change, or a local-only commit after the scan" \
  'skipped_all "$SKIPC_ID" "$SKIPCH_ID" "$SKIPL_ID" && [ -d "$H/projects/skipc/.git" ] && [ -d "$H/projects/skipch/.git" ] && [ -d "$H/projects/skipl/.git" ]'

: > "$MOCK/calls.log"
mc_as darwin apply --select "machine-cleanup:select $(tool_at "$H/.nvm/versions/node/v18.20.4") $(tool_at "$MISE/node/21.7.3") $(tool_at "$H/.rustup/toolchains/1.70.0-aarch64-apple-darwin")" > "$T/apply-tools-versions.out" 2>&1
check "apply deletes picked tool versions, and uses rustup for a toolchain" \
  '[ -n "$(cat_at tool "$MISE/node/21.7.3")" ] && [ ! -e "$H/.nvm/versions/node/v18.20.4" ] && [ ! -e "$MISE/node/21.7.3" ] && [ ! -L "$MISE/node/21" ] && [ ! -L "$MISE/node/21.7" ] && [ -L "$MISE/node/24" ] && grep -qx "rustup toolchain uninstall 1.70.0-aarch64-apple-darwin" "$MOCK/calls.log"'

# Ollama runs for the first apply and not for the second. The ollama stand-in deletes nothing.
OLLAMA_UP=1 write_ps 10:00.00
: > "$MOCK/calls.log"
mc_as darwin apply --select "machine-cleanup:select $(model_at "$OLLAMA_LATEST") $(model_at "$HF_TINY") $(model_at "$LMS")" > "$T/apply-models.out" 2>&1
check "apply removes Ollama models with ollama rm while Ollama runs and deletes other model folders" \
  '[ -n "$(model_at "$OLLAMA_LATEST")" ] && grep -qx "ollama rm llama3:latest" "$MOCK/calls.log" && [ -f "$OLLAMA_LATEST" ] && [ ! -e "$HF_TINY" ] && [ ! -e "$LMS" ]'
write_ps 10:00.00
: > "$MOCK/calls.log"
# A model pulled after the scan uses blob d, which only 8b-q4 used when the scan ran.
manifest "$OLLAMA/manifests/registry.ollama.ai/library/phi3/latest" a 10 d 200
mc_as darwin apply --select "machine-cleanup:select $(model_at "$OLLAMA_Q4")" > "$T/apply-ollama-files.out" 2>&1
check "while Ollama is not running, apply deletes the manifest and only the blobs no other model uses" \
  '[ -n "$(model_at "$OLLAMA_Q4")" ] && [ ! -e "$OLLAMA_Q4" ] && [ ! -e "$OLLAMA/blobs/sha256-$(printf "%064d" 0 | tr 0 e)" ] && [ -f "$OLLAMA/blobs/sha256-$(printf "%064d" 0 | tr 0 d)" ] && [ -f "$OLLAMA/blobs/sha256-$(printf "%064d" 0 | tr 0 b)" ] && [ -f "$OLLAMA_LATEST" ] && ! grep -q "^ollama rm" "$MOCK/calls.log"'
check "apply leaves unpicked projects, leftovers, tool versions, and models alone" \
  '[ -n "$(cat_at project "$IDLE2")" ] && leftover_named com.gonevendor.app2 && [ -n "$(tool_at "$H/.pyenv/versions/3.9.18")" ] && [ -n "$(model_at "$HF_OTHER")" ] && [ -d "$IDLE2/.git" ] && [ -f "$LIB/Application Support/com.gonevendor.app2/data" ] && [ -d "$H/.pyenv/versions/3.9.18" ] && [ -d "$HF_OTHER" ] && [ -d "$LMS_OLD" ]'

# --- boundaries -----------------------------------------------------------------------------
check "every path the tests touch is under the throwaway HOME" \
  '[ -s "$T/scan.out" ] && has "[.items[] | (.path // empty), ((.detail.support // [])[])] | length > 0" && has "[.items[] | (.path // empty), ((.detail.support // [])[])] | all(startswith(\"$H/\"))"'
check "no script connects outside the machine" \
  '[ -f "$SCRIPT" ] && ! grep -rnE "urllib\.request|http\.client|import requests|from requests|socket\.create_connection|\bcurl\b|\bwget\b" "$SCRIPTS" && grep -q "\"127.0.0.1\"" "$SCRIPT" && ! grep -q "0\.0\.0\.0" "$SCRIPT"'
check "the marketplace and the root READMEs list machine-cleanup" \
  '[ -n "$REPO" ] && jq -e ".plugins | any(.name == \"machine-cleanup\" and .source == \"./plugins/machine-cleanup\")" "$REPO/.claude-plugin/marketplace.json" > /dev/null && grep -qE "^\| \[machine-cleanup\]\(plugins/machine-cleanup\) \|" "$REPO/README.md" && grep -qE "^\| \[machine-cleanup\]\(plugins/machine-cleanup\) \|" "$REPO/README.ja.md"'

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
printf 'checks: %d\n' "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
