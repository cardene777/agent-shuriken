#!/usr/bin/env python3
"""長く使っていない物を一覧にし、選んだ物だけを片付ける。

呼び方は同じ dir の `tidy.sh` が持つ。 技の dir だけを写した PC でも動くよう、この dir の外の物を読まない。

状態の置き場は `$IKKAN_USER_DIR/tidy/` (未設定なら `~/.ikkan/tidy/`) で、次の file を持つ。

| file | 中身 |
|---|---|
| `config` | `days=<日数>` (既定 30) と `min_size_mb=<MB>` (既定 100) |
| `protect.txt` | 人ごとに守る置き場。 1 行に 1 つ、`~` はホーム |
| `candidates.json` | 前の一覧。 適用と説明はこの番号を読む (`schema_version` 2。 1 は読まずに断る) |
| `candidates.html` | 前の一覧を押して選ぶ頁 |
| `notes.json` | 技を回す AI が書いた、候補の場所ごとの名前と説明と消すおすすめと、本人のコメント (`schema_version` 1。 おすすめとコメントの欄は無くてもよい) |
| `removed.jsonl` | 消した物の記録。 1 行に 1 件 (`schema_version` 1) |

種類は `KINDS` の表が持つ。 OS ごとに足す時は、測る関数を書いて表に 1 行足す。
最後に使った日は file の読んだ日に頼らず、種類ごとの根拠で読む (repo は最後の commit と checkout)。
読んだ日 (`atime`) を使うのは、呼ばれた日を他に知る手が無い道具とモデルだけで、
誤って新しく見える側にしか倒れない (候補が減るだけで、誤って消す側には倒れない)。
"""

from __future__ import annotations

import datetime
import html
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

# 形式の版は file ごとに持つ。 一覧は中身と説明の欄を足した時に 2 へ上げた。
LIST_SCHEMA = 2
RECORD_SCHEMA = 1
NOTES_SCHEMA = 1
SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPT_DIR.parent
DEFAULT_DAYS = 30
DEFAULT_MIN_SIZE_MB = 100

KIND_LABELS = {
    "repo": "手元のrepo",
    "worktree": "作業場所",
    "app": "アプリ",
    "leftover": "消したアプリの残り",
    "toolchain": "道具と実行環境",
    "model": "AIのモデル",
    "image": "Dockerのimage",
    "record": "溜まる記録の設定",
    "other": "どの種類にも当たらない物",
}
ACTION_LABELS = {
    "delete": "直接消す",
    "trash": "ゴミ箱へ移す",
    "command": "命令で消す",
    "setting": "設定を変える",
}

# 道具の管理の仕組みと、版を置く場所。 root はホームからの相対。
MANAGERS = [
    ("rustup", ".rustup", "toolchains/*"),
    ("elan", ".elan", "toolchains/*"),
    ("mise", ".local/share/mise", "installs/*/*"),
    ("nvm", ".nvm", "versions/node/*"),
    ("pyenv", ".pyenv", "versions/*"),
    ("rbenv", ".rbenv", "versions/*"),
]
# AIのモデルの置き場と、1 件に数える単位。 単位が空の時は置き場ごと 1 件に数える。
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
# Apple のアプリと OS が `Application Support` に置く名前。 対応するアプリの .app が無いため、残りと取り違えないよう外す。
APPLE_SUPPORT_NAMES = {
    "addressbook", "animoji", "callhistorydb", "callhistorytransactions", "clouddocs", "crashreporter",
    "diskimages", "dock", "facetime", "fileprovider", "icloud", "icdd", "knowledge", "mobilesync",
    "networkserviced", "syncservices", "accounts", "appstore", "coreparsec", "familycircle",
    "homeenergyd", "locationaccessstored", "quicklook", "siri", "videoconference", "tipsd",
    "stocks", "weather", "maps", "news", "podcasts", "photos", "books", "contacts", "calendars",
    "notes", "reminders", "safari", "mail", "messages", "shortcuts", "translate",
}
# ホーム全体を測る時に入らない置き場。 種類が別に測るか、キャッシュで各道具の掃除の命令の受け持ちのため。
WALK_EXCLUDED = ["Library", ".cache", ".Trash", "Applications"]
# パッケージの管理の仕組みが、消しても次に使う時に取り直して作る置き場。
# 作り直せるキャッシュは各道具の掃除の命令 (`npm cache clean`など) の受け持ちなので、ホームを辿る時に入らない。
# 入らない置き場はその上の dir も丸ごとの候補にしないので、`~/.cargo/bin`の道具を巻き込まない。
PACKAGE_CACHES = [
    ".cargo/registry", ".cargo/git", ".npm", ".pnpm-store", ".bun/install/cache", ".yarn/berry/cache",
    ".gradle/caches", ".gradle/wrapper/dists", ".m2/repository", "go/pkg/mod", ".pub-cache",
    ".nuget/packages", ".cocoapods/repos",
]


