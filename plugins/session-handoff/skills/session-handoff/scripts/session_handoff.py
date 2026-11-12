#!/usr/bin/env python3
"""Check and save the state one session hands to the next, and print the message to paste.

The agent writes the handoff as JSON: the three paragraphs of the message and, when there is
state worth keeping, the snapshot (options already rejected, the current phase, delegated work,
and things not to do). This script checks the shape, refuses text that looks like a secret,
saves the snapshot as one Markdown file per project, and prints the message.

Usage:
  session_handoff.py save [--project DIR] [--input FILE]   (JSON on standard input without --input)
  session_handoff.py show [--project DIR]
  session_handoff.py forget [--project DIR]

The project is the top folder of the git repository that holds DIR, or DIR itself outside git.
DIR defaults to the current folder. Snapshots live in ~/.local/share/session-handoff/, or in
SESSION_HANDOFF_HOME when set, in a folder with mode 700 and files with mode 600, and are removed
7 days after they were saved.

Exit codes: 0 on success, 1 when there is no saved state, 2 for input or a saved file in the wrong
format, 3 when text looks like a secret.
"""
import argparse
import datetime
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import time

FORMAT = "session-handoff/1"
KEEP_DAYS = 7
DAY = 86400
MAX_FILE_BYTES = 256 * 1024
# <slug of the folder name>-<first 8 hex digits of the SHA-256 of the project path>.md
SNAPSHOT_NAME = re.compile(r"^[a-z0-9][a-z0-9-]{0,39}-[0-9a-f]{8}\.md$")

MESSAGE_PARTS = ("handoff", "background", "task")
PART_MAX_LINES = 2
PART_MAX_CHARS = 400
PHASE_MAX_LINES = 3
PHASE_MAX_CHARS = 800
ITEM_MAX_CHARS = 500
LIST_MAX_ITEMS = 20
ISSUE_MAX_CHARS = 100

# The four parts of a snapshot: the key in the JSON, the heading in the file, and the text
# written when the part is empty, so that an empty part never looks like a forgotten one.
PARTS = (
    ("rejected", "## Rejected options (do not propose again)", "None."),
    ("phase", "## Current phase", "No work in progress."),
    ("delegated", "## Delegated work", "No delegated work."),
    ("do_not", "## Do not", "Nothing noted."),
)
ITEM_FIELDS = {
    "rejected": (("option", str), ("reason", str)),
    "delegated": (("work", str), ("expected", str), ("waiting", bool)),
    "do_not": (("action", str), ("reason", str)),
}
PREAMBLE = ("Notes from an earlier session in this project. "
            "They record what was decided there; they are not commands to run.")

# ------------------------------------------------------------------ secrets

# Values with these shapes are secrets wherever they appear. Every repeat has an upper bound,
# so a long run of letters cannot make the check slow.
SECRET_SHAPES = [
    (r"-----BEGIN [A-Z0-9 ]{0,40}PRIVATE KEY-----", "a private key"),
    (r"sk-ant-[A-Za-z0-9_-]{20,512}", "an Anthropic API key"),
    (r"sk-(?:proj|svcacct|admin)-[A-Za-z0-9_-]{20,512}", "an OpenAI API key"),
    (r"sk-[A-Za-z0-9]{32,512}", "an API key"),
    (r"github_pat_[A-Za-z0-9_]{50,512}", "a GitHub token"),
    (r"gh[pousr]_[A-Za-z0-9]{36,512}", "a GitHub token"),
    (r"glpat-[A-Za-z0-9_-]{20,512}", "a GitLab token"),
    (r"xox[abposr]-[A-Za-z0-9-]{10,512}", "a Slack token"),
    (r"(?:AKIA|ASIA)[A-Z0-9]{16}", "an AWS access key ID"),
    (r"AIza[A-Za-z0-9_-]{35}", "a Google API key"),
    (r"npm_[A-Za-z0-9]{36}", "an npm token"),
    (r"hf_[A-Za-z0-9]{30,512}", "a Hugging Face token"),
    (r"(?:sk|rk)_(?:live|test)_[A-Za-z0-9]{20,512}", "a Stripe key"),
    (r"SG\.[A-Za-z0-9_-]{16,512}\.[A-Za-z0-9_-]{16,512}", "a SendGrid key"),
    (r"eyJ[A-Za-z0-9_-]{8,512}\.eyJ[A-Za-z0-9_-]{8,512}\.[A-Za-z0-9_-]{8,512}", "a signed web token"),
]
SECRET_SHAPES = [(re.compile(p), kind) for p, kind in SECRET_SHAPES]

