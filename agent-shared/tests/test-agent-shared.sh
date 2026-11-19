#!/usr/bin/env bash
# Tests for agent-shared with a throwaway HOME for every scenario.
# A stand-in for `codex app-server` answers the trust calls and logs them, so no real agent settings
# are read or written. Only the uv check builds the package, into a throwaway tool folder.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PKG="$(cd "$HERE/.." && pwd)"
ROOT="$(cd "$PKG/.." && pwd)"
REAL_HOME="$HOME"
PASS=0
FAIL=0
T="$(mktemp -d)"
T="$(cd "$T" && pwd -P)"
trap 'rm -rf "$T"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; [ -n "$why" ] && printf '      %s\n' "$why"; }
check() { why=""; if "$2"; then ok "$1"; else ng "$1"; fi; }

# The stand-in for `codex app-server`: lists the hooks in $CODEX_HOME/hooks.json with a hash of each
# command, reports an empty trust state, accepts every write, and logs each message to $STUB_LOG.
mkdir -p "$T/bin"
cat > "$T/bin/codex" <<'PY'
#!/usr/bin/env python3
import hashlib
import json
import os
import sys

if sys.argv[1:] != ["app-server"]:
    sys.exit(2)
home = os.environ["CODEX_HOME"]
log = os.environ.get("STUB_LOG")


def reply(request_id, result):
    sys.stdout.write(json.dumps({"id": request_id, "result": result}) + "\n")
    sys.stdout.flush()


for line in sys.stdin:
    message = json.loads(line)
    if log:
        with open(log, "a") as handle:
            handle.write(json.dumps(message) + "\n")
    method, request_id = message.get("method"), message.get("id")
    if request_id is None:
        continue
    if method == "hooks/list":
        place = os.path.join(home, "hooks.json")
        data = json.load(open(place)) if os.path.exists(place) else {}
        hooks = []
        for event, groups in (data.get("hooks") or {}).items():
            for group_index, group in enumerate(groups):
                for hook_index, hook in enumerate(group.get("hooks") or []):
                    command = hook.get("command", "")
                    hooks.append({
                        "source": "user", "sourcePath": place, "command": command,
                        "key": "%s:%s:%d:%d" % (place, event, group_index, hook_index),
                        "currentHash": "sha256:" + hashlib.sha256(command.encode()).hexdigest(),
                    })
        reply(request_id, {"data": [{"hooks": hooks}]})
    elif method == "config/read":
        reply(request_id, {"layers": [{"name": {"type": "user"}, "config": {"hooks": {"state": {}}}, "version": "v1"}]})
    elif method == "config/batchWrite":
        reply(request_id, {"status": "ok"})
    else:
        reply(request_id, {})
PY
chmod +x "$T/bin/codex"

