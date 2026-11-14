#!/usr/bin/env python3
"""Find secrets written into shell startup files and files that tools read on their own, and move the ones you pick into the Keychain, the secret service, pass, or 1Password.

Usage:

  secure_dotfile.py scan [--file PATH]... [--store STORE] [--json]
  secure_dotfile.py move --item PATH:LINE:NAME [--item ...] [--store STORE] [--dry-run] [--json]

`scan` reads the zsh, bash, and fish startup files, `.envrc`, direnv `env.d` files, the files
they source, and every PATH given with `--file`. It lists each `export NAME=value` (or fish
`set -x NAME value`) whose value is written as a literal and looks like a secret: the name ends
in a word such as `_TOKEN`, `_API_KEY`, or `_PASSWORD`, or the value has the shape of a known
key (GitHub, OpenAI, Anthropic, Slack, AWS, and others). Values shorter than 8 characters are
listed only under a password name, such as `PGPASSWORD` or `MYSQL_PWD`, as a `short password`.
It also reads files that tools read on their own: `_authToken` lines in `~/.npmrc`, the secret
keys of the profiles in `~/.aws/credentials`, `password` entries in `~/.netrc`, and the
assignments in the `.env` and `.env.*` files of the current folder.

`move` stores each picked value, reads it back, and replaces the literal with a command that
reads the value when the shell starts. On macOS the value goes into the Keychain through the
`security` command. On Linux it goes into the secret service (GNOME Keyring, KWallet, or
KeePassXC with its secret service turned on) through `secret-tool` from libsecret. With
`--store pass` it goes into the password store of `pass`, encrypted with the user's GPG key, on
any system. With `--store 1password` it goes into 1Password through the 1Password CLI `op`, as a
Login item in the vault `op` stores new items in (Private, Personal, or Employee). It runs the
shell's syntax check on the edited file and restores the file when the check fails.
An npm token becomes `${NAME}`, which npm fills in from the environment, and an export line that
reads the store is added to the startup file of the shell in `$SHELL`. An AWS profile's two keys
become one `credential_process` line that prints them from the store. `~/.netrc` and `.env`
files are never edited.

No part of a value is ever printed: the output names the variable, the file and line, the kind,
and the length. The values stay inside this process and are handed to `security`,
`secret-tool`, `pass`, or `op` on its standard input, never on its command line.

`--store` picks the store: `keychain`, `secret-service`, `pass`, or `1password`. Only a scan or
move that picks `1password` runs `op`, which may ask the 1Password app for approval. Without it the store is
`SECURE_DOTFILE_STORE` when set, or else the Keychain on macOS and the secret service on Linux.
`scan` names the stores that can be used here. `SECURE_DOTFILE_STORE` and
`SECURE_DOTFILE_KEYCHAIN`, which names a keychain file to use instead of the default keychain,
are meant for tests against a throwaway store. `pass` reads `PASSWORD_STORE_DIR` as it always
does.

Exit codes: 0 done, 2 bad arguments, 3 moving is not supported on this system or the store's
command is missing.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

HOME = os.path.expanduser("~")
ACCOUNT = os.environ.get("USER") or os.path.basename(HOME)
KEYCHAIN = os.environ.get("SECURE_DOTFILE_KEYCHAIN", "")
STORE = os.environ.get("SECURE_DOTFILE_STORE") or (
    "keychain" if sys.platform == "darwin" else "secret-service" if sys.platform.startswith("linux") else "")
WHERE = {"keychain": "the keychain", "secret-service": "the secret service", "pass": "pass", "1password": "1Password"}
PASS_DIR = os.environ.get("PASSWORD_STORE_DIR") or os.path.join(HOME, ".password-store")
# `op item create` without `--vault` stores the item in one of these, depending on the account type.
OP_DEFAULT_VAULTS = ("Private", "Personal", "Employee")
TIMEOUT = 120
MIN_LENGTH = 8
MAX_INCLUDE_DEPTH = 5
HISTORY_LIMIT = 64 * 1024 * 1024

# A name ending in one of these words marks the value as a secret. PASSWORD and PASSWD count
# without an underscore too, as in PGPASSWORD, which the PostgreSQL clients read.
NAME_RE = re.compile(r"(?:^|_)(API_KEY|ACCESS_KEY|SECRET_KEY|PRIVATE_KEY|KEY|TOKEN|SECRET|PASSWORD|PASSWD|PASS|PWD|PIN|PAT)$"
                     r"|(PASSWORD|PASSWD)$")
NAME_KIND = {
    "API_KEY": "API key", "ACCESS_KEY": "access key", "SECRET_KEY": "secret key",
    "PRIVATE_KEY": "private key", "KEY": "key", "TOKEN": "token", "SECRET": "secret",
    "PASSWORD": "password", "PASSWD": "password", "PASS": "password", "PWD": "password", "PIN": "PIN",
    "PAT": "personal access token",
}
# Values under these names are listed at any length, since a short password is still a password.
# Shorter than MIN_LENGTH, their kind is "short password".
PASSWORD_WORDS = {"PASSWORD", "PASSWD", "PASS", "PWD", "PIN"}

# Values with these shapes are secrets whatever the variable is called.
VALUE_KINDS = [
    (r"sk-ant-[A-Za-z0-9_-]{20,}", "Anthropic API key"),
    (r"sk-(?:proj|svcacct|admin)-[A-Za-z0-9_-]{20,}", "OpenAI API key"),
    (r"sk-[A-Za-z0-9]{32,}", "OpenAI-style API key"),
    (r"github_pat_[A-Za-z0-9_]{50,}", "GitHub fine-grained token"),
    (r"gh[pousr]_[A-Za-z0-9]{36,}", "GitHub token"),
    (r"glpat-[A-Za-z0-9_-]{20,}", "GitLab token"),
    (r"xox[abposr]-[A-Za-z0-9-]{10,}", "Slack token"),
    (r"(?:AKIA|ASIA)[A-Z0-9]{16}", "AWS access key ID"),
    (r"AIza[A-Za-z0-9_-]{35}", "Google API key"),
    (r"npm_[A-Za-z0-9]{36}", "npm token"),
    (r"hf_[A-Za-z0-9]{30,}", "Hugging Face token"),
    (r"(?:sk|rk)_(?:live|test)_[A-Za-z0-9]{20,}", "Stripe key"),
    (r"SG\.[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{16,}", "SendGrid key"),
    (r"dop_v1_[a-f0-9]{64}", "DigitalOcean token"),
    (r"xai-[A-Za-z0-9]{40,}", "xAI API key"),
    (r"gsk_[A-Za-z0-9]{40,}", "Groq API key"),
    (r"pplx-[A-Za-z0-9]{40,}", "Perplexity API key"),
]
VALUE_KINDS = [(re.compile(p), k) for p, k in VALUE_KINDS]

PLACEHOLDERS = {
    "undefined", "null", "none", "nil", "changeme", "change_me", "replace_me", "replaceme",
    "your_key_here", "your_api_key", "your_token", "your_token_here", "todo", "example",
    "dummy", "placeholder", "secret", "password",
}

# `export NAME=value`: no space around `=`, since `export NAME= value` sets NAME to empty.
BASH_RE = re.compile(r"^(?P<pre>[ \t]*export[ \t]+(?P<name>[A-Za-z_][A-Za-z0-9_]*)=)(?P<val>.*)$")
FISH_RE = re.compile(r"^(?P<pre>[ \t]*set[ \t]+(?:-gx|-xg|-x)[ \t]+(?P<name>[A-Za-z_][A-Za-z0-9_]*)[ \t]+)(?P<val>.*)$")
UNQUOTED_RE = re.compile(r"[^\s'\"$`;#&|<>()]+")
SOURCE_RE = re.compile(r"(?:^|[\s;&|])(?:source|\.)[ \t]+(\"[^\"]+\"|'[^']+'|[^\s;#&|]+)")

# Files that tools read on their own.
# `//registry.npmjs.org/:_authToken=VALUE` in ~/.npmrc. npm replaces `${NAME}` there with the
# environment variable when it reads the file.
NPMRC_RE = re.compile(r"^(?P<pre>[ \t]*(?:(?P<scope>//[^\s=]+?):)?_authToken[ \t]*=[ \t]*)(?P<val>\S+)[ \t]*$")
NPM_VALUE_RE = re.compile(r"[A-Za-z0-9._~+/=-]+")
# ~/.aws/credentials: `[profile]` sections of `key = value` lines.
INI_SECTION_RE = re.compile(r"^[ \t]*\[(?P<name>[^\]]+)\][ \t]*$")
AWS_LINE_RE = re.compile(r"^[ \t]*(?P<key>aws_access_key_id|aws_secret_access_key|aws_session_token|credential_process)"
                         r"[ \t]*=[ \t]*(?P<val>.*?)[ \t]*$")
AWS_ID_RE = re.compile(r"[A-Z0-9]{16,128}")
AWS_SECRET_RE = re.compile(r"[A-Za-z0-9/+=]{16,}")
# What `credential_process` runs: the AWS CLI splits it like a shell and runs it without one, so
# `sh -c` does the reading. It prints the JSON the AWS CLI expects, and exits non-zero when the
# store cannot be read, so the AWS CLI reports the failure instead of using empty keys.
CREDENTIAL_PROCESS = (r"""sh -c 'a=$(%s) && s=$(%s) && printf "{\"Version\": 1, \"AccessKeyId\": \"%%s\", """
                      r"""\"SecretAccessKey\": \"%%s\"}" "$a" "$s"'""")
