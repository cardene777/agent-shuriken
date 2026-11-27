# How Agent Notices works

English · [日本語](how-it-works.ja.md)

Claude Code and Codex start each hook after a shell command, an edit, a Grep, a skill call, or an MCP call, and at the start and end of a session, and pass the event as JSON on standard input.
A hook that has something to say prints one JSON object whose `additionalContext` the agent reads after the call, and prints nothing otherwise.
It never prints a deny, an ask, a block, or a stop, and it exits 0 even when it cannot read the event, so a call always goes on as the agent's own rules decide.
All hooks share one Python file, `hooks/lib/agent_notices.py`, and each `hooks/<name>.sh` starts it with the hook's name.

## How an edit is read

| Call | Files | Added text | Removed text |
|---|---|---|---|
| Write | `file_path` | `content` | none |
| Edit | `file_path` | `new_string` | `old_string` |
| MultiEdit | `file_path` | every `new_string` | every `old_string` |
| Codex `apply_patch` | each `*** Add File:`, `*** Update File:`, and `*** Move to:` path, relative to the working folder | the lines that start with `+` | the lines that start with `-` |

A deleted file is skipped.
The hooks that look at code read the added text, so a line that was in the file before the edit gives no notice.

## pipefail-grep

The hook looks at an edited file that ends in `.sh`, `.bash`, `.zsh`, or `.ksh`, or starts with a shell's `#!` line.
When the file has a `set` line with `pipefail`, it names each line the edit added that pipes into `grep` with `-q`, `--quiet`, or `--silent`.
`grep -q` stops reading at the first match, the command before it can then die of SIGPIPE, and `pipefail` makes the pipe fail although the text was found.

## nohup

The hook reads the command with the text inside quotes left out.
It speaks when `nohup` starts a command and the command also has `disown` or an `&` that sends a command to the background.
An `&` of `&&`, `2>&1`, `>&2`, `&>`, and `|&` is not counted.

## grep-binary

After the Grep tool of Claude Code reports no match, the hook walks the searched path, skipping `.git`, and reads up to 5000 files.
A file with a NUL byte in its first 8 KiB is binary, and the hook searches its first 16 MiB for the pattern.
It names up to five binary files that hold the pattern.

## branch

The hook reads a shell command that has `git switch`, `git checkout`, or `git commit`, cut at `;`, `&&`, `||`, `|`, and line breaks.
It follows `git -C <folder>` and a `cd <folder>` before the git command to find the repository.

| Command | When the hook speaks |
|---|---|
| `git switch <branch>`, `git switch -c <branch>`, `git checkout <branch>`, `git checkout -b <branch>` | The repository is on another branch, or on a detached HEAD, after the command |
| `git commit` | The repository is on a branch other than the one this session last switched to in that repository |

`git checkout` of a file, with `--` or a name that is not a branch, is not a switch.
The branch a session last switched to is kept per session and repository in `~/.local/share/agent-notices/branches/`, and records older than seven days are removed.

## env-example

The hook reads the names an edit's added text reads from the environment, without the names its removed text read.

| Language | Reads |
|---|---|
| JavaScript and TypeScript | `process.env.NAME`, `process.env["NAME"]`, `import.meta.env.NAME`, `Deno.env.get("NAME")`, `Bun.env.NAME` |
| Python | `os.environ["NAME"]`, `os.environ.get("NAME")`, `os.getenv("NAME")` |
| Go | `os.Getenv("NAME")`, `os.LookupEnv("NAME")` |
| Ruby | `ENV["NAME"]`, `ENV.fetch("NAME")` |
| Rust | `env::var("NAME")`, `env::var_os("NAME")`, `env!("NAME")`, `option_env!("NAME")` |

The example files are the files at the top of the repository named `.env.example`, `.env.sample`, `.env.template`, or such a name with another part, like `.env.local.example`.
A name is listed when a line, commented out or not, sets it, like `NAME=` or `# NAME=`.
A repository without an example file gets no notice, and `NODE_ENV`, `PATH`, `HOME`, `USER`, `PWD`, `SHELL`, `TMPDIR`, `TEMP`, `TMP`, `LANG`, `CI`, and `TZ` are never named.

## tmp-space

