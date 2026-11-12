# agent-shuriken

A collection of agent skills for Claude Code and Codex.
Each skill is a folder with a `SKILL.md`, so both agents can load it.

## Skills

| Skill | What it does |
|---|---|
| [`account-cleanup`](skills/account-cleanup/SKILL.md) | Finds web accounts you no longer use without reading any passwords, then cancels subscriptions and deletes the accounts you approve |
| [`pc-tidy`](skills/pc-tidy/SKILL.md) | Lists what has gone unused on your Mac and deletes only the items you pick, to free up disk space |

The agent talks to you in the language you write in.
The HTML pages the skills open default to English and have an English / 日本語 switch in the header.

## Installation

### Claude Code

Install the skills you want.

```
/plugin install account-cleanup --marketplace cardene777/agent-shuriken
/plugin install pc-tidy --marketplace cardene777/agent-shuriken
```

On Claude Code versions before 2.1.275, add the marketplace first.

```
/plugin marketplace add cardene777/agent-shuriken
/plugin install account-cleanup@agent-shuriken
/plugin install pc-tidy@agent-shuriken
```

### Codex

Copy a skill folder into `~/.codex/skills/` and Codex loads it.

```
git clone https://github.com/cardene777/agent-shuriken.git
cp -R agent-shuriken/skills/account-cleanup ~/.codex/skills/
cp -R agent-shuriken/skills/pc-tidy ~/.codex/skills/
```

## account-cleanup

Finds web accounts you no longer use, then cancels and deletes the ones you don't need.
It collects only service names, URLs, and dates from 1Password, Bitwarden, and browser-saved passwords, without reading any passwords.
You don't need to remember which services you signed up for or which ones you pay for.

```
Collect ──> Add reasons and descriptions ──> Mark OK or Keep ──> Cancel and delete OK items ──> Tidy the password manager
 (agent)     (agent)                          (you)               (agent; you do 2FA and         (agent, reversibly)
                                                                   approve each round)
```

### How passwords stay unread

| Source | What is read | What is never read |
|---|---|---|
| 1Password | During collection, the names, URLs, and modification dates returned by `op item list` | Collection never calls `op item get`. At login, `browser.sh login` reads the item with `op item get` and types it straight into the page's fields, never passing it to the agent or a file |
| Bitwarden | Names, URLs, and modification dates from `bw list items` | Passwords, usernames, and notes are discarded inside the script and never reach a file or the agent |
| Chrome and Chromium browsers | `origin_url` and dates from a copy of the saved-password database | The password column is never selected. The copy is deleted after reading |
| Google, Apple, and GitHub sign-ins, and Gmail | Only which page to open and what to search for | The agent never sees the screens or the emails |

Credentials are filled in only when the open page's domain matches the domain of the 1Password item's URL.
For items without a URL, they are filled in only on the official domain you looked up and passed with `--site`.
Field values are stripped from every page snapshot the agent reads, so the agent never receives a password.
You complete two-factor prompts and CAPTCHAs yourself in the browser window.
The agent presses the final delete and cancel buttons only after you approve that round's items once, before deletion starts.
In the browser, the agent only signs in, checks payments, cancels subscriptions, removes payment methods, and deletes accounts.
The candidate files and sheet live in `~/.local/share/account-cleanup/` with permissions only you can read, and are deleted when you finish.
The candidate sheet HTML loads nothing from the network.

### Usage

In Claude Code, run `/account-cleanup:account-cleanup`, or ask "I want to clean up accounts I don't use anymore."

1. Choose which sources to collect from, and where you live (EU, UK, California, Japan, or elsewhere), which picks the erasure request template
2. The agent tags likely-unused accounts with reasons, such as not updated in a long time or the site no longer exists, adds a short description of each site, and opens the candidate sheet
3. On the sheet, press OK for each account you want deleted or Keep for those you want to keep, press "Copy OK items", and paste the text into the chat
4. The agent opens your App Store, Google Play, and PayPal subscription lists once and cancels any subscriptions billed there first
5. Before deletion starts, you approve the number of accounts in that round once
6. For each OK item, the agent signs in from 1Password, cancels paid plans, removes saved cards and bank accounts, and deletes the account. You handle two-factor prompts. Payment methods it couldn't remove are shown in a list at the end
7. Accounts whose site is gone or whose service has ended skip deletion. For services that can't delete accounts, the agent drafts an erasure request under GDPR, CCPA, or Japan's APPI
8. When you say you're done, the agent moves the items for deleted accounts to the archive in 1Password or the trash in Bitwarden

### Requirements

| Tool | When it's needed |
|---|---|
| `jq` | Always |
| Node.js | When the agent drives the browser to delete accounts. On first use it installs Playwright and Chromium into the skill's data directory |
| `sqlite3` | When collecting from Chrome and other Chromium browsers |
| `op` (1Password CLI) | When collecting from 1Password. Turn on CLI integration in the 1Password app settings |
| `bw` (Bitwarden CLI) | When collecting from Bitwarden. Run `export BW_SESSION="$(bw unlock --raw)"` in your terminal before starting the agent |

### Bundled deletion directory

`skills/account-cleanup/data/sites.json` is an unmodified copy of the public JustDeleteMe data (MIT).
Its source and license are in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
For services not in the directory, the agent searches for the deletion page and adds it to `~/.local/share/account-cleanup/additions.json`, which is used from then on.

## pc-tidy

Lists what has gone unused on your Mac and deletes only the items you pick, to get disk space back.
It covers work folders and local repositories, apps, leftovers from removed apps, old tool versions, AI models, Docker images, and logs that keep growing.
It never deletes caches that can be rebuilt.
It runs on macOS only.

```
Build the list ──> Describe each item and recommend ──> Pick on the page ──> Delete only the picks ──> Report the space freed
 (agent)            (agent)                              (you)                (agent)                   (agent)
```

### Usage

In Claude Code, run `/pc-tidy:pc-tidy`.
The agent never starts this skill on its own.

1. The agent scans your home folder and lists items untouched for more than 30 days. This takes a few minutes
2. The agent opens a pick page that says what each item is and whether it is safe to delete, should be checked first, or should be kept
3. Pick the items to delete, leave comments on anything you're unsure about, and paste the copied text into the chat
4. The agent answers your comments and deletes only what you picked. Right before deleting, it re-checks for uncommitted changes and running processes
5. The agent reports what it deleted, what it skipped and why, and how much free space changed

Photos, keys, iCloud Drive, Mail, and similar locations are protected by default and never listed.
To protect more locations, add them one per line to `~/.local/share/pc-tidy/protect.txt`.
State is kept in `~/.local/share/pc-tidy/`, or in `PC_TIDY_HOME` when it is set.

### Requirements

| Tool | When it's needed |
|---|---|
| macOS | Always |
| `python3` | Always. The one that ships with macOS works |
| `git` | When measuring work folders and repositories |
| `docker` | When measuring Docker images. Without it, that category is reported as unmeasured |

## Contributing

Read [`AGENTS.md`](AGENTS.md) for the repository layout, safety principles, and how to verify a change.

## Security

Report vulnerabilities privately as described in [`SECURITY.md`](SECURITY.md).

## License

[MIT](LICENSE). Bundled third-party material is listed in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
