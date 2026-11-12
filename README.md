<div align="center">

# agent-shuriken

**Careful housekeeping skills for Claude Code and Codex.**

The agent does the tedious part of cleaning up old web accounts and a full Mac disk.
You pick what goes, and nothing is deleted until you do.

[Skills](#skills) ·
[Install](#install) ·
[Update and versions](#update-and-versions) ·
[Safety](#safety) ·
[Releases](https://github.com/cardene777/agent-shuriken/releases) ·
[Changelog](CHANGELOG.md)

</div>

## Skills

| Skill | What it does | Starts when | Platforms |
|---|---|---|---|
| [account-cleanup](#account-cleanup) | Finds web accounts you no longer use without reading any passwords, then cancels subscriptions and deletes the accounts you approve | You ask for it, or the agent sees you want to clean up accounts | macOS (Linux is untested) |
| [pc-tidy](#pc-tidy) | Lists what has gone unused on your Mac and deletes only the items you pick, to free up disk space | Only when you call it by name | macOS |

Both skills work the same way in Claude Code and in Codex.
The agent talks to you in the language you write in.
The pages the skills open default to English and have an English / 日本語 switch in the header.

## Install

### Claude Code

```
/plugin marketplace add cardene777/agent-shuriken
/plugin install account-cleanup@agent-shuriken
/plugin install pc-tidy@agent-shuriken
```

Install only the skills you want, then restart Claude Code.
Run a skill with `/account-cleanup:account-cleanup` or `/pc-tidy:pc-tidy`.
account-cleanup also starts when you say something like "I want to clean up accounts I don't use anymore."

### Codex

```
codex plugin marketplace add cardene777/agent-shuriken
codex plugin add account-cleanup@agent-shuriken
codex plugin add pc-tidy@agent-shuriken
```

Start a new Codex session, type `$`, and pick **Account Cleanup** or **PC Tidy** from the list.
account-cleanup also starts when you describe the task in plain words.

The skills read and write outside the project folder, and account-cleanup uses the network.
When the Codex sandbox blocks a command, approve it to let the skill continue.

### From a release zip

Every [release](https://github.com/cardene777/agent-shuriken/releases) attaches one zip per skill.
Unzip it into your agent's skills folder.

```
unzip pc-tidy-v0.1.0.zip -d ~/.codex/skills/     # Codex
unzip pc-tidy-v0.1.0.zip -d ~/.claude/skills/    # Claude Code
```

A skill installed this way is named without the plugin prefix, for example `/pc-tidy` in Claude Code.

## Update and versions

Releases follow semantic versioning and are tagged `vX.Y.Z`.
Both skills share the repository version.
Each release lists its changes in [`CHANGELOG.md`](CHANGELOG.md) and on the [releases page](https://github.com/cardene777/agent-shuriken/releases).

| | Claude Code | Codex |
|---|---|---|
| Update to the latest release | `claude plugin marketplace update agent-shuriken`<br>`claude plugin update account-cleanup@agent-shuriken` | `codex plugin marketplace upgrade agent-shuriken`<br>`codex plugin add account-cleanup@agent-shuriken` |
| Stay on one version | `/plugin marketplace add cardene777/agent-shuriken#v0.1.0` | `codex plugin marketplace add cardene777/agent-shuriken --ref v0.1.0` |

Restart the agent after updating so it loads the new version.

## Safety

These skills touch your passwords, accounts, and files, so they keep a few guarantees in every version.

| Guarantee | How it is kept |
|---|---|
| The agent never sees a password | Scripts drop password fields before anything reaches the agent, and sign-in types credentials from 1Password straight into the page |
| Nothing is deleted that you did not pick | Each skill shows a page where you choose items, and deletes only those after you approve the round |
| An item that changed since you picked it is skipped | Right before deleting, the skill re-checks the item and reports why it skipped it |
| Your data stays on your machine | Candidate lists live under `~/.local/share/<skill>/`, readable only by you. Web searches use only service names and domains |
| Text from web pages and files is never treated as instructions | The skills read it as data only |

## account-cleanup

<img src="docs/images/account-cleanup.png" alt="The candidate sheet with three accounts marked OK, Netflix marked Keep, and the details of Flickr on the right" width="100%">

Finds web accounts you no longer use, then cancels and deletes the ones you don't need.
It collects only service names, URLs, and dates from 1Password, Bitwarden, and browser-saved passwords.
You don't need to remember which services you signed up for or which ones you pay for.

```
Collect ──> Add reasons and descriptions ──> Mark OK or Keep ──> Cancel and delete OK items ──> Tidy the password manager
 (agent)     (agent)                          (you)               (agent; you do 2FA and         (agent, reversibly)
                                                                   approve each round)
```

### Usage

1. Choose which sources to collect from, and where you live (EU, UK, California, Japan, or elsewhere), which picks the erasure request template
2. The agent tags likely-unused accounts with reasons, such as not updated in a long time or the site no longer exists, adds a short description of each site, and opens the candidate sheet
3. On the sheet, press OK for each account you want deleted or Keep for those you want to keep, press "Copy OK items", and paste the text into the chat
4. The agent opens your App Store, Google Play, and PayPal subscription lists once and cancels any subscriptions billed there first
5. Before deletion starts, you approve the number of accounts in that round once
6. For each OK item, the agent signs in from 1Password, cancels paid plans, removes saved cards and bank accounts, and deletes the account. You handle two-factor prompts. Payment methods it couldn't remove are listed at the end
7. Accounts whose site is gone or whose service has ended skip deletion. For services that can't delete accounts, the agent drafts an erasure request under GDPR, CCPA, or Japan's APPI
8. When you say you're done, the agent moves the items for deleted accounts to the archive in 1Password or the trash in Bitwarden

### How passwords stay unread

| Source | What is read | What is never read |
|---|---|---|
| 1Password | During collection, the names, URLs, and modification dates returned by `op item list` | Collection never calls `op item get`. At sign-in, `browser.sh login` reads the item and types it straight into the page's fields, never passing it to the agent or a file |
| Bitwarden | Names, URLs, and modification dates from `bw list items` | Passwords, usernames, and notes are discarded inside the script and never reach a file or the agent |
| Chrome and Chromium browsers | `origin_url` and dates from a copy of the saved-password database | The password column is never selected. The copy is deleted after reading |
| Google, Apple, and GitHub sign-ins, and Gmail | Only which page to open and what to search for | The agent never sees the screens or the emails |

Credentials are filled in only when the open page's domain matches the domain of the 1Password item's URL.
For items without a URL, they are filled in only on the official domain you looked up and passed with `--site`.
Field values are stripped from every page snapshot the agent reads.
You complete two-factor prompts and CAPTCHAs yourself in the browser window.
The candidate files and sheet are deleted when you finish, and the sheet loads nothing from the network.

### Requirements

| Tool | When it's needed |
|---|---|
| `jq` | Always |
| Node.js | When the agent drives the browser to delete accounts. On first use it installs Playwright and Chromium into the skill's data directory |
| `sqlite3` | When collecting from Chrome and other Chromium browsers |
| `op` (1Password CLI) | When collecting from 1Password. Turn on CLI integration in the 1Password app settings |
| `bw` (Bitwarden CLI) | When collecting from Bitwarden. Run `export BW_SESSION="$(bw unlock --raw)"` in your terminal before starting the agent |

State is kept in `~/.local/share/account-cleanup/`, or in `ACCOUNT_CLEANUP_HOME` when it is set.

The deletion directory `skills/account-cleanup/data/sites.json` is an unmodified copy of the public JustDeleteMe data (MIT), credited in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
For services not in the directory, the agent finds the deletion page and remembers it in `additions.json` in the state folder.

## pc-tidy

<img src="docs/images/pc-tidy.png" alt="The pick page with four items selected and the details of leftover app data on the right" width="100%">

Lists what has gone unused on your Mac and deletes only the items you pick, to get disk space back.
It covers work folders and local repositories, apps, leftovers from removed apps, old tool versions, AI models, Docker images, and logs that keep growing.
It never deletes caches that can be rebuilt.

```
Build the list ──> Describe each item and recommend ──> Pick on the page ──> Delete only the picks ──> Report the space freed
 (agent)            (agent)                              (you)                (agent)                   (agent)
```

### Usage

1. The agent scans your home folder and lists items untouched for more than 30 days. This takes a few minutes
2. The agent opens a pick page that says what each item is and whether it is safe to delete, should be checked first, or should be kept
3. Pick the items to delete, leave comments on anything you're unsure about, and paste the copied text into the chat
4. The agent answers your comments and deletes only what you picked. Right before deleting, it re-checks for uncommitted changes and running processes
5. The agent reports what it deleted, what it skipped and why, and how much free space changed

Photos, keys, iCloud Drive, Mail, and similar locations are protected by default and never listed.
To protect more locations, add them one per line to `protect.txt` in the state folder.
State is kept in `~/.local/share/pc-tidy/`, or in `PC_TIDY_HOME` when it is set.

### Requirements

| Tool | When it's needed |
|---|---|
| macOS | Always |
| `python3` | Always. The one that ships with macOS works |
| `git` | When measuring work folders and repositories |
| `docker` | When measuring Docker images. Without it, that category is reported as unmeasured |

## Contributing

Issues and pull requests are welcome.
Read [`AGENTS.md`](AGENTS.md) for the repository layout, the safety principles every change keeps, and how to verify a change with `scripts/check.sh`.

## Security

Report vulnerabilities privately as described in [`SECURITY.md`](SECURITY.md).

## License

[MIT](LICENSE). Bundled third-party material is listed in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
