# Changelog

Releases of the machine-cleanup plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

### Fixed

- The confirm dialog shows the number of items apart from their size, such as `4 items, 807.4 MB`, instead of running them together as `4 807.4 MB`

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
