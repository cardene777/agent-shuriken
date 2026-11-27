#!/usr/bin/env python3
"""agent-notices: notices for the agent that never stop a tool call.

Each hook script runs this file with the hook's name. It reads one event from Claude Code or Codex
as JSON on standard input and prints, at most, one JSON object whose additionalContext the agent
reads after the call. It never returns a deny, an ask, a block, or a stop, and it exits 0 even when
the event cannot be read. Only the Python standard library is used.
"""
import datetime
import fcntl
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PLUGIN = "agent-notices"


# ---------------------------------------------------------------- shared helpers

def data_dir():
    """The folder for state and logs, created readable only by the user."""
    base = os.environ.get("XDG_DATA_HOME") or os.path.join(os.path.expanduser("~"), ".local", "share")
    path = os.path.join(base, PLUGIN)
    os.makedirs(path, mode=0o700, exist_ok=True)
    os.chmod(path, 0o700)
    return path


def say(hook, text, event_name="PostToolUse"):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": event_name,
        "additionalContext": f"{PLUGIN} ({hook}): {text}",
    }}))


def shown(path, cwd):
    """A path as the agent wrote it: relative to the working folder when it is inside it."""
    try:
        rel = os.path.relpath(os.path.realpath(path), os.path.realpath(cwd))
    except ValueError:
        return path
    return path if rel.startswith("..") else rel


def read_text(path, limit=4 * 1024 * 1024):
    try:
        with open(path, "rb") as f:
            data = f.read(limit)
    except OSError:
        return None
    return data.decode("utf-8", "replace")


def git(args, cwd):
    try:
        done = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, timeout=10,
                              stdin=subprocess.DEVNULL)
    except (OSError, subprocess.SubprocessError):
        return None
    return done.stdout.strip() if done.returncode == 0 else None


def repo_top(path):
    folder = path if os.path.isdir(path) else os.path.dirname(path)
    return git(["rev-parse", "--show-toplevel"], folder) if os.path.isdir(folder) else None


# ---------------------------------------------------------------- edits

EDIT_TOOLS = {"Edit", "Write", "MultiEdit", "apply_patch"}


def parse_patch(text, cwd):
    """Files and added and removed lines of a Codex apply_patch call."""
    files = []
    current = None
    for line in text.splitlines():
        m = re.match(r"^\*\*\* (Add|Update|Delete) File: (.+)$", line)
        if m:
            current = {"path": os.path.join(cwd, m.group(2).strip()), "added": [], "removed": [],
                       "deleted": m.group(1) == "Delete"}
            files.append(current)
            continue
        m = re.match(r"^\*\*\* Move to: (.+)$", line)
        if m and current:
            current["path"] = os.path.join(cwd, m.group(1).strip())
            continue
        if line.startswith("***") or current is None:
            continue
        if line.startswith("+"):
            current["added"].append(line[1:])
        elif line.startswith("-"):
            current["removed"].append(line[1:])
    return [(f["path"], "\n".join(f["added"]), "\n".join(f["removed"])) for f in files if not f["deleted"]]


def edits(event):
    """(absolute path, added text, removed text) for each file an edit call changed."""
    tool = event.get("tool_name") or ""
    data = event.get("tool_input") or {}
    cwd = event.get("cwd") or os.getcwd()
    if not isinstance(data, dict):
        return []
    if tool == "apply_patch":
        patch = data.get("command") or data.get("patch") or data.get("input") or ""
        if isinstance(patch, list):
            patch = "\n".join(str(p) for p in patch)
        return parse_patch(str(patch), cwd)
    path = data.get("file_path") or data.get("path")
    if not path:
        return []
    path = os.path.join(cwd, os.path.expanduser(path))
    if tool == "Write":
        return [(path, str(data.get("content") or ""), "")]
    if tool == "Edit":
        return [(path, str(data.get("new_string") or ""), str(data.get("old_string") or ""))]
    if tool == "MultiEdit":
        items = data.get("edits") or []
        return [(path, "\n".join(str(e.get("new_string") or "") for e in items if isinstance(e, dict)),
                 "\n".join(str(e.get("old_string") or "") for e in items if isinstance(e, dict)))]
    return []


