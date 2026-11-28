#!/usr/bin/env python3
"""Find a Chromium-based browser on the machine and open a page in it, headless.

Usage:
  browser.py path
  browser.py dump <url> [--size <width>x<height>] [--reduced-motion] [--budget <ms>]
  browser.py shot <url> <out.png> [--size <width>x<height>] [--reduced-motion] [--budget <ms>]

path prints the browser that dump and shot use. dump opens the page with a throwaway profile, lets
its scripts run on virtual time (60000 ms unless --budget says otherwise), and prints the page as it
stands afterwards. shot does the same and saves a screenshot of the window instead.

Nothing is installed. The search looks, in order, at the path in MOTION_EXPLAINER_BROWSER,
Playwright's chrome-headless-shell (newest first), and Google Chrome, Chromium, Microsoft Edge, and
Brave installed on the machine.

Exit codes:
  0  printed the path or the page, or saved the screenshot
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

ENV = "MOTION_EXPLAINER_BROWSER"
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


def run(url, size, reduced, budget, output):
    """Opens url headless on virtual time; output is ["--dump-dom"] or ["--screenshot=<file>"]."""
    exe = find()
    if not exe:
        print("motion-explainer: no Chromium-based browser found; install Google Chrome or set %s" % ENV, file=sys.stderr)
        return None
    profile = tempfile.mkdtemp(prefix="motion-explainer-browser.")
    args = [exe, "--disable-gpu", "--no-first-run", "--no-default-browser-check", "--hide-scrollbars",
            "--user-data-dir=" + profile, "--window-size=" + size.replace("x", ","),
            "--virtual-time-budget=%d" % budget, "--run-all-compositor-stages-before-draw"]
    if "headless-shell" not in os.path.basename(exe):
        args.append("--headless=new")
    if reduced:
        args.append("--force-prefers-reduced-motion")
    args += output + [url]
    try:
        return subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=180)
    except subprocess.TimeoutExpired:
        print("motion-explainer: the browser did not finish within 180 seconds", file=sys.stderr)
        return None
    finally:
        shutil.rmtree(profile, ignore_errors=True)


def dump(url, size, reduced, budget=60000):
    done = run(url, size, reduced, budget, ["--dump-dom"])
    if done is None:
        return 1
    if done.returncode != 0 or not done.stdout:
        print("motion-explainer: the browser exited %d" % done.returncode, file=sys.stderr)
        return 1
    sys.stdout.write(done.stdout.decode("utf-8", "replace"))
    return 0


def shot(url, out, size, reduced, budget=60000):
    if os.path.exists(out):
        os.remove(out)
    done = run(url, size, reduced, budget, ["--screenshot=" + os.path.abspath(out)])
    if done is None:
        return 1
    if not os.path.isfile(out):
        print("motion-explainer: the browser exited %d without a screenshot" % done.returncode, file=sys.stderr)
        return 1
    return 0


def options(rest):
    """Reads --size, --reduced-motion, and --budget; returns them, or None after printing the first unknown option."""
    size, reduced, budget = "1000x900", False, 60000
    while rest:
        if rest[0] == "--size" and len(rest) > 1 and "x" in rest[1]:
            size, rest = rest[1], rest[2:]
        elif rest[0] == "--reduced-motion":
            reduced, rest = True, rest[1:]
        elif rest[0] == "--budget" and len(rest) > 1 and rest[1].isdigit():
            budget, rest = int(rest[1]), rest[2:]
        else:
            print("motion-explainer: unknown option %s" % rest[0], file=sys.stderr)
            return None
    return size, reduced, budget


def main(argv):
    if argv[:1] == ["path"]:
        exe = find()
        if not exe:
            print("motion-explainer: no Chromium-based browser found", file=sys.stderr)
            return 1
        print(exe)
        return 0
    if len(argv) >= 2 and argv[0] == "dump":
        opts = options(argv[2:])
        return 2 if opts is None else dump(argv[1], *opts)
    if len(argv) >= 3 and argv[0] == "shot":
        opts = options(argv[3:])
        return 2 if opts is None else shot(argv[1], argv[2], *opts)
    print((__doc__ or "").strip().split("\n\n")[1], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
