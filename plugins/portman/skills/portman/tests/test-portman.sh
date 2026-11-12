#!/usr/bin/env bash
# Tests for portman.py with a throwaway HOME, registry, and project folders.
# Stand-ins for lsof and docker print fixed output, so the tests do not depend on what runs on this
# machine. The socket test is turned off (PORTMAN_NO_PROBE=1) except in the checks that start a real
# listener on 127.0.0.1. Nothing reaches the network.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../scripts/portman.py"
PASS=0
FAIL=0
T="$(mktemp -d)"
LISTENER=""
cleanup() { [ -n "$LISTENER" ] && kill "$LISTENER" 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }

export HOME="$T/home"
export GIT_CONFIG_NOSYSTEM=1
export PORTMAN_HOME="$T/state"
export PORTMAN_LSOF="$T/bin/lsof"
export PORTMAN_DOCKER="$T/bin/docker"
export PORTMAN_PROC_NET="$T/no-proc"
export PORTMAN_NO_PROBE=1
export MOCK_DIR="$T/mock"
mkdir -p "$HOME" "$T/bin" "$MOCK_DIR" "$T/projects/shop" "$T/projects/blog" "$T/elsewhere"
SHOP="$(cd "$T/projects/shop" && pwd -P)"
REG="$PORTMAN_HOME/registry.json"

# The stand-in for lsof: the listening list comes from mock/lsof.listen, a working folder from mock/cwd.<pid>.
cat > "$T/bin/lsof" <<'SH'
#!/usr/bin/env bash
case " $* " in
  *" -sTCP:LISTEN "*) [ -f "$MOCK_DIR/lsof.listen" ] || exit 1; cat "$MOCK_DIR/lsof.listen" ;;
  *" cwd "*) pid="$3"; [ -f "$MOCK_DIR/cwd.$pid" ] || exit 1; printf 'p%s\nfcwd\nn%s\n' "$pid" "$(cat "$MOCK_DIR/cwd.$pid")" ;;
  *) exit 1 ;;
esac
SH
# The stand-in for docker: `ps` prints mock/docker.ps, or fails when mock/docker.down exists.
cat > "$T/bin/docker" <<'SH'
#!/usr/bin/env bash
case "$1" in
  ps) [ -f "$MOCK_DIR/docker.down" ] && exit 1; cat "$MOCK_DIR/docker.ps" 2>/dev/null ;;
  compose) cat "$MOCK_DIR/compose.version" 2>/dev/null || echo 2.29.1 ;;
  *) exit 1 ;;
esac
SH
chmod +x "$T/bin/lsof" "$T/bin/docker"

