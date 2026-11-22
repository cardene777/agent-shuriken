# How Machine Cleanup works

English · [日本語](how-it-works.ja.md)

This page explains what the scan measures and how, what counts as in use, how the page talks to the agent, and what happens to each picked item.
Every command is `scripts/machine_cleanup.py` in the skill folder.

## The scan

`scan` first lowers its own priority to the lowest CPU priority (niceness 19), and measures folder sizes with `du` under `taskpolicy -b` on macOS or `ionice -c3` on Linux, so the computer stays usable while it runs.
It stops when its time limit (90 seconds unless `--time-limit` says otherwise) runs out, and lists every place it did not reach with the reason `time limit`.

It looks in this order, so the fastest and most useful results come first.

| Step | What it reads |
|---|---|
| Processes | `ps` twice, `--sample` seconds apart (2 by default). CPU use is how much each process's CPU time grew between the two, because the `%cpu` that `ps` prints is a decaying average |
| Login items | `~/Library/LaunchAgents` on macOS. `~/.config/autostart` and `systemctl --user list-unit-files` on Linux |
| Containers | `docker ps` and `docker stats --no-stream` |
| AI models | Ollama's manifests and blobs (`OLLAMA_MODELS` or `~/.ollama/models`), the `models--` folders of the Hugging Face cache (`HF_HUB_CACHE`, `HF_HOME`, or `~/.cache/huggingface/hub`), and the model folders of LM Studio (`~/.lmstudio/models` and `~/.cache/lm-studio/models`) |
| Caches | The default folder of each package manager, honoring the variables that move it (`npm_config_cache`, `PNPM_STORE_DIR`, `YARN_CACHE_FOLDER`, `BUN_INSTALL_CACHE_DIR`, `PIP_CACHE_DIR`, `UV_CACHE_DIR`, `HOMEBREW_CACHE`, `CARGO_HOME`, `GOPATH`, `GOMODCACHE`, `GOCACHE`, `GRADLE_USER_HOME`, `XDG_CACHE_HOME`, `XDG_DATA_HOME`), Xcode's folders on macOS, app caches of 50 MB or more in `~/Library/Caches` or `~/.cache`, and `docker system df` |
| Trash and logs | The Trash, files older than 30 days in `~/Library/Logs` on macOS or log files in `~/.local/state` on Linux, and installers older than 30 days in `~/Downloads` |
| Apps | On macOS, `.app` bundles in `/Applications` and `~/Applications` (or `--apps-dir`) that you can change, whose last use `mdls` reports as more than 90 days ago. On Linux, `flatpak list --user --app` |
| App leftovers | On macOS, the entries of `~/Library/Application Support`, `Caches`, `Preferences`, `Containers`, `Saved Application State`, `HTTPStorages`, `WebKit`, and `Logs` named by a bundle id (`com.example.app`) |
| Files | A walk of the home folder (or each `--root`) up to 8 levels deep, which skips hidden folders, `~/Library` and `~/Applications` on macOS, and the places in "Places it never enters" |
| Work folders | The git projects the walk met, read with `git log`, `git status`, `git remote`, and `git rev-list` |
| Tool versions | The version folders of nvm, fnm, pyenv, rbenv, asdf, mise, and rustup, honoring `NVM_DIR`, `FNM_DIR`, `PYENV_ROOT`, `RBENV_ROOT`, `ASDF_DATA_DIR`, `MISE_DATA_DIR`, and `RUSTUP_HOME`, their defaults, and the version files the walk met |

During the walk, a folder that holds `.git` is a project.
Folders named `node_modules`, `.next`, `.nuxt`, `.svelte-kit`, `.turbo`, `.parcel-cache`, `.vite`, `.angular`, `.expo`, `.docusaurus`, `.output`, `.vercel`, `.wrangler`, `dist`, `build`, `out`, `target`, `.venv`, `venv`, `__pycache__`, `.pytest_cache`, `.mypy_cache`, `.ruff_cache`, `.tox`, `.gradle`, `DerivedData`, `coverage`, `.cache`, and `Pods` within four levels of the project's top are build output only when `git check-ignore` says git ignores them and `git ls-files` finds no tracked file inside.
Build output under 1 MB is not listed.

