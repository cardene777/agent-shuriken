#!/usr/bin/env python3
"""Keep the record of one correction and refuse to close it until the fix was checked and reviewed.

The agent runs these commands while it works through a correction the user gave:

  where     show the repository and the folder that holds its records
  open      record a correction as open, with the criteria a review must judge
  classify  set how far the correction applies
  case      add or remove texts that a file must or must not contain
  rule      note a rule file that was written for the correction
  check     run the case checks and an optional command, and record the result
  status    list the open corrections, or print the brief for the evaluator of one
  review    save an evaluator's verdicts for one round
  extend    allow more rounds after the user asks to keep going
  close     check that the loop is complete, then move the record to the log
  drop      close a correction the user withdrew
  history   list closed corrections

Records live in ~/.local/share/feedback-loop/repos/<repo>-<hash>/ (FEEDBACK_LOOP_HOME replaces
~/.local/share/feedback-loop), or in a folder inside the repository chosen with `where --use`.

Exit codes: 0 done, 1 the step did not pass, 2 bad input, 3 the round limit was reached.
"""
import argparse
import datetime
import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
import tempfile
import time

FORMAT_VERSION = 1
SCOPES = ("artifact", "repository", "skill", "global", "one-off")
MODES = ("deterministic", "independent-review", "hybrid")
KINDS = ("independent_llm", "deterministic", "human")
BASE_RUBRIC = (
    ("user-feedback", "The correction the user gave is resolved"),
    ("regression", "The rules and case checks that applied before still hold"),
)
FEEDBACK_ID = re.compile(r"^fb-[0-9]{8}-[0-9]{3,}$")
CRITERION_ID = re.compile(r"^[a-z0-9][a-z0-9-]{0,39}$")
SKILL_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9:._-]{0,79}$")
# A verdict line: "- <criterion id>: PASS - <reason>". The bullet, backticks, and bold are optional.
VERDICT_LINE = re.compile(
    r"^\s*(?:[-*+]\s+)?`?([A-Za-z0-9][A-Za-z0-9-]*)`?\s*:\s*\**\s*(PASS|FAIL)\b\**\s*[-:–—]*\s*(.*)$", re.I)
MISSING = "missing"
MAX_ROUNDS = 10
RULES_HEADER = "# Rules\n\nRules learned from corrections in this repository. Each one says what to do and why.\n"


# ------------------------------------------------------------------ small helpers

def stop(message, code=2):
    print(message, file=sys.stderr)
    sys.exit(code)


def now():
    # Tests fix the clock so that ids and dates are stable.
    value = os.environ.get("FEEDBACK_LOOP_NOW", "")
    return int(value) if value.isdigit() else int(time.time())