pm() { python3 "$SCRIPT" "$@"; }
mode() { python3 -c 'import os, sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$1"; }
same() { cmp -s "$1" "$2"; }

# --- empty registry and input checks
pm list >/dev/null 2>&1; rc=$?
check "list on an empty registry exits 1" '[ "$rc" = 1 ]'
check "a run that only reads creates no registry" '[ ! -e "$REG" ]'
pm add shop app 70000 >/dev/null 2>&1; rc=$?
check "a port above 65535 is refused with exit 2" '[ "$rc" = 2 ]'
pm add shop app abc >/dev/null 2>&1; rc=$?
check "a port that is not a number is refused with exit 2" '[ "$rc" = 2 ]'
pm add ../shop app 21001 >/dev/null 2>&1; rc=$?
check "a project name with a slash is refused with exit 2" '[ "$rc" = 2 ]'
pm add shop 'a b' 21001 >/dev/null 2>&1; rc=$?
check "a port name with a space is refused with exit 2" '[ "$rc" = 2 ]'
check "refused input writes no registry" '[ ! -e "$REG" ]'

# --- add
out="$(pm add shop app 21001 --dir "$T/projects/shop")"; rc=$?
check "add exits 0" '[ "$rc" = 0 ]'
check "add records the project folder" 'printf "%s\n" "$out" | grep -q "Recorded $SHOP as the folder of shop"'
check "the registry file is readable only by you" '[ "$(mode "$REG")" = 0o600 ]'
check "the state folder is readable only by you" '[ "$(mode "$PORTMAN_HOME")" = 0o700 ]'
check "the lock file is readable only by you" '[ "$(mode "$PORTMAN_HOME/registry.lock")" = 0o600 ]'
check "the registry has format version 1" 'python3 -c "import json,sys; sys.exit(0 if json.load(open(sys.argv[1]))[\"version\"] == 1 else 1)" "$REG"'
pm add shop db 21003 --service postgres --target 5432 >/dev/null
pm add shop worker 21004 >/dev/null
pm add blog app 21002 --dir "$T/elsewhere/../projects/blog" >/dev/null
pm add notes app 21005 >/dev/null
cp "$REG" "$T/reg.before"
pm add blog web 21001 >/dev/null 2>"$T/err"; rc=$?
check "a port registered to another project is refused with exit 1" '[ "$rc" = 1 ] && grep -q "already registered to shop/app" "$T/err"'
pm add shop app 21009 >/dev/null 2>&1; rc=$?
check "a name already in the project is refused with exit 1" '[ "$rc" = 1 ]'
pm add shop work-er 21009 >/dev/null 2>&1; pm add shop work_er 21010 >/dev/null 2>"$T/err"; rc=$?
check "two names that give the same variable are refused" '[ "$rc" = 1 ] && grep -q "PORT_WORK_ER" "$T/err"'
pm remove --confirm shop/work-er=21009 >/dev/null
check "refused adds leave the registry as it was" 'same "$REG" "$T/reg.before"'
out="$(pm add demo app 3000)"
check "adding a common default port says so" 'printf "%s\n" "$out" | grep -q "Note: 3000 is the default port of"'
pm remove --confirm demo/app=3000 >/dev/null

# --- what holds the ports (stand-ins)
cat > "$MOCK_DIR/lsof.listen" <<'EOF'
p100
cnode
f20
n*:21001
p200
cpython3
f7
n127.0.0.1:21002
p300
ccom.docker.backend
f9
n*:21003
p400
cControlCenter
f4
n*:21007
f5
n[::1]:21007
p500
crapportd
f3
n*:49999
p600
cruby
f8
n*:21005
EOF
printf '%s\n' "$SHOP/web" > "$MOCK_DIR/cwd.100"
printf '%s\n' "$T/elsewhere" > "$MOCK_DIR/cwd.200"
cat > "$MOCK_DIR/docker.ps" <<EOF
{"ID":"a1","Names":"shop-db-1","Ports":"0.0.0.0:21003->5432/tcp, [::]:21003->5432/tcp","Labels":"com.docker.compose.project=shop,com.docker.compose.project.working_dir=$SHOP"}
{"ID":"b2","Names":"cache","Ports":"127.0.0.1:21008->6379/tcp","Labels":""}
{"ID":"c3","Names":"other-web-1","Ports":"0.0.0.0:21004->80/tcp","Labels":"com.docker.compose.project=other"}
EOF

table="$(pm list)"; rc=$?
check "list exits 0" '[ "$rc" = 0 ]'
check "list shows the ports in registry order" \
  '[ "$(printf "%s\n" "$table" | awk "NR > 1 { print \$1 \"/\" \$2 }" | tr "\n" " ")" = "shop/app shop/db shop/worker blog/app notes/app " ]'
check "a process running in the project folder is the project's own" \
  'printf "%s\n" "$table" | grep -E "^shop +app " | grep -q "in use: pid 100 node (this project)"'
check "a container of the same Compose project is the project's own, without its forwarder" \
  'printf "%s\n" "$table" | grep -E "^shop +db " | grep -q "in use: container shop-db-1 (this project)$"'
check "a container of another Compose project is another program" \
  'printf "%s\n" "$table" | grep -E "^shop +worker " | grep -q "container other-web-1 (another program)"'
check "a process outside the project folder is another program" \
  'printf "%s\n" "$table" | grep -E "^blog +app " | grep -q "pid 200 python3 (another program)"'
check "a process for a project without a folder has no owner label" \
  'printf "%s\n" "$table" | grep -E "^notes +app " | grep -q "in use: pid 600 ruby$"'
json="$(pm list --json)"
check "every JSON line parses and names its variable and owner" \
  'printf "%s\n" "$json" | python3 -c "import json,sys; r=[json.loads(l) for l in sys.stdin]; a=r[0]; sys.exit(0 if (a[\"variable\"], a[\"state\"], a[\"holders\"][0][\"owner\"]) == (\"PORT_APP\", \"in use\", \"this project\") and len(r) == 5 else 1)"'
pm list --project nothing >/dev/null 2>&1; rc=$?
check "list --project for an unknown project exits 1" '[ "$rc" = 1 ]'

# --- check
out="$(pm check)"
check "check without ports lists the registered ports in use" \
  '[ "$(printf "%s\n" "$out" | awk "NR > 1 { print \$1 }" | tr "\n" " ")" = "shop/app shop/db shop/worker blog/app notes/app " ]'
out="$(pm check 21007 3000 21001)"
check "check names a holder that is not registered" 'printf "%s\n" "$out" | grep -E "^21007 " | grep -q "pid 400 ControlCenter"'
check "check names a common default port" 'printf "%s\n" "$out" | grep -E "^3000 " | grep -q "free; the default port of"'
check "check names who registered a port" 'printf "%s\n" "$out" | grep -E "^21001 " | grep -q "registered to shop/app"'
pm check 0 >/dev/null 2>&1; rc=$?
check "check refuses port 0 with exit 2" '[ "$rc" = 2 ]'

# --- doctor
doc="$(pm doctor)"; rc=$?
dsection() { printf '%s\n' "$doc" | awk -v s="[$1]" 'index($0, s) == 1 { on = 1; print; next } /^\[/ { on = 0 } on && /^  /'; }
check "doctor exits 0" '[ "$rc" = 0 ]'
check "doctor reports a container of another Compose project as a collision, with a free port" \
  'dsection Collisions | grep -q "shop/worker  21004  container other-web-1. Free instead: 21006$"'
check "doctor reports a process of another folder as a collision, with the next free port" \
  'dsection Collisions | grep -q "blog/app  21002  pid 200 python3. Free instead: 21009$"'
check "doctor never offers the same free port twice" \
  '[ "$(dsection Collisions | grep -o "Free instead: [0-9]*" | sort | uniq -d | wc -l | tr -d " ")" = 0 ]'
check "doctor offers no port that is in use" '! dsection Collisions | grep -qE "Free instead: (21007|21008)$"'
check "doctor lists the ports in use by their own project" \
  'dsection "In use by its own project" | grep -q "shop/app" && dsection "In use by its own project" | grep -q "shop/db"'
check "doctor says when no folder is recorded" 'dsection "In use, owner unclear" | grep -q "notes/app  21005  pid 600 ruby. No folder is recorded for notes"'
check "doctor lists unregistered ports from lsof and docker, and only below 32768" \
  '[ "$(dsection Unregistered | awk "NR > 1 { print \$1 }" | tr "\n" " ")" = "21007 21008 " ]'
check "doctor counts the collisions as problems" 'printf "%s\n" "$doc" | grep -q "^2 problems found.$"'
check "doctor says how the listeners were read" 'printf "%s\n" "$doc" | grep -q "^Listeners   read with lsof"'
check "doctor says Docker is running" 'printf "%s\n" "$doc" | grep -q "^Docker      running$"'
touch "$MOCK_DIR/docker.down"
check "doctor says when Docker does not answer" 'pm doctor | grep -q "^Docker      installed but not answering"'
rm -f "$MOCK_DIR/docker.down"
PORTMAN_DOCKER="$T/bin/none" pm doctor > "$T/doc"
check "doctor runs without docker installed" 'grep -q "^Docker      not installed (optional)" "$T/doc" && ! grep -q "container" "$T/doc"'

# /proc/net is read when lsof is missing.
mkdir -p "$T/proc"
cat > "$T/proc/tcp" <<'EOF'
  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode
   0: 0100007F:51FE 00000000:0000 0A 00000000:00000000 00:00000000 00000000  1000        0 1 1
   1: 0100007F:51FF 0100007F:9C40 01 00000000:00000000 00:00000000 00000000  1000        0 2 1
EOF
out="$(PORTMAN_LSOF="$T/bin/none" PORTMAN_PROC_NET="$T/proc" PORTMAN_DOCKER="$T/bin/none" pm doctor)"
check "without lsof, doctor reads listening ports from /proc/net" \
  'printf "%s\n" "$out" | grep -q "^Listeners   read from" && printf "%s\n" "$out" | grep -qE "^  20990 +a program that could not be named"'
check "/proc/net rows that are not listening are skipped" '! printf "%s\n" "$out" | grep -qE "^  20991 "'
out="$(PORTMAN_LSOF="$T/bin/none" PORTMAN_DOCKER="$T/bin/none" pm doctor)"
check "without lsof or /proc/net, unregistered ports are unknown, not none" \
  'printf "%s\n" "$out" | grep -q "^\[Unregistered\] unknown" && ! printf "%s\n" "$out" | grep -q "^\[Unregistered\] none"'

# --- suggest
out="$(pm suggest --from 21000 --count 3)"; rc=$?
check "suggest exits 0" '[ "$rc" = 0 ]'
check "suggest skips registered ports and ports held according to lsof and docker" \
  '[ "$(printf "%s\n" "$out" | awk "NR > 1 { print \$1 }" | tr "\n" " ")" = "21000 21006 21009 " ]'
pm add blog spare 21000 >/dev/null
out="$(pm suggest --from 21000 --count 1)"
check "suggest skips a registered port that nothing uses" '[ "$(printf "%s\n" "$out" | awk "NR == 2 { print \$1 }")" = 21006 ]'
pm remove --confirm blog/spare=21000 >/dev/null
out="$(pm suggest --from 5170 --count 6)"
check "suggest skips common default ports" '! printf "%s\n" "$out" | grep -qE "^  (5173|5174)$"'
out="$(pm suggest --from 5173 --count 1 --allow-common)"
check "suggest --allow-common may offer a common default port" 'printf "%s\n" "$out" | grep -qE "^  5173$"'
pm suggest --from 40000 >/dev/null 2>&1; rc=$?
check "suggest refuses to start in the ephemeral range" '[ "$rc" = 2 ]'

# A real listener on 127.0.0.1, found only by the socket test.
base="$(python3 - <<'PY'
import socket
def free(port):
    for host in ("127.0.0.1", "0.0.0.0"):
        s = socket.socket()
        try:
            s.bind((host, port))
        except OSError:
            return False
        finally:
            s.close()
    return True
for start in range(22000, 26000, 41):
    if all(free(p) for p in range(start, start + 4)):
        print(start)
        break
PY
)"
python3 - "$base" "$T/ready" <<'PY' &
import socket, sys, time
s = socket.socket()
s.bind(("127.0.0.1", int(sys.argv[1])))
s.listen()
open(sys.argv[2], "w").close()
time.sleep(60)
PY
LISTENER=$!
for _ in $(seq 1 50); do [ -f "$T/ready" ] && break; sleep 0.1; done
out="$(PORTMAN_NO_PROBE=0 pm suggest --from "$base" --count 1)"
check "suggest skips a port a real program listens on" \
  '[ -n "$base" ] && [ "$(printf "%s\n" "$out" | awk "NR == 2 { print \$1 }")" = "$((base + 1))" ]'
