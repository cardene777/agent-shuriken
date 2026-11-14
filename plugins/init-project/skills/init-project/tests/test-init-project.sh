#!/usr/bin/env bash
# Tests for init_project.py against throwaway projects under a throwaway HOME.
# Nothing reaches the network: stand-ins mark op and docker as installed, ports are probed and
# served on 127.0.0.1 only, and every output is checked for the values in the env files.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$HERE/../scripts"
SCRIPT="$SCRIPTS/init_project.py"
PASS=0
FAIL=0
T="$(mktemp -d)"
PIDS=()
cleanup() {
  for p in "${PIDS[@]:-}"; do [ -n "$p" ] && kill "$p" 2>/dev/null; done
  rm -rf "$T"
}
trap cleanup EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }

export HOME="$T/home"
export GIT_CONFIG_NOSYSTEM=1
# Importing the script must not leave a __pycache__ folder inside the plugin.
export PYTHONDONTWRITEBYTECODE=1
export INIT_PROJECT_HOME="$T/state"
export INIT_PROJECT_OP="$T/bin/op"
export INIT_PROJECT_DOCKER="$T/bin/docker"
mkdir -p "$HOME" "$T/bin" "$T/www"
git config --global user.name "Ada Example"
git config --global user.email ada@example.com
git config --global init.defaultBranch main
for tool in op docker; do printf '#!/bin/sh\nexit 0\n' > "$T/bin/$tool"; chmod +x "$T/bin/$tool"; done

ALL="$T/all-output.txt"
# r <args>: run the script, keep stdout in $out, stderr in $err, the exit code in $rc, and add both to $ALL.
r() {
  python3 "$SCRIPT" "$@" > "$T/out" 2> "$T/err"; rc=$?
  cat "$T/out" "$T/err" >> "$ALL"
  out="$(cat "$T/out")"; err="$(cat "$T/err")"
}
plan_id() { printf '%s\n' "$out" | sed -nE 's/^Plan ([0-9a-f]{8}) .*/\1/p'; }
mode_of() { python3 -c 'import os,sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$1"; }
snapshot() { (cd "$1" && find . -path ./.git -prune -o -print | LC_ALL=C sort | while IFS= read -r f; do
  if [ -f "$f" ]; then printf '%s %s\n' "$f" "$(cksum < "$f")"; else printf '%s\n' "$f"; fi; done); }

# A base port with 12 free ports after it, none of them in the script's busy list.
BASE="$(python3 - "$SCRIPTS" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import init_project as m
for base in range(41000, 60000, 37):
    span = range(base, base + 12)
    if not any(p in m.BUSY_PORTS or m.port_in_use(p) for p in span):
        print(base)
        break
PY
)"
# listen <port>: keep a socket listening on 127.0.0.1:<port> until the tests end.
listen() {
  python3 -c 'import socket,sys,time
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", int(sys.argv[1]))); s.listen(); open(sys.argv[2], "w").write("ready"); time.sleep(600)' "$1" "$T/ready-$1" &
  PIDS+=("$!")
  for _ in $(seq 1 50); do [ -f "$T/ready-$1" ] && return 0; sleep 0.1; done
  return 1
}

# --- a Next.js project with pnpm, several env files, and one env file committed to git
P="$T/shop"
mkdir -p "$P/packages/api"
cat > "$P/package.json" <<'JSON'
{"name": "shop", "packageManager": "pnpm@9.12.0", "scripts": {"dev": "next dev", "build": "next build"},
 "dependencies": {"next": "15.0.0", "react": "19.0.0"}}
JSON
: > "$P/pnpm-lock.yaml"
printf '20\n' > "$P/.nvmrc"
printf 'node_modules\n.env*\n' > "$P/.gitignore"
cat > "$P/.env" <<'ENV'
DATABASE_URL=postgres://shop:SECRETVALUE1@db:5432/shop
export STRIPE_SECRET_KEY="SECRETVALUE2"
NEXT_PUBLIC_SITE_URL=http://localhost:3000
PRIVATE_KEY="-----BEGIN PRIVATE KEY-----
SECRETVALUE3abcdEFGH==
FAKE_NAME=SECRETVALUE4
-----END PRIVATE KEY-----"
# COMMENTED=SECRETVALUE5
API_TOKEN='SECRETVALUE6'
ENV
printf 'SESSION_SECRET=SECRETVALUE7\n' > "$P/.env.local"
printf 'EXAMPLE_ONLY=placeholder\n' > "$P/.env.example"
printf 'JWT_SECRET=SECRETVALUE8\n' > "$P/packages/api/.env.dev"
git init -q "$P"
git -C "$P" add package.json .gitignore
git -C "$P" add -f packages/api/.env.dev
git -C "$P" commit -qm init