def iso(ts):
    return datetime.datetime.fromtimestamp(ts, datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()


def home():
    return os.path.realpath(os.path.expanduser("~"))


def shorten(path):
    """Write a path under the home folder as ~/..., so records never hold the user's home path."""
    path = os.path.realpath(path)
    h = home()
    if path == h:
        return "~"
    if path.startswith(h + os.sep):
        return "~/" + os.path.relpath(path, h).replace(os.sep, "/")
    return path


def expand(path):
    return os.path.expanduser(path) if path.startswith("~") else path


def state_home():
    return os.environ.get("FEEDBACK_LOOP_HOME") or os.path.join(os.path.expanduser("~"), ".local", "share", "feedback-loop")


def make_dir(path, private):
    if private:
        os.makedirs(path, mode=0o700, exist_ok=True)
        os.chmod(path, 0o700)
    else:
        os.makedirs(path, exist_ok=True)


def file_mode(private):
    if private:
        return 0o600
    mask = os.umask(0)
    os.umask(mask)
    return 0o666 & ~mask


def write_text(path, text, private):
    """Write a file in one step, so a reader never sees half of it."""
    folder = os.path.dirname(path)
    make_dir(folder, private)
    fd, tmp = tempfile.mkstemp(dir=folder, prefix=".tmp-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text)
        os.chmod(tmp, file_mode(private))
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def write_json(path, data, private):
    write_text(path, json.dumps(data, ensure_ascii=False, indent=2) + "\n", private)


def append_line(path, line, private):
    make_dir(os.path.dirname(path), private)
    fd = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_CREAT, file_mode(private))
    with os.fdopen(fd, "a", encoding="utf-8") as handle:
        handle.write(line + "\n")
    if private:
        os.chmod(path, 0o600)


def git(start, *args):
    try:
        r = subprocess.run(["git", "-C", start] + list(args), capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return r.stdout.strip() if r.returncode == 0 else None


# ------------------------------------------------------------------ where the records live

class Place:
    """The repository root (the worktree that holds the files) and the folder of its records."""

    def __init__(self, given):
        path = os.path.abspath(os.path.expanduser(given or "."))
        if not os.path.exists(path):
            stop(f"{given} does not exist.")
        start = path if os.path.isdir(path) else os.path.dirname(path)
        top = git(start, "rev-parse", "--show-toplevel")
        if not top:
            stop(f"{given} is not inside a git repository. Fix the output and report it as a one-time "
                 "correction; nothing is recorded outside a repository.")
        self.root = os.path.realpath(top)
        common = git(start, "rev-parse", "--git-common-dir") or ".git"
        common = os.path.realpath(os.path.join(start, common))
        # Linked worktrees share the records of their main clone.
        self.main = os.path.dirname(common) if os.path.basename(common) == ".git" else common
        name = re.sub(r"[^A-Za-z0-9._-]+", "-", os.path.basename(self.main)).strip("-") or "repo"
        self.private_store = os.path.join(state_home(), "repos", f"{name}-{sha256_bytes(self.main.encode())[:12]}")
        self.choice_file = os.path.join(self.private_store, "store")
        chosen = None
        if os.path.isfile(self.choice_file):
            with open(self.choice_file, encoding="utf-8") as handle:
                chosen = handle.read().strip() or None
        if chosen:
            self.store = os.path.join(self.root, chosen)
            self.private = False
        else:
            self.store = self.private_store
            self.private = True

    def ensure_store(self):
        make_dir(state_home(), True)
        make_dir(os.path.join(state_home(), "repos"), True)
        make_dir(self.store, self.private)
        rules = self.rules_path()
        if not os.path.exists(rules):
            write_text(rules, RULES_HEADER, self.private)

    def pending_path(self, fid):
        return os.path.join(self.store, "pending", fid + ".json")

    def events_path(self):
        return os.path.join(self.store, "events.jsonl")

    def rules_path(self):
        return os.path.join(self.store, "rules.md")


def inside(root, path):
    return path == root or path.startswith(root + os.sep)


def repo_relative(root, given, what):
    """Return a file path inside the repository as a relative POSIX path, or stop."""
    if not given:
        stop(f"The {what} path is empty.")
    # realpath follows symbolic links, so a link inside the repository that leads outside is refused too.
    real = os.path.realpath(given if os.path.isabs(given) else os.path.join(root, given))
    if not inside(root, real) or real == root:
        stop(f"{given} is outside the repository {shorten(root)}.")
    rel = os.path.relpath(real, root).replace(os.sep, "/")
    if rel == ".git" or rel.startswith(".git/"):
        stop(f"{given} is inside .git; name a file of the project.")
    if what == "file" and os.path.isdir(real):
        stop(f"{given} is a folder; name the files that were corrected.")
    return rel


def load_jsonl(path):
    rows = []
    if not os.path.isfile(path):
        return rows
    with open(path, encoding="utf-8") as handle:
        for number, line in enumerate(handle, 1):
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                stop(f"{shorten(path)} line {number} is not valid JSON. Fix or remove that line.")
    return rows


def open_records(place):
    folder = os.path.join(place.store, "pending")
    found = []
    if os.path.isdir(folder):
        for name in sorted(os.listdir(folder)):
            if name.endswith(".json") and FEEDBACK_ID.match(name[:-5]):
                found.append(read_record(place, name[:-5]))
    return found


def read_record(place, fid):
    if not FEEDBACK_ID.match(fid or ""):
        stop(f"{fid} is not a correction id; ids look like fb-20330101-001.")
    path = place.pending_path(fid)
    if not os.path.isfile(path):
        stop(f"No open correction {fid} in {shorten(place.store)}. Run status to list the open ones.")
    try:
        with open(path, encoding="utf-8") as handle:
            record = json.load(handle)
    except (OSError, json.JSONDecodeError):
        stop(f"{shorten(path)} is not valid JSON.")
    if not isinstance(record, dict) or record.get("version") != FORMAT_VERSION:
        version = record.get("version") if isinstance(record, dict) else None
        stop(f"{shorten(path)} has format version {version!r}; this script reads version {FORMAT_VERSION}.")
    return record


def save_record(place, record):
    write_json(place.pending_path(record["id"]), record, place.private)


def record_root(record):
    return os.path.realpath(expand(record["target_repository"]))


def artifact_state(root, rel):
    path = os.path.join(root, rel)
    if not os.path.isfile(path):
        return MISSING
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def states(record):
    root = record_root(record)
    return {rel: artifact_state(root, rel) for rel in record["target_artifacts"]}


def next_id(place):
    day = time.strftime("%Y%m%d", time.localtime(now()))
    prefix = f"fb-{day}-"
    used = {str(row.get("id", "")) for row in load_jsonl(place.events_path())}
    folder = os.path.join(place.store, "pending")
    if os.path.isdir(folder):
        used.update(name[:-5] for name in os.listdir(folder) if name.endswith(".json"))
    numbers = [int(x[len(prefix):]) for x in used if x.startswith(prefix) and x[len(prefix):].isdigit()]
    return f"{prefix}{(max(numbers) + 1) if numbers else 1:03d}"


# ------------------------------------------------------------------ cases

def case_name(rel):
    slug = re.sub(r"[^A-Za-z0-9._-]+", "-", rel).strip("-") or "file"
    return f"cases/{slug[:80]}-{sha256_bytes(rel.encode())[:8]}.json"


def read_case(place, rel):
    """Return the case file name and its data for one file, an empty case when there is none, or stop when it is malformed."""
    name = case_name(rel)
    path = os.path.join(place.store, name)
    if not os.path.exists(path):
        return name, {"version": FORMAT_VERSION, "target": rel, "entries": []}
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, json.JSONDecodeError):
        stop(f"{shorten(path)} is not valid JSON. Fix or remove it before checking.")
    good = (isinstance(data, dict) and data.get("version") == FORMAT_VERSION and data.get("target") == rel
            and isinstance(data.get("entries"), list))
    if good:
        for entry in data["entries"]:
            good = good and isinstance(entry, dict) and isinstance(entry.get("id"), str) and all(
                isinstance(entry.get(k), list) and all(isinstance(t, str) and t for t in entry[k])
                for k in ("forbid", "require", "questions"))
    if not good:
        stop(f"{shorten(path)} is not a case file of version {FORMAT_VERSION} for {rel}. Fix or remove it before checking.")
    return name, data


def case_checks(place, record):
    """Return (number of conditions, failures, questions) for the record's files."""
    root = record_root(record)
    count, failures, questions = 0, [], []
    for rel in record["target_artifacts"]:
        _, case = read_case(place, rel)
        path = os.path.join(root, rel)
        text = None
        if os.path.isfile(path):
            with open(path, "rb") as handle:
                text = handle.read().decode("utf-8", errors="replace")
        for entry in case["entries"]:
            for value in entry["forbid"]:
                count += 1
                if text is not None and value in text:
                    failures.append(f"{rel} must not contain {json.dumps(value, ensure_ascii=False)} (from {entry['id']})")
            for value in entry["require"]:
                count += 1
                if text is None or value not in text:
                    failures.append(f"{rel} must contain {json.dumps(value, ensure_ascii=False)} (from {entry['id']})")
            questions.extend(f"{rel}: {q}" for q in entry["questions"])
    return count, failures, questions


# ------------------------------------------------------------------ checks and reviews

def latest_results(record, current):
    """The latest exit code of each command that ran on the files as they are now."""
    latest = {}
    for run in record["verification"]["runs"]:
        if run["artifacts"] == current:
            for result in run["commands"]:
                latest[result["command"]] = result["exit_code"]
    return latest


def checks_problem(record, current):
    latest = latest_results(record, current)
    if not latest:
        return "No check ran on the files as they are now. Run check after the last change."
    failed = [c for c, code in latest.items() if code != 0]
    if failed:
        return "These checks failed on the files as they are now: " + "; ".join(failed) + ". Fix the files and run check again."
    return None


def parse_review(text, rubric_ids):
    """Return ({id: (verdict, reason)}, problems) for the criteria of the record."""
    found, problems = {}, []
    wanted = set(rubric_ids)
    for line in text.splitlines():
        m = VERDICT_LINE.match(line)
        if not m:
            continue
        cid = m.group(1).lower()
        if cid not in wanted:
            continue
        if cid in found:
            problems.append(f"{cid} has more than one verdict line")
            continue
        found[cid] = (m.group(2).upper(), m.group(3).strip())
    missing = [cid for cid in rubric_ids if cid not in found]
    if missing:
        problems.append("no verdict line for " + ", ".join(missing))
    return found, problems


def mode_problem(record, kind):
    if record["loop"]["mode"] != "deterministic" and kind == "deterministic":
        return (f"{record['id']} is in {record['loop']['mode']} mode, so its review needs an evaluator that reads the work: "
                "use --kind independent_llm or --kind human.")
    return None


def next_step(record):
    current = states(record)
    rounds = record["loop"]["iterations"]
    limit = record["loop"]["max_iterations"]
    if rounds and rounds[-1]["evaluation"]["verdict"] == "pass" and rounds[-1]["artifacts"] == current:
        return "close" if record.get("scope") else "classify, then close"
    if rounds and rounds[-1]["evaluation"]["verdict"] == "fail" and len(rounds) >= limit:
        return "ask the user (round limit)"
    if checks_problem(record, current):
        return "fix, then check"
    return f"review round {len(rounds) + 1}"


# ------------------------------------------------------------------ commands

def cmd_where(args):
    place = Place(args.repo)
    if args.use:
        folder = repo_relative(place.root, args.use, "records folder")
        if os.path.isfile(os.path.join(place.root, folder)):
            stop(f"{args.use} is a file; name a folder for the records.")
        make_dir(state_home(), True)
        make_dir(os.path.join(state_home(), "repos"), True)
        make_dir(place.private_store, True)
        write_text(place.choice_file, folder + "\n", True)
        place = Place(args.repo)
        place.ensure_store()
    elif args.private:
        if os.path.exists(place.choice_file):
            os.unlink(place.choice_file)
        place = Place(args.repo)
    kind = "private, readable only by you" if place.private else "inside the repository"
    count = len(open_records(place)) if os.path.isdir(place.store) else 0
    print(f"repository  {place.root}")
    print(f"records     {place.store}  ({kind})")
    print(f"rules       {place.rules_path()}")
    print(f"open        {count}")
    return 0


def cmd_open(args):
    place = Place(args.repo)
    text = sys.stdin.read().strip()
    if not text:
        stop("Pass the user's correction, word for word, on standard input.")
    digest = sha256_bytes(text.encode("utf-8"))
    if not args.subject.strip():
        stop("--subject is empty; say which output or behavior the user corrected.")
    artifacts = []
    for given in args.artifact:
        rel = repo_relative(place.root, given, "file")
        if rel not in artifacts:
            artifacts.append(rel)
    if not artifacts:
        stop("Name at least one corrected file with --artifact.")
    rubric = [{"id": cid, "criterion": criterion} for cid, criterion in BASE_RUBRIC]
    for item in args.criterion:
        cid, sep, criterion = item.partition("=")
        cid = cid.strip()
        if not sep or not criterion.strip() or not CRITERION_ID.match(cid):
            stop(f"--criterion {item!r} must be <id>=<text>, with an id of lowercase letters, digits, and '-'.")
        if any(r["id"] == cid for r in rubric):
            stop(f"The criterion id {cid} is used twice.")
        rubric.append({"id": cid, "criterion": criterion.strip()})
    origin = (args.origin_skill or "none").strip()
    if origin != "none" and not SKILL_NAME.match(origin):
        stop(f"--origin-skill {origin!r} is not a skill name.")
    if not 1 <= args.max_iterations <= MAX_ROUNDS:
        stop(f"--max-iterations must be between 1 and {MAX_ROUNDS}.")

    place.ensure_store()
    for record in open_records(place):
        if record["source_sha256"] == digest:
            print(f"Already open as {record['id']}: {record['feedback_subject']}")
            return 0
    events = load_jsonl(place.events_path())
    fid = next_id(place)
    record = {
        "version": FORMAT_VERSION,
        "id": fid,
        "status": "open",
        "source_sha256": digest,
        "target_repository": shorten(place.root),
        "origin_skill": origin,
        "target_artifacts": artifacts,
        "feedback_subject": args.subject.strip(),
        "expected": (args.expected or "").strip(),
        "scope": None,
        "rule_files": [],
        "case_files": [],
        "opened_at": iso(now()),
        "opened_artifacts": {rel: artifact_state(place.root, rel) for rel in artifacts},
        "verification": {"runs": []},
        "loop": {
            "mode": args.mode,
            "max_iterations": args.max_iterations,
            "rubric": rubric,
            "iterations": [],
            "final_verdict": None,
        },
    }
    save_record(place, record)
    print(f"Opened {fid}: {record['feedback_subject']}")
    print(f"records  {shorten(place.store)}")
    for event in events:
        if event.get("source_sha256") == digest:
            print(f"The same correction was closed before as {event.get('id')} ({event.get('status')}): "
                  f"{event.get('feedback_subject')}")
    earlier = [e for e in events
               if set(e.get("target_artifacts") or []) & set(artifacts) and e.get("source_sha256") != digest]
    for event in earlier[-5:]:
        print(f"Earlier correction to these files: {event.get('id')} {event.get('feedback_subject')} "
              f"(scope {event.get('scope')}, kept in {', '.join((event.get('rule_files') or []) + (event.get('case_files') or [])) or 'nothing'})")
    return 0


def cmd_classify(args):
    place = Place(args.repo)
    record = read_record(place, args.id)
    record["scope"] = args.scope
    save_record(place, record)
    print(f"{record['id']} applies to: {args.scope}")
    return 0


def pick_artifact(record, given):
    if given:
        rel = repo_relative(record_root(record), given, "file")
        if rel not in record["target_artifacts"]:
            stop(f"{rel} is not one of the files of {record['id']}: {', '.join(record['target_artifacts'])}")
        return rel
    if len(record["target_artifacts"]) == 1:
        return record["target_artifacts"][0]
    stop(f"{record['id']} has several files; name one with --artifact.")


def cmd_case(args):
    place = Place(args.repo)
    record = read_record(place, args.id)
    rel = pick_artifact(record, args.artifact)
    name, case = read_case(place, rel)
    if args.remove:
        if not FEEDBACK_ID.match(args.remove):
            stop(f"{args.remove} is not a correction id.")
        before = len(case["entries"])
        case["entries"] = [e for e in case["entries"] if e["id"] != args.remove]
        if len(case["entries"]) == before:
            stop(f"{name} has no entry from {args.remove}.", 1)
        record.setdefault("case_removals", []).append({"case_file": name, "entry": args.remove})
        print(f"Removed the entry from {args.remove} in {name}")
    else:
        values = {"forbid": args.forbid, "require": args.require, "questions": args.question}
        if not any(values.values()):
            stop("Give at least one --forbid, --require, or --question.")
        if any(not item.strip() for items in values.values() for item in items):
            stop("An empty --forbid, --require, or --question was given.")
        entry = next((e for e in case["entries"] if e["id"] == record["id"]), None)
        if entry is None:
            entry = {"id": record["id"], "forbid": [], "require": [], "questions": []}
            case["entries"].append(entry)
        for key, items in values.items():
            for item in items:
                if item not in entry[key]:
                    entry[key].append(item)
        print(f"Added to {name} from {record['id']}: forbid {len(entry['forbid'])}, require {len(entry['require'])}, "
              f"questions {len(entry['questions'])}")
    write_json(os.path.join(place.store, name), case, place.private)
    if name not in record["case_files"]:
        record["case_files"].append(name)
    save_record(place, record)
    return 0


def cmd_rule(args):
    place = Place(args.repo)
    record = read_record(place, args.id)
    root = record_root(record)
    for given in args.path:
        given_path = os.path.expanduser(given)
        path = os.path.realpath(given_path if os.path.isabs(given_path) else os.path.join(root, given_path))
        if not os.path.isfile(path):
            stop(f"{given} is not a file; write the rule first, then note it.")
        shown = os.path.relpath(path, root).replace(os.sep, "/") if inside(root, path) else shorten(path)
        if shown not in record["rule_files"]:
            record["rule_files"].append(shown)
        print(f"{record['id']} keeps its rule in {shown}")
    save_record(place, record)
    return 0


def cmd_check(args):
    place = Place(args.repo)
    record = read_record(place, args.id)
    command = list(args.command or [])
    count, failures, _ = case_checks(place, record)
    results = []
    if count:
        for failure in failures:
            print(f"FAIL  {failure}")
        print(f"case checks: {count - len(failures)} of {count} conditions hold")
        results.append({"command": "case checks", "exit_code": 0 if not failures else 1})
    if command:
        shown = shlex.join(command)
        print(f"$ {shown}", flush=True)
        try:
            code = subprocess.run(command, cwd=record_root(record), timeout=args.timeout).returncode
        except FileNotFoundError:
            print(f"{command[0]}: command not found", file=sys.stderr)
            code = 127
        except subprocess.TimeoutExpired:
            print(f"Stopped after {args.timeout} seconds.", file=sys.stderr)
            code = 124
        print(f"exit {code}")
        results.append({"command": shown, "exit_code": code})
    if not results:
        stop("Nothing to check: pass a command after --, or add a case with case.")
    record["verification"]["runs"].append({"at": iso(now()), "artifacts": states(record), "commands": results})
    save_record(place, record)
    return 0 if all(r["exit_code"] == 0 for r in results) else 1


def cmd_status(args):
    place = Place(args.repo)
    if not args.id:
        records = open_records(place) if os.path.isdir(place.store) else []
        if not records:
            print("No open corrections.")
            return 0
        print(f"{'id':<16}  {'scope':<10}  {'rounds':<6}  {'next':<26}  subject")
        for record in records:
            rounds = f"{len(record['loop']['iterations'])}/{record['loop']['max_iterations']}"
            print(f"{record['id']:<16}  {record.get('scope') or '-':<10}  {rounds:<6}  {next_step(record):<26}  "
                  f"{record['feedback_subject']}")
        return 0
    record = read_record(place, args.id)
    current = states(record)
    count, failures, questions = case_checks(place, record)
    loop = record["loop"]
    print(f"{record['id']}  {record['feedback_subject']}")
    print(f"  repository  {record['target_repository']}")
    print(f"  files       {', '.join(record['target_artifacts'])}")
    print(f"  expected    {record.get('expected') or '-'}")
    print(f"  origin      {record['origin_skill']}")
    print(f"  scope       {record.get('scope') or 'not set'}")
    print(f"  mode        {loop['mode']}")
    print(f"  rounds      {len(loop['iterations'])} of {loop['max_iterations']}")
    print(f"  next        {next_step(record)}")
    print()
    print("Criteria")
    for item in loop["rubric"]:
        print(f"  {item['id']}: {item['criterion']}")
    print()
    print(f"Case checks: {count - len(failures)} of {count} conditions hold")
    for failure in failures:
        print(f"  FAIL  {failure}")
    if questions:
        print("Questions for the evaluator")
        for q in questions:
            print(f"  - {q}")
    if os.path.isfile(place.rules_path()):
        # Full paths here, because the evaluator opens these files.
        print(f"Rules that still apply: {place.rules_path()}")
    for rule in record["rule_files"]:
        print(f"Rule written for this correction: {expand(rule)}")
    latest = latest_results(record, current)
    print("Checks on the files as they are now: "
          + ("; ".join(f"{c} (exit {code})" for c, code in latest.items()) or "none"))
    if loop["iterations"]:
        last = loop["iterations"][-1]
        print(f"Last review: round {last['number']} {last['evaluation']['verdict'].upper()} by {last['evaluation']['evaluator']}")
        for finding in last["evaluation"]["findings"]:
            print(f"  {finding['id']}: {finding['reason']}")
    print()
    print("The evaluator reads the files, edits nothing, and answers with one line per criterion:")
    for item in loop["rubric"]:
        print(f"  - {item['id']}: PASS - <why>   or   - {item['id']}: FAIL - <what must change>")
    return 0


def cmd_review(args):
    place = Place(args.repo)
    record = read_record(place, args.id)
    loop = record["loop"]
    number = len(loop["iterations"]) + 1
    if number > loop["max_iterations"] and args.kind != "human":
        stop(f"{record['id']} reached its limit of {loop['max_iterations']} rounds. Keep it open and ask the user: "
             "keep going (extend), accept it as it is (a review with --kind human), or withdraw it (drop).", 3)
    problem = mode_problem(record, args.kind)
    if problem:
        stop(problem)
    if not args.evaluator.strip():
        stop("--evaluator is empty; name the agent, review pass, or person that judged the work.")
    current = states(record)
    problem = checks_problem(record, current)
    if problem:
        stop(problem, 1)
    if args.file:
        try:
            with open(args.file, encoding="utf-8") as handle:
                text = handle.read()
        except OSError:
            stop(f"Cannot read {args.file}.")
    else:
        text = sys.stdin.read()
    if not text.strip():
        stop("The review is empty.")
    rubric_ids = [r["id"] for r in loop["rubric"]]
    verdicts, problems = parse_review(text, rubric_ids)
    if problems:
        stop("The review cannot be read: " + "; ".join(problems)
             + ". Each criterion needs exactly one line such as `- user-feedback: PASS - <why>`.")
    name = f"reviews/{record['id']}-{number}.md"
    path = os.path.join(place.store, name)
    write_text(path, text if text.endswith("\n") else text + "\n", place.private)
    with open(path, "rb") as handle:
        review_hash = sha256_bytes(handle.read())
    findings = [{"id": cid, "reason": verdicts[cid][1]} for cid in rubric_ids if verdicts[cid][0] == "FAIL"]
    verdict = "fail" if findings else "pass"
    loop["iterations"].append({
        "number": number,
        "at": iso(now()),
        "artifacts": current,
        "evaluation": {"evaluator": args.evaluator.strip(), "kind": args.kind, "verdict": verdict, "findings": findings},
        "review_file": name,
        "review_sha256": review_hash,
    })
    save_record(place, record)
    if verdict == "pass":
        print(f"Round {number} of {record['id']} passed. Run close.")
        return 0
    print(f"Round {number} of {record['id']} failed:")
    for finding in findings:
        print(f"  {finding['id']}: {finding['reason']}")
    if number >= loop["max_iterations"]:
        print(f"That was the last of {loop['max_iterations']} rounds. Keep the correction open and give the user "
              "the open points and the choices: keep going, accept it as it is, or withdraw it.")
        return 3
    print("Give these findings to the fixer, fix the files, run check, and review again.")
    return 1


def cmd_extend(args):
    place = Place(args.repo)
    record = read_record(place, args.id)
    if not 1 <= args.rounds <= MAX_ROUNDS:
        stop(f"--rounds must be between 1 and {MAX_ROUNDS}.")
    record["loop"]["max_iterations"] += args.rounds
    save_record(place, record)
    print(f"{record['id']} now allows {record['loop']['max_iterations']} rounds.")
    return 0


def close_problems(place, record):
    problems = []
    loop = record["loop"]
    current = states(record)
    if not record.get("scope"):
        problems.append("The scope is not set. Run classify.")
    ids = [r["id"] for r in loop["rubric"]]
    for cid, _ in BASE_RUBRIC:
        if cid not in ids:
            problems.append(f"The criteria do not include {cid}.")
    rounds = loop["iterations"]
    if not rounds:
        problems.append("No review was recorded. Run review after the checks pass.")
    else:
        last = rounds[-1]
        if last["evaluation"]["verdict"] != "pass":
            problems.append(f"The last review (round {last['number']}) did not pass.")
        changed = [rel for rel in record["target_artifacts"] if last["artifacts"].get(rel) != current[rel]]
        if changed:
            problems.append("These files changed after the last review: " + ", ".join(changed)
                            + ". Check and review them again.")
        review_path = os.path.join(place.store, last["review_file"])
        if not os.path.isfile(review_path):
            problems.append(f"The review file {last['review_file']} is missing.")
        else:
            with open(review_path, "rb") as handle:
                data = handle.read()
            if sha256_bytes(data) != last["review_sha256"]:
                problems.append(f"The review file {last['review_file']} changed after it was recorded.")
            else:
                verdicts, unreadable = parse_review(data.decode("utf-8", errors="replace"), ids)
                if unreadable or any(v[0] != "PASS" for v in verdicts.values()):
                    problems.append(f"The review file {last['review_file']} does not pass every criterion.")
        problem = mode_problem(record, last["evaluation"]["kind"])
        if problem:
            problems.append(problem)
    problem = checks_problem(record, current)
    if problem:
        problems.append(problem)
    scope = record.get("scope")
    has_entry = False
    for rel in record["target_artifacts"]:
        _, case = read_case(place, rel)
        has_entry = has_entry or any(e["id"] == record["id"] for e in case["entries"])
    if scope == "artifact":
        if not has_entry:
            problems.append("The scope is artifact, but no case holds an entry from this correction. Add one with case.")
    elif scope in ("repository", "skill", "global"):
        if not record["rule_files"]:
            problems.append(f"The scope is {scope}, but no rule file was noted. Write the rule and note it with rule.")
        for rule in record["rule_files"]:
            path = expand(rule) if rule.startswith(("~", "/")) else os.path.join(record_root(record), rule)
            if not os.path.isfile(path):
                problems.append(f"The rule file {rule} no longer exists.")
    return problems, current


def finish(place, record, status, extra):
    record = dict(record)
    record["status"] = status
    record["closed_at"] = iso(now())
    record.update(extra)
    append_line(place.events_path(), json.dumps(record, ensure_ascii=False, separators=(",", ":")), place.private)
    os.unlink(place.pending_path(record["id"]))


def cmd_close(args):
    place = Place(args.repo)
    record = read_record(place, args.id)
    problems, current = close_problems(place, record)
    if problems:
        print(f"{record['id']} cannot be closed yet:")
        for problem in problems:
            print(f"  - {problem}")
        return 1
    record["loop"]["final_verdict"] = "pass"
    record["verification"]["commands"] = [{"command": c, "exit_code": code}
                                          for c, code in latest_results(record, current).items()]
    record["verification"]["artifacts"] = [{"path": rel, "sha256": current[rel]} for rel in record["target_artifacts"]]
    finish(place, record, "resolved", {})
    print(f"Closed {record['id']} after {len(record['loop']['iterations'])} round(s): {record['feedback_subject']}")
    print(f"log  {shorten(place.events_path())}")
    return 0


def cmd_drop(args):
    place = Place(args.repo)
    record = read_record(place, args.id)
    if not args.reason.strip():
        stop("--reason is empty; say why the user withdrew the correction.")
    finish(place, record, "dropped", {"drop_reason": args.reason.strip()})
    print(f"Dropped {record['id']}: {args.reason.strip()}")
    return 0


def cmd_history(args):
    place = Place(args.repo)
    events = load_jsonl(place.events_path())
    if args.artifact:
        rel = repo_relative(place.root, args.artifact, "file")
        events = [e for e in events if rel in (e.get("target_artifacts") or [])]
    if not events:
        print("No closed corrections.")
        return 0
    for event in list(reversed(events))[: max(args.limit, 1)]:
        rounds = len((event.get("loop") or {}).get("iterations") or [])
        print(f"{event.get('id')}  {str(event.get('closed_at', ''))[:10]}  {event.get('status')}  "
              f"scope {event.get('scope') or '-'}  rounds {rounds}  {event.get('feedback_subject')}")
        print(f"    files {', '.join(event.get('target_artifacts') or [])}")
        kept = (event.get("rule_files") or []) + (event.get("case_files") or [])
        if kept:
            print(f"    kept in {', '.join(kept)}")
        if event.get("drop_reason"):
            print(f"    dropped because {event['drop_reason']}")
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Record a correction, check the fix, and close it only after a passing review.")
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--repo", default=".",
                        help="A path inside the repository that holds the corrected files (default: the current folder)")
    sub = parser.add_subparsers(dest="command_name", required=True)

    p = sub.add_parser("where", parents=[common], help="Show the repository and the records folder")
    group = p.add_mutually_exclusive_group()
    group.add_argument("--use", metavar="FOLDER", help="Keep the records in this folder inside the repository from now on")
    group.add_argument("--private", action="store_true", help="Keep the records in the private folder again")
    p.set_defaults(func=cmd_where)

    p = sub.add_parser("open", parents=[common], help="Record a correction; the user's words come on standard input")
    p.add_argument("--subject", required=True, help="Which output or behavior the user corrected")
    p.add_argument("--expected", default="", help="What the user expects instead")
    p.add_argument("--artifact", action="append", default=[],
                   help="A corrected file, relative to the repository root; repeatable")
    p.add_argument("--origin-skill", default="none", help="The skill that produced the output, or none")
    p.add_argument("--mode", choices=MODES, default="hybrid")
    p.add_argument("--max-iterations", type=int, default=3)
    p.add_argument("--criterion", action="append", default=[], metavar="ID=TEXT",
                   help="An extra criterion for the review; repeatable")
    p.set_defaults(func=cmd_open)

    p = sub.add_parser("classify", parents=[common], help="Set how far the correction applies")
    p.add_argument("id")
    p.add_argument("scope", choices=SCOPES)
    p.set_defaults(func=cmd_classify)

    p = sub.add_parser("case", parents=[common], help="Add texts a file must or must not contain, or remove an entry")
    p.add_argument("id")
    p.add_argument("--artifact", help="The file the case is for, when the correction has several")
    p.add_argument("--forbid", action="append", default=[], help="A text the file must not contain; repeatable")
    p.add_argument("--require", action="append", default=[], help="A text the file must contain; repeatable")
    p.add_argument("--question", action="append", default=[], help="A question the evaluator answers; repeatable")
    p.add_argument("--remove", metavar="FEEDBACK_ID", help="Remove the entry from this correction instead")
    p.set_defaults(func=cmd_case)

    p = sub.add_parser("rule", parents=[common], help="Note the rule files written for the correction")
    p.add_argument("id")
    p.add_argument("path", nargs="+")
    p.set_defaults(func=cmd_rule)

    p = sub.add_parser("check", parents=[common], help="Run the case checks and the command given after --")
    p.add_argument("id")
    p.add_argument("--timeout", type=int, default=600, help="Seconds before the command is stopped (default 600)")
    p.set_defaults(func=cmd_check, command=[])

    p = sub.add_parser("status", parents=[common], help="List open corrections, or print the brief for one")
    p.add_argument("id", nargs="?")
    p.set_defaults(func=cmd_status)

    p = sub.add_parser("review", parents=[common], help="Save the evaluator's verdicts, from --file or standard input")
    p.add_argument("id")
    p.add_argument("--evaluator", required=True, help="Who judged the work, for example the name of a review agent")
    p.add_argument("--kind", choices=KINDS, required=True)
    p.add_argument("--file", help="A file with the evaluator's answer")
    p.set_defaults(func=cmd_review)

    p = sub.add_parser("extend", parents=[common], help="Allow more rounds after the user asks to keep going")
    p.add_argument("id")
    p.add_argument("--rounds", type=int, default=1)
    p.set_defaults(func=cmd_extend)

    p = sub.add_parser("close", parents=[common], help="Close a correction whose loop is complete")
    p.add_argument("id")
    p.set_defaults(func=cmd_close)

    p = sub.add_parser("drop", parents=[common], help="Close a correction the user withdrew")
    p.add_argument("id")
    p.add_argument("--reason", required=True)
    p.set_defaults(func=cmd_drop)

    p = sub.add_parser("history", parents=[common], help="List closed corrections, newest first")
    p.add_argument("--artifact", help="Only corrections to this file")
    p.add_argument("--limit", type=int, default=20)
    p.set_defaults(func=cmd_history)

    argv = list(sys.argv[1:] if argv is None else argv)
    # Everything after the first -- belongs to the command that check runs, in every Python version.
    command = []
    if argv[:1] == ["check"] and "--" in argv:
        cut = argv.index("--")
        argv, command = argv[:cut], argv[cut + 1:]
    args = parser.parse_args(argv)
    if args.command_name == "check":
        args.command = command
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
