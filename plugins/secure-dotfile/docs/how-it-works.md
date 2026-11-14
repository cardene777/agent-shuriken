# How Secure Dotfile works

English · [日本語](how-it-works.ja.md)

This page lists the files the plugin scans, what it treats as a secret, each step of a move, and what it never does.
Everything here is done by `skills/secure-dotfile/scripts/secure_dotfile.py`, which uses only the Python standard library.

## What it scans

| Shell or tool | Files |
|---|---|
| zsh | `~/.zshenv`, `~/.zprofile`, `~/.zshrc`, `~/.zlogin`, and the same files in `$ZDOTDIR` |
| bash | `~/.bash_profile`, `~/.bash_login`, `~/.profile`, `~/.bashrc` |
| fish | `~/.config/fish/config.fish` and `~/.config/fish/conf.d/*.fish` |
| direnv | `~/.envrc` and `~/.config/*/env.d/*` |
| Loaded files | Every file those files load with `source FILE` or `. FILE`, when the path is fixed (`~`, `$HOME`, and `$ZDOTDIR` are expanded), up to five levels deep |
| chezmoi | The chezmoi source file of any scanned file that chezmoi generates |
| Your choice | Any file passed with `--file` |

## What counts as a secret

A line is listed when it sets an exported variable to a literal value, as `export NAME=value` or, in fish, `set -x NAME value`, and one of these holds.

| Rule | Examples |
|---|---|
| The name ends in `_API_KEY`, `_ACCESS_KEY`, `_SECRET_KEY`, `_PRIVATE_KEY`, `_KEY`, `_TOKEN`, `_SECRET`, `_PASSWORD`, `_PASSWD`, `_PASS`, `_PWD`, `_PIN`, or `_PAT`, or in `PASSWORD` or `PASSWD` without an underscore | `GH_TOKEN`, `DB_PASSWORD`, `PGPASSWORD`, `MYSQL_PWD` |
| The value has the shape of a known key | GitHub, GitLab, OpenAI, Anthropic, Slack, AWS access key IDs, Google API keys, npm, Hugging Face, Stripe, SendGrid, DigitalOcean, xAI, Groq, Perplexity |

These lines are not listed.

- Values read when the shell runs: `$(...)`, backquotes, and `$VAR` inside double quotes or without quotes
- Placeholders such as `REPLACE_ME`, `changeme`, `your_api_key`, or a value made of one repeated character
- Paths that start with `/`, `~`, `./`, or `../`
- Values shorter than 8 characters, except under a password name: one ending in `PASSWORD`, `PASSWD`, `_PASS`, `_PWD`, or `_PIN`. Those are listed at any length, and a value shorter than 8 characters has the kind `short password`
- `export NAME= value`, which sets `NAME` to an empty value

## How values stay away from the agent

The agent runs the script and reads its output, and the output never holds any part of a value.
For each secret it prints the name, the file and line, the kind, the length, and whether the value is in git history.
When the script stops on an unexpected error, it prints only the error's type and the script line, because an error message could quote a line of your file.
On macOS the script stores a value by sending the `security` command its instruction on standard input (`security -i`), and on Linux by sending the value itself to `secret-tool store` on standard input, so the value never appears on a command line, where other processes could read it.
It checks the syntax of an edited file by sending the text to the shell on standard input, so no copy of the file is written elsewhere.

## Where values are stored

| System | Store | Command |
|---|---|---|
| macOS | Your default keychain | `security` |
| Linux | Your default collection in the secret service, which GNOME Keyring, or KeePassXC with its secret service turned on, provides over your login session's D-Bus | `secret-tool` from libsecret, in the `libsecret-tools` package on Debian and Ubuntu |

`SECURE_DOTFILE_STORE` picks `keychain` or `secret-service` instead of the system's default, and `SECURE_DOTFILE_KEYCHAIN` names a keychain file to use instead of the default keychain.
Both are meant for tests against a throwaway store.

## How a move works

The agent passes the items you picked, and the script does these steps for each one.