out="$(PORTMAN_NO_PROBE=0 pm check "$base" "$((base + 1))")"
check "check finds a real listener and a free port" \
  'printf "%s\n" "$out" | grep -E "^$base " | grep -q "in use: a program that could not be named" && printf "%s\n" "$out" | grep -E "^$((base + 1)) " | grep -q "free"'
kill "$LISTENER" 2>/dev/null; LISTENER=""

# --- the registry is only read by list, check, suggest, and doctor
cp "$REG" "$T/reg.before"
pm list >/dev/null; pm check >/dev/null; pm suggest >/dev/null; pm doctor >/dev/null
check "list, check, suggest, and doctor leave the registry unchanged" 'same "$REG" "$T/reg.before"'

# --- remove
out="$(pm remove shop worker)"; rc=$?
check "remove without --confirm only previews" '[ "$rc" = 0 ] && printf "%s\n" "$out" | grep -q "^  shop/worker=21004$" && same "$REG" "$T/reg.before"'
check "the preview prints the command that removes exactly those entries" \
  'printf "%s\n" "$out" | grep -q "portman.py remove --confirm shop/worker=21004$"'
pm remove shop nothing >/dev/null 2>&1; rc=$?
check "previewing a name that is not registered exits 1" '[ "$rc" = 1 ]'
out="$(pm remove --confirm shop/worker=21099 --confirm shop/ghost=21098)"; rc=$?
check "an entry whose port changed after the preview is skipped" 'printf "%s\n" "$out" | grep -q "skipped shop/worker=21099: now registered as 21004"'
check "an entry that is gone is skipped" 'printf "%s\n" "$out" | grep -q "skipped shop/ghost=21098: no longer registered"'
check "skipped entries exit 3 and change nothing" '[ "$rc" = 3 ] && same "$REG" "$T/reg.before"'
out="$(pm remove --confirm shop/worker=21004)"; rc=$?
check "a confirmed entry that still matches is removed" '[ "$rc" = 0 ] && printf "%s\n" "$out" | grep -q "^removed shop/worker=21004$" && ! pm list | grep -qE "^shop +worker "'
pm remove --confirm notes/app=21005 >/dev/null
check "removing the last port of a project removes the project" '! pm list | grep -q "^notes "'
pm remove --confirm 'shop/app 21001' >/dev/null 2>&1; rc=$?
check "a --confirm item in another form exits 2" '[ "$rc" = 2 ]'
pm remove shop --confirm shop/app=21001 >/dev/null 2>&1; rc=$?
check "remove refuses a preview and --confirm together" '[ "$rc" = 2 ] && pm list | grep -qE "^shop +app "'

