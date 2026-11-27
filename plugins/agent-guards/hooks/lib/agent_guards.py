#!/usr/bin/env python3
"""The six blocking hooks of agent-guards and the checks each runs.

Claude Code and Codex start a hook for each PreToolUse event and pass the event as JSON on standard
input. A hook prints a deny decision when it refuses the tool call and prints nothing otherwise, so
it never approves a call that the agent's own permission rules would ask about.

    agent_guards.py secret-read | secret-write | onepassword | outbound | git | delete

A hook runs one or more checks, and each check turns off with its own environment variable set to
`off`. The checks of a hook share one process, so a check added to a hook starts no new process on a
call. With AGENT_GUARDS_RECORD=on, each refusal adds one line (time, hook, kind) to refusals.log in
the data folder; the line never holds the command or a value.
"""

import fnmatch
import json
import os
import re
import shlex
import stat
import subprocess
import sys
import time
from urllib.parse import urlsplit

# The variable that turns off the first check of each hook. CHECKS, at the end of the file, lists
# every check of each hook with its variable.
OFF_VARS = {
    "secret-read": "AGENT_GUARDS_SECRET_READ",
    "secret-write": "AGENT_GUARDS_SECRET_WRITE",
    "onepassword": "AGENT_GUARDS_ONEPASSWORD",
    "outbound": "AGENT_GUARDS_OUTBOUND",
    "git": "AGENT_GUARDS_GIT",
    "delete": "AGENT_GUARDS_DELETE",
}


class Refusal(Exception):
    def __init__(self, kind, reason):
        super().__init__(reason)
        self.kind = kind
        self.reason = reason


def home():
    return os.environ.get("HOME") or os.path.expanduser("~")


def config_file(name):
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.join(home(), ".config")
    return os.path.join(base, "agent-guards", name)


def record(hook, kind):
    if os.environ.get("AGENT_GUARDS_RECORD", "").lower() != "on":
        return
    folder = os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.join(home(), ".local", "share"), "agent-guards")
    try:
        os.makedirs(folder, mode=0o700, exist_ok=True)
        with open(os.path.join(folder, "refusals.log"), "a", encoding="utf-8") as f:
            f.write(f"{time.strftime('%Y-%m-%dT%H:%M:%S%z')}\t{hook}\t{kind}\n")
    except OSError:
        pass


def deny(hook, reason):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": f"agent-guards ({hook}): {reason}",
    }}))


def list_entries(name):
    """Lines of a list file in ~/.config/agent-guards/, without blanks and # comments."""
    try:
        with open(config_file(name), encoding="utf-8") as f:
            lines = f.read().splitlines()
    except OSError:
        return []
    out = []
    for line in lines:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line == "~" or line.startswith("~/"):
            line = home() + line[1:]
        out.append(line.rstrip("/") or "/")
    return out


def listed(path, name):
    """Whether an absolute path is one of the places in a list file, or inside one."""
    for entry in list_entries(name):
        if "/" not in entry:
            if fnmatch.fnmatch(os.path.basename(path), entry):
                return True
        elif path == entry or path.startswith(entry + "/") or fnmatch.fnmatch(path, entry) \
                or fnmatch.fnmatch(path, entry + "/*"):
            return True
    return False


# ---------------------------------------------------------------------------------------------
# Reading the command

def command_text(event):
    command = (event.get("tool_input") or {}).get("command", "")
    if isinstance(command, list):
        # Codex can pass the shell's argv, such as ["bash", "-lc", "<script>"].
        if len(command) >= 3 and os.path.basename(str(command[0])) in SHELLS and command[1] in ("-c", "-lc", "-ic"):
            return str(command[2])
        return shlex.join(str(c) for c in command)
    return str(command or "")


SHELLS = {"bash", "sh", "zsh", "dash", "ksh"}
OPERATORS = {";", "&&", "||", "|", "|&", "&", "(", ")", ";;", "{", "}"}
# Commands that run the command after their options, and their options that take the next word as
# their value. An option written with its value in the same word (`-n10`, `--user=root`) is one word.
WRAPPERS = {
    "sudo": {"-u", "-g", "-h", "-p", "-C", "-D", "-R", "-T", "-U", "-r", "-t", "--user", "--group", "--host",
             "--prompt", "--close-from", "--chdir", "--chroot", "--command-timeout", "--other-user", "--role",
             "--type"},
    "doas": {"-u", "-C"},
    "exec": {"-a"},
    "time": {"-o", "-f", "--output", "--format"},
    "nice": {"-n", "--adjustment"},
    "env": {"-u", "-C", "--unset", "--chdir"},
    "timeout": {"-s", "-k", "--signal", "--kill-after"},
    "command": set(),
    "builtin": set(),
    "nohup": set(),
}
# Commands that run other commands, with the options that take a value. `find` runs the words after
# each of FIND_EXEC, up to `;` or a `+` after `{}`.
RUNNERS = {
    "xargs": {"-a", "-d", "-E", "-I", "-J", "-L", "-n", "-P", "-R", "-s", "-S", "--arg-file", "--delimiter",
              "--max-args", "--max-chars", "--max-lines", "--max-procs", "--process-slot-var"},
    "watch": {"-n", "-q", "--interval", "--equexit"},
}
FIND_EXEC = {"-exec", "-execdir", "-ok", "-okdir"}
ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")


def strip_heredocs(text):
    """Removes the bodies of here-documents opened outside quotes; quoted ones stay in the text."""
    out, i, n = [], 0, len(text)
    quote = None
    pending = []
    while i < n:
        c = text[i]
        if quote:
            out.append(c)
            if c == "\\" and quote == '"' and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if c == quote:
                quote = None
            i += 1
            continue
        if c in ("'", '"'):
            quote = c
            out.append(c)
            i += 1
            continue
        if c == "\\" and i + 1 < n:
            out.append(text[i:i + 2])
            i += 2
            continue
        if text.startswith("<<", i) and not text.startswith("<<<", i):
            m = re.match(r"<<(-?)\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\2", text[i:])
            if m:
                pending.append((m.group(3), m.group(1) == "-"))
                out.append(text[i:i + m.end()])
                i += m.end()
                continue
        if c == "\n" and pending:
            out.append("\n")
            i += 1
            for word, tabs in pending:
                while i < n:
                    end = text.find("\n", i)
                    end = n if end < 0 else end
                    line = text[i:end]
                    i = end + 1
                    if (line.lstrip("\t") if tabs else line) == word:
                        break
            pending = []
            continue
        out.append(c)
        i += 1
    return "".join(out)


def unquoted_newlines_to_semicolons(text):
    out, quote, i = [], None, 0
    while i < len(text):
        c = text[i]
        if quote:
            if c == "\\" and quote == '"' and i + 1 < len(text):
                out.append(text[i:i + 2])
                i += 2
                continue
            if c == quote:
                quote = None
        elif c in ("'", '"'):
            quote = c
        elif c == "\\" and i + 1 < len(text):
            if text[i + 1] == "\n":
                i += 2
                continue
            out.append(text[i:i + 2])
            i += 2
            continue
        elif c == "\n":
            c = ";"
        out.append(c)
        i += 1
    return "".join(out)


def tokens(text):
    lexer = shlex.shlex(unquoted_newlines_to_semicolons(strip_heredocs(text)), posix=True, punctuation_chars=";&|()<>")
    lexer.whitespace_split = True
    lexer.commenters = "#"
    try:
        return list(lexer)
    except ValueError:
        return None


def segments(text, depth=0):
    """Simple commands of a shell text, each a list of words, with the commands they run inside them."""
    words = tokens(text)
    if words is None:
        return None
    out, current = [], []
    for w in words + [";"]:
        if w in OPERATORS:
            if current:
                out.append(current)
            current = []
        else:
            current.append(w)
    nested = []
    for seg in out:
        nested.extend(nested_segments(seg, depth))
    return out + nested


def nested_segments(seg, depth):
    """The commands one simple command runs inside itself, up to three levels deep: the text after
    `bash -c` and `eval`, the command of `xargs`, each command after a `-exec` of `find`, and the text
    `watch` hands to the shell."""
    if depth >= 3:
        return []
    cmd, args = command_of(seg)
    if cmd in SHELLS:
        for i, a in enumerate(args):
            if a in ("-c", "-lc", "-ic") and i + 1 < len(args):
                return segments(args[i + 1], depth + 1) or []
        return []
    if cmd == "eval":
        return segments(" ".join(args), depth + 1) or []
    if cmd == "watch":
        rest = past_options(args, RUNNERS["watch"])
        return (segments(" ".join(rest), depth + 1) or []) if rest else []
    out = []
    for inner in run_commands(cmd, args):
        out.append(inner)
        out.extend(nested_segments(inner, depth + 1))
    return out