# ---------------------------------------------------------------- pipefail-grep

SHELL_EXTS = (".sh", ".bash", ".zsh", ".ksh")
PIPEFAIL = re.compile(r"^\s*set\s+[^#\n]*\bpipefail\b", re.M)
PIPED_QUIET_GREP = re.compile(r"(?<!\|)\|(?!\|)\s*grep\s+(?:[^|;&]*\s)?(?:-[A-Za-z]*q[A-Za-z]*|--quiet|--silent)\b")


def is_shell(path, text):
    if path.endswith(SHELL_EXTS):
        return True
    first = text.split("\n", 1)[0]
    return bool(re.match(r"^#!.*\b(ba|z|k|da)?sh\b", first))


def pipefail_grep(event):
    cwd = event.get("cwd") or os.getcwd()
    found = []
    for path, added, _ in edits(event):
        text = read_text(path)
        if text is None or not is_shell(path, text) or not PIPEFAIL.search(text):
            continue
        new_lines = {line.strip() for line in added.splitlines() if line.strip()}
        for number, line in enumerate(text.splitlines(), 1):
            if line.lstrip().startswith("#"):
                continue
            if PIPED_QUIET_GREP.search(line) and line.strip() in new_lines:
                found.append(f"{shown(path, cwd)}:{number}")
    if found:
        say("pipefail-grep", f"{', '.join(found[:10])} pipes into `grep -q` while `pipefail` is set. "
            "grep -q stops reading at the first match, the command before it can then die of SIGPIPE, "
            "and under pipefail the whole pipe fails even though the text was found. "
            "Use `grep -c`, `grep ... > /dev/null`, or `grep -q ... <<< \"$(command)\"` instead.")


# ---------------------------------------------------------------- nohup

def strip_quoted(command):
    """The command without the text inside quotes. An unclosed quote is kept as it is."""
    out = []
    i, n = 0, len(command)
    while i < n:
        c = command[i]
        if c == "\\" and i + 1 < n:
            out.append("  ")
            i += 2
            continue
        if c in "'\"":
            end = command.find(c, i + 1)
            while c == '"' and end != -1 and command[end - 1] == "\\":
                end = command.find(c, end + 1)
            if end == -1:
                out.append(command[i:])
                break
            out.append(" " * (end - i + 1))
            i = end + 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


BACKGROUND_AMP = re.compile(r"(?<![&>|<])&(?![&>])")


def nohup(event):
    command = str((event.get("tool_input") or {}).get("command") or "")
    if "nohup" not in command:
        return
    bare = strip_quoted(command)
    if not re.search(r"(^|[\s;&|(])nohup\s", bare):
        return
    if BACKGROUND_AMP.search(bare) or re.search(r"(^|[\s;&|])disown\b", bare):
        say("nohup", "`nohup ... &` detaches the command from the agent, so no completion notice will come "
            "and its exit status is lost. Run it with the agent's own background run instead, such as "
            "`run_in_background` of the Bash tool in Claude Code, so you are told when it ends.")


# ---------------------------------------------------------------- grep-binary

def grep_found_nothing(response):
    if isinstance(response, str):
        text = response.strip()
        return text in ("", "No files found", "No matches found")
    if not isinstance(response, dict):
        return False
    for key in ("numFiles", "numMatches", "numLines"):
        value = response.get(key)
        if isinstance(value, int) and value > 0:
            return False
    if response.get("filenames"):
        return False
    content = response.get("content")
    if isinstance(content, str) and content.strip() not in ("", "No files found", "No matches found"):
        return False
    return True


