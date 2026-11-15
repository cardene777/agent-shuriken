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
exit 0
SH
chmod +x "$T/bin/claude"

# --- a sample repository with two plugins
R="$T/repo"
mkdir -p "$R/plugins/alpha/skills/alpha/scripts/__pycache__" "$R/plugins/alpha/evals/one" "$R/plugins/alpha/evals/two" \
  "$R/plugins/alpha/evals/results" "$R/plugins/beta/skills/beta"
printf -- '---\nname: alpha\ndescription: Does a thing. Use when testing.\n---\n\n# Alpha\n\nOne two three four five.\n' \
  > "$R/plugins/alpha/skills/alpha/SKILL.md"
printf -- '---\nname: beta\ndescription: Does another thing.\n---\n\n# Beta\n\nOne two three four five six seven eight nine ten.\n' \
  > "$R/plugins/beta/skills/beta/SKILL.md"
printf 'name: one\n' > "$R/plugins/alpha/evals/one/case.yaml"
printf 'name: two\n' > "$R/plugins/alpha/evals/two/case.yaml"
printf '{}\n' > "$R/plugins/alpha/evals/results/old.json"
printf 'x\n' > "$R/plugins/alpha/skills/alpha/scripts/__pycache__/run.cpython-312.pyc"
printf 'print(1)\n' > "$R/plugins/alpha/skills/alpha/scripts/run.py"

# --- eval results in the shape claude plugin eval writes
python3 - "$T" <<'PY'
import json, os, sys
T = sys.argv[1]

def run(cost, judge, sec, turns, graders, trace=None):
    return {"score": 0, "passed": True, "turns": turns, "costUsd": cost, "judgeCostUsd": judge,
            "durationSeconds": sec, "error": None, "tracePath": trace,
            "graders": [{"name": n, "passed": p, "weight": 1, "withOnly": w, "scored": not w} for n, p, w in graders]}

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

before = {"cases": [
    case_a([run(0.20, 0.01, 10, 4, [("skill-fired", True, True), ("check-line", False, False), ("result", True, False)], trace),
            run(0.30, 0.01, 20, 6, [("skill-fired", True, True), ("check-line", True, False), ("result", True, False)])],
           [run(0.10, 0.0, 5, 3, [("skill-fired", False, True), ("check-line", False, False), ("result", False, False)])]),
    {"name": "alpha-two", "arms": {"with": [run(0.05, 0.0, 3, 2, [("skill-not-fired", True, False)])],
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

# --- run
tune run "$copy" --label before --max-cost-usd 4 > "$T/run.txt"; rc=$?
check "run passes the copy, the cost limit, and the result path to claude plugin eval" \
  '[ "$rc" = 0 ] && grep -qF "plugin eval $copy " "$CLAUDE_LOG" \
   && grep -qF -- "--scaffold" "$CLAUDE_LOG" && grep -qF -- "--trust-plugin" "$CLAUDE_LOG" && grep -qF -- "--no-publish" "$CLAUDE_LOG" \
   && grep -qF -- "--keep-temp" "$CLAUDE_LOG" && grep -qF -- "--max-cost-usd 4" "$CLAUDE_LOG" \
   && grep -qF -- "--json $D/runs/alpha-before/results/before.json" "$CLAUDE_LOG" && [ -f "$D/runs/alpha-before/results/before.json" ] \
   && ! tune run "$copy" --label again >/dev/null 2>&1'

# --- summary
tune summary "$T/before.json" --indicator check-line > "$T/summary.txt"
tune summary "$T/before.json" > "$T/summary-all.txt"
check "summary scores each case without the indicator graders" \
  'grep -qx "case alpha-one  with 1.00 (n=2)  without 0.00 (n=1)" "$T/summary.txt" \
   && grep -qx "case alpha-two  with 1.00 (n=1)  without 1.00 (n=1)" "$T/summary.txt" \
   && grep -qx "case alpha-one  with 0.75 (n=2)  without 0.00 (n=1)" "$T/summary-all.txt" \
   && grep -qx "  check-line  with 1/2  without 0/1  (indicator)" "$T/summary.txt"'
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

# --- SKILL.md
SKILL="$SKILL_DIR/SKILL.md"
skill_rules() {
  local phrase
  [ -f "$SKILL" ] || return 1
  for phrase in \
    "The Write tool cannot write outside the workspace" \
    "There is no network and no browser" \
    '`git` fails' \
    "Grade the files the run leaves in the workspace" \
    "An LLM judge can fail a reply that meets every condition" \
    "ask the user how much they allow" \
    "In agents other than Claude Code, stop before measuring" \
    "only on plugins the user wrote or trusts"; do
    grep -qF -- "$phrase" "$SKILL" || return 1
  done
}
check "the SKILL.md keeps its rules on the sandbox, graders, cost, and other agents" "skill_rules"

SKILL_WORDS_MAX=1500
SKILL_DESCRIPTION_MAX=400
skill_size() {
  [ -f "$SKILL" ] || return 1
  local words chars
  words="$(tune size "$SKILL" | sed -n 's/^body: \([0-9]*\) words$/\1/p')"
  chars="$(tune size "$SKILL" | sed -n 's/^description: \([0-9]*\) characters$/\1/p')"
  printf '      body %s words (max %s), description %s characters (max %s)\n' "$words" "$SKILL_WORDS_MAX" "$chars" "$SKILL_DESCRIPTION_MAX"
  [ -n "$words" ] && [ -n "$chars" ] && [ "$words" -le "$SKILL_WORDS_MAX" ] && [ "$chars" -le "$SKILL_DESCRIPTION_MAX" ]
}
check "the SKILL.md stays within its size limits" "skill_size"

printf '\n%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" = 0 ]
