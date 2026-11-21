#!/usr/bin/env python3
"""Find what takes disk space and what holds memory and CPU, and free only what the user picks.

The scan measures, at the lowest priority and within a time limit: caches that tools rebuild,
build output in git projects, the Trash, old logs and installers, large and duplicate files,
apps not opened for a long time, dev processes left running after their session ended, heavy
processes, login items, and running Docker containers. Anything a live agent session, an open
terminal, or a running program in the same project uses is listed but cannot be picked.

State lives in ~/.local/share/machine-cleanup (or MACHINE_CLEANUP_HOME), readable only by you.
Nothing is sent anywhere: the page is served on 127.0.0.1 only, to the browser on this computer.

Usage:
  machine_cleanup.py scan [--root DIR]... [--apps-dir DIR]... [--time-limit SECONDS] [--sample SECONDS] [--json]
  machine_cleanup.py serve [--wait SECONDS] [--no-open]
  machine_cleanup.py apply --select TEXT [--term-wait SECONDS]
  machine_cleanup.py apply --kill ID...
  machine_cleanup.py restore [ID...]          lists what can be restored when no ID is given
  machine_cleanup.py finish                   removes the scan and the page session

Exit codes: 0 on success, 1 when a selection or a restore is refused, 2 for bad input or a missing
scan, 3 when an item could not be freed, 4 when serve waited without receiving a selection.
"""
import argparse
import datetime
import hashlib
import hmac
import http.server
import json
import os
import plistlib
import pwd
import re
import secrets
import shutil
import signal
import socket
import subprocess
import sys
import time
import urllib.parse

FORMAT_VERSION = 1  # restore.json
# scan.json; 2 added each item's level and reason, 3 the whole disk size, 4 work folders, app leftovers,
# tool versions, and models, 5 one row for each path, the rows that hold a row, and keys for the names
# the script makes
SCAN_VERSION = 5
MIB = 1024 * 1024
LARGE_FILE = 500 * MIB
DUPLICATE_MIN = 10 * MIB
BUILD_MIN = 1 * MIB
APP_CACHE_MIN = 50 * MIB
OLD_DAYS = 30
APP_UNUSED_DAYS = 90
HEAVY_RSS = 500 * MIB
HEAVY_CPU = 25.0
HEAVY_TOP = 15
WALK_DEPTH = 8
REPO_DEPTH = 4
DEFAULT_TIME_LIMIT = 90
DEFAULT_WAIT = 540
DEFAULT_TERM_WAIT = 5
SELECT_PREFIX = "machine-cleanup:select"
ID_RE = re.compile(r"^[dp]-[0-9a-f]{8}$")
AGENTS = ("claude", "codex", "copilot", "gemini")
INSTALLER_EXTS = (".dmg", ".pkg", ".mpkg", ".iso", ".xip", ".appimage", ".deb", ".rpm", ".msi", ".exe")
LOG_EXTS = (".log", ".crash", ".ips", ".diag", ".spin", ".hang", ".old", ".gz")
BUILD_NAMES = {
    "node_modules", ".next", ".nuxt", ".svelte-kit", ".turbo", ".parcel-cache", ".vite", ".angular",
    ".expo", ".docusaurus", ".output", ".vercel", ".wrangler", "dist", "build", "out", "target",
    ".venv", "venv", "__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache", ".tox", ".gradle",
    "DerivedData", "coverage", ".cache", "Pods",
}
# Folders in the cache folder that a cache entry of its own already covers.
COVERED_CACHES = {"Homebrew", "Yarn", "yarn", "pip", "CocoaPods", "go-build", "uv", "pnpm"}
# Places whose contents a sync service mirrors to the cloud and to other devices.
# Folders under the cache folder that hold downloaded AI models, which take long to download again.
MODEL_CACHES = {"huggingface", "lm-studio"}
# The Library folders where macOS apps keep files, and the name forms of a bundle id there.
LEFTOVER_PLACES = ("Application Support", "Caches", "Preferences", "Containers", "Saved Application State",
                   "HTTPStorages", "WebKit", "Logs")
# A bundle id starts with a top-level domain of 2 to 4 letters (com, io, dev, info). A part that looks
# generated, such as a UUID or a long random token, marks storage an app or a test made per run.
BUNDLE_ID_RE = re.compile(r"^[a-z]{2,4}\.[A-Za-z0-9-]+(\.[A-Za-z0-9_-]+)+$")
GENERATED_PART_RE = re.compile(r"^([0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-.*|[0-9A-Fa-f]{16,}|(?=.*[0-9])[A-Za-z0-9_-]{20,})$")
LEFTOVER_WALK_MAX = 5000
# Files where a project names the tool versions it uses, and the version managers that read each.
VERSION_FILES = {
    ".nvmrc": ("node", ("nvm", "fnm", "mise")), ".node-version": ("node", ("nvm", "fnm", "mise")),
    ".python-version": ("python", ("pyenv", "mise")), ".ruby-version": ("ruby", ("rbenv", "mise", "asdf")),
    ".tool-versions": (None, ("asdf", "mise")), "mise.toml": (None, ("mise",)), ".mise.toml": (None, ("mise",)),
    "rust-toolchain": ("rust", ("rustup",)), "rust-toolchain.toml": ("rust", ("rustup",)),
}
TOOL_NAMES = {"nodejs": "node", "golang": "go"}
SYNC_DIRS = ("Library/Mobile Documents", "Library/CloudStorage", "Dropbox", "OneDrive", "Google Drive",
             "iCloud Drive", "Box", "pCloud Drive", "Nextcloud", "ownCloud", "MEGA")
SECRET_ARG = re.compile(r"(?i)(--?[a-z0-9_-]*(token|secret|password|passwd|api[-_]?key|auth)[a-z0-9_-]*)(=|\s+)(\S+)")
SECRET_ENV = re.compile(r"(?i)\b([A-Z0-9_]*(TOKEN|SECRET|PASSWORD|PASSWD|API_KEY|APIKEY|AUTH)[A-Z0-9_]*)=(\S+)")
DEV_PATTERNS = (
    (r"(^|/)next\s+dev\b", "Next.js dev server"),
    # Next.js renames both `next dev` and `next start` to next-server, so the title cannot tell them apart.
    (r"(^|/)next-server\b|next-router-worker", "Next.js server"),
    (r"(^|/)vite(\s|$)", "Vite dev server"),
    (r"webpack-dev-server|(^|/)webpack\s+serve\b", "webpack dev server"),
    (r"(^|/)nodemon(\s|$)", "nodemon"),
    (r"(^|/)(tsx|ts-node-dev)\s+(watch|--watch|--respawn)|(^|/)tsc\s+.*(-w|--watch)\b", "TypeScript watcher"),
    (r"(^|/)vitest(\s|$)|(^|/)jest\s+.*--watch", "test watcher"),
    (r"(^|/)playwright\s+test\b|playwright/cli\.js\s+test\b", "Playwright tests"),
    (r"(^|/)pytest(\s|$)|python[0-9.]*\s+-m\s+pytest\b", "pytest"),
    (r"(^|/)(astro|nuxt|nuxi|remix|gatsby|docusaurus|svelte-kit)\s+(dev|develop|start)\b", "framework dev server"),
    (r"react-scripts\s+start\b|(^|/)ng\s+serve\b|storybook\s+dev\b|start-storybook", "dev server"),
    (r"(^|/)(npm|pnpm|yarn|bun)\s+(run\s+)?(dev|start|watch|serve|test)\b", "package script"),
    (r"(^|/)turbo\s+(run\s+)?dev\b", "Turborepo dev"),
    (r"(^|/)wrangler\s+dev\b|firebase\s+emulators", "local emulator"),
    (r"(^|/)rails\s+(s|server)\b|(^|/)uvicorn\s|flask\s+run\b|manage\.py\s+runserver\b", "dev server"),
    (r"(^|/)hugo\s+server\b|(^|/)jekyll\s+serve\b|(^|/)mkdocs\s+serve\b", "site preview server"),
    (r"(^|/)(anvil|ganache)(\s|$)|hardhat\s+node\b", "local chain"),
    (r"(^|/)cargo\s+watch\b|(^|/)watchexec(\s|$)|(^|/)air(\s|$)", "file watcher"),
    (r"esbuild\s+.*--watch|(^|/)chokidar(\s|$)", "file watcher"),
    (r"(^|/)expo\s+start\b|(^|/)metro(\s|$)", "React Native bundler"),
    (r"GradleDaemon|KotlinCompileDaemon", "Gradle daemon"),
)
DEV_RES = tuple((re.compile(p), label) for p, label in DEV_PATTERNS)
# The page's dictionary key for each dev process name. nodemon and pytest are the tools' own names,
# which read the same in every language, so they have none.
DEV_KEYS = {
    "Next.js dev server": "dev_next_dev", "Next.js server": "dev_next_server", "Vite dev server": "dev_vite",
    "webpack dev server": "dev_webpack", "TypeScript watcher": "dev_typescript_watch", "test watcher": "dev_test_watch",
    "Playwright tests": "dev_playwright", "framework dev server": "dev_framework", "dev server": "dev_server",
    "package script": "dev_package_script", "Turborepo dev": "dev_turborepo", "local emulator": "dev_emulator",
    "site preview server": "dev_site_preview", "local chain": "dev_chain", "file watcher": "dev_file_watch",
    "React Native bundler": "dev_react_native", "Gradle daemon": "dev_gradle",
}


# --- basics ---------------------------------------------------------------------------------

def detect_platform():
    if sys.platform == "darwin":
        return "darwin"
    try:
        with open("/proc/version", encoding="utf-8", errors="replace") as f:
            if "microsoft" in f.read().lower():
                return "wsl"
    except OSError:
        pass
    return "linux"


class Ctx:
    def __init__(self, platform=None):
        self.platform = platform or detect_platform()
        self.home = os.path.realpath(os.path.expanduser("~"))
        self.state = os.environ.get("MACHINE_CLEANUP_HOME") or os.path.join(self.home, ".local", "share", "machine-cleanup")
        self.uid = os.getuid()
        try:
            self.user = pwd.getpwuid(self.uid).pw_name
        except KeyError:
            self.user = str(self.uid)
        self.now = time.time()

    @property
    def mac(self):
        return self.platform == "darwin"

    def h(self, *parts):
        return os.path.join(self.home, *parts)

    def cache_root(self):
        if self.mac:
            return self.h("Library", "Caches")
        return os.environ.get("XDG_CACHE_HOME") or self.h(".cache")

    def data_root(self):
        return os.environ.get("XDG_DATA_HOME") or self.h(".local", "share")


def run(cmd, timeout=60, env=None):
    """Runs a command and returns (exit code, stdout). A missing command returns 127."""
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout,
                           universal_newlines=True, errors="replace", env=env)
        return p.returncode, p.stdout, p.stderr
    except FileNotFoundError:
        return 127, "", "%s is not installed" % cmd[0]
    except subprocess.TimeoutExpired:
        return 124, "", "%s took longer than %d seconds" % (cmd[0], timeout)
    except OSError as e:
        return 126, "", str(e)


def git(repo, *args, deadline=None):
    """Runs a read-only git command in a repository, for at most 60 seconds or the time left.
    GIT_OPTIONAL_LOCKS=0 keeps git status from rewriting the index, so reading a project never
    makes it look used."""
    timeout = 60 if deadline is None else max(1, min(60, deadline - time.time()))
    return run(["git", "-C", repo] + list(args), timeout=timeout, env=dict(os.environ, GIT_OPTIONAL_LOCKS="0"))


def lowest_priority():
    try:
        os.nice(19 - os.nice(0))
    except OSError:
        pass


def ensure_state(ctx):
    os.makedirs(ctx.state, mode=0o700, exist_ok=True)
    os.chmod(ctx.state, 0o700)


def write_private(path, text):
    tmp = path + ".tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(text)
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)


def read_json(path, default=None):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def human(n):
    if n is None:
        return "unknown"
    n = float(n)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        # 999.95 and more would print as 1000.0, so it moves to the next unit.
        if abs(n) < (1000 if unit == "B" else 999.95) or unit == "TB":
            return ("%d %s" % (n, unit)) if unit == "B" else ("%.1f %s" % (n, unit))
        n /= 1000.0
    return "%.1f TB" % n


def tilde(ctx, path):
    if path and (path == ctx.home or path.startswith(ctx.home + "/")):
        return "~" + path[len(ctx.home):]
    return path


def item_id(prefix, *parts):
    return "%s-%s" % (prefix, hashlib.sha1("|".join(str(p) for p in parts).encode("utf-8")).hexdigest()[:8])


def redact(text):
    text = SECRET_ARG.sub(lambda m: m.group(1) + m.group(3) + "***", text)
    return SECRET_ENV.sub(lambda m: m.group(1) + "=***", text)


def stat_or_none(path):
    try:
        return os.lstat(path)
    except OSError:
        return None


def excluded(path, platform, home):
    """Returns why a place is never scanned or touched, or None."""
    if platform == "wsl" and (path == "/mnt" or path.startswith("/mnt/")):
        return "Windows drive"
    for d in SYNC_DIRS:
        base = os.path.join(home, d)
        if path == base or path.startswith(base + "/"):
            return "sync folder"
    if os.path.dirname(path) == home:
        name = os.path.basename(path)
        if name.startswith(("Dropbox", "OneDrive", "Google Drive")):
            return "sync folder"
    return None


# --- sizes ----------------------------------------------------------------------------------

