# Secure Dotfile

Move the API keys and tokens written into your shell startup files into the macOS Keychain, the Linux secret service, `pass`, or 1Password, without your agent ever seeing a value.

English · [日本語](README.ja.md)

A line such as `export OPENAI_API_KEY="sk-..."` in `~/.zshrc` puts the key in every backup, every dotfile repository, and every agent session that reads the file.
Moving it by hand means pasting the key into a terminal, where it lands in the shell history, and editing each line without a typo.
This plugin finds those lines and moves the ones you pick into the Keychain on macOS, or on Linux into the secret service that GNOME Keyring, KWallet, or KeePassXC with its secret service turned on, provides.
If you keep your secrets in `pass` or 1Password, they can go into your password store or your 1Password vault instead, on any system.
Each moved line then reads the value from there when the shell starts, so your programs see the same environment variable as before.
It also looks in files that tools read on their own: an npm token in `~/.npmrc` and AWS keys in `~/.aws/credentials` move too, while passwords in `~/.netrc` and keys in the `.env` and `.env.*` files of the folder you work in are listed with the reason they cannot be moved.
The value leaves the file, not the shell's environment: every program the shell starts still receives it, so a key with wide access is safer read only for the command that needs it, and a key your team shares belongs in a vault your team shares, not in one person's Keychain or personal vault.
Scripts read, store, and check the values, so the agent only ever sees names, locations, kinds, and lengths.

```
Scan the startup files ──> Pick what to move ──> Store the values and edit the lines ──> Report and suggest rotation
 (agent)                    (you)                 (agent)                                (agent)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install secure-dotfile@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add secure-dotfile@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install secure-dotfile@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/secure-dotfile/skills/secure-dotfile   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts when you mention a secret in your shell configuration, for example "I have API keys in my .zshrc, move them somewhere safer".
You can also call it: run `/secure-dotfile:secure-dotfile` in Claude Code, or type `$` and pick **Secure Dotfile** in Codex.
In GitHub Copilot CLI, write `/secure-dotfile` in your request, and in Gemini CLI, describe the task.

1. The agent scans your shell startup files and the files tools read on their own, and lists each secret by name, location, kind, and length, and whether its value is in the file's git history. A password under a name such as `DB_PASSWORD`, `PGPASSWORD`, or `MYSQL_PWD` is listed at any length, and one shorter than 8 characters has the kind `short password`, so you know to make it longer
2. You pick the secrets to move. When your password store is set up or the 1Password CLI `op` is installed too, you also pick which store they go into
3. The agent stores each one in the Keychain on macOS, in the secret service through `secret-tool` on Linux, in `pass`, or in 1Password through `op`, reads it back, and changes its line to load the value from there. macOS may ask for your login password to unlock the Keychain, the keyring on Linux may ask you to unlock it, `pass` may ask for your GPG key's passphrase, and the 1Password app may ask you to approve `op`
4. The agent reports what it moved and what it skipped and why, and tells you which keys to rotate because their values are in git history

The scan looks like this.

```text
Scanned 4 files: ~/.zprofile, ~/.zshrc, ~/.bashrc, ~/.secrets.sh
Moves into the keychain. Also available: pass (add --store pass)
Found 2 secrets written into them.

1  GH_TOKEN  ~/.zshrc:12
   GitHub token, 40 characters, in git history: not in a git repository
   item     ~/.zshrc:12:GH_TOKEN
   becomes  export GH_TOKEN="$(security find-generic-password -a "$USER" -s GH_TOKEN -w 2>/dev/null)"
2  OPENAI_API_KEY  ~/.secrets.sh:3
   OpenAI API key, 164 characters, in git history: yes
   item     ~/.secrets.sh:3:OPENAI_API_KEY
   becomes  export OPENAI_API_KEY="$(security find-generic-password -a "$USER" -s OPENAI_API_KEY -w 2>/dev/null)"