# `NAME=value` in a .env file, with or without `export`.
ENV_RE = re.compile(r"^[ \t]*(?:export[ \t]+)?(?P<name>[A-Za-z_][A-Za-z0-9_]*)[ \t]*=[ \t]*(?P<val>.*?)[ \t]*$")
NETRC_REASON = ("curl and git read ~/.netrc as written and cannot read a value from elsewhere; for git, "
                "a credential helper such as osxkeychain or libsecret can keep it instead, then remove the line")
ENV_REASON = ("tools read .env files differently: node --env-file keeps ${VAR} as written while python-dotenv "
              "expands it, so a reference could break the app; keep the file out of git")


def display(path):
    """The path as the user knows it, with the home folder written as `~`."""
    if path == HOME or path.startswith(HOME + os.sep):
        return "~" + path[len(HOME):]
    return path


def expand(path):
    return os.path.abspath(os.path.expanduser(path))


def startup_files():
    """The shell startup files that exist, in the order the shells read them."""
    names = [
        ".zshenv", ".zprofile", ".zshrc", ".zlogin",
        ".bash_profile", ".bash_login", ".profile", ".bashrc",
        ".config/fish/config.fish", ".envrc",
    ]
    files = [os.path.join(HOME, n) for n in names]
    zdot = os.environ.get("ZDOTDIR")
    if zdot and os.path.abspath(zdot) != HOME:
        files += [os.path.join(zdot, n) for n in (".zshenv", ".zprofile", ".zshrc", ".zlogin")]
    confd = os.path.join(HOME, ".config/fish/conf.d")
    if os.path.isdir(confd):
        files += sorted(os.path.join(confd, f) for f in os.listdir(confd) if f.endswith(".fish"))
    config = os.path.join(HOME, ".config")
    if os.path.isdir(config):
        for tool in sorted(os.listdir(config)):
            envd = os.path.join(config, tool, "env.d")
            if os.path.isdir(envd):
                files += sorted(os.path.join(envd, f) for f in os.listdir(envd))
    return [f for f in files if os.path.isfile(f)]


def read_text(path):
    with open(path, "rb") as fh:
        return fh.read().decode("utf-8", "surrogateescape")


def sourced_files(path, text):
    """Files that `source FILE` or `. FILE` lines in this file read, when the path is fixed."""
    found = []
    base = os.path.dirname(path)
    for line in text.splitlines():
        if line.lstrip().startswith("#"):
            continue
        for m in SOURCE_RE.finditer(line):
            arg = m.group(1)
            if arg[0] in "\"'":
                arg = arg[1:-1]
            for var in ("${HOME}", "$HOME"):
                arg = arg.replace(var, HOME)
            zdot = os.environ.get("ZDOTDIR") or HOME
            for var in ("${ZDOTDIR}", "$ZDOTDIR"):
                arg = arg.replace(var, zdot)
            if arg.startswith("~/"):
                arg = os.path.join(HOME, arg[2:])
            if "$" in arg or any(c in arg for c in "*?[`"):
                continue
            if not os.path.isabs(arg):
                arg = os.path.join(base, arg)
            if os.path.isfile(arg):
                found.append(os.path.abspath(arg))
    return found


def is_fish(path):
    return path.endswith(".fish")