def past_options(args, values):
    """The words after the leading options, skipping the value of each option in `values`."""
    i = 0
    while i < len(args) and args[i].startswith("-") and args[i] != "-":
        if args[i] == "--":
            return args[i + 1:]
        i += 2 if args[i] in values else 1
    return args[i:]


def run_commands(cmd, args):
    """The commands `xargs` and `find` run, each a list of words."""
    if cmd == "xargs":
        rest = past_options(args, RUNNERS["xargs"])
        return [rest] if rest else []
    if cmd != "find":
        return []
    out = []
    for k, a in enumerate(args):
        if a not in FIND_EXEC:
            continue
        inner = []
        for b in args[k + 1:]:
            if b == ";" or (b == "+" and inner and inner[-1] == "{}"):
                break
            inner.append(b)
        if inner:
            out.append(inner)
    return out


def env_split_string(seg, i):
    """The string of the `env -S` option at seg[i] and the index after it, or None for another option."""
    opt = seg[i]
    if opt in ("-S", "--split-string"):
        return (seg[i + 1], i + 2) if i + 1 < len(seg) else ("", i + 1)
    if opt.startswith("--split-string="):
        return opt.split("=", 1)[1], i + 1
    if opt.startswith("-S"):
        return opt[2:], i + 1
    return None


def command_of(seg):
    """The command name of a simple command and its arguments, past assignments and wrappers. The
    value of a wrapper option is skipped with it, and the string of `env -S` is read as the words that
    follow, as env splits it."""
    i = 0
    while i < len(seg):
        w = seg[i]
        name = os.path.basename(w)
        if ASSIGNMENT.match(w):
            i += 1
            continue
        if name not in WRAPPERS:
            return name, seg[i + 1:]
        values = WRAPPERS[name]
        i += 1
        while i < len(seg) and (seg[i].startswith("-") or (name == "env" and ASSIGNMENT.match(seg[i]))):
            split = env_split_string(seg, i) if name == "env" else None
            if split is not None:
                try:
                    words = shlex.split(split[0])
                except ValueError:
                    words = split[0].split()
                return command_of(["env"] + words + seg[split[1]:])
            i += 2 if seg[i] in values else 1
        if name == "timeout":
            i += 1
    return "", []


VAR = re.compile(r"\$(\{[A-Za-z_][A-Za-z0-9_]*\}|[A-Za-z_][A-Za-z0-9_]*)")


def expand(word):
    """The word with ~ and $HOME expanded, or None when another variable or a substitution is left."""
    if word == "~" or word.startswith("~/"):
        word = home() + word[1:]
    word = word.replace("${HOME}", home())
    word = re.sub(r"\$HOME(?![A-Za-z0-9_])", lambda _match: home(), word)
    if "`" in word or "$" in word:
        return None
    return word


def absolute(path, cwd):
    return os.path.normpath(path if os.path.isabs(path) else os.path.join(cwd, path))


# ---------------------------------------------------------------------------------------------
# secret-read

ENV_KEEP = (".example", ".sample", ".template")
KEY_NAMES = {"id_rsa", "id_ed25519", "id_ecdsa", "id_dsa"}
KEY_EXTS = (".pem", ".key", ".p12", ".pfx", ".token", ".secret", ".private")
SOURCE_EXTS = (".py", ".js", ".mjs", ".cjs", ".ts", ".tsx", ".jsx", ".go", ".rs", ".rb", ".java", ".kt",
               ".swift", ".c", ".h", ".cc", ".cpp", ".cs", ".php", ".sh", ".bash", ".zsh", ".md", ".mdx",
               ".html", ".css", ".scss", ".vue", ".svelte", ".sol")
SECRET_PLACES = [
    (re.compile(r"/\.ssh/(id_[^/]*|config|[^/]*\.pem)$"), "an SSH key or SSH config"),
    (re.compile(r"/\.aws/(credentials|config)$"), "AWS credentials"),
    (re.compile(r"/\.config/gcloud/"), "Google Cloud credentials"),
    (re.compile(r"/\.azure/"), "Azure credentials"),
    (re.compile(r"/\.(zsh|bash)_history$"), "a shell history"),
    (re.compile(r"/\.npmrc$"), "an npm token file"),
    (re.compile(r"/\.git-credentials$"), "git credentials"),
    (re.compile(r"/\.docker/config\.json$"), "Docker credentials"),
    (re.compile(r"/\.kube/config$"), "a Kubernetes config"),
    (re.compile(r"/\.netrc$"), "a .netrc file"),
    (re.compile(r"/\.pgpass$"), "a PostgreSQL password file"),
    (re.compile(r"/\.gnupg/"), "a GnuPG folder"),
    (re.compile(r"/\.claude/history\.jsonl$"), "Claude Code's conversation records"),
    (re.compile(r"/\.claude/projects/.*\.jsonl$"), "Claude Code's conversation records"),
    (re.compile(r"/Library/(Keychains|Messages|Mail|Calendars|Safari|Cookies)(/|$)"), "private app data"),
    (re.compile(r"/Library/Application Support/(AddressBook|Google/Chrome|Firefox|1Password)(/|$)"), "private app data"),
    (re.compile(r"/Library/Group Containers(/|$)"), "private app data"),
]


def secret_kind(path):
    """What makes an absolute path secret, or None."""
    base = os.path.basename(path)
    if base == ".env" or (base.startswith(".env.") and not base.endswith(ENV_KEEP) and base != ".env.test"):
        return "a .env file"
    if base in KEY_NAMES or (base.startswith("id_") and "/.ssh/" in path and not base.endswith(".pub")):
        return "a private key"
    if base.endswith(KEY_EXTS):
        return "a key file"
    if re.search(r"_(token|key)([^a-zA-Z]|$)", base) and not base.endswith(SOURCE_EXTS):
        return "a token or key file"
    parts = path.split("/")[:-1]
    if "secrets" in parts or ".secrets" in parts:
        return "a file in a secrets folder"
    for pattern, kind in SECRET_PLACES:
        if pattern.search(path) and not (kind == "an SSH key or SSH config" and base.endswith(".pub")):
            return kind
    if listed(path, "secret-paths"):
        return "a place in your secret-paths list"
    return None


READERS = {"cat", "head", "tail", "less", "more", "strings", "xxd", "hexdump", "od", "grep", "egrep", "fgrep",
           "rg", "sed", "awk", "gawk", "source", ".", "bat", "nl", "tac", "base64", "jq", "cut", "sort",
           "uniq", "diff", "cmp", "cp", "scp", "rsync", "wc", "file"}
INTERPRETERS = {"python", "python3", "node", "ruby", "perl", "php", "bun", "deno"}
# Options that take the next word as their value, per reader.
VALUE_OPTIONS = {
    "head": {"-n", "-c"}, "tail": {"-n", "-c"},
    "grep": {"-e", "-f", "-m", "-A", "-B", "-C", "--regexp", "--file"},
    "egrep": {"-e", "-f", "-m", "-A", "-B", "-C"}, "fgrep": {"-e", "-f", "-m", "-A", "-B", "-C"},
    "rg": {"-e", "-f", "-m", "-A", "-B", "-C", "-g", "-t", "-T", "--glob", "--type"},
    "sed": {"-e", "-f"}, "awk": {"-f", "-v", "-F"}, "gawk": {"-f", "-v", "-F"},
    "jq": {"-f", "--from-file", "--indent"}, "cut": {"-d", "-f", "-c", "-b"},
    "sort": {"-k", "-t", "-o"}, "diff": {"-U", "-C"},
}
PATTERN_FIRST = {"grep", "egrep", "fgrep", "rg", "sed", "awk", "gawk", "jq"}
TAKES_PROGRAM = {"-e", "-f", "--regexp", "--file", "--from-file"}
CANNOT_TELL = ("it cannot tell which file the command reads, because the path comes from a variable or a "
               "command substitution, so name the file directly in the command.")


def read_targets(cmd, args):
    """The words a reader reads as files, with None for a word it cannot tell."""
    opts = VALUE_OPTIONS.get(cmd, set())
    positional, i, program_given = [], 0, False
    while i < len(args):
        a = args[i]
        if a == "--":
            positional.extend(args[i + 1:])
            break
        if a in ("<", "<<<"):
            i += 2
            continue
        if a.startswith("-") and a != "-":
            name = a.split("=", 1)[0]
            if name in TAKES_PROGRAM:
                program_given = True
                if name in ("-f", "--file", "--from-file") and "=" not in a and i + 1 < len(args):
                    positional.append(args[i + 1])
            if name in opts and "=" not in a:
                i += 2
                continue
            i += 1
            continue
        if a in (">", ">>", "2>", "&>"):
            i += 2
            continue
        positional.append(a)
        i += 1
    if cmd in PATTERN_FIRST and not program_given and positional:
        positional = positional[1:]
    if cmd in ("cp", "scp", "rsync") and positional:
        positional = positional[:-1]
    return positional


