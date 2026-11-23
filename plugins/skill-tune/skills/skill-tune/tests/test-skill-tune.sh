#!/usr/bin/env bash
# Tests for the skill-tune script in a throwaway HOME and data folder.
# A stand-in for claude comes first on PATH and records how it was called, and the eval results and
# traces are written here, so no real eval runs and no model is used.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
SCRIPT="$SKILL_DIR/scripts/skill_tune.py"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }
mode() { python3 -c 'import os, sys; print(format(os.stat(sys.argv[1]).st_mode & 0o777, "o"))' "$1"; }
tune() { python3 "$SCRIPT" "$@"; }

export HOME="$T/home"
export TMPDIR="$T/tmp"
export SKILL_TUNE_HOME="$T/data"
export CLAUDE_LOG="$T/claude.log"
export PYTHONDONTWRITEBYTECODE=1
mkdir -p "$HOME" "$TMPDIR" "$T/bin"
export PATH="$T/bin:$PATH"
D="$SKILL_TUNE_HOME"

# --- stand-in for claude: records its arguments and writes a small result to the --json path
cat > "$T/bin/claude" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >> "$CLAUDE_LOG"
out=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "--json" ]; then out="$2"; fi
  shift
done
[ -n "$out" ] && printf '{"cases": []}\n' > "$out"
# CLAUDE_DURING names a script to run while this eval is running, as another session would.
if [ -n "${CLAUDE_DURING:-}" ]; then bash "$CLAUDE_DURING" >> "$CLAUDE_DURING_LOG" 2>&1; fi
exit 0
SH
chmod +x "$T/bin/claude"

# --- a sample repository with two plugins
R="$T/repo"
mkdir -p "$R/plugins/alpha/skills/alpha/scripts/__pycache__" "$R/plugins/alpha/evals/one" "$R/plugins/alpha/evals/two" \
  "$R/plugins/alpha/evals/results/old-run/one" "$R/plugins/beta/skills/beta"
printf -- '---\nname: alpha\ndescription: Does a thing. Use when testing.\n---\n\n# Alpha\n\nOne two three four five.\n' \
  > "$R/plugins/alpha/skills/alpha/SKILL.md"
printf -- '---\nname: beta\ndescription: Does another thing.\n---\n\n# Beta\n\nOne two three four five six seven eight nine ten.\n' \
  > "$R/plugins/beta/skills/beta/SKILL.md"
printf 'name: one\n' > "$R/plugins/alpha/evals/one/case.yaml"
printf 'name: two\n' > "$R/plugins/alpha/evals/two/case.yaml"
printf '{}\n' > "$R/plugins/alpha/evals/results/old.json"
printf 'name: one\n' > "$R/plugins/alpha/evals/results/old-run/one/case.yaml"
printf 'x\n' > "$R/plugins/alpha/skills/alpha/scripts/__pycache__/run.cpython-312.pyc"
printf 'print(1)\n' > "$R/plugins/alpha/skills/alpha/scripts/run.py"

# --- eval results in the shape claude plugin eval writes
python3 - "$T" <<'PY'
import json, os, sys
T = sys.argv[1]

def run(cost, judge, sec, turns, graders, trace=None):
    return {"score": 0, "passed": True, "turns": turns, "costUsd": cost, "judgeCostUsd": judge,
            "durationSeconds": sec, "error": None, "tracePath": trace,
            "graders": [{"name": g[0], "passed": g[1], "weight": 1, "withOnly": g[2],
                         "scored": g[3] if len(g) > 3 else not g[2]} for g in graders]}

trace = os.path.join(T, "tmp", "e-abc123", "out", "trace.jsonl")
os.makedirs(os.path.dirname(trace))
with open(trace, "w") as f:
    f.write(json.dumps({"type": "assistant", "message": {"role": "assistant", "content": [
        {"type": "tool_use", "name": "Bash", "input": {"command": "echo hi"}}]}}) + "\n")
    f.write(json.dumps({"type": "user", "message": {"role": "user", "content": [
        {"type": "tool_result", "content": "hi"}]}}) + "\n")
os.makedirs(os.path.join(T, "tmp", "e-abc123", "sealed"))
os.makedirs(os.path.join(T, "tmp", "e-keep99", "out"))

def case_a(with_runs, without_runs):
    return {"name": "alpha-one", "arms": {"with": with_runs, "without": without_runs}}

