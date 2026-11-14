#!/usr/bin/env python3
"""Lays out and checks public documentation written in one or more languages.

The pages live under one root folder, `docs` by default, with one folder per language and
the same page paths in every language folder:

    docs/_translation-map.json      the languages, the projects followed, the pages, and which
                                    translations are current
    docs/<code>/README.md           the index of that language
    docs/<code>/quickstart.md
    docs/<code>/concepts/README.md  and one page per concept
    docs/<code>/api/README.md       and one page per function, class, command, or option group
    docs/<code>/cookbook/README.md  and one page per task
    docs/<code>/faq.md

The first language in the map is the source; every other language is translated from it.

Commands (each takes --root, default `docs`):
    scaffold PLAN        Creates the folders, a starter page for every planned page in every
                         language, and the map. PLAN is a JSON file, or - for standard input,
                         and may list projects whose docs were followed, which the map keeps.
                         Never overwrites a file. --dry-run prints the files and writes nothing.
    add PATH --title T   Adds one page to every language and to the map.
    drop PATH            Removes one page from the map. Its files are left in place.
    translated PATH...   Records that each translation matches the current source page.
    check                Checks the pages against the map and against each other. Writes nothing.

Exit codes: 0 done, or no problems found; 1 problems found, or a page was not recorded;
2 bad input or an unreadable map; 3 the docs are already laid out (scaffold).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
from urllib.parse import unquote

MAP_NAME = "_translation-map.json"
# Version 2 added the projects followed. A version 1 map is read as following none and written
# back as version 2; a script that knows only version 1 refuses version 2 instead of dropping them.
MAP_VERSION = 2
READABLE_VERSIONS = (1, 2)
TODO = "docs-publish:todo"
PARTS = ("concepts", "api", "cookbook")
FIXED = ("README.md", "quickstart.md", "concepts/README.md", "api/README.md", "cookbook/README.md", "faq.md")
TOP_ORDER = ("README.md", "quickstart.md", "concepts", "api", "cookbook", "faq.md")
PART_TITLES = {"concepts": "Concepts", "api": "API reference", "cookbook": "Cookbook"}

SEGMENT = r"[A-Za-z0-9][A-Za-z0-9._-]*"
SLUG_RE = re.compile(r"(?:%s/)*%s" % (SEGMENT, SEGMENT))
PAGE_RE = re.compile(r"(?:%s)/(?:%s/)*%s\.md" % ("|".join(PARTS), SEGMENT, SEGMENT))
LANG_RE = re.compile(r"[a-z]{2,3}(?:-[A-Za-z0-9]{2,8})*")
LABEL_RE = re.compile(r"[^\[\]\r\n]{1,80}")
SHA_RE = re.compile(r"[0-9a-f]{64}")
URL_RE = re.compile(r"https://[^\s\[\]()<>]{1,300}")
ADOPTED_RE = re.compile(r"[^\r\n]{1,200}")

FENCE_RE = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")
HEADING_RE = re.compile(r"^ {0,3}(#{1,6})(?:[ \t]|$)")
CODE_SPAN_RE = re.compile(r"(`+).*?\1")
INLINE_LINK_RE = re.compile(r"\]\(\s*(<[^>\n]*>|[^)\s]+)(?:\s+(?:\"[^\"]*\"|'[^']*'|\([^)]*\)))?\s*\)")
REF_DEF_RE = re.compile(r"^ {0,3}\[(?!\^)[^\]]+\]:\s*(<[^>\n]*>|\S+)")
HTML_LINK_RE = re.compile(r"""(?:src|href)\s*=\s*["']([^"']+)["']""")
SCHEME_RE = re.compile(r"[A-Za-z][A-Za-z0-9+.-]*:")

KIND_ORDER = ("missing", "unmapped", "todo", "content", "structure", "untranslated", "stale",
              "link", "crosslink", "switch", "orphan")


class Usage(Exception):
    """Bad input. The command prints the message and exits 2."""


# ------------------------------------------------------------------ pages and languages

def valid_page(path):
    return path in FIXED or bool(PAGE_RE.fullmatch(path))


def order_key(path):
    """Index first, then Quickstart, Concepts, API, Cookbook, FAQ; each part's README first."""
    top = path.split("/", 1)[0]
    rank = TOP_ORDER.index(path) if path in TOP_ORDER else TOP_ORDER.index(top)
    return (rank, path != top + "/README.md", path)


