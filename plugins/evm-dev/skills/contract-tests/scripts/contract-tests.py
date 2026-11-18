#!/usr/bin/env python3
"""Dated items about the tools that run contract tests, the points a project's contracts need
tests for, and the points no test touches.

Commands
  check [--dir DIR]                  validate the items; exit 1 naming each bad item
  list [--dir DIR] [--today DATE]    one line per item, `stale` once checked more than 90 days ago
  points FOLDER                      one line per point: `<kind> <name> <file>:<line>`
  uncovered FOLDER                   `uncovered <kind> <name> <file>:<line>` for each point that no
                                     test touches

Kinds of points
  function   an external or public function
  error      a custom error
  event      an event
  access     a function guarded by a modifier whose name starts with `only`, by `restricted`
             (OpenZeppelin's AccessManaged), or by a comparison with msg.sender
  fuzz       a function that changes state and takes an integer
  invariant  a contract with a mapping to an unsigned integer, with or without names for its key and
             value, at the top of the contract or in a struct it declares, and a function that
             changes state

A test touches a function when it calls `.<name>`, an error or an event when it names it, an access
rule when a test expects a revert on a call to the function, a fuzz target when a Solidity test
function (its name starts with `test`) that takes parameters or a fast-check property calls it, and
an invariant when a Solidity test file that names the contract has a function whose name starts with
`invariant`, or a fast-check `fc.commands` test names it. A helper that takes parameters but is not a
test function does not count, even when a test calls it. Names inside comments do not count.

Contracts are read from the `src` folder in foundry.toml (default `src`) and from `contracts` in a
Hardhat project, leaving out interfaces and `.t.sol` and `.s.sol` files. Tests are the files under
the test folder (default `test`) and every `.t.sol` file.

An item is a Markdown file whose front matter holds `tool` (forge-std, foundry, or hardhat),
`since` (the version the fact holds from), `checked` (YYYY-MM-DD), and `source`.

Exit codes: 0 fine, 1 problems or uncovered points, 2 wrong use or nothing to read.
points and uncovered never print the text of a contract or a test, and never read dependencies
(lib/, node_modules/), build output (out/, cache/, artifacts/), hidden folders, or files whose
names start with `.env`.
"""
import argparse
import datetime
import os
import re
import sys
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent.parent
ITEMS_DIR = SKILL_DIR / "references" / "items"
TOOLS = ("forge-std", "foundry", "hardhat")
FRESH_DAYS = 90
SKIP_DIRS = {"lib", "node_modules", "out", "cache", "artifacts", "coverage", "typechain-types"}
VERSION = re.compile(r"(\d+)\.(\d+)\.(\d+)")
HARDHAT_CONFIGS = ("hardhat.config.ts", "hardhat.config.js", "hardhat.config.cjs",
                   "hardhat.config.mjs", "hardhat.config.cts", "hardhat.config.mts")
TEST_SUFFIXES = {".sol", ".ts", ".js", ".cjs", ".mjs", ".cts", ".mts"}
KINDS = ("invariant", "function", "access", "fuzz", "error", "event")

IDENT = r"[A-Za-z_$][\w$]*"
DECLARATION = re.compile(r"\b(abstract\s+contract|contract|library|interface)\s+(" + IDENT + ")")
FUNCTION = re.compile(r"\bfunction\s+(" + IDENT + r")\s*\(")
ERROR = re.compile(r"\berror\s+(" + IDENT + r")\s*\(")
EVENT = re.compile(r"\bevent\s+(" + IDENT + r")\s*\(")
UINT_MAPPING = re.compile(r"\bmapping\s*\([^;{}]*=>\s*uint\d*(?:\s+" + IDENT + r")?\s*\)")
STRUCT = re.compile(r"\bstruct\s+" + IDENT + r"\s*\{")
INTEGER = re.compile(r"\bu?int\d*\b")
GUARD_MODIFIER = re.compile(r"\bonly\w+|\brestricted\b")
SENDER_CHECK = re.compile(r"msg\.sender\s*[!=]=|[!=]=\s*msg\.sender|\b_check(?:Owner|Role)\s*\(")
REVERT = re.compile(r"\b(?:expect\w*Revert\w*|revert\w*|reject\w*)\b")
JS_TEST = re.compile(r"\b(?:it|test)(?:\.(?:only|skip|each\([^)]*\)))?\s*\(")
FAST_CHECK = re.compile(r"\bfc\.(?:assert|property|asyncProperty)\s*\(")
FAST_CHECK_COMMANDS = re.compile(r"\bfc\.commands\s*\(")


