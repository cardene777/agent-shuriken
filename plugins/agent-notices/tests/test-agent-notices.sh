#!/usr/bin/env bash
# Tests for the agent-notices hooks. Each hook reads one event as JSON on stdin, the shape Claude Code
# and Codex hand to a hook, and prints a notice for the agent or nothing. HOME, TMPDIR, and PATH point
# at a throwaway folder, so no real repository, log, or formatter is read or run. Key-shaped values
# are built while the tests run, so this file holds none.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$(cd "$HERE/.." && pwd)"
HOOKS="$PLUGIN/hooks"
T="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$T"' EXIT

export HOME="$T/home"
export TMPDIR="$T/tmp"
WORK="$T/work"
STUBS="$T/stubs"
mkdir -p "$HOME" "$TMPDIR" "$WORK" "$STUBS"
for v in $(env | sed -n 's/^\(AGENT_NOTICES_[A-Z_]*\)=.*/\1/p'); do unset "$v"; done
unset XDG_CONFIG_HOME XDG_DATA_HOME CLAUDE_CLIENT_PRESENCE_FILE CLAUDECODE
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
BASE_PATH="$STUBS:/usr/bin:/bin:/usr/sbin:/sbin"
for tool in jq python3 git; do
  p="$(command -v "$tool")" && ln -sf "$p" "$STUBS/$tool"
done
export PATH="$BASE_PATH"
RUNS="$T/runs.log"
: > "$RUNS"

PASS=0
FAIL=0
why=""
ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; [ -n "$why" ] && printf '        %s\n' "$why"; }
check() { why=""; if "$2"; then ok "$1"; else ng "$1"; fi; }

# Events in the shapes Claude Code and Codex hand to a hook.
event_edit() { jq -nc --arg p "$1" --arg o "$2" --arg n "$3" --arg d "${4:-$WORK}" \
  '{hook_event_name: "PostToolUse", session_id: "s1", tool_name: "Edit", tool_input: {file_path: $p, old_string: $o, new_string: $n}, cwd: $d}'; }
event_write() { jq -nc --arg p "$1" --arg c "$2" --arg d "${3:-$WORK}" \
  '{hook_event_name: "PostToolUse", session_id: "s1", tool_name: "Write", tool_input: {file_path: $p, content: $c}, cwd: $d}'; }
event_patch() { jq -nc --arg c "$1" --arg d "${2:-$WORK}" \
  '{hook_event_name: "PostToolUse", session_id: "s1", tool_name: "apply_patch", tool_input: {command: $c}, cwd: $d}'; }
event_bash() { jq -nc --arg c "$1" --arg d "${2:-$WORK}" --arg s "${3:-s1}" \
  '{hook_event_name: "PostToolUse", session_id: $s, tool_name: "Bash", tool_input: {command: $c}, tool_response: {stdout: "", stderr: ""}, cwd: $d}'; }
event_grep() { jq -nc --arg p "$1" --arg path "$2" --argjson n "$3" --arg d "$WORK" \
  '{hook_event_name: "PostToolUse", session_id: "s1", tool_name: "Grep", tool_input: {pattern: $p, path: $path}, tool_response: {mode: "files_with_matches", numFiles: $n, filenames: (if $n == 0 then [] else ["found.txt"] end)}, cwd: $d}'; }
event_session() { jq -nc --arg e "$1" --arg d "$WORK" '{hook_event_name: $e, session_id: "s1", cwd: $d}'; }
event_tool() { jq -nc --arg e "$1" --arg t "$2" --arg id "$3" --argjson i "$4" --arg d "$WORK" \
  '{hook_event_name: $e, session_id: "s1", tool_name: $t, tool_use_id: $id, tool_input: $i, tool_response: {content: "RESULT_TEXT_MARK"}, error: "failed", cwd: $d}'; }

# run_hook <hook> <event> prints what the hook printed, and notes the hook, its exit code, and its
# output in RUNS. A missing hook prints nothing.
run_hook() {
  [ -f "$HOOKS/$1.sh" ] || return 0
  local out status dir
  dir="$(printf '%s' "$2" | jq -r '.cwd')"
  out="$(cd "$dir" && printf '%s' "$2" | bash "$HOOKS/$1.sh" 2>/dev/null)"
  status=$?
  printf '%s\t%s\t%s\n' "$1" "$status" "$(printf '%s' "$out" | tr '\n' ' ')" >> "$RUNS"
  printf '%s' "$out"
}
notice() { run_hook "$1" "$2" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null; }

# notes <hook> <event> <label> <text>...: the hook adds a notice that holds every text.
notes() {
  local hook="$1" event="$2" label="$3" got t
  shift 3
  [ -f "$HOOKS/$hook.sh" ] || { why="hooks/$hook.sh does not exist"; return 1; }
  got="$(notice "$hook" "$event")"
  [ -n "$got" ] || { why="$hook said nothing for: $label"; return 1; }
  for t in "$@"; do
    case "$got" in *"$t"*) ;; *) why="$hook's notice for $label does not hold '$t': $got"; return 1 ;; esac
  done
}
# quiet <hook> <event> <label>: the hook exists, exits 0, and prints nothing.
quiet() {
  [ -f "$HOOKS/$1.sh" ] || { why="hooks/$1.sh does not exist"; return 1; }
  local out dir status
  dir="$(printf '%s' "$2" | jq -r '.cwd')"
  out="$(cd "$dir" && printf '%s' "$2" | bash "$HOOKS/$1.sh" 2>/dev/null)"
  status=$?
  printf '%s\t%s\t%s\n' "$1" "$status" "$(printf '%s' "$out" | tr '\n' ' ')" >> "$RUNS"
  [ "$status" -eq 0 ] || { why="$1 exited $status for: $3"; return 1; }
  [ -z "$out" ] || { why="$1 printed something for: $3 ($out)"; return 1; }
}

# A GitHub token shape, assembled here so the file never holds one.
KEY_GH="gh""p_aB3dE5gH7jK9mN1pQ3sT5vW7yZ9bC1dE3fG5"