def check_secret_path(path_word, cwd):
    path = expand(path_word)
    if path is None:
        raise Refusal("cannot tell", CANNOT_TELL)
    kind = secret_kind(absolute(path, cwd))
    if kind:
        raise Refusal("secret read", f"`{path_word}` is {kind}, which can hold keys, so the agent does not read it.")


def redirect_targets(seg):
    return [seg[i + 1] for i, w in enumerate(seg[:-1]) if w == "<"]


def strings_in_code(code):
    found = re.findall(r"\"([^\"]*)\"|'([^']*)'", code)
    words = [a or b for a, b in found]
    words += re.findall(r"[\w~./-]+", code)
    return words


def secret_read(event):
    cwd = event.get("cwd") or os.getcwd()
    tool = event.get("tool_name")
    if tool == "Read":
        path = (event.get("tool_input") or {}).get("file_path") or ""
        if path:
            kind = secret_kind(absolute(os.path.expanduser(path), cwd))
            if kind:
                raise Refusal("secret read", f"`{path}` is {kind}, which can hold keys, so the agent does not read it.")
        return
    text = command_text(event)
    segs = segments(text)
    if segs is None:
        raise Refusal("cannot tell", "it cannot read the command's quoting. Write the command without unbalanced quotes.")
    every_word = [w for seg in segs for w in seg]
    for seg in segs:
        cmd, args = command_of(seg)
        for target in redirect_targets(seg):
            check_secret_path(target, cwd)
        if cmd in READERS:
            for target in read_targets(cmd, args):
                check_secret_path(target, cwd)
        elif cmd in INTERPRETERS:
            for i, a in enumerate(args):
                if a in ("-c", "-e", "--eval", "-p", "--print") and i + 1 < len(args):
                    for word in strings_in_code(args[i + 1]):
                        p = expand(word)
                        if p and secret_kind(absolute(p, cwd)):
                            raise Refusal("secret read", f"the code reads `{word}`, which can hold keys, so the agent does not run it.")
        elif cmd in ("xargs", "find"):
            # The reader gets its files from the input of xargs, or from the search of find through
            # `{}`, so the words of the command that names them stand in for those files.
            readers = [c for c in run_commands(cmd, args) if command_of(c)[0] in READERS]
            if cmd == "find":
                readers = [c for c in readers if any("{}" in w for w in c)]
            if not readers:
                continue
            for word in (every_word if cmd == "xargs" else seg):
                p = expand(word)
                if p and secret_kind(absolute(p, cwd)):
                    raise Refusal("secret read", f"the command passes `{word}` to a reader through {cmd}, and it can hold keys.")


# ---------------------------------------------------------------------------------------------
# secret-write

FILE_TOOLS = {"Write": "file_path", "Edit": "file_path", "MultiEdit": "file_path", "NotebookEdit": "notebook_path"}
WRITE_REDIRECTS = {">", ">>", ">|", "&>", "&>>", ">&"}
# Commands that write the files named by their arguments, and which arguments those are.
LAST_IS_TARGET = {"cp", "mv", "install", "ln", "rsync", "scp"}
SED_LIKE = {"sed", "perl"}


def plain_args(args):
    """The arguments of a simple command without its redirects and their targets."""
    out, i = [], 0
    while i < len(args):
        if args[i] in WRITE_REDIRECTS or args[i] in ("<", "<<", "<<<", "<&", "<>"):
            i += 2
            continue
        out.append(args[i])
        i += 1
    return out


def write_targets(seg):
    """The words a simple command writes as files. A word it cannot expand is left out, since an
    unknown write target is far more often a temporary file than a secret one."""
    targets = []
    for i, w in enumerate(seg[:-1]):
        if w in WRITE_REDIRECTS:
            nxt = seg[i + 1]
            # `2>&1` reads as `2`, `>&`, `1`, which points a stream at another stream, not at a file.
            if w == ">&" and (nxt.isdigit() or nxt == "-"):
                continue
            targets.append(nxt)
    cmd, args = command_of(seg)
    words = [a for a in plain_args(args) if not (a.startswith("-") and a != "-")]
    if cmd == "tee":
        targets.extend(words)
    elif cmd in LAST_IS_TARGET and len(words) >= 2:
        targets.append(words[-1])
    elif cmd in SED_LIKE and any(a == "-i" or a.startswith("-i") or a == "--in-place" or a.startswith("--in-place=")
                                 for a in args):
        targets.extend(words[1:] if not any(a in ("-e", "-f") for a in args) else words)
    elif cmd == "truncate":
        sized = plain_args(args)
        targets.extend(a for j, a in enumerate(sized)
                       if not a.startswith("-") and not (j > 0 and sized[j - 1] in ("-s", "--size", "-r", "--reference")))
    elif cmd == "dd":
        targets.extend(a[3:] for a in args if a.startswith("of="))
    return targets


def check_secret_write(word, cwd, how):
    path = expand(word)
    if path is None:
        return
    kind = secret_kind(absolute(path, cwd))
    if kind:
        raise Refusal("secret write", f"{how} `{word}`, which is {kind}. A secret file is not in git, so an "
                      "overwrite cannot be undone, and the agent does not write it. Edit it yourself if you mean to.")


def patch_text(tool_input):
    if isinstance(tool_input, str):
        return tool_input
    if isinstance(tool_input, dict):
        for key in ("patch", "input", "command"):
            value = tool_input.get(key)
            if isinstance(value, str):
                return value
            if isinstance(value, list):
                return "\n".join(part for part in value if isinstance(part, str))
    return ""


PATCH_FILE = re.compile(r"^\*\*\* (?:Add File|Update File|Delete File|Move to): (.+?)\s*$")


def secret_write(event):
    cwd = event.get("cwd") or os.getcwd()
    tool = event.get("tool_name")
    tool_input = event.get("tool_input")
    if tool in FILE_TOOLS:
        path = tool_input.get(FILE_TOOLS[tool]) if isinstance(tool_input, dict) else ""
        if isinstance(path, str) and path:
            check_secret_write(os.path.expanduser(path), cwd, f"{tool} would change")
        return
    if tool == "apply_patch":
        for line in patch_text(tool_input).splitlines():
            m = PATCH_FILE.match(line)
            if m:
                check_secret_write(m.group(1), cwd, "the patch would change")
        return
    segs = segments(command_text(event))
    if segs is None:
        return
    for seg in segs:
        for target in write_targets(seg):
            check_secret_write(target, cwd, "the command would write")


def patch_files(text):
    """The files a Codex patch adds or changes, each with the lines it adds. A moved file's lines
    belong to its new name; a deleted file adds nothing."""
    files, current = [], None
    for line in text.splitlines():
        m = PATCH_FILE.match(line)
        if m:
            if line.startswith("*** Delete File:"):
                current = None
                continue
            if line.startswith("*** Move to:") and files and current is files[-1]:
                files.pop()
            current = (m.group(1), [])
            files.append(current)
        elif current is not None and line.startswith("+"):
            current[1].append(line[1:])
    return [(path, added) for path, added in files]


# Commands that write through the file a name points at. `mv`, `ln`, `install`, `rsync`, `sed -i`, and
# `perl -i` replace the name with a new file instead, which leaves the other names untouched.
WRITES_THROUGH = {"tee", "cp", "scp", "truncate", "dd"}


def redirect_write_targets(seg):
    """The files the redirects of a simple command write. `2>&1` points a stream at another stream."""
    return [seg[i + 1] for i, w in enumerate(seg[:-1])
            if w in WRITE_REDIRECTS and not (w == ">&" and (seg[i + 1].isdigit() or seg[i + 1] == "-"))]


def write_through_targets(seg):
    cmd, _ = command_of(seg)
    if cmd in WRITES_THROUGH:
        return write_targets(seg)
    return redirect_write_targets(seg)


def second_name(word, cwd):
    """Whether the file a word names has another name (hard link). A file that does not exist, is not
    a regular file, or whose link count cannot be read has none."""
    path = expand(word)
    if path is None:
        return False
    try:
        st = os.stat(os.path.realpath(absolute(path, cwd)))
    except OSError:
        return False
    return stat.S_ISREG(st.st_mode) and st.st_nlink >= 2


def check_hard_link(word, cwd, how):
    if second_name(word, cwd):
        raise Refusal("hard link", f"{how} `{word}`, which has a second name (hard link). Its name does not show "
                      "what it holds, and a write through it also changes the file under its other name, which can "
                      f"be a key file. Copy it to a file of its own with `cp {word} <new file>` and write that, or "
                      "remove the other name first.")


