#!/usr/bin/env python3
"""Find a Chromium-based browser on the machine and open a page in it, headless.

Usage:
  browser.py path
  browser.py dump <url> [--size <width>x<height>] [--reduced-motion]

path prints the browser that export and dump use. dump opens the page with a throwaway profile,
lets its scripts run on virtual time, and prints the page as it stands afterwards.

Nothing is installed. The search looks, in order, at the path in MOTION_DIAGRAM_BROWSER,
Playwright's chrome-headless-shell (newest first), and Google Chrome, Chromium, Microsoft Edge, and
Brave installed on the machine.

Exit codes:
  0  printed the path or the page
  1  no browser was found, or the browser failed; the reason is printed
  2  called wrongly

Uses only the Python standard library, starts only the browser it finds, writes only its throwaway
profile, which it removes, and connects to nothing itself.
"""

import glob
import os
import shutil
import subprocess
import sys
import tempfile

ENV = "MOTION_DIAGRAM_BROWSER"
PLAYWRIGHT_ROOTS = ["~/Library/Caches/ms-playwright", "~/.cache/ms-playwright", "~/AppData/Local/ms-playwright"]
SHELL_NAMES = ["chrome-headless-shell-mac-arm64/chrome-headless-shell", "chrome-headless-shell-mac-x64/chrome-headless-shell",
               "chrome-headless-shell-linux64/chrome-headless-shell", "chrome-headless-shell-linux-arm64/chrome-headless-shell",
               "chrome-headless-shell-win64/chrome-headless-shell.exe"]
INSTALLED = ["/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
             "/Applications/Chromium.app/Contents/MacOS/Chromium",
             "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
             "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"]
ON_PATH = ["google-chrome", "google-chrome-stable", "chromium", "chromium-browser", "microsoft-edge", "brave-browser"]


def version_key(path):
    digits = "".join(c if c.isdigit() else " " for c in os.path.basename(os.path.dirname(os.path.dirname(path))))
    return [int(x) for x in digits.split()] or [0]


def find():
    chosen = os.environ.get(ENV)
    if chosen:
        return chosen if os.access(chosen, os.X_OK) else None
    shells = []
    for root in PLAYWRIGHT_ROOTS:
        for folder in glob.glob(os.path.join(os.path.expanduser(root), "chromium_headless_shell-*")):
            for name in SHELL_NAMES:
                candidate = os.path.join(folder, name)
                if os.access(candidate, os.X_OK):
                    shells.append(candidate)
    if shells:
        return sorted(shells, key=version_key)[-1]
    for candidate in INSTALLED:
        if os.access(candidate, os.X_OK):
            return candidate
    for name in ON_PATH:
        found = shutil.which(name)
        if found:
            return found
    return None


def dump(url, size, reduced):
    exe = find()
    if not exe:
        print("motion-diagram: no Chromium-based browser found; install Google Chrome or set %s" % ENV, file=sys.stderr)
        return 1
    profile = tempfile.mkdtemp(prefix="motion-diagram-browser.")
    args = [exe, "--disable-gpu", "--no-first-run", "--no-default-browser-check", "--hide-scrollbars",
            "--user-data-dir=" + profile, "--window-size=" + size.replace("x", ","),
            "--virtual-time-budget=60000", "--run-all-compositor-stages-before-draw"]
    if "headless-shell" not in os.path.basename(exe):
        args.append("--headless=new")
    if reduced:
        args.append("--force-prefers-reduced-motion")
    args += ["--dump-dom", url]
    try:
        done = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=180)
    except subprocess.TimeoutExpired:
        print("motion-diagram: the browser did not finish within 180 seconds", file=sys.stderr)
        return 1
    finally:
        shutil.rmtree(profile, ignore_errors=True)
    if done.returncode != 0 or not done.stdout:
        print("motion-diagram: the browser exited %d" % done.returncode, file=sys.stderr)
        return 1
    sys.stdout.write(done.stdout.decode("utf-8", "replace"))
    return 0


def main(argv):
    if argv[:1] == ["path"]:
        exe = find()
        if not exe:
            print("motion-diagram: no Chromium-based browser found", file=sys.stderr)
            return 1
        print(exe)
        return 0
    if len(argv) >= 2 and argv[0] == "dump":
        size, reduced, rest = "1000x900", False, argv[2:]
        while rest:
            if rest[0] == "--size" and len(rest) > 1 and "x" in rest[1]:
                size, rest = rest[1], rest[2:]
            elif rest[0] == "--reduced-motion":
                reduced, rest = True, rest[1:]
            else:
                print("motion-diagram: unknown option %s" % rest[0], file=sys.stderr)
                return 2
        return dump(argv[1], size, reduced)
    print((__doc__ or "").strip().split("\n\n")[1], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