# pipefail-grep
pipefail_noticed() {
  local f="$WORK/pf/run.sh"
  mkdir -p "$WORK/pf"
  printf '#!/usr/bin/env bash\nset -euo pipefail\necho start\nfind . -name x | grep -q x\n' > "$f"
  notes pipefail-grep "$(event_write "$f" "$(cat "$f")")" 'a pipefail script with a piped grep -q' 'run.sh' ':4' 'pipefail' || return 1
  local g="$WORK/pf/edit.bash"
  printf '#!/bin/bash\nset -o pipefail\nls\n' > "$g"
  printf '#!/bin/bash\nset -o pipefail\nls | grep --quiet foo\n' > "$g"
  notes pipefail-grep "$(event_edit "$g" 'ls' 'ls | grep --quiet foo')" 'an edit that adds ls | grep --quiet' 'edit.bash' ':3'
}
pipefail_quiet() {
  mkdir -p "$WORK/pq"
  local a="$WORK/pq/plain.sh" b="$WORK/pq/direct.sh" c="$WORK/pq/notes.md"
  printf '#!/usr/bin/env bash\nset -eu\nfind . | grep -q x\n' > "$a"
  printf '#!/usr/bin/env bash\nset -o pipefail\ngrep -q x file.txt\n' > "$b"
  printf 'Run `set -o pipefail` and then `ls | grep -q x`.\n' > "$c"
  quiet pipefail-grep "$(event_write "$a" "$(cat "$a")")" 'a script without pipefail' || return 1
  quiet pipefail-grep "$(event_write "$b" "$(cat "$b")")" 'grep -q reading a file' || return 1
  quiet pipefail-grep "$(event_write "$c" "$(cat "$c")")" 'a Markdown file'
}

# nohup
nohup_noticed() {
  local c
  for c in 'nohup ./server &' 'nohup make test > log 2>&1 & disown' 'cd app && nohup npm start >/dev/null 2>&1 &'; do
    notes nohup "$(event_bash "$c")" "$c" 'nohup' 'background' || return 1
  done
}
nohup_quiet() {
  local c
  for c in 'echo "nohup x &"' 'nohup make && echo done' 'nohup make > log 2>&1' 'make 2>&1 | tee log' 'ls &> out.txt'; do
    quiet nohup "$(event_bash "$c")" "$c" || return 1
  done
}

# grep-binary
GB="$WORK/gb"
mkdir -p "$GB/data" "$GB/src"
printf 'abc\000needle-in-binary\000end' > "$GB/data/blob.bin"
printf 'hello world\n' > "$GB/src/a.txt"
grep_binary_noticed() {
  notes grep-binary "$(event_grep 'needle-in-binary' "$GB" 0)" 'a search that found nothing' 'blob.bin' '-a'
}
grep_binary_quiet() {
  quiet grep-binary "$(event_grep 'hello' "$GB" 1)" 'a search with matches' || return 1
  quiet grep-binary "$(event_grep 'absent-word' "$GB" 0)" 'a pattern no file holds'
}

# branch
BR="$WORK/br"
mkdir -p "$BR"
git -C "$BR" init -q -b main
git -C "$BR" -c user.name=test -c user.email=test commit -q --allow-empty -m init
git -C "$BR" branch feature
branch_switch_noticed() {
  git -C "$BR" checkout -q main
  notes branch "$(event_bash 'git switch feature' "$BR" s2)" 'a switch that did not happen' 'feature' 'main' || return 1
  notes branch "$(event_bash "git -C $BR checkout feature" "$WORK" s2)" 'git -C <repo> checkout that did not happen' 'feature' 'main'
}
branch_commit_noticed() {
  git -C "$BR" checkout -q feature
  quiet branch "$(event_bash 'git switch feature' "$BR" s3)" 'a switch that took effect' || return 1
  git -C "$BR" checkout -q main
  notes branch "$(event_bash 'git commit -m wip' "$BR" s3)" 'a commit after another process switched' 'main' 'feature'
}
branch_quiet() {
  git -C "$BR" checkout -q feature
  quiet branch "$(event_bash 'git switch feature' "$BR" s4)" 'a switch that took effect' || return 1
  quiet branch "$(event_bash 'git commit -m done' "$BR" s4)" 'a commit on the session branch' || return 1
  quiet branch "$(event_bash 'ls -la' "$BR" s4)" 'a command that is not git' || return 1
  quiet branch "$(event_bash 'git checkout -- README.md' "$BR" s4)" 'a checkout of a file'
}

# env-example
ENVR="$WORK/envr"
mkdir -p "$ENVR"
git -C "$ENVR" init -q -b main
printf 'EXISTING_NAME=\n# COMMENTED_NAME=\n' > "$ENVR/.env.example"
env_example_noticed() {
  local f
  f="$ENVR/a.ts"; printf 'const u = process.env.NEW_TS_URL;\n' > "$f"
  notes env-example "$(event_write "$f" "$(cat "$f")")" 'TypeScript process.env' 'NEW_TS_URL' '.env.example' || return 1
  f="$ENVR/b.js"; printf 'const k = import.meta.env.NEW_JS_KEY;\n' > "$f"
  notes env-example "$(event_write "$f" "$(cat "$f")")" 'JavaScript import.meta.env' 'NEW_JS_KEY' || return 1
  f="$ENVR/c.py"; printf 'import os\na = os.environ["NEW_PY_A"]\nb = os.getenv("NEW_PY_B")\nc = os.environ.get("NEW_PY_C")\n' > "$f"
  notes env-example "$(event_write "$f" "$(cat "$f")")" 'Python' 'NEW_PY_A' 'NEW_PY_B' 'NEW_PY_C' || return 1
  f="$ENVR/d.go"; printf 'package main\nimport "os"\nvar v = os.Getenv("NEW_GO_V")\n' > "$f"
  notes env-example "$(event_write "$f" "$(cat "$f")")" 'Go' 'NEW_GO_V' || return 1
  f="$ENVR/e.rb"; printf 'a = ENV["NEW_RB_A"]\nb = ENV.fetch("NEW_RB_B")\n' > "$f"
  notes env-example "$(event_write "$f" "$(cat "$f")")" 'Ruby' 'NEW_RB_A' 'NEW_RB_B' || return 1
  f="$ENVR/f.rs"; printf 'fn main() { let v = std::env::var("NEW_RS_V"); }\n' > "$f"
  notes env-example "$(event_write "$f" "$(cat "$f")")" 'Rust' 'NEW_RS_V'
}
env_example_quiet() {
  local f="$ENVR/g.ts"
  printf 'const a = process.env.EXISTING_NAME;\nconst b = process.env.COMMENTED_NAME;\n' > "$f"
  quiet env-example "$(event_write "$f" "$(cat "$f")")" 'names the example file lists' || return 1
  printf 'const a = process.env.OLD_NAME_HERE ?? "x";\n' > "$f"
  quiet env-example "$(event_edit "$f" 'process.env.OLD_NAME_HERE' 'process.env.OLD_NAME_HERE ?? "x"' "$ENVR")" 'a name that was there before the edit' || return 1
  mkdir -p "$WORK/noexample"
  git -C "$WORK/noexample" init -q -b main
  printf 'const a = process.env.ANY_NAME;\n' > "$WORK/noexample/a.ts"
  quiet env-example "$(event_write "$WORK/noexample/a.ts" 'const a = process.env.ANY_NAME;' "$WORK/noexample")" 'a repository without an example file'
}

