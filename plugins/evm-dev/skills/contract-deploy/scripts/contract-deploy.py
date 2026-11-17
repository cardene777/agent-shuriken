#!/usr/bin/env python3
"""Dated items about deploying contracts, a check of how a project's deploy scripts and settings
handle keys, and one deployment record per chain built from Foundry and Hardhat Ignition files.

Commands
  check [--dir DIR]                  validate the items; exit 1 naming each bad item
  list [--dir DIR] [--today DATE]    one line per item, `stale` once checked more than 90 days ago
  keys FOLDER                        one line per finding: `<kind> <file>:<line>`, or
                                     `env-file <file> (<why>)`
  record FOLDER [--write]            one line per deployed contract and per transaction that needs a
                                     look; --write also writes deployments/<chain id>.json

Kinds of findings from keys
  env-key      a private key or mnemonic read from an environment variable (vm.env* in Solidity,
               process.env in JavaScript and TypeScript, $NAME in shell, Make, and other settings),
               or from a Hardhat 2 configuration variable (vars.get), which is stored in plain text
  key-flag     a command that passes --private-key, --private-keys, --mnemonic, --mnemonics, or
               --password
  key-literal  64 hex digits, or a quoted phrase of 12 to 24 lowercase words, on a line that speaks
               of a key, a mnemonic, a seed, accounts, or broadcasting
  env-file     a file whose name starts with .env that git tracks or does not ignore (.env.example,
               .env.sample, and .env.template are left out); only checked inside a git repository

A variable counts as a key when its name holds private_key, privkey, secret_key, mnemonic, seed, or pk
as a word. keys reads Solidity, JavaScript, TypeScript, shell scripts, Makefiles, justfiles,
package.json, and TOML and YAML files. Comments are left out, except for key-literal: a key in a
comment is still a key in the file.

Lines from record
  contract <chain> <name> <address> tx <hash> block <n> from <deployer> source <source>
  failed   <chain> <name> tx <hash> source <source>   the transaction reverted
  pending  <chain> <name> tx <hash> source <source>   the transaction has no receipt
  mismatch <chain> <name> tx <hash> source <source>   the record says the transaction created the
                                                      contract, but its receipt does not show it
The source is `foundry:<script>` for broadcast/<script>/<chain>/run-latest.json, or
`ignition:<deployment id>` for ignition/deployments/<deployment id>/journal.jsonl. Dry runs
(broadcast/.../dry-run/) are left out. A record file holds `format` (1), `chainId`, `contracts` (name,
address, tx, block, deployer, source, commit), and `problems` (kind, name, tx, source); it is rebuilt
from the files each time. The commit comes from Foundry's run file and is null when it has none.

An item is a Markdown file whose front matter holds `topic` (keys, records, or verification),
`subject`, `checked` (YYYY-MM-DD), and `source`.

Exit codes: 0 fine, 1 problems or findings, 2 wrong use or nothing to read.
keys and record never print a key or a line of the project's files. They never open files whose names
start with .env, Foundry's cache/ folder (it holds RPC URLs), dependencies (lib/, node_modules/), build
output, or hidden folders.
"""
import argparse
import datetime
import json
import os
import re
import subprocess
import sys
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent.parent
ITEMS_DIR = SKILL_DIR / "references" / "items"
TOPICS = ("keys", "records", "verification")
FRESH_DAYS = 90
SKIP_DIRS = {"lib", "node_modules", "out", "cache", "artifacts", "coverage", "typechain-types",
             "broadcast", "deployments"}
MAX_BYTES = 1024 * 1024

C_LIKE = {".sol", ".ts", ".js", ".cjs", ".mjs", ".cts", ".mts"}
JS_LIKE = C_LIKE - {".sol"}
SHELL_LIKE = {".sh", ".bash", ".zsh", ".toml", ".yml", ".yaml"}
SHELL_NAMES = {"Makefile", "makefile", "GNUmakefile", "justfile", "Justfile", "package.json"}
ENV_EXAMPLES = {".env.example", ".env.sample", ".env.template"}