r detect --dir "$P"
check "detect exits 0" '[ "$rc" = 0 ]'
check "a package.json with a dev script is a web app" 'printf "%s\n" "$out" | grep -q "^kind  *web-app (package.json has a dev script)"'
check "the Node version comes from .nvmrc and the package manager from the lockfile" \
  'printf "%s\n" "$out" | grep -q "^runtime  *node 20 from .nvmrc, pnpm from pnpm-lock.yaml"'
check "Next.js is named as the framework" 'printf "%s\n" "$out" | grep -q "^framework  *next"'
check "env files are listed with their name counts and whether git tracks them" \
  'printf "%s\n" "$out" | grep -q "^env files  *.env (5 names), .env.local (1 name), packages/api/.env.dev (1 name, committed to git)"'
check "an .env.example is not read as an env file" '! printf "%s\n" "$out" | grep -q "env.example"'
r detect --dir "$P" --json
check "only the names before = are read, never lines inside a quoted multi-line value" \
  'printf "%s\n" "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); n=[e for e in d[\"env_files\"] if e[\"path\"]==\".env\"][0][\"names\"]; sys.exit(0 if n==[\"DATABASE_URL\",\"STRIPE_SECRET_KEY\",\"NEXT_PUBLIC_SITE_URL\",\"PRIVATE_KEY\",\"API_TOKEN\"] else 1)"'

before="$(snapshot "$P"; git -C "$P" status --porcelain)"
r plan --dir "$P" --docker --env --vault Personal --from "$BASE"
id="$(plan_id)"
check "plan exits 0 and prints a plan id" '[ "$rc" = 0 ] && [ -n "$id" ]'
check "plan writes nothing into the project" '[ "$before" = "$(snapshot "$P"; git -C "$P" status --porcelain)" ]'
check "the plan is kept readable only by you" \
  '[ "$(mode_of "$INIT_PROJECT_HOME/plans/$id.json")" = 0o600 ] && [ "$(mode_of "$INIT_PROJECT_HOME")" = 0o700 ] && [ "$(mode_of "$INIT_PROJECT_HOME/plans")" = 0o700 ]'
check "the plan holds no value from the env files" '! grep -rq SECRETVALUE "$INIT_PROJECT_HOME"'
check "the first free port from --from is picked" 'printf "%s\n" "$out" | grep -q "^  port     $BASE for the app service (free)"'
check "the Dockerfile uses the Node version from .nvmrc and the pinned pnpm" \
  'printf "%s\n" "$out" | grep -q "^    FROM node:20-alpine$" && printf "%s\n" "$out" | grep -q "^    RUN npm install -g pnpm@9.12.0$"'
check "the Dockerfile runs the dev script with pnpm" 'printf "%s\n" "$out" | grep -qF "    CMD [\"pnpm\", \"run\", \"dev\"]"'
compose="$(printf '%s\n' "$out" | awk '/^\[create\] docker-compose.yml/ { on = 1; next } /^\[/ { on = 0 } on')"
check "the committed compose file has no ports" '! printf "%s\n" "$compose" | grep -q "ports:"'
check "the compose file passes the root env names through to the container" \
  'printf "%s\n" "$compose" | grep -qx "          - DATABASE_URL" && printf "%s\n" "$compose" | grep -qx "          - PRIVATE_KEY" && ! printf "%s\n" "$compose" | grep -q JWT_SECRET'
check "the local port is bound to 127.0.0.1 in the override file" \
  'printf "%s\n" "$out" | grep -qF "      - \"127.0.0.1:$BASE:3000\""'
check "each env file gets references in its own section" \
  'printf "%s\n" "$out" | grep -qx "    DATABASE_URL=op://Personal/shop/env/DATABASE_URL" &&
   printf "%s\n" "$out" | grep -qx "    SESSION_SECRET=op://Personal/shop/env_local/SESSION_SECRET" &&
   printf "%s\n" "$out" | grep -qx "    JWT_SECRET=op://Personal/shop/packages_api_env_dev/JWT_SECRET"'
check ".gitignore keeps the templates in and the override out, and skips what is already ignored" \
  'printf "%s\n" "$out" | grep -qx "    + !.env.tpl" && printf "%s\n" "$out" | grep -qx "    + !packages/api/.env.dev.tpl" &&
   printf "%s\n" "$out" | grep -qx "    + docker-compose.override.yml" && ! printf "%s\n" "$out" | grep -qx "    + .env"'
check "the import commands take values from the env file in a subshell, never inline" \
  'printf "%s\n" "$out" | grep -qF "( set -a; . ./.env; set +a; op item edit shop --vault Personal \"env.DATABASE_URL[concealed]=\${DATABASE_URL-}\""'
