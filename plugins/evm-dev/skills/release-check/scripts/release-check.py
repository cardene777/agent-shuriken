#!/usr/bin/env python3
"""Dated items about checking contracts before a release, and three checks on build output: the
storage layout and the ABI of two versions, and the opcodes a target EVM version lacks.

Commands
  check [--dir DIR]                  validate the items; exit 1 naming each bad item
  list [--dir DIR] [--today DATE]    one line per item, `stale` once checked more than 90 days ago
  layout OLD NEW [--contract NAME] [--new-contract NAME]
                                     compare two storage layouts; exit 1 on a problem
  abi OLD NEW [--contract NAME] [--new-contract NAME]
                                     compare two ABIs; exit 1 on a breaking change
  opcodes BUILD --evm VERSION [--contract NAME]
                                     name each opcode the EVM version lacks; exit 1 when there is one

Inputs
  OLD and NEW are each a JSON file or a Foundry out/ folder. A layout file is the output of
  `forge inspect <contract> storageLayout --json` or an artifact built with
  `--extra-output storageLayout`; an ABI file is the output of `forge inspect <contract> abi --json`
  or an artifact. Two folders are compared artifact by artifact (<file>.sol/<contract>.json); in a
  folder, test and script artifacts (*.t.sol/, *.s.sol/), build-info/, and *.dbg.json are left out.
  --contract keeps one contract; with --new-contract the old one named by --contract is compared with
  the new one named by --new-contract. BUILD is a Foundry out/ folder, a Hardhat artifacts/ folder, or
  one artifact.

Lines from layout
  removed <contract> <label> slot <n> offset <n>   the variable is gone and nothing took its place
  moved <contract> <label> <slot>:<offset> -> <slot>:<offset>
  retyped <contract> <label> <old type> -> <new type>, or <type> changed inside (a struct's members,
          a mapping's value, or an array's base changed)
  gap <contract> <label> ends at slot <n> instead of <n>   a __gap array no longer ends where it did
  renamed <contract> <old> -> <new> slot <n> offset <n>   same place and type, new name (not counted
          as a problem)
  not-compared <contract> <namespace>: <why>   the contract's ERC-7201 namespaced storage was not
          compared; <namespace> is `namespaces` when the build does not say which it has
A variable is matched by name first, then by place. New variables are fine where nothing lived
before: in unused bytes of a slot, inside the old __gap, or after the last old variable. Struct and
enum names are compared without the contract that declares them, and a contract type counts as an
address.

ERC-7201 namespaced storage
  Variables in a struct marked `@custom:storage-location erc7201:<id>` are not in solc's layout
  output. layout reads those structs from the syntax tree that `forge build --ast` puts in each
  artifact, for the contract and every contract it inherits from, lays out their fields the way solc
  lays out a struct, and compares them namespace by namespace with the same lines as above. The label
  is `erc7201:<id>.<field>` and the slot counts from the namespace's own slot. A namespace that is gone
  from the new version has every field removed. layout prints `not-compared` instead, and never
  `compatible` for that contract, when an artifact has no syntax tree (forge inspect output, or a build
  without --ast), when a base contract is in no artifact given (pass the out/ folder rather than one
  artifact), when the build mixes compiler runs, or when a field's type cannot be laid out.

Lines from abi
  removed-function <contract> <signature>   (receive() and fallback() included)
  changed-function <contract> <signature> outputs (<old>) -> (<new>)
  changed-function <contract> <signature> stateMutability <old> -> <new>
  removed-event <contract> <signature>
  changed-event <contract> <signature> indexed (<old>) -> (<new>), or anonymous <old> -> <new>
  removed-error <contract> <signature>
Additions are compatible and are not printed.

Lines from opcodes
  opcode <contract> <runtime|creation> <OPCODE> needs <fork>
The runtime code is the deployed bytecode without solc's CBOR metadata; the creation code is the part
of the bytecode before the runtime code, which runs the constructor. Push data is skipped, and library
placeholders count as zero bytes. EVM versions, oldest first: homestead, tangerineWhistle,
spuriousDragon, byzantium, constantinople, petersburg, istanbul, berlin, london, paris, shanghai,
cancun, prague, osaka.

An item is a Markdown file whose front matter holds `topic` (layout, evm, or tools), `subject`,
`checked` (YYYY-MM-DD), and `source`.

Exit codes: 0 fine, 1 problems, 2 wrong use or nothing to compare.
The checks read only the JSON files they are given or find in the folders, and never read keys or
.env files.
"""
import argparse
import datetime
import json
import os
import re
import sys
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent.parent
ITEMS_DIR = SKILL_DIR / "references" / "items"
TOPICS = ("layout", "evm", "tools")
FRESH_DAYS = 90

