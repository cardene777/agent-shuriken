"""Finds the page each contents entry of a report starts on, and writes a copy of the report with the pages.

Usage:
  python3 toc-pages.py pages <report.html> <report.pdf>
      Prints "<id> <page>" for each entry of the contents list, in order, and exits 0.
      When a page cannot be found, prints one line with the reason and exits 1.
  python3 toc-pages.py copy <report.html> <pages file>
      Writes a hidden copy of the report next to it, with a dot leader and the page after each
      contents entry, prints the copy's path, and exits 0. The report itself is never changed.

The pages come from the named destinations Chromium writes into a PDF for every element that a
link in the page points at: "/summary [12 0 R /XYZ 0 538 0]" names the page object of #summary.
Pages are counted from the cover, which is page 1, the same way as the numbers at the bottom of
the pages and the page numbers a PDF viewer shows.
"""
import os
import re
import sys
import tempfile
import zlib
from urllib.parse import unquote

CONTENTS = re.compile(r"<nav\b[^>]*\bclass=[\"'][^\"']*\btoc\b[^\"']*[\"'][^>]*>(.*?)</nav>", re.S | re.I)
ENTRY = re.compile(r"(<a\b[^>]*\bhref=[\"']#([^\"']+)[\"'][^>]*>.*?</a>)", re.S | re.I)
STYLE = """<style>
/* Added by to-pdf.sh to the copy it prints: a dot leader and the page of each contents entry */
.toc li { align-items: baseline; }
.toc li a { flex: 0 1 auto; }
.toc .toc-leader { flex: 1 1 24px; min-width: 24px; border-bottom: 1.5px dotted #9ca3af; }
.toc .toc-page { flex: none; min-width: 24px; color: var(--muted, #4b5563); text-align: right; font-variant-numeric: tabular-nums; }
</style>
"""


class Unreadable(Exception):
    pass


def contents(html):
    """The contents list of the report and the ids its entries link to, in order."""
    m = CONTENTS.search(html)
    if not m:
        raise Unreadable("the report has no contents list (<nav class=\"toc\">)")
    ids = [unquote(e.group(2)) for e in ENTRY.finditer(m.group(1))]
    if not ids:
        raise Unreadable("the contents list has no links to sections")
    return m, ids


def objects(pdf):
    """Every object of the PDF by number, including those packed in object streams."""
    found = {}
    for m in re.finditer(rb"(?<![0-9])(\d+)\s+(\d+)\s+obj\b(.*?)\bendobj", pdf, re.S):
        found.setdefault(int(m.group(1)), m.group(3))
    for body in list(found.values()):
        if b"/ObjStm" not in body:
            continue
        head = re.search(rb"/N\s+(\d+).*?/First\s+(\d+)|/First\s+(\d+).*?/N\s+(\d+)", body, re.S)
        start = re.search(rb"stream\r?\n", body)
        end = body.rfind(b"endstream")
        if not head or not start or end < 0:
            continue
        n = int(head.group(1) or head.group(4))
        first = int(head.group(2) or head.group(3))
        try:
            data = zlib.decompress(body[start.end():end].rstrip(b"\r\n"))
        except zlib.error:
            continue
        nums = [int(x) for x in data[:first].split()]
        pairs = list(zip(nums[0::2], nums[1::2]))[:n]
        for i, (num, off) in enumerate(pairs):
            stop = pairs[i + 1][1] if i + 1 < len(pairs) else len(data) - first
            found.setdefault(num, data[first + off:first + stop])
    return found


def ref(body, key):
    m = re.search(rb"/" + key + rb"\s+(\d+)\s+\d+\s+R", body)
    return int(m.group(1)) if m else None


def page_order(objs, node, seen=None):
    """The page objects under a node of the page tree, in order."""
    seen = seen if seen is not None else set()
    if node in seen or node not in objs:
        return []
    seen.add(node)
    body = objs[node]
    if re.search(rb"/Type\s*/Pages\b", body):
        kids = re.search(rb"/Kids\s*\[(.*?)\]", body, re.S)
        order = []
        for k in re.findall(rb"(\d+)\s+\d+\s+R", kids.group(1) if kids else b""):
            order += page_order(objs, int(k), seen)
        return order
    return [node]


def pdf_name(raw):
    return re.sub(rb"#([0-9A-Fa-f]{2})", lambda m: bytes([int(m.group(1), 16)]), raw).decode("utf-8", "replace")


def pdf_string(raw):
    s = re.sub(rb"\\([nrtbf()\\])", lambda m: {b"n": b"\n", b"r": b"\r", b"t": b"\t", b"b": b"\b", b"f": b"\f"}.get(m.group(1), m.group(1)), raw)
    return s.decode("utf-8", "replace")


