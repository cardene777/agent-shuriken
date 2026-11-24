# How Agent Guards works

English · [日本語](how-it-works.ja.md)

Claude Code and Codex start each hook before a shell command, a file read, or a file edit, and pass the call as JSON on standard input.
A hook prints a deny decision with its reason when it refuses the call, and prints nothing otherwise.
It never prints an approval, so a call it does not refuse still goes through the agent's own permission rules.
All six hooks share one Python file, `hooks/lib/agent_guards.py`, and each `hooks/<name>.sh` starts it with the hook's name.

| Hook | Runs before | Turned off with |
|---|---|---|
| `secret-read.sh` | A shell command and the Read tool | `AGENT_GUARDS_SECRET_READ=off` |
| `secret-write.sh` | A shell command, the Write, Edit, MultiEdit, and NotebookEdit tools, and Codex's `apply_patch` | `AGENT_GUARDS_SECRET_WRITE=off` |
| `onepassword.sh` | A shell command | `AGENT_GUARDS_ONEPASSWORD=off` |
| `outbound.sh` | A shell command | `AGENT_GUARDS_OUTBOUND=off` |
| `git.sh` | A shell command | `AGENT_GUARDS_GIT=off` |
| `delete.sh` | A shell command | `AGENT_GUARDS_DELETE=off` |

## How a command is read

The hooks read the command the way a shell splits it.
They cut the command at `;`, `&&`, `||`, `|`, `&`, parentheses, and line breaks, and read each part on its own.
They skip leading variable assignments and the words `sudo`, `env`, `command`, `nohup`, `time`, `timeout`, and `exec`, so `sudo rm -rf /` is read as `rm`.
They read the text after `bash -c`, `sh -c`, `zsh -c`, and `eval` as another command, up to three levels deep.
The body of a here-document opened outside quotes is not read as commands.
`~`, `$HOME`, and `${HOME}` become your home folder; any other variable or command substitution is left unknown.

## Secret read

The hook looks at the files that reading commands take: `cat`, `head`, `tail`, `less`, `more`, `grep`, `rg`, `sed`, `awk`, `jq`, `cut`, `sort`, `diff`, `base64`, `source`, and the other readers in the source, the files after `<`, and the sources of `cp`, `scp`, and `rsync`.
For `grep`, `rg`, `sed`, `awk`, and `jq`, the first word is the pattern or the program, not a file.
For `python`, `node`, `ruby`, `perl`, `php`, `bun`, and `deno`, it looks at the quoted strings in the code after `-c` or `-e`.
For the Read tool, it looks at `file_path`.

| A file is secret when | Examples |
|---|---|
| Its name is `.env` or starts with `.env.`, except names ending in `.example`, `.sample`, or `.template`, and `.env.test` | `.env`, `.env.local`, `.env.production` |
| It is a private key or ends in `.pem`, `.key`, `.p12`, `.pfx`, `.token`, `.secret`, or `.private` | `id_ed25519`, `server.pem` |
| Its name has `_token` or `_key` and it is not source code | `api_token.txt`, `service_key.json` |
| It is inside a folder named `secrets` or `.secrets` | `secrets/api.txt` |
| It is a credential file or a shell history | `~/.aws/credentials`, `~/.npmrc`, `~/.netrc`, `~/.git-credentials`, `~/.docker/config.json`, `~/.kube/config`, `~/.pgpass`, `~/.zsh_history`, files under `~/.config/gcloud/`, `~/.azure/`, and `~/.gnupg/` |
| It is private app data on macOS | files under `~/Library/Keychains`, `Messages`, `Mail`, `Calendars`, `Safari`, `Cookies`, `Group Containers`, and the Chrome, Firefox, 1Password, and address book folders of `~/Library/Application Support` |
| It is one of Claude Code's conversation records | `~/.claude/history.jsonl`, `~/.claude/projects/*/*.jsonl` |
| It is in your `secret-paths` list | `~/Documents` |

When a reading command's file is a variable or a command substitution, such as `cat "$FILE"` or `cat $(find . -name '*.key')`, the hook cannot tell what it reads and refuses it.
When `xargs` hands files to a reader, the hook refuses the command if any word of it is a secret file.

## Secret write

The hook refuses a write to a file that the secret read hook counts as secret, the places in your `secret-paths` list included.
These files are seldom in git, so an overwrite cannot be undone.

| Where | What it looks at |
|---|---|
| A shell command | The files after `>`, `>>`, `>\|`, `&>`, and `>&`, the files `tee` writes, the last file of `cp`, `mv`, `install`, `ln`, `rsync`, and `scp`, the files of `sed -i` and `perl -i`, the files of `truncate`, and `of=` of `dd` |
| The Write, Edit, and MultiEdit tools | `file_path` |
| The NotebookEdit tool | `notebook_path` |
| Codex's `apply_patch` | The files after `*** Add File:`, `*** Update File:`, `*** Delete File:`, and `*** Move to:` in the patch |