FORKS = ("homestead", "tangerineWhistle", "spuriousDragon", "byzantium", "constantinople", "petersburg",
         "istanbul", "berlin", "london", "paris", "shanghai", "cancun", "prague", "osaka")
NEW_OPCODES = {
    0x3d: ("RETURNDATASIZE", "byzantium"), 0x3e: ("RETURNDATACOPY", "byzantium"),
    0xfa: ("STATICCALL", "byzantium"), 0xfd: ("REVERT", "byzantium"),
    0x1b: ("SHL", "constantinople"), 0x1c: ("SHR", "constantinople"), 0x1d: ("SAR", "constantinople"),
    0x3f: ("EXTCODEHASH", "constantinople"), 0xf5: ("CREATE2", "constantinople"),
    0x46: ("CHAINID", "istanbul"), 0x47: ("SELFBALANCE", "istanbul"),
    0x48: ("BASEFEE", "london"),
    0x5f: ("PUSH0", "shanghai"),
    0x49: ("BLOBHASH", "cancun"), 0x4a: ("BLOBBASEFEE", "cancun"),
    0x5c: ("TLOAD", "cancun"), 0x5d: ("TSTORE", "cancun"), 0x5e: ("MCOPY", "cancun"),
    0x1e: ("CLZ", "osaka"),
}
PLACEHOLDER = re.compile(r"__\$[0-9a-fA-F]{34}\$__")
QUALIFIED = re.compile(r"\b(struct|enum) [A-Za-z_$][\w$]*\.")
CONTRACT_TYPE = re.compile(r"^contract [A-Za-z_$][\w$]*$")
ARRAY_LENGTH = re.compile(r"\[(\d+)\]$")
STORAGE_LOCATION = re.compile(r"@custom:storage-location\s+([A-Za-z0-9_]+:\S+)")
DATA_LOCATION = re.compile(r" (?:storage ref|storage pointer|storage|memory|calldata)\b")
INT_CONST = re.compile(r"^int_const (\d+)$")
SIZED = re.compile(r"^(u?int|bytes|u?fixed)(\d+)(?:x\d+)?$")
DECLARATIONS = ("ContractDefinition", "StructDefinition", "EnumDefinition", "UserDefinedValueTypeDefinition")


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
        print("release-check: %d problem%s; fix the front matter of each item named above"
              % (len(problems), "" if len(problems) == 1 else "s"))
        return 1
    print("release-check: ok (%d items)" % len(items))
    return 0


def cmd_list(args):
    items, problems = load_items(args.dir)
    if problems:
        for problem in problems:
            print(problem, file=sys.stderr)
        print("release-check: the items have problems; run check and fix them first", file=sys.stderr)
        return 2
    try:
        today = datetime.date.fromisoformat(args.today) if args.today else datetime.datetime.now(datetime.timezone.utc).date()
    except ValueError:
        print("release-check: --today takes a date such as 2026-11-17", file=sys.stderr)
        return 2
    stale = 0
    for item in items:
        old = (today - item["checked_date"]).days > FRESH_DAYS
        stale += old
        print("%-6s %-7s %s %s %s" % ("stale" if old else "ok", item["topic"], item["checked"],
                                      item["name"], item["subject"]))
    print("%d items, %d stale as of %s" % (len(items), stale, today.isoformat()))
    return 0


# ---- reading build output ----------------------------------------------------------------------

class UseError(Exception):
    """Wrong use or nothing to compare; the message goes to stderr and the exit code is 2."""