def parse_line(line, fish):
    """Return (name, value, pre, start, end, problem) for a literal assignment, or None.

    `start` and `end` index the value token inside `line`, quotes included.
    `problem` is a reason the value cannot be moved, or None."""
    m = (FISH_RE if fish else BASH_RE).match(line)
    if not m:
        return None
    name, val, pre = m.group("name"), m.group("val"), m.group("pre")
    start = len(pre)
    if not val:
        return None
    q = val[0]
    problem = None
    if q in "\"'":
        close = val.find(q, 1)
        if close < 0:
            return None
        value = val[1:close]
        token_len = close + 1
        if q == '"' and ("$" in value or "`" in value):
            return None
        if "\\" in value:
            problem = "the value contains a backslash, so its meaning depends on the shell; move it by hand"
    else:
        um = UNQUOTED_RE.match(val)
        if not um:
            return None
        value = um.group(0)
        token_len = len(value)
        if "\\" in value:
            problem = "the value contains a backslash, so its meaning depends on the shell; move it by hand"
        elif any(c in value for c in "*?[{"):
            problem = "the value contains * ? [ or {, which the shell may expand; move it by hand"
    rest = val[token_len:]
    if fish:
        tail = rest.strip()
        if tail and tail[0] not in "#;":
            return None
    elif rest and rest[0] not in " \t;":
        return None
    if problem is None and any(ord(c) > 126 or ord(c) < 32 and c != "\t" for c in value):
        problem = "the value contains characters outside printable ASCII, which the security command reads back as hex"
    return name, value, pre, start, start + token_len, problem


def kind_of(name, value):
    """The kind of secret, or None when the line does not look like one."""
    m = NAME_RE.search(name)
    word = (m.group(1) or m.group(2)) if m else None
    if not value or (len(value) < MIN_LENGTH and word not in PASSWORD_WORDS):
        return None
    low = value.lower()
    if low in PLACEHOLDERS or len(set(low)) == 1 or (value.startswith("<") and value.endswith(">")):
        return None
    if low.startswith(("your_", "your-")) or value.startswith(("/", "~", "./", "../")):
        return None
    for rx, kind in VALUE_KINDS:
        if rx.fullmatch(value):
            return kind
    if word in PASSWORD_WORDS and len(value) < MIN_LENGTH:
        return "short password"
    return NAME_KIND[word] if word else None


# ---------------------------------------------------------------------------
# Files that tools read on their own: ~/.npmrc, ~/.aws/credentials, ~/.netrc, and the .env files
# of the folder the scan runs in. Each entry is a dict with the line, name, kind, value, and
# problem, and for the files that can be moved, what the line becomes.


def upper_name(text):
    return re.sub(r"[^A-Za-z0-9]", "_", text).upper()


def tool_files():
    """(path, kind) of the files tools read on their own that exist, in the order scan lists them."""
    files = [(os.path.join(HOME, ".npmrc"), "npmrc"), (os.path.join(HOME, ".aws", "credentials"), "aws"),
             (os.path.join(HOME, ".netrc"), "netrc")]
    cwd = os.getcwd()
    try:
        names = sorted(os.listdir(cwd))
    except OSError:
        names = []
    files += [(os.path.join(cwd, f), "env") for f in names if f == ".env" or f.startswith(".env.")]
    return [(p, k) for p, k in files if os.path.isfile(p)]


def tool_kind(path):
    real = os.path.realpath(path)
    return next((k for p, k in tool_files() if os.path.realpath(p) == real), None)


def shell_rc():
    """(path, fish) of the startup file of the user's shell, from $SHELL, or (None, False)."""
    sh = os.path.basename(os.environ.get("SHELL", ""))
    if sh == "zsh":
        return os.path.join(os.environ.get("ZDOTDIR") or HOME, ".zshrc"), False
    if sh == "bash":
        return os.path.join(HOME, ".bashrc"), False
    if sh == "fish":
        return os.path.join(HOME, ".config", "fish", "config.fish"), True
    return None, False


def variable_set_in(name, rc):
    """Where a startup file, or a file it sources, already sets `name`, as `FILE:LINE`, or None."""
    rx = re.compile(r"^[ \t]*(?:export[ \t]+%s=|set[ \t]+(?:-[A-Za-z]+[ \t]+)*%s(?:[ \t]|$))" % (name, name))
    files = startup_files() + ([rc] if os.path.isfile(rc) else [])
    seen = set()
    while files:
        f = files.pop(0)
        real = os.path.realpath(f)
        if real in seen:
            continue
        seen.add(real)
        try:
            text = read_text(f)
        except OSError:
            continue
        for n, line in enumerate(text.splitlines(), 1):
            if rx.match(line):
                return "%s:%d" % (display(f), n)
        files += sourced_files(f, text)
    return None


def npmrc_entries(text, ready):
    """Tokens written into ~/.npmrc. Each moves to `${NAME}` plus an export line in the startup file."""
    rc, fish = shell_rc()
    out = []
    for n, line in enumerate(text.splitlines(), 1):
        m = NPMRC_RE.match(line.rstrip("\r"))
        if not m or m.group("val").startswith("${"):
            continue
        value = m.group("val")
        host = (m.group("scope") or "//registry.npmjs.org/")[2:].split("/")[0]
        name = "NPM_TOKEN" if host == "registry.npmjs.org" else "NPM_TOKEN_" + upper_name(host)
        kind = kind_of(name, value)
        if not kind:
            continue
        problem = None
        if not NPM_VALUE_RE.fullmatch(value):
            problem = "the value contains characters npm may read differently; move it by hand"
        elif rc is None:
            problem = "could not tell your shell from $SHELL, so there is no startup file to export %s from; move it by hand" % name
        else:
            where = variable_set_in(name, rc)
            source = chezmoi_source(rc)
            if where:
                problem = "a startup file already sets %s (%s); move the token by hand under another name" % (name, where)
            elif source:
                problem = "%s is generated by chezmoi; add the export line to %s by hand" % (display(rc), display(source))
        start, end = m.start("val"), m.end("val")
        show = ready and not problem
        out.append({
            "line": n, "name": name, "kind": kind, "value": value, "problem": problem, "rc": rc,
            "becomes": line[:start] + "${%s}" % name + line[end:] if show else None,
            "adds": {"path": display(rc), "line": ("set -gx %s %s" if fish else "export %s=%s") % (name, lookup(name, fish))}
            if show else None,
        })
    return out


