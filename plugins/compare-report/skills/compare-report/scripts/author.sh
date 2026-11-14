#!/bin/bash
# Shows, saves, or forgets the author's name that goes on the report cover.
# Usage: author.sh                prints "name: NAME", "no name", or "not saved"
#        author.sh --set 'NAME'   saves NAME as given by the user; an empty NAME saves "no name"
#        author.sh --forget       removes the saved answer
# The answer is kept in author.txt under COMPARE_REPORT_HOME, or ~/.local/share/compare-report,
# readable only by the user. The name comes only from the user's answer: this command never
# reads git config, the system's user name, or anything else.
set -euo pipefail

exec python3 - "$@" <<'PY'
import os
import sys
import tempfile
import unicodedata

MAX = 100
home = os.environ.get("COMPARE_REPORT_HOME") or os.path.join(os.path.expanduser("~"), ".local", "share", "compare-report")
path = os.path.join(home, "author.txt")


def show():
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            name = f.read().strip()
    except FileNotFoundError:
        print("not saved")
        return
    print(f"name: {name}" if name else "no name")


def save(name):
    name = name.strip()
    if len(name) > MAX or any(unicodedata.category(c) in ("Cc", "Cs", "Zl", "Zp") for c in name):
        print(f"The name must be one line of at most {MAX} characters", file=sys.stderr)
        sys.exit(2)
    os.makedirs(home, mode=0o700, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=home, prefix=".author.")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(name + "\n" if name else "")
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


args = sys.argv[1:]
if not args:
    show()
elif args[0] == "--set" and len(args) == 2:
    save(args[1])
    show()
elif args == ["--forget"]:
    try:
        os.remove(path)
    except FileNotFoundError:
        pass
    show()
else:
    print("usage: author.sh [--set NAME | --forget]", file=sys.stderr)
    sys.exit(2)
PY