# --- doctor on a registry edited by hand
cp "$REG" "$T/reg.good"
python3 - "$REG" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
d["projects"]["blog"]["ports"].append({"name": "admin", "port": 21001})
d["projects"]["blog"]["ports"].append({"name": "admin", "port": 21020})
json.dump(d, open(sys.argv[1], "w"))
PY
chmod 644 "$REG"
doc="$(pm doctor)"
check "doctor lists a port registered twice" 'dsection Duplicates | grep -q "port 21001 is registered 2 times: shop/app, blog/admin"'
check "doctor lists a name repeated in a project" 'dsection Duplicates | grep -q "blog has the port name admin twice"'
check "doctor reports a registry others can read" 'printf "%s\n" "$doc" | grep -q "^Permissions .*registry.json can be read by others; run: chmod 600"'
cp "$T/reg.good" "$REG"; chmod 600 "$REG"
printf '{"version": 2, "projects": {}}\n' > "$REG"
pm list >/dev/null 2>"$T/err"; rc=$?
check "a registry of another format version is refused with exit 2" '[ "$rc" = 2 ] && grep -q "format version 2" "$T/err"'
pm add shop api 21030 >/dev/null 2>&1; rc=$?
check "add does not write over a registry it cannot read" '[ "$rc" = 2 ] && grep -q "\"version\": 2" "$REG"'
printf '{"version": 1, "projects": {"shop": {"ports": [{"name": "app", "port": "21001"}]}}}\n' > "$REG"
pm doctor >/dev/null 2>"$T/err"; rc=$?
check "an entry with a port that is not a number is refused with exit 2" '[ "$rc" = 2 ] && grep -q "shop/app: port" "$T/err"'
printf 'not json' > "$REG"
pm list >/dev/null 2>&1; rc=$?
check "a registry that is not JSON is refused with exit 2" '[ "$rc" = 2 ]'
cp "$T/reg.good" "$REG"; chmod 600 "$REG"