# ---- items -------------------------------------------------------------------------------------

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
        for key in ("tool", "since", "checked", "source"):
            if not fields.get(key):
                wrong.append("missing %s" % key)
        tool = fields.get("tool", "")
        if tool and tool not in TOOLS:
            wrong.append("unknown tool %s (use one of %s)" % (tool, ", ".join(TOOLS)))
        if fields.get("since") and not VERSION.fullmatch(fields["since"]):
            wrong.append("since must be a version such as 3.0.0")
        try:
            fields["checked_date"] = datetime.date.fromisoformat(fields.get("checked", ""))
        except ValueError:
            if fields.get("checked"):
                wrong.append("checked %s is not a real date (YYYY-MM-DD)" % fields["checked"])
        if wrong:
            problems.append("%s: %s" % (name, "; ".join(wrong)))
            continue
        fields["name"] = name
        items.append(fields)
    return items, problems


def cmd_check(args):
    items, problems = load_items(args.dir)
    for problem in problems:
        print(problem)
    if problems:
        print("contract-tests: %d problem%s; fix the front matter of each item named above"
              % (len(problems), "" if len(problems) == 1 else "s"))
        return 1
    print("contract-tests: ok (%d items)" % len(items))
    return 0


def cmd_list(args):
    items, problems = load_items(args.dir)
    if problems:
        for problem in problems:
            print(problem, file=sys.stderr)
        print("contract-tests: the items have problems; run check and fix them first", file=sys.stderr)
        return 2
    try:
        today = datetime.date.fromisoformat(args.today) if args.today else datetime.datetime.now(datetime.timezone.utc).date()
    except ValueError:
        print("contract-tests: --today takes a date such as 2026-11-17", file=sys.stderr)
        return 2
    stale = 0
    for item in items:
        old = (today - item["checked_date"]).days > FRESH_DAYS
        stale += old
        print("%-6s %-13s %-8s %s %s" % ("stale" if old else "ok", item["tool"], item["since"],
                                         item["checked"], item["name"]))
    print("%d items, %d stale as of %s" % (len(items), stale, today.isoformat()))
    return 0


# ---- reading code ------------------------------------------------------------------------------

def clean(text, blank_strings):
    """The text with comments, and string contents too when asked, replaced by spaces.

    Newlines stay, so an offset in the result is the same line in the original."""
    out = list(text)
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if text.startswith("//", i):
            while i < n and text[i] != "\n":
                out[i] = " "
                i += 1
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            end = n if end < 0 else end + 2
            for j in range(i, end):
                if text[j] != "\n":
                    out[j] = " "
            i = end
        elif c in "\"'`":
            j = i + 1
            while j < n and text[j] != c:
                if text[j] == "\\":
                    j += 1
                elif c != "`" and text[j] == "\n":
                    break
                j += 1
            if blank_strings:
                for k in range(i + 1, min(j, n)):
                    if text[k] != "\n":
                        out[k] = " "
            i = j + 1
        else:
            i += 1
    return "".join(out)


def matching(text, start, opening, closing):
    """The offset just past the bracket that closes the one at `start`, or len(text)."""
    depth = 0
    for i in range(start, len(text)):
        if text[i] == opening:
            depth += 1
        elif text[i] == closing:
            depth -= 1
            if depth == 0:
                return i + 1
    return len(text)


def top_level(body):
    """The body with the contents of every nested `{...}` block blanked, keeping offsets."""
    out = list(body)
    depth = 0
    for i, c in enumerate(body):
        if c == "}":
            depth -= 1
        if depth > 0 and c != "\n":
            out[i] = " "
        if c == "{":
            depth += 1
    return "".join(out)


def declarations(cleaned):
    """Each contract, library, or interface: (kind, name, offset, body start, body end)."""
    found, at = [], 0
    while True:
        match = DECLARATION.search(cleaned, at)
        if not match:
            return found
        brace = cleaned.find("{", match.end())
        if brace < 0:
            return found
        end = matching(cleaned, brace, "{", "}")
        kind = "abstract" if match.group(1).startswith("abstract") else match.group(1)
        found.append((kind, match.group(2), match.start(), brace + 1, end - 1))
        at = end


def functions(cleaned, start, end):
    """Each function declared at the top of a body: (name, offset, params, header, body)."""
    flat = top_level(cleaned[start:end])
    found = []
    for match in FUNCTION.finditer(flat):
        open_paren = start + match.end() - 1
        close_paren = matching(cleaned, open_paren, "(", ")")
        params = cleaned[open_paren + 1:close_paren - 1]
        stop = re.compile(r"[{;]").search(cleaned, close_paren)
        if not stop:
            continue
        header = cleaned[close_paren:stop.start()]
        body = None
        if cleaned[stop.start()] == "{":
            body = cleaned[stop.start():matching(cleaned, stop.start(), "{", "}")]
        found.append((match.group(1), start + match.start(), params, header, body))
    return found


