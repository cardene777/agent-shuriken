# Changelog

Releases of the portman plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

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

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/portman--v0.2.0...HEAD
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/portman--v0.2.0
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/portman--v0.1.0