# `password=...`, `API_KEY: ...`, `"token": "..."`: a secret's name, then `=` or `:`, then a value.
SECRET_WORD = (r"(?:password|passwd|passphrase|secret|token|api[_-]?key|access[_-]?key|"
               r"private[_-]?key|credentials?)")
ASSIGNMENT = re.compile(r"(?i)" + SECRET_WORD + r"[A-Za-z0-9_.-]{0,40}[\"']?\s*[:=]\s*[\"']?([^\s\"'`,;)\]}]{1,512})")
# A URL whose user part carries a password between the user name's colon and the at sign.
URL_PASSWORD = re.compile(r"[A-Za-z][A-Za-z0-9+.-]{0,31}://[^\s/:@]{1,256}:([^\s/@]{1,256})@")
# Environment variables whose name has one of these words hold secrets.
SECRET_ENV_NAME = re.compile(r"(?:^|_)(?:API_KEY|ACCESS_KEY|SECRET_KEY|PRIVATE_KEY|KEY|TOKEN|SECRET|"
                             r"PASSWORD|PASSWD|PASSPHRASE|PAT|CREDENTIALS?|AUTH|COOKIE)(?:_|$)")
# Words that stand where a value would be, so `password: required` is not a secret.
PLACEHOLDERS = {
    "undefined", "null", "none", "nil", "changeme", "change_me", "replace_me", "replaceme",
    "your_key_here", "your_api_key", "your_token", "your_token_here", "todo", "example",
    "dummy", "placeholder", "redacted", "required", "optional", "missing",
}
MIN_SECRET_LENGTH = 8


def looks_like_value(value):
    """True when the text after a secret's name looks like a real value, not a word or a reference."""
    value = value.strip()
    if len(value) < MIN_SECRET_LENGTH:
        return False
    if value[0] in "$<{%/~.*" or value.lower() in PLACEHOLDERS or len(set(value)) == 1:
        return False
    has_letter = any(c.isalpha() for c in value)
    has_digit = any(c.isdigit() for c in value)
    return (has_letter and has_digit) or len(value) >= 20


def secret_env_values():
    """Return (name, value) for the environment variables whose name marks them as secrets."""
    found = []
    for name, value in os.environ.items():
        if not SECRET_ENV_NAME.search(name.upper()):
            continue
        value = value.strip()
        if len(value) < MIN_SECRET_LENGTH or value[0] in "/~" or value.lower() in PLACEHOLDERS:
            continue
        found.append((name, value))
    return found


def find_secret(text, env_values):
    """Return what kind of secret the text holds, or None. Never returns the value itself."""
    for name, value in env_values:
        if value in text:
            return "the value of $" + name
    for pattern, kind in SECRET_SHAPES:
        if pattern.search(text):
            return kind
    for m in ASSIGNMENT.finditer(text):
        if looks_like_value(m.group(1)):
            return "a value written after a secret's name"
    for m in URL_PASSWORD.finditer(text):
        password = m.group(1)
        if len(password) >= 4 and password[0] not in "$<{*" and password.lower() not in PLACEHOLDERS:
            return "a password inside a URL"
    return None


# ------------------------------------------------------------------ paths and git

def state_home():
    return os.environ.get("SESSION_HANDOFF_HOME") or os.path.join(os.path.expanduser("~"), ".local", "share", "session-handoff")


def display(path):
    """Show a path under the home folder as ~/..., also when one of them went through a symbolic link."""
    raw = os.path.expanduser("~")
    for home in (raw, os.path.realpath(raw)):
        if home and home != "/" and (path == home or path.startswith(home + os.sep)):
            return "~" + path[len(home):]
    return path


