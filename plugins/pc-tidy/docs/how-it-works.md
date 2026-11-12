# How PC Tidy works

English · [日本語](how-it-works.ja.md)

This page lists what the plugin looks at, how it removes each kind of item, and what it never touches.

## What it lists

An item is listed when it has gone untouched for more than 30 days.

| Kind | How the last-used date is found | How it is removed |
|---|---|---|
| Work folders and local repositories | The last commit and the last checkout | Deleted permanently, and only when everything is on the remote |
| Apps | The last launch | Deleted permanently |
| Leftovers of removed apps | The newest file inside, or the last time an executable inside ran | Moved to the Trash |
| Tools and runtimes | The last time anything in a version's `bin` ran | Deleted permanently. When every version is old, removing the version manager is offered too |
| AI models | The last time they were read | Deleted permanently |
| Docker images | The creation date. Images that a container uses are not listed | `docker image rm` |
| Log retention settings | None | The retention period is changed |
| Anything else | The newest file inside, or the last time an executable inside ran | Moved to the Trash |

Files that Finder writes just by opening a folder, such as `.DS_Store`, do not count as use.
When a kind cannot be measured because a tool is missing, it is reported as unmeasured instead of as zero.
Anything deleted before that has come back is named, along with what recreates it.

## What it never lists

- Photos, keys, iCloud Drive, mail, and the other locations in `skills/pc-tidy/protect-default.txt`
- Locations you add, one per line, to `protect.txt` in the settings folder
- The settings folder itself
- Anything in `~/Documents` or `~/Desktop` that is not a repository
- Repositories with uncommitted changes or unpushed commits
- Folders that a running process is working in
- Repositories inside dot-folders in your home folder, such as editor plugins, because tools look them up when they run
- Docker volumes and virtual machine storage
- Package manager caches that rebuild themselves, such as `~/.npm` and `~/.cargo/registry`
- Items of zero bytes

## How deletion stays safe

You pick every item on the page, and the agent never picks for you.
Right before deleting, the plugin re-checks protection, uncommitted changes, unpushed commits, and running processes.
Anything that changed after the list was built is skipped and named with a reason.
Whether a repository's commits are on the remote is judged from what your Mac last fetched, because the plugin does not connect to the network.
Settings owned by another tool, such as a symlinked repository or `chezmoi`, and shell files such as `~/.zshrc` are never rewritten. The agent tells you what to change instead.

## The report

After deleting, the agent tells you:

- What was deleted, and what was skipped and why
- How much free space changed
- How much went to the Trash, which becomes free space once the Trash is emptied
- Whether Time Machine local snapshots are holding the space

## Settings

Settings live in `~/.local/share/pc-tidy/`, or in `PC_TIDY_HOME` when it is set.

| File | Contents |
|---|---|
| `config` | `days=<days>` sets how long an item must be unused (default 30). `min_size_mb=<MB>` sets the smallest uncategorized item to list (default 100) |
| `protect.txt` | Locations to protect, one per line. `~` means your home folder |
| `removed.jsonl` | The log of deleted items |
| `notes.json` | The descriptions and your comments, kept per location so later lists reuse them |

## What it runs

The plugin runs only on macOS and needs no network.
It runs `python3`, and reads usage information from `git`, `mdls`, and `docker` when they are present.
The scan runs at low CPU priority so other work keeps going.
