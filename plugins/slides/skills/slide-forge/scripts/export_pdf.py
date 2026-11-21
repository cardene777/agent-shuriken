#!/usr/bin/env python3
"""export_pdf.py: prints the public HTML of a slide to a PDF with pages of the slide's size,
1280 x 720 px, using Playwright's Chromium.

Needs Playwright, which uv fetches for one run, and Playwright's Chromium browser, which this
script never downloads:

    uv run --with playwright --no-project python3 export_pdf.py public.html out.pdf

Exit codes: 0 when the PDF is written, 3 when Playwright's Chromium is not installed (nothing is
written, and the message says how to install it), and 1 on any other failure.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

BROWSER_MISSING = 3
INSTALL_BROWSER = "uv run --with playwright --no-project python3 -m playwright install chromium"


def main() -> int:
    parser = argparse.ArgumentParser(description="print a slide's public HTML to PDF")
    parser.add_argument("input_html", help="public HTML written by export_html_final.py")
    parser.add_argument("output_pdf", help="output .pdf path")
    args = parser.parse_args()

    try:
        from playwright.sync_api import Error, sync_playwright
    except ImportError as e:
        print(f"ERROR: Playwright is not available ({e}). Run it through uv: "
              "uv run --with playwright --no-project python3 export_pdf.py ...", file=sys.stderr)
        return 1

    source = Path(args.input_html).resolve()
    if not source.is_file():
        print(f"ERROR: input HTML not found: {source}", file=sys.stderr)
        return 1

    with sync_playwright() as playwright:
        try:
            browser = playwright.chromium.launch()
        except Error as e:
            if "Executable doesn't exist" not in str(e):
                raise
            print("WARN: Playwright's Chromium browser is not installed, so no PDF was written.", file=sys.stderr)
            print(f"To install it once (about 150 MB), run: {INSTALL_BROWSER}", file=sys.stderr)
            return BROWSER_MISSING
        try:
            page = browser.new_page(viewport={"width": 1280, "height": 720})
            page.goto(source.as_uri())
            page.pdf(path=args.output_pdf, width="1280px", height="720px", print_background=True)
        finally:
            browser.close()

    print(f"OK: {args.output_pdf} generated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
