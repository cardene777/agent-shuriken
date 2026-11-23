# Failure types and the grader check

Read this at step 4, when new cases get their graders, and at step 7, when an `llm` grader is checked against the user's labels.
`S` is the `scripts` folder next to the `SKILL.md`, as in the `SKILL.md`.

## Name the failure types (step 4)

1. Read every run of the preflight, one at a time: `python3 "$S/skill_tune.py" trace <result> --case <case>`, and the files the run left in its kept folder.
2. Write one line per output that says what is wrong with it, in the words of the output, such as "the plan lists the files but no command to undo them". Write "nothing wrong" when nothing is.
3. Group the lines into a few failure types, usually two to six. Each failure type is one question about an output that a reader answers with yes or no, such as "does every write step say how to undo it?".
4. Write one grader per failure type in step 5: `regex` when the text decides it, `tool_used` when an action decides it, and `llm` only when a reader has to judge it.

A failure type that the preflight outputs never show still gets a grader when the user named it as a rule in step 2.
Two lines that need the same fix belong to one failure type, and one line that needs two fixes is two.

Write each `llm` criterion as a skeptical reader that fails the output on any problem it finds, however small: list what fails, and say what does not count as a failure.
A judge asked to weigh whether a problem matters tends to pass it.

## Check an llm grader (step 7)

Each `llm` grader has its own label file, `<plugin>/evals/labels/<case>/<grader>.json`.
It keeps every label with the text the grader read, so it outlives `clean`; commit it with the cases.
Its text comes from the fixtures and the agent's output, which hold no real secrets.

### Label

For each output, show the user the text, then record the answer.

```bash
python3 "$S/skill_tune.py" label <result> --case <case> --grader <grader> --arm with --run 1
python3 "$S/skill_tune.py" label <result> --case <case> --grader <grader> --arm with --run 1 --verdict pass --into <plugin folder>
```

The first command prints only the text, so the user is not led by the grader's verdict; do not show the verdict until the user has answered.
Ask "Does this output pass `<the failure type>`?" with the two answers pass and fail.
The second command prints how many passes and fails the grader has, against the 12 of each needed.
Labeling a run again replaces its verdict.
The runs without the plugin usually supply the fails; when the skill passes everything, keep labeling them until there are 12 fails.

### Tune

```bash
python3 "$S/skill_tune.py" copy <plugin folder> --label labels
python3 "$S/skill_tune.py" label-cases <copy> --labels <label file> --set tune
python3 "$S/skill_tune.py" run <copy> --label tune1 --eval-dir label-evals --ablation none --runs 1
python3 "$S/skill_tune.py" agree <result> --labels <label file>
```

On its first call, `label-cases` sets 3 labels aside as examples, a pass, a fail, and one more, and holds 5 passes and 5 fails back at random; the split stays in the label file.
It prints the examples; put them in the grader's criteria in the plugin's `case.yaml`, as an output that passes and an output that fails.
It writes one small case per tuning label into the copy's `label-evals/`: its fixture puts the label's text where the grader reads it, or in `label-text.md` for a grader that reads the reply, and its grader is the copy's current grader.
Each case costs one short reply and one judging.

`agree` prints, apart, the share of human passes the grader passed and the share of human fails it failed.
Overall agreement hides a grader that misses every fail when fails are few, so read the two shares, not their sum.
For each label the grader got wrong, read its `explanation` in the result, and look for the two failure types of graders.

| Failure type | Sign in the explanation | Fix in the criteria |
|---|---|---|
| Passing a found problem as minor | It names the problem and still passes | Say that any such problem fails, however small |
| Testing only the surface | It passes because the headings or words are there | Say what the content must hold, and name the edge case it skipped |

After changing the criteria in the plugin, make a new copy, write the cases again, and run them with a new label.
Do not open the label file while tuning: it shows which labels are held back.

### The final check

```bash
python3 "$S/skill_tune.py" label-cases <copy> --labels <label file> --set held
python3 "$S/skill_tune.py" run <copy> --label held1 --eval-dir label-evals --ablation none --runs 1
python3 "$S/skill_tune.py" agree <result> --labels <label file>
```

Run it once, when tuning is done.
`agree` records the check in the label file and trusts the grader when it agrees on at least 4 of the 5 held-back passes and 4 of the 5 held-back fails.
It exits 1 otherwise, and for a held-back case the eval did not measure, and names the grader to pass with `--indicator` to `summary` and `compare`, so the grader leaves the score; report it as not trusted.
Checking the same held-back labels again after more tuning would test against labels seen while tuning, so `label-cases --set held` refuses a checked part.
To check again, label 5 new passes and 5 new fails; it holds those back and moves the checked part to tuning.
