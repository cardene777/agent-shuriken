---
name: secure-dotfile
description: Finds API keys, tokens, and passwords written straight into shell startup files (~/.zshrc, ~/.bashrc, fish config, .envrc, direnv env.d files, and the files they source) and into files tools read on their own (~/.npmrc, ~/.aws/credentials, ~/.netrc, and the current folder's .env files), and moves the ones the user picks into the macOS Keychain, the Linux secret service through secret-tool, pass, or 1Password through op, so the shell reads them from there at startup. The agent never sees any part of a value. Use when a secret is written into a dotfile, or when the user wants to move keys out of their shell configuration.
---

# Secure dotfile

This skill finds secrets written as literal values in shell startup files, such as `export OPENAI_API_KEY="sk-..."` in `~/.zshrc`, and moves the ones the user picks into the macOS Keychain, or on Linux into the secret service (GNOME Keyring, KWallet, or KeePassXC with its secret service turned on) through `secret-tool`.
A user who keeps secrets in `pass` or 1Password can move them there instead, on any system.
Each moved line then reads the value from there when the shell starts, so programs see the same environment variable as before.
It also looks in files that tools read on their own: npm tokens in `~/.npmrc` and AWS keys in `~/.aws/credentials` can be moved, and passwords in `~/.netrc` and keys in the current folder's `.env` and `.env.*` files are listed with the reason they cannot.

Talk to the user in the language they write in.
The commands and their output are the same in every language.

All commands live in `scripts/` next to this `SKILL.md`.
Below, `S` stands for the absolute path of that folder.
When running a command, put `S=<folder that contains this SKILL.md>/scripts` at the start of the same shell command.

This skill works in Claude Code, Codex, and other agents that read `SKILL.md`, such as GitHub Copilot CLI and Gemini CLI.
The commands read files in the home folder and use the Keychain, the secret service, `pass`, or `op`, all outside the project folder, so request approval for them when a sandbox blocks them, as Codex can.

## Keep every value away from the agent

The commands read, store, and check the values inside their own process.
They print only the variable name, the file and line, the kind of secret, and the length.
The rest of this skill relies on the agent never seeing a value, so follow these rules for the whole session.

- Never open, print, or search the startup files or the files they source with any tool (file readers, `cat`, `grep`, editors). Use only the commands below
- Never run `security find-generic-password` with `-w`, `secret-tool lookup`, `pass show`, `op read`, or `op item get` with `--reveal`, since they print the value
- Never ask the user to paste a value into the chat. If they paste one anyway, tell them it is now in the conversation and recommend rotating that key (section 4)

## 1. Scan

```bash
python3 "$S/secure_dotfile.py" scan
```

It reads these files, when they exist, and every file they load with a `source FILE` or `. FILE` line whose path is fixed.

| Shell or tool | Files |
|---|---|
| zsh | `~/.zshenv`, `~/.zprofile`, `~/.zshrc`, `~/.zlogin`, and the same files in `$ZDOTDIR` |
| bash | `~/.bash_profile`, `~/.bash_login`, `~/.profile`, `~/.bashrc` |
| fish | `~/.config/fish/config.fish` and `~/.config/fish/conf.d/*.fish` |
| direnv | `~/.envrc` and `~/.config/*/env.d/*` |
| npm | `~/.npmrc`: lines such as `//registry.npmjs.org/:_authToken=VALUE` |
| AWS | `~/.aws/credentials`: the `aws_secret_access_key` of each profile |
| netrc | `~/.netrc`: each `password` |
| The folder the command runs in | `.env` and every `.env.*` file there, not in subfolders |

To scan another file the user names, add `--file <path>` once per file; it is read as a shell file.
Run the scan in the project folder the user works in, so its `.env` files are included.

Above the items, the output says where the move would store the values, such as `Moves into the secret service`, and names any other store that can be used here, such as `Also available: pass (add --store pass), 1Password (add --store 1password)`.
1Password is listed when the `op` command exists; the scan does not run `op` unless `--store 1password` is given.

A line is listed when it sets an exported variable to a literal value (`export NAME=value`, or `set -x NAME value` in fish) and either the name ends in a word such as `_TOKEN`, `_API_KEY`, `_SECRET`, or `_PASSWORD`, or the value has the shape of a known key (GitHub, OpenAI, Anthropic, Slack, AWS, Google, Stripe, and others).
Values read at run time (`$(...)`, `$VAR`), placeholders such as `REPLACE_ME`, values of one repeated character, and paths are not listed.
Values shorter than 8 characters are listed only under a password name: one ending in `PASSWORD` or `PASSWD`, also without an underscore as in `PGPASSWORD`, or in `_PASS`, `_PWD`, or `_PIN`, as in `MYSQL_PWD`. Their kind is `short password`.

Each listed item has these fields.

| Field | Meaning |
|---|---|
| Name, file, and line | Where the secret is written |
| Kind and length | What the value looks like, and how many characters it has |
| In git history | `yes` when the value is in the git history of that file, which means it may already be on a remote. `no`, `not tracked by git`, or `not in a git repository` otherwise |
| `item` | The text to pass to the move command for this item |
| `becomes` | The line that will replace the current one. For an AWS profile it replaces both key lines |
| `adds` | For an npm token, the export line added at the end of the user's shell startup file, and that file |
| `cannot move` | Why the command will not move this item |

Files that tools read on their own move like this, because those tools do not run a shell.

| File | Move |
|---|---|
| `~/.npmrc` | The token is stored as `NPM_TOKEN`, or for another registry as a name such as `NPM_TOKEN_NPM_PKG_GITHUB_COM`. The line becomes `${NPM_TOKEN}`, which npm fills in from the environment, and the startup file of the shell in `$SHELL` gets an export line that reads the store. Skipped when a startup file already sets that variable |
| `~/.aws/credentials` | A profile's two keys are stored as `AWS_ACCESS_KEY_ID_PROFILE` and `AWS_SECRET_ACCESS_KEY_PROFILE`, and the two lines become one `credential_process` line that prints them from the store. A profile with `aws_session_token` is not moved |
| `~/.netrc` | Never moved: curl and git read it as written. Suggest git's credential helper (osxkeychain on macOS, libsecret on Linux) for git passwords |
| `.env` and `.env.*` | Never moved: `node --env-file` keeps `${VAR}` as written while python-dotenv expands it. Point out the ones in git history, and suggest keeping the file out of git |

When a file is generated by `chezmoi`, the command lists its chezmoi source file too, and only the source can be moved, because `chezmoi apply` would bring the old line back otherwise.

If nothing is found, tell the user which files were scanned and stop.

## 2. Let the user pick

Show the items to the user as a table with the number, name, file and line, kind, whether the value is in git history, and, for items that cannot be moved, the reason.
Recommend moving every item that can be moved, and say first which values are in git history, since those keys should also be rotated.

Ask which items to move.
In Claude Code, use AskUserQuestion with multiple selection when four or fewer items can be moved; with more, ask the user to reply with the numbers or "all".
In other agents, ask in the chat.
The agent never picks items on its own.

When the scan names another store with `Also available`, such as `pass (add --store pass)`, also ask which store to move into, in the same way.
Recommend the store the scan says it moves into, unless the user says they keep their secrets in the other one.
When the user picks `pass`, add `--store pass` to the move command.
When the user picks 1Password, add `--store 1password` to the move command.
Commands with `--store 1password` run `op`, which may ask the user to approve it in the 1Password app, and they store items in the vault named Private, Personal, or Employee that `op` stores new items in.
To show the user the exact lines with that vault's name before moving, run the scan again with `--store 1password`.

## 3. Move only the picks

Pass the `item` of each picked item.

```bash
python3 "$S/secure_dotfile.py" move --item '<item>' --item '<item>'
python3 "$S/secure_dotfile.py" move --store pass --item '<item>' --item '<item>'        # when the user picked pass
python3 "$S/secure_dotfile.py" move --store 1password --item '<item>' --item '<item>'   # when the user picked 1Password
```

For each item, the command does these steps in order.

1. Reads the line again and skips the item with a reason if it no longer sets that variable to a literal value
2. Skips the item if the store already holds a different value under the same name, so nothing is overwritten. When it already holds the same value, the item is moved without storing it again
3. Stores the value under the variable's name, passing it on standard input: in the login keychain through `security` on macOS and in the secret service through `secret-tool store` on Linux (service `NAME`, account `$USER`), as the entry `NAME` through `pass insert` with `--store pass`, or as a Login item titled `NAME` through `op item create` with `--store 1password`. Then it reads the value back and compares. In 1Password, it skips the item when two or more items in the vault have that title
4. Replaces only the value on that line with `"$(security find-generic-password -a "$USER" -s NAME -w 2>/dev/null)"` on macOS, `"$(secret-tool lookup service NAME account "$USER" 2>/dev/null)"` on Linux, `"$(pass show NAME 2>/dev/null)"` with `--store pass`, or `"$(op read 'op://VAULT/NAME/password' 2>/dev/null)"` with `--store 1password` (a command substitution in fish), keeping the rest of the line
5. Writes the file in one step, keeping its permissions and any symlink to it, and runs the shell's syntax check (`zsh -n`, `bash -n`, or `fish --no-execute`). If the edited file fails a check that the original passed, the file is left as it was

Files that tools read on their own go through the same checks and storing, with these differences.

- `~/.npmrc`: after storing the token, the command first adds the `adds` line to the end of the shell startup file and checks that file's syntax, then changes the `.npmrc` line to `${NPM_TOKEN}`. If adding the line fails, `.npmrc` is left as it was and the message says the value is already stored
- `~/.aws/credentials`: the command stores both keys, then replaces the `aws_secret_access_key` line with the `credential_process` line and removes the `aws_access_key_id` line. The AWS CLI and SDKs run that line themselves, so it works outside the shell too

macOS may ask for the login password to unlock the keychain, on Linux the keyring may ask to be unlocked, `pass` may ask for the GPG key's passphrase, and the 1Password app may ask to approve `op`; the user answers in that dialog, never in the chat.
To show what would change without storing or editing anything, add `--dry-run`.

## 4. Report the result

From the command output, tell the user these things.

- Which items were moved, and which were skipped and why
- That a new terminal, or `exec $SHELL -l`, loads the moved values. A moved npm token reaches npm only from a shell that has loaded the export line; a moved AWS profile works right away
- That the move takes the value out of the file, not out of the shell's environment: the shell still exports it, so every program it starts receives it, and tools that list a process's environment can show it. A key with wide access is safer read only for the one command that needs it, by putting the same `security find-generic-password`, `secret-tool lookup`, `pass show`, or `op read` call in front of that command instead of exporting it from the startup file
- For a key the team shares: it belongs in a vault the team shares, such as a shared 1Password vault read with `op`, not in one person's Keychain or personal vault, so that rotating it reaches everyone who uses it
- When a chezmoi source file was moved, that `chezmoi apply` updates the generated file; run it if the user agrees
- For each `short password`: moving it keeps it out of the file but not from being guessed. Suggest the user sets a longer password with the service, then stores it with the command below
- For each value that is in git history, or was ever shared, pasted, or shown on screen: rotate the key. The user creates a new key with the service, revokes the old one, and stores the new one by running this in their own terminal. It asks for the value without showing it

```bash
security add-generic-password -a "$USER" -s <NAME> -U -w          # macOS
secret-tool store --label=<NAME> service <NAME> account "$USER"   # Linux
pass insert -f <NAME>                                              # pass
# 1Password: edit the item in the 1Password app
```

For a moved npm token or AWS profile, `<NAME>` is the name the move stored it under, such as `NPM_TOKEN` or `AWS_SECRET_ACCESS_KEY_DEFAULT`, so the file keeps reading the new value.
For a `.netrc` password or a `.env` value, the user changes the value in that file.
Never run that command for the user, because the new value would pass through the agent.
For items that could not be moved, explain the reason and that the user can move them by hand in the same way.

## When something fails

| What happens | What to do |
|---|---|
| Exit code 2 | An item is not in the form `PATH:LINE:NAME`, or a `--file` does not exist. Fix the arguments and run again |
| Exit code 3 | Moving needs macOS and its `security` command, Linux and `secret-tool`, with `--store pass` the `pass` command and a password store set up with `pass init`, or with `--store 1password` the `op` command, a sign-in, and one vault named Private, Personal, or Employee; the message names what is missing. Tell the user that Debian and Ubuntu ship `secret-tool` in the `libsecret-tools` package, and let them install it. The scan still works without it |
| "could not reach 1Password" or "could not read 1Password" | `op` is not signed in, or the 1Password app did not approve it. Ask the user to sign in, or to turn on the 1Password app integration and approve the request, and run the move again |
| "could not tell which vault op stores new items in" | None, or more than one, of the user's vaults is named Private, Personal, or Employee. Tell the user, and let them move the values by hand into the vault they choose |
| "more than one item in the 1Password vault" | Two or more items in the vault have that title. The user renames or removes the extra ones in the 1Password app, then the move is run again |
| "a different value is already stored" | Another item in the store uses that name. The user renames or removes it in Keychain Access on macOS, in Passwords and Keys (Seahorse), KWallet Manager, or KeePassXC on Linux, with `pass mv` or `pass rm` in `pass`, or in the 1Password app, then the move is run again |
| "could not read the keychain" or "did not answer" | The keychain is locked or waiting for a password. Ask the user to unlock it and run the move again |
| "could not reach the secret service" | No D-Bus session or keyring is running, or the keyring is locked. Ask the user to unlock the keyring in their desktop session and run the move again. Over SSH the secret service is often out of reach, so the move has to run in a desktop session |
| "could not read pass" or "could not be read back" | The GPG key is locked or missing, and no passphrase prompt could be shown. Ask the user to unlock the key in their own terminal, for example by opening any entry with `pass`, and run the move again. A value already stored there is the same one, so the next move finds it and edits the line |
| "line N no longer sets NAME" | The file changed after the scan. Scan again and pass the new item |
| "a startup file already sets NAME" | An npm token would go under a variable the user already sets. Tell the user, and let them move the token by hand under another name |
| "could not tell your shell from $SHELL" | There is no startup file to add the npm export line to. The user moves the token by hand |
| "the profile also has a session token" | The AWS profile holds temporary keys. The user renews them with their sign-in tool, such as `aws sso login`, instead of storing them |

## Not covered

- Moving `~/.netrc` passwords and `.env` values; they are listed only. `.env` files in subfolders, or outside the folder the command runs in, are not scanned
- Other files that tools read on their own, such as SSH keys, `~/.docker/config.json`, and `~/.pypirc`
- Assignments without `export` (or fish `set -x`), and values that span several lines
- Copies of the old value in shell history, backups, Time Machine, and other machines. Rotating the key makes those copies useless
- The environment the shell passes to the programs it starts. A moved value is still exported to every one of them, and tools that list a process's environment can show it
- Stores other than the Keychain, the secret service, `pass`, and 1Password. KWallet is reached through the secret service, which KWallet from KDE Frameworks 6 serves unless it is turned off. Bitwarden is not a store: its `bw` command reads only when the session key `BW_SESSION` is in the environment, so a new shell would get an empty variable