# tmp-space
tmp_noticed() {
  AGENT_NOTICES_TMP_MIN_GB=1000000 notes tmp-space "$(event_bash 'ls')" 'a limit above the free space' "$TMPDIR" 'GB'
}
tmp_quiet() {
  AGENT_NOTICES_TMP_MIN_GB=0 quiet tmp-space "$(event_bash 'ls')" 'a limit of 0' || return 1
  local free
  free="$(python3 -c 'import os,sys; s=os.statvfs(sys.argv[1]); print(s.f_bavail*s.f_frsize//(1<<30))' "$TMPDIR")"
  [ "$free" -ge 6 ] || return 0
  quiet tmp-space "$(event_bash 'ls')" 'the default limit with more than 5 GB free'
}

# security
SEC="$WORK/sec"
mkdir -p "$SEC/.github/workflows"
security_noticed() {
  local f
  f="$SEC/run.py"; printf 'import os\nos.system(cmd)\n' > "$f"
  notes security "$(event_edit "$f" 'pass' 'os.system(cmd)' "$SEC")" 'os.system in Python' 'Security Warning' 'os.system' || return 1
  f="$SEC/page.js"; printf 'el.innerHTML = html;\n' > "$f"
  notes security "$(event_write "$f" "$(cat "$f")" "$SEC")" 'innerHTML in JavaScript' 'innerHTML' || return 1
  f="$SEC/.github/workflows/ci.yml"; printf 'on: push\n' > "$f"
  notes security "$(event_write "$f" "$(cat "$f")" "$SEC")" 'a GitHub Actions workflow' 'GitHub Actions'
}
security_quiet() {
  local f="$SEC/ok.py"
  printf 'print("hello")\n' > "$f"
  for tool in curl wget claude node npx nc; do
    printf '#!/bin/sh\necho "%s" >> "%s/outside.log"\n' "$tool" "$T" > "$STUBS/$tool"
    chmod +x "$STUBS/$tool"
  done
  quiet security "$(event_write "$f" "$(cat "$f")" "$SEC")" 'safe Python' || return 1
  local g="$SEC/again.py"
  printf 'os.system(x)\n' > "$g"
  HTTPS_PROXY=http://127.0.0.1:9 HTTP_PROXY=http://127.0.0.1:9 \
    notes security "$(event_write "$g" "$(cat "$g")" "$SEC")" 'os.system with every outside call stubbed' 'os.system' || return 1
  for tool in curl wget claude node npx nc; do rm -f "$STUBS/$tool"; done
  [ ! -s "$T/outside.log" ] || { why="the security hook ran $(tr '\n' ' ' < "$T/outside.log")"; return 1; }
}
patterns_notice_matches() {
  local f="$HOOKS/lib/security_guidance/patterns.py" n="$PLUGIN/THIRD_PARTY_NOTICES.md" sum
  [ -f "$f" ] || { why="hooks/lib/security_guidance/patterns.py does not exist"; return 1; }
  [ -f "$HOOKS/lib/security_guidance/LICENSE" ] || { why="the Apache 2.0 license is not next to patterns.py"; return 1; }
  [ -f "$n" ] || { why="THIRD_PARTY_NOTICES.md does not exist"; return 1; }
  sum="$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$f")"
  grep -q "$sum" "$n" || { why="THIRD_PARTY_NOTICES.md does not record the checksum $sum"; return 1; }
  grep -q 'github.com/anthropics/claude-plugins-official' "$n" || { why="the notice names no source"; return 1; }
  grep -Eq '[0-9a-f]{40}' "$n" || { why="the notice names no commit"; return 1; }
  grep -q 'Apache License 2.0' "$n" || { why="the notice names no license"; return 1; }
  grep -Eq '20[0-9]{2}-[0-9]{2}-[0-9]{2}' "$n" || { why="the notice names no date"; return 1; }
}

