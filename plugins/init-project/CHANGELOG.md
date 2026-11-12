# Changelog

Releases of the init-project plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

## [0.1.0] - 2026-11-12

First public release.

- Tells what kind of project a folder is (web app, CLI, library, smart contract, or unknown), with its runtime, package manager, dev command, Docker files, and env files
- Picks a local port from 3100 up that nothing listens on, that common tools such as 3000, 5173, 8000, and 8080 are not using, and that no other project set up with it has, and records it in `~/.local/share/init-project/ports.json`, readable only by you
- Writes a Docker setup for Node and Python web apps and for Foundry and Hardhat local chains: a `Dockerfile`, a `.dockerignore`, a compose file without ports, and an override file that binds the local port to 127.0.0.1 and stays out of git
- Links env files to 1Password by writing a `.tpl` file of `op://` references for each one and printing the commands you run in your own terminal to store the values, so no value passes through the agent
- Shows every file first and writes only after you approve, keeps existing files unless you name one to replace, and checks each file and the port again right before writing
- Starts when you ask to set up a project, add Docker, or move environment variables into 1Password, or when you call it, in Claude Code, Codex, GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/init-project--v0.1.0...HEAD
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/init-project--v0.1.0
