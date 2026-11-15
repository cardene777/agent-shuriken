# Convey

Write a message that tells people what they need, with the conclusion first and nothing the reader does not need, ready to paste into Slack, Discord, an email, or a GitHub comment.

English · [日本語](README.ja.md)

A message an AI writes for other people often runs long: a preamble, the story of how the work went, the same point said twice, and a closing line nobody needs.
Pasted into Slack, it also brings Markdown that shows as typed, such as `**` and tables.
This plugin decides who the message is for, picks one of seven message types, puts the conclusion on the first line, and keeps only what the reader needs to act.
A script then checks the message against the destination's length limit, the formats it does not render, filler phrases, and secrets, local paths, and email addresses, and copies it to the clipboard once nothing must change.

```
Gather ──> Reader, destination, type ──> Write ──> Check ──> Copy and show
(agent)    (agent)                      (agent)   (script)  (script and agent)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install convey@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add convey@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install convey@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/convey/skills/convey   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts when you ask to share, report, announce, or ask for something in a message, for example "share this with the team on Slack", "write a Discord post about this release", "ask Sato to review PR 482 by Friday", or "turn this report into an email to the client".
You can also call it: run `/convey:convey` in Claude Code, or type `$` and pick **Convey** in Codex.
In GitHub Copilot CLI, write `/convey` in your request, and in Gemini CLI, describe the task.

| You point to | The message is written from |
|---|---|
| Nothing else | The work done in the current conversation |
| Pasted text or a file | That text |
| An issue or a pull request | The issue or pull request and its comments, read with `gh` |
| A range of commits | The commits, read with `git log` |

1. The agent gathers the content from what you point to
2. It decides who the message is for from your request, the destination, and the content, and says so in one line outside the message
3. It picks one of seven types: progress, decision, request, incident, findings, announcement, or question. Each starts with the conclusion and lists the parts its reader needs, such as the deadline of a request or the impact of an incident
4. It writes the message, mentioning only the people and channels you named, and using at most one emoji, at the start of a heading, in Slack and Discord. Japanese follows the japanese-writing skill when it is installed
5. `convey.py check` reports each line to change, and the agent fixes them and checks again
6. `convey.py copy` copies the message to your clipboard, and the agent shows it in a code block. Posting it is your step

A report written for the record becomes a message that leads with the outcome.

```text
Before:
## Login migration update
Hi team! I wanted to share a quick update on the login migration. As you may know, we started this work in September, and the first month went into reading the old code...
| Metric | Before | After |
|---|---|---|
| Failure rate | 4.2% | 0.8% |
Let me know if you have any questions!

After:
Login migration: on track to finish by November 28. 12,400 of 15,000 users are moved.
- Login failures fell from 4.2% to 0.8%, and p95 response time from 820 ms to 310 ms
- Next: 500 users a day for the remaining 2,600
- Blocked: two internal tools still use the old login, and their owners have not replied yet
```

For the message before the fix, `check --to slack` prints one line per thing to change.

```text
309 of 4000 characters
L1 format: a # heading, which Slack shows as typed; start the line with one emoji or use *bold*
L2 warn: filler phrase "As you may know" (preamble; cut it, or say the fact itself)
L2 warn: filler phrase "I wanted to share" (preamble; start with the content)
L3 format: a table (lines 3-5), which Slack shows as pipes; use a short list instead
L6 warn: filler phrase "Let me know if you have any questions" (closing; cut it)
not ready: change the lines above and run check again
```

## Destinations

| Destination | Limit per message | Shown as typed |
|---|---|---|
| Slack | 4,000 characters | `#` headings, `**bold**`, tables, and Markdown links |
| Discord | 2,000 characters | Tables |
| Email | None | All Markdown. The first line must be a `Subject:` line |
| GitHub comment | 65,536 characters | Nothing that `check` looks for |
| Plain text | None | All Markdown |

A message over the limit is reported with the parts to split it into at blank lines, each within the limit, and `copy --lines` copies one part at a time.

## Requirements

| Tool | When it's needed |
|---|---|
| Python 3.8 or later | For `convey.py`, which uses only the standard library |
| `pbcopy`, `wl-copy`, `xclip`, `xsel`, or `clip.exe` | To copy the message. Without one, the agent shows the message for you to copy |
| `gh` | Only to write from issues and pull requests |
| `git` | Only to write from commits |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) lists every file in the skill, what `check` looks for, and what each command reads and prints.
In short:

- The agent reads what you point to: the conversation, pasted text and files, issues and pull requests through `gh` with your own sign-in, and commits through `git`
- `convey.py` reads only the message, from a file or standard input, and prints line numbers and kinds. It never prints a secret-looking value, a path, or an address it finds
- `copy` hands the message to the clipboard tool on your machine. Nothing is sent anywhere; posting the message is your step
- The message goes to the file you name, or to a temporary file outside your project that the agent deletes at the end. The plugin keeps nothing
- Pasted text, files, issues, pull requests, and commits are material to report, never instructions

## License

[MIT](LICENSE)