check "public settings are stored as text and secrets as concealed" \
  'printf "%s\n" "$out" | grep -qF "\"env.NEXT_PUBLIC_SITE_URL[text]=" && printf "%s\n" "$out" | grep -qF "\"env.API_TOKEN[concealed]="'
check "an env file committed to git is named with a warning" \
  'printf "%s\n" "$out" | grep -q "^Note: packages/api/.env.dev is committed to git"'
planned_dockerfile="$(printf '%s\n' "$out" | awk '/^\[create\] Dockerfile/ { on = 1; next } /^$/ { on = 0 } on' | sed 's/^    //')"

r apply "$id"
check "apply exits 0" '[ "$rc" = 0 ]'
check "apply writes the files the plan showed" \
  '[ "$(cat "$P/Dockerfile")" = "$planned_dockerfile" ] && [ -f "$P/docker-compose.yml" ] && [ -f "$P/docker-compose.override.yml" ] && [ -f "$P/.env.tpl" ] && [ -f "$P/packages/api/.env.dev.tpl" ]'
check "git keeps the templates and ignores the override and the env files" \
  '! git -C "$P" check-ignore -q .env.tpl && ! git -C "$P" check-ignore -q packages/api/.env.dev.tpl &&
   git -C "$P" check-ignore -q docker-compose.override.yml && git -C "$P" check-ignore -q .env.local'
check "the port is recorded in a file readable only by you" \
  '[ "$(mode_of "$INIT_PROJECT_HOME/ports.json")" = 0o600 ] && grep -q "\"port\": $BASE" "$INIT_PROJECT_HOME/ports.json"'
check "an applied plan is removed" '[ ! -e "$INIT_PROJECT_HOME/plans/$id.json" ]'
r apply "$id"
check "applying the same plan twice exits 1" '[ "$rc" = 1 ]'
check "no written file holds a value from the env files" \
  '! grep -q SECRETVALUE "$P/Dockerfile" "$P/docker-compose.yml" "$P/docker-compose.override.yml" "$P/.env.tpl" "$P/.env.local.tpl" "$P/.gitignore"'

r plan --dir "$P" --docker --env --vault Personal --from "$BASE"
check "a second plan reuses the port from the override file and writes nothing" \
  '[ "$rc" = 0 ] && printf "%s\n" "$out" | grep -q "^  port     $BASE for the app service (set in docker-compose.override.yml)" &&
   printf "%s\n" "$out" | grep -q "^Nothing to write" && [ -z "$(ls "$INIT_PROJECT_HOME/plans")" ]'

printf 'LEGACY=SECRETVALUE9\n' >> "$P/.env.tpl"
printf 'NEW_KEY=SECRETVALUE10\n' >> "$P/.env"
r plan --dir "$P" --env --vault Personal --env-file .env
id="$(plan_id)"
check "a new name in the env file is appended to the existing template, alone" \
  'printf "%s\n" "$out" | grep -qx "\[append\] .env.tpl" && printf "%s\n" "$out" | grep -qx "    + NEW_KEY=op://Personal/shop/env/NEW_KEY" &&
   [ "$(printf "%s\n" "$out" | grep -c "^    + ")" = 1 ]'
r apply "$id"
check "appending keeps the lines already in the template" \
  '[ "$rc" = 0 ] && [ "$(tail -1 "$P/.env.tpl")" = "NEW_KEY=op://Personal/shop/env/NEW_KEY" ] && grep -q "^LEGACY=" "$P/.env.tpl"'

# --- port picking and the checks right before writing
Q="$T/api"
mkdir -p "$Q"
printf 'fastapi\nuvicorn[standard]\n' > "$Q/requirements.txt"
printf 'app = None\n' > "$Q/main.py"
printf '3.12\n' > "$Q/.python-version"
listen $((BASE + 1))
r plan --dir "$Q" --docker --from "$BASE"
id="$(plan_id)"
check "a port recorded for another project and a port in use are both skipped" \
  'printf "%s\n" "$out" | grep -q "^  port     $((BASE + 2)) for the app service (free)"'
check "a FastAPI project gets a Python image, its requirements, and uvicorn" \
  'printf "%s\n" "$out" | grep -qx "    FROM python:3.12-slim" && printf "%s\n" "$out" | grep -qx "    RUN pip install --no-cache-dir -r requirements.txt" &&
   printf "%s\n" "$out" | grep -qF "    CMD [\"uvicorn\", \"main:app\", \"--host\", \"0.0.0.0\", \"--port\", \"8000\", \"--reload\"]"'