def du_sizes(ctx, paths, deadline=None):
    """Measures folders with du at the lowest I/O priority. Returns {path: bytes}."""
    out = {}
    paths = [p for p in paths if p]
    prefix = []
    if ctx.mac and shutil.which("taskpolicy"):
        prefix = ["taskpolicy", "-b"]
    elif not ctx.mac and shutil.which("ionice"):
        prefix = ["ionice", "-c3"]
    for i in range(0, len(paths), 40):
        if deadline is not None and time.time() > deadline:
            break
        chunk = paths[i:i + 40]
        # One du over a large tree can outlast the time limit, so it gets only the time left.
        timeout = 600 if deadline is None else max(1, deadline - time.time())
        _, stdout, _ = run(prefix + ["du", "-sk"] + chunk, timeout=timeout)
        for line in stdout.splitlines():
            kb, _, p = line.partition("\t")
            if p and kb.strip().isdigit():
                out[p] = int(kb.strip()) * 1024
    return out


# --- processes ------------------------------------------------------------------------------

def cputime(text):
    days = 0
    if "-" in text:
        d, _, text = text.partition("-")
        days = int(d) if d.isdigit() else 0
    total = 0.0
    for part in text.split(":"):
        try:
            total = total * 60 + float(part)
        except ValueError:
            return 0.0
    return days * 86400 + total


def read_procs():
    """Returns {pid: process} from ps, or {} when ps cannot run."""
    _, stdout, _ = run(["ps", "axww", "-o", "pid=,ppid=,user=,tty=,rss=,time=,lstart=,args="], timeout=30)
    procs = {}
    for line in stdout.splitlines():
        parts = line.split(None, 11)
        if len(parts) < 12 or not parts[0].isdigit() or not parts[1].isdigit():
            continue
        pid, ppid, user, tty, rss, cpu = parts[:6]
        args = parts[11].strip()
        tty = None if tty in ("??", "?", "-") else tty
        procs[int(pid)] = {
            "pid": int(pid), "ppid": int(ppid), "user": user, "tty": tty,
            "rss": int(rss) * 1024 if rss.isdigit() else 0, "cpu_time": cputime(cpu),
            "lstart": " ".join(parts[6:11]), "args": args, "base": exe_name(args),
        }
    return procs


def exe_name(args):
    """The executable's file name. ps prints the command line with spaces unquoted, so a path such
    as "/Applications/T3 Code.app/Contents/MacOS/T3 Code --flag" is cut at its first space. When the
    first word stops before /Contents/MacOS/, the name is read from there up to the first option."""
    tokens = args.split()
    if not tokens:
        return ""
    mark = "/Contents/MacOS/"
    if mark in args and mark not in tokens[0]:
        rest = args[args.index(mark) + len(mark):]
        return re.split(r"\s+-", rest, 1)[0].strip()
    # A process that sets its own title, such as a PostgreSQL backend ("postgres: user db"), ends the name with a colon.
    return os.path.basename(tokens[0]).rstrip(":")


def started_at(lstart):
    try:
        return iso(time.mktime(time.strptime(lstart, "%a %b %d %H:%M:%S %Y")))
    except ValueError:
        return lstart


def is_agent(proc):
    tokens = proc["args"].split()
    if not tokens:
        return False
    first = proc["base"].lower()
    if first in AGENTS:
        return True
    if first in ("node", "bun", "deno") and len(tokens) > 1:
        segments = [s.lower() for s in tokens[1].split("/")]
        return any(s == a or s.startswith(a + "-") for s in segments for a in AGENTS)
    return False


def ancestors(procs, pid):
    seen, chain = set(), []
    cur = procs.get(pid)
    while cur and cur["ppid"] in procs and cur["ppid"] not in seen and cur["ppid"] > 1:
        seen.add(cur["ppid"])
        cur = procs[cur["ppid"]]
        chain.append(cur)
    return chain


def self_chain(procs):
    pids = {os.getpid(), os.getppid()}
    for p in ancestors(procs, os.getpid()):
        pids.add(p["pid"])
    return pids


def app_bundle(args):
    m = re.match(r"(/.+?\.app)/Contents/", args)
    return m.group(1) if m else None


def app_name(args):
    """The app a process's row is named after: the bundle that holds its executable, or the outer app
    when that bundle is a helper inside the app's Contents/Frameworks (an Electron renderer)."""
    i = args.find("/Contents/MacOS/")
    if i < 0:
        return None
    bundle, outer = args[:i], app_bundle(args)
    if outer and bundle.startswith(outer + "/Contents/Frameworks/"):
        bundle = outer
    return os.path.splitext(os.path.basename(bundle))[0]


class AgentUse:
    """What live agent sessions depend on besides their own descendants: the processes they run
    under, the apps those processes belong to, and the git projects they work in. Ending an app's
    helper or a dev server in such a project can end or break a session."""

    def __init__(self, ctx, procs, cwds):
        self.ctx, self.cwd = ctx, dict(cwds)
        self.hosts, self.apps, self.projects = {}, {}, {}
        agents = {pid: p for pid, p in procs.items() if is_agent(p)}
        for p in agents.values():
            for a in ancestors(procs, p["pid"]):
                self.hosts.setdefault(a["pid"], p)
                app = app_bundle(a["args"])
                if app:
                    self.apps.setdefault(app, p)
        for pid in agents:
            repo = self.project(pid)
            if repo:
                self.projects.setdefault(repo, agents[pid])

    def project(self, pid):
        cwd = self.cwd.get(pid)
        return find_repo(self.ctx, os.path.join(cwd, ".")) if cwd else None


def process_lock(procs, proc, use):
    if is_agent(proc):
        return "is a live agent session"
    for a in ancestors(procs, proc["pid"]):
        if is_agent(a):
            return "runs under a live agent session (%s, pid %d)" % (a["base"], a["pid"])
    agent = use.hosts.get(proc["pid"])
    if agent:
        return "a live agent session runs under it (%s, pid %d)" % (agent["base"], agent["pid"])
    app = app_bundle(proc["args"])
    agent = use.apps.get(app) if app else None
    if agent:
        return "belongs to %s, which a live agent session runs in (%s, pid %d)" % (
            os.path.basename(app)[:-4], agent["base"], agent["pid"])
    agent = use.projects.get(use.project(proc["pid"]))
    if agent:
        return "works in a project a live agent session works in (%s, pid %d)" % (agent["base"], agent["pid"])
    if proc["tty"]:
        return "runs in an open terminal (%s)" % proc["tty"]
    first = proc["args"].split()[0] if proc["args"].split() else ""
    if first.startswith(("/System/", "/usr/libexec/", "/usr/sbin/", "/sbin/", "/usr/lib/systemd/")):
        return "part of the operating system"
    return None


def dev_label(args):
    for rx, label in DEV_RES:
        if rx.search(args):
            return label
    return None


def working_dirs(ctx):
    """Returns [(pid, cwd)] for the user's running processes."""
    found = []
    if ctx.mac:
        _, stdout, _ = run(["lsof", "-nP", "-a", "-u", str(ctx.uid), "-d", "cwd", "-Fpn"], timeout=30)
        pid = None
        for line in stdout.splitlines():
            if line.startswith("p") and line[1:].isdigit():
                pid = int(line[1:])
            elif line.startswith("n") and pid is not None:
                found.append((pid, line[1:]))
        return found
    try:
        names = os.listdir("/proc")
    except OSError:
        return found
    for name in names:
        if not name.isdigit():
            continue
        try:
            if os.stat("/proc/" + name).st_uid != ctx.uid:
                continue
            found.append((int(name), os.readlink("/proc/%s/cwd" % name)))
        except OSError:
            continue
    return found


def folder_lock(root, cwds, procs):
    if not root:
        return None
    for pid, cwd in cwds:
        if cwd == root or cwd.startswith(root + "/"):
            p = procs.get(pid)
            name = p["base"] if p else "a program"
            return "a running program works in this project (%s, pid %d)" % (name, pid)
    return None


# --- items ----------------------------------------------------------------------------------

def disk_item(category, kind, name, path, size, rebuilt, action, command=None, locked=None, detail=None, label=None):
    """One disk row. A name the script makes also gets a label, {"key": ..., "vars": {...}}, which the
    page looks up in its dictionary; the English name stays for apply's output and the agent."""
    st = stat_or_none(path) if path else None
    it = {
        "id": item_id("d", category, kind, path or name), "group": "disk", "category": category, "kind": kind,
        "name": name, "path": path, "size": size, "rebuilt": rebuilt, "action": action, "command": command,
        "locked": locked, "detail": detail or {},
        "fingerprint": {"size": size, "mtime": st.st_mtime if st else None, "ino": st.st_ino if st else None},
    }
    if label:
        it["label"] = label
    return it


def name_key(prefix, kind):
    return {"key": "%s_%s" % (prefix, kind.replace("-", "_"))}


def cache_specs(ctx):
    h, env, cache = ctx.h, os.environ.get, ctx.cache_root()
    gopath = env("GOPATH") or h("go")
    cargo = env("CARGO_HOME") or h(".cargo")
    pip = ["pip", "cache", "purge"] if shutil.which("pip") or not shutil.which("pip3") else ["pip3", "cache", "purge"]
    specs = [
        ("npm", "npm cache", os.path.join(env("npm_config_cache") or env("NPM_CONFIG_CACHE") or h(".npm"), "_cacache"),
         ["npm", "cache", "clean", "--force"], "npm"),
        ("pnpm", "pnpm store", env("PNPM_STORE_DIR") or (h("Library", "pnpm", "store") if ctx.mac else os.path.join(ctx.data_root(), "pnpm", "store")),
         ["pnpm", "store", "prune"], "pnpm"),
        ("yarn", "Yarn cache", env("YARN_CACHE_FOLDER") or os.path.join(cache, "Yarn" if ctx.mac else "yarn"),
         ["yarn", "cache", "clean"], "yarn"),
        ("yarn-berry", "Yarn Berry cache", h(".yarn", "berry", "cache"), None, "yarn"),
        ("bun", "Bun cache", env("BUN_INSTALL_CACHE_DIR") or os.path.join(env("BUN_INSTALL") or h(".bun"), "install", "cache"),
         ["bun", "pm", "cache", "rm"], "bun"),
        ("pip", "pip cache", env("PIP_CACHE_DIR") or os.path.join(cache, "pip"), pip, "pip"),
        ("uv", "uv cache", env("UV_CACHE_DIR") or os.path.join(env("XDG_CACHE_HOME") or h(".cache"), "uv"),
         ["uv", "cache", "clean"], "uv"),
        ("homebrew", "Homebrew downloads", env("HOMEBREW_CACHE") or os.path.join(cache, "Homebrew"),
         ["brew", "cleanup", "--prune=all"], "brew"),
        ("cargo", "Cargo downloads", os.path.join(cargo, "registry", "cache"), None, "cargo"),
        ("cargo-sources", "Cargo unpacked sources", os.path.join(cargo, "registry", "src"), None, "cargo"),
        ("cargo-git", "Cargo git checkouts", os.path.join(cargo, "git", "checkouts"), None, "cargo"),
        ("go-modules", "Go module cache", env("GOMODCACHE") or os.path.join(gopath, "pkg", "mod"),
         ["go", "clean", "-modcache"], "go"),
        ("go-build", "Go build cache", env("GOCACHE") or os.path.join(cache, "go-build"), ["go", "clean", "-cache"], "go"),
        ("gradle", "Gradle caches", os.path.join(env("GRADLE_USER_HOME") or h(".gradle"), "caches"), None, "java"),
        ("maven", "Maven repository", h(".m2", "repository"), None, "mvn"),
    ]
    if ctx.mac:
        dev = h("Library", "Developer")
        specs += [
            ("cocoapods", "CocoaPods cache", os.path.join(cache, "CocoaPods"), ["pod", "cache", "clean", "--all"], "pod"),
            ("xcode-derived-data", "Xcode DerivedData", os.path.join(dev, "Xcode", "DerivedData"), None, "xcodebuild"),
            ("xcode-device-support", "Xcode iOS device support", os.path.join(dev, "Xcode", "iOS DeviceSupport"), None, None),
            ("xcode-watch-support", "Xcode watchOS device support", os.path.join(dev, "Xcode", "watchOS DeviceSupport"), None, None),
            ("simulator-caches", "Simulator caches", os.path.join(dev, "CoreSimulator", "Caches"), None, None),
        ]
    return specs


def running_bases(procs):
    return {p["base"].lower() for p in procs.values()}


def busy_tools(procs):
    """Tools running something other than a dev server (an install or a build uses their cache)."""
    return {p["base"].lower() for p in procs.values() if not dev_label(p["args"])}


def scan_caches(ctx, procs, deadline, skipped):
    items, wanted = [], []
    bases = busy_tools(procs)
    for kind, name, path, command, tool in cache_specs(ctx):
        if time.time() > deadline:
            skipped.append({"path": path, "reason": "time limit"})
            continue
        st = stat_or_none(path)
        if st is None:
            continue
        if os.path.islink(path):
            skipped.append({"path": path, "reason": "symbolic link"})
            continue
        if excluded(path, ctx.platform, ctx.home):
            continue
        wanted.append((kind, name, path, command, tool))
    sizes = du_sizes(ctx, [w[2] for w in wanted], deadline)
    for kind, name, path, command, tool in wanted:
        size = sizes.get(path)
        if size is None:
            skipped.append({"path": path, "reason": "time limit" if time.time() > deadline else "could not be measured"})
            continue
        if size < BUILD_MIN:
            continue
        lock = ("%s is running" % tool) if tool and tool.lower() in bases else None
        items.append(disk_item("cache", kind, name, path, size, True, "tool" if command else "delete", command, lock,
                               label=name_key("cache", kind)))
    return items


