#!/usr/bin/env python3
"""List things that have gone unused for a long time, and remove only the ones the user picks.

`tidy.sh` in the same directory is the entry point. The script needs nothing from outside this skill's
directory, so copying that directory alone is enough to run it on another Mac.

The state directory is `$PC_TIDY_HOME` (default `~/.local/share/pc-tidy/`) and holds these files.

| file | contents |
|---|---|
| `config` | `days=<days>` (default 30) and `min_size_mb=<MB>` (default 100) |
| `protect.txt` | Extra locations this user wants protected. One per line; `~` is the home directory |
| `candidates.json` | The latest list. `apply`, `explain` and `comment` read its numbers (`schema_version` 2; version 1 is refused) |
| `candidates.html` | The selection page for the latest list |
| `notes.json` | Per-location names, descriptions and recommendations written by the agent, plus the user's comments (`schema_version` 1; the recommendation and comment fields are optional) |
| `removed.jsonl` | Log of removed items, one per line (`schema_version` 1) |

Kinds live in the `KINDS` table. To support another OS, write its measure functions and add rows to the table.
The last-used date does not rely on file access times; each kind uses its own evidence (repos use the last
commit and checkout). Access times (`atime`) are used only for tools and models, where nothing else records
when they were last used. An access time can only make an item look newer than it is, which means fewer
candidates, never an item that looks unused while it is still in use.
"""

from __future__ import annotations

import datetime
import json
import os
import platform
import plistlib
import re
import shutil
import subprocess
import sys
import time
import urllib.parse
from pathlib import Path

# Each file format has its own version. The list went to 2 when the contents and description fields were added.
LIST_SCHEMA = 2
RECORD_SCHEMA = 1
NOTES_SCHEMA = 1
SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPT_DIR.parent
DEFAULT_DAYS = 30
DEFAULT_MIN_SIZE_MB = 100

# Labels for the command-line output. The selection page keeps its own English and Japanese labels in `PAGE`.
KIND_LABELS = {
    "repo": "Local repo",
    "worktree": "Worktree",
    "app": "App",
    "leftover": "Leftovers of a removed app",
    "toolchain": "Tool or runtime",
    "model": "AI model",
    "image": "Docker image",
    "record": "Log retention setting",
    "other": "Uncategorized",
}
ACTION_LABELS = {
    "delete": "Delete permanently",
    "trash": "Move to Trash",
    "command": "Remove with a command",
    "setting": "Change a setting",
}

# Version managers and where they keep versions. The root is relative to the home directory.
MANAGERS = [
    ("rustup", ".rustup", "toolchains/*"),
    ("elan", ".elan", "toolchains/*"),
    ("mise", ".local/share/mise", "installs/*/*"),
    ("nvm", ".nvm", "versions/node/*"),
    ("pyenv", ".pyenv", "versions/*"),
    ("rbenv", ".rbenv", "versions/*"),
]
# Where AI models are stored, and the unit counted as one candidate. An empty unit counts the whole place as one.
MODEL_PLACES = [
    (".cache/huggingface/hub", "models--*"),
    (".lmstudio/models", "*/*"),
    (".ollama/models", ""),
]
LEFTOVER_PLACES = [
    "Library/Application Support",
    "Library/Containers",
    "Library/Group Containers",
]
# Names that Apple apps and macOS itself use in `Application Support`. They have no matching .app, so they are
# excluded to avoid mistaking them for leftovers of removed apps.
APPLE_SUPPORT_NAMES = {
    "addressbook", "animoji", "callhistorydb", "callhistorytransactions", "clouddocs", "crashreporter",
    "diskimages", "dock", "facetime", "fileprovider", "icloud", "icdd", "knowledge", "mobilesync",
    "networkserviced", "syncservices", "accounts", "appstore", "coreparsec", "familycircle",
    "homeenergyd", "locationaccessstored", "quicklook", "siri", "videoconference", "tipsd",
    "stocks", "weather", "maps", "news", "podcasts", "photos", "books", "contacts", "calendars",
    "notes", "reminders", "safari", "mail", "messages", "shortcuts", "translate",
}
# Places the home-wide walk does not enter: another kind measures them, or they are caches that each tool's
# own cleanup command is responsible for.
WALK_EXCLUDED = ["Library", ".cache", ".Trash", "Applications"]
# Places that package managers download and rebuild the next time they run, even after deletion.
# Regenerable caches belong to each tool's own cleanup command (`npm cache clean` and so on), so the walk skips them.
# A skipped place also stops its parent from becoming a whole-directory candidate, so tools in `~/.cargo/bin` are never swept up.
PACKAGE_CACHES = [
    ".cargo/registry", ".cargo/git", ".npm", ".pnpm-store", ".bun/install/cache", ".yarn/berry/cache",
    ".gradle/caches", ".gradle/wrapper/dists", ".m2/repository", "go/pkg/mod", ".pub-cache",
    ".nuget/packages", ".cocoapods/repos",
]


def reject(reason: str, code: int, detail: str = "") -> None:
    suffix = f" {detail}" if detail else ""
    print(f"tidy: rejected (reason={reason}){suffix}", file=sys.stderr)
    sys.exit(code)


# --- State directory and settings ------------------------------------------------


def state_dir() -> Path:
    """Return the state directory: `$PC_TIDY_HOME`, or `~/.local/share/pc-tidy` when it is unset or empty.

    The path is made absolute so that the protect check in `read_protect` compares it like any other location.
    """
    value = os.environ.get("PC_TIDY_HOME")
    if not value:
        value = os.path.join(os.environ.get("HOME", ""), ".local", "share", "pc-tidy")
    return Path(os.path.abspath(Path(value).expanduser()))


def read_config(state: Path) -> dict[str, int]:
    config = {"days": DEFAULT_DAYS, "min_size_mb": DEFAULT_MIN_SIZE_MB}
    path = state / "config"
    if not path.exists():
        return config
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = (part.strip() for part in line.split("=", 1))
        if key in config:
            if not value.isdigit() or int(value) <= 0:
                reject("bad-config", 2, f"{key}={value} is not a positive integer")
            config[key] = int(value)
    return config


def expand(home: Path, text: str) -> Path:
    if text == "~":
        return home
    if text.startswith("~/"):
        return home / text[2:]
    return Path(text)


def read_protect(home: Path, state: Path) -> tuple[list[Path], list[Path]]:
    """Return the protected locations as (excluded from every kind, places for the user's own files).

    The state directory is always protected, even when `PC_TIDY_HOME` moves it away from the default location
    listed in `protect-default.txt`: it holds the list that `apply` reads and the log of removed items.
    """
    protect_all: list[Path] = [state]
    protect_files: list[Path] = []
    section = protect_all
    for line in (SKILL_DIR / "protect-default.txt").read_text().splitlines():
        line = line.strip()
        if line == "[files]":
            section = protect_files
            continue
        if line and not line.startswith("#"):
            section.append(expand(home, line))
    user = state / "protect.txt"
    if user.exists():
        for line in user.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                protect_all.append(expand(home, line))
    return protect_all, protect_files


def under(path: Path, roots: list[Path]) -> bool:
    text = os.path.normpath(str(path))
    for root in roots:
        base = os.path.normpath(str(root))
        if text == base or text.startswith(base + os.sep):
            return True
    return False


def contains(path: Path, roots: list[Path]) -> bool:
    base = os.path.normpath(str(path))
    return any(os.path.normpath(str(root)).startswith(base + os.sep) for root in roots)


def resolve_links(home: Path, path: Path) -> Path:
    """Follow symlinks below the home directory one level at a time. Links above home are left as written."""
    try:
        rest = path.relative_to(home).parts
    except ValueError:
        return path
    current = home
    hops = 0
    for part in rest:
        current = current / part
        while current.is_symlink() and hops < 40:
            hops += 1
            target = os.readlink(current)
            current = Path(os.path.normpath(os.path.join(os.path.dirname(current), target)))
    return current


def managed_by(home: Path, path: Path) -> str | None:
    """When another mechanism (a symlinked repo or `chezmoi`) owns a settings file, return where to edit it."""
    real = resolve_links(home, path)
    if os.path.normpath(str(real)) != os.path.normpath(str(path)):
        return str(real)
    if shutil.which("chezmoi"):
        result = run(["chezmoi", "source-path", str(path)])
        if result is not None and result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    return None


# --- Running commands and measuring ----------------------------------------------


def run(args: list[str], cwd: str | None = None, timeout: int = 60) -> subprocess.CompletedProcess | None:
    try:
        return subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return None


def git(path: Path, *args: str) -> tuple[int, str]:
    result = run(["git", "--no-optional-locks", "-C", str(path), *args])
    if result is None:
        return 127, ""
    return result.returncode, result.stdout


# Files Finder writes just by opening a folder. They say nothing about how the contents are used,
# so they do not count toward the last-used date.
METADATA_NAMES = {".DS_Store", ".localized", "Icon\r"}


def file_stamp(name: str, st: os.stat_result, with_atime: bool = False) -> float | None:
    """Return when a file was last used, or None for files that do not count toward the last-used date.

    For executables, the only record of when they last ran is the access time (`atime`), so the newer of
    the modification and access times is used.
    """
    if name in METADATA_NAMES or name.startswith("._"):
        return None
    if with_atime or st.st_mode & 0o111:
        return max(st.st_mtime, st.st_atime)
    return st.st_mtime


def tree_size(path: Path, with_atime: bool = False) -> tuple[int, float]:
    """Return the total size in bytes under a directory and its newest timestamp. Symlinks are not followed.

    A directory's own modification time only says when an entry was added or removed, so it is used only
    when the directory holds no file that counts.
    """
    try:
        top = path.lstat()
    except OSError:
        return 0, 0.0
    if path.is_symlink() or not path.is_dir():
        stamp = file_stamp(path.name, top, with_atime)
        return top.st_blocks * 512, top.st_mtime if stamp is None else stamp
    total = 0
    newest = 0.0
    stack = [path]
    while stack:
        current = stack.pop()
        try:
            entries = list(os.scandir(current))
        except OSError:
            continue
        for entry in entries:
            try:
                st = entry.stat(follow_symlinks=False)
            except OSError:
                continue
            if entry.is_dir(follow_symlinks=False):
                stack.append(Path(entry.path))
                continue
            total += st.st_blocks * 512
            stamp = file_stamp(entry.name, st, with_atime)
            if stamp is not None:
                newest = max(newest, stamp)
    return total, newest if newest else top.st_mtime