Files of 10 MB or more are duplicate candidates.
Two files are duplicates when they have the same size, the same SHA-256 of their first 64 KiB, and the same SHA-256 of their whole content; hard links to one file count once.
This is the only time the scan reads file contents, and it keeps only the hashes.
Files of 500 MB or more that have no duplicate are large files.

A project is an unused work folder when its last commit and the last change of `.git/HEAD` and its log (a checkout or a commit) are both more than 30 days old, `git status` shows nothing uncommitted and no untracked file, it has a remote, and `git rev-list HEAD --branches --not --remotes` finds no commit that is missing from the remote-tracking refs.
Those refs are what the last fetch saw, so the scan never connects to the remote.
git runs with `GIT_OPTIONAL_LOCKS=0`, so reading a project never rewrites its index.
A project with another worktree, and a worktree itself, are never listed.

An app leftover is a Library entry whose bundle id belongs to a company (its first two parts, such as `com.example`) that no app in the app folders or among running apps has, whose other parts match no running process, and whose newest file is more than 30 days old.
The entries of one bundle id across the eight folders form one row.
A bundle id here starts with a top-level domain of 2 to 4 letters and has no part that looks generated, such as a UUID or a long random token, which an app or a test makes for each run.
Entries named otherwise, entries starting with `com.apple.`, and files already listed with an unused app or as an app cache are left out, since names that are not bundle ids belong mostly to macOS itself and to command-line tools.
When the time limit ends before the eight folders are read, no leftover is listed, because a file of the same bundle id in a folder not read may be recent.
Linux has no leftovers row, because files there cannot be matched to the package that made them.

