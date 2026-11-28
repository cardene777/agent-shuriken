#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = [
#   "Pillow==13.0.0",
# ]
# ///
"""Captures frames of a page built by build.py, so the video can be checked by eye before it is shown.

Usage:
  capture.py scenes <page.html> <out-dir>
  capture.py sheet <page.html> <out.png> [--every <ms>] [--cols <n>]

scenes saves the middle and the end of every scene as scene-<NN>-mid.png and scene-<NN>-end.png,
896 x 504 each. sheet saves one picture with a frame every <ms> milliseconds (1000 unless --every
says otherwise), <cols> to a row (4 unless --cols says otherwise), each with its time under it.

Both first play the page through once in a headless browser and print the errors it reported, one
`page error: <message>` per line, then `page errors: <count>`. Frames are taken with the
Chromium-based browser browser.py finds, at times the page's window.MX names, and the sheet is tiled
with Pillow, which uv fetches for one run (scripts/with_pillow.py).

Exit codes:
  0  saved the frames, and the page reported no error
  1  the page reported an error (the frames are still saved), or the browser failed
  2  called wrongly
  3  uv is missing
"""

import html
import json
import math
import os
import re
import shutil
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import browser  # noqa: E402
import with_pillow  # noqa: E402

W, H = 896, 504
USAGE = "usage: capture.py scenes <page.html> <out-dir>\n       capture.py sheet <page.html> <out.png> [--every <ms>] [--cols <n>]"

# Records errors before the engine runs, and runs animation frames on timers, which run on virtual time.
WATCH = ("<script>window.__errors = []; addEventListener('error', e => __errors.push(String(e.message || e)));"
         " addEventListener('unhandledrejection', e => __errors.push(String(e.reason)));"
         " window.requestAnimationFrame = f => setTimeout(() => f(performance.now()), 16);"
         " window.cancelAnimationFrame = id => clearTimeout(id);</script>")
# Plays the video through once, then reports its times and the errors.
REPORT = ("<pre id=\"mx-capture\"></pre><script>(async () => { const wait = ms => new Promise(r => setTimeout(r, ms));"
          " const out = {}; await wait(800);"
          " if (window.MX) { out.end = MX.END; out.scenes = MX.SCENE_T; MX.seek(0, true); await wait(MX.END + 1500); }"
          " out.errors = window.__errors; document.getElementById('mx-capture').textContent = JSON.stringify(out); })();</script>")
# Shows only the video, at its own size, without the pause badge.
FRAME_CSS = ("<style>html, body { margin: 0 !important; overflow: hidden !important; } .me { max-width: none !important; padding: 0 !important; }"
             " .me > :not(#me-player), #me-player > :not(.mx) { display: none !important; }"
             " #me-player > .mx { width: %dpx !important; border-radius: 0 !important; box-shadow: none !important; }"
             " .mx .pausebadge { display: none !important; }</style>" % W)


def insert(page, head="", tail=""):
    i, j = page.find("<head>"), page.rfind("</body>")
    if i < 0 or j < 0:
        return None
    return page[:i + 6] + head + page[i + 6:j] + tail + page[j:]


def report(page, work):
    """Plays the page once and returns what it reported: end, scenes, and errors."""
    path = os.path.join(work, "report.html")
    open(path, "w", encoding="utf-8").write(insert(page, WATCH, REPORT))
    done = browser.run("file://" + path, "%dx%d" % (W, H), False, 900000, ["--dump-dom"])
    if done is None or done.returncode != 0:
        return None
    m = re.search(r'<pre id="mx-capture">(.*?)</pre>', done.stdout.decode("utf-8", "replace"), re.S)
    return json.loads(html.unescape(m.group(1))) if m and m.group(1).strip() else None


def frames(page, work, times, names):
    """Saves a screenshot of the video at each time; returns the paths, in order."""
    def one(job):
        t, name = job
        copy = os.path.join(work, "frame-%d.html" % t)
        open(copy, "w", encoding="utf-8").write(insert(page, FRAME_CSS + "<script>window.SHOT_T = %d;</script>" % t))
        return name if browser.shot("file://" + copy, name, "%dx%d" % (W, H), False, budget=4000) == 0 else None
    with ThreadPoolExecutor(max_workers=4) as pool:
        return list(pool.map(one, zip(times, names)))