def grep_binary(event):
    data = event.get("tool_input") or {}
    pattern = data.get("pattern")
    if not isinstance(pattern, str) or not pattern or not grep_found_nothing(event.get("tool_response")):
        return
    cwd = event.get("cwd") or os.getcwd()
    root = os.path.join(cwd, os.path.expanduser(data.get("path") or "."))
    flags = re.IGNORECASE if data.get("-i") else 0
    try:
        matcher = re.compile(pattern.encode("utf-8"), flags)
    except re.error:
        literal = pattern.encode("utf-8")
        matcher = re.compile(re.escape(literal), flags)
    hidden = []
    seen = 0
    walk = [(root, [], [os.path.basename(root)])] if os.path.isfile(root) else os.walk(root)
    for folder, dirs, files in walk:
        if os.path.isfile(root):
            folder = os.path.dirname(root)
        dirs[:] = [d for d in dirs if d != ".git"]
        for name in files:
            seen += 1
            if seen > 5000 or len(hidden) >= 5:
                break
            path = os.path.join(folder, name)
            try:
                with open(path, "rb") as f:
                    head = f.read(8192)
                    if b"\0" not in head:
                        continue
                    body = head + f.read(16 * 1024 * 1024)
            except OSError:
                continue
            if matcher.search(body):
                hidden.append(shown(path, cwd))
    if hidden:
        say("grep-binary", f"Grep found nothing, but {', '.join(hidden)} holds the pattern and is binary, "
            "so the search skipped it. Search binary files with `grep -a` or `rg -a` (`--text`).")


# ---------------------------------------------------------------- branch

def split_commands(command):
    return [part for part in re.split(r"&&|\|\||;|\||\n", strip_quoted_keep(command)) if part.strip()]


def strip_quoted_keep(command):
    """The command with separators inside quotes hidden, so splitting keeps quoted text whole."""
    out = []
    quote = ""
    for c in command:
        if quote:
            out.append("\x00" if c in "&|;\n" else c)
            if c == quote:
                quote = ""
        else:
            if c in "'\"":
                quote = c
            out.append(c)
    return "".join(out)


def git_words(segment):
    """(folder, subcommand, arguments) of one git command, or ("<dir>", "cd", []) for a cd."""
    try:
        words = shlex.split(segment.replace("\x00", " "))
    except ValueError:
        return None, None, []
    folder = None
    if len(words) > 1 and words[0] == "cd":
        return words[1], "cd", []
    if not words or os.path.basename(words[0]) != "git":
        return None, None, []
    words = words[1:]
    while words and words[0].startswith("-"):
        option = words.pop(0)
        if option == "-C" and words:
            folder = words.pop(0)
        elif option in ("-c", "--git-dir", "--work-tree") and words:
            words.pop(0)
    if not words:
        return folder, None, []
    return folder, words[0], words[1:]


def wanted_branch(sub, args, folder):
    if sub == "switch":
        it = iter(args)
        for word in it:
            if word in ("-c", "-C", "--create", "--force-create"):
                return next(it, None)
            if word in ("--detach", "-d", "-"):
                return None
            if not word.startswith("-"):
                return word
        return None
    if sub == "checkout":
        if "--" in args:
            return None
        it = iter(args)
        for word in it:
            if word in ("-b", "-B"):
                return next(it, None)
            if word in ("--detach", "-"):
                return None
            if word.startswith("-"):
                continue
            if git(["show-ref", "--verify", "--quiet", f"refs/heads/{word}"], folder) is not None:
                return word
            if git(["show-ref", "--verify", "--quiet", f"refs/remotes/origin/{word}"], folder) is not None:
                return word
            return None
    return None


def branch_state_file(session, top):
    folder = os.path.join(data_dir(), "branches")
    os.makedirs(folder, mode=0o700, exist_ok=True)
    now = time.time()
    for name in os.listdir(folder):
        old = os.path.join(folder, name)
        try:
            if now - os.path.getmtime(old) > 7 * 86400:
                os.remove(old)
        except OSError:
            pass
    key = hashlib.sha256(f"{session}\0{top}".encode()).hexdigest()[:24]
    return os.path.join(folder, key)


