---
name: skill-tune
description: Measures a plugin's skill with claude plugin eval cases kept in the plugin, shortens its SKILL.md, and measures again so that no case scores lower, then caps the size in the plugin's test. Use when the user wants to measure a skill, add evals to a plugin, shorten a SKILL.md, find out why an eval case fails, or see which skills in a repository are longest.
---

# Skill tune

Measure what a plugin's skill makes the agent do, shorten its `SKILL.md`, and show with the same eval cases that no case got worse.
Talk to the user in the language they write in.
Where it says to ask the user, use AskUserQuestion in Claude Code, and ask in the chat with numbered options in other agents.

The script is `scripts/skill_tune.py` next to this `SKILL.md`.
When you run it, put `S=<folder that contains this SKILL.md>/scripts` at the start of the same shell command, and run `python3 "$S/skill_tune.py" <command>`.
`python3 "$S/skill_tune.py" --help` describes every command, and `claude plugin eval --help` the eval command it runs.
It keeps copies and results in `${SKILL_TUNE_HOME:-~/.local/share/skill-tune}`, readable only by the user.

| The user wants | Do |
|---|---|
| To measure and shorten a skill | Steps 1 to 10 |
| Eval cases only | Steps 1 to 7, without the cuts |
| To know why a case fails | Step 9, from the result that has the failing case |
| The longest skills in a repository | `list <repository folder>`, then offer step 1 for one of them |

## Rules

- `--scaffold` runs each case's `fixture.sh` as the user, and `--trust-plugin` skips the question that guards it, so run the eval only on plugins the user wrote or trusts
- Run every eval on a copy made with `copy`, never on the user's folder, so the user's files do not change while it runs
- Spend nothing before the user agrees on the cases in step 2, where the cost per case is said, and show the estimate in step 6 without asking for a limit. Pass `--max-cost-usd` only when the user names a limit
- In agents other than Claude Code, stop before measuring: do steps 1 to 3, then tell the user that `claude plugin eval` comes with Claude Code and that steps 4 to 10 run there. `run` exits 3 when `claude` is missing
- Report the scores that `summary` and `compare` print. A case that scored lower is reported as lower, with its cause
- Do not publish, release, or push anything

## 1. Measure the skill

Run `size` on the `SKILL.md`, and read it with the files it points to.
List the parts that say again what something else already says.

- Tables of what a script prints, its exit codes, or its messages, when the script prints them itself
- An overview of the steps that repeats the headings
- A list of every file next to the `SKILL.md`, when each step names the files it reads
- Option details that the script's `--help` gives
- A description that walks through the whole flow instead of saying what the skill does and when to use it

Keep the rules, the safety guarantees, and every judgment a script cannot make, such as how to write the text a skill produces.

## 2. Agree on the cases and the cuts

Propose case groups, and the parts to cut with the words each would save, and ask the user which to take (several may be chosen).

- The request that starts the skill, and what the skill does before it acts (for example, it asks first, or shows a plan and writes nothing)
- The main result, from a state where the earlier questions are already answered in the prompt
- A rule that must hold, such as never reading a secret, even when the prompt asks for it
- A repair, such as fixing what the skill's own check reports
- A nearby request that must not start the skill

Each case is run three times with the plugin and three times without it, and some cases cost a dollar a run.
Say that step 4 runs each case once first, at about 0.2 to 1 USD per case.
Say also that each `llm` grader needs the user to label 12 passing and 12 failing outputs in step 7, and one short run per label.

## 3. Write the prompts and fixtures

Put each case in `<plugin>/evals/<case>/case.yaml` with a `fixture.sh` that writes the starting state, and share code between fixtures in `<plugin>/evals/_fixture.py`.
Copy the shape from a plugin that already has cases, or from `claude plugin eval --help`.
The prompt asks the way a user would, for what the skill does rather than for an exact edit, which the agent makes without the skill.
A case that should run to the end says the earlier answers in the prompt.
A new case gets only its `skill-fired` grader here; step 4 finds what the other graders check.

What the eval sandbox allows decides what a case can test.

- The run's `HOME` is a temporary folder and the workspace is `HOME/cwd`. `fixture.sh` runs there before the agent, as the user and outside the sandbox
- The Write tool cannot write outside the workspace, even with a permission for that path. A skill that writes to a data folder with the Write tool stops or falls back to the shell; a script that takes the data on standard input avoids this
- There is no network and no browser. A step that needs either takes the path the skill gives for when they are missing
- A process cannot listen on a local port (Operation not permitted), so a step that checks or serves a port fails there. Test what the skill does when that step is refused, and leave the rest to the plugin's test
- `git` fails inside the sandbox (on macOS, `/usr/bin/git` cannot create its cache file). A fixture that needs a repository creates it in `fixture.sh`, and a script that runs `git` stops there unless it can find the repository another way, such as by reading `.git`. The run's `HOME` is itself a repository, so a fixture that runs a plugin script that names things by the repository runs it without `git` on the `PATH`, the way the agent's run sees it
- `claude plugin eval` keeps the agent out of a plugin folder that holds a file named `report.html`, the name of its own report, so the skill can read none of its files and run none of its scripts. `copy` warns about such a file; rename it in the plugin before measuring
- Fixture files hold no real secrets, and no fake key that a secret scanner flags

## 4. Read every output and name the failure types

