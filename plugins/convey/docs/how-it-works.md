# How it works

English · [日本語](how-it-works.ja.md)

This page describes what Convey reads, runs, and keeps, and what `convey.py` checks.
The agent writes the message; the script in `skills/convey/scripts/` only checks it and copies it.

## Files in the skill

Paths are relative to `skills/convey/`.

| Path | What it holds |
|---|---|
| `SKILL.md` | The rules and the five steps, from gathering the content and choosing what the message carries to showing it |
| `references/types.md` | The seven message types, each with its parts in order, starting with the conclusion |
| `references/filler-phrases.tsv` | The Japanese and English phrases `check` warns about, each with a hint |
| `scripts/convey.py` | The `check`, `copy`, and `formats` commands |
| `agents/openai.yaml` | The skill's name and default prompt in Codex |
| `tests/test-convey.sh` | The plugin's checks |

## What check looks for

`convey.py check --to <destination> [file]` reads the message from the file, or from standard input when the file is missing or `-`.
It prints the length, one line per finding as `L<line> <kind>: ...`, and then `ready to paste` or `not ready`.

| Kind | Exit code | What it means |
|---|---|---|
| `over the limit` | 1 | The message is longer than the destination allows. The lines after it give the parts to split it into at blank lines outside code fences, each within the limit |
| `format` | 1 | A format the destination shows as typed, or an email whose first line is not a `Subject:` line |
| `secret` | 1 | A value that looks like a GitHub, AWS, Slack, OpenAI, Anthropic, or Google key, a webhook URL, a private key, a JSON web token, a URL with a password, or a password or token written after `password=` or a similar name |
| `private` | 1 | A path under a user's home folder, such as one under `/home/`, an email address, or a phone number |
| `warn` | 0 | A filler phrase from `references/filler-phrases.tsv`, a line written as a short label and a colon, a space between Japanese and a Latin letter or digit outside code, URLs, paths, and mentions, or an emoji the destination usually does without |

A finding names the line and the kind, never the value it found.
Lengths count UTF-16 code units after trailing blank lines are dropped, so some emoji count as two, which keeps the count on the safe side.
The limits are 4,000 for Slack, the length Slack advises a message to stay under, 2,000 for Discord, its limit without a paid plan, and 65,536 for a GitHub comment.
`convey.py formats` prints each destination with its limit and what it does not render.

## What it runs and connects to

- The agent runs `python3 convey.py` from the skill folder, and imports only the Python standard library
- `copy --to <destination> [--lines A-B] [file]` runs the same check on the message, or on lines A to B only, and refuses with exit 1 when a line must change. Otherwise it looks for `pbcopy`, `wl-copy`, `xclip`, `xsel`, and `clip.exe` on `PATH` in that order, and gives the text to the first one that succeeds; `clip.exe` gets it as UTF-16. When none is found or every one fails, it prints `not copied` and exits 3
- The agent runs `gh issue view`, `gh pr view`, `git log`, and `git show` only when you point to an issue, a pull request, or commits. `gh` uses your own sign-in
- Nothing is sent anywhere, and the plugin never posts a message. The script reads one message and prints to the terminal

## What it keeps

Nothing.
The message goes to the file you name, or to a temporary file outside your project that the agent deletes when it finishes.
The clipboard holds the message until you copy something else.