def write_private(path, text):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(text)


def branch(event):
    command = str((event.get("tool_input") or {}).get("command") or "")
    if not re.search(r"\b(switch|checkout|commit)\b", command):
        return
    cwd = event.get("cwd") or os.getcwd()
    folder = cwd
    want = None
    committed = False
    for segment in split_commands(command):
        where, sub, args = git_words(segment)
        if sub == "cd" and where:
            folder = os.path.join(folder, os.path.expanduser(where))
            continue
        target = os.path.join(folder, os.path.expanduser(where)) if where else folder
        if sub in ("switch", "checkout"):
            name = wanted_branch(sub, args, target)
            if name:
                want, folder = name, target
        elif sub == "commit":
            committed, folder = True, target
    if not want and not committed:
        return
    if not os.path.isdir(folder):
        return
    top = git(["rev-parse", "--show-toplevel"], folder)
    if not top:
        return
    head = git(["symbolic-ref", "--quiet", "--short", "HEAD"], top) or "a detached HEAD"
    state = branch_state_file(str(event.get("session_id") or ""), top)
    where = "this repository" if os.path.realpath(top) == os.path.realpath(cwd) else f"`{shown(top, cwd)}`"
    if want:
        write_private(state, want)
        if head != want:
            say("branch", f"The command asked to switch to `{want}`, but {where} is on `{head}`. "
                "Read the command's output to see why the switch did not happen before you go on.")
        return
    try:
        with open(state, encoding="utf-8") as f:
            last = f.read().strip()
    except OSError:
        return
    if last and head != last:
        say("branch", f"The commit went to `{head}`, but this session last switched {where} to `{last}`. "
            "Another process may have switched the branch; check with `git log -1` and move the commit if it is on the wrong branch.")


# ---------------------------------------------------------------- env-example

NAME = r"([A-Za-z_][A-Za-z0-9_]*)"
Q = r"['\"]"
ENV_READS = {
    "js": [rf"process\.env\.{NAME}", rf"process\.env\[\s*{Q}{NAME}{Q}\s*\]", rf"import\.meta\.env\.{NAME}",
           rf"Deno\.env\.get\(\s*{Q}{NAME}{Q}", rf"Bun\.env\.{NAME}"],
    "py": [rf"os\.environ\[\s*{Q}{NAME}{Q}\s*\]", rf"os\.environ\.get\(\s*{Q}{NAME}{Q}", rf"os\.getenv\(\s*{Q}{NAME}{Q}"],
    "go": [rf"os\.Getenv\(\s*\"{NAME}\"", rf"os\.LookupEnv\(\s*\"{NAME}\""],
    "rb": [rf"ENV\[\s*{Q}{NAME}{Q}\s*\]", rf"ENV\.fetch\(\s*{Q}{NAME}{Q}"],
    "rs": [rf"env::var(?:_os)?\(\s*\"{NAME}\"", rf"(?:option_)?env!\(\s*\"{NAME}\""],
}
LANG_OF = {".js": "js", ".jsx": "js", ".ts": "js", ".tsx": "js", ".mjs": "js", ".cjs": "js", ".mts": "js",
           ".cts": "js", ".vue": "js", ".svelte": "js", ".py": "py", ".go": "go", ".rb": "rb", ".rs": "rs"}
COMMON_NAMES = {"NODE_ENV", "PATH", "HOME", "USER", "PWD", "SHELL", "TMPDIR", "TEMP", "TMP", "LANG", "CI", "TZ"}
EXAMPLE_FILE = re.compile(r"^\.env(?:\.[\w.-]+)?\.(?:example|sample|template)$|^\.env\.(?:example|sample|template)(?:\.[\w.-]+)?$")


def env_names(lang, text):
    names = set()
    for pattern in ENV_READS[lang]:
        names.update(re.findall(pattern, text))
    return names