def hard_links(event):
    cwd = event.get("cwd") or os.getcwd()
    tool = event.get("tool_name")
    tool_input = event.get("tool_input")
    if tool in FILE_TOOLS:
        path = tool_input.get(FILE_TOOLS[tool]) if isinstance(tool_input, dict) else ""
        if isinstance(path, str) and path:
            check_hard_link(os.path.expanduser(path), cwd, f"{tool} would change")
        return
    if tool == "apply_patch":
        for path, _ in patch_files(patch_text(tool_input)):
            check_hard_link(path, cwd, "the patch would change")
        return
    segs = segments(command_text(event))
    if segs is None:
        return
    for seg in segs:
        for target in write_through_targets(seg):
            check_hard_link(target, cwd, "the command would write")


# Shell startup files by name, in any folder. chezmoi keeps them under source names such as
# `private_dot_zshrc.tmpl`, which plain_name turns back into `.zshrc`.
STARTUP_NAMES = {".zshrc", ".zprofile", ".zshenv", ".zlogin", ".bashrc", ".bash_profile", ".bash_login", ".profile"}
CHEZMOI_PREFIXES = ("create_", "modify_", "encrypted_", "private_", "readonly_", "empty_", "executable_", "exact_",
                    "literal_")
KEY_VAR = r"[A-Za-z_][A-Za-z0-9_]*_(?:API_KEY|ACCESS_KEY|PRIVATE_KEY|KEY|TOKEN|SECRET|PASSWORD)"
# A value written as it is: quoted without `$`, backticks, or parentheses, or unquoted up to a space,
# `;`, or `#`. A value read at startup with `$(...)`, `${...}`, or `$VAR` does not match.
LITERAL = r"(\"[^\"$`()]*\"|'[^'$`()]*'|[^\"'$`()\s;#]+)"
SH_EXPORT = r"export\s+(?:-[a-z]+\s+)*(" + KEY_VAR + r")=" + LITERAL
FISH_EXPORT = r"set\s+(?:(?:-[A-Za-z]*x[A-Za-z]*|--export)\s+(?:-[A-Za-z]+\s+)*)(" + KEY_VAR + r")\s+" + LITERAL
# File text is read line by line from the start of each line; a shell command is searched anywhere,
# since the line sits inside `echo '...'` or `printf '...'`.
STARTUP_LINE = {"sh": re.compile(r"^\s*" + SH_EXPORT), "fish": re.compile(r"^\s*" + FISH_EXPORT)}
STARTUP_ANYWHERE = re.compile(r"(?:^|[\s;&|(\"'])(?:" + SH_EXPORT + r"|" + FISH_EXPORT + r")")
PLACEHOLDERS = {"", "undefined", "null", "none", "replace_me", "your_key_here", "xxx", "todo", "changeme"}


def plain_name(name):
    if name.endswith(".tmpl"):
        name = name[:-5]
    changed = True
    while changed:
        changed = False
        for prefix in CHEZMOI_PREFIXES:
            if name.startswith(prefix):
                name = name[len(prefix):]
                changed = True
    return "." + name[4:] if name.startswith("dot_") else name


def startup_kind(path):
    """`sh` for a zsh or bash startup file, `fish` for a fish config, or None."""
    parts = [plain_name(p) for p in path.replace("\\", "/").split("/") if p]
    if not parts:
        return None
    if parts[-1] in STARTUP_NAMES:
        return "sh"
    if parts[-1] == "config.fish" and len(parts) >= 2 and parts[-2] == "fish":
        return "fish"
    return None


def literal_key(match_groups):
    """The variable of a matched export whose value is written as it is and is not a placeholder."""
    pairs = [(match_groups[i], match_groups[i + 1]) for i in range(0, len(match_groups), 2)]
    for var, value in pairs:
        if var is None:
            continue
        if value.strip("\"'").strip().lower() in PLACEHOLDERS:
            continue
        return var
    return None


def key_in_startup_text(text, kind):
    """What makes the text hold a key: `a literal value in `VAR``, a key shape, or None."""
    for line in text.splitlines():
        m = STARTUP_LINE[kind].match(line)
        if m:
            var = literal_key(m.groups())
            if var:
                return f"a literal value in `{var}`"
        shape = key_in(line)
        if shape:
            return shape
    return None


def check_startup_text(word, text, how):
    kind = startup_kind(word)
    if kind is None or not text:
        return
    found = key_in_startup_text(text, kind)
    if found:
        startup_refusal(word, found, how)


def startup_refusal(word, found, how):
    raise Refusal("key in a startup file", f"{how} `{word}`, a shell startup file, with {found}. The value is not "
                  "shown. A key there sits in plain text in the file, its backups, and the environment of every "
                  "shell. Keep it in a secret store, such as the macOS keychain or 1Password, and read it at startup, "
                  "for example `export NAME=\"$(security find-generic-password -s NAME -w)\"`. The secure-dotfile "
                  "skill of agent-shuriken moves such values.")


def startup_keys(event):
    tool = event.get("tool_name")
    tool_input = event.get("tool_input") if isinstance(event.get("tool_input"), dict) else {}
    if tool in FILE_TOOLS:
        path = tool_input.get(FILE_TOOLS[tool]) or ""
        if not isinstance(path, str) or not path:
            return
        texts = [tool_input.get("content"), tool_input.get("new_string")]
        texts += [e.get("new_string") for e in tool_input.get("edits") or [] if isinstance(e, dict)]
        check_startup_text(path, "\n".join(t for t in texts if isinstance(t, str)), f"{tool} would write")
        return
    if tool == "apply_patch":
        for path, added in patch_files(patch_text(event.get("tool_input"))):
            check_startup_text(path, "\n".join(added), "the patch would write")
        return
    text = command_text(event)
    segs = segments(text)
    if segs is None:
        return
    for seg in segs:
        for target in write_targets(seg):
            path = expand(target)
            if path is None or startup_kind(path) is None:
                continue
            found = next((f"a literal value in `{var}`" for var in
                          (literal_key(m.groups()) for m in STARTUP_ANYWHERE.finditer(text)) if var), None)
            found = found or key_in(text)
            if found:
                startup_refusal(target, found, "the command would write")


# ---------------------------------------------------------------------------------------------
# onepassword

# `op` commands that print no value stored in 1Password and delete nothing. Every other `op`
# command is refused, since values come out through many subcommands and flags.
OP_SAFE = {("whoami",), ("account", "list"), ("vault", "list"), ("item", "list"), ("document", "list"),
           ("document", "create"), ("document", "edit"), ("help",)}
OP_GLOBAL_VALUE = {"--account", "--config", "--encoding", "--format", "--session"}
OP_INFO_FLAGS = {"--version", "-v", "--help", "-h"}
SUBSTITUTION = re.compile(r"\$\(([^()]*)\)|`([^`]*)`")


def op_subcommand(args):
    """The subcommand words of an `op` call, past its global options."""
    words, i = [], 0
    while i < len(args) and len(words) < 2:
        a = args[i]
        if a.startswith("-"):
            i += 2 if a in OP_GLOBAL_VALUE else 1
            continue
        words.append(a)
        i += 1
    return words


def op_allowed(args):
    sub = op_subcommand(args)
    if not sub:
        return all(a in OP_INFO_FLAGS or a.startswith("-") for a in args)
    if sub[0] == "help":
        return True
    return tuple(sub[:2]) in OP_SAFE or tuple(sub[:1]) in OP_SAFE


def onepassword(event):
    text = command_text(event)
    texts = [text] + [a or b for a, b in SUBSTITUTION.findall(text)]
    for t in texts:
        segs = segments(t)
        if segs is None:
            if re.search(r"(^|[\s;&|(`])op\s", t):
                raise Refusal("cannot tell", "it cannot read the command's quoting, and the command runs `op`. "
                              "Write the command without unbalanced quotes.")
            continue
        for seg in segs:
            cmd, args = command_of(seg)
            if cmd == "op" and not op_allowed(args):
                shown = " ".join(["op"] + op_subcommand(args))
                raise Refusal("1Password value", f"`{shown}` can print a value stored in 1Password into the "
                              "conversation. Only `op whoami`, `op account list`, `op vault list`, `op item list`, "
                              "`op document list`, `op document create`, `op document edit`, `op --version`, and "
                              "`op help` pass. Run it yourself in a terminal outside the agent, so the value does "
                              "not reach the conversation.")


# ---------------------------------------------------------------------------------------------
# outbound