# "only-shown" is a with-only grader that the result still marks as scored, as with --ablation none.
# The alpha-two run has a failed skill-fired grader, so it is not one of the runs where the skill fired.
before = {"cases": [
    case_a([run(0.20, 0.01, 10, 4, [("skill-fired", True, True), ("check-line", False, False), ("result", True, False),
                                     ("only-shown", False, True, True)], trace),
            run(0.30, 0.01, 20, 6, [("skill-fired", True, True), ("check-line", True, False), ("result", True, False)])],
           [run(0.10, 0.0, 5, 3, [("skill-fired", False, True), ("check-line", False, False), ("result", False, False)])]),
    {"name": "alpha-two", "arms": {"with": [run(0.05, 0.0, 3, 2, [("skill-fired", False, True), ("skill-not-fired", True, False)])],
                                   "without": [run(0.05, 0.0, 3, 2, [("skill-not-fired", True, False)])]}},
]}
after = {"cases": [
    case_a([run(0.25, 0.01, 12, 5, [("skill-fired", True, True), ("check-line", True, False), ("result", False, False)])], []),
    {"name": "alpha-two", "arms": {"with": [run(0.05, 0.0, 3, 2, [("skill-not-fired", True, False)])], "without": []}},
]}
rerun = {"cases": [
    case_a([run(0.25, 0.01, 12, 5, [("skill-fired", True, True), ("check-line", False, False), ("result", True, False)])], []),
]}
preflight = {"cases": [
    {"name": "alpha-one", "arms": {"with": [run(0.40, 0.02, 30, 8, [("skill-fired", True, True)])], "without": []}},
    {"name": "alpha-two", "arms": {"with": [run(0.10, 0.0, 5, 2, [("skill-not-fired", True, False)])], "without": []}},
]}
for name, data in (("before", before), ("after", after), ("rerun", rerun), ("preflight", preflight)):
    with open(os.path.join(T, name + ".json"), "w") as f:
        json.dump(data, f)
PY

# --- size
out="$(tune size "$R/plugins/alpha/skills/alpha/SKILL.md")"
check "size prints the body words and the description characters" \
  'printf "%s\n" "$out" | grep -qx "body: 7 words" && printf "%s\n" "$out" | grep -qx "description: 31 characters"'

# --- list
tune list "$R" > "$T/list.txt"
check "list ranks the skills by body words and counts their eval cases" \
  'grep -qxF "| beta/beta | 12 | 19 | 0 |" "$T/list.txt" && grep -qxF "| alpha/alpha | 7 | 31 | 2 |" "$T/list.txt" \
   && [ "$(grep -n "beta/beta" "$T/list.txt" | cut -d: -f1)" -lt "$(grep -n "alpha/alpha" "$T/list.txt" | cut -d: -f1)" ]'

# --- copy and clean
copy="$(tune copy "$R/plugins/alpha" --label before)"
check "copy leaves out results and caches and is readable only by the user" \
  '[ "$copy" = "$D/runs/alpha-before/alpha" ] && [ -f "$copy/skills/alpha/SKILL.md" ] && [ -f "$copy/evals/one/case.yaml" ] \
   && [ -f "$copy/skills/alpha/scripts/run.py" ] && [ ! -e "$copy/evals/results" ] && [ ! -e "$copy/skills/alpha/scripts/__pycache__" ] \
   && [ "$(mode "$D")" = 700 ] && [ "$(mode "$D/runs/alpha-before")" = 700 ] \
   && ! tune copy "$R/plugins/alpha" --label before >/dev/null 2>&1'

# A plugin that holds a file named report.html, the name of the eval's own report: claude plugin eval then
# keeps the agent out of the plugin's folder, so copy says so and still makes the copy.
mkdir -p "$R/plugins/alpha/skills/alpha/templates"
printf '<html></html>\n' > "$R/plugins/alpha/skills/alpha/templates/report.html"
named="$(tune copy "$R/plugins/alpha" --label named 2> "$T/named.err")"; rc_named=$?
rm -rf "$R/plugins/alpha/skills/alpha/templates"
tune copy "$R/plugins/alpha" --label plain 2> "$T/plain.err" >/dev/null
check "copy warns when the plugin holds a file named report.html, and still makes the copy" \
  '[ "$rc_named" = 0 ] && [ -f "$named/skills/alpha/templates/report.html" ] \
   && grep -qF "skills/alpha/templates/report.html" "$T/named.err" && grep -qF "claude plugin eval keeps the agent out of the plugin" "$T/named.err" \
   && [ ! -s "$T/plain.err" ]'
