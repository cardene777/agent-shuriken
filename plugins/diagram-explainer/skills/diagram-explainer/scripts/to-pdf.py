#!/usr/bin/env python3
"""Print a finished document to PDF with a Chromium-based browser already on the machine.

The document is opened with `?paper=1`, the same print layout the reader gets from the
PDF button with "All pages": header and contents hidden, every section of every page in
order, one section per sheet, notes and both states of switchable charts shown.

Usage:

  to-pdf.py <document.html> [<output.pdf>]

The PDF defaults to the document's path with `.pdf`. The browser is found by `chrome.py`
(`DIAGRAM_EXPLAINER_BROWSER` overrides it) and runs with a throwaway profile.
The paper size is the browser's default for headless printing (US Letter in Chrome); the
PDF button in the document uses the reader's own print settings instead.

Exit codes: 0 written, 2 bad arguments, 3 no browser found, 4 the browser wrote nothing.
"""
import os
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import chrome  # noqa: E402


def main(argv):
    if not argv or argv[0] in ("-h", "--help") or len(argv) > 2:
        print(__doc__.strip())
        return 0 if argv and argv[0] in ("-h", "--help") else 2
    src = os.path.abspath(argv[0])
    if not os.path.isfile(src):
        print("no such document: %s" % src)
        return 2
    out = os.path.abspath(argv[1]) if len(argv) > 1 else os.path.splitext(src)[0] + ".pdf"
    browser, looked = chrome.find_chrome()
    if not browser:
        print("no Chromium-based browser found (looked in: %s). Set %s to a browser executable."
              % (", ".join(looked), chrome.ENV))
        return 3
    profile = tempfile.mkdtemp(prefix="dx-pdf-")
    try:
        if os.path.exists(out):
            os.remove(out)
        subprocess.run(
            [browser, "--headless=new", "--disable-gpu", "--no-sandbox", "--hide-scrollbars",
             "--user-data-dir=" + profile] + chrome.QUIET_FLAGS +
            ["--virtual-time-budget=8000", "--run-all-compositor-stages-before-draw",
             "--no-pdf-header-footer", "--print-to-pdf=" + out,
             "file://" + src + "?paper=1"],
            capture_output=True, text=True, timeout=180)
    except subprocess.TimeoutExpired:
        print("the browser did not finish within 180 s")
        return 4
    finally:
        shutil.rmtree(profile, ignore_errors=True)
    if not os.path.isfile(out) or os.path.getsize(out) == 0:
        print("the browser wrote no PDF (%s)" % out)
        return 4
    print("wrote %s (%d bytes)" % (out, os.path.getsize(out)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