# Key shapes with a fixed prefix, from the default rules of gitleaks (MIT), and two forms of a
# password in a header or a URL.
KEY_SHAPES = [
    ("a GitHub token", r"\b(?:ghp|gho|ghu|ghs|ghr)_[0-9A-Za-z]{36}\b"),
    ("a GitHub token", r"\bgithub_pat_\w{82}\b"),
    ("an npm token", r"\b(?i:npm_[a-z0-9]{36})\b"),
    ("an Anthropic API key", r"\bsk-ant-(?:api03|admin01)-[A-Za-z0-9_\-]{93}AA"),
    ("an AWS access key", r"\b(?:A3T[A-Z0-9]|AKIA|ASIA|ABIA|ACCA)[A-Z2-7]{16}\b"),
    ("a GitLab token", r"\bglpat-[\w\-]{20}"),
    ("a Google API key", r"\bAIza[\w\-]{35}"),
    ("a Slack token", r"\bxox[bpas]-[0-9]{10,13}-[0-9A-Za-z\-]+"),
    ("a Stripe key", r"\b(?:sk|rk)_(?:test|live|prod)_[A-Za-z0-9]{10,99}\b"),
    ("a PyPI token", r"\bpypi-AgEIcHlwaS5vcmc[\w\-]{50,1000}"),
    ("a Hugging Face token", r"\bhf_(?i:[a-z]{34})\b"),
    ("a DigitalOcean token", r"\bdop_v1_[a-f0-9]{64}\b"),
    ("a Shopify token", r"\bshpat_[a-fA-F0-9]{32}\b"),
    ("a Linear API key", r"\blin_api_(?i:[a-z0-9]{40})\b"),
    ("a Doppler token", r"\bdp\.pt\.(?i:[a-z0-9]{43})"),
    ("a SendGrid key", r"\bSG\.(?i:[a-z0-9=_\-\.]{66})"),
    ("an OpenAI API key", r"\bsk-(?:proj|svcacct|admin)-[A-Za-z0-9_\-]{58,74}T3BlbkFJ[A-Za-z0-9_\-]{58,74}"),
    ("a private key block", r"-----BEGIN (?:[A-Z]+ )?PRIVATE KEY-----"),
    ("a password in an Authorization header", r"(?i:authorization)\s*[:=]\s*(?i:bearer|basic|token)\s+[^\s'\"\\<>$*{}\[\]]{8,}"),
    ("a password in a URL", r"[A-Za-z][A-Za-z0-9+.\-]*://[^\s/:@'\"\\<>$*{}\[\]]+:[^\s/@'\"\\<>$*{}\[\]]{8,}@"),
]
KEY_PATTERNS = [(kind, re.compile(p)) for kind, p in KEY_SHAPES]


def key_in(line):
    for kind, pattern in KEY_PATTERNS:
        if pattern.search(line):
            return kind
    return None


def scan_text(text, where):
    for n, line in enumerate(text.splitlines(), 1):
        kind = key_in(line)
        if kind:
            raise Refusal("key in outbound text", f"{where} holds {kind} on line {n}. The value is not shown. "
                          "Remove it, or keep it in a secret store, before sending.")


BODY_FILE_HINT = ("it cannot read the text this command sends, so it cannot check it for keys. "
                  "Write the text to a file and pass it with `--body-file <path>`.")


def unreadable_value(value):
    if "$(" in value and "<<" not in value:
        return True
    if "`" in value or VAR.search(value):
        return True
    return False


