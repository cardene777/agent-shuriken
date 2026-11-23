#!/usr/bin/env python3
"""Measure a plugin's skill with `claude plugin eval` and compare it before and after a change.

Commands
  size <SKILL.md>                       Body words and description characters
  list <folder>                         Every skill under the folder, longest body first, with its eval cases
  copy <plugin> --label L [--replace]   Copy the plugin into the data folder, without eval results and caches
  run <copy> --label L [--max-cost-usd U] [--case GLOB] [--runs N] [--ablation MODE] [-j N] [--eval-dir DIR]
                                        Run `claude plugin eval` on a copy; the result is results/<L>.json
  summary <result.json>... [--indicator NAME]... [--fired NAME]
                                        Scores per case and arm, grader counts, averages, and cost
  compare --before <json>... --after <json>... [--indicator NAME]...
                                        Each case's score before and after; exit 1 when one is lower
  estimate <preflight.json> [--runs N]  The cost of the baseline and the after runs, from one run per case
  trace <result.json> --case NAME [--arm with|without]
                                        The tool calls and results of each run of a case
  clean <run name> | --all              Remove copies, their results, and the eval folders they kept, except a copy run is evaluating
  label <result.json> --case C --grader G --arm with|without --run N [--verdict pass|fail --into <plugin>]
                                        Print the text an llm grader read in one run, or record a person's verdict on it
  label-cases <copy> --labels <file> --set tune|held
                                        Write one small case per label of a part into <copy>/label-evals/
  agree <result.json> --labels <file>   How often the grader agreed with the person, for human passes and fails apart

When several result files are given, each case comes from the last file that holds it.
A run's score is the share of its scored graders that passed, leaving out with-only graders and
the graders named with --indicator; a case's score is the mean over its runs.

A label file, <plugin>/evals/labels/<case>/<grader>.json, holds version 1, the case, the grader, the
labels (an id, the verdict, the text the grader read, and the part: example, tune, held, or none yet),
and the checks of held-back parts. label-cases needs 12 passes and 12 fails, and on its first call sets
3 labels aside as examples and holds 5 passes and 5 fails back at random; agree trusts a grader when it
agrees on at least 4 of the 5 held-back passes and 4 of the 5 held-back fails.

The data folder is $SKILL_TUNE_HOME, by default ~/.local/share/skill-tune, readable only by the user.
Exit codes: 0 done; 1 a case scored lower, nothing to show, or agree does not trust the grader;
2 bad input; 3 `claude` is missing; 3 also when compare finds a case measured on one side only.
`run` passes on the exit code of `claude plugin eval` (2 when a --max-cost-usd limit stopped it).
"""
import argparse
import glob
import json
import os
import random
import re
import shutil
import subprocess
import sys
import time

LABEL = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
KEPT = re.compile(r"^e-[A-Za-z0-9]{6,}$")
# The file run writes next to a copy while claude plugin eval runs on it, holding run's process id.
RUNNING = "running"
# The grader check: a label file's version, the labels needed of each side, the examples set aside,
# the labels of each side held back, the agreements needed on each held-back side, and where
# label-cases writes its cases in a copy.
LABELS_VERSION = 1
NEEDED = 12
EXAMPLES = 3
HELD = 5
BAR = 4
LABEL_EVALS = "label-evals"
LABEL_CASE = re.compile(r"^(tune|held)-([0-9]+)$")
# Where a label case puts the text of a grader that reads the reply instead of a file.
REPLY_TEXT = "label-text.md"


def fail(message, code=2):
    print("skill-tune: " + message, file=sys.stderr)
    sys.exit(code)


def data_home():
    home = os.environ.get("SKILL_TUNE_HOME") or os.path.join(os.path.expanduser("~"), ".local", "share", "skill-tune")
    return os.path.abspath(home)


def private_dir(path):
    os.makedirs(path, exist_ok=True)
    os.chmod(path, 0o700)
    return path


# --- size and list

def read_skill(path):
    """(body words, description characters) of a SKILL.md."""
    try:
        text = open(path, encoding="utf-8").read()
    except OSError as e:
        fail("cannot read %s: %s" % (path, e.strerror))
    parts = text.split("---", 2)
    if not text.startswith("---") or len(parts) < 3:
        fail("%s has no frontmatter between --- lines" % path)
    front, body = parts[1], parts[2]
    lines = front.splitlines()
    desc = ""
    for i, line in enumerate(lines):
        m = re.match(r"^description:\s*(.*)$", line)
        if not m:
            continue
        desc = m.group(1).strip()
        if desc in (">", "|", ">-", "|-", ">+", "|+"):
            block = []
            for nxt in lines[i + 1:]:
                if nxt and not nxt[0].isspace():
                    break
                block.append(nxt.strip())
            desc = " ".join(x for x in block if x)
        elif len(desc) >= 2 and desc[0] == desc[-1] and desc[0] in "\"'":
            desc = desc[1:-1]
        break
    return len(body.split()), len(desc)