tune clean alpha-named > /dev/null; tune clean alpha-plain > /dev/null

# --- run
tune run "$copy" --label before --max-cost-usd 4 > "$T/run.txt"; rc=$?
check "run passes the copy, the cost limit, and the result path to claude plugin eval" \
  '[ "$rc" = 0 ] && grep -qF "plugin eval $copy " "$CLAUDE_LOG" \
   && grep -qF -- "--scaffold" "$CLAUDE_LOG" && grep -qF -- "--trust-plugin" "$CLAUDE_LOG" && grep -qF -- "--no-publish" "$CLAUDE_LOG" \
   && grep -qF -- "--keep-temp" "$CLAUDE_LOG" && grep -qF -- "--max-cost-usd 4" "$CLAUDE_LOG" \
   && grep -qF -- "--json $D/runs/alpha-before/results/before.json" "$CLAUDE_LOG" && [ -f "$D/runs/alpha-before/results/before.json" ] \
   && ! tune run "$copy" --label again --max-cost-usd 0 >/dev/null 2>&1'
: > "$CLAUDE_LOG"
tune run "$copy" --label open > /dev/null; rc_open=$?
check "run without --max-cost-usd passes no limit to claude plugin eval" \
  '[ "$rc_open" = 0 ] && grep -qF "plugin eval $copy " "$CLAUDE_LOG" && ! grep -qF -- "--max-cost-usd" "$CLAUDE_LOG"'
: > "$CLAUDE_LOG"
tune run "$copy" --label one --case alpha-one > /dev/null; rc_one=$?
grep -qF -- "--case alpha-one" "$CLAUDE_LOG"; logged_one=$?
: > "$CLAUDE_LOG"
tune run "$copy" --label two --case alpha-one --case alpha-two 2> "$T/two.err"; rc_two=$?
check "run passes one --case on, and refuses a second one instead of dropping it" \
  '[ "$rc_one" = 0 ] && [ "$logged_one" = 0 ] && [ "$rc_two" = 2 ] && [ ! -s "$CLAUDE_LOG" ] \
   && grep -qF -- "--case takes one glob" "$T/two.err"'

# --- summary
tune summary "$T/before.json" --indicator check-line > "$T/summary.txt"
tune summary "$T/before.json" > "$T/summary-all.txt"
check "summary scores each case without the indicator graders" \
  'grep -qx "case alpha-one  with 1.00 (n=2)  without 0.00 (n=1)" "$T/summary.txt" \
   && grep -qx "case alpha-two  with 1.00 (n=1)  without 1.00 (n=1)" "$T/summary.txt" \
   && grep -qx "case alpha-one  with 0.75 (n=2)  without 0.00 (n=1)" "$T/summary-all.txt" \
   && grep -qx "  check-line  with 1/2  without 0/1  (indicator)" "$T/summary.txt" \
   && grep -qx "  only-shown  with 0/1  without 0/0  (indicator)" "$T/summary-all.txt"'
check "summary averages the runs where the skill fired and adds up the cost" \
  'grep -qx "runs where the skill fired: 2, average 0.250 USD, 15 s, 5.0 turns" "$T/summary.txt" \
   && grep -qx "total cost: 0.72 USD" "$T/summary.txt"'

# --- compare
tune compare --before "$T/before.json" --after "$T/after.json" --indicator check-line > "$T/compare.txt"; rc_lower=$?
tune compare --before "$T/before.json" --after "$T/after.json" "$T/rerun.json" --indicator check-line > "$T/compare2.txt"; rc_kept=$?
check "compare fails when a case scores lower after" \
  '[ "$rc_lower" = 1 ] && grep -qx "alpha-one  before 1.00  after 0.00  lower" "$T/compare.txt"'
check "compare takes each case from the last file that holds it" \
  '[ "$rc_kept" = 0 ] && grep -qx "alpha-one  before 1.00  after 1.00  kept" "$T/compare2.txt" \
   && grep -qx "alpha-two  before 1.00  after 1.00  kept" "$T/compare2.txt"'

# --- estimate
tune estimate "$T/preflight.json" --runs 3 > "$T/estimate.txt"
check "estimate projects the cost of the baseline and the after runs from the preflight" \
  'grep -qx "baseline, with and without the skill, 3 runs: 3.12 USD" "$T/estimate.txt" \
   && grep -qx "after, with the skill only, 3 runs: 1.56 USD" "$T/estimate.txt" && grep -qx "total: 4.68 USD" "$T/estimate.txt"'