def state_text(text, start, end, flat):
    """The top of a contract's body and the bodies of the structs it declares, where its storage
    variables are declared."""
    parts = [flat]
    for match in STRUCT.finditer(flat):
        brace = start + match.end() - 1
        parts.append(text[brace:matching(text, brace, "{", "}")])
    return "\n".join(parts)


def line_at(text, offset):
    return text.count("\n", 0, offset) + 1


def config_value(path, pattern, default):
    try:
        match = re.search(pattern, path.read_text(encoding="utf-8", errors="replace"), re.M)
    except OSError:
        return default
    return match.group(1).strip("/") if match else default


def walk(root):
    """Files under root, leaving out dependencies, build output, hidden folders, and .env files."""
    for current, dirs, files in os.walk(root):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS and not d.startswith("."))
        for name in sorted(files):
            if not name.startswith(".env"):
                yield Path(current) / name


def layout(root):
    """(source folders, test folders) relative to root, from foundry.toml and the Hardhat config."""
    sources, tests = [], []
    foundry = root / "foundry.toml"
    hardhat = next((root / n for n in HARDHAT_CONFIGS if (root / n).is_file()), None)
    if foundry.is_file():
        sources.append(config_value(foundry, r'^\s*src\s*=\s*["\']([^"\']+)', "src"))
        tests.append(config_value(foundry, r'^\s*test\s*=\s*["\']([^"\']+)', "test"))
    if hardhat:
        sources.append(config_value(hardhat, r'\bsources\s*:\s*["\']([^"\']+)', "contracts"))
        tests.append("test")
    if not sources:
        sources = [d for d in ("src", "contracts") if (root / d).is_dir()]
        tests = ["test"]
    return sorted(set(sources)), sorted(set(tests))


def within(rel, folders):
    return any(rel == f or rel.startswith(f + "/") for f in folders)


def contract_files(root, sources, tests):
    for path in walk(root):
        rel = path.relative_to(root).as_posix()
        if (path.suffix == ".sol" and within(rel, sources) and not within(rel, tests)
                and not path.name.endswith((".t.sol", ".s.sol"))):
            yield path, rel


def test_files(root, tests):
    for path in walk(root):
        rel = path.relative_to(root).as_posix()
        if path.name.endswith(".t.sol") or (within(rel, tests) and path.suffix in TEST_SUFFIXES):
            yield path, rel


def read(path):
    return path.read_text(encoding="utf-8", errors="replace")


def project_points(root):
    """(points, contracts read): points as dicts with kind, name, contract, member, place."""
    sources, tests = layout(root)
    points, contracts = [], 0
    for path, rel in contract_files(root, sources, tests):
        text = clean(read(path), blank_strings=True)
        for kind, name, offset, start, end in declarations(text):
            if kind == "interface":
                continue
            contracts += 1
            flat = top_level(text[start:end])

            def add(point_kind, member, at, contract=name):
                points.append({"kind": point_kind, "contract": contract, "member": member,
                               "name": "%s.%s" % (contract, member) if member else contract,
                               "place": "%s:%d" % (rel, line_at(text, at))})

            for match in ERROR.finditer(flat):
                add("error", match.group(1), start + match.start())
            for match in EVENT.finditer(flat):
                add("event", match.group(1), start + match.start())
            changes_state = False
            for fname, at, params, header, body in functions(text, start, end):
                if body is None or not re.search(r"\b(?:external|public)\b", header):
                    continue
                add("function", fname, at)
                readonly = re.search(r"\b(?:view|pure)\b", header)
                if not readonly:
                    changes_state = True
                if GUARD_MODIFIER.search(header) or SENDER_CHECK.search(body):
                    add("access", fname, at)
                if not readonly and INTEGER.search(params):
                    add("fuzz", fname, at)
            if kind == "contract" and changes_state and UINT_MAPPING.search(state_text(text, start, end, flat)):
                add("invariant", None, offset)
    points.sort(key=lambda p: (p["place"].rsplit(":", 1)[0], int(p["place"].rsplit(":", 1)[1]),
                               KINDS.index(p["kind"])))
    return points, contracts