```bash
S=<skill folder>/scripts
python3 "$S/skill_tune.py" copy <plugin folder> --label preflight
python3 "$S/skill_tune.py" run <copy> --label preflight --runs 1 --ablation none
python3 "$S/skill_tune.py" summary <result> --indicator skill-fired
```

`run` takes minutes; run it in the background where the agent can.
When this run writes cases, read every output before writing a grader: its `trace`, and the files it left in the folder `--keep-temp` kept, which holds the `out/` folder of its trace path.
Note what is wrong with each output, group the notes into failure types that each pass or fail by yes or no, and write one grader per failure type in step 5, as `references/graders.md` says.
When the cases already exist, these runs only check that every case scores 1.00.

## 5. Write the graders and try each case again

How to grade:

- Grade the files the run leaves in the workspace: `regex` with `target: {source: file, path: ...}`, and `match: not_contains` for what must be absent. A line that a script prints into the trace is missed when the agent filters the output, so a grader on such a line, or on anything only the plugin can produce, gets `arm: with-only` and counts only as a sign that the skill ran
- `regex` patterns are JavaScript regular expressions: no inline flags such as `(?m)`, and no `\A` or `\Z`. `^` and `$` match only the start and end of the whole text, so write `(^|\n)` for the start of a line
- What the agent must not do is `tool_used` with `min: 0`, `max: 0`, and `arm: both`
- `tool_used` matches `input_match` against the input as JSON text, so a `"` in a command arrives as `\"` and a line break as `\n`; write `\\?"?` where a command may quote a path, and `(?:\s|\\n)*` where it may break a line
- Name the grader that shows the skill started `skill-fired`, with `arm: with-only`: `tool_used` on `Skill` with the skill's name, or, for a skill with `disable-model-invocation: true`, which starts only from a prompt that calls it by name such as `/<plugin>:<skill>` and makes no `Skill` call, its first script call. `summary` and `compare` average the cost over the runs where it passed
- An LLM judge can fail a reply that meets every condition, and pass one that misses a condition. Keep `llm` criteria to what only a reader can judge, say what is not a failure (for example, the date a password changed is not a password), and pair the judge with a `regex` on the result. An `llm` grader reads a file through `focus`, not `target`
- Run the eval on a folder path. A bare plugin name runs the installed copy

Add checks to the plugin's test: the suite has its cases, each fixture builds the state its case starts from, and files under `evals/results/` are ignored by git.

Run the preflight again on a copy with a new label, since `--replace` also removes the earlier result.
Every case should score 1.00 here.
When one does not, read its runs with `trace` and fix the case, its fixture, or its graders, not the `SKILL.md`, until the sandbox can produce the result.

## 6. Record the baseline

Run `estimate` on the preflight result and show the user the cost.
Make a copy with the label `before` before any cut, run it with and without the plugin, and show `summary` with the indicators named.
Step 9 runs only with the plugin, since the runs without it do not depend on the `SKILL.md`.

## 7. Check each `llm` grader against labels

Before the comparison counts an `llm` grader, check it against outputs the user labeled, unless a check trusted it with its current criteria.
From the step 6 baseline, show the user each output's text with `label`, never the grader's verdict, and record each answer with `label --verdict`, until 12 human passes and 12 human fails are labeled; the runs without the plugin supply fails.
`label-cases` sets 3 examples aside, and 5 passes and 5 fails are held back for one final check.
Tune the criteria with `agree`, which prints the share of human passes the grader passed and the share of human fails it failed, apart, and read each disagreement's explanation for these failure types:

- Passing a found problem as minor: it names the problem and passes anyway
- Testing only the surface: it passes on the right headings or words, or skips the edge cases

A grader that agrees on fewer than 4 of the 5 held-back passes or fails stays out of the score through `--indicator`, and is reported as not trusted.
`references/graders.md` gives the commands in order.
For eval cases only, stop here and report.

## 8. Shorten

Make the agreed cuts in the user's `SKILL.md`, and nothing else.
In the plugin's test, cap the body words and the description characters at the new size, and check that the phrases of each rule are still there.

## 9. Measure again and compare

```bash
S=<skill folder>/scripts
python3 "$S/skill_tune.py" copy <plugin folder> --label after
python3 "$S/skill_tune.py" run <copy> --label after --ablation none
python3 "$S/skill_tune.py" compare --before <before result> --after <after result> --indicator skill-fired
```

`compare` exits 1 when a case scored lower.
Read that case's runs with `trace`, on both sides, and name the cause before changing anything.

| Cause | Fix |
|---|---|
| The cut took something the agent needed | Put that sentence back, and run the case again after |
| A shorter description started the skill less often | Put back the phrase that names the request, and run the case again after |
| The grader measured something other than the result | Fix the grader, and run the case again on both the before and the after copy |
| The sandbox stopped the run the same way on both sides | Change the case or the skill so it does not depend on that, and run it again on both sides |

Never change a grader and rerun only the after side.
When several results hold the same case, `summary` and `compare` take it from the last file given.

## 10. Report and clean up

Report a table of each case's score before, after, and without the plugin, the average cost and turns of the runs where the skill fired before and after, the total cost, and each `llm` grader that is not trusted.
Say so when a run did not get cheaper.
Then run `clean <name>` for each copy this run made, the folder under `runs/` that `copy` printed, such as `<plugin>-before`. It removes the copy, its results, and the folders `claude plugin eval` kept for them.
Never run `clean --all`: other sessions may be measuring with their own copies at the same time.
