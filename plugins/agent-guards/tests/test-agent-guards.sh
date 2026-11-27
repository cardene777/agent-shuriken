#!/usr/bin/env bash
# Tests for the agent-guards hooks. Each hook reads one PreToolUse event as JSON on stdin and prints
# a deny decision, or nothing when it lets the command through. HOME points at a throwaway folder,
# so no real list file, record, or repository is read or written. Key-shaped values are built while
# the tests run, so this file holds none.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$(cd "$HERE/.." && pwd)"
HOOKS="$PLUGIN/hooks"
REPO="$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null || true)"
T="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$T"' EXIT

export HOME="$T/home"
WORK="$T/work"
mkdir -p "$HOME" "$WORK"
unset XDG_CONFIG_HOME XDG_DATA_HOME AGENT_GUARDS_SECRET_READ AGENT_GUARDS_SECRET_WRITE AGENT_GUARDS_ONEPASSWORD \
  AGENT_GUARDS_OUTBOUND AGENT_GUARDS_GIT AGENT_GUARDS_DELETE AGENT_GUARDS_RECORD AGENT_GUARDS_HARD_LINKS \
  AGENT_GUARDS_STARTUP_KEYS AGENT_GUARDS_SYSTEM AGENT_GUARDS_CHAIN AGENT_GUARDS_OTHER_REPOS GH_REPO
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset AGENT_GUARDS_PROCESSES

# The process check asks `ps` and `pgrep` which process a PID or a pattern names. These stand-ins answer
# from a fixed table (PID, name, command line), so no real process is looked at or signalled.
PROCS="$T/procs"
cat > "$PROCS" <<'TABLE'
1 launchd /sbin/launchd
88 WindowServer /System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer -daemon
400 Finder /System/Library/CoreServices/Finder.app/Contents/MacOS/Finder
512 sshd sshd: user@pts/0
4242 node node /work/app/node_modules/.bin/next dev
4343 python3 python3 -m http.server 8000
TABLE
FAKEBIN="$T/fakebin"
mkdir -p "$FAKEBIN"
cat > "$FAKEBIN/ps" <<FAKE
#!/usr/bin/env bash
pid=""
while [ \$# -gt 0 ]; do case "\$1" in -p) pid="\$2"; shift 2 ;; *) shift ;; esac; done
awk -v p="\$pid" '\$1 == p { print \$2; n++ } END { exit n ? 0 : 1 }' "$PROCS"
FAKE
cat > "$FAKEBIN/pgrep" <<FAKE
#!/usr/bin/env bash
mode=name pat=""
while [ \$# -gt 0 ]; do
  case "\$1" in -f) mode=full; shift ;; -x) mode=exact; shift ;; --) shift; pat="\$1"; shift ;; -*) shift ;; *) pat="\$1"; shift ;; esac
done
awk -v m="\$mode" -v p="\$pat" '{ a = \$0; sub(/^[^ ]+ [^ ]+ /, "", a)
  if ((m == "full" && a ~ p) || (m == "exact" && \$2 == p) || (m == "name" && \$2 ~ p)) { print \$1; n++ } }
  END { exit n ? 0 : 1 }' "$PROCS"
FAKE
chmod +x "$FAKEBIN/ps" "$FAKEBIN/pgrep"
export PATH="$FAKEBIN:$PATH"

PASS=0
FAIL=0
why=""
ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; [ -n "$why" ] && printf '        %s\n' "$why"; }
check() { why=""; if "$2"; then ok "$1"; else ng "$1"; fi; }

# Events in the shape Claude Code and Codex hand to a PreToolUse hook.
event_bash() { jq -nc --arg c "$1" --arg d "${2:-$WORK}" '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}, cwd: $d}'; }
event_read() { jq -nc --arg p "$1" --arg d "$WORK" '{hook_event_name: "PreToolUse", tool_name: "Read", tool_input: {file_path: $p}, cwd: $d}'; }
# event_file <tool> <path>: a Claude Code file tool. NotebookEdit names its file in notebook_path.
event_file() {
  local key=file_path
  [ "$1" = NotebookEdit ] && key=notebook_path
  jq -nc --arg t "$1" --arg k "$key" --arg p "$2" --arg d "$WORK" \
    '{hook_event_name: "PreToolUse", tool_name: $t, tool_input: {($k): $p, content: "x"}, cwd: $d}'
}
# event_text <tool> <path> <text>: a Claude Code file tool that writes <text>: the content of Write, the
# new_string of Edit, and the new_string of the one edit of MultiEdit.
event_text() {
  jq -nc --arg t "$1" --arg p "$2" --arg s "$3" --arg d "$WORK" '{hook_event_name: "PreToolUse", tool_name: $t, cwd: $d,
    tool_input: (if $t == "Write" then {file_path: $p, content: $s}
      elif $t == "MultiEdit" then {file_path: $p, edits: [{old_string: "a", new_string: $s}]}
      else {file_path: $p, old_string: "a", new_string: $s} end)}'
}
# event_patch <patch>: a Codex apply_patch call, with the patch in tool_input.patch.
event_patch() { jq -nc --arg p "$1" --arg d "$WORK" '{hook_event_name: "PreToolUse", tool_name: "apply_patch", tool_input: {patch: $p}, cwd: $d}'; }
patch_of() { printf '*** Begin Patch\n%s\n*** End Patch\n' "$1"; }

# run_hook <hook> <event> prints what the hook printed. A missing hook prints nothing.
run_hook() {
  [ -f "$HOOKS/$1.sh" ] || return 0
  (cd "$(printf '%s' "$2" | jq -r '.cwd')" && printf '%s' "$2" | bash "$HOOKS/$1.sh" 2>/dev/null)
}
decision() { run_hook "$1" "$2" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null; }
reason() { run_hook "$1" "$2" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null; }

# refuses <hook> <event> <label>: the hook denies the event.
refuses() {
  [ -f "$HOOKS/$1.sh" ] || { why="hooks/$1.sh does not exist"; return 1; }
  [ "$(decision "$1" "$2")" = deny ] || { why="$1 let through: $3"; return 1; }
}
# passes <hook> <event> <label>: the hook exists and prints nothing, so it neither denies nor approves.
passes() {
  [ -f "$HOOKS/$1.sh" ] || { why="hooks/$1.sh does not exist"; return 1; }
  local out
  out="$(run_hook "$1" "$2")"
  [ -z "$out" ] || { why="$1 printed a decision for: $3 ($out)"; return 1; }
}

# A GitHub token shape and an AWS key id shape, assembled here so the file never holds one.
KEY_GH="gh""p_aB3dE5gH7jK9mN1pQ3sT5vW7yZ9bC1dE3fG5"
KEY_AWS="AK""IAQ3EXAMPLE7XYZ7W2"

secret_shell_refused() {
  local c
  for c in 'cat .env' 'head -5 .env.local' 'grep TOKEN .env.production' 'cat ~/.ssh/id_ed25519' \
    'less certs/server.pem' 'cat secrets/api.txt' 'python3 -c "print(open(\".env\").read())"'; do
    refuses secret-read "$(event_bash "$c")" "$c" || return 1
  done
}

secret_read_tool_refused() {
  local p
  for p in "$WORK/.env" "$WORK/.env.production" "$HOME/.ssh/id_ed25519" "$WORK/certs/server.pem"; do
    refuses secret-read "$(event_read "$p")" "Read $p" || return 1
  done
}

secret_ordinary_allowed() {
  local c p
  for c in 'cat .env.example' 'cat src/main.py' 'grep -n TODO README.md'; do
    passes secret-read "$(event_bash "$c")" "$c" || return 1
  done
  for p in "$WORK/.env.example" "$WORK/README.md"; do
    passes secret-read "$(event_read "$p")" "Read $p" || return 1
  done
}

secret_app_data_refused() {
  local c p
  for c in 'cat ~/Library/Keychains/login.keychain-db' 'cat ~/Library/Messages/chat.db' \
    'cat ~/Library/Mail/V10/inbox.emlx' 'cat "$HOME/Library/Application Support/Google/Chrome/Default/Cookies"' \
    'cat ~/.claude/history.jsonl' 'tail ~/.claude/projects/demo/session.jsonl'; do
    refuses secret-read "$(event_bash "$c")" "$c" || return 1
  done
  for p in "$HOME/.claude/history.jsonl" "$HOME/Library/Messages/chat.db"; do
    refuses secret-read "$(event_read "$p")" "Read $p" || return 1
  done
}

secret_personal_folders_allowed() {
  local c
  for c in 'cat ~/Documents/notes.txt' 'head ~/Downloads/data.csv' 'ls ~/Pictures'; do
    passes secret-read "$(event_bash "$c")" "$c" || return 1
  done
  passes secret-read "$(event_read "$HOME/Downloads/data.csv")" "Read ~/Downloads/data.csv"
}