`2>&1` and the other forms that point a stream at another stream are not files.
A write whose file comes from a variable or a command substitution, such as `echo x > "$OUT"`, is let through, since such a file is far more often a temporary one than a secret one.

## 1Password

The hook reads every `op` command of the 1Password CLI, also after `&&`, `;`, and pipes, inside `bash -c` and `eval`, and inside `$(...)` and backquotes.
It passes only the commands that print no value stored in 1Password and delete nothing.

| Passes | Why |
|---|---|
| `op whoami`, `op account list`, `op vault list`, `op item list`, `op document list` | They print names and ids, not stored values |
| `op document create`, `op document edit` | They store a file, such as a `.env` file, without printing it |
| `op --version`, `op help`, and `op` alone | They print the CLI's own text |

Every other `op` command is refused, because values come out through many subcommands and flags: `op read`, `op item get` (with `--format json`, `--otp`, or `--share-link` as well as `--reveal`), `op document get`, `op run`, `op inject`, and `op signin`, which prints a session token.
`op item create` and `op item edit` are refused too, since a value written on their command line stays in the conversation, and the delete commands are refused because they remove items from your vault.
The global options `--account`, `--config`, `--encoding`, `--format`, and `--session` are skipped with their values before the subcommand is read.
A refused command is not shown with a leading `!`, since a value printed by your own `!` command would reach the conversation too; run it in a terminal outside the agent.

## Outbound

The hook looks at commands that send text or record it: `gh issue`, `gh pr`, `gh release`, and `gh gist` commands that create, comment, edit, review, or close, every `gh api` command, and `git commit`.
It checks, for key-shaped values:

| Where | What it reads |
|---|---|
| The command line | The whole command, since it goes out with the text |
| Body files | The files after `--body-file`, `-F`, and `--notes-file`, `-F field=@file` and `--input` of `gh api`, and `git commit -F` |
| A commit | The staged change, the working change with `-a` or paths, and the files that a `git add` earlier in the same command names |

| Key shapes | |
|---|---|
| Tokens with a fixed prefix | GitHub, npm, Anthropic, AWS, GitLab, Google, Slack, Stripe, PyPI, Hugging Face, DigitalOcean, Shopify, Linear, Doppler, SendGrid, and OpenAI |
| Other forms | A private key block, a password in an `Authorization` header, and a password in a URL |

The shapes with a fixed prefix follow the default rules of gitleaks (MIT).
The refusal names the kind of key, the file, and the line, and never the value.
When the text cannot be read, as with `--body "$(cat file)"`, `--body -`, a body file named by a variable, or a commit message built from another command, the hook refuses and shows the `--body-file <path>` or `git commit -F <path>` form.
A message built from a here-document written in the command is read, since its text is in the command.

## Git

| Refused | Why |
|---|---|
| `git push` with `--force`, `-f`, `--force-with-lease`, `--force-if-includes`, or a `+` refspec | It overwrites the remote branch's history |
| `--no-verify` on any git command, and `git commit -n` | It skips the repository's checks |
| `git reset --hard` | It throws away uncommitted work |
| `git clean` with `-f` and without `-n` | It deletes untracked files |
| `git checkout` and `git switch` with `--`, `.`, `-f`, `--force`, or `--discard-changes` | It throws away uncommitted changes |
| `git restore` without `--staged`, or with `--worktree` | It throws away uncommitted changes |

## Delete

| Refused | Examples |
|---|---|
| `rm -r` or `mv` of the root, the home folder, the current folder, `..`, `*`, or a top-level system folder such as `/usr` or `/Users` | `rm -rf /`, `rm -rf ~`, `rm -rf .` |
| `find` with `-delete` or `-exec rm` that starts at one of those places; starting at the current folder is allowed with `-name`, `-path`, or `-regex` | `find / -delete` |
| `rm`, `mv`, `rmdir`, `unlink`, or `find -delete` of a place in your `protected-paths` list, or inside one | `rm ~/work/keep/a.txt` |
| `chmod`, `chown`, or `chgrp` with `-R` or `--recursive` on one of those places or a place in your `protected-paths` list, since a whole tree without permissions locks you out like a delete. The first word is the mode or the owner, and a mode such as `-w` is read as the mode | `chmod -R 000 ~`, `chown -R nobody ~` |

## When a hook cannot judge

A hook that cannot read the event, or fails while judging, refuses the call and says so, rather than letting it through unseen.
Without Python 3, each hook refuses every call and says to install Python 3 or turn the hook off.
Each hook turns off with its own variable set to `off`, as the table at the top lists.

## Limits

- The hooks see only the command text the agent sends. A script file the command runs is not read, so `bash cleanup.sh` is not checked inside
- Key shapes without a fixed prefix, such as a random password, are not found
- A command built at run time, for example by `printf` piped into `sh`, is not read
- A write whose file comes from a variable is not refused, and a write by a program's own code, such as `python3 -c "open('.env', 'w')"`, is not read
