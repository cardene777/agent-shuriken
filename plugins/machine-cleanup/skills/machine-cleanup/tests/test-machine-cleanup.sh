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
  HOMEBREW_CACHE CARGO_HOME GOPATH GOMODCACHE GOCACHE GRADLE_USER_HOME CP_HOME_DIR DOCKER_HOST DOCKER_CONTEXT
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
for tool in brew npm pnpm yarn bun pip uv go pod; do stub "$tool" "$LOG"; done
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
  } > "$MOCK/ps"
}
write_ps 9:50.00
cp "$MOCK/ps" "$MOCK/ps.first"
write_ps 10:00.00

# --- scan -----------------------------------------------------------------------------------
SCAN="$MACHINE_CLEANUP_HOME/scan.json"
mc_as darwin scan --json --sample 0 --apps-dir "$H/Applications" > "$T/scan.out" 2> "$T/scan.err"
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
  'has ".items | any(.category == \"large\" and (.path | endswith(\"/Videos/raw.mov\")))" && [ "$(jq "[.items[] | select(.category == \"duplicate\" and (.path | endswith(\"archive.zip\")))] | length" "$SCAN")" = 2 ] && has "[.items[] | select(.category == \"duplicate\")] | map(.detail.set) | unique | length == 1" && [ -z "$(id_at "$H/Documents/small.bin")" ]'

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

mode() { "$PY" -c 'import os, sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$1" 2>/dev/null; }
check "scan state is readable only by the user" \
  '[ "$(mode "$T/state")" = 0o700 ] && [ "$(mode "$T/state/scan.json")" = 0o600 ]'

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

# A scan written by the previous format has no levels, so serve and apply ask for a new scan.
mkdir -p "$T/state-old"
jq '.version = 1' "$SCAN" > "$T/state-old/scan.json" 2>/dev/null
MACHINE_CLEANUP_HOME="$T/state-old" mc apply --select "machine-cleanup:select d-00000000" > "$T/old-apply.out" 2>&1; OLD_APPLY_RC=$?
MACHINE_CLEANUP_HOME="$T/state-old" mc serve --no-open --wait 1 > "$T/old-serve.out" 2>&1; OLD_SERVE_RC=$?
check "serve and apply refuse a scan from an older version and ask for a new one" \
  '[ "$OLD_APPLY_RC" = 2 ] && [ "$OLD_SERVE_RC" = 2 ] && grep -q "older version" "$T/old-apply.out" && grep -q "older version" "$T/old-serve.out"'

PLUGIN_DIR="$(cd "$SKILL_DIR/../.." && pwd)"
check "how-it-works lists the three levels and their rules in both languages" \
  'grep -qx "## How rows are ranked" "$PLUGIN_DIR/docs/how-it-works.md" && grep -q "^| Recommended |" "$PLUGIN_DIR/docs/how-it-works.md" && grep -q "^| Check first |" "$PLUGIN_DIR/docs/how-it-works.md" && grep -q "^| Careful |" "$PLUGIN_DIR/docs/how-it-works.md" && grep -qx "## 行の推奨度" "$PLUGIN_DIR/docs/how-it-works.ja.md" && grep -q "^| おすすめ |" "$PLUGIN_DIR/docs/how-it-works.ja.md" && grep -q "^| 確かめて選ぶ |" "$PLUGIN_DIR/docs/how-it-works.ja.md" && grep -q "^| 慎重に |" "$PLUGIN_DIR/docs/how-it-works.ja.md"'

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