KEY_NAME = re.compile(r"private_?key|privkey|secret_?key|mnemonic|seed|(?:^|_)pk(?:$|_)", re.I)
SOL_ENV = re.compile(r"\bvm\.env\w*\s*\(\s*\"(\w+)\"")
JS_ENV = re.compile(r"\bprocess\.env(?:\.(\w+)|\[\s*[\"'`](\w+)[\"'`]\s*\])|\bvars\.(?:get|has)\s*\(\s*[\"'`](\w+)")
SHELL_ENV = re.compile(r"\$(?:\{|\()?([A-Za-z_]\w*)")
KEY_FLAG = re.compile(r"(?<![\w-])--(?:private-keys?|mnemonics?|password)(?=[\s=\"']|$)")
HEX_KEY = re.compile(r"(?<![0-9A-Za-z])(?:0x)?[0-9a-fA-F]{64}(?![0-9A-Za-z])")
PHRASE = re.compile(r"[\"'`][a-z]+(?: [a-z]+){11,23}[\"'`]")
KEY_WORDS = re.compile(r"private|priv|secret|mnemonic|seed|phrase|\bpk\b|key|accounts|broadcast|wallet|signer", re.I)


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
        for key in ("topic", "subject", "checked", "source"):
            if not fields.get(key):
                wrong.append("missing %s" % key)
        topic = fields.get("topic", "")
        if topic and topic not in TOPICS:
            wrong.append("unknown topic %s (use one of %s)" % (topic, ", ".join(TOPICS)))
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
        print("contract-deploy: %d problem%s; fix the front matter of each item named above"
              % (len(problems), "" if len(problems) == 1 else "s"))
        return 1
    print("contract-deploy: ok (%d items)" % len(items))
    return 0


def cmd_list(args):
    items, problems = load_items(args.dir)
    if problems:
        for problem in problems:
            print(problem, file=sys.stderr)
        print("contract-deploy: the items have problems; run check and fix them first", file=sys.stderr)
        return 2
    try:
        today = datetime.date.fromisoformat(args.today) if args.today else datetime.datetime.now(datetime.timezone.utc).date()
    except ValueError:
        print("contract-deploy: --today takes a date such as 2026-11-17", file=sys.stderr)
        return 2
    stale = 0
    for item in items:
        old = (today - item["checked_date"]).days > FRESH_DAYS
        stale += old
        print("%-6s %-13s %s %s %s" % ("stale" if old else "ok", item["topic"], item["checked"],
                                       item["name"], item["subject"]))
    print("%d items, %d stale as of %s" % (len(items), stale, today.isoformat()))
    return 0


# ---- keys --------------------------------------------------------------------------------------

def strip_c_comments(text):
    """The text with // and /* */ comments replaced by spaces; strings stay, and so do newlines."""
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
            i = j + 1
        else:
            i += 1
    return "".join(out)


def strip_hash_comments(text):
    """The text with every line that starts with # blanked, keeping the line count."""
    return "\n".join("" if line.lstrip().startswith("#") else line for line in text.split("\n"))


def walk(root):
    """Files under root, leaving out dependencies, build output, records, and hidden folders.

    Files whose names start with .env are yielded by name only and must not be opened."""
    for current, dirs, files in os.walk(root):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS and not d.startswith("."))
        for name in sorted(files):
            yield Path(current) / name


def scanned(path):
    return path.suffix in C_LIKE or path.suffix in SHELL_LIKE or path.name in SHELL_NAMES


def key_findings(text, path):
    """Sorted (kind, line) pairs for one file's text."""
    found = set()
    if path.suffix in C_LIKE:
        code = strip_c_comments(text)
    else:
        code = strip_hash_comments(text)
    for number, line in enumerate(code.split("\n"), 1):
        names = []
        if path.suffix == ".sol":
            names = SOL_ENV.findall(line)
        elif path.suffix in JS_LIKE:
            names = [next(n for n in groups if n) for groups in JS_ENV.findall(line)]
        else:
            names = SHELL_ENV.findall(line)
        if any(KEY_NAME.search(name) for name in names):
            found.add(("env-key", number))
        if path.suffix != ".sol" and KEY_FLAG.search(line):
            found.add(("key-flag", number))
    for number, line in enumerate(text.split("\n"), 1):
        if KEY_WORDS.search(line) and (HEX_KEY.search(line) or PHRASE.search(line)):
            found.add(("key-literal", number))
    return sorted(found, key=lambda f: (f[1], f[0]))


def git(root, *args):
    try:
        return subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True).returncode
    except OSError:
        return None


def env_file_findings(root, env_files):
    """(findings, note): env files that git tracks or does not ignore, or a note when git cannot tell."""
    if not env_files:
        return [], None
    if git(root, "rev-parse", "--is-inside-work-tree") != 0:
        return [], "not a git repository, so env files were not checked"
    findings = []
    for rel in env_files:
        if git(root, "ls-files", "--error-unmatch", "--", rel) == 0:
            findings.append("env-file %s (tracked by git)" % rel)
        elif git(root, "check-ignore", "-q", "--", rel) != 0:
            findings.append("env-file %s (not ignored by git)" % rel)
    return findings, None


