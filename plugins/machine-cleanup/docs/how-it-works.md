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
| Caches | The default folder of each package manager, honoring the variables that move it (`npm_config_cache`, `PNPM_STORE_DIR`, `YARN_CACHE_FOLDER`, `BUN_INSTALL_CACHE_DIR`, `PIP_CACHE_DIR`, `UV_CACHE_DIR`, `HOMEBREW_CACHE`, `CARGO_HOME`, `GOPATH`, `GOMODCACHE`, `GOCACHE`, `GRADLE_USER_HOME`, `XDG_CACHE_HOME`, `XDG_DATA_HOME`), Xcode's folders on macOS, app caches of 50 MB or more in `~/Library/Caches` or `~/.cache`, and `docker system df` |
| Trash and logs | The Trash, files older than 30 days in `~/Library/Logs` on macOS or log files in `~/.local/state` on Linux, and installers older than 30 days in `~/Downloads` |
| Apps | On macOS, `.app` bundles in `/Applications` and `~/Applications` (or `--apps-dir`) that you can change, whose last use `mdls` reports as more than 90 days ago. On Linux, `flatpak list --user --app` |
| Files | A walk of the home folder (or each `--root`) up to 8 levels deep, which skips hidden folders, `~/Library` and `~/Applications` on macOS, and the places in "Places it never enters" |

During the walk, a folder that holds `.git` is a project.
Folders named `node_modules`, `.next`, `.nuxt`, `.svelte-kit`, `.turbo`, `.parcel-cache`, `.vite`, `.angular`, `.expo`, `.docusaurus`, `.output`, `.vercel`, `.wrangler`, `dist`, `build`, `out`, `target`, `.venv`, `venv`, `__pycache__`, `.pytest_cache`, `.mypy_cache`, `.ruff_cache`, `.tox`, `.gradle`, `DerivedData`, `coverage`, `.cache`, and `Pods` within four levels of the project's top are build output only when `git check-ignore` says git ignores them and `git ls-files` finds no tracked file inside.
Build output under 1 MB is not listed.

Files of 10 MB or more are duplicate candidates.
Two files are duplicates when they have the same size, the same SHA-256 of their first 64 KiB, and the same SHA-256 of their whole content; hard links to one file count once.
This is the only time the scan reads file contents, and it keeps only the hashes.
Files of 500 MB or more that have no duplicate are large files.

The result goes to `scan.json` in the state folder.
Each item has an id (`d-` and eight hex digits for disk items, `p-` for processes, login items, and containers), a category, a kind, a size or memory use, whether it comes back on its own, how it is freed, the reason it is in use when it is, and a fingerprint for the check before acting.
The file also keeps the free and whole disk from `df`, the memory in use and in all, and the load, which the overview tab draws.

## How rows are ranked

The scan gives every item one of three levels and a reason, and the page groups each tab by level, with the rows in use last.
The level only orders the rows and explains them; `apply` checks every pick the same way whatever its level.

| Level | Items | Reason shown |
|---|---|---|
| Recommended | Caches that tools rebuild, build output of a project with no commit for more than 30 days, the Trash, logs and installers older than 30 days, and dev servers still running after their session ended | Rebuilt the next time it is needed, how many days the project has had no commit, or how old the files are |
| Check first | Build output of a project with a commit in the last 30 days, large files, duplicates, unused apps, login items, and a `next-server` process, since `next start` runs under the same name | How many days since the last commit or since the app was opened, or that the item can be put back |
| Careful | Heavy processes and running containers | Ending it stops its work |

The headings of the recommended and check-first groups have a button that picks every row in the group except duplicates, which are picked one copy at a time so that one copy always stays.
The careful and in-use groups have no such button, and the page opens with nothing picked.

## The overview tab

The page opens on the overview tab, which draws the scan as seven charts.
Pressing a part of a ring or a legend row that leads to a tab opens that tab, and pressing a bar opens the details of that row.
A value the scan could not measure is shown as "Not measured", never as zero.

| Chart | What it shows |
|---|---|
| What can be freed | The disk each kind of row gives back, without rows in use and keeping one copy of each set of duplicates. The line below is how much of it is rebuilt on next use |
| Size by level | The same disk split into recommended, check first, and careful, with the rows in use apart. The line below is the free disk after freeing every recommended row |
| Disk | The whole disk as what you picked, what can be freed but is not picked, other use, and free space. The line below is the free disk after freeing what you picked |
| Memory | Memory used by processes that can end, by processes in use, by everything else, and free memory. Containers are left out, since the process that runs them already counts their memory. The line below is the load over the last minute |
| Largest items | The 8 largest rows on disk, coloured by their group |
| Processes using the most memory | The 6 processes that use the most memory |
| Processes using the most CPU | The 6 processes with the highest CPU share between the two `ps` samples |

A row in the other tabs shows only its name, its size, and for a process or container its CPU share.
The i button at the end of the row opens a dialog with the reason, what happens when it is freed, and the location, or for a process its memory, CPU share, start time, working folder, and command.
A row that can be picked can also be picked or unpicked in that dialog.
Above the rows, three tools change what the tab shows; they never change what is picked.

| Tool | What it does |
|---|---|
| Search | Shows only the rows whose name or location holds the typed text, ignoring case |
| Groups | One button per group. Turning a group off hides its rows |
| Sort | Orders the rows inside each group largest first, smallest first, or by name |

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

When the server accepts a selection, it prints `machine-cleanup:select <id> <id> ...` and ends.
When it waited `--wait` seconds (540 by default) without one, it ends with exit code 4, and the open page shows that the agent is not waiting and offers Copy the selection, which copies the same line.
The line does not depend on the page's language.

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
| Files and apps moved to the Trash | Moves them back while they are still in the Trash and nothing is in their old place |

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

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Done |
| 1 | `apply` or `restore` refused, and nothing changed |
| 2 | Bad input, or no scan yet |
| 3 | `apply` could not free an item |
| 4 | `serve` waited without receiving a selection |
