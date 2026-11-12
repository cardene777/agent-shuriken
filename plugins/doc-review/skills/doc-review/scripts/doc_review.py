#!/usr/bin/env python3
"""Checks the form of Markdown documents and records a one-round review of them.

Commands:
  start PATH...                      Check headings, numbering, links, anchors, tables, and code fences,
                                     remember each file's content, and create a review folder.
  record REVIEW_DIR --findings FILE  Validate the reviewers' findings and the agent's decisions, and write
                                     the review record.

Exit codes: 0 done, 2 invalid findings (nothing written), 3 missing file or review folder.
Uses only the Python standard library and, when present, `git` to find the repository root.
"""
import argparse
import datetime
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import unicodedata
import urllib.parse

SCHEMA = 1
MARKDOWN = (".md", ".markdown", ".mdx")
SEVERITIES = ("critical", "major", "minor")
REVIEWERS = ("content", "form", "both")
STATUSES = ("fixed", "rejected")


# ---------- paths and state ----------

def tilde(path):
    """The path with the home folder written as `~`, so pasted output does not show the user name."""
    home = os.path.expanduser("~")
    return "~" + path[len(home):] if path == home or path.startswith(home + os.sep) else path


def repo_root(path):
    folder = path if os.path.isdir(path) else os.path.dirname(path)
    try:
        out = subprocess.run(["git", "-C", folder, "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return folder
    return os.path.realpath(out.stdout.strip()) if out.returncode == 0 and out.stdout.strip() else folder


def state_base():
    base = os.environ.get("DOC_REVIEW_HOME") or os.path.join(os.path.expanduser("~"), ".local", "share", "doc-review")
    os.makedirs(base, mode=0o700, exist_ok=True)
    os.chmod(base, 0o700)
    return base


def write_private(path, text):
    folder = os.path.dirname(path)
    fd, tmp = tempfile.mkstemp(dir=folder, prefix=".tmp-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def kind_of(rel):
    """A guess at the kind of document from its path, used to pick what the content reviewer checks."""
    p = rel.lower()
    name = os.path.basename(p)
    if re.search(r"(^|/)(adr|adrs|decisions)/", p) or re.match(r"(adr[-_ ]?\d+|\d{3,4}-[a-z])", name):
        return "adr"
    if re.match(r"(spec|specs|specification|requirements|prd)([-_. ]|$)", name) or re.search(r"(^|/)specs?/", p):
        return "spec"
    if name.startswith("architecture"):
        return "architecture"
    if name.startswith("design") or re.search(r"(^|/)design/", p):
        return "design"
    if name.startswith("readme"):
        return "readme"
    return "other"


# ---------- Markdown parsing ----------

FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})")
ATX = re.compile(r"^ {0,3}(#{1,6})(?:[ \t]+(.*?))?[ \t]*$")
SETEXT_1 = re.compile(r"^ {0,3}=+[ \t]*$")
SETEXT_2 = re.compile(r"^ {0,3}-+[ \t]*$")
NUMBERED = re.compile(r"^(\d+(?:\.\d+)*)[.)]?[ \t]+\S")
INLINE_LINK = re.compile(r"!?\[(?:[^\[\]]|\[[^\[\]]*\])*\]\(\s*(<[^>]*>|[^()\s]+(?:\([^()\s]*\))?)(?:\s+(?:\"[^\"]*\"|'[^']*'|\([^)]*\)))?\s*\)")
REF_DEF = re.compile(r"^ {0,3}\[(?!\^)[^\]]+\]:\s*(<[^>]*>|\S+)")
HTML_ATTR = re.compile(r"""\b(?:href|src)\s*=\s*["']([^"']+)["']""", re.I)
HTML_ANCHOR = re.compile(r"""<[a-z][^>]*\b(?:id|name)\s*=\s*["']([^"']+)["']""", re.I)
SEPARATOR = re.compile(r"^ {0,3}\|?[ \t]*:?-+:?[ \t]*(\|[ \t]*:?-+:?[ \t]*)*\|?[ \t]*$")
SCHEME = re.compile(r"^[a-z][a-z0-9+.-]*:", re.I)


def blank_code_spans(line):
    """The line with inline code spans replaced by spaces, so links and pipes inside them are ignored."""
    out, i = [], 0
    while i < len(line):
        if line[i] == "\\" and i + 1 < len(line):
            out.append(line[i:i + 2])
            i += 2
            continue
        if line[i] == "`":
            j = i
            while j < len(line) and line[j] == "`":
                j += 1
            ticks = line[i:j]
            end = line.find(ticks, j)
            while end != -1 and end + len(ticks) < len(line) and line[end + len(ticks)] == "`":
                end = line.find(ticks, end + len(ticks) + 1)
            if end == -1:
                out.append(ticks)
                i = j
                continue
            out.append(" " * (end + len(ticks) - i))
            i = end + len(ticks)
            continue
        out.append(line[i])
        i += 1
    return "".join(out)


def strip_inline(text):
    """Heading text as GitHub renders it: code, links, images, emphasis, and HTML tags reduced to their text."""
    text = re.sub(r"`+([^`]*)`+", r"\1", text)
    text = re.sub(r"!\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"\[([^\]]*)\]\[[^\]]*\]", r"\1", text)
    text = re.sub(r"<[^>]+>", "", text)
    return text


