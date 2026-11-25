#!/usr/bin/env python3
"""Print an exported explainer page to a PDF with a Chromium-based browser already on the machine.

The page is printed with its own print styles, so the PDF holds what those styles draw for paper.
A copy of the page with an `@page` rule for
the paper size is written next to the page, printed, and removed, so links to files beside the page
still resolve and the page itself is not changed.

Usage:
  to-pdf.py <page.html> [<output.pdf>] [--paper a3|a4|letter]

The PDF defaults to the page's path with `.pdf`, and the paper to A3.

The browser is searched in this order, and nothing is installed:
1. The executable in the environment variable MECHANISM_EXPLAINER_BROWSER. When it is set, no other
   place is searched, and a path that is not an executable counts as no browser.
2. Playwright's chrome-headless-shell, newest version first.
3. An installed Google Chrome, Chromium, Microsoft Edge, or Brave.

Each run uses a throwaway browser profile that is removed afterwards.

Exit codes: 0 written, 2 bad arguments, 3 no browser found, 4 the browser wrote nothing.
"""
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile

ENV = "MECHANISM_EXPLAINER_BROWSER"
PAPERS = {"a3": "A3", "a4": "A4", "letter": "letter"}
PLAYWRIGHT_ROOTS = ["~/Library/Caches/ms-playwright", "~/.cache/ms-playwright"]
# The macOS .app builds of Playwright are left out: started without a display they can abort and
# show a crash notice, while chrome-headless-shell never registers as an application.
HEADLESS_RELS = [
    "chrome-headless-shell-mac-arm64/chrome-headless-shell",
    "chrome-headless-shell-mac-x64/chrome-headless-shell",
    "chrome-headless-shell-linux64/chrome-headless-shell",
    "chrome-linux/chrome",
]
MAC_APP_DIRS = ["/Applications", "~/Applications"]
MAC_APPS = [
    "Google Chrome.app/Contents/MacOS/Google Chrome",
    "Chromium.app/Contents/MacOS/Chromium",
    "Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
    "Brave Browser.app/Contents/MacOS/Brave Browser",
]
PATH_NAMES = ["google-chrome", "google-chrome-stable", "chromium", "chromium-browser", "microsoft-edge", "brave-browser"]
# Keep the run offline and silent: a fresh profile would otherwise sync, update components,
# fetch default apps, report crashes, or ask for the system keychain.
QUIET_FLAGS = [
    "--no-first-run", "--no-default-browser-check", "--disable-background-networking",
    "--disable-component-update", "--disable-sync", "--disable-default-apps", "--disable-extensions",
    "--disable-breakpad", "--metrics-recording-only", "--use-mock-keychain", "--password-store=basic",
]


def executable(path):
    return os.path.isfile(path) and os.access(path, os.X_OK)


def find_browser():
    """Return (path or None, places looked at)."""
    looked = []
    env = os.environ.get(ENV)
    if env:
        looked.append("%s (%s)" % (env, ENV))
        return (env if executable(env) else None), looked
    for root in PLAYWRIGHT_ROOTS:
        root = os.path.expanduser(root)
        looked.append(root)
        folders = glob.glob(os.path.join(root, "chromium*"))
        folders.sort(key=lambda d: int((re.search(r"(\d+)$", d) or [0, 0])[1] or 0), reverse=True)
        for folder in folders:
            for rel in HEADLESS_RELS:
                path = os.path.join(folder, rel)
                if executable(path):
                    return path, looked
    if sys.platform == "darwin":
        for base in MAC_APP_DIRS:
            for app in MAC_APPS:
                path = os.path.join(os.path.expanduser(base), app)
                looked.append(path)
                if executable(path):
                    return path, looked
        return None, looked
    for name in PATH_NAMES:
        looked.append("PATH:" + name)
        path = shutil.which(name)
        if path:
            return path, looked
    return None, looked


def parse(argv):
    paper, rest = "a3", []
    i = 0
    while i < len(argv):
        if argv[i] == "--paper" and i + 1 < len(argv):
            paper = argv[i + 1].lower()
            i += 2
            continue
        rest.append(argv[i])
        i += 1
    if not rest or len(rest) > 2 or paper not in PAPERS:
        return None
    src = os.path.abspath(rest[0])
    out = os.path.abspath(rest[1]) if len(rest) > 1 else os.path.splitext(src)[0] + ".pdf"
    return src, out, PAPERS[paper]


def with_paper(src, paper):
    """Write a copy of the page next to it with an @page rule, and return its path."""
    with open(src, encoding="utf-8") as f:
        html = f.read()
    rule = "<style>@page{size:%s;margin:12mm}</style>" % paper
    head = re.search(r"<head[^>]*>", html, re.I)
    html = html[:head.end()] + rule + html[head.end():] if head else rule + html
    fd, path = tempfile.mkstemp(prefix=".print-", suffix=".html", dir=os.path.dirname(src))
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(html)
    return path


def main(argv):
    if argv and argv[0] in ("-h", "--help"):
        print((__doc__ or "").strip())
        return 0
    args = parse(argv)
    if not args:
        print((__doc__ or "").strip())
        return 2
    src, out, paper = args
    if not os.path.isfile(src):
        print("no such page: %s" % src)
        return 2
    browser, looked = find_browser()
    if not browser:
        print("no Chromium-based browser found (looked in: %s). Set %s to a browser executable."
              % (", ".join(looked), ENV))
        return 3
    profile = tempfile.mkdtemp(prefix="mx-pdf-")
    copy = with_paper(src, paper)
    try:
        if os.path.exists(out):
            os.remove(out)
        subprocess.run(
            [browser, "--headless=new", "--disable-gpu", "--no-sandbox", "--hide-scrollbars",
             "--user-data-dir=" + profile] + QUIET_FLAGS +
            ["--virtual-time-budget=10000", "--run-all-compositor-stages-before-draw",
             "--no-pdf-header-footer", "--print-to-pdf=" + out, "file://" + copy],
            capture_output=True, text=True, timeout=180)
    except subprocess.TimeoutExpired:
        print("the browser did not finish within 180 s")
        return 4
    except OSError as e:
        print("could not start the browser (%s)" % e)
        return 4
    finally:
        shutil.rmtree(profile, ignore_errors=True)
        os.remove(copy)
    if not os.path.isfile(out) or os.path.getsize(out) == 0:
        print("the browser wrote no PDF (%s)" % out)
        return 4
    print("wrote %s (%d bytes, %s)" % (out, os.path.getsize(out), paper))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