# --- trace
tune trace "$T/before.json" --case alpha-one > "$T/trace.txt"
check "trace prints the tool calls of each run" \
  'grep -qx "== with run 1" "$T/trace.txt" && grep -qxF "CALL Bash {\"command\": \"echo hi\"}" "$T/trace.txt" \
   && grep -qx "  RESULT hi" "$T/trace.txt" && grep -qx "== with run 2: no trace kept" "$T/trace.txt"'

# --- clean (the kept eval folder of a result in the run folder goes with it; others stay)
cp "$T/before.json" "$D/runs/alpha-before/results/before.json"
chmod 000 "$T/tmp/e-abc123/sealed"
tune clean alpha-before > /dev/null
check "clean removes the copies and the kept eval folders" \
  '[ ! -e "$D/runs/alpha-before" ] && [ ! -e "$T/tmp/e-abc123" ] && [ -d "$T/tmp/e-keep99" ] && [ -d "$D" ]'

# --- clean while another session's eval runs: the copy stays until the eval ends
busy="$(tune copy "$R/plugins/alpha" --label busy)"
stale="$(tune copy "$R/plugins/alpha" --label stale)"
# A mark left by an eval whose process is gone does not keep its copy.
printf '99999999\n' > "$D/runs/alpha-stale/running"
cat > "$T/during.sh" <<SH
python3 "$SCRIPT" clean --all
python3 "$SCRIPT" clean alpha-busy
echo "named clean exit \$?"
SH
CLAUDE_DURING="$T/during.sh" CLAUDE_DURING_LOG="$T/during.txt" tune run "$busy" --label busy > /dev/null; rc_busy=$?
kept_after_run=1; [ -d "$busy" ] && kept_after_run=0
tune clean --all > "$T/after.txt"
check "clean keeps a copy while an eval runs on it, and removes it once the eval has ended" \
  '[ "$rc_busy" = 0 ] && [ "$kept_after_run" = 0 ] && [ ! -e "$stale" ] \
   && grep -qF "kept $D/runs/alpha-busy: an eval is running on it" "$T/during.txt" \
   && grep -qxF "named clean exit 1" "$T/during.txt" \
   && grep -qxF "removed $D/runs/alpha-busy" "$T/after.txt" && [ ! -e "$D/runs/alpha-busy" ]'

# --- labels: a person's pass or fail on the outputs an llm grader read, and the checks of the grader
# The gamma plugin has one case with an llm grader that reads a file and a regex grader. Its result holds
# 13 runs with the plugin, the last of which kept no text, and 12 runs without it.
G="$R/plugins/gamma"
mkdir -p "$G/skills/gamma" "$G/evals/judged"
printf -- '---\nname: gamma\ndescription: Writes a report. Use when testing.\n---\n\n# Gamma\n\nWrite a report.\n' > "$G/skills/gamma/SKILL.md"
cat > "$G/evals/judged/case.yaml" <<'YAML'
schema_version: "1.1"
name: gamma-judged
plugins: ["../.."]
execution:
  prompt: |
    Write the report.
  max_turns: 10
graders:
  - name: skill-fired
    type: tool_used
    tool: Skill
    input_match: 'gamma'
    arm: with-only
  - name: judge
    type: llm
    focus: {source: file, path: out/report.md}
    criteria: |
      PASS if the report names the owner.
      FAIL if it names no owner.
  - name: check-line
    type: regex
    target: {source: file, path: out/report.md}
    pattern: 'owner'
YAML
python3 - "$T" <<'PY'
import json, os, sys
T = sys.argv[1]

def run(arm, i, human, text=True):
    judge = {"name": "judge", "passed": human, "weight": 1, "withOnly": False, "scored": True,
             "explanation": "judge votes: PASS PASS PASS" if human else "judge votes: FAIL FAIL FAIL"}
    if text:
        judge["evidence"] = "report from the %s run %d" % (arm, i)
    return {"score": 1, "passed": True, "turns": 3, "costUsd": 0.1, "judgeCostUsd": 0.01, "durationSeconds": 9,
            "error": None, "tracePath": None,
            "graders": [judge, {"name": "check-line", "passed": True, "weight": 1, "withOnly": False, "scored": True}]}

case = {"name": "gamma-judged",
        "graders": [{"name": "judge", "type": "llm", "config": {"criteria": "PASS if the report names the owner.",
                                                              "focus": {"source": "file", "path": "out/report.md"}}},
                    {"name": "check-line", "type": "regex"}],
        "arms": {"with": [run("with", i, True) for i in range(1, 13)] + [run("with", 13, True, text=False)],
                 "without": [run("without", i, False) for i in range(1, 13)]}}
