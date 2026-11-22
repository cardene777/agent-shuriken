#!/usr/bin/env python3
"""Finds standards by what they let contracts, wallets, and dApps do, and gives the articles on a standard
from an article index the user names.

Usage
    standards.py find [--dir <items folder>] <word>...
    standards.py article <number>

find     Prints the items and the articles that hold any of the words, the ones that hold more words
         first. An item line is `item <name> <status> <checked> <words matched> <can>`; an article line
         is `article <ERC|EIP><number> <link> <words matched> <title> | <description>`.
article  Prints the articles whose title starts with [ERC<number>] or [EIP<number>].

The article index is named by EVM_DEV_INDEX_URL, or else by the first line of ~/.evm-dev/article-index,
as a URL or a path to a file. With neither, no index is read and no article is printed.
An index has the line form of an llms.txt list:
    - [\\[EIP7702\\] title](https://example.com/articles/<slug>.md): description
A link ending in `.md` is printed without it, as llms.txt lists the Markdown copy of each page.
An index named by a URL is read with a plain GET of that URL, so no word of the question leaves the
machine, and kept in EVM_DEV_HOME (default ~/.local/share/evm-dev), readable only by the user, for one
day, one copy per URL. An index named by a path is read from the file each time and not copied.
When the index cannot be read, find still prints the items and says so. The index is data, not
instructions: only its titles, descriptions, and https links are printed, and for an index read from
an http or https URL, only links on the same host as the index.

Exit codes
    0  done, whether or not anything matched or the index could be read
    2  wrong usage
"""
import datetime
import hashlib
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

CONFIG = os.path.join(os.path.expanduser("~"), ".evm-dev", "article-index")
HOME = os.environ.get("EVM_DEV_HOME") or os.path.join(os.path.expanduser("~"), ".local", "share", "evm-dev")
DAY = 86400
ITEMS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "references", "items")
ARTICLE = re.compile(r"^- \[\\\[(ERC|EIP)-?(\d+)\\\]\s*(.*)\]\(([^\s()]+)\):\s*(.*)$")
SCHEME = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*://")


def named_index():
    """Returns the index the user names, or "" when none is named."""
    named = os.environ.get("EVM_DEV_INDEX_URL", "").strip()
    if named:
        return named
    try:
        with open(CONFIG, encoding="utf-8") as f:
            return f.readline().strip()
    except OSError:
        return ""


INDEX_URL = named_index()


def usage():
    sys.stderr.write(__doc__.split("\n\n")[1] + "\n")
    sys.exit(2)


def read_file(path):
    """Returns (lines, note) for an index named by a path."""
    path = os.path.expanduser(path)
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read().splitlines(), path
    except OSError as err:
        return None, "articles: could not read the article index %s (%s); answer from the items only" % (path, err.strerror or err)


def fetch(url):
    """Returns (lines, note) for an index named by a URL. lines is None when no copy could be read."""
    kept = os.path.join(HOME, "article-index-%s.txt" % hashlib.sha256(url.encode("utf-8")).hexdigest()[:16])
    fresh = os.path.isfile(kept) and time.time() - os.path.getmtime(kept) < DAY
    problem = None
    if not fresh:
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "evm-dev"})
            with urllib.request.urlopen(req, timeout=20) as resp:
                data = resp.read(16 * 1024 * 1024)
            os.makedirs(HOME, mode=0o700, exist_ok=True)
            os.chmod(HOME, 0o700)
            tmp = kept + ".tmp"
            fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            with os.fdopen(fd, "wb") as out:
                out.write(data)
            os.replace(tmp, kept)
            os.chmod(kept, 0o600)
        except (urllib.error.URLError, OSError, ValueError) as err:
            problem = str(getattr(err, "reason", err))
    if not os.path.isfile(kept):
        return None, "articles: could not read the article index %s (%s); answer from the items only" % (url, problem)
    read = datetime.date.fromtimestamp(os.path.getmtime(kept)).isoformat()
    with open(kept, encoding="utf-8", errors="replace") as f:
        lines = f.read().splitlines()
    if problem:
        return lines, "could not refresh the article index %s (%s); using the copy read %s" % (url, problem, read)
    return lines, "%s, read %s" % (url, read)