def part_of(path):
    top = path.split("/", 1)[0]
    return top if top in PARTS and "/" in path else None


def is_index(path):
    return os.path.basename(path) == "README.md"


def check_languages(value, errors, where="languages"):
    if not isinstance(value, list) or not value:
        errors.append('%s: list the languages, source first, as {"code": "en", "name": "English"}' % where)
        return []
    seen, out = set(), []
    for i, item in enumerate(value):
        code = item.get("code") if isinstance(item, dict) else None
        name = item.get("name") if isinstance(item, dict) else None
        if not isinstance(code, str) or not LANG_RE.fullmatch(code):
            errors.append("%s[%d]: code must be a language tag such as en, ja, or pt-BR" % (where, i))
        elif code in seen:
            errors.append("%s[%d]: %s is listed twice" % (where, i, code))
        elif not isinstance(name, str) or not LABEL_RE.fullmatch(name):
            errors.append("%s[%d]: name must be the language's own name on one line, such as English" % (where, i))
        else:
            seen.add(code)
            out.append({"code": code, "name": name})
    return out


def valid_title(title):
    return isinstance(title, str) and bool(title.strip()) and bool(LABEL_RE.fullmatch(title))


def check_follow(value, errors):
    """The projects whose docs were followed, as [{"name", "url", "adopted"}]. Absent means none."""
    if value is None:
        return []
    if not isinstance(value, list):
        errors.append('follow: list the projects you followed as {"name": "...", "url": "https://...", "adopted": "..."}')
        return []
    out = []
    for i, item in enumerate(value):
        if not isinstance(item, dict):
            errors.append('follow[%d]: list each project as {"name": "...", "url": "https://...", "adopted": "..."}' % i)
            continue
        name, url, adopted = item.get("name"), item.get("url"), item.get("adopted")
        bad = False
        if not valid_title(name):
            errors.append("follow[%d]: give the project's name, up to 80 characters on one line, without [ or ]" % i)
            bad = True
        if not isinstance(url, str) or not URL_RE.fullmatch(url):
            errors.append("follow[%d]: url must start with https:// and have no spaces" % i)
            bad = True
        if not isinstance(adopted, str) or not adopted.strip() or not ADOPTED_RE.fullmatch(adopted):
            errors.append("follow[%d]: adopted must say which parts of the project's structure you followed, "
                          "up to 200 characters on one line" % i)
            bad = True
        if not bad:
            out.append({"name": name.strip(), "url": url, "adopted": adopted.strip()})
    return out


def read_plan(source):
    """Return (project, languages, {page path: title}, projects followed) from a plan, or raise Usage."""
    try:
        if source == "-":
            text = sys.stdin.read()
        else:
            with open(source, encoding="utf-8") as f:
                text = f.read()
        plan = json.loads(text)
    except (OSError, ValueError) as error:
        raise Usage("Cannot read the plan: %s" % error)
    if not isinstance(plan, dict):
        raise Usage("The plan must be a JSON object")
    errors = []
    project = plan.get("project")
    if not valid_title(project):
        errors.append("project: give the project's name, up to 80 characters on one line")
    languages = check_languages(plan.get("languages"), errors)
    follow = check_follow(plan.get("follow"), errors)
    titles = {}
    for part in PARTS:
        items = plan.get(part)
        if not isinstance(items, list) or not items:
            errors.append('%s: list at least one page as {"slug": "...", "title": "..."}' % part)
            continue
        for i, item in enumerate(items):
            where = "%s[%d]" % (part, i)
            slug = item.get("slug") if isinstance(item, dict) else None
            title = item.get("title") if isinstance(item, dict) else None
            if isinstance(slug, str) and slug.endswith(".md"):
                slug = slug[:-3]
            if not isinstance(slug, str) or not SLUG_RE.fullmatch(slug) or slug == "README":
                errors.append("%s: slug must use letters, digits, '.', '_', and '-', such as getting-paid, "
                              "and not be README" % where)
                continue
            path = "%s/%s.md" % (part, slug)
            if path in titles:
                errors.append("%s: %s is listed twice" % (where, path))
            elif not valid_title(title):
                errors.append("%s: title must be up to 80 characters on one line, without [ or ]" % where)
            else:
                titles[path] = title.strip()
    if errors:
        raise Usage("The plan has problems:\n" + "\n".join("  " + e for e in errors))
    return project.strip(), languages, titles, follow


