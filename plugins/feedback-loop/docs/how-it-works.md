# How Feedback Loop works

English · [日本語](how-it-works.ja.md)

This page explains where the records live, what each command does, how a review is read, and every condition the script checks before it closes a correction.
The records and the checks are handled by `skills/feedback-loop/scripts/feedback_loop.py`, which uses only the Python standard library and `git`.
The parts that need judgment, such as deciding what the user corrected and fixing the files, are done by the agent as `SKILL.md` describes.

## The loop

| Step | Who | Command |
|---|---|---|
| Find the repository and its records | Script | `where --repo <file>` |
| Record the correction | Agent, with the user's words on standard input | `open` |
| Decide how far it applies | Agent | `classify <id> <scope>` |
| Keep the lesson | Agent writes the rule; the script keeps the case | `case`, `rule` |
| Fix the files | Agent | None |
| Check the files | Script runs the case checks and the agent's command | `check <id> -- <command>` |
| Review the fix | An evaluator that edits nothing; the script reads its answer | `status <id>` prints the brief, `review <id>` saves the answer |
| Close | Script, when every condition below holds | `close <id>` |

A failing review sends the agent back to fixing.
`status` without an id lists the open corrections and the next step of each, `history` lists the closed ones, `extend` adds rounds, and `drop` closes a correction the user withdrew.

## Which repository

The repository is the git work tree that holds the corrected files, found with `git rev-parse --show-toplevel` from the path given to `--repo`.
Every file given with `--artifact` must be inside it, not inside `.git`, and not a folder; a path that leads outside it, including through `..` or a symbolic link, is refused.
Outside a git repository the script records nothing and exits 2, and the agent fixes the output as a one-time correction.

## Where the records live

| Choice | Folder | Permissions |
|---|---|---|
| Default | `~/.local/share/feedback-loop/repos/<repository>-<hash>/`, or under `FEEDBACK_LOOP_HOME` when set. `<hash>` is the first 12 hex digits of the SHA-256 of the main clone's path | Folders readable only by you (700), files readable only by you (600) |
| A folder inside the repository, set with `where --use <folder>` | `<repository>/<folder>/` | Your usual permissions, so the files can be committed and shared |

Linked worktrees share the default folder of their main clone, found with `git rev-parse --git-common-dir`.
A folder chosen with `--use` is relative to the root of the work tree in use.
The choice itself is kept in the file `store` of the default folder, and `where --private` removes it; records already written stay where they are.

| File in the records folder | Holds |
|---|---|
| `pending/<id>.json` | One open correction |
| `events.jsonl` | One line per closed or withdrawn correction, the whole record with its closing time |
| `rules.md` | Rules for the repository, written by the agent. The script creates it with a heading |
| `cases/<file>-<hash>.json` | The case of one corrected file |
| `reviews/<id>-<round>.md` | The evaluator's answer for each round, exactly as saved |

Every file except `events.jsonl`, which only gets lines added at its end, is written to a temporary file in the same folder and renamed into place, so a reader never sees half of it.

## What a record holds

| Field | Content |
|---|---|
| `id` | `fb-<date>-<number>`, such as `fb-20330518-001`, numbered per day in local time |
| `status`, `drop_reason` | `open`, then `resolved` or `dropped` in the log, with the user's reason for `dropped` |
| `source_sha256` | The SHA-256 of the user's words, with surrounding whitespace removed. The words are not stored |
| `target_repository` | The repository root, written as `~/...` when it is under your home folder |
| `target_artifacts` | The corrected files, relative to the repository root |
| `origin_skill` | The skill that produced the output, or `none` |
| `feedback_subject`, `expected` | What was corrected and what the user expects, in the agent's words |
| `scope` | `artifact`, `repository`, `skill`, `global`, or `one-off` |
| `rule_files` | The rule files noted with `rule`: relative to the repository when inside it, starting with `~` when under your home folder |
| `case_files`, `case_removals` | The case files this correction changed, relative to the records folder, and the case entries it removed |
| `opened_at`, `opened_artifacts`, `closed_at` | When it was opened, the file hashes at that moment, and when it was closed |
| `verification.runs` | Each check: the time, the SHA-256 of every corrected file (or `missing` when it does not exist), and each command with its exit code |
| `loop` | The mode, the round limit, the criteria, and each round: the file hashes, the evaluator, its kind, the verdict, the findings, and the review file with its SHA-256 |

Records carry `"version": 1`, and the script refuses open records and case files of another version instead of guessing.

## Opening a correction

`open` reads the user's words from standard input and stops when they are empty.
When an open correction already has the same hash, it prints `Already open as <id>` and adds nothing.
When a closed correction had the same hash, or earlier corrections touched the same files, it names them, because a repeat means the earlier lesson did not hold.

