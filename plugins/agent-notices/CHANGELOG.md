# Changelog

Releases of the agent-notices plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

## [0.1.0] - 2026-11-24

- Eleven hooks for Claude Code and Codex that add a notice for the agent and never stop a call: pipefail-grep, nohup, grep-binary, branch, env-example, tmp-space, security, format, presence, skill-log, and mcp-log
- The pipefail-grep, nohup, and grep-binary hooks point out a pipe into `grep -q` under `pipefail`, a `nohup` command sent to the background, and a Grep that skipped a binary file holding the pattern
- The branch hook points out a `git switch` or `git checkout` that left the repository on another branch, and a `git commit` on a branch the session did not switch to
- The env-example hook points out a read of an environment variable in JavaScript, TypeScript, Python, Go, Ruby, or Rust that `.env.example` does not list, and the tmp-space hook a temporary directory with less free space than `AGENT_NOTICES_TMP_MIN_GB`
- The security hook adds the reminders of the patterns of Anthropic's `security-guidance` plugin, whose `patterns.py` is copied unmodified under the Apache License 2.0
- The format hook runs the project's own Biome, Prettier, Ruff, Black, `gofmt`, or `rustfmt` on each edited file and installs nothing
- The presence hook creates the file `CLAUDE_CLIENT_PRESENCE_FILE` names at session start and removes it at session end
- The skill and MCP logs, off unless `AGENT_NOTICES_SKILL_LOG=on` or `AGENT_NOTICES_MCP_LOG=on`, write names, times, durations, and outcomes, never arguments or results
- Each hook turns off with its own `AGENT_NOTICES_*` variable

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/agent-notices--v0.1.0...HEAD
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/agent-notices--v0.1.0
