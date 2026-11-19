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

printf '%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
