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
| npm | `~/.npmrc`: lines such as `//registry.npmjs.org/:_authToken=VALUE` |
| AWS | `~/.aws/credentials`: the `aws_secret_access_key` of each profile |
| netrc | `~/.netrc`: each `password` |
| The folder it runs in | `.env` and every `.env.*` file in that folder, not in its subfolders: lines such as `NAME=value`, with or without `export` |

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
On macOS the script stores a value by sending the `security` command its instruction on standard input (`security -i`), on Linux by sending the value itself to `secret-tool store` on standard input, in `pass` by sending it to `pass insert -e` on standard input, and in 1Password by sending an item JSON template that holds it to `op item create -` on standard input, so the value never appears on a command line, where other processes could read it.
It checks the syntax of an edited file by sending the text to the shell on standard input, so no copy of the file is written elsewhere.

## Where values are stored

| System | Store | Command |
|---|---|---|
| macOS | Your default keychain | `security` |
| Linux | Your default collection in the secret service, which GNOME Keyring, KWallet, or KeePassXC with its secret service turned on, provides over your login session's D-Bus | `secret-tool` from libsecret, in the `libsecret-tools` package on Debian and Ubuntu |
| Any system, with `--store pass` | Your password store, `~/.password-store` or the folder in `PASSWORD_STORE_DIR`, with each entry encrypted to your GPG key | `pass`, with GnuPG |
| Any system, with `--store 1password` | The 1Password vault that `op` stores new items in, named Private, Personal, or Employee depending on your account type, as a Login item titled `NAME` | The 1Password CLI `op`, signed in or connected to the 1Password app |

The scan prints where the move would store values, such as `Moves into the secret service`, and names the other stores that can be used here, such as `Also available: pass (add --store pass)`.
`pass` is listed when the `pass` command exists and the password store has been set up with `pass init`.
1Password is listed when the `op` command exists, without running it.
`--store` picks the store for one scan or move.
Only a scan or move that picks `--store 1password` runs `op`, which may ask the 1Password app to approve it. It first runs `op vault list` and takes the vault named Private, Personal, or Employee, because `op` has no command that names the vault it stores new items in. When none or more than one vault has those names, or `op` is not signed in, the scan says why it cannot move, and the move stops with exit code 3 and changes nothing.
KWallet from KDE Frameworks 6 serves the secret service unless that is turned off, so `secret-tool` reaches it. When it is off, turn it on again by removing `apiEnabled=false` from the `[org.freedesktop.secrets]` group in `~/.config/kwalletrc`.
`SECURE_DOTFILE_STORE` picks the store instead of the system's default when `--store` is not given, and `SECURE_DOTFILE_KEYCHAIN` names a keychain file to use instead of the default keychain.
Both are meant for tests against a throwaway store.

## How a move works

The agent passes the items you picked, and the script does these steps for each one.

1. Reads the line again, and skips the item if the line no longer sets that variable to a literal value
2. Looks up the variable's name in the store. When a different value is stored there, it skips the item and stores nothing. When the same value is stored, it keeps it. `secret-tool store` and `pass insert` replace an item without asking, and `op item create` adds a second item of the same name, so this lookup is what keeps them from overwriting or doubling one. In `pass`, an entry whose file does not exist is known to be missing without decrypting anything. In 1Password, it lists the vault's items with `op item list` and compares their titles with the name without regard to case, as secret references do, and skips the item when two or more items have that title
3. Stores the value, then reads it back and compares. The Keychain and the secret service use service `NAME` and account `$USER`, and the secret service labels the item `NAME (added by secure-dotfile)`. `pass` stores the entry `NAME` with `pass insert -e`. 1Password stores a Login item titled `NAME` with `op item create --vault VAULT -`, with the value in its password field and the note `added by secure-dotfile`, and reads it back with `op read -n`
4. Replaces only the value on that line with `"$(security find-generic-password -a "$USER" -s NAME -w 2>/dev/null)"` on macOS, `"$(secret-tool lookup service NAME account "$USER" 2>/dev/null)"` on Linux, `"$(pass show NAME 2>/dev/null)"` in `pass`, or `"$(op read 'op://VAULT/NAME/password' 2>/dev/null)"` in 1Password, keeping the rest of the line, such as a comment. In fish the command goes inside `( )` instead of `"$( )"`
5. Writes each file in one step, through a temporary file in the same folder that replaces the original. It keeps the file's permissions, and when the path is a symlink, it edits the file the link points to
6. Runs the shell's syntax check on the edited file: `zsh -n` for zsh files, `fish --no-execute` for fish files, and `bash -n` for the rest. If the original passed and the edited file fails, the file is written back as it was

`--dry-run` shows what each item would become without storing or editing anything.

## Files that tools read on their own

These tools do not run a shell, so a line cannot read the value with `$( )`. Each file is handled the way its tool allows.

