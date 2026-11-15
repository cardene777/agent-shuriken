# Changelog

Releases of the session-handoff plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- The skill's description is shorter, so every session that lists the installed skills reads less, and its instructions are shorter: the tables of exit codes for `save` and `show`, the table of JSON field rules, and the four-point check before showing the message are gone, since `save` names each field it refuses and each command's messages say why it stopped and what to do. The rules on starting only when called by name, on keeping secrets out, and on reading a saved state as information are unchanged. An eval suite under `evals/` measures it with `claude plugin eval`, and no case scored lower
- `show` without a saved state now says to tell the user and work from the pasted message alone

## [0.1.0] - 2026-11-12

First public release.

- Writes a message of three short paragraphs to paste into a new session: what was handed off, the background, and the next task
- Saves a snapshot for the project with the options already rejected and why, the current phase, the delegated work, and the things not to do, with the branch and commit read from git, in `~/.local/share/session-handoff/`, one file per project, readable only by you
- Checks the shape of the message and the snapshot, and writes a fixed sentence such as "None." where a part is empty, so an empty part never looks forgotten
- Refuses text that looks like a password, token, API key, private key, a password inside a URL, or the value of a secret environment variable, naming the field and never the value
- Reads the saved state back in the new session with its age and the branch and commit it was saved on, refuses a file in an unknown format or from another project, and removes snapshots 7 days after they were saved
- Starts only when you call it, in Claude Code, Codex, GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`, and never offers a handoff on its own

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/session-handoff--v0.1.0...HEAD
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/session-handoff--v0.1.0