def env_example(event):
    cwd = event.get("cwd") or os.getcwd()
    notes = []
    for path, added, removed in edits(event):
        lang = LANG_OF.get(os.path.splitext(path)[1])
        if not lang:
            continue
        new = env_names(lang, added) - env_names(lang, removed) - COMMON_NAMES
        if not new:
            continue
        top = repo_top(path) or cwd
        try:
            examples = sorted(n for n in os.listdir(top) if EXAMPLE_FILE.match(n))
        except OSError:
            continue
        if not examples:
            continue
        listed = set()
        for name in examples:
            text = read_text(os.path.join(top, name)) or ""
            listed.update(re.findall(r"^\s*#?\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=", text, re.M))
        missing = sorted(new - listed)
        if missing:
            files = ", ".join(f"`{shown(os.path.join(top, n), cwd)}`" for n in examples)
            notes.append(f"`{shown(path, cwd)}` reads {', '.join(missing)}, which {files} does not list")
    if notes:
        say("env-example", "; ".join(notes) + ". Add each name with a placeholder value so others know to set it.")


# ---------------------------------------------------------------- tmp-space

def tmp_space(event):
    folder = (os.environ.get("TMPDIR") or tempfile.gettempdir() or "/tmp").rstrip("/") or "/"
    try:
        limit = float(os.environ.get("AGENT_NOTICES_TMP_MIN_GB") or 5)
    except ValueError:
        limit = 5.0
    try:
        st = os.statvfs(folder)
    except OSError:
        return
    free = st.f_bavail * st.f_frsize / (1 << 30)
    if free < limit:
        say("tmp-space", f"The temporary directory {folder} has {free:.1f} GB free, under the limit of "
            f"{limit:g} GB (AGENT_NOTICES_TMP_MIN_GB). Remove temporary files you made, or point TMPDIR at a "
            "disk with room, before large builds or tests.")


# ---------------------------------------------------------------- security

def security_patterns():
    sys.path.insert(0, os.path.join(HERE, "security_guidance"))
    try:
        from patterns import SECURITY_PATTERNS  # type: ignore  # Anthropic's file, copied unmodified
    except Exception:
        return []
    finally:
        sys.path.pop(0)
    return SECURITY_PATTERNS


def rule_matches(rule, path, content):
    """The upstream rule semantics: path_filter gates, then path_check, substrings, or regex match."""
    normalized = path.lstrip("/")
    if "path_filter" in rule:
        try:
            if not rule["path_filter"](normalized):
                return False
        except Exception:
            return False
    if "path_check" in rule:
        try:
            if rule["path_check"](normalized):
                return True
        except Exception:
            pass
    if content and any(s in content for s in rule.get("substrings") or []):
        return True
    if content and rule.get("regex"):
        try:
            return bool(re.search(rule["regex"], content))
        except re.error:
            return False
    return False


def security(event):
    cwd = event.get("cwd") or os.getcwd()
    rules = None
    notes = []
    for path, added, _ in edits(event):
        if rules is None:
            rules = security_patterns()
        for rule in rules:
            if rule_matches(rule, path, added):
                notes.append(f"{shown(path, cwd)}: {rule.get('reminder', '').strip()}")
    if notes:
        say("security", "\n\n".join(notes[:5]))


# ---------------------------------------------------------------- format

JS_EXTS = (".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs", ".mts", ".cts", ".json", ".jsonc", ".css")
PRETTIER_EXTS = JS_EXTS + (".scss", ".less", ".html", ".vue", ".svelte", ".md", ".mdx", ".yaml", ".yml", ".graphql")
PRETTIER_FILES = (".prettierrc", ".prettierrc.json", ".prettierrc.yaml", ".prettierrc.yml", ".prettierrc.js",
                  ".prettierrc.cjs", ".prettierrc.mjs", ".prettierrc.toml", ".prettierrc.json5",
                  "prettier.config.js", "prettier.config.cjs", "prettier.config.mjs", "prettier.config.ts")