with open(os.path.join(T, "labeled.json"), "w") as f:
    json.dump({"cases": [case]}, f)
PY
LF="$G/evals/labels/gamma-judged/judge.json"
lbl() { tune label "$T/labeled.json" --case gamma-judged "$@"; }

shown="$(lbl --grader judge --arm with --run 2)"; rc_shown=$?
check "label shows the text an llm grader read without its verdict" \
  '[ "$rc_shown" = 0 ] && [ "$shown" = "report from the with run 2" ] && [ ! -e "$G/evals/labels" ]'

first="$(lbl --grader judge --arm with --run 1 --verdict pass --into "$G" | tail -n 1)"
for i in 2 3 4 5 6 7 8 9 10 11 12; do lbl --grader judge --arm with --run "$i" --verdict pass --into "$G" > /dev/null; done
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do lbl --grader judge --arm without --run "$i" --verdict fail --into "$G" > /dev/null; done
changed="$(lbl --grader judge --arm with --run 1 --verdict fail --into "$G" | tail -n 1)"
again="$(lbl --grader judge --arm with --run 1 --verdict pass --into "$G" | tail -n 1)"
# A label file in the form label writes: version 1, its case and grader, and each label with its verdict and text.
label_file_ok() {
  python3 - "$LF" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
labels = data.get("labels", [])
one = [l for l in labels if l.get("text") == "report from the with run 1"]
ok = (data.get("version") == 1 and data.get("case") == "gamma-judged" and data.get("grader") == "judge"
      and len(labels) == 24 and len(one) == 1 and one[0].get("verdict") == "pass"
      and sum(1 for l in labels if l.get("verdict") == "fail") == 12)
sys.exit(0 if ok else 1)
PY
}
check "label records the verdict with the text and counts both sides" \
  '[ "$first" = "labels for gamma-judged/judge: passes 1/12, fails 0/12" ] \
   && [ "$changed" = "labels for gamma-judged/judge: passes 11/12, fails 13/12" ] \
   && [ "$again" = "labels for gamma-judged/judge: passes 12/12, fails 12/12" ] && label_file_ok'

sum_before="$(cksum < "$LF" 2>/dev/null)"
lbl --grader check-line --arm with --run 3 --verdict pass --into "$G" 2> "$T/regex.err"; rc_regex=$?
lbl --grader judge --arm with --run 99 --verdict pass --into "$G" 2> /dev/null; rc_missing=$?
lbl --grader judge --arm with --run 13 --verdict pass --into "$G" 2> /dev/null; rc_bare=$?
lbl --grader judge --arm with --run 13 > /dev/null 2>&1; rc_bare_show=$?
check "label refuses a grader that is not llm, a missing run, and a verdict without text" \
  '[ "$rc_regex" = 2 ] && [ "$rc_missing" = 2 ] && [ "$rc_bare" = 2 ] && [ "$rc_bare_show" = 2 ] \
   && [ "$(cksum < "$LF")" = "$sum_before" ] && grep -qF "llm" "$T/regex.err"'

# The split label-cases keeps in the label file: how many labels each part holds, and each label's part.
cat > "$T/split.py" <<'PY'
import json, sys
labels = json.load(open(sys.argv[1], encoding="utf-8"))["labels"]
parts = {}
for l in labels:
    key = l.get("set", "") + ("-" + l["verdict"] if l.get("set") == "held" else "")
    parts[key] = parts.get(key, 0) + 1
print(" ".join("%s=%d" % kv for kv in sorted(parts.items())))
print(",".join(l.get("set", "") for l in labels))
if len(sys.argv) > 2:
    for l in labels:
        if l.get("set") == sys.argv[2]:
            print(l["text"])
