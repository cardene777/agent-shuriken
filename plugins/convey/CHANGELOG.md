# Changelog

Releases of the convey plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

- The fingerprint of `japanese-writing/connecting` in `musubi.json` matches japanese-writing again, whose `SKILL.md` now also lists its writing rules as a content other skills follow; the guide to connecting sentences did not change

## [0.3.0] - 2026-11-24

- `musubi.json` follows `japanese-writing/connecting`, the guide to connecting sentences, as an optional musubi follow. When the `musubi` command is installed, the agent runs `musubi check` before reading the guide, and the check refuses convey when the guide changed after the last check. Without japanese-writing, convey writes as before

## [0.2.0] - 2026-11-16

- Before writing, the agent lists the facts in the source and keeps only what the reader cannot get by opening the files, screens, or links the message points to: what arrived or changed, what to do first, where the reader may get stuck, and what is undecided or asked. Every line, list items included, is a full sentence, and a short message has no headings
- `convey.py check` warns about lines written as a label and a colon, and about a space between Japanese and a Latin letter or digit
- A new eval case, `handoff-message`, measures whether a long handoff becomes a short message that keeps what the developer needs and leaves out what the files explain
- The agent starts a sentence with a connecting word where the reader would otherwise have to guess how it follows from the one before, and for Japanese reads the japanese-writing skill's guide to connecting sentences when that skill is installed. The `handoff-message` and `long-report-to-discord` cases check that at least two sentences start with a conjunction

## [0.1.0] - 2026-11-15

First public release.

- Writes a message that tells people what they need from the work in the conversation, pasted text, issues and pull requests, or commits, with the conclusion on the first line and without preambles, restatements, or sign-offs
- Decides who the message is for from the request, the destination, and the content, and says so in one line outside the message
- Follows one of seven types, progress, decision, request, incident, findings, announcement, and question, each listing the parts its reader needs in order
- Mentions only the people and channels you named, and uses at most one emoji at the start of a heading in Slack and Discord
- Checks the message for Slack, Discord, an email, a GitHub comment, or plain text with `convey.py check`: the length limit with where to split a long message, formats the destination shows as typed, an email without a subject line, filler phrases in Japanese and English, and secret-looking values, local paths, email addresses, and phone numbers, which it reports without printing them
- Copies the message to the clipboard with `convey.py copy` after the same check, and never sends anything
- Follows the japanese-writing skill for Japanese when it is installed
- Starts when you ask to share, report, announce, or ask for something in a message, or when you call it, in Claude Code, Codex, GitHub Copilot CLI, Gemini CLI, and other agents that read `SKILL.md`

[Unreleased]: https://github.com/cardene777/agent-shuriken/compare/convey--v0.3.0...HEAD
[0.3.0]: https://github.com/cardene777/agent-shuriken/releases/tag/convey--v0.3.0
[0.2.0]: https://github.com/cardene777/agent-shuriken/releases/tag/convey--v0.2.0
