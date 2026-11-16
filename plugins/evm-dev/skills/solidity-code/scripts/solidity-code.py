#!/usr/bin/env python3
"""Dated items about the tools a Solidity project uses, the versions a project uses, and a scan
of written code against the items.

Commands
  check [--dir DIR]                  validate the items; exit 1 naming each bad item
  list [--dir DIR] [--today DATE]    one line per item, `stale` once checked more than 90 days ago
  project FOLDER                     the framework and the versions of solc, OpenZeppelin,
                                     forge-std, Foundry, and Hardhat; `unknown` when a version
                                     cannot be read, `none` when the project does not use the tool
  scan FOLDER [--items DIR]          `file:line item` for each line that matches an item's
                                     `detect` pattern, for items whose tool version applies

An item is a Markdown file whose front matter holds `tool`, `since` (the version the fact starts
at; not used for `ethereum`), `checked` (YYYY-MM-DD), `source`, and optionally `detect` (a regular
expression matched per line) and `files` (space-separated file name globs, `*.sol` by default).

Exit codes: 0 fine or nothing found, 1 problems or matches found, 2 wrong use or unreadable
items, 3 scan found nothing but could not judge some items because a version is unknown.
scan never prints the text of a line, and never reads dependencies (lib/, node_modules/), build
output (out/, cache/), hidden folders, or files whose names start with `.env`.
"""
import argparse
import datetime
import fnmatch
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent.parent
ITEMS_DIR = SKILL_DIR / "references" / "items"
TOOLS = ("solc", "openzeppelin", "forge-std", "foundry", "hardhat", "ethereum")
FRESH_DAYS = 90
SKIP_DIRS = {"lib", "node_modules", "out", "cache"}
VERSION = re.compile(r"(\d+)\.(\d+)\.(\d+)")
HARDHAT_CONFIGS = ("hardhat.config.ts", "hardhat.config.js", "hardhat.config.cjs",
                   "hardhat.config.mjs", "hardhat.config.cts", "hardhat.config.mts")


def front_matter(path):
    """The `key: value` lines between the first two `---` lines, or None when there are none."""
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    fields = {}
    for line in lines[1:]:
        if line.strip() == "---":
            return fields
        key, sep, value = line.partition(":")
        if sep:
            fields[key.strip()] = value.strip()
    return None


def load_items(folder):
    """(items, problems): items as dicts with their name, problems as 'name: what is wrong'."""
    items, problems = [], []
    paths = sorted(Path(folder).glob("*.md"))
    if not paths:
        problems.append("%s: no items" % folder)
    for path in paths:
        name = path.stem
        fields = front_matter(path)
        if fields is None:
            problems.append("%s: no front matter between --- lines" % name)
            continue
        wrong = []
        for key in ("tool", "checked", "source"):
            if not fields.get(key):
                wrong.append("missing %s" % key)
        tool = fields.get("tool", "")
        if tool and tool not in TOOLS:
            wrong.append("unknown tool %s (use one of %s)" % (tool, ", ".join(TOOLS)))
        if tool and tool != "ethereum" and not VERSION.fullmatch(fields.get("since", "")):
            wrong.append("since must be a version such as 5.7.0")
        try:
            fields["checked_date"] = datetime.date.fromisoformat(fields.get("checked", ""))
        except ValueError:
            if fields.get("checked"):
                wrong.append("checked %s is not a real date (YYYY-MM-DD)" % fields["checked"])
        if fields.get("detect"):
            try:
                fields["pattern"] = re.compile(fields["detect"])
            except re.error as err:
                wrong.append("detect is not a regular expression (%s)" % err)
        if wrong:
            problems.append("%s: %s" % (name, "; ".join(wrong)))
            continue
        fields["name"] = name
        fields["globs"] = fields.get("files", "*.sol").split()
        items.append(fields)
    return items, problems


def version_tuple(text):
    match = VERSION.search(text or "")
    return tuple(int(n) for n in match.groups()) if match else None


