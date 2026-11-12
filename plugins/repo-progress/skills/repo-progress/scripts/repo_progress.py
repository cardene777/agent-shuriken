#!/usr/bin/env python3
"""Show where every repository you work on stands, without changing anything.

It reads each local clone with git (worktrees, uncommitted files, the last commit) and asks
GitHub through `gh` for the open issues and pull requests. It never writes to a repository.

Usage:
  repo_progress.py [--root DIR]... [--author NAME] [--json] [--repo NAME] [--save-roots] [--show-roots]

Root folders come from, in order: --root, REPO_PROGRESS_ROOTS (separated by ":"), the saved
list in ~/.local/share/repo-progress/roots, and common folders such as ~/projects and ~/code.
Each root is scanned directly and one level deeper.

Exit codes: 0 on success, 1 when no repository was found, 2 for bad input or no author.
"""
import argparse
import concurrent.futures
import json
import os
import re
import shutil
import subprocess
import sys
import time

DEFAULT_ROOTS = ("projects", "code", "src", "dev", "Developer", "repos", "workspace", "work", "git",
                 "Documents/GitHub", "Desktop/projects", "Desktop/work")
DEFAULT_BRANCHES = {"main", "master", "develop", "trunk"}
# A branch points at an issue when it is <prefix>/<number>-<words>, <number>-<words>, or issue-<number>.
ISSUE_IN_BRANCH = re.compile(r"^(?:[A-Za-z][A-Za-z0-9_.-]*/)?(?:issue-|gh-)?([0-9]+)(?:-|$)")
ISSUE_LIMIT = 500
PR_LIMIT = 200


def state_home():
    base = os.environ.get("REPO_PROGRESS_HOME") or os.path.join(os.path.expanduser("~"), ".local", "share", "repo-progress")
    return base


