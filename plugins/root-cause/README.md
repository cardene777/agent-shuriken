# Root Cause

Have your agent find the cause of a bug from evidence before it changes any code, and fix that cause instead of the symptom.

English · [日本語](README.ja.md)

Asked to fix a bug, an agent often patches the symptom: it adds a null check, a retry, or a sleep, or skips the failing test, and the bug comes back in another form.
This plugin gives your agent one procedure to follow instead.
The agent reproduces the bug, reads the code it runs through, and tests each hypothesis and tries to prove it wrong before changing anything.
It fixes only the cause, starting with a test that fails, and reports the evidence.

```
Record the symptom and reproduce it
  ↓
Read the code the reproduction runs through
  ↓
List up to three hypotheses that an experiment could prove wrong
  ↓
Test each one and try to refute it
  ↓
Fix only the cause, starting with a test that fails
  ↓
Report the cause, the evidence, and the fix
```

## Install

```
/plugin marketplace add cardene777/agent-shuriken        # Claude Code
/plugin install root-cause@agent-shuriken

codex plugin marketplace add cardene777/agent-shuriken   # Codex
codex plugin add root-cause@agent-shuriken

copilot plugin marketplace add cardene777/agent-shuriken # GitHub Copilot CLI
copilot plugin install root-cause@agent-shuriken

gemini skills install https://github.com/cardene777/agent-shuriken.git --path plugins/root-cause/skills/root-cause   # Gemini CLI
```

In other agents that read `SKILL.md`, unzip the skill zip attached to each release into the agent's skills folder, as [Getting started](../../docs/getting-started.md#install-without-the-marketplace) shows.

## Use

The plugin starts when you describe a bug, for example "this test fails only sometimes, find out why".
You can also call it: run `/root-cause:root-cause` in Claude Code, optionally followed by what fails, or type `$` and pick **Root Cause** in Codex.
In GitHub Copilot CLI, write `/root-cause` in your request, and in Gemini CLI, describe the task.

1. Tell the agent what fails, what you expected, and how you ran it. The agent asks when something is missing
2. The agent reproduces the bug, preferably with a test, and reads the code the reproduction runs through
3. The agent lists up to three hypotheses, tests them one at a time, and tries to prove each one wrong
4. The agent fixes only the cause, checks that the new test passes and the existing tests still pass, and checks that undoing the fix brings the bug back
5. The agent reports the symptom, the cause and its evidence, the fix, and other places the same cause affects

When three approaches do not find the cause, the agent stops and reports what it tried and what each attempt showed, instead of guessing.

The report looks like this.

```text
## Debugging report

### Symptom
The date test passes locally and fails on the build server.

### Root cause
formatDay() calls toLocaleDateString() without a time zone, so it uses the machine's.
Evidence: the test fails locally with TZ=UTC and passes with TZ=Asia/Tokyo.

### Fix
formatDay() passes timeZone explicitly. A new test runs under both time zones.

### Reach
formatMonth() had the same call and is fixed too.

### Prevention
The test suite now runs with TZ=UTC.
```

## Requirements

| Tool | When it's needed |
|---|---|
| Your project's test runner | To reproduce the bug and check the fix |
| `git` | To find the commit that introduced a bug with `git bisect` |

The plugin has no scripts and needs nothing else.

## What it reads, runs, and sends

[How it works](docs/how-it-works.md) lists every step, what the agent may change, and when it stops.
In short:

- It reads the code, tests, and logs of the project you are working on
- It runs your project's tests and commands, `git`, and code search. It runs `git bisect` only when there are no uncommitted changes, and always finishes with `git bisect reset`
- It edits files only in that project, to reproduce, diagnose, and fix the bug, and removes the logging it added before reporting
- It does not commit, push, or open a pull request unless you ask
- It has no scripts of its own, connects to nothing, and keeps no files. It never prints the values of environment variables

## License

[MIT](LICENSE)
