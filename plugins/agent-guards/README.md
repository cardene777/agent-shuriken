# Agent Guards

Hooks that stop your agent, in Claude Code and Codex, before it reads a key file, sends a key to GitHub, runs a force push, or deletes your home folder.

English · [日本語](README.ja.md)

An agent that runs shell commands for you can read `~/.ssh/id_ed25519` or `.env` while it looks for a setting, paste what it read into an issue, run `git push --force` to get past a rejected push, or run `rm -rf ~ /tmp/build` with a stray space.
Each of these takes one command, and none of them can be undone after the command runs.
This plugin adds four hooks that run before every shell command and every file read the agent makes, and refuse those commands with a reason the agent can act on.
The hooks never approve a command; anything they do not refuse goes on to your agent's own permission rules as before.

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install agent-guards@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add agent-guards@agent-shuriken
```

The hooks start working in the next session.
Codex runs a plugin's hooks only after you trust them: in a Codex session, open `/hooks` and trust the five agent-guards hooks.
After an update changes a hook, Codex marks it as modified and stops running it until you trust it again in `/hooks`.

## What each hook refuses

| Hook | Refuses | Lets through | Turn off with |
|---|---|---|---|
| Secret read | Reading `.env` files, private keys, `.pem` and `.key` files, files in a `secrets` folder, credential files such as `~/.aws/credentials`, `~/.npmrc`, and `~/.netrc`, shell histories, the private data of macOS apps (the keychains, Messages, Mail, Calendars, Safari, cookies, Chrome, Firefox, 1Password, and the address book), and Claude Code's conversation records, through a shell command or the Read tool. It also refuses a read whose file comes from a variable or a command substitution | `.env.example`, `.env.sample`, `.env.template`, `.env.test`, public keys, and every other file | `AGENT_GUARDS_SECRET_READ=off` |
| Outbound | `gh issue`, `gh pr`, `gh release`, `gh gist`, and `gh api` commands, and `git commit`, whose command line, body file, or staged change holds a key-shaped value, such as a GitHub, AWS, Anthropic, OpenAI, Google, Slack, or Stripe key, a private key block, or a password in a URL. It names the kind of key and the line, never the value. It also refuses a body it cannot read, such as `--body "$(cat file)"` or `--body -`, and shows the `--body-file <path>` form | Text without a key-shaped value | `AGENT_GUARDS_OUTBOUND=off` |
| Git | `git push --force` and its other forms, `git reset --hard`, `--no-verify`, `git clean -f`, and `git checkout -- .`, `git restore`, and the other forms that throw away uncommitted changes | Ordinary pushes, branch switches, `git clean -n`, `git restore --staged`, and every other git command | `AGENT_GUARDS_GIT=off` |
| Delete | `rm -r` and `mv` of the root, the home folder, the current folder, a top-level system folder, or `*`, and `find` with `-delete` on them | Deletes of a named file or folder, such as `rm -rf ./build` | `AGENT_GUARDS_DELETE=off` |

A refused git or delete command comes back with the same command after a leading `!`, so you can run it yourself when you mean it.
In Claude Code, a line typed with a leading `!` runs in your shell as your own command; in Codex, run the command in a terminal.

Set a variable in the `env` field of `~/.claude/settings.json` for Claude Code, or in your shell's startup file for Codex.

## Your own places

Two list files add places on your machine.
Each holds one place per line; a line that starts with `~/` starts at your home folder, a line without `/` matches a file name anywhere, and a line that starts with `#` is a comment.
A missing file adds nothing.

| File | What its places get |
|---|---|
| `~/.config/agent-guards/secret-paths` | Refused for reading, with everything inside them |
| `~/.config/agent-guards/protected-paths` | Refused for deleting and moving, with everything inside them |

```
# ~/.config/agent-guards/secret-paths
~/Documents
~/work/keys
*.dump
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
| `git` | Reading the staged change of a commit |

## What it reads, runs, and sends

- It reads the event Claude Code or Codex sends before each shell command and file read, the body files a `gh` command names, the staged change and the files `git add` names before a commit, and the two list files
- It runs `git rev-parse`, `git diff`, and `git ls-files` in the repository of a commit, and nothing else
- It sends nothing anywhere and keeps nothing unless `AGENT_GUARDS_RECORD=on` is set
- It is not uploaded to OpenAI's plugin directory, because a plugin with hooks is not accepted there; install it from this marketplace

[How it works](docs/how-it-works.md) has the rules each hook follows.

## License

MIT