r discard "$id"
check "discard removes the plan" '[ "$rc" = 0 ] && [ ! -e "$INIT_PROJECT_HOME/plans/$id.json" ]'
r plan --dir "$Q" --docker --port $((BASE + 1))
check "asking for a port in use exits 6" '[ "$rc" = 6 ]'
r plan --dir "$Q" --docker --port "$BASE"
check "asking for a port recorded for another project exits 6" '[ "$rc" = 6 ] && printf "%s\n" "$err" | grep -q "another project"'
r plan --dir "$Q" --docker --from 27017
picked="$(printf '%s\n' "$out" | sed -nE 's/^  port     ([0-9]+) .*/\1/p')"
check "well-known ports are skipped when picking" '[ -n "$picked" ] && [ "$picked" -gt 27017 ]'
r plan --dir "$Q" --docker --from $((BASE + 3))
id="$(plan_id)"
listen $((BASE + 3))
r apply "$id"
check "a picked port that came into use before apply skips the override and the record" \
  '[ "$rc" = 4 ] && printf "%s\n" "$out" | grep -q "^Skipped docker-compose.override.yml: port $((BASE + 3)) came into use" &&
   [ ! -e "$Q/docker-compose.override.yml" ] && [ -f "$Q/Dockerfile" ] && ! grep -q "$Q" "$INIT_PROJECT_HOME/ports.json"'

# --- existing files: never replaced without --overwrite, and re-checked before writing
V="$T/site"
mkdir -p "$V"
printf '{"scripts": {"dev": "vite"}, "devDependencies": {"vite": "6.0.0"}}\n' > "$V/package.json"
printf '{}\n' > "$V/package-lock.json"
r plan --dir "$V" --docker --from $((BASE + 4))
id="$(plan_id)"
check "a Vite dev server is told to listen on every address inside the container" \
  'printf "%s\n" "$out" | grep -qF "    CMD [\"npm\", \"run\", \"dev\", \"--\", \"--host\", \"0.0.0.0\"]" && printf "%s\n" "$out" | grep -qx "    EXPOSE 5173"'
printf 'FROM scratch\n' > "$V/Dockerfile"
r apply "$id"
check "a file created after the plan is skipped, and the rest is written" \
  '[ "$rc" = 4 ] && printf "%s\n" "$out" | grep -q "^Skipped Dockerfile: it was created after the plan" &&
   [ "$(cat "$V/Dockerfile")" = "FROM scratch" ] && [ -f "$V/docker-compose.yml" ]'
check "outside git, .gitignore is created with the override line" 'grep -qx "docker-compose.override.yml" "$V/.gitignore"'
rm -f "$V/docker-compose.yml" "$V/docker-compose.override.yml"
r plan --dir "$V" --docker
check "an existing Dockerfile is kept unless --overwrite names it" \
  'printf "%s\n" "$out" | grep -q "^\[skip\] Dockerfile: already exists; add --overwrite Dockerfile to replace it"'
r plan --dir "$V" --docker --overwrite Dockerfile
id="$(plan_id)"
check "--overwrite shows the change as a diff" \
  'printf "%s\n" "$out" | grep -qx "\[overwrite\] Dockerfile" && printf "%s\n" "$out" | grep -qx "    -FROM scratch" && printf "%s\n" "$out" | grep -qx "    +FROM node:24-alpine"'
printf 'FROM busybox\n' > "$V/Dockerfile"
r apply "$id"
check "a file that changed after the plan is not replaced" '[ "$rc" = 4 ] && [ "$(cat "$V/Dockerfile")" = "FROM busybox" ]'
r plan --dir "$V" --docker --overwrite Dockerfile
r apply "$(plan_id)"
check "--overwrite replaces the file after approval" '[ "$rc" = 0 ] && grep -qx "FROM node:24-alpine" "$V/Dockerfile"'
r plan --dir "$V" --docker --overwrite .env
check "env files can never be overwritten" '[ "$rc" = 2 ]'
r plan --dir "$V" --docker --overwrite package.json
check "--overwrite accepts only the Docker files of the plan" '[ "$rc" = 2 ]'

# --- an existing compose file: only the local port is added, for the service you name
W="$T/legacy"
mkdir -p "$W"
printf '{"scripts": {"start": "node server.js"}}\n' > "$W/package.json"
cat > "$W/compose.yaml" <<'YAML'
services:
    web:
        build: .
    db:
        image: postgres:16
YAML
r plan --dir "$W" --docker
check "with several services and no --service, plan exits 2 and names them" '[ "$rc" = 2 ] && printf "%s\n" "$err" | grep -q "web, db"'
r plan --dir "$W" --docker --service nope
check "an unknown --service exits 2" '[ "$rc" = 2 ]'
r plan --dir "$W" --docker --service web --container-port 8080 --from $((BASE + 5))
check "only an override named after compose.yaml is planned, for that service" \
  '[ "$rc" = 0 ] && printf "%s\n" "$out" | grep -qx "\[create\] compose.override.yaml" && printf "%s\n" "$out" | grep -qx "      web:" &&
   printf "%s\n" "$out" | grep -qF "\"127.0.0.1:$((BASE + 5)):8080\"" && ! printf "%s\n" "$out" | grep -q "\[create\] Dockerfile"'