# A new throwaway HOME with two skills, two rules, and two hooks in ~/.shared, and settings that already
# hold the user's own entries.
fresh() {
  export HOME="$T/home-$1"
  export AGENT_SHARED_CODEX_BIN="$T/bin/codex"
  export STUB_LOG="$HOME/codex-calls.jsonl"
  unset AGENT_SHARED_STATE
  RUN_DIR="$HOME"
  mkdir -p "$HOME/.shared/skills/alpha" "$HOME/.shared/skills/beta" "$HOME/.shared/rules" "$HOME/.claude" "$HOME/.codex"
  printf -- '---\nname: alpha\ndescription: Alpha.\n---\nAlpha.\n' > "$HOME/.shared/skills/alpha/SKILL.md"
  printf -- '---\nname: beta\ndescription: Beta.\n---\nBeta.\n' > "$HOME/.shared/skills/beta/SKILL.md"
  printf '# One\nRule one.\n' > "$HOME/.shared/rules/one.md"
  printf '# Two\nRule two.\n' > "$HOME/.shared/rules/two.md"
  cat > "$HOME/.shared/hooks.json" <<'JSON'
{"hooks": {
  "PreToolUse": [
    {"matcher": "Bash", "hooks": [{"type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/guard.sh"}]},
    {"matcher": "Edit", "hooks": [{"type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/guard.sh"}]}
  ],
  "Stop": [{"hooks": [{"type": "command", "command": "echo stop"}]}]
}}
JSON
  cat > "$HOME/.claude/settings.json" <<'JSON'
{
  "model": "opus",
  "permissions": {"allow": ["Bash(ls)"]},
  "hooks": {"PreToolUse": [{"matcher": "Read", "hooks": [{"type": "command", "command": "echo mine"}]}]}
}
JSON
  printf '# My notes\n\nKeep this line.\n' > "$HOME/.codex/AGENTS.md"
  cat > "$HOME/.codex/hooks.json" <<'JSON'
{"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "echo my-codex-hook"}]}]}}
JSON
}

# Runs agent-shared from the package source in $RUN_DIR. Output goes to $T/out, the exit code to $rc.
run() {
  (cd "$RUN_DIR" && PYTHONPATH="$PKG/src" python3 -m agent_shared "$@") > "$T/out" 2>&1
  rc=$?
}

# True when $1 is a link that resolves to the folder or file $2.
real() { python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$1"; }
links_to() { [ -L "$1" ] && [ -e "$1" ] && [ "$(real "$1")" = "$(real "$2")" ]; }
deployed() { run deploy; [ "$rc" = 0 ] || { why="deploy exited $rc: $(tail -1 "$T/out")"; return 1; }; }
mode() { python3 -c 'import os, sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$1"; }

uv_installs() {
  command -v uv > /dev/null || { why="uv is not installed"; return 1; }
  HOME="$REAL_HOME" UV_TOOL_DIR="$T/uv/tools" UV_TOOL_BIN_DIR="$T/uv/bin" uv tool install --quiet "$PKG" > "$T/uv.out" 2>&1 \
    || { why="uv tool install failed: $(tail -1 "$T/uv.out")"; return 1; }
  [ -x "$T/uv/bin/agent-shared" ] || { why="no agent-shared command in the tool bin folder"; return 1; }
  [ -z "$(find "$T/uv/tools" -name SKILL.md -print -quit)" ] || { why="a SKILL.md was installed with the command"; return 1; }
  HOME="$REAL_HOME" "$T/uv/bin/agent-shared" --help > /dev/null 2>&1 || { why="agent-shared --help failed"; return 1; }
}

links_skills() {
  fresh links
  deployed || return 1
  local skill place
  for skill in alpha beta; do
    for place in "$HOME/.claude/skills" "$HOME/.agents/skills"; do
      links_to "$place/$skill" "$HOME/.shared/skills/$skill" || { why="$place/$skill is not a link to the shared copy"; return 1; }
    done
  done
}

no_codex_skills() {
  fresh codexskills
  deployed || return 1
  [ -L "$HOME/.agents/skills/alpha" ] || { why="the shared agent folder got no skill"; return 1; }
  [ ! -e "$HOME/.codex/skills" ] || { why="something was placed in ~/.codex/skills"; return 1; }
}

writes_rules() {
  fresh rules
  local before="$T/agents-before.md"
  cp "$HOME/.codex/AGENTS.md" "$before"
  deployed || return 1
  links_to "$HOME/.claude/rules/one.md" "$HOME/.shared/rules/one.md" || { why="~/.claude/rules/one.md is not a link to the rule"; return 1; }
  links_to "$HOME/.claude/rules/two.md" "$HOME/.shared/rules/two.md" || { why="~/.claude/rules/two.md is not a link to the rule"; return 1; }
  python3 - "$before" "$HOME/.codex/AGENTS.md" <<'PY' || { why="$(cat "$before.why" 2>/dev/null)"; return 1; }
import sys
before = open(sys.argv[1]).read()
after = open(sys.argv[2]).read()
lines = after.splitlines(keepends=True)
begins = [i for i, line in enumerate(lines) if line.startswith("<!-- agent-shared begin")]
ends = [i for i, line in enumerate(lines) if line.startswith("<!-- agent-shared end")]
problem = None
if len(begins) != 1 or len(ends) != 1 or begins[0] > ends[0]:
    problem = "AGENTS.md does not have exactly one block"
elif "".join(lines[:begins[0]]) + "".join(lines[ends[0] + 1:]) != before:
    problem = "the lines outside the block changed"
elif "Rule one." not in after or "Rule two." not in after:
    problem = "the block does not hold both rules"
if problem:
    open(sys.argv[1] + ".why", "w").write(problem)
    sys.exit(1)
PY
}

adds_hooks() {
  fresh hooks
  deployed || return 1
  python3 - "$HOME" <<'PY' || { why="$(cat "$T/hooks.why" 2>/dev/null)"; return 1; }
import json, os, sys
home = sys.argv[1]
def commands(path, event):
    data = json.load(open(path))
    return [hook["command"] for group in data.get("hooks", {}).get(event, []) for hook in group.get("hooks", [])]
def marked(command):
    return "\n" in command and command.rsplit("\n", 1)[1].startswith("# agent-shared")
problem = None
settings = json.load(open(os.path.join(home, ".claude/settings.json")))
guard = "bash %s/.shared/hooks/guard.sh" % home
for path in (os.path.join(home, ".claude/settings.json"), os.path.join(home, ".codex/hooks.json")):
    pre = commands(path, "PreToolUse")
    stop = commands(path, "Stop")
    if sum(1 for c in pre if marked(c) and c.startswith(guard)) != 2:
        problem = "%s does not have the guard hook once for each of its two matchers, with the source folder filled in" % path
    elif not any(marked(c) and c.startswith("echo stop") for c in stop):
        problem = "%s has no marked stop hook" % path
if problem is None and (settings.get("model") != "opus" or settings.get("permissions") != {"allow": ["Bash(ls)"]}):
    problem = "settings outside hooks changed"
if problem is None and "echo mine" not in commands(os.path.join(home, ".claude/settings.json"), "PreToolUse"):
    problem = "the hand-written hook is gone"
if problem:
    open(os.environ["T"] + "/hooks.why", "w").write(problem)
    sys.exit(1)
PY
}

trusts_codex_hooks() {
  fresh trust
  deployed || return 1
  python3 - "$HOME" <<'PY' || { why="$(cat "$T/trust.why" 2>/dev/null)"; return 1; }
import json, os, sys
home = sys.argv[1]
problem = None
log = os.path.join(home, "codex-calls.jsonl")
writes = [json.loads(l) for l in open(log)] if os.path.exists(log) else []
writes = [m for m in writes if m.get("method") == "config/batchWrite"]
if not writes:
    problem = "agent-shared never asked Codex to write the trust state"
else:
    value = writes[-1]["params"]["edits"][0]["value"]
    data = json.load(open(os.path.join(home, ".codex/hooks.json")))
    place = os.path.join(home, ".codex/hooks.json")
    marked, hand = set(), set()
    for event, groups in data["hooks"].items():
        for gi, group in enumerate(groups):
            for hi, hook in enumerate(group["hooks"]):
                key = "%s:%s:%d:%d" % (place, event, gi, hi)
                c = hook["command"]
                (marked if "\n" in c and c.rsplit("\n", 1)[1].startswith("# agent-shared") else hand).add(key)
    trusted = {k for k, v in value.items() if isinstance(v, dict) and v.get("trusted_hash")}
    if trusted != marked:
        problem = "trusted keys %s, placed hooks %s" % (sorted(trusted), sorted(marked))
if problem:
    open(os.path.join(os.environ["T"], "trust.why"), "w").write(problem)
    sys.exit(1)
PY
}

without_codex() {
  fresh nocodex
  export AGENT_SHARED_CODEX_BIN="$T/bin/no-such-codex"
  deployed || return 1
  grep -q '/hooks' "$T/out" || { why="the run did not say how to trust the hooks in Codex"; return 1; }
  [ -L "$HOME/.claude/skills/alpha" ] || { why="the other agents were not deployed"; return 1; }
}

repo_skills() {
  fresh repo
  local repo="$T/repo"
  mkdir -p "$repo/.shared/skills/gamma"
  git -C "$repo" init -q
  printf -- '---\nname: gamma\ndescription: Gamma.\n---\nGamma.\n' > "$repo/.shared/skills/gamma/SKILL.md"
  RUN_DIR="$repo"
  deployed || return 1
  links_to "$repo/.claude/skills/gamma" "$repo/.shared/skills/gamma" || { why="the repository's .claude/skills/gamma is not a link to its skill"; return 1; }
  links_to "$repo/.agents/skills/gamma" "$repo/.shared/skills/gamma" || { why="the repository's .agents/skills/gamma is not a link to its skill"; return 1; }
}

removes_taken_out() {
  fresh remove
  deployed || return 1
  rm -rf "$HOME/.shared/skills/beta" "$HOME/.shared/rules/two.md"
  cat > "$HOME/.shared/hooks.json" <<'JSON'
{"hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/guard.sh"}]}]}}
JSON
  deployed || return 1
  [ ! -e "$HOME/.claude/skills/beta" ] && [ ! -L "$HOME/.claude/skills/beta" ] || { why="beta is still in ~/.claude/skills"; return 1; }
  [ ! -L "$HOME/.agents/skills/beta" ] || { why="beta is still in ~/.agents/skills"; return 1; }
  [ ! -L "$HOME/.claude/rules/two.md" ] || { why="rule two is still in ~/.claude/rules"; return 1; }
  ! grep -q 'Rule two.' "$HOME/.codex/AGENTS.md" || { why="rule two is still in AGENTS.md"; return 1; }
  ! grep -q 'echo stop' "$HOME/.claude/settings.json" || { why="the stop hook is still in settings.json"; return 1; }
  [ -L "$HOME/.claude/skills/alpha" ] && [ -L "$HOME/.claude/rules/one.md" ] && grep -q 'guard.sh' "$HOME/.claude/settings.json" \
    || { why="an item that stayed in the source was removed"; return 1; }
}