def cmd_size(args):
    words, chars = read_skill(args.skill)
    print("body: %d words" % words)
    print("description: %d characters" % chars)


def eval_cases(plugin):
    cases = 0
    for root, dirs, files in os.walk(os.path.join(plugin, "evals")):
        dirs[:] = [d for d in dirs if d != "results"]
        cases += files.count("case.yaml")
    return cases


def cmd_list(args):
    folder = os.path.abspath(args.folder)
    found = set()
    for pattern in ("plugins/*/skills/*/SKILL.md", "*/skills/*/SKILL.md", "skills/*/SKILL.md"):
        found.update(glob.glob(os.path.join(folder, pattern)))
    if not found:
        fail("no skills/<name>/SKILL.md under %s" % folder, 1)
    rows = []
    for path in found:
        skill_dir = os.path.dirname(path)
        plugin = os.path.dirname(os.path.dirname(skill_dir))
        words, chars = read_skill(path)
        name = "%s/%s" % (os.path.basename(plugin), os.path.basename(skill_dir))
        rows.append((words, name, chars, eval_cases(plugin)))
    print("| Skill | Body words | Description characters | Eval cases |")
    print("|---|---|---|---|")
    for words, name, chars, cases in sorted(rows, key=lambda r: (-r[0], r[1])):
        print("| %s | %d | %d | %d |" % (name, words, chars, cases))


# --- copy, run, and clean

def ignore_for(plugin):
    evals = os.path.join(plugin, "evals")

    def ignore(folder, names):
        skip = {n for n in names if n in ("__pycache__", ".DS_Store")}
        if os.path.abspath(folder) == evals and "results" in names:
            skip.add("results")
        return skip
    return ignore


def cmd_copy(args):
    plugin = os.path.abspath(args.plugin)
    if not os.path.isdir(os.path.join(plugin, "skills")):
        fail("%s is not a plugin folder (it has no skills/ folder)" % plugin)
    if not LABEL.match(args.label):
        fail("a label uses letters, digits, '.', '_', and '-': %s" % args.label)
    name = "%s-%s" % (os.path.basename(plugin), args.label)
    runs = private_dir(os.path.join(private_dir(data_home()), "runs"))
    dest_dir = os.path.join(runs, name)
    if os.path.exists(dest_dir):
        if not args.replace:
            fail("%s already exists; pass --replace or use another label" % dest_dir)
        remove_run(dest_dir)
    private_dir(dest_dir)
    dest = os.path.join(dest_dir, os.path.basename(plugin))
    shutil.copytree(plugin, dest, ignore=ignore_for(plugin), symlinks=True)
    # claude plugin eval names its own report report.html and keeps the agent out of a plugin folder that
    # holds a file of that name, so the skill there can read none of its files and run none of its scripts.
    for root, _, files in os.walk(dest):
        if "report.html" in files:
            print("warning: %s is named report.html, the name of the eval's own report: claude plugin eval keeps "
                  "the agent out of the plugin's folder, so the skill can read none of its files and run none of "
                  "its scripts. Rename the file in the plugin before measuring."
                  % os.path.relpath(os.path.join(root, "report.html"), dest), file=sys.stderr)
    print(dest)