# format
# stub <dir> <name>: a formatter stub that notes its arguments and appends a line to the file it gets.
stub() {
  mkdir -p "$1"
  printf '#!/bin/sh\nprintf "%%s\\n" "%s $*" >> "%s/formatted.log"\nfor a in "$@"; do [ -f "$a" ] && printf "\\n" >> "$a"; done\nexit 0\n' "$2" "$T" > "$1/$2"
  chmod +x "$1/$2"
}
ran() { grep -q "^$1 .*$2" "$T/formatted.log" 2>/dev/null; }
FMT="$WORK/fmt"
setup_format() {
  mkdir -p "$FMT/js/src" "$FMT/biome/src" "$FMT/ruff/pkg" "$FMT/black/pkg" "$FMT/go" "$FMT/rs/src" "$T/fmtbin"
  printf '{}\n' > "$FMT/js/.prettierrc"; printf '{"name":"js"}\n' > "$FMT/js/package.json"
  stub "$FMT/js/node_modules/.bin" prettier
  printf '{}\n' > "$FMT/biome/biome.json"; stub "$FMT/biome/node_modules/.bin" biome
  printf '[tool.ruff]\nline-length = 100\n' > "$FMT/ruff/pyproject.toml"; stub "$FMT/ruff/.venv/bin" ruff
  printf '[tool.black]\nline-length = 100\n' > "$FMT/black/pyproject.toml"
  printf 'module x\n' > "$FMT/go/go.mod"
  printf '[package]\nname = "x"\nedition = "2021"\n' > "$FMT/rs/Cargo.toml"
  stub "$T/fmtbin" black; stub "$T/fmtbin" gofmt; stub "$T/fmtbin" rustfmt
}
setup_format
format_runs() {
  local f
  : > "$T/formatted.log"
  export PATH="$T/fmtbin:$BASE_PATH"
  f="$FMT/js/src/a.ts"; printf 'let a=1\n' > "$f"; run_hook format "$(event_write "$f" "$(cat "$f")" "$FMT/js")" > /dev/null
  ran prettier "$f" || { why="prettier did not run on $f"; export PATH="$BASE_PATH"; return 1; }
  f="$FMT/biome/src/b.ts"; printf 'let b=1\n' > "$f"; run_hook format "$(event_write "$f" "$(cat "$f")" "$FMT/biome")" > /dev/null
  ran biome "$f" || { why="biome did not run on $f"; export PATH="$BASE_PATH"; return 1; }
  f="$FMT/ruff/pkg/c.py"; printf 'x=1\n' > "$f"; run_hook format "$(event_write "$f" "$(cat "$f")" "$FMT/ruff")" > /dev/null
  ran ruff "$f" || { why="ruff did not run on $f"; export PATH="$BASE_PATH"; return 1; }
  f="$FMT/black/pkg/d.py"; printf 'y=1\n' > "$f"; run_hook format "$(event_write "$f" "$(cat "$f")" "$FMT/black")" > /dev/null
  ran black "$f" || { why="black did not run on $f"; export PATH="$BASE_PATH"; return 1; }
  f="$FMT/go/main.go"; printf 'package main\n' > "$f"; run_hook format "$(event_write "$f" "$(cat "$f")" "$FMT/go")" > /dev/null
  ran gofmt "$f" || { why="gofmt did not run on $f"; export PATH="$BASE_PATH"; return 1; }
  f="$FMT/rs/src/main.rs"; printf 'fn main(){}\n' > "$f"; run_hook format "$(event_write "$f" "$(cat "$f")" "$FMT/rs")" > /dev/null
  ran rustfmt "$f" || { why="rustfmt did not run on $f"; export PATH="$BASE_PATH"; return 1; }
  export PATH="$BASE_PATH"
}
format_nothing_unnamed() {
  : > "$T/formatted.log"
  mkdir -p "$FMT/none/src" "$FMT/missing" "$T/anybin"
  stub "$T/anybin" prettier; stub "$T/anybin" npx; stub "$T/anybin" ruff
  export PATH="$T/anybin:$BASE_PATH"
  local f="$FMT/none/src/a.ts"
  printf 'let a=1\n' > "$f"
  quiet format "$(event_write "$f" "$(cat "$f")" "$FMT/none")" 'a project that names no formatter' || { export PATH="$BASE_PATH"; return 1; }
  export PATH="$BASE_PATH"
  printf '{}\n' > "$FMT/missing/.prettierrc"
  stub "$T/onlynpx" npx
  export PATH="$T/onlynpx:$BASE_PATH"
  f="$FMT/missing/b.ts"; printf 'let b=1\n' > "$f"
  quiet format "$(event_write "$f" "$(cat "$f")" "$FMT/missing")" 'a named formatter that is not installed' || { export PATH="$BASE_PATH"; return 1; }
  export PATH="$BASE_PATH"
  [ ! -s "$T/formatted.log" ] || { why="something ran: $(tr '\n' ' ' < "$T/formatted.log")"; return 1; }
}
format_tells_change() {
  local f="$FMT/js/src/told.ts"
  printf 'let c=1\n' > "$f"
  notes format "$(event_write "$f" "$(cat "$f")" "$FMT/js")" 'a file prettier changed' 'told.ts' 'prettier' || return 1
  mkdir -p "$FMT/same/node_modules/.bin"
  printf '{}\n' > "$FMT/same/.prettierrc"
  printf '#!/bin/sh\nexit 0\n' > "$FMT/same/node_modules/.bin/prettier"; chmod +x "$FMT/same/node_modules/.bin/prettier"
  f="$FMT/same/e.ts"; printf 'let e = 1;\n' > "$f"
  quiet format "$(event_write "$f" "$(cat "$f")" "$FMT/same")" 'a file prettier left as it was'
}

# presence
presence_start_end() {
  local p="$T/presence/here"
  CLAUDE_CLIENT_PRESENCE_FILE="$p" run_hook presence "$(event_session SessionStart)" > /dev/null
  [ -f "$HOOKS/presence.sh" ] || { why="hooks/presence.sh does not exist"; return 1; }
  [ -f "$p" ] || { why="the presence file was not created at session start"; return 1; }
  CLAUDE_CLIENT_PRESENCE_FILE="$p" run_hook presence "$(event_session SessionEnd)" > /dev/null
  [ ! -e "$p" ] || { why="the presence file was not removed at session end"; return 1; }
}
presence_unset() {
  local before after
  before="$(find "$T" -type f 2>/dev/null | sort)"
  quiet presence "$(event_session SessionStart)" 'a session start without the variable' || return 1
  after="$(find "$T" -type f 2>/dev/null | grep -v "^$RUNS\$" | sort)"
  [ "$after" = "$(printf '%s\n' "$before" | grep -v "^$RUNS\$")" ] \
    || { why="a file was created without the variable: $(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | tr '\n' ' ')"; return 1; }
}

