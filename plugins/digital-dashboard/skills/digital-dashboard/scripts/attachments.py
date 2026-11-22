#!/usr/bin/env python3
"""List the files to attach to the request for the screens judged to be dashboards.

Usage:
    python3 attachments.py [--repo <dir>] [--domain finance|medical|saas|civic] [--theme <name>]
                           [--official <dir>] [--manifest <path>]

The material comes from the repository's declaration, <repo>/.claude/design-sources.json, when it
has the field dashboard_attach_globs (schema versions 2 and 3). All three fields are then taken from
the declaration and nothing is added from this skill. Without such a declaration, the list holds the
official files that fetch_official.py downloaded into the official folder, together with the rule
files of this skill. With --theme, files that only set colors are left out, and a request line asks
the drawing tool to use the theme's colors instead of the guidebook's palette.

Prints one tab-separated line per file:
    required   <path>          attach it
    domain     <path>          attach it; printed only when --domain is given
    on-demand  <path>  <when>  attach it only when the screens need what <when> describes
    request    <sentence>      copy the sentence into the request text
Exits 0 with the list, 1 when a pattern matches nothing or an official file was not fetched, and 2
when the declaration or the manifest cannot be read.
Uses only the Python standard library.
"""

import argparse
import glob
import json
import os
import sys
from typing import NoReturn

HERE = os.path.dirname(os.path.abspath(__file__))
SKILL = os.path.abspath(os.path.join(HERE, ".."))
DEFAULT_MANIFEST = os.path.join(SKILL, "references", "official-files.json")
VERSIONS = (1, 2, 3)

# The rule files of this skill, used when the repository declares no material.
RULES_REQUIRED = [
    "references/abstraction-principles.md",
    "references/chart-decision-tree.md",
    "references/color-palette.md",
]
RULES_CONVENTION = "references/conventions/{domain}.md"
RULES_ON_DEMAND = [
    ("references/numeric-format.md", "When currency, units, and percentages need one notation"),
    ("references/time-axis.md", "When the tick spacing and the granularity of time axes need to agree"),
    ("references/theme-spec.md", "When the screens follow the type scale, spacing, corners, and grid lines inside the official templates"),
    ("references/chart-library.md", "When the 30 charts of the official templates and their default sizes are needed"),
    ("references/visual-ssot.md", "When checking the rules on lone line charts, dual axes, and hidden grid lines"),
    ("references/dos-donts.md", "When checking the guidebook's principles of chart design and its dos and don'ts"),
]
# Files that set colors. A themed request leaves them out.
RULES_PALETTE = {
    "references/color-palette.md",
    "references/theme-spec.md",
    "references/chart-library.md",
}


def default_official():
    override = os.environ.get("DIGITAL_DASHBOARD_HOME")
    if override:
        return override
    return os.path.join(os.path.expanduser("~"), ".local", "share", "digital-dashboard")


def stop(status, message) -> NoReturn:
    print(f"attachments.py: {message}", file=sys.stderr)
    sys.exit(status)


def expand(base, pattern):
    """Expands a glob relative to base in Python, since a shell would not expand one held in a variable."""
    hits = sorted(glob.glob(os.path.join(base, pattern)))
    if not hits:
        stop(1, f"the pattern matched nothing: {os.path.join(base, pattern)}")
    return hits


def first_content_line(path):
    """The first line of a Markdown file, or the first non-empty line after its front matter."""
    with open(path, encoding="utf-8", errors="replace") as source:
        first = next(source, "")
        if first.rstrip("\r\n") != "---":
            return first.rstrip()
        for line in source:
            if line.rstrip("\r\n") == "---":
                return next((body.rstrip() for body in source if body.strip()), "")
        return first.rstrip()


def read_declaration(repo):
    """Returns the declaration when it names the material, or None to use this skill's list."""
    path = os.path.join(repo, ".claude", "design-sources.json")
    if not os.path.isfile(path):
        return None
    try:
        with open(path, encoding="utf-8") as source:
            declaration = json.load(source)
    except (OSError, ValueError) as error:
        stop(2, f"cannot read {path}: {error}")
    version = declaration.get("schema_version") if isinstance(declaration, dict) else None
    if version not in VERSIONS:
        stop(2, f"{path} has schema_version {version!r}; versions 1 to 3 are read")
    if version >= 2 and "dashboard_attach_globs" in declaration:
        return declaration
    return None