def aws_entries(text, ready):
    """The secret key of each profile in ~/.aws/credentials. Its two key lines become one
    `credential_process` line that reads both keys from the store."""
    profiles = []
    for n, line in enumerate(text.splitlines(), 1):
        m = INI_SECTION_RE.match(line)
        if m:
            profiles.append((m.group("name").strip(), {}))
            continue
        m = AWS_LINE_RE.match(line)
        if m and profiles:
            profiles[-1][1][m.group("key")] = (n, m.group("val"))
    out = []
    for profile, keys in profiles:
        if "aws_secret_access_key" not in keys:
            continue
        n, secret = keys["aws_secret_access_key"]
        if not kind_of("AWS_SECRET_ACCESS_KEY", secret):
            continue
        name, id_name = "AWS_SECRET_ACCESS_KEY_" + upper_name(profile), "AWS_ACCESS_KEY_ID_" + upper_name(profile)
        id_line, key_id = keys.get("aws_access_key_id", (None, ""))
        problem = None
        if "aws_session_token" in keys:
            problem = "the profile also has a session token (aws_session_token), so its keys are temporary; renew " \
                      "them with your sign-in tool instead of storing them"
        elif "credential_process" in keys:
            problem = "the profile already has credential_process; move the keys by hand"
        elif id_line is None:
            problem = "the profile has no aws_access_key_id line to go with the secret key; move it by hand"
        elif not AWS_ID_RE.fullmatch(key_id) or not AWS_SECRET_RE.fullmatch(secret):
            problem = "the keys contain characters AWS keys do not use; move them by hand"
        show = ready and not problem
        out.append({
            "line": n, "name": name, "kind": "AWS secret access key", "value": secret, "problem": problem,
            "id_line": id_line, "id_name": id_name, "id_value": key_id,
            "becomes": "credential_process = " + CREDENTIAL_PROCESS % (plain_lookup(id_name), plain_lookup(name))
            if show else None,
            "adds": None,
        })
    return out


def netrc_entries(text):
    """Passwords in ~/.netrc, which cannot be moved."""
    tokens = [(t, n) for n, line in enumerate(text.splitlines(), 1) for t in line.split()]
    out = []
    machine = "default"
    i = 0
    while i < len(tokens):
        t = tokens[i][0]
        if t == "macdef":
            break
        if t == "machine" and i + 1 < len(tokens):
            machine = tokens[i + 1][0]
            i += 2
            continue
        if t == "default":
            machine = "default"
        elif t == "password" and i + 1 < len(tokens):
            value, n = tokens[i + 1]
            if value.lower() not in PLACEHOLDERS:
                out.append({"line": n, "name": "NETRC_" + upper_name(machine), "value": value, "problem": NETRC_REASON,
                            "kind": "password" if len(value) >= MIN_LENGTH else "short password",
                            "becomes": None, "adds": None})
            i += 2
            continue
        i += 1
    return out


def env_entries(text):
    """Secrets in a .env file, which cannot be moved."""
    out = []
    for n, line in enumerate(text.splitlines(), 1):
        m = ENV_RE.match(line.rstrip("\r"))
        if not m or not m.group("val"):
            continue
        val = m.group("val")
        if val[0] in "\"'":
            close = val.find(val[0], 1)
            if close < 0:
                continue
            value = val[1:close]
            if val[0] == '"' and "$" in value:
                continue
        else:
            value = re.split(r"[ \t]+#", val, maxsplit=1)[0]
            if "$" in value:
                continue
        kind = kind_of(m.group("name"), value)
        if kind:
            out.append({"line": n, "name": m.group("name"), "kind": kind, "value": value, "problem": ENV_REASON,
                        "becomes": None, "adds": None})
    return out


def tool_entries(kind, text, ready):
    if kind == "npmrc":
        return npmrc_entries(text, ready)
    if kind == "aws":
        return aws_entries(text, ready)
    if kind == "netrc":
        return netrc_entries(text)
    return env_entries(text)


def store_problem(store):
    """Why values cannot be moved into `store` here, or None when it and its command are present."""
    if store == "keychain":
        if sys.platform == "darwin" and shutil.which("security"):
            return None
        return "moving needs macOS and its security command"
    if store == "secret-service":
        if shutil.which("secret-tool"):
            return None
        return "moving on Linux needs secret-tool from libsecret, such as the libsecret-tools package"
    if store == "pass":
        if not shutil.which("pass"):
            return "moving into pass needs the pass command"
        if not os.path.isfile(os.path.join(PASS_DIR, ".gpg-id")):
            return "moving into pass needs a password store; set one up with `pass init` and your GPG key ID first"
        return None
    if store == "1password":
        # Only the command is looked for here: running op may ask the 1Password app for approval.
        if shutil.which("op"):
            return None
        return "moving into 1Password needs the op command (1Password CLI)"
    if store:
        return "SECURE_DOTFILE_STORE must be keychain, secret-service, pass, or 1password"
    return "moving needs macOS, Linux with secret-tool, pass, or the 1Password CLI"


_op_vault = None


def op_vault():
    """(vault, problem): the vault op stores new items in, or why it cannot be told.

    op has no command that names that vault; its help says it is Private, Personal, or Employee,
    depending on the account type. So the vault is the one of the account's vaults with one of
    those names. op runs once, and only when the store is 1Password."""
    global _op_vault
    if _op_vault is None:
        try:
            r = subprocess.run(["op", "vault", "list", "--format", "json"], capture_output=True, timeout=TIMEOUT)
        except subprocess.TimeoutExpired:
            _op_vault = None, "1Password did not answer within %d s; it may be waiting for approval" % TIMEOUT
            return _op_vault
        names = None
        if r.returncode == 0:
            try:
                names = [v.get("name") for v in json.loads(r.stdout)]
            except (ValueError, TypeError, AttributeError):
                names = None
        hits = [n for n in names or [] if n in OP_DEFAULT_VAULTS]
        if r.returncode != 0:
            _op_vault = None, "could not reach 1Password (op exited with %d%s); sign in with op or turn on " \
                              "the 1Password app integration" % (r.returncode, first_line(r.stderr))
        elif names is None:
            _op_vault = None, "could not read the vault list that op printed"
        elif len(hits) != 1:
            _op_vault = None, "could not tell which vault op stores new items in: %s of your vaults is named " \
                              "Private, Personal, or Employee" % ("none" if not hits else "more than one")
        else:
            _op_vault = hits[0], None
    return _op_vault


def moving_problem():
    problem = store_problem(STORE)
    if problem or STORE != "1password":
        return problem
    return op_vault()[1]