def upward(start, stop):
    folder = start
    while True:
        yield folder
        if folder == stop or os.path.dirname(folder) == folder:
            return
        folder = os.path.dirname(folder)


def has_prettier(folder):
    if any(os.path.isfile(os.path.join(folder, n)) for n in PRETTIER_FILES):
        return True
    try:
        with open(os.path.join(folder, "package.json"), encoding="utf-8") as f:
            return "prettier" in json.load(f)
    except (OSError, ValueError, TypeError):
        return False


def find_tool(name, folder, stop, local_dirs):
    """The tool installed in the project (its node_modules or virtual environment) or on PATH."""
    for up in upward(folder, stop):
        for sub in local_dirs:
            candidate = os.path.join(up, sub, name)
            if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
                return candidate
    return shutil.which(name)


def pyproject_has(folder, table):
    text = read_text(os.path.join(folder, "pyproject.toml")) or ""
    return re.search(rf"^\[tool\.{table}(\]|\.)", text, re.M) is not None


def cargo_edition(folder):
    text = read_text(os.path.join(folder, "Cargo.toml")) or ""
    m = re.search(r'^\s*edition\s*=\s*"(\d{4})"', text, re.M)
    return m.group(1) if m else "2021"


def formatter_for(path, top):
    """(tool name, command) of the project's own formatter for this file, or None."""
    ext = os.path.splitext(path)[1]
    start = os.path.dirname(path)
    node_bins = (os.path.join("node_modules", ".bin"),)
    venv_bins = (os.path.join(".venv", "bin"), os.path.join("venv", "bin"))
    for folder in upward(start, top):
        if ext in PRETTIER_EXTS:
            biome = any(os.path.isfile(os.path.join(folder, n)) for n in ("biome.json", "biome.jsonc"))
            if biome and ext in JS_EXTS:
                tool = find_tool("biome", folder, top, node_bins)
                return ("biome", [tool, "format", "--write", path], folder) if tool else None
            if has_prettier(folder):
                tool = find_tool("prettier", folder, top, node_bins)
                return ("prettier", [tool, "--write", path], folder) if tool else None
        if ext in (".py", ".pyi"):
            if pyproject_has(folder, "ruff") or any(os.path.isfile(os.path.join(folder, n)) for n in ("ruff.toml", ".ruff.toml")):
                tool = find_tool("ruff", folder, top, venv_bins)
                return ("ruff", [tool, "format", path], folder) if tool else None
            if pyproject_has(folder, "black"):
                tool = find_tool("black", folder, top, venv_bins)
                return ("black", [tool, "-q", path], folder) if tool else None
        if ext == ".go" and os.path.isfile(os.path.join(folder, "go.mod")):
            tool = shutil.which("gofmt")
            return ("gofmt", [tool, "-w", path], folder) if tool else None
        if ext == ".rs" and os.path.isfile(os.path.join(folder, "Cargo.toml")):
            tool = shutil.which("rustfmt") or find_tool("rustfmt", os.path.expanduser("~"), os.path.expanduser("~"), (os.path.join(".cargo", "bin"),))
            return ("rustfmt", [tool, "--edition", cargo_edition(folder), path], folder) if tool else None
    return None


def digest(path):
    try:
        with open(path, "rb") as f:
            return hashlib.sha256(f.read()).hexdigest()
    except OSError:
        return None


def format_files(event):
    cwd = event.get("cwd") or os.getcwd()
    changed = []
    for path, _, _ in edits(event):
        if not os.path.isfile(path):
            continue
        top = repo_top(path) or cwd
        found = formatter_for(path, top if path.startswith(top) else os.path.dirname(path))
        if not found:
            continue
        name, command, folder = found
        before = digest(path)
        try:
            subprocess.run(command, cwd=folder, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, timeout=20)
        except (OSError, subprocess.SubprocessError):
            continue
        if digest(path) != before:
            changed.append(f"`{shown(path, cwd)}` with {name}")
    if changed:
        say("format", f"Formatted {', '.join(changed)}. Read the file again before the next edit, since its text changed.")


