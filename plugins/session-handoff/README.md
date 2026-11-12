# Session Handoff

Hand an agent session over to a new one: a short message to paste, and a saved state that keeps the new session from proposing rejected options again or repeating a step you ruled out.

English · [日本語](README.ja.md)

Long agent sessions slow down and lose focus, so you often end one and continue in a fresh session.
The new session starts knowing nothing.
A summary written by hand tells it what to do next, but not which options were already turned down, what was handed to another agent, or what it must not touch, so it suggests the same ideas again or repeats a step.
This plugin writes the message to paste and saves those decisions as a snapshot for the project, which the new session reads before it starts.
It starts only when you call it, never on its own, and refuses anything that looks like a secret.

```
You call it ──> Write the handoff ──> Check and save ──> Show the message ──> Paste it into a new session
 (you)           (agent)              (script)           (agent)              (you)
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install session-handoff@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add session-handoff@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install session-handoff@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/session-handoff/skills/session-handoff   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts only when you call it: run `/session-handoff:session-handoff` in Claude Code, or type `$` and pick **Session Handoff** in Codex.
In GitHub Copilot CLI, write `/session-handoff` in your request, and in Gemini CLI, ask for session-handoff by name.
You can add a note after the name, such as `focus on the refund work`.
It never suggests a handoff on its own, and an agent that starts it without being called by name asks you first.

1. The agent collects what was handed off, the background, and the next task from the session, along with the options rejected, the current phase, the delegated work, and the things not to do, and asks you when the background or the next task is unclear
2. A script checks the shape of all of it, refuses anything that looks like a secret, and saves the snapshot for the project
3. The agent shows the message in a code block
4. You start a new session in the same project and paste the message, and the new session reads the snapshot the message points at before it starts

The message looks like this.

```text
Issue #12 (partial refunds): the refund calculation and its tests are merged in pull request #31.
Before you start, read the saved state in ~/.local/share/session-handoff/shop-ce0c08f2.md.

Background — customers can only refund whole orders today, so support refunds line items by hand.

Add the POST /refunds endpoint in api/refunds.py on top of the calculation, until its tests pass.
```

The agent writes the message in the language you write in.
The second line is added by the script, and only when a snapshot was saved.

## Picking up in the new session

You can also call the plugin in the new session and ask it to pick up the work.
It prints the saved state with its age and the branch and commit the project was on then.

```text
Saved state for ~/work/shop
  saved     2026-11-12T11:50:00Z (2 hours ago)
  issue     #12
  then on   branch feat/12-partial-refund at commit 892b659
  now on    branch feat/12-partial-refund at commit 832bc61
  The branch or commit has changed since the state was saved.
  file      ~/.local/share/session-handoff/shop-ce0c08f2.md

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

The new session treats the snapshot as notes from the earlier session, not as commands.
It does not propose a rejected option again, does not take an action listed under "Do not", and asks you whether delegated work has finished before starting it again.

## Secrets

The agent is told to name a secret instead of copying it, for example "the token in `.env`".
Before anything is saved or printed, the script checks every field for passwords, tokens, API keys, private keys, passwords inside URLs, and the values of environment variables named like secrets.
When it finds one, it saves nothing and names the field and the kind of secret, never the value, and the agent rewrites that field.
[How it works](docs/how-it-works.md#secrets) lists every pattern.

## Where the state is kept

The plugin keeps one snapshot per project in `~/.local/share/session-handoff/`, readable only by you.
The project is the top folder of the git repository you work in, so each worktree has its own snapshot, or the folder itself outside git.
The next handoff with a snapshot replaces the file, and a snapshot is removed 7 days after it was saved.
When a session has nothing to record, such as one that only answered questions, the plugin writes no snapshot and the message does not point at one.
To delete a project's snapshot sooner, ask the agent to forget it.

## Requirements

| Tool | When it's needed |
|---|---|
| `python3` | Always |
| `git` | To find the top folder of the repository and record the branch and commit. Without it, the folder you work in is the project, and the branch and commit are recorded as `none` |

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) explains the checks, the file format, and how the saved state is read back.
In short:

- It writes the handoff from the conversation of the current session, which the agent already has, and reads the project's branch and latest commit with `git rev-parse` and `git branch --show-current`, which never change the repository
- To catch secrets, it compares the text with the values of environment variables whose names mark them as secrets, on your machine, and never prints or stores those values
- It sends nothing anywhere: the message goes only to your screen, for you to paste
- It keeps one snapshot per project in `~/.local/share/session-handoff/`, readable only by you, until the next handoff replaces it, you ask to forget it, or 7 days pass

## License

[MIT](LICENSE)