After each shell command, the hook reads the free space of `TMPDIR`, or of the system's temporary directory when it is not set.
It speaks while the free space is under `AGENT_NOTICES_TMP_MIN_GB` gigabytes, 5 by default.

## security

The hook loads `SECURITY_PATTERNS` from `hooks/lib/security_guidance/patterns.py`, Anthropic's file copied unmodified, and checks each edited file the way the upstream hook does.
A pattern with `path_filter` applies only to the paths it accepts; a pattern matches when its `path_check` accepts the path, when one of its `substrings` is in the added text, or when its `regex` finds the added text.
For each match, the hook adds the pattern's `reminder`, up to five.
It calls no model and opens no connection.

## format

For each edited file, the hook walks from the file's folder up to the top of the repository and takes the first folder whose settings name a formatter, as the README's table lists.
It runs the formatter in that folder with a 20 second limit and drops its output.
When the file's contents changed, it tells the agent to read the file again, since an edit that quotes the old text would fail.
A formatter that is named but not installed is skipped; nothing is installed and `npx` is never run.

## edit-loop

After each edit, the hook adds one to the count of each file the edit changed, read as the table above says, in the count file of the session under `~/.local/share/agent-notices/edit-loop/`.
The file is named by a hash of the session id and holds one JSON object from each file's real path to its count.
When a count reaches a multiple of `AGENT_NOTICES_EDIT_LOOP_EVERY`, 5 by default, the hook tells the agent the file and the count, and to write a command that reproduces the failure and confirm the root cause before the next fix.
With `AGENT_NOTICES_EDIT_LOOP_SKILL=<skill>`, the notice asks the agent to do that with that skill; a value other than letters, digits, `_`, `:`, `.`, and `-` is not used.
A file git ignores, judged with `git check-ignore` in the file's folder only when the count reaches the notice, and a file in the temporary directory that Python reports, which is `TMPDIR` when it is set and `/tmp` otherwise, get no notice; they are drafts, not the work.
Edits in another session have their own count file.

## sequential

The hook runs after every tool call in Claude Code, where `CLAUDECODE=1` is set in the hook's environment, and does nothing elsewhere or after `AskUserQuestion` and `ExitPlanMode`.
It keeps the count of calls in a row that came one at a time, and the time of the last call, in the count file of the session under `~/.local/share/agent-notices/sequential/`, named by a hash of the session id.
A call less than 200 milliseconds after the last one came together with it in one message, and starts the count over at 0.
A call 500 milliseconds or more after the last one starts a new message and adds one; a call in between leaves the count as it is.
When the count reaches `AGENT_NOTICES_SEQUENTIAL_AFTER`, 10 by default, the hook tells the agent to make calls that do not need each other's results together in one message, and starts over at 0.
Each count file is read and written under a lock, so two calls that end at the same moment do not lose a count.

Both folders are readable only by you, the count files are created with mode 600, and a count file older than seven days is removed on the next write.

## presence

At `SessionStart`, the hook creates the file `CLAUDE_CLIENT_PRESENCE_FILE` names, with its folder, or updates its time.
At `SessionEnd`, it removes the file.
Without the variable, it does nothing.

## skill-log and mcp-log

At `PreToolUse`, the hook keeps the start time of the call under `~/.local/share/agent-notices/pending/`, keyed by the call's `tool_use_id`.
At `PostToolUse` or `PostToolUseFailure`, it writes one line with the end time, the duration, and `ok` set to whether the call succeeded, and removes the start time.
The skill log takes the name from the Skill call's `skill` field; the MCP log splits `mcp__<server>__<tool>` into the server and the tool.
The folder is readable only by you, the files are created with mode 600, and a file over 1 MB moves to `.1` before the next line.

## When a hook cannot judge

A hook that cannot read the event, or fails while judging, prints nothing and exits 0.
Without Python 3, every hook does nothing.
Each hook turns off with its own variable set to `off`, and the two logs turn on with theirs set to `on`, as the README lists.

## Limits

- The nohup and branch hooks see only the command text the agent sends; a script the command runs is not read
- The env-example hook reads the usual forms of each language; a name built at run time is not found
- The grep-binary hook reads the pattern as a Python regular expression, which matches most patterns of ripgrep but not every one
- The sequential hook tells calls made together from calls made one at a time only by the time between them, so the first call of a message with several calls counts as one made alone, and edits made through a shell command are not counted by edit-loop
