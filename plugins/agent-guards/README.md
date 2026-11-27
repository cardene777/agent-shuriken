# Agent Guards

Hooks that stop your agent, in Claude Code and Codex, before it reads or overwrites a key file, prints a value stored in 1Password, sends a key to GitHub, runs a force push, deletes your home folder, or ends the processes your desktop runs on.

English · [日本語](README.ja.md)

An agent that runs shell commands for you can read `~/.ssh/id_ed25519` or `.env` while it looks for a setting, paste what it read into an issue, run `git push --force` to get past a rejected push, or run `rm -rf ~ /tmp/build` with a stray space.
Each of these takes one command, and none of them can be undone after the command runs.
This plugin adds six hooks that run before every shell command, file read, and file edit the agent makes, and refuse those commands with a reason the agent can act on.
Three of the hooks run more than one check in the same process, so the twelve checks start no more processes than the six hooks.
The hooks never approve a command; anything they do not refuse goes on to your agent's own permission rules as before.

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install agent-guards@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add agent-guards@agent-shuriken
```

The hooks start working in the next session.
Codex runs a plugin's hooks only after you trust them: in a Codex session, open `/hooks` and trust the eight agent-guards hooks.
After an update changes a hook, Codex marks it as modified and stops running it until you trust it again in `/hooks`.

## What each check refuses

Each check turns off with its own variable; a check named after another one in parentheses runs in that hook.

| Check | Refuses | Lets through | Turn off with |
|---|---|---|---|
| Secret read | Reading `.env` files, private keys, `.pem` and `.key` files, files in a `secrets` folder, credential files such as `~/.aws/credentials`, `~/.npmrc`, and `~/.netrc`, shell histories, the private data of macOS apps (the keychains, Messages, Mail, Calendars, Safari, cookies, Chrome, Firefox, 1Password, and the address book), and Claude Code's conversation records, through a shell command or the Read tool. It also refuses a read whose file comes from a variable or a command substitution | `.env.example`, `.env.sample`, `.env.template`, `.env.test`, public keys, and every other file | `AGENT_GUARDS_SECRET_READ=off` |
| Secret write | Writing the same secret files, and the places in your `secret-paths` list, with `>`, `>>`, `tee`, `cp`, `mv`, `sed -i`, `truncate`, or `dd`, with the Write, Edit, MultiEdit, and NotebookEdit tools of Claude Code, and with a Codex patch that adds, changes, moves, or deletes one. These files are not in git, so an overwrite cannot be undone | Writes to `.env.example` and every other file, and writes whose target comes from a variable | `AGENT_GUARDS_SECRET_WRITE=off` |
| 1Password | Every `op` command of the 1Password CLI that can print a stored value, such as `op read`, `op item get`, `op document get`, `op run`, `op inject`, and `op signin`, and the commands that create or delete items, also inside `bash -c` and `$(...)` | `op whoami`, `op account list`, `op vault list`, `op item list`, `op document list`, `op document create`, `op document edit`, `op --version`, and `op help`, so a `.env` file can be stored in 1Password without being read | `AGENT_GUARDS_ONEPASSWORD=off` |
| Outbound | `gh issue`, `gh pr`, `gh release`, `gh gist`, and `gh api` commands, and `git commit`, whose command line, body file, or staged change holds a key-shaped value, such as a GitHub, AWS, Anthropic, OpenAI, Google, Slack, or Stripe key, a private key block, or a password in a URL. It names the kind of key and the line, never the value. It also refuses a body it cannot read, such as `--body "$(cat file)"` or `--body -`, and shows the `--body-file <path>` form | Text without a key-shaped value | `AGENT_GUARDS_OUTBOUND=off` |
| Git | `git push --force` and its other forms, `git reset --hard`, `--no-verify`, `git clean -f`, and `git checkout -- .`, `git restore`, and the other forms that throw away uncommitted changes | Ordinary pushes, branch switches, `git clean -n`, `git restore --staged`, and every other git command | `AGENT_GUARDS_GIT=off` |
| Delete | `rm -r` and `mv` of the root, the home folder, the current folder, a top-level system folder, or `*`, `find` with `-delete` on them, and `chmod -R`, `chown -R`, and `chgrp -R` on them, which can lock you out of the folder like a delete | Deletes and permission changes of a named file or folder, such as `rm -rf ./build` and `chmod -R 755 ./build` | `AGENT_GUARDS_DELETE=off` |
| Hard links (secret write) | A write through a file that has a second name (hard link), by the file tools, a Codex patch, `>`, `tee`, `cp`, `truncate`, or `dd`, since a harmless name can overwrite a key file under its other name | Files with one name, new files, and `mv`, `ln`, and `sed -i`, which replace the name instead | `AGENT_GUARDS_HARD_LINKS=off` |
| Startup keys (secret write) | A literal value in a variable named like a key (ending in `_KEY`, `_TOKEN`, `_SECRET`, or `_PASSWORD`), or any key-shaped value, written into `.zshrc`, `.bashrc`, `.profile`, the fish config, or another shell startup file, also in a dotfiles folder or under a chezmoi source name, by the file tools, a Codex patch, or a command such as `echo ... >> ~/.zshrc`. It names the file and the variable, never the value | Values read at startup, such as `"$(security find-generic-password -s NAME -w)"`, placeholders such as `REPLACE_ME`, and every other line | `AGENT_GUARDS_STARTUP_KEYS=off` |
| Chain (outbound) | `cast send`, `cast publish`, the sending forms of `cast rpc` and `cast erc20-token`, `forge script --broadcast`, `forge create`, and `hardhat ignition deploy`, when the target is not `127.0.0.1`, `localhost`, or `::1`, or cannot be read | The same commands against a chain on this machine, and reads such as `cast call` | `AGENT_GUARDS_CHAIN=off` |
| Other repositories (outbound) | With an `own-owners` list, issues, pull requests, comments, reviews, and title or body edits sent with `gh` or `gh api` to a repository of an owner not in the list, a `git push` to such a repository, GraphQL mutations, and repositories held in variables | Sends to your own owners, reads, label changes, and every send when there is no list | `AGENT_GUARDS_OTHER_REPOS=off` |
| System (delete) | `mount`, `umount`, `chroot`, `pfctl`, `mkfs`, and `osascript` running a shell script with administrator privileges, also behind `sudo` and `bash -c` | The same names as arguments, such as `grep mount notes.txt`, and other `osascript` scripts | `AGENT_GUARDS_SYSTEM=off` |
| Processes (delete) | `kill` of PID 1, PID 0, or a negative PID such as `-1`, which signals every process; `kill` of a PID that `ps` reports as a system process, such as launchd, WindowServer, Finder, systemd, or sshd; `pkill` or `killall` of a system process name or of a pattern that `pgrep` matches to one; `pkill` and `killall` that pick processes only by user; ending a terminal app such as `Terminal`, `iTerm2`, ghostty, or konsole, which closes the agent's own window; and targets taken from a variable or a command substitution, such as `kill $PID` or `kill $(pgrep -f node)`, also behind `sudo` and `bash -c` | `kill` of other PIDs, also with a redirect such as `2>&1`, `kill $!`, `kill %1`, a `kill -0` probe of any target, `pkill -f` of a pattern that matches no system process, and `killall node` | `AGENT_GUARDS_PROCESSES=off` |

A refused git, delete, system, process, chain, or other-repository command comes back with the same command after a leading `!`, so you can run it yourself when you mean it.
In Claude Code, a line typed with a leading `!` runs in your shell as your own command; in Codex, run the command in a terminal.

Set a variable in the `env` field of `~/.claude/settings.json` for Claude Code, or in your shell's startup file for Codex.

## Your own places

Two list files add places on your machine, and a third names the GitHub owners that are yours.
A place list holds one place per line; a line that starts with `~/` starts at your home folder, a line without `/` matches a file name anywhere, and a line that starts with `#` is a comment.
A missing file adds nothing.

