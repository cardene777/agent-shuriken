#!/usr/bin/env python3
"""Find a Chromium-based browser and run it headless.

`check.py --live` uses this to open the finished document and measure it.
Nothing is installed: the search only looks at browsers already on the machine.

Search order:

1. The path in the environment variable `DIAGRAM_EXPLAINER_BROWSER`.
2. Playwright's `chrome-headless-shell`, newest version first.
3. A browser installed on the machine (Google Chrome, Chromium, Microsoft Edge, Brave).
"""
import glob
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile

ENV = "DIAGRAM_EXPLAINER_BROWSER"

# Where Playwright keeps the browsers it downloads (macOS, then Linux).
PLAYWRIGHT_ROOTS = ["~/Library/Caches/ms-playwright", "~/.cache/ms-playwright"]

# Executables inside one Playwright browser folder.
#
# The macOS `.app` builds (Google Chrome for Testing.app, Chromium.app) are not
# listed. Even with `--headless=new` they register as an application with a
# window, and when started from a process without a display connection they
# can abort; macOS then shows a crash notice to the user.
# `chrome-headless-shell` never registers, so it neither aborts nor shows a notice.
HEADLESS_RELS = [
    "chrome-headless-shell-mac-arm64/chrome-headless-shell",
    "chrome-headless-shell-mac-x64/chrome-headless-shell",
    "chrome-headless-shell-linux64/chrome-headless-shell",
    "chrome-linux/chrome",
]

# Installed browsers, used only when no headless shell is found
# (on macOS these are `.app` builds, see the note above).
MAC_APP_DIRS = ["/Applications", "~/Applications"]
MAC_APPS = [
    "Google Chrome.app/Contents/MacOS/Google Chrome",
    "Chromium.app/Contents/MacOS/Chromium",
    "Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
    "Brave Browser.app/Contents/MacOS/Brave Browser",
]
PATH_NAMES = [
    "google-chrome",
    "google-chrome-stable",
    "chromium",
    "chromium-browser",
    "microsoft-edge",
    "brave-browser",
]

# Keep the run offline and silent: a fresh profile would otherwise sync, update
# components, fetch default apps, report crashes, or ask for the system keychain.
QUIET_FLAGS = [
    "--no-first-run",
    "--no-default-browser-check",
    "--disable-background-networking",
    "--disable-component-update",
    "--disable-sync",
    "--disable-default-apps",
    "--disable-extensions",
    "--disable-breakpad",
    "--metrics-recording-only",
    "--use-mock-keychain",
    "--password-store=basic",
]


def _rev(path):
    """Version number at the end of a Playwright folder name; 0 sorts last."""
    m = re.search(r"chromium[^0-9]*(\d+)", os.path.basename(path))
    return int(m.group(1)) if m else 0


def _headless(roots, looked):
    for root in roots:
        root = os.path.expanduser(root)
        looked.append(root)
        if not os.path.isdir(root):
            continue
        for d in sorted(glob.glob(os.path.join(root, "chromium*")), key=_rev, reverse=True):
            for rel in HEADLESS_RELS:
                p = os.path.join(d, rel)
                if os.path.isfile(p) and os.access(p, os.X_OK):
                    return p
    return None


def _installed(looked):
    if sys.platform == "darwin":
        for base in MAC_APP_DIRS:
            base = os.path.expanduser(base)
            for app in MAC_APPS:
                p = os.path.join(base, app)
                looked.append(p)
                if os.path.isfile(p) and os.access(p, os.X_OK):
                    return p
        return None
    for name in PATH_NAMES:
        looked.append("PATH:" + name)
        p = shutil.which(name)
        if p:
            return p
    return None


def find_chrome(roots=None):
    """Find a browser. Returns (path or None, list of places looked at).

    `roots` replaces the Playwright folders to search. When it is given, installed
    browsers are not searched, so a test can make the search miss with `roots=[]`.
    """
    looked = []
    env = os.environ.get(ENV)
    if env:
        looked.append("%s (%s)" % (env, ENV))
        if os.path.isfile(env) and os.access(env, os.X_OK):
            return env, looked
    p = _headless(PLAYWRIGHT_ROOTS if roots is None else roots, looked)
    if p:
        return p, looked
    if roots is None:
        p = _installed(looked)
        if p:
            return p, looked
    return None, looked


def run(chrome, path, width, height, budget, limit):
    """Open one page headless and return its DOM. Returns (stdout, reason it failed or None).

    `budget` is the virtual time in milliseconds the page may run, `limit` the wall-clock
    timeout in seconds. Each run gets a throwaway profile that is removed afterwards.
    """
    profile = tempfile.mkdtemp(prefix="dx-browser-")
    try:
        try:
            out = subprocess.run(
                [chrome, "--headless=new", "--disable-gpu", "--no-sandbox",
                 "--hide-scrollbars", "--user-data-dir=" + profile] + QUIET_FLAGS +
                ["--window-size=%d,%d" % (width, height),
                 "--virtual-time-budget=%d" % budget, "--dump-dom",
                 "file://" + os.path.abspath(path)],
                capture_output=True, text=True, timeout=limit)
        except subprocess.TimeoutExpired:
            return "", "did not finish within %d s" % limit
        except OSError as e:
            return "", "could not start the browser (%s)" % e
        if out.returncode not in (0, -signal.SIGTERM, 143):
            return out.stdout, "the browser exited with code %d" % out.returncode
        return out.stdout, None
    finally:
        shutil.rmtree(profile, ignore_errors=True)