# --- local chains
C="$T/chain"
mkdir -p "$C"
: > "$C/foundry.toml"
printf '{"scripts": {"dev": "x"}}\n' > "$C/package.json"
r detect --dir "$C" --json
check "foundry.toml makes a smart-contract project before package.json is read" \
  'printf "%s\n" "$out" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if (d[\"kind\"], d[\"framework\"]) == (\"smart-contract\", \"foundry\") else 1)"'
r plan --dir "$C" --docker --from $((BASE + 6))
check "a Foundry project gets an anvil service from the Foundry image and no Dockerfile" \
  'printf "%s\n" "$out" | grep -qx "        image: ghcr.io/foundry-rs/foundry:latest" && printf "%s\n" "$out" | grep -qF "command: [\"anvil --host 0.0.0.0\"]" &&
   printf "%s\n" "$out" | grep -qF "\"127.0.0.1:$((BASE + 6)):8545\"" && ! printf "%s\n" "$out" | grep -q "\[create\] Dockerfile"'
H="$T/hardhat"
mkdir -p "$H"
: > "$H/hardhat.config.ts"
printf '{"devDependencies": {"hardhat": "2.22.0"}}\n' > "$H/package.json"
: > "$H/yarn.lock"
r plan --dir "$H" --docker --from $((BASE + 7))
check "a Hardhat project runs hardhat node with yarn installs" \
  'printf "%s\n" "$out" | grep -qF "    CMD [\"npx\", \"hardhat\", \"node\", \"--hostname\", \"0.0.0.0\"]" &&
   printf "%s\n" "$out" | grep -qx "    RUN yarn --version >/dev/null 2>&1 || npm install -g yarn" && printf "%s\n" "$out" | grep -qx "      chain:"'

# --- kinds
kind_of() { python3 "$SCRIPT" detect --dir "$1" --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["kind"])'; }
mk() { mkdir -p "$T/k/$1"; printf '%s' "$3" > "$T/k/$1/$2"; }
mk cli package.json '{"bin": {"tool": "cli.js"}}'
mk lib package.json '{"name": "lib"}'
mk rustbin Cargo.toml '[package]'; mkdir -p "$T/k/rustbin/src"; : > "$T/k/rustbin/src/main.rs"
mk rustlib Cargo.toml '[lib]'
mk django pyproject.toml '[project]
dependencies = ["django>=5"]'
mk flask requirements.txt 'Flask==3.0'
mk flaskext requirements.txt 'flask-sqlalchemy'
mk pylib setup.py ''
mkdir -p "$T/k/empty"
check "a package.json with a bin field is a cli" '[ "$(kind_of "$T/k/cli")" = cli ]'
check "a package.json without scripts is a library" '[ "$(kind_of "$T/k/lib")" = library ]'
check "a Cargo project with src/main.rs is a cli" '[ "$(kind_of "$T/k/rustbin")" = cli ]'
check "a Cargo project with [lib] is a library" '[ "$(kind_of "$T/k/rustlib")" = library ]'
check "a pyproject that depends on django is a web app" '[ "$(kind_of "$T/k/django")" = web-app ]'
check "requirements with Flask make a web app" '[ "$(kind_of "$T/k/flask")" = web-app ]'
check "a Flask extension alone does not make a web app" '[ "$(kind_of "$T/k/flaskext")" = library ]'
check "setup.py alone is a library" '[ "$(kind_of "$T/k/pylib")" = library ]'
check "a folder without a manifest is unknown" '[ "$(kind_of "$T/k/empty")" = unknown ]'
r plan --dir "$T/k/flask" --docker --from $((BASE + 8))
check "a Flask project runs flask on port 5000 in the container" \
  'printf "%s\n" "$out" | grep -qF "    CMD [\"flask\", \"run\", \"--host\", \"0.0.0.0\", \"--port\", \"5000\", \"--debug\"]"'
r plan --dir "$T/k/lib" --docker
check "--docker for a library exits 5" '[ "$rc" = 5 ]'
r plan --dir "$T/k/lib"
check "a plan without --docker, --assign-port, or --env exits 2" '[ "$rc" = 2 ]'

N="$T/nuxt"
mkdir -p "$N"
printf '{"scripts": {"dev": "nuxt dev"}, "dependencies": {"nuxt": "3.0.0"}}\n' > "$N/package.json"
: > "$N/bun.lock"
before="$(snapshot "$N")"
r plan --dir "$N" --assign-port --from $((BASE + 9))
id="$(plan_id)"
check "--assign-port plans only the port and says how to start on it" \
  'printf "%s\n" "$out" | grep -q "Start it on port $((BASE + 9)) with: bun run dev --port $((BASE + 9))" && ! printf "%s\n" "$out" | grep -q "^\[create\]"'