# --- apply
rm -f "$MOCK_DIR/lsof.listen" "$MOCK_DIR/docker.ps"
P="$T/projects/shop"
git init -q "$P"
printf 'NODE_ENV=development\nPORT=9999\n# keep this comment\nSESSION_SECRET=placeholder-value-42' > "$P/.env.local"
cat > "$P/docker-compose.yml" <<'EOF'
x-common: &common
  restart: unless-stopped

services:
  app:
    build: .
    ports:
      - "${WEB_PORT:-3000}:3000"   # the dev server
      - "9229:9229"
  postgres:
    image: postgres:16
    ports:
      - target: 5432
        published: 5432
        host_ip: 127.0.0.1
  worker:
    <<: *common
    image: busybox
    ports: ["7070:7070"]
EOF
cp "$P/.env.local" "$T/env.before"
pm remove --confirm shop/app=21001 >/dev/null
pm add shop app 21011 --dir "$P" --target 3000 >/dev/null
pm add shop worker 21012 >/dev/null
pm add shop docs 21013 --target 8080 >/dev/null
cp "$REG" "$T/reg.before"
prev="$(pm apply --dir "$P")"; rc=$?
token="$(printf '%s\n' "$prev" | sed -nE 's/.*--confirm ([0-9a-f]{12})$/\1/p')"
check "the apply preview exits 0 and prints a token" '[ "$rc" = 0 ] && [ -n "$token" ]'
check "the preview writes nothing" 'same "$P/.env.local" "$T/env.before" && [ ! -e "$P/docker-compose.override.yml" ] && same "$REG" "$T/reg.before"'
check "the preview shows the new lines of the env file" 'printf "%s\n" "$prev" | grep -q "^  +PORT_APP=21011$"'
check "the preview never prints a line of the env file outside the block" '! printf "%s\n" "$prev" | grep -qE "placeholder-value-42|NODE_ENV|keep this comment"'
check "the preview names a variable also set outside the block" 'printf "%s\n" "$prev" | grep -q "Line 2 of .env.local also sets PORT"'
check "the preview says the env file is not ignored by git" 'printf "%s\n" "$prev" | grep -q ".env.local is not ignored by git"'
check "the preview leaves a service with merges alone" 'printf "%s\n" "$prev" | grep -q "The ports of service worker use a layout portman does not read"'
check "the preview names a port with no matching service" 'printf "%s\n" "$prev" | grep -q "no service named docs, so shop/docs goes only to .env.local"'
pm apply --dir "$P" --confirm 000000000000 >/dev/null 2>&1; rc=$?
check "a wrong token exits 3 and writes nothing" '[ "$rc" = 3 ] && same "$P/.env.local" "$T/env.before" && [ ! -e "$P/docker-compose.override.yml" ]'
out="$(pm apply --dir "$P" --confirm "$token")"; rc=$?
check "apply with the token exits 0 and gives the address" '[ "$rc" = 0 ] && printf "%s\n" "$out" | grep -q "^Open http://localhost:21011$"'
check "the env file keeps every other line as it was" \
  '[ "$(head -c "$(wc -c < "$T/env.before")" "$P/.env.local")" = "$(cat "$T/env.before")" ]'