def declared(declaration, repo, domain):
    version = declaration["schema_version"]

    def on_demand(element):
        # From version 3 an element may be {"glob": ..., "when": ...}; "when" says when to add it.
        if isinstance(element, str):
            return element, None
        if version == 3 and isinstance(element, dict) and isinstance(element.get("glob"), str) \
                and isinstance(element.get("when", ""), str):
            return element["glob"], element.get("when")
        stop(2, f"an element of dashboard_on_demand_globs cannot be read: {element!r}; "
                "an object needs version 3 and a glob")

    # Every element is read before anything is printed, so a broken list prints nothing.
    elements = [on_demand(element) for element in declaration.get("dashboard_on_demand_globs", [])]
    lines: list[tuple[str, ...]] = [("required", path) for pattern in declaration["dashboard_attach_globs"]
                                    for path in expand(repo, pattern)]
    template = declaration.get("dashboard_convention_template")
    if domain and template:
        lines += [("domain", path) for path in expand(repo, template.replace("{domain}", domain))]
    for pattern, when in elements:
        for path in expand(repo, pattern):
            lines.append(("on-demand", path, when or (first_content_line(path) if path.endswith(".md") else "")))
    return lines


def read_manifest(path):
    try:
        with open(path, encoding="utf-8") as source:
            rows = json.load(source)
    except (OSError, ValueError) as error:
        stop(2, f"cannot read the manifest {path}: {error}")
    if not isinstance(rows, list):
        stop(2, f"the manifest {path} is not a JSON array")
    return rows


def bundled(official, manifest, domain, theme):
    rows = [row for row in read_manifest(manifest) if not (theme and row.get("palette"))]
    missing = [row["path"] for row in rows if not os.path.isfile(os.path.join(official, row["path"]))]
    if missing:
        stop(1, f"{len(missing)} official files are not in {official}; run fetch_official.py first "
                f"(missing: {', '.join(missing[:5])}{' ...' if len(missing) > 5 else ''})")
    lines: list[tuple[str, ...]] = [("required", os.path.join(official, row["path"])) for row in rows
                                    if row.get("attach") == "required"]
    lines += [("required", os.path.join(SKILL, path)) for path in RULES_REQUIRED if not (theme and path in RULES_PALETTE)]
    if domain:
        lines += [("domain", path) for path in expand(SKILL, RULES_CONVENTION.replace("{domain}", domain))]
    lines += [("on-demand", os.path.join(SKILL, path), when) for path, when in RULES_ON_DEMAND
              if not (theme and path in RULES_PALETTE)]
    lines += [("on-demand", os.path.join(official, row["path"]), row.get("when") or row.get("title", ""))
              for row in rows if row.get("attach") == "on-demand"]
    return lines


def main():
    parser = argparse.ArgumentParser(description="List the files to attach to the request for the dashboard screens.")
    parser.add_argument("--repo", default=".", help="root of the repository whose screens are drawn")
    parser.add_argument("--domain", default="", help="finance, medical, saas, or civic, when the field is known")
    parser.add_argument("--theme", default="", help="name of the theme the drawing tool uses, if any")
    parser.add_argument("--official", default=default_official(), help="folder that fetch_official.py wrote")
    parser.add_argument("--manifest", default=DEFAULT_MANIFEST, help="list of the official files")
    args = parser.parse_args()

    repo = os.path.abspath(args.repo)
    declaration = read_declaration(repo)
    if declaration is not None:
        lines = declared(declaration, repo, args.domain)
    else:
        lines = bundled(os.path.abspath(args.official), args.manifest, args.domain, args.theme)
    if args.theme:
        lines.append(("request", f"Use the colors of the theme {args.theme} instead of the color palette of the guidebook: "
                                 "leave out its section on colors and every color value in the attached files."))
    for line in lines:
        print("\t".join(line))


if __name__ == "__main__":
    main()
