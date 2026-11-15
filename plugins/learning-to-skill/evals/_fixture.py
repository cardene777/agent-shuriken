"""Writes the starting state of an eval case into the current folder, the run's workspace.

Usage: python3 _fixture.py <mode>

Every mode makes a git repository, shop, with an AGENTS.md that has the sections Setup and Testing,
and a README.md with the typo "smal". The modes add:

  plain     nothing more
  existing  the rule to run `pnpm test:checkout` before pushing, already in the Testing section
  close     a vaguer line in the Testing section: "Run the checkout tests before pushing."
  claude    a CLAUDE.md that does not import AGENTS.md, so Claude Code does not read AGENTS.md
  web       web/AGENTS.md with the rules for work in web/, and web/src/tokens.css
"""
import os
import subprocess
import sys

GIT = ["git", "-c", "user.name=Shop Example", "-c", "user.email=shop@example.com", "-c", "init.defaultBranch=main"]

AGENTS = """# AGENTS.md

## Setup

- Install dependencies with `pnpm install`.

## Testing

- Run `pnpm test` before opening a pull request.
"""

EXISTING = "- Run `pnpm test:checkout` before pushing; the unit tests do not cover checkout.\n"
CLOSE = "- Run the checkout tests before pushing.\n"

README = "# shop\n\nA smal online shop with a checkout and a web front end.\n"

CLAUDE = """# CLAUDE.md

## Style

- Keep answers short.
"""

WEB_AGENTS = """# web

## Styling

- Use CSS modules.
"""

TOKENS = ":root {\n  --color-brand: #0b5fff;\n  --color-text: #1a1a1a;\n}\n"


def write(path, text):
    folder = os.path.dirname(path)
    if folder:
        os.makedirs(folder, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def main(mode):
    agents = AGENTS
    if mode == "existing":
        agents += EXISTING
    elif mode == "close":
        agents += CLOSE
    elif mode == "claude":
        write("CLAUDE.md", CLAUDE)
    elif mode == "web":
        write("web/AGENTS.md", WEB_AGENTS)
        write("web/src/tokens.css", TOKENS)
    elif mode != "plain":
        sys.exit("unknown mode: " + mode)
    write("AGENTS.md", agents)
    write("README.md", README)
    subprocess.run([*GIT, "init", "-q", "."], check=True)
    subprocess.run([*GIT, "add", "-A"], check=True)
    subprocess.run([*GIT, "commit", "-q", "-m", "Start the shop"], check=True)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "plain")
