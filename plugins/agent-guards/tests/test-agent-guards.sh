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
  AGENT_GUARDS_OUTBOUND AGENT_GUARDS_GIT AGENT_GUARDS_DELETE AGENT_GUARDS_RECORD
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

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

# The newest entries: those under Unreleased, or those of the newest release when Unreleased has none.
changelog_names_refusals() {
  local section where="the Unreleased section"
  section="$(awk '/^## \[Unreleased\]/{f=1; next} /^## \[/{f=0} f && /^- /' "$PLUGIN/CHANGELOG.md")"
  if [ -z "$section" ]; then
    where="the newest release section"
    section="$(awk '/^## \[[0-9]/{n++; next} /^## \[/ || /^\[[^]]+\]: /{if (n) exit} n == 1 && /^- /' "$PLUGIN/CHANGELOG.md")"
  fi
  local w
  for w in AGENT_GUARDS_SECRET_WRITE AGENT_GUARDS_ONEPASSWORD 'chmod -R'; do
    case "$section" in *"$w"*) ;; *) why="$where does not name $w"; return 1 ;; esac
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
  # Entries still under Unreleased are read first, and an older release does not stand in for them.
  printf '%s\n' '# Changelog' '' '## [Unreleased]' '' '- An unrelated change' '' '## [0.2.0] - 2026-01-01' '' \
    '- Turn it off with `AGENT_GUARDS_SECRET_WRITE=off`' '- Turn it off with `AGENT_GUARDS_ONEPASSWORD=off`' \
    '- The delete hook also refuses `chmod -R`' >"$dir/CHANGELOG.md"
  if PLUGIN="$dir" changelog_names_refusals; then
    why="it read the 0.2.0 section although Unreleased has entries"
    return 1
  fi
  why=""
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

# The entries of this change name the commands the hooks now read behind wrappers and runners.
changelog_names_runners() {
  local section
  section="$(awk '/^## \[Unreleased\]/{f=1; next} /^## \[/{f=0} f && /^- /' "$PLUGIN/CHANGELOG.md")"
  if [ -z "$section" ]; then
    section="$(awk '/^## \[[0-9]/{n++; next} /^## \[/ || /^\[[^]]+\]: /{if (n) exit} n == 1 && /^- /' "$PLUGIN/CHANGELOG.md")"
  fi
  local w
  for w in xargs 'find -exec' watch 'env -S'; do
    case "$section" in *"$w"*) ;; *) why="the newest entries do not name $w"; return 1 ;; esac
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

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
printf 'checks: %d\n' "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
