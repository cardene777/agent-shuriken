#!/usr/bin/env python3
"""Remove half-width spaces between Japanese text and ASCII letters or digits.

Japanese typesetting puts no space between Japanese and Latin text, so a space there looks
loose ("22 figures" written with spaces around the number). Only Japanese documents are changed:
a document whose `<html lang>` does not start with `ja` is left byte for byte as it is.

Left untouched:

- tags and attributes (changing them breaks styles and references)
- the inside of `<pre>` and `<code>` (shown exactly as written)
- the inside of `<script>` and `<style>`
- the inside of `<svg>` (text drawn in a figure belongs to the figure)
- the inside of elements with `data-replica` (text copied from a running screen)
- comments

A space next to a protected element is still checked: the space between Japanese text and
`<code>client_id</code>` is removed, while the inside of `<code>` stays as it is.

Usage: despace.py <document.html> [<document.html> ...]
Prints one line per file and exits 0.
"""
import re
import sys

JP = (
    "\u3041-\u309f"   # hiragana
    "\u30a0-\u30ff"   # katakana
    "\u3400-\u4dbf"   # CJK ideographs, extension A
    "\u4e00-\u9fff"   # CJK ideographs
    "\u3005\u3006\u30fc"   # iteration mark, closing mark, long-vowel mark
    # ideographic comma and full stop, middle dot, corner brackets, full-width parentheses,
    # question mark, exclamation mark
    "\u3001\u3002\u30fb\u300c\u300d\u300e\u300f\uff08\uff09\uff1f\uff01"
)
IS_JP = re.compile("[" + JP + "]").match
IS_AN = re.compile("[0-9A-Za-z]").match

PROTECT = re.compile(
    r"<pre\b.*?</pre>|<code\b.*?</code>|<svg\b.*?</svg>"
    r"|<script\b.*?</script>|<style\b.*?</style>|<!--.*?-->",
    re.S | re.I,
)
TAG = re.compile(r"<[^>]*>")
HTML_LANG = re.compile(r"<html\b[^>]*?\s(?:xml:)?lang\s*=\s*[\"']?([^\"'\s>]*)", re.I)

# `data-replica` marks text copied from a running screen. Removing spaces there would show a
# string the screen never printed.
REPLICA_OPEN = re.compile(r"<(\w+)\b[^>]*data-replica(?=[\s=/>])[^>]*?(/?)>", re.I)

# Elements without content. They protect nothing, so a mark on them is skipped.
VOID = {
    "area", "base", "br", "col", "embed", "hr", "img", "input",
    "link", "meta", "param", "source", "track", "wbr",
}


def document_lang(doc):
    """The `lang` attribute of the `<html>` element, or "" when there is none."""
    m = HTML_LANG.search(doc)
    return m.group(1).strip() if m else ""


def replica_spans(doc):
    """Ranges of elements with `data-replica`, counting nested elements of the same name.

    A non-greedy regular expression would end at the first closing tag of the same name inside
    the element. Without a closing tag, the range runs to the end of the file (nothing is removed).
    """
    spans = []
    for m in REPLICA_OPEN.finditer(doc):
        if spans and m.start() < spans[-1][1]:
            continue
        name = m.group(1).lower()
        if m.group(2) or name in VOID:
            continue
        pat = re.compile(r"<(/?)%s\b[^>]*?(/?)>" % re.escape(name), re.I)
        depth = 1
        end = len(doc)
        for t in pat.finditer(doc, m.end()):
            if t.group(1):
                depth -= 1
                if depth == 0:
                    end = t.end()
                    break
            elif not t.group(2):
                depth += 1
        spans.append((m.start(), end))
    return spans


def protected_spans(doc):
    """All protected ranges as one sorted list, with overlaps merged."""
    spans = [(m.start(), m.end()) for m in PROTECT.finditer(doc)]
    spans += replica_spans(doc)
    spans.sort()
    out = []
    for s, e in spans:
        if out and s < out[-1][1]:
            out[-1] = (out[-1][0], max(out[-1][1], e))
        else:
            out.append((s, e))
    return out


def stream(doc):
    """List of (character, index in doc), with tags left out.

    A protected range contributes only its first and last visible characters, without an index,
    so they are never removed. They keep the neighbors of the range: without them, the spaces
    around `<code>client_id</code>` would look like they had no neighbor and would stay.
    """
    out = []
    pos = 0
    marks = protected_spans(doc)
    for m in marks + [None]:
        end = m[0] if m else len(doc)
        p = pos
        for t in TAG.finditer(doc, pos, end):
            out += [(doc[i], i) for i in range(p, t.start())]
            p = t.end()
        out += [(doc[i], i) for i in range(p, end)]
        if m is None:
            break
        vis = [c for c in TAG.sub("", doc[m[0]:m[1]]) if not c.isspace()]
        # A range without visible characters gets a character that is neither Japanese nor ASCII,
        # which breaks the adjacency.
        edge = (vis[0], vis[-1]) if vis else ("\x00", "\x00")
        out.append((edge[0], None))
        out.append((edge[1], None))
        pos = m[1]
    return out


def despace(doc):
    """Return (new document, number of spaces removed)."""
    st = stream(doc)
    ch = [c for c, _ in st]
    drop = set()
    for n, c in enumerate(ch):
        if c != " " or st[n][1] is None:
            continue
        prev = next((ch[k] for k in range(n - 1, -1, -1) if ch[k] not in " \n\t"), None)
        nxt = next((ch[k] for k in range(n + 1, len(ch)) if ch[k] not in " \n\t"), None)
        if prev is None or nxt is None:
            continue
        # Only a single space directly between the two characters; a gap with more
        # whitespace (such as a line break) is left alone.
        if ch[n - 1] == " " or (n + 1 < len(ch) and ch[n + 1] == " "):
            continue
        if ch[n - 1] != prev:
            continue
        if n + 1 < len(ch) and ch[n + 1] != nxt:
            continue
        if (IS_JP(prev) and IS_AN(nxt)) or (IS_AN(prev) and IS_JP(nxt)):
            drop.add(st[n][1])
    if not drop:
        return doc, 0
    return "".join(c for i, c in enumerate(doc) if i not in drop), len(drop)


def main(paths):
    if not paths or paths[0] in ("-h", "--help"):
        print("usage: despace.py <body HTML> [<body HTML> ...]\n\n"
              "Remove half-width spaces between Japanese and ASCII letters or digits in a\n"
              "Japanese document (<html lang=\"ja\">), in place. Other documents are left as they are.")
        return 0 if paths else 2
    for path in paths:
        # newline="" keeps the file's line endings as they are.
        with open(path, encoding="utf-8", newline="") as f:
            src = f.read()
        lang = document_lang(src)
        if not lang.lower().startswith("ja"):
            print("-- skipped: document language is %s (%s)" % (lang or "missing", path))
            continue
        dst, n = despace(src)
        if n:
            with open(path, "w", encoding="utf-8", newline="") as f:
                f.write(dst)
        print("%s: %d spaces removed" % (path, n))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