# skill-log and mcp-log
DATA="$HOME/.local/share/agent-notices"
skill_events() {
  local args
  args="$(jq -nc --arg k "$KEY_GH" '{skill: "demo-skill", args: ("ARG_TEXT_MARK " + $k)}')"
  run_hook skill-log "$(event_tool PreToolUse Skill t1 "$args")" > /dev/null
  run_hook skill-log "$(event_tool PostToolUse Skill t1 "$args")" > /dev/null
  run_hook skill-log "$(event_tool PreToolUse Skill t2 "$args")" > /dev/null
  run_hook skill-log "$(event_tool PostToolUseFailure Skill t2 "$args")" > /dev/null
}
mcp_events() {
  local args
  args="$(jq -nc --arg k "$KEY_GH" '{path: ("ARG_TEXT_MARK " + $k)}')"
  run_hook mcp-log "$(event_tool PreToolUse mcp__files__read_file m1 "$args")" > /dev/null
  run_hook mcp-log "$(event_tool PostToolUse mcp__files__read_file m1 "$args")" > /dev/null
  run_hook mcp-log "$(event_tool PreToolUse mcp__files__read_file m2 "$args")" > /dev/null
  run_hook mcp-log "$(event_tool PostToolUseFailure mcp__files__read_file m2 "$args")" > /dev/null
}
logs_off() {
  [ -f "$HOOKS/skill-log.sh" ] && [ -f "$HOOKS/mcp-log.sh" ] || { why="hooks/skill-log.sh or hooks/mcp-log.sh does not exist"; return 1; }
  rm -rf "$DATA"
  skill_events; mcp_events
  [ -z "$(find "$DATA" -type f 2>/dev/null)" ] || { why="a log was written with the variables unset: $(find "$DATA" -type f)"; return 1; }
}
mode_of() { python3 -c 'import os,stat,sys; print(oct(stat.S_IMODE(os.stat(sys.argv[1]).st_mode)))' "$1"; }
log_lines_hold() {
  local file="$1" key="$2" name="$3"
  [ -f "$file" ] || { why="$file was not written"; return 1; }
  [ "$(wc -l < "$file" | tr -d ' ')" -eq 2 ] || { why="$file holds $(wc -l < "$file" | tr -d ' ') lines, not 2"; return 1; }
  jq -e --arg k "$key" --arg n "$name" -s 'length == 2 and all(.[]; .[$k] == $n and (.start | type) == "string" and (.end | type) == "string" and (.duration_ms | type) == "number" and .duration_ms >= 0) and .[0].ok == true and .[1].ok == false' "$file" > /dev/null \
    || { why="$file does not hold $key, start, end, duration_ms, and ok as expected: $(tr '\n' ' ' < "$file")"; return 1; }
  [ "$(mode_of "$file")" = 0o600 ] || { why="$file has mode $(mode_of "$file"), not 0o600"; return 1; }
  [ "$(mode_of "$DATA")" = 0o700 ] || { why="$DATA has mode $(mode_of "$DATA"), not 0o700"; return 1; }
}
skill_log_on() {
  rm -rf "$DATA"
  AGENT_NOTICES_SKILL_LOG=on skill_events
  log_lines_hold "$DATA/skill-calls.jsonl" skill demo-skill
}
mcp_log_on() {
  rm -rf "$DATA"
  AGENT_NOTICES_MCP_LOG=on mcp_events
  log_lines_hold "$DATA/mcp-calls.jsonl" server files || return 1
  jq -e -s 'all(.[]; .tool == "read_file")' "$DATA/mcp-calls.jsonl" > /dev/null || { why="the MCP log does not name the tool"; return 1; }
}
logs_no_arguments() {
  rm -rf "$DATA"
  export AGENT_NOTICES_SKILL_LOG=on AGENT_NOTICES_MCP_LOG=on
  skill_events; mcp_events
  unset AGENT_NOTICES_SKILL_LOG AGENT_NOTICES_MCP_LOG
  [ -n "$(find "$DATA" -type f 2>/dev/null)" ] || { why="no log was written"; return 1; }
  if grep -rq -e ARG_TEXT_MARK -e RESULT_TEXT_MARK -e "$KEY_GH" "$DATA"; then
    why="a log holds an argument or a result"; return 1
  fi
}

# Every hook, its switch, and an event it gives a notice for.
off_case() {
  local var="$1" hook="$2" event="$3"
  [ -f "$HOOKS/$hook.sh" ] || { why="hooks/$hook.sh does not exist"; return 1; }
  [ -n "$(notice "$hook" "$event")" ] || { why="$hook gave no notice to turn off"; return 1; }
  [ -z "$(env "$var=off" bash -c 'cd "$1" && printf "%s" "$2" | bash "$3"' _ "$(printf '%s' "$event" | jq -r .cwd)" "$event" "$HOOKS/$hook.sh" 2>/dev/null)" ] \
    || { why="$hook still spoke with $var=off"; return 1; }
}
turn_off_each() {
  local pf="$WORK/pf/run.sh"
  off_case AGENT_NOTICES_PIPEFAIL_GREP pipefail-grep "$(event_write "$pf" "$(cat "$pf" 2>/dev/null)")" || return 1
  off_case AGENT_NOTICES_NOHUP nohup "$(event_bash 'nohup ./server &')" || return 1
  off_case AGENT_NOTICES_GREP_BINARY grep-binary "$(event_grep 'needle-in-binary' "$GB" 0)" || return 1
  git -C "$BR" checkout -q main
  off_case AGENT_NOTICES_BRANCH branch "$(event_bash 'git switch feature' "$BR" s9)" || return 1
  off_case AGENT_NOTICES_ENV_EXAMPLE env-example "$(event_write "$ENVR/a.ts" "$(cat "$ENVR/a.ts" 2>/dev/null)")" || return 1
  AGENT_NOTICES_TMP_MIN_GB=1000000 off_case AGENT_NOTICES_TMP_SPACE tmp-space "$(event_bash 'ls')" || return 1
  off_case AGENT_NOTICES_SECURITY security "$(event_write "$SEC/run.py" "$(cat "$SEC/run.py" 2>/dev/null)" "$SEC")" || return 1
  printf 'let z=1\n' > "$FMT/js/src/off.ts"
  off_case AGENT_NOTICES_FORMAT format "$(event_write "$FMT/js/src/off.ts" 'let z=1' "$FMT/js")" || return 1
  AGENT_NOTICES_EDIT_LOOP_EVERY=1 off_case AGENT_NOTICES_EDIT_LOOP edit-loop "$(event_edit_in "$EL/src/off.ts" e8)" || return 1
  CLAUDECODE=1 AGENT_NOTICES_SEQUENTIAL_AFTER=1 off_case AGENT_NOTICES_SEQUENTIAL sequential "$(event_call Read q6)" || return 1
  local p="$T/presence/off"
  [ -f "$HOOKS/presence.sh" ] || { why="hooks/presence.sh does not exist"; return 1; }
  CLAUDE_CLIENT_PRESENCE_FILE="$p" AGENT_NOTICES_PRESENCE=off run_hook presence "$(event_session SessionStart)" > /dev/null
  [ ! -e "$p" ] || { why="presence still wrote the file with AGENT_NOTICES_PRESENCE=off"; return 1; }
  AGENT_NOTICES_PIPEFAIL_GREP=off notes nohup "$(event_bash 'nohup ./server &')" 'nohup with another hook off' 'nohup'
}

