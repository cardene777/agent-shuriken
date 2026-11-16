"""Writes the state an eval case starts from into the run's workspace and HOME.

Usage: python3 _fixture.py <mode>

git fails in the eval sandbox, so repo_progress.py cannot read the user's name there, and gh has no
network. No mode writes a ~/.gitconfig, and the workspace is not a git repository. The modes:

  plain   nothing more: the scan cannot tell which commits are the user's and exits 2, and with
          --author it finds no root folder and exits 1
  table   progress.txt, the table repo_progress.py printed for two repositories by Dana Kim, last
          changed 41 and 3 days ago, with gh missing, so every row shows ? for issues and prs. The
          repositories are made in a temporary folder that is removed afterwards
  shop    a git repository shop with main, a branch feat/12-login merged into main, and a branch
          fix/15-typo that is not merged
"""
import os
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "..", "skills", "repo-progress", "scripts", "repo_progress.py")
AUTHOR = ["-c", "user.name=Dana Kim", "-c", "user.email=dana@example.com"]


def git(repo, *args):
    subprocess.run(["git", "-C", repo] + AUTHOR + list(args), check=True, capture_output=True)


def commit(repo, name, text, message, days_ago=0):
    with open(os.path.join(repo, name), "w", encoding="utf-8") as f:
        f.write(text)
    git(repo, "add", "-A")
    when = time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(time.time() - days_ago * 86400))
    env = dict(os.environ, GIT_AUTHOR_DATE=when, GIT_COMMITTER_DATE=when)
    subprocess.run(["git", "-C", repo] + AUTHOR + ["commit", "-qm", message], check=True, capture_output=True, env=env)


def new_repo(path, days_ago=0):
    os.makedirs(path)
    subprocess.run(["git", "init", "-q", "-b", "main", path], check=True, capture_output=True)
    commit(path, "README.md", "# %s\n" % os.path.basename(path), "Start the project", days_ago)


def table():
    tmp = tempfile.mkdtemp(prefix="repo-progress-fixture-")
    try:
        root = os.path.join(tmp, "projects")
        for name, days_ago in (("billing-api", 41), ("docs-site", 3)):
            repo = os.path.join(root, name)
            new_repo(repo, days_ago)
        env = {k: v for k, v in os.environ.items() if not k.startswith("REPO_PROGRESS_")}
        env.update(REPO_PROGRESS_GH="/nonexistent/gh", REPO_PROGRESS_HOME=os.path.join(tmp, "state"),
                   HOME=tmp)
        out = subprocess.run([sys.executable, SCRIPT, "--root", root, "--author", "Dana Kim"],
                             env=env, capture_output=True, text=True)
        if out.returncode != 0:
            print(out.stderr, file=sys.stderr)
            return 1
        with open("progress.txt", "w", encoding="utf-8") as f:
            f.write(out.stdout)
    finally:
        shutil.rmtree(tmp)
    return 0


def shop():
    new_repo("shop")
    git("shop", "checkout", "-q", "-b", "feat/12-login")
    commit("shop", "login.txt", "login form\n", "Add the login form")
    git("shop", "checkout", "-q", "main")
    git("shop", "merge", "-q", "--no-ff", "-m", "Merge the login form", "feat/12-login")
    git("shop", "checkout", "-q", "-b", "fix/15-typo")
    commit("shop", "README.md", "# shop\n\nA small shop.\n", "Fix a typo")
    git("shop", "checkout", "-q", "main")
    return 0


def main(mode):
    if mode == "plain":
        return 0
    if mode == "table":
        return table()
    if mode == "shop":
        return shop()
    print("unknown mode: %s" % mode, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else ""))