def usable_stores():
    """The stores that values can be moved into here, in the order `--store` lists them."""
    return [s for s in WHERE if store_problem(s) is None]


def op_reference(name):
    """The secret reference of the item's password field. The vault name is one of
    OP_DEFAULT_VAULTS and the item name is a variable name, so no part needs quoting."""
    return "op://%s/%s/password" % (op_vault()[0], name)


def lookup(name, fish):
    """The command that reads the value back when the shell starts."""
    if STORE == "secret-service":
        cmd = 'secret-tool lookup service %s account "$USER" 2>/dev/null' % name
    elif STORE == "pass":
        cmd = "pass show %s 2>/dev/null" % name
    elif STORE == "1password":
        cmd = "op read '%s' 2>/dev/null" % op_reference(name)
    else:
        kc = ' "%s"' % KEYCHAIN if KEYCHAIN else ""
        cmd = 'security find-generic-password -a "$USER" -s %s -w%s 2>/dev/null' % (name, kc)
    return "(%s)" % cmd if fish else '"$(%s)"' % cmd


def plain_lookup(name):
    """The command that prints the value, with no single quotes, to go inside `sh -c '...'`."""
    if STORE == "secret-service":
        return 'secret-tool lookup service %s account "$USER"' % name
    if STORE == "pass":
        return "pass show %s" % name
    if STORE == "1password":
        return "op read -n %s" % op_reference(name)
    kc = ' "%s"' % KEYCHAIN if KEYCHAIN else ""
    return 'security find-generic-password -a "$USER" -s %s -w%s' % (name, kc)


def chezmoi_source(path):
    """The chezmoi source file that `path` is generated from, or None."""
    if not shutil.which("chezmoi") or not path.startswith(HOME + os.sep):
        return None
    try:
        r = subprocess.run(["chezmoi", "source-path", path], capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.TimeoutExpired):
        return None
    src = r.stdout.strip()
    if r.returncode != 0 or not src or os.path.abspath(src) == os.path.abspath(path):
        return None
    return src if os.path.isfile(src) else None