def reject(reason: str, code: int, detail: str = "") -> None:
    suffix = f" {detail}" if detail else ""
    print(f"tidy: rejected (reason={reason}){suffix}", file=sys.stderr)
    sys.exit(code)


# --- 置き場と設定 ----------------------------------------------------------------


def state_dir() -> Path:
    if "IKKAN_USER_DIR" in os.environ:
        value = os.environ["IKKAN_USER_DIR"]
        if not value:
            reject("no-user-dir", 2, "IKKAN_USER_DIR が空で、状態を置く場所が無い")
    else:
        value = os.path.join(os.environ.get("HOME", ""), ".ikkan")
    return Path(value).expanduser() / "tidy"


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
                reject("bad-config", 2, f"{key}={value} は正の整数でない")
            config[key] = int(value)
    return config


def expand(home: Path, text: str) -> Path:
    if text == "~":
        return home
    if text.startswith("~/"):
        return home / text[2:]
    return Path(text)


def read_protect(home: Path, state: Path) -> tuple[list[Path], list[Path]]:
    """守る置き場を (全ての種類から外す物, 本人が作った file の置き場) の 2 つで返す。"""
    protect_all: list[Path] = []
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
    """ホームより下の link を 1 段ずつ辿る。 ホームより上の link は辿らず、人の書いた形のまま返す。"""
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
    """設定の file を別の仕組み (link の先の repo か `chezmoi`) が持つ時、直す場所を返す。"""
    real = resolve_links(home, path)
    if os.path.normpath(str(real)) != os.path.normpath(str(path)):
        return str(real)
    if shutil.which("chezmoi"):
        result = run(["chezmoi", "source-path", str(path)])
        if result is not None and result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    return None


# --- 命令と測り ----------------------------------------------------------------


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


# Finder が dir を開くだけで書く file。 中身の使われ方を表さないので、最後に使った日に数えない。
METADATA_NAMES = {".DS_Store", ".localized", "Icon\r"}


def file_stamp(name: str, st: os.stat_result, with_atime: bool = False) -> float | None:
    """file の最後に使った日時を返す。 最後に使った日に数えない file は None。

    実行できる file は、呼ばれた日が読んだ日 (`atime`) にしか残らないので、変えた日と読んだ日の新しい方を使う。
    """
    if name in METADATA_NAMES or name.startswith("._"):
        return None
    if with_atime or st.st_mode & 0o111:
        return max(st.st_mtime, st.st_atime)
    return st.st_mtime


def tree_size(path: Path, with_atime: bool = False) -> tuple[int, float]:
    """dir の下の大きさ (byte) と、一番新しい日時を返す。 link は辿らない。

    dir 自身の変えた日は、中の file を足すか消した日なので数えない。 数える file が 1 つも無い時だけ使う。
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
    """動いている process の今いる dir を返す。 測れない時は None (使っていないと潰さない)。"""
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
    """動いている process の今いる dir と、その上の dir を、ホームを辿る時の path の形で返す。

    辿る間に dir ごとに `realpath` を引くと遅いため、先に 1 度だけ作って引き当てる。
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
        now = os.environ.get("IKKAN_TIDY_NOW")
        self.now = float(now) if now else time.time()
        self.cutoff = self.now - self.days * 86400
        self.protect_all, self.protect_files = read_protect(self.home, self.state)
        self.cwds = in_use_dirs()
        self.busy = busy_dirs(self.home, self.cwds or [])
        self.removed = read_removed(self.state)

    def app_dirs(self) -> list[Path]:
        value = os.environ.get("IKKAN_TIDY_APP_DIRS")
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


# --- ホーム全体の走査 (repo とどの種類にも当たらない物) --------------------------


class Walk:
    """ホームを 1 度だけ辿り、repo の置き場と、どの種類にも当たらない古い物を集める。"""

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
        # 動いている process が中に居る物は、古く見えても使っている。 測れない時は出さない。
        if self.ctx.cwds is None or str(path) in self.ctx.busy:
            return
        if size >= self.ctx.min_size and not self.files_protected(path):
            self.others.append(candidate("other", str(path), size, newest, False, "trash"))

    def scan(self, path: Path, top: bool = False) -> tuple[int, float, bool]:
        """(大きさ, 一番新しい日時, 消せない物を中に持つか) を返す。"""
        try:
            st = path.lstat()
            entries = list(os.scandir(path))
        except OSError:
            self.unreadable += 1
            return 0, 0.0, True
        size = 0
        newest = 0.0
        # 動いている process が中に居る dir は丸ごとは消せないので、中の古い物を 1 件ずつ候補にする。
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
            # 数える file が 1 つも無い dir は、dir 自身の変えた日で読む。
            newest = st.st_mtime
        wholly_old = not top and not blocked and newest < self.ctx.cutoff and not self.files_protected(path)
        if not wholly_old:
            # この dir ごとは消せないので、中の古い物を 1 件ずつ候補にする。
            for child, child_size, child_newest in old_children:
                self.emit(child, child_size, child_newest)
        if self.files_protected(path):
            blocked = True
        return size, newest, blocked


