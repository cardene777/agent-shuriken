# How Agent Guards works

English · [日本語](how-it-works.ja.md)

Claude Code and Codex start each hook before a shell command, a file read, or a file edit, and pass the call as JSON on standard input.
A hook prints a deny decision with its reason when it refuses the call, and prints nothing otherwise.
It never prints an approval, so a call it does not refuse still goes through the agent's own permission rules.
All six hooks share one Python file, `hooks/lib/agent_guards.py`, and each `hooks/<name>.sh` starts it with the hook's name.
Three hooks run more than one check in the same process, so a check starts no process of its own.
Each check turns off with its own variable, and a hook whose checks are all off exits at once.

| Hook | Check | Runs before | Turned off with |
|---|---|---|---|
| `secret-read.sh` | Secret read | A shell command and the Read tool | `AGENT_GUARDS_SECRET_READ=off` |
| `secret-write.sh` | Secret write | A shell command, the Write, Edit, MultiEdit, and NotebookEdit tools, and Codex's `apply_patch` | `AGENT_GUARDS_SECRET_WRITE=off` |
| `secret-write.sh` | Hard links | The same calls as secret write | `AGENT_GUARDS_HARD_LINKS=off` |
| `secret-write.sh` | Startup keys | The same calls as secret write | `AGENT_GUARDS_STARTUP_KEYS=off` |
| `onepassword.sh` | 1Password | A shell command | `AGENT_GUARDS_ONEPASSWORD=off` |
| `outbound.sh` | Outbound | A shell command | `AGENT_GUARDS_OUTBOUND=off` |
| `outbound.sh` | Chain | A shell command | `AGENT_GUARDS_CHAIN=off` |
| `outbound.sh` | Other repositories | A shell command | `AGENT_GUARDS_OTHER_REPOS=off` |
| `git.sh` | Git | A shell command | `AGENT_GUARDS_GIT=off` |
| `delete.sh` | Delete | A shell command | `AGENT_GUARDS_DELETE=off` |
| `delete.sh` | System | A shell command | `AGENT_GUARDS_SYSTEM=off` |

## How a command is read

The hooks read the command the way a shell splits it.
They cut the command at `;`, `&&`, `||`, `|`, `&`, parentheses, and line breaks, and read each part on its own.
They skip leading variable assignments and the words `sudo`, `doas`, `env`, `command`, `builtin`, `nohup`, `nice`, `time`, `timeout`, and `exec` with their options, so `sudo rm -rf /` is read as `rm`.
An option that takes a value is skipped with its value, so `sudo -u root rm -rf /`, `nice -n 10 rm -rf /`, and `env -C /tmp rm -rf ~` are read as `rm` too.
The string after `env -S` is read as the words that follow, as env splits it.
They read the text after `bash -c`, `sh -c`, `zsh -c`, and `eval`, the command `xargs` runs, each command after `find -exec`, `-execdir`, `-ok`, and `-okdir`, and the text `watch` runs, as other commands, up to three levels deep.
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
When `find -exec` hands the found files to a reader through `{}`, the hook refuses it if any word of the `find` command is a secret file, as in `find . -name .env -exec cat {} \;`.

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

## Hard links

A file can have more than one name (a hard link), made with `ln`.
A write through one name changes the file under every name, so a harmless name such as `notes.txt` can overwrite `.env`, and the name alone cannot show what the file holds.
The check refuses a write to a regular file whose link count is two or more.

| Where | What it looks at |
|---|---|
| A shell command | The files after `>`, `>>`, and the other redirects, and the files `tee`, `cp`, `scp`, `truncate`, and `of=` of `dd` write, since they write through the name |
| The Write, Edit, MultiEdit, and NotebookEdit tools | `file_path` and `notebook_path` |
| Codex's `apply_patch` | The files the patch adds or changes |

`mv`, `ln`, `install`, `rsync`, `sed -i`, and `perl -i` replace the name with a new file and leave the other names as they were, so they pass.
A file that does not exist yet and a file whose link count cannot be read pass, and a symbolic link is judged by the file it points to.
The refusal says to copy the file with `cp` to a file of its own, which has one name, and write that.
Package managers such as pnpm on Linux link the files of `node_modules` to a shared store, so an edit there is refused too.

## Startup keys

The check reads what a call writes into a shell startup file and refuses a key.

| Startup files | Examples |
|---|---|
| zsh and bash startup files by name, in any folder | `.zshrc`, `.zprofile`, `.zshenv`, `.zlogin`, `.bashrc`, `.bash_profile`, `.bash_login`, and `.profile`, in the home folder or a dotfiles folder |
| The fish config | `config.fish` in a folder named `fish` |
| The same files under chezmoi source names | `dot_zshrc`, `private_dot_zshrc.tmpl`, and `dot_config/fish/config.fish` |

| Where | What it reads |
|---|---|
| The Write tool | `content` |
| The Edit tool and each edit of MultiEdit | `new_string` |
| Codex's `apply_patch` | The lines the patch adds to the file |
| A shell command that writes a startup file | The whole command, as in `echo 'export FOO_TOKEN=abc' >> ~/.zshrc` |

| Refused | Passes |
|---|---|
| `export NAME=value` of zsh and bash, and `set -x NAME value` or `set -gx NAME value` of fish, when the name ends in `_KEY`, `_TOKEN`, `_SECRET`, or `_PASSWORD` and the value is written as it is | A value read at startup, such as `"$(security find-generic-password -s NAME -w)"`, `$OTHER`, or `${OTHER}`, an empty value, a placeholder such as `REPLACE_ME`, `CHANGEME`, `TODO`, or `xxx`, and a commented line |
| A key shape the outbound check knows, such as a GitHub or AWS key, in any line | Lines without one |

