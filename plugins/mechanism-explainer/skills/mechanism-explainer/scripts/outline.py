#!/usr/bin/env python3
"""Draw the outline of an explainer as one light HTML page that the person reads before anything is written.

Usage: outline.py <outline.json> [-o <page.html>]

The outline is a JSON object.

    {
      "lang": "en",
      "title": "<short noun phrase>",
      "point": "<one sentence>",
      "overview": [{"name": "...", "point": "..."}],
      "chapters": [
        {"name": "...", "point": "...", "pages": [
          {"name": "...", "point": "...", "sections": [{"name": "...", "point": "..."}]}
        ]}
      ]
    }

`lang` is `en` or `ja` and picks the words of the button. `overview` and `sections` may be empty, and every
chapter holds at least one page. The page is written next to the outline as `<name>.html` unless `-o` names
another path.

The script refuses an outline that breaks the rules of references/outline-design.md and writes no page: a
name that has a question mark or starts with a number, an empty point, a point written twice, or a line that
starts with a bullet. Every problem is printed on standard error with where it is.

Exit codes: 0 the page was written, 1 the outline was refused, 2 usage error (a missing or unreadable file).
"""

import html
import json
import re
import sys
from pathlib import Path
from typing import NoReturn

HERE = Path(__file__).resolve().parent
TEMPLATE = HERE.parent / "templates" / "outline.html"
UI = HERE.parent / "templates" / "ui.json"

QUESTION = re.compile(r"[?\uff1f]\s*$")
NUMBERED = re.compile(r"^\s*[0-9\uff10-\uff19]+(?:[-.\uff0e)\uff09\u3001:\uff1a]|\s)")
# A dash, a star, or a plus followed by a space, a bullet sign, or a number with a dot or a bracket followed by a space.
BULLET = re.compile(r"^\s*(?:[-*+\u2013\u2014]\s|[\u2022\u2023\u25aa\u25cf\u25e6\u30fb]|[0-9]+[.)]\s)")


def usage(message) -> NoReturn:
    print("outline: " + message, file=sys.stderr)
    print("usage: outline.py <outline.json> [-o <page.html>]", file=sys.stderr)
    sys.exit(2)


def check(outline):
    """Return the problems of the outline, one line each, in the order they appear."""
    problems = []
    seen = {}

    def name_of(node, where):
        name = node.get("name") if where != "title" else node.get("title")
        field = where + (".name" if where != "title" else "")
        if not isinstance(name, str) or not name.strip():
            problems.append("%s: has no name; write a short noun heading" % field)
            return
        if "\n" in name:
            problems.append("%s: breaks the line; write the name on one line" % field)
        if QUESTION.search(name) or NUMBERED.match(name):
            problems.append("%s %s: has a question mark or number; write a short noun heading without either" % (field, json.dumps(name, ensure_ascii=False)))
        elif BULLET.match(name):
            problems.append("%s %s: starts with a bullet; write a short noun heading" % (field, json.dumps(name, ensure_ascii=False)))

    def point_of(node, where):
        point = node.get("point")
        field = where + ".point" if where != "title" else "point"
        if not isinstance(point, str) or not point.strip():
            problems.append("%s: has no point; write its point in one sentence" % field)
            return
        if any(BULLET.match(line) for line in point.split("\n")):
            problems.append("%s: starts a line with a bullet; write the point as one sentence" % field)
        key = " ".join(point.split())
        if key in seen:
            problems.append("%s: repeats the point of %s; write each point once" % (field, seen[key]))
        else:
            seen[key] = field

    def node(item, where):
        if not isinstance(item, dict):
            problems.append("%s: is not an object with a name and a point" % where)
            return False
        name_of(item, where)
        point_of(item, where)
        return True

    def items(value, where, required):
        if value is None and not required:
            return []
        if not isinstance(value, list) or (required and not value):
            problems.append("%s: needs a list%s" % (where, " with one item or more" if required else ""))
            return []
        return value

    if not isinstance(outline, dict):
        return ["the outline is not a JSON object"]
    if outline.get("lang", "en") not in ("en", "ja"):
        problems.append("lang: must be en or ja")
    name_of(outline, "title")
    point_of(outline, "title")
    for i, item in enumerate(items(outline.get("overview"), "overview", False)):
        node(item, "overview[%d]" % i)
    for c, chapter in enumerate(items(outline.get("chapters"), "chapters", True)):
        where = "chapters[%d]" % c
        if not node(chapter, where):
            continue
        for p, page in enumerate(items(chapter.get("pages"), where + ".pages", True)):
            at = "%s.pages[%d]" % (where, p)
            if not node(page, at):
                continue
            for s, section in enumerate(items(page.get("sections"), at + ".sections", False)):
                node(section, "%s.sections[%d]" % (at, s))
    return problems