def scan_app_caches(ctx, procs, running_ids, deadline, skipped):
    root = ctx.cache_root()
    try:
        entries = sorted(os.scandir(root), key=lambda e: e.name)
    except OSError:
        return []
    candidates = []
    for e in entries:
        # Models are listed on their own, since they take long to download again.
        if e.name in COVERED_CACHES or e.name in MODEL_CACHES or e.name.startswith(("com.apple.", ".")):
            continue
        if e.is_symlink():
            skipped.append({"path": e.path, "reason": "symbolic link"})
            continue
        if e.is_dir(follow_symlinks=False):
            candidates.append(e.path)
    if time.time() > deadline:
        skipped.extend({"path": p, "reason": "time limit"} for p in candidates)
        return []
    sizes = du_sizes(ctx, candidates, deadline)
    bases = running_bases(procs)
    items = []
    for path in candidates:
        size = sizes.get(path)
        if size is None or size < APP_CACHE_MIN:
            continue
        name = os.path.basename(path)
        lock = "the app is running" if (name in running_ids or name.lower() in bases) else None
        items.append(disk_item("cache", "app-cache", name, path, size, True, "delete", None, lock))
    return items


def docker_size(text):
    m = re.match(r"\s*([0-9.]+)\s*([kKMGT]?B)", text or "")
    if not m:
        return 0
    mult = {"B": 1, "kB": 1e3, "KB": 1e3, "MB": 1e6, "GB": 1e9, "TB": 1e12}[m.group(2)]
    return int(float(m.group(1)) * mult)


def docker_reclaimable():
    rc, stdout, _ = run(["docker", "system", "df", "--format", "{{json .}}"], timeout=60)
    if rc != 0:
        return None
    out = {}
    for line in stdout.splitlines():
        try:
            row = json.loads(line)
        except ValueError:
            continue
        out[row.get("Type", "")] = docker_size(row.get("Reclaimable", ""))
    return out


def scan_docker(ctx, deadline, skipped):
    if not shutil.which("docker"):
        return []
    if time.time() > deadline:
        skipped.append({"path": "docker", "reason": "time limit"})
        return []
    rec = docker_reclaimable()
    if rec is None:
        skipped.append({"path": "docker", "reason": "Docker is not running"})
        return []
    items = []
    for kind, typ, name, command in (
            ("docker-images", "Images", "Docker images no container uses", ["docker", "image", "prune", "-a", "-f"]),
            ("docker-build-cache", "Build Cache", "Docker build cache", ["docker", "builder", "prune", "-a", "-f"]),
            ("docker-stopped-containers", "Containers", "Stopped Docker containers", ["docker", "container", "prune", "-f"])):
        size = rec.get(typ, 0)
        if size >= BUILD_MIN:
            it = disk_item("cache", kind, name, None, size, True, "tool", command, label=name_key("cache", kind))
            it["id"] = item_id("d", "cache", kind)
            items.append(it)
    return items


def trash_dir(ctx):
    return ctx.h(".Trash") if ctx.mac else os.path.join(ctx.data_root(), "Trash")


def scan_trash_logs_installers(ctx, deadline, skipped):
    items = []
    cutoff = ctx.now - OLD_DAYS * 86400
    if time.time() > deadline:
        skipped.append({"path": trash_dir(ctx), "reason": "time limit"})
        return items
    trash = trash_dir(ctx)
    if os.path.isdir(trash) and not os.path.islink(trash):
        try:
            names = os.listdir(trash)
            if [n for n in names if n != ".DS_Store"]:
                size = du_sizes(ctx, [trash], deadline).get(trash)
                if size:
                    items.append(disk_item("trash", "trash", "Trash", trash, size, False, "empty-trash", label={"key": "trash"}))
        except PermissionError:
            skipped.append({"path": trash, "reason": "macOS needs Full Disk Access for this terminal app to read the Trash"})
    log_roots = [ctx.h("Library", "Logs")] if ctx.mac else [os.environ.get("XDG_STATE_HOME") or ctx.h(".local", "state")]
    for root in log_roots:
        groups = {}
        for dirpath, dirnames, filenames in os.walk(root):
            if time.time() > deadline:
                skipped.append({"path": dirpath, "reason": "time limit"})
                break
            dirnames[:] = [d for d in dirnames if not os.path.islink(os.path.join(dirpath, d))]
            for fn in filenames:
                p = os.path.join(dirpath, fn)
                st = stat_or_none(p)
                if not st or os.path.islink(p) or st.st_mtime > cutoff:
                    continue
                if not ctx.mac and not (fn.endswith(LOG_EXTS) or ".log." in fn):
                    continue
                rel = os.path.relpath(p, root).split(os.sep)
                group = os.path.join(root, rel[0]) if len(rel) > 1 else root
                groups.setdefault(group, []).append((p, st.st_size))
        for group, files in sorted(groups.items()):
            size = sum(s for _, s in files)
            app = os.path.basename(group)
            name, label = ("Logs", {"key": "logs"}) if group == root else (app + " logs", {"key": "app_logs", "vars": {"app": app}})
            items.append(disk_item("log", "old-logs", name, group, size, False, "delete-files",
                                   detail={"files": [p for p, _ in files][:500], "file_count": len(files),
                                           "older_than_days": OLD_DAYS}, label=label))
    downloads = ctx.h("Downloads")
    try:
        entries = list(os.scandir(downloads))
    except OSError:
        entries = []
    for e in entries:
        if e.is_symlink() or not e.name.lower().endswith(INSTALLER_EXTS):
            continue
        st = stat_or_none(e.path)
        if st and st.st_mtime <= cutoff:
            size = st.st_size if e.is_file(follow_symlinks=False) else du_sizes(ctx, [e.path]).get(e.path)
            items.append(disk_item("installer", "installer", e.name, e.path, size, False, "trash",
                                   detail={"modified": iso(st.st_mtime)}))
    return items