def day(stamp: float) -> str:
    return datetime.datetime.fromtimestamp(stamp, datetime.timezone.utc).strftime("%Y-%m-%d")


def human(size: int) -> str:
    value = float(size)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if value < 1024 or unit == "TB":
            return f"{value:.0f}{unit}" if unit == "B" else f"{value:.1f}{unit}"
        value /= 1024
    return f"{size}B"


def in_use_dirs() -> list[str] | None:
    """Return the working directories of running processes, or None when they cannot be read.

    None is kept distinct from an empty list so that "unknown" is never treated as "not in use".
    """
    if not shutil.which("lsof"):
        return None
    result = run(["lsof", "-a", "-d", "cwd", "-F", "n"], timeout=60)
    if result is None:
        return None
    return [os.path.realpath(line[1:]) for line in result.stdout.splitlines() if line.startswith("n/")]


def used_by_process(path: Path, cwds: list[str]) -> bool:
    base = os.path.realpath(str(path))
    return any(cwd == base or cwd.startswith(base + os.sep) for cwd in cwds)


def busy_dirs(home: Path, cwds: list[str]) -> set[str]:
    """Return the working directories of running processes and all their parents, as paths the home walk uses.

    Calling `realpath` for every directory during the walk is slow, so the set is built once up front.
    """
    real_home = os.path.realpath(str(home))
    busy: set[str] = set()
    for cwd in cwds:
        if cwd != real_home and not cwd.startswith(real_home + os.sep):
            continue
        current = home
        busy.add(str(current))
        for part in Path(os.path.relpath(cwd, real_home)).parts:
            if part == ".":
                continue
            current = current / part
            busy.add(str(current))
    return busy


class Context:
    def __init__(self) -> None:
        self.home = Path(os.environ["HOME"])
        self.state = state_dir()
        config = read_config(self.state)
        self.days = config["days"]
        self.min_size = config["min_size_mb"] * 1024 * 1024
        now = os.environ.get("PC_TIDY_NOW")
        self.now = float(now) if now else time.time()
        self.cutoff = self.now - self.days * 86400
        self.protect_all, self.protect_files = read_protect(self.home, self.state)
        self.cwds = in_use_dirs()
        self.busy = busy_dirs(self.home, self.cwds or [])
        self.removed = read_removed(self.state)

    def app_dirs(self) -> list[Path]:
        value = os.environ.get("PC_TIDY_APP_DIRS")
        if value:
            return [Path(part) for part in value.split(":") if part]
        return [Path("/Applications"), self.home / "Applications"]


def read_removed(state: Path) -> list[dict]:
    path = state / "removed.jsonl"
    entries: list[dict] = []
    if not path.exists():
        return entries
    for line in path.read_text().splitlines():
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(entry, dict) and entry.get("schema_version") == RECORD_SCHEMA and entry.get("path"):
            entries.append(entry)
    return entries


def candidate(kind: str, path: str, size: int, last: float, recoverable: bool, action: str, **extra) -> dict:
    item = {
        "kind": kind,
        "path": path,
        "size_bytes": int(size),
        "last_used": day(last),
        "recoverable": recoverable,
        "action": action,
        "regrows": False,
        "source": None,
        "regrown": False,
        "note": "",
    }
    item.update(extra)
    return item


# --- Home-wide walk (repos and uncategorized items) ------------------------------


class Walk:
    """Walk the home directory once, collecting repo locations and old items that fit no other kind."""

    def __init__(self, ctx: Context, skipped: list[Path]) -> None:
        self.ctx = ctx
        self.skipped = [os.path.normpath(str(path)) for path in skipped]
        self.repos: list[tuple[Path, bool]] = []
        self.others: list[dict] = []
        self.unreadable = 0
        self.device = ctx.home.lstat().st_dev

    def run(self) -> None:
        sys.setrecursionlimit(20000)
        self.scan(self.ctx.home, top=True)

    def files_protected(self, path: Path) -> bool:
        return under(path, self.ctx.protect_files)

    def emit(self, path: Path, size: int, newest: float) -> None:
        # Anything a running process is inside is in use, however old it looks. When that cannot be measured, list nothing.
        if self.ctx.cwds is None or str(path) in self.ctx.busy:
            return
        if size >= self.ctx.min_size and not self.files_protected(path):
            self.others.append(candidate("other", str(path), size, newest, False, "trash"))

    def scan(self, path: Path, top: bool = False) -> tuple[int, float, bool]:
        """Return (size, newest timestamp, whether it contains something that must not be removed)."""
        try:
            st = path.lstat()
            entries = list(os.scandir(path))
        except OSError:
            self.unreadable += 1
            return 0, 0.0, True
        size = 0
        newest = 0.0
        # A directory a running process is inside cannot be removed as a whole, so its old entries become separate candidates.
        blocked = str(path) in self.ctx.busy
        old_children: list[tuple[Path, int, float]] = []
        for entry in entries:
            child = Path(entry.path)
            try:
                child_st = entry.stat(follow_symlinks=False)
            except OSError:
                blocked = True
                continue
            if entry.is_symlink():
                continue
            if entry.is_dir(follow_symlinks=False):
                if os.path.normpath(entry.path) in self.skipped or under(child, self.ctx.protect_all) \
                        or child_st.st_dev != self.device:
                    blocked = True
                    continue
                if (child / ".git").exists():
                    self.repos.append((child, (child / ".git").is_file()))
                    blocked = True
                    continue
                child_size, child_newest, child_blocked = self.scan(child)
                size += child_size
                newest = max(newest, child_newest)
                if child_blocked:
                    blocked = True
                elif child_newest < self.ctx.cutoff:
                    old_children.append((child, child_size, child_newest))
                continue
            file_size = child_st.st_blocks * 512
            size += file_size
            stamp = file_stamp(entry.name, child_st)
            if stamp is None:
                continue
            newest = max(newest, stamp)
            if stamp < self.ctx.cutoff:
                old_children.append((child, file_size, stamp))
        if not newest:
            # A directory with no file that counts falls back to its own modification time.
            newest = st.st_mtime
        wholly_old = not top and not blocked and newest < self.ctx.cutoff and not self.files_protected(path)
        if not wholly_old:
            # This directory cannot be removed as a whole, so its old entries become separate candidates.
            for child, child_size, child_newest in old_children:
                self.emit(child, child_size, child_newest)
        if self.files_protected(path):
            blocked = True
        return size, newest, blocked


# --- Measuring each kind ---------------------------------------------------------


def git_dir(path: Path, worktree: bool) -> Path | None:
    dot = path / ".git"
    if not worktree:
        return dot
    try:
        text = dot.read_text().strip()
    except OSError:
        return None
    if not text.startswith("gitdir:"):
        return None
    target = text[len("gitdir:"):].strip()
    return Path(os.path.normpath(os.path.join(str(path), target)))


def repo_last_used(path: Path, worktree: bool) -> float | None:
    code, out = git(path, "log", "-1", "--format=%ct", "HEAD")
    if code != 0 or not out.strip().isdigit():
        return None
    stamps = [float(out.strip())]
    gd = git_dir(path, worktree)
    if gd is not None:
        for name in ("HEAD", "logs/HEAD"):
            try:
                stamps.append((gd / name).lstat().st_mtime)
            except OSError:
                pass
    return max(stamps)


def default_ref(path: Path) -> str | None:
    code, out = git(path, "symbolic-ref", "-q", "refs/remotes/origin/HEAD")
    if code == 0 and out.strip():
        return out.strip().replace("refs/remotes/", "", 1)
    for ref in ("origin/main", "origin/master"):
        code, _ = git(path, "rev-parse", "--verify", "-q", ref)
        if code == 0:
            return ref
    return None


def content_in_default(path: Path) -> bool:
    """Whether every file HEAD's branch changed has the same contents on the remote default branch (a squash-merged branch)."""
    ref = default_ref(path)
    if ref is None:
        return False
    code, base = git(path, "merge-base", "HEAD", ref)
    if code != 0 or not base.strip():
        return False
    code, names = git(path, "diff", "--name-only", base.strip(), "HEAD")
    if code != 0:
        return False
    files = [name for name in names.splitlines() if name]
    if not files:
        return True
    code, _ = git(path, "diff", "--quiet", ref, "HEAD", "--", *files)
    return code == 0


def copy_elsewhere(path: Path, worktree: bool) -> bool:
    """Whether the contents survive elsewhere (on a remote) after deletion. When unsure, answer no."""
    if worktree:
        code, out = git(path, "rev-list", "-1", "HEAD", "--not", "--remotes")
        if code != 0:
            return False
        return not out.strip() or content_in_default(path)
    code, out = git(path, "rev-list", "-1", "--branches", "--not", "--remotes")
    if code != 0:
        return False
    if not out.strip():
        return True
    code, out = git(path, "rev-list", "-1", "--branches", "--not", "--remotes", "HEAD")
    if code != 0 or out.strip():
        return False
    return content_in_default(path)


def repo_refusal(ctx: Context, path: Path, worktree: bool, cwds: list[str] | None) -> str | None:
    """Return the reason it must not be removed, or None when it may be removed."""
    if cwds is None:
        return "in-use-unknown"
    if used_by_process(path, cwds):
        return "in-use"
    code, out = git(path, "status", "--porcelain")
    if code != 0:
        return "status-unknown"
    if out.strip():
        return "uncommitted"
    if not worktree:
        code, out = git(path, "worktree", "list", "--porcelain")
        if code != 0 or sum(1 for line in out.splitlines() if line.startswith("worktree ")) > 1:
            return "has-worktrees"
        code, out = git(path, "stash", "list")
        if code != 0 or out.strip():
            return "stashed"
    if not copy_elsewhere(path, worktree):
        return "unpushed"
    return None


def measure_repos(ctx: Context, walk: Walk) -> tuple[str, str, list[dict]]:
    if ctx.cwds is None:
        return "unknown", "lsof-missing", []
    items = []
    for path, worktree in walk.repos:
        # Repos under a dot-directory such as `~/.<name>/` are managed by tools (editor plugins, registries)
        # that look them up when they run, so they are not listed.
        if any(part.startswith(".") for part in path.relative_to(ctx.home).parts):
            continue
        last = repo_last_used(path, worktree)
        if last is None or last >= ctx.cutoff:
            continue
        if repo_refusal(ctx, path, worktree, ctx.cwds) is not None:
            continue
        size, _ = tree_size(path)
        kind = "worktree" if worktree else "repo"
        note = "Its contents are on the remote"
        items.append(candidate(kind, str(path), size, last, True, "delete", note=note))
    return "ok", "", items