def text(value):
    """Escape a name or a point, and show `code` in backticks as code."""
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", html.escape(value))


def sections(rows):
    if not rows:
        return ""
    body = "".join('<div class="sec"><dt>%s</dt><dd>%s</dd></div>' % (html.escape(r["name"]), text(r["point"])) for r in rows)
    return '<dl class="secs">%s</dl>' % body


def render(outline):
    words = json.loads(UI.read_text(encoding="utf-8"))[outline.get("lang", "en")]
    chapters = []
    for c, chapter in enumerate(outline["chapters"]):
        pages = "".join(
            '<section class="page"><h3>%s</h3><p class="point">%s</p>%s</section>'
            % (html.escape(p["name"]), text(p["point"]), sections(p.get("sections") or []))
            for p in chapter["pages"]
        )
        chapters.append(
            '<details class="chapter" id="c%d"><summary><span class="icon" aria-hidden="true"></span>'
            '<span class="head"><h2>%s</h2><span class="sub">%s</span></span></summary>'
            '<div class="body">%s</div></details>' % (c, html.escape(chapter["name"]), text(chapter["point"]), pages)
        )
    overview = outline.get("overview") or []
    script_words = json.dumps({"open": words["open"], "close": words["close"]}).replace("</", "<\\/")
    values = {
        "lang": outline.get("lang", "en"),
        "page_title": html.escape(words["title"].replace("{title}", outline["title"])),
        "title": html.escape(outline["title"]),
        "point": text(outline["point"]),
        "overview": '<div class="overview">%s</div>' % sections(overview) if overview else "",
        "open": html.escape(words["open"]),
        "chapters": "\n".join(chapters),
        "text": script_words,
    }
    template = TEMPLATE.read_text(encoding="utf-8")
    return re.sub(r"\{\{(\w+)\}\}", lambda m: values[m.group(1)], template)


def main(argv):
    args = list(argv)
    out = None
    if "-o" in args:
        i = args.index("-o")
        if i + 1 >= len(args):
            usage("-o needs a path")
        out = Path(args[i + 1])
        del args[i:i + 2]
    if len(args) != 1:
        usage("give one outline file")
    source = Path(args[0])
    try:
        outline = json.loads(source.read_text(encoding="utf-8"))
    except FileNotFoundError:
        usage("%s does not exist" % source)
    except (OSError, ValueError) as error:
        usage("cannot read %s: %s" % (source, error))
    problems = check(outline)
    if problems:
        for problem in problems:
            print("outline: refused: " + problem, file=sys.stderr)
        print("outline: %d problems, no page written" % len(problems), file=sys.stderr)
        return 1
    out = out or source.with_suffix(".html")
    out.write_text(render(outline), encoding="utf-8")
    pages = sum(len(c["pages"]) for c in outline["chapters"])
    count = sum(len(p.get("sections") or []) for c in outline["chapters"] for p in c["pages"])
    print("outline: wrote %s (%d chapters, %d pages, %d sections)" % (out, len(outline["chapters"]), pages, count))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