block="$(sed -n '/^# >>> portman >>>$/,/^# <<< portman <<<$/p' "$P/.env.local")"
check "the block sets PORT to the app port and one variable per port" \
  '[ "$block" = "$(printf "# >>> portman >>>\nPORT=21011\nPORT_DB=21003\nPORT_APP=21011\nPORT_WORKER=21012\nPORT_DOCS=21013\n# <<< portman <<<")" ]'
O="$P/docker-compose.override.yml"
check "the override starts with the portman line" 'head -1 "$O" | grep -q "^# Written by portman"'
check "the override replaces the ports of a service that has them" 'grep -A1 "^  app:$" "$O" | grep -q "^    ports: !override$"'
check "the override maps the registered port to the container port of an interpolated mapping" 'grep -q "^      - \"21011:3000\"$" "$O"'
check "the override keeps a mapping no registered port points at" 'grep -q "^      - \"9229:9229\"$" "$O"'
check "the override uses --service and --target and keeps the host address" \
  'grep -A2 "^  postgres:$" "$O" | grep -q "^      - \"127.0.0.1:21003:5432\"$"'
check "the override leaves the unreadable service out" '! grep -q "worker" "$O"'
check "a new override is readable only by you" '[ "$(mode "$O")" = 0o600 ]'
check "apply records the project folder" 'pm list --json | python3 -c "import json,sys; sys.exit(0 if json.loads(sys.stdin.readline())[\"dir\"] == sys.argv[1] else 1)" "$SHOP"'
out="$(pm apply --dir "$P")"
check "a second preview has nothing to change" 'printf "%s\n" "$out" | grep -q "Nothing to change" && ! printf "%s\n" "$out" | grep -q -- "--confirm"'