| File | What it does |
|---|---|
| `~/.config/agent-guards/secret-paths` | Its places are refused for reading and writing, with everything inside them |
| `~/.config/agent-guards/protected-paths` | Its places are refused for deleting, moving, `chmod -R`, writing over them with a copy, a link, `tee`, `dd`, or a redirect, and `git rm`, with everything inside them. Reading from them and the agent's own file tools stay allowed |
| `~/.config/agent-guards/own-owners` | Each line names a GitHub user or organization that is yours, and sends to repositories of other owners are refused. Without it, no send is refused for where it goes |

```
# ~/.config/agent-guards/secret-paths
~/Documents
~/work/keys
*.dump
```

```
# ~/.config/agent-guards/own-owners
your-github-name
your-organization
```

When `XDG_CONFIG_HOME` is set, the files live in `$XDG_CONFIG_HOME/agent-guards/` instead.

## Records

The hooks write nothing by default.
With `AGENT_GUARDS_RECORD=on`, each refusal adds one line with the time, the hook, and the kind of refusal to `~/.local/share/agent-guards/refusals.log`.
The line never holds the command or a value.

## Requirements

| Needs | For |
|---|---|
| Python 3 | Every hook. Without it, every hook refuses each call and says to install Python 3 or turn the hook off |
| `bash` | Starting the hooks |
| `git` | Reading the staged change of a commit, and the remotes of a clone that a `gh` send or a push goes from |
| `ps` and `pgrep` | Finding which processes a `kill`, `pkill`, or `killall` names. Without them, those commands go on to your agent's permission rules |

## What it reads, runs, and sends

- It reads the event Claude Code or Codex sends before each shell command, file read, and file edit, the body files a `gh` command names, the staged change and the files `git add` names before a commit, the link count of each file a write names, and the three list files
- It runs `git rev-parse`, `git diff`, and `git ls-files` in the repository of a commit, and `git config`, `git symbolic-ref`, and `git remote get-url` in the clone of a `gh` send or a push to read its remotes, and `ps` and `pgrep` to find which processes a `kill`, `pkill`, or `killall` names, and nothing else
- It sends nothing anywhere and keeps nothing unless `AGENT_GUARDS_RECORD=on` is set
- It is not uploaded to OpenAI's plugin directory, because a plugin with hooks is not accepted there; install it from this marketplace

[How it works](docs/how-it-works.md) has the rules each hook follows.

## License

MIT