def read_json(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise UseError("cannot read %s: %s" % (path, type(error).__name__))


def artifact_files(folder):
    """(key, contract name, path) for each artifact in a build folder, leaving out tests, scripts,
    build-info, debug files, and hidden folders."""
    root = Path(folder)
    for current, dirs, files in os.walk(root):
        dirs[:] = sorted(d for d in dirs if d != "build-info" and not d.startswith(".")
                         and not d.endswith((".t.sol", ".s.sol")))
        for name in sorted(files):
            if name.endswith(".json") and not name.endswith(".dbg.json"):
                path = Path(current) / name
                yield path.relative_to(root).as_posix(), path.stem, path


def side(path, pick, contract, visit=None):
    """{key: (name, part, data)} for one side of a comparison. pick(data) returns the part compared,
    or None when the file holds none; visit(data), when given, sees every file read."""
    p = Path(path)
    found = {}
    if p.is_dir():
        for key, name, file in artifact_files(p):
            try:
                data = json.loads(file.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                continue
            if visit:
                visit(data)
            part = pick(data) if isinstance(data, (dict, list)) else None
            if part is not None and (contract is None or name == contract):
                found[key] = (name, part, data)
    elif p.is_file():
        data = read_json(p)
        if visit:
            visit(data)
        part = pick(data)
        if part is None:
            raise UseError("%s holds nothing to compare" % path)
        found[p.name] = (file_contract(data, p), part, data)
    else:
        raise UseError("%s is neither a file nor a folder" % path)
    return found


def file_contract(data, path):
    """The contract named in a layout's entries (`src/Vault.sol:Vault`), or the file's name."""
    layout = data.get("storageLayout", data) if isinstance(data, dict) else None
    if isinstance(layout, dict):
        for entry in layout.get("storage") or []:
            if ":" in str(entry.get("contract", "")):
                return entry["contract"].rsplit(":", 1)[1]
    if isinstance(data, dict) and data.get("contractName"):
        return data["contractName"]
    return path.name.split(".")[0]


def pairs(old_path, new_path, pick, contract, new_contract, visit_old=None, visit_new=None):
    """The (name, old, new) to compare, where old and new are each (name, part, data)."""
    old = side(old_path, pick, contract, visit_old)
    new = side(new_path, pick, new_contract or contract, visit_new)
    if new_contract or len(old) == 1 and len(new) == 1 and not (Path(old_path).is_dir() and Path(new_path).is_dir()):
        if len(old) != 1 or len(new) != 1:
            raise UseError("name one contract on each side: found %d old and %d new" % (len(old), len(new)))
        o, n = next(iter(old.values())), next(iter(new.values()))
        return [(n[0], o, n)]
    if Path(old_path).is_dir() and Path(new_path).is_dir():
        keys = sorted(set(old) & set(new))
    else:
        by_name = {v[0]: k for k, v in new.items()}
        keys = [k for k in old if old[k][0] in by_name]
        new = {k: new[by_name[old[k][0]]] for k in keys}
    if not keys:
        raise UseError("no contract is in both %s and %s; name them with --contract and --new-contract"
                       % (old_path, new_path))
    return [(new[k][0], old[k], new[k]) for k in keys]


# ---- layout ------------------------------------------------------------------------------------

def pick_layout(data):
    if isinstance(data, dict):
        layout = data.get("storageLayout", data)
        if isinstance(layout, dict) and isinstance(layout.get("storage"), list):
            return layout
    return None


def plain(label):
    label = QUALIFIED.sub(r"\1 ", label or "")
    return "address" if CONTRACT_TYPE.match(label) else label


def shape(types, type_id, depth=0):
    """A description of a type that changes exactly when its storage changes."""
    t = types.get(type_id) or {}
    if depth > 32:
        return type_id
    encoding = t.get("encoding")
    if encoding == "mapping":
        return "mapping(%s=>%s)" % (shape(types, t.get("key"), depth + 1), shape(types, t.get("value"), depth + 1))
    if t.get("members"):
        return "struct{%s}" % ",".join("%s:%s@%s:%s" % (m.get("label"), shape(types, m.get("type"), depth + 1),
                                                         m.get("slot"), m.get("offset")) for m in t["members"])
    if encoding == "dynamic_array":
        return "%s[]" % shape(types, t.get("base"), depth + 1)
    if t.get("base"):
        length = ARRAY_LENGTH.search(t.get("label", ""))
        return "%s[%s]" % (shape(types, t.get("base"), depth + 1), length.group(1) if length else t.get("numberOfBytes"))
    return "%s:%s" % (plain(t.get("label", type_id)), t.get("numberOfBytes"))


def slots(types, entry):
    size = int((types.get(entry["type"]) or {}).get("numberOfBytes") or 32)
    return int(entry["slot"]), (int(entry.get("offset") or 0) + size + 31) // 32


def is_gap(label):
    return str(label).startswith("__gap")


def compare_layout(name, old, new, prefix=""):
    """(problem lines, renamed lines) for one contract, or one namespace of it when the labels carry
    the namespace as their prefix."""
    old_types, new_types = old.get("types") or {}, new.get("types") or {}
    old_vars, new_vars = old["storage"], new["storage"]
    used = set()
    problems, renamed = [], []

    def place(e):
        return int(e["slot"]), int(e.get("offset") or 0)

    for o in old_vars:
        label = prefix + o["label"]
        match = next((i for i, n in enumerate(new_vars) if i not in used and n["label"] == o["label"]), None)
        if match is not None:
            used.add(match)
            n = new_vars[match]
            if is_gap(o["label"]):
                old_start, old_count = slots(old_types, o)
                new_start, new_count = slots(new_types, n)
                if old_start + old_count != new_start + new_count:
                    problems.append("gap %s %s ends at slot %d instead of %d"
                                    % (name, label, new_start + new_count, old_start + old_count))
                continue
            if place(o) != place(n):
                problems.append("moved %s %s %d:%d -> %d:%d" % ((name, label) + place(o) + place(n)))
            old_shape, new_shape = shape(old_types, o["type"]), shape(new_types, n["type"])
            if old_shape != new_shape:
                old_label = plain((old_types.get(o["type"]) or {}).get("label", o["type"]))
                new_label = plain((new_types.get(n["type"]) or {}).get("label", n["type"]))
                if old_label == new_label:
                    problems.append("retyped %s %s %s changed inside" % (name, label, old_label))
                else:
                    problems.append("retyped %s %s %s -> %s" % (name, label, old_label, new_label))
            continue
        if is_gap(o["label"]):
            continue
        same_place = next((i for i, n in enumerate(new_vars)
                           if i not in used and place(n) == place(o)
                           and not any(x["label"] == n["label"] for x in old_vars)), None)
        if same_place is not None and shape(old_types, o["type"]) == shape(new_types, new_vars[same_place]["type"]):
            used.add(same_place)
            renamed.append("renamed %s %s -> %s slot %d offset %d"
                           % ((name, label, prefix + new_vars[same_place]["label"]) + place(o)))
            continue
        problems.append("removed %s %s slot %d offset %d" % ((name, label) + place(o)))
    return problems, renamed


# ---- ERC-7201 namespaced storage ---------------------------------------------------------------

class AstIndex:
    """The contracts, structs, enums, and user-defined value types of the syntax trees on one side,
    by node id. An id that names two different declarations means the build mixes compiler runs."""

    def __init__(self):
        self.nodes, self.clashes = {}, set()

    def add(self, data):
        unit = data.get("ast") if isinstance(data, dict) else None
        if not isinstance(unit, dict) or unit.get("nodeType") != "SourceUnit":
            return
        for node in unit.get("nodes") or []:
            self.keep(node)
            if isinstance(node, dict) and node.get("nodeType") == "ContractDefinition":
                for child in node.get("nodes") or []:
                    self.keep(child)

    def keep(self, node):
        if not isinstance(node, dict) or node.get("nodeType") not in DECLARATIONS:
            return
        seen = self.nodes.setdefault(node.get("id"), node)
        if (seen.get("nodeType"), seen.get("canonicalName", seen.get("name"))) != \
                (node.get("nodeType"), node.get("canonicalName", node.get("name"))):
            self.clashes.add(node.get("id"))

    def get(self, node_id):
        """(node, None), or (None, why) when the id is in no syntax tree read or names two nodes."""
        if node_id in self.clashes:
            return None, "clash"
        node = self.nodes.get(node_id)
        return (node, None) if node is not None else (None, "missing")


class Unsized(Exception):
    """A type whose storage cannot be worked out from the syntax trees read."""


def packed(t):
    """Whether a type is a value that shares a slot with its neighbours."""
    return t["encoding"] == "inplace" and not t.get("members") and not t.get("base")


class Layouter:
    """Lays out structs the way solc does, into a `types` table shaped like solc's storageLayout."""

    def __init__(self, index):
        self.index, self.types = index, {}

    def add(self, label, size, encoding="inplace", **parts):
        type_id = "t%d" % len(self.types)
        self.types[type_id] = dict(parts, label=label, numberOfBytes=str(size), encoding=encoding)
        return type_id

    def type_of(self, type_name, depth):
        if not isinstance(type_name, dict):
            raise Unsized("a type the syntax tree does not spell out")
        if depth > 32:
            raise Unsized("a type nested too deep")
        kind = type_name.get("nodeType")
        label = DATA_LOCATION.sub("", (type_name.get("typeDescriptions") or {}).get("typeString")
                                  or type_name.get("name") or "")
        if kind == "ElementaryTypeName":
            return self.elementary(label)
        if kind == "Mapping":
            return self.add(label, 32, "mapping", key=self.type_of(type_name.get("keyType"), depth + 1),
                            value=self.type_of(type_name.get("valueType"), depth + 1))
        if kind == "ArrayTypeName":
            base = self.type_of(type_name.get("baseType"), depth + 1)
            if type_name.get("length") is None:
                return self.add(label, 32, "dynamic_array", base=base)
            length = ARRAY_LENGTH.search(label) or INT_CONST.match(
                ((type_name["length"] or {}).get("typeDescriptions") or {}).get("typeString") or "")
            if not length:
                raise Unsized(label)
            count, t = int(length.group(1)), self.types[base]
            size = int(t["numberOfBytes"])
            used = -(-count // (32 // size)) if packed(t) else count * -(-size // 32)
            return self.add(label, used * 32, base=base)
        if kind == "FunctionTypeName":
            return self.add(label, 24 if type_name.get("visibility") == "external" else 8)
        if kind == "UserDefinedTypeName":
            if label.startswith("contract "):
                return self.add(label, 20)
            if label.startswith("enum "):
                return self.add(label, 1)
            node, _ = self.index.get(type_name.get("referencedDeclaration"))
            if node is None:
                raise Unsized(label)
            if node["nodeType"] == "StructDefinition":
                members, used = self.struct(node, depth + 1)
                return self.add(label, used * 32, members=members)
            if node["nodeType"] == "UserDefinedValueTypeDefinition":
                underlying = node.get("underlyingType") or {}
                size = int(self.types[self.elementary(underlying.get("name") or "")]["numberOfBytes"])
                return self.add(label, size)
            return self.add(label, 1 if node["nodeType"] == "EnumDefinition" else 20)
        raise Unsized(label or "an unknown type")

    def elementary(self, label):
        if label in ("string", "bytes"):
            return self.add(label, 32, "bytes")
        if label in ("bool", "address", "address payable"):
            return self.add(label, 1 if label == "bool" else 20)
        if label in ("uint", "int", "fixed", "ufixed"):
            return self.add(label, 32 if label.endswith("int") else 16)
        sized = SIZED.match(label)
        if not sized:
            raise Unsized(label)
        bits = int(sized.group(2))
        return self.add(label, bits if sized.group(1) == "bytes" else bits // 8)

    def struct(self, node, depth=0):
        """(members as solc's storageLayout writes them, slots used) for one struct."""
        members, slot, offset = [], 0, 0
        for member in node.get("members") or []:
            try:
                type_id = self.type_of(member.get("typeName"), depth + 1)
            except Unsized as error:
                raise Unsized("cannot lay out field %s (%s)" % (member.get("name"), error)) if depth == 0 else error
            t = self.types[type_id]
            size = int(t["numberOfBytes"])
            if offset and (not packed(t) or offset + size > 32):
                slot, offset = slot + 1, 0
            members.append({"label": member.get("name"), "slot": str(slot), "offset": offset, "type": type_id})
            if packed(t):
                offset += size
            else:
                slot, offset = slot + -(-size // 32), 0
            if offset >= 32:
                slot, offset = slot + 1, 0
        return members, slot + (1 if offset else 0)


def storage_location(node):
    """`erc7201:<id>` for a struct marked as namespaced storage, else None."""
    if not isinstance(node, dict) or node.get("nodeType") != "StructDefinition":
        return None
    doc = node.get("documentation")
    text = doc.get("text") if isinstance(doc, dict) else doc
    match = STORAGE_LOCATION.search(text or "")
    return match.group(1) if match else None


def namespaces(index, data, contract):
    """(laid out, unsized, why) for one side of one contract: each namespace of the contract and its
    bases as a layout, each namespace whose fields cannot be laid out with the reason, and why the
    contract's namespaces cannot all be known (no syntax tree, a missing base, mixed runs), or None."""
    unit = data.get("ast") if isinstance(data, dict) else None
    if not isinstance(unit, dict):
        return {}, {}, "no AST"
    node = next((n for n in unit.get("nodes") or [] if isinstance(n, dict)
                 and n.get("nodeType") == "ContractDefinition" and n.get("name") == contract), None)
    if node is None:
        return {}, {}, "no contract"
    laid, unsized, why = {}, {}, None
    for base_id in node.get("linearizedBaseContracts") or [node.get("id")]:
        base, missing = (node, None) if base_id == node.get("id") else index.get(base_id)
        if base is None:
            why = why or ("mixed runs" if missing == "clash" else "missing base")
            continue
        for child in base.get("nodes") or []:
            namespace = storage_location(child)
            if namespace is None or namespace in laid or namespace in unsized:
                continue
            layouter = Layouter(index)
            try:
                members, _ = layouter.struct(child)
                laid[namespace] = {"storage": members, "types": layouter.types}
            except Unsized as error:
                unsized[namespace] = str(error)
    return laid, unsized, why


REASONS = {"no AST": "the %s build has no AST; build it with --ast",
           "no contract": "the AST in the %s build does not declare the contract",
           "missing base": "a base contract is in no artifact of the %s build; pass the whole out/ folder",
           "mixed runs": "the %s build mixes compiler runs; rebuild it into an empty folder"}


BOTH = {"no AST": "neither build has an AST; build both with --ast",
        "no contract": "the AST in neither build declares the contract",
        "missing base": "a base contract is in no artifact given; pass the whole out/ folders",
        "mixed runs": "both builds mix compiler runs; rebuild them into empty folders"}


def unread_reason(old_why, new_why):
    if old_why == new_why:
        return BOTH[old_why]
    return "; ".join(REASONS[why] % which for which, why in (("old", old_why), ("new", new_why)) if why)


def compare_namespaces(name, old, old_index, new, new_index):
    """(problem lines, renamed lines, not-compared lines, namespaces compared) for one contract."""
    old_laid, old_unsized, old_why = namespaces(old_index, old[2], old[0])
    new_laid, new_unsized, new_why = namespaces(new_index, new[2], new[0])
    if old_why or new_why:
        why = unread_reason(old_why, new_why)
        known = sorted(set(old_laid) | set(old_unsized) | set(new_laid) | set(new_unsized))
        return [], [], (["not-compared %s %s: %s" % (name, ns, why) for ns in known]
                        or ["not-compared %s namespaces: %s" % (name, why)]), 0
    problems, renamed, unread, compared = [], [], [], 0
    for ns in sorted(set(old_laid) | set(old_unsized)):
        if ns in old_unsized or ns in new_unsized:
            unread.append("not-compared %s %s: %s" % (name, ns, old_unsized.get(ns) or new_unsized.get(ns)))
            continue
        p, r = compare_layout(name, old_laid[ns], new_laid.get(ns, {"storage": [], "types": {}}), ns + ".")
        problems += p
        renamed += r
        compared += 1
    return problems, renamed, unread, compared


def cmd_layout(args):
    old_index, new_index = AstIndex(), AstIndex()
    found = pairs(args.old, args.new, pick_layout, args.contract, args.new_contract, old_index.add, new_index.add)
    problems, renamed, unread, unread_contracts, compared = [], [], [], set(), 0
    for name, old, new in found:
        p, r = compare_layout(name, old[1], new[1])
        problems += p
        renamed += r
        p, r, u, c = compare_namespaces(name, old, old_index, new, new_index)
        problems += p
        renamed += r
        unread += u
        compared += c
        if u:
            unread_contracts.add(name)
    for line in problems + renamed + unread:
        print(line)
    contracts = "%d contract%s compared" % (len(found), "" if len(found) == 1 else "s")
    if problems:
        print("layout: %d problem%s in %s (%d renamed)" % (len(problems), "" if len(problems) == 1 else "s",
                                                          contracts, len(renamed)))
        return 1
    if unread:
        print("layout: namespaced storage not compared in %d of %d contract%s (%d renamed)"
              % (len(unread_contracts), len(found), "" if len(found) == 1 else "s", len(renamed)))
        return 1
    print("layout: compatible (%s, %d namespace%s, %d renamed)"
          % (contracts, compared, "" if compared == 1 else "s", len(renamed)))
    return 0


# ---- abi ---------------------------------------------------------------------------------------

def pick_abi(data):
    if isinstance(data, list):
        return data
    if isinstance(data, dict) and isinstance(data.get("abi"), list):
        return data["abi"]
    return None


def param_type(p):
    t = p.get("type", "")
    if t.startswith("tuple"):
        return "(%s)%s" % (",".join(param_type(c) for c in p.get("components") or []), t[5:])
    return t


def signature(entry):
    return "%s(%s)" % (entry.get("name", ""), ",".join(param_type(p) for p in entry.get("inputs") or []))


def abi_entries(abi):
    """{kind: {signature: entry}} with receive and fallback as functions."""
    out = {"function": {}, "event": {}, "error": {}}
    for entry in abi:
        kind = entry.get("type", "function")
        if kind in ("receive", "fallback"):
            out["function"]["%s()" % kind] = entry
        elif kind in out:
            out[kind][signature(entry)] = entry
    return out


def flags(values):
    return "(%s)" % ",".join("true" if v else "false" for v in values)


def compare_abi(name, old, new):
    old_entries, new_entries = abi_entries(old), abi_entries(new)
    lines = []
    for sig, o in old_entries["function"].items():
        n = new_entries["function"].get(sig)
        if n is None:
            lines.append("removed-function %s %s" % (name, sig))
            continue
        old_out = ",".join(param_type(p) for p in o.get("outputs") or [])
        new_out = ",".join(param_type(p) for p in n.get("outputs") or [])
        if old_out != new_out:
            lines.append("changed-function %s %s outputs (%s) -> (%s)" % (name, sig, old_out, new_out))
        if o.get("stateMutability") != n.get("stateMutability"):
            lines.append("changed-function %s %s stateMutability %s -> %s"
                         % (name, sig, o.get("stateMutability"), n.get("stateMutability")))
    for sig, o in old_entries["event"].items():
        n = new_entries["event"].get(sig)
        if n is None:
            lines.append("removed-event %s %s" % (name, sig))
            continue
        old_indexed = [bool(p.get("indexed")) for p in o.get("inputs") or []]
        new_indexed = [bool(p.get("indexed")) for p in n.get("inputs") or []]
        if old_indexed != new_indexed:
            lines.append("changed-event %s %s indexed %s -> %s" % (name, sig, flags(old_indexed), flags(new_indexed)))
        if bool(o.get("anonymous")) != bool(n.get("anonymous")):
            lines.append("changed-event %s %s anonymous %s -> %s" % (name, sig, str(bool(o.get("anonymous"))).lower(),
                                                                     str(bool(n.get("anonymous"))).lower()))
    for sig in old_entries["error"]:
        if sig not in new_entries["error"]:
            lines.append("removed-error %s %s" % (name, sig))
    return lines


def cmd_abi(args):
    found = pairs(args.old, args.new, pick_abi, args.contract, args.new_contract)
    lines = []
    for name, old, new in found:
        lines += compare_abi(name, old[1], new[1])
    for line in lines:
        print(line)
    contracts = "%d contract%s compared" % (len(found), "" if len(found) == 1 else "s")
    if lines:
        print("abi: %d breaking change%s in %s" % (len(lines), "" if len(lines) == 1 else "s", contracts))
        return 1
    print("abi: compatible (%s)" % contracts)
    return 0


# ---- opcodes -----------------------------------------------------------------------------------

def hex_bytes(value):
    """Bytes from a hex string, with library placeholders as zero bytes; None when it is not hex."""
    if isinstance(value, dict):
        value = value.get("object")
    if not isinstance(value, str):
        return None
    text = value[2:] if value.startswith("0x") else value
    text = PLACEHOLDER.sub("0" * 40, text)
    text = re.sub(r"[^0-9a-fA-F]", "0", text)
    if len(text) % 2:
        return None
    return bytes.fromhex(text)


def without_metadata(code):
    """The code without solc's CBOR metadata, whose length sits in the last two bytes."""
    if len(code) >= 2:
        length = int.from_bytes(code[-2:], "big")
        if 0 < length and length + 2 <= len(code) and 0xa1 <= code[-(length + 2)] <= 0xa5:
            return code[:-(length + 2)]
    return code


def opcodes_in(code):
    """The set of opcodes in the code, skipping push data."""
    seen, i = set(), 0
    while i < len(code):
        op = code[i]
        seen.add(op)
        i += 1 + (op - 0x5f if 0x60 <= op <= 0x7f else 0)
    return seen


def bytecode_parts(data):
    """(creation code before the runtime, runtime code), or None when the artifact holds no code."""
    if not isinstance(data, dict):
        return None
    creation, runtime = hex_bytes(data.get("bytecode")), hex_bytes(data.get("deployedBytecode"))
    if not runtime:
        return None
    init = b""
    if creation:
        if creation.endswith(runtime):
            init = creation[:-len(runtime)]
        elif runtime in creation:
            init = creation[:creation.index(runtime)]
        else:
            init = without_metadata(creation)
    return init, without_metadata(runtime)


def cmd_opcodes(args):
    forks = {f.lower(): f for f in FORKS}
    evm = forks.get(args.evm.lower())
    if evm is None:
        print("release-check: unknown EVM version %s; known versions, oldest first: %s"
              % (args.evm, ", ".join(FORKS)), file=sys.stderr)
        return 2
    target = FORKS.index(evm)
    path = Path(args.build)
    if path.is_dir():
        files = [(name, file) for _, name, file in artifact_files(path)]
    elif path.is_file():
        files = [(path.stem, path)]
    else:
        print("release-check: %s is neither a file nor a folder" % args.build, file=sys.stderr)
        return 2
    lines, contracts = [], 0
    for stem, file in files:
        try:
            data = json.loads(file.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        parts = bytecode_parts(data)
        if parts is None:
            continue
        name = data.get("contractName") or stem
        if args.contract and name != args.contract:
            continue
        contracts += 1
        for part, code in (("runtime", parts[1]), ("creation", parts[0])):
            missing = [NEW_OPCODES[op] for op in opcodes_in(code)
                       if op in NEW_OPCODES and FORKS.index(NEW_OPCODES[op][1]) > target]
            for op_name, fork in sorted(missing, key=lambda m: (FORKS.index(m[1]), m[0])):
                lines.append("opcode %s %s %s needs %s" % (name, part, op_name, fork))
    if not contracts:
        print("release-check: no bytecode found in %s; build the project first" % args.build, file=sys.stderr)
        return 2
    for line in lines:
        print(line)
    counted = "%d contract%s" % (contracts, "" if contracts == 1 else "s")
    if lines:
        print("opcodes: %d opcode%s the %s EVM lacks in %s" % (len(lines), "" if len(lines) == 1 else "s", evm, counted))
        return 1
    print("opcodes: every opcode runs on %s (%s)" % (evm, counted))
    return 0


def main(argv):
    parser = argparse.ArgumentParser(prog="release-check.py", description=__doc__.split("\n\n")[0],
                                     epilog="Exit codes: 0 fine, 1 problems, 2 wrong use or nothing to compare.")
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("check", help="validate the items")
    p.add_argument("--dir", default=str(ITEMS_DIR), help="folder of items (default: the bundled items)")
    p = sub.add_parser("list", help="list the items and mark the stale ones")
    p.add_argument("--dir", default=str(ITEMS_DIR), help="folder of items (default: the bundled items)")
    p.add_argument("--today", help="count the days to this date (YYYY-MM-DD) instead of today in UTC")
    for command, text in (("layout", "compare two storage layouts"), ("abi", "compare two ABIs")):
        p = sub.add_parser(command, help=text)
        p.add_argument("old")
        p.add_argument("new")
        p.add_argument("--contract", help="compare only this contract (the old one when --new-contract is given)")
        p.add_argument("--new-contract", help="the name of the new contract, when it differs from the old one")
    p = sub.add_parser("opcodes", help="name each opcode the target EVM version lacks")
    p.add_argument("build")
    p.add_argument("--evm", required=True, help="the target chain's EVM version, such as cancun or osaka")
    p.add_argument("--contract", help="check only this contract")
    args = parser.parse_args(argv)
    commands = {"check": cmd_check, "list": cmd_list, "layout": cmd_layout, "abi": cmd_abi, "opcodes": cmd_opcodes}
    try:
        return commands[args.command](args)
    except UseError as error:
        print("release-check: %s" % error, file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