def cmd_run(args):
    copy = os.path.abspath(args.copy)
    evals = args.eval_dir or "evals"
    if not LABEL.match(evals):
        fail("--eval-dir names a folder in the copy with letters, digits, '.', '_', and '-': %s" % evals)
    if not os.path.isdir(os.path.join(copy, evals)):
        fail("%s has no %s/ folder" % (copy, evals))
    if not LABEL.match(args.label):
        fail("a label uses letters, digits, '.', '_', and '-': %s" % args.label)
    if args.max_cost_usd is not None:
        try:
            if float(args.max_cost_usd) <= 0:
                raise ValueError
        except ValueError:
            fail("--max-cost-usd takes a positive number of US dollars")
    if args.case and len(args.case) > 1:
        fail("--case takes one glob, since claude plugin eval filters by one; "
             "run the other cases in another run with a new label")
    if not shutil.which("claude"):
        fail("`claude plugin eval` comes with Claude Code; run this step in Claude Code", 3)
    results = private_dir(os.path.join(os.path.dirname(copy), "results"))
    out = os.path.join(results, args.label + ".json")
    log = os.path.join(results, args.label + ".log")
    cmd = ["claude", "plugin", "eval", copy, "--scaffold", "--allow-tools", "Bash", "Write", "Edit",
           "--trust-plugin", "--no-publish", "--threshold", "0", "-j", str(args.jobs), "--keep-temp",
           "--output-dir", os.path.join(results, args.label + "-out"), "--json", out]
    if args.max_cost_usd is not None:
        cmd += ["--max-cost-usd", args.max_cost_usd]
    if args.case:
        cmd += ["--case", args.case[0]]
    if args.runs:
        cmd += ["--runs", str(args.runs)]
    if args.ablation:
        cmd += ["--ablation", args.ablation]
    if args.eval_dir:
        cmd += ["--eval-dir", args.eval_dir]
    # The mark tells clean, in this session or another one, that this copy is being evaluated.
    mark = os.path.join(os.path.dirname(copy), RUNNING)
    with open(mark, "w", encoding="utf-8") as f:
        f.write("%d\n" % os.getpid())
    try:
        with open(log, "w", encoding="utf-8") as f:
            rc = subprocess.run(cmd, cwd=os.path.dirname(copy), stdout=f, stderr=subprocess.STDOUT).returncode
    finally:
        try:
            os.remove(mark)
        except OSError:
            pass
    os.chmod(log, 0o600)
    print("result: %s" % out)
    print("log: %s" % log)
    print("exit: %d" % rc)
    sys.exit(rc)


def make_removable(path):
    try:
        os.chmod(path, 0o700)
    except OSError:
        return
    for entry in os.listdir(path):
        child = os.path.join(path, entry)
        if os.path.isdir(child) and not os.path.islink(child):
            make_removable(child)


def kept_folders(run_dir):
    """The eval folders that claude plugin eval kept for the results in this run folder."""
    kept = set()
    for result in glob.glob(os.path.join(run_dir, "results", "*.json")):
        try:
            data = json.load(open(result, encoding="utf-8"))
        except (OSError, ValueError):
            continue
        for case in data.get("cases", []):
            for runs in case.get("arms", {}).values():
                for r in runs:
                    trace = r.get("tracePath") or ""
                    out = os.path.dirname(trace)
                    folder = os.path.dirname(out)
                    if os.path.basename(out) == "out" and KEPT.match(os.path.basename(folder)) and os.path.isdir(folder):
                        kept.add(folder)
    return kept


def running_pid(run_dir):
    """The process id of a run that is evaluating the copy in this folder now, or None.

    A mark whose process is gone, or that cannot be read, does not keep the copy."""
    try:
        with open(os.path.join(run_dir, RUNNING), encoding="utf-8") as f:
            pid = int(f.read().strip())
    except (OSError, ValueError):
        return None
    if pid <= 0:
        return None
    try:
        os.kill(pid, 0)
    except PermissionError:
        return pid
    except (OSError, OverflowError):
        return None
    return pid


def remove_run(run_dir):
    removed = []
    for folder in sorted(kept_folders(run_dir)):
        make_removable(folder)
        shutil.rmtree(folder)
        removed.append(folder)
    make_removable(run_dir)
    shutil.rmtree(run_dir)
    removed.append(run_dir)
    return removed


def cmd_clean(args):
    runs = os.path.join(data_home(), "runs")
    if args.all:
        names = sorted(os.listdir(runs)) if os.path.isdir(runs) else []
    elif args.name:
        names = [args.name]
    else:
        fail("name a run folder, or pass --all")
    if not names:
        print("nothing to remove")
        return
    for name in names:
        run_dir = os.path.join(runs, name)
        if not LABEL.match(name) or not os.path.isdir(run_dir):
            fail("no run folder %s" % run_dir, 1)
        pid = running_pid(run_dir)
        if pid is not None:
            kept = "kept %s: an eval is running on it (process %d)" % (run_dir, pid)
            if not args.all:
                fail(kept, 1)
            print(kept)
            continue
        for path in remove_run(run_dir):
            print("removed %s" % path)


# --- reading results

def load_cases(files):
    cases = {}
    for path in files:
        try:
            data = json.load(open(path, encoding="utf-8"))
        except (OSError, ValueError) as e:
            fail("cannot read %s: %s" % (path, e))
        for case in data.get("cases", []):
            cases[case["name"]] = case
    return cases


def run_score(run, indicators):
    graders = [g for g in run.get("graders", [])
               if g.get("scored", True) and not g.get("withOnly") and g["name"] not in indicators]
    if not graders:
        return None
    return sum(1 for g in graders if g.get("passed")) / len(graders)


def arm_score(runs, indicators):
    scores = [s for s in (run_score(r, indicators) for r in runs) if s is not None]
    return sum(scores) / len(scores) if scores else None