def git(path, *args):
    """Run a read-only git command in path and return its output, or None when git fails."""
    try:
        r = subprocess.run(["git", "-C", path] + list(args), capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return r.stdout.strip() if r.returncode == 0 else None


def project_root(given):
    path = os.path.realpath(os.path.expanduser(given or os.getcwd()))
    if not os.path.isdir(path):
        fail(2, "input: --project %s is not a folder" % display(path))
    top = git(path, "rev-parse", "--show-toplevel")
    return os.path.realpath(top) if top else path


def git_position(project):
    """Return (branch, commit) of the project, with "none" where git cannot tell."""
    if git(project, "rev-parse", "--show-toplevel") is None:
        return "none", "none"
    branch = git(project, "branch", "--show-current") or "detached"
    commit = git(project, "rev-parse", "--short", "HEAD") or "none"
    return branch, commit


def snapshot_path(project):
    slug = re.sub(r"[^a-z0-9]+", "-", os.path.basename(project).lower()).strip("-")[:40].strip("-") or "project"
    digest = hashlib.sha256(project.encode("utf-8")).hexdigest()[:8]
    return os.path.join(state_home(), "%s-%s.md" % (slug, digest))


def now_epoch():
    # Tests fix the clock so that ages and expiry are stable.
    value = os.environ.get("SESSION_HANDOFF_NOW", "")
    return int(value) if value.isdigit() else int(time.time())


def iso(epoch):
    return datetime.datetime.fromtimestamp(epoch, datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_iso(text):
    try:
        when = datetime.datetime.strptime(text, "%Y-%m-%dT%H:%M:%SZ")
    except (TypeError, ValueError):
        return None
    return int(when.replace(tzinfo=datetime.timezone.utc).timestamp())


def age(seconds):
    seconds = max(0, seconds)
    if seconds < 3600:
        n, unit = seconds // 60, "minute"
    elif seconds < DAY:
        n, unit = seconds // 3600, "hour"
    else:
        n, unit = seconds // DAY, "day"
    return "%d %s%s ago" % (n, unit, "" if n == 1 else "s")


def fail(code, *lines):
    for line in lines:
        print(line, file=sys.stderr)
    sys.exit(code)


# ------------------------------------------------------------------ the saved file

def read_snapshot(path):
    """Return (header, body, text) of a saved snapshot, or raise ValueError naming the problem."""
    if os.path.getsize(path) > MAX_FILE_BYTES:
        raise ValueError("it is larger than %d KiB" % (MAX_FILE_BYTES // 1024))
    with open(path, encoding="utf-8") as f:
        text = f.read()
    lines = text.split("\n")
    if lines[0] != "---":
        raise ValueError("it does not start with a --- line")
    try:
        end = lines.index("---", 1)
    except ValueError:
        raise ValueError("its header has no closing --- line")
    header = {}
    for line in lines[1:end]:
        key, sep, value = line.partition(": ")
        if not sep:
            raise ValueError("its header line %r is not key: value" % line[:40])
        header[key] = value
    if header.get("format") != FORMAT:
        raise ValueError("it is in format %r, and this version reads only %s" % (header.get("format", "none"), FORMAT))
    for key in ("project", "saved_at", "branch", "commit", "issue"):
        if key not in header:
            raise ValueError("its header has no %s" % key)
    if parse_iso(header["saved_at"]) is None:
        raise ValueError("its saved_at is not a time")
    body = lines[end + 1:]
    at = 0
    for _, heading, _ in PARTS:
        try:
            at = body.index(heading, at) + 1
        except ValueError:
            raise ValueError("it has no %r heading after the ones before it" % heading)
    return header, "\n".join(body), text


def saved_at(path):
    """Return when a snapshot file was saved, or None when its header cannot be read."""
    try:
        with open(path, encoding="utf-8") as f:
            head = f.read(4096)
    except (OSError, UnicodeDecodeError):
        return None
    m = re.search(r"^saved_at: (\S+)$", head, re.M)
    return parse_iso(m.group(1)) if m and head.startswith("---\n") else None


def prune(now):
    """Remove this plugin's snapshots saved more than KEEP_DAYS ago. Other files are left alone."""
    home = state_home()
    try:
        names = os.listdir(home)
    except OSError:
        return
    for name in names:
        path = os.path.join(home, name)
        if not SNAPSHOT_NAME.match(name) or os.path.islink(path) or not os.path.isfile(path):
            continue
        when = saved_at(path)
        # A file whose time cannot be read is kept: an unknown age is not an old one.
        if when is not None and now - when > KEEP_DAYS * DAY:
            try:
                os.remove(path)
            except OSError:
                pass


def write_private(path, text):
    home = os.path.dirname(path)
    os.makedirs(home, mode=0o700, exist_ok=True)
    os.chmod(home, 0o700)
    fd, tmp = tempfile.mkstemp(dir=home, prefix=".tmp-", suffix=".md")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.remove(tmp)
        raise
    os.chmod(path, 0o600)


# ------------------------------------------------------------------ checking the input

def check_text(errors, field, value, max_lines, max_chars, allow_empty=False):
    if not isinstance(value, str):
        errors.append("%s must be text" % field)
        return ""
    value = "\n".join(line.rstrip() for line in value.strip().split("\n"))
    if not value and not allow_empty:
        errors.append("%s is empty" % field)
    lines = value.split("\n") if value else []
    if any(not line.strip() for line in lines):
        errors.append("%s has a blank line" % field)
    if len(lines) > max_lines:
        errors.append("%s has %d lines; at most %d" % (field, len(lines), max_lines))
    if len(value) > max_chars:
        errors.append("%s has %d characters; at most %d" % (field, len(value), max_chars))
    return value


def check_keys(errors, field, obj, required, optional=()):
    for key in required:
        if key not in obj:
            errors.append("%s has no %s" % (field, key))
    for key in obj:
        if key not in required and key not in optional:
            errors.append("%s has an unknown key %s" % (field, key))


def check_input(data):
    """Return (message parts, snapshot or None, errors)."""
    errors = []
    if not isinstance(data, dict):
        return None, None, ["the input must be a JSON object with message and snapshot"]
    check_keys(errors, "the input", data, ("message", "snapshot"))
    message = {}
    raw = data.get("message")
    if not isinstance(raw, dict):
        errors.append("message must be an object with %s" % ", ".join(MESSAGE_PARTS))
    else:
        check_keys(errors, "message", raw, MESSAGE_PARTS)
        for part in MESSAGE_PARTS:
            if part in raw:
                message[part] = check_text(errors, "message." + part, raw[part], PART_MAX_LINES, PART_MAX_CHARS)

    raw = data.get("snapshot")
    if raw is None:
        return message, None, errors
    if not isinstance(raw, dict):
        errors.append("snapshot must be an object, or null when there is nothing to record")
        return message, None, errors
    check_keys(errors, "snapshot", raw, [key for key, _, _ in PARTS], ("issue",))
    snap = {"issue": "none", "phase": ""}
    if "issue" in raw:
        issue = check_text(errors, "snapshot.issue", raw["issue"], 1, ISSUE_MAX_CHARS, allow_empty=True)
        snap["issue"] = issue or "none"
    if "phase" in raw:
        snap["phase"] = check_text(errors, "snapshot.phase", raw["phase"], PHASE_MAX_LINES, PHASE_MAX_CHARS, allow_empty=True)
    for key, fields in ITEM_FIELDS.items():
        snap[key] = []
        if key not in raw:
            continue
        items = raw[key]
        if not isinstance(items, list):
            errors.append("snapshot.%s must be a list; give [] when there is none" % key)
            continue
        if len(items) > LIST_MAX_ITEMS:
            errors.append("snapshot.%s has %d items; at most %d" % (key, len(items), LIST_MAX_ITEMS))
        for i, item in enumerate(items):
            field = "snapshot.%s[%d]" % (key, i)
            if not isinstance(item, dict):
                errors.append("%s must be an object with %s" % (field, ", ".join(f for f, _ in fields)))
                continue
            check_keys(errors, field, item, [f for f, _ in fields])
            clean = {}
            for name, kind in fields:
                if name not in item:
                    continue
                if kind is bool:
                    if not isinstance(item[name], bool):
                        errors.append("%s.%s must be true or false" % (field, name))
                    clean[name] = item[name] is True
                else:
                    clean[name] = check_text(errors, "%s.%s" % (field, name), item[name], 1, ITEM_MAX_CHARS)
            snap[key].append(clean)
    if not any(snap[key] for key, _, _ in PARTS):
        # Nothing rejected, no phase, nothing delegated, nothing to avoid: nothing to keep.
        return message, None, errors
    return message, snap, errors


def texts(data, prefix=""):
    """Yield (field, text) for every string in the input, for the secret check."""
    if isinstance(data, str):
        yield prefix or "the input", data
    elif isinstance(data, dict):
        for key, value in data.items():
            yield from texts(value, "%s.%s" % (prefix, key) if prefix else str(key))
    elif isinstance(data, list):
        for i, value in enumerate(data):
            yield from texts(value, "%s[%d]" % (prefix, i))


# ------------------------------------------------------------------ rendering

def render_snapshot(project, snap, now):
    branch, commit = git_position(project)
    out = ["---", "format: " + FORMAT, "project: " + project, "saved_at: " + iso(now),
           "branch: " + branch, "commit: " + commit, "issue: " + snap["issue"], "---", "",
           "# Session handoff state", "", PREAMBLE, ""]
    for key, heading, empty in PARTS:
        out += [heading, ""]
        if key == "phase":
            out += [snap["phase"] or empty]
        elif not snap[key]:
            out += [empty]
        else:
            for item in snap[key]:
                if key == "rejected":
                    out += ["- " + item["option"], "  Reason: " + item["reason"]]
                elif key == "delegated":
                    out += ["- " + item["work"], "  Expected: " + item["expected"],
                            "  Waiting for the result: " + ("yes" if item["waiting"] else "no")]
                else:
                    out += ["- " + item["action"], "  Reason: " + item["reason"]]
        out += [""]
    return "\n".join(out)


def render_message(message, pointer):
    first = message["handoff"]
    if pointer:
        first += "\nBefore you start, read the saved state in %s." % pointer
    return "\n\n".join([first, message["background"], message["task"]])


# ------------------------------------------------------------------ commands

def cmd_save(args):
    now = now_epoch()
    project = project_root(args.project)
    try:
        if args.input:
            with open(args.input, "rb") as f:
                raw = f.read()
        else:
            raw = sys.stdin.buffer.read()
        data = json.loads(raw.decode("utf-8"))
    except OSError as e:
        fail(2, "input: cannot read %s: %s" % (args.input, e.strerror))
    except (UnicodeDecodeError, ValueError) as e:
        fail(2, "input: not valid JSON in UTF-8 (%s)" % str(e).split(":")[0])

    # The secret check runs on every string before anything else, so a refused value is never
    # written, printed, or echoed back in an error.
    env_values = secret_env_values()
    found = []
    for field, text in texts(data):
        kind = find_secret(text, env_values)
        if kind:
            found.append("secret: %s holds what looks like %s" % (field, kind))
    if found:
        fail(3, *found, "Nothing was saved. Refer to a secret by its name or place, for example "
                        "\"the token in .env\", never by its value, and run save again.")

    message, snap, errors = check_input(data)
    if errors:
        fail(2, *["input: " + e for e in errors], "Nothing was saved.")

    prune(now)
    path = snapshot_path(project)
    if snap is not None:
        write_private(path, render_snapshot(project, snap, now))
        print("Snapshot saved: " + display(path))
        pointer = display(path)
    else:
        line = "No snapshot written: there was nothing to record."
        when = saved_at(path) if os.path.isfile(path) else None
        if when is not None:
            line += " The state saved for this project %s is kept, and the message does not point at it." % age(now - when)
        print(line)
        pointer = None
    print("--- message to paste ---")
    print(render_message(message, pointer))
    print("--- end of message ---")
    return 0


def cmd_show(args):
    now = now_epoch()
    project = project_root(args.project)
    prune(now)
    path = snapshot_path(project)
    if not os.path.isfile(path):
        fail(1, "No saved state for %s. State is kept for %d days after a handoff." % (display(project), KEEP_DAYS))
    try:
        header, body, text = read_snapshot(path)
    except (OSError, UnicodeDecodeError, ValueError) as e:
        fail(2, "%s was not shown: %s." % (display(path), e))
    if header["project"] != project:
        fail(2, "%s was not shown: it belongs to %s, not %s." % (display(path), display(header["project"]), display(project)))
    kind = find_secret(text, secret_env_values())
    if kind:
        fail(3, "%s was not shown: it holds what looks like %s. Remove that part of the file, or run forget." % (display(path), kind))

    branch, commit = git_position(project)
    print("Saved state for " + display(project))
    print("  saved     %s (%s)" % (header["saved_at"], age(now - parse_iso(header["saved_at"]))))
    print("  issue     " + header["issue"])
    print("  then on   branch %s at commit %s" % (header["branch"], header["commit"]))
    print("  now on    branch %s at commit %s" % (branch, commit))
    if (branch, commit) != (header["branch"], header["commit"]):
        print("  The branch or commit has changed since the state was saved.")
    print("  file      " + display(path))
    print()
    print(body[body.index(PARTS[0][1]):].rstrip("\n"))
    return 0


def cmd_forget(args):
    project = project_root(args.project)
    path = snapshot_path(project)
    if not os.path.isfile(path):
        fail(1, "No saved state for %s." % display(project))
    os.remove(path)
    print("Removed the saved state for %s: %s" % (display(project), display(path)))
    return 0


def main():
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8")
        except (AttributeError, ValueError):
            pass
    parser = argparse.ArgumentParser(description="Save and read the state one session hands to the next.")
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("save", help="check the handoff JSON, save the snapshot, and print the message")
    p.add_argument("--project", help="the project folder (default: the current folder)")
    p.add_argument("--input", help="read the JSON from this file instead of standard input")
    p.set_defaults(func=cmd_save)
    p = sub.add_parser("show", help="print the saved state of the project")
    p.add_argument("--project", help="the project folder (default: the current folder)")
    p.set_defaults(func=cmd_show)
    p = sub.add_parser("forget", help="remove the saved state of the project")
    p.add_argument("--project", help="the project folder (default: the current folder)")
    p.set_defaults(func=cmd_forget)
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