secret_paths_listed() {
  mkdir -p "$HOME/.config/agent-guards"
  printf '%s\n' '# places only this person keeps keys in' '~/vault/keys' '# ~/other' > "$HOME/.config/agent-guards/secret-paths"
  local result=0
  refuses secret-read "$(event_bash 'cat ~/vault/keys/a.txt')" 'cat ~/vault/keys/a.txt' || result=1
  [ "$result" -eq 0 ] && { refuses secret-read "$(event_read "$HOME/vault/keys/b.txt")" "Read ~/vault/keys/b.txt" || result=1; }
  [ "$result" -eq 0 ] && { passes secret-read "$(event_bash 'cat ~/vault/notes.txt')" 'cat ~/vault/notes.txt' || result=1; }
  [ "$result" -eq 0 ] && { passes secret-read "$(event_bash 'cat ~/other/a.txt')" 'cat ~/other/a.txt (a # line)' || result=1; }
  rm -f "$HOME/.config/agent-guards/secret-paths"
  return "$result"
}

secret_unknown_target_refused() {
  local c
  for c in 'cat "$SECRET_FILE"' 'cat $(find . -name "*.key")' 'head "$(ls | head -1)"'; do
    refuses secret-read "$(event_bash "$c")" "$c" || return 1
  done
  case "$(reason secret-read "$(event_bash 'cat "$SECRET_FILE"')")" in
    *"name the file"*) ;;
    *) why="the refusal does not say to name the file directly"; return 1 ;;
  esac
}

secret_read_after_op_refused() {
  local c
  for c in 'op document create .env --title backup; cat .env' 'op document create .env --title backup | cat .env' \
    'op document create .env --title backup && head .env'; do
    refuses secret-read "$(event_bash "$c")" "$c" || return 1
  done
}

secret_write_shell_refused() {
  local c
  for c in 'echo FOO=1 > .env' 'printf x >> .env.local' 'printf x | tee .env.production' 'tee -a .env < input.txt' \
    'echo k > ~/.ssh/id_ed25519' 'cat a.pem > certs/server.pem' 'echo x > secrets/api.txt' 'echo x 2>&1 >.env' \
    'cp .env.example .env' 'mv draft.txt .env.local' 'sed -i.bak s/a/b/ .env' 'truncate -s 0 .env'; do
    refuses secret-write "$(event_bash "$c")" "$c" || return 1
  done
}

secret_write_tools_refused() {
  local pair tool path
  for pair in "Write $WORK/.env" "Edit $WORK/.env.local" "MultiEdit $WORK/certs/server.key" \
    "NotebookEdit $WORK/secrets/notes.ipynb" "Write $HOME/.ssh/id_ed25519"; do
    tool="${pair%% *}"
    path="${pair#* }"
    refuses secret-write "$(event_file "$tool" "$path")" "$tool $path" || return 1
  done
}

secret_write_patch_refused() {
  local p
  for p in "$(patch_of $'*** Add File: .env\n+FOO=1')" "$(patch_of $'*** Update File: config/server.key\n@@\n-a\n+b')" \
    "$(patch_of $'*** Update File: notes.txt\n*** Move to: .env.local\n@@\n-a\n+b')" \
    "$(patch_of $'*** Update File: src/a.py\n@@\n-a\n+b\n*** Add File: secrets/token.txt\n+x')"; do
    refuses secret-write "$(event_patch "$p")" "patch: $(printf '%s' "$p" | sed -n 2p)" || return 1
  done
}

secret_write_ordinary_allowed() {
  local c p
  for c in 'echo FOO=1 > .env.example' 'printf y > notes.txt' 'echo z | tee build.log' 'ls -la > listing.txt' 'cat .env.example'; do
    passes secret-write "$(event_bash "$c")" "$c" || return 1
  done
  for p in "$WORK/.env.example" "$WORK/src/main.py"; do
    passes secret-write "$(event_file Write "$p")" "Write $p" || return 1
    passes secret-write "$(event_file Edit "$p")" "Edit $p" || return 1
  done
  passes secret-write "$(event_patch "$(patch_of $'*** Update File: src/a.py\n@@\n-a\n+b')")" 'patch of src/a.py'
}

secret_paths_write_listed() {
  mkdir -p "$HOME/.config/agent-guards"
  printf '%s\n' '~/vault/keys' > "$HOME/.config/agent-guards/secret-paths"
  local result=0
  refuses secret-write "$(event_bash 'echo x > ~/vault/keys/a.txt')" 'echo x > ~/vault/keys/a.txt' || result=1
  [ "$result" -eq 0 ] && { refuses secret-write "$(event_file Write "$HOME/vault/keys/b.txt")" "Write ~/vault/keys/b.txt" || result=1; }
  [ "$result" -eq 0 ] && { passes secret-write "$(event_bash 'echo x > ~/vault/notes.txt')" 'echo x > ~/vault/notes.txt' || result=1; }
  rm -f "$HOME/.config/agent-guards/secret-paths"
  return "$result"
}

onepassword_value_refused() {
  local c
  for c in 'op read op://Private/demo/password' 'op item get demo --format json' 'op item get demo --otp' \
    'op document get abc123' 'op run -- env' 'op inject -i app.tpl' 'op signin' 'op item create --category login' \
    'op item delete demo' 'op whoami && op read op://Private/demo/password' 'op vault list; op item get demo' \
    'op item list | op item get -' 'bash -c "op read op://Private/demo/password"' \
    'echo "$(op read op://Private/demo/password)"' 'export TOKEN=$(op read op://Private/demo/password)'; do
    refuses onepassword "$(event_bash "$c")" "$c" || return 1
  done
}

onepassword_safe_allowed() {
  local c
  for c in 'op whoami' 'op account list' 'op vault list' 'op item list --vault Private' 'op document list' \
    'op document create .env --title backup' 'op document edit abc123 .env' 'op --version' 'op help' 'ls -la'; do
    passes onepassword "$(event_bash "$c")" "$c" || return 1
  done
}

printf 'first line\ntoken: %s\n' "$KEY_GH" > "$WORK/body.md"
printf 'nothing secret here\n' > "$WORK/clean.md"

outbound_body_key_refused() {
  local c r
  for c in 'gh issue create --title t --body-file body.md' 'gh pr create --title t --body-file body.md' \
    'gh api repos/o/r/issues -X POST -F body=@body.md' "gh issue comment 1 --body \"key $KEY_AWS\""; do
    refuses outbound "$(event_bash "$c")" "$c" || return 1
  done
  r="$(reason outbound "$(event_bash 'gh issue create --title t --body-file body.md')")"
  case "$r" in *"$KEY_GH"*) why="the refusal shows the value"; return 1 ;; esac
  case "$r" in *"line 2"*) ;; *) why="the refusal does not name line 2: $r"; return 1 ;; esac
}

REPO_DIR="$WORK/repo"
git init -q "$REPO_DIR"
git -C "$REPO_DIR" config user.email test
git -C "$REPO_DIR" config user.name test
printf 'ok\n' > "$REPO_DIR/a.txt"
git -C "$REPO_DIR" add a.txt
git -C "$REPO_DIR" commit -qm first

outbound_commit_key_refused() {
  printf 'aws = "%s"\n' "$KEY_AWS" > "$REPO_DIR/config.txt"
  git -C "$REPO_DIR" add config.txt
  local result=0 r
  refuses outbound "$(event_bash 'git commit -m "add config"' "$REPO_DIR")" 'git commit with a staged key' || result=1
  r="$(reason outbound "$(event_bash 'git commit -m "add config"' "$REPO_DIR")")"
  case "$r" in *"$KEY_AWS"*) why="the refusal shows the value"; result=1 ;; esac
  git -C "$REPO_DIR" rm -qf --cached config.txt
  rm -f "$REPO_DIR/config.txt"
  return "$result"
}

outbound_unreadable_body_refused() {
  local c
  for c in 'gh issue create --title t --body "$(cat body.md)"' 'gh issue create --title t --body -' \
    'gh issue create --title t --body-file "$BODY"'; do
    refuses outbound "$(event_bash "$c")" "$c" || return 1
  done
  case "$(reason outbound "$(event_bash 'gh issue create --title t --body "$(cat body.md)"')")" in
    *"--body-file"*) ;;
    *) why="the refusal does not show the --body-file form"; return 1 ;;
  esac
}

outbound_clean_allowed() {
  local c
  for c in 'gh issue create --title t --body-file clean.md' 'gh issue comment 1 --body "looks good"' 'ls -la'; do
    passes outbound "$(event_bash "$c")" "$c" || return 1
  done
  printf 'more\n' >> "$REPO_DIR/a.txt"
  git -C "$REPO_DIR" add a.txt
  passes outbound "$(event_bash 'git commit -m "more"' "$REPO_DIR")" 'git commit without a key'
  local result=$?
  git -C "$REPO_DIR" reset -q
  git -C "$REPO_DIR" checkout -q -- a.txt
  return "$result"
}