def git_history(path, values):
    """For each value, whether it appears in the git history of `path`.

    Returns (state, {value: bool}) where state is `repo`, `untracked`, `none`, or `unknown: ...`."""
    real = os.path.realpath(path)
    d = os.path.dirname(real)
    try:
        r = subprocess.run(["git", "-C", d, "rev-parse", "--show-toplevel"], capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.TimeoutExpired):
        return "none", {}
    if r.returncode != 0:
        return "none", {}
    top = r.stdout.strip()
    rel = os.path.relpath(real, top)
    t = subprocess.run(["git", "-C", top, "ls-files", "--error-unmatch", "--", rel], capture_output=True, text=True)
    if t.returncode != 0:
        return "untracked", {}
    try:
        p = subprocess.Popen(["git", "-C", top, "log", "--all", "-p", "--no-color", "--no-ext-diff",
                              "--format=", "--", rel], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    except OSError as e:
        return "unknown: git could not run (%s)" % type(e).__name__, {}
    wanted = {v: v.encode("utf-8", "surrogateescape") for v in values}
    seen = {v: False for v in values}
    keep = max((len(b) for b in wanted.values()), default=1)
    tail = b""
    total = 0
    while True:
        chunk = p.stdout.read(1 << 20)
        if not chunk:
            break
        total += len(chunk)
        buf = tail + chunk
        for v, b in wanted.items():
            if not seen[v] and b in buf:
                seen[v] = True
        tail = buf[-keep:]
        if total > HISTORY_LIMIT or all(seen.values()):
            p.kill()
            break
    p.wait()
    if total > HISTORY_LIMIT and not all(seen.values()):
        return "unknown: the history of %s is larger than 64 MB" % rel, seen
    return "repo", seen


def scan(extra):
    for f in extra:
        if not os.path.isfile(expand(f)):
            print("no such file: %s" % f, file=sys.stderr)
            sys.exit(2)
    queue = [(f, 0) for f in startup_files()] + [(expand(f), 0) for f in extra]
    cannot_move = moving_problem()
    seen_real = set()
    scanned = []
    items = []
    while queue:
        path, depth = queue.pop(0)
        real = os.path.realpath(path)
        if real in seen_real:
            continue
        seen_real.add(real)
        try:
            text = read_text(path)
        except OSError:
            continue
        scanned.append(path)
        fish = is_fish(path)
        found = []
        for n, line in enumerate(text.splitlines(), 1):
            parsed = parse_line(line, fish)
            if not parsed:
                continue
            name, value, pre, start, end, problem = parsed
            kind = kind_of(name, value)
            if not kind:
                continue
            found.append((n, line, name, value, start, end, problem, kind))
        if depth < MAX_INCLUDE_DEPTH:
            queue += [(f, depth + 1) for f in sourced_files(path, text)]
        if not found:
            continue
        source = chezmoi_source(path)
        if source:
            queue.append((source, depth))
        state, hist = git_history(path, [f[3] for f in found])
        for n, line, name, value, start, end, problem, kind in found:
            if source and not problem:
                problem = "managed by chezmoi: move it in %s, then run `chezmoi apply`" % display(source)
            becomes = line[:start] + lookup(name, fish) + line[end:] if not problem and lines_ready(cannot_move) else None
            items.append(make_item(path, n, name, kind, value, history_of(state, hist, value), problem, cannot_move,
                                   becomes, None))
    for path, kind in tool_files():
        real = os.path.realpath(path)
        if real in seen_real:
            continue
        seen_real.add(real)
        try:
            text = read_text(path)
        except OSError:
            continue
        scanned.append(path)
        entries = tool_entries(kind, text, lines_ready(cannot_move))
        if not entries:
            continue
        source = chezmoi_source(path)
        state, hist = git_history(path, [e["value"] for e in entries])
        for e in entries:
            problem = e["problem"]
            if source and not problem:
                problem = "managed by chezmoi: move it by hand in %s, then run `chezmoi apply`" % display(source)
            items.append(make_item(path, e["line"], e["name"], e["kind"], e["value"], history_of(state, hist, e["value"]),
                                   problem, cannot_move, None if problem else e["becomes"], None if problem else e["adds"]))
    return scanned, items


def lines_ready(cannot_move):
    """Whether the lines a move writes can be shown. A 1Password line names the vault, which is
    known only when op answered."""
    return STORE in WHERE and not (STORE == "1password" and cannot_move)


def history_of(state, hist, value):
    if state == "none":
        return "not in a git repository"
    if state == "untracked":
        return "not tracked by git"
    if hist.get(value):
        return "yes"
    return state if state.startswith("unknown") else "no"


def make_item(path, n, name, kind, value, history, problem, cannot_move, becomes, adds):
    return {
        "name": name,
        "path": display(path),
        "line": n,
        "kind": kind,
        "length": len(value),
        "in_git_history": history,
        "item": "%s:%d:%s" % (display(path), n, name),
        "movable": problem is None and cannot_move is None,
        "reason": problem or cannot_move,
        "becomes": becomes,
        # An npm token also adds an export line to the startup file: {"path": ..., "line": ...}.
        "adds": adds,
    }


def store_line(stores):
    """Where the move would store values, and the other stores `--store` can pick here."""
    cannot_move = moving_problem()
    where = "the 1Password vault %s" % op_vault()[0] if STORE == "1password" and not cannot_move else WHERE.get(STORE)
    line = "Cannot move here: %s" % cannot_move if cannot_move else "Moves into %s" % where
    others = ["%s (add --store %s)" % (WHERE[s], s) for s in stores if s != STORE]
    return line + (". Also available: " + ", ".join(others) if others else "")


def print_scan(scanned, items, stores):
    print("Scanned %d files: %s" % (len(scanned), ", ".join(display(p) for p in scanned) or "none"))
    if not items:
        print("Found no secrets written into them.")
        return
    print(store_line(stores))
    print("Found %d secret%s written into them.\n" % (len(items), "" if len(items) == 1 else "s"))
    for i, it in enumerate(items, 1):
        print("%d  %s  %s:%d" % (i, it["name"], it["path"], it["line"]))
        print("   %s, %d characters, in git history: %s" % (it["kind"], it["length"], it["in_git_history"]))
        print("   item     %s" % it["item"])
        if it["movable"]:
            print("   becomes  %s" % it["becomes"].strip())
            if it.get("adds"):
                print("   adds     %s  (to %s)" % (it["adds"]["line"], it["adds"]["path"]))
        else:
            print("   cannot move: %s" % it["reason"])


# ---------------------------------------------------------------------------
# Stores: the macOS Keychain through `security`, the secret service through `secret-tool`, the
# password store through `pass`, and 1Password through `op`


def kc_args():
    return [KEYCHAIN] if KEYCHAIN else []


def quote(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def first_line(err):
    """The first line of a command's error output, as `: line`, or "" when it wrote none.

    Only errors of `secret-tool`, `pass`, and the `op` commands that are given no value are passed
    here. They describe the D-Bus session, the keyring, the GPG key, or the 1Password sign-in and
    never repeat the value, which reaches the command on standard input."""
    lines = err.decode("utf-8", "replace").strip().splitlines()
    if not lines:
        return ""
    return ": " + "".join(c for c in lines[0] if 32 <= ord(c) < 127)[:200]


def read_secret(name):
    """(state, value bytes, exit code, error). State is `found`, `missing`, `many`, or `error`."""
    if STORE == "1password":
        # The item list tells whether the item exists, so a missing item is not judged by an error
        # message. Secret references ignore case, so titles that differ only in case count too.
        r = subprocess.run(["op", "item", "list", "--vault", op_vault()[0], "--format", "json"],
                           capture_output=True, timeout=TIMEOUT)
        if r.returncode != 0:
            return "error", b"", r.returncode, first_line(r.stderr)
        try:
            titles = [i.get("title") for i in json.loads(r.stdout)]
        except (ValueError, TypeError, AttributeError):
            return "error", b"", 0, ": the item list that op printed could not be read"
        same = [t for t in titles if isinstance(t, str) and t.lower() == name.lower()]
        if not same:
            return "missing", b"", 0, ""
        if len(same) > 1:
            return "many", b"", 0, ""
        r = subprocess.run(["op", "read", "-n", op_reference(name)], capture_output=True, timeout=TIMEOUT)
        if r.returncode != 0:
            return "error", b"", r.returncode, first_line(r.stderr)
        return "found", r.stdout, 0, ""
    if STORE == "pass":
        # The entry's file tells whether it exists, so a missing entry needs no GPG key.
        if not os.path.isfile(os.path.join(PASS_DIR, name + ".gpg")):
            return "missing", b"", 1, ""
        r = subprocess.run(["pass", "show", name], capture_output=True, timeout=TIMEOUT)
        err = first_line(r.stderr)
        if r.returncode != 0:
            return "error", b"", r.returncode, err
        # `pass insert -e` stores the value followed by a newline.
        return "found", r.stdout[:-1] if r.stdout.endswith(b"\n") else r.stdout, 0, err
    if STORE == "secret-service":
        # A missing item exits 1 with no output; an unreachable secret service exits 1 and says why.
        r = subprocess.run(["secret-tool", "lookup", "service", name, "account", ACCOUNT],
                           capture_output=True, timeout=TIMEOUT)
        err = first_line(r.stderr)
        if r.returncode == 0:
            return "found", r.stdout, 0, err
        if r.returncode == 1 and not r.stdout and not err:
            return "missing", b"", 1, err
        return "error", b"", r.returncode, err
    r = subprocess.run(["security", "find-generic-password", "-a", ACCOUNT, "-s", name, "-w"] + kc_args(),
                       capture_output=True, timeout=TIMEOUT)
    out = r.stdout[:-1] if r.stdout.endswith(b"\n") else r.stdout
    state = "found" if r.returncode == 0 else "missing" if r.returncode == 44 else "error"
    return state, out, r.returncode, ""


def add_secret(name, value):
    """Store the value on the command's standard input, so it never reaches a command line.

    Returns (exit code, error). `secret-tool store` and `pass insert` replace an item silently, and
    `op item create` adds a second item of the same name, so `store` reads first and calls this
    only when the name holds nothing."""
    if STORE == "1password":
        # op's help says values given as assignment arguments can be seen by other processes, and
        # points to an item JSON template on standard input instead.
        item = {"title": name, "category": "LOGIN", "fields": [
            {"id": "password", "type": "CONCEALED", "purpose": "PASSWORD", "label": "password", "value": value},
            {"id": "notesPlain", "type": "STRING", "purpose": "NOTES", "label": "notesPlain",
             "value": "added by secure-dotfile"},
        ]}
        # The error output is never read: it could quote the template, value included.
        r = subprocess.run(["op", "item", "create", "--vault", op_vault()[0], "-"],
                           input=json.dumps(item).encode("utf-8"), capture_output=True, timeout=TIMEOUT)
        return r.returncode, ""
    if STORE == "pass":
        r = subprocess.run(["pass", "insert", "-e", name], input=value.encode("utf-8") + b"\n",
                           capture_output=True, timeout=TIMEOUT)
        return r.returncode, first_line(r.stderr)
    if STORE == "secret-service":
        r = subprocess.run(["secret-tool", "store", "--label=%s (added by secure-dotfile)" % name,
                            "service", name, "account", ACCOUNT],
                           input=value.encode("utf-8"), capture_output=True, timeout=TIMEOUT)
        return r.returncode, first_line(r.stderr)
    cmd = "add-generic-password -a %s -s %s -j %s -w %s%s\n" % (
        quote(ACCOUNT), quote(name), quote("added by secure-dotfile"), quote(value),
        " " + quote(KEYCHAIN) if KEYCHAIN else "")
    # The error output of `security -i` is never read: it could repeat the command, value included.
    r = subprocess.run(["security", "-i"], input=cmd.encode("utf-8"), capture_output=True, timeout=TIMEOUT)
    return r.returncode, ""


def store(name, value):
    """Put the value in the store. Returns None when it is there now, or the reason it is not."""
    want = value.encode("utf-8")
    try:
        state, have, code, err = read_secret(name)
        if state == "found":
            if have == want:
                return None
            return "a different value is already stored as %s; remove or rename that item first" % name
        if state == "many":
            return "more than one item in the 1Password vault %s is named %s; remove or rename the others first" % (
                op_vault()[0], name)
        if state == "error":
            if STORE == "1password":
                return "could not read 1Password (op exited with %d%s); sign in with op or unlock the 1Password app" % (
                    code, err)
            if STORE == "secret-service":
                return "could not reach the secret service (secret-tool exited with %d%s); " \
                       "it may be locked or not running" % (code, err)
            if STORE == "pass":
                return "could not read pass (pass exited with %d%s); the GPG key may be locked or missing" % (code, err)
            return "could not read the keychain (security exited with %d); it may be locked" % code
        added, added_err = add_secret(name, value)
        state, have, code, err = read_secret(name)
    except subprocess.TimeoutExpired:
        return "%s did not answer within %d s; it may be waiting for a password" % (WHERE[STORE], TIMEOUT)
    if state == "found" and have == want:
        return None
    if STORE == "keychain":
        return "the value could not be stored and read back (security exited with %d)" % code
    if STORE == "1password":
        if added != 0:
            return "the value could not be stored in 1Password (op exited with %d)" % added
        return "the value was stored in the 1Password vault %s as %s but could not be read back " \
               "(op exited with %d%s); check that item and run the move again" % (op_vault()[0], name, code, err)
    tool = "secret-tool" if STORE == "secret-service" else "pass"
    if added != 0:
        return "the value could not be stored in %s (%s exited with %d%s)" % (WHERE[STORE], tool, added, added_err)
    if STORE == "pass":
        # `pass insert` encrypts with the public key, so it succeeds while the private key is locked.
        return "the value was stored in pass as %s but could not be read back (pass exited with %d%s); " \
               "unlock the GPG key and run the move again" % (name, code, err)
    return "the value could not be stored and read back (secret-tool exited with %d%s)" % (code, err)


# ---------------------------------------------------------------------------
# Editing files


def syntax_check(path, text):
    """(ok, label). ok is None when the check could not run."""
    base = os.path.basename(path)
    if path.endswith(".tmpl"):
        return None, "not checked: chezmoi template"
    if is_fish(path):
        shell, args = "fish", ["--no-execute"]
    elif "zsh" in base or base.endswith(".zsh"):
        shell, args = "zsh", ["-n"]
    else:
        shell, args = "bash", ["-n"]
    if not shutil.which(shell):
        return None, "not checked: %s not found" % shell
    # The text goes in on standard input, so no copy of the file is written anywhere.
    try:
        r = subprocess.run([shell] + args, input=text.encode("utf-8", "surrogateescape"),
                           capture_output=True, timeout=30)
    except subprocess.TimeoutExpired:
        return None, "not checked: %s did not finish" % shell
    return r.returncode == 0, "%s %s" % (shell, " ".join(args))


def write_atomic(path, text):
    real = os.path.realpath(path)
    mode = os.stat(real).st_mode & 0o7777
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(real), prefix=".secure-dotfile-")
    try:
        with os.fdopen(fd, "wb") as fh:
            fh.write(text.encode("utf-8", "surrogateescape"))
            fh.flush()
            os.fsync(fh.fileno())
        os.chmod(tmp, mode)
        os.replace(tmp, real)
    except BaseException:
        if os.path.exists(tmp):
            os.remove(tmp)
        raise


def append_line(path, line):
    """Add `line` at the end of a startup file and check its syntax. Returns None, or why the line
    was not added. A missing file is created, readable only by the user."""
    exists = os.path.isfile(path)
    text = read_text(path) if exists else ""
    new = text + ("\n" if text and not text.endswith("\n") else "") + line + "\n"
    before_ok = syntax_check(path, text)[0] if exists else True
    after_ok, label = syntax_check(path, new)
    if before_ok and after_ok is False:
        return "%s failed `%s` with the export line added, so it was left as it was" % (display(path), label)
    if exists:
        write_atomic(path, new)
    else:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "wb") as fh:
            fh.write(new.encode("utf-8", "surrogateescape"))
    return None