# Changing a port rewrites only the block, in place.
cp "$P/.env.local" "$T/env.applied"
pm remove --confirm shop/worker=21012 >/dev/null
pm add shop worker 21014 >/dev/null
prev="$(pm apply --dir "$P")"
token="$(printf '%s\n' "$prev" | sed -nE 's/.*--confirm ([0-9a-f]{12})$/\1/p')"
check "a preview of an existing block shows no line next to it" '! printf "%s\n" "$prev" | grep -q "placeholder-value-42" && printf "%s\n" "$prev" | grep -q "^  -PORT_WORKER=21012$"'
pm apply --dir "$P" --confirm "$token" >/dev/null
outside() { sed '/^# >>> portman >>>$/,/^# <<< portman <<<$/d' "$1"; }
check "a second apply rewrites the block in place and keeps one block" \
  '[ "$(grep -c "^# >>> portman >>>$" "$P/.env.local")" = 1 ] && grep -q "^PORT_WORKER=21014$" "$P/.env.local" && ! grep -q 21012 "$P/.env.local"'
check "a second apply leaves the lines outside the block as they were" '[ "$(outside "$T/env.applied")" = "$(outside "$P/.env.local")" ]'

# The registry changes between the preview and the approval.
token="$(pm apply --dir "$P" | sed -nE 's/.*--confirm ([0-9a-f]{12})$/\1/p')"
pm remove --confirm shop/docs=21013 >/dev/null
cp "$P/.env.local" "$T/env.applied"
pm apply --dir "$P" --confirm "${token:-none}" >/dev/null 2>&1; rc=$?
check "apply after the registry changed exits 3 and writes nothing" '[ "$rc" = 3 ] && same "$P/.env.local" "$T/env.applied"'

# The env file changes between the preview and the approval.
pm add shop docs 21013 --target 8080 >/dev/null
token="$(pm apply --dir "$P" | sed -nE 's/.*--confirm ([0-9a-f]{12})$/\1/p')"
printf 'EXTRA=1\n' >> "$P/.env.local"
cp "$P/.env.local" "$T/env.edited"
pm apply --dir "$P" --confirm "$token" >/dev/null 2>&1; rc=$?
check "apply after the env file changed exits 3 and writes nothing" '[ "$rc" = 3 ] && same "$P/.env.local" "$T/env.edited"'

# An override portman did not write is never replaced.
Q="$T/projects/blog"
printf 'services:\n  app:\n    image: nginx\n    ports:\n      - 8080:80\n' > "$Q/docker-compose.yml"
printf 'services:\n  app:\n    environment:\n      DEBUG: "1"\n' > "$Q/docker-compose.override.yml"
cp "$Q/docker-compose.override.yml" "$T/override.before"
out="$(pm apply --dir "$Q")"
token="$(printf '%s\n' "$out" | sed -nE 's/.*--confirm ([0-9a-f]{12})$/\1/p')"
check "an override written by someone else is left out, with the lines to add by hand" \
  'printf "%s\n" "$out" | grep -q "docker-compose.override.yml exists and was not written by portman" && printf "%s\n" "$out" | grep -q "\"21002:80\""'
pm apply --dir "$Q" --confirm "$token" >/dev/null
check "applying then writes only the env file" 'same "$Q/docker-compose.override.yml" "$T/override.before" && grep -q "^PORT_APP=21002$" "$Q/.env.local"'
check "a new env file is readable only by you" '[ "$(mode "$Q/.env.local")" = 0o600 ]'

