"""Turn the SVG into a PNG with a Chromium-based browser that is already installed.

Nothing is downloaded or installed. The browser is looked for in this order:

1. The path in EXCALIDRAW_DIAGRAM_BROWSER (the value "none" means: make no PNG).
2. Playwright's chrome-headless-shell, if Playwright already put one in its cache.
3. Google Chrome, Chromium, or Microsoft Edge installed on the machine.

The browser runs headless with a throwaway profile that is deleted afterwards, opens only
the local SVG, and cannot resolve any host name, so it reaches no network.
Every PNG gets a text chunk with a digest of its image data, so a later run can tell
whether the file is still exactly as this plugin wrote it.
"""
import glob
import hashlib
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib

ENV = "EXCALIDRAW_DIAGRAM_BROWSER"
SIGNATURE = b"\x89PNG\r\n\x1a\n"
MARK = b"Software\x00excalidraw-diagram sha256:"
MAX_SIDE = 16000
PLAYWRIGHT_ROOTS = ["~/Library/Caches/ms-playwright", "~/.cache/ms-playwright"]
HEADLESS_RELS = [
    "chrome-headless-shell-mac-arm64/chrome-headless-shell",
    "chrome-headless-shell-mac-x64/chrome-headless-shell",
    "chrome-headless-shell-linux64/chrome-headless-shell",
]
MAC_APPS = [
    "Google Chrome.app/Contents/MacOS/Google Chrome",
    "Chromium.app/Contents/MacOS/Chromium",
    "Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
]
PATH_NAMES = ["google-chrome", "google-chrome-stable", "chromium", "chromium-browser",
              "microsoft-edge", "microsoft-edge-stable", "msedge", "chrome"]
WINDOWS_RELS = ["Google/Chrome/Application/chrome.exe", "Microsoft/Edge/Application/msedge.exe",
                "Chromium/Application/chrome.exe"]
FLAGS = [
    "--headless=new", "--disable-gpu", "--hide-scrollbars", "--no-first-run",
    "--no-default-browser-check", "--disable-background-networking", "--disable-component-update",
    "--disable-sync", "--disable-default-apps", "--disable-extensions", "--disable-breakpad",
    "--metrics-recording-only", "--use-mock-keychain", "--password-store=basic",
    "--host-resolver-rules=MAP * ~NOTFOUND",
]


def _executable(p):
    return bool(p) and os.path.isfile(p) and os.access(p, os.X_OK)


def find_browser():
    """Return (path, None) or (None, why no browser is used)."""
    env = os.environ.get(ENV, "")
    if env:
        if env == "none":
            return None, "%s is set to none" % ENV
        return (env, None) if _executable(env) else (None, "%s=%s is not an executable file" % (ENV, env))
    for root in PLAYWRIGHT_ROOTS:
        for folder in sorted(glob.glob(os.path.join(os.path.expanduser(root), "chromium_headless_shell-*")), reverse=True):
            for rel in HEADLESS_RELS:
                if _executable(os.path.join(folder, rel)):
                    return os.path.join(folder, rel), None
    if sys.platform == "darwin":
        for base in ("/Applications", os.path.expanduser("~/Applications")):
            for app in MAC_APPS:
                if _executable(os.path.join(base, app)):
                    return os.path.join(base, app), None
    if os.name == "nt":
        for var in ("PROGRAMFILES", "PROGRAMFILES(X86)", "LOCALAPPDATA"):
            for rel in WINDOWS_RELS:
                p = os.path.join(os.environ.get(var, ""), rel)
                if os.environ.get(var) and os.path.isfile(p):
                    return p, None
    for name in PATH_NAMES:
        p = shutil.which(name)
        if p:
            return p, None
    return None, "no Playwright chrome-headless-shell, Chrome, Chromium, or Edge was found"


def _chunks(data):
    if data[:8] != SIGNATURE:
        raise ValueError("not a PNG")
    pos, out = 8, []
    while pos + 8 <= len(data):
        n = struct.unpack(">I", data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        out.append((kind, data[pos + 8:pos + 8 + n]))
        pos += 12 + n
        if kind == b"IEND":
            break
    if not out or out[0][0] != b"IHDR" or out[-1][0] != b"IEND":
        raise ValueError("a PNG without IHDR or IEND")
    return out


def size(data):
    """(width, height) of a PNG, or None when the bytes are not a PNG."""
    try:
        return struct.unpack(">II", _chunks(data)[0][1][:8])
    except (ValueError, struct.error):
        return None


def _chunk(kind, body):
    return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)


def _image_digest(chunks):
    h = hashlib.sha256()
    for kind, body in chunks:
        if kind == b"IDAT":
            h.update(body)
    return h.hexdigest().encode("ascii")


def add_marker(data):
    chunks = [c for c in _chunks(data) if not (c[0] == b"tEXt" and c[1].startswith(MARK))]
    out = [SIGNATURE, _chunk(*chunks[0]), _chunk(b"tEXt", MARK + _image_digest(chunks))]
    out.extend(_chunk(kind, body) for kind, body in chunks[1:])
    return b"".join(out)


def marker_ok(data):
    """True when the PNG still has this plugin's digest of its image data."""
    try:
        chunks = _chunks(data)
    except ValueError:
        return False
    marks = [body[len(MARK):] for kind, body in chunks if kind == b"tEXt" and body.startswith(MARK)]
    return len(marks) == 1 and marks[0] == _image_digest(chunks)


def make(svg_path, width, height, scale):
    """Render the SVG. Returns (png bytes with the marker, browser path, None) or (None, browser, reason)."""
    browser, why = find_browser()
    if browser is None:
        return None, None, why
    while scale > 1 and max(width, height) * scale > MAX_SIDE:
        scale -= 1
    if max(width, height) * scale > MAX_SIDE:
        return None, browser, "the diagram is %dx%d px, over the %d px a browser screenshot can hold" % (width, height, MAX_SIDE)
    profile = tempfile.mkdtemp(prefix="excalidraw-diagram-browser-")
    out = os.path.join(profile, "shot.png")
    try:
        try:
            subprocess.run(
                [browser] + FLAGS + ["--user-data-dir=" + profile, "--window-size=%d,%d" % (width, height),
                                     "--force-device-scale-factor=%d" % scale, "--screenshot=" + out,
                                     "file://" + os.path.abspath(svg_path)],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=90)
        except subprocess.TimeoutExpired:
            return None, browser, "the browser did not finish within 90 s"
        except OSError as e:
            return None, browser, "the browser could not start (%s)" % (e.strerror or e)
        try:
            with open(out, "rb") as f:
                data = f.read()
        except OSError:
            return None, browser, "the browser wrote no image"
        got = size(data)
        want = (width * scale, height * scale)
        if got != want:
            return None, browser, "the browser wrote a %s image instead of %dx%d" % (
                "%dx%d" % got if got else "broken", want[0], want[1])
        return add_marker(data), browser, None
    finally:
        shutil.rmtree(profile, ignore_errors=True)