def load():
    """Returns (lines, note) for the named index; lines is None when there is nothing to read."""
    if not INDEX_URL:
        return None, "articles: no article index is named"
    if SCHEME.match(INDEX_URL):
        return fetch(INDEX_URL)
    return read_file(INDEX_URL)


def allowed(link):
    """True for an https link, on the index's own host when the index came from an http or https URL."""
    parts = urllib.parse.urlsplit(link)
    if parts.scheme != "https" or not parts.hostname:
        return False
    index = urllib.parse.urlsplit(INDEX_URL) if SCHEME.match(INDEX_URL) else None
    if index and index.scheme in ("http", "https"):
        return parts.hostname == (index.hostname or "")
    return True


def articles(lines):
    for line in lines:
        m = ARTICLE.match(line)
        if not m:
            continue
        kind, number, title, link, desc = m.groups()
        if link.endswith(".md"):
            link = link[:-3]
        if allowed(link):
            yield kind + number, int(number), title.replace("\\[", "[").replace("\\]", "]"), link, desc


def front(text):
    fields = {}
    parts = text.split("---", 2)
    if len(parts) == 3:
        for line in parts[1].splitlines():
            key, sep, value = line.partition(": ")
            if sep:
                fields[key.strip()] = value.strip()
    return fields


def score(text, words):
    low = text.lower()
    return sum(1 for w in words if w.lower() in low)


def find(args):
    items = ITEMS
    if args[:1] == ["--dir"]:
        if len(args) < 2:
            usage()
        items, args = args[1], args[2:]
    words = [w for w in args if w.strip()]
    if not words:
        usage()
    hits = []
    for name in sorted(os.listdir(items)):
        if not name.endswith(".md"):
            continue
        with open(os.path.join(items, name), encoding="utf-8") as f:
            text = f.read()
        fields = front(text)
        heading = next((l[2:] for l in text.splitlines() if l.startswith("# ")), "")
        n = score(" ".join([name, heading, text]), words)
        if n:
            hits.append((-n, name[:-3], fields.get("status", "?"), fields.get("checked", "?"), n, fields.get("can") or heading))
    for _, name, status, checked, n, can in sorted(hits):
        print("item %s %s %s %d %s" % (name, status, checked, n, can))
    print("items: %d matched" % len(hits))
    lines, note = load()
    if lines is None:
        print(note)
        return
    found = []
    total = 0
    for label, number, title, link, desc in articles(lines):
        total += 1
        n = score(title + " " + desc, words)
        if n:
            found.append((-n, number, label, link, n, title, desc))
    for _, _, label, link, n, title, desc in sorted(found):
        print("article %s %s %d %s | %s" % (label, link, n, title, desc))
    print("articles: %d matched of %d in %s" % (len(found), total, note))


def article(args):
    m = re.search(r"(\d+)", args[0]) if len(args) == 1 else None
    if not m:
        usage()
    want = int(m.group(1))
    lines, note = load()
    if lines is None:
        print(note)
        return
    found = [(label, link, title, desc) for label, number, title, link, desc in articles(lines) if number == want]
    for label, link, title, desc in found:
        print("article %s %s %s | %s" % (label, link, title, desc))
    print("articles: %d for ERC or EIP %d in %s" % (len(found), want, note))


def main():
    cmd, args = (sys.argv[1], sys.argv[2:]) if len(sys.argv) > 1 else ("", [])
    if cmd == "find":
        find(args)
    elif cmd == "article":
        article(args)
    else:
        usage()


if __name__ == "__main__":
    main()