# --- 種類ごとの測り --------------------------------------------------------------


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
    """HEAD の枝が変えた file が、既定の枝の remote 側に同じ中身で入っているか (squash で取り込んだ枝)。"""
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
    """消しても中身が他 (remote) に残るか。 判定できない時は残らない側に倒す。"""
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
    """消してはいけない理由を返す。 消してよい時は None。"""
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
        # `~/.<名前>/` の下の repo は道具が管理する物 (editor の plugin や登録簿) で、使う時に道具が引くため出さない。
        if any(part.startswith(".") for part in path.relative_to(ctx.home).parts):
            continue
        last = repo_last_used(path, worktree)
        if last is None or last >= ctx.cutoff:
            continue
        if repo_refusal(ctx, path, worktree, ctx.cwds) is not None:
            continue
        size, _ = tree_size(path)
        kind = "worktree" if worktree else "repo"
        note = "中身がremoteに在る"
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
    if not os.environ.get("IKKAN_TIDY_APP_DIRS"):
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
        items.append(candidate("app", str(app), size, last, True, "delete", note="入れ直せる"))
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
                                   note="対応するアプリが見つからない"))
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
            note = f"{name}ごと外す"
            if where:
                note += "。 shellの設定の行は書き換えないので、手で消す: " + ", ".join(where)
            manager = candidate("toolchain", str(root), size, last, True, "delete", note=note)
            items.append(manager)
        for version in old:
            size, _ = tree_size(version)
            item = candidate("toolchain", str(version), size, stamps[version], True, "delete",
                             regrows=True, note=f"{name}が使う時にまた入れる")
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
            items.append(candidate("model", str(unit), size, newest, True, "delete", note="取り直せる"))
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
                               note="使うcontainerが無い。 取り直せる"))
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
    note = f"Claude Codeの会話の記録を{value}日残す設定 (cleanupPeriodDays) を{ctx.days}日にする"
    where = managed_by(ctx.home, settings)
    if where:
        note += f"。 別の仕組みが持つfileなので書き換えず、直す場所を示す: {where}"
    item = candidate("record", str(settings), 0, settings.stat().st_mtime, True, "setting",
                     setting={"key": "cleanupPeriodDays", "value": ctx.days}, note=note)
    return "ok", "", [item]


def measure_others(ctx: Context, walk: Walk) -> tuple[str, str, list[dict]]:
    if ctx.cwds is None:
        return "unknown", "lsof-missing", []
    return "ok", "", walk.others


# 種類の表。 (名前, OS, 測る関数) を持つ。 OS を足す時は、その OS の測る関数を書いて行を足す。
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
    return os.environ.get("IKKAN_TIDY_OS") or platform.system()


# --- 一覧 ------------------------------------------------------------------------


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
        # 消しても空きが増えない 0B の物は、選ぶ手間だけを増やすので出さない。
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


# 消すのがおすすめかの 3 段階。 技を回す AI が書き、書かない候補は写しが在るかで命令が付ける。
ADVICE_LABELS = {"delete": "消してよい", "check": "確かめてから", "keep": "残す"}
# 頁の表と横の欄で使う、種類の短い名前と色の番号。
TAB_LABELS = dict(KIND_LABELS, other="その他の古い物")
KIND_COLORS = {"other": 1, "leftover": 2, "toolchain": 3, "repo": 4, "worktree": 4, "image": 5, "model": 6,
               "app": 2, "record": 6}
# 表を分ける 1 頁の行の数。 これを超えると頁を移る欄を表の上と下に出す。
PAGE_ROWS = 50


def ago(last_used: str, measured_at: str) -> str:
    """最後に使った日が、測った日からどれだけ前かを返す。"""
    try:
        last = datetime.date.fromisoformat(last_used)
        now = datetime.date.fromisoformat(measured_at[:10])
    except ValueError:
        return ""
    months = (now.year - last.year) * 12 + now.month - last.month - (1 if now.day < last.day else 0)
    if months >= 12:
        return f"{months // 12}年前"
    if months >= 1:
        return f"{months}か月前"
    return f"{max(0, (now - last).days)}日前"