git_dangerous_refused() {
  local c r
  for c in 'git push --force' 'git push -f origin main' 'git reset --hard HEAD~1' 'git commit --no-verify -m wip' \
    'git clean -fd' 'git checkout -- .'; do
    refuses git "$(event_bash "$c" "$REPO_DIR")" "$c" || return 1
    r="$(reason git "$(event_bash "$c" "$REPO_DIR")")"
    case "$r" in *"! $c"*) ;; *) why="the refusal of '$c' does not show '! $c'"; return 1 ;; esac
  done
}

git_ordinary_allowed() {
  local c
  for c in 'git push' 'git push origin feat/x' 'git checkout main' 'git clean -n' 'git restore --staged a.txt' 'git status'; do
    passes git "$(event_bash "$c" "$REPO_DIR")" "$c" || return 1
  done
}

delete_broad_refused() {
  local c r
  for c in 'rm -rf /' 'rm -rf ~' 'rm -rf "$HOME"' 'rm -rf .' 'find / -delete'; do
    refuses delete "$(event_bash "$c")" "$c" || return 1
    r="$(reason delete "$(event_bash "$c")")"
    case "$r" in *"! $c"*) ;; *) why="the refusal of '$c' does not show '! $c'"; return 1 ;; esac
  done
}

delete_named_allowed() {
  local c
  for c in 'rm -rf ./build' 'rm -rf node_modules' 'rm notes.txt'; do
    passes delete "$(event_bash "$c")" "$c" || return 1
  done
}

delete_chmod_refused() {
  local c r
  mkdir -p "$HOME/.config/agent-guards"
  printf '%s\n' '~/work/keep' > "$HOME/.config/agent-guards/protected-paths"
  for c in 'chmod -R 000 /' 'chmod -R 000 ~' 'chmod -R 000 "$HOME"' 'chmod -R u-rwx ~' 'chmod --recursive 700 /' \
    'chmod -R 000 ~/work/keep' 'chown -R nobody ~'; do
    refuses delete "$(event_bash "$c")" "$c" || { rm -f "$HOME/.config/agent-guards/protected-paths"; return 1; }
    r="$(reason delete "$(event_bash "$c")")"
    case "$r" in *"! $c"*) ;; *) why="the refusal of '$c' does not show '! $c'"; rm -f "$HOME/.config/agent-guards/protected-paths"; return 1 ;; esac
  done
  rm -f "$HOME/.config/agent-guards/protected-paths"
}

delete_chmod_named_allowed() {
  local c
  for c in 'chmod -R 755 ./build' 'chmod -R u+w node_modules' 'chmod +x run.sh'; do
    passes delete "$(event_bash "$c")" "$c" || return 1
  done
}

# Wrapper options that take a value. The value is skipped, so the command behind it is judged.
WRAPPED=('nice -n 10' 'sudo -u root' 'sudo -g staff' 'doas -u root' 'exec -a x' 'time -o run.txt' 'env -u FOO' \
  'env -C /tmp' 'timeout -s KILL 5' 'timeout -k 1 5' 'nohup nice -n 5')

onepassword_wrapped_refused() {
  local p
  for p in "${WRAPPED[@]}"; do
    refuses onepassword "$(event_bash "$p op read op://Private/demo/password")" "$p op read" || return 1
  done
}

git_delete_wrapped_refused() {
  local c
  for c in 'sudo -u root rm -rf /' 'nice -n 10 rm -rf /' 'env -C /tmp rm -rf ~' 'timeout -s KILL 5 rm -rf ~'; do
    refuses delete "$(event_bash "$c")" "$c" || return 1
  done
  for c in 'nice -n 10 git push --force origin main' 'sudo -u root git push --force' \
    'env -C /tmp git push --force origin main' 'exec -a x git reset --hard HEAD~1'; do
    refuses git "$(event_bash "$c" "$REPO_DIR")" "$c" || return 1
  done
}

secret_wrapped_refused() {
  local c
  for c in 'nice -n 10 cat .env' 'sudo -u root cat .env' 'env -u FOO head .env.local' 'time -o run.txt cat certs/server.pem'; do
    refuses secret-read "$(event_bash "$c")" "$c" || return 1
  done
  for c in 'sudo -u root tee .env < input.txt' 'nice -n 10 cp .env.example .env' 'env -u FOO sed -i.bak s/a/b/ .env'; do
    refuses secret-write "$(event_bash "$c")" "$c" || return 1
  done
}

xargs_command_judged() {
  local c
  for c in 'echo op://Private/demo/password | xargs op read' 'xargs -n 1 op read < refs.txt' \
    'xargs -I {} op read {} < refs.txt' 'xargs -0 -P 2 op item get < ids.txt'; do
    refuses onepassword "$(event_bash "$c")" "$c" || return 1
  done
  for c in 'echo main | xargs git push --force origin' 'xargs -n 1 git reset --hard < refs.txt'; do
    refuses git "$(event_bash "$c" "$REPO_DIR")" "$c" || return 1
  done
  for c in 'echo x | xargs rm -rf ~' 'echo x | xargs -n 1 rm -rf /'; do
    refuses delete "$(event_bash "$c")" "$c" || return 1
  done
}

find_exec_judged() {
  local c
  for c in 'find . -name x -exec op read {} \;' 'find . -name x -execdir op read {} +' \
    'find . -ok op item get {} \;' 'find . -okdir op document get {} \;'; do
    refuses onepassword "$(event_bash "$c")" "$c" || return 1
  done
  for c in 'find . -name .env -exec cat {} \;' 'find certs -name "*.pem" -exec head {} +' \
    'find . -name .env.local -execdir cat {} \;'; do
    refuses secret-read "$(event_bash "$c")" "$c" || return 1
  done
  refuses git "$(event_bash 'find . -maxdepth 0 -exec git push --force \;' "$REPO_DIR")" 'find -exec git push --force'
}

watch_command_judged() {
  local c
  for c in 'watch op read op://Private/demo/password' 'watch -n 1 op read op://Private/demo/password' \
    'watch -n 1 -d op item get demo' 'watch --interval 2 "op read op://Private/demo/password"'; do
    refuses onepassword "$(event_bash "$c")" "$c" || return 1
  done
  refuses delete "$(event_bash 'watch -n 5 rm -rf ~')" 'watch -n 5 rm -rf ~'
}

env_split_string_judged() {
  local c
  for c in "env -S 'op read op://Private/demo/password'" "env --split-string='op read op://Private/demo/password'" \
    "env -S'op item get demo'" "env -u FOO -S 'op read op://Private/demo/password'"; do
    refuses onepassword "$(event_bash "$c")" "$c" || return 1
  done
  for c in "env -S 'rm -rf /'" "env --split-string 'rm -rf ~'"; do
    refuses delete "$(event_bash "$c")" "$c" || return 1
  done
}

wrapped_ordinary_allowed() {
  local c h
  for c in 'nice -n 10 ls' 'sudo -u root ls /tmp' 'sudo -E ls' "env -S 'ls -l'" 'echo a | xargs -n 1 echo' \
    "find . -name '*.md' -exec wc -l {} +" 'watch -n 1 ls' "grep -n 'op read' notes.md" 'nice -n 10 op item list' \
    'timeout 5 op whoami' 'echo build | xargs rm -rf' 'find . -name node_modules -prune -exec rm -rf {} +'; do
    for h in secret-read secret-write onepassword outbound git delete; do
      passes "$h" "$(event_bash "$c")" "$c" || return 1
    done
  done
}

protected_paths_listed() {
  mkdir -p "$HOME/.config/agent-guards"
  printf '%s\n' '~/work/keep' > "$HOME/.config/agent-guards/protected-paths"
  local result=0
  refuses delete "$(event_bash 'rm -rf ~/work/keep')" 'rm -rf ~/work/keep' || result=1
  [ "$result" -eq 0 ] && { refuses delete "$(event_bash 'rm ~/work/keep/a.txt')" 'rm ~/work/keep/a.txt' || result=1; }
  [ "$result" -eq 0 ] && { passes delete "$(event_bash 'rm -rf ~/work/other')" 'rm -rf ~/work/other' || result=1; }
  rm -f "$HOME/.config/agent-guards/protected-paths"
  return "$result"
}

# protected_list makes ~/work/keep the one protected place; protected_done takes the list away.
protected_list() {
  mkdir -p "$HOME/.config/agent-guards" "$HOME/work/keep"
  printf '%s\n' '~/work/keep' > "$HOME/.config/agent-guards/protected-paths"
}
protected_done() { rm -f "$HOME/.config/agent-guards/protected-paths"; }

