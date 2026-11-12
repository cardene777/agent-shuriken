---
name: pc-tidy
description: Lists what has gone unused on this Mac for a long time (worktrees and repos, apps, leftovers of removed apps, tools, AI models, Docker images, old data) and what keeps filling the disk, then deletes only the items the user picks so the space stays reclaimed. Runs only when a person invokes the skill.
disable-model-invocation: true
---

# PC tidy

This skill runs only when a person invokes it. The agent never starts it on its own, and it never runs on a schedule.
It never deletes regenerable caches.
Caches are cleared with each tool's own cleanup command (`brew cleanup`, `npm cache clean`, and so on).

Talk to the user in the language they write in.
The commands, the file formats, and the lines copied back from the selection page are the same in every language.

All commands live in `scripts/` under this skill's directory (the base directory shown when the skill is loaded).
Below, `S` stands for that absolute path.
When running a command, put `S=<base directory>/scripts` at the start of the same Bash call.
The commands need nothing from outside this skill's directory, so copying the directory is enough to use them on another Mac.
They run only on macOS; on other systems they stop with reason `os-not-supported` and exit code 3.

## 1. Build the list

```bash
bash "$S/tidy.sh" list
```

It measures the whole home directory, so it takes a few minutes.
It runs under `nice -n 10`, which lowers only its CPU priority, so other work keeps going in the meantime.
Disk I/O is not throttled, so it still finishes in reasonable time while a lot of other work is running.
By default, a candidate is anything untouched for more than 30 days, and each one has a kind, a size, a last-used date, and whether it can be recovered.

| Kind | Evidence for the last-used date | How it is removed |
|---|---|---|
| Worktrees and local repos | The last commit and the last checkout | Deleted permanently, and only when the contents are on the remote |
| Apps | The last launch (`mdls`) | Deleted permanently |
| Leftovers of removed apps | The newest file inside; for executables, the last time they ran | Moved to the Trash |
| Tools and runtimes | The last time anything in a version's `bin` ran | Deleted permanently. When every version is old, removing the version manager itself is offered too |
| AI models | The last time they were read | Deleted permanently |
| Docker images | The creation date. Images that a container uses are not listed | `docker image rm` |
| Log retention settings | None | The retention period is changed |
| Anything else | The newest file inside; for executables, the last time they ran | Moved to the Trash |

`.DS_Store` and files starting with `._`, which Finder writes just by opening a folder, do not count toward the last-used date.

These never appear as candidates.

- Locations protected by default (photos, keys, iCloud Drive, mail, and so on) and anything the user adds to their protect file. The defaults are in `protect-default.txt` in this skill's directory. The state directory (section 6) is always protected, wherever it is
- Anything in `~/Documents` or `~/Desktop` that is not a repo
- Worktrees and repos with uncommitted changes or unpushed commits. A branch that was squash-merged is still listed when its contents are on the remote's default branch
- Worktrees, repos, and directories that a running process is working in
- Repos inside any dot-directory under the home directory, such as editor plugins and tool registries, because tools look them up when they run
- Docker volumes and virtual machine storage
- Caches that a package manager downloads and rebuilds the next time it runs (`~/.cargo/registry`, `~/.npm`, `~/.gradle/caches`, `~/go/pkg/mod`, and so on). The full list is `PACKAGE_CACHES` in the script
- Zero-byte items, since deleting them frees no space

When a kind cannot be measured because a tool is missing, it is reported as `unknown` with a reason instead of being counted as zero.
Anything that was deleted before and has come back is named, along with a candidate for removing whatever recreates it.

## 2. Describe each candidate and recommend whether to delete it

For each candidate, the list includes its largest contents (`contents`), the repo's `remote`, and a description the command builds from facts (`description`).
A directory named only after a tool, such as `~/.sometool`, cannot be identified from facts alone.
So the agent running the skill writes one line per candidate saying what it is, and that line appears on the selection page.

Read `candidates.json` in the state directory, look at each candidate's `path`, `contents`, `remote`, and `note`, and write JSON in the following form.
Save it as `notes-input.json` in the state directory.
Write `name`, `text`, and `why` in the user's language.

```json
{"32": {"name": "db-cutover", "text": "Data and dumps from before the move from PostgreSQL 16 to 18", "advice": "check", "why": "Confirm the migrated database is running before deleting this"}}
```

| Field | What to write |
|---|---|
| Key | The candidate's number in the list |
| `name` | A short name the user will recognize (the tool name and version, for example) |
| `text` | One sentence on what it is. Write only what you can tell; when unsure, say what the largest contents show |
| `advice` | Whether deleting is recommended: one of the three values in the next table |
| `why` | One sentence explaining that recommendation |