# Codex apply_patch
CX="$WORK/cx"
codex_patch() {
  mkdir -p "$CX"
  git -C "$CX" init -q -b main
  printf 'OLD_ONE=\n' > "$CX/.env.example"
  printf '{}\n' > "$CX/.prettierrc"
  stub "$CX/node_modules/.bin" prettier
  printf 'export const a = 1;\n' > "$CX/app.ts"
  printf '#!/usr/bin/env bash\nset -o pipefail\nls | grep -q x\n' > "$CX/job.sh"
  printf 'import os\nos.system(cmd)\n' > "$CX/tool.py"
  printf 'export const a = 1;\nexport const b = process.env.PATCHED_NAME;\n' > "$CX/app.ts"
  local patch
  patch="$(printf '*** Begin Patch\n*** Add File: job.sh\n+#!/usr/bin/env bash\n+set -o pipefail\n+ls | grep -q x\n*** Add File: tool.py\n+import os\n+os.system(cmd)\n*** Update File: app.ts\n@@\n export const a = 1;\n+export const b = process.env.PATCHED_NAME;\n*** End Patch\n')"
  notes pipefail-grep "$(event_patch "$patch" "$CX")" 'apply_patch adding job.sh' 'job.sh' ':3' || return 1
  notes env-example "$(event_patch "$patch" "$CX")" 'apply_patch updating app.ts' 'PATCHED_NAME' || return 1
  notes security "$(event_patch "$patch" "$CX")" 'apply_patch adding tool.py' 'os.system' || return 1
  : > "$T/formatted.log"
  run_hook format "$(event_patch "$patch" "$CX")" > /dev/null
  ran prettier "$CX/app.ts" || ran prettier "app.ts" || { why="prettier did not run on app.ts from apply_patch"; return 1; }
}

# edit-loop
EL="$WORK/el"
mkdir -p "$EL/src" "$EL/.context"
git -C "$EL" init -q -b main
printf '.context/\n' > "$EL/.gitignore"
event_edit_in() { jq -nc --arg p "$1" --arg s "$2" --arg d "$EL" \
  '{hook_event_name: "PostToolUse", session_id: $s, tool_name: "Edit", tool_input: {file_path: $p, old_string: "a", new_string: "b"}, cwd: $d}'; }
event_patch_in() { jq -nc --arg c "$1" --arg s "$2" --arg d "$EL" \
  '{hook_event_name: "PostToolUse", session_id: $s, tool_name: "apply_patch", tool_input: {command: $c}, cwd: $d}'; }
# edit_quietly <path> <session> <times>: that many edits, each without a notice.
edit_quietly() {
  local i got
  for i in $(seq 1 "$3"); do
    got="$(notice edit-loop "$(event_edit_in "$1" "$2")")"
    [ -z "$got" ] || { why="edit-loop spoke on edit $i of $1 in $2: $got"; return 1; }
  done
}
edit_loop_noticed() {
  [ -f "$HOOKS/edit-loop.sh" ] || { why="hooks/edit-loop.sh does not exist"; return 1; }
  local f="$EL/src/app.ts" i got
  for i in $(seq 1 11); do
    got="$(notice edit-loop "$(event_edit_in "$f" e1)")"
    if [ "$i" -eq 5 ] || [ "$i" -eq 10 ]; then
      case "$got" in *src/app.ts*"$i times"*) ;; *) why="edit $i of src/app.ts gave no notice with the file and '$i times': $got"; return 1 ;; esac
    else
      [ -z "$got" ] || { why="edit-loop spoke on edit $i: $got"; return 1; }
    fi
  done
}
edit_loop_apart() {
  [ -f "$HOOKS/edit-loop.sh" ] || { why="hooks/edit-loop.sh does not exist"; return 1; }
  edit_quietly "$EL/src/a.ts" e2 4 || return 1
  edit_quietly "$EL/src/b.ts" e2 1 || return 1
  edit_quietly "$EL/src/a.ts" e3 1 || return 1
  notes edit-loop "$(event_edit_in "$EL/src/a.ts" e2)" 'the fifth edit of a.ts in its own session' 'a.ts' '5 times'
}
edit_loop_codex() {
  local patch i
  patch="$(printf '*** Begin Patch\n*** Update File: src/patched.ts\n@@\n-a\n+b\n*** End Patch\n')"
  for i in 1 2 3 4; do
    [ -z "$(notice edit-loop "$(event_patch_in "$patch" e4)")" ] || { why="edit-loop spoke on apply_patch $i"; return 1; }
  done
  notes edit-loop "$(event_patch_in "$patch" e4)" 'the fifth apply_patch of src/patched.ts' 'patched.ts' '5 times'
}
edit_loop_skips() {
  [ -f "$HOOKS/edit-loop.sh" ] || { why="hooks/edit-loop.sh does not exist"; return 1; }
  edit_quietly "$EL/.context/plan.md" e5 6 || return 1
  edit_quietly "$TMPDIR/scratch.txt" e5 6
}
edit_loop_variables() {
  [ -f "$HOOKS/edit-loop.sh" ] || { why="hooks/edit-loop.sh does not exist"; return 1; }
  local got
  AGENT_NOTICES_EDIT_LOOP_EVERY=3 edit_quietly "$EL/src/v.ts" e6 2 || return 1
  got="$(AGENT_NOTICES_EDIT_LOOP_EVERY=3 notice edit-loop "$(event_edit_in "$EL/src/v.ts" e6)")"
  case "$got" in *"3 times"*reproduces*) ;; *) why="the third edit with AGENT_NOTICES_EDIT_LOOP_EVERY=3 gave no general notice: $got"; return 1 ;; esac
  case "$got" in *skill*) why="the notice names a skill without AGENT_NOTICES_EDIT_LOOP_SKILL: $got"; return 1 ;; esac
  got="$(AGENT_NOTICES_EDIT_LOOP_EVERY=1 AGENT_NOTICES_EDIT_LOOP_SKILL=fix-the-cause notice edit-loop "$(event_edit_in "$EL/src/w.ts" e6)")"
  case "$got" in *'`fix-the-cause`'*) ;; *) why="the notice does not name the skill AGENT_NOTICES_EDIT_LOOP_SKILL sets: $got"; return 1 ;; esac
}