PY
gcopy="$(tune copy "$G" --label lbl)"
tune label-cases "$gcopy" --labels "$LF" --set tune > "$T/lc.txt"; rc_lc=$?
split1="$(python3 "$T/split.py" "$LF")"
tune label-cases "$gcopy" --labels "$LF" --set tune > /dev/null
split2="$(python3 "$T/split.py" "$LF")"
python3 "$T/split.py" "$LF" held | tail -n +3 > "$T/held-texts.txt"
# Every tuning case grades the copy's current grader on the label's text, put where the grader reads it.
tuning_cases_ok() {
  local dirs d n
  dirs="$(find "$gcopy/label-evals" -mindepth 1 -maxdepth 1 -type d -name 'tune-*' | sort)"
  [ "$(printf '%s\n' "$dirs" | grep -c .)" = 11 ] || return 1
  [ -z "$(find "$gcopy/label-evals" -mindepth 1 -maxdepth 1 -type d ! -name 'tune-*' ! -name results)" ] || return 1
  for d in $dirs; do
    n="$(basename "$d")"
    grep -qx "name: $n" "$d/case.yaml" && grep -qF "PASS if the report names the owner." "$d/case.yaml" \
      && grep -qF "focus: {source: file, path: out/report.md}" "$d/case.yaml" && ! grep -qF "check-line" "$d/case.yaml" \
      && grep -qF "out/report.md" "$d/fixture.sh" || return 1
    python3 - "$LF" "$n" "$d" <<'PY' || return 1
import json, os, sys
labels = json.load(open(sys.argv[1], encoding="utf-8"))["labels"]
label = labels[int(sys.argv[2].split("-")[1]) - 1]
text = open(os.path.join(sys.argv[3], "text"), encoding="utf-8").read()
sys.exit(0 if label.get("set") == "tune" and text == label["text"] else 1)
PY
  done
}
no_held_text_shown() {
  local line
  [ -s "$T/held-texts.txt" ] || return 1
  while IFS= read -r line; do grep -qxF "$line" "$T/lc.txt" && return 1; done < "$T/held-texts.txt"
  return 0
}
check "label-cases fixes the split once and writes one case per tuning label" \
  '[ "$rc_lc" = 0 ] && [ "$(printf "%s\n" "$split1" | head -n 1)" = "example=3 held-fail=5 held-pass=5 tune=11" ] \
   && [ "$split1" = "$split2" ] && tuning_cases_ok && no_held_text_shown'

# --- run on another eval folder
: > "$CLAUDE_LOG"
tune run "$gcopy" --label lbl1 --eval-dir label-evals > /dev/null; rc_dir=$?
grep -qF -- "--eval-dir label-evals" "$CLAUDE_LOG"; logged_dir=$?
: > "$CLAUDE_LOG"
tune run "$gcopy" --label lbl2 --eval-dir nowhere 2> /dev/null; rc_nowhere=$?
check "run passes --eval-dir to claude plugin eval" \
  '[ "$rc_dir" = 0 ] && [ "$logged_dir" = 0 ] && [ "$rc_nowhere" = 2 ] && [ ! -s "$CLAUDE_LOG" ]'

# --- agree: results of the label cases, where the grader differs from the person on some labels
# Writes a result for the labels of one part; flips the grader's verdict on the first N human passes
# and the first M human fails, and leaves K cases without a run. Prints the human passes and fails.
cat > "$T/agree.py" <<'PY'
import json, sys
path, part, out, flip_pass, flip_fail, missing = sys.argv[1], sys.argv[2], sys.argv[3], *map(int, sys.argv[4:7])
labels = json.load(open(path, encoding="utf-8"))["labels"]
cases, passes, fails = [], 0, 0
for i, l in enumerate(labels, 1):
    if l.get("set") != part:
        continue
    human = l["verdict"] == "pass"
    passes, fails = passes + human, fails + (not human)
    grader = human
    if human and flip_pass:
        grader, flip_pass = False, flip_pass - 1
    elif not human and flip_fail:
        grader, flip_fail = True, flip_fail - 1
    runs = [{"graders": [{"name": "judge", "passed": grader, "scored": True, "withOnly": False}]}]
    if missing:
        runs, missing = [], missing - 1
    cases.append({"name": "%s-%02d" % (part, i), "arms": {"with": runs, "without": []}})
json.dump({"cases": cases}, open(out, "w"))
print(passes, fails)
PY
read -r tp tf < <(python3 "$T/agree.py" "$LF" tune "$T/agree-tune.json" 1 0 0)
tune agree "$T/agree-tune.json" --labels "$LF" > "$T/agree-tune.txt"; rc_tune=$?
check "agree counts human passes and human fails apart" \
  '[ "$rc_tune" = 0 ] \
   && grep -qxF "tune: human passes the grader passed: $((tp - 1))/$tp ($(python3 -c "print(\"%.2f\" % (($tp - 1) / $tp))"))" "$T/agree-tune.txt" \
   && grep -qxF "tune: human fails the grader failed: $tf/$tf (1.00)" "$T/agree-tune.txt"'