def read_app(app: Path) -> dict:
    try:
        with open(app / "Contents" / "Info.plist", "rb") as handle:
            data = plistlib.load(handle)
    except (OSError, plistlib.InvalidFileException, ValueError):
        return {}
    return data if isinstance(data, dict) else {}


def installed_apps(ctx: Context) -> list[Path]:
    apps: list[Path] = []
    for place in ctx.app_dirs():
        if place.is_dir():
            apps.extend(sorted(child for child in place.iterdir() if child.suffix == ".app"))
    return apps


def normalize(text: str) -> str:
    return re.sub(r"[^a-z0-9]", "", text.lower())


def app_tokens(ctx: Context) -> set[str]:
    tokens: set[str] = set()
    places = list(ctx.app_dirs())
    if not os.environ.get("PC_TIDY_APP_DIRS"):
        places.append(Path("/System/Applications"))
    for place in places:
        if not place.is_dir():
            continue
        for app in place.iterdir():
            if app.suffix != ".app":
                continue
            info = read_app(app)
            names = [app.stem, str(info.get("CFBundleName", "")), str(info.get("CFBundleExecutable", ""))]
            bundle = str(info.get("CFBundleIdentifier", ""))
            names.append(bundle)
            names.extend(bundle.split("."))
            tokens.update(token for token in (normalize(name) for name in names) if len(token) >= 3)
    return tokens


def last_used_app(app: Path) -> float | None:
    result = run(["mdls", "-raw", "-name", "kMDItemLastUsedDate", str(app)])
    if result is None or result.returncode != 0:
        return None
    text = result.stdout.strip()
    try:
        return datetime.datetime.strptime(text, "%Y-%m-%d %H:%M:%S %z").timestamp()
    except ValueError:
        return None


def measure_apps(ctx: Context, walk: Walk) -> tuple[str, str, list[dict]]:
    if not shutil.which("mdls"):
        return "unknown", "mdls-missing", []
    items = []
    for app in installed_apps(ctx):
        bundle = str(read_app(app).get("CFBundleIdentifier", ""))
        if bundle.startswith("com.apple.") or under(app, ctx.protect_all):
            continue
        last = last_used_app(app)
        if last is None or last >= ctx.cutoff:
            continue
        size, _ = tree_size(app)
        items.append(candidate("app", str(app), size, last, True, "delete", note="It can be reinstalled"))
    return "ok", "", items


def leftover_name(name: str) -> str:
    name = re.sub(r"^[A-Z0-9]{10}\.", "", name)
    return re.sub(r"^group\.", "", name)


def matches_installed(name: str, tokens: set[str]) -> bool:
    key = normalize(leftover_name(name))
    if not key:
        return True
    if key in tokens:
        return True
    return len(key) >= 4 and any(len(token) >= 4 and (key in token or token in key) for token in tokens)


def measure_leftovers(ctx: Context, walk: Walk) -> tuple[str, str, list[dict]]:
    tokens = app_tokens(ctx)
    items = []
    for place in LEFTOVER_PLACES:
        root = ctx.home / place
        if not root.is_dir():
            continue
        for child in sorted(root.iterdir()):
            name = child.name
            if child.is_symlink() or not child.is_dir():
                continue
            if name.startswith("com.apple.") or ".com.apple." in name or normalize(name) in APPLE_SUPPORT_NAMES:
                continue
            if under(child, ctx.protect_all) or contains(child, ctx.protect_all):
                continue
            if matches_installed(name, tokens):
                continue
            size, newest = tree_size(child)
            if newest >= ctx.cutoff or size < ctx.min_size:
                continue
            items.append(candidate("leftover", str(child), size, newest, False, "trash",
                                   note="No matching app is installed"))
    return "ok", "", items


def version_last_used(version: Path) -> float:
    stamps = [version.lstat().st_mtime]
    bin_dir = version / "bin"
    if bin_dir.is_dir():
        for entry in os.scandir(bin_dir):
            try:
                st = entry.stat(follow_symlinks=False)
            except OSError:
                continue
            stamps.append(max(st.st_atime, st.st_mtime))
    return max(stamps)


def rc_lines(ctx: Context, word: str) -> list[str]:
    found = []
    for name in (".zshrc", ".zprofile", ".zshenv", ".bashrc", ".bash_profile", ".profile"):
        path = ctx.home / name
        try:
            lines = path.read_text(errors="replace").splitlines()
        except OSError:
            continue
        for number, line in enumerate(lines, 1):
            if word in line and not line.lstrip().startswith("#"):
                found.append(f"~/{name}:{number}")
    return found


def regrown_paths(ctx: Context) -> set[str]:
    return {entry["path"] for entry in ctx.removed if os.path.lexists(entry["path"])}


def measure_toolchains(ctx: Context, walk: Walk) -> tuple[str, str, list[dict]]:
    items = []
    regrown = regrown_paths(ctx)
    for name, root_rel, pattern in MANAGERS:
        root = ctx.home / root_rel
        if not root.is_dir() or root.is_symlink() or under(root, ctx.protect_all):
            continue
        versions = sorted(path for path in root.glob(pattern) if path.is_dir() and not path.is_symlink())
        stamps = {version: version_last_used(version) for version in versions}
        old = [version for version in versions if stamps[version] < ctx.cutoff]
        regrew = any(under(Path(path), [root]) for path in regrown)
        manager = None
        if (versions and len(old) == len(versions)) or regrew:
            size, newest = tree_size(root)
            last = max(stamps.values()) if stamps else newest
            where = rc_lines(ctx, name)
            note = f"Remove {name} entirely"
            if where:
                note += ". Shell configuration is not edited, so remove these lines by hand: " + ", ".join(where)
            manager = candidate("toolchain", str(root), size, last, True, "delete", note=note)
            items.append(manager)
        for version in old:
            size, _ = tree_size(version)
            item = candidate("toolchain", str(version), size, stamps[version], True, "delete",
                             regrows=True, note=f"{name} installs it again when it is needed")
            item["_source"] = manager
            items.append(item)
    return "ok", "", items


def measure_models(ctx: Context, walk: Walk) -> tuple[str, str, list[dict]]:
    items = []
    for place, pattern in MODEL_PLACES:
        root = ctx.home / place
        if not root.is_dir() or under(root, ctx.protect_all):
            continue
        units = [root] if not pattern else sorted(path for path in root.glob(pattern) if path.is_dir())
        for unit in units:
            size, newest = tree_size(unit, with_atime=True)
            if newest >= ctx.cutoff:
                continue
            items.append(candidate("model", str(unit), size, newest, True, "delete", note="It can be downloaded again"))
    return "ok", "", items


def parse_docker_size(text: str) -> int:
    match = re.match(r"^\s*([0-9.]+)\s*([kKMGT]?B)\s*$", text)
    if not match:
        return 0
    scale = {"B": 1, "kB": 10**3, "KB": 10**3, "MB": 10**6, "GB": 10**9, "TB": 10**12}[match.group(2)]
    return int(float(match.group(1)) * scale)


def measure_images(ctx: Context, walk: Walk) -> tuple[str, str, list[dict]]:
    if not shutil.which("docker"):
        return "unknown", "docker-missing", []
    listing = run(["docker", "image", "ls", "--format", "{{json .}}"], timeout=60)
    used = run(["docker", "ps", "-a", "--no-trunc", "--format", "{{.Image}}"], timeout=60)
    if listing is None or used is None or listing.returncode != 0 or used.returncode != 0:
        return "unknown", "docker-unreachable", []
    in_use = {line.strip() for line in used.stdout.splitlines() if line.strip()}
    items = []
    for line in listing.stdout.splitlines():
        try:
            image = json.loads(line)
        except json.JSONDecodeError:
            continue
        repo, tag, image_id = image.get("Repository", ""), image.get("Tag", ""), image.get("ID", "")
        ref = f"{repo}:{tag}" if repo and repo != "<none>" and tag != "<none>" else image_id
        if ref in in_use or repo in in_use or any(image_id and name.startswith(image_id) for name in in_use):
            continue
        created_text = re.sub(r"\s+[A-Z]{2,5}$", "", str(image.get("CreatedAt", "")))
        try:
            created = datetime.datetime.strptime(created_text, "%Y-%m-%d %H:%M:%S %z").timestamp()
        except ValueError:
            continue
        if created >= ctx.cutoff:
            continue
        items.append(candidate("image", ref, parse_docker_size(str(image.get("Size", ""))), created, True,
                               "command", command=["docker", "image", "rm", image_id],
                               note="No container uses it. It can be pulled again"))
    return "ok", "", items


def measure_records(ctx: Context, walk: Walk) -> tuple[str, str, list[dict]]:
    settings = ctx.home / ".claude" / "settings.json"
    if not settings.exists():
        return "ok", "", []
    try:
        data = json.loads(settings.read_text())
    except (OSError, json.JSONDecodeError):
        return "unknown", "settings-unreadable", []
    value = data.get("cleanupPeriodDays") if isinstance(data, dict) else None
    if not isinstance(value, int) or value <= ctx.days:
        return "ok", "", []
    note = f"Lower the Claude Code setting that keeps conversation logs for {value} days (cleanupPeriodDays) to {ctx.days} days"
    where = managed_by(ctx.home, settings)
    if where:
        note += f". Another mechanism owns this file, so it is not edited here; change it at {where}"
    item = candidate("record", str(settings), 0, settings.stat().st_mtime, True, "setting",
                     setting={"key": "cleanupPeriodDays", "value": ctx.days}, note=note)
    return "ok", "", [item]


def measure_others(ctx: Context, walk: Walk) -> tuple[str, str, list[dict]]:
    if ctx.cwds is None:
        return "unknown", "lsof-missing", []
    return "ok", "", walk.others


# The table of kinds: (name, OS, measure function). To add an OS, write its measure functions and add rows.
KINDS = [
    ("repo", "Darwin", measure_repos),
    ("app", "Darwin", measure_apps),
    ("leftover", "Darwin", measure_leftovers),
    ("toolchain", "Darwin", measure_toolchains),
    ("model", "Darwin", measure_models),
    ("image", "Darwin", measure_images),
    ("record", "Darwin", measure_records),
    ("other", "Darwin", measure_others),
]


def current_os() -> str:
    return os.environ.get("PC_TIDY_OS") or platform.system()


# --- The list --------------------------------------------------------------------