leaves_unmarked() {
  fresh unmarked
  mkdir -p "$HOME/.claude/skills/mine"
  printf 'my own skill\n' > "$HOME/.claude/skills/mine/SKILL.md"
  cp "$HOME/.claude/skills/mine/SKILL.md" "$T/mine-before"
  cp "$HOME/.codex/AGENTS.md" "$T/agents-unmarked-before"
  deployed || return 1
  [ -L "$HOME/.claude/skills/alpha" ] || { why="the run placed nothing"; return 1; }
  cmp -s "$HOME/.claude/skills/mine/SKILL.md" "$T/mine-before" || { why="the hand-made skill changed"; return 1; }
  head -c "$(wc -c < "$T/agents-unmarked-before")" "$HOME/.codex/AGENTS.md" | cmp -s - "$T/agents-unmarked-before" \
    || { why="the lines of AGENTS.md before the block changed"; return 1; }
  python3 - "$HOME" <<'PY' || { why="a hand-written hook changed or moved"; return 1; }
import json, os, sys
home = sys.argv[1]
s = json.load(open(os.path.join(home, ".claude/settings.json")))
c = json.load(open(os.path.join(home, ".codex/hooks.json")))
mine = [g for g in s["hooks"]["PreToolUse"] if g.get("matcher") == "Read"]
codex = [h for g in c["hooks"]["Stop"] for h in g["hooks"] if h["command"] == "echo my-codex-hook"]
sys.exit(0 if mine == [{"matcher": "Read", "hooks": [{"type": "command", "command": "echo mine"}]}] and len(codex) == 1 else 1)
PY
}