Every correction has two criteria: `user-feedback` (the correction is resolved) and `regression` (the rules and case checks that applied before still hold).
`--criterion <id>=<text>` adds more; an id is lowercase letters, digits, and `-`, at most 40 characters, and is used once.
`--max-iterations` sets the rounds before the agent asks the user, 3 by default, from 1 to 10.

## Cases

A case lists, for one file, texts it must not contain, texts it must contain, and questions for the evaluator, each entry tagged with the correction that added it.
`check` matches the texts as exact substrings, including case, against the file read as UTF-8.
A file that does not exist contains nothing, so a forbidden text passes and a required text fails.
A case file that is not valid JSON or not in the expected shape stops `check`, `status`, and `close` with exit code 2 and its path, instead of being skipped.

## Checks

`check <id> -- <command>` first runs the case checks of the corrected files, then runs the command in the repository root with a time limit of 600 seconds (`--timeout` changes it).
The command's output goes to the terminal and is not stored.
A command that cannot be found counts as exit code 127, and one stopped at the time limit as 124.

A check counts only for the files exactly as they were when it ran.
For the files as they are now, the latest result of each command is what counts, so a later passing run of the same command replaces an earlier failure, and a failure of any command blocks the review.

## The review

`status <id>` prints the brief for the evaluator: the files, the criteria, the case results and questions, the rules file, the checks on the files as they are now, the findings of the last round, and the answer format.
The answer has exactly one line per criterion.

```text
- user-feedback: PASS - the jargon is gone
- regression: PASS - the case checks hold
- plain: FAIL - step 1 does not say which command sets up the environment
```

A leading `-`, `*`, or `+`, backticks around the id, and bold around the verdict are allowed, and `PASS` and `FAIL` may be in any case.
`review` refuses, without recording a round, an answer that lacks a line for a criterion or has two lines for one.
It also refuses a review while no passing check covers the files as they are now, which is also how an evaluator that edited the files is caught.

| `--kind` | Use |
|---|---|
| `independent_llm` | A separate agent or a separate read-only review pass |
| `human` | The user's own verdicts |
| `deterministic` | Only in `deterministic` mode, where the checks decide everything |

In `independent-review` and `hybrid` mode, a review of kind `deterministic` is refused.
The answer is saved as `reviews/<id>-<round>.md` with its SHA-256, and the round is recorded with the file hashes at that moment.

## The round limit

A failing review in the last allowed round exits 3, and the correction stays open.
After that, a review is accepted only with `--kind human`, until `extend --rounds <n>` adds rounds.
`drop --reason <text>` closes a correction the user withdrew, with the reason, as `dropped`.

## When a correction can close

`close` lists every condition that does not hold and exits 1, or closes the correction and exits 0.

- The scope is set
- The criteria include `user-feedback` and `regression`
- At least one round was recorded, and the last one passed
- No corrected file changed after the last round
- The last round's review file exists, has the recorded SHA-256, and has a `PASS` line for every criterion
- The last round's kind fits the mode
- The latest result of every check on the files as they are now is exit code 0
- For `artifact`, a case of one of the files holds an entry from this correction
- For `repository`, `skill`, and `global`, at least one rule file was noted with `rule`, and every noted file still exists

On closing, the record goes to `events.jsonl` with `status` `resolved`, `final_verdict` `pass`, the final file hashes, and the latest result of each check, and its file in `pending/` is removed.

## What it keeps

| What | Where | Until |
|---|---|---|
| Open corrections, the log, rules, cases, and reviews | The records folder described above | You delete them |
| Where the records of a repository live, when you chose a folder inside it | `store` in the default records folder | You run `where --private` or delete it |

Nothing else is written, and no temporary file is left behind.

## What it never does

- Store the words of your correction: only their SHA-256 hash
- Change a project file: the script writes only in the records folder, and the agent makes the fixes
- Run anything other than `git rev-parse` and the check command the agent passes after `--`
- Decide a verdict: it reads the verdicts from the evaluator's answer
- Write to your project's agent instructions, a skill, or your user-level instruction file: the agent does that only after you agree, and the script only notes the path
- Send anything over the network

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Done |
| 1 | The step did not pass: a check failed, a review failed, or a condition for closing does not hold |
| 2 | Bad input, such as a path outside the repository, an unknown id, an unreadable review, or a malformed case file |
| 3 | The last allowed round failed, or a review came after the limit without `--kind human` |

## Environment variables

| Variable | Use |
|---|---|
| `FEEDBACK_LOOP_HOME` | Where the default records folders live, instead of `~/.local/share/feedback-loop` |
| `FEEDBACK_LOOP_NOW` | A fixed time in seconds since 1970, for tests |
