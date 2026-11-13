# Feedback Loop

Turn a correction you give an agent into fixed files, a review that passes, and a check that keeps the same mistake from coming back.

English · [日本語](README.ja.md)

When you tell an agent that its output is wrong, it usually edits something and says it is fixed.
Nobody checks the fix against what you said, and the same mistake returns in the next file or the next session.
This plugin records each correction for the repository, has an evaluator that edits nothing judge the fix against your correction and the rules from earlier corrections, and sends a failing review back for another round.
A script refuses to close the correction until the checks pass on the final files and the last review passes every criterion, and the lesson stays as texts a file must or must not contain, or as a rule for the repository.

```
Record the correction ──> Fix ──> Check ──> Review ──────> Close
 (agent)                  (agent)  (script)  (evaluator)    (script, once every criterion passes)
                           ^                    │
                           └───── on FAIL ──────┘
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install feedback-loop@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add feedback-loop@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install feedback-loop@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/feedback-loop/skills/feedback-loop   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts when you correct something the agent produced, for example "that's wrong", "this section is not needed", "I can't follow this", or "I told you this already".
A new request such as "fix the login bug" does not start it.
You can also call it: run `/feedback-loop:feedback-loop` in Claude Code, or type `$` and pick **Feedback Loop** in Codex.
In GitHub Copilot CLI, write `/feedback-loop` in your request, and in Gemini CLI, describe the task.

1. The agent names the files, the repository, and the skill your correction is about, and asks you when the conversation does not show it
2. The agent records the correction and decides how far it applies: only this file, the whole repository, a kind of work, or every task
3. The agent keeps the lesson: texts the file must or must not contain, or a rule for the repository. Rules for a skill or for every task are written only after you agree
4. The agent fixes the files and runs the checks, such as the project's tests and the texts from step 3
5. An evaluator that edits nothing, such as a subagent, judges each criterion: your correction is resolved, the rules from earlier corrections still hold, and any point you raised
6. A failing review goes back to step 4. After 3 rounds the agent stops and asks whether to keep going, accept the files as they are, or withdraw the correction
7. When the last review passes on the files exactly as they are, the script closes the correction

A correction that took two rounds looks like this.

```text
Opened fb-20330518-001: Setup steps use jargon
records  ~/.local/share/feedback-loop/repos/shop-bd3b0bd07953
fb-20330518-001 applies to: artifact
Added to cases/docs-setup.md-4ca53116.json from fb-20330518-001: forbid 2, require 0, questions 1
case checks: 2 of 2 conditions hold
$ test -s docs/setup.md
exit 0
Round 1 of fb-20330518-001 failed:
  plain: step 1 does not say which command sets up the environment
Give these findings to the fixer, fix the files, run check, and review again.
Round 2 of fb-20330518-001 passed. Run close.
Closed fb-20330518-001 after 2 round(s): Setup steps use jargon
log  ~/.local/share/feedback-loop/repos/shop-bd3b0bd07953/events.jsonl
```

## What a correction leaves

After that correction, the records folder holds these files.

| File | Holds |
|---|---|
| `cases/docs-setup.md-4ca53116.json` | The texts `docs/setup.md` must not contain and must contain, and the questions for the evaluator |
| `reviews/fb-20330518-001-1.md`, `reviews/fb-20330518-001-2.md` | The evaluator's answer in each round, exactly as saved |
| `rules.md` | Rules for the whole repository |
| `events.jsonl` | One line per closed correction, with the hash of your words instead of the words |

The case keeps the lesson for `docs/setup.md`.
In every later correction of that file, `check` fails if the file contains either forbidden text again, and the evaluator is asked the question.

```json
{
  "version": 1,
  "target": "docs/setup.md",
  "entries": [
    {
      "id": "fb-20330518-001",
      "forbid": [
        "Bootstrap the toolchain",
        "Hydrate the env"
      ],
      "require": [],
      "questions": [
        "Can someone new to the project follow every step without asking what a word means?"
      ]
    }
  ]
}
```

The review of round 1, `reviews/fb-20330518-001-1.md`, failed on `plain`, so the agent fixed step 1.

```text
- user-feedback: PASS - the jargon is gone
- regression: PASS - the case checks hold
- plain: FAIL - step 1 does not say which command sets up the environment
```

The review of round 2, `reviews/fb-20330518-001-2.md`, passed every criterion, so the correction could close.

```text
- user-feedback: PASS - every step is in plain words
- regression: PASS - the case checks hold
- plain: PASS - both steps name the command to run
```

This correction applied only to `docs/setup.md`, so `rules.md` kept only the heading the script writes.
A correction that applies to the whole repository adds a rule there, written by the agent as what to do and why.

```markdown
# Rules

Rules learned from corrections in this repository. Each one says what to do and why.

- Name the command to run in every setup step, because a newcomer cannot tell which tool a word such as "bootstrap" means
```

## When a correction can close

The script closes a correction only when all of these hold, so "I fixed it" is never enough.

| Condition | Why |
|---|---|
| The checks passed on the files exactly as they are now | A check of an earlier version says nothing about the final one |
| The last review has one `PASS` line for every criterion | A review that skips a criterion has not judged it |
| The files have not changed since that review, and the saved review has not changed either | Otherwise the review judged other files than the ones being closed |
| The lesson is kept where its scope says: a case for one file, a rule file for anything wider | So the next output is checked against it |

The script cannot tell who wrote a review, so the agent gives the review to an evaluator that does not edit, such as a subagent, or does a separate read-only pass when it cannot start one.

## Where the records live

Records stay in `~/.local/share/feedback-loop/repos/<repository>-<hash>/`, readable only by you, and the worktrees of one clone share them.
To share the rules with your team, ask the agent to keep the records in a folder inside the project, such as `.feedback/`.
The words of your correction are never stored; the record keeps their SHA-256 hash, so the same correction given twice is recognized.

## Requirements

| Tool | When it's needed |
|---|---|
| `python3` | Always |
| `git` | Always. Corrections are recorded per git repository; outside one, the agent fixes the output and records nothing |

The checks use whatever your project already has, such as its tests or linter.

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) explains the records, the review format, and every condition the script checks.
In short:

- It reads the files you corrected and the rules and cases kept for the repository
- It runs `git rev-parse` to find the repository, and the check commands the agent picks, such as your tests, inside the repository, recording only each command and its exit code
- It keeps the hash of your correction, the subject, the criteria, the reviews, and the file hashes in `~/.local/share/feedback-loop/`, readable only by you, or in the project folder you choose, until you delete them
- It changes your project's agent instructions, a skill, or your user-level instruction file only after you agree
- It sends nothing over the network

## License

[MIT](LICENSE)