# ------------------------------------------------------------------ the map

def map_path(root):
    return os.path.join(root, MAP_NAME)


def load_map(root):
    path = map_path(root)
    if not os.path.isfile(path):
        raise Usage("No %s in %s. Run scaffold first, or pass --root with the docs folder" % (MAP_NAME, root))
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError) as error:
        raise Usage("Cannot read %s: %s" % (path, error))
    if not isinstance(data, dict) or data.get("version") not in READABLE_VERSIONS:
        version = data.get("version") if isinstance(data, dict) else None
        raise Usage("%s has version %r; this script reads versions %s only"
                    % (path, version, " and ".join(map(str, READABLE_VERSIONS))))
    errors = []
    languages = check_languages(data.get("languages"), errors, "languages in the map")
    follow = check_follow(data.get("follow"), errors)
    codes = {l["code"] for l in languages}
    source = languages[0]["code"] if languages else None
    pages, seen = [], set()
    raw_pages = data.get("pages")
    if not isinstance(raw_pages, list):
        errors.append("pages in the map must be a list")
        raw_pages = []
    for i, page in enumerate(raw_pages):
        p = page.get("path") if isinstance(page, dict) else None
        shas = page.get("source_sha256", {}) if isinstance(page, dict) else None
        if not isinstance(p, str) or not valid_page(p):
            errors.append("pages[%d]: %r is not a page path this layout allows" % (i, p))
        elif p in seen:
            errors.append("pages[%d]: %s is listed twice" % (i, p))
        elif not isinstance(shas, dict) or any(
                k not in codes or k == source or not isinstance(v, str) or not SHA_RE.fullmatch(v)
                for k, v in shas.items()):
            errors.append("pages[%d]: source_sha256 must map translation codes to sha256 values" % i)
        else:
            seen.add(p)
            pages.append({"path": p, "source_sha256": dict(shas)})
    missing_fixed = [p for p in FIXED if p not in seen]
    if missing_fixed and not errors:
        errors.append("the map has lost the fixed pages %s" % ", ".join(missing_fixed))
    if errors:
        raise Usage("%s has problems:\n%s" % (path, "\n".join("  " + e for e in errors)))
    pages.sort(key=lambda page: order_key(page["path"]))
    return {"version": MAP_VERSION, "languages": languages, "follow": follow, "pages": pages}


def write_map(root, data):
    """Write the map in one step, so a failed write never leaves half a file."""
    data["pages"].sort(key=lambda page: order_key(page["path"]))
    text = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    fd, tmp = tempfile.mkstemp(dir=root, prefix=".translation-map.", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        os.chmod(tmp, 0o644)
        os.replace(tmp, map_path(root))
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)


# ------------------------------------------------------------------ starter pages

def todo(text):
    return "<!-- %s %s -->" % (TODO, text)


def switch_line(languages, code, path):
    """This language's name, and a link to the same page in every other language."""
    up = "../" * (path.count("/") + 1)
    return " · ".join(l["name"] if l["code"] == code else "[%s](%s%s/%s)" % (l["name"], up, l["code"], path)
                      for l in languages)


def header(title, languages, code, path):
    lines = ["# " + title, ""]
    if len(languages) > 1:
        lines += [switch_line(languages, code, path), ""]
    return lines