# each_refused <hook> <cwd> <command>...: the hook refuses every command run in <cwd>.
each_refused() {
  local hook="$1" dir="$2" c
  shift 2
  for c in "$@"; do refuses "$hook" "$(event_bash "$c" "$dir")" "$c" || return 1; done
}
# each_passes <hook> <cwd> <command>...: the hook prints nothing for every command run in <cwd>.
each_passes() {
  local hook="$1" dir="$2" c
  shift 2
  for c in "$@"; do passes "$hook" "$(event_bash "$c" "$dir")" "$c" || return 1; done
}

delete_copy_into_protected() {
  protected_list
  local result=0
  each_refused delete "$WORK" 'cp build/claude ~/work/keep/claude' 'cp -f a.txt b.txt ~/work/keep' \
    'install -m 755 build/claude ~/work/keep/claude' 'ln -sf /tmp/other ~/work/keep/claude' \
    'rsync -a dist/ ~/work/keep/' 'scp host:claude ~/work/keep/claude' \
    "cp -t $HOME/work/keep a.txt" "cp --target-directory=$HOME/work/keep a.txt" || result=1
  protected_done
  return "$result"
}

delete_write_into_protected() {
  protected_list
  local result=0
  each_refused delete "$WORK" 'tee ~/work/keep/a.txt < note.txt' 'echo x | tee -a ~/work/keep/a.txt' \
    "dd if=build/claude of=$HOME/work/keep/claude" 'echo x > ~/work/keep/a.txt' 'echo x >> ~/work/keep/a.txt' \
    'echo x >| ~/work/keep/a.txt' 'make &> ~/work/keep/build.log' 'ls 2> ~/work/keep/err.log' \
    'echo x >~/work/keep/a.txt' || result=1
  protected_done
  return "$result"
}

delete_mv_into_protected() {
  protected_list
  local result=0
  each_refused delete "$WORK" 'mv build/claude ~/work/keep/claude' 'mv -f a.txt ~/work/keep' || result=1
  protected_done
  return "$result"
}

delete_git_rm_protected() {
  protected_list
  local result=0
  each_refused delete "$WORK" 'git rm ~/work/keep/a.txt' 'git rm -r ~/work/keep' 'git rm --cached ~/work/keep/a.txt' \
    "git -C $HOME/work rm -r keep" || result=1
  [ "$result" -eq 0 ] && { each_refused delete "$HOME/work" 'git rm -r keep' 'git rm -rf -- keep/a.txt' || result=1; }
  protected_done
  return "$result"
}

delete_reads_protected() {
  protected_list
  local result=0
  each_passes delete "$WORK" 'cp ~/work/keep/a.txt /tmp/a.txt' 'rsync -a ~/work/keep/ ~/backup/' \
    'cat ~/work/keep/a.txt > /tmp/a.txt' 'cp ~/work/keep/a.txt ~/work/keep-copy.txt' 'git rm ~/work/other.txt' \
    'echo x > ~/work/keeper.txt' 'grep x ~/work/keep/a.txt 2> /dev/null' || result=1
  protected_done
  return "$result"
}

delete_leaves_file_tools() {
  protected_list
  local result=0 t
  for t in Write Edit; do
    passes delete "$(event_file "$t" "$HOME/work/keep/a.txt")" "$t of ~/work/keep/a.txt" || { result=1; break; }
  done
  protected_done
  return "$result"
}

docs_protected_overwrite() {
  local f
  for f in README.md README.ja.md docs/how-it-works.md docs/how-it-works.ja.md; do
    grep -qF 'git rm' "$PLUGIN/$f" || { why="$f does not say that git rm of a protected place is refused"; return 1; }
  done
}

turn_off_one_hook() {
  local hooks=(secret-read secret-write onepassword outbound git delete)
  local vars=(AGENT_GUARDS_SECRET_READ AGENT_GUARDS_SECRET_WRITE AGENT_GUARDS_ONEPASSWORD AGENT_GUARDS_OUTBOUND \
    AGENT_GUARDS_GIT AGENT_GUARDS_DELETE)
  local events=("$(event_bash 'cat .env')" "$(event_bash 'echo FOO=1 > .env')" \
    "$(event_bash 'op read op://Private/demo/password')" "$(event_bash 'gh issue create --title t --body-file body.md')" \
    "$(event_bash 'git push --force' "$REPO_DIR")" "$(event_bash 'rm -rf ~')")
  local i j
  for i in 0 1 2 3 4 5; do
    export "${vars[$i]}=off"
    passes "${hooks[$i]}" "${events[$i]}" "${hooks[$i]} with ${vars[$i]}=off" || { unset "${vars[$i]}"; return 1; }
    for j in 0 1 2 3 4 5; do
      [ "$i" -eq "$j" ] && continue
      refuses "${hooks[$j]}" "${events[$j]}" "${hooks[$j]} with ${vars[$i]}=off" || { unset "${vars[$i]}"; return 1; }
    done
    unset "${vars[$i]}"
  done
}

records_off_by_default() {
  local log="$HOME/.local/share/agent-guards/refusals.log"
  rm -rf "$HOME/.local/share/agent-guards"
  refuses git "$(event_bash 'git push --force' "$REPO_DIR")" 'git push --force' || return 1
  [ ! -e "$log" ] || { why="a record was written with the record variable unset"; return 1; }
  export AGENT_GUARDS_RECORD=on
  refuses git "$(event_bash 'git push --force' "$REPO_DIR")" 'git push --force' || { unset AGENT_GUARDS_RECORD; return 1; }
  refuses delete "$(event_bash 'rm -rf ~')" 'rm -rf ~' || { unset AGENT_GUARDS_RECORD; return 1; }
  unset AGENT_GUARDS_RECORD
  [ -f "$log" ] || { why="no record was written with AGENT_GUARDS_RECORD=on"; return 1; }
  [ "$(wc -l < "$log" | tr -d ' ')" = 2 ] || { why="expected 2 record lines, found $(wc -l < "$log" | tr -d ' ')"; return 1; }
}

manifests_declare_hooks() {
  local claude="$PLUGIN/.claude-plugin/plugin.json" codex="$PLUGIN/.codex-plugin/plugin.json" file h
  [ -f "$claude" ] && [ -f "$codex" ] || { why="a plugin.json is missing"; return 1; }
  [ "$(jq -c '.hooks' "$claude")" = "$(jq -c '.hooks' "$codex")" ] || { why="the two manifests declare different hooks"; return 1; }
  file="$(jq -r '.hooks // empty' "$claude")"
  [ -n "$file" ] && [ -f "$PLUGIN/${file#./}" ] || { why="the manifests name no hooks file that exists"; return 1; }
  runs_for() {
    jq -e --arg t "$1" --arg h "$2" \
      '[.hooks.PreToolUse[] | select(.matcher as $m | $t | test("^(" + $m + ")$")) | .hooks[].command] | any(contains("hooks/" + $h + ".sh"))' \
      "$PLUGIN/${file#./}" > /dev/null
  }
  for h in secret-read secret-write onepassword outbound git delete; do
    runs_for Bash "$h" || { why="hooks file does not run $h.sh for Bash"; return 1; }
  done
  runs_for Read secret-read || { why="hooks file does not run secret-read.sh for Read"; return 1; }
  for t in Write Edit MultiEdit NotebookEdit apply_patch; do
    runs_for "$t" secret-write || { why="hooks file does not run secret-write.sh for $t"; return 1; }
  done
}

# The number of hook commands the hooks file declares, which is how many Codex lists in /hooks.
hook_count() { jq '[.hooks.PreToolUse[].hooks[]] | length' "$HOOKS/hooks.json"; }
number_word() {
  local words=(zero one two three four five six seven eight nine ten eleven twelve)
  printf '%s' "${words[$1]:-$1}"
}

docs_name_variables() {
  local v f n
  for v in AGENT_GUARDS_SECRET_READ AGENT_GUARDS_SECRET_WRITE AGENT_GUARDS_ONEPASSWORD AGENT_GUARDS_OUTBOUND \
    AGENT_GUARDS_GIT AGENT_GUARDS_DELETE; do
    for f in README.md README.ja.md docs/how-it-works.md docs/how-it-works.ja.md; do
      grep -qF "$v" "$PLUGIN/$f" || { why="$f does not name $v"; return 1; }
    done
  done
  n="$(hook_count)"
  grep -qF "trust the $(number_word "$n") agent-guards hooks" "$PLUGIN/README.md" \
    || { why="README.md does not say to trust the $(number_word "$n") agent-guards hooks"; return 1; }
  # The Japanese page counts with a digit; the phrase is matched by its number and the escaped word for hooks.
  python3 -I -c 'import sys; sys.exit(0 if ("agent-guards\u306e" + sys.argv[2] + "\u3064\u306e\u30d5\u30c3\u30af") in open(sys.argv[1], encoding="utf-8").read() else 1)' \
    "$PLUGIN/README.ja.md" "$n" || { why="README.ja.md does not count $n hooks"; return 1; }
}

