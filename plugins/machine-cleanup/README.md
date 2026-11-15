# Machine Cleanup

Get disk space, memory, and CPU back on your computer by freeing only what you pick.

English · [日本語](README.ja.md)

Coding agents leave a lot behind: `node_modules` and build output in every project, package manager and Docker caches, Xcode's DerivedData, and dev servers and watchers that keep running after the session that started them ended.
This plugin measures all of it at the lowest priority, shows it on a page in your browser with the size or load of each item and what freeing it does, and frees only what you pick there.
Anything that a live agent session, an open terminal, or a running program in the same project uses is shown but cannot be picked, so a cleanup never breaks work in progress in another session.

```
Scan ──> Pick on the page ──> Check each pick again ──> Free it ──> Report before and after
 (agent)  (you)                (agent)                   (agent)     (agent)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install machine-cleanup@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add machine-cleanup@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install machine-cleanup@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/machine-cleanup/skills/machine-cleanup   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts when you say something like "my disk is full", "my Mac is slow", or "what is using all my memory?".
You can also call it: run `/machine-cleanup:machine-cleanup` in Claude Code, or type `$` and pick **Machine Cleanup** in Codex.
In GitHub Copilot CLI, write `/machine-cleanup` in your request, and in Gemini CLI, describe the task.

1. The agent scans, which takes up to 90 seconds at the lowest priority, and tells you the totals
2. A page opens in your browser. Pick the rows you want to free, press **Free**, check the summary, and press **Send to the agent**
3. The agent checks each pick again, skips any that changed or came into use, frees the rest, and reports free disk, memory, and load before and after
4. When a process ignores the end signal, the agent asks you before ending it at once

The page opens in English and has an English / 日本語 switch in its header.
When the agent stopped waiting for the page, press **Copy the selection** and paste the text into the chat.

## What it finds

| Tab | What it lists | What freeing it does |
|---|---|---|
| Caches | Caches of npm, pnpm, Yarn, Bun, pip, uv, Homebrew, Cargo, Go, Gradle, Maven, and CocoaPods, Docker images and build cache, Xcode DerivedData and device support, and app caches of 50 MB or more | The tool downloads or builds it again the next time it needs it. Where the tool has its own clean command, such as `npm cache clean --force`, `brew cleanup --prune=all`, or `docker builder prune`, that command runs |
| Build output | `node_modules`, `.next`, `dist`, `target`, `.venv`, and similar folders in git projects that git ignores and that hold no tracked file | Deleted. The next install or build makes it again |
| Trash and logs | The Trash, logs and crash reports older than 30 days, and installers in Downloads older than 30 days | The Trash is emptied and old logs are deleted for good. Installers move to the Trash |
| Large and duplicate files | Files of 500 MB or more, and files of 10 MB or more with the same content in several places | Moved to the Trash. At least one copy of each duplicate always stays |
| Apps | macOS apps not opened for 90 days that you can change without an administrator password, with their support files, and Flatpak apps installed for you on Linux | macOS apps move to the Trash with their support files. Flatpak apps are uninstalled |
| Processes | Dev servers, watchers, and test runs left running after their session ended, and the 15 processes that use the most memory or CPU | The process gets the end signal, so it can save its work. It is ended at once only when you pick it again |
| Login items | macOS LaunchAgents in your Library, and autostart entries and systemd user services on Linux | Stopped, and kept so that the agent can turn it back on |
| Containers | Running Docker containers | Stopped. Their data stays |

## What it keeps out of reach

- Anything a live agent session (Claude Code, Codex, GitHub Copilot CLI, or Gemini CLI) or an open terminal runs, and every item in a project where a running program works. These rows show why and cannot be picked
- Sync folders such as iCloud Drive, Dropbox, Google Drive, and OneDrive, because deleting there deletes in the cloud too, and Windows drives under WSL
- Symbolic links and what they point to, files git tracks, and Docker volumes
- Anything that needs an administrator password, and other users' processes
- Operating system settings such as swap and indexing

## Requirements

| Tool | When it's needed |
|---|---|
| `python3` | Always, on macOS, Linux, or WSL |
| `ps`, `du`, `df` | Always. Built into macOS and Linux |
| `lsof` | On macOS, to tell which projects running programs work in. Built into macOS. Linux reads `/proc` instead |
| `git` | To tell build output from tracked files |
| `docker` | Optional. When it is installed and running, its caches and running containers are listed |
| npm, pnpm, Yarn, Bun, pip, uv, Homebrew, Go, CocoaPods | Optional. When one is installed, its own clean command frees its cache. Without it, the cache folder is deleted |
| `flatpak` | Optional, on Linux, to list Flatpak apps |
| A web browser | To pick on the page |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) explains the scan, what counts as in use, the page and its server, and the check before each change.
In short:

- It reads the sizes and dates of files and folders in your home folder and app folders, reads the contents of files of 10 MB or more that have the same size as another file to tell duplicates apart, and lists your processes, login items, and containers
- It runs `ps`, `du`, `df`, `lsof`, `git`, `mdls` on macOS, and, when they are installed, `docker`, `flatpak`, and the package managers' clean commands
- It serves the page only on `127.0.0.1` with a one-time token and accepts a selection only from that page. It sends nothing over the network
- It changes only what you picked, after checking it again. It never asks for or uses an administrator password
- It hides values of command-line flags and environment variables whose names suggest a token, secret, password, or API key before a process command reaches the page or a file
- It keeps the scan, the page session, and what `restore` needs in `~/.local/share/machine-cleanup/`, readable only by you. `finish` removes everything but the restore records

## License

[MIT](LICENSE)