def source_stub(path, title, languages, children=()):
    """The starter page in the source language: the outline, with a to-do note per section."""
    lines = header(title, languages, languages[0]["code"], path)

    def section(heading, note, extra=()):
        lines.extend(["## " + heading, "", todo(note), ""])
        if extra:
            lines.extend(list(extra) + [""])

    back = "../" * (path.count("/") - 1) + "README.md"
    part = part_of(path)
    if path == "README.md":
        lines += [todo("One paragraph: what the project is, who it is for, and where to start."), ""]
        for heading, link in (("Get started", "quickstart.md"), ("Concepts", "concepts/README.md"),
                              ("API reference", "api/README.md"), ("Cookbook", "cookbook/README.md"),
                              ("FAQ", "faq.md")):
            label = "Quickstart" if link == "quickstart.md" else heading
            lines += ["## " + heading, "", "- [%s](%s)" % (label, link), ""]
    elif path == "quickstart.md":
        lines += [todo("One sentence: what the reader has running at the end, in about five minutes."), ""]
        section("Requirements", "The runtimes and tools, each with its minimum version.")
        section("Install", "The install command in a code block.")
        section("First run", "The smallest complete example, the command that runs it, and the output it prints.")
        lines += ["## Next steps", "", "- [Concepts](concepts/README.md)", "- [Cookbook](cookbook/README.md)", ""]
    elif path == "faq.md":
        lines += [todo("One ## heading per question, a one-to-three-sentence answer, and a link to the page "
                       "with the details. Quote error messages exactly, so people find them by searching."), ""]
    elif is_index(path):
        lines += [todo("One paragraph: what these pages cover and the order to read them in."), ""]
        if children:
            lines += ["- [%s](%s)" % (t, rel) for rel, t in children] + [""]
    elif part == "concepts":
        lines += [todo("One or two sentences that sum up the idea."), ""]
        section("Why", "The problem this idea solves, in the reader's terms.")
        section("How it works", "A Mermaid diagram of the parts or the flow, then the explanation.")
        section("Example", "A short, complete code example.")
        section("Related", "Links to related concepts and API pages.", ["- [Concepts](%s)" % back])
    elif part == "api":
        lines += [todo("One sentence on what it does, and when to use something else instead."), ""]
        section("Signature", "The signature exactly as the code declares it, in a code block.")
        section("Parameters", "A table with Name, Type, Required, Default, and Description.")
        section("Returns", "What it returns, and when.")
        section("Errors", "Each error it raises or returns, and the condition.")
        section("Example", "A complete example that runs as written.")
        section("Related", "Links to related API pages and recipes.", ["- [API reference](%s)" % back])
    else:
        lines += [todo("One or two sentences: the task and the result."), ""]
        section("Before you start", "What the reader needs installed or set up.")
        section("Steps", "Numbered steps, each with its code.")
        section("Check the result", "The command that shows it worked, and the output it prints.")
        section("Related", "Links to the API pages and recipes this one uses.", ["- [Cookbook](%s)" % back])
    return "\n".join(lines).rstrip("\n") + "\n"


def translation_stub(path, title, languages, code):
    name = next(l["name"] for l in languages if l["code"] == code)
    lines = header(title, languages, code, path)
    lines += [todo("Translate %s/%s into %s here once it is written, with the same headings, code blocks, "
                   "and tables." % (languages[0]["code"], path, name)), ""]
    return "\n".join(lines).rstrip("\n") + "\n"