def project_tests(root):
    """The tests, as whole texts and as single test cases, with comments removed."""
    _, tests = layout(root)
    texts, solidity_cases, script_cases, solidity_files = [], [], [], []
    for path, rel in test_files(root, tests):
        text = clean(read(path), blank_strings=False)
        texts.append(text)
        if path.suffix == ".sol":
            solidity_files.append(text)
            for _, _, _, start, end in [d for d in declarations(text) if d[0] != "interface"]:
                for fname, _, params, _, body in functions(text, start, end):
                    if body is not None:
                        solidity_cases.append({"name": fname, "params": params.strip(), "body": body,
                                               "test": fname.startswith("test")})
        else:
            starts = [m.start() for m in JS_TEST.finditer(text)]
            for i, at in enumerate(starts):
                script_cases.append(text[at:starts[i + 1] if i + 1 < len(starts) else len(text)])
    return texts, solidity_cases, script_cases, solidity_files


def reverting_call(case, call, solidity):
    """Whether the test expects a revert on a call that `call` matches.

    In Solidity the call is the first statement after `expectRevert` that is not a `vm.` cheatcode;
    in TypeScript and JavaScript the call and the revert check sit in one statement."""
    statements = case.split(";")
    if not solidity:
        return any(call.search(s) and REVERT.search(s) for s in statements)
    for i, statement in enumerate(statements):
        if not re.search(r"\bexpect\w*Revert\b", statement):
            continue
        following = (s for s in statements[i + 1:] if not re.match(r"[\s{}]*vm\.", s))
        if call.search(next(following, "")):
            return True
    return False


def touched(point, texts, solidity_cases, script_cases, solidity_files):
    member = point["member"]
    call = re.compile(r"\.%s\b" % re.escape(member or ""))
    named = re.compile(r"\b%s\b" % re.escape(member or point["contract"]))
    kind = point["kind"]
    if kind == "function":
        return any(call.search(t) for t in texts)
    if kind in ("error", "event"):
        return any(named.search(t) for t in texts)
    if kind == "access":
        return (any(reverting_call(c["body"], call, solidity=True) for c in solidity_cases)
                or any(reverting_call(c, call, solidity=False) for c in script_cases))
    if kind == "fuzz":
        return (any(c["test"] and c["params"] and call.search(c["body"]) for c in solidity_cases)
                or any(FAST_CHECK.search(c) and call.search(c) for c in script_cases))
    contract = re.compile(r"\b%s\b" % re.escape(point["contract"]))
    return (any(contract.search(t) and re.search(r"\bfunction\s+invariant\w*\s*\(", t) for t in solidity_files)
            or any(FAST_CHECK_COMMANDS.search(c) and contract.search(c) for c in script_cases))


def folder_or_fail(folder):
    root = Path(folder)
    if not root.is_dir():
        print("contract-tests: %s is not a folder; pass the project's root folder" % folder, file=sys.stderr)
        return None
    return root


def cmd_points(args):
    root = folder_or_fail(args.folder)
    if root is None:
        return 2
    points, contracts = project_points(root)
    if not contracts:
        sources, _ = layout(root)
        print("contract-tests: no contracts under %s" % (", ".join(sources) or "src or contracts"), file=sys.stderr)
        return 2
    for point in points:
        print("%s %s %s" % (point["kind"], point["name"], point["place"]))
    print("points: %d in %d contract%s" % (len(points), contracts, "" if contracts == 1 else "s"))
    return 0


def cmd_uncovered(args):
    root = folder_or_fail(args.folder)
    if root is None:
        return 2
    points, contracts = project_points(root)
    if not points:
        print("contract-tests: no points to check%s" % ("" if contracts else "; no contracts found"), file=sys.stderr)
        return 2
    tests = project_tests(root)
    missing = [p for p in points if not touched(p, *tests)]
    for point in missing:
        print("uncovered %s %s %s" % (point["kind"], point["name"], point["place"]))
    if missing:
        print("uncovered: %d of %d points have no test" % (len(missing), len(points)))
        return 1
    print("uncovered: every point has a test (%d points)" % len(points))
    return 0


def main(argv):
    parser = argparse.ArgumentParser(prog="contract-tests.py", description=__doc__.split("\n\n")[0],
                                     epilog="Exit codes: 0 fine, 1 problems or uncovered points, 2 wrong use.")
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("check", help="validate the items")
    p.add_argument("--dir", default=str(ITEMS_DIR), help="folder of items (default: the bundled items)")
    p = sub.add_parser("list", help="list the items and mark the stale ones")
    p.add_argument("--dir", default=str(ITEMS_DIR), help="folder of items (default: the bundled items)")
    p.add_argument("--today", help="count the days to this date (YYYY-MM-DD) instead of today in UTC")
    p = sub.add_parser("points", help="list what the project's contracts need tests for")
    p.add_argument("folder")
    p = sub.add_parser("uncovered", help="name each point that no test touches")
    p.add_argument("folder")
    args = parser.parse_args(argv)
    return {"check": cmd_check, "list": cmd_list, "points": cmd_points, "uncovered": cmd_uncovered}[args.command](args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
