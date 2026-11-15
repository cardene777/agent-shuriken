# Changelog

Releases of the convey plugin, newest first.
Versions follow semantic versioning: a major release changes how the plugin is called or what it stores, a minor release adds behavior, and a patch release fixes behavior.

## [Unreleased]

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
