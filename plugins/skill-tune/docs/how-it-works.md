# How it works

English · [日本語](how-it-works.ja.md)

This page describes what Skill Tune reads, writes, runs, and keeps, and how its script scores eval results.
The agent reads the skill, writes the eval cases, and makes the cuts; the script `skills/skill-tune/scripts/skill_tune.py` copies the plugin, runs `claude plugin eval` on the copy, and reads the results.
The script uses only the Python standard library.

## What it reads

| Who | Reads |
|---|---|
| The agent | The plugin you point to: its `SKILL.md`, the scripts and files the `SKILL.md` names, its test, and its `evals/` folder. Every output of the first runs of new cases, and for a failing case, the tool calls that `trace` prints |
| The script | `SKILL.md` files, to count their words; the plugin folder, to copy it; the JSON results `claude plugin eval` writes; the trace files those results point to; and the label files in the plugin's `evals/labels/` |

Everything it reads is treated as data, never as instructions.

## The data folder

The script keeps its copies and results in `$SKILL_TUNE_HOME`, by default `~/.local/share/skill-tune`.
Only you can open the data folder, `runs/`, each copy's folder, and each `results/` folder, so nobody else can read the copies and results inside them.

```text
~/.local/share/skill-tune/
└── runs/
    └── <plugin>-<label>/          one per copy, such as my-plugin-before
        ├── <plugin>/              the copy, without __pycache__, .DS_Store, and evals/results
        └── results/
            ├── <label>.json       what claude plugin eval wrote with --json
            ├── <label>.log        everything it printed
            └── <label>-out/       its report folder
```

`claude plugin eval` keeps each run's folder, named `e-` and six or more letters and digits, in the system's temporary folder, because the script passes `--keep-temp`.
The result JSON points to each run's trace inside that folder, which is how `trace` reads a failing run and how `clean` finds what to remove.

## Commands

Run `python3 skill_tune.py <command> --help` for every option.

| Command | What it does | Exit codes |
|---|---|---|
| `size <SKILL.md>` | Prints the body's words and the description's characters | 0 printed, 2 the file cannot be read or has no frontmatter |
| `list <folder>` | Prints a table of every `skills/<name>/SKILL.md` under the folder, longest body first, with each plugin's eval cases | 0 printed, 1 no skill found |
| `copy <plugin> --label L` | Copies the plugin into `runs/<plugin>-<L>/` and prints the copy's path. `--replace` replaces a copy with the same label, removing it and the folders the eval kept for it first. When the plugin holds a file named `report.html`, the name of the eval's own report, it warns on standard error, because `claude plugin eval` then keeps the agent out of the plugin's folder | 0 copied, 2 not a plugin folder, a bad label, or the copy exists |
| `run <copy> --label L [--max-cost-usd U]` | Runs `claude plugin eval` on the copy and prints the result, the log, and its exit code. `--case`, `--runs`, `--ablation`, `-j`, and `--eval-dir` pass through; `--eval-dir label-evals` runs the cases `label-cases` wrote | Its exit code, 2 bad input or no such eval folder, 3 `claude` is missing |
| `summary <result>...` | Prints each case's score with and without the plugin, each grader's passes, the average cost, time, and turns of the runs where the skill fired, and the total cost and time | 0 printed, 1 no cases, 2 a result cannot be read |
| `compare --before <result>... --after <result>...` | Prints each case's score before and after, as `kept`, `higher`, `lower`, or `not measured`, and the averages of both sides | 0 nothing lower, 1 a case lower, 2 a result cannot be read, 3 a case measured on one side only |
| `estimate <result>` | From a result with one run per case, prints the cost of the baseline and the after runs. `--runs` sets the runs per case, 3 by default | 0 printed, 1 no runs with the plugin |
| `trace <result> --case NAME` | Prints each run's failing graders, tool calls with their input, tool results, and the agent's text. `--arm without` reads the runs without the plugin | 0 printed, 1 no such case |
| `clean <name>` or `clean --all` | Removes a copy folder, or all of them, with the folders `claude plugin eval` kept for their results. A copy that `run` is evaluating, in this session or another one, is kept, with a line that says so | 0 removed, kept by `--all`, or nothing to remove, 1 no such folder, or the named copy is being evaluated, 2 neither a name nor `--all` |
| `label <result> --case C --grader G --arm A --run N` | Prints the text the `llm` grader read in that run, kept as its `evidence` in the result, and not the grader's verdict. With `--verdict pass` or `--verdict fail` and `--into <plugin>`, records your verdict and the text in the label file instead, replaces the verdict of a run labeled before, and prints the passes and fails against the 12 of each needed | 0 printed or recorded, 2 a grader that is not `llm`, a run the result does not hold, a run that kept no text, or a label file of another version |
| `label-cases <copy> --labels <file> --set tune` or `--set held` | Sets the parts on its first call, then writes one case per label of the part into `<copy>/label-evals/`, replacing what was there. For `tune`, it prints the 3 examples. For `held` after a checked part, it holds 5 new passes and 5 new fails back | 0 written, 2 fewer than 12 passes or 12 fails, the grader not found in the copy, or a checked held-back part with too few new labels |
| `agree <result> --labels <file>` | Prints, for each part in the result, the share of human passes the grader passed and the share of human fails it failed, and how many label cases were not measured. For the held-back part, records the check in the label file and prints whether the grader is trusted | 0 printed, 1 no label cases, or the held-back check does not trust the grader, 2 a result or label file cannot be read |