# ---------------------------------------------------------------- presence

def presence(event):
    target = os.environ.get("CLAUDE_CLIENT_PRESENCE_FILE")
    if not target:
        return
    target = os.path.expanduser(target)
    kind = event.get("hook_event_name")
    if kind == "SessionStart":
        os.makedirs(os.path.dirname(target) or ".", exist_ok=True)
        with open(target, "a", encoding="utf-8"):
            os.utime(target, None)
    elif kind == "SessionEnd":
        try:
            os.remove(target)
        except FileNotFoundError:
            pass


# ---------------------------------------------------------------- edit-loop and sequential

COUNT_DAYS = 7
# Calls closer than this come together in one message; calls further apart than MESSAGE_GAP start a new one.
TOGETHER_GAP = 0.2
MESSAGE_GAP = 0.5


def count_file(name, session):
    """The count file of one session in <data folder>/<name>/, removing count files older than COUNT_DAYS."""
    folder = os.path.join(data_dir(), name)
    os.makedirs(folder, mode=0o700, exist_ok=True)
    os.chmod(folder, 0o700)
    now = time.time()
    for entry in os.listdir(folder):
        old = os.path.join(folder, entry)
        try:
            if now - os.path.getmtime(old) > COUNT_DAYS * 86400:
                os.remove(old)
        except OSError:
            pass
    return os.path.join(folder, hashlib.sha256(str(session).encode()).hexdigest()[:24])


def update_locked(path, change):
    """Reads the file under an exclusive lock, passes its text to change, and writes back what change returns."""
    fd = os.open(path, os.O_RDWR | os.O_CREAT, 0o600)
    with os.fdopen(fd, "r+", encoding="utf-8") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        text = change(f.read())
        f.seek(0)
        f.truncate()
        f.write(text)


def positive_number(name, default):
    try:
        value = int(os.environ.get(name) or default)
    except ValueError:
        return default
    return value if value > 0 else default


def inside(path, folder):
    path, folder = os.path.realpath(path), os.path.realpath(folder)
    return path == folder or path.startswith(folder.rstrip(os.sep) + os.sep)


def ignored_by_git(path):
    folder = os.path.dirname(path)
    while not os.path.isdir(folder):
        parent = os.path.dirname(folder)
        if parent == folder:
            return False
        folder = parent
    try:
        done = subprocess.run(["git", "check-ignore", "-q", "--", path], cwd=folder, capture_output=True,
                              timeout=10, stdin=subprocess.DEVNULL)
    except (OSError, subprocess.SubprocessError):
        return False
    return done.returncode == 0


def edit_loop(event):
    session = event.get("session_id")
    paths = sorted({os.path.realpath(path) for path, _, _ in edits(event)})
    if not session or not paths:
        return
    every = positive_number("AGENT_NOTICES_EDIT_LOOP_EVERY", 5)
    due = []

    def count(text):
        try:
            counts = json.loads(text) if text.strip() else {}
        except ValueError:
            counts = {}
        if not isinstance(counts, dict):
            counts = {}
        for path in paths:
            n = counts.get(path)
            n = (n if isinstance(n, int) else 0) + 1
            counts[path] = n
            if n % every == 0:
                due.append((path, n))
        return json.dumps(counts)

    update_locked(count_file("edit-loop", session), count)
    cwd = event.get("cwd") or os.getcwd()
    skill = (os.environ.get("AGENT_NOTICES_EDIT_LOOP_SKILL") or "").strip()
    how = f"use the `{skill}` skill to write" if re.fullmatch(r"[\w:.-]+", skill) else "write"
    for path, n in due:
        if inside(path, tempfile.gettempdir()) or ignored_by_git(path):
            continue
        say("edit-loop", f"You have edited `{shown(path, cwd)}` {n} times in this session. If the same kind of fix "
            f"keeps coming back, {how} a command that reproduces the failure and confirm the root cause before the next fix.")