def slug(text):
    """GitHub's anchor for a heading: lower case, punctuation removed, spaces turned into hyphens."""
    text = strip_inline(text).strip().lower()
    text = "".join(ch for ch in text if ch.isalnum() or ch in "_- " or unicodedata.category(ch).startswith("M"))
    return text.replace(" ", "-")


def parse(lines):
    """Headings, fenced-code flags per line, and unclosed fences of one Markdown file."""
    in_code = [False] * len(lines)
    headings = []
    unclosed = []
    fence = None
    start = 0
    if lines and lines[0].strip() == "---":
        for k in range(1, len(lines)):
            if lines[k].strip() in ("---", "..."):
                for m in range(0, k + 1):
                    in_code[m] = True
                start = k + 1
                break
    prev_text = None
    for n in range(start, len(lines)):
        line = lines[n].rstrip("\n")
        m = FENCE.match(line)
        if fence:
            in_code[n] = True
            if m and m.group(1)[0] == fence[0] and len(m.group(1)) >= len(fence) and not line.strip()[len(m.group(1)):].strip():
                fence = None
            prev_text = None
            continue
        if m:
            fence = m.group(1)
            fence_line = n
            in_code[n] = True
            prev_text = None
            continue
        if line.startswith("    ") or line.startswith("\t"):
            if prev_text is None:
                in_code[n] = True
                continue
        a = ATX.match(line)
        if a:
            text = re.sub(r"(^|[ \t]+)#+$", "", (a.group(2) or "").strip()).strip()
            headings.append({"level": len(a.group(1)), "text": text, "line": n + 1})
            prev_text = None
            continue
        if prev_text is not None and SETEXT_1.match(line):
            headings.append({"level": 1, "text": prev_text[1], "line": prev_text[0] + 1})
            prev_text = None
            continue
        if prev_text is not None and SETEXT_2.match(line) and not re.match(r"^\s*([-*+>|]|\d+[.)])", prev_text[1]):
            headings.append({"level": 2, "text": prev_text[1], "line": prev_text[0] + 1})
            prev_text = None
            continue
        prev_text = (n, line.strip()) if line.strip() else None
    if fence:
        unclosed.append(fence_line + 1)
    headings.sort(key=lambda h: h["line"])
    return headings, in_code, unclosed


def anchors_of(lines, headings, in_code):
    seen = {}
    out = set()
    for h in headings:
        base = slug(h["text"])
        n = seen.get(base, 0)
        out.add(base if n == 0 else "%s-%d" % (base, n))
        seen[base] = n + 1
    for i, line in enumerate(lines):
        if not in_code[i]:
            out.update(a.lower() for a in HTML_ANCHOR.findall(line))
    return out


def split_cells(line):
    text = blank_code_spans(line.strip())
    cells, cur, i = [], [], 0
    while i < len(text):
        if text[i] == "\\" and i + 1 < len(text):
            cur.append(text[i:i + 2])
            i += 2
            continue
        if text[i] == "|":
            cells.append("".join(cur))
            cur = []
        else:
            cur.append(text[i])
        i += 1
    cells.append("".join(cur))
    if text.startswith("|"):
        cells = cells[1:]
    if text.endswith("|") and not text.endswith("\\|"):
        cells = cells[:-1]
    return cells


# ---------- checks ----------

class Doc:
    def __init__(self, path, root):
        self.path = path
        self.root = root
        self.rel = os.path.relpath(path, root)
        with open(path, encoding="utf-8", errors="replace") as f:
            self.lines = f.read().split("\n")
        self.headings, self.in_code, self.unclosed = parse(self.lines)
        self.anchors = anchors_of(self.lines, self.headings, self.in_code)


_cache = {}


def doc_for(path, root):
    key = os.path.realpath(path)
    if key not in _cache:
        _cache[key] = Doc(path, root)
    return _cache[key]