skips_plugin_skills() {
  fresh plugin
  local cache="$HOME/.claude/plugins/cache/market/kit/1.0.0"
  mkdir -p "$cache/skills/alpha"
  printf -- '---\nname: alpha\ndescription: Alpha from a plugin.\n---\n' > "$cache/skills/alpha/SKILL.md"
  printf '{"version": 2, "plugins": {"kit@market": [{"scope": "user", "installPath": "%s", "version": "1.0.0"}]}}\n' "$cache" \
    > "$HOME/.claude/plugins/installed_plugins.json"
  deployed || return 1
  [ ! -e "$HOME/.claude/skills/alpha" ] && [ ! -L "$HOME/.claude/skills/alpha" ] || { why="alpha was placed for Claude Code although the plugin has it"; return 1; }
  [ -L "$HOME/.claude/skills/beta" ] || { why="beta was not placed for Claude Code"; return 1; }
  [ -L "$HOME/.agents/skills/alpha" ] || { why="alpha was not placed for the agents without the plugin"; return 1; }
  grep 'alpha' "$T/out" | grep -q 'kit@market' || { why="the run did not name the skill and the plugin"; return 1; }
}

refuses_same_name() {
  fresh twosources
  mkdir -p "$T/extra/skills/alpha"
  printf -- '---\nname: alpha\ndescription: Another alpha.\n---\n' > "$T/extra/skills/alpha/SKILL.md"
  run deploy --source "$T/extra"
  [ "$rc" = 1 ] || { why="deploy exited $rc"; return 1; }
  grep -q "$T/extra" "$T/out" && grep -qE '~/\.shared|'"$HOME"'/\.shared' "$T/out" || { why="the run did not name both sources"; return 1; }
  [ ! -L "$HOME/.claude/skills/alpha" ] && [ ! -L "$HOME/.claude/skills/beta" ] && [ ! -L "$HOME/.agents/skills/beta" ] \
    || { why="the run placed skills although it refused"; return 1; }
}

refuses_hand_hook() {
  fresh handhook
  python3 - "$HOME/.claude/settings.json" <<'PY'
import json, sys
path = sys.argv[1]
data = json.load(open(path))
data["hooks"]["Stop"] = [{"hooks": [{"type": "command", "command": "echo stop"}]}]
open(path, "w").write(json.dumps(data, indent=2) + "\n")
PY
  cp "$HOME/.claude/settings.json" "$T/settings-before"
  run deploy
  [ "$rc" = 1 ] || { why="deploy exited $rc"; return 1; }
  cmp -s "$HOME/.claude/settings.json" "$T/settings-before" || { why="settings.json changed"; return 1; }
  grep -q 'echo stop' "$T/out" || { why="the run did not name the hook"; return 1; }
}

user_row() {
  fresh row
  printf '{"version": 1, "agents": [{"name": "tester", "skills": "~/.tester/skills"}]}\n' > "$HOME/.shared/agents.json"
  deployed || return 1
  links_to "$HOME/.tester/skills/alpha" "$HOME/.shared/skills/alpha" || { why="the added agent got no skill"; return 1; }
  [ -L "$HOME/.claude/skills/alpha" ] || { why="the default agents lost their skills"; return 1; }
}

private_record() {
  fresh record
  deployed || return 1
  local dir="$HOME/.local/share/agent-shared" file
  [ -d "$dir" ] || { why="no record folder at ~/.local/share/agent-shared"; return 1; }
  [ "$(mode "$dir")" = 0o700 ] || { why="the record folder has mode $(mode "$dir")"; return 1; }
  file="$(find "$dir" -type f -print -quit)"
  [ -n "$file" ] && [ "$(mode "$file")" = 0o600 ] || { why="no record file readable only by the user"; return 1; }
  fresh record-moved
  export AGENT_SHARED_STATE="$T/state"
  deployed || return 1
  [ -n "$(find "$T/state" -type f -print -quit 2>/dev/null)" ] || { why="AGENT_SHARED_STATE did not move the record"; return 1; }
}

readmes_first() {
  local f first
  for f in README.md README.ja.md; do
    first="$(grep -m1 '^## ' "$ROOT/$f")"
    [ "$first" = "## agent-shared" ] || { why="the first section of $f is '$first'"; return 1; }
  done
}

getting_started() {
  local f
  for f in docs/getting-started.md docs/getting-started.ja.md; do
    ! grep -qF '~/.codex/skills' "$ROOT/$f" || { why="$f still names ~/.codex/skills"; return 1; }
    grep -qF '~/.agents/skills' "$ROOT/$f" || { why="$f does not name ~/.agents/skills"; return 1; }
  done
}

