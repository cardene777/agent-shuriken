# Agent Notices

Hooks that tell your agent, in Claude Code and Codex, about mistakes that fail without a clear error, and format each file it edits, without ever stopping a call.

English · [日本語](README.ja.md)

An agent that writes shell scripts and runs commands for you makes mistakes that no command reports.
`find . | grep -q x` under `set -o pipefail` fails even when the text is there, `nohup make &` finishes without the agent hearing of it, and `git switch feature` can leave the repository on `main` while the agent goes on as if it switched.
This plugin adds hooks that run after the agent's shell commands and edits and add a short notice that the agent reads before its next step.
The hooks never stop, change, or approve a call; your agent's own permission rules stay as before.
Hooks that stop risky commands are in the separate [agent-guards](../agent-guards) plugin.

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install agent-notices@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add agent-notices@agent-shuriken
```

The hooks start working in the next session.
Codex runs a plugin's hooks only after you trust them: in a Codex session, open `/hooks` and trust the agent-notices hooks.
After an update changes a hook, Codex marks it as modified and stops running it until you trust it again in `/hooks`.

## What each hook does

| Hook | Runs after | Tells the agent | Turn off with |
|---|---|---|---|
| pipefail-grep | An edit of a shell script | That a line it added pipes into `grep -q` while the script sets `pipefail`, with the file and line, since the pipe then fails even when the text is found | `AGENT_NOTICES_PIPEFAIL_GREP=off` |
| nohup | A shell command | That `nohup` with `&` or `disown` detaches the command, so no completion notice comes, and to use the agent's own background run | `AGENT_NOTICES_NOHUP=off` |
| grep-binary | The Grep tool of Claude Code | That the search found nothing while a binary file under the searched path holds the pattern, with the file, and to search it with `grep -a` or `rg -a` | `AGENT_NOTICES_GREP_BINARY=off` |
| branch | A shell command | That `git switch` or `git checkout` left the repository on another branch, or that `git commit` ran on a branch other than the one the session last switched to | `AGENT_NOTICES_BRANCH=off` |
| env-example | An edit of JavaScript, TypeScript, Python, Go, Ruby, or Rust | That the edit added a read of an environment variable that the repository's `.env.example` does not list | `AGENT_NOTICES_ENV_EXAMPLE=off` |
| tmp-space | A shell command | That the temporary directory has less free space than `AGENT_NOTICES_TMP_MIN_GB` gigabytes, 5 by default | `AGENT_NOTICES_TMP_SPACE=off` |
| security | An edit | The reminder of each pattern of Anthropic's `security-guidance` plugin that the new code matches, such as `os.system(`, `innerHTML =`, `pickle.load`, or a GitHub Actions workflow | `AGENT_NOTICES_SECURITY=off` |
| format | An edit | Runs the project's own formatter on the edited file, and tells the agent when the file changed so it reads it again | `AGENT_NOTICES_FORMAT=off` |
| edit-loop | An edit | That it has edited the same file `AGENT_NOTICES_EDIT_LOOP_EVERY` times in this session, 5 by default, and again at every multiple, and to reproduce the failure and find the root cause before the next fix. `AGENT_NOTICES_EDIT_LOOP_SKILL=<skill>` makes the notice name your own debugging skill. Files git ignores and files in the temporary directory get no notice | `AGENT_NOTICES_EDIT_LOOP=off` |
| sequential | Any tool call in Claude Code | That the last `AGENT_NOTICES_SEQUENTIAL_AFTER` tool calls, 10 by default, each came in a message of their own, and to make calls that do not need each other's results together in one message | `AGENT_NOTICES_SEQUENTIAL=off` |
| presence | The start and end of a Claude Code session | Nothing. It creates the file `CLAUDE_CLIENT_PRESENCE_FILE` names at session start and removes it at session end, so Claude Code holds back mobile notifications while you are at the machine | `AGENT_NOTICES_PRESENCE=off` |
| skill-log | A skill call in Claude Code | Nothing. It writes one line per call when turned on | Off unless `AGENT_NOTICES_SKILL_LOG=on` |
| mcp-log | An MCP tool call | Nothing. It writes one line per call when turned on | Off unless `AGENT_NOTICES_MCP_LOG=on` |

Set a variable in the `env` field of `~/.claude/settings.json` for Claude Code, or in your shell's startup file for Codex.
A notice for an edit comes right after the edit, since that is when the agent reads it.
Codex has no Grep tool and no skill tool call, so grep-binary and skill-log run only in Claude Code; the presence file is read only by Claude Code.
sequential also runs only in Claude Code, where `CLAUDECODE=1` is set, since its rule for telling calls made together from calls made one at a time was measured there.

## Formatters

The format hook runs a formatter only when the project's settings name it and the tool is already installed.
It installs nothing and never runs `npx`.

| Files | Formatter | When |
|---|---|---|
| JavaScript, TypeScript, JSON, CSS | Biome, `biome format --write` | A `biome.json` or `biome.jsonc` is in the file's folder or above, and `biome` is in `node_modules/.bin` there or on `PATH` |
| JavaScript, TypeScript, JSON, CSS, HTML, Markdown, YAML, and the other Prettier files | Prettier, `prettier --write` | A Prettier config file, or a `prettier` key in `package.json`, is in the file's folder or above, and `prettier` is in `node_modules/.bin` there or on `PATH` |
| Python | Ruff, `ruff format` | `pyproject.toml` has a `[tool.ruff]` table, or a `ruff.toml` is there, and `ruff` is in `.venv/bin`, `venv/bin`, or on `PATH` |
| Python | Black, `black -q` | `pyproject.toml` has a `[tool.black]` table and no Ruff settings, and `black` is in `.venv/bin`, `venv/bin`, or on `PATH` |
| Go | `gofmt -w` | A `go.mod` is in the file's folder or above, and `gofmt` is on `PATH` |
| Rust | `rustfmt` with the edition of `Cargo.toml` | A `Cargo.toml` is in the file's folder or above, and `rustfmt` is on `PATH` or in `~/.cargo/bin` |

## Logs

The skill and MCP logs write nothing by default.
With `AGENT_NOTICES_SKILL_LOG=on`, each skill call adds one line to `~/.local/share/agent-notices/skill-calls.jsonl`; with `AGENT_NOTICES_MCP_LOG=on`, each MCP call adds one line to `~/.local/share/agent-notices/mcp-calls.jsonl`.

```
{"v":1,"skill":"pdf","start":"2026-11-24T06:12:03.418Z","end":"2026-11-24T06:12:09.902Z","duration_ms":6484,"ok":true}
{"v":1,"server":"files","tool":"read_file","start":"2026-11-24T06:13:40.010Z","end":"2026-11-24T06:13:40.152Z","duration_ms":142,"ok":false}
```

A line holds the skill name, or the MCP server and tool, the start and end times in UTC, the duration, and whether the call succeeded.
It never holds the arguments or the result of a call, since they can carry your text or a key.
Only you can read the files, and a file over 1 MB moves to `.1` before the next line.
When `XDG_DATA_HOME` is set, the files live in `$XDG_DATA_HOME/agent-notices/` instead.

## Requirements

| Needs | For |
|---|---|
| Python 3 | Every hook. Without it, the hooks do nothing |
| `bash` | Starting the hooks |
| `git` | The branch hook, finding the top of the repository for env-example and format, and telling whether git ignores a file for edit-loop |

## What it reads, runs, and sends

- It reads the event Claude Code or Codex sends after each shell command, edit, Grep, skill call, and MCP call, the files an edit changed, the `.env.example` files at the top of the repository, the project settings that name a formatter, and, after a Grep that found nothing, the files under the searched path
- It runs `git` in the repository a command names, and the project's own formatter on the edited file
- It keeps the branch each session last switched to, how many times each session edited each file, how many calls in a row came one at a time, and the start time of a call while the logs are on, in `~/.local/share/agent-notices/`, readable only by you, and removes branch and count records older than seven days
- It sends nothing anywhere and calls no model
- It is not uploaded to OpenAI's plugin directory, because a plugin with hooks is not accepted there; install it from this marketplace

The reminders of the security hook come from `hooks/lib/security_guidance/patterns.py` of Anthropic's `security-guidance` plugin, copied unmodified under the Apache License 2.0; [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) has its source.
[How it works](docs/how-it-works.md) has the rules each hook follows.

## License

MIT, except `hooks/lib/security_guidance/`, which is under the Apache License 2.0
