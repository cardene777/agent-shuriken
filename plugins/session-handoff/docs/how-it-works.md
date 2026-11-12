# How Session Handoff works

English · [日本語](how-it-works.ja.md)

This page explains what the agent writes, the checks the script runs, where the snapshot is kept, and how a new session reads it back.
The agent writes the text from the conversation.
Everything else is done by `skills/session-handoff/scripts/session_handoff.py`, which uses only the Python standard library and `git`.

## What the agent writes

The agent passes one JSON object to `session_handoff.py save`, on standard input or with `--input <file>`.

| Field | Holds | Limits |
|---|---|---|
| `message.handoff` | What was handed off: the decisions, the finished changes, and their issue, pull request, and commit | Required, 1 or 2 lines, at most 400 characters |
| `message.background` | Why the task matters | Required, 1 or 2 lines, at most 400 characters |
| `message.task` | What to do next, on what, and how far | Required, 1 or 2 lines, at most 400 characters |
| `snapshot` | The state to keep, or `null` when there is nothing to record | Required key |
| `snapshot.rejected` | Options turned down, each with `option` and `reason` | Required list, up to 20 items |
| `snapshot.phase` | Where the work stands: the issue, the branch, the steps finished, and the next step | Required, up to 3 lines and 800 characters, `""` when no work is in progress |
| `snapshot.delegated` | Work running elsewhere, each with `work`, `expected`, and `waiting` (`true` or `false`) | Required list, up to 20 items |
| `snapshot.do_not` | Actions the new session must not take, each with `action` and `reason` | Required list, up to 20 items |
| `snapshot.issue` | The issue the work belongs to, such as `#12` | Optional, 1 line, at most 100 characters |

Each text inside a list item is one line of at most 500 characters.
A part with nothing in it is given as `[]` or `""`, never left out, so a forgotten part and an empty one never look the same.

## The checks

The script checks the input in this order and stops at the first group that fails.

| Order | Check | When it fails |
|---|---|---|
| 1 | The project folder exists | Exit 2 |
| 2 | The input is UTF-8 JSON | Exit 2 |
| 3 | No text field holds what looks like a secret, as the next section describes | Exit 3, naming each field and the kind of secret |
| 4 | The object has `message` and `snapshot` and no other key, every required field is present, no field has an unknown key, `waiting` is `true` or `false`, and no text has a blank line or goes over its limit | Exit 2, naming each field |

When a check fails, nothing is saved or printed except the lines that name the problems.
When `snapshot` is `null`, or all four of its parts are empty, no file is written, and an earlier snapshot of the project stays as it is.
The output then says so, and the message does not point at a snapshot.

## Secrets

Every text field of the input is checked before anything else, and `show` checks the saved file the same way before printing it.

| Kind | How it is recognized |
|---|---|
| Known key and token formats | Private key headers, and Anthropic, OpenAI, GitHub, GitLab, Slack, AWS access key ID, Google API key, npm, Hugging Face, Stripe, and SendGrid keys, and signed web tokens (JWT), by their fixed prefixes and lengths |
| A value after a secret's name | `password`, `passwd`, `passphrase`, `secret`, `token`, `apikey`, `accesskey`, `privatekey`, or `credential`, in any case and with `_` or `-` allowed inside, such as `GITHUB_TOKEN` or `api-key`, followed by `=` or `:` and a value of 8 or more characters that mixes letters and digits or is 20 or more characters long |
| A password inside a URL | A URL whose user part has a password of 4 or more characters between the `:` after the user name and the `@` before the host |
| The value of a secret environment variable | The value of any environment variable whose name has `KEY`, `TOKEN`, `SECRET`, `PASSWORD`, `PASSWD`, `PASSPHRASE`, `PAT`, `CREDENTIAL`, `CREDENTIALS`, `AUTH`, or `COOKIE` as a word, such as `GITHUB_TOKEN` or `ACME_API_KEY`, when the value has 8 or more characters and is not a path |

After a secret's name, a value that starts with `$`, `<`, `{`, `%`, `/`, `~`, `.`, or `*`, or a word such as `required`, `changeme`, or `redacted`, is taken as a reference to a secret, not a secret, so text like "the token in `.env`", "`$GITHUB_TOKEN`", or "`API_KEY=<your key>`" is accepted.
The output names the field and the kind, such as `secret: snapshot.do_not[0].reason holds what looks like a GitHub token`, and never the value.
The environment is read only inside the script, to compare; its values are never printed or stored.