export T
# Runs `agent-shared hooks` with stdout and stderr kept apart in $T/hooks.out and $T/hooks.err.
hooks_run() {
  (cd "$RUN_DIR" && PYTHONPATH="$PKG/src" python3 -m agent_shared hooks "$@") > "$T/hooks.out" 2> "$T/hooks.err"
  rc=$?
}

# Prints every path under $1 with its kind, link target, and content hash, to compare before and after.
snapshot() {
  python3 - "$1" <<'PY'
import hashlib, os, sys
for here, dirs, files in os.walk(sys.argv[1]):
    dirs.sort()
    for name in sorted(dirs + files):
        path = os.path.join(here, name)
        if os.path.islink(path):
            print("link", path, os.readlink(path))
        elif os.path.isdir(path):
            print("dir", path)
        else:
            print("file", path, hashlib.sha256(open(path, "rb").read()).hexdigest())
PY
}

hooks_match_deploy() {
  fresh hooks-match
  hooks_run --agent "Claude Code"
  [ "$rc" = 0 ] || { why="hooks exited $rc: $(tail -1 "$T/hooks.err")"; return 1; }
  cp "$T/hooks.out" "$T/hooks-claude.json"
  deployed || return 1
  python3 - "$T/hooks-claude.json" "$HOME/.claude/settings.json" <<'PY' > "$T/compare.out" 2>&1 || { why="$(tail -1 "$T/compare.out")"; return 1; }
import json, sys
printed = json.load(open(sys.argv[1]))
settings = json.load(open(sys.argv[2]))
mark = "# agent-shared 1 source="
placed = {}
for event, groups in settings["hooks"].items():
    kept = [g for g in groups if all(h["command"].rsplit("\n", 1)[-1].startswith(mark) for h in g["hooks"])]
    if kept:
        placed[event] = kept
if not placed:
    sys.exit("deploy placed no marked hooks to compare with")
if printed.get("hooks") != placed:
    sys.exit("the printed hooks differ from the marked hooks deploy added")
PY
}

hooks_by_tools() {
  fresh hooks-tools
  cat > "$HOME/.shared/hooks.json" <<'JSON'
{"hooks": {
  "Stop": [
    {"hooks": [{"type": "command", "command": "echo stop"}]},
    {"hooks": [{"type": "command", "command": "echo claude-only", "tools": ["Claude Code"]}]}
  ]
}}
JSON
  hooks_run --agent Codex
  [ "$rc" = 0 ] || { why="hooks --agent Codex exited $rc: $(tail -1 "$T/hooks.err")"; return 1; }
  grep -q 'echo stop' "$T/hooks.out" || { why="the hook for every agent is missing for Codex"; return 1; }
  ! grep -q 'claude-only' "$T/hooks.out" || { why="a hook for Claude Code only was printed for Codex"; return 1; }
  hooks_run --agent "Claude Code"
  grep -q 'claude-only' "$T/hooks.out" || { why="the hook for Claude Code only is missing for Claude Code"; return 1; }
}

hooks_every_source() {
  fresh hooks-sources
  mkdir -p "$T/extra-source"
  printf '%s\n' '{"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "echo extra"}]}]}}' > "$T/extra-source/hooks.json"
  hooks_run --agent "Claude Code" --source "$T/extra-source"
  [ "$rc" = 0 ] || { why="hooks exited $rc: $(tail -1 "$T/hooks.err")"; return 1; }
  grep -q 'echo extra' "$T/hooks.out" || { why="the hook of the --source folder was not printed"; return 1; }
  grep -q 'echo stop' "$T/hooks.out" || { why="the hook of ~/.shared was not printed"; return 1; }
}

hooks_write_nothing() {
  fresh hooks-quiet
  deployed || return 1
  snapshot "$HOME" > "$T/before.txt"
  hooks_run --agent "Claude Code"
  [ "$rc" = 0 ] || { why="hooks exited $rc: $(tail -1 "$T/hooks.err")"; return 1; }
  snapshot "$HOME" > "$T/after.txt"
  cmp -s "$T/before.txt" "$T/after.txt" || { why="hooks changed $(diff "$T/before.txt" "$T/after.txt" | sed -n 2p)"; return 1; }
}

hooks_unknown_agent() {
  fresh hooks-unknown
  hooks_run --agent Nobody
  [ "$rc" = 2 ] || { why="hooks --agent Nobody exited $rc"; return 1; }
  [ ! -s "$T/hooks.out" ] || { why="hooks printed something for an unknown agent"; return 1; }
  grep -q 'Nobody' "$T/hooks.err" || { why="the refusal does not name the agent: $(tail -1 "$T/hooks.err")"; return 1; }
}

hooks_need_agent() {
  fresh hooks-no-agent
  hooks_run
  [ "$rc" = 2 ] || { why="hooks without --agent exited $rc"; return 1; }
  grep -q -- '--agent' "$T/hooks.err" || { why="the refusal does not name --agent: $(tail -1 "$T/hooks.err")"; return 1; }
}