# The entries of the 0.2.0 refusals, under Unreleased before the release and in a release section after
# it, so a newer entry under Unreleased does not hide them.
changelog_names_refusals() {
  local entries
  entries="$(awk '/^## \[/{f=1; next} /^\[[^]]+\]: /{f=0} f && /^- /' "$PLUGIN/CHANGELOG.md")"
  local w
  for w in AGENT_GUARDS_SECRET_WRITE AGENT_GUARDS_ONEPASSWORD 'chmod -R'; do
    case "$entries" in *"$w"*) ;; *) why="no section of the changelog names $w"; return 1 ;; esac
  done
}

# After a release, the entries sit in the newest release section below an empty Unreleased.
changelog_check_reads_release() {
  local dir="$T/released"
  mkdir -p "$dir"
  printf '%s\n' '# Changelog' '' '## [Unreleased]' '' '## [0.2.0] - 2026-01-01' '' \
    '- Turn it off with `AGENT_GUARDS_SECRET_WRITE=off`' '- Turn it off with `AGENT_GUARDS_ONEPASSWORD=off`' \
    '- The delete hook also refuses `chmod -R`' '' '## [0.1.0] - 2025-12-01' '' '- Four hooks' >"$dir/CHANGELOG.md"
  PLUGIN="$dir" changelog_names_refusals || return 1
  # Before the release, the same entries sit under Unreleased.
  printf '%s\n' '# Changelog' '' '## [Unreleased]' '' '- Turn it off with `AGENT_GUARDS_SECRET_WRITE=off`' \
    '- Turn it off with `AGENT_GUARDS_ONEPASSWORD=off`' '- The delete hook also refuses `chmod -R`' '' \
    '## [0.1.0] - 2025-12-01' '' '- Four hooks' >"$dir/CHANGELOG.md"
  PLUGIN="$dir" changelog_names_refusals || { why="under Unreleased: $why"; return 1; }
}

# A newer entry under Unreleased does not hide the entries of an earlier release, and a changelog that
# names them nowhere still fails.
changelog_check_reads_below_unreleased() {
  local dir="$T/newer"
  mkdir -p "$dir"
  printf '%s\n' '# Changelog' '' '## [Unreleased]' '' '- A newer change' '' '## [0.2.0] - 2026-01-01' '' \
    '- Turn it off with `AGENT_GUARDS_SECRET_WRITE=off`' '- Turn it off with `AGENT_GUARDS_ONEPASSWORD=off`' \
    '- The delete hook also refuses `chmod -R`' '' '## [0.1.0] - 2025-12-01' '' '- Four hooks' >"$dir/CHANGELOG.md"
  PLUGIN="$dir" changelog_names_refusals || { why="below a newer Unreleased entry: $why"; return 1; }
  printf '%s\n' '# Changelog' '' '## [Unreleased]' '' '- A newer change' '' '## [0.2.0] - 2026-01-01' '' \
    '- Turn it off with `AGENT_GUARDS_SECRET_WRITE=off`' '' '## [0.1.0] - 2025-12-01' '' '- Four hooks' >"$dir/CHANGELOG.md"
  if PLUGIN="$dir" changelog_names_refusals; then
    why="it passed although no section names AGENT_GUARDS_ONEPASSWORD or chmod -R"
    return 1
  fi
  why=""
}

# The entries of 0.2.1 name the commands the hooks read behind wrappers and runners, under Unreleased
# before the release and in a release section after it, so a newer entry under Unreleased does not hide them.
changelog_names_runners() {
  local entries w
  entries="$(awk '/^## \[/{f=1; next} /^\[[^]]+\]: /{f=0} f && /^- /' "$PLUGIN/CHANGELOG.md")"
  for w in xargs 'find -exec' watch 'env -S'; do
    case "$entries" in *"$w"*) ;; *) why="no section of the changelog names $w"; return 1 ;; esac
  done
}

docs_name_runners() {
  local f w
  for f in docs/how-it-works.md docs/how-it-works.ja.md; do
    for w in 'sudo -u' 'nice -n' xargs 'find -exec' '-execdir' watch 'env -S'; do
      grep -qF -- "$w" "$PLUGIN/$f" || { why="$f does not name $w"; return 1; }
    done
  done
}

repository_rules_allow_hook_plugins() {
  [ -n "$REPO" ] || { why="not inside the repository"; return 1; }
  grep -qF 'holds hooks and no skills' "$REPO/AGENTS.md" || { why="AGENTS.md does not state the exception"; return 1; }
  grep -qF 'holds hooks and no skills' "$REPO/docs/creating-a-plugin.md" || { why="docs/creating-a-plugin.md does not state the exception"; return 1; }
  # The Japanese page says the same rule; the phrase is written as escapes to keep this file English.
  python3 -I -c 'import sys; sys.exit(0 if "\u6280\u3092\u6301\u305f\u305a\u30d5\u30c3\u30af\u3060\u3051\u3092\u6301\u3064" in open(sys.argv[1], encoding="utf-8").read() else 1)' \
    "$REPO/docs/creating-a-plugin.ja.md" || { why="docs/creating-a-plugin.ja.md does not state the exception"; return 1; }
}

# Hard links: linked/a.txt and linked/b.txt are two names of one file, and single.txt has one name.
mkdir -p "$WORK/linked"
printf 'x\n' > "$WORK/linked/a.txt"
ln "$WORK/linked/a.txt" "$WORK/linked/b.txt"
printf 'x\n' > "$WORK/single.txt"

hard_link_write_refused() {
  local t c r
  for t in Write Edit MultiEdit NotebookEdit; do
    refuses secret-write "$(event_file "$t" "$WORK/linked/b.txt")" "$t linked/b.txt" || return 1
  done
  refuses secret-write "$(event_patch "$(patch_of $'*** Update File: linked/b.txt\n@@\n-x\n+y')")" 'patch of linked/b.txt' || return 1
  for c in 'echo y > linked/b.txt' 'printf y | tee -a linked/a.txt' 'sudo -u root tee linked/b.txt < input.txt'; do
    refuses secret-write "$(event_bash "$c")" "$c" || return 1
  done
  r="$(reason secret-write "$(event_file Write "$WORK/linked/b.txt")")"
  case "$r" in *"second name"*) ;; *) why="the refusal does not say the file has a second name: $r"; return 1 ;; esac
  case "$r" in *"cp "*) ;; *) why="the refusal does not say to copy the file with cp: $r"; return 1 ;; esac
}

hard_link_one_name_passes() {
  local t c
  for t in Write Edit MultiEdit; do
    passes secret-write "$(event_file "$t" "$WORK/single.txt")" "$t single.txt" || return 1
    passes secret-write "$(event_file "$t" "$WORK/new-file.txt")" "$t new-file.txt" || return 1
  done
  passes secret-write "$(event_patch "$(patch_of $'*** Update File: single.txt\n@@\n-x\n+y')")" 'patch of single.txt' || return 1
  for c in 'echo y > single.txt' 'printf y | tee -a single.txt'; do
    passes secret-write "$(event_bash "$c")" "$c" || return 1
  done
}

# Startup files in the home folder, in a dotfiles folder, and under chezmoi source names.
mkdir -p "$WORK/dotfiles" "$WORK/chezmoi/dot_config/fish" "$HOME/.config/fish"

