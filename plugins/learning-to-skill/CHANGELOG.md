# Changelog

Releases of the learning-to-skill plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- The skill's description is shorter, so every session that lists the installed skills reads less, and its instructions are shorter: the tables of exit codes for `check`, `propose`, and `apply`, the table of `propose` options, and the table of the notes `files` prints are gone, since each command's messages say why it stopped and what to do, `propose --help` describes every option, and the notes are plain words such as `imported by CLAUDE.md`. The rules on approval, on keeping secrets out of instruction files, and on writing each rule once are unchanged. An eval suite under `evals/` measures it with `claude plugin eval`, and no case scored lower

## [0.1.1] - 2026-11-13

- The README's sample proposal ends with the line that tells the agent to run `apply` with `--expect` and the fingerprint, so the sample shows how a change that was not approved, or a file that changed, is never written

## [0.1.0] - 2026-11-12

First public release.

- Lists the instruction files in a project (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.github/copilot-instructions.md`, `.claude/rules/`, `.github/instructions/`, and the skills' `SKILL.md` files), which of Claude Code, Codex, GitHub Copilot CLI, and Gemini CLI read each one, following links and `@` imports, and the file that reaches the most agents
- Points out lines repeated across those files and files over the size budget, including AGENTS.md files past the 32 KiB that Codex reads
- Checks that a new rule is not already written, also when the wording differs or the words have no spaces between them
- Shows every change as a diff with a fingerprint, and writes exactly that change only after you approve it, refusing when the file changed in between, and keeping the file's permissions, line endings, and links
- Lists the instruction files in your home folder with `--home`, for lessons about you rather than one project
- Never commits, sends nothing, and keeps no files of its own
- Starts when you ask the agent to remember a lesson, or when you call it, in Claude Code, Codex, GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/learning-to-skill--v0.1.1...HEAD
[0.1.1]: https://github.com/cardene777/agent-shuriken/releases/tag/learning-to-skill--v0.1.1
[0.1.0]: https://github.com/cardene777/agent-shuriken/releases/tag/learning-to-skill--v0.1.0