# sequential
event_call() { jq -nc --arg t "$1" --arg s "$2" --arg d "$WORK" \
  '{hook_event_name: "PostToolUse", session_id: $s, tool_name: $t, tool_input: {}, tool_response: {}, cwd: $d}'; }
# calls_quietly <session> <times>: that many Claude Code calls 0.6 seconds apart, each without a notice.
calls_quietly() {
  local i got
  for i in $(seq 1 "$2"); do
    got="$(CLAUDECODE=1 notice sequential "$(event_call Read "$1")")"
    [ -z "$got" ] || { why="sequential spoke on call $i of $1: $got"; return 1; }
    sleep 0.6
  done
}
sequential_noticed() {
  [ -f "$HOOKS/sequential.sh" ] || { why="hooks/sequential.sh does not exist"; return 1; }
  calls_quietly q1 9 || return 1
  CLAUDECODE=1 notes sequential "$(event_call Bash q1)" 'the tenth call in a row' '10' || return 1
  AGENT_NOTICES_SEQUENTIAL_AFTER=3 calls_quietly q2 2 || return 1
  CLAUDECODE=1 AGENT_NOTICES_SEQUENTIAL_AFTER=3 notes sequential "$(event_call Read q2)" 'the third call with AGENT_NOTICES_SEQUENTIAL_AFTER=3' '3'
}
# One call alone, two calls together, then two alone: counted one at a time, they would reach 3.
# The two calls together start at once; on a loaded machine one may start more than 200 milliseconds
# late, so the run is tried up to three times, each in a new session. A hook that never starts the
# count over fails all three.
together_once() {
  local s="$1" a b
  a="$(event_call Read "$s")" b="$(event_call Grep "$s")"
  calls_quietly "$s" 1 || return 1
  (cd "$WORK" && printf '%s' "$a" | CLAUDECODE=1 bash "$HOOKS/sequential.sh" > "$T/$s-a" 2>/dev/null) &
  (cd "$WORK" && printf '%s' "$b" | CLAUDECODE=1 bash "$HOOKS/sequential.sh" > "$T/$s-b" 2>/dev/null) &
  wait
  sleep 0.6
  calls_quietly "$s" 2 || return 1
  [ ! -s "$T/$s-a" ] && [ ! -s "$T/$s-b" ] || { why="two calls together still counted as one at a time: $(cat "$T/$s-a" "$T/$s-b")"; return 1; }
}
sequential_together() {
  [ -f "$HOOKS/sequential.sh" ] || { why="hooks/sequential.sh does not exist"; return 1; }
  local s status=1
  export AGENT_NOTICES_SEQUENTIAL_AFTER=3
  for s in q3a q3b q3c; do
    together_once "$s" && { status=0; break; }
  done
  unset AGENT_NOTICES_SEQUENTIAL_AFTER
  return "$status"
}
sequential_outside() {
  [ -f "$HOOKS/sequential.sh" ] || { why="hooks/sequential.sh does not exist"; return 1; }
  AGENT_NOTICES_SEQUENTIAL_AFTER=1 quiet sequential "$(event_call Bash q4)" 'a call without CLAUDECODE=1'
}