tune label-cases "$gcopy" --labels "$LF" --set held > /dev/null; rc_held_cases=$?
held_cases="$(find "$gcopy/label-evals" -mindepth 1 -maxdepth 1 -type d -name 'held-*' | grep -c .)"
python3 "$T/agree.py" "$LF" held "$T/agree-held.json" 0 1 0 > /dev/null
tune agree "$T/agree-held.json" --labels "$LF" > "$T/agree-held.txt"; rc_held=$?
check "agree trusts a grader at 4 of 5 on each held-back side" \
  '[ "$rc_held_cases" = 0 ] && [ "$held_cases" = 10 ] && [ "$rc_held" = 0 ] \
   && grep -qxF "held: human passes the grader passed: 5/5 (1.00)" "$T/agree-held.txt" \
   && grep -qxF "held: human fails the grader failed: 4/5 (0.80)" "$T/agree-held.txt" \
   && grep -qxF "trusted: judge counts in the score" "$T/agree-held.txt"'

python3 "$T/agree.py" "$LF" held "$T/agree-low.json" 2 0 0 > /dev/null
tune agree "$T/agree-low.json" --labels "$LF" > "$T/agree-low.txt"; rc_low=$?
python3 "$T/agree.py" "$LF" held "$T/agree-gap.json" 0 0 1 > /dev/null
tune agree "$T/agree-gap.json" --labels "$LF" > "$T/agree-gap.txt"; rc_gap=$?
check "agree does not trust a grader below 4 of 5 on either held-back side" \
  '[ "$rc_low" = 1 ] && grep -qxF "held: human passes the grader passed: 3/5 (0.60)" "$T/agree-low.txt" \
   && grep -q "^not trusted: .*--indicator judge" "$T/agree-low.txt" && ! grep -q "^trusted:" "$T/agree-low.txt" \
   && [ "$rc_gap" = 1 ] && grep -qx "not measured: 1" "$T/agree-gap.txt" && grep -q "^not trusted: " "$T/agree-gap.txt"'

# Too few labels: a label file with one pass less and no split yet.
python3 - "$LF" "$T/few.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
drop = next(i for i, l in enumerate(data["labels"]) if l["verdict"] == "pass")
data["labels"] = [dict(l, set="") for i, l in enumerate(data["labels"]) if i != drop]
data["checks"] = []
json.dump(data, open(sys.argv[2], "w"))
PY
fcopy="$(tune copy "$G" --label few)"
tune label-cases "$fcopy" --labels "$T/few.json" --set tune 2> "$T/few.err"; rc_few=$?
sum_checked="$(cksum < "$LF")"
tune label-cases "$gcopy" --labels "$LF" --set held 2> "$T/reheld.err"; rc_reheld=$?
check "label-cases refuses too few labels and a held-back part already checked" \
  '[ "$rc_few" = 2 ] && [ ! -e "$fcopy/label-evals" ] && grep -qF "11" "$T/few.err" \
   && [ "$rc_reheld" = 2 ] && [ "$(cksum < "$LF")" = "$sum_checked" ] && grep -qF "checked" "$T/reheld.err"'

# --- SKILL.md
SKILL="$SKILL_DIR/SKILL.md"
skill_rules() {
  local phrase
  [ -f "$SKILL" ] || return 1
  for phrase in \
    "The Write tool cannot write outside the workspace" \
    "There is no network and no browser" \
    "A process cannot listen on a local port" \
    '`regex` patterns are JavaScript regular expressions' \
    '`tool_used` matches `input_match` against the input as JSON text' \
    '`git` fails' \
    'a script that runs `git` stops there' \
    "Grade the files the run leaves in the workspace" \
    "An LLM judge can fail a reply that meets every condition" \
    "Spend nothing before the user agrees" \
    "Pass \`--max-cost-usd\` only when the user names a limit" \
    "In agents other than Claude Code, stop before measuring" \
    "only on plugins the user wrote or trusts" \
    'Never run `clean --all`' \
    'Name the grader that shows the skill started `skill-fired`' \
    'for a skill with `disable-model-invocation: true`' \
    'The run'"'"'s `HOME` is itself a repository' \
    'a file named `report.html`'; do
    grep -qF -- "$phrase" "$SKILL" || return 1
  done
}
check "the SKILL.md keeps its rules on the sandbox, graders, cost, and other agents" "skill_rules"