startup_key_refused() {
  local c r
  refuses secret-write "$(event_text Write "$HOME/.zshrc" 'export FOO_API_KEY="abc123def456"')" 'Write ~/.zshrc' || return 1
  refuses secret-write "$(event_text Edit "$HOME/.bashrc" 'export FOO_TOKEN=abc123def456')" 'Edit ~/.bashrc' || return 1
  refuses secret-write "$(event_text MultiEdit "$WORK/dotfiles/.zshenv" "export DEPLOY_SECRET='abc123def456'")" \
    'MultiEdit dotfiles/.zshenv' || return 1
  refuses secret-write "$(event_text Write "$WORK/chezmoi/dot_zshrc" '  export FOO_PASSWORD=hunter2hunter2')" \
    'Write chezmoi/dot_zshrc' || return 1
  refuses secret-write "$(event_text Write "$WORK/chezmoi/private_dot_zshrc.tmpl" 'export FOO_ACCESS_KEY="abc123def456"')" \
    'Write chezmoi/private_dot_zshrc.tmpl' || return 1
  refuses secret-write "$(event_text Edit "$HOME/.config/fish/config.fish" 'set -gx FOO_API_KEY abc123def456')" \
    'Edit the fish config' || return 1
  refuses secret-write "$(event_text Write "$WORK/chezmoi/dot_config/fish/config.fish" 'set -x FOO_TOKEN "abc123def456"')" \
    'Write the chezmoi fish config' || return 1
  refuses secret-write "$(event_text Edit "$HOME/.profile" "export GITHUB=$KEY_GH")" 'Edit ~/.profile with a key-shaped value' || return 1
  refuses secret-write "$(event_patch "$(patch_of $'*** Update File: dotfiles/.bash_profile\n@@\n-a\n+export FOO_PASSWORD="hunter2hunter2"')")" \
    'patch of dotfiles/.bash_profile' || return 1
  refuses secret-write "$(event_patch "$(patch_of $'*** Add File: chezmoi/dot_zprofile\n+export FOO_TOKEN=abc123def456')")" \
    'patch adding chezmoi/dot_zprofile' || return 1
  for c in "echo 'export FOO_API_KEY=\"abc123def456\"' >> ~/.zshrc" "printf 'export FOO_TOKEN=abc123def456\n' >> ~/.bashrc" \
    "echo 'export GITHUB=$KEY_GH' | tee -a ~/.zprofile" "echo 'export FOO_SECRET=abc123def456' >> dotfiles/.zshrc"; do
    refuses secret-write "$(event_bash "$c")" "$c" || return 1
  done
  r="$(reason secret-write "$(event_text Write "$HOME/.zshrc" 'export FOO_API_KEY="abc123def456"')")"
  case "$r" in *abc123def456*) why="the refusal shows the value"; return 1 ;; esac
  case "$r" in *.zshrc*) ;; *) why="the refusal does not name the file: $r"; return 1 ;; esac
  case "$r" in *FOO_API_KEY*) ;; *) why="the refusal does not name the variable: $r"; return 1 ;; esac
  r="$(reason secret-write "$(event_bash "echo 'export GITHUB=$KEY_GH' | tee -a ~/.zprofile")")"
  r="${r%%! *}"
  case "$r" in *"$KEY_GH"*) why="the refusal of a shell append shows the value"; return 1 ;; esac
}

startup_without_key_passes() {
  local text c
  for text in 'export FOO_API_KEY="$(security find-generic-password -s FOO_API_KEY -w)"' 'export FOO_TOKEN=$OTHER_TOKEN' \
    'export FOO_TOKEN="${OTHER_TOKEN}"' 'export FOO_API_KEY="REPLACE_ME"' 'export FOO_API_KEY=""' \
    '# export FOO_API_KEY="abc123def456"' 'export EDITOR=vim' 'export PATH="$HOME/bin:$PATH"' 'alias ll="ls -l"'; do
    passes secret-write "$(event_text Write "$HOME/.zshrc" "$text")" "Write ~/.zshrc: $text" || return 1
    passes secret-write "$(event_text Edit "$WORK/dotfiles/.bashrc" "$text")" "Edit dotfiles/.bashrc: $text" || return 1
  done
  passes secret-write "$(event_text Edit "$HOME/.config/fish/config.fish" 'set -gx FOO_API_KEY (security find-generic-password -s FOO_API_KEY -w)')" \
    'fish value read at startup' || return 1
  passes secret-write "$(event_text Write "$WORK/notes.md" 'export FOO_API_KEY="abc123def456"')" 'Write notes.md' || return 1
  for c in "echo 'export EDITOR=vim' >> ~/.zshrc" "echo 'alias ll=\"ls -l\"' >> ~/.bashrc" \
    "echo 'export FOO_API_KEY=\"\$(security find-generic-password -s FOO_API_KEY -w)\"' >> ~/.zshrc"; do
    passes secret-write "$(event_bash "$c")" "$c" || return 1
  done
}

system_commands_refused() {
  local c r
  for c in 'mount /dev/disk2s1 /mnt' 'umount /mnt' 'sudo mount -t tmpfs none /mnt' 'env FOO=1 umount /Volumes/x' \
    '/sbin/mount -a' 'chroot /srv/jail /bin/sh' 'sudo pfctl -d' 'mkfs.ext4 /dev/sdb1' 'sudo -u root mkfs.vfat /dev/sdc' \
    'bash -c "pfctl -f /etc/pf.conf"' "osascript -e 'do shell script \"touch /tmp/x\" with administrator privileges'"; do
    refuses delete "$(event_bash "$c")" "$c" || return 1
    r="$(reason delete "$(event_bash "$c")")"
    case "$r" in *"! $c"*) ;; *) why="the refusal of '$c' does not show '! $c'"; return 1 ;; esac
  done
}

system_args_pass() {
  local c
  for c in 'grep mount notes.txt' 'ls /mnt' 'diskutil list' "osascript -e 'display notification \"done\"'" 'man pfctl' \
    'mountpoint -q /mnt' 'echo umount'; do
    passes delete "$(event_bash "$c")" "$c" || return 1
  done
}

# refused_with_bang <hook> <command>: the hook denies the command and shows it again after a leading `!`.
refused_with_bang() {
  local r
  refuses "$1" "$(event_bash "$2")" "$2" || return 1
  r="$(reason "$1" "$(event_bash "$2")")"
  case "$r" in *"! $2"*) ;; *) why="the refusal of '$2' does not show '! $2'"; return 1 ;; esac
}

processes_pid_refused() {
  local c
  for c in 'kill 1' 'kill -9 1' 'kill 0' 'kill -9 -1' 'kill -s KILL -1' 'kill -- -4242' 'sudo kill -9 1' \
    'bash -c "kill -9 -1"' 'kill -HUP 4242 1'; do
    refused_with_bang delete "$c" || return 1
  done
}

processes_system_refused() {
  local c
  for c in 'kill 88' 'kill -9 400' 'kill 4242 512' 'pkill Finder' 'pkill -x WindowServer' 'pkill -f launchd' \
    'pkill -f .' 'killall Dock' 'killall -9 Finder' 'killall WindowServer' 'sudo killall systemd'; do
    refused_with_bang delete "$c" || return 1
  done
}

processes_unreadable_refused() {
  local c r
  for c in 'kill $PID' 'kill -9 "$pid"' 'kill $(pgrep -f node)' 'kill `cat app.pid`' 'pkill -f "$PATTERN"' \
    'killall $NAME' 'kill -9 ${PIDS}'; do
    refuses delete "$(event_bash "$c")" "$c" || return 1
    r="$(reason delete "$(event_bash "$c")")"
    case "$r" in *PID*) ;; *) why="the refusal of '$c' does not say to name the PID"; return 1 ;; esac
  done
}

processes_user_only_refused() {
  local c
  for c in 'pkill -u alice' 'pkill -U 501' 'killall -u alice' 'pkill -9 -u alice' 'sudo killall -u alice'; do
    refused_with_bang delete "$c" || return 1
  done
}

processes_ordinary_pass() {
  local c
  for c in 'kill 4242' 'kill -TERM 4343' 'kill -9 4242 4343' 'kill $!' 'kill -9 $!' 'kill %1' 'kill -0 4242' \
    'kill 99999' 'kill -l' 'pkill -f "next dev"' 'pkill node' 'pkill -u alice node' 'killall node' 'killall -9 python3' \
    'grep kill notes.txt' 'echo pkill done' 'man killall'; do
    passes delete "$(event_bash "$c")" "$c" || return 1
  done
}

processes_turn_off() {
  off_lets_only AGENT_GUARDS_PROCESSES delete "$(event_bash 'kill 1')" delete "$(event_bash 'rm -rf ~')"
}

docs_name_processes() {
  local f w
  for f in README.md README.ja.md docs/how-it-works.md docs/how-it-works.ja.md; do
    for w in AGENT_GUARDS_PROCESSES '`ps`' '`pgrep`' '`killall`'; do
      grep -qF -- "$w" "$PLUGIN/$f" || { why="$f does not name $w"; return 1; }
    done
  done
}