def git(path, *args):
    """Run git in path and return stdout, or None when git fails."""
    try:
        r = subprocess.run(["git", "-C", path] + list(args), capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return r.stdout if r.returncode == 0 else None


def now_epoch():
    # Tests fix the clock so that "days since the last commit" is stable.
    value = os.environ.get("REPO_PROGRESS_NOW", "")
    return int(value) if value.isdigit() else int(time.time())


# ------------------------------------------------------------------ settings

def resolve_author(given):
    """Return the names and emails that count as the user, or [] when none is known."""
    if given:
        return [given]
    env = os.environ.get("REPO_PROGRESS_AUTHOR", "")
    if env:
        return [env]
    found = []
    for key in ("user.name", "user.email"):
        try:
            r = subprocess.run(["git", "config", "--global", key], capture_output=True, text=True, timeout=10)
        except (OSError, subprocess.TimeoutExpired):
            continue
        value = r.stdout.strip()
        if r.returncode == 0 and value:
            found.append(value)
    return found


def saved_roots_path():
    return os.path.join(state_home(), "roots")


def read_saved_roots():
    try:
        with open(saved_roots_path(), encoding="utf-8") as f:
            return [line.strip() for line in f if line.strip() and not line.startswith("#")]
    except OSError:
        return []


def save_roots(roots):
    home = state_home()
    os.makedirs(home, mode=0o700, exist_ok=True)
    os.chmod(home, 0o700)
    path = saved_roots_path()
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write("".join(r + "\n" for r in roots))
    os.chmod(path, 0o600)
    return path


def resolve_roots(given):
    """Return (roots, where they came from)."""
    if given:
        return [os.path.abspath(os.path.expanduser(r)) for r in given], "--root"
    env = os.environ.get("REPO_PROGRESS_ROOTS", "")
    if env:
        return [os.path.abspath(os.path.expanduser(r)) for r in env.split(":") if r], "REPO_PROGRESS_ROOTS"
    saved = read_saved_roots()
    if saved:
        return saved, saved_roots_path()
    home = os.path.expanduser("~")
    roots = [os.path.join(home, d) for d in DEFAULT_ROOTS if os.path.isdir(os.path.join(home, d))]
    return roots, "common folders"


# ------------------------------------------------------------------ finding repositories

def parse_remote(url):
    """Turn a remote URL into the form `gh -R` takes, or None when it is not a GitHub-style URL."""
    url = url.strip()
    m = re.match(r"^(?:[a-z+]+://)?(?:[^@/]+@)?([^/:]+)[:/](?:\d+/)?([^/]+)/([^/]+?)(?:\.git)?/?$", url)
    if not m:
        return None
    host, owner, name = m.groups()
    return "%s/%s" % (owner, name) if host == "github.com" else "%s/%s/%s" % (host, owner, name)


def list_repos(roots, authors):
    """Yield (path, slug, display name) for clones that have a commit by one of the authors."""
    seen = set()
    for root in roots:
        if not os.path.isdir(root):
            continue
        candidates = []
        for first in sorted(os.listdir(root)):
            p1 = os.path.join(root, first)
            if not os.path.isdir(p1) or first.startswith("."):
                continue
            candidates.append(p1)
            try:
                children = sorted(os.listdir(p1))
            except OSError:
                continue
            if os.path.exists(os.path.join(p1, ".git")):
                continue
            for second in children:
                p2 = os.path.join(p1, second)
                if os.path.isdir(p2) and not second.startswith("."):
                    candidates.append(p2)
        for path in candidates:
            real = os.path.realpath(path)
            if real in seen or not os.path.exists(os.path.join(path, ".git")):
                continue
            # A linked worktree has a .git file; it is shown under its main clone instead.
            if os.path.isfile(os.path.join(path, ".git")):
                continue
            author_args = []
            for a in authors:
                author_args += ["--author", a]
            mine = git(path, "log", "--all", "--fixed-strings", "-1", "--format=%H", *author_args)
            if not mine or not mine.strip():
                continue
            seen.add(real)
            url = git(path, "remote", "get-url", "origin")
            slug = parse_remote(url) if url else None
            yield path, slug, os.path.relpath(path, root)


# ------------------------------------------------------------------ one repository

def list_worktrees(path):
    """Return [(branch, prunable)] for the main clone and every linked worktree."""
    out = git(path, "worktree", "list", "--porcelain", "-z")
    if out is None:
        return []
    items, branch, prunable = [], None, False
    for field in out.split("\0"):
        if field.startswith("worktree "):
            if branch is not None:
                items.append((branch, prunable))
            branch, prunable = "", False
        elif field.startswith("branch "):
            branch = field[len("branch "):].replace("refs/heads/", "", 1)
        elif field == "detached":
            branch = "(detached)"
        elif field.startswith("prunable"):
            prunable = True
    if branch is not None:
        items.append((branch, prunable))
    return items


def default_branch(path):
    out = git(path, "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD")
    return out.strip().split("/", 1)[-1] if out and out.strip() else None


def gh_list(slug, kind):
    """Return the open issues or pull requests of slug as a list, or None when gh fails."""
    if not slug:
        return None
    gh = os.environ.get("REPO_PROGRESS_GH") or shutil.which("gh")
    if not gh:
        return None
    if kind == "issue":
        args = ["issue", "list", "--state", "open", "--limit", str(ISSUE_LIMIT), "--json", "number,title,updatedAt"]
    else:
        args = ["pr", "list", "--state", "open", "--limit", str(PR_LIMIT), "--json", "number,title,headRefName"]
    try:
        r = subprocess.run([gh, "-R", slug] + args, capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if r.returncode != 0:
        return None
    try:
        data = json.loads(r.stdout or "[]")
    except ValueError:
        return None
    return data if isinstance(data, list) else None


def issue_number(branch):
    m = ISSUE_IN_BRANCH.match(branch or "")
    return int(m.group(1)) if m else None


def scan_repo(path, slug, name):
    branch = (git(path, "branch", "--show-current") or "").strip()
    status = git(path, "status", "--porcelain")
    last = (git(path, "log", "-1", "--format=%ct") or "").strip()
    worktrees = list_worktrees(path)
    defaults = set(DEFAULT_BRANCHES)
    d = default_branch(path)
    if d:
        defaults.add(d)
    return {
        "path": path,
        "repo": name,
        "slug": slug,
        "branch": branch,
        "uncommitted": None if status is None else len([l for l in status.splitlines() if l.strip()]),
        "last_commit": int(last) if last.isdigit() else None,
        "worktrees": worktrees,
        "defaults": defaults,
    }


def classify(branch, prunable, repo):
    """Return (kind, label). kind is active, cleanup, unknown, or none."""
    if prunable:
        return "cleanup", "worktree folder is gone (prunable)"
    if branch in repo["defaults"] or branch in ("", "(detached)"):
        return "none", "default branch" if branch else "detached"
    num = issue_number(branch)
    if num is None:
        return "active", "no issue number"
    if repo["issues"] is None:
        return "unknown", "#%d, open issues could not be read" % num
    if num in {i["number"] for i in repo["issues"]}:
        return "active", "#%d" % num
    return "cleanup", "#%d is not an open issue" % num


def idle_score(repo, now):
    """Days since the last commit times open issues, or None when either is unknown."""
    if repo["last_commit"] is None or repo["issues"] is None:
        return None
    days = max(0, (now - repo["last_commit"]) // 86400)
    return days * len(repo["issues"])


def ago(epoch, now):
    if epoch is None:
        return "unknown"
    d = max(0, now - epoch)
    if d < 3600:
        return "%d min ago" % (d // 60)
    if d < 86400:
        return "%d h ago" % (d // 3600)
    return "%d days ago" % (d // 86400)


def head_label(repo):
    kind, label = classify(repo["branch"], False, repo)
    if kind == "active" and label.startswith("#"):
        num = int(label[1:])
        title = next((i.get("title", "") for i in repo["issues"] or [] if i["number"] == num), "")
        return ("%s %s" % (label, title)).strip()
    if kind == "cleanup":
        return "%s (clean up)" % label
    return label


def count(value):
    return "?" if value is None else str(len(value)) if isinstance(value, list) else str(value)


# ------------------------------------------------------------------ output

def print_table(repos, now):
    header = ("repo", "worktrees", "issues", "prs", "uncommitted", "idle", "last commit", "now")
    rows = []
    for r in repos:
        score = idle_score(r, now)
        rows.append((r["repo"], str(max(0, len(r["worktrees"]) - 1)), count(r["issues"]), count(r["prs"]),
                     count(r["uncommitted"]), "?" if score is None else str(score), ago(r["last_commit"], now),
                     head_label(r)))
    widths = [max(len(header[i]), *(len(row[i]) for row in rows)) for i in range(len(header) - 1)]
    fmt = "  ".join("%%-%ds" % w if i == 0 else "%%%ds" % w for i, w in enumerate(widths)) + "  %s"
    print(fmt % header)
    for row in rows:
        print(fmt % row)
    unmeasured = sum(1 for r in repos if idle_score(r, now) is None)
    if unmeasured:
        print()
        print("%d %s could not be measured and %s listed last (idle is ?)."
              % (unmeasured, "repository" if unmeasured == 1 else "repositories", "is" if unmeasured == 1 else "are"))


def print_json(repos, now):
    for r in repos:
        print(json.dumps({
            "repo": r["repo"],
            "slug": r["slug"],
            "branch": r["branch"],
            "now": head_label(r),
            "worktrees": max(0, len(r["worktrees"]) - 1),
            "issues": None if r["issues"] is None else len(r["issues"]),
            "prs": None if r["prs"] is None else len(r["prs"]),
            "uncommitted": r["uncommitted"],
            "last_commit_epoch": r["last_commit"],
            "idle": idle_score(r, now),
        }, ensure_ascii=False))


def print_detail(r, now):
    print(r["slug"] or r["repo"])
    print("  folder       %s" % r["repo"])
    print("  branch       %s" % (r["branch"] or "(detached)"))
    print("  uncommitted  %s files" % count(r["uncommitted"]))
    print("  last commit  %s" % ago(r["last_commit"], now))
    if r["issues"] is None:
        print("  open issues and pull requests could not be read from GitHub")
    prs = {p.get("headRefName"): p["number"] for p in r["prs"] or []}
    issues = {i["number"]: i for i in r["issues"] or []}
    groups = {"active": [], "cleanup": [], "unknown": []}
    active_numbers = set()
    seen = set()
    for branch, prunable in r["worktrees"]:
        if (branch, prunable) in seen:
            continue
        seen.add((branch, prunable))
        kind, label = classify(branch, prunable, r)
        if kind == "none":
            continue
        num = issue_number(branch)
        if kind == "active" and num is not None:
            active_numbers.add(num)
            label = "#%d %s" % (num, issues[num].get("title", ""))
        if branch in prs:
            label += "  (pull request #%d)" % prs[branch]
        groups[kind].append((branch, label))
    for kind, title in (("active", "In progress"), ("cleanup", "To clean up"), ("unknown", "Unknown")):
        if kind == "unknown" and not groups[kind]:
            continue
        print()
        print("  [%s]" % title)
        for branch, label in groups[kind]:
            print("    %-44s %s" % (branch, label))
        if not groups[kind]:
            print("    none")
    print()
    if r["issues"] is None:
        print("  [Waiting] unknown")
        return
    waiting = [i for n, i in sorted(issues.items()) if n not in active_numbers]
    print("  [Waiting] %d issues" % len(waiting))
    for i in waiting:
        print("    #%-7s %-10s %s" % (i["number"], (i.get("updatedAt") or "")[:10], i.get("title", "")))


# ------------------------------------------------------------------ main

def main(argv):
    ap = argparse.ArgumentParser(description="Show where every repository you work on stands, without changing anything.")
    ap.add_argument("--root", action="append", default=[], help="folder to scan, directly and one level deeper (repeatable)")
    ap.add_argument("--author", help="name or email whose commits mark a repository as yours")
    ap.add_argument("--json", action="store_true", help="print one JSON object per repository")
    ap.add_argument("--repo", help="show the branches, worktrees, and waiting issues of one repository")
    ap.add_argument("--save-roots", action="store_true", help="remember the --root folders for later scans")
    ap.add_argument("--show-roots", action="store_true", help="print the root folders a scan would use and exit")
    args = ap.parse_args(argv)

    if args.save_roots:
        if not args.root:
            print("--save-roots needs at least one --root", file=sys.stderr)
            return 2
        roots = [os.path.abspath(os.path.expanduser(r)) for r in args.root]
        missing = [r for r in roots if not os.path.isdir(r)]
        if missing:
            print("not a folder: %s" % ", ".join(missing), file=sys.stderr)
            return 2
        print("Saved %d root folders to %s" % (len(roots), save_roots(roots)))

    roots, source = resolve_roots(args.root)
    if args.show_roots:
        print("Root folders (from %s):" % source)
        for r in roots:
            print("  %s%s" % (r, "" if os.path.isdir(r) else "  (missing)"))
        return 0

    authors = resolve_author(args.author)
    if not authors:
        print("Cannot tell which commits are yours. Set git config --global user.name, or pass --author.", file=sys.stderr)
        return 2
    if not roots:
        print("No root folder to scan. Pass --root DIR, and add --save-roots to remember it.", file=sys.stderr)
        return 1

    found = list(list_repos(roots, authors))
    if args.repo:
        found = [f for f in found if f[2] == args.repo or os.path.basename(f[0]) == args.repo]
    if not found:
        what = "named %s " % args.repo if args.repo else ""
        print("No repository %swith a commit by %s under: %s" % (what, " or ".join(authors), ", ".join(roots)), file=sys.stderr)
        return 1

    repos = [scan_repo(*f) for f in found]
    # Ask GitHub once per repository, even when it is cloned in several folders.
    slugs = sorted({r["slug"] for r in repos if r["slug"]})
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        issues = dict(zip(slugs, pool.map(lambda s: gh_list(s, "issue"), slugs)))
        prs = dict(zip(slugs, pool.map(lambda s: gh_list(s, "pr"), slugs)))
    for r in repos:
        r["issues"] = issues.get(r["slug"])
        r["prs"] = prs.get(r["slug"])

    now = now_epoch()
    if args.repo:
        for i, r in enumerate(repos):
            if i:
                print()
            print_detail(r, now)
        return 0
    # Stalled repositories first; ones that could not be measured go last instead of looking most idle.
    repos.sort(key=lambda r: (idle_score(r, now) is None, -(idle_score(r, now) or 0), r["repo"]))
    if args.json:
        print_json(repos, now)
    else:
        print_table(repos, now)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