PAGE = """<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>片付けの候補</title>
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
h1 { font-size: 22px; margin: 0; }
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
<div><h1>片付けの候補</h1><p class="lead">__LEAD__</p>__WARN__</div>
<div class="picked">
<span>選んだ物 <b id="picked-count">0件</b></span>
<span>選んだ大きさ <b id="picked-size">0B</b></span>
<textarea id="text" readonly rows="2" placeholder="選ぶかコメントを書くと、会話へ貼る文がここに出る"></textarea>
<span class="sub">コピーした文を会話へ貼ると、選んだ物を消し、コメントにAIが答える</span>
<button class="copy" id="copy" disabled>コピー</button>
</div>
</div>
<div class="tabs">__TABS__</div>
<div class="wrap">
<div>
__PAGER__
<table><thead><tr><th>選ぶ</th><th>物</th><th>大きさ</th><th>最後に使った</th><th>おすすめ</th><th>消し方</th></tr></thead>
<tbody>__ROWS__</tbody></table>
__PAGER__
</div>
<aside id="detail"><p class="sub">行を押すと、何の物かと中身がここに出る</p></aside>
</div>
</main>
<script type="application/json" id="details">__DETAILS__</script>
<script>
const details = JSON.parse(document.getElementById("details").textContent);
const rows = [...document.querySelectorAll("tr[data-id]")];
const picked = new Set();
const saved = {};
const drafts = {};
for (const [id, item] of Object.entries(details)) saved[id] = item.comment || "";
let tab = "all";
let page = 1;
let shown = null;
const text = document.getElementById("text");
const copy = document.getElementById("copy");
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
function pasteText(ids, drafts, saved) {
  const lines = [];
  if (ids.length) lines.push("pc-tidy apply --select " + ids.join(","));
  const keys = Object.keys(drafts).map(Number).sort((a, b) => a - b);
  for (const id of keys) {
    const comment = String(drafts[id]).replace(/\\s+/g, " ").trim();
    if (comment === (saved[id] || "")) continue;
    lines.push(comment ? "pc-tidy comment " + id + " " + comment : "pc-tidy comment " + id);
  }
  return lines.join("\\n");
}
function draftKey(id) {
  return "pc-tidy:comment:" + details[id].key;
}
function loadDrafts() {
  for (const id of Object.keys(details)) {
    let value = null;
    try { value = window.localStorage.getItem(draftKey(id)); } catch (error) { value = null; }
    if (value === null) continue;
    if (value.replace(/\\s+/g, " ").trim() === saved[id]) {
      try { window.localStorage.removeItem(draftKey(id)); } catch (error) { /* 下書きを消せなくても頁は出す */ }
    } else {
      drafts[id] = value;
    }
  }
}
function saveDraft(id, value) {
  drafts[id] = value;
  try {
    if (value.replace(/\\s+/g, " ").trim() === saved[id]) window.localStorage.removeItem(draftKey(id));
    else window.localStorage.setItem(draftKey(id), value);
  } catch (error) { /* 下書きを残せなくても、コピーする文には入る */ }
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
  document.getElementById("picked-count").textContent = ids.length + "件";
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
  const item = details[id];
  const box = document.getElementById("detail");
  box.replaceChildren();
  const kind = el("div", "sub");
  const dot = el("span", "dot");
  dot.style.background = "var(--c" + item.color + ")";
  kind.append(dot, item.kind);
  box.append(kind, el("h2", "", item.title), el("p", "", item.description));
  const facts = el("dl");
  for (const [label, value] of item.facts) facts.append(el("dt", "", label), el("dd", "", value));
  const place = el("dd");
  if (item.href) {
    const link = el("a", "", item.place);
    link.href = item.href;
    place.append(link);
  } else {
    place.textContent = item.place;
  }
  facts.append(el("dt", "", "場所"), place);
  box.append(facts);
  if (item.contents.length) {
    box.append(el("h3", "", "中の大きい物"));
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
  box.append(el("h3", "", "コメント"));
  const note = el("textarea", "comment-box");
  note.placeholder = "この候補への考えや問いを書く";
  note.value = id in drafts ? drafts[id] : saved[id];
  note.addEventListener("input", () => { saveDraft(id, note.value); updateCopy(); });
  box.append(note);
  const on = picked.has(Number(id));
  const button = el("button", "pick-big" + (on ? " on" : ""), on ? "選ぶのをやめる" : "選ぶ");
  button.addEventListener("click", () => toggle(Number(id)));
  box.append(button);
  rows.forEach((row) => row.classList.toggle("shown", row.dataset.id === String(id)));
  if (scroll && window.innerWidth < 1000) box.scrollIntoView({ behavior: "smooth", block: "start" });
}
function layout() {
  const visible = rows.filter((row) => tab === "all" || row.dataset.kind === tab);
  const pages = Math.max(1, Math.ceil(visible.length / __PAGE_ROWS__));
  if (page > pages) page = pages;
  rows.forEach((row) => { row.hidden = true; });
  visible.forEach((row, index) => { row.hidden = Math.floor(index / __PAGE_ROWS__) + 1 !== page; });
  document.querySelectorAll(".pager").forEach((nav) => {
    nav.replaceChildren();
    nav.hidden = pages <= 1;
    const go = (to) => { page = to; layout(); };
    const prev = el("button", "", "前へ");
    prev.disabled = page === 1;
    prev.addEventListener("click", () => go(page - 1));
    nav.append(prev);
    for (let number = 1; number <= pages; number += 1) {
      const button = el("button", number === page ? "on" : "", String(number));
      button.addEventListener("click", () => go(number));
      nav.append(button);
    }
    const next = el("button", "", "次へ");
    next.disabled = page === pages;
    next.addEventListener("click", () => go(page + 1));
    nav.append(next);
  });
}
rows.forEach((row) => {
  row.addEventListener("click", () => show(row.dataset.id, true));
  row.querySelector(".pick").addEventListener("click", (event) => { event.stopPropagation(); toggle(Number(row.dataset.id)); });
});
document.querySelectorAll(".tab").forEach((button) => {
  button.addEventListener("click", () => {
    tab = button.dataset.tab;
    page = 1;
    document.querySelectorAll(".tab").forEach((other) => other.classList.toggle("on", other === button));
    layout();
  });
});
copy.addEventListener("click", async () => {
  try { await navigator.clipboard.writeText(text.value); copy.textContent = "コピーした"; }
  catch (error) { text.select(); copy.textContent = "⌘Cでコピー"; }
  setTimeout(() => { copy.textContent = "コピー"; }, 2000);
});
loadDrafts();
layout();
refresh();
if (rows.length) show(rows[0].dataset.id, false);
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
    """一覧から、種類のタブと大きい順の表と横の詳細の欄を持つ選ぶ頁を書く。"""
    home = listing.get("home", "")
    items = sorted(listing["candidates"], key=lambda item: (-item["size_bytes"], item["id"]))
    biggest = max([item["size_bytes"] for item in items] + [1])
    measured = listing["measured_at"]
    totals: dict[str, int] = {}
    for item in items:
        totals[item["kind"]] = totals.get(item["kind"], 0) + item["size_bytes"]
    tabs = [f'<button class="tab on" data-tab="all">すべて {len(items)}</button>']
    for kind in sorted(totals, key=lambda name: -totals[name]):
        count = sum(1 for item in items if item["kind"] == kind)
        tabs.append(f'<button class="tab" data-tab="{kind}">{html.escape(TAB_LABELS[kind])} {count}</button>')
    rows = []
    details = {}
    for index, item in enumerate(items):
        color = KIND_COLORS.get(item["kind"], 6)
        width = max(2, round(item["size_bytes"] / biggest * 100)) if item["size_bytes"] else 0
        trash = " trash" if item["action"] == "trash" else ""
        mark = '<span class="badge cmark">コメント</span>' if item.get("comment") else ""
        when = ago(item["last_used"], measured)
        rows.append(
            f'<tr data-id="{item["id"]}" data-size="{item["size_bytes"]}" data-kind="{item["kind"]}" '
            f'data-advice="{item["advice"]}" data-comment="{1 if item.get("comment") else 0}" '
            f'data-page="{index // PAGE_ROWS + 1}">'
            f'<td><button class="pick" aria-label="選ぶ">✓</button></td>'
            f'<td><div class="t"><span class="dot" style="background:var(--c{color})"></span>{html.escape(item["title"])}{mark}</div>'
            f'<div class="s">{html.escape(item["description"])}</div></td>'
            f'<td class="num">{human(item["size_bytes"])}<div class="bar"><i style="width:{width}%;background:var(--c{color})"></i></div></td>'
            f'<td class="when">{when}<div class="sub">{item["last_used"]}</div></td>'
            f'<td><span class="badge advice-{item["advice"]}">{ADVICE_LABELS[item["advice"]]}</span></td>'
            f'<td><span class="badge{trash}">{ACTION_LABELS[item["action"]]}</span></td></tr>'
        )
        if item["recoverable"]:
            how = "。写しが在るので取り戻せる"
        elif item["action"] == "trash":
            how = "。ほかに写しが無いので、ゴミ箱を空にするまでは戻せる"
        else:
            how = ""
        facts = [
            ["おすすめ", ADVICE_LABELS[item["advice"]] + ("。AIの判断" if item.get("advised_by") == "ai" else "。写しが在るかから付けた")],
            ["理由", item["advice_reason"]],
            ["大きさ", human(item["size_bytes"])],
            ["最後に使った", f'{item["last_used"]} ({when})' if when else item["last_used"]],
            ["消し方", ACTION_LABELS[item["action"]] + how],
        ]
        if item.get("remote"):
            facts.append(["remote", item["remote"]])
        extra = []
        if item.get("regrown"):
            extra.append("前に消したのにまた作られた")
        elif item.get("regrows"):
            extra.append("消してもまた作られる")
        if item.get("source"):
            extra.append(f"作る元は{item['source']}番")
        if extra:
            facts.append(["補足", "。".join(extra)])
        facts.append(["説明の元", "AIが書いた" if item.get("described_by") == "ai" else "中身から作った"])
        is_path = item["path"].startswith("/")
        details[str(item["id"])] = {
            "title": item["title"],
            "kind": KIND_LABELS[item["kind"]],
            "color": color,
            "description": item["description"],
            "facts": facts,
            "place": short(home, item["path"]) if is_path else "Dockerの中",
            "href": "file://" + urllib.parse.quote(item["path"]) if is_path else "",
            "contents": item.get("contents", []),
            "comment": item.get("comment", ""),
            "key": item["path"],
        }
    if not rows:
        rows.append('<tr><td colspan="6" class="empty">候補は無い</td></tr>')
    total = sum(item["size_bytes"] for item in items)
    lead = (f"{listing['days']}日より前から使っていない物{len(items)}件、計{human(total)}。"
            f"{measured[:10]}に測った")
    warns = [f"{KIND_LABELS[kind['name']]}は測れなかった (理由 {kind['reason']})"
             for kind in listing["kinds"] if kind["status"] != "ok"]
    if listing.get("unreadable_dirs"):
        warns.append(f"読めなかったdirが{listing['unreadable_dirs']}件在り、その中は測っていない")
    warn = "".join(f'<p class="warn">{html.escape(line)}</p>' for line in warns)
    pager = '<nav class="pager"></nav>' if len(items) > PAGE_ROWS else ""
    data = json.dumps(details, ensure_ascii=False).replace("</", "<\\/")
    page = (PAGE.replace("__LEAD__", html.escape(lead)).replace("__WARN__", warn)
            .replace("__TABS__", "".join(tabs)).replace("__PAGER__", pager).replace("__ROWS__", "\n".join(rows))
            .replace("__PAGE_ROWS__", str(PAGE_ROWS)).replace("__DETAILS__", data))
    path = state / "candidates.html"
    path.write_text(page)
    return path


# --- 候補が何の物か ----------------------------------------------------------------


def contents_of(path: str, limit: int = 5) -> list[dict]:
    """dir の候補の中で大きい物を、大きい順に limit 個まで返す。 dir でない物は空。"""
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
    """手元の repo と作業場所の、取り込む先の場所を返す。 読めない時は None。"""
    if item["kind"] not in ("repo", "worktree"):
        return None
    code, out = git(Path(item["path"]), "remote", "get-url", "origin")
    url = out.strip()
    return url if code == 0 and url else None


VERSION_LIKE = re.compile(r"^v?[0-9]+(\.[0-9]+)+")


def facts_title(item: dict) -> str:
    """機械で作る候補の名前。 版の番号だけの dir は、道具の名前を前に付ける。"""
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
    """機械で集めた事実から、候補が何の物かを述べる文を作る。"""
    parts = []
    if item.get("note"):
        parts.append(item["note"])
    if item.get("remote"):
        parts.append(f"remoteは{item['remote']}")
    big = [f"{part['name']} ({human(part['size_bytes'])})" for part in item.get("contents", [])[:2] if part["size_bytes"]]
    if big:
        parts.append("中の大きい物は" + "と".join(big))
    return "。".join(parts) if parts else KIND_LABELS[item["kind"]]


def facts_advice(item: dict) -> tuple[str, str]:
    """段階を渡されていない候補に、写しが在るかから段階と理由を付ける。"""
    if item["recoverable"]:
        return "delete", "ほかに写しが在り、消しても取り戻せる"
    if item["action"] == "trash":
        return "check", "ほかに写しが無い。ゴミ箱を空にすると戻せないので、中身を確かめてから選ぶ"
    return "check", "ほかに写しが無い。中身を確かめてから選ぶ"


def read_notes(state: Path) -> dict:
    """前に渡された説明を、候補の場所ごとに返す。"""
    path = state / "notes.json"
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError:
        reject("unreadable-notes", 3, str(path))
    if not isinstance(data, dict) or data.get("schema_version") != NOTES_SCHEMA or not isinstance(data.get("notes"), dict):
        reject("unknown-notes-version", 3, f"{path} の schema_version={data.get('schema_version') if isinstance(data, dict) else None!r}")
    return data["notes"]


def describe(listing: dict, notes: dict) -> None:
    """候補ごとに名前と説明の文を付ける。 説明を渡された場所はその文を、無い物は事実から作った文を使う。"""
    for item in listing["candidates"]:
        note = notes.get(item["path"])
        if isinstance(note, dict) and note.get("name") and note.get("text"):
            item["title"], item["description"], item["described_by"] = note["name"], note["text"], "ai"
        else:
            item["title"], item["description"], item["described_by"] = facts_title(item), facts_description(item), "facts"
        item["comment"] = note.get("comment", "") if isinstance(note, dict) else ""
        if isinstance(note, dict) and note.get("advice") in ADVICE_LABELS and note.get("why"):
            item["advice"], item["advice_reason"], item["advised_by"] = note["advice"], note["why"], "ai"
        else:
            item["advice"], item["advice_reason"] = facts_advice(item)
            item["advised_by"] = "facts"


COMMENT_LINE = re.compile(r"^pc-tidy comment ([0-9]+)(?:[ \t]+(.*))?$")


def command_comment(paste_file: str, as_json: bool) -> int:
    """貼り返された文からコメントの行だけを読み、書いたままの文で候補の場所ごとに残す。

    番号だけの行はその候補のコメントを外す。 受けた物を全部確かめてから書くため、断る時は何も書かない。
    """
    state = state_dir()
    listing = load_list(state)
    try:
        pasted = Path(paste_file).read_text()
    except (OSError, UnicodeError) as error:
        reject("bad-paste", 2, f"{paste_file} を読めない ({type(error).__name__})")
    given: dict[str, str] = {}
    for line in pasted.splitlines():
        match = COMMENT_LINE.match(line.strip())
        if match:
            given[match.group(1)] = (match.group(2) or "").strip()
    if not given:
        reject("bad-paste", 2, "pc-tidy comment <番号> <コメント> の行が無い")
    by_id = {str(item["id"]): item for item in listing["candidates"]}
    unknown = [key for key in given if key not in by_id]
    if unknown:
        reject("unknown-id", 2, "一覧に無い番号: " + ",".join(unknown))
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
            state_text = f"「{entry['comment']}」を残した" if entry["comment"] else "コメントを外した"
            print(f"{entry['id']}番 {entry['title']} に{state_text}")
        print(f"選ぶ頁を作り直した: {listing['html']}")
    return 0


def load_list(state: Path) -> dict:
    """前の一覧を読む。 無い時と、読めない時と、今の版でない時は断る。"""
    listing_path = state / "candidates.json"
    if not listing_path.exists():
        reject("no-list", 2, "先に list を打つ")
    try:
        listing = json.loads(listing_path.read_text())
    except json.JSONDecodeError:
        reject("unreadable-list", 3, str(listing_path))
    if not isinstance(listing, dict) or listing.get("schema_version") != LIST_SCHEMA:
        version = listing.get("schema_version") if isinstance(listing, dict) else None
        reject("unknown-list-version", 3, f"schema_version={version!r}。 list を打ち直す")
    return listing


def command_explain(notes_file: str, as_json: bool) -> int:
    """番号ごとの名前と説明の文を受け、候補の場所ごとに残して頁を作り直す。

    受けた物を全部確かめてから書くため、断る時は何も書かない。
    """
    state = state_dir()
    listing = load_list(state)
    try:
        given = json.loads(Path(notes_file).read_text())
    except (OSError, json.JSONDecodeError) as error:
        reject("bad-notes", 2, f"{notes_file} を読めない ({type(error).__name__})")
    if not isinstance(given, dict) or not given:
        reject("bad-notes", 2, '{"<番号>": {"name": "<名前>", "text": "<説明>"}} の形で渡す')
    by_id = {str(item["id"]): item for item in listing["candidates"]}
    unknown = [key for key in given if key not in by_id]
    if unknown:
        reject("unknown-id", 2, "一覧に無い番号: " + ",".join(unknown))
    for key, note in given.items():
        if not isinstance(note, dict) or not all(isinstance(note.get(field), str) and note[field].strip()
                                                 for field in ("name", "text")):
            reject("bad-notes", 2, f"{key}番の name と text は空でない文にする")
        if ("advice" in note or "why" in note) and not (
                note.get("advice") in ADVICE_LABELS and isinstance(note.get("why"), str) and note["why"].strip()):
            reject("bad-notes", 2, f"{key}番の advice は {'、'.join(ADVICE_LABELS)} のどれかにし、why に理由の文を添える")
    notes = read_notes(state)
    for key, note in given.items():
        # 前に残した本人のコメントは、説明を直しても消さない。
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
        print(f"{len(given)}件の説明を残し、選ぶ頁を作り直した: {listing['html']}")
    return 0


def print_list(ctx: Context, listing: dict) -> None:
    print(f"{listing['days']}日より前から触っていない物 ({listing['measured_at'][:10]}に測った)")
    print("| 番号 | 種類 | 大きさ | 最後に使った日 | 戻せるか | 消し方 | 物 |")
    print("|---|---|---|---|---|---|---|")
    for item in listing["candidates"]:
        back = "戻せる" if item["recoverable"] else "戻せない"
        print(f"| {item['id']} | {KIND_LABELS[item['kind']]} | {human(item['size_bytes'])} | {item['last_used']} | "
              f"{back} | {ACTION_LABELS[item['action']]} | {short(str(ctx.home), item['path'])} |")
    for kind in listing["kinds"]:
        if kind["status"] != "ok":
            print(f"{KIND_LABELS[kind['name']]}は測れなかった (unknown、理由 {kind['reason']})")
    for item in listing["regrown"]:
        print(f"前に消したのにまた作られた物: {short(str(ctx.home), item['path'])}")
    if listing["unreadable_dirs"]:
        print(f"読めなかったdirが{listing['unreadable_dirs']}件在り、その中は測っていない")
    print(f"選ぶ頁: {listing['html']}")


def write_listing(ctx: Context) -> dict:
    """測って一覧と選ぶ頁を書く。 一覧の命令と定期の命令が共に使う。"""
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


# --- 適用 ------------------------------------------------------------------------


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
            reject("bad-select", 2, f"番号として読めない: {part}")
    if not ids:
        reject("bad-select", 2, "番号が無い")
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
    """消す直前に、一覧の後で変わった事を確かめ直す。"""
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
        return "skipped", f"managed (直す場所 {where})"
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
        return "done", f"ゴミ箱へ移した ({target})"
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
        reject("unknown-id", 2, "一覧に無い番号: " + ",".join(str(number) for number in unknown))
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
            print(f"消した: {where}" + (f" {result['reason']}" if result["reason"] else ""))
        elif result["status"] == "skipped":
            print(f"消さなかった: {where} (理由 {result['reason']})")
        else:
            print(f"消せなかった: {where} (理由 {result['reason']})")
    if report["free_gain_kb"] is None:
        print("空きは測れなかった (unknown)")
    else:
        print(f"空きは消す前の{human(report['free_before_kb'] * 1024)}から{human(report['free_after_kb'] * 1024)}になり、"
              f"{human(max(report['free_gain_kb'], 0) * 1024)}増えた")
    if report["trashed_bytes"]:
        print(f"ゴミ箱へ移した{human(report['trashed_bytes'])}は、ゴミ箱を空けると空きになる")
    snapshots = report["local_snapshots"]
    if snapshots == "unknown":
        print("Time Machineの手元の写しは測れなかった (unknown)")
    elif snapshots:
        print(f"Time Machineの手元の写しが{snapshots}個在り、消した分の空きは写しが消えるまで増えない")


def main(argv: list[str]) -> int:
    if not argv or argv[0] not in ("list", "apply", "explain", "comment"):
        reject("bad-usage", 2, "使い方は tidy.sh list [--json] か tidy.sh explain --notes <file> [--json] か "
                               "tidy.sh comment --paste <file> [--json] か tidy.sh apply --select <番号> [--json]")
    if current_os() != "Darwin":
        reject("os-not-supported", 3, f"OS={current_os()} はまだ種類を持たない")
    command, rest = argv[0], argv[1:]
    as_json = "--json" in rest
    rest = [arg for arg in rest if arg != "--json"]
    if command == "list":
        if rest:
            reject("bad-usage", 2, "list は --json だけを受ける")
        return command_list(as_json)
    if command == "explain":
        if len(rest) != 2 or rest[0] != "--notes":
            reject("bad-usage", 2, "explain は --notes <file> を受ける")
        return command_explain(rest[1], as_json)
    if command == "comment":
        if len(rest) != 2 or rest[0] != "--paste":
            reject("bad-usage", 2, "comment は --paste <file> を受ける")
        return command_comment(rest[1], as_json)
    if len(rest) != 2 or rest[0] != "--select":
        reject("bad-usage", 2, "apply は --select <番号> を受ける")
    return command_apply(rest[1], as_json)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