| File | How it moves |
|---|---|
| `~/.npmrc` | npm replaces `${NAME}` in the file with the environment variable when it reads it. The move stores the token as `NPM_TOKEN`, or for another registry as `NPM_TOKEN_` followed by the host in capitals with `_` for other characters, such as `NPM_TOKEN_NPM_PKG_GITHUB_COM`. It adds `export NPM_TOKEN="$(...)"` at the end of your shell's startup file, chosen by `$SHELL`: `~/.zshrc`, `~/.bashrc`, or fish's `config.fish`, and checks that file's syntax. Only after that line is added does it change the `.npmrc` line to `${NPM_TOKEN}`. When a startup file already sets that variable, the token is skipped |
| `~/.aws/credentials` | The AWS CLI runs `credential_process` and reads the keys it prints as JSON. The move stores a profile's two keys as `AWS_ACCESS_KEY_ID_PROFILE` and `AWS_SECRET_ACCESS_KEY_PROFILE`, with the profile name in capitals, and replaces the two lines with `credential_process = sh -c 'a=$(...) && s=$(...) && printf ...'`. When the store cannot be read, the command fails and the AWS CLI says so instead of using empty keys. A profile with `aws_session_token` holds temporary keys, so it is listed but not moved, and so is a profile that already has `credential_process` |
| `~/.netrc` | Listed but not moved. curl and git read it as written and cannot read a value from elsewhere. For git, a credential helper such as osxkeychain or libsecret can keep the password instead |
| `.env` and `.env.*` | Listed but not moved, with whether the value is in git history. `node --env-file` keeps `${VAR}` as written while python-dotenv expands it, so replacing the value with a reference could break the app. Keep the file out of git |

Values that are already references, such as `${NPM_TOKEN}` or `$API_KEY`, are not listed.

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
| `pass` could not read the entry, or read it back | The GPG key is locked and no passphrase prompt could be shown, or the key is missing. The reason ends with the first line `pass` printed. `pass insert` encrypts with the public key, so the value may already be stored. Unlock the key and run the move again, and it finds the same value and edits the line |
| A startup file already sets the npm token's variable | Adding another export line would set it twice. Move the token by hand under another name |
| The AWS profile has `aws_session_token` or `credential_process` | Its keys are temporary, or it already reads them from elsewhere |
| The item is in `~/.netrc` or a `.env` file | Those files cannot read a value from elsewhere for every tool, as the section above says |
| 1Password could not be read, or two items have the name | `op` is not signed in or the 1Password app did not approve it, and the reason ends with the first line `op` printed. Or the vault holds two or more items titled with the name. Sign in, approve, or rename the other items, and run the move again |

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
- Overwrite a value already stored in the Keychain, the secret service, `pass`, or 1Password
- Edit any line other than the lines of the values it moved, apart from the export line it adds to your shell's startup file for an npm token
- Write a backup of a file, since a backup would hold the secret
- Rotate keys, or ask for the new value. You run `security add-generic-password -a "$USER" -s NAME -U -w` on macOS, `secret-tool store --label=NAME service NAME account "$USER"` on Linux, or `pass insert -f NAME` for `pass`, in your own terminal, which asks for the value without showing it, or edit the item in the 1Password app. A moved npm token or AWS key is stored under the name the move used, such as `NPM_TOKEN` or `AWS_SECRET_ACCESS_KEY_DEFAULT`
- Connect to the network itself, or keep files of its own. On Linux, `secret-tool` talks to the secret service only over your login session's D-Bus. When the password store is a git repository, `pass` commits each new entry there, encrypted, and never pushes it. With `--store 1password`, `op` talks to the 1Password app or to 1Password's servers to read and store the items in your account

## Limits

- Moving needs macOS with its `security` command, Linux with `secret-tool`, with `--store pass` the `pass` command and a password store, or with `--store 1password` the `op` command, a sign-in, and one vault named Private, Personal, or Employee. Elsewhere, or without that command, the scan works and the move stops with exit code 3 and names what is missing
- A moved line reads the value when the shell starts, so the store has to be reachable then. On Linux, a shell started over SSH or before the keyring is unlocked can get an empty variable, because `secret-tool` prints nothing when it cannot reach an unlocked keyring. A line that reads `pass` decrypts with your GPG key, so each new shell asks for the key's passphrase until gpg-agent holds it, and a shell with no way to ask gets an empty variable. A line that runs `op read` may ask the 1Password app for approval when a new terminal starts, and a shell where `op` is not signed in gets an empty variable
- The 1Password move was checked with a stand-in `op` that follows the help of op 2.42, not against a real 1Password account
- Bitwarden is not a store. Its `bw` command takes a value on standard input, but reads one only when the session key `BW_SESSION` is set in the environment, so a new shell would get an empty variable, and writing the session key into a startup file would put a secret there again. Each read also takes about 3 seconds
- Other stores are not supported
- SSH keys, a project's own `.npmrc`, `.env` files in subfolders, and the files that `AWS_SHARED_CREDENTIALS_FILE` or `NPM_CONFIG_USERCONFIG` point to are not scanned
- A moved npm token reaches only an npm started from a shell that ran the export line. An editor or app started outside the shell does not get it
- Assignments without `export` (or fish `set -x`), and values that span several lines, are not found
- Copies of an old value in shell history, backups, or Time Machine stay where they are. Rotating the key makes them useless
- A moved value is still exported to every program the shell starts, and tools that list a process's environment can show it. A key with wide access is safer read only for the command that needs it
- A key a team shares belongs in a vault the team shares, such as a shared 1Password vault read with `op`, not in one person's Keychain or personal vault