def move_tool_file(path, kind, picks, dry_run, result):
    """Move the picks of one file that a tool reads on its own. npm tokens become `${NAME}` with an
    export line in the startup file, and AWS profiles get a `credential_process` line. Items in
    ~/.netrc and .env files are skipped with the reason."""
    original = read_text(path)
    lines = original.splitlines(keepends=True)
    entries = {e["line"]: e for e in tool_entries(kind, original, True)}
    where = WHERE[STORE]
    changed = []
    for _, n, name in sorted(picks, key=lambda p: p[1]):
        e = entries.get(n)
        if not e or e["name"] != name:
            result(name, n, "skipped", "line %d no longer holds %s as a literal value; scan again" % (n, name))
            continue
        if e["problem"]:
            result(name, n, "skipped", e["problem"])
            continue
        eol = lines[n - 1][len(lines[n - 1].rstrip("\r\n")):]
        if kind == "npmrc":
            if dry_run:
                result(name, n, "would move", "would store %s in %s, change the line to: %s, and add to %s: %s" % (
                    name, where, e["becomes"], e["adds"]["path"], e["adds"]["line"]))
                continue
            reason = store(name, e["value"])
            if reason:
                result(name, n, "skipped", reason)
                continue
            reason = append_line(e["rc"], e["adds"]["line"])
            if reason:
                result(name, n, "skipped", "the value is stored in %s as %s, but %s" % (where, name, reason))
                continue
            lines[n - 1] = e["becomes"] + eol
            changed.append((name, n, "stored in %s as %s; %s reads ${%s}, which %s exports" % (
                where, name, display(path), name, e["adds"]["path"])))
            continue
        if dry_run:
            result(name, n, "would move", "would store %s and %s in %s and replace their two lines with: %s" % (
                e["id_name"], name, where, e["becomes"]))
            continue
        reason = store(e["id_name"], e["id_value"]) or store(name, e["value"])
        if reason:
            result(name, n, "skipped", reason)
            continue
        lines[n - 1] = e["becomes"] + eol
        lines[e["id_line"] - 1] = ""
        changed.append((name, n, "stored in %s as %s and %s; the profile reads them through credential_process" % (
            where, e["id_name"], name)))
    if changed:
        write_atomic(path, "".join(lines))
    for name, n, note in changed:
        result(name, n, "moved", note)