def build_list(ctx: Context) -> dict:
    skipped = [ctx.home / name for name in WALK_EXCLUDED + PACKAGE_CACHES]
    skipped += [ctx.home / root for _, root, _ in MANAGERS]
    skipped += [ctx.home / place.split("/")[0] for place, _ in MODEL_PLACES if not place.startswith(".cache")]
    walk = Walk(ctx, skipped)
    walk.run()
    kinds = []
    candidates: list[dict] = []
    for name, os_name, measure in KINDS:
        if os_name != current_os():
            continue
        status, reason, items = measure(ctx, walk)
        # Zero-byte items free no space and only make choosing harder, so they are not listed.
        items = [item for item in items if not (item["action"] in ("delete", "trash") and item["size_bytes"] == 0)]
        kinds.append({"name": name, "status": status, "reason": reason, "count": len(items) if status == "ok" else None})
        candidates.extend(items)
    regrown = regrown_paths(ctx)
    for number, item in enumerate(candidates, 1):
        item["id"] = number
        item["regrown"] = item["path"] in regrown
    for item in candidates:
        source = item.pop("_source", None)
        item["source"] = source["id"] if source else None
        item["contents"] = contents_of(item["path"])
        item["remote"] = remote_of(item)
    removed_by_path = {entry["path"]: entry for entry in ctx.removed}
    regrown_items = [
        {"path": path, "kind": removed_by_path[path].get("kind"), "removed_at": removed_by_path[path].get("removed_at")}
        for path in sorted(regrown)
    ]
    return {
        "schema_version": LIST_SCHEMA,
        "measured_at": datetime.datetime.fromtimestamp(ctx.now, datetime.timezone.utc).isoformat(),
        "home": str(ctx.home),
        "days": ctx.days,
        "min_size_mb": ctx.min_size // (1024 * 1024),
        "kinds": kinds,
        "candidates": candidates,
        "regrown": regrown_items,
        "unreadable_dirs": walk.unreadable,
    }


# The three recommendation levels. The agent writes them; for candidates it skips, the command assigns one
# from whether a copy exists. The selection page holds the label shown for each level.
ADVICE_LEVELS = ("delete", "check", "keep")
# Color number per kind, used by the page's table and detail panel.
KIND_COLORS = {"other": 1, "leftover": 2, "toolchain": 3, "repo": 4, "worktree": 4, "image": 5, "model": 6,
               "app": 2, "record": 6}
# Rows per table page. Beyond this, page controls appear above and below the table.
PAGE_ROWS = 50


def age(last_used: str, measured_at: str) -> dict | None:
    """Return how long before the measurement an item was last used, as {"unit": year|month|day, "n": count}.

    The page turns it into words such as "3 months ago" in the chosen language. None when a date cannot be read.
    """
    try:
        last = datetime.date.fromisoformat(last_used)
        now = datetime.date.fromisoformat(measured_at[:10])
    except ValueError:
        return None
    months = (now.year - last.year) * 12 + now.month - last.month - (1 if now.day < last.day else 0)
    if months >= 12:
        return {"unit": "year", "n": months // 12}
    if months >= 1:
        return {"unit": "month", "n": months}
    return {"unit": "day", "n": max(0, (now - last).days)}


PAGE = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>pc-tidy</title>
<style>
:root { --bg: #f7f7f5; --panel: #ffffff; --text: #1d1d1b; --muted: #5b5b57; --line: #e2e1dc;
  --accent: #2f5bd3; --on-accent: #ffffff; --pick: #e8eefc; --warn: #9a5b00; --track: #ebeae6;
  --ok: #23824f; --keep: #4d6a8f;
  --c1: #3b6fd8; --c2: #d07a2e; --c3: #2f9a6f; --c4: #8a55cf; --c5: #c94f6d; --c6: #6f6f68; }
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) { --bg: #161615; --panel: #20201e; --text: #ecebe6; --muted: #a9a8a1; --line: #34332f;
    --accent: #6e95ff; --on-accent: #10131a; --pick: #1f2b45; --warn: #f0b45c; --track: #2c2c29;
    --ok: #5fcf8f; --keep: #9db4d6; }
}
:root[data-theme="dark"] { --bg: #161615; --panel: #20201e; --text: #ecebe6; --muted: #a9a8a1; --line: #34332f;
  --accent: #6e95ff; --on-accent: #10131a; --pick: #1f2b45; --warn: #f0b45c; --track: #2c2c29;
  --ok: #5fcf8f; --keep: #9db4d6; }
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--text); font: 15px/1.6 -apple-system, "Hiragino Sans", sans-serif; }
main { max-width: 1320px; margin: 0 auto; padding: 20px 16px 48px; }
code { font: 13px ui-monospace, Menlo, monospace; }
.top { position: sticky; top: 0; z-index: 5; background: var(--bg); display: flex; justify-content: space-between;
  align-items: flex-start; gap: 16px; flex-wrap: wrap; padding: 8px 0 12px; }
.head { display: flex; align-items: center; gap: 8px 14px; flex-wrap: wrap; }
h1 { font-size: 22px; margin: 0; }
.lang { display: inline-flex; flex: none; border: 1px solid var(--line); border-radius: 8px; overflow: hidden; }
.lang button { background: var(--panel); color: var(--muted); border: 0; padding: 4px 12px; font-size: 13px; white-space: nowrap; }
.lang button + button { border-left: 1px solid var(--line); }
.lang button[aria-pressed="true"] { background: var(--accent); color: var(--on-accent); font-weight: 600; }
.lead { color: var(--muted); margin: 2px 0 0; }
.warn { color: var(--warn); margin: 2px 0 0; }
.picked { background: var(--panel); border: 1px solid var(--line); border-radius: 10px; padding: 10px 14px;
  display: grid; grid-template-columns: auto auto; gap: 6px 14px; align-items: center; min-width: min(100%, 420px); }
.picked b { font-size: 18px; }
.picked textarea { grid-column: 1 / -1; width: 100%; font: 13px ui-monospace, Menlo, monospace; color: var(--text);
  background: var(--bg); border: 1px solid var(--line); border-radius: 8px; padding: 6px 8px; resize: vertical; }