# The two steps that come before trusting a grader: phrases that only the failure-type step holds, and
# phrases that only the grader check holds, so removing either step drops one of the two sets.
types_step() {
  local phrase
  for phrase in "Read every output" "pass or fail by yes or no" "one grader per failure type"; do
    grep -qF -- "$phrase" "$1" || return 1
  done
}
grader_step() {
  local phrase
  for phrase in "share of human passes" "share of human fails" "held back" \
    "Passing a found problem as minor" "Testing only the surface"; do
    grep -qF -- "$phrase" "$1" || return 1
  done
}
skill_steps() { [ -f "$1" ] && types_step "$1" && grader_step "$1" && grep -qF 'references/graders.md' "$1"; }
REF="$SKILL_DIR/references/graders.md"
graders_ref() {
  local word
  [ -f "$REF" ] || return 1
  for word in 'label-cases' 'agree' '4 of the 5' '--indicator' 'failure type'; do
    grep -qF -- "$word" "$REF" || return 1
  done
}
check "the SKILL.md keeps the failure-type step and the grader check" 'skill_steps "$SKILL" && graders_ref'

# Writes the SKILL.md without the step whose heading holds the given words; fails when no heading does.
without_step() {
  python3 - "$SKILL" "$1" "$2" <<'PY'
import re, sys
src, words, out = sys.argv[1:]
parts = re.split(r"(?m)^(?=## )", open(src, encoding="utf-8").read())
kept = [p for p in parts if not (p.startswith("## ") and words in p.splitlines()[0])]
open(out, "w", encoding="utf-8").write("".join(kept))
sys.exit(0 if len(kept) < len(parts) else 1)
PY
}
step_check_bites() {
  skill_steps "$SKILL" || return 1
  without_step "Read every output" "$T/no-types.md" || return 1
  without_step "against labels" "$T/no-check.md" || return 1
  ! skill_steps "$T/no-types.md" && ! skill_steps "$T/no-check.md"
}
check "the step check fails on a SKILL.md without either new step" "step_check_bites"

SKILL_WORDS_MAX=2209
SKILL_DESCRIPTION_MAX=357
skill_size() {
  [ -f "$SKILL" ] || return 1
  local words chars
  words="$(tune size "$SKILL" | sed -n 's/^body: \([0-9]*\) words$/\1/p')"
  chars="$(tune size "$SKILL" | sed -n 's/^description: \([0-9]*\) characters$/\1/p')"
  printf '      body %s words (max %s), description %s characters (max %s)\n' "$words" "$SKILL_WORDS_MAX" "$chars" "$SKILL_DESCRIPTION_MAX"
  [ -n "$words" ] && [ -n "$chars" ] && [ "$words" -le "$SKILL_WORDS_MAX" ] && [ "$chars" -le "$SKILL_DESCRIPTION_MAX" ]
}
check "the SKILL.md stays within its size limits" "skill_size"

# A reader learns that measuring needs Claude Code and paid runs before the steps and the diagram.
readme_cost_first() {
  local f cost fence
  for f in README.md README.ja.md; do
    cost="$(grep -n 'Claude Code' "$SKILL_DIR/../../$f" | grep -F 'USD' | head -1 | cut -d: -f1)"
    fence="$(grep -n '^```' "$SKILL_DIR/../../$f" | head -1 | cut -d: -f1)"
    [ -n "$cost" ] && [ -n "$fence" ] && [ "$cost" -lt "$fence" ] \
      || { echo "      $f does not say before its first diagram that measuring needs Claude Code and costs USD per run"; return 1; }
  done
}
check "the READMEs say before the steps what measuring needs and costs" "readme_cost_first"

# Every page a reader opens names the commands of the grader check; the How it works pages also say the bar.
docs_grader_check() {
  local f word base="$SKILL_DIR/../.."
  for f in docs/how-it-works.md docs/how-it-works.ja.md README.md README.ja.md CHANGELOG.md; do
    for word in 'label-cases' 'agree'; do
      grep -qF -- "$word" "$base/$f" || { echo "      $f does not name $word"; return 1; }
    done
  done
  grep -qF "failure type" "$base/docs/how-it-works.md" && grep -qF "4 of the 5" "$base/docs/how-it-works.md" \
    && grep -qF "$(printf '5\344\273\266\344\270\2554\344\273\266')" "$base/docs/how-it-works.ja.md" \
    || { echo "      a How it works page does not give the failure types or the bar of 4 of the 5"; return 1; }
}
check "the docs describe the failure types and the grader check" "docs_grader_check"

printf '\n%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" = 0 ]