# Runs `agent-shared placed` with stdout and stderr kept apart in $T/placed.out and $T/placed.err.
placed_run() {
  (cd "$RUN_DIR" && PYTHONPATH="$PKG/src" python3 -m agent_shared placed "$@") > "$T/placed.out" 2> "$T/placed.err"
  rc=$?
}
placed_ok() {
  placed_run "$@"
  [ "$rc" = 0 ] || { why="placed exited $rc: $(tail -1 "$T/placed.err")"; return 1; }
}

# A second source in $T/source-$1, deployed with ~/.shared: two skills, one rule, the same hook command
# under two matchers with ${CLAUDE_PLUGIN_ROOT}, a Stop hook without a matcher, and a hook for Claude
# Code only. $SRC names the folder.
full_source() {
  SRC="$T/source-$1"
  mkdir -p "$SRC/skills/delta" "$SRC/skills/epsilon" "$SRC/rules"
  printf -- '---\nname: delta\ndescription: Delta.\n---\nDelta.\n' > "$SRC/skills/delta/SKILL.md"
  printf -- '---\nname: epsilon\ndescription: Epsilon.\n---\nEpsilon.\n' > "$SRC/skills/epsilon/SKILL.md"
  printf '# Three\nRule three.\n' > "$SRC/rules/three.md"
  cat > "$SRC/hooks.json" <<'JSON'
{"hooks": {
  "PreToolUse": [
    {"matcher": "Bash", "hooks": [{"type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/check.sh"}]},
    {"matcher": "Edit", "hooks": [{"type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/check.sh", "timeout": 5}]}
  ],
  "Stop": [
    {"hooks": [{"type": "command", "command": "echo source-stop"}]},
    {"hooks": [{"type": "command", "command": "echo claude-only", "tools": ["Claude Code"]}]}
  ]
}}
JSON
}

# Reads $T/placed.out and runs the Python check on stdin with `out` (the JSON, keys in order), `src`,
# and `home` defined. The check calls fail(<reason>) when it does not hold.
placed_holds() {
  python3 - "$T/placed.out" "${SRC:-}" "$HOME" "$T/placed.why" 3<&0 <<'PY' || { why="$(cat "$T/placed.why" 2>/dev/null)"; return 1; }
import json, os, sys
path, src, home, why = sys.argv[1:]
def fail(reason):
    open(why, "w").write(reason)
    sys.exit(1)
try:
    out = json.load(open(path), object_pairs_hook=lambda pairs: dict(pairs))
except ValueError as error:
    fail("placed did not print JSON (%s)" % error)
exec(os.fdopen(3).read())
PY
}

placed_lists() {
  fresh placed-lists
  full_source lists
  run deploy --source "$SRC"
  [ "$rc" = 0 ] || { why="deploy exited $rc: $(tail -1 "$T/out")"; return 1; }
  placed_ok --source "$SRC" || return 1
  placed_holds <<'PY'
if out.get("source") != src:
    fail("source is %r, not the folder passed" % out.get("source"))
agents = out.get("agents") or {}
for name, hooks in (("Claude Code", 4), ("Codex", 3)):
    agent = agents.get(name)
    if not isinstance(agent, dict):
        fail("%s is missing from agents" % name)
    if agent.get("skills") != ["delta", "epsilon"]:
        fail("%s skills are %r" % (name, agent.get("skills")))
    if agent.get("rules") != ["three.md"]:
        fail("%s rules are %r" % (name, agent.get("rules")))
    if len(agent.get("hooks") or []) != hooks:
        fail("%s has %d hooks, not the %d the source declared for it" % (name, len(agent.get("hooks") or []), hooks))
PY
}

placed_hook_shape() {
  fresh placed-hooks
  full_source hooks
  run deploy --source "$SRC"
  [ "$rc" = 0 ] || { why="deploy exited $rc: $(tail -1 "$T/out")"; return 1; }
  placed_ok --source "$SRC" || return 1
  placed_holds <<'PY'
check = "bash %s/hooks/check.sh" % src
want = {
    "Claude Code": [
        {"event": "PreToolUse", "matcher": "Bash", "command": check},
        {"event": "PreToolUse", "matcher": "Edit", "command": check},
        {"event": "Stop", "command": "echo source-stop"},
        {"event": "Stop", "command": "echo claude-only"},
    ],
    "Codex": [
        {"event": "PreToolUse", "matcher": "Bash", "command": check},
        {"event": "PreToolUse", "matcher": "Edit", "command": check},
        {"event": "Stop", "command": "echo source-stop"},
    ],
}
key = lambda hook: json.dumps(hook, sort_keys=True)
for name, hooks in want.items():
    got = (out.get("agents") or {}).get(name, {}).get("hooks")
    if not isinstance(got, list) or sorted(got, key=key) != sorted(hooks, key=key):
        fail("%s hooks are %r" % (name, got))
PY
}

