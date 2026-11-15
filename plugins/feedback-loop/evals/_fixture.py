"""Writes the starting state of an eval case into the current folder, the run's workspace.

Usage: python3 _fixture.py <mode>

Every mode makes a git repository, shop, with docs/guide.md, a guide the agent wrote earlier whose
install step says `npm install -g shop-cli`, and keeps the plugin's records in .feedback inside the
repository, so the graders can read them. The modes add:

  plain    nothing more
  login    src/login.py, which rejects passwords that contain a space
  earlier  an earlier correction to the install step, closed with a case that forbids
           `npm install -g`, after which the guide says `npm install -g shop-cli` again
"""
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "..", "skills", "feedback-loop", "scripts", "feedback_loop.py")
GIT = ["git", "-c", "user.name=Shop Example", "-c", "user.email=shop@example.com", "-c", "init.defaultBranch=main"]

GUIDE = """# Shop CLI guide

## Install

Install the CLI with `npm install -g shop-cli`.

## Usage

Run `shop-cli list` to see your orders, and `shop-cli show <id>` to see one order.

## FAQ

**Is it free?** Yes, the CLI is free to use.
"""

FIXED_GUIDE = GUIDE.replace("Install the CLI with `npm install -g shop-cli`.", "Run the CLI with `npx shop-cli`, without installing it.")

LOGIN = '''"""Password check for the shop."""


def valid_password(password):
    if " " in password:
        return False
    return len(password) >= 8
'''


def write(path, text):
    folder = os.path.dirname(path)
    if folder:
        os.makedirs(folder, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def run(*args, stdin=None):
    env = {k: v for k, v in os.environ.items() if k not in ("FEEDBACK_LOOP_HOME", "FEEDBACK_LOOP_NOW")}
    return subprocess.run(args, input=stdin, text=True, check=True, env=env, stdout=subprocess.PIPE).stdout


def fl(*args, stdin=None):
    return run(sys.executable, SCRIPT, *args, stdin=stdin)


def earlier():
    """Close an earlier correction the way the skill does, then put the old install step back."""
    write("docs/guide.md", FIXED_GUIDE)
    out = fl("open", "--repo", ".", "--subject", "Install step", "--expected", "Use npx, not a global install",
             "--artifact", "docs/guide.md", "--origin-skill", "none", stdin="The install step must use npx.\n")
    fid = re.search(r"^Opened (fb-\d{8}-\d{3}):", out, re.M).group(1)
    fl("classify", "--repo", ".", fid, "artifact")
    fl("case", "--repo", ".", fid, "--forbid", "npm install -g", "--require", "npx shop-cli")
    fl("check", "--repo", ".", fid)
    fl("review", "--repo", ".", fid, "--evaluator", "user", "--kind", "human",
       stdin="- user-feedback: PASS - the install step uses npx\n- regression: PASS - nothing else changed\n")
    fl("close", "--repo", ".", fid)
    write("docs/guide.md", GUIDE)


def main(mode):
    write("README.md", "# shop\n\nA small online shop with a command-line tool.\n")
    write("docs/guide.md", GUIDE)
    if mode == "login":
        write("src/login.py", LOGIN)
    elif mode not in ("plain", "earlier"):
        sys.exit("unknown mode: " + mode)
    run(*GIT, "init", "-q", ".")
    run(*GIT, "add", "-A")
    run(*GIT, "commit", "-q", "-m", "Add the guide")
    fl("where", "--repo", ".", "--use", ".feedback")
    if mode == "earlier":
        earlier()


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "plain")