A tool version is unused when it is neither the manager's default (nvm's `alias/default`, fnm's `aliases/default`, the `version` file of pyenv and rbenv, `~/.tool-versions` for asdf and mise, mise's global `config.toml`, and rustup's `settings.toml`) nor named by a project's `.nvmrc`, `.node-version`, `.python-version`, `.ruby-version`, `.tool-versions`, `mise.toml`, `.mise.toml`, `rust-toolchain`, or `rust-toolchain.toml`.
A name also counts when it is the leading part of a version (`20` for `20.11.1`) or a link beside it (mise's `lts`).
A version is listed but cannot be picked when a running program uses it, when a default or a project names a word such as `latest` that matches no installed version, or when the walk stopped at the time limit before reading every project.
Work folders and tool versions come from the walk of the home folder, which comes after the caches; on a large home folder, `--time-limit` gives the walk time to finish.

Every model is listed with its size and the day it was downloaded.
An Ollama model's size counts only the blobs that no other model uses, because only those are freed.
The Hugging Face and LM Studio folders under `~/.cache` are never listed as app caches, since a model takes long to download again.

The result goes to `scan.json` in the state folder.
Each item has an id (`d-` and eight hex digits for disk items, `p-` for processes, login items, and containers), a category, a kind, a size or memory use, whether it comes back on its own, how it is freed, the reason it is in use when it is, and a fingerprint for the check before acting.
The file also keeps the free and whole disk from `df`, the memory in use and in all, and the load, which the overview tab draws.
It records its format as version 5, and `serve` and `apply` refuse a scan of an older version and ask for a new scan.

A row whose name the scan makes, such as a cache, a log folder, build output, or a dev server, also has a `label`: a key and the values the name needs, such as `{"key": "build", "vars": {"folder": "node_modules", "project": "shop"}}`.
The page looks the key up in its dictionary, so the name follows the page's language, and product names such as npm or Vite stay as they are.
The item's `name` keeps the English name, which the agent reports and the copied selection never needs.

## One row for each path

Two steps can meet the same file: an installer in Downloads older than 30 days can also be a file of 500 MB or more.
The scan keeps the row of the step that met the path first, in the order of the table above, so the file appears once and is counted once.
When the row it drops was one copy of a set of duplicates, the kept row takes the set, so that one copy of the set still has to stay.

A row can also lie inside another row: build output or a large file inside an unused work folder, or an app's cache or logs among the support files of an unused app.
The inner row keeps its own row, so that it can be freed alone, and lists in `within` the ids of the rows that hold it, nearest first.

| Where | How the inner row counts |
|---|---|
| The charts | Once. A row's share leaves out the shown rows inside it, and a picked row inside a picked row adds nothing |
| The bar at the bottom | Once, in Disk to free |
| The summary before sending | It says that the inner row is freed with the outer row |
| `apply` | Frees the outer rows first. An inner row whose holder was freed is reported as `skipped`, inside the holder, which was freed with it |

## How rows are ranked

The scan gives every item one of three levels and a reason, stored as `recommended`, `check`, and `careful`.
The page splits each list tab into one table per level, with the rows in use last, and shows each row's level as a tag with an icon and its word.
The level only orders the rows and explains them; `apply` checks every pick the same way whatever its level.

| Level | Items | Reason shown |
|---|---|---|
| Recommended | Caches that tools rebuild, build output of a project with no commit for more than 30 days, the Trash, logs and installers older than 30 days, and dev servers still running after their session ended | Rebuilt the next time it is needed, how many days the project has had no commit, or how old the files are |
| Restorable | Build output of a project with a commit in the last 30 days, large files, duplicates, unused work folders, unused apps, app leftovers, unused tool versions, AI models, login items, and a `next-server` process, since `next start` runs under the same name | How many days since the last commit, checkout, or download, since the app was opened, or since the leftover last changed, or that the item can be put back or installed again |
| Risky | Heavy processes and running containers | Ending it stops its work |
| In use | Any item that is in use, whatever its level | Why it is in use |

The headings of the recommended and restorable levels have a Pick all button that picks every row of the level except copies of duplicates, which are picked one copy at a time so that one copy always stays.
The copies of one set sit together, wherever the scan found them, and the first of them says how many copies there are and the size of each.
The risky and in-use levels have no such button, and the page opens with nothing picked.

## The overview tab

The page has four tabs: Overview, Disk, Programs, and Not measured, and each tab after the first names how many rows it holds.
The tabs stay on one line. The arrow keys, Home, and End move between them, and the strip scrolls sideways when the window is too narrow for them.
The page opens on the overview tab, which draws the scan as seven charts.
Pressing a part of a ring or a legend row that names a kind opens the Disk or Programs tab showing only that kind, and pressing a bar opens the details of that row.
A value the scan could not measure is shown as "Not measured", never as zero.
The hole of a ring holds only its name and value, and the lines below the ring hold the rest, such as the whole disk.

| Chart | What it shows |
|---|---|
| What can be freed | The disk each kind of row gives back, without rows in use and keeping one copy of each set of duplicates. The line below is how much of it is rebuilt on next use |
| Size by level | The same disk split into recommended, restorable, and risky, with the rows in use apart. The line below is the free disk after freeing every recommended row |
| Disk | The whole disk as what you picked, what can be freed but is not picked, other use, and free space. The line below is the free disk after freeing what you picked |
| Memory | Memory used by processes that can end, by processes in use, by everything else, and free memory. Containers are left out, since the process that runs them already counts their memory. The line below is the load over the last minute |
| Largest items | The 8 largest rows on disk, coloured by their level. A long name wraps onto a second line instead of being cut |
| Processes using the most memory | The 6 processes that use the most memory |
| Processes using the most CPU | The 6 processes with the highest CPU share between the two `ps` samples |

Each bar reads its name and its value, and a bar shows where its row is when another bar of its chart has the same name, such as two Host processes.

## The Disk and Programs tabs

The Disk tab lists caches, build output, the Trash and logs, large and duplicate files, projects, apps, and tools and models.
The Programs tab lists processes, login items, and containers.
Each level is a table under its heading, with the column headers kept on top as the list scrolls.
A row has its name as the row header, then its size, or for a process or container its memory and its share of CPU in the CPU (%) column, and a pick button named by the row.
A login item has neither memory nor a CPU share, so both of its cells stay empty.
A large file, a copy of a duplicate, and a row whose name another row in the tab has, such as one of three Vite dev servers, show a second line as plain text: the folder the file is in, or for a process its working folder or command.
Below 600px each row is a card that puts each value under its label.

Pressing a row's name shows its details beside the list: the reason, what happens when it is freed, and the location, or for a process its memory, CPU share, start time, working folder, and command, each label beside its value.
A list of more than 10 lines, such as the places of an app leftover or the copies of a duplicate, folds until you open it.
A row that is deleted for good says so in its own notice, and a row that can be picked can also be picked or unpicked there.
The list and the details scroll apart, and the name of the shown row stays at the top of its details.
A list tab opens on its first row, and the address keeps the shown row as `#item-<id>`, so opening the page with that address shows that row in its tab.
Below 860px the list and the details take turns. Pressing a name opens the details in place of the list, with Back to the list above them and links to the previous and next rows under them, and Back in the browser also returns to the list.

Above the rows, these tools change what the tab shows; they never change what is picked.

| Tool | What it does |
|---|---|
| Search | Shows only the rows whose name or location holds the typed text, ignoring case. A search that finds nothing names the text and offers Clear filters |
| Kind | One button per kind with how many rows it has. Pressing one shows only that kind, and its explanation replaces the tab's |
| Levels | One button per level with how many rows it has. Turning a level off hides its rows |
| Sort | Pressing the Name or Size header, or Memory or CPU (%) in the Programs tab, sorts the rows inside each level by it. Pressing it again reverses the order |
| Pages | A tab with more than 50 rows shows 50 at a time, with a pager above and below the list. The line above the list says which rows are shown out of how many |

Clear picks unpicks every row of the tab and offers Undo, which puts those picks back.
The top right of the page says how many rows are picked and not sent, and while that is so the browser asks before you leave the page.
The bar at the bottom shows how many rows are picked and, apart from it, how much disk they free.
Pressing Free with nothing picked says so in the bar.
With rows picked, it opens a confirm window titled with how many items it frees, which lists each row under what freeing it does and says what can be put back, with Cancel and Free.

## What counts as in use

An item that is in use is listed, its details give the reason, and it cannot be picked, on the page or in `apply`.

| Reason | When |
|---|---|
| Runs under a live agent session | Following the parent processes up reaches `claude`, `codex`, `copilot`, or `gemini`, run directly or through `node`, `bun`, or `deno` |
| Is a live agent session | The process is one of those agents |
| A live agent session runs under it | Following an agent's parent processes up reaches this process, such as the app or terminal that hosts the session |
| Belongs to an app a live agent session runs in | The process runs from the same `.app` bundle as a process an agent runs under, such as the app's renderer or GPU helper |
| Works in a project a live agent session works in | The process's working folder is in the same git project as an agent's working folder, so a dev server the agent started and left to run in the background is kept |
| Runs in an open terminal | The process has a controlling terminal |
| Part of the operating system | The program is under `/System/`, `/usr/libexec/`, `/usr/sbin/`, `/sbin/`, or `/usr/lib/systemd/` |
| A running program works in this project | A process's working folder (from `lsof -d cwd` on macOS, `/proc/<pid>/cwd` on Linux) is inside the project that holds the item, or inside a Compose project's working folder for a container |
| The app is running | A process runs from inside the app bundle, or an app cache belongs to a running app |
| A tool is running | The package manager whose cache it is runs something other than a dev server, such as an install |

The agent that runs the scan and its parent processes are left out of the list entirely.
Processes of other users are never listed.

## Places it never enters

| Place | Why |
|---|---|
| `~/Library/Mobile Documents`, `~/Library/CloudStorage`, and `~/Dropbox`, `~/OneDrive`, `~/Google Drive`, `~/iCloud Drive`, `~/Box`, `~/pCloud Drive`, `~/Nextcloud`, `~/ownCloud`, `~/MEGA` | Sync folders. Deleting there deletes in the cloud and on your other devices too |
| `/mnt` under WSL | Windows drives |
| Symbolic links | The scan never follows them, and `apply` never changes a link or what it points to |
| Docker volumes | They hold data that is not rebuilt |
| Anything outside the home folder, except app bundles in the app folders | `apply` refuses to change it |

## The page and the server

`serve` reads `scan.json`, picks a free port on `127.0.0.1`, makes a one-time token, and serves the page there to the browser on this computer only.
It saves the port and the token in `session.json`, so running `serve` again keeps the same address for a page that is already open.

| Request | Accepted when |
|---|---|
| `GET /?t=<token>` | The token matches and the `Host` header is `127.0.0.1:<port>`. The response is the page with the scan built in |
| `GET /ping?t=<token>` | The same. The page asks every 4 seconds to show whether the agent is waiting |
| `POST /select` | The `Host` header and the `Origin` header both name this server, the body is JSON of at most 64 KiB with the token, and every id is in the scan and not in use |

Anything else gets 403 or 404, so another site open in the browser cannot read the page or send a selection.
The page and every response carry a Content-Security-Policy that allows no outside connection.

When the server accepts a selection, it prints `machine-cleanup:select <id> <id> ...` and ends, and the page says in its bar and at its top right when it was sent.
When the server refuses one, the bar shows the error as an alert with an icon, and the page asks again whether the agent waits.
When it waited `--wait` seconds (540 by default) without a selection, it ends with exit code 4.
The open page then shows a notice above the tabs that the agent is not waiting, and its confirm window offers Copy instead of Free.
Copy puts `machine-cleanup:select` on the first line and one id per line under it, in a read-only text box and on the clipboard. When the browser refuses the clipboard, the text box is selected for Command+C or Ctrl+C.
`apply --select` reads both forms, and neither depends on the page's language.

## The page's template

`serve` builds the page in memory from the template of the skill. Paths in the table are relative to `skills/machine-cleanup/`.

| File | What it holds |
|---|---|
| `templates/sheet.html` | The page, with its styles, its English and Japanese words, and its script inside. `serve` builds the scan into it |
| `musubi.json` | The optional follows of `page-design/structure`, `page-design/look`, `page-design/sheet`, and `page-design/verify` through musubi: for each, the version range `^1.0.0`, the fingerprint of the content at the last check, and `"optional": true` |

The page's header has the English / 日本語 switch and, next to it, a Light and Dark switch.
The colors follow the system setting until you choose, and the browser keeps both choices in its local storage under `machine-cleanup-lang` and `machine-cleanup-theme`. Nothing is sent anywhere.

- When the page-design skill of the design-formats plugin is installed, the agent reads its `structure` and `look` formats and its `sheet` page type, which `musubi.json` follows as optional follows. Since `serve` builds the page in memory, the agent runs page-design's `verify` on `templates/sheet.html` and tells you about any line it names. It reads nothing else from other plugins
- When the `musubi` command is installed, the agent runs `musubi check` before reading them and stops if it fails; the check skips the follows with a warning when design-formats is not installed. When a followed content changes, `musubi check` refuses machine-cleanup until its fingerprint is checked again
- Without page-design, the page comes from `templates/sheet.html` alone. Nothing in the plugin requires design-formats

## How each item is freed

`apply` takes that line, or the ids alone.
When any id is not in the scan, is in use, or picks every copy of a duplicate, it refuses the whole selection and changes nothing.

| Item | What `apply` does |
|---|---|
| Caches with a clean command | Runs `npm cache clean --force`, `pnpm store prune`, `yarn cache clean`, `bun pm cache rm`, `pip cache purge`, `uv cache clean`, `brew cleanup --prune=all`, `go clean -modcache`, `go clean -cache`, `pod cache clean --all`, `docker image prune -a -f`, `docker builder prune -a -f`, or `docker container prune -f`. When the tool is not installed, deletes the folder |
| Other caches and build output | Deletes the folder |
| Trash | Deletes everything in it |
| Old logs | Deletes the files listed in the scan that are still older than 30 days |
| Installers, large files, duplicates | Moves the file to the Trash: `~/.Trash` on macOS, and the freedesktop.org Trash with a `.trashinfo` record on Linux, so file managers can put it back |
| macOS apps | Moves the app and its support files (in `Application Support`, `Caches`, `Preferences`, `Containers`, `Saved Application State`, `HTTPStorages`, `WebKit`, and `Logs`) to the Trash |
| Flatpak apps | Runs `flatpak uninstall --user -y <app>` |
| Work folders and app leftovers | Moves the project folder, or every place of the leftover, to the Trash |
| Tool versions | Deletes the version folder and the links beside it that pointed at it, such as mise's `21` and `21.7`. A rustup toolchain is removed with `rustup toolchain uninstall <toolchain>` |
| AI models | While Ollama runs, runs `ollama rm <model>`. While it does not, deletes the model's manifest and the blobs no other model uses, as `ollama rm` does. Deletes a Hugging Face or LM Studio model's folder |
| Processes | Sends the end signal (SIGTERM) and waits `--term-wait` seconds (5 by default). A process still running is reported as `survived`, and only `apply --kill <id>` for that id sends SIGKILL |
| macOS LaunchAgents | Runs `launchctl bootout` and moves the file into the state folder |
| Linux autostart entries | Moves the file into the state folder |
| systemd user services | Runs `systemctl --user disable --now` |
| Containers | Runs `docker stop` |

## The check right before acting

`apply` runs `ps` and reads the working folders again, then checks each item before acting on it.
An item that fails a check is reported as `skipped` with the reason and left as it is.

| Item | Skipped when |
|---|---|
| Files | The size, modification time, or file number differs from the scan |
| Folders | The folder was replaced, or its size changed by more than 5% or 1 MB |
| Items in a project | A running program now works in the project |
| Work folders | The project gained a commit or a checkout in the last 30 days, uncommitted changes or untracked files, or a commit that is not on the remote |
| Tool versions | A running program now uses the version |
| Ollama models | The manifest changed |
| Processes | The process ended, or its start time or command differs, which means the process id now belongs to another program |
| Login items | The file changed or is gone |
| Containers | The container is no longer running |
| Docker caches | Nothing is left to free |

It measures free disk with `df -k`, memory used with `vm_stat` and `sysctl hw.memsize` on macOS or `/proc/meminfo` on Linux, and the load average, before and after, and prints them.
When it ran a Docker prune and Docker Desktop's disk image exists, it adds that the free space can rise later, because Docker Desktop gives the space back on its own over time.

## Restoring

`restore` lists what can be put back, and `restore <id>` puts it back.

| Item | What `restore` does |
|---|---|
| macOS LaunchAgents | Moves the file back and runs `launchctl bootstrap` |
| Linux autostart entries | Moves the file back |
| systemd user services | Runs `systemctl --user enable --now` |
| Files, apps, work folders, and app leftovers moved to the Trash | Moves them back while they are still in the Trash and nothing is in their old place |

## What it keeps

Everything lives in `~/.local/share/machine-cleanup/` (or `MACHINE_CLEANUP_HOME`), in a folder only you can read, with files only you can read.

| File | What it holds | Removed by |
|---|---|---|
| `scan.json` | The last scan | The next scan, or `finish` |
| `session.json` | The page's port and token | `apply`, or `finish` |
| `selection.txt` | The last selection the page sent | `apply`, or `finish` |
| `survivors.json` | Processes that survived the last `apply` | The next `apply`, or `finish` |
| `restore.json` | What `restore` can put back | `restore`, once an item is back |
| `disabled/` | Login item files that were stopped | `restore` |

Process commands are kept only after the values of flags and variables whose names contain token, secret, password, passwd, api-key, apikey, or auth are replaced with `***`.

## What it never does

- Deletes, moves, or stops anything you did not pick, or anything in use
- Follows a symbolic link, enters a sync folder or a Windows drive, or changes anything outside the home folder except app bundles
- Asks for or uses an administrator password, or touches other users' processes
- Sends anything over the network, or serves the page anywhere but `127.0.0.1`
- Changes operating system settings, or installs anything that runs in the background

## Environment variables

| Variable | Effect |
|---|---|
| `MACHINE_CLEANUP_HOME` | The state folder, instead of `~/.local/share/machine-cleanup` |
| The cache variables in "The scan" | Where each package manager's cache is looked for |
| The version manager and model variables in "The scan" | Where each version manager keeps its versions, and where models are looked for |

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Done |
| 1 | `apply` or `restore` refused, and nothing changed |
| 2 | Bad input, or no scan yet |
| 3 | `apply` could not free an item |
| 4 | `serve` waited without receiving a selection |