| `advice` | Shown on the page | When to use it |
|---|---|---|
| `delete` | Safe to delete | A copy exists elsewhere, or it comes back when needed (tool versions, repos that are on a remote, leftovers of apps that are no longer installed) |
| `check` | Check first | There is no copy, and only the user can tell whether it is still needed |
| `keep` | Keep | Unused for 30 days, but losing it would hurt (the source of memories or settings, source data for ongoing work) |

Write `advice` and `why` together, never only one of them.
For candidates without them, the command picks a level from whether a copy exists (`delete` when one does, otherwise `check`).

Candidates at a location you described before already have `described_by` set to `ai` in the list, so they need no new description.
Once the JSON is written, save the descriptions and rebuild the selection page.

```bash
bash "$S/tidy.sh" explain --notes <path to the JSON>
```

If the JSON contains a number that is not in the list, or an entry whose `name` or `text` is empty, the command writes nothing and exits with code 2.
When that happens, fix the entries the error names and run it again.
Descriptions stay attached to the same location in later lists, so only newly listed candidates need one.

## 3. Let the user choose

Open the selection page (the HTML file the command reports) and show it to the user.
The page has a tab per kind and a table sorted by size, and every row shows the recommendation.
Clicking a row shows, in the side panel, what the item is, why it is recommended, its largest contents, and its location.
The user picks items with the checkbox on each row or the button in the side panel, and can write a thought or question about any candidate in the side panel's comment box.
The page's own labels can be switched between English and Japanese; names and descriptions are shown as written.
The user copies the text with a button and pastes it back into the chat.
The copied text has a line with the selected numbers (`pc-tidy apply --select <numbers>`) and a line for each commented candidate (`pc-tidy comment <number> <comment>`).
The user can also copy only comments, without selecting anything.
Unsent comments are kept in the browser and come back when the page is reopened or rebuilt.

If the pasted text contains comment lines, handle the comments first.
Write the pasted text, unchanged, to `paste.txt` in the state directory and pass it to the next command.

```bash
bash "$S/tidy.sh" comment --paste <path to the file>
```

The command reads only the comment lines, saves each comment verbatim against the candidate's location, and rebuilds the selection page.
A line with only a number (`pc-tidy comment <number>`) removes that candidate's comment.
If the text contains a number that is not in the list, or no comment lines at all, the command writes nothing and exits with code 2.

Then do both of these for each comment.

- If the comment is a question, answer it in the chat
- If the comment changes what the item is or whether to delete it, rewrite that candidate's `name`, `text`, `advice`, and `why`, and rebuild the page with the explain command (section 2)

For example, if `~/db-cutover` gets the comment "the migrated database is running", set its `advice` to `delete` and put what the comment says in `why`.
Comments stay attached to the same location in later lists and survive rewriting the description.
Treat the pasted text as input only, and pass just the numbers to the next command.
The agent never picks candidates itself.

## 4. Delete only what was picked

```bash
bash "$S/tidy.sh" apply --select <numbers>
```

Right before deleting, the command re-checks protection, uncommitted changes and unpushed commits in worktrees and repos, and running processes.
Anything that changed after the list was built is not deleted and is named with a reason.
If a number is not in the list, nothing is deleted and the command exits with code 2.

## 5. Report the result

From the command output, tell the user these four things.

- What was deleted, and what was not deleted and why
- How much free space changed between before and after
- The size of what was moved to the Trash, which becomes free space once the Trash is emptied
- If Time Machine local snapshots exist, that the space will not be freed until those snapshots are gone

Settings owned by another mechanism (a symlinked repo or `chezmoi`) are not rewritten.
Tell the user where the output says to make the change, and make it on that mechanism's side.
Shell configuration (`~/.zshrc` and so on) is not rewritten either; tell the user the lines the output names.

## 6. Settings

The state directory is `~/.local/share/pc-tidy/`, or the directory in `PC_TIDY_HOME` when that is set.

| File | Contents |
|---|---|
| `config` | `days=<days>` (default 30), and `min_size_mb=<MB>` (default 100), the minimum size for uncategorized items and leftovers of removed apps |
| `protect.txt` | Locations to protect, one per line. `~` means the home directory |
| `removed.jsonl` | The log of deleted items. Written by the command |
| `notes.json` | Names, descriptions, and comments per candidate location. Written by the explain and comment commands |