def iso(ts):
    return datetime.datetime.fromtimestamp(ts, datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def app_info(app):
    try:
        with open(os.path.join(app, "Contents", "Info.plist"), "rb") as f:
            info = plistlib.load(f)
        return info.get("CFBundleIdentifier"), info.get("CFBundleName") or os.path.splitext(os.path.basename(app))[0]
    except Exception:
        return None, None


def last_used(app):
    rc, stdout, _ = run(["mdls", "-raw", "-name", "kMDItemLastUsedDate", app], timeout=20)
    text = stdout.strip()
    if rc != 0 or not text or text == "(null)":
        return None
    try:
        return datetime.datetime.strptime(text, "%Y-%m-%d %H:%M:%S %z").timestamp()
    except ValueError:
        return None


def support_files(ctx, bundle_id, name):
    lib = ctx.h("Library")
    found = []
    for p in (os.path.join(lib, "Application Support", bundle_id), os.path.join(lib, "Caches", bundle_id),
              os.path.join(lib, "Preferences", bundle_id + ".plist"), os.path.join(lib, "Containers", bundle_id),
              os.path.join(lib, "Saved Application State", bundle_id + ".savedState"),
              os.path.join(lib, "HTTPStorages", bundle_id), os.path.join(lib, "WebKit", bundle_id),
              os.path.join(lib, "Application Support", name), os.path.join(lib, "Logs", name)):
        if p not in found and stat_or_none(p) and not os.path.islink(p):
            found.append(p)
    return found


def running_apps(procs):
    apps = set()
    for p in procs.values():
        m = re.match(r"(/.+?\.app)/Contents/", p["args"])
        if m:
            apps.add(m.group(1))
    return apps


def scan_apps(ctx, procs, apps_dirs, deadline, skipped):
    items = []
    if ctx.mac:
        running = running_apps(procs)
        cutoff = ctx.now - APP_UNUSED_DAYS * 86400
        found = []
        for d in apps_dirs:
            try:
                entries = sorted(os.scandir(d), key=lambda e: e.name)
            except OSError:
                continue
            for e in entries:
                if not e.name.endswith(".app") or e.is_symlink() or not e.is_dir(follow_symlinks=False):
                    continue
                if time.time() > deadline:
                    skipped.append({"path": e.path, "reason": "time limit"})
                    continue
                bid, name = app_info(e.path)
                if not bid or bid.startswith("com.apple.") or not os.access(e.path, os.W_OK) or not os.access(d, os.W_OK):
                    continue
                used = last_used(e.path)
                if used is None or used > cutoff:
                    continue
                found.append((e.path, bid, name, used))
        sizes = du_sizes(ctx, [f[0] for f in found], deadline)
        for path, bid, name, used in found:
            support = support_files(ctx, bid, name)
            size = (sizes.get(path) or 0) + sum(du_sizes(ctx, support).values()) if support else sizes.get(path)
            lock = "the app is running" if path in running else None
            it = disk_item("app", "mac-app", name, path, size, False, "trash-app", None, lock,
                           {"bundle_id": bid, "last_used": iso(used), "support": support})
            # The size shown counts the support files; the check before acting measures the app alone.
            it["fingerprint"]["size"] = sizes.get(path)
            items.append(it)
        return items
    if not shutil.which("flatpak"):
        return items
    rc, stdout, _ = run(["flatpak", "list", "--user", "--app", "--columns=application,name,size"], timeout=60)
    for line in stdout.splitlines() if rc == 0 else []:
        cols = line.split("\t")
        if len(cols) < 3 or not cols[0]:
            continue
        appid, name, size = cols[0].strip(), cols[1].strip(), cols[2].strip()
        data = ctx.h(".var", "app", appid)
        st = stat_or_none(data)
        m = re.match(r"([0-9.]+)\s*([kMGT]?B)", size.replace(" ", " "))
        nbytes = int(float(m.group(1)) * {"B": 1, "kB": 1e3, "MB": 1e6, "GB": 1e9, "TB": 1e12}[m.group(2)]) if m else None
        it = disk_item("app", "flatpak", name, None, nbytes, False, "tool", ["flatpak", "uninstall", "--user", "-y", appid],
                       detail={"app_id": appid, "last_used": iso(st.st_mtime) if st else None, "support": []})
        it["id"] = item_id("d", "app", "flatpak", appid)
        items.append(it)
    return items


def scan_home(ctx, roots, procs, cwds, deadline, skipped, found):
    """Walks the roots for build output in git projects, large files, and duplicates. It also fills
    found with the git repositories it met, the files where projects name tool versions, and whether
    the walk ended before the time limit."""
    found.update({"repos": [], "version_files": [], "complete": False})
    build, files = [], []
    stack = []
    for r in roots:
        r = os.path.abspath(os.path.expanduser(r))
        why = excluded(r, ctx.platform, ctx.home)
        if why:
            skipped.append({"path": r, "reason": why})
            continue
        if not os.path.isdir(r):
            skipped.append({"path": r, "reason": "not found"})
            continue
        stack.append((r, 0, None, 0))
    skip_top = {"Library", "Applications"} if ctx.mac else set()
    cut = False
    while stack:
        if time.time() > deadline:
            skipped.extend({"path": s[0], "reason": "time limit"} for s in stack[:50])
            cut = True
            break
        path, depth, repo, repo_depth = stack.pop()
        try:
            entries = list(os.scandir(path))
        except OSError:
            continue
        if repo is None and any(e.name == ".git" for e in entries):
            repo, repo_depth = path, 0
            found["repos"].append(path)
        for e in entries:
            if e.is_symlink():
                continue
            if e.is_dir(follow_symlinks=False):
                if e.name == ".git" or excluded(e.path, ctx.platform, ctx.home):
                    continue
                if path == ctx.home and e.name in skip_top:
                    continue
                if repo is not None and e.name in BUILD_NAMES and repo_depth < REPO_DEPTH:
                    build.append((repo, e.path))
                    continue
                if e.name.startswith(".") and repo is None:
                    continue
                if e.name.startswith(".") and repo is not None:
                    continue
                if depth + 1 <= WALK_DEPTH:
                    stack.append((e.path, depth + 1, repo, repo_depth + 1 if repo else 0))
            elif e.is_file(follow_symlinks=False):
                if e.name in VERSION_FILES:
                    found["version_files"].append(e.path)
                try:
                    st = e.stat(follow_symlinks=False)
                except OSError:
                    continue
                if st.st_size >= DUPLICATE_MIN:
                    files.append((e.path, st.st_size, st.st_dev, st.st_ino, repo))
    found["complete"] = not cut
    items = []
    # Build output counts only when git ignores it and it holds no tracked file.
    keep = []
    for repo, path in build:
        if time.time() > deadline:
            skipped.append({"path": path, "reason": "time limit"})
            continue
        rel = os.path.relpath(path, repo)
        rc, _, _ = run(["git", "-C", repo, "check-ignore", "-q", "--", rel + "/"], timeout=30)
        if rc != 0:
            continue
        _, tracked, _ = run(["git", "-C", repo, "ls-files", "--", rel], timeout=60)
        if tracked.strip():
            continue
        keep.append((repo, path))
    sizes = du_sizes(ctx, [p for _, p in keep], deadline)
    for repo, path in keep:
        size = sizes.get(path)
        if size is None:
            skipped.append({"path": path, "reason": "time limit"})
            continue
        if size < BUILD_MIN:
            continue
        folder, project = os.path.basename(path), os.path.basename(repo)
        items.append(disk_item("build", folder, "%s in %s" % (folder, project), path, size, True, "delete", None,
                               folder_lock(repo, cwds, procs), {"project": repo},
                               label={"key": "build", "vars": {"folder": folder, "project": project}}))
    # Duplicates: same size, then the same first 64 KiB, then the same full hash.
    by_size = {}
    for f in files:
        by_size.setdefault(f[1], []).append(f)
    dup_paths = set()
    for size, group in sorted(by_size.items(), reverse=True):
        uniq = {}
        for f in group:
            uniq.setdefault((f[2], f[3]), f)
        group = list(uniq.values())
        if len(group) < 2:
            continue
        if time.time() > deadline:
            skipped.append({"path": group[0][0], "reason": "time limit"})
            continue
        sets = {}
        for f in group:
            h = file_hash(f[0], 65536)
            if h:
                sets.setdefault(h, []).append(f)
        for members in sets.values():
            if len(members) < 2:
                continue
            full = {}
            for f in members:
                if time.time() > deadline:
                    break
                h = file_hash(f[0])
                if h:
                    full.setdefault(h, []).append(f)
            for h, same in full.items():
                if len(same) < 2:
                    continue
                copies = sorted(f[0] for f in same)
                for f in same:
                    dup_paths.add(f[0])
                    items.append(disk_item("duplicate", "duplicate", os.path.basename(f[0]), f[0], size, False, "trash", None,
                                           folder_lock(f[4], cwds, procs), {"set": h[:12], "copies": copies}))
    for path, size, _, _, repo in files:
        if size >= LARGE_FILE and path not in dup_paths:
            items.append(disk_item("large", "large-file", os.path.basename(path), path, size, False, "trash", None,
                                   folder_lock(repo, cwds, procs)))
    return items


# --- unused projects, app leftovers, tool versions, and models -------------------------------

def project_state(repo, now, deadline=None):
    """Returns (why the repository is not an idle project or None, when it was last used or None).
    It reads only what git keeps on disk: whether a branch is on the remote is judged from the
    remote-tracking refs of the last fetch, and nothing connects to the remote."""
    gitdir = os.path.join(repo, ".git")
    if not os.path.isdir(gitdir) or os.path.islink(gitdir):
        return "a worktree of another repository", None
    try:
        if os.listdir(os.path.join(gitdir, "worktrees")):
            return "has another worktree", None
    except OSError:
        pass
    touched = [st.st_mtime for st in (stat_or_none(os.path.join(gitdir, "HEAD")), stat_or_none(os.path.join(gitdir, "logs", "HEAD"))) if st]
    rc, out, _ = git(repo, "log", "-1", "--branches", "--format=%ct", deadline=deadline)
    if not touched or rc != 0 or not out.strip().isdigit():
        return "git could not tell when it was last used", None
    last = max(touched + [int(out.strip())])
    if now - last <= OLD_DAYS * 86400:
        return "a commit or checkout in the last %d days" % OLD_DAYS, last
    rc, out, _ = git(repo, "status", "--porcelain", "--untracked-files=normal", deadline=deadline)
    if rc != 0 or out.strip():
        return "uncommitted changes or untracked files", last
    rc, out, _ = git(repo, "remote", deadline=deadline)
    if rc != 0 or not out.strip():
        return "no remote", last
    rc, out, _ = git(repo, "rev-list", "-1", "HEAD", "--branches", "--not", "--remotes", deadline=deadline)
    if rc != 0 or out.strip():
        return "commits that are not on the remote", last
    return None, last


def scan_projects(ctx, repos, procs, cwds, deadline, skipped):
    """Git projects whose last commit and checkout are older than 30 days, with nothing uncommitted
    and every commit on the remote."""
    idle = []
    for repo in repos:
        if time.time() > deadline:
            skipped.append({"path": repo, "reason": "time limit"})
            continue
        why, last = project_state(repo, ctx.now, deadline)
        if why is None:
            idle.append((repo, last))
    sizes = du_sizes(ctx, [r for r, _ in idle], deadline)
    items = []
    for repo, last in idle:
        size = sizes.get(repo)
        if size is None:
            skipped.append({"path": repo, "reason": "time limit"})
            continue
        items.append(disk_item("project", "git-project", os.path.basename(repo), repo, size, False, "trash", None,
                               folder_lock(repo, cwds, procs), {"project": repo, "last_used": iso(last)}))
    return items


def newest_mtime(path):
    """The newest modification time of a file, or of the files in a folder, or None when the folder
    holds more files than LEFTOVER_WALK_MAX and its age cannot be told."""
    st = stat_or_none(path)
    if st is None or not os.path.isdir(path) or os.path.islink(path):
        return st.st_mtime if st else None
    newest, n = None, 0
    for dirpath, dirnames, filenames in os.walk(path):
        dirnames[:] = [d for d in dirnames if not os.path.islink(os.path.join(dirpath, d))]
        n += len(dirnames)
        for fn in filenames:
            n += 1
            if n > LEFTOVER_WALK_MAX:
                return None
            fst = stat_or_none(os.path.join(dirpath, fn))
            if fst and (newest is None or fst.st_mtime > newest):
                newest = fst.st_mtime
    return newest if newest is not None else st.st_mtime


def installed_apps(apps_dirs, procs):
    """The bundle ids and lowercase names of the apps in the app folders, one level of subfolders,
    and the running apps."""
    ids, names = set(), set()

    def add(app):
        bid, name = app_info(app)
        if bid:
            ids.add(bid.lower())
        if name:
            names.add(name.lower())
        names.add(os.path.splitext(os.path.basename(app))[0].lower())
    for d in apps_dirs:
        try:
            entries = list(os.scandir(d))
        except OSError:
            continue
        for e in entries:
            if e.name.endswith(".app"):
                add(e.path)
            elif e.is_dir(follow_symlinks=False) and not e.name.startswith("."):
                try:
                    for sub in os.scandir(e.path):
                        if sub.name.endswith(".app"):
                            add(sub.path)
                except OSError:
                    pass
    for app in running_apps(procs):
        add(app)
    return ids, names


def company(bundle_id):
    return ".".join(bundle_id.lower().split(".")[:2])


def scan_leftovers(ctx, procs, apps_dirs, listed, deadline, skipped):
    """Files that removed apps left in the Library folders on macOS: one row per bundle id whose
    company matches no installed or running app, whose other parts match no running process, and
    whose newest file is older than 30 days. Names that are not bundle ids are left out, since they
    cannot be told apart from the system's own folders and command-line tools."""
    if not ctx.mac:
        return []
    ids, names = installed_apps(apps_dirs, procs)
    companies = {company(b) for b in ids}
    words = names | {p["base"].lower() for p in procs.values()}
    cutoff = ctx.now - OLD_DAYS * 86400
    groups, order, unknown = {}, [], set()
    cut = False
    for place in LEFTOVER_PLACES:
        root = ctx.h("Library", place)
        if cut or time.time() > deadline:
            # A bundle id's files in a place not read may be recent, so nothing is listed.
            if os.path.isdir(root):
                skipped.append({"path": root, "reason": "time limit"})
            cut = True
            continue
        try:
            entries = sorted(os.scandir(root), key=lambda e: e.name)
        except OSError:
            continue
        for e in entries:
            name = e.name
            for suffix in (".plist", ".savedState"):
                if name.endswith(suffix):
                    name = name[:-len(suffix)]
            key = name.lower()
            if (not BUNDLE_ID_RE.match(name) or any(GENERATED_PART_RE.match(part) for part in name.split("."))
                    or key.startswith("com.apple.") or e.is_symlink() or e.path in listed):
                continue
            if company(name) in companies or any(part in words for part in key.split(".")[2:]):
                continue
            if time.time() > deadline:
                skipped.append({"path": root, "reason": "time limit"})
                cut = True
                break
            newest = newest_mtime(e.path)
            if newest is None:
                skipped.append({"path": e.path, "reason": "too many files to tell its age"})
                unknown.add(key)
                continue
            if key not in groups:
                groups[key] = {"name": name, "paths": [], "newest": newest}
                order.append(key)
            groups[key]["paths"].append(e.path)
            groups[key]["newest"] = max(groups[key]["newest"], newest)
    if cut:
        return []
    keep = [groups[k] for k in order if k not in unknown and groups[k]["newest"] <= cutoff]
    sizes = du_sizes(ctx, [p for g in keep for p in g["paths"]], deadline)
    items = []
    for g in keep:
        first, rest = g["paths"][0], g["paths"][1:]
        if any(sizes.get(p) is None for p in g["paths"]):
            skipped.append({"path": first, "reason": "time limit"})
            continue
        it = disk_item("app", "leftover", g["name"], first, sum(sizes[p] for p in g["paths"]), False, "trash-app", None, None,
                       {"bundle_id": g["name"], "last_used": iso(g["newest"]), "support": rest})
        # The check before acting measures the first place alone.
        it["fingerprint"]["size"] = sizes[first]
        items.append(it)
    return items


def version_roots(ctx):
    """Where each version manager keeps its versions: (manager, folder of versions or of tools, how
    the folder is laid out)."""
    env, h = os.environ.get, ctx.h
    fnm = env("FNM_DIR") or (h("Library", "Application Support", "fnm") if ctx.mac else os.path.join(ctx.data_root(), "fnm"))
    return [
        ("nvm", os.path.join(env("NVM_DIR") or h(".nvm"), "versions", "node"), "node"),
        ("fnm", os.path.join(fnm, "node-versions"), "node"),
        ("pyenv", os.path.join(env("PYENV_ROOT") or h(".pyenv"), "versions"), "python"),
        ("rbenv", os.path.join(env("RBENV_ROOT") or h(".rbenv"), "versions"), "ruby"),
        ("asdf", os.path.join(env("ASDF_DATA_DIR") or h(".asdf"), "installs"), None),
        ("mise", os.path.join(env("MISE_DATA_DIR") or os.path.join(ctx.data_root(), "mise"), "installs"), None),
        ("rustup", os.path.join(env("RUSTUP_HOME") or h(".rustup"), "toolchains"), "rust"),
    ]


def real_dirs(path):
    """The folders in a folder, by name, without links and hidden folders."""
    try:
        return sorted((e for e in os.scandir(path) if e.is_dir(follow_symlinks=False) and not e.name.startswith(".")),
                      key=lambda e: e.name)
    except OSError:
        return []


def tool_key(name):
    """The folder name a tool's versions live under, from the name a version file uses. mise keeps
    "npm:@pen.dev/cli" in npm-pen-dev-cli and "core:node" in node; asdf calls Node.js nodejs."""
    name = name.strip()
    if name.startswith("core:"):
        name = name[len("core:"):]
    if ":" in name:
        name = re.sub(r"[:/.]", "-", name).replace("@", "")
    return TOOL_NAMES.get(name, name)


def installed_versions(ctx):
    """Yields (manager, tool, version, path) for each version folder. Links are aliases, not versions."""
    for manager, root, tool in version_roots(ctx):
        if tool:
            for e in real_dirs(root):
                version = e.name[1:] if manager in ("nvm", "fnm") and e.name.startswith("v") else e.name
                yield manager, tool, version, e.path
        else:
            for t in real_dirs(root):
                for e in real_dirs(t.path):
                    yield manager, tool_key(t.name), e.name, e.path


def toml_values(path):
    """{section: {key: [strings]}} from a TOML file, read with a small parser that knows only the
    forms version files use (key = "v", key = ["a", "b"], key = { version = "v" })."""
    out, section = {}, ""
    try:
        lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    except OSError:
        return out
    for line in lines:
        line = line.split("#", 1)[0].strip()
        m = re.match(r"^\[\s*([^\]]+?)\s*\]$", line)
        if m:
            section = m.group(1)
            continue
        m = re.match(r"^(\"[^\"]+\"|'[^']+'|[A-Za-z0-9_.:/@-]+)\s*=\s*(.+)$", line)
        if m:
            values = [a or b for a, b in re.findall(r"\"([^\"]*)\"|'([^']*)'", m.group(2))]
            out.setdefault(section, {})[m.group(1).strip("\"'")] = values
    return out


def first_lines(path):
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        return []
    return [l.split("#", 1)[0].strip() for l in text.splitlines() if l.split("#", 1)[0].strip()]


def file_specs(path):
    """{tool: [specs]} that one version file names."""
    name = os.path.basename(path)
    tool = VERSION_FILES[name][0]
    specs = {}
    if name == ".tool-versions":
        for line in first_lines(path):
            parts = line.split()
            if len(parts) > 1:
                specs.setdefault(tool_key(parts[0]), []).extend(parts[1:])
    elif name in ("mise.toml", ".mise.toml"):
        for key, values in toml_values(path).get("tools", {}).items():
            specs.setdefault(tool_key(key), []).extend(values)
    elif name == "rust-toolchain.toml" or (name == "rust-toolchain" and "[toolchain]" in "".join(first_lines(path))):
        specs["rust"] = toml_values(path).get("toolchain", {}).get("channel", [])
    elif name == ".python-version":
        specs[tool] = [w for l in first_lines(path) for w in l.split()]
    else:
        specs[tool] = first_lines(path)[:1]
    return specs


def default_specs(ctx):
    """{(manager, tool): [specs]} of the versions each manager uses by default, and
    {(manager, tool): [paths]} of the versions a default link points at."""
    env, h = os.environ.get, ctx.h
    specs, linked = {}, {}
    nvm = env("NVM_DIR") or h(".nvm")
    specs[("nvm", "node")] = first_lines(os.path.join(nvm, "alias", "default"))[:1]
    fnm_root = os.path.dirname(version_roots(ctx)[1][1])
    alias = os.path.join(fnm_root, "aliases", "default")
    if os.path.islink(alias):
        target = os.path.realpath(alias)
        linked[("fnm", "node")] = [os.path.dirname(target) if os.path.basename(target) == "installation" else target]
    for manager, root in (("pyenv", env("PYENV_ROOT") or h(".pyenv")), ("rbenv", env("RBENV_ROOT") or h(".rbenv"))):
        tool = "python" if manager == "pyenv" else "ruby"
        specs[(manager, tool)] = [w for l in first_lines(os.path.join(root, "version")) for w in l.split()]
    tool_versions = env("ASDF_DEFAULT_TOOL_VERSIONS_FILENAME") or h(".tool-versions")
    if os.path.exists(tool_versions):
        for tool, values in file_specs(tool_versions).items():
            specs.setdefault(("asdf", tool), []).extend(values)
            specs.setdefault(("mise", tool), []).extend(values)
    config = env("MISE_GLOBAL_CONFIG_FILE") or os.path.join(env("MISE_CONFIG_DIR") or os.path.join(env("XDG_CONFIG_HOME") or h(".config"), "mise"), "config.toml")
    for key, values in toml_values(config).get("tools", {}).items():
        specs.setdefault(("mise", tool_key(key)), []).extend(values)
    settings = toml_values(os.path.join(env("RUSTUP_HOME") or h(".rustup"), "settings.toml"))
    specs[("rustup", "rust")] = settings.get("", {}).get("default_toolchain", []) + [v for vs in settings.get("overrides", {}).values() for v in vs]
    return specs, linked


def spec_matches(spec, manager, version, path):
    """Whether a version spec names this version: the same name, a leading part of it (20 for
    20.11.1, stable for stable-aarch64-apple-darwin), or a link beside it with the spec's name."""
    s = spec.strip()
    for prefix in ("python-", "ruby-", "node-"):
        if s.startswith(prefix):
            s = s[len(prefix):]
    if s[:1] == "v" and s[1:2].isdigit():
        s = s[1:]
    if not s:
        return False
    if version == s or version.startswith(s + ".") or (manager == "rustup" and version.startswith(s + "-")):
        return True
    link = os.path.join(os.path.dirname(path), s)
    return os.path.islink(link) and os.path.realpath(link) == os.path.realpath(path)


def resolves(spec, manager, versions):
    """Whether a spec names a version or is a version number (which may name one not installed).
    A word such as lts or latest that names no installed version cannot be told."""
    s = spec.strip()
    if s in ("system", ""):
        return True
    if any(spec_matches(spec, manager, v, p) for v, p in versions):
        return True
    return bool(re.match(r"^(v|python-|ruby-|node-)?[0-9]", s))


def scan_tools(ctx, procs, version_files, complete, deadline, skipped):
    """Versions kept by nvm, fnm, pyenv, rbenv, asdf, mise, and rustup that are neither a default nor
    named by a project's version file. A version is locked when a running program uses it, when the
    default cannot be told, or when the walk ended before it read every project."""
    found = list(installed_versions(ctx))
    if not found:
        return []
    defaults, linked = default_specs(ctx)
    named = []     # (tool, spec) from projects, which keep a version of that tool in every manager
    unclear = {}   # (manager, tool) -> spec a project names that cannot be told
    for path in version_files:
        managers = VERSION_FILES[os.path.basename(path)][1]
        for tool, specs in file_specs(path).items():
            for spec in specs:
                named.append((tool, spec))
                for m in managers:
                    unclear.setdefault((m, tool), []).append(spec)
    by_key = {}
    for manager, tool, version, path in found:
        by_key.setdefault((manager, tool), []).append((version, path))
    rows = []
    for manager, tool, version, path in found:
        key = (manager, tool)
        if path in linked.get(key, []) or any(spec_matches(s, manager, version, path) for s in defaults.get(key, [])):
            continue
        if any(t == tool and spec_matches(s, manager, version, path) for t, s in named):
            continue
        lock = None
        if not complete:
            lock = "the scan stopped before it read every project's version file"
        elif any((path + "/") in p["args"] for p in procs.values()):
            lock = "a running program uses this version"
        else:
            bad = [s for s in defaults.get(key, []) if not resolves(s, manager, by_key[key])]
            if bad:
                lock = "could not tell which version is the default (%s)" % bad[0]
            else:
                bad = [s for s in unclear.get(key, []) if not resolves(s, manager, by_key[key])]
                if bad:
                    lock = "could not tell which version a project names (%s)" % bad[0]
        rows.append((manager, tool, version, path, lock))
    sizes = du_sizes(ctx, [r[3] for r in rows], deadline) if time.time() <= deadline else {}
    items = []
    for manager, tool, version, path, lock in rows:
        # A row that can be picked needs its size, which the check before acting compares with.
        if sizes.get(path) is None and lock is None:
            skipped.append({"path": path, "reason": "time limit"})
            continue
        command = ["rustup", "toolchain", "uninstall", version] if manager == "rustup" else None
        it = disk_item("tool", "tool-version", "%s %s (%s)" % (tool, version, manager), path, sizes.get(path), False,
                       "tool" if command else "delete", command, lock, {"manager": manager, "tool": tool, "version": version})
        items.append(it)
    return items


def ollama_root(ctx):
    return os.environ.get("OLLAMA_MODELS") or ctx.h(".ollama", "models")


def ollama_manifests(root):
    """{manifest path: (model name, [blob paths])} for every Ollama manifest under the root."""
    out = {}
    base = os.path.join(root, "manifests")
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [d for d in dirnames if not os.path.islink(os.path.join(dirpath, d))]
        for fn in filenames:
            path = os.path.join(dirpath, fn)
            parts = os.path.relpath(path, base).split(os.sep)
            if len(parts) != 4 or os.path.islink(path):
                continue
            data = read_json(path)
            if not isinstance(data, dict):
                continue
            registry, ns, model, tag = parts
            if registry == "registry.ollama.ai":
                name = ("%s:%s" % (model, tag)) if ns == "library" else ("%s/%s:%s" % (ns, model, tag))
            else:
                name = "%s/%s/%s:%s" % (registry, ns, model, tag)
            digests = [(data.get("config") or {}).get("digest")] + [(l or {}).get("digest") for l in data.get("layers") or []]
            blobs = []
            for d in digests:
                if isinstance(d, str) and re.match(r"^sha256:[0-9a-f]{64}$", d):
                    for candidate in (d.replace(":", "-"), d):
                        p = os.path.join(root, "blobs", candidate)
                        if os.path.lexists(p):
                            blobs.append(p)
                            break
            out[path] = (name, blobs)
    return out


def scan_models(ctx, procs, deadline, skipped):
    """Models downloaded by Ollama, into the Hugging Face cache, and by LM Studio. An Ollama model's
    size counts only the blobs no other model uses, since only those are freed."""
    env = os.environ.get
    cache = env("XDG_CACHE_HOME") or ctx.h(".cache")
    hub = env("HF_HUB_CACHE") or (os.path.join(env("HF_HOME"), "hub") if env("HF_HOME") else os.path.join(cache, "huggingface", "hub"))
    lms_roots = [ctx.h(".lmstudio", "models"), os.path.join(cache, "lm-studio", "models")]
    items, wanted = [], []
    running = {p["base"].lower() for p in procs.values()}
    o_root = ollama_root(ctx)
    for root in [o_root, hub] + lms_roots:
        if not os.path.isdir(root):
            continue
        if os.path.islink(root):
            skipped.append({"path": root, "reason": "symbolic link"})
            continue
        if time.time() > deadline:
            skipped.append({"path": root, "reason": "time limit"})
            continue
        if root == o_root:
            manifests = ollama_manifests(root)
            uses = {}
            for name, blobs in manifests.values():
                for b in set(blobs):
                    uses[b] = uses.get(b, 0) + 1
            for path, (name, blobs) in sorted(manifests.items()):
                own = sorted({b for b in blobs if uses[b] == 1})
                size = sum(st.st_size for st in map(stat_or_none, own) if st)
                it = disk_item("model", "ollama-model", name, path, size, False, "ollama", ["ollama", "rm", name], None,
                               {"downloaded": iso(os.stat(path).st_mtime), "blobs": own, "root": root})
                items.append(it)
        elif root == hub:
            for e in real_dirs(root):
                if e.name.startswith("models--"):
                    snaps = [s.stat(follow_symlinks=False).st_mtime for s in real_dirs(os.path.join(e.path, "snapshots"))]
                    wanted.append(("hf-model", e.name[len("models--"):].replace("--", "/"), e.path, max(snaps) if snaps else e.stat().st_mtime, None))
        else:
            lock = "LM Studio is running" if running & {"lm studio", "lms"} else None
            for pub in real_dirs(root):
                for e in real_dirs(pub.path):
                    wanted.append(("lmstudio-model", "%s/%s" % (pub.name, e.name), e.path, newest_mtime(e.path) or e.stat().st_mtime, lock))
    sizes = du_sizes(ctx, [w[2] for w in wanted], deadline)
    for kind, name, path, downloaded, lock in wanted:
        size = sizes.get(path)
        if size is None:
            skipped.append({"path": path, "reason": "time limit"})
            continue
        if size < BUILD_MIN:
            continue
        items.append(disk_item("model", kind, name, path, size, False, "delete", None, lock, {"downloaded": iso(downloaded)}))
    return items


def file_hash(path, limit=None):
    h = hashlib.sha256()
    try:
        with open(path, "rb") as f:
            if limit:
                h.update(f.read(limit))
            else:
                for chunk in iter(lambda: f.read(1048576), b""):
                    h.update(chunk)
    except OSError:
        return None
    return h.hexdigest()


def proc_item(category, kind, proc, label, lock, cpu, folder):
    args = redact(proc["args"])[:300]
    it = {
        "id": item_id("p", category, proc["pid"], proc["lstart"]), "group": "process", "category": category, "kind": kind,
        "name": label, "path": None, "pid": proc["pid"], "size": proc["rss"], "cpu": round(cpu, 1), "rebuilt": False,
        "action": "terminate", "command": None, "locked": lock,
        "detail": {"command": args, "started": started_at(proc["lstart"]), "terminal": proc["tty"], "folder": folder},
        # The full command can hold a secret, so only its hash is kept to recognize the process later.
        "fingerprint": {"lstart": proc["lstart"], "args": args_hash(proc["args"])},
    }
    if category == "dev-process" and DEV_KEYS.get(label):
        it["label"] = {"key": DEV_KEYS[label]}
    return it


def args_hash(args):
    return hashlib.sha256(args.encode("utf-8", "replace")).hexdigest()


def scan_processes(ctx, procs, first, elapsed, cwds):
    mine = self_chain(procs)
    use = AgentUse(ctx, procs, cwds)
    items, heavy = [], []
    for pid, p in sorted(procs.items()):
        if pid in mine or p["user"] != ctx.user:
            continue
        cpu = 0.0
        if pid in first and elapsed > 0 and first[pid]["lstart"] == p["lstart"]:
            cpu = max(0.0, (p["cpu_time"] - first[pid]["cpu_time"]) / elapsed * 100.0)
        label = dev_label(p["args"])
        # Apps run from "/", which says nothing about what they work on.
        folder = use.cwd.get(pid) if use.cwd.get(pid) != "/" else None
        if label:
            items.append(proc_item("dev-process", "dev-process", p, label, process_lock(procs, p, use), cpu, folder))
        elif p["rss"] >= HEAVY_RSS or cpu >= HEAVY_CPU:
            # An agent bundled in an app (Codex in ChatGPT) and a tool shipped in one (git in Xcode)
            # are named after their own file, not the app.
            app = app_name(p["args"])
            name = p["base"] if is_agent(p) or not app else app
            heavy.append(proc_item("heavy-process", "heavy-process", p, name, process_lock(procs, p, use), cpu, folder))
    heavy.sort(key=lambda i: (i["size"] or 0) + (i["cpu"] or 0) * MIB, reverse=True)
    return items + heavy[:HEAVY_TOP]


def scan_login_items(ctx):
    items = []
    if ctx.mac:
        d = ctx.h("Library", "LaunchAgents")
        try:
            names = sorted(os.listdir(d))
        except OSError:
            names = []
        for n in names:
            p = os.path.join(d, n)
            if not n.endswith(".plist") or os.path.islink(p):
                continue
            try:
                with open(p, "rb") as f:
                    info = plistlib.load(f)
            except Exception:
                continue
            label = info.get("Label") or n[:-6]
            program = info.get("Program") or (info.get("ProgramArguments") or [""])[0]
            st = stat_or_none(p)
            items.append({
                "id": item_id("p", "login-item", p), "group": "process", "category": "login-item", "kind": "launch-agent",
                "name": label, "path": p, "size": None, "rebuilt": False, "action": "disable", "command": None, "locked": None,
                "detail": {"program": program}, "fingerprint": {"mtime": st.st_mtime if st else None},
            })
        return items
    d = os.path.join(os.environ.get("XDG_CONFIG_HOME") or ctx.h(".config"), "autostart")
    try:
        names = sorted(os.listdir(d))
    except OSError:
        names = []
    for n in names:
        p = os.path.join(d, n)
        if not n.endswith(".desktop") or os.path.islink(p):
            continue
        try:
            text = open(p, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        if re.search(r"^Hidden\s*=\s*true", text, re.M):
            continue
        m = re.search(r"^Exec\s*=\s*(.+)$", text, re.M)
        st = stat_or_none(p)
        items.append({
            "id": item_id("p", "login-item", p), "group": "process", "category": "login-item", "kind": "autostart",
            "name": n[:-8], "path": p, "size": None, "rebuilt": False, "action": "disable", "command": None, "locked": None,
            "detail": {"program": redact(m.group(1)) if m else ""}, "fingerprint": {"mtime": st.st_mtime if st else None},
        })
    if shutil.which("systemctl"):
        rc, stdout, _ = run(["systemctl", "--user", "list-unit-files", "--type=service", "--state=enabled", "--no-legend", "--no-pager"], timeout=30)
        for line in stdout.splitlines() if rc == 0 else []:
            unit = line.split()[0] if line.split() else ""
            if unit.endswith(".service"):
                items.append({
                    "id": item_id("p", "login-item", "systemd", unit), "group": "process", "category": "login-item",
                    "kind": "systemd-user", "name": unit, "path": None, "size": None, "rebuilt": False, "action": "disable",
                    "command": None, "locked": None, "detail": {"unit": unit}, "fingerprint": {},
                })
    return items


def mem_bytes(text):
    m = re.match(r"\s*([0-9.]+)\s*([KMGT]i?B|B|kB)", text or "")
    if not m:
        return None
    unit = m.group(2)
    mult = {"B": 1, "kB": 1e3, "KB": 1e3, "MB": 1e6, "GB": 1e9, "TB": 1e12,
            "KiB": 1024, "MiB": MIB, "GiB": 1024 ** 3, "TiB": 1024 ** 4}.get(unit, 1)
    return int(float(m.group(1)) * mult)


def scan_containers(ctx, procs, cwds):
    if not shutil.which("docker"):
        return []
    rc, stdout, _ = run(["docker", "ps", "--format", "{{json .}}"], timeout=30)
    if rc != 0:
        return []
    rows = []
    for line in stdout.splitlines():
        try:
            rows.append(json.loads(line))
        except ValueError:
            continue
    if not rows:
        return []
    _, stats_out, _ = run(["docker", "stats", "--no-stream", "--format", "{{json .}}"], timeout=60)
    stats = {}
    for line in stats_out.splitlines():
        try:
            s = json.loads(line)
        except ValueError:
            continue
        stats[s.get("ID", "")] = s
    items = []
    for r in rows:
        cid = r.get("ID", "")
        s = next((v for k, v in stats.items() if k and (cid.startswith(k) or k.startswith(cid))), {})
        labels = dict(kv.split("=", 1) for kv in (r.get("Labels") or "").split(",") if "=" in kv)
        workdir = labels.get("com.docker.compose.project.working_dir")
        cpu = s.get("CPUPerc", "0%").rstrip("%")
        items.append({
            "id": item_id("p", "container", cid), "group": "process", "category": "container", "kind": "container",
            "name": r.get("Names", cid), "path": None, "size": mem_bytes((s.get("MemUsage") or "").split("/")[0]),
            "cpu": float(cpu) if re.match(r"^[0-9.]+$", cpu) else 0.0, "rebuilt": False, "action": "docker-stop",
            "command": ["docker", "stop", cid], "locked": folder_lock(workdir, cwds, procs),
            "detail": {"image": r.get("Image"), "running_for": r.get("RunningFor"), "project": labels.get("com.docker.compose.project")},
            "fingerprint": {"container": cid},
        })
    return items


def measure(ctx):
    # disk_total and disk_free are None when df cannot tell; the page then says "not measured".
    free = total_disk = None
    _, stdout, _ = run(["df", "-k", ctx.home], timeout=20)
    lines = stdout.splitlines()
    if len(lines) >= 2:
        cols = lines[-1].split()
        if len(cols) >= 4 and cols[3].isdigit():
            free = int(cols[3]) * 1024
        if len(cols) >= 4 and cols[1].isdigit():
            total_disk = int(cols[1]) * 1024
    used = total = None
    if ctx.mac:
        _, vm, _ = run(["vm_stat"], timeout=20)
        page = re.search(r"page size of (\d+) bytes", vm)
        pages = {}
        for k, v in re.findall(r"^(Pages [^:]+):\s+(\d+)\.", vm, re.M):
            pages[k] = int(v)
        if page:
            used = (pages.get("Pages active", 0) + pages.get("Pages wired down", 0)
                    + pages.get("Pages occupied by compressor", 0)) * int(page.group(1))
        _, mem, _ = run(["sysctl", "-n", "hw.memsize"], timeout=20)
        total = int(mem.strip()) if mem.strip().isdigit() else None
    else:
        try:
            info = dict(re.findall(r"^(\w+):\s+(\d+) kB", open("/proc/meminfo").read(), re.M))
            total = int(info["MemTotal"]) * 1024
            used = total - int(info["MemAvailable"]) * 1024
        except (OSError, KeyError, ValueError):
            pass
    try:
        load = [round(x, 2) for x in os.getloadavg()]
    except OSError:
        load = None
    return {"disk_free": free, "disk_total": total_disk, "memory_used": used, "memory_total": total, "load": load}


# --- scan -----------------------------------------------------------------------------------

def cmd_scan(ctx, args):
    lowest_priority()
    ensure_state(ctx)
    started = time.time()
    deadline = started + max(0.0, args.time_limit)
    skipped = []
    # CPU use is the growth of each process's CPU time between two samples, because ps's %cpu is a
    # decaying average that cannot tell a burst from a process that stays busy.
    first = read_procs()
    if args.sample > 0:
        time.sleep(args.sample)
    procs = read_procs()
    elapsed = max(time.time() - started, 0.001)
    cwds = working_dirs(ctx)
    running_ids = set()
    if ctx.mac:
        for app in running_apps(procs):
            bid, _ = app_info(app)
            if bid:
                running_ids.add(bid)
    items = scan_processes(ctx, procs, first, elapsed, cwds)
    items += scan_login_items(ctx)
    items += scan_containers(ctx, procs, cwds)
    # Models read a few known folders, so they come before the caches, whose sizes take longest.
    items += scan_models(ctx, procs, deadline, skipped)
    items += scan_caches(ctx, procs, deadline, skipped)
    items += scan_app_caches(ctx, procs, running_ids, deadline, skipped)
    items += scan_docker(ctx, deadline, skipped)
    items += scan_trash_logs_installers(ctx, deadline, skipped)
    apps_dirs = args.apps_dir or (["/Applications", ctx.h("Applications")] if ctx.mac else [])
    items += scan_apps(ctx, procs, apps_dirs, deadline, skipped)
    listed = {it["path"] for it in items if it.get("path")} | {p for it in items for p in (it.get("detail") or {}).get("support", [])}
    items += scan_leftovers(ctx, procs, args.apps_dir or apps_dirs + ["/System/Applications"], listed, deadline, skipped)
    found = {}
    items += scan_home(ctx, args.root or [ctx.home], procs, cwds, deadline, skipped, found)
    items += scan_projects(ctx, found["repos"], procs, cwds, deadline, skipped)
    items += scan_tools(ctx, procs, found["version_files"], found["complete"], deadline, skipped)
    seen, unique = set(), []
    for it in items:
        if it["id"] not in seen:
            seen.add(it["id"])
            unique.append(it)
    unique = one_row_per_path(unique)
    last_commits = {}
    for it in unique:
        it["level"], it["reason"] = rank(ctx, it, last_commits)
    result = {
        "version": SCAN_VERSION, "platform": ctx.platform, "home": ctx.home, "scanned_at": iso(time.time()),
        "seconds": round(time.time() - started, 1), "time_limit": args.time_limit, "measure": measure(ctx),
        "items": unique, "skipped": skipped,
    }
    write_private(os.path.join(ctx.state, "scan.json"), json.dumps(result, indent=1))
    if args.json:
        print(json.dumps(result, indent=1))
    else:
        print_summary(ctx, result)
    return 0


def one_row_per_path(items):
    """Keeps one row for each path and records which rows hold each row.

    Two scans can meet the same path: an old installer in Downloads is also a large file or a copy.
    The row of the scan that ran first stays, since its reason is the more particular one, and when
    the row it replaces belongs to a duplicate set, it takes that set, so the set still names every
    copy. A row whose path is inside another row's folder, or is one of an app's support files, stays
    a row of its own, since it can be freed alone; its within lists the ids of the rows that hold it,
    nearest first. Freeing a holder frees it too, so the page counts its size once and apply skips it
    when its holder is freed in the same run."""
    kept, at = [], {}
    for it in items:
        path = it.get("path") if it["group"] == "disk" else None
        first = at.get(path) if path else None
        if first is None:
            if path:
                at[path] = it
            kept.append(it)
            continue
        dropped, own = it.get("detail") or {}, first.setdefault("detail", {})
        if dropped.get("set") and not own.get("set"):
            own["set"], own["copies"] = dropped["set"], dropped.get("copies", [])
    places = {}
    for it in kept:
        if it["group"] == "disk" and it.get("path"):
            for p in [it["path"]] + list(it["detail"].get("support") or []):
                places.setdefault(p, []).append(it["id"])
    for it in kept:
        within, p = [], it.get("path") if it["group"] == "disk" else None
        while p:
            within += [i for i in places.get(p, []) if i != it["id"] and i not in within]
            parent = os.path.dirname(p)
            p = parent if parent != p else None
        it["within"] = within
    return kept


def days_since(ts, now):
    return max(0, int((now - ts) // 86400))


def last_commit(repo, cache):
    """Unix time of the repository's last commit, or None when git cannot tell."""
    if repo not in cache:
        rc, stdout, _ = run(["git", "-C", repo, "log", "-1", "--format=%ct"], timeout=30)
        cache[repo] = int(stdout.strip()) if rc == 0 and stdout.strip().isdigit() else None
    return cache[repo]


def rank(ctx, it, last_commits):
    """Returns (level, reason) for one item. The level is recommended, check, or careful, and the
    reason is {"code": ..., "days": ...} for the page to put into words. The rules, in order:
    rebuilt or already discarded and unused for 30 days is recommended; your own files, apps, login
    items, and anything that cannot be told apart from something in use is check; a running
    program or container, whose work stops when it is ended, is careful."""
    cat = it["category"]
    if cat == "cache":
        return "recommended", {"code": "rebuilt"}
    if cat == "build":
        ts = last_commit((it.get("detail") or {}).get("project") or "", last_commits)
        if ts is None:
            return "check", {"code": "build_unknown"}
        days = days_since(ts, ctx.now)
        if days > OLD_DAYS:
            return "recommended", {"code": "build_idle", "days": days}
        return "check", {"code": "build_recent", "days": days}
    if cat == "trash":
        return "recommended", {"code": "trash"}
    if cat == "log":
        return "recommended", {"code": "old_logs", "days": OLD_DAYS}
    if cat == "installer":
        return "recommended", {"code": "old_installer", "days": OLD_DAYS}
    if cat == "large":
        return "check", {"code": "own_file"}
    if cat == "duplicate":
        return "check", {"code": "duplicate"}
    if cat == "project":
        used = parse_iso((it.get("detail") or {}).get("last_used"))
        return "check", {"code": "project_idle", "days": days_since(used, ctx.now) if used else 0}
    if cat == "app" and it["kind"] == "leftover":
        used = parse_iso((it.get("detail") or {}).get("last_used"))
        return "check", {"code": "leftover", "days": days_since(used, ctx.now) if used else 0}
    if cat == "tool":
        return "check", {"code": "tool_unused"}
    if cat == "model":
        got = parse_iso((it.get("detail") or {}).get("downloaded"))
        return "check", {"code": "model", "days": days_since(got, ctx.now) if got else 0}
    if cat == "app" and it["kind"] == "mac-app":
        used = parse_iso((it.get("detail") or {}).get("last_used"))
        return "check", ({"code": "app_unused", "days": days_since(used, ctx.now)} if used else {"code": "app_unused_unknown"})
    if cat == "app":
        return "check", {"code": "flatpak"}
    if cat == "dev-process":
        if it["name"] == "Next.js server":
            return "check", {"code": "next_server"}
        return "recommended", {"code": "session_ended"}
    if cat == "login-item":
        return "check", {"code": "login_item"}
    if cat == "container":
        return "careful", {"code": "container"}
    # heavy-process: a running program, whose work stops when it ends.
    return "careful", {"code": "running_program"}


def parse_iso(text):
    try:
        return datetime.datetime.strptime(text, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=datetime.timezone.utc).timestamp()
    except (TypeError, ValueError):
        return None


def print_summary(ctx, result):
    by = {}
    for it in result["items"]:
        c = by.setdefault(it["category"], [0, 0, 0])
        c[0] += 1
        if it["locked"]:
            c[2] += 1
        elif it["group"] == "disk":
            c[1] += it["size"] or 0
    print("Scanned in %.0f seconds." % result["seconds"])
    for cat in ("cache", "build", "trash", "log", "installer", "large", "duplicate", "project", "app", "tool", "model",
                "dev-process", "heavy-process", "login-item", "container"):
        if cat in by:
            n, size, locked = by[cat]
            extra = (", %s to free" % human(size)) if size else ""
            extra += (", %d in use" % locked) if locked else ""
            print("%-14s %3d%s" % (cat, n, extra))
    rec = [it for it in result["items"] if it["level"] == "recommended" and not it["locked"]]
    rec_size = sum(it["size"] or 0 for it in rec if it["group"] == "disk")
    print("Recommended: %d items, %s of disk." % (len(rec), human(rec_size)))
    m = result["measure"]
    print("Free disk now %s, memory used %s of %s." % (human(m["disk_free"]), human(m["memory_used"]), human(m["memory_total"])))
    if result["skipped"]:
        print("Not measured: %d places (%s)." % (len(result["skipped"]), ", ".join(sorted({s["reason"] for s in result["skipped"]}))))
    print("Scan saved to %s" % tilde(ctx, os.path.join(ctx.state, "scan.json")))


def load_scan(ctx):
    scan = read_json(os.path.join(ctx.state, "scan.json"))
    if not scan:
        print("No scan found. Run scan first.", file=sys.stderr)
        return None
    if scan.get("version") != SCAN_VERSION:
        # An older scan has no recommendation levels, and its items may have changed since.
        print("The last scan was made by an older version of machine-cleanup. Run scan again.", file=sys.stderr)
        return None
    return scan


# --- serve ----------------------------------------------------------------------------------

def free_port(preferred=None):
    for port in ([preferred] if preferred else []) + [0]:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            s.bind(("127.0.0.1", port))
            return s.getsockname()[1]
        except OSError:
            continue
        finally:
            s.close()
    return None


def page_html(ctx, scan, token):
    here = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(here, "..", "templates", "sheet.html"), encoding="utf-8") as f:
        template = f.read()
    data = {"home": scan["home"], "platform": scan["platform"], "scanned_at": scan["scanned_at"],
            "measure": scan["measure"], "skipped": scan["skipped"], "token": token,
            "items": [{k: v for k, v in it.items() if k != "fingerprint"} for it in scan["items"]]}
    blob = json.dumps(data).replace("<", "\\u003c").replace(">", "\\u003e").replace("&", "\\u0026")
    return template.replace("__DATA__", blob)


def cmd_serve(ctx, args):
    scan = load_scan(ctx)
    if scan is None:
        return 2
    ensure_state(ctx)
    session_path = os.path.join(ctx.state, "session.json")
    session = read_json(session_path, {}) or {}
    port = free_port(session.get("port"))
    if port is None:
        print("No free port on 127.0.0.1.", file=sys.stderr)
        return 2
    token = session.get("token") if session.get("port") == port and session.get("token") else secrets.token_urlsafe(24)
    write_private(session_path, json.dumps({"port": port, "token": token}))
    origin = "http://127.0.0.1:%d" % port
    page = page_html(ctx, scan, token).encode("utf-8")
    pickable = {it["id"] for it in scan["items"] if not it["locked"]}
    state = {"ids": None}

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def send(self, code, body=b"", ctype="text/plain; charset=utf-8"):
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Referrer-Policy", "no-referrer")
            self.send_header("Content-Security-Policy", "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; "
                             "connect-src 'self'; img-src data:; base-uri 'none'; form-action 'none'; frame-ancestors 'none'")
            self.end_headers()
            if body:
                self.wfile.write(body)

        def token_ok(self, given):
            return isinstance(given, str) and hmac.compare_digest(given.encode(), token.encode())

        def host_ok(self):
            return self.headers.get("Host") == "127.0.0.1:%d" % port

        def do_GET(self):
            url = urllib.parse.urlparse(self.path)
            q = urllib.parse.parse_qs(url.query)
            if not self.host_ok() or not self.token_ok((q.get("t") or [""])[0]):
                return self.send(403, b"forbidden")
            if url.path == "/":
                return self.send(200, page, "text/html; charset=utf-8")
            if url.path == "/ping":
                return self.send(204)
            return self.send(404, b"not found")

        def do_POST(self):
            if urllib.parse.urlparse(self.path).path != "/select":
                return self.send(404, b"not found")
            if not self.host_ok() or self.headers.get("Origin") != origin:
                return self.send(403, b"forbidden")
            length = int(self.headers.get("Content-Length") or 0)
            if length > 65536 or "application/json" not in (self.headers.get("Content-Type") or ""):
                return self.send(400, b"bad request")
            try:
                body = json.loads(self.rfile.read(length).decode("utf-8"))
            except ValueError:
                return self.send(400, b"bad request")
            if not isinstance(body, dict) or not self.token_ok(body.get("t")):
                return self.send(403, b"forbidden")
            ids = body.get("ids")
            if not isinstance(ids, list) or not all(isinstance(i, str) and i in pickable for i in ids):
                return self.send(400, json.dumps({"error": "unknown or locked item"}).encode(), "application/json")
            state["ids"] = ids
            return self.send(200, b'{"ok": true}', "application/json")

    server = http.server.HTTPServer(("127.0.0.1", port), Handler)
    server.timeout = 0.5
    url = "%s/?t=%s" % (origin, token)
    print(url, flush=True)
    if not args.no_open:
        opener = {"darwin": ["open"], "wsl": ["wslview"]}.get(ctx.platform, ["xdg-open"])
        if run(opener + [url], timeout=20)[0] != 0:
            print("Open the address above in a browser on this computer.", flush=True)
    deadline = time.time() + max(1, args.wait)
    try:
        while state["ids"] is None and time.time() < deadline:
            server.handle_request()
    finally:
        server.server_close()
    if state["ids"] is None:
        print("No selection yet. Run serve again to keep waiting; the page stays open at the same address.", flush=True)
        return 4
    text = (SELECT_PREFIX + " " + " ".join(state["ids"])).strip()
    write_private(os.path.join(ctx.state, "selection.txt"), text + "\n")
    print(text, flush=True)
    return 0


# --- apply ----------------------------------------------------------------------------------

def parse_selection(text):
    text = (text or "").strip()
    if text.startswith(SELECT_PREFIX):
        text = text[len(SELECT_PREFIX):]
    ids = [t for t in re.split(r"[\s,]+", text) if t]
    bad = [t for t in ids if not ID_RE.match(t)]
    return ids, bad


def safe_target(ctx, path, item):
    """Refuses paths outside HOME (apps also in their folders), HOME itself, links, and excluded places."""
    if not path or os.path.islink(path):
        return False
    real = os.path.realpath(path)
    if real == ctx.home or excluded(real, ctx.platform, ctx.home):
        return False
    if real.startswith(ctx.home + "/"):
        return True
    return item["category"] == "app" and real.endswith(".app")


def remove_tree(path):
    def onerror(func, p, _):
        try:
            os.chmod(os.path.dirname(p), 0o700)
            os.chmod(p, 0o700)
            func(p)
        except OSError:
            pass
    if os.path.isdir(path) and not os.path.islink(path):
        shutil.rmtree(path, onerror=onerror)
    elif os.path.lexists(path):
        os.remove(path)


def move_to_trash(path, platform=None, home=None):
    """Moves a file or folder to the Trash and returns where it went. Linux keeps a .trashinfo record."""
    platform = platform or detect_platform()
    home = home or os.path.realpath(os.path.expanduser("~"))
    name = os.path.basename(path.rstrip("/"))
    if platform == "darwin":
        trash = os.path.join(home, ".Trash")
        os.makedirs(trash, exist_ok=True)
        dest = os.path.join(trash, name)
        n = 1
        while os.path.lexists(dest):
            stem, ext = os.path.splitext(name)
            dest = os.path.join(trash, "%s %d%s" % (stem, n, ext))
            n += 1
        os.rename(path, dest)
        return dest
    base = os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.join(home, ".local", "share"), "Trash")
    files, info = os.path.join(base, "files"), os.path.join(base, "info")
    os.makedirs(files, exist_ok=True)
    os.makedirs(info, exist_ok=True)
    dest_name, n = name, 1
    while os.path.lexists(os.path.join(files, dest_name)) or os.path.lexists(os.path.join(info, dest_name + ".trashinfo")):
        stem, ext = os.path.splitext(name)
        dest_name = "%s.%d%s" % (stem, n, ext)
        n += 1
    record = "[Trash Info]\nPath=%s\nDeletionDate=%s\n" % (urllib.parse.quote(path), time.strftime("%Y-%m-%dT%H:%M:%S"))
    write_private(os.path.join(info, dest_name + ".trashinfo"), record)
    dest = os.path.join(files, dest_name)
    os.rename(path, dest)
    return dest


def changed(ctx, item):
    """Returns why a disk item no longer matches the scan, or None."""
    fp = item.get("fingerprint") or {}
    if item["kind"].startswith("docker-"):
        rec = docker_reclaimable() or {}
        typ = {"docker-images": "Images", "docker-build-cache": "Build Cache", "docker-stopped-containers": "Containers"}[item["kind"]]
        return None if rec.get(typ, 0) > 0 else "nothing is left to free"
    if item["kind"] == "flatpak":
        return None
    path = item["path"]
    st = stat_or_none(path)
    if st is None:
        return "no longer exists"
    if os.path.islink(path):
        return "changed after the scan (now a symbolic link)"
    if fp.get("ino") is not None and st.st_ino != fp["ino"]:
        return "changed after the scan (replaced)"
    if item["category"] == "project":
        why, _ = project_state(path, time.time())
        return ("changed after the scan (%s)" % why) if why else None
    if item["kind"] == "ollama-model":
        return "changed after the scan" if st.st_mtime != fp.get("mtime") else None
    if item["category"] in ("installer", "large", "duplicate"):
        if st.st_size != fp.get("size") or st.st_mtime != fp.get("mtime"):
            return "changed after the scan"
        return None
    if item["category"] == "log":
        return None
    old = fp.get("size") or 0
    now = du_sizes(ctx, [path]).get(path)
    if now is None:
        return "could not be measured again"
    if abs(now - old) > max(MIB, old * 0.05):
        return "changed after the scan (%s -> %s)" % (human(old), human(now))
    return None


def disk_lock_now(ctx, item, procs, cwds):
    if item["category"] in ("build", "large", "duplicate", "project"):
        return folder_lock((item.get("detail") or {}).get("project") or find_repo(ctx, item["path"]), cwds, procs)
    if item["category"] == "tool" and any((item["path"] + "/") in p["args"] for p in procs.values()):
        return "a running program uses this version"
    if item["category"] == "app" and item["kind"] == "mac-app" and item["path"] in running_apps(procs):
        return "the app is running"
    return None


def find_repo(ctx, path):
    d = os.path.dirname(path or "")
    while d and d != ctx.home and d != "/":
        if os.path.exists(os.path.join(d, ".git")):
            return d
        d = os.path.dirname(d)
    return None


def remove_ollama_files(ctx, item):
    """Removes what `ollama rm` removes while Ollama is not running: the manifest, and the blobs that
    no other manifest uses now. Returns how many blobs it removed."""
    root = (item.get("detail") or {}).get("root") or ollama_root(ctx)
    path = item["path"]
    used = {b for p, (_, blobs) in ollama_manifests(root).items() if p != path for b in blobs}
    os.remove(path)
    n = 0
    for b in (item.get("detail") or {}).get("blobs", []):
        if b not in used and os.path.lexists(b) and not os.path.islink(b) and safe_target(ctx, b, item):
            os.remove(b)
            n += 1
    d = os.path.dirname(path)
    while d.startswith(os.path.join(root, "manifests") + "/"):
        try:
            os.rmdir(d)
        except OSError:
            break
        d = os.path.dirname(d)
    return n


def remove_version_links(path):
    """Removes the links beside a deleted version that pointed at it, such as mise's 21 and 21.7."""
    parent = os.path.dirname(path)
    try:
        names = os.listdir(parent)
    except OSError:
        return
    for name in names:
        link = os.path.join(parent, name)
        if os.path.islink(link) and os.path.normpath(os.path.join(parent, os.readlink(link))) == os.path.normpath(path):
            os.remove(link)


def free_disk_item(ctx, item, records, procs):
    """Frees one disk item. Returns (status, note)."""
    action = item["action"]
    if action == "ollama":
        if any(p["base"].lower() == "ollama" for p in procs.values()):
            if not shutil.which("ollama"):
                return "failed", "Ollama is running, but the ollama command is not installed"
            rc, _, err = run(item["command"], timeout=300)
            if rc != 0:
                return "failed", "%s exited %d: %s" % (" ".join(item["command"]), rc, (err.strip().splitlines() or [""])[-1][:200])
            return "done", "ran %s" % " ".join(item["command"])
        if not safe_target(ctx, item["path"], item):
            return "skipped", "outside the places this plugin may change"
        n = remove_ollama_files(ctx, item)
        return "done", "Ollama is not running, so deleted the model's manifest and %d blobs no other model uses" % n
    if action == "tool":
        tool = item["command"][0]
        if shutil.which(tool):
            rc, _, err = run(item["command"], timeout=1800)
            if rc != 0:
                return "failed", "%s exited %d: %s" % (" ".join(item["command"]), rc, (err.strip().splitlines() or [""])[-1][:200])
            return "done", "ran %s" % " ".join(item["command"])
        if not item["path"]:
            return "failed", "%s is not installed" % tool
        action = "delete"
    if not safe_target(ctx, item["path"], item):
        return "skipped", "outside the places this plugin may change"
    if action == "delete":
        remove_tree(item["path"])
        if item["category"] == "tool":
            remove_version_links(item["path"])
        return "done", "deleted"
    if action == "empty-trash":
        root = item["path"]
        for sub in ([root] if ctx.mac else [os.path.join(root, "files"), os.path.join(root, "info")]):
            for n in os.listdir(sub) if os.path.isdir(sub) else []:
                remove_tree(os.path.join(sub, n))
        return "done", "emptied"
    if action == "delete-files":
        n = 0
        cutoff = time.time() - OLD_DAYS * 86400
        for p in (item.get("detail") or {}).get("files", []):
            st = stat_or_none(p)
            if st and not os.path.islink(p) and st.st_mtime <= cutoff and p.startswith(ctx.home + "/"):
                os.remove(p)
                n += 1
        return "done", "deleted %d old files" % n
    if action in ("trash", "trash-app"):
        moved = [move_to_trash(item["path"], ctx.platform, ctx.home)]
        records.append({"id": item["id"], "type": "trash", "from": moved[0], "to": item["path"]})
        for p in (item.get("detail") or {}).get("support", []) if action == "trash-app" else []:
            if stat_or_none(p) and safe_target(ctx, p, item):
                dest = move_to_trash(p, ctx.platform, ctx.home)
                records.append({"id": item["id"], "type": "trash", "from": dest, "to": p})
        return "done", "moved to the Trash"
    return "failed", "unknown action %s" % action


def disable_login_item(ctx, item, records):
    if item["kind"] == "systemd-user":
        unit = item["detail"]["unit"]
        rc, _, err = run(["systemctl", "--user", "disable", "--now", unit], timeout=60)
        if rc != 0:
            return "failed", err.strip()[:200]
        records.append({"id": item["id"], "type": "systemd-user", "unit": unit})
        return "done", "disabled; restore %s turns it back on" % item["id"]
    path = item["path"]
    st = stat_or_none(path)
    if st is None:
        return "skipped", "no longer exists"
    if st.st_mtime != (item.get("fingerprint") or {}).get("mtime"):
        return "skipped", "changed after the scan"
    if item["kind"] == "launch-agent":
        run(["launchctl", "bootout", "gui/%d" % ctx.uid, path], timeout=60)
    keep = os.path.join(ctx.state, "disabled")
    os.makedirs(keep, mode=0o700, exist_ok=True)
    dest = os.path.join(keep, "%s-%s" % (item["id"], os.path.basename(path)))
    shutil.move(path, dest)
    records.append({"id": item["id"], "type": item["kind"], "from": dest, "to": path})
    return "done", "stopped; restore %s turns it back on" % item["id"]


def alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def same_process(procs, item):
    p = procs.get(item["pid"])
    if p is None or not alive(item["pid"]):
        return None, "already ended"
    fp = item.get("fingerprint") or {}
    if p["lstart"] != fp.get("lstart") or args_hash(p["args"]) != fp.get("args"):
        return None, "the process id now belongs to another program"
    return p, None


def report(ctx, before, after, docker_done):
    def mem(m):
        return human(m.get("memory_used"))

    def load(m):
        return "%.2f" % m["load"][0] if m.get("load") else "unknown"
    gained = (after["disk_free"] - before["disk_free"]) if before.get("disk_free") is not None and after.get("disk_free") is not None else None
    print("")
    print("Free disk    %s -> %s%s" % (human(before.get("disk_free")), human(after.get("disk_free")),
                                       " (%s%s)" % ("+" if gained >= 0 else "-", human(abs(gained))) if gained is not None else ""))
    print("Memory used  %s -> %s" % (mem(before), mem(after)))
    print("Load         %s -> %s" % (load(before), load(after)))
    raw = (ctx.h("Library", "Containers", "com.docker.docker", "Data", "vms", "0", "data", "Docker.raw") if ctx.mac
           else ctx.h(".docker", "desktop", "vms", "0", "data", "Docker.raw"))
    if docker_done and os.path.exists(raw):
        print("Docker Desktop keeps its disk image at its size for a while after a prune, so the free space can rise later "
              "than the report shows. Docker Desktop gives the space back on its own, or when it restarts.")


def save_records(ctx, records):
    if not records:
        return
    path = os.path.join(ctx.state, "restore.json")
    data = read_json(path, {"version": FORMAT_VERSION, "records": []}) or {"version": FORMAT_VERSION, "records": []}
    data["records"].extend(records)
    write_private(path, json.dumps(data, indent=1))


def line(status, ident, name, note):
    print("%-9s%s  %s  %s" % (status, ident, name, note))


def cmd_apply(ctx, args):
    scan = load_scan(ctx)
    if scan is None:
        return 2
    lowest_priority()
    by_id = {it["id"]: it for it in scan["items"]}
    if args.kill is not None:
        return kill_survivors(ctx, args.kill, by_id)
    ids, bad = parse_selection(args.select)
    if bad:
        print("Not an item id: %s" % " ".join(bad), file=sys.stderr)
        return 2
    refused = []
    for i in ids:
        if i not in by_id:
            refused.append((i, "not in the last scan"))
        elif by_id[i]["locked"]:
            refused.append((i, "in use: %s" % by_id[i]["locked"]))
    picked = [by_id[i] for i in ids if i in by_id]
    chosen = set(ids)

    def freed(it):
        return it["id"] in chosen or any(w in chosen for w in it.get("within") or [])
    # A copy is freed when it is picked or when a row holding it is; the copies of a set can sit in
    # different tabs (an old installer and a copy elsewhere).
    for s in {(it.get("detail") or {}).get("set") for it in picked} - {None}:
        copies = [it for it in scan["items"] if (it.get("detail") or {}).get("set") == s]
        if all(freed(c) for c in copies):
            refused.append((copies[0]["id"], "every copy of a duplicate set was picked; keep at least one"))
    if refused:
        for i, why in refused:
            line("refused", i, by_id[i]["name"] if i in by_id else "-", why)
        print("Nothing was changed. Pick again without these items.")
        return 1
    ensure_state(ctx)
    before = measure(ctx)
    procs = read_procs()
    cwds = working_dirs(ctx)
    use = AgentUse(ctx, procs, cwds)
    records, failed, docker_done = [], False, False
    targets = []
    done = set()
    # Rows that hold others go first, so a row inside a freed row is skipped instead of freed twice;
    # when the holder is skipped, the row inside it is still freed on its own.
    for it in sorted(picked, key=lambda x: len(x.get("within") or [])):
        if it["group"] == "disk":
            holder = next((by_id[w] for w in it.get("within") or [] if w in done), None)
            if holder is not None:
                line("skipped", it["id"], it["name"], "inside %s (%s), which was freed with it" % (holder["name"], holder["id"]))
                continue
            lock = disk_lock_now(ctx, it, procs, cwds)
            why = ("in use: " + lock) if lock else changed(ctx, it)
            if why:
                line("skipped", it["id"], it["name"], why)
                continue
            status, note = free_disk_item(ctx, it, records, procs)
            failed = failed or status == "failed"
            if status == "done":
                done.add(it["id"])
            docker_done = docker_done or (status == "done" and it["kind"].startswith("docker-"))
            line(status, it["id"], it["name"], note)
        elif it["category"] == "login-item":
            status, note = disable_login_item(ctx, it, records)
            failed = failed or status == "failed"
            line(status, it["id"], it["name"], note)
        elif it["category"] == "container":
            rc, stdout, _ = run(["docker", "ps", "-q", "--no-trunc"], timeout=30)
            if not any(c.startswith(it["fingerprint"]["container"]) for c in stdout.split()):
                line("skipped", it["id"], it["name"], "no longer running")
                continue
            rc, _, err = run(it["command"], timeout=120)
            failed = failed or rc != 0
            line("done" if rc == 0 else "failed", it["id"], it["name"], "stopped" if rc == 0 else err.strip()[:200])
        else:
            p, why = same_process(procs, it)
            if p is not None:
                why = process_lock(procs, p, use)
                why = ("in use: " + why) if why else None
            if why:
                line("skipped", it["id"], it["name"], why)
                continue
            targets.append(it)
    for it in targets:
        try:
            os.kill(it["pid"], signal.SIGTERM)
        except ProcessLookupError:
            pass
        except PermissionError as e:
            line("failed", it["id"], it["name"], str(e))
            failed = True
    end = time.time() + max(0.0, args.term_wait)
    while targets and time.time() < end and any(alive(t["pid"]) for t in targets):
        time.sleep(0.1)
    survivors = {}
    for it in targets:
        if alive(it["pid"]):
            survivors[it["id"]] = it["fingerprint"]
            line("survived", it["id"], it["name"], "still running after the end signal; apply --kill %s ends it at once, "
                 "without letting it save its work" % it["id"])
        else:
            line("done", it["id"], it["name"], "ended")
    write_private(os.path.join(ctx.state, "survivors.json"), json.dumps({"ids": survivors}))
    save_records(ctx, records)
    after = measure(ctx)
    report(ctx, before, after, docker_done)
    for n in ("session.json", "selection.txt"):
        try:
            os.remove(os.path.join(ctx.state, n))
        except OSError:
            pass
    return 3 if failed else 0


def kill_survivors(ctx, ids, by_id):
    survivors = (read_json(os.path.join(ctx.state, "survivors.json"), {}) or {}).get("ids", {})
    refused = [i for i in ids if i not in survivors or i not in by_id]
    if refused:
        for i in refused:
            line("refused", i, by_id[i]["name"] if i in by_id else "-", "not a process that survived the last apply")
        print("Nothing was changed.")
        return 1
    procs = read_procs()
    use = AgentUse(ctx, procs, working_dirs(ctx))
    for i in ids:
        it = by_id[i]
        p, why = same_process(procs, it)
        if p is not None:
            why = process_lock(procs, p, use)
            why = ("in use: " + why) if why else None
        if why:
            line("skipped", i, it["name"], why)
            continue
        try:
            os.kill(it["pid"], signal.SIGKILL)
            line("done", i, it["name"], "ended at once")
        except ProcessLookupError:
            line("skipped", i, it["name"], "already ended")
        survivors.pop(i, None)
    write_private(os.path.join(ctx.state, "survivors.json"), json.dumps({"ids": survivors}))
    return 0


# --- restore and finish ---------------------------------------------------------------------

def cmd_restore(ctx, args):
    path = os.path.join(ctx.state, "restore.json")
    data = read_json(path, {"version": FORMAT_VERSION, "records": []}) or {"version": FORMAT_VERSION, "records": []}
    records = data.get("records", [])
    if not args.ids:
        if not records:
            print("Nothing to restore.")
            return 1
        for r in records:
            print("%s  %-12s %s" % (r["id"], r["type"], tilde(ctx, r.get("to") or r.get("unit"))))
        return 0
    keep, status = [], 0
    unknown = [i for i in args.ids if not any(r["id"] == i for r in records)]
    if unknown:
        for i in unknown:
            line("refused", i, "-", "nothing recorded to restore")
        return 1
    for r in records:
        if r["id"] not in args.ids:
            keep.append(r)
            continue
        if r["type"] == "systemd-user":
            rc, _, err = run(["systemctl", "--user", "enable", "--now", r["unit"]], timeout=60)
            line("done" if rc == 0 else "failed", r["id"], r["unit"], "turned back on" if rc == 0 else err.strip()[:200])
            if rc != 0:
                keep.append(r)
                status = 3
            continue
        if os.path.lexists(r["to"]):
            line("skipped", r["id"], os.path.basename(r["to"]), "something is already at %s" % tilde(ctx, r["to"]))
            keep.append(r)
            continue
        if not os.path.lexists(r["from"]):
            line("skipped", r["id"], os.path.basename(r["to"]), "the saved copy is gone (the Trash may have been emptied)")
            continue
        os.makedirs(os.path.dirname(r["to"]), exist_ok=True)
        shutil.move(r["from"], r["to"])
        if r["type"] == "launch-agent":
            run(["launchctl", "bootstrap", "gui/%d" % ctx.uid, r["to"]], timeout=60)
        if r["type"] == "trash" and not ctx.mac:
            info = os.path.join(os.path.dirname(os.path.dirname(r["from"])), "info", os.path.basename(r["from"]) + ".trashinfo")
            if os.path.exists(info):
                os.remove(info)
        line("done", r["id"], os.path.basename(r["to"]), "restored to %s" % tilde(ctx, r["to"]))
    data["records"] = keep
    write_private(path, json.dumps(data, indent=1))
    return status


def cmd_finish(ctx, args):
    for n in ("scan.json", "session.json", "selection.txt", "survivors.json"):
        try:
            os.remove(os.path.join(ctx.state, n))
        except OSError:
            pass
    print("Removed the scan and the page session. Restore records stay in %s." % tilde(ctx, ctx.state))
    return 0


# --- main -----------------------------------------------------------------------------------

def main(argv=None, platform=None):
    parser = argparse.ArgumentParser(prog="machine_cleanup.py", description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="cmd")
    s = sub.add_parser("scan")
    s.add_argument("--root", action="append", help="folder to walk for build output and large files (default: HOME)")
    s.add_argument("--apps-dir", action="append", help="folder of macOS apps (default: /Applications and ~/Applications)")
    s.add_argument("--time-limit", type=float, default=DEFAULT_TIME_LIMIT)
    s.add_argument("--sample", type=float, default=2.0, help="seconds between the two CPU samples")
    s.add_argument("--json", action="store_true")
    v = sub.add_parser("serve")
    v.add_argument("--wait", type=float, default=DEFAULT_WAIT)
    v.add_argument("--no-open", action="store_true")
    a = sub.add_parser("apply")
    a.add_argument("--select")
    a.add_argument("--kill", nargs="+")
    a.add_argument("--term-wait", type=float, default=DEFAULT_TERM_WAIT)
    r = sub.add_parser("restore")
    r.add_argument("ids", nargs="*")
    sub.add_parser("finish")
    args = parser.parse_args(argv)
    if args.cmd is None:
        parser.print_help()
        return 2
    if args.cmd == "apply" and args.select is None and args.kill is None:
        print("apply needs --select TEXT or --kill ID...", file=sys.stderr)
        return 2
    ctx = Ctx(platform)
    return {"scan": cmd_scan, "serve": cmd_serve, "apply": cmd_apply, "restore": cmd_restore, "finish": cmd_finish}[args.cmd](ctx, args)


if __name__ == "__main__":
    sys.exit(main())