def cmd_keys(args):
    root = folder_or_fail(args.folder)
    if root is None:
        return 2
    findings, env_files, read = [], [], 0
    for path in walk(root):
        rel = path.relative_to(root).as_posix()
        if path.name.startswith(".env"):
            if path.name not in ENV_EXAMPLES:
                env_files.append(rel)
            continue
        if not scanned(path):
            continue
        try:
            if path.stat().st_size > MAX_BYTES:
                continue
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        read += 1
        for kind, number in key_findings(text, path):
            findings.append("%s %s:%d" % (kind, rel, number))
    env_findings, note = env_file_findings(root, env_files)
    findings += env_findings
    for finding in findings:
        print(finding)
    if note:
        print("keys: %s" % note, file=sys.stderr)
    if findings:
        print("keys: %d finding%s in %d files read; change each one to an encrypted keystore or a "
              "hardware wallet" % (len(findings), "" if len(findings) == 1 else "s", read))
        return 1
    print("keys: no key handling problems (%d files read)" % read)
    return 0


# ---- record ------------------------------------------------------------------------------------

def number(value):
    """An integer from a hex string, a decimal string, an int, or Ignition's bigint object."""
    if isinstance(value, dict) and value.get("_kind") == "bigint":
        value = value.get("value")
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        try:
            return int(value, 16) if value.lower().startswith("0x") else int(value)
        except ValueError:
            return None
    return None


def low(value):
    return value.lower() if isinstance(value, str) else ""


def foundry_runs(root):
    """Each (script, chain folder, run file) under broadcast/, leaving out dry runs."""
    broadcast = root / "broadcast"
    if not broadcast.is_dir():
        return
    for script in sorted(p for p in broadcast.iterdir() if p.is_dir()):
        for chain in sorted(p for p in script.iterdir() if p.is_dir() and p.name.isdigit()):
            run = chain / "run-latest.json"
            if run.is_file():
                yield script.name, chain.name, run


def foundry_record(script, chain_name, path, contracts, problems):
    data = json.loads(path.read_text(encoding="utf-8"))
    chain = number(data.get("chain")) or int(chain_name)
    source = "foundry:%s" % script
    commit = data.get("commit") or None
    receipts = {low(r.get("transactionHash")): r for r in data.get("receipts") or []}
    for tx in data.get("transactions") or []:
        tx_hash = tx.get("hash") or ""
        name = tx.get("contractName") or "unknown"
        receipt = receipts.get(low(tx_hash))
        problem = None
        if receipt is None:
            problem = "pending"
        elif number(receipt.get("status")) != 1:
            problem = "failed"
        elif tx.get("transactionType") == "CREATE" and low(receipt.get("contractAddress")) != low(tx.get("contractAddress")):
            problem = "mismatch"
        if problem:
            problems.append({"chain": chain, "kind": problem, "name": name, "tx": tx_hash, "source": source})
            continue
        if tx.get("transactionType") not in ("CREATE", "CREATE2"):
            continue
        entry = {"name": name, "tx": tx_hash, "block": number(receipt.get("blockNumber")),
                 "deployer": (tx.get("transaction") or {}).get("from"), "source": source, "commit": commit}
        contracts.append(dict(entry, chain=chain, address=tx.get("contractAddress")))
        for extra in tx.get("additionalContracts") or []:
            contracts.append(dict(entry, chain=chain, name=extra.get("contractName") or "unknown",
                                  address=extra.get("address")))


def ignition_record(deployment, path, contracts, problems):
    """Deployments and failures from one Ignition journal, one JSON message per line."""
    chain, futures, order = None, {}, []

    def future(future_id):
        if future_id not in futures:
            futures[future_id] = {"name": future_id.split("#")[-1], "deployment": False, "from": None,
                                  "sent": [], "confirmed": {}, "result": None}
            order.append(future_id)
        return futures[future_id]

    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        message = json.loads(line)
        kind = message.get("type", "")
        if kind == "DEPLOYMENT_INITIALIZE":
            chain = number(message.get("chainId"))
        elif kind.endswith("_EXECUTION_STATE_INITIALIZE"):
            f = future(message.get("futureId", ""))
            f["deployment"] = kind == "DEPLOYMENT_EXECUTION_STATE_INITIALIZE"
            f["name"] = message.get("contractName") or f["name"]
            f["from"] = message.get("from")
        elif kind == "TRANSACTION_SEND":
            future(message.get("futureId", ""))["sent"].append((message.get("transaction") or {}).get("hash"))
        elif kind == "TRANSACTION_CONFIRM":
            future(message.get("futureId", ""))["confirmed"][message.get("hash")] = message.get("receipt") or {}
        elif kind.endswith("_EXECUTION_STATE_COMPLETE"):
            future(message.get("futureId", ""))["result"] = message.get("result") or {}
    if chain is None:
        return
    source = "ignition:%s" % deployment
    for future_id in order:
        f = futures[future_id]
        if not f["sent"]:
            continue
        confirmed = [(h, r) for h, r in f["confirmed"].items()]
        tx_hash, receipt = confirmed[-1] if confirmed else (f["sent"][-1], None)
        result = f["result"] or {}
        problem = None
        if receipt is None:
            problem = "pending"
        elif receipt.get("status") != "SUCCESS" or (result and result.get("type") not in (None, "SUCCESS")):
            problem = "failed"
        elif f["deployment"] and result.get("address") and receipt.get("contractAddress") \
                and low(receipt.get("contractAddress")) != low(result.get("address")):
            problem = "mismatch"
        if problem:
            problems.append({"chain": chain, "kind": problem, "name": f["name"], "tx": tx_hash, "source": source})
        elif f["deployment"] and result.get("type") == "SUCCESS":
            contracts.append({"chain": chain, "name": f["name"], "address": result.get("address"), "tx": tx_hash,
                              "block": number(receipt.get("blockNumber")), "deployer": f["from"],
                              "source": source, "commit": None})