```

On Linux the same line becomes `export GH_TOKEN="$(secret-tool lookup service GH_TOKEN account "$USER" 2>/dev/null)"`, and in `pass` it becomes `export GH_TOKEN="$(pass show GH_TOKEN 2>/dev/null)"`.
In 1Password it becomes `export GH_TOKEN="$(op read 'op://Personal/GH_TOKEN/password' 2>/dev/null)"`, where `Personal` is the name of the vault `op` stores new items in: Private, Personal, or Employee, depending on your account type.
The 1Password move was checked with a stand-in `op` that follows the help of op 2.42, not against a real 1Password account.

Files that tools read on their own are handled like this.

| File | What happens |
|---|---|
| `~/.npmrc` | A token on a `//registry.npmjs.org/:_authToken=` line moves to the store, the line becomes `${NPM_TOKEN}`, which npm fills in from the environment, and your shell's startup file gets `export NPM_TOKEN="$(...)"`. A token for another registry gets its own name, such as `NPM_TOKEN_NPM_PKG_GITHUB_COM` |
| `~/.aws/credentials` | A profile's `aws_access_key_id` and `aws_secret_access_key` move to the store, and the two lines become one `credential_process` line that reads them back. The AWS CLI runs that line itself, so it works outside the shell too. A profile with `aws_session_token` holds temporary keys and is left alone |
| `~/.netrc` | Listed, not moved: curl and git read it as written. For git, a credential helper such as osxkeychain or libsecret can keep the password instead |
| `.env` and `.env.*` in the folder you work in | Listed with whether the key is in git history, not moved: `node --env-file` keeps `${VAR}` as written while python-dotenv expands it, so a reference could break the app |

When an agent's sandbox asks, as Codex can, approve the commands, because they read files in your home folder and use the Keychain, the secret service, `pass`, or `op`.

## Requirements

| Tool | When it's needed |
|---|---|
| macOS and its `security` command | To move secrets on macOS |
| `secret-tool` from libsecret, and a running secret service such as GNOME Keyring or KWallet | To move secrets on Linux. Debian and Ubuntu ship `secret-tool` in the `libsecret-tools` package. The scan works without it |
| `pass` and GnuPG, with a password store set up by `pass init` | Only to move secrets into `pass` |
| The 1Password CLI `op`, signed in or connected to the 1Password app, and one vault named Private, Personal, or Employee | Only to move secrets into 1Password |
| `python3` | Always. The one that ships with macOS works |
| `git` | To tell whether a value is in a file's git history |
| `zsh`, `bash`, or `fish` | To check the syntax of an edited file. A file whose shell is missing is edited but not checked |
| `chezmoi` | Only when your dotfiles are managed by chezmoi |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) lists every file it scans, what counts as a secret, and each step of a move.
In short:

- It reads your shell startup files and the files they source, `~/.npmrc`, `~/.aws/credentials`, `~/.netrc`, and the `.env` and `.env.*` files of the folder it runs in, and asks `git` for their history and `chezmoi` for their source files
- It never prints any part of a value. The values stay inside the script and reach `security`, `secret-tool`, `pass`, or `op` on its standard input, never on its command line
- It stores only the values you pick, in your default keychain on macOS, your default secret service collection on Linux, your password store, or your 1Password vault named Private, Personal, or Employee, and never overwrites a different value stored under the same name. When the password store is a git repository, `pass` commits each new entry there, encrypted, and pushing it is up to you
- It edits only the lines of the values it moved, plus one export line added to your shell's startup file for each npm token, keeps each file's permissions and symlinks, and checks the syntax of each edited shell file
- It connects to nothing on the network itself and keeps no files of its own. On Linux, `secret-tool` reaches the secret service over your login session's local message bus (D-Bus). With `--store 1password`, `op` talks to the 1Password app or to 1Password's servers to read and store the items in your account, and only a scan or move that picks 1Password runs `op`

## License

[MIT](LICENSE)