def errors_of(got):
    for e in got["errors"]:
        print("page error: %s" % e)
    print("page errors: %d" % len(got["errors"]))
    return 1 if got["errors"] else 0


def scenes(page, out_dir, work):
    got = report(page, work)
    if got is None:
        print("motion-explainer: the page did not report its scenes; is it a page built by build.py?", file=sys.stderr)
        return 1
    if "end" not in got:
        errors_of(got)
        return 1
    os.makedirs(out_dir, exist_ok=True)
    starts, end = got["scenes"], got["end"]
    times, names = [], []
    for i, t0 in enumerate(starts):
        t1 = (starts[i + 1] if i + 1 < len(starts) else end) - 1
        for when, t in (("mid", (t0 + t1) // 2), ("end", t1 - 1)):
            times.append(t)
            names.append(os.path.join(out_dir, "scene-%02d-%s.png" % (i + 1, when)))
    saved = frames(page, work, times, names)
    if None in saved:
        print("motion-explainer: the browser did not save every frame", file=sys.stderr)
        return 1
    print("saved %d frames of %d scenes to %s" % (len(saved), len(starts), out_dir))
    return errors_of(got)


def sheet(page, out, every, cols, work):
    from PIL import Image, ImageDraw
    got = report(page, work)
    if got is None:
        print("motion-explainer: the page did not report its scenes; is it a page built by build.py?", file=sys.stderr)
        return 1
    if "end" not in got:
        errors_of(got)
        return 1
    times = list(range(0, got["end"] + 1, every))
    names = [os.path.join(work, "sheet-%06d.png" % t) for t in times]
    saved = frames(page, work, times, names)
    if None in saved:
        print("motion-explainer: the browser did not save every frame", file=sys.stderr)
        return 1
    tw, th, label = W // 2, H // 2, 22
    rows = math.ceil(len(times) / cols)
    board = Image.new("RGB", (cols * tw + (cols + 1) * 8, rows * (th + label) + (rows + 1) * 8), "#ffffff")
    draw = ImageDraw.Draw(board)
    for n, (t, name) in enumerate(zip(times, saved)):
        x, y = 8 + (n % cols) * (tw + 8), 8 + (n // cols) * (th + label + 8)
        board.paste(Image.open(name).convert("RGB").resize((tw, th), Image.Resampling.LANCZOS), (x, y))
        draw.text((x + 4, y + th + 4), "%d ms" % t, fill="#222222")
    folder = os.path.dirname(os.path.abspath(out))
    os.makedirs(folder, exist_ok=True)
    board.save(out)
    print("sheet: %d frames every %d ms, saved to %s" % (len(times), every, out))
    return errors_of(got)


def main(argv):
    if len(argv) < 3 or argv[0] not in ("scenes", "sheet"):
        print(USAGE, file=sys.stderr)
        return 2
    command, page_path, out = argv[:3]
    every, cols, rest = 1000, 4, argv[3:]
    while rest:
        if command == "sheet" and rest[0] in ("--every", "--cols") and len(rest) > 1 and rest[1].isdigit() and int(rest[1]) > 0:
            every, cols = (int(rest[1]), cols) if rest[0] == "--every" else (every, int(rest[1]))
            rest = rest[2:]
        else:
            print(USAGE, file=sys.stderr)
            return 2
    try:
        page = open(page_path, encoding="utf-8").read()
    except OSError as e:
        print("motion-explainer: %s cannot be read: %s" % (page_path, e.strerror), file=sys.stderr)
        return 1
    if insert(page) is None:
        print("motion-explainer: %s has no <head> or </body>" % page_path, file=sys.stderr)
        return 1
    work = tempfile.mkdtemp(prefix="motion-explainer-capture.")
    try:
        if command == "scenes":
            return scenes(page, out, work)
        return sheet(page, out, every, cols, work)
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    if len(sys.argv) < 4 or sys.argv[1] not in ("scenes", "sheet"):
        print(USAGE, file=sys.stderr)
        sys.exit(2)
    with_pillow.ensure(__file__)
    sys.exit(main(sys.argv[1:]))
