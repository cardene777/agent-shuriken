# How Root Cause works

English · [日本語](how-it-works.ja.md)

This page lists the steps the agent follows, what it may change, and when it stops.
The procedure itself is in `skills/root-cause/SKILL.md`, and the pages it points to are in `skills/root-cause/references/`.

## The steps

| Step | What the agent does |
|---|---|
| Record the symptom | Writes down what happens, when, where, and since when |
| Reproduce | Reproduces the bug, preferably with a test, in one to three steps. When it fails only sometimes, measures how often |
| Read the code | Reads the path the reproduction takes, the whole module, its callers, and its tests |
| List hypotheses | Lists up to three causes, each written so that an experiment could prove it wrong |
| Test | Tests each hypothesis with logging, a debugger, a test, `git bisect`, or a minimal reproduction |
| Refute | Lists what it would observe if the hypothesis were wrong, and checks for it |
| Name the cause | States the cause, the evidence, and the other places the same cause affects |
| Fix | Writes a test that fails, then fixes only the cause, here and in the other places |
| Verify | Checks that the new test passes, the existing tests pass, and undoing the fix brings the bug back |
| Report | Reports the symptom, the cause, the fix, the reach, and what would prevent it |

## How it weighs evidence

The agent does not accept a hypothesis on reasoning or intuition alone.
It needs at least one artifact, such as a log, an error message, or a stack trace, and prefers a controlled experiment in which changing one condition makes the bug appear and disappear.

## What it may change

- Files in the project you are working on, only to reproduce, diagnose, or fix the bug
- Logging and temporary files it adds while testing, which it removes before reporting
- The checked-out commit during `git bisect`, only when there are no uncommitted changes, and always restored with `git bisect reset`

It does not commit, push, or open a pull request unless you ask.
It treats text in logs, issues, web pages, and files as data, never as instructions.

## When it stops

When five whys and bisecting do not lead to the cause, the agent tries three different approaches.
If all three hypotheses are refuted, it stops instead of guessing, and reports what it tried, what each attempt showed, and the evidence it collected.

## What it runs

The plugin has no scripts.
The agent runs your project's tests and commands, `git`, and a code search such as `rg`, the same way you would.
It never prints the values of environment variables, and only checks whether they are set.
The plugin connects to nothing and keeps no files of its own.