1. Reads the line again, and skips the item if the line no longer sets that variable to a literal value
2. Looks up the variable's name in the store. When a different value is stored there, it skips the item and stores nothing. When the same value is stored, it keeps it. `secret-tool store` replaces an item without asking, so this lookup is what keeps it from overwriting one
3. Stores the value with service `NAME` and account `$USER`, then reads it back and compares. In the secret service the item's label is `NAME (added by secure-dotfile)`
4. Replaces only the value on that line with `"$(security find-generic-password -a "$USER" -s NAME -w 2>/dev/null)"` on macOS, or `"$(secret-tool lookup service NAME account "$USER" 2>/dev/null)"` on Linux, keeping the rest of the line, such as a comment. In fish the command goes inside `( )` instead of `"$( )"`
5. Writes each file in one step, through a temporary file in the same folder that replaces the original. It keeps the file's permissions, and when the path is a symlink, it edits the file the link points to
6. Runs the shell's syntax check on the edited file: `zsh -n` for zsh files, `fish --no-execute` for fish files, and `bash -n` for the rest. If the original passed and the edited file fails, the file is written back as it was

`--dry-run` shows what each item would become without storing or editing anything.

## When an item is skipped

| Reason | Why |
|---|---|
| The line no longer sets the variable to a literal value | The file changed after the scan. Scan again |
| A different value is already stored under the same name | Storing would overwrite another secret |
| The value contains a backslash | A backslash means different things in different shells, so the stored value might not match what the shell used |
| The value contains `*`, `?`, `[`, or `{` | The shell may expand these characters |
| The value contains characters outside printable ASCII | The `security` command reads such values back as hex, so the variable would change. Such values are skipped on Linux too |
| The file is generated by chezmoi | `chezmoi apply` would bring the old line back. The source file is moved instead |
| The Keychain did not answer | It is locked or waiting for a password. Unlock it and run the move again |
| The secret service could not be reached | No D-Bus session or keyring is running, or the keyring is locked. The reason ends with `secret-tool`'s own message. Unlock or start the keyring and run the move again |

## chezmoi

When `chezmoi` is installed and a scanned file with secrets is generated by it, the scan also reads that file's chezmoi source file.
The generated file is listed but cannot be moved, and the source file can.
After a move, `chezmoi apply` writes the new line into the generated file.
Template source files (`.tmpl`) are edited the same way, without the syntax check.

## Git history

For each file with secrets inside a git repository, the script reads `git log --all -p` for that file and looks for each value inside its own process, reading at most 64 MB.
`yes` means the value was committed to that file at some point, so it may already be on a remote; rotate that key.
`no` means the value is not in that file's history, but it may still be in other files, in backups, or in the shell history.

## What it never does

- Print, log, or send any part of a value
- Overwrite a value already stored in the Keychain or the secret service
- Edit any line other than the lines of the values it moved
- Write a backup of a file, since a backup would hold the secret
- Rotate keys, or ask for the new value. You run `security add-generic-password -a "$USER" -s NAME -U -w` on macOS, or `secret-tool store --label=NAME service NAME account "$USER"` on Linux, in your own terminal, which asks for the value without showing it
- Connect to the network, or keep files of its own. On Linux, `secret-tool` talks to the secret service only over your login session's D-Bus

## Limits

- Moving needs macOS with its `security` command, or Linux with `secret-tool`. Elsewhere, or without that command, the scan works and the move stops with exit code 3 and names what is missing
- A moved line reads the value when the shell starts, so the store has to be reachable then. On Linux, a shell started over SSH or before the keyring is unlocked can get an empty variable, because `secret-tool` prints nothing when it cannot reach an unlocked keyring
- Stores other than the Keychain and the secret service, such as `pass` or KWallet without its secret service, are not supported
- Files that tools read on their own, such as project `.env` files, `~/.npmrc`, `~/.netrc`, `~/.aws/credentials`, and SSH keys, are not scanned
- Assignments without `export` (or fish `set -x`), and values that span several lines, are not found
- Copies of an old value in shell history, backups, or Time Machine stay where they are. Rotating the key makes them useless
- A moved value is still exported to every program the shell starts, and tools that list a process's environment can show it. A key with wide access is safer read only for the command that needs it
- A key a team shares belongs in the team's password manager, such as 1Password read with `op`, not in one person's Keychain
