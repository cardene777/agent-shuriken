---
name: secure-dotfile
description: Finds API keys and tokens written in plain text in shell startup files and in tool files such as ~/.npmrc, and moves the ones the user picks into the macOS Keychain, the Linux secret service, pass, or 1Password without the agent seeing any value. Use when a secret is written into a dotfile, or the user wants keys out of their shell config.
---

# Secure dotfile

This skill finds secrets written as literal values in shell startup files, such as `export OPENAI_API_KEY="sk-..."` in `~/.zshrc`, and in files that tools read on their own: `~/.npmrc`, `~/.aws/credentials`, `~/.netrc`, and the `.env` and `.env.*` files of the current folder.
It moves the ones the user picks into a store, and each moved line reads the value from there, so programs see the same variable as before.

Talk to the user in the language they write in.
The commands and their output are the same in every language.

All commands live in `scripts/` next to this `SKILL.md`.
When running one, put `S=<folder that contains this SKILL.md>/scripts` at the start of the same shell command.
They read files in the home folder and use the stores below, outside the project folder, so request approval when a sandbox blocks them, as Codex can.
This skill works in Claude Code, Codex, and other agents that read `SKILL.md`, such as GitHub Copilot CLI and Gemini CLI.

## Keep every value away from the agent

The commands read, store, and check values inside their own process, and print only names, files and lines, kinds, and lengths.
Everything below relies on the agent never seeing a value, so follow these rules for the whole session.

- Never open, print, or search the scanned files with any tool (file readers, `cat`, `grep`, editors, `git log -p`). Use only the commands below
- Never run a command that prints a stored value: `security find-generic-password -w`, `secret-tool lookup`, `pass show`, `op read`, or `op item get --reveal`
- When the user asks to see a value, tell them to open the file or the store themselves, and never print it
- Never ask the user to paste a value into the chat. If they paste one anyway, keep it out of every command, tell them it is now in the conversation and should be changed, and give them the command in section 4 to store the new one in their own terminal

## 1. Scan

```bash
python3 "$S/secure_dotfile.py" scan
```

Run it in the project folder the user works in, so that folder's `.env` files are included.
For another file the user names, add `--file <path>` once per file; it is read as a shell file.
Each item shows the name, file and line, kind, length, whether the value is in git history, the `item` to pass to the move, the line it `becomes`, and why it `cannot move` when it cannot.
Above the items, the output says where the move would store values and which other stores can be used here.
If nothing is found, tell the user which files were scanned and stop.

## 2. Let the user pick

Show the items as a table with the number, name, file and line, kind, whether the value is in git history, and the reason for items that cannot be moved.
Recommend moving every item that can be moved, and say first which values are in git history, since those keys must also be replaced.
Ask which items to move: in Claude Code with AskUserQuestion and multiple selection when four or fewer can be moved, otherwise in the chat, by numbers or "all".
Never pick items on your own.

When the scan names other stores, also ask which store to use, recommending the one the scan moves into unless the user keeps their secrets in another.

| Store | Where it is used | Add to the move |
|---|---|---|
| Keychain | macOS, by default | nothing |
| Secret service | Linux, by default: GNOME Keyring, KWallet, or KeePassXC, through `secret-tool` | nothing |
| `pass` | Any system with a password store | `--store pass` |
| 1Password | Any system where `op` is signed in; the 1Password app may ask to approve it | `--store 1password` |

To show the exact lines with the 1Password vault's name before moving, scan again with `--store 1password`.

## 3. Move only the picks

```bash
python3 "$S/secure_dotfile.py" move --item '<item>' --item '<item>'                     # default store
python3 "$S/secure_dotfile.py" move --store pass --item '<item>' --item '<item>'        # pass
python3 "$S/secure_dotfile.py" move --store 1password --item '<item>' --item '<item>'   # 1Password
```

For each item, the command reads the line again, stores the value without overwriting a different one, reads it back, rewrites the line, and checks the file's syntax, and it skips the item with a reason rather than risk a wrong change.
The store may ask for a password, a passphrase, or an approval in its own dialog; the user answers there, never in the chat.
To show what would change without storing or editing anything, add `--dry-run`.

## 4. Report the result

From the output, tell the user these things.

- Which items were moved, and which were skipped and why
- That a new terminal, or `exec $SHELL -l`, loads the moved values. A moved npm token reaches npm only from a shell that loaded its export line; a moved AWS profile works at once through `credential_process`
- That the value is out of the file but still exported to every program the shell starts, so a key with wide access is safer read only for the command that needs it
- That a key the team shares belongs in a vault the team shares, such as a shared 1Password vault, so replacing it reaches everyone
- When a chezmoi source file was moved, that `chezmoi apply` updates the generated file; run it if the user agrees
- For each `short password`, such as a 4-character `PGPASSWORD`, that moving it does not make it harder to guess, so a longer one is safer
- For each value that is in git history, or was ever pasted, shared, or shown: replace the key. The user creates a new key with the service, revokes the old one, and stores the new one in their own terminal with the command below, which asks for the value without showing it. Never run it for the user

```bash
security add-generic-password -a "$USER" -s <NAME> -U -w          # Keychain
secret-tool store --label=<NAME> service <NAME> account "$USER"   # secret service
pass insert -f <NAME>                                              # pass
# 1Password: edit the item in the 1Password app
```

`<NAME>` is the name the value is stored under, such as `NPM_TOKEN` or `AWS_SECRET_ACCESS_KEY_DEFAULT`.
For a `.netrc` password or a `.env` value, the user changes the value in that file; the scan says why those files are not moved.

## When something fails

Every error and skip reason in the output says what to do next.
Pass it on to the user, and run the command again only after the user has done it.
Exit code 2 means the arguments were wrong, and exit code 3 means moving cannot work here, while the scan still works.

## Not covered

- Moving `~/.netrc` passwords and `.env` values, which are only listed, and `.env` files outside the current folder
- SSH keys, `~/.docker/config.json`, `~/.pypirc`, assignments without `export` or fish `set -x`, and values over several lines
- Copies of an old value in shell history, backups, and other machines; replacing the key makes them useless
- Stores other than these four. Bitwarden's `bw` reads only with the session key `BW_SESSION` set, so a new shell would get an empty variable