r apply "$id"
check "applying a port-only plan records the port and writes no file" \
  '[ "$rc" = 0 ] && [ "$before" = "$(snapshot "$N")" ] && grep -q "\"port\": $((BASE + 9))" "$INIT_PROJECT_HOME/ports.json"'

# --- 1Password checks
E="$T/envapp"
mkdir -p "$E"
printf '{"scripts": {"dev": "next dev"}}\n' > "$E/package.json"
printf 'DATABASE_URL=SECRETVALUE11\n' > "$E/.env"
INIT_PROJECT_OP="$T/bin/missing-op" r plan --dir "$E" --env --vault Personal
check "--env without op installed exits 3" '[ "$rc" = 3 ]'
r plan --dir "$E" --env
check "--env without --vault exits 2" '[ "$rc" = 2 ]'
r plan --dir "$E" --env --vault "Team/Shared"
check "a vault name that references cannot hold exits 2" '[ "$rc" = 2 ]'
r plan --dir "$T/k/lib" --env --vault Personal
check "--env with no env file exits 1" '[ "$rc" = 1 ]'
r plan --dir "$E" --env --vault "Dev Team" --item "env app"
check "names with spaces are quoted in the template and in the commands" \
  'printf "%s\n" "$out" | grep -qx "    DATABASE_URL=\"op://Dev Team/env app/env/DATABASE_URL\"" && printf "%s\n" "$out" | grep -qF "op item edit '"'"'env app'"'"' --vault '"'"'Dev Team'"'"'"'

# --- plans, the port list, and waiting for a server
r discard zz
check "a malformed plan id exits 2" '[ "$rc" = 2 ]'
r apply deadbeef
check "an unknown plan id exits 1" '[ "$rc" = 1 ]'
r plan --dir "$E" --env --vault Personal
old="$(plan_id)"
touch -t 202001010000 "$INIT_PROJECT_HOME/plans/$old.json"
r plan --dir "$H" --docker --from $((BASE + 7))
check "plans older than a day are removed" '[ ! -e "$INIT_PROJECT_HOME/plans/$old.json" ]'
plans_for() {
  python3 -c 'import json,os,sys
d, folder = sys.argv[1], os.path.realpath(sys.argv[2])
print(sum(1 for n in os.listdir(d) if json.load(open(os.path.join(d, n)))["folder"] == folder))' "$INIT_PROJECT_HOME/plans" "$1"
}
r plan --dir "$E" --env --vault Personal
r plan --dir "$E" --env --vault Personal
check "a newer plan for the same folder replaces the earlier one, and plans for other folders stay" \
  '[ "$(plans_for "$E")" = 1 ] && [ "$(plans_for "$C")" = 1 ]'
r plan --dir "$V" --docker --overwrite Dockerfile --overwrite .dockerignore
check "a plan with nothing new to write says so and keeps no plan" \
  '[ "$rc" = 0 ] && printf "%s\n" "$out" | grep -q "^Nothing to write" && [ "$(plans_for "$V")" = 0 ]'

r ports
check "ports lists every recorded port with its folder" 'printf "%s\n" "$out" | grep -qE "^ *$BASE  app +.*/shop$"'
rm -rf "$N"
r ports
check "ports marks folders that are gone" 'printf "%s\n" "$out" | grep -q "nuxt  (folder is gone)"'
r ports --forget "$P"
check "--forget removes the ports of a folder" '[ "$rc" = 0 ] && ! grep -q "\"port\": $BASE," "$INIT_PROJECT_HOME/ports.json"'
r ports --forget "$P"
check "--forget for a folder without ports exits 1" '[ "$rc" = 1 ]'
printf '{"version": 99, "ports": []}\n' > "$INIT_PROJECT_HOME/ports.json"
r plan --dir "$Q" --docker
check "a port record in another format is refused" '[ "$rc" = 2 ] && printf "%s\n" "$err" | grep -q "format"'

python3 -m http.server $((BASE + 10)) --bind 127.0.0.1 --directory "$T/www" >/dev/null 2>&1 &
PIDS+=("$!")
r wait --port $((BASE + 10)) --timeout 10
check "wait reports the status once the server answers" '[ "$rc" = 0 ] && printf "%s\n" "$out" | grep -q "answered with status 200"'
r wait --port $((BASE + 11)) --timeout 1
check "wait exits 1 when nothing answers in time" '[ "$rc" = 1 ]'