def fired_runs(cases, fired):
    runs = []
    for case in cases.values():
        for r in case.get("arms", {}).get("with", []):
            if any(g["name"] == fired and g.get("passed") for g in r.get("graders", [])):
                runs.append(r)
    return runs


def average_line(runs):
    if not runs:
        return "runs where the skill fired: 0"
    n = len(runs)
    return "runs where the skill fired: %d, average %.3f USD, %.0f s, %.1f turns" % (
        n, sum(r.get("costUsd") or 0 for r in runs) / n,
        sum(r.get("durationSeconds") or 0 for r in runs) / n, sum(r.get("turns") or 0 for r in runs) / n)


def run_cost(r):
    return (r.get("costUsd") or 0) + (r.get("judgeCostUsd") or 0)


def fmt(score):
    return "-" if score is None else "%.2f" % score


def cmd_summary(args):
    cases = load_cases(args.results)
    if not cases:
        fail("no cases in %s" % ", ".join(args.results), 1)
    indicators = set(args.indicator)
    total = seconds = 0.0
    for name, case in cases.items():
        arms = case.get("arms", {})
        w, o = arms.get("with", []), arms.get("without", [])
        print("case %s  with %s (n=%d)  without %s (n=%d)" % (
            name, fmt(arm_score(w, indicators)), len(w), fmt(arm_score(o, indicators)), len(o)))
        names = []
        for r in w + o:
            for g in r.get("graders", []):
                if g["name"] not in names:
                    names.append(g["name"])
        for g_name in names:
            def count(runs):
                hits = [g for r in runs for g in r.get("graders", []) if g["name"] == g_name]
                return "%d/%d" % (sum(1 for g in hits if g.get("passed")), len(hits))
            flagged = g_name in indicators or any(
                g.get("withOnly") or not g.get("scored", True) for r in w + o for g in r.get("graders", []) if g["name"] == g_name)
            print("  %s  with %s  without %s%s" % (g_name, count(w), count(o), "  (indicator)" if flagged else ""))
        for r in w + o:
            total += run_cost(r)
            seconds += r.get("durationSeconds") or 0
    print(average_line(fired_runs(cases, args.fired)))
    print("total cost: %.2f USD" % total)
    print("total time: %.0f s" % seconds)


def cmd_compare(args):
    before, after = load_cases(args.before), load_cases(args.after)
    indicators = set(args.indicator)
    lower = unmeasured = False
    for name in list(before) + [n for n in after if n not in before]:
        b = arm_score(before.get(name, {}).get("arms", {}).get("with", []), indicators)
        a = arm_score(after.get(name, {}).get("arms", {}).get("with", []), indicators)
        if b is None or a is None:
            status = "not measured"
            unmeasured = True
        elif a < b - 1e-9:
            status = "lower"
            lower = True
        elif a > b + 1e-9:
            status = "higher"
        else:
            status = "kept"
        print("%s  before %s  after %s  %s" % (name, fmt(b), fmt(a), status))
    print("before: " + average_line(fired_runs(before, args.fired)))
    print("after: " + average_line(fired_runs(after, args.fired)))
    if lower:
        sys.exit(1)
    if unmeasured:
        sys.exit(3)


def cmd_estimate(args):
    cases = load_cases([args.preflight])
    per_pass = 0.0
    for case in cases.values():
        runs = case.get("arms", {}).get("with", [])
        if runs:
            per_pass += sum(run_cost(r) for r in runs) / len(runs)
    if per_pass == 0:
        fail("no runs with the skill in %s" % args.preflight, 1)
    baseline, after = per_pass * args.runs * 2, per_pass * args.runs
    print("every case once: %.2f USD" % per_pass)
    print("baseline, with and without the skill, %d runs: %.2f USD" % (args.runs, baseline))
    print("after, with the skill only, %d runs: %.2f USD" % (args.runs, after))
    print("total: %.2f USD" % (baseline + after))
    print("A run without the skill is counted at the cost of a run with it, and reruns are not included.")


def one_line(text, limit):
    return " ".join(str(text).split())[:limit]