def package_version(path):
    """The X.Y.Z version in a package.json, or 'unknown' when it has none or cannot be read."""
    try:
        version = json.loads(path.read_text(encoding="utf-8")).get("version", "")
    except (OSError, ValueError, AttributeError):
        return "unknown"
    found = version_tuple(version)
    return ".".join(map(str, found)) if found else "unknown"


def first_version(paths):
    """The version from the first package.json whose folder exists; 'none' when no folder does."""
    for path in paths:
        if path.parent.is_dir():
            return package_version(path)
    return "none"


def source_files(root):
    """Paths under root, leaving out dependencies, build output, hidden folders, and .env files."""
    for current, dirs, files in os.walk(root):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS and not d.startswith("."))
        for name in sorted(files):
            if not name.startswith(".env"):
                yield Path(current) / name


def project_info(root):
    root = Path(root)
    foundry_toml = root / "foundry.toml"
    hardhat_config = next((root / n for n in HARDHAT_CONFIGS if (root / n).is_file()), None)
    frameworks = [n for n, there in (("foundry", foundry_toml.is_file()), ("hardhat", hardhat_config)) if there]
    info = {"framework": " ".join(frameworks) or "none"}

    sol_files = [p for p in source_files(root) if p.suffix == ".sol"]
    solc = None
    if foundry_toml.is_file():
        match = re.search(r'^\s*solc(?:_version)?\s*=\s*["\']?(\d+\.\d+\.\d+)', foundry_toml.read_text(errors="replace"), re.M)
        solc = match and match.group(1)
    if not solc and hardhat_config:
        match = re.search(r'(?:solidity|version)\s*:\s*["\'](\d+\.\d+\.\d+)', hardhat_config.read_text(errors="replace"))
        solc = match and match.group(1)
    info["solc"] = solc or ("unknown" if frameworks or sol_files else "none")

    info["openzeppelin"] = first_version([
        root / "lib/openzeppelin-contracts/package.json",
        root / "node_modules/@openzeppelin/contracts/package.json",
        root / "lib/openzeppelin-contracts-upgradeable/package.json",
        root / "node_modules/@openzeppelin/contracts-upgradeable/package.json",
    ])
    info["forge-std"] = first_version([root / "lib/forge-std/package.json", root / "node_modules/forge-std/package.json"])

    info["foundry"] = "none"
    if foundry_toml.is_file():
        info["foundry"] = "unknown"
        forge = shutil.which("forge")
        if forge:
            try:
                out = subprocess.run([forge, "--version"], capture_output=True, text=True, timeout=20).stdout
                found = version_tuple(out)
                if found:
                    info["foundry"] = ".".join(map(str, found))
            except (OSError, subprocess.SubprocessError):
                pass

    hardhat = first_version([root / "node_modules/hardhat/package.json"])
    if hardhat in ("none", "unknown"):
        try:
            package = json.loads((root / "package.json").read_text(encoding="utf-8"))
            declared = {**package.get("dependencies", {}), **package.get("devDependencies", {})}.get("hardhat")
        except (OSError, ValueError, AttributeError):
            declared = None
        found = version_tuple(declared)
        if found:
            hardhat = ".".join(map(str, found))
        elif hardhat == "none" and (hardhat_config or declared):
            hardhat = "unknown"
    info["hardhat"] = hardhat

    pragmas = set()
    for path in sol_files:
        for match in re.finditer(r"pragma\s+solidity\s+([^;]+);", path.read_text(errors="replace")):
            pragmas.add(" ".join(match.group(1).split()))
    info["pragma"] = ", ".join(sorted(pragmas)) or "none"
    return info


def cmd_check(args):
    items, problems = load_items(args.dir)
    for problem in problems:
        print(problem)
    if problems:
        print("solidity-code: %d problem%s; fix the front matter of each item named above"
              % (len(problems), "" if len(problems) == 1 else "s"))
        return 1
    print("solidity-code: ok (%d items)" % len(items))
    return 0