# --- with portman installed, its registry is the one record of ports
# The checks run the portman script of this repository against a throwaway registry. portman reads
# listeners through stand-ins here, so it never looks at the real machine, docker, or registry.
PORTMAN_SRC="$HERE/../../../../portman/skills/portman/scripts/portman.py"
if [ -f "$PORTMAN_SRC" ]; then
  OUTER_STATE="$INIT_PROJECT_HOME"
  export INIT_PROJECT_HOME="$T/state-pm"
  export PORTMAN_HOME="$T/portman"
  export PORTMAN_NO_PROBE=1 PORTMAN_PROC_NET="$T/no-proc" PORTMAN_LSOF="$T/bin/no-lsof" PORTMAN_DOCKER="$T/bin/no-docker"
  for tool in no-lsof no-docker; do printf '#!/bin/sh\nexit 1\n' > "$T/bin/$tool"; chmod +x "$T/bin/$tool"; done
  PM="$T/bin/portman.py"
  cp "$PORTMAN_SRC" "$PM" && chmod +x "$PM"
  export INIT_PROJECT_PORTMAN="$PM"
  REG="$PORTMAN_HOME/registry.json"
  REC="$INIT_PROJECT_HOME/ports.json"
  pm() { python3 "$PM" "$@" > "$T/pm-out" 2>&1; }
  hash_of() { if [ -f "$1" ]; then cksum < "$1"; else echo none; fi; }
  picked() { printf '%s\n' "$out" | sed -nE 's/^  port     ([0-9]+) .*/\1/p'; }
  real() { python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$1"; }
  # registered <project> <port> <folder>: the registry lists that port for that project and folder.
  registered() { python3 "$PM" list --json 2>/dev/null | python3 -c 'import json, sys
want = (sys.argv[1], int(sys.argv[2]), sys.argv[3])
rows = [json.loads(l) for l in sys.stdin if l.startswith("{")]
sys.exit(0 if any((r["project"], r["port"], r["dir"]) == want for r in rows) else 1)' "$1" "$2" "$3"; }
  docs_say() { local f; for f in README.md README.ja.md docs/how-it-works.md docs/how-it-works.ja.md; do
    grep -qF -- "$1" "$HERE/../../../$f" || return 1; done; }
  # A second base with 12 free ports, away from the ones above.
  PB="$(python3 - "$SCRIPTS" "$((BASE + 200))" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import init_project as m
for base in range(int(sys.argv[2]), 60000, 37):
    span = range(base, base + 12)
    if not any(p in m.BUSY_PORTS or m.port_in_use(p) for p in span):
        print(base)
        break
PY
)"
  for name in pm-other pm-site pm-blog pm-shop pm-new pm-legacy pm-clash pm-far pm-find; do
    mkdir -p "$T/$name"; printf '{"scripts": {"dev": "node server.js"}}\n' > "$T/$name/package.json"
  done

  pm add other app "$PB" --dir "$T/pm-other"
  before="$(hash_of "$REG")"
  r plan --dir "$T/pm-site" --assign-port --from "$PB"
  check "with portman, plan skips a port portman holds for another folder" \
    '[ "$rc" = 0 ] && [ -n "$(picked)" ] && [ "$(picked)" != "$PB" ]'
  check "with portman, plan leaves the registry unchanged" '[ "$before" = "$(hash_of "$REG")" ]'

  pm add site app $((PB + 3)) --dir "$T/pm-site"
  r plan --dir "$T/pm-site" --assign-port --from "$PB"
  check "with portman, plan uses the port portman holds for this folder" \
    '[ "$rc" = 0 ] && [ "$(picked)" = $((PB + 3)) ] && printf "%s\n" "$out" | grep -q "registered in portman"'

  pm add pm-blog app $((PB + 4))
  r plan --dir "$T/pm-blog" --assign-port --from "$PB"
  check "with portman, a project without a folder is matched by the folder name" '[ "$rc" = 0 ] && [ "$(picked)" = $((PB + 4)) ]'

  r plan --dir "$T/pm-shop" --assign-port --from "$PB"
  shop_port="$(picked)"
  r apply "$(plan_id)"
  check "with portman, apply registers the port in portman and not in the ports record" \
    '[ "$rc" = 0 ] && [ -n "$shop_port" ] && registered pm-shop "$shop_port" "$(real "$T/pm-shop")" &&
     ! grep -qF "$(real "$T/pm-shop")" "$REC" 2>/dev/null'

  K="$T/pm-repo"
  mkdir -p "$K"; printf '{"scripts": {"dev": "node server.js"}}\n' > "$K/package.json"
  git init -q "$K"; git -C "$K" add package.json; git -C "$K" commit -qm init
  git -C "$K" worktree add -q -b wt "$T/pm-repo-wt"
  pm add pm-repo app $((PB + 5)) --dir "$K"
  r plan --dir "$T/pm-repo-wt" --assign-port --from $((PB + 5))
  check "with portman, a worktree gets a port of its own" '[ "$rc" = 0 ] && [ -n "$(picked)" ] && [ "$(picked)" != $((PB + 5)) ]'

  # Ports recorded by init-project before portman was installed, one of them on a port portman gives to another project.
  mkdir -p "$INIT_PROJECT_HOME"
  python3 - "$REC" "$(real "$T/pm-legacy")" "$(real "$T/pm-clash")" $((PB + 6)) "$PB" <<'PY'
import json, sys
path, legacy, clash, legacy_port, clash_port = sys.argv[1:]
ports = [{"port": int(legacy_port), "folder": legacy, "service": "app"}, {"port": int(clash_port), "folder": clash, "service": "app"}]
open(path, "w").write(json.dumps({"version": 1, "ports": ports}, indent=2) + "\n")
PY
  r plan --dir "$T/pm-new" --assign-port --from $((PB + 6))
  check "with portman, plan skips the ports not yet moved and names ports --move" \
    '[ "$rc" = 0 ] && [ -n "$(picked)" ] && [ "$(picked)" != $((PB + 6)) ] && [ "$(printf "%s\n%s\n" "$out" "$err" | grep -c "ports --move")" = 1 ]'

  cp "$REG" "$T/registry.saved"
  printf '{"version": 99, "projects": {}}\n' > "$REG"
  r plan --dir "$T/pm-new" --assign-port --from $((PB + 6))
  check "an unreadable registry gives one warning and plan uses the ports record" \
    '[ "$rc" = 0 ] && [ "$(printf "%s\n" "$err" | grep -c .)" = 1 ] && printf "%s\n" "$err" | grep -q portman && [ "$(picked)" = $((PB + 7)) ]'
  cp "$T/registry.saved" "$REG"

  before_reg="$(hash_of "$REG")"; before_rec="$(hash_of "$REC")"
  r ports --move
  check "ports --move without --confirm changes neither record" \
    '[ "$rc" = 0 ] && printf "%s\n" "$out" | grep -q pm-legacy && [ "$before_reg" = "$(hash_of "$REG")" ] && [ "$before_rec" = "$(hash_of "$REC")" ]'
  r ports --move --confirm
  check "ports --move --confirm moves every port into portman" \
    'registered pm-legacy $((PB + 6)) "$(real "$T/pm-legacy")" && ! grep -qF "$(real "$T/pm-legacy")" "$REC"'
  check "ports --move keeps a port portman holds for another project" \
    'grep -qF "$(real "$T/pm-clash")" "$REC" && printf "%s\n%s\n" "$out" "$err" | grep "pm-clash" | grep -q "$PB"'

  # Without INIT_PROJECT_PORTMAN, portman is found where Claude Code and Codex install plugins.
  unset INIT_PROJECT_PORTMAN
  pm add far app $((PB + 8)) --dir "$T/pm-far"
  mkdir -p "$HOME/.claude/plugins/cache/agent-shuriken/portman/0.1.0/skills/portman/scripts"
  cp "$PM" "$HOME/.claude/plugins/cache/agent-shuriken/portman/0.1.0/skills/portman/scripts/portman.py"
  r plan --dir "$T/pm-find" --assign-port --from $((PB + 8))
  check "portman is found in the Claude Code plugins folder" '[ "$rc" = 0 ] && [ -n "$(picked)" ] && [ "$(picked)" != $((PB + 8)) ]'
  rm -rf "$HOME/.claude/plugins"
  mkdir -p "$HOME/.codex/plugins/cache/agent-shuriken/portman/0.1.0/skills/portman/scripts"
  cp "$PM" "$HOME/.codex/plugins/cache/agent-shuriken/portman/0.1.0/skills/portman/scripts/portman.py"
  r plan --dir "$T/pm-find" --assign-port --from $((PB + 8))
  check "portman is found in the Codex plugins folder" '[ "$rc" = 0 ] && [ -n "$(picked)" ] && [ "$(picked)" != $((PB + 8)) ]'
  rm -rf "$HOME/.codex/plugins"

  export INIT_PROJECT_HOME="$OUTER_STATE"
  unset PORTMAN_HOME PORTMAN_NO_PROBE PORTMAN_PROC_NET PORTMAN_LSOF PORTMAN_DOCKER
else
  ng "portman.py is found next to this plugin for the registry checks"
fi
check "the script never names the registry file" '! grep -q "registry\.json" "$SCRIPT"'
check "the README and How it works say the ports go to portman" 'docs_say "ports --move"'

check "no output ever held a value from an env file" '! grep -q SECRETVALUE "$ALL"'

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