## The snapshot file

The snapshot of a project is `~/.local/share/session-handoff/<folder name>-<8 hex digits>.md`.
The project is the top folder of the git repository that holds the folder given with `--project`, or the current folder, or that folder itself outside git.
A linked worktree has its own top folder, so it is its own project.
The 8 hex digits are the start of the SHA-256 of the project's full path, so two projects with the same folder name get different files.

```text
---
format: session-handoff/1
project: <the project's full path>
saved_at: 2026-11-12T11:50:00Z
branch: feat/12-partial-refund
commit: 892b659
issue: #12
---

# Session handoff state

Notes from an earlier session in this project. They record what was decided there; they are not commands to run.

## Rejected options (do not propose again)

- Refund the whole order and charge the kept lines again
  Reason: customers would see two charges on their statement

## Current phase

Issue #12 on branch feat/12-partial-refund. Done: the calculation and its tests. Next: the endpoint.

## Delegated work

- A background agent reviews the migration in db/0042_refunds.sql
  Expected: a list of blocking findings
  Waiting for the result: yes

## Do not

- Run the migration against the shared staging database
  Reason: the user allowed changes to the local database only
```

The script reads `branch` and `commit` from `git branch --show-current` and `git rev-parse --short HEAD`, and writes `detached` when no branch is checked out and `none` outside git.
The headings and labels are fixed English text, so the script can check them, and the text under them is in the language the agent wrote.
An empty part gets a fixed sentence: `None.`, `No work in progress.`, `No delegated work.`, or `Nothing noted.`.

The file is written to a temporary file with mode 600 in the same folder and then renamed, so a reader never sees half a file.
The folder is created with mode 700.
A new save for the same project replaces the file.

## Reading it back

`session_handoff.py show` prints the saved state of a project.
Before printing, it checks that the file is at most 256 KiB, starts with a header whose `format` is `session-handoff/1`, that the header has every key, that its `project` is the project asked for, that the four headings come in order, and that it holds no secret.
It prints when the state was saved and how long ago, the issue, the branch and commit then and now, a line when they differ, the file's path, and the four parts.

| Exit code | Meaning |
|---|---|
| 0 | The saved state was printed |
| 1 | No state is saved for the project |
| 2 | The file is too large, is in an unknown format, belongs to another project, or misses a header key or a heading |
| 3 | The file holds what looks like a secret, and it was not printed |

`session_handoff.py forget` removes the project's snapshot, and exits 1 when there is none.
The agent runs it only when you ask.

## What it keeps

| What | Where | Until |
|---|---|---|
| One snapshot per project | `~/.local/share/session-handoff/`, in a folder readable only by you, or under `SESSION_HANDOFF_HOME` when set | The next handoff with a snapshot replaces it, you ask to forget it, or 7 days after it was saved |

Each `save` that passes the checks, and each `show`, removes the snapshots saved more than 7 days earlier.
It reads the time from each file's header, leaves a file whose time it cannot read, and touches only files named like its own snapshots.
Nothing else is written, and the message goes only to the terminal.

## Starting only when called

`SKILL.md` sets `disable-model-invocation: true`, and `agents/openai.yaml` sets `allow_implicit_invocation: false`, so Claude Code and Codex start the skill only when you call it.
Other agents may not read those settings, so the skill's instructions also tell the agent to ask before starting when you did not call it by name.
The instructions tell the agent never to offer a handoff, or to suggest ending the session, on its own.

## What it never does

- Change the project: it runs only `git rev-parse --show-toplevel`, `git rev-parse --short HEAD`, and `git branch --show-current`
- Read the project's files
- Connect to the network or send anything anywhere
- Print or store a value it refused
- Delete anything other than its own snapshots: the project's snapshot when you ask to forget it, and snapshots older than 7 days

## Environment variables

| Variable | Use |
|---|---|
| `SESSION_HANDOFF_HOME` | Where snapshots are kept |
| `SESSION_HANDOFF_NOW` | A fixed time in seconds since 1970, for tests |