placed_other_source() {
  fresh placed-other
  # The shape of an app's own folder: skills only, an empty rules folder, and no hooks.
  SRC="$T/source-other"
  mkdir -p "$SRC/skills/gamma" "$SRC/rules"
  printf -- '---\nname: gamma\ndescription: Gamma.\n---\nGamma.\n' > "$SRC/skills/gamma/SKILL.md"
  printf '{"hooks": {}}\n' > "$SRC/hooks.json"
  run deploy --source "$SRC"
  [ "$rc" = 0 ] || { why="deploy exited $rc: $(tail -1 "$T/out")"; return 1; }
  [ -L "$HOME/.claude/skills/alpha" ] || { why="deploy did not place ~/.shared's skills to leave out"; return 1; }
  placed_ok --source "$SRC" || return 1
  placed_holds <<'PY'
for name in ("Claude Code", "Codex"):
    agent = (out.get("agents") or {}).get(name)
    if agent != {"skills": ["gamma"], "rules": [], "hooks": []}:
        fail("%s is %r, with something ~/.shared placed or without gamma" % (name, agent))
PY
}

placed_plugin_skill() {
  fresh placed-plugin
  full_source plugin
  local cache="$HOME/.claude/plugins/cache/market/kit/1.0.0"
  mkdir -p "$cache/skills/delta"
  printf -- '---\nname: delta\ndescription: Delta from a plugin.\n---\n' > "$cache/skills/delta/SKILL.md"
  printf '{"version": 2, "plugins": {"kit@market": [{"scope": "user", "installPath": "%s", "version": "1.0.0"}]}}\n' "$cache" \
    > "$HOME/.claude/plugins/installed_plugins.json"
  run deploy --source "$SRC"
  [ "$rc" = 0 ] || { why="deploy exited $rc: $(tail -1 "$T/out")"; return 1; }
  placed_ok --source "$SRC" || return 1
  placed_holds <<'PY'
agents = out.get("agents") or {}
if (agents.get("Claude Code") or {}).get("skills") != ["epsilon"]:
    fail("Claude Code skills are %r, though its plugin has delta" % (agents.get("Claude Code") or {}).get("skills"))
if (agents.get("Codex") or {}).get("skills") != ["delta", "epsilon"]:
    fail("Codex skills are %r, though delta was placed for it" % (agents.get("Codex") or {}).get("skills"))
PY
}

placed_marked_only() {
  fresh placed-marked
  full_source marked
  run deploy --source "$SRC"
  [ "$rc" = 0 ] || { why="deploy exited $rc: $(tail -1 "$T/out")"; return 1; }
  # The user removes one link, points another somewhere else, and adds a skill and a hook by hand.
  rm "$HOME/.claude/skills/delta"
  rm "$HOME/.agents/skills/epsilon"
  ln -s "$T" "$HOME/.agents/skills/epsilon"
  mkdir -p "$HOME/.claude/skills/mine"
  printf 'my own skill\n' > "$HOME/.claude/skills/mine/SKILL.md"
  python3 - "$HOME/.codex/hooks.json" <<'PY'
import json, sys
path = sys.argv[1]
data = json.load(open(path))
data["hooks"]["Stop"].append({"hooks": [{"type": "command", "command": "echo source-stop-by-hand"}]})
open(path, "w").write(json.dumps(data, indent=2) + "\n")
PY
  placed_ok --source "$SRC" || return 1
  placed_holds <<'PY'
agents = out.get("agents") or {}
if (agents.get("Claude Code") or {}).get("skills") != ["epsilon"]:
    fail("Claude Code skills are %r, with the removed link or the hand-made skill" % (agents.get("Claude Code") or {}).get("skills"))
if (agents.get("Codex") or {}).get("skills") != ["delta"]:
    fail("Codex skills are %r, with the link that now points elsewhere" % (agents.get("Codex") or {}).get("skills"))
commands = [h.get("command") for a in agents.values() for h in a.get("hooks") or []]
for mine in ("echo mine", "echo my-codex-hook", "echo source-stop-by-hand"):
    if mine in commands:
        fail("the hook %r without the mark was listed" % mine)
PY
}

placed_write_nothing() {
  fresh placed-quiet
  full_source quiet
  run deploy --source "$SRC"
  [ "$rc" = 0 ] || { why="deploy exited $rc: $(tail -1 "$T/out")"; return 1; }
  { snapshot "$HOME"; snapshot "$SRC"; } > "$T/before.txt"
  placed_ok --source "$SRC" || return 1
  { snapshot "$HOME"; snapshot "$SRC"; } > "$T/after.txt"
  cmp -s "$T/before.txt" "$T/after.txt" || { why="placed changed $(diff "$T/before.txt" "$T/after.txt" | sed -n 2p)"; return 1; }
}

placed_never_deployed() {
  fresh placed-never
  SRC="$T/source-never"
  mkdir -p "$SRC/skills/zeta"
  printf -- '---\nname: zeta\ndescription: Zeta.\n---\nZeta.\n' > "$SRC/skills/zeta/SKILL.md"
  # Before any deploy there is no record, and after deploying only ~/.shared the record names another source.
  placed_ok --source "$SRC" || return 1
  placed_holds <<'PY' || return 1
empty = {"skills": [], "rules": [], "hooks": []}
if out != {"source": src, "agents": {"Claude Code": empty, "Codex": empty}} or list(out["agents"]) != ["Claude Code", "Codex"]:
    fail("before any deploy placed printed %r" % out)
PY
  printf '{"version": 1, "agents": [{"name": "tester", "skills": "~/.tester/skills"}]}\n' > "$HOME/.shared/agents.json"
  deployed || return 1
  placed_ok --source "$SRC" || return 1
  placed_holds <<'PY'
agents = out.get("agents") or {}
if list(agents) != ["Claude Code", "Codex", "tester"]:
    fail("the agents are %r, not every agent of the table in its order" % list(agents))
for name, agent in agents.items():
    if agent != {"skills": [], "rules": [], "hooks": []}:
        fail("%s is %r for a source never deployed" % (name, agent))
PY
}