chain_remote_refused() {
  local c r
  for c in 'cast send 0xabc "f()" --rpc-url https://mainnet.example.org/v3/abc123 --ledger' 'cast send 0xabc "f()" --ledger' \
    'cast send 0xabc "f()" --rpc-url "$RPC_URL" --ledger' 'cast send 0xabc "f()" --rpc-url sepolia --ledger' \
    'cast send 0xabc "f()" -r https://rpc.example.org --ledger' 'cast s 0xabc "f()" --rpc-url=https://rpc.example.org' \
    'cast publish 0x02f8 --rpc-url https://rpc.example.org' 'cast rpc eth_sendRawTransaction 0x02f8 --rpc-url https://rpc.example.org' \
    'cast erc20-token transfer 0xabc 0xdef 1 --rpc-url https://rpc.example.org' \
    'forge script script/Deploy.s.sol --broadcast --rpc-url https://rpc.example.org' 'forge script script/Deploy.s.sol --broadcast' \
    'forge create src/A.sol:A --rpc-url https://rpc.example.org --broadcast' 'forge create src/A.sol:A --rpc-url https://rpc.example.org' \
    'forge create src/A.sol:A --broadcast' 'npx hardhat ignition deploy ignition/modules/A.ts --network sepolia' \
    'pnpm hardhat ignition deploy ./ignition/modules/A.ts --network mainnet' \
    'cast send 0xabc "f()" --rpc-url http://127.0.0.1:8545 --flashbots' \
    'cast send 0xabc "f()" --rpc-url http://127.0.0.1.example.com:8545' 'cast send 0xabc "f()" --rpc-url http://127.0.0.1:8545@example.com' \
    'sudo -u root cast send 0xabc "f()" --rpc-url https://rpc.example.org'; do
    refuses outbound "$(event_bash "$c")" "$c" || return 1
    r="$(reason outbound "$(event_bash "$c")")"
    case "$r" in *"! $c"*) ;; *) why="the refusal of '$c' does not show '! $c'"; return 1 ;; esac
  done
  # The reason names the host; only the command after ! repeats the URL, whose path can hold an API key.
  r="$(reason outbound "$(event_bash 'cast send 0xabc "f()" --rpc-url https://mainnet.example.org/v3/abc123 --ledger')")"
  r="${r%%! *}"
  case "$r" in *mainnet.example.org*) ;; *) why="the refusal does not name the host: $r"; return 1 ;; esac
  case "$r" in *abc123*) why="the reason before the ! command shows the URL path: $r"; return 1 ;; esac
}

chain_local_pass() {
  local c
  for c in 'cast send 0xabc "f()" --rpc-url http://127.0.0.1:8545 --unlocked --from 0xabc' \
    'cast send 0xabc "f()" --rpc-url http://localhost:8545' 'cast send 0xabc "f()" --rpc-url http://[::1]:8545' \
    'forge script script/Deploy.s.sol --broadcast --rpc-url http://127.0.0.1:8545' \
    'forge create src/A.sol:A --rpc-url http://localhost:8545 --broadcast' \
    'npx hardhat ignition deploy ignition/modules/A.ts --network localhost' 'npx hardhat ignition deploy ignition/modules/A.ts' \
    'npx hardhat ignition deploy ignition/modules/A.ts --network hardhat' 'cast call 0xabc "f()" --rpc-url https://rpc.example.org' \
    'forge script script/Deploy.s.sol --rpc-url https://rpc.example.org' 'cast mktx 0xabc "f()" --rpc-url https://rpc.example.org' \
    'cast wallet sign hello' 'forge build' 'npx hardhat test'; do
    passes outbound "$(event_bash "$c")" "$c" || return 1
  done
}

# Clones for the destination checks: fork has the user's origin and someone else's upstream, mine has
# only the user's origin, and theirs is a clone of someone else's project. The URLs take the three
# shapes git remotes hold. The SSH user is joined here, so the file holds no text shaped like an
# email address.
SSH_USER="git""@"
for d in fork mine theirs; do git init -q "$WORK/$d"; done
git -C "$WORK/fork" remote add origin "${SSH_USER}github.com:me/proj.git"
git -C "$WORK/fork" remote add upstream https://github.com/other/proj.git
git -C "$WORK/mine" remote add origin https://github.com/me/tool.git
git -C "$WORK/theirs" remote add origin "ssh://${SSH_USER}github.com/other/lib.git"
own_owners() { mkdir -p "$HOME/.config/agent-guards"; printf '%s\n' '# my accounts' me my-org > "$HOME/.config/agent-guards/own-owners"; }
no_own_owners() { rm -f "$HOME/.config/agent-guards/own-owners"; }

other_repos_refused() {
  own_owners
  local c r pair d result=0
  for c in 'gh issue create -R other/proj --title t --body-file clean.md' 'gh pr create --repo other/proj --title t --body-file clean.md' \
    'gh issue comment 5 -R other/proj --body-file clean.md' 'gh pr comment 7 --repo=other/proj --body "thanks"' \
    'gh pr review 7 -R other/proj --approve' 'gh issue edit 5 -R other/proj --title "new title"' \
    'gh pr close 7 -R other/proj --comment "closing"' 'gh api -X POST repos/other/proj/issues -f title=t' \
    'gh api repos/other/proj/issues/5/comments -f body=hi' 'gh api --method PATCH repos/other/proj/pulls/7 -f title=t' \
    'gh api -X DELETE repos/other/proj/issues/comments/9' \
    'gh api graphql -f query="mutation { closeIssue(input: {issueId: 1}) { clientMutationId } }"' \
    'gh issue create -R "$REPO" --title t --body-file clean.md' "git -C $WORK/theirs push origin main"; do
    refuses outbound "$(event_bash "$c")" "$c" || { result=1; break; }
    r="$(reason outbound "$(event_bash "$c")")"
    case "$r" in *"! $c"*) ;; *) why="the refusal of '$c' does not show '! $c'"; result=1; break ;; esac
  done
  if [ "$result" -eq 0 ]; then
    for pair in "fork|gh pr create --title t --body-file ../clean.md" "fork|git push upstream feat/x" \
      "theirs|git push origin main" "theirs|git push" "theirs|gh issue comment 3 --body-file ../clean.md"; do
      d="$WORK/${pair%%|*}"
      c="${pair#*|}"
      refuses outbound "$(event_bash "$c" "$d")" "$c in ${pair%%|*}" || { result=1; break; }
    done
  fi
  no_own_owners
  return "$result"
}

other_repos_listed_pass() {
  own_owners
  local c pair d result=0
  for c in 'gh issue create -R me/tool --title t --body-file clean.md' 'gh issue create -R My-Org/site --title t --body-file clean.md' \
    'gh api repos/other/proj/issues' 'gh api -X GET repos/other/proj/pulls' 'gh issue edit 5 -R other/proj --add-label bug' \
    'gh issue close 5 -R other/proj' 'gh repo view other/proj' 'gh api graphql -f query="query { viewer { login } }"' \
    'gh api -X POST repos/me/tool/issues -f title=t' "git -C $WORK/mine push origin main"; do
    passes outbound "$(event_bash "$c")" "$c" || { result=1; break; }
  done
  if [ "$result" -eq 0 ]; then
    for pair in "mine|gh issue create --title t --body-file ../clean.md" "fork|git push origin feat/x" "fork|git push" "mine|git push"; do
      d="$WORK/${pair%%|*}"
      c="${pair#*|}"
      passes outbound "$(event_bash "$c" "$d")" "$c in ${pair%%|*}" || { result=1; break; }
    done
  fi
  no_own_owners
  return "$result"
}

other_repos_without_list_pass() {
  no_own_owners
  local c
  for c in 'gh issue create -R other/proj --title t --body-file clean.md' 'gh api -X POST repos/other/proj/issues -f title=t' \
    'gh api graphql -f query="mutation { closeIssue(input: {issueId: 1}) { clientMutationId } }"' \
    'gh issue create -R "$REPO" --title t --body-file clean.md'; do
    passes outbound "$(event_bash "$c")" "$c" || return 1
  done
  passes outbound "$(event_bash 'git push upstream feat/x' "$WORK/fork")" 'git push upstream in fork'
}

# off_lets_only <variable> <hook> <event> [<hook> <event>]...: with <variable>=off the first event passes
# its hook, and every other pair is still refused.
off_lets_only() {
  local var="$1" result=0
  export "$var=off"
  passes "$2" "$3" "$2 with $var=off" || result=1
  shift 3
  while [ "$result" -eq 0 ] && [ "$#" -ge 2 ]; do
    refuses "$1" "$2" "$1 with $var=off" || result=1
    shift 2
  done
  unset "$var"
  return "$result"
}