def write_new(path, text):
    """Create a file that does not exist yet. Returns False, and writes nothing, when it exists."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    try:
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644)
    except FileExistsError:
        return False
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(text)
    return True


# ------------------------------------------------------------------ reading pages

def parse(text):
    """The parts of a page the checks compare. Code blocks and code spans are not read for links."""
    info = {"headings": [], "fences": [], "tables": 0, "links": [], "todo": 0}
    fence = None
    for number, line in enumerate(text.splitlines(), 1):
        m = FENCE_RE.match(line)
        if fence:
            if m and m.group(1)[0] == fence[0] and len(m.group(1)) >= fence[1] and not m.group(2).strip():
                fence = None
            continue
        if m and not (m.group(1)[0] == "`" and "`" in m.group(2)):
            fence = (m.group(1)[0], len(m.group(1)))
            words = m.group(2).split()
            info["fences"].append(words[0].lower() if words else "")
            continue
        h = HEADING_RE.match(line)
        if h:
            info["headings"].append(len(h.group(1)))
        if line.lstrip().startswith("|"):
            info["tables"] += 1
        info["todo"] += line.count(TODO)
        bare = CODE_SPAN_RE.sub("", line)
        for regex in (INLINE_LINK_RE, REF_DEF_RE, HTML_LINK_RE):
            for target in regex.findall(bare):
                info["links"].append((number, target))
    return info


def structure_diff(a, b):
    """Return the ways two pages differ in structure, as (what, a, b) with printable values."""
    out = []
    if a["headings"] != b["headings"]:
        out.append(("headings", " ".join(map(str, a["headings"])) or "none",
                    " ".join(map(str, b["headings"])) or "none"))
    if a["fences"] != b["fences"]:
        show = lambda fences: " ".join(f or "plain" for f in fences) or "none"
        out.append(("code blocks", show(a["fences"]), show(b["fences"])))
    if a["tables"] != b["tables"]:
        out.append(("table rows", str(a["tables"]), str(b["tables"])))
    return out


def describe_diff(diff, a_name, b_name):
    return "; ".join("%s differ (%s: %s, %s: %s)" % (what, a_name, x, b_name, y) for what, x, y in diff)


def read_page(file):
    """Return (bytes, text) of a page, or None when it is missing or not UTF-8."""
    try:
        with open(file, "rb") as f:
            data = f.read()
        return data, data.decode("utf-8")
    except (OSError, UnicodeDecodeError):
        return None


def list_pages(folder):
    out = []
    for base, dirs, files in os.walk(folder):
        dirs.sort()
        for name in sorted(files):
            if name.endswith(".md"):
                out.append(os.path.relpath(os.path.join(base, name), folder).replace(os.sep, "/"))
    return out


def link_target(raw):
    """Return (kind, path): kind is relative, absolute, or skip (web addresses and in-page anchors)."""
    t = raw.strip()
    if t.startswith("<") and t.endswith(">"):
        t = t[1:-1].strip()
    if not t or t.startswith("#") or t.startswith("//") or SCHEME_RE.match(t):
        return "skip", None
    if t.startswith("/"):
        return "absolute", None
    t = re.split(r"[#?]", t, maxsplit=1)[0]
    return ("relative", unquote(t)) if t else ("skip", None)


class Disk:
    """Answers whether a path exists with exactly this letter case, since links are case-sensitive on the web."""

    def __init__(self):
        self.listings = {}

    def names(self, folder):
        if folder not in self.listings:
            try:
                self.listings[folder] = set(os.listdir(folder))
            except OSError:
                self.listings[folder] = None
        return self.listings[folder]

    def exact(self, path):
        head = path
        while True:
            parent, name = os.path.split(head)
            if not name or parent == head:
                return True
            names = self.names(parent)
            if names is not None and name not in names:
                return False
            head = parent


# ------------------------------------------------------------------ commands

def cmd_scaffold(args):
    root = args.root
    project, languages, titles, follow = read_plan(args.plan)
    if os.path.exists(map_path(root)):
        print("%s already exists, so the docs are already laid out. Use add for new pages." % map_path(root),
              file=sys.stderr)
        return 3
    titles.update({"README.md": "%s documentation" % project, "quickstart.md": "Quickstart", "faq.md": "FAQ"})
    for part in PARTS:
        titles["%s/README.md" % part] = PART_TITLES[part]
    paths = sorted(titles, key=order_key)
    written = kept = 0
    rows = [("new", map_path(root))]
    for i, lang in enumerate(languages):
        for path in paths:
            file = os.path.join(root, lang["code"], path)
            if i == 0:
                part = part_of(path)
                children = [(p[len(part) + 1:], titles[p]) for p in paths
                            if part and path == part + "/README.md" and part_of(p) == part and p != path]
                text = source_stub(path, titles[path], languages, children)
            else:
                text = translation_stub(path, titles[path], languages, lang["code"])
            fresh = not os.path.exists(file) if args.dry_run else write_new(file, text)
            rows.append(("new" if fresh else "kept", file + ("" if fresh else " (it already exists)")))
            written, kept = written + fresh, kept + (not fresh)
    if not args.dry_run:
        os.makedirs(root, exist_ok=True)
        write_map(root, {"version": MAP_VERSION, "languages": languages, "follow": follow,
                         "pages": [{"path": p, "source_sha256": {}} for p in paths]})
    for state, file in rows:
        print("%-5s %s" % (state, file))
    for f in follow:
        print("follow %s (%s): %s" % (f["name"], f["url"], f["adopted"]))
    codes = [l["code"] for l in languages]
    if args.dry_run:
        print("Would write %d pages and the map, and keep %d. Nothing was written (dry run)." % (written, kept))
    else:
        then = ", then translate them into %s" % ", ".join(codes[1:]) if len(codes) > 1 else ""
        print("Wrote %d pages and the map, and kept %d. Write the %s pages%s, then run check."
              % (written, kept, codes[0], then))
    return 0


def page_arg(raw, root, codes):
    """Accept quickstart.md, ja/quickstart.md, or docs/ja/quickstart.md. Returns (code or None, path)."""
    p = raw.replace(os.sep, "/")
    while p.startswith("./"):
        p = p[2:]
    prefix = os.path.normpath(root).replace(os.sep, "/").rstrip("/") + "/"
    if p.startswith(prefix):
        p = p[len(prefix):]
    first, _, rest = p.partition("/")
    if rest and first in codes:
        return first, rest
    return None, p


def cmd_add(args):
    root = args.root
    data = load_map(root)
    languages = data["languages"]
    _, path = page_arg(args.path, root, [l["code"] for l in languages])
    if not path.endswith(".md"):
        path += ".md"
    if path in FIXED or not PAGE_RE.fullmatch(path):
        raise Usage("%s is not a page you can add. New pages go under concepts/, api/, or cookbook/, "
                    "such as concepts/caching.md" % path)
    if any(page["path"] == path for page in data["pages"]):
        raise Usage("%s is already in the map" % path)
    if not valid_title(args.title):
        raise Usage("--title must be up to 80 characters on one line, without [ or ]")
    for i, lang in enumerate(languages):
        file = os.path.join(root, lang["code"], path)
        if i == 0:
            text = source_stub(path, args.title.strip(), languages)
        else:
            text = translation_stub(path, args.title.strip(), languages, lang["code"])
        fresh = write_new(file, text)
        print("%-5s %s" % ("new" if fresh else "kept", file + ("" if fresh else " (it already exists)")))
    data["pages"].append({"path": path, "source_sha256": {}})
    write_map(root, data)
    print("Added %s to the map. Link it from %s/README.md in every language." % (path, part_of(path)))
    return 0


def cmd_drop(args):
    root = args.root
    data = load_map(root)
    codes = [l["code"] for l in data["languages"]]
    _, path = page_arg(args.path, root, codes)
    if path in FIXED:
        raise Usage("%s is one of the five parts, so it stays in the map" % path)
    if not any(page["path"] == path for page in data["pages"]):
        raise Usage("%s is not in the map" % path)
    data["pages"] = [page for page in data["pages"] if page["path"] != path]
    write_map(root, data)
    print("Removed %s from the map. No file was deleted." % path)
    left = [os.path.join(root, code, path) for code in codes if os.path.exists(os.path.join(root, code, path))]
    if left:
        print("These files are still there. Delete them only after the user agrees, and remove the links to them:")
        for file in left:
            print("  " + file)
    return 0


def cmd_translated(args):
    root = args.root
    data = load_map(root)
    codes = [l["code"] for l in data["languages"]]
    source = codes[0]
    if len(codes) == 1:
        raise Usage("The docs have one language, %s, so there is nothing to record" % source)
    pages = {page["path"]: page for page in data["pages"]}
    recorded = refused = 0
    for raw in args.paths:
        lang, path = page_arg(raw, root, codes)
        if lang and args.lang and lang != args.lang:
            raise Usage("%s is a %s page, but --lang is %s" % (raw, lang, args.lang))
        lang = lang or args.lang or (codes[1] if len(codes) == 2 else None)
        if not lang:
            raise Usage("Name the language of %s with --lang, one of %s" % (raw, ", ".join(codes[1:])))
        if lang not in codes:
            raise Usage("%s is not a language in the map, which has %s" % (lang, ", ".join(codes)))
        if lang == source:
            raise Usage("%s is the source language; record its translations, such as %s/%s"
                        % (source, codes[1], path))
        reason = None
        if path not in pages:
            reason = "it is not in the map"
        else:
            src = read_page(os.path.join(root, source, path))
            dst = read_page(os.path.join(root, lang, path))
            if src is None:
                reason = "%s/%s is missing or not UTF-8" % (source, path)
            elif dst is None:
                reason = "it is missing or not UTF-8"
            else:
                a, b = parse(src[1]), parse(dst[1])
                diff = structure_diff(a, b)
                if a["todo"]:
                    reason = "%s/%s still has to-do notes, so write it first" % (source, path)
                elif b["todo"]:
                    reason = "it still has to-do notes"
                elif diff:
                    reason = describe_diff(diff, source, lang)
                else:
                    pages[path]["source_sha256"][lang] = hashlib.sha256(src[0]).hexdigest()
        if reason:
            refused += 1
            print("not recorded  %s/%s: %s" % (lang, path, reason))
        else:
            recorded += 1
            print("recorded      %s/%s is a translation of %s/%s as it is now" % (lang, path, source, path))
    if recorded:
        write_map(root, data)
    return 1 if refused else 0


def cmd_check(args):
    root = args.root
    data = load_map(root)
    languages = [l["code"] for l in data["languages"]]
    source = languages[0]
    pages = {page["path"]: page for page in data["pages"]}
    root_abs = os.path.abspath(root)
    problems = []

    def add(kind, message):
        problems.append((kind, message))

    parsed, sha = {}, {}
    for lang in languages:
        for path in pages:
            page = read_page(os.path.join(root, lang, path))
            if page is None:
                add("missing", "%s/%s is in the map but is missing or not UTF-8" % (lang, path))
                continue
            parsed[(lang, path)] = parse(page[1])
            sha[(lang, path)] = hashlib.sha256(page[0]).hexdigest()
        for path in list_pages(os.path.join(root, lang)):
            if path not in pages:
                add("unmapped", "%s/%s is not in the map; add it, or delete it once the user agrees" % (lang, path))

    for (lang, path), info in parsed.items():
        if info["todo"]:
            add("todo", "%s/%s has %d to-do note%s left" % (lang, path, info["todo"], "" if info["todo"] == 1 else "s"))

    for path in pages:
        info = parsed.get((source, path))
        if not info or info["todo"] or is_index(path):
            continue
        code = [f for f in info["fences"] if f != "mermaid"]
        if part_of(path) == "concepts" and "mermaid" not in info["fences"]:
            add("content", "%s/%s has no Mermaid diagram (a mermaid code block)" % (source, path))
        if (part_of(path) in ("api", "cookbook") or path == "quickstart.md") and not code:
            add("content", "%s/%s has no code example" % (source, path))

    for lang in languages[1:]:
        for path, page in pages.items():
            a, b = parsed.get((source, path)), parsed.get((lang, path))
            if not a or not b or a["todo"] or b["todo"]:
                continue
            diff = structure_diff(a, b)
            if diff:
                add("structure", "%s/%s: %s" % (lang, path, describe_diff(diff, source, lang)))
            recorded = page["source_sha256"].get(lang)
            if not recorded:
                add("untranslated", "%s/%s is not recorded as a translation of %s/%s; compare them, "
                    "then run translated" % (lang, path, source, path))
            elif recorded != sha[(source, path)]:
                add("stale", "%s/%s changed after %s/%s was translated from it" % (source, path, lang, path))

    disk = Disk()
    checked = broken = absolute = 0
    edges = {}
    for (lang, path), info in parsed.items():
        here = os.path.dirname(os.path.join(root_abs, lang, path))
        lang_root = os.path.join(root_abs, lang)
        switched = set()
        for number, raw in info["links"]:
            kind, target = link_target(raw)
            if kind == "absolute":
                absolute += 1
                continue
            if kind == "skip":
                continue
            checked += 1
            resolved = os.path.normpath(os.path.join(here, target))
            where = "%s/%s:%d: %s" % (lang, path, number, raw)
            if not os.path.exists(resolved):
                broken += 1
                add("link", "%s does not exist" % where)
                continue
            if not disk.exact(resolved):
                broken += 1
                add("link", "%s differs in letter case from the file on disk, so it breaks on GitHub "
                    "and most web servers" % where)
                continue
            first = os.path.relpath(resolved, root_abs).split(os.sep, 1)[0]
            if first in languages and first != lang:
                if resolved == os.path.normpath(os.path.join(root_abs, first, path)):
                    switched.add(first)
                else:
                    add("crosslink", "%s points into %s/; link the page in %s/ instead" % (where, first, lang))
            elif first == lang:
                if os.path.isdir(resolved):
                    resolved = os.path.join(resolved, "README.md")
                edges.setdefault((lang, path), set()).add(os.path.relpath(resolved, lang_root).replace(os.sep, "/"))
        for other in languages:
            if other != lang and other not in switched:
                add("switch", "%s/%s has no link to %s/%s; put the language switch under the title"
                    % (lang, path, other, path))

    # Starter pages do not link everything yet, so a language is checked for orphans once it has no to-do notes.
    for lang in languages:
        if (lang, "README.md") not in parsed or any(parsed[(l, p)]["todo"] for l, p in parsed if l == lang):
            continue
        seen, queue = {"README.md"}, ["README.md"]
        while queue:
            for nxt in edges.get((lang, queue.pop()), ()):
                if nxt not in seen:
                    seen.add(nxt)
                    queue.append(nxt)
        for path in pages:
            if (lang, path) in parsed and path not in seen:
                add("orphan", "%s/%s cannot be reached by following links from %s/README.md" % (lang, path, lang))

    if len(languages) > 1:
        print("%s: %d pages in %s, translated from %s" % (root, len(pages), ", ".join(languages), source))
    else:
        print("%s: %d pages in %s" % (root, len(pages), source))
    if data["follow"]:
        print("Follows: %s" % ", ".join("%s (%s)" % (f["name"], f["url"]) for f in data["follow"]))
    if problems:
        print()
        for kind, message in sorted(problems, key=lambda p: (KIND_ORDER.index(p[0]), p[1])):
            print("%-12s %s" % (kind, message))
        print()
    links = "Links: %d checked, %d broken" % (checked, broken)
    if absolute:
        links += ", %d not checked because they start with /" % absolute
    if problems:
        print("%d problem%s. %s." % (len(problems), "" if len(problems) == 1 else "s", links))
        return 1
    print("No problems. %s." % links)
    return 0


def main(argv):
    ap = argparse.ArgumentParser(description="Lay out and check documentation written in one or more languages.")
    sub = ap.add_subparsers(dest="command")

    def command(name, help_text):
        p = sub.add_parser(name, help=help_text)
        p.add_argument("--root", default="docs", help="the docs folder that holds the map (default: docs)")
        return p

    p = command("scaffold", "create the folders, the starter pages, and the map from a plan")
    p.add_argument("plan", help="the plan as a JSON file, or - for standard input")
    p.add_argument("--dry-run", action="store_true", help="print the files it would write, and write nothing")
    p = command("add", "add a page to every language and to the map")
    p.add_argument("path", help="the page path, such as concepts/caching.md")
    p.add_argument("--title", required=True, help="the page title in the source language")
    p = command("drop", "remove a page from the map, leaving its files")
    p.add_argument("path", help="the page path, such as concepts/caching.md")
    p = command("translated", "record that translations match the current source pages")
    p.add_argument("paths", nargs="+", help="page paths, such as quickstart.md or ja/quickstart.md")
    p.add_argument("--lang", help="the translation's language code, when the map has more than one")
    command("check", "check the pages against the map and each other")
    args = ap.parse_args(argv)
    if not args.command:
        ap.print_help(sys.stderr)
        return 2
    handler = {"scaffold": cmd_scaffold, "add": cmd_add, "drop": cmd_drop,
               "translated": cmd_translated, "check": cmd_check}[args.command]
    try:
        return handler(args)
    except Usage as error:
        print(error, file=sys.stderr)
        return 2
    except OSError as error:
        print("Cannot write %s: %s" % (error.filename or "a file", error.strerror or error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