def cmd_list(args):
    items, problems = load_items(args.dir)
    if problems:
        for problem in problems:
            print(problem, file=sys.stderr)
        print("solidity-code: the items have problems; run check and fix them first", file=sys.stderr)
        return 2
    try:
        today = datetime.date.fromisoformat(args.today) if args.today else datetime.datetime.now(datetime.timezone.utc).date()
    except ValueError:
        print("solidity-code: --today takes a date such as 2026-11-16", file=sys.stderr)
        return 2
    stale = 0
    for item in items:
        old = (today - item["checked_date"]).days > FRESH_DAYS
        stale += old
        print("%-6s %-13s %-8s %s %s" % ("stale" if old else "ok", item["tool"], item.get("since") or "-",
                                         item["checked"], item["name"]))
    print("%d items, %d stale as of %s" % (len(items), stale, today.isoformat()))
    return 0


def cmd_project(args):
    if not Path(args.folder).is_dir():
        print("solidity-code: %s is not a folder; pass the project's root folder" % args.folder, file=sys.stderr)
        return 2
    for key, value in project_info(args.folder).items():
        print("%-13s %s" % (key, value))
    return 0


def cmd_scan(args):
    root = Path(args.folder)
    if not root.is_dir():
        print("solidity-code: %s is not a folder; pass the project's root folder" % args.folder, file=sys.stderr)
        return 2
    items, problems = load_items(args.items)
    if problems:
        for problem in problems:
            print(problem, file=sys.stderr)
        print("solidity-code: the items have problems; run check and fix them first", file=sys.stderr)
        return 2
    info = project_info(root)
    applies, unknown = [], []
    for item in items:
        if "pattern" not in item:
            continue
        if item["tool"] == "ethereum":
            applies.append(item)
            continue
        version = info[item["tool"]]
        if version == "unknown":
            unknown.append(item)
        elif version != "none" and version_tuple(version) >= version_tuple(item["since"]):
            applies.append(item)

    matches, unreadable = [], 0
    for path in source_files(root):
        wanted = [i for i in applies if any(fnmatch.fnmatch(path.name, g) for g in i["globs"])]
        if not wanted:
            continue
        try:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            unreadable += 1
            continue
        rel = path.relative_to(root).as_posix()
        for number, line in enumerate(lines, 1):
            for item in wanted:
                if item["pattern"].search(line):
                    matches.append("%s:%d %s" % (rel, number, item["name"]))
    for match in matches:
        print(match)
    if unknown:
        print("unknown")
        for item in unknown:
            print("  %s (%s version unknown)" % (item["name"], item["tool"]))
    note = "; %d file%s could not be read" % (unreadable, "" if unreadable == 1 else "s") if unreadable else ""
    if matches:
        print("scan: %d match%s; %d item%s not judged%s" % (len(matches), "" if len(matches) == 1 else "es",
                                                          len(unknown), "" if len(unknown) == 1 else "s", note))
        return 1
    if unknown:
        print("scan: %d item%s not judged, because the version of their tool is unknown%s"
              % (len(unknown), "" if len(unknown) == 1 else "s", note))
        return 3
    print("scan: no matches (%d items judged)%s" % (len(applies), note))
    return 0


def main(argv):
    parser = argparse.ArgumentParser(prog="solidity-code.py", description=__doc__.split("\n\n")[0],
                                     epilog="Exit codes: 0 fine, 1 problems or matches, 2 wrong use, 3 versions unknown.")
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("check", help="validate the items")
    p.add_argument("--dir", default=str(ITEMS_DIR), help="folder of items (default: the bundled items)")
    p = sub.add_parser("list", help="list the items and mark the stale ones")
    p.add_argument("--dir", default=str(ITEMS_DIR), help="folder of items (default: the bundled items)")
    p.add_argument("--today", help="count the days to this date (YYYY-MM-DD) instead of today in UTC")
    p = sub.add_parser("project", help="print the framework and the versions a project uses")
    p.add_argument("folder")
    p = sub.add_parser("scan", help="find lines that match the items for the project's versions")
    p.add_argument("folder")
    p.add_argument("--items", default=str(ITEMS_DIR), help="folder of items (default: the bundled items)")
    args = parser.parse_args(argv)
    return {"check": cmd_check, "list": cmd_list, "project": cmd_project, "scan": cmd_scan}[args.command](args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