def heading_number(text):
    """The section number a heading starts with, such as (2, 1) for "2.1 Scope", or None.
    A bare number over 99 without a dot, such as a year, is not taken as a section number."""
    m = NUMBERED.match(strip_inline(text))
    if not m:
        return None
    number = tuple(int(x) for x in m.group(1).split("."))
    marked = text.strip()[len(m.group(1)):len(m.group(1)) + 1] in (".", ")")
    if len(number) == 1 and not marked and number[0] > 99:
        return None
    return number


def check_headings(doc, out):
    prev = None
    parents = []  # stack of (level, number tuple or None)
    last_child = {}  # (parent index, level) -> number tuple of the previous numbered sibling
    for idx, h in enumerate(doc.headings):
        if not h["text"]:
            out.append((doc.rel, h["line"], "heading", "empty heading"))
        if prev is not None and h["level"] > prev + 1:
            out.append((doc.rel, h["line"], "heading", "heading level jumps from H%d to H%d" % (prev, h["level"])))
        prev = h["level"]
        while parents and parents[-1][0] >= h["level"]:
            parents.pop()
        parent_key = parents[-1][2] if parents else -1
        number = heading_number(h["text"])
        if number:
            key = (parent_key, h["level"])
            before = last_child.get(key)
            if before is not None and len(before) == len(number):
                if number[:-1] == before[:-1] and number[-1] != before[-1] + 1:
                    out.append((doc.rel, h["line"], "numbering",
                                "heading %s follows %s" % (".".join(map(str, number)), ".".join(map(str, before)))))
            last_child[key] = number
            pnum = parents[-1][1] if parents else None
            if pnum and len(number) == len(pnum) + 1 and number[:-1] != pnum:
                out.append((doc.rel, h["line"], "numbering",
                            "heading %s sits under %s" % (".".join(map(str, number)), ".".join(map(str, pnum)))))
        parents.append((h["level"], number, idx))


def link_targets(doc):
    for i, line in enumerate(doc.lines):
        if doc.in_code[i]:
            continue
        text = blank_code_spans(line)
        for m in INLINE_LINK.finditer(text):
            yield i + 1, m.group(1).strip("<>")
        m = REF_DEF.match(text)
        if m:
            yield i + 1, m.group(1).strip("<>")
        for m in HTML_ATTR.finditer(text):
            yield i + 1, m.group(1)


def check_links(doc, out):
    for line, target in link_targets(doc):
        if not target or SCHEME.match(target) or target.startswith("//"):
            continue
        path, _, anchor = target.partition("#")
        path = urllib.parse.unquote(path.split("?")[0])
        anchor = urllib.parse.unquote(anchor)
        if not path:
            dest = doc.path
        elif path.startswith("/"):
            dest = os.path.join(doc.root, path.lstrip("/"))
        else:
            dest = os.path.normpath(os.path.join(os.path.dirname(doc.path), path))
        if not os.path.exists(dest):
            out.append((doc.rel, line, "link", "link target not found: %s" % target))
            continue
        if anchor and os.path.isfile(dest) and dest.lower().endswith(MARKDOWN):
            other = doc_for(dest, doc.root)
            if anchor.lower() not in other.anchors:
                where = "this file" if os.path.realpath(dest) == os.path.realpath(doc.path) else other.rel
                out.append((doc.rel, line, "anchor", "anchor #%s not found in %s" % (anchor, where)))


def check_tables(doc, out):
    n = 0
    lines = doc.lines
    while n < len(lines) - 1:
        if doc.in_code[n] or doc.in_code[n + 1] or "|" not in lines[n] or "|" not in lines[n + 1] \
                or not SEPARATOR.match(lines[n + 1]):
            n += 1
            continue
        header = len(split_cells(lines[n]))
        sep = len(split_cells(lines[n + 1]))
        if sep != header:
            out.append((doc.rel, n + 2, "table", "separator has %d cells, header has %d" % (sep, header)))
        k = n + 2
        while k < len(lines) and lines[k].strip() and "|" in lines[k] and not doc.in_code[k]:
            cells = len(split_cells(lines[k]))
            if cells != header:
                out.append((doc.rel, k + 1, "table", "row has %d cells, header has %d" % (cells, header)))
            k += 1
        n = k


def check(doc):
    out = []
    check_headings(doc, out)
    check_links(doc, out)
    check_tables(doc, out)
    for line in doc.unclosed:
        out.append((doc.rel, line, "fence", "code block opened here is never closed"))
    out.sort(key=lambda f: (f[0], f[1]))
    return out


# ---------- commands ----------