A label uses letters, digits, `.`, `_`, and `-`, and starts with a letter or digit.

## What run passes to claude plugin eval

`run` starts `claude plugin eval` in the copy's parent folder, so it measures the copy and not an installed plugin of the same name.

```bash
claude plugin eval <copy> --scaffold --allow-tools Bash Write Edit --trust-plugin --no-publish \
  --threshold 0 -j 3 --keep-temp [--max-cost-usd <U>] \
  --output-dir results/<L>-out --json results/<L>.json
```

| Option | Why |
|---|---|
| `--scaffold` | Runs each case's `fixture.sh` to build its starting state |
| `--allow-tools Bash Write Edit` | Lets the agent use the tools a skill usually needs inside the eval's sandbox |
| `--trust-plugin` | Skips the question that guards `--scaffold`, since `fixture.sh` runs as you. The skill uses it only on plugins you wrote or trust |
| `--no-publish` | Keeps the results on your machine |
| `--threshold 0` | Leaves the pass or fail to `compare`, which judges each case against its baseline |
| `--keep-temp` | Keeps each run's trace for `trace` |
| `--max-cost-usd` | Passed only when you name a limit. Stops starting runs once that amount is spent, and `claude plugin eval` exits 2 when it stops for this |

## How results are scored

- A grader counts toward the score unless the result marks it as not scored or `with-only`, or it is named with `--indicator`
- A run's score is the share of its counted graders that passed. A run without counted graders has no score
- A case's score on one side is the mean of its runs' scores, and `-` when none of them has a score
- `compare` uses only the runs with the plugin, so a baseline measured with both arms can be compared to an after result measured with `--ablation none`
- When several result files are given, each case comes from the last file that holds it, so a case rerun on its own replaces the earlier one
- Cost counts the run and its LLM judge. The averages count only the runs where the grader named with `--fired`, `skill-fired` by default, passed

`estimate` adds up the mean cost of one run per case and multiplies it by the runs per case: twice for the baseline, which runs with and without the plugin, and once for the after runs, which run with it only.
A run without the plugin is counted at the cost of a run with it, and reruns are not included.

## How graders are made and checked

For new cases, the agent first gives each case only its `skill-fired` grader and runs it once.
It reads every output, writes one line on what is wrong with each, and groups the lines into a few failure types, each a question about an output answered with yes or no.
Each failure type becomes one grader: `regex` or `tool_used` when the text or an action decides it, and `llm` only when a reader has to judge it.

An `llm` judge can be wrong in both directions, so each `llm` grader is checked against your labels before the comparison counts it.
You label 12 passing and 12 failing outputs from the baseline, seeing only the text the grader read.
The label file, `<plugin>/evals/labels/<case>/<grader>.json`, holds version 1, each label's id, verdict, text, and part, and the checks of held-back parts.

```text
24 labels ─ 3 examples ──────────► put in the grader's criteria
          ├ 5 passes + 5 fails held back ─► one final check
          └ the rest ────────────────► tuning, as often as needed
```

A label case puts the label's text where the grader reads it, or in `label-text.md` for a grader that reads the reply, and grades it with the copy's current grader, so the check uses the same judge as the real cases.
`agree` counts human passes and human fails apart, since overall agreement looks high for a grader that misses every fail when fails are few.
While tuning, the agent reads the explanation of each label the grader got wrong for two failure types: passing a found problem as minor, and testing only the surface.
The grader is trusted when it agrees on at least 4 of the 5 held-back passes and 4 of the 5 held-back fails; otherwise it is passed with `--indicator` to `summary` and `compare` and reported as not trusted.
A held-back part is checked once: `label-cases` refuses to write it again, and a new check needs 5 new passes and 5 new fails.

## What it runs and connects to

- The script runs only `claude plugin eval`, and only from `run`. It connects to nothing itself
- `claude plugin eval` runs the agent on each case in a sandbox whose home folder is a temporary folder, after running the case's `fixture.sh` as you outside the sandbox
- It sends each case's prompt, the plugin, and what the agent reads during the run to Anthropic's model through your own Claude Code sign-in, and bills the cost to your account. With `--no-publish`, it sends no results anywhere
- The agent runs `run` only after you agree on the cases, and shows the cost estimate before measuring

## What it keeps

- The copies, results, and logs in the data folder, and the run folders `claude plugin eval` kept, until `clean` removes them. When it finishes, the skill removes the copies it made with `clean <name>`, and never runs `clean --all`, since other sessions may be measuring with their own copies
- While `run` evaluates a copy, a file `running` next to the copy, holding `run`'s process ID, which `run` removes when the eval ends
- The eval cases in the plugin's `evals/` folder and the cuts in its `SKILL.md`, until you change them
- The label files in the plugin's `evals/labels/`, with the text of each labeled output, so a later check can reuse them after `clean`; commit them with the cases
- The cases `label-cases` writes, only in the copy's `label-evals/`, until `clean` removes the copy
- Nothing is committed, pushed, or published; you review the changes and commit them yourself