def cmd_trace(args):
    cases = load_cases([args.result])
    if args.case not in cases:
        fail("no case %s in %s" % (args.case, args.result), 1)
    for i, r in enumerate(cases[args.case].get("arms", {}).get(args.arm, []), 1):
        path = r.get("tracePath")
        if not path or not os.path.isfile(path):
            print("== %s run %d: no trace kept" % (args.arm, i))
            continue
        print("== %s run %d" % (args.arm, i))
        failed = [g["name"] for g in r.get("graders", []) if not g.get("passed")]
        if failed:
            print("  failed graders: %s" % ", ".join(failed))
        for line in open(path, encoding="utf-8", errors="replace"):
            try:
                event = json.loads(line)
            except ValueError:
                continue
            msg = event.get("message") if isinstance(event, dict) else None
            if not isinstance(msg, dict) or not isinstance(msg.get("content"), list):
                continue
            for part in msg["content"]:
                if not isinstance(part, dict):
                    continue
                if part.get("type") == "tool_use":
                    print("CALL %s %s" % (part.get("name"), json.dumps(part.get("input"), ensure_ascii=False)[:400]))
                elif part.get("type") == "tool_result":
                    body = part.get("content")
                    if isinstance(body, list):
                        body = " ".join(x.get("text", "") for x in body if isinstance(x, dict))
                    print("  RESULT %s" % one_line(body, 300))
                elif part.get("type") == "text" and msg.get("role") == "assistant":
                    print("TEXT %s" % one_line(part.get("text", ""), 300))


# --- labels and the grader check

def read_labels(path, new=None):
    """The label file at path. A missing file is refused, unless new gives (case, grader) to start one."""
    if not os.path.exists(path):
        if new is None:
            fail("no label file %s" % path)
        return {"version": LABELS_VERSION, "case": new[0], "grader": new[1], "labels": [], "checks": []}
    try:
        data = json.load(open(path, encoding="utf-8"))
    except (OSError, ValueError) as e:
        fail("cannot read %s: %s" % (path, e))
    if not isinstance(data, dict) or data.get("version") != LABELS_VERSION:
        fail("%s is a label file of version %s; this skill-tune reads version %d only"
             % (path, data.get("version") if isinstance(data, dict) else "unknown", LABELS_VERSION))
    if new is not None and (data.get("case"), data.get("grader")) != new:
        fail("%s holds labels for %s/%s, not %s/%s" % (path, data.get("case"), data.get("grader"), new[0], new[1]))
    data.setdefault("checks", [])
    return data