def cmd_start(args):
    paths = []
    for p in args.paths:
        full = os.path.realpath(os.path.expanduser(p))
        if not os.path.isfile(full):
            print("not a file: %s" % p, file=sys.stderr)
            return 3
        if full not in paths:
            paths.append(full)
    root = repo_root(paths[0])
    files, lint = [], []
    for full in paths:
        rel = os.path.relpath(full, root) if full.startswith(root + os.sep) else tilde(full)
        entry = {"path": full, "rel": rel, "sha256": sha256(full), "kind": kind_of(rel),
                 "markdown": full.lower().endswith(MARKDOWN)}
        files.append(entry)
        if entry["markdown"]:
            lint.extend(check(doc_for(full, root)))
    project = os.path.basename(root) or "root"
    tag = hashlib.sha1(root.encode("utf-8")).hexdigest()[:8]
    folder = os.path.join(state_base(), "%s-%s" % (project, tag))
    os.makedirs(folder, mode=0o700, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    review = os.path.join(folder, stamp)
    suffix = 1
    while os.path.exists(review):
        suffix += 1
        review = os.path.join(folder, "%s-%d" % (stamp, suffix))
    os.makedirs(review, mode=0o700)
    data = {"schema": SCHEMA, "started_at": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
            "root": root, "files": files,
            "checks": [{"file": f, "line": l, "kind": k, "message": m} for f, l, k, m in lint]}
    write_private(os.path.join(review, "start.json"), json.dumps(data, indent=1, ensure_ascii=False) + "\n")

    print("doc-review of %d file%s in %s" % (len(files), "" if len(files) == 1 else "s", tilde(root)))
    for f in files:
        note = "" if f["markdown"] else ", not Markdown, so the form checks were skipped"
        print("  %s  kind %s%s" % (f["rel"], f["kind"], note))
    print("\nForm checks: %d finding%s" % (len(lint), "" if len(lint) == 1 else "s"))
    for f, l, k, m in lint:
        print("  %s:%d  %s  %s" % (f, l, k, m))
    print("\nReview: %s" % tilde(review))
    return 0


def resolve_file(name, files):
    if not isinstance(name, str) or not name:
        return None
    full = os.path.realpath(os.path.expanduser(name))
    for f in files:
        if name in (f["rel"], os.path.normpath(f["rel"])) or os.path.normpath(name) == f["rel"] or full == f["path"]:
            return f
    base = [f for f in files if os.path.basename(f["rel"]) == name]
    return base[0] if len(base) == 1 else None


def cmd_record(args):
    review = os.path.realpath(os.path.expanduser(args.review))
    start_file = os.path.join(review, "start.json")
    if not os.path.isfile(start_file):
        print("not a review folder (no start.json): %s" % tilde(review), file=sys.stderr)
        return 3
    with open(start_file, encoding="utf-8") as f:
        start = json.load(f)
    if start.get("schema") != SCHEMA:
        print("start.json has schema %r; this version reads schema %d. Run start again." % (start.get("schema"), SCHEMA),
              file=sys.stderr)
        return 2
    try:
        with open(os.path.expanduser(args.findings), encoding="utf-8") as f:
            findings = json.load(f)
    except FileNotFoundError:
        print("findings file not found: %s" % args.findings, file=sys.stderr)
        return 3
    except json.JSONDecodeError as e:
        print("findings file is not valid JSON: %s" % e, file=sys.stderr)
        return 2
    if isinstance(findings, dict) and isinstance(findings.get("findings"), list):
        findings = findings["findings"]
    if not isinstance(findings, list):
        print("the findings file must hold a JSON list of findings", file=sys.stderr)
        return 2

    files = start["files"]
    errors, clean = [], []
    for i, item in enumerate(findings, 1):
        label = "finding %d" % i
        if not isinstance(item, dict):
            errors.append("%s is not an object" % label)
            continue
        sev = str(item.get("severity", "")).lower()
        rev = str(item.get("reviewer", "")).lower()
        status = str(item.get("status", "")).lower()
        if sev not in SEVERITIES:
            errors.append("%s: severity must be one of %s" % (label, ", ".join(SEVERITIES)))
        if rev not in REVIEWERS:
            errors.append("%s: reviewer must be one of %s" % (label, ", ".join(REVIEWERS)))
        for field in ("where", "problem", "fix"):
            if not str(item.get(field, "")).strip():
                errors.append("%s: %s is empty" % (label, field))
        target = resolve_file(item.get("file"), files)
        if target is None:
            errors.append("%s: file %r is not one of the reviewed files (%s)"
                          % (label, item.get("file"), ", ".join(f["rel"] for f in files)))
        if status not in STATUSES:
            errors.append("%s: status must be fixed or rejected" % label)
        elif status == "rejected" and not str(item.get("reason", "")).strip():
            errors.append("%s: a rejected finding needs a reason" % label)
        elif status == "fixed" and target is not None:
            now = sha256(target["path"]) if os.path.isfile(target["path"]) else None
            if now == target["sha256"]:
                errors.append("%s: marked fixed, but %s has not changed since start" % (label, target["rel"]))
        clean.append({"severity": sev, "reviewer": rev, "file": target["rel"] if target else item.get("file"),
                      "where": str(item.get("where", "")).strip(), "problem": str(item.get("problem", "")).strip(),
                      "fix": str(item.get("fix", "")).strip(), "status": status,
                      "reason": str(item.get("reason", "")).strip()})
    if errors:
        print("Nothing was recorded:", file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 2

    order = {s: i for i, s in enumerate(SEVERITIES)}
    clean.sort(key=lambda f: order[f["severity"]])
    recorded = datetime.datetime.now().astimezone().isoformat(timespec="seconds")
    out = {"schema": SCHEMA, "started_at": start["started_at"], "recorded_at": recorded,
           "files": [f["rel"] for f in files], "findings": clean}
    write_private(os.path.join(review, "findings.json"), json.dumps(out, indent=1, ensure_ascii=False) + "\n")
    write_private(os.path.join(review, "review.md"), render_md(start, clean, recorded))

    names = ", ".join(f["rel"] for f in files)
    if not clean:
        print("Recorded no findings for %s" % names)
    else:
        by_sev = ", ".join("%s %d" % (s, sum(1 for f in clean if f["severity"] == s)) for s in SEVERITIES)
        fixed = sum(1 for f in clean if f["status"] == "fixed")
        print("Recorded %d finding%s for %s: %s; fixed %d, not fixed %d"
              % (len(clean), "" if len(clean) == 1 else "s", names, by_sev, fixed, len(clean) - fixed))
        rejected = [f for f in clean if f["status"] == "rejected"]
        if rejected:
            print("Not fixed:")
            for f in rejected:
                print("  %-8s %-7s %s %s: %s" % (f["severity"], f["reviewer"], f["file"], f["where"], f["reason"]))
        critical = sum(1 for f in rejected if f["severity"] == "critical")
        if critical:
            print("Critical findings not fixed: %d. Ask the user how to proceed." % critical)
    print("Record: %s" % tilde(os.path.join(review, "review.md")))
    return 0


def render_md(start, findings, recorded):
    files = ", ".join("`%s`" % f["rel"] for f in start["files"])
    lines = ["# Review of %s" % files, "",
             "Started %s, recorded %s." % (start["started_at"], recorded), ""]
    lines += ["| Severity | Found | Fixed | Not fixed |", "|---|---|---|---|"]
    for s in SEVERITIES:
        found = [f for f in findings if f["severity"] == s]
        fixed = sum(1 for f in found if f["status"] == "fixed")
        lines.append("| %s | %d | %d | %d |" % (s.capitalize(), len(found), fixed, len(found) - fixed))
    lines += ["", "## Findings", ""]
    if not findings:
        lines.append("No findings.")
    for i, f in enumerate(findings, 1):
        result = "Fixed." if f["status"] == "fixed" else "Not fixed: %s" % f["reason"]
        who = "both reviewers" if f["reviewer"] == "both" else "%s reviewer" % f["reviewer"]
        lines.append("%d. %s, %s, `%s` %s. %s Suggested fix: %s %s"
                     % (i, f["severity"].capitalize(), who, f["file"], f["where"],
                        _sentence(f["problem"]), _sentence(f["fix"]), result))
    checks = start.get("checks") or []
    lines += ["", "## Form checks", ""]
    if not checks:
        lines.append("No findings.")
    for c in checks:
        lines.append("- `%s:%d` %s: %s" % (c["file"], c["line"], c["kind"], c["message"]))
    return "\n".join(lines) + "\n"


def _sentence(text):
    return text if text.endswith((".", "!", "?", "。")) else text + "."


def main():
    p = argparse.ArgumentParser(description="Check the form of documents and record a one-round review.")
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("start", help="check the documents and create a review folder")
    s.add_argument("paths", nargs="+")
    r = sub.add_parser("record", help="validate and record the findings and decisions")
    r.add_argument("review")
    r.add_argument("--findings", required=True)
    args = p.parse_args()
    return cmd_start(args) if args.cmd == "start" else cmd_record(args)


if __name__ == "__main__":
    sys.exit(main())
