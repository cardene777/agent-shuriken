# Changelog

Releases of the portman plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- The chat report follows the `structure` format of page-design in the design-formats plugin through musubi, as an optional follow declared in `skills/portman/musubi.json`: the result first, what was done and skipped with the reasons, ports not tested written as not tested, and the user's steps last. When the `musubi` command is installed, the agent runs `musubi check` before reading the format. Without design-formats, the skill reports in its own order
- When the registry folder, its lock file, or the registry cannot be written, `add`, `remove --confirm`, and `apply --confirm` refuse with exit code 2, the path with the home folder shortened to `~`, and what to fix, instead of stopping with a Python traceback that shows the full path. When `apply --confirm` cannot write a project file, it refuses the same way and names the files it already wrote

## [0.3.1] - 2026-11-18

- Every command stops without a traceback and exits 141 when the reader closes the output pipe, as in `portman.py doctor | head -1`, and `remove --confirm` and `apply --confirm` finish writing their changes before they print anything
- The refusals for a registry that cannot be read or used print its path with the home folder shortened to `~`, like the other messages, instead of the full path with the account name

## [0.3.0] - 2026-11-16

- When the socket test is refused, as inside a sandbox, `list` and `check` show the ports that `lsof` does not see as `unknown` instead of `free`, `doctor` lists them under `[Not tested]`, and `suggest` says that its ports could not be tested
- The refusal for a registry written by a newer portman says to update the plugin instead of editing the file, and the refusal for a port that is already registered names `suggest`
- The `SKILL.md` is shorter: the tables of arguments, exit codes, notes, and failures that the script's help and messages already give are gone, and the description says only what the skill does and when to use it
- The plugin has `claude plugin eval` cases under `evals/` that measure the skill, run by hand

## [0.2.0] - 2026-11-14

- `doctor` lists under `[Folders gone]` the ports of projects whose recorded folder no longer exists, such as a removed git worktree, and counts them as problems
- The README says that the init-project plugin registers its ports in this registry

## [0.1.0] - 2026-11-12

First public release.

- Keeps a registry of the localhost ports each project uses in `~/.local/share/portman/registry.json`, readable only by you, and refuses a port that another project already has
- Lists every registered port with what holds it right now, a process named with `lsof` or a Docker container, and whether that is the project itself or another program
- Suggests free ports that are not registered, not in use on this machine, and not a default that popular tools take, such as 3000, 5173, 8000, and 8080
- Finds ports registered twice, registered ports held by another program with a free port to move to, and ports in use outside the registry, and shows what it could not read as unknown instead of none
- Writes a project's port variables between marker lines in `.env.local`, leaving every other line as it is, and a Docker Compose override that replaces the published ports, only after you approve the change it shows
- Removes ports only after you approve the entries it shows, and skips an entry that changed in between
- Starts when a port is already in use, when two projects want the same port, or when you set up ports for a project, in Claude Code, Codex, GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/portman--v0.3.1...HEAD
[0.3.1]: https://github.com/cardene777/agent-shuriken/releases/tag/portman--v0.3.1
[0.3.0]: https://github.com/cardene777/agent-shuriken/releases/tag/portman--v0.3.0
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/portman--v0.2.0
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/portman--v0.1.0