def write_labels(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    os.replace(tmp, path)


def label_count(data):
    passes = sum(1 for l in data["labels"] if l["verdict"] == "pass")
    fails = sum(1 for l in data["labels"] if l["verdict"] == "fail")
    return passes, fails


def labeled_text(args):
    """The text the llm grader read in the run that the arguments name; refuses anything else."""
    case = load_cases([args.result]).get(args.case)
    if case is None:
        fail("no case %s in %s" % (args.case, args.result))
    kinds = {g.get("name"): g.get("type") for g in case.get("graders", [])}
    if args.grader not in kinds:
        fail("case %s names no grader %s in %s" % (args.case, args.grader, args.result))
    if kinds[args.grader] != "llm":
        fail("%s is a %s grader; only llm graders are checked against labels" % (args.grader, kinds[args.grader] or "untyped"))
    runs = case.get("arms", {}).get(args.arm, [])
    if not 1 <= args.run <= len(runs):
        fail("case %s has %d runs %s the plugin, so there is no run %d" % (args.case, len(runs), args.arm, args.run))
    verdict = next((g for g in runs[args.run - 1].get("graders", []) if g.get("name") == args.grader), None)
    text = verdict.get("evidence") if verdict else None
    if not isinstance(text, str) or not text:
        fail("run %d %s the plugin kept no text for %s, so it cannot be labeled" % (args.run, args.arm, args.grader))
    return text


def label_id(result, arm, run):
    """The result named by its run folder and file when it is in the data folder, and by its file otherwise."""
    path = os.path.abspath(result)
    runs = os.path.join(data_home(), "runs") + os.sep
    name = os.path.relpath(path, runs) if path.startswith(runs) else os.path.basename(path)
    return "%s:%s:%d" % (name.replace(os.sep + "results" + os.sep, "/"), arm, run)


def cmd_label(args):
    text = labeled_text(args)
    if args.verdict is None:
        if args.into:
            fail("--into records a verdict; pass --verdict pass or --verdict fail with it")
        print(text.rstrip("\n"))
        return
    if not args.into:
        fail("--verdict needs --into <plugin folder>, where the label file is kept")
    plugin = os.path.abspath(args.into)
    if not os.path.isdir(os.path.join(plugin, "skills")):
        fail("%s is not a plugin folder (it has no skills/ folder)" % plugin)
    path = os.path.join(plugin, "evals", "labels", args.case, args.grader + ".json")
    data = read_labels(path, new=(args.case, args.grader))
    ident = label_id(args.result, args.arm, args.run)
    for label in data["labels"]:
        if label["id"] == ident:
            label["verdict"], label["text"] = args.verdict, text
            break
    else:
        data["labels"].append({"id": ident, "verdict": args.verdict, "text": text, "set": ""})
    write_labels(path, data)
    passes, fails = label_count(data)
    print("labeled %s %s in %s" % (ident, args.verdict, path))
    print("labels for %s/%s: passes %d/%d, fails %d/%d" % (args.case, args.grader, passes, NEEDED, fails, NEEDED))


def checked(data, ids):
    return any(sorted(c.get("ids", [])) == sorted(ids) for c in data["checks"])


def split_labels(data):
    """Sets the parts on the first call: 3 examples (a pass, a fail, and one more), 5 passes and 5 fails
    held back, and the rest to tune. Labels added later wait without a part. Returns whether it changed."""
    labels = data["labels"]
    if any(l.get("set") for l in labels):
        return False
    rng = random.SystemRandom()
    passes = [i for i, l in enumerate(labels) if l["verdict"] == "pass"]
    fails = [i for i, l in enumerate(labels) if l["verdict"] == "fail"]
    examples = [rng.choice(passes), rng.choice(fails)]
    examples.append(rng.choice([i for i in range(len(labels)) if i not in examples]))
    held = rng.sample([i for i in passes if i not in examples], HELD) + rng.sample([i for i in fails if i not in examples], HELD)
    for i, label in enumerate(labels):
        label["set"] = "example" if i in examples else "held" if i in held else "tune"
    return True


def redraw_held(data):
    """After a held-back part was checked, holds 5 new passes and 5 new fails back from the labels without a
    part, and moves the checked part and the other new labels to tune."""
    labels = data["labels"]
    fresh = [i for i, l in enumerate(labels) if not l.get("set")]
    fresh_passes = [i for i in fresh if labels[i]["verdict"] == "pass"]
    fresh_fails = [i for i in fresh if labels[i]["verdict"] == "fail"]
    if len(fresh_passes) < HELD or len(fresh_fails) < HELD:
        fail("the held-back part was checked already, and checking it again would test against labels seen "
             "while tuning; label %d more passes and %d more fails, then run label-cases --set held again"
             % (max(0, HELD - len(fresh_passes)), max(0, HELD - len(fresh_fails))))
    rng = random.SystemRandom()
    held = rng.sample(fresh_passes, HELD) + rng.sample(fresh_fails, HELD)
    for i, label in enumerate(labels):
        if label.get("set") == "held" or (i in fresh and i not in held):
            label["set"] = "tune"
        elif i in held:
            label["set"] = "held"


def grader_block(copy, case_name, grader):
    """The lines of the grader's entry in the copy's case file, indented as one item of a graders list,
    and the path the label case writes the text to. Refuses a grader it cannot find or that is not llm."""
    for root, dirs, files in os.walk(os.path.join(copy, "evals")):
        dirs[:] = sorted(d for d in dirs if d not in ("results", "labels"))
        if "case.yaml" not in files:
            continue
        lines = open(os.path.join(root, "case.yaml"), encoding="utf-8").read().splitlines()
        names = [m.group(1) for m in (re.match(r"^name:\s*['\"]?([^'\"\s#]+)", l) for l in lines) if m]
        if names[:1] != [case_name]:
            continue
        start = next((i for i, l in enumerate(lines) if re.match(r"^graders:\s*$", l)), None)
        if start is None:
            break
        items, current, base = [], None, None
        for line in lines[start + 1:]:
            if line.strip() and not line[0].isspace():
                break
            m = re.match(r"^(\s*)-\s", line)
            if m and (base is None or len(m.group(1)) == base):
                base = len(m.group(1))
                current = [line]
                items.append(current)
            elif current is not None:
                current.append(line)
        for item in items:
            text = "\n".join(item)
            if not re.search(r"(?m)^\s*-?\s*name:\s*['\"]?%s['\"]?\s*$" % re.escape(grader), text):
                continue
            if not re.search(r"(?m)^\s*-?\s*type:\s*['\"]?llm['\"]?\s*$", text):
                fail("grader %s of case %s is not an llm grader" % (grader, case_name))
            while item and not item[-1].strip():
                item.pop()
            block = ["  " + l[base:] if l.strip() else "" for l in item]
            m = re.search(r"focus:\s*\{([^}]*)\}", text) or re.search(r"(?ms)^\s*focus:\s*$((?:\n\s+\w+:.*$)+)", text)
            found = re.search(r"path:\s*['\"]?([^,'\"}\s]+)", m.group(1)) if m else None
            if m and not found:
                fail("grader %s has a focus without a path, so label-cases cannot tell where it reads" % grader)
            path = found.group(1) if found else None
            if path is None:
                path = REPLY_TEXT
                block.insert(1, "    focus: {source: file, path: %s}" % REPLY_TEXT)
            if path.startswith("/") or ".." in path.split("/") or "'" in path:
                fail("grader %s reads %s, which is not a plain path in the workspace" % (grader, path))
            return block, path
        break
    fail("no llm grader %s in a case named %s under %s/evals" % (grader, case_name, copy))


def write_label_case(folder, name, label, block, path, case_name):
    os.makedirs(folder)
    text = os.path.join(folder, "text")
    with open(text, "w", encoding="utf-8") as f:
        f.write(label["text"])
    fixture = os.path.join(folder, "fixture.sh")
    with open(fixture, "w", encoding="utf-8") as f:
        f.write("#!/bin/sh\n# Puts the labeled text where the grader reads it.\n"
                "mkdir -p \"$(dirname '%s')\"\ncp '%s' '%s'\n" % (path, text, path))
    os.chmod(fixture, 0o755)
    with open(os.path.join(folder, "case.yaml"), "w", encoding="utf-8") as f:
        f.write("# One labeled output of case %s, graded by its grader; written by skill_tune.py label-cases.\n"
                "schema_version: \"1.1\"\nname: %s\nplugins: [\"../..\"]\nexecution:\n  prompt: |\n"
                "    Reply with the word done and nothing else.\n  max_turns: 1\n  timeout_seconds: 120\n"
                "context:\n  scaffold_script: fixture.sh\ngraders:\n%s\n" % (case_name, name, "\n".join(block)))


def cmd_label_cases(args):
    copy = os.path.abspath(args.copy)
    if not os.path.isdir(os.path.join(copy, "evals")):
        fail("%s has no evals/ folder" % copy)
    data = read_labels(args.labels)
    passes, fails = label_count(data)
    if passes < NEEDED or fails < NEEDED:
        fail("%s holds %d passes and %d fails; label-cases needs %d of each" % (args.labels, passes, fails, NEEDED))
    block, path = grader_block(copy, data["case"], data["grader"])
    changed = split_labels(data)
    labels = data["labels"]
    if args.set == "held" and checked(data, [l["id"] for l in labels if l.get("set") == "held"]):
        redraw_held(data)
        changed = True
    if changed:
        write_labels(args.labels, data)
    out = os.path.join(copy, LABEL_EVALS)
    if os.path.exists(out):
        make_removable(out)
        shutil.rmtree(out)
    private_dir(out)
    chosen = [i for i, l in enumerate(labels) if l.get("set") == args.set]
    for i in chosen:
        name = "%s-%02d" % (args.set, i + 1)
        write_label_case(os.path.join(out, name), name, labels[i], block, path, data["case"])
    print("wrote %d cases for the %s part in %s" % (len(chosen), args.set, out))
    if args.set == "tune":
        for label in labels:
            if label.get("set") == "example":
                print("== example %s (%s)" % (label["id"], label["verdict"]))
                print(label["text"].rstrip("\n"))
    print("next: run %s --label <label> --eval-dir %s --ablation none --runs 1" % (copy, LABEL_EVALS))


def share(agreed, total):
    return "%d/%d (%s)" % (agreed, total, "%.2f" % (agreed / total) if total else "-")


def cmd_agree(args):
    data = read_labels(args.labels)
    labels, grader = data["labels"], data["grader"]
    parts = {}
    for name, case in load_cases([args.result]).items():
        m = LABEL_CASE.match(name)
        if not m:
            continue
        i = int(m.group(2)) - 1
        if not 0 <= i < len(labels):
            fail("case %s names no label in %s" % (name, args.labels))
        verdicts = [g.get("passed") for r in case.get("arms", {}).get("with", [])
                    for g in r.get("graders", []) if g.get("name") == grader]
        parts.setdefault(m.group(1), []).append((labels[i], verdicts[0] if verdicts else None))
    if not parts:
        fail("no label cases in %s" % args.result, 1)
    trusted = True
    for part in ("tune", "held"):
        rows = parts.get(part)
        if not rows:
            continue
        human_passes = [g for l, g in rows if l["verdict"] == "pass" and g is not None]
        human_fails = [g for l, g in rows if l["verdict"] == "fail" and g is not None]
        unmeasured = sum(1 for _, g in rows if g is None)
        agreed_passes = sum(1 for g in human_passes if g is True)
        agreed_fails = sum(1 for g in human_fails if g is False)
        print("%s: human passes the grader passed: %s" % (part, share(agreed_passes, len(human_passes))))
        print("%s: human fails the grader failed: %s" % (part, share(agreed_fails, len(human_fails))))
        if unmeasured:
            print("not measured: %d" % unmeasured)
        if part != "held":
            continue
        ok = (not unmeasured and len(human_passes) >= HELD and len(human_fails) >= HELD
              and agreed_passes >= BAR and agreed_fails >= BAR)
        data["checks"].append({"ids": sorted(l["id"] for l, _ in rows), "passes": [agreed_passes, len(human_passes)],
                               "fails": [agreed_fails, len(human_fails)], "unmeasured": unmeasured,
                               "trusted": ok, "date": time.strftime("%Y-%m-%d")})
        write_labels(args.labels, data)
        if ok:
            print("trusted: %s counts in the score" % grader)
        else:
            trusted = False
            print("not trusted: pass --indicator %s to summary and compare so it leaves the score, "
                  "and report it as not trusted" % grader)
    if not trusted:
        sys.exit(1)


def main():
    ap = argparse.ArgumentParser(prog="skill_tune.py", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="command", required=True)

    p = sub.add_parser("size", help="body words and description characters of a SKILL.md")
    p.add_argument("skill")
    p.set_defaults(func=cmd_size)

    p = sub.add_parser("list", help="every skill under a folder, longest body first")
    p.add_argument("folder")
    p.set_defaults(func=cmd_list)

    p = sub.add_parser("copy", help="copy a plugin into the data folder")
    p.add_argument("plugin")
    p.add_argument("--label", required=True)
    p.add_argument("--replace", action="store_true", help="replace a copy with the same label")
    p.set_defaults(func=cmd_copy)

    p = sub.add_parser("run", help="run claude plugin eval on a copy")
    p.add_argument("copy")
    p.add_argument("--label", required=True)
    p.add_argument("--max-cost-usd", help="stop starting runs once this many US dollars are spent (no limit when left out)")
    p.add_argument("--case", action="append", help="only the cases whose name matches this glob (one glob)")
    p.add_argument("--runs", type=int, help="runs per case (claude plugin eval's default is 3)")
    p.add_argument("--ablation", choices=["none", "with-without"], help="none runs only with the plugin")
    p.add_argument("-j", "--jobs", type=int, default=3, help="runs at once (default 3)")
    p.add_argument("--eval-dir", help="the folder in the copy that holds the cases, such as label-evals (default evals)")
    p.set_defaults(func=cmd_run)

    p = sub.add_parser("summary", help="scores, grader counts, averages, and cost of results")
    p.add_argument("results", nargs="+")
    p.add_argument("--indicator", action="append", default=[], help="a grader that only shows the skill ran")
    p.add_argument("--fired", default="skill-fired", help="the grader that shows the skill started")
    p.set_defaults(func=cmd_summary)

    p = sub.add_parser("compare", help="each case's score before and after")
    p.add_argument("--before", nargs="+", required=True)
    p.add_argument("--after", nargs="+", required=True)
    p.add_argument("--indicator", action="append", default=[])
    p.add_argument("--fired", default="skill-fired")
    p.set_defaults(func=cmd_compare)

    p = sub.add_parser("estimate", help="the cost of the measuring runs, from one run per case")
    p.add_argument("preflight")
    p.add_argument("--runs", type=int, default=3)
    p.set_defaults(func=cmd_estimate)

    p = sub.add_parser("trace", help="the tool calls and results of each run of a case")
    p.add_argument("result")
    p.add_argument("--case", required=True)
    p.add_argument("--arm", choices=["with", "without"], default="with")
    p.set_defaults(func=cmd_trace)

    p = sub.add_parser("clean", help="remove copies, their results, and the eval folders they kept; a copy that run is evaluating is kept")
    p.add_argument("name", nargs="?")
    p.add_argument("--all", action="store_true")
    p.set_defaults(func=cmd_clean)

    p = sub.add_parser("label", help="print the text an llm grader read, or record a person's verdict on it")
    p.add_argument("result")
    p.add_argument("--case", required=True)
    p.add_argument("--grader", required=True)
    p.add_argument("--arm", choices=["with", "without"], default="with")
    p.add_argument("--run", type=int, required=True, help="the run's number in its arm, from 1")
    p.add_argument("--verdict", choices=["pass", "fail"], help="the person's verdict; without it, the text is printed")
    p.add_argument("--into", help="the plugin folder whose evals/labels/ keeps the label")
    p.set_defaults(func=cmd_label)

    p = sub.add_parser("label-cases", help="write one small case per label of a part into the copy")
    p.add_argument("copy")
    p.add_argument("--labels", required=True, help="the label file in the plugin's evals/labels/")
    p.add_argument("--set", choices=["tune", "held"], required=True, help="tune while tuning, held for the one final check")
    p.set_defaults(func=cmd_label_cases)

    p = sub.add_parser("agree", help="how often the grader agreed with the person on the label cases")
    p.add_argument("result")
    p.add_argument("--labels", required=True)
    p.set_defaults(func=cmd_agree)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