def target(objs, value):
    """The page object a destination value points at."""
    value = value.strip()
    m = re.match(rb"\[\s*(\d+)\s+\d+\s+R", value)
    if m:
        return int(m.group(1))
    m = re.match(rb"(\d+)\s+\d+\s+R", value)
    if m and int(m.group(1)) in objs:
        inner = objs[int(m.group(1))].strip()
        d = re.search(rb"/D\s*(\[.*?\])", inner, re.S)
        return target(objs, d.group(1) if d else inner)
    return None


def destinations(pdf):
    """The page number of every named destination in the PDF."""
    objs = objects(pdf)
    catalog = next((b for b in objs.values() if re.search(rb"/Type\s*/Catalog\b", b)), None)
    if catalog is None:
        raise Unreadable("the PDF has no catalog")
    pages = page_order(objs, ref(catalog, b"Pages"))
    if not pages:
        raise Unreadable("the PDF has no pages")
    number = {p: i + 1 for i, p in enumerate(pages)}
    found = {}

    dests = ref(catalog, b"Dests")
    body = objs.get(dests) if dests else None
    if body is None:
        inline = re.search(rb"/Dests\s*<<(.*?)>>", catalog, re.S)
        body = inline.group(1) if inline else None
    if body:
        for m in re.finditer(rb"/([^\s/\[\]<>()]+)\s*(\[[^\]]*\]|\d+\s+\d+\s+R)", body):
            page = number.get(target(objs, m.group(2)))
            if page:
                found[pdf_name(m.group(1))] = page

    names = re.search(rb"/Names\s*<<(.*?)>>", catalog, re.S)
    names_ref = ref(catalog, b"Names")
    tree = ref(names.group(1), b"Dests") if names else (ref(objs.get(names_ref, b""), b"Dests") if names_ref else None)
    todo, seen = [tree] if tree else [], set()
    while todo:
        node = todo.pop()
        if node in seen or node not in objs:
            continue
        seen.add(node)
        body = objs[node]
        kids = re.search(rb"/Kids\s*\[(.*?)\]", body, re.S)
        if kids:
            todo += [int(k) for k in re.findall(rb"(\d+)\s+\d+\s+R", kids.group(1))]
        pairs = re.search(rb"/Names\s*\[(.*)\]", body, re.S)
        if pairs:
            for m in re.finditer(rb"\(((?:\\.|[^\\)])*)\)\s*(\[[^\]]*\]|\d+\s+\d+\s+R)", pairs.group(1)):
                page = number.get(target(objs, m.group(2)))
                if page:
                    found[pdf_string(m.group(1))] = page

    if not found:
        raise Unreadable("the browser wrote no page destinations into the PDF")
    return found


def pages(report, pdf_path):
    _, ids = contents(open(report, encoding="utf-8").read())
    try:
        pdf = open(pdf_path, "rb").read()
    except OSError as e:
        raise Unreadable(f"the PDF cannot be read ({e.strerror})")
    found = destinations(pdf)
    missing = [i for i in ids if i not in found]
    if missing:
        raise Unreadable("no page was found for " + ", ".join("#" + i for i in missing)
                         + "; the contents link to an id that no section has")
    for i in ids:
        print(f"{i} {found[i]}")


def copy(report, pages_file):
    html = open(report, encoding="utf-8").read()
    m, ids = contents(html)
    numbers = [line.rsplit(" ", 1)[1] for line in open(pages_file, encoding="utf-8").read().splitlines() if line]
    if len(numbers) != len(ids):
        raise Unreadable("the pages do not match the contents list")
    entries = iter(numbers)
    block = ENTRY.sub(lambda e: e.group(1) + '<span class="toc-leader"></span><span class="toc-page">' + next(entries) + "</span>", m.group(1))
    html = html[:m.start(1)] + block + html[m.end(1):]
    head = re.search(r"</head>", html, re.I)
    html = html[:head.start()] + STYLE + html[head.start():] if head else STYLE + html
    folder = os.path.dirname(os.path.abspath(report))
    try:
        fd, path = tempfile.mkstemp(prefix=".print-", suffix=".html", dir=folder)
    except OSError as e:
        raise Unreadable(f"the copy to print cannot be written next to the report ({e.strerror})")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(html)
    print(path)


def main():
    try:
        if len(sys.argv) == 4 and sys.argv[1] == "pages":
            pages(sys.argv[2], sys.argv[3])
        elif len(sys.argv) == 4 and sys.argv[1] == "copy":
            copy(sys.argv[2], sys.argv[3])
        else:
            print("usage: toc-pages.py pages <report.html> <report.pdf> | copy <report.html> <pages file>", file=sys.stderr)
            return 2
    except Unreadable as e:
        print(e)
        return 1
    except (OSError, UnicodeError, ValueError, StopIteration) as e:
        print(f"the pages could not be read ({type(e).__name__})")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
