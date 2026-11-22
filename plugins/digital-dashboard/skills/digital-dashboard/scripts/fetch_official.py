#!/usr/bin/env python3
"""Download the Digital Agency's official dashboard documents listed in references/official-files.json.

Usage:
    python3 fetch_official.py [--dest <dir>] [--manifest <path>]

Each entry of the manifest has a relative `path`, a `url`, and the `sha256` of the published file.
A file already under the destination whose fingerprint matches is left untouched, so running the
command again downloads nothing and changes no file. Any other file is downloaded into a temporary
file next to its place, checked against the fingerprint, and moved into place only when it matches.
A file whose fingerprint differs is not kept, and a copy that no longer matches is removed.

The destination defaults to $DIGITAL_DASHBOARD_HOME, or ~/.local/share/digital-dashboard/ when that
is not set. A folder the command creates is readable only by you.

Prints one line per file and a summary. Exits 0 when every file matches, 1 when a download fails or
a fingerprint differs, and 2 when the manifest or the arguments cannot be read.
Uses only the Python standard library.
"""

import argparse
import hashlib
import http.client
import json
import os
import sys
import tempfile
import urllib.parse
import urllib.request
from typing import NoReturn

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_MANIFEST = os.path.join(HERE, "..", "references", "official-files.json")
TIMEOUT_SECONDS = 120
CHUNK = 1 << 20


def default_destination():
    override = os.environ.get("DIGITAL_DASHBOARD_HOME")
    if override:
        return override
    return os.path.join(os.path.expanduser("~"), ".local", "share", "digital-dashboard")


def fail(message) -> NoReturn:
    print(f"fetch_official.py: {message}", file=sys.stderr)
    sys.exit(2)


def read_manifest(path):
    try:
        with open(path, encoding="utf-8") as source:
            rows = json.load(source)
    except (OSError, ValueError) as error:
        fail(f"cannot read the manifest {path}: {error}")
    if not isinstance(rows, list) or not rows:
        fail(f"the manifest {path} is not a non-empty JSON array")
    for row in rows:
        target = row.get("path") if isinstance(row, dict) else None
        if not isinstance(target, str) or not target or os.path.isabs(target) or ".." in target.split("/"):
            fail(f"the manifest has an entry without a relative path: {row!r}")
        if not isinstance(row.get("sha256"), str) or len(row["sha256"]) != 64:
            fail(f"{target}: the manifest entry has no 64-character sha256")
        scheme = urllib.parse.urlsplit(str(row.get("url", ""))).scheme
        if scheme not in ("https", "file"):
            fail(f"{target}: the url must be https:// (or file:// for a local copy), not {row.get('url')!r}")
    return rows


def fingerprint(path):
    digest = hashlib.sha256()
    with open(path, "rb") as source:
        for block in iter(lambda: source.read(CHUNK), b""):
            digest.update(block)
    return digest.hexdigest()


def download(url, target):
    """Writes the body of url into a temporary file next to target and returns its path."""
    folder = os.path.dirname(target)
    os.makedirs(folder, mode=0o700, exist_ok=True)
    handle, temporary = tempfile.mkstemp(prefix=".download-", dir=folder)
    try:
        request = urllib.request.Request(url, headers={"User-Agent": "digital-dashboard-fetch"})
        with os.fdopen(handle, "wb") as sink, urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            for block in iter(lambda: response.read(CHUNK), b""):
                sink.write(block)
    except BaseException:
        os.unlink(temporary)
        raise
    return temporary


def main():
    parser = argparse.ArgumentParser(description="Download the official dashboard documents and check their fingerprints.")
    parser.add_argument("--dest", default=default_destination(), help="folder to write the files into")
    parser.add_argument("--manifest", default=DEFAULT_MANIFEST, help="list of files to download")
    args = parser.parse_args()

    rows = read_manifest(args.manifest)
    dest = os.path.abspath(args.dest)
    os.makedirs(dest, mode=0o700, exist_ok=True)

    counts = {"kept": 0, "fetched": 0, "rejected": 0, "failed": 0}
    for row in rows:
        path, want = row["path"], row["sha256"]
        target = os.path.join(dest, path)
        if os.path.isfile(target) and fingerprint(target) == want:
            counts["kept"] += 1
            print(f"kept      {path}")
            continue
        try:
            temporary = download(row["url"], target)
        except (OSError, ValueError, http.client.HTTPException) as error:
            counts["failed"] += 1
            print(f"failed    {path}: {row['url']}: {error}")
            continue
        got = fingerprint(temporary)
        if got != want:
            os.unlink(temporary)
            if os.path.isfile(target):
                os.unlink(target)
            counts["rejected"] += 1
            print(f"rejected  {path}: the sha256 is {got}, not {want}; the file was not kept")
            continue
        os.chmod(temporary, 0o600)
        os.replace(temporary, target)
        counts["fetched"] += 1
        print(f"fetched   {path}")

    print(f"\n{len(rows)} files in {dest}: {counts['kept']} kept, {counts['fetched']} fetched, "
          f"{counts['rejected']} rejected, {counts['failed']} failed")
    sys.exit(0 if counts["rejected"] == 0 and counts["failed"] == 0 else 1)


if __name__ == "__main__":
    main()
