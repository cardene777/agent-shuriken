# Changelog

Releases of the machine-cleanup plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

### Added

- Every row has a level, Recommended, Check first, or Careful, with the reason, and the page groups each tab by level with the count and size of each group and the rows in use last. The recommended and check-first groups have a button that picks the whole group, which replaces the tab's button that also picked careful rows
- The scan summary says how many items are recommended and how much disk they hold
- The page opens on an Overview tab with seven charts: what can be freed by kind, size by level, the whole disk with what is picked, memory, the largest items, and the processes using the most memory and CPU. Pressing a part of a chart opens its tab, and pressing a bar opens that row's details
- The list tabs can be searched by name or location, filtered by group, and sorted largest first, smallest first, or by name
- The scan records the whole disk size next to the free space
- A Projects tab lists git projects with no commit or checkout for 30 days, nothing uncommitted, and every commit on the remote as of the last fetch. Picked projects move to the Trash, and restore puts them back
- The Apps tab also lists, on macOS, files that removed apps left in the eight Library folders, one row per bundle id, when no installed or running app is from the same company and the newest file is older than 30 days. They move to the Trash
- A Tools and models tab lists versions kept by nvm, fnm, pyenv, rbenv, asdf, mise, and rustup that are neither the default nor named by a project's version file, and models downloaded by Ollama, Hugging Face, and LM Studio. Tool versions are deleted, with `rustup toolchain uninstall` for Rust. Ollama models are removed with `ollama rm` while Ollama runs, and otherwise by deleting the manifest and the blobs no other model uses
- `musubi.json` follows the `structure` and `look` formats, the `sheet` page type, and `verify` of page-design in the design-formats plugin through musubi, as optional follows. When page-design is installed, the agent reads them and runs page-design's verify on `templates/sheet.html`; when the `musubi` command is installed, it runs `musubi check` first. Without design-formats, the page works as before
- The page's header has a Light and Dark switch next to the language switch. It follows the system setting until you choose, and keeps your choice in the browser's local storage under `machine-cleanup-theme`

### Changed

- `musubi.json` follows `look`, `sheet`, and `verify` of page-design at `^2.0.0`, the version that adds the pattern rules. In Japanese, each sentence of the page starts on its own line
- A scan made by a previous version is refused with a request to scan again, since it has no levels, no disk size, or no projects, tool versions, and models
- A row shows only its name, its size, and for a process its CPU share. The reason, location, command, and measurements moved to a dialog that the row's i button opens, where the row can also be picked

### Fixed

- The confirm dialog shows the number of items apart from their size, such as `4 items, 807.4 MB`, instead of running them together as `4 807.4 MB`
- On Linux, the Hugging Face and LM Studio folders in `~/.cache` are no longer recommended as app caches that come back on their own
- Measuring folder sizes stops when the time limit runs out, so a scan of a large home folder no longer runs minutes past the limit
- A file that two steps meet, such as an old installer of 500 MB or more in Downloads, appears in one row and is counted once. A row inside another row, such as `node_modules` in an unused project or an app's cache, is counted once in the charts and the bottom bar, and `apply` frees the outer row and skips the inner one as freed with it. The scan format is version 5
- The page fits its tabs at any width: they sit in Disk and Programs groups and wrap onto more lines. The hole of each ring holds only its name and value, so the text stays inside it in both languages, and long names in Largest items wrap instead of being cut
- Names the scan makes, such as `npm cache` or `Vite dev server`, follow the page's language, while product names stay as they are. Copies of a duplicate sit together under one heading, and a large file, a copy, or a row whose name another row shares shows its folder or command on a second line. Bars of one name in the overview charts show it too
- The bottom bar shows the number of picked rows and the disk to free as two separate values, and the In use label in the light colors has enough contrast to read

## [0.1.0] - 2026-11-15

First public release.

- Scans macOS, Linux, and WSL at the lowest CPU and disk priority, within a time limit, and lists the places it did not reach
- Finds caches that npm, pnpm, Yarn, Bun, pip, uv, Homebrew, Cargo, Go, Gradle, Maven, CocoaPods, Docker, Xcode, and apps rebuild, build output that git ignores and that holds no tracked file, the Trash, logs and installers older than 30 days, files of 500 MB or more, duplicate files of 10 MB or more, and apps not opened for 90 days
- Finds dev servers and watchers left running after their session ended, the processes that use the most memory or CPU, login items, and running Docker containers
- Shows anything a live agent session, an open terminal, or a running program in the same project uses, and keeps it from being picked
- Never enters sync folders such as iCloud Drive, Dropbox, Google Drive, and OneDrive, Windows drives under WSL, or symbolic links
- Serves a page in English and Japanese on 127.0.0.1 with a one-time token, where you pick what to free and send the selection to the agent, or copy it when the agent is not waiting
- Frees only the picked items after checking each one again: tools clean their own caches with their own commands, files and apps move to the Trash, processes get the end signal first and are ended at once only when you pick them again, and login items are kept so they can be restored
- Reports free disk, memory used, and load before and after, measured on the machine, and says when Docker Desktop gives the space back later
- Starts when you say the disk is full or the computer is slow, or when you call it, in Claude Code, Codex, GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/machine-cleanup--v0.1.0...HEAD