moved_checks_turn_off() {
  own_owners
  local hl sk sys ch orp envw key rmh result=0
  hl="$(event_file Write "$WORK/linked/b.txt")"
  sk="$(event_text Write "$HOME/.zshrc" 'export FOO_API_KEY="abc123def456"')"
  envw="$(event_file Write "$WORK/.env")"
  sys="$(event_bash 'mount -a')"
  rmh="$(event_bash 'rm -rf ~')"
  ch="$(event_bash 'cast send 0xabc "f()" --rpc-url https://rpc.example.org')"
  orp="$(event_bash 'gh issue create -R other/proj --title t --body-file clean.md')"
  key="$(event_bash 'gh issue create -R me/tool --title t --body-file body.md')"
  off_lets_only AGENT_GUARDS_HARD_LINKS secret-write "$hl" secret-write "$sk" secret-write "$envw" || result=1
  [ "$result" -eq 0 ] && { off_lets_only AGENT_GUARDS_STARTUP_KEYS secret-write "$sk" secret-write "$hl" secret-write "$envw" || result=1; }
  [ "$result" -eq 0 ] && { off_lets_only AGENT_GUARDS_SYSTEM delete "$sys" delete "$rmh" || result=1; }
  [ "$result" -eq 0 ] && { off_lets_only AGENT_GUARDS_CHAIN outbound "$ch" outbound "$orp" outbound "$key" || result=1; }
  [ "$result" -eq 0 ] && { off_lets_only AGENT_GUARDS_OTHER_REPOS outbound "$orp" outbound "$ch" outbound "$key" || result=1; }
  # Turning off the first check of a hook leaves the moved checks in the same hook on.
  [ "$result" -eq 0 ] && { off_lets_only AGENT_GUARDS_SECRET_WRITE secret-write "$envw" secret-write "$hl" secret-write "$sk" || result=1; }
  [ "$result" -eq 0 ] && { off_lets_only AGENT_GUARDS_DELETE delete "$rmh" delete "$sys" || result=1; }
  [ "$result" -eq 0 ] && { off_lets_only AGENT_GUARDS_OUTBOUND outbound "$key" outbound "$ch" outbound "$orp" || result=1; }
  no_own_owners
  return "$result"
}

hooks_file_eight() {
  [ "$(hook_count)" = 8 ] || { why="the hooks file declares $(hook_count) hook commands"; return 1; }
}

MOVED_VARS=(AGENT_GUARDS_HARD_LINKS AGENT_GUARDS_STARTUP_KEYS AGENT_GUARDS_SYSTEM AGENT_GUARDS_CHAIN AGENT_GUARDS_OTHER_REPOS)

docs_name_moved_variables() {
  local v f
  for f in README.md README.ja.md docs/how-it-works.md docs/how-it-works.ja.md; do
    for v in "${MOVED_VARS[@]}" own-owners; do
      grep -qF -- "$v" "$PLUGIN/$f" || { why="$f does not name $v"; return 1; }
    done
  done
}

changelog_names_moved_checks() {
  local entries v
  entries="$(awk '/^## \[/{f=1; next} /^\[[^]]+\]: /{f=0} f && /^- /' "$PLUGIN/CHANGELOG.md")"
  for v in "${MOVED_VARS[@]}"; do
    case "$entries" in *"$v"*) ;; *) why="no section of the changelog names $v"; return 1 ;; esac
  done
}

# A newer entry under Unreleased does not hide the runner entries of 0.2.1, and a changelog that names
# them nowhere still fails.
runner_changelog_below_unreleased() {
  local dir="$T/runners"
  mkdir -p "$dir"
  printf '%s\n' '# Changelog' '' '## [Unreleased]' '' '- A newer change' '' '## [0.2.1] - 2026-01-01' '' \
    '- The hooks read xargs, find -exec, watch, and env -S' '' '## [0.2.0] - 2025-12-01' '' '- Earlier' >"$dir/CHANGELOG.md"
  PLUGIN="$dir" changelog_names_runners || { why="below a newer Unreleased entry: $why"; return 1; }
  printf '%s\n' '# Changelog' '' '## [Unreleased]' '' '- A newer change' '' '## [0.2.1] - 2026-01-01' '' '- Other' >"$dir/CHANGELOG.md"
  if PLUGIN="$dir" changelog_names_runners; then
    why="it passed although no section names the runners"
    return 1
  fi
  why=""
}

check "secret read refuses .env and key files in a shell command" secret_shell_refused
check "secret read refuses .env and key files in the Read tool" secret_read_tool_refused
check "secret read allows .env.example and ordinary files" secret_ordinary_allowed
check "secret read refuses app data and conversation records" secret_app_data_refused
check "secret read allows Documents, Downloads, and Pictures by default" secret_personal_folders_allowed
check "secret-paths adds places to refuse reading" secret_paths_listed
check "secret read refuses a target it cannot tell" secret_unknown_target_refused
check "secret read refuses a read joined after op document create" secret_read_after_op_refused
check "secret write refuses writes to .env and key files in a shell command" secret_write_shell_refused
check "secret write refuses .env and key files in the file tools" secret_write_tools_refused
check "secret write refuses a Codex patch that writes a secret file" secret_write_patch_refused
check "secret write allows .env.example and ordinary files" secret_write_ordinary_allowed
check "secret-paths adds places to refuse writing" secret_paths_write_listed
check "1Password refuses op commands that can print a value" onepassword_value_refused
check "1Password allows op commands that print no value" onepassword_safe_allowed
check "outbound refuses a body holding a key without showing it" outbound_body_key_refused
check "outbound refuses a commit whose staged change holds a key" outbound_commit_key_refused
check "outbound refuses a body it cannot read and shows --body-file" outbound_unreadable_body_refused
check "outbound allows text without keys" outbound_clean_allowed
check "git refuses force push, hard reset, skipped checks, and discarded changes with a ! command" git_dangerous_refused
check "git allows ordinary commands" git_ordinary_allowed
check "delete refuses broad deletes with a ! command" delete_broad_refused
check "delete allows a named folder" delete_named_allowed
check "delete refuses chmod -R on the root, the home folder, and protected places" delete_chmod_refused
check "delete allows chmod -R on a named folder" delete_chmod_named_allowed
check "protected-paths adds places to refuse deleting" protected_paths_listed
check "delete refuses copying and linking into a protected place" delete_copy_into_protected
check "delete refuses tee, dd, and redirects into a protected place" delete_write_into_protected
check "delete refuses mv into a protected place" delete_mv_into_protected
check "delete refuses git rm of a protected place" delete_git_rm_protected
check "the docs say protected places refuse overwriting and git rm" docs_protected_overwrite
check "delete lets commands read from a protected place" delete_reads_protected
check "delete leaves Write and Edit in a protected place to the agent" delete_leaves_file_tools
check "1Password refuses op behind a wrapper option that takes a value" onepassword_wrapped_refused
check "git and delete refuse their commands behind a wrapper option that takes a value" git_delete_wrapped_refused
check "secret read and write refuse secret files behind a wrapper option that takes a value" secret_wrapped_refused
check "the hooks judge the command xargs runs" xargs_command_judged
check "the hooks judge the command after find -exec" find_exec_judged
check "the hooks judge the command watch runs" watch_command_judged
check "the hooks judge the command in the string of env -S" env_split_string_judged
check "the hooks allow ordinary commands behind wrappers and runners" wrapped_ordinary_allowed
check "how-it-works says the hooks read the commands behind wrappers and runners" docs_name_runners
check "the changelog names the commands behind wrappers and runners" changelog_names_runners
check "the changelog check finds released entries below a newer Unreleased entry" changelog_check_reads_below_unreleased
check "each hook turns off with its own variable" turn_off_one_hook
check "records are off by default and on with a variable" records_off_by_default
check "both manifests declare the same hooks" manifests_declare_hooks
check "the README and how-it-works name every hook variable" docs_name_variables
check "the changelog names the new refusals" changelog_names_refusals
check "the changelog check reads the newest release when Unreleased is empty" changelog_check_reads_release
check "the repository rules allow hooks only in plugins without skills" repository_rules_allow_hook_plugins
check "hard links: a write to a file with a second name is refused" hard_link_write_refused
check "hard links: a write to a file with one name passes" hard_link_one_name_passes
check "startup keys: a key written into a shell startup file is refused" startup_key_refused
check "startup keys: a startup file without a key passes" startup_without_key_passes
check "system commands are refused with a ! command" system_commands_refused
check "system command names as arguments and other osascript pass" system_args_pass
check "process check refuses PID 1, 0, and negative PIDs with a ! command" processes_pid_refused
check "process check refuses system processes found by ps and pgrep" processes_system_refused
check "process check refuses targets from a variable or a command substitution" processes_unreadable_refused
check "process check refuses pkill and killall that select only by user" processes_user_only_refused
check "process check lets ordinary kill, pkill, and killall through" processes_ordinary_pass
check "AGENT_GUARDS_PROCESSES=off turns only the process check off" processes_turn_off
check "the docs name the process check and the commands it runs" docs_name_processes
check "chain sends to a target that is not local are refused" chain_remote_refused
check "chain sends to local targets and chain reads pass" chain_local_pass
check "sends to repositories of other owners are refused with a ! command" other_repos_refused
check "sends to listed owners and reads pass" other_repos_listed_pass
check "without own-owners no send is refused for its destination" other_repos_without_list_pass
check "each moved check turns off with its own variable" moved_checks_turn_off
check "the hooks file declares eight hook commands" hooks_file_eight
check "the README and how-it-works name every moved check variable" docs_name_moved_variables
check "the changelog names the moved checks" changelog_names_moved_checks
check "the runner changelog check reads below a newer Unreleased entry" runner_changelog_below_unreleased

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
printf 'checks: %d\n' "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