# A service without ports needs --target; an old Compose gets a note; compose.yaml gets compose.override.yaml.
R="$T/projects/api"
mkdir -p "$R"
printf 'services:\n  api:\n    image: api\n  web:\n    image: web\n    ports:\n      - "3000:3000"\n' > "$R/compose.yaml"
pm add api api 21021 --dir "$R" >/dev/null
pm add api web 21022 >/dev/null
printf '2.20.3\n' > "$MOCK_DIR/compose.version"
out="$(pm apply --dir "$R")"
check "a service that publishes no ports asks for --target" 'printf "%s\n" "$out" | grep -q "Service api publishes no ports, so portman cannot tell which container port api/api is"'
check "a Compose older than 2.24 gets a note about !override" 'printf "%s\n" "$out" | grep -q "Docker Compose 2.20.3 does not read !override"'
check "compose.yaml gets compose.override.yaml" 'printf "%s\n" "$out" | grep -q "^compose.override.yaml (new file)$"'
rm -f "$MOCK_DIR/compose.version"
pm remove --confirm api/api=21021 >/dev/null
pm add api api 21021 --target 8000 >/dev/null
out="$(pm apply --dir "$R")"
check "with --target, a service without ports gets a plain ports list" \
  'printf "%s\n" "$out" | grep -A2 "^  +  api:$" | grep -q "^  +    ports:$" && printf "%s\n" "$out" | grep -q "^  +      - \"21021:8000\"$"'

# A broken block, a missing project, and a folder without a Compose file.
printf 'A=1\n# >>> portman >>>\nPORT=1\n' > "$Q/.env.local"
cp "$Q/.env.local" "$T/env.broken"
pm apply --dir "$Q" >/dev/null 2>"$T/err"; rc=$?
check "an incomplete block is refused with exit 1 and left as it is" '[ "$rc" = 1 ] && grep -q "incomplete or repeated portman block" "$T/err" && same "$Q/.env.local" "$T/env.broken"'
mkdir -p "$T/projects/unknown"
pm apply --dir "$T/projects/unknown" >/dev/null 2>"$T/err"; rc=$?
check "apply for a folder with no registered project exits 1" '[ "$rc" = 1 ] && grep -q "No ports are registered for unknown" "$T/err"'
S="$T/projects/plain"
mkdir -p "$S"
printf '.env.local\n' > "$S/.gitignore"
git init -q "$S"
pm add plain app 21031 >/dev/null
out="$(cd "$S" && pm apply --project plain)"
check "without a Compose file, apply plans only the env file" \
  'printf "%s\n" "$out" | grep -q "^.env.local (new file)$" && ! printf "%s\n" "$out" | grep -q "override"'
check "an env file that git ignores gets no note" '! printf "%s\n" "$out" | grep -q "not ignored by git"'
check "apply uses the current git folder when --dir is not given" 'printf "%s\n" "$out" | grep -q "^Project plain, folder $(cd "$S" && pwd -P)$"'

# Paths under the home folder are printed with ~, and the printed command works as it is.
H="$HOME/projects/site"
mkdir -p "$H"
pm add site app 21041 --dir "$H" > "$T/out"
check "add prints a folder under the home folder with ~" 'grep -q "^Recorded ~/projects/site as the folder of site$" "$T/out"'
out="$(pm apply --dir "$H")"
check "the apply preview prints the folder with ~" 'printf "%s\n" "$out" | grep -q "^Project site, folder ~/projects/site$"'
cmd="$(printf '%s\n' "$out" | sed -n 's/^  portman\.py //p')"
eval "pm $cmd" > "$T/out"; rc=$?
check "the command the preview prints writes the files" '[ "$rc" = 0 ] && grep -q "^Wrote .env.local$" "$T/out" && grep -q "^PORT_APP=21041$" "$H/.env.local"'

# Without PORTMAN_HOME, the registry lives in ~/.local/share/portman.
(
  unset PORTMAN_HOME
  pm add home app 21051 >/dev/null
  check "without PORTMAN_HOME the registry is in ~/.local/share/portman, readable only by you" \
    '[ "$(mode "$HOME/.local/share/portman")" = 0o700 ] && [ "$(mode "$HOME/.local/share/portman/registry.json")" = 0o600 ]'
  check "doctor prints the default registry path with ~" 'pm doctor | grep -q "^Registry    ~/.local/share/portman/registry.json, 1 project, 1 port$"'
  printf '%d %d\n' "$PASS" "$FAIL" > "$T/sub"
)
read -r PASS FAIL < "$T/sub"

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