def read_file_for_scan(word, cwd):
    if word == "-":
        raise Refusal("unreadable text", BODY_FILE_HINT)
    path = expand(word)
    if path is None:
        raise Refusal("unreadable text", BODY_FILE_HINT)
    try:
        with open(absolute(path, cwd), encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        raise Refusal("unreadable text", f"it cannot open `{word}` to check it for keys. Pass a file that exists.")


GH_SENDS = {("issue", "create"), ("issue", "comment"), ("issue", "edit"), ("issue", "close"),
            ("pr", "create"), ("pr", "comment"), ("pr", "edit"), ("pr", "review"), ("pr", "close"),
            ("release", "create"), ("release", "edit"), ("gist", "create")}


def scan_gh(args, cwd):
    sub = [a for a in args if not a.startswith("-")][:2]
    if not sub:
        return
    is_api = sub[0] == "api"
    if not is_api and tuple(sub) not in GH_SENDS:
        return
    i = 0
    while i < len(args):
        a = args[i]
        name, _, inline = a.partition("=")
        value = inline if inline else (args[i + 1] if i + 1 < len(args) else "")
        step = 1 if inline else 2
        if is_api and name in ("-f", "-F", "--field", "--raw-field"):
            field_value = value.partition("=")[2]
            if name in ("-F", "--field") and field_value.startswith("@"):
                scan_text(read_file_for_scan(field_value[1:], cwd), f"`{field_value[1:]}`")
            elif unreadable_value(field_value):
                raise Refusal("unreadable text", BODY_FILE_HINT)
            i += step
            continue
        if is_api and name == "--input":
            scan_text(read_file_for_scan(value, cwd), f"`{value}`")
            i += step
            continue
        if not is_api and name in ("--body-file", "-F", "--notes-file"):
            scan_text(read_file_for_scan(value, cwd), f"`{value}`")
            i += step
            continue
        if not is_api and name in ("--body", "-b", "--title", "-t", "--notes", "-n"):
            if value == "-" or unreadable_value(value):
                raise Refusal("unreadable text", BODY_FILE_HINT)
            i += step
            continue
        i += 1


def git_lines(cwd, *args):
    try:
        out = subprocess.run(["git", "-C", cwd, *args], capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.TimeoutExpired):
        raise Refusal("unreadable change", "it cannot read the change this commit records, so it cannot check it for keys.")
    if out.returncode != 0:
        raise Refusal("unreadable change", "it cannot read the change this commit records, so it cannot check it for keys.")
    return out.stdout


def scan_diff(diff):
    path, line = None, 0
    for raw in diff.splitlines():
        if raw.startswith("+++ "):
            path = raw[6:] if raw.startswith("+++ b/") else None
        elif raw.startswith("@@"):
            m = re.search(r"\+(\d+)", raw)
            line = int(m.group(1)) if m else 0
        elif raw.startswith("+") and path:
            kind = key_in(raw[1:])
            if kind:
                raise Refusal("key in a commit", f"the change to `{path}` holds {kind} on line {line}. The value is not shown. "
                              "Remove it from the file before committing.")
            line += 1


def git_root(cwd):
    out = subprocess.run(["git", "-C", cwd, "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    return out.stdout.strip() if out.returncode == 0 else None


def scan_commit(args, cwd, added_paths):
    i, every, paths = 0, False, []
    while i < len(args):
        a = args[i]
        name, _, inline = a.partition("=")
        if name in ("-m", "--message"):
            value = inline if inline else (args[i + 1] if i + 1 < len(args) else "")
            if unreadable_value(value):
                raise Refusal("unreadable text", BODY_FILE_HINT.replace("`--body-file <path>`", "`git commit -F <path>`"))
            i += 1 if inline else 2
            continue
        if name in ("-F", "--file"):
            value = inline if inline else (args[i + 1] if i + 1 < len(args) else "")
            scan_text(read_file_for_scan(value, cwd), f"`{value}`")
            i += 1 if inline else 2
            continue
        if a in ("-a", "--all") or (re.match(r"^-[a-zA-Z]+$", a) and "a" in a[1:] and "m" not in a[1:-1]):
            every = True
        if a == "--":
            paths.extend(args[i + 1:])
            break
        i += 1
    root = git_root(cwd)
    if root is None:
        return
    scan_diff(git_lines(cwd, "diff", "--cached", "--unified=0", "--no-color"))
    if every or paths:
        scan_diff(git_lines(cwd, "diff", "--unified=0", "--no-color", "--", *paths))
    for word in added_paths:
        p = expand(word)
        if p is None:
            raise Refusal("unreadable change", "it cannot tell which files `git add` stages, so it cannot check them for keys.")
        full = absolute(p, cwd)
        files = []
        if os.path.isdir(full):
            listing = git_lines(cwd, "ls-files", "--others", "--exclude-standard", "--", full)
            files = [os.path.join(root, f) for f in listing.splitlines() if f]
            scan_diff(git_lines(cwd, "diff", "--unified=0", "--no-color", "--", full))
        elif os.path.isfile(full):
            files = [full]
        for f in files:
            try:
                with open(f, encoding="utf-8", errors="replace") as fh:
                    scan_text(fh.read(), f"`{os.path.relpath(f, cwd)}`")
            except OSError:
                pass


def git_parts(args):
    """The git subcommand and its arguments, past git's own options, with a -C folder."""
    i, folder = 0, None
    while i < len(args):
        a = args[i]
        if a in ("-C", "-c", "--git-dir", "--work-tree", "--namespace"):
            if a == "-C" and i + 1 < len(args):
                folder = args[i + 1]
            i += 2
            continue
        if a.startswith("-"):
            i += 1
            continue
        return a, args[i + 1:], folder
    return "", [], folder


def outbound(event):
    cwd = event.get("cwd") or os.getcwd()
    text = command_text(event)
    segs = segments(text)
    if segs is None:
        if re.search(r"\b(gh|git)\b", text):
            raise Refusal("unreadable text", BODY_FILE_HINT)
        return
    sends = False
    added = []
    for seg in segs:
        cmd, args = command_of(seg)
        if cmd == "gh":
            sub = [a for a in args if not a.startswith("-")][:2]
            if sub and (sub[0] == "api" or tuple(sub) in GH_SENDS):
                sends = True
        if cmd == "git" and git_parts(args)[0] == "commit":
            sends = True
    if not sends:
        return
    # The command line itself goes out with the text, so a key anywhere in it is refused.
    kind = key_in(text)
    if kind:
        raise Refusal("key in outbound text", f"the command holds {kind}. The value is not shown. "
                      "Remove it, or keep it in a secret store, before sending.")
    for seg in segs:
        cmd, args = command_of(seg)
        if cmd == "gh":
            scan_gh(args, cwd)
        elif cmd == "git":
            sub, rest, folder = git_parts(args)
            here = cwd if folder is None else absolute(expand(folder) or folder, cwd)
            if sub == "add":
                added.extend(a for a in rest if not a.startswith("-"))
            elif sub == "commit":
                scan_commit(rest, here, added)


# ---------------------------------------------------------------------------------------------
# chain: transactions sent to a chain that is not on this machine

LOCAL_HOSTS = {"127.0.0.1", "localhost", "::1"}
LOCAL_SCHEMES = {"http", "https", "ws", "wss"}
CAST_SEND = {"send", "s", "publish", "p"}
CAST_RPC = {"rpc", "rp"}
RPC_SEND_METHODS = {"eth_sendRawTransaction", "eth_sendTransaction"}
CAST_ERC20 = {"erc20-token", "erc20"}
ERC20_WRITES = {"transfer", "t", "approve", "a", "mint", "m", "burn", "bu"}
TARGET_FLAGS = {"cast": {"--rpc-url", "-r"}, "forge": {"--rpc-url", "--fork-url", "-f"}}
# Package runners that start the hardhat of the project, with their own words before it.
JS_RUNNERS = {"npx": set(), "bunx": set(), "pnpx": set(), "pnpm": {"exec", "dlx"}, "yarn": {"exec", "dlx"},
              "bun": {"x", "run"}, "npm": {"exec", "x"}}
LOCAL_NETWORKS = {"hardhat", "localhost"}


def run_through_package_runner(cmd, args):
    """The command a package runner starts, as (name, args), or (cmd, args) for another command."""
    if cmd not in JS_RUNNERS:
        return cmd, args
    rest = list(args)
    while rest and (rest[0].startswith("-") or rest[0] in JS_RUNNERS[cmd]):
        rest = rest[1:]
        if rest and rest[0] == "--":
            rest = rest[1:]
            break
    return (os.path.basename(rest[0]), rest[1:]) if rest else (cmd, args)


def option_values(args, flags):
    """The values of the flags in `args`, with None for a flag at the end that has no value."""
    found = []
    for i, a in enumerate(args):
        if a in flags:
            found.append(args[i + 1] if i + 1 < len(args) else None)
            continue
        for flag in flags:
            if flag.startswith("--") and a.startswith(flag + "="):
                found.append(a[len(flag) + 1:])
    return found


def is_local_url(url):
    try:
        parts = urlsplit(url)
        host = parts.hostname
        parts.port
    except ValueError:
        return False
    return (parts.scheme in LOCAL_SCHEMES and parts.username is None and parts.password is None
            and "@" not in parts.netloc and host in LOCAL_HOSTS)


def target_text(url):
    """How a refusal names a target: its host, never its path, which can hold an API key."""
    if url is None or url == "":
        return "a target it cannot read (no --rpc-url)"
    if "$" in url or "`" in url:
        return "a target held in a variable"
    if "://" not in url:
        return f"`{url}`, a name it cannot read (an alias from foundry.toml)"
    try:
        host = urlsplit(url).hostname
    except ValueError:
        host = None
    return f"the host `{host}`" if host else "a target it cannot read"


def chain_send(seg):
    """What a simple command sends to a chain that is not local, or None."""
    cmd, args = command_of(seg)
    cmd, args = run_through_package_runner(cmd, args)
    words = [a for a in args if not a.startswith("-")]
    if cmd == "hardhat":
        if words[:2] != ["ignition", "deploy"]:
            return None
        networks = option_values(args, {"--network"})
        assigned = [w.split("=", 1)[1] for w in seg if w.startswith("HARDHAT_NETWORK=")]
        for network in networks + assigned:
            if network not in LOCAL_NETWORKS:
                return "`hardhat ignition deploy`", "the network " + (f"`{network}`" if network else "it cannot read")
        return None
    if cmd == "cast" and words:
        sends = (words[0] in CAST_SEND or (words[0] in CAST_RPC and len(words) > 1 and words[1] in RPC_SEND_METHODS)
                 or (words[0] in CAST_ERC20 and len(words) > 1 and words[1] in ERC20_WRITES))
    elif cmd == "forge" and words:
        sends = words[0] == "create" or (words[0] == "script" and any(
            a == "--broadcast" or a.startswith("--broadcast=") for a in args))
    else:
        return None
    if not sends:
        return None
    shown = f"`{cmd} {words[0]}`"
    if cmd == "cast" and "--flashbots" in args:
        return shown, "Flashbots"
    targets = option_values(args, TARGET_FLAGS[cmd])
    targets += [w.split("=", 1)[1] for w in seg if w.startswith("ETH_RPC_URL=")]
    if not targets:
        return shown, target_text(None)
    for url in targets:
        if not url or not is_local_url(url):
            return shown, target_text(url)
    return None


def chain_sends(event):
    text = command_text(event)
    segs = segments(text)
    if segs is None:
        if re.search(r"\b(cast|forge|hardhat)\b", text):
            raise Refusal("chain send", "it cannot read the command's quoting, and the command can send a chain "
                          "transaction. Write the command without unbalanced quotes." + run_it_yourself(text))
        return
    for seg in segs:
        found = chain_send(seg)
        if found:
            shown, where = found
            raise Refusal("chain send", f"{shown} sends a signed transaction to {where}, and a sent transaction "
                          "cannot be taken back. Only a target on this machine (`127.0.0.1`, `localhost`, or `::1`) "
                          "passes." + run_it_yourself(text))


# ---------------------------------------------------------------------------------------------
# other repositories: sends to repositories of owners not in the own-owners list

GH_EDIT_TEXT = {"-t", "--title", "-b", "--body", "-F", "--body-file", "--attach"}
GH_REPO_FLAGS = {"-R", "--repo"}
GH_FIELD_FLAGS = {"-f", "-F", "--field", "--raw-field"}
GH_URL = re.compile(r"^https?://(?:www\.)?github\.com/([^/\s]+)/([^/\s]+)/(?:issues|pull)/")
API_REPO = re.compile(r"^/?repos/([^/]+)/([^/]+)")
WRITE_METHODS = {"POST", "PATCH", "PUT", "DELETE"}


def flag_present(args, flags):
    return any(a in flags or a.split("=", 1)[0] in flags for a in args)


def owner_of_repo(word):
    """The owner in `owner/name`, `host/owner/name`, or a GitHub URL, or None."""
    if "://" in word:
        try:
            path = urlsplit(word).path
        except ValueError:
            return None
        parts = [p for p in path.split("/") if p]
        return parts[0] if parts else None
    parts = [p for p in word.split("/") if p]
    if len(parts) == 3:
        return parts[1]
    return parts[0] if len(parts) == 2 else None


def owner_of_remote_url(url):
    """The owner a git remote URL names, or None for a local path."""
    if "://" in url:
        return owner_of_repo(url)
    m = re.match(r"^[^@/\s]+@[^:/\s]+:/?([^/\s]+)/", url)
    return m.group(1) if m else None


def git_out(folder, *args):
    try:
        out = subprocess.run(["git", "-C", folder, *args], capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return out.stdout.strip() if out.returncode == 0 else None


def remote_owners(folder):
    """The owner each remote of the clone at a folder names, and the remote gh was told to use."""
    listing = git_out(folder, "config", "--get-regexp", r"^remote\..*\.(url|gh-resolved)$") or ""
    owners, resolved = {}, None
    for line in listing.splitlines():
        key, _, value = line.partition(" ")
        name = key[len("remote."):].rsplit(".", 1)[0]
        if key.endswith(".url"):
            owners[name] = owner_of_remote_url(value)
        elif value == "base":
            resolved = name
    return owners, resolved


def gh_api_send(args):
    """For `gh api`, ("graphql", query) or ("rest", endpoint) when it writes, or None for a read."""
    words, i, method, fields, query = [], 0, None, False, None
    while i < len(args):
        a = args[i]
        name, eq, inline = a.partition("=")
        value = inline if eq else (args[i + 1] if i + 1 < len(args) else "")
        if name in ("-X", "--method"):
            method = value.upper()
            i += 1 if eq else 2
            continue
        if name in GH_FIELD_FLAGS or name == "--input":
            fields = True
            if name in GH_FIELD_FLAGS and value.startswith("query="):
                query = value[len("query="):]
            i += 1 if eq else 2
            continue
        if name in ("-H", "--header", "-q", "--jq", "-t", "--template", "--hostname", "--cache", "-p", "--preview"):
            i += 1 if eq else 2
            continue
        if not a.startswith("-"):
            words.append(a)
        i += 1
    endpoint = words[1] if len(words) > 1 else ""
    if endpoint == "graphql":
        return ("graphql", query)
    if (method or ("POST" if fields else "GET")) in WRITE_METHODS:
        return ("rest", endpoint)
    return None


def graphql_writes(query, cwd):
    """Whether a GraphQL query writes, or None when it cannot be read."""
    if query is None:
        return None
    if query.startswith("@"):
        path = expand(query[1:])
        if path is None:
            return None
        try:
            with open(absolute(path, cwd), encoding="utf-8", errors="replace") as f:
                query = f.read()
        except OSError:
            return None
    if "$" in query or "`" in query:
        return None
    body = re.sub(r"#[^\n]*", "", query).strip()
    return body.startswith("mutation")


def gh_send(seg, cwd):
    """What a `gh` command sends and where: ("owner", word, owner), ("unreadable", why), ("implicit", what),
    or None when it sends nothing to a repository."""
    _, args = command_of(seg)
    words = [a for a in args if not a.startswith("-")]
    sub = tuple(words[:2])
    if sub[:1] == ("api",):
        found = gh_api_send(args)
        if found is None:
            return None
        if found[0] == "graphql":
            writes = graphql_writes(found[1], cwd)
            if writes is None:
                return ("unreadable", "a GraphQL query it cannot read, which can change any repository")
            return ("unreadable", "a GraphQL mutation, which names its target by an ID") if writes else None
        endpoint = found[1]
        if "$" in endpoint or "`" in endpoint:
            return ("unreadable", "an endpoint held in a variable")
        m = API_REPO.match(endpoint)
        if not m:
            return None
        if m.group(1) in ("{owner}", ":owner"):
            return ("implicit", f"`gh api {endpoint}`")
        return ("owner", f"`{m.group(1)}/{m.group(2)}`", m.group(1))
    if len(sub) < 2 or sub[0] not in ("issue", "pr"):
        return None
    verb = sub[1]
    sends = (verb in ("create", "comment") and "--delete-last" not in args) or (sub == ("pr", "review")) \
        or (verb == "edit" and flag_present(args, GH_EDIT_TEXT)) or (verb == "close" and flag_present(args, {"-c", "--comment"}))
    if not sends:
        return None
    repos = option_values(args, GH_REPO_FLAGS) + [a[2:] for a in args if a.startswith("-R") and len(a) > 2]
    repos += [w.split("=", 1)[1] for w in seg if w.startswith("GH_REPO=")]
    for word in words[2:]:
        m = GH_URL.match(word)
        if m:
            return ("owner", f"`{m.group(1)}/{m.group(2)}`", m.group(1))
    if not repos and os.environ.get("GH_REPO"):
        repos = [os.environ["GH_REPO"]]
    for repo in repos:
        if not repo or "$" in repo or "`" in repo:
            return ("unreadable", "a repository held in a variable")
        owner = owner_of_repo(repo)
        if owner is None:
            return ("unreadable", f"`{repo}`, which is not in the form owner/name")
        return ("owner", f"`{repo}`", owner)
    return ("implicit", f"`gh {' '.join(sub)}`")


def push_owner(args, cwd):
    """For `git push`, ("owner", where, owner), ("unreadable", why), or None for a push that names no
    GitHub owner."""
    sub, rest, folder = git_parts(args)
    if sub != "push":
        return None
    here = cwd if folder is None else absolute(expand(folder) or folder, cwd)
    if folder is not None and expand(folder) is None:
        return ("unreadable", "a clone held in a variable")
    positional, i, remote = [], 0, None
    while i < len(rest):
        a = rest[i]
        if a in ("-o", "--push-option", "--receive-pack", "--exec"):
            i += 2
            continue
        if a in ("--repo",) or a.startswith("--repo="):
            remote = a.split("=", 1)[1] if "=" in a else (rest[i + 1] if i + 1 < len(rest) else "")
            i += 1 if "=" in a else 2
            continue
        if not a.startswith("-"):
            positional.append(a)
        i += 1
    remote = remote or (positional[0] if positional else None)
    if remote is None:
        branch = git_out(here, "symbolic-ref", "--short", "-q", "HEAD") or ""
        for key in (f"branch.{branch}.pushRemote", "remote.pushDefault", f"branch.{branch}.remote"):
            remote = git_out(here, "config", "--get", key) if branch or key == "remote.pushDefault" else None
            if remote:
                break
        remote = remote or "origin"
    if "$" in remote or "`" in remote:
        return ("unreadable", "a remote held in a variable")
    if "://" in remote or re.match(r"^[^@/\s]+@[^:/\s]+:", remote):
        url = remote
    else:
        url = git_out(here, "remote", "get-url", "--push", remote)
        if url is None:
            return None
    owner = owner_of_remote_url(url)
    return ("owner", f"the remote `{remote}`", owner) if owner else None


def other_repos(event):
    owners = {o.lower() for o in list_entries("own-owners")}
    if not owners:
        return
    cwd = event.get("cwd") or os.getcwd()
    text = command_text(event)
    segs = segments(text)
    if segs is None:
        if re.search(r"\b(gh|git)\b", text):
            raise Refusal("other owner", "it cannot read the command's quoting, so it cannot tell where the command "
                          "sends. Write the command without unbalanced quotes." + run_it_yourself(text))
        return
    for seg in segs:
        cmd, args = command_of(seg)
        if cmd == "gh":
            found = gh_send(seg, cwd)
        elif cmd == "git":
            found = push_owner(args, cwd)
        else:
            continue
        if found is None:
            continue
        if found[0] == "unreadable":
            raise Refusal("other owner", f"the command sends to {found[1]}, so it cannot tell whose repository it "
                          "changes. Name the repository as owner/name." + run_it_yourself(text))
        if found[0] == "implicit":
            remotes, resolved = remote_owners(cwd)
            named = [remotes[resolved]] if resolved in remotes else list(remotes.values())
            outside = sorted({o for o in named if o and o.lower() not in owners})
            if outside:
                raise Refusal("other owner", f"{found[1]} names no repository, and this clone's remotes name "
                              f"`{outside[0]}`, which is not in your own-owners list, so gh can send there. Name the "
                              "repository with `-R owner/name`." + run_it_yourself(text))
            continue
        _, where, owner = found
        if owner.lower() not in owners:
            raise Refusal("other owner", f"the command sends to {where}, a repository of `{owner}`, which is not in "
                          "your own-owners list. What is sent there is public at once and cannot be taken back."
                          + run_it_yourself(text))


# ---------------------------------------------------------------------------------------------
# git

def run_it_yourself(text):
    one_line = " ".join(text.split())
    return f" If you mean it, run it yourself in this conversation: ! {one_line}"


def short_flags(args):
    return "".join(a[1:] for a in args if re.match(r"^-[A-Za-z]+$", a))


def git_danger(sub, rest):
    flags = short_flags(rest)
    if "--no-verify" in rest or any(a.startswith("--no-verify=") for a in rest) or (sub == "commit" and "n" in flags):
        return "skips the repository's checks with --no-verify"
    if sub == "push":
        if any(a in ("--force", "--force-with-lease", "--force-if-includes") or a.startswith("--force-with-lease=") for a in rest) \
                or "f" in flags or any(a.startswith("+") for a in rest):
            return "overwrites the remote branch's history with a force push"
    if sub == "reset" and "--hard" in rest:
        return "throws away uncommitted work with reset --hard"
    if sub == "clean" and ("--force" in rest or "f" in flags) and not ("--dry-run" in rest or "n" in flags):
        return "deletes untracked files with clean -f"
    if sub in ("checkout", "switch"):
        if "--" in rest or "." in rest or "--force" in rest or "--discard-changes" in rest or "f" in flags:
            return "throws away uncommitted changes"
    if sub == "restore":
        staged_only = "--staged" in rest or "S" in flags
        worktree = "--worktree" in rest or "W" in flags
        if not staged_only or worktree:
            return "throws away uncommitted changes with restore"
    return None


def git_hook(event):
    text = command_text(event)
    segs = segments(text)
    if segs is None:
        return
    for seg in segs:
        cmd, args = command_of(seg)
        if cmd != "git":
            continue
        sub, rest, _ = git_parts(args)
        why = git_danger(sub, rest)
        if why:
            raise Refusal(f"git {sub}", f"the command {why}." + run_it_yourself(text))


# ---------------------------------------------------------------------------------------------
# delete

SYSTEM_TOP = {"bin", "boot", "dev", "etc", "lib", "opt", "private", "sbin", "System", "usr", "var",
              "Applications", "Library", "Users", "home", "Volumes"}


def broad(word, cwd):
    if word in (".", "..", "./", "../", "*", ".*", "./*", "/*", "~/*", "$HOME/*", "${HOME}/*"):
        return True
    path = expand(word)
    if path is None:
        return False
    path = os.path.normpath(path)
    if path in ("/", home(), os.path.normpath(cwd)) and os.path.isabs(path):
        return True
    parts = [p for p in path.split("/") if p]
    return os.path.isabs(path) and len(parts) == 1 and parts[0] in SYSTEM_TOP


def protected(word, cwd):
    path = expand(word)
    return path is not None and listed(absolute(path, cwd), "protected-paths")


def delete_targets(cmd, args):
    if cmd in ("rm", "mv", "rmdir", "unlink", "trash"):
        targets = [a for a in args if not a.startswith("-") or a == "-"]
        if cmd == "mv" and targets:
            targets = targets[:-1]
        return targets
    return []


CHMOD_OPTION = re.compile(r"^(-[RfvhHLPc]+|--[a-z-]+(=.*)?)$")


def target_directory(args):
    """The folder given with `-t <folder>`, `--target-directory <folder>`, or `--target-directory=<folder>`."""
    for i, a in enumerate(args):
        if a in ("-t", "--target-directory") and i + 1 < len(args):
            return args[i + 1]
        if a.startswith("--target-directory="):
            return a.split("=", 1)[1]
    return None


def overwrite_targets(seg):
    """The places a simple command writes over: its redirects and the files `write_targets` names, or the
    folder a copy names with `-t`, whose last word is then a source."""
    cmd, args = command_of(seg)
    folder = target_directory(args) if cmd in LAST_IS_TARGET else None
    if folder is None:
        return write_targets(seg)
    return redirect_write_targets(seg) + [folder]


def git_rm_targets(args, cwd):
    """The folder `git rm` paths are relative to, and the paths it removes."""
    sub, rest, folder = git_parts(args)
    base = cwd
    if folder is not None:
        path = expand(folder)
        base = absolute(path, cwd) if path else cwd
    if sub != "rm":
        return base, []
    paths, past_options = [], False
    for a in rest:
        if not past_options and a == "--":
            past_options = True
        elif past_options or not a.startswith("-"):
            paths.append(a)
    return base, paths


def delete_hook(event):
    cwd = event.get("cwd") or os.getcwd()
    text = command_text(event)
    segs = segments(text)
    if segs is None:
        return
    for seg in segs:
        cmd, args = command_of(seg)
        recursive = cmd == "rm" and ("--recursive" in args or re.search(r"[rR]", short_flags(args) or ""))
        for target in delete_targets(cmd, args):
            if protected(target, cwd):
                raise Refusal("protected path", f"`{target}` is in your protected-paths list." + run_it_yourself(text))
            if (recursive or cmd == "mv") and broad(target, cwd):
                raise Refusal("broad delete", f"`{target}` would remove a whole folder tree such as the root, "
                              "the home folder, or the current folder." + run_it_yourself(text))
        # Copying, linking, or writing over a file replaces what a protected place holds as surely as
        # deleting it, so the places a command writes are held to the same list.
        for target in overwrite_targets(seg):
            if protected(target, cwd):
                raise Refusal("protected path", f"`{target}` is in your protected-paths list, and the command "
                              "would write over it." + run_it_yourself(text))
        if cmd == "git":
            base, paths = git_rm_targets(args, cwd)
            for target in paths:
                if protected(target, base):
                    raise Refusal("protected path", f"`git rm` would remove `{target}`, which is in your "
                                  "protected-paths list." + run_it_yourself(text))
        if cmd in ("chmod", "chown", "chgrp") and ("--recursive" in args or "R" in short_flags(args)):
            # The first word is the mode or the owner; the rest are the places it changes. A mode can
            # start with `-`, as in `-w`, so only the options of these commands are skipped.
            for target in [a for a in plain_args(args) if not CHMOD_OPTION.match(a)][1:]:
                if protected(target, cwd) or broad(target, cwd):
                    raise Refusal("broad chmod", f"`{cmd} -R` on `{target}` would change the permissions of a whole "
                                  "folder tree such as the root or the home folder, which can lock you out of it like "
                                  "a delete." + run_it_yourself(text))
        if cmd == "find" and ("-delete" in args or ("-exec" in args and "rm" in args)):
            starts = []
            for a in args:
                if a.startswith("-") or a in ("(", "!"):
                    break
                starts.append(a)
            starts = starts or ["."]
            filtered = any(a in ("-name", "-iname", "-path", "-ipath", "-regex", "-iregex") for a in args)
            for s in starts:
                if protected(s, cwd):
                    raise Refusal("protected path", f"`{s}` is in your protected-paths list." + run_it_yourself(text))
                if broad(s, cwd) and not (filtered and s in (".", "./")):
                    raise Refusal("broad delete", f"`find {s}` with -delete would remove a whole folder tree." + run_it_yourself(text))


# ---------------------------------------------------------------------------------------------
# system: commands that change the whole machine

SYSTEM_COMMANDS = {
    "mount": "changes what is mounted on the machine",
    "umount": "changes what is mounted on the machine",
    "chroot": "runs a command inside another root folder",
    "pfctl": "changes the packet filter, the firewall of the machine",
    "mkfs": "formats a disk, which erases what it holds",
}
ADMIN_SCRIPT = re.compile(r"do\s+shell\s+script.*with\s+administrator\s+privileges", re.IGNORECASE | re.DOTALL)


def system_commands(event):
    text = command_text(event)
    segs = segments(text)
    if segs is None:
        return
    for seg in segs:
        cmd, args = command_of(seg)
        name = "mkfs" if cmd == "mkfs" or cmd.startswith("mkfs.") else cmd
        if name in SYSTEM_COMMANDS:
            why = f"`{cmd}` {SYSTEM_COMMANDS[name]}"
        elif cmd == "osascript" and ADMIN_SCRIPT.search(" ".join(args)):
            why = "`osascript` runs a shell script with administrator privileges, like sudo"
        else:
            continue
        raise Refusal("system command", f"{why}. A change to the whole machine is hard to undo, so the agent does "
                      "not run it." + run_it_yourself(text))


HOOKS = {"secret-read": secret_read, "secret-write": secret_write, "onepassword": onepassword,
         "outbound": outbound, "git": git_hook, "delete": delete_hook}

# Every check each hook runs, in order, with the variable that turns it off. The checks after the
# first run in the same process, so they start no process of their own.
CHECKS = {hook: [(OFF_VARS[hook], run)] for hook, run in HOOKS.items()}
CHECKS["secret-write"] += [("AGENT_GUARDS_HARD_LINKS", hard_links), ("AGENT_GUARDS_STARTUP_KEYS", startup_keys)]
CHECKS["outbound"] += [("AGENT_GUARDS_CHAIN", chain_sends), ("AGENT_GUARDS_OTHER_REPOS", other_repos)]
CHECKS["delete"] += [("AGENT_GUARDS_SYSTEM", system_commands)]


def judged(hook, event):
    """Whether the hook judges this event: shell commands, plus the Read tool for secret-read and the
    file tools and Codex's apply_patch for secret-write."""
    tool = event.get("tool_name")
    tool_input = event.get("tool_input")
    if tool == "apply_patch":
        return hook == "secret-write"
    if tool in FILE_TOOLS:
        return hook == "secret-write"
    if tool == "Read":
        return hook == "secret-read"
    return tool == "Bash" or (isinstance(tool_input, dict) and "command" in tool_input)


def main():
    hook = sys.argv[1] if len(sys.argv) > 1 else ""
    if hook not in HOOKS:
        print(f"usage: agent_guards.py {' | '.join(HOOKS)}", file=sys.stderr)
        return 2
    checks = [(var, run) for var, run in CHECKS[hook] if os.environ.get(var, "").lower() != "off"]
    if not checks:
        return 0
    try:
        event = json.load(sys.stdin)
    except ValueError:
        deny(hook, "it could not read the event Claude Code or Codex sent, so it refuses the call.")
        record(hook, "unreadable event")
        return 0
    if not isinstance(event, dict) or not judged(hook, event):
        return 0
    for var, run in checks:
        try:
            run(event)
        except Refusal as r:
            deny(hook, r.reason)
            record(hook, r.kind)
            return 0
        except Exception as e:  # A bug must not let the call through unseen.
            deny(hook, f"it failed while judging the call ({type(e).__name__}). Turn this check off with "
                 f"{var}=off if it keeps failing, and report it.")
            record(hook, "internal error")
            return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
