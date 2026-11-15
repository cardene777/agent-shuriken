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
| To measure and shorten a skill | Steps 1 to 8 |
| Eval cases only | Steps 1 to 5, without the cuts |
| To know why a case fails | Step 7, from the result that has the failing case |
| The longest skills in a repository | `list <repository folder>`, then offer step 1 for one of them |

## Rules

- `--scaffold` runs each case's `fixture.sh` as the user, and `--trust-plugin` skips the question that guards it, so run the eval only on plugins the user wrote or trusts
- Run every eval on a copy made with `copy`, never on the user's folder, so the user's files do not change while it runs
- Spend nothing before the user agrees: give the estimate and ask the user how much they allow, and pass that amount as `--max-cost-usd`
- In agents other than Claude Code, stop before measuring: do steps 1 to 3, then tell the user that `claude plugin eval` comes with Claude Code and that steps 4 to 8 run there. `run` exits 3 when `claude` is missing
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
Say that step 4 runs each case once first, at about 0.2 to 1 USD per case, and ask the user how much they allow for it.

## 3. Write the cases

Put each case in `<plugin>/evals/<case>/case.yaml` with a `fixture.sh` that writes the starting state, and share code between fixtures in `<plugin>/evals/_fixture.py`.
Copy the shape from a plugin that already has cases, or from `claude plugin eval --help`.
The prompt asks the way a user would; a case that should run to the end says the earlier answers in the prompt.

What the eval sandbox allows decides what a case can test.

- The run's `HOME` is a temporary folder and the workspace is `HOME/cwd`. `fixture.sh` runs there before the agent, as the user and outside the sandbox
- The Write tool cannot write outside the workspace, even with a permission for that path. A skill that writes to a data folder with the Write tool stops or falls back to the shell; a script that takes the data on standard input avoids this
- There is no network and no browser. A step that needs either takes the path the skill gives for when they are missing
- `git` fails inside the sandbox. A fixture that needs a repository creates it in `fixture.sh`
- Fixture files hold no real secrets, and no fake key that a secret scanner flags

How to grade:

- Grade the files the run leaves in the workspace: `regex` with `target: {source: file, path: ...}`, and `match: not_contains` for what must be absent. A line that a script prints into the trace is missed when the agent filters the output, so a grader on such a line, or on anything only the plugin can produce, gets `arm: with-only` and counts only as a sign that the skill ran
- What the agent must not do is `tool_used` with `min: 0`, `max: 0`, and `arm: both`
- An LLM judge can fail a reply that meets every condition, and pass one that misses a condition. Keep `llm` criteria to what only a reader can judge, say what is not a failure (for example, the date a password changed is not a password), and pair the judge with a `regex` on the result. An `llm` grader reads a file through `focus`, not `target`
- Run the eval on a folder path. A bare plugin name runs the installed copy

Add checks to the plugin's test: the suite has its cases, each fixture builds the state its case starts from, and files under `evals/results/` are ignored by git.

## 4. Try each case once

```bash
S=<skill folder>/scripts
python3 "$S/skill_tune.py" copy <plugin folder> --label preflight
python3 "$S/skill_tune.py" run <copy> --label preflight --runs 1 --ablation none --max-cost-usd <allowed>
python3 "$S/skill_tune.py" summary <result> --indicator skill-fired
```

`run` takes minutes; run it in the background where the agent can.
Every case should score 1.00 here.
When one does not, read its runs with `trace` and fix the case, its fixture, or its graders, not the `SKILL.md`, until the sandbox can produce the result.

## 5. Record the baseline

Run `estimate` on the preflight result, and ask the user how much they allow, offering two choices.

| Choice | Runs |
|---|---|
| Both arms before, the plugin only after | `--ablation none` after shortening, since the runs without the plugin do not depend on the `SKILL.md`. About two thirds of the estimate |
| Both arms before and after | The full estimate |

Make a copy with the label `before` before any cut, run it with the allowed ceiling, and show `summary` with the indicators named.
For eval cases only, stop here and report.

## 6. Shorten

Make the agreed cuts in the user's `SKILL.md`, and nothing else.
In the plugin's test, cap the body words and the description characters at the new size, and check that the phrases of each rule are still there.

## 7. Measure again and compare

```bash
S=<skill folder>/scripts
python3 "$S/skill_tune.py" copy <plugin folder> --label after
python3 "$S/skill_tune.py" run <copy> --label after --ablation none --max-cost-usd <allowed>
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

## 8. Report and clean up

Report a table of each case's score before, after, and without the plugin, the average cost and turns of the runs where the skill fired before and after, and the total cost.
Say so when a run did not get cheaper.
Then run `clean --all`, which removes the copies, their results, and the folders `claude plugin eval` kept for them.