def parse_item(spec):
    try:
        path, line, name = spec.rsplit(":", 2)
        return expand(path), int(line), name
    except ValueError:
        return None


def move(specs, dry_run):
    results = []
    by_file = {}
    for spec in specs:
        parsed = parse_item(spec)
        if not parsed or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", parsed[2]):
            print("bad item: %s (expected PATH:LINE:NAME)" % spec, file=sys.stderr)
            sys.exit(2)
        by_file.setdefault(parsed[0], []).append(parsed)
    for path, picks in by_file.items():
        def result(name, line, status, note):
            results.append({"name": name, "path": display(path), "line": line, "status": status, "note": note})

        if not os.path.isfile(path):
            for _, line, name in picks:
                result(name, line, "skipped", "the file no longer exists")
            continue
        kind = tool_kind(path)
        source = chezmoi_source(path)
        if source:
            how = "by hand " if kind else ""
            for _, line, name in picks:
                result(name, line, "skipped", "managed by chezmoi: move it %sin %s, then run `chezmoi apply`" % (
                    how, display(source)))
            continue
        if kind:
            move_tool_file(path, kind, picks, dry_run, result)
            continue
        original = read_text(path)
        lines = original.splitlines(keepends=True)
        fish = is_fish(path)
        changed = []
        for _, n, name in sorted(picks, key=lambda p: p[1]):
            if n < 1 or n > len(lines):
                result(name, n, "skipped", "the file has no line %d now; scan again" % n)
                continue
            raw = lines[n - 1]
            body = raw.rstrip("\r\n")
            eol = raw[len(body):]
            parsed = parse_line(body, fish)
            if not parsed or parsed[0] != name or not kind_of(name, parsed[1]):
                result(name, n, "skipped", "line %d no longer sets %s to a literal value; scan again" % (n, name))
                continue
            _, value, _, start, end, problem = parsed
            if problem:
                result(name, n, "skipped", problem)
                continue
            new = body[:start] + lookup(name, fish) + body[end:]
            if dry_run:
                result(name, n, "would move", "would store %s in %s and change the line to: %s" % (name, WHERE[STORE], new.strip()))
                continue
            reason = store(name, value)
            if reason:
                result(name, n, "skipped", reason)
                continue
            lines[n - 1] = new + eol
            changed.append((name, n))
        if not changed:
            continue
        edited = "".join(lines)
        before_ok, _ = syntax_check(path, original)
        after_ok, label = syntax_check(path, edited)
        if before_ok and after_ok is False:
            for name, n in changed:
                result(name, n, "skipped", "the edited file failed `%s`, so the file was left as it was; "
                       "the value is stored in %s as %s" % (label, WHERE[STORE], name))
            continue
        write_atomic(path, edited)
        check = "syntax check passed (%s)" % label if after_ok else (
            label if after_ok is None else "the file already failed `%s` before the edit" % label)
        for name, n in changed:
            result(name, n, "moved", "stored in %s as %s; %s" % (WHERE[STORE], name, check))
    return results


def print_move(results, dry_run):
    for r in results:
        print("%-10s %s  %s:%d  %s" % (r["status"], r["name"], r["path"], r["line"], r["note"]))
    moved = sum(1 for r in results if r["status"] == "moved")
    skipped = sum(1 for r in results if r["status"] == "skipped")
    if dry_run:
        print("Dry run: nothing was stored or changed.")
    else:
        print("Moved %d, skipped %d." % (moved, skipped))
        if moved:
            print("Open a new terminal, or run `exec $SHELL -l`, to load the moved values.")


def main(argv):
    ap = argparse.ArgumentParser(prog="secure_dotfile.py", description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("scan", help="list secrets written into shell startup files")
    s.add_argument("--file", action="append", default=[], help="also scan this file")
    s.add_argument("--store", choices=list(WHERE), help="show the lines for this store")
    s.add_argument("--json", action="store_true")
    m = sub.add_parser("move", help="move the picked secrets into the Keychain, the secret service, pass, or 1Password")
    m.add_argument("--item", action="append", required=True, help="PATH:LINE:NAME from the scan")
    m.add_argument("--store", choices=list(WHERE), help="the store to move the values into")
    m.add_argument("--dry-run", action="store_true")
    m.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    global STORE
    if args.store:
        STORE = args.store
    if args.cmd == "scan":
        scanned, items = scan(args.file)
        stores = usable_stores()
        if args.json:
            print(json.dumps({"scanned": [display(p) for p in scanned], "store": STORE or None, "stores": stores,
                              "items": items}, indent=2))
        else:
            print_scan(scanned, items, stores)
        return 0
    cannot_move = moving_problem()
    if cannot_move:
        print("os-not-supported: %s" % cannot_move, file=sys.stderr)
        return 3
    results = move(args.item, args.dry_run)
    if args.json:
        print(json.dumps({"results": results}, indent=2))
    else:
        print_move(results, args.dry_run)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        sys.exit(130)
    except Exception as e:  # never print the message: it could quote a line of a file
        tb = e.__traceback__
        while tb.tb_next:
            tb = tb.tb_next
        print("secure_dotfile.py stopped with %s at line %d" % (type(e).__name__, tb.tb_lineno), file=sys.stderr)
        sys.exit(1)