def sequential(event):
    if os.environ.get("CLAUDECODE") != "1":
        return
    session = event.get("session_id")
    if not session or event.get("tool_name") in ("AskUserQuestion", "ExitPlanMode"):
        return
    after = positive_number("AGENT_NOTICES_SEQUENTIAL_AFTER", 10)
    spoke = []

    def count(text):
        now = time.time()
        try:
            n, last = text.split()
            n, last = int(n), float(last)
        except ValueError:
            n, last = 0, 0.0
        gap = now - last
        if gap < TOGETHER_GAP:
            n = 0
        elif gap >= MESSAGE_GAP:
            n += 1
        if n >= after:
            spoke.append(n)
            n = 0
        return f"{n} {now}\n"

    update_locked(count_file("sequential", session), count)
    if spoke:
        say("sequential", f"The last {after} tool calls each came in a message of their own. When calls do not "
            "need each other's results, such as reads of several files or independent commands, make them together "
            "in one message so they run at the same time.")


# ---------------------------------------------------------------- skill-log and mcp-log

def now_iso():
    return datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def append_line(name, record):
    path = os.path.join(data_dir(), name)
    try:
        if os.path.getsize(path) > 1024 * 1024:
            os.replace(path, path + ".1")
    except OSError:
        pass
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
    os.fchmod(fd, 0o600)
    with os.fdopen(fd, "a", encoding="utf-8") as f:
        f.write(json.dumps(record, separators=(",", ":")) + "\n")


def call_log(event, file_name, fields):
    kind = event.get("hook_event_name")
    key = str(event.get("tool_use_id") or f"{event.get('session_id')}:{event.get('tool_name')}")
    folder = os.path.join(data_dir(), "pending")
    os.makedirs(folder, mode=0o700, exist_ok=True)
    pending = os.path.join(folder, hashlib.sha256(key.encode()).hexdigest()[:24])
    if kind == "PreToolUse":
        write_private(pending, json.dumps({"start": now_iso(), "t": time.time()}))
        return
    if kind not in ("PostToolUse", "PostToolUseFailure"):
        return
    end, t_end = now_iso(), time.time()
    try:
        with open(pending, encoding="utf-8") as f:
            begun = json.load(f)
        os.remove(pending)
    except (OSError, ValueError):
        begun = {"start": end, "t": t_end}
    record = {"v": 1, **fields, "start": begun.get("start", end), "end": end,
              "duration_ms": max(0, int(round((t_end - float(begun.get("t", t_end))) * 1000))),
              "ok": kind == "PostToolUse"}
    append_line(file_name, record)


def skill_log(event):
    data = event.get("tool_input") or {}
    name = data.get("skill") or data.get("name") or data.get("command") if isinstance(data, dict) else None
    call_log(event, "skill-calls.jsonl", {"skill": str(name or "unknown")})


def mcp_log(event):
    parts = str(event.get("tool_name") or "").split("__")
    if len(parts) < 3 or parts[0] != "mcp":
        return
    call_log(event, "mcp-calls.jsonl", {"server": parts[1], "tool": "__".join(parts[2:])})


HOOKS = {
    "pipefail-grep": pipefail_grep,
    "nohup": nohup,
    "grep-binary": grep_binary,
    "branch": branch,
    "env-example": env_example,
    "tmp-space": tmp_space,
    "security": security,
    "format": format_files,
    "edit-loop": edit_loop,
    "sequential": sequential,
    "presence": presence,
    "skill-log": skill_log,
    "mcp-log": mcp_log,
}


def main():
    hook = HOOKS.get(sys.argv[1] if len(sys.argv) > 1 else "")
    try:
        event = json.load(sys.stdin)
    except ValueError:
        return
    if hook and isinstance(event, dict):
        try:
            hook(event)
        except Exception:
            pass  # a notice is never worth failing the call


if __name__ == "__main__":
    main()
    sys.exit(0)