button { font: inherit; cursor: pointer; }
.copy { justify-self: end; background: var(--accent); color: var(--on-accent); border: 0; border-radius: 8px; padding: 7px 18px; font-weight: 600; }
.copy:disabled { opacity: .4; cursor: default; }
.tabs { display: flex; flex-wrap: wrap; gap: 4px; border-bottom: 1px solid var(--line); margin: 4px 0 12px; }
.tab { background: none; border: 0; border-bottom: 2px solid transparent; padding: 8px 12px; color: var(--muted); }
.tab.on { color: var(--text); border-bottom-color: var(--accent); font-weight: 600; }
.wrap { display: grid; grid-template-columns: minmax(0, 1fr); gap: 16px; align-items: start; }
@media (min-width: 1000px) { .wrap { grid-template-columns: minmax(0, 1fr) 380px; } }
table { width: 100%; border-collapse: collapse; }
th { text-align: left; white-space: nowrap; font-size: 13px; color: var(--muted); font-weight: 600; padding: 6px 8px; border-bottom: 1px solid var(--line); }
td { padding: 10px 8px; border-bottom: 1px solid var(--line); vertical-align: top; }
tbody tr { cursor: pointer; }
tbody tr:hover { background: color-mix(in srgb, var(--text) 4%, transparent); }
tbody tr.picked-row { background: var(--pick); }
tbody tr.shown td:first-child { box-shadow: inset 3px 0 var(--accent); }
.pick { width: 24px; height: 24px; border-radius: 6px; border: 1.5px solid var(--line); background: var(--panel); color: transparent; padding: 0; font-size: 14px; }
tr.picked-row .pick, .pick-big.on { background: var(--accent); border-color: var(--accent); color: var(--on-accent); }
.t { font-weight: 600; }
.s { color: var(--muted); font-size: 14px; }
.num { white-space: nowrap; font-weight: 600; }
.bar { height: 8px; border-radius: 4px; background: var(--track); overflow: hidden; margin-top: 6px; width: 96px; }
.bar i { display: block; height: 100%; border-radius: 4px; }
.when { white-space: nowrap; }
.sub { color: var(--muted); font-size: 13px; }
.badge { display: inline-block; white-space: nowrap; font-size: 13px; padding: 1px 8px; border-radius: 999px; border: 1px solid var(--line); }
.badge.trash { color: var(--warn); border-color: color-mix(in srgb, var(--warn) 45%, transparent); }
.badge.advice-delete { color: var(--ok); border-color: color-mix(in srgb, var(--ok) 45%, transparent); }
.badge.advice-check { color: var(--warn); border-color: color-mix(in srgb, var(--warn) 45%, transparent); }
.badge.advice-keep { color: var(--keep); border-color: color-mix(in srgb, var(--keep) 45%, transparent); }
.dot { display: inline-block; width: 10px; height: 10px; border-radius: 3px; margin-right: 6px; }
aside { background: var(--panel); border: 1px solid var(--line); border-radius: 10px; padding: 16px; }
@media (min-width: 1000px) { aside { position: sticky; top: 132px; } }
aside h2 { font-size: 19px; margin: 2px 0 6px; }
aside dl { display: grid; grid-template-columns: auto 1fr; gap: 6px 14px; margin: 14px 0; font-size: 14px; }
aside dt { color: var(--muted); }
aside dd { margin: 0; word-break: break-all; }
aside h3 { font-size: 14px; color: var(--muted); font-weight: 600; margin: 16px 0 6px; }
aside a { color: var(--accent); }
.crow { display: grid; grid-template-columns: minmax(0, 1fr) 96px 64px; gap: 8px; align-items: center; font-size: 14px; margin: 6px 0; }
.crow .bar { margin: 0; width: 100%; }
.cname { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.csize { text-align: right; color: var(--muted); }
.cmark { margin-left: 8px; font-size: 12px; font-weight: 400; color: var(--accent); border-color: color-mix(in srgb, var(--accent) 45%, transparent); }
.comment-box { width: 100%; min-height: 72px; font: inherit; color: var(--text); background: var(--bg); border: 1px solid var(--line); border-radius: 8px; padding: 8px; resize: vertical; }
.pick-big { margin-top: 12px; width: 100%; padding: 9px; border-radius: 8px; border: 1.5px solid var(--accent); background: var(--panel); color: var(--accent); font-weight: 600; }
.pager { display: flex; justify-content: center; gap: 6px; margin: 12px 0; flex-wrap: wrap; }
.pager button { min-width: 36px; padding: 5px 10px; border-radius: 8px; border: 1px solid var(--line); background: var(--panel); color: var(--text); }
.pager button.on { background: var(--accent); border-color: var(--accent); color: var(--on-accent); }
.pager button:disabled { opacity: .4; cursor: default; }
.empty { padding: 32px; text-align: center; color: var(--muted); }
</style>
</head>
<body>
<main>
<div class="top">
<div>
<div class="head"><h1 data-t="title"></h1>
<div class="lang" id="lang" role="group"><button type="button" data-lang="en" lang="en">English</button><button type="button" data-lang="ja" lang="ja">日本語</button></div>
</div>
<p class="lead" id="lead"></p>
<div id="warns"></div>
</div>
<div class="picked">
<span><span data-t="pickedCount"></span> <b id="picked-count"></b></span>
<span><span data-t="pickedSize"></span> <b id="picked-size"></b></span>
<textarea id="text" readonly rows="2"></textarea>
<span class="sub" data-t="hint"></span>
<button class="copy" id="copy" type="button" disabled></button>
</div>
</div>
<div class="tabs" id="tabs"></div>
<div class="wrap">
<div>
<nav class="pager" hidden></nav>
<table><thead><tr><th data-t="colPick"></th><th data-t="colItem"></th><th data-t="colSize"></th><th data-t="colLastUsed"></th><th data-t="colAdvice"></th><th data-t="colAction"></th></tr></thead>
<tbody id="rows"></tbody></table>
<nav class="pager" hidden></nav>
</div>
<aside id="detail"><p class="sub" data-t="detailEmpty"></p></aside>
</div>
</main>
<script type="application/json" id="data">__DATA__</script>
<script>
// Every interface string, in English and Japanese. What was written for a candidate (its name, description and
// reason) is shown as written in either language, and the lines copied back to the chat never change with it.
const I18N = {
  en: {
    title: "Cleanup candidates",
    language: "Language",
    lead: (p) => `${p.count === 1 ? "1 item" : p.count + " items"} not used in the last ${p.days} days, ${p.size} in total. Measured on ${p.date}.`,
    unmeasured: (kind, reason) => `${kind} could not be measured (reason: ${reason})`,
    unreadable: (n) => `${n === 1 ? "1 directory" : n + " directories"} could not be read; nothing inside was measured`,
    pickedCount: "Selected",
    count: (n) => (n === 1 ? "1 item" : n + " items"),
    pickedSize: "Selected size",
    placeholder: "Select items or write a comment, and the text to paste into the chat appears here",
    hint: "Paste the copied text into the chat to delete the selected items and get answers to your comments",
    copy: "Copy",
    copied: "Copied",
    copyManual: "Press ⌘C to copy",
    all: "All",
    colPick: "Select",
    colItem: "Item",
    colSize: "Size",
    colLastUsed: "Last used",
    colAdvice: "Advice",
    colAction: "Action",
    pick: "Select",
    unpick: "Deselect",
    commentBadge: "Comment",
    empty: "No candidates",
    detailEmpty: "Click a row to see what it is and what it contains",
    ago: (unit, n) => (unit === "day" && n === 0 ? "today" : `${n} ${unit}${n === 1 ? "" : "s"} ago`),
    factAdvice: "Advice",
    adviceBy: (label, ai) => label + (ai ? " (the AI's judgment)" : " (based on whether a copy exists)"),
    factReason: "Reason",
    factSize: "Size",
    factLastUsed: "Last used",
    factAction: "Action",
    actionHow: (label, how) => label + ({
      copy: " (a copy exists elsewhere, so it can be recovered)",
      trash: " (no other copy exists; it can be restored until the Trash is emptied)",
    }[how] || ""),
    factRemote: "Remote",
    factNotes: "Notes",
    regrown: "Came back after an earlier deletion",
    regrows: "Comes back after deletion",
    source: (n) => `Recreated by item ${n}`,
    joinNotes: (parts) => parts.join("; "),
    factDescribedBy: "Description",
    byAi: "Written by the AI",
    byFacts: "Generated from its contents",
    factPlace: "Location",
    insideDocker: "Inside Docker",
    contents: "Largest items inside",
    comment: "Comment",
    commentPlaceholder: "Write your thoughts or a question about this item",
    prev: "Previous",
    next: "Next",
    kind: {
      repo: "Local repos", worktree: "Worktrees", app: "Apps", leftover: "Leftovers of removed apps",
      toolchain: "Tools and runtimes", model: "AI models", image: "Docker images", record: "Log retention settings",
      other: "Uncategorized items",
    },
    tab: {
      repo: "Local repos", worktree: "Worktrees", app: "Apps", leftover: "Leftovers of removed apps",
      toolchain: "Tools and runtimes", model: "AI models", image: "Docker images", record: "Log retention settings",
      other: "Other old items",
    },
    advice: { delete: "Safe to delete", check: "Check first", keep: "Keep" },
    action: { delete: "Delete permanently", trash: "Move to Trash", command: "Remove with a command", setting: "Change a setting" },
  },
  ja: {
    title: "片付けの候補",
    language: "言語",
    lead: (p) => `${p.days}日より前から使っていない物${p.count}件、計${p.size}。${p.date}に測った`,
    unmeasured: (kind, reason) => `${kind}は測れなかった (理由 ${reason})`,
    unreadable: (n) => `読めなかったdirが${n}件在り、その中は測っていない`,
    pickedCount: "選んだ物",
    count: (n) => n + "件",
    pickedSize: "選んだ大きさ",
    placeholder: "選ぶかコメントを書くと、会話へ貼る文がここに出る",
    hint: "コピーした文を会話へ貼ると、選んだ物を消し、コメントにAIが答える",
    copy: "コピー",
    copied: "コピーした",
    copyManual: "⌘Cでコピー",
    all: "すべて",
    colPick: "選ぶ",
    colItem: "物",
    colSize: "大きさ",
    colLastUsed: "最後に使った",
    colAdvice: "おすすめ",
    colAction: "消し方",
    pick: "選ぶ",
    unpick: "選ぶのをやめる",
    commentBadge: "コメント",
    empty: "候補は無い",
    detailEmpty: "行を押すと、何の物かと中身がここに出る",
    ago: (unit, n) => n + { year: "年前", month: "か月前", day: "日前" }[unit],
    factAdvice: "おすすめ",
    adviceBy: (label, ai) => label + (ai ? "。AIの判断" : "。写しが在るかから付けた"),
    factReason: "理由",
    factSize: "大きさ",
    factLastUsed: "最後に使った",
    factAction: "消し方",
    actionHow: (label, how) => label + ({
      copy: "。写しが在るので取り戻せる",
      trash: "。ほかに写しが無いので、ゴミ箱を空にするまでは戻せる",
    }[how] || ""),
    factRemote: "remote",
    factNotes: "補足",
    regrown: "前に消したのにまた作られた",
    regrows: "消してもまた作られる",
    source: (n) => `作る元は${n}番`,
    joinNotes: (parts) => parts.join("。"),
    factDescribedBy: "説明の元",
    byAi: "AIが書いた",
    byFacts: "中身から作った",
    factPlace: "場所",
    insideDocker: "Dockerの中",
    contents: "中の大きい物",
    comment: "コメント",
    commentPlaceholder: "この候補への考えや問いを書く",
    prev: "前へ",
    next: "次へ",
    kind: {
      repo: "手元のrepo", worktree: "作業場所", app: "アプリ", leftover: "消したアプリの残り",
      toolchain: "道具と実行環境", model: "AIのモデル", image: "Dockerのimage", record: "溜まる記録の設定",
      other: "どの種類にも当たらない物",
    },
    tab: {
      repo: "手元のrepo", worktree: "作業場所", app: "アプリ", leftover: "消したアプリの残り",
      toolchain: "道具と実行環境", model: "AIのモデル", image: "Dockerのimage", record: "溜まる記録の設定",
      other: "その他の古い物",
    },
    advice: { delete: "消してよい", check: "確かめてから", keep: "残す" },
    action: { delete: "直接消す", trash: "ゴミ箱へ移す", command: "命令で消す", setting: "設定を変える" },
  },
};
const LANG_KEY = "pc-tidy:lang";
const data = JSON.parse(document.getElementById("data").textContent);
const byId = {};
const picked = new Set();
const saved = {};
const drafts = {};
for (const item of data.items) {
  byId[item.id] = item;
  saved[item.id] = item.comment || "";
}
let lang = "en";
try {
  const stored = window.localStorage.getItem(LANG_KEY);
  if (stored !== null && Object.prototype.hasOwnProperty.call(I18N, stored)) lang = stored;
} catch (error) { /* Without storage the page starts in English */ }
let rows = [];
let tab = "all";
let page = 1;
let shown = null;
let copyTimer = null;
const text = document.getElementById("text");
const copy = document.getElementById("copy");
function t(key, ...args) {
  const value = I18N[lang][key];
  return typeof value === "function" ? value(...args) : value;
}
function label(group, key) {
  return I18N[lang][group][key] || key;
}
function human(n) {
  let value = n;
  for (const unit of ["B", "KB", "MB", "GB", "TB"]) {
    if (value < 1024 || unit === "TB") return unit === "B" ? value.toFixed(0) + unit : value.toFixed(1) + unit;
    value /= 1024;
  }
}
function el(tag, cls, content) {
  const node = document.createElement(tag);
  if (cls) node.className = cls;
  if (content !== undefined) node.textContent = content;
  return node;
}
function dot(color) {
  const node = el("span", "dot");
  node.style.background = "var(--c" + color + ")";
  return node;
}
function ago(item) {
  return item.age ? t("ago", item.age.unit, item.age.n) : "";
}
function pasteText(ids, drafts, saved) {
  const lines = [];
  if (ids.length) lines.push("pc-tidy apply --select " + ids.join(","));
  const keys = Object.keys(drafts).map(Number).sort((a, b) => a - b);
  for (const id of keys) {
    const comment = String(drafts[id]).replace(/\s+/g, " ").trim();
    if (comment === (saved[id] || "")) continue;
    lines.push(comment ? "pc-tidy comment " + id + " " + comment : "pc-tidy comment " + id);
  }
  return lines.join("\n");
}
function draftKey(id) {
  return "pc-tidy:comment:" + byId[id].key;
}
function loadDrafts() {
  for (const item of data.items) {
    let value = null;
    try { value = window.localStorage.getItem(draftKey(item.id)); } catch (error) { value = null; }
    if (value === null) continue;
    if (value.replace(/\s+/g, " ").trim() === saved[item.id]) {
      try { window.localStorage.removeItem(draftKey(item.id)); } catch (error) { /* The page still renders when a draft cannot be removed */ }
    } else {
      drafts[item.id] = value;
    }
  }
}
function saveDraft(id, value) {
  drafts[id] = value;
  try {
    if (value.replace(/\s+/g, " ").trim() === saved[id]) window.localStorage.removeItem(draftKey(id));
    else window.localStorage.setItem(draftKey(id), value);
  } catch (error) { /* Even when the draft cannot be stored, it is still part of the text to copy */ }
}
function updateCopy() {
  const ids = [...picked].sort((a, b) => a - b);
  text.value = pasteText(ids, drafts, saved);
  copy.disabled = text.value === "";
}
function refresh() {
  const ids = [...picked].sort((a, b) => a - b);
  let sum = 0;
  rows.forEach((row) => {
    const on = picked.has(Number(row.dataset.id));
    row.classList.toggle("picked-row", on);
    if (on) sum += Number(row.dataset.size);
  });
  document.getElementById("picked-count").textContent = t("count", ids.length);
  document.getElementById("picked-size").textContent = human(sum);
  updateCopy();
  if (shown !== null) show(shown, false);
}
function toggle(id) {
  if (picked.has(id)) picked.delete(id); else picked.add(id);
  refresh();
}
function show(id, scroll) {
  shown = id;
  const item = byId[id];
  const box = document.getElementById("detail");
  box.replaceChildren();
  const kind = el("div", "sub");
  kind.append(dot(item.color), label("kind", item.kind));
  box.append(kind, el("h2", "", item.title), el("p", "", item.description));
  const facts = el("dl");
  const fact = (name, value) => facts.append(el("dt", "", name), value instanceof Node ? value : el("dd", "", value));
  const when = ago(item);
  const how = item.recoverable ? "copy" : item.action === "trash" ? "trash" : "";
  fact(t("factAdvice"), t("adviceBy", label("advice", item.advice), item.advised_by === "ai"));
  fact(t("factReason"), item.advice_reason);
  fact(t("factSize"), human(item.size));
  fact(t("factLastUsed"), when ? item.last_used + " (" + when + ")" : item.last_used);
  fact(t("factAction"), t("actionHow", label("action", item.action), how));
  if (item.remote) fact(t("factRemote"), item.remote);
  const extra = [];
  if (item.regrown) extra.push(t("regrown"));
  else if (item.regrows) extra.push(t("regrows"));
  if (item.source) extra.push(t("source", item.source));
  if (extra.length) fact(t("factNotes"), t("joinNotes", extra));
  fact(t("factDescribedBy"), t(item.described_by === "ai" ? "byAi" : "byFacts"));
  const place = el("dd");
  if (item.href) {
    const link = el("a", "", item.place);
    link.href = item.href;
    place.append(link);
  } else {
    place.textContent = t("insideDocker");
  }
  fact(t("factPlace"), place);
  box.append(facts);
  if (item.contents.length) {
    box.append(el("h3", "", t("contents")));
    const top = item.contents[0].size_bytes || 1;
    for (const part of item.contents) {
      const line = el("div", "crow");
      const bar = el("div", "bar");
      const fill = el("i");
      fill.style.width = Math.max(2, Math.round(part.size_bytes / top * 100)) + "%";
      fill.style.background = "var(--c" + item.color + ")";
      bar.append(fill);
      line.append(el("span", "cname", part.name), bar, el("span", "csize", human(part.size_bytes)));
      box.append(line);
    }
  }
  box.append(el("h3", "", t("comment")));
  const note = el("textarea", "comment-box");
  note.placeholder = t("commentPlaceholder");
  note.value = id in drafts ? drafts[id] : saved[id];
  note.addEventListener("input", () => { saveDraft(id, note.value); updateCopy(); });
  box.append(note);
  const on = picked.has(id);
  const button = el("button", "pick-big" + (on ? " on" : ""), on ? t("unpick") : t("pick"));
  button.type = "button";
  button.addEventListener("click", () => toggle(id));
  box.append(button);
  rows.forEach((row) => row.classList.toggle("shown", row.dataset.id === String(id)));
  if (scroll && window.innerWidth < 1000) box.scrollIntoView({ behavior: "smooth", block: "start" });
}
function buildTabs() {
  const box = document.getElementById("tabs");
  box.replaceChildren();
  for (const [kind, count] of [["all", data.items.length], ...data.tabs]) {
    const name = kind === "all" ? t("all") : label("tab", kind);
    const button = el("button", "tab" + (kind === tab ? " on" : ""), name + " " + count);
    button.type = "button";
    button.addEventListener("click", () => {
      tab = kind;
      page = 1;
      buildTabs();
      layout();
    });
    box.append(button);
  }
}
function buildRows() {
  const body = document.getElementById("rows");
  body.replaceChildren();
  rows = [];
  if (!data.items.length) {
    const cell = el("td", "empty", t("empty"));
    cell.colSpan = 6;
    const row = el("tr");
    row.append(cell);
    body.append(row);
    return;
  }
  const biggest = data.items.reduce((most, item) => Math.max(most, item.size), 1);
  for (const item of data.items) {
    const row = el("tr");
    row.dataset.id = item.id;
    row.dataset.size = item.size;
    row.dataset.kind = item.kind;
    row.dataset.advice = item.advice;
    const pick = el("button", "pick", "✓");
    pick.type = "button";
    pick.setAttribute("aria-label", t("pick"));
    pick.addEventListener("click", (event) => { event.stopPropagation(); toggle(item.id); });
    const pickCell = el("td");
    pickCell.append(pick);
    const name = el("div", "t");
    name.append(dot(item.color), item.title);
    if (item.comment) name.append(el("span", "badge cmark", t("commentBadge")));
    const what = el("td");
    what.append(name, el("div", "s", item.description));
    const size = el("td", "num", human(item.size));
    const bar = el("div", "bar");
    const fill = el("i");
    fill.style.width = (item.size ? Math.max(2, Math.round(item.size / biggest * 100)) : 0) + "%";
    fill.style.background = "var(--c" + item.color + ")";
    bar.append(fill);
    size.append(bar);
    const when = el("td", "when", ago(item));
    when.append(el("div", "sub", item.last_used));
    const advice = el("td");
    advice.append(el("span", "badge advice-" + item.advice, label("advice", item.advice)));
    const action = el("td");
    action.append(el("span", "badge" + (item.action === "trash" ? " trash" : ""), label("action", item.action)));
    row.append(pickCell, what, size, when, advice, action);
    row.addEventListener("click", () => show(item.id, true));
    body.append(row);
    rows.push(row);
  }
}
function layout() {
  const visible = rows.filter((row) => tab === "all" || row.dataset.kind === tab);
  const pages = Math.max(1, Math.ceil(visible.length / data.page_rows));
  if (page > pages) page = pages;
  rows.forEach((row) => { row.hidden = true; });
  visible.forEach((row, index) => { row.hidden = Math.floor(index / data.page_rows) + 1 !== page; });
  document.querySelectorAll(".pager").forEach((nav) => {
    nav.replaceChildren();
    nav.hidden = pages <= 1;
    const go = (to) => { page = to; layout(); };
    const prev = el("button", "", t("prev"));
    prev.type = "button";
    prev.disabled = page === 1;
    prev.addEventListener("click", () => go(page - 1));
    nav.append(prev);
    for (let number = 1; number <= pages; number += 1) {
      const button = el("button", number === page ? "on" : "", String(number));
      button.type = "button";
      button.addEventListener("click", () => go(number));
      nav.append(button);
    }
    const next = el("button", "", t("next"));
    next.type = "button";
    next.disabled = page === pages;
    next.addEventListener("click", () => go(page + 1));
    nav.append(next);
  });
}
function render() {
  document.documentElement.lang = lang;
  document.title = t("title");
  document.querySelectorAll("[data-t]").forEach((node) => { node.textContent = t(node.dataset.t); });
  const switcher = document.getElementById("lang");
  switcher.setAttribute("aria-label", t("language"));
  switcher.querySelectorAll("button").forEach((button) => {
    button.setAttribute("aria-pressed", String(button.dataset.lang === lang));
  });
  text.placeholder = t("placeholder");
  copy.textContent = t("copy");
  const total = data.items.reduce((sum, item) => sum + item.size, 0);
  document.getElementById("lead").textContent =
    t("lead", { count: data.items.length, days: data.days, size: human(total), date: data.measured });
  const warns = document.getElementById("warns");
  warns.replaceChildren();
  for (const entry of data.unmeasured) warns.append(el("p", "warn", t("unmeasured", label("kind", entry.kind), entry.reason)));
  if (data.unreadable) warns.append(el("p", "warn", t("unreadable", data.unreadable)));
  buildTabs();
  buildRows();
  layout();
  refresh();
}
document.querySelectorAll("#lang button").forEach((button) => {
  button.addEventListener("click", () => {
    if (button.dataset.lang === lang) return;
    lang = button.dataset.lang;
    try { window.localStorage.setItem(LANG_KEY, lang); } catch (error) { /* The choice then lasts until the page is closed */ }
    render();
  });
});
copy.addEventListener("click", async () => {
  try { await navigator.clipboard.writeText(text.value); copy.textContent = t("copied"); }
  catch (error) { text.select(); copy.textContent = t("copyManual"); }
  clearTimeout(copyTimer);
  copyTimer = setTimeout(() => { copy.textContent = t("copy"); }, 2000);
});
loadDrafts();
render();
if (data.items.length) show(data.items[0].id, false);
</script>
</body>
</html>
"""


def short(home: str, path: str) -> str:
    if path == home:
        return "~"
    if path.startswith(home + os.sep):
        return "~/" + path[len(home) + 1:]
    return path


def write_html(state: Path, listing: dict) -> Path:
    """Write the selection page: kind tabs, a table sorted by size, and a detail panel.

    The page renders itself from one embedded JSON payload, so it can switch its interface language in the
    browser. Names, descriptions and reasons are passed through as written; only the page's own labels change.
    """
    home = listing.get("home", "")
    measured = listing["measured_at"]
    items = sorted(listing["candidates"], key=lambda item: (-item["size_bytes"], item["id"]))
    totals: dict[str, int] = {}
    counts: dict[str, int] = {}
    for item in items:
        totals[item["kind"]] = totals.get(item["kind"], 0) + item["size_bytes"]
        counts[item["kind"]] = counts.get(item["kind"], 0) + 1
    entries = []
    for item in items:
        is_path = item["path"].startswith("/")
        entries.append({
            "id": item["id"],
            "kind": item["kind"],
            "color": KIND_COLORS.get(item["kind"], 6),
            "size": item["size_bytes"],
            "last_used": item["last_used"],
            "age": age(item["last_used"], measured),
            "advice": item["advice"],
            "advised_by": item.get("advised_by", "facts"),
            "advice_reason": item["advice_reason"],
            "action": item["action"],
            "recoverable": bool(item["recoverable"]),
            "remote": item.get("remote") or "",
            "regrown": bool(item.get("regrown")),
            "regrows": bool(item.get("regrows")),
            "source": item.get("source"),
            "described_by": item.get("described_by", "facts"),
            "title": item["title"],
            "description": item["description"],
            "place": short(home, item["path"]) if is_path else "",
            "href": "file://" + urllib.parse.quote(item["path"]) if is_path else "",
            "contents": item.get("contents", []),
            "comment": item.get("comment", ""),
            "key": item["path"],
        })
    payload = {
        "days": listing["days"],
        "measured": measured[:10],
        "unmeasured": [{"kind": kind["name"], "reason": kind["reason"]}
                       for kind in listing["kinds"] if kind["status"] != "ok"],
        "unreadable": listing.get("unreadable_dirs", 0),
        "page_rows": PAGE_ROWS,
        "tabs": [[kind, counts[kind]] for kind in sorted(totals, key=lambda name: -totals[name])],
        "items": entries,
    }
    # Escaping every "<" keeps a path or comment from ending the script element early.
    data = json.dumps(payload, ensure_ascii=False).replace("<", "\\u003c")
    path = state / "candidates.html"
    path.write_text(PAGE.replace("__DATA__", data), encoding="utf-8")
    return path


# --- What each candidate is -------------------------------------------------------


def contents_of(path: str, limit: int = 5) -> list[dict]:
    """Return up to `limit` of the largest entries inside a directory candidate, largest first. Empty for non-directories."""
    base = Path(path)
    if not path.startswith("/") or base.is_symlink() or not base.is_dir():
        return []
    parts = []
    try:
        entries = list(os.scandir(base))
    except OSError:
        return []
    for entry in entries:
        child = Path(entry.path)
        if entry.is_dir(follow_symlinks=False):
            size, _ = tree_size(child)
        else:
            try:
                size = entry.stat(follow_symlinks=False).st_blocks * 512
            except OSError:
                continue
        parts.append({"name": entry.name, "size_bytes": size})
    parts.sort(key=lambda part: (-part["size_bytes"], part["name"]))
    return parts[:limit]


def remote_of(item: dict) -> str | None:
    """Return the `origin` remote URL of a local repo or worktree, or None when it cannot be read."""
    if item["kind"] not in ("repo", "worktree"):
        return None
    code, out = git(Path(item["path"]), "remote", "get-url", "origin")
    url = out.strip()
    return url if code == 0 and url else None


VERSION_LIKE = re.compile(r"^v?[0-9]+(\.[0-9]+)+")


def facts_title(item: dict) -> str:
    """Build a candidate name from facts. A directory named only by a version number gets the tool's name in front."""
    path = item["path"]
    if not path.startswith("/"):
        return path
    base = Path(path)
    if VERSION_LIKE.match(base.name):
        parent = base.parent
        if parent.name in ("versions", "toolchains", "installs"):
            parent = parent.parent
        return f"{parent.name.lstrip('.')} {base.name}"
    return base.name


def facts_description(item: dict) -> str:
    """Build a sentence saying what a candidate is from the facts gathered by the command."""
    parts = []
    if item.get("note"):
        parts.append(item["note"])
    if item.get("remote"):
        parts.append(f"Remote: {item['remote']}")
    big = [f"{part['name']} ({human(part['size_bytes'])})" for part in item.get("contents", [])[:2] if part["size_bytes"]]
    if big:
        parts.append("Largest inside: " + ", ".join(big))
    return ". ".join(parts) if parts else KIND_LABELS[item["kind"]]


def facts_advice(item: dict) -> tuple[str, str]:
    """For a candidate without a recommendation, assign a level and reason from whether a copy exists."""
    if item["recoverable"]:
        return "delete", "A copy exists elsewhere, so it can be recovered after deletion"
    if item["action"] == "trash":
        return "check", ("No other copy exists, and it cannot be recovered once the Trash is emptied. "
                         "Check the contents before selecting it")
    return "check", "No other copy exists. Check the contents before selecting it"


def read_notes(state: Path) -> dict:
    """Return the descriptions saved earlier, keyed by candidate location."""
    path = state / "notes.json"
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError:
        reject("unreadable-notes", 3, str(path))
    if not isinstance(data, dict) or data.get("schema_version") != NOTES_SCHEMA or not isinstance(data.get("notes"), dict):
        reject("unknown-notes-version", 3, f"{path} has schema_version={data.get('schema_version') if isinstance(data, dict) else None!r}")
    return data["notes"]


def describe(listing: dict, notes: dict) -> None:
    """Give every candidate a name and description: the saved ones for described locations, otherwise built from facts."""
    for item in listing["candidates"]:
        note = notes.get(item["path"])
        if isinstance(note, dict) and note.get("name") and note.get("text"):
            item["title"], item["description"], item["described_by"] = note["name"], note["text"], "ai"
        else:
            item["title"], item["description"], item["described_by"] = facts_title(item), facts_description(item), "facts"
        item["comment"] = note.get("comment", "") if isinstance(note, dict) else ""
        if isinstance(note, dict) and note.get("advice") in ADVICE_LEVELS and note.get("why"):
            item["advice"], item["advice_reason"], item["advised_by"] = note["advice"], note["why"], "ai"
        else:
            item["advice"], item["advice_reason"] = facts_advice(item)
            item["advised_by"] = "facts"


COMMENT_LINE = re.compile(r"^pc-tidy comment ([0-9]+)(?:[ \t]+(.*))?$")


def command_comment(paste_file: str, as_json: bool) -> int:
    """Read only the comment lines from the pasted text and save each comment verbatim, keyed by candidate location.

    A line with only a number removes that candidate's comment. Everything is validated before anything is
    written, so a refusal leaves the state untouched.
    """
    state = state_dir()
    listing = load_list(state)
    try:
        pasted = Path(paste_file).read_text()
    except (OSError, UnicodeError) as error:
        reject("bad-paste", 2, f"cannot read {paste_file} ({type(error).__name__})")
    given: dict[str, str] = {}
    for line in pasted.splitlines():
        match = COMMENT_LINE.match(line.strip())
        if match:
            given[match.group(1)] = (match.group(2) or "").strip()
    if not given:
        reject("bad-paste", 2, "no line of the form `pc-tidy comment <number> <comment>`")
    by_id = {str(item["id"]): item for item in listing["candidates"]}
    unknown = [key for key in given if key not in by_id]
    if unknown:
        reject("unknown-id", 2, "numbers not in the list: " + ",".join(unknown))
    notes = read_notes(state)
    for key, comment in given.items():
        path = by_id[key]["path"]
        entry = dict(notes.get(path, {}))
        if comment:
            entry["comment"] = comment
        else:
            entry.pop("comment", None)
        if entry:
            notes[path] = entry
        else:
            notes.pop(path, None)
    (state / "notes.json").write_text(json.dumps({"schema_version": NOTES_SCHEMA, "notes": notes},
                                                 ensure_ascii=False, indent=2) + "\n")
    describe(listing, notes)
    listing["html"] = str(write_html(state, listing))
    (state / "candidates.json").write_text(json.dumps(listing, ensure_ascii=False, indent=2) + "\n")
    comments = [{"id": int(key), "title": by_id[key]["title"], "comment": comment} for key, comment in given.items()]
    if as_json:
        print(json.dumps({"html": listing["html"], "comments": comments}, ensure_ascii=False))
    else:
        for entry in comments:
            state_text = f'saved the comment "{entry["comment"]}"' if entry["comment"] else "removed the comment"
            print(f"Item {entry['id']} ({entry['title']}): {state_text}")
        print(f"Rebuilt the selection page: {listing['html']}")
    return 0


def load_list(state: Path) -> dict:
    """Read the latest list. Refuse when it is missing, unreadable, or in an older format."""
    listing_path = state / "candidates.json"
    if not listing_path.exists():
        reject("no-list", 2, "run list first")
    try:
        listing = json.loads(listing_path.read_text())
    except json.JSONDecodeError:
        reject("unreadable-list", 3, str(listing_path))
    if not isinstance(listing, dict) or listing.get("schema_version") != LIST_SCHEMA:
        version = listing.get("schema_version") if isinstance(listing, dict) else None
        reject("unknown-list-version", 3, f"schema_version={version!r}; run list again")
    return listing


def command_explain(notes_file: str, as_json: bool) -> int:
    """Take a name and description per number, save them keyed by candidate location, and rebuild the page.

    Everything is validated before anything is written, so a refusal leaves the state untouched.
    """
    state = state_dir()
    listing = load_list(state)
    try:
        given = json.loads(Path(notes_file).read_text())
    except (OSError, json.JSONDecodeError) as error:
        reject("bad-notes", 2, f"cannot read {notes_file} ({type(error).__name__})")
    if not isinstance(given, dict) or not given:
        reject("bad-notes", 2, 'pass an object of the form {"<number>": {"name": "<name>", "text": "<description>"}}')
    by_id = {str(item["id"]): item for item in listing["candidates"]}
    unknown = [key for key in given if key not in by_id]
    if unknown:
        reject("unknown-id", 2, "numbers not in the list: " + ",".join(unknown))
    for key, note in given.items():
        if not isinstance(note, dict) or not all(isinstance(note.get(field), str) and note[field].strip()
                                                 for field in ("name", "text")):
            reject("bad-notes", 2, f"item {key}: name and text must be non-empty strings")
        if ("advice" in note or "why" in note) and not (
                note.get("advice") in ADVICE_LEVELS and isinstance(note.get("why"), str) and note["why"].strip()):
            reject("bad-notes", 2, f"item {key}: advice must be one of {', '.join(ADVICE_LEVELS)}, with a reason in why")
    notes = read_notes(state)
    for key, note in given.items():
        # Keep any comment the user left earlier, even when the description is rewritten.
        entry = dict(notes.get(by_id[key]["path"], {}))
        entry.update(name=note["name"].strip(), text=note["text"].strip())
        if "advice" in note:
            entry.update(advice=note["advice"], why=note["why"].strip())
        notes[by_id[key]["path"]] = entry
    (state / "notes.json").write_text(json.dumps({"schema_version": NOTES_SCHEMA, "notes": notes},
                                                 ensure_ascii=False, indent=2) + "\n")
    describe(listing, notes)
    listing["html"] = str(write_html(state, listing))
    (state / "candidates.json").write_text(json.dumps(listing, ensure_ascii=False, indent=2) + "\n")
    if as_json:
        print(json.dumps({"html": listing["html"], "described": len(given)}, ensure_ascii=False))
    else:
        noun = "description" if len(given) == 1 else "descriptions"
        print(f"Saved {len(given)} {noun} and rebuilt the selection page: {listing['html']}")
    return 0


def print_list(ctx: Context, listing: dict) -> None:
    print(f"Not touched in the last {listing['days']} days (measured on {listing['measured_at'][:10]})")
    print("| # | Kind | Size | Last used | Recoverable | Action | Item |")
    print("|---|---|---|---|---|---|---|")
    for item in listing["candidates"]:
        back = "yes" if item["recoverable"] else "no"
        print(f"| {item['id']} | {KIND_LABELS[item['kind']]} | {human(item['size_bytes'])} | {item['last_used']} | "
              f"{back} | {ACTION_LABELS[item['action']]} | {short(str(ctx.home), item['path'])} |")
    for kind in listing["kinds"]:
        if kind["status"] != "ok":
            print(f"{KIND_LABELS[kind['name']]}: could not be measured (unknown, reason {kind['reason']})")
    for item in listing["regrown"]:
        print(f"Came back after an earlier deletion: {short(str(ctx.home), item['path'])}")
    if listing["unreadable_dirs"]:
        print(f"Could not read {listing['unreadable_dirs']} director{'y' if listing['unreadable_dirs'] == 1 else 'ies'}; "
              "nothing inside was measured")
    print(f"Selection page: {listing['html']}")


def write_listing(ctx: Context) -> dict:
    """Measure, then write the list and the selection page."""
    listing = build_list(ctx)
    ctx.state.mkdir(parents=True, exist_ok=True)
    describe(listing, read_notes(ctx.state))
    listing["html"] = str(write_html(ctx.state, listing))
    (ctx.state / "candidates.json").write_text(json.dumps(listing, ensure_ascii=False, indent=2) + "\n")
    return listing


def command_list(as_json: bool) -> int:
    ctx = Context()
    listing = write_listing(ctx)
    if as_json:
        print(json.dumps(listing, ensure_ascii=False, indent=2))
    else:
        print_list(ctx, listing)
    return 0


# --- Applying --------------------------------------------------------------------


def parse_select(text: str) -> list[int]:
    ids: list[int] = []
    for part in text.split(","):
        part = part.strip()
        if re.fullmatch(r"[0-9]+", part):
            ids.append(int(part))
        elif re.fullmatch(r"[0-9]+-[0-9]+", part):
            start, end = (int(value) for value in part.split("-"))
            ids.extend(range(start, end + 1))
        elif part:
            reject("bad-select", 2, f"not a number or range: {part}")
    if not ids:
        reject("bad-select", 2, "no numbers given")
    return sorted(set(ids))


def free_kb(home: Path) -> int | None:
    result = run(["df", "-k", "-P", str(home)])
    if result is None or result.returncode != 0:
        return None
    lines = result.stdout.strip().splitlines()
    if len(lines) < 2:
        return None
    fields = lines[-1].split()
    return int(fields[3]) if len(fields) >= 4 and fields[3].isdigit() else None


def local_snapshots() -> int | None:
    if not shutil.which("tmutil"):
        return None
    result = run(["tmutil", "listlocalsnapshots", "/"])
    if result is None or result.returncode != 0:
        return None
    return sum(1 for line in result.stdout.splitlines() if "com.apple.TimeMachine" in line)


def refusal(ctx: Context, item: dict, cwds: list[str] | None) -> str | None:
    """Right before removing, re-check whatever may have changed since the list was built."""
    if item["kind"] == "image":
        return None
    path = Path(item["path"])
    if not os.path.lexists(path):
        return "missing"
    if item["action"] == "setting":
        return None
    if under(path, ctx.protect_all) or contains(path, ctx.protect_all):
        return "protected"
    if item["kind"] in ("other", "leftover") and under(path, ctx.protect_files):
        return "protected"
    if item["kind"] in ("repo", "worktree"):
        return repo_refusal(ctx, path, item["kind"] == "worktree", cwds)
    if cwds is None:
        return "in-use-unknown"
    if used_by_process(path, cwds):
        return "in-use"
    return None


def to_trash(ctx: Context, path: Path) -> Path:
    trash = ctx.home / ".Trash"
    trash.mkdir(exist_ok=True)
    target = trash / path.name
    number = 1
    while os.path.lexists(target):
        number += 1
        target = trash / f"{path.name} {number}"
    shutil.move(str(path), str(target))
    return target


def remove_tree(path: Path) -> None:
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(path)
    else:
        path.unlink()


def remove_worktree(path: Path) -> str | None:
    code, common = git(path, "rev-parse", "--path-format=absolute", "--git-common-dir")
    if code != 0 or not common.strip():
        return "git-dir-unknown"
    result = run(["git", f"--git-dir={common.strip()}", "worktree", "remove", str(path)])
    if result is None or result.returncode != 0:
        return "worktree-remove-failed"
    return None


def apply_setting(ctx: Context, item: dict) -> tuple[str, str]:
    path = Path(item["path"])
    where = managed_by(ctx.home, path)
    if where:
        return "skipped", f"managed (change it at {where})"
    data = json.loads(path.read_text())
    data[item["setting"]["key"]] = item["setting"]["value"]
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    return "done", ""


def perform(ctx: Context, item: dict) -> tuple[str, str]:
    path = Path(item["path"])
    action = item["action"]
    if action == "setting":
        return apply_setting(ctx, item)
    if action == "command":
        result = run(item["command"], timeout=300)
        if result is None or result.returncode != 0:
            return "failed", "command-failed"
        return "done", ""
    if action == "trash":
        target = to_trash(ctx, path)
        return "done", f"moved to the Trash: {target}"
    if item["kind"] == "worktree":
        reason = remove_worktree(path)
        return ("failed", reason) if reason else ("done", "")
    remove_tree(path)
    return "done", ""


def command_apply(select: str, as_json: bool) -> int:
    ctx = Context()
    listing = load_list(ctx.state)
    by_id = {item["id"]: item for item in listing.get("candidates", [])}
    ids = parse_select(select)
    unknown = [number for number in ids if number not in by_id]
    if unknown:
        reject("unknown-id", 2, "numbers not in the list: " + ",".join(str(number) for number in unknown))
    before = free_kb(ctx.home)
    results = []
    trashed = 0
    log_lines = []
    for number in ids:
        item = by_id[number]
        reason = refusal(ctx, item, ctx.cwds)
        if reason:
            results.append({"id": number, "path": item["path"], "status": "skipped", "reason": reason})
            continue
        try:
            status, detail = perform(ctx, item)
        except OSError as error:
            status, detail = "failed", f"{type(error).__name__}: {error}"
        results.append({"id": number, "path": item["path"], "status": status, "reason": detail})
        if status == "done":
            if item["action"] == "trash":
                trashed += item["size_bytes"]
            log_lines.append(json.dumps({
                "schema_version": RECORD_SCHEMA, "path": item["path"], "kind": item["kind"], "action": item["action"],
                "size_bytes": item["size_bytes"],
                "removed_at": datetime.datetime.fromtimestamp(ctx.now, datetime.timezone.utc).isoformat(),
            }, ensure_ascii=False))
    if log_lines:
        with open(ctx.state / "removed.jsonl", "a") as handle:
            handle.write("\n".join(log_lines) + "\n")
    after = free_kb(ctx.home)
    snapshots = local_snapshots()
    report = {
        "schema_version": RECORD_SCHEMA,
        "results": results,
        "free_before_kb": before,
        "free_after_kb": after,
        "free_gain_kb": after - before if before is not None and after is not None else None,
        "trashed_bytes": trashed,
        "local_snapshots": snapshots if snapshots is not None else "unknown",
    }
    if as_json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print_apply(ctx, report)
    return 1 if any(result["status"] == "failed" for result in results) else 0


def print_apply(ctx: Context, report: dict) -> None:
    for result in report["results"]:
        where = short(str(ctx.home), result["path"])
        if result["status"] == "done":
            print(f"Removed: {where}" + (f" ({result['reason']})" if result["reason"] else ""))
        elif result["status"] == "skipped":
            print(f"Skipped: {where} (reason: {result['reason']})")
        else:
            print(f"Failed: {where} (reason: {result['reason']})")
    if report["free_gain_kb"] is None:
        print("Free space could not be measured (unknown)")
    else:
        print(f"Free space went from {human(report['free_before_kb'] * 1024)} to {human(report['free_after_kb'] * 1024)}, "
              f"a gain of {human(max(report['free_gain_kb'], 0) * 1024)}")
    if report["trashed_bytes"]:
        print(f"{human(report['trashed_bytes'])} moved to the Trash becomes free space once the Trash is emptied")
    snapshots = report["local_snapshots"]
    if snapshots == "unknown":
        print("Time Machine local snapshots could not be measured (unknown)")
    elif snapshots:
        noun = "snapshot exists" if snapshots == 1 else "snapshots exist"
        print(f"{snapshots} Time Machine local {noun}; the freed space will not appear until they are removed")


def main(argv: list[str]) -> int:
    if not argv or argv[0] not in ("list", "apply", "explain", "comment"):
        reject("bad-usage", 2, "usage: tidy.sh list [--json] | tidy.sh explain --notes <file> [--json] | "
                               "tidy.sh comment --paste <file> [--json] | tidy.sh apply --select <numbers> [--json]")
    if current_os() != "Darwin":
        reject("os-not-supported", 3, f"no kinds are defined for OS={current_os()} yet")
    command, rest = argv[0], argv[1:]
    as_json = "--json" in rest
    rest = [arg for arg in rest if arg != "--json"]
    if command == "list":
        if rest:
            reject("bad-usage", 2, "list takes only --json")
        return command_list(as_json)
    if command == "explain":
        if len(rest) != 2 or rest[0] != "--notes":
            reject("bad-usage", 2, "explain takes --notes <file>")
        return command_explain(rest[1], as_json)
    if command == "comment":
        if len(rest) != 2 or rest[0] != "--paste":
            reject("bad-usage", 2, "comment takes --paste <file>")
        return command_comment(rest[1], as_json)
    if len(rest) != 2 or rest[0] != "--select":
        reject("bad-usage", 2, "apply takes --select <numbers>")
    return command_apply(rest[1], as_json)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