# Where the counts are kept
counts_private() {
  local d="$HOME/.local/share/agent-notices" sub old new
  for sub in edit-loop sequential; do
    [ -d "$d/$sub" ] || { why="no $sub folder under the data folder"; return 1; }
    old="$d/$sub/old-count" new="$d/$sub/recent-count"
    : > "$old"; : > "$new"
    python3 -c 'import os, sys, time; os.utime(sys.argv[1], (time.time() - 8 * 86400,) * 2); os.utime(sys.argv[2], (time.time() - 6 * 86400,) * 2)' "$old" "$new"
  done
  notice edit-loop "$(event_edit_in "$EL/src/prune.ts" e7)" > /dev/null
  CLAUDECODE=1 notice sequential "$(event_call Read q5)" > /dev/null
  for sub in edit-loop sequential; do
    [ ! -e "$d/$sub/old-count" ] || { why="a $sub count file 8 days old was not removed"; return 1; }
    [ -e "$d/$sub/recent-count" ] || { why="a $sub count file 6 days old was removed"; return 1; }
  done
  python3 - "$d" <<'PY' || { why="a count folder or file is readable by others"; return 1; }
import os, stat, sys
for sub in ("edit-loop", "sequential"):
    folder = os.path.join(sys.argv[1], sub)
    if stat.S_IMODE(os.stat(folder).st_mode) != 0o700:
        sys.exit(1)
    for name in os.listdir(folder):
        if name.endswith("-count"):
            continue
        if stat.S_IMODE(os.stat(os.path.join(folder, name)).st_mode) & 0o077:
            sys.exit(1)
PY
  local stray
  stray="$(find "$T" \( -name '*edit-loop*' -o -name '*sequential*' \) -not -path "$d/*" -not -path "$d" 2>/dev/null)"
  [ -z "$stray" ] || { why="counts were kept outside the data folder: $stray"; return 1; }
}

# The pages
pages_describe() {
  local page word
  for page in docs/how-it-works.md docs/how-it-works.ja.md; do
    for word in edit-loop sequential CLAUDECODE AGENT_NOTICES_EDIT_LOOP_SKILL; do
      grep -qF "$word" "$PLUGIN/$page" || { why="$page does not name $word"; return 1; }
    done
  done
}

# The plugin's files
no_startup_scan() {
  local hj="$HOOKS/hooks.json"
  [ -f "$hj" ] || { why="hooks/hooks.json does not exist"; return 1; }
  local starts
  starts="$(jq -r '.hooks.SessionStart // [] | .[].hooks[].command' "$hj")"
  [ -n "$starts" ] || { why="hooks.json has no SessionStart hook"; return 1; }
  case "$starts" in *presence.sh*) ;; *) why="the SessionStart hook is not presence.sh"; return 1 ;; esac
  [ "$(printf '%s\n' "$starts" | grep -vc presence.sh)" -eq 0 ] || { why="hooks other than presence.sh run at session start: $starts"; return 1; }
  if grep -rlE '\.zshrc|\.bashrc|\.zprofile|config\.fish' "$HOOKS" > /dev/null 2>&1; then
    why="a hook reads shell startup files: $(grep -rlE '\.zshrc|\.bashrc|\.zprofile|config\.fish' "$HOOKS")"; return 1
  fi
}
manifests_declare_hooks() {
  local claude="$PLUGIN/.claude-plugin/plugin.json" codex="$PLUGIN/.codex-plugin/plugin.json"
  [ -f "$claude" ] && [ -f "$codex" ] || { why="a plugin.json is missing"; return 1; }
  [ "$(jq -c '.hooks' "$claude")" = "$(jq -c '.hooks' "$codex")" ] || { why="the two manifests declare different hooks"; return 1; }
  local file
  file="$(jq -r '.hooks // empty' "$claude")"
  [ -n "$file" ] && [ -f "$PLUGIN/${file#./}" ] || { why="the manifests name no hooks file that exists"; return 1; }
  local cmd script
  while IFS= read -r cmd; do
    script="$(printf '%s' "$cmd" | sed -n 's/.*\${CLAUDE_PLUGIN_ROOT}\/\([^"]*\)".*/\1/p')"
    [ -n "$script" ] && [ -f "$PLUGIN/$script" ] || { why="hooks.json runs a script that does not exist: $cmd"; return 1; }
  done < <(jq -r '.hooks[][].hooks[].command' "$PLUGIN/${file#./}")
}
readmes_name_variables() {
  [ -f "$PLUGIN/README.md" ] && [ -f "$PLUGIN/README.ja.md" ] || { why="README.md or README.ja.md is missing"; return 1; }
  local vars v
  vars="$(grep -rhoE 'AGENT_NOTICES_[A-Z_]+' "$HOOKS" 2>/dev/null | sort -u)"
  [ -n "$vars" ] || { why="the hooks read no AGENT_NOTICES_ variable"; return 1; }
  for v in $vars; do
    grep -q "$v" "$PLUGIN/README.md" || { why="README.md does not name $v"; return 1; }
    grep -q "$v" "$PLUGIN/README.ja.md" || { why="README.ja.md does not name $v"; return 1; }
  done
}

# No hook stops or replaces a call, in any run above.
no_hook_stops() {
  local hooks
  hooks="$(cut -f1 "$RUNS" | sort -u | wc -l | tr -d ' ')"
  [ "$hooks" -ge 11 ] || { why="only $hooks hooks ran in the tests, not 11"; return 1; }
  if awk -F'\t' '$2 != 0' "$RUNS" | grep -q .; then
    why="a hook exited non-zero: $(awk -F'\t' '$2 != 0 {print $1}' "$RUNS" | sort -u | tr '\n' ' ')"; return 1
  fi
  if cut -f3 "$RUNS" | grep -qE '"permissionDecision"|"decision"|"continue" *: *false'; then
    why="a hook returned a decision: $(cut -f3 "$RUNS" | grep -E '"permissionDecision"|"decision"|"continue" *: *false' | head -1)"; return 1
  fi
}

check "pipefail-grep notes grep -q in a pipefail script" pipefail_noticed
check "pipefail-grep stays quiet without pipefail or a piped grep -q" pipefail_quiet
check "nohup notes a detached start" nohup_noticed
check "nohup stays quiet for quotes, && and redirects" nohup_quiet
check "grep-binary notes a binary file that holds the pattern" grep_binary_noticed
check "grep-binary stays quiet when nothing is hidden" grep_binary_quiet
check "branch notes a switch that did not take effect" branch_switch_noticed
check "branch notes a commit on a branch the session did not switch to" branch_commit_noticed
check "branch stays quiet when the branch is as asked" branch_quiet
check "env-example notes a new variable in each language" env_example_noticed
check "env-example stays quiet when the example file is complete" env_example_quiet
check "tmp-space notes a temporary directory that runs short" tmp_noticed
check "tmp-space stays quiet with enough space" tmp_quiet
check "security adds the upstream reminder for a risky pattern" security_noticed
check "security stays quiet for safe code and calls nothing outside" security_quiet
check "the copied patterns.py matches its notice" patterns_notice_matches
check "format runs the project's own formatter for each language" format_runs
check "format installs nothing and runs nothing unnamed" format_nothing_unnamed
check "format tells the agent when it changed the file" format_tells_change
check "presence creates the file at start and removes it at end" presence_start_end
check "presence does nothing without its variable" presence_unset
check "the logs are off by default" logs_off
check "skill-log records the name, times, and outcome" skill_log_on
check "mcp-log records the server, tool, times, and outcome" mcp_log_on
check "the logs keep no arguments or results" logs_no_arguments
check "each hook turns off with its own variable" turn_off_each
check "the edit hooks read a Codex apply_patch call" codex_patch
check "edit-loop notes the fifth edit of one file and every fifth after it" edit_loop_noticed
check "edit-loop counts each file and each session apart" edit_loop_apart
check "edit-loop counts a Codex apply_patch edit" edit_loop_codex
check "edit-loop stays quiet for ignored and temporary files" edit_loop_skips
check "edit-loop names the skill and the count its variables set" edit_loop_variables
check "sequential notes ten calls in a row made one at a time" sequential_noticed
check "sequential starts over when calls come together" sequential_together
check "sequential stays quiet outside Claude Code" sequential_outside
check "the counts stay private in the data folder and old ones are removed" counts_private
check "the pages describe edit-loop and sequential" pages_describe
check "agent-notices leaves the startup-file scan to secure-dotfile" no_startup_scan
check "both manifests declare the same hooks" manifests_declare_hooks
check "the READMEs name every variable" readmes_name_variables
check "no hook stops a tool call" no_hook_stops

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
printf 'checks: %d\n' "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
