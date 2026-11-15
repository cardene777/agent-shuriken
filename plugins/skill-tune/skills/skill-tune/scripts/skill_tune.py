#!/usr/bin/env python3
"""Measure a plugin's skill with `claude plugin eval` and compare it before and after a change.

Commands
  size <SKILL.md>                       Body words and description characters
  list <folder>                         Every skill under the folder, longest body first, with its eval cases
  copy <plugin> --label L [--replace]   Copy the plugin into the data folder, without eval results and caches
  run <copy> --label L [--max-cost-usd U] [--case GLOB] [--runs N] [--ablation MODE] [-j N]
                                        Run `claude plugin eval` on a copy; the result is results/<L>.json
  summary <result.json>... [--indicator NAME]... [--fired NAME]
                                        Scores per case and arm, grader counts, averages, and cost
  compare --before <json>... --after <json>... [--indicator NAME]...
                                        Each case's score before and after; exit 1 when one is lower
  estimate <preflight.json> [--runs N]  The cost of the baseline and the after runs, from one run per case
  trace <result.json> --case NAME [--arm with|without]
                                        The tool calls and results of each run of a case
  clean <run name> | --all              Remove copies, their results, and the eval folders they kept, except a copy run is evaluating

When several result files are given, each case comes from the last file that holds it.
A run's score is the share of its scored graders that passed, leaving out with-only graders and
the graders named with --indicator; a case's score is the mean over its runs.

The data folder is $SKILL_TUNE_HOME, by default ~/.local/share/skill-tune, readable only by the user.
Exit codes: 0 done; 1 a case scored lower, or nothing to show; 2 bad input; 3 `claude` is missing;
3 also when compare finds a case measured on one side only. `run` passes on the exit code of
`claude plugin eval` (2 when a --max-cost-usd limit stopped it).
"""
import argparse
import glob
import json
import os
import re
import shutil
import subprocess
import sys

LABEL = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
KEPT = re.compile(r"^e-[A-Za-z0-9]{6,}$")
# The file run writes next to a copy while claude plugin eval runs on it, holding run's process id.
RUNNING = "running"


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
    print(dest)


def cmd_run(args):
    copy = os.path.abspath(args.copy)
    if not os.path.isdir(os.path.join(copy, "evals")):
        fail("%s has no evals/ folder" % copy)
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

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