The refusal names the file and the variable or the kind of key, never the value.
It says to keep the value in a secret store, such as the macOS keychain or 1Password, and read it at startup; the secure-dotfile plugin of this marketplace moves such values.

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

## Chain

The check refuses a command that sends a signed transaction to a chain that is not on this machine, since a sent transaction cannot be taken back.

| Sends | Example |
|---|---|
| `cast send` and `cast publish`, also as `cast s` and `cast p` | `cast send 0xabc "f()" --rpc-url https://rpc.example.org` |
| `eth_sendRawTransaction` and `eth_sendTransaction` through `cast rpc` | `cast rpc eth_sendRawTransaction 0x02f8 --rpc-url https://rpc.example.org` |
| `transfer`, `approve`, `mint`, and `burn` of `cast erc20-token` | `cast erc20-token transfer 0xabc 0xdef 1 --rpc-url https://rpc.example.org` |
| `forge script` with `--broadcast`, and `forge create` | `forge script script/Deploy.s.sol --broadcast --rpc-url https://rpc.example.org` |
| `hardhat ignition deploy`, also through `npx`, `pnpm`, `yarn`, `bunx`, and `npm exec` | `npx hardhat ignition deploy ignition/modules/A.ts --network sepolia` |

The target comes from `--rpc-url` and `-r` of cast, from `--rpc-url`, `--fork-url`, and `-f` of forge, and from an `ETH_RPC_URL=` written before the command.
It passes when its URL uses `http`, `https`, `ws`, or `wss`, holds no user name or password, and its host is `127.0.0.1`, `localhost`, or `::1`.
A command without a target, a target held in a variable, a name from `foundry.toml` such as `--rpc-url sepolia`, and `cast` with `--flashbots` are refused, because the check cannot tell that they stay on this machine.
A Hardhat deploy passes on the `hardhat` and `localhost` networks and without `--network`, and a network named by `--network` or `HARDHAT_NETWORK=` is refused otherwise.
Reads and signing without sending pass, such as `cast call`, `cast mktx`, `cast wallet sign`, and `forge script` without `--broadcast`.
The refusal names the host and never the whole URL, since the path of an RPC URL can hold an API key, and it ends with the command after a leading `!`.

## Other repositories

The check refuses sends to repositories of owners that are not yours, since what is sent there is public at once and cannot be taken back.
It reads the GitHub users and organizations that are yours from `~/.config/agent-guards/own-owners`, one per line, and compares them without case.
Without the file, or with no owner in it, the check refuses nothing, since it cannot tell whose repositories are yours.

| Send | Where the owner comes from |
|---|---|
| `gh issue create`, `gh pr create`, `gh issue comment`, `gh pr comment`, and `gh pr review` | `-R` or `--repo`, `GH_REPO`, or an issue or pull request URL given as the argument |
| `gh issue edit` and `gh pr edit` that change the title, the body, or the attachments, and `gh issue close` and `gh pr close` with a comment | The same |
| `gh api` with POST, PATCH, PUT, or DELETE, or with fields and no method, to `repos/<owner>/<name>/...` | The endpoint |
| `git push` | The URL of the remote it pushes to, which is the remote it names, `--repo`, or the push remote of the branch, and `origin` otherwise |

| Refused whatever the owner | Why |
|---|---|
| A GraphQL mutation through `gh api graphql`, and a query the check cannot read | It names its target by an ID |
| A repository, an endpoint, or a remote held in a variable | The check cannot tell whose it is |

A `gh` send without `-R` goes to a repository that gh picks from the remotes of the clone, which is the upstream in a fork.
The check refuses it when the remote chosen with `gh repo set-default`, or any remote when none was chosen, names an owner outside the list, and says to name the repository with `-R`.
Reads, label and assignee changes, and a close without a comment pass.
To read the remotes, it runs `git config`, `git symbolic-ref`, and `git remote get-url` in the clone.
The refusal ends with the command after a leading `!`.

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

## System

The check refuses commands that change the whole machine, which are hard to undo.

| Refused | Why |
|---|---|
| `mount` and `umount` | They change what is mounted on the machine |
| `chroot` | It runs a command inside another root folder |
| `pfctl` | It changes the packet filter, the firewall of macOS |
| `mkfs` and `mkfs.*` | They format a disk, which erases what it holds |
| `osascript` with `do shell script ... with administrator privileges` | It runs a shell script as an administrator, like `sudo` |

They are read behind `sudo`, `env`, an absolute path such as `/sbin/mount`, and `bash -c`, as the section on reading a command says.
A name that is only an argument, such as `grep mount notes.txt`, and `osascript` without administrator privileges pass.
The refusal ends with the command after a leading `!`.

## When a hook cannot judge

A hook that cannot read the event, or fails while judging, refuses the call and says so, rather than letting it through unseen.
Without Python 3, each hook refuses every call and says to install Python 3 or turn its checks off.
Each check turns off with its own variable set to `off`, as the table at the top lists, and a hook whose checks are all off exits at once.

## Limits

- The hooks see only the command text the agent sends. A script file the command runs is not read, so `bash cleanup.sh` is not checked inside
- Key shapes without a fixed prefix, such as a random password, are not found
- A command built at run time, for example by `printf` piped into `sh`, is not read
- A write whose file comes from a variable is not refused, and a write by a program's own code, such as `python3 -c "open('.env', 'w')"`, is not read
- A startup file written by copying another file over it, as with `cp`, is not read for keys, since only the command text is read
- A deploy run by `hardhat run` or a script, and a Hardhat network chosen by `defaultNetwork` in the config, are not read
- A send to GitHub by a program's own code, such as `curl` to the GitHub API, is not read