def cmd_record(args):
    root = folder_or_fail(args.folder)
    if root is None:
        return 2
    contracts, problems, read = [], [], 0
    for script, chain, path in foundry_runs(root):
        try:
            foundry_record(script, chain, path, contracts, problems)
        except (OSError, ValueError) as error:
            print("record: cannot read %s: %s" % (path.relative_to(root).as_posix(), type(error).__name__), file=sys.stderr)
            return 2
        read += 1
    deployments = root / "ignition" / "deployments"
    if deployments.is_dir():
        for folder in sorted(p for p in deployments.iterdir() if p.is_dir()):
            journal = folder / "journal.jsonl"
            if not journal.is_file():
                continue
            try:
                ignition_record(folder.name, journal, contracts, problems)
            except (OSError, ValueError) as error:
                print("record: cannot read %s: %s" % (journal.relative_to(root).as_posix(), type(error).__name__), file=sys.stderr)
                return 2
            read += 1
    if not read:
        print("contract-deploy: no broadcast/<script>/<chain>/run-latest.json and no "
              "ignition/deployments/<id>/journal.jsonl under %s" % args.folder, file=sys.stderr)
        return 2
    for c in contracts:
        print("contract %s %s %s tx %s block %s from %s source %s"
              % (c["chain"], c["name"], c["address"], c["tx"], c["block"], c["deployer"], c["source"]))
    for p in problems:
        print("%s %s %s tx %s source %s" % (p["kind"], p["chain"], p["name"], p["tx"], p["source"]))
    chains = sorted({c["chain"] for c in contracts} | {p["chain"] for p in problems})
    if args.write:
        out = root / "deployments"
        out.mkdir(exist_ok=True)
        for chain in chains:
            record = {"format": 1, "chainId": chain,
                      "contracts": [{k: c[k] for k in ("name", "address", "tx", "block", "deployer", "source", "commit")}
                                    for c in contracts if c["chain"] == chain],
                      "problems": [{k: p[k] for k in ("kind", "name", "tx", "source")}
                                   for p in problems if p["chain"] == chain]}
            target = out / ("%s.json" % chain)
            target.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
            print("wrote %s" % target.relative_to(root).as_posix())
    print("record: %d contract%s on %d chain%s, %d transaction%s to look at"
          % (len(contracts), "" if len(contracts) == 1 else "s", len(chains), "" if len(chains) == 1 else "s",
             len(problems), "" if len(problems) == 1 else "s"))
    return 1 if problems else 0


def folder_or_fail(folder):
    root = Path(folder)
    if not root.is_dir():
        print("contract-deploy: %s is not a folder; pass the project's root folder" % folder, file=sys.stderr)
        return None
    return root


def main(argv):
    parser = argparse.ArgumentParser(prog="contract-deploy.py", description=__doc__.split("\n\n")[0],
                                     epilog="Exit codes: 0 fine, 1 problems or findings, 2 wrong use.")
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("check", help="validate the items")
    p.add_argument("--dir", default=str(ITEMS_DIR), help="folder of items (default: the bundled items)")
    p = sub.add_parser("list", help="list the items and mark the stale ones")
    p.add_argument("--dir", default=str(ITEMS_DIR), help="folder of items (default: the bundled items)")
    p.add_argument("--today", help="count the days to this date (YYYY-MM-DD) instead of today in UTC")
    p = sub.add_parser("keys", help="name each place where the project handles a key unsafely")
    p.add_argument("folder")
    p = sub.add_parser("record", help="build the deployment record of each chain")
    p.add_argument("folder")
    p.add_argument("--write", action="store_true", help="write deployments/<chain id>.json in the project")
    args = parser.parse_args(argv)
    return {"check": cmd_check, "list": cmd_list, "keys": cmd_keys, "record": cmd_record}[args.command](args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