placed_bad_hook_file() {
  fresh placed-badhooks
  full_source badhooks
  run deploy --source "$SRC"
  [ "$rc" = 0 ] || { why="deploy exited $rc: $(tail -1 "$T/out")"; return 1; }
  printf '{"hooks": \n' > "$HOME/.codex/hooks.json"
  placed_run --source "$SRC"
  [ "$rc" = 2 ] || { why="placed exited $rc with a hook file that is not JSON"; return 1; }
  [ ! -s "$T/placed.out" ] || { why="placed printed something though it could not read a hook file"; return 1; }
  grep -q 'codex/hooks.json' "$T/placed.err" || { why="the refusal does not name the file: $(tail -1 "$T/placed.err")"; return 1; }
}

placed_broken_block() {
  fresh placed-block
  full_source block
  run deploy --source "$SRC"
  [ "$rc" = 0 ] || { why="deploy exited $rc: $(tail -1 "$T/out")"; return 1; }
  grep '^<!-- agent-shared begin' "$HOME/.codex/AGENTS.md" | tail -1 >> "$HOME/.codex/AGENTS.md"
  placed_run --source "$SRC"
  [ "$rc" = 2 ] || { why="placed exited $rc with a broken rules block"; return 1; }
  [ ! -s "$T/placed.out" ] || { why="placed printed something though the rules block is broken"; return 1; }
  grep -q 'AGENTS.md' "$T/placed.err" || { why="the refusal does not name the file: $(tail -1 "$T/placed.err")"; return 1; }
}

placed_needs_source() {
  fresh placed-nosource
  placed_run
  [ "$rc" = 2 ] || { why="placed without --source exited $rc"; return 1; }
  [ ! -s "$T/placed.out" ] || { why="placed without --source printed something"; return 1; }
  grep -q -- '--source' "$T/placed.err" || { why="the refusal does not name --source: $(tail -1 "$T/placed.err")"; return 1; }
  placed_run --source "$T/no-such-source"
  [ "$rc" = 2 ] || { why="placed with a missing folder exited $rc"; return 1; }
  [ ! -s "$T/placed.out" ] || { why="placed with a missing folder printed something"; return 1; }
  grep -q "$T/no-such-source" "$T/placed.err" || { why="the refusal does not name the folder: $(tail -1 "$T/placed.err")"; return 1; }
}

check "uv tool install puts agent-shared on PATH without any plugin" uv_installs
check "deploy links every skill into the Claude Code and shared agent folders" links_skills
check "deploy places nothing in the deprecated Codex skills folder" no_codex_skills
check "deploy writes rules as links for Claude Code and one block for Codex" writes_rules
check "deploy adds marked hooks and keeps the other settings" adds_hooks
check "deploy writes Codex trust for the hooks it placed" trusts_codex_hooks
check "without codex the run prints how to trust hooks in Codex" without_codex
check "deploy in a repository links its skills into its own folders" repo_skills
check "a removed skill, rule, or hook is taken out on the next run" removes_taken_out
check "entries without the mark are left unchanged" leaves_unmarked
check "a skill an installed plugin already has is not placed for that agent" skips_plugin_skills
check "two sources with the same skill name are refused" refuses_same_name
check "a hand-written hook with a declared command is refused" refuses_hand_hook
check "a row in the user's table adds an agent" user_row
check "the record of placed items is kept readable only by the user" private_record
check "the READMEs put agent-shared before the plugins" readmes_first
check "getting started no longer points Codex at its deprecated skills folder" getting_started
check "hooks prints the groups deploy adds for an agent" hooks_match_deploy
check "hooks leaves out a hook whose tools name another agent" hooks_by_tools
check "hooks includes the hooks of every source" hooks_every_source
check "hooks writes nothing" hooks_write_nothing
check "hooks refuses an agent the table does not have" hooks_unknown_agent
check "hooks refuses a call without --agent" hooks_need_agent
check "placed lists what a source placed for each agent" placed_lists
check "placed prints each hook without the mark" placed_hook_shape
check "placed leaves out what another source placed" placed_other_source
check "placed leaves out a skill a plugin already has" placed_plugin_skill
check "placed counts only what still carries the mark" placed_marked_only
check "placed writes nothing" placed_write_nothing
check "placed prints empty lists for a source never deployed" placed_never_deployed
check "placed refuses a hook file it cannot read" placed_bad_hook_file
check "placed refuses a broken rules block" placed_broken_block
check "placed refuses a call without an existing source" placed_needs_source

printf '%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
