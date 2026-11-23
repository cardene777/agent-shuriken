#!/usr/bin/env bash
# Tests for release-check.py, the bundled items, the SKILL.md, and the eval suite. Storage layouts,
# syntax trees, ABIs, and bytecode written here follow what forge 1.5 and solc 0.8.30 write, live in a
# throwaway folder, and are built by hand; nothing reaches the network and nothing runs forge or
# Hardhat.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
SCRIPT="$SKILL_DIR/scripts/release-check.py"
ITEMS="$SKILL_DIR/references/items"
SKILL="$SKILL_DIR/SKILL.md"
PLUGIN="$(cd "$SKILL_DIR/../.." && pwd)"
REPO="$(cd "$PLUGIN/../.." && pwd)"
EVALS="$PLUGIN/evals"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }

run() { python3 "$SCRIPT" "$@"; }

TOPICS=(layout evm tools)

# item <folder> <name> <field lines...>: writes one item file with the given front matter lines.
item() {
  local d="$1" name="$2" line
  shift 2
  mkdir -p "$d"
  {
    printf -- '---\n'
    for line in "$@"; do printf '%s\n' "$line"; done
    printf -- '---\n\n# %s\n\nBody.\n' "$name"
  } > "$d/$name.md"
}

bundled_check() {
  local t
  [ -f "$SCRIPT" ] || return 1
  run check > "$T/bundled.out" 2>&1 || return 1
  for t in "${TOPICS[@]}"; do
    grep -rqx "topic: $t" "$ITEMS" || return 1
  done
}
check "check passes on the bundled release-check items and covers every topic" bundled_check

bad_items_named() {
  local d="$T/bad" code
  item "$d" good-item 'topic: layout' 'subject: A layout check' 'checked: 2026-11-01' 'source: The vendor, documentation'
  item "$d" no-source 'topic: evm' 'subject: An EVM version' 'checked: 2026-11-01'
  item "$d" no-subject 'topic: tools' 'checked: 2026-11-01' 'source: The tool, reference'
  item "$d" unknown-topic 'topic: gas' 'subject: Gas prices' 'checked: 2026-11-01' 'source: The tool'
  item "$d" bad-date 'topic: layout' 'subject: Namespaced storage' 'checked: 2026-02-30' 'source: The standard'
  run check --dir "$d" > "$T/bad.out" 2>&1
  code=$?
  [ "$code" -eq 1 ] || return 1
  grep -q 'no-source' "$T/bad.out" && grep -q 'no-subject' "$T/bad.out" && grep -q 'unknown-topic' "$T/bad.out" \
    && grep -q 'bad-date' "$T/bad.out" && ! grep -q 'good-item' "$T/bad.out"
}
check "check names a release-check item with a missing field, an unknown topic, or an impossible date" bad_items_named

# Counted to 2026-05-01: 2026-01-31 is exactly 90 days old (still ok), 2026-01-30 is 91 (stale).
stale_marked() {
  local d="$T/stale"
  item "$d" edge-item 'topic: evm' 'subject: Chain EVM versions' 'checked: 2026-01-31' 'source: The chains, documentation'
  item "$d" old-item 'topic: tools' 'subject: Gas snapshots' 'checked: 2026-01-30' 'source: The tool, reference'
  run list --dir "$d" --today 2026-05-01 > "$T/list.out" 2>&1 || return 1
  grep -Eq '^ok +evm +2026-01-31 +edge-item +Chain EVM versions$' "$T/list.out" \
    && grep -Eq '^stale +tools +2026-01-30 +old-item +Gas snapshots$' "$T/list.out" \
    && grep -Eq '^2 items, 1 stale as of 2026-05-01$' "$T/list.out"
}
check "list marks the release-check items checked more than 90 days ago" stale_marked

# layouts <folder>: writes storage layouts in the shape forge writes. The old version is a Base
# contract (owner, then a 49-slot gap) under Vault (total and fee sharing a slot, a mapping to a
# Position struct, a dynamic array of users). Each new version changes one set of things.
layouts() {
  python3 - "$1" <<'PYEOF'
import json, os, sys
root = sys.argv[1]
os.makedirs(root, exist_ok=True)

def entry(label, slot, typ, offset=0, contract="src/Vault.sol:Vault"):
    return {"astId": 1, "contract": contract, "label": label, "offset": offset, "slot": str(slot), "type": typ}

def types(struct_id="17", struct_owner="Vault", position=None, gap=49, total="t_uint128", fee="t_uint64"):
    position = position or [("amount", 0, 0, "t_uint128"), ("since", 0, 16, "t_uint64"), ("active", 0, 24, "t_bool")]
    s = "t_struct(Position)%s_storage" % struct_id
    t = {
        "t_address": {"encoding": "inplace", "label": "address", "numberOfBytes": "20"},
        "t_bool": {"encoding": "inplace", "label": "bool", "numberOfBytes": "1"},
        "t_uint32": {"encoding": "inplace", "label": "uint32", "numberOfBytes": "4"},
        "t_uint64": {"encoding": "inplace", "label": "uint64", "numberOfBytes": "8"},
        "t_uint128": {"encoding": "inplace", "label": "uint128", "numberOfBytes": "16"},
        "t_uint256": {"encoding": "inplace", "label": "uint256", "numberOfBytes": "32"},
        "t_array(t_address)dyn_storage": {"encoding": "dynamic_array", "label": "address[]", "numberOfBytes": "32", "base": "t_address"},
        "t_array(t_uint256)%d_storage" % gap: {"encoding": "inplace", "label": "uint256[%d]" % gap, "numberOfBytes": str(32 * gap), "base": "t_uint256"},
        "t_mapping(t_address,%s)" % s: {"encoding": "mapping", "label": "mapping(address => struct %s.Position)" % struct_owner,
                                         "numberOfBytes": "32", "key": "t_address", "value": s},
        s: {"encoding": "inplace", "label": "struct %s.Position" % struct_owner, "numberOfBytes": "32",
            "members": [entry(l, sl, ty, off) for (l, sl, off, ty) in position]},
    }
    return t, s

def write(name, storage, t):
    with open(os.path.join(root, name), "w", encoding="utf-8") as f:
        json.dump({"storage": storage, "types": t}, f, indent=2)

t, s = types()
old = [entry("owner", 0, "t_address"), entry("__gap", 1, "t_array(t_uint256)49_storage"),
       entry("total", 50, "t_uint128"), entry("fee", 50, "t_uint64", 16),
       entry("positions", 51, "t_mapping(t_address,%s)" % s), entry("users", 52, "t_array(t_address)dyn_storage")]
write("old.json", old, t)

# Compatible: a bool packed into owner's slot, a new variable at the start of the gap with the gap
# shrunk by one, a new variable at the end, and the contract renamed to VaultV2 (new struct id).
t2, s2 = types(struct_id="42", struct_owner="VaultV2", gap=48)
good = [entry("owner", 0, "t_address", contract="src/VaultV2.sol:VaultV2"),
        entry("paused", 0, "t_bool", 20, contract="src/VaultV2.sol:VaultV2"),
        entry("cap", 1, "t_uint256", contract="src/VaultV2.sol:VaultV2"),
        entry("__gap", 2, "t_array(t_uint256)48_storage", contract="src/VaultV2.sol:VaultV2"),
        entry("total", 50, "t_uint128", contract="src/VaultV2.sol:VaultV2"),
        entry("fee", 50, "t_uint64", 16, contract="src/VaultV2.sol:VaultV2"),
        entry("positions", 51, "t_mapping(t_address,%s)" % s2, contract="src/VaultV2.sol:VaultV2"),
        entry("users", 52, "t_array(t_address)dyn_storage", contract="src/VaultV2.sol:VaultV2"),
        entry("version", 53, "t_uint256", contract="src/VaultV2.sol:VaultV2")]
write("good.json", good, t2)

# In place: fee narrowed to uint32, Position's members reordered, users renamed to members, and
# total removed.
t3, s3 = types(position=[("amount", 0, 0, "t_uint128"), ("active", 0, 16, "t_bool"), ("since", 0, 17, "t_uint64")])
inplace = [entry("owner", 0, "t_address"), entry("__gap", 1, "t_array(t_uint256)49_storage"),
           entry("fee", 50, "t_uint32", 16), entry("positions", 51, "t_mapping(t_address,%s)" % s3),
           entry("members", 52, "t_array(t_address)dyn_storage")]
write("inplace.json", inplace, t3)

# Gap: cap added to Base without shrinking the gap, so the gap and everything after it move.
gapped = [entry("owner", 0, "t_address"), entry("cap", 1, "t_uint256"), entry("__gap", 2, "t_array(t_uint256)49_storage"),
          entry("total", 51, "t_uint128"), entry("fee", 51, "t_uint64", 16),
          entry("positions", 52, "t_mapping(t_address,%s)" % s), entry("users", 53, "t_array(t_address)dyn_storage")]
write("gapped.json", gapped, t)
PYEOF
}

# astfix.py: syntax trees in the shape forge 1.5 writes into each artifact with --ast, and artifacts
# that hold one next to a storage layout. Node ids are unique across one build, as in one solc run.
cat > "$T/astfix.py" <<'PYEOF'
import itertools, json, os
_ids = itertools.count(1000)

def _desc(text):
    return {"typeString": text}

def elem(name):
    return {"nodeType": "ElementaryTypeName", "id": next(_ids), "name": name, "typeDescriptions": _desc(name)}

def ref(target, type_string):
    """A type that names a declaration: a contract, a struct, an enum, or a user-defined value type."""
    target_id = target["id"] if isinstance(target, dict) else target
    return {"nodeType": "UserDefinedTypeName", "id": next(_ids), "referencedDeclaration": target_id,
            "typeDescriptions": _desc(type_string)}

def mapping(key, value):
    text = "mapping(%s => %s)" % (key["typeDescriptions"]["typeString"], value["typeDescriptions"]["typeString"])
    return {"nodeType": "Mapping", "id": next(_ids), "keyType": key, "valueType": value, "typeDescriptions": _desc(text)}

def array(base, length=None):
    text = "%s[%s]" % (base["typeDescriptions"]["typeString"], "" if length is None else length)
    size = None if length is None else {"nodeType": "Literal", "id": next(_ids), "value": str(length),
                                        "typeDescriptions": _desc("int_const %d" % length)}
    return {"nodeType": "ArrayTypeName", "id": next(_ids), "baseType": base, "length": size, "typeDescriptions": _desc(text)}

def field(name, type_name):
    return {"nodeType": "VariableDeclaration", "id": next(_ids), "name": name, "typeName": type_name,
            "typeDescriptions": dict(type_name["typeDescriptions"])}

def struct(name, owner, fields, namespace=None):
    node = {"nodeType": "StructDefinition", "id": next(_ids), "name": name, "canonicalName": "%s.%s" % (owner, name),
            "members": list(fields), "visibility": "public"}
    if namespace:
        node["documentation"] = {"nodeType": "StructuredDocumentation", "id": next(_ids),
                                 "text": "@custom:storage-location erc7201:" + namespace}
    return node

def contract(name, nodes=(), bases=(), kind="contract"):
    node = {"nodeType": "ContractDefinition", "id": next(_ids), "name": name, "contractKind": kind,
            "abstract": False, "nodes": list(nodes)}
    order = [node["id"]]
    for base in bases:
        for i in base["linearizedBaseContracts"]:
            if i not in order:
                order.append(i)
    node["linearizedBaseContracts"] = order
    node["baseContracts"] = [{"nodeType": "InheritanceSpecifier", "baseName": {"nodeType": "IdentifierPath",
                              "name": b["name"], "referencedDeclaration": b["id"]}} for b in bases]
    return node

def unit(path, *nodes):
    return {"nodeType": "SourceUnit", "id": next(_ids), "absolutePath": path, "nodes": list(nodes)}

# Places in the source, unique across one build, that tie a Yul identifier to its external reference.
_places = itertools.count(100)

def _place():
    return "%d:6:0" % (next(_places) * 10)

def constant(name, value=None, expression=None):
    """A bytes32 constant whose value is a hex literal, or the given expression node."""
    if expression is None:
        expression = {"nodeType": "Literal", "id": next(_ids), "kind": "number", "value": value,
                      "typeDescriptions": _desc("int_const %d" % int(value, 16))}
    return {"nodeType": "VariableDeclaration", "id": next(_ids), "name": name, "constant": True,
            "mutability": "constant", "stateVariable": True, "typeName": elem("bytes32"), "value": expression,
            "typeDescriptions": _desc("bytes32")}

def slot_expression(text):
    """keccak256(abi.encode(uint256(keccak256(text)) - 1)) & ~bytes32(uint256(0xff)), as solc writes it."""
    def call(callee, *args):
        return {"nodeType": "FunctionCall", "id": next(_ids), "kind": "functionCall", "arguments": list(args),
                "expression": callee}
    def ident(name):
        return {"nodeType": "Identifier", "id": next(_ids), "name": name, "referencedDeclaration": -1}
    def literal(kind, value):
        return {"nodeType": "Literal", "id": next(_ids), "kind": kind, "value": value}
    def conv(name, arg):
        return call({"nodeType": "ElementaryTypeNameExpression", "id": next(_ids), "typeName": elem(name)}, arg)
    inner = {"nodeType": "BinaryOperation", "id": next(_ids), "operator": "-",
             "leftExpression": conv("uint256", call(ident("keccak256"), literal("string", text))),
             "rightExpression": literal("number", "1")}
    encoded = call({"nodeType": "MemberAccess", "id": next(_ids), "memberName": "encode",
                    "expression": ident("abi")}, inner)
    mask = {"nodeType": "UnaryOperation", "id": next(_ids), "operator": "~", "prefix": True,
            "subExpression": conv("bytes32", conv("uint256", literal("number", "0xff")))}
    return {"nodeType": "BinaryOperation", "id": next(_ids), "operator": "&",
            "leftExpression": call(ident("keccak256"), encoded), "rightExpression": mask}

def getter(name, target, slot):
    """A private function that points `$` at the struct target in inline assembly. slot is a constant
    declaration, written as a Yul identifier, or a hex string, written as a Yul literal."""
    pointer = {"nodeType": "VariableDeclaration", "id": next(_ids), "name": "$", "storageLocation": "storage",
               "typeName": ref(target, "struct " + target["canonicalName"]),
               "typeDescriptions": _desc("struct %s storage pointer" % target["canonicalName"])}
    pointer_place = _place()
    references = [{"declaration": pointer["id"], "isOffset": False, "isSlot": True, "src": pointer_place,
                   "suffix": "slot", "valueSize": 1}]
    if isinstance(slot, dict):
        value_place = _place()
        value = {"nodeType": "YulIdentifier", "name": slot["name"], "src": value_place}
        references.append({"declaration": slot["id"], "isOffset": False, "isSlot": False, "src": value_place,
                           "valueSize": 1})
    else:
        value = {"nodeType": "YulLiteral", "kind": "number", "type": "", "value": slot, "src": _place()}
    assembly = {"nodeType": "InlineAssembly", "id": next(_ids), "evmVersion": "prague", "externalReferences": references,
                "AST": {"nodeType": "YulBlock", "statements": [{"nodeType": "YulAssignment", "value": value,
                        "variableNames": [{"nodeType": "YulIdentifier", "name": "$.slot", "src": pointer_place}]}]}}
    return {"nodeType": "FunctionDefinition", "id": next(_ids), "name": name, "kind": "function",
            "visibility": "private", "stateMutability": "pure",
            "parameters": {"nodeType": "ParameterList", "id": next(_ids), "parameters": []},
            "returnParameters": {"nodeType": "ParameterList", "id": next(_ids), "parameters": [pointer]},
            "body": {"nodeType": "Block", "id": next(_ids), "statements": [assembly]}}

def artifact(root, path, ast=None, layout=None):
    p = os.path.join(root, path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    data = {"abi": [], "bytecode": {"object": "0x00"}, "deployedBytecode": {"object": "0x00"},
            "storageLayout": layout or {"storage": [], "types": {}}}
    if ast is not None:
        data["ast"] = ast
    with open(p, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
PYEOF

# The forge inspect layouts of layouts(), wrapped into artifacts that also hold a syntax tree in
# which Vault and VaultV2 keep no namespaced storage.
ast_layouts() {
  python3 - "$1" "$T" <<'PYEOF'
import json, os, sys
root, T = sys.argv[1], sys.argv[2]
sys.path.insert(0, T)
from astfix import artifact, contract, unit
def load(name):
    return json.load(open(os.path.join(root, name)))
artifact(root, "old-ast.json", unit("src/Vault.sol", contract("Vault")), load("old.json"))
artifact(root, "good-ast.json", unit("src/VaultV2.sol", contract("VaultV2")), load("good.json"))
PYEOF
}

layout_compatible() {
  local d="$T/layout"
  [ -f "$SCRIPT" ] || return 1
  layouts "$d"
  ast_layouts "$d" || return 1
  run layout "$d/old-ast.json" "$d/good-ast.json" > "$T/layout-good.out" 2>&1 || return 1
  ! grep -Eq '^(removed|moved|retyped|gap|renamed|not-compared) ' "$T/layout-good.out" \
    && grep -Eq '^layout: compatible \(1 contract compared, 0 namespaces, 0 renamed\)$' "$T/layout-good.out"
}
check "layout passes an upgrade that appends variables and shrinks the gap to match" layout_compatible

layout_breaks() {
  local d="$T/layout"
  [ -f "$d/old.json" ] || layouts "$d"
  run layout "$d/old.json" "$d/inplace.json" > "$T/layout-inplace.out" 2>&1
  [ $? -eq 1 ] || return 1
  grep -qx 'removed Vault total slot 50 offset 0' "$T/layout-inplace.out" \
    && grep -qx 'retyped Vault fee uint64 -> uint32' "$T/layout-inplace.out" \
    && grep -qx 'retyped Vault positions mapping(address => struct Position) changed inside' "$T/layout-inplace.out" \
    && grep -qx 'renamed Vault users -> members slot 52 offset 0' "$T/layout-inplace.out" \
    && ! grep -q '^moved ' "$T/layout-inplace.out" \
    && grep -Eq '^layout: 3 problems in 1 contract compared \(1 renamed\)$' "$T/layout-inplace.out" || return 1
  run layout "$d/old.json" "$d/gapped.json" > "$T/layout-gap.out" 2>&1
  [ $? -eq 1 ] || return 1
  grep -qx 'gap Vault __gap ends at slot 51 instead of 50' "$T/layout-gap.out" \
    && grep -qx 'moved Vault total 50:0 -> 51:0' "$T/layout-gap.out" \
    && grep -qx 'moved Vault fee 50:16 -> 51:16' "$T/layout-gap.out" \
    && grep -qx 'moved Vault positions 51:0 -> 52:0' "$T/layout-gap.out" \
    && grep -qx 'moved Vault users 52:0 -> 53:0' "$T/layout-gap.out" \
    && ! grep -q 'moved Vault __gap' "$T/layout-gap.out" \
    && ! grep -q 'cap' "$T/layout-gap.out"
}
check "layout names removed, moved, retyped, and renamed variables and a gap that no longer ends where it did" layout_breaks

# Foundry out folders built with --ast: one artifact per contract under <file>.sol/, test and script
# artifacts that also changed, and a build-info folder, none of which may be compared.
out_folders() {
  python3 - "$1" "$T/layout" "$T" <<'PYEOF'
import json, os, sys
root, layouts, T = sys.argv[1], sys.argv[2], sys.argv[3]
sys.path.insert(0, T)
import astfix
def load(name):
    return json.load(open(os.path.join(layouts, name)))
def artifact(folder, path, layout):
    name = os.path.basename(path)[:-len(".json")]
    source = os.path.dirname(path)
    astfix.artifact(os.path.join(root, folder), path, astfix.unit("src/" + source, astfix.contract(name)), layout)
token = {"storage": [{"astId": 1, "contract": "src/Token.sol:Token", "label": "supply", "offset": 0, "slot": "0", "type": "t_uint256"}],
         "types": {"t_uint256": {"encoding": "inplace", "label": "uint256", "numberOfBytes": "32"}}}
artifact("old", "Vault.sol/Vault.json", load("old.json"))
artifact("new", "Vault.sol/Vault.json", load("inplace.json"))
artifact("old", "Token.sol/Token.json", token)
artifact("new", "Token.sol/Token.json", token)
artifact("old", "Vault.t.sol/VaultTest.json", load("old.json"))
artifact("new", "Vault.t.sol/VaultTest.json", load("gapped.json"))
artifact("old", "Deploy.s.sol/Deploy.json", load("old.json"))
artifact("new", "Deploy.s.sol/Deploy.json", load("gapped.json"))
for side in ("old", "new"):
    os.makedirs(os.path.join(root, side, "build-info"), exist_ok=True)
    json.dump({"output": {"contracts": {}}}, open(os.path.join(root, side, "build-info", "abc.json"), "w"))
artifact("v1", "VaultV1.sol/VaultV1.json", load("old.json"))
artifact("v2", "VaultV2.sol/VaultV2.json", load("good.json"))
PYEOF
}

layout_folders() {
  local d="$T/outs"
  [ -f "$T/layout/old.json" ] || layouts "$T/layout"
  out_folders "$d" || return 1
  run layout "$d/old" "$d/new" > "$T/layout-folders.out" 2>&1
  [ $? -eq 1 ] || return 1
  grep -qx 'removed Vault total slot 50 offset 0' "$T/layout-folders.out" \
    && ! grep -Eq 'VaultTest|Deploy|Token ' "$T/layout-folders.out" \
    && grep -Eq '^layout: 3 problems in 2 contracts compared \(1 renamed\)$' "$T/layout-folders.out" || return 1
  run layout "$d/old" "$d/new" --contract Token > "$T/layout-token.out" 2>&1 || return 1
  grep -Eq '^layout: compatible \(1 contract compared, 0 namespaces, 0 renamed\)$' "$T/layout-token.out" || return 1
  run layout "$d/v1" "$d/v2" > "$T/layout-none.out" 2>&1
  [ $? -eq 2 ] || return 1
  run layout "$d/v1" "$d/v2" --contract VaultV1 --new-contract VaultV2 > "$T/layout-pair.out" 2>&1 || return 1
  grep -Eq '^layout: compatible \(1 contract compared, 0 namespaces, 0 renamed\)$' "$T/layout-pair.out"
}
check "layout compares Foundry out folders contract by contract, leaving out tests, scripts, and build-info" layout_folders

# Namespaced builds: an interface, an abstract Counted with the namespace example.counted, and Points
# (is Counted) with the namespace example.points, whose mapping holds a plain Position struct. The old
# version (v1) and three new ones: v2 appends to both structs and types membership as an address
# instead of the interface; bad reorders, retypes, and removes fields; odd holds a field whose struct
# is not in the build.
namespaced_builds() {
  python3 - "$1" "$T" <<'PYEOF'
import os, sys
root, T = sys.argv[1], sys.argv[2]
sys.path.insert(0, T)
from astfix import array, artifact, constant, contract, elem, field, getter, mapping, ref, slot_expression, struct, unit

COUNTED_SLOT = "0x183a6125c38840424c4a85fa12bab2ab606c4b6d0e7cc73c0c06ba5300eab500"
POINTS_SLOT = "0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00"

# Counted reaches its struct through the constant COUNTED_SLOT, a hex literal or, with counted_text,
# the ERC-7201 formula over that text; Points sets its struct's slot to a hex literal in each of
# points_slots (none leaves the slot unset).
def build(folder, counted_fields, position_fields, points_fields, membership_as_address=False, with_ast=True,
          counted_slot=COUNTED_SLOT, counted_text=None, points_slots=(POINTS_SLOT,)):
    out = os.path.join(root, folder)
    iface = contract("IMembership", kind="interface")
    counted_struct = struct("CountedStorage", "Counted", [field(n, elem(t)) for n, t in counted_fields], "example.counted")
    location = constant("COUNTED_SLOT", expression=slot_expression(counted_text)) if counted_text \
        else constant("COUNTED_SLOT", counted_slot)
    counted = contract("Counted", [counted_struct, location, getter("_countedStorage", counted_struct, location)])
    position = struct("Position", "Points", [field(n, elem(t)) for n, t in position_fields])
    membership = elem("address") if membership_as_address else ref(iface, "contract IMembership")
    types = {"membership": membership,
             "positions": mapping(elem("address"), ref(position, "struct Points.Position")),
             "missing": ref(999999, "struct Lib.Missing"),
             "days": array(elem("uint64"), 3)}
    fields = [field(n, types[t] if t in types else elem(t)) for n, t in points_fields]
    points_struct = struct("PointsStorage", "Points", fields, "example.points")
    getters = [getter("_pointsStorage%d" % i, points_struct, s) for i, s in enumerate(points_slots)]
    points = contract("Points", [position, points_struct] + getters, [counted])
    artifact(out, "IMembership.sol/IMembership.json", unit("src/IMembership.sol", iface) if with_ast else None)
    artifact(out, "Counted.sol/Counted.json", unit("src/Counted.sol", counted) if with_ast else None)
    artifact(out, "Points.sol/Points.json", unit("src/Points.sol", points) if with_ast else None)

v1_points = [("membership", "membership"), ("cap", "uint256"), ("positions", "positions"),
             ("totalMinted", "uint256"), ("lastDay", "uint64"), ("days", "days")]
build("v1", [("count", "uint256")], [("amount", "uint128"), ("since", "uint64")], v1_points)
build("v2", [("count", "uint256"), ("resets", "uint256")], [("amount", "uint128"), ("since", "uint64")],
      v1_points + [("totalBurned", "uint256")], membership_as_address=True)
build("bad", [("count", "uint128")], [("since", "uint64"), ("amount", "uint128")],
      [("membership", "membership"), ("cap", "uint128"), ("positions", "positions"), ("lastDay", "uint64"), ("days", "days")])
build("odd", [("count", "uint256")], [("amount", "uint128"), ("since", "uint64")], v1_points + [("extra", "missing")])
build("flat", [("count", "uint256")], [("amount", "uint128"), ("since", "uint64")], v1_points, with_ast=False)
v1_args = ([("count", "uint256")], [("amount", "uint128"), ("since", "uint64")], v1_points)
build("moved", *v1_args, counted_slot="0x" + "11" * 32, points_slots=("0x" + "22" * 32,))
build("expr-a", *v1_args, counted_text="example.counted")
build("expr-b", *v1_args, counted_text="example.counted")
build("expr-c", *v1_args, counted_text="example.other")
build("noslot", *v1_args, points_slots=())
build("twoslots", *v1_args, points_slots=(POINTS_SLOT, "0x" + "33" * 32))
PYEOF
}

# In v1, PointsStorage holds membership 0:0, cap 1:0, positions 2:0, totalMinted 3:0, lastDay 4:0, and
# days 5:0. In bad, cap shrinks to uint128 and fits slot 1 alone, positions stays at 2:0, totalMinted
# is gone, so lastDay moves to 3:0 and days to 4:0; Position's members are swapped; count shrinks.
namespaced_breaks() {
  local d="$T/ns" out="$T/ns-bad.out"
  [ -d "$d/v1" ] || namespaced_builds "$d" || return 1
  run layout "$d/v1" "$d/bad" > "$out" 2>&1
  [ $? -eq 1 ] || return 1
  grep -qx 'retyped Points erc7201:example.points.cap uint256 -> uint128' "$out" \
    && grep -qx 'retyped Points erc7201:example.points.positions mapping(address => struct Position) changed inside' "$out" \
    && grep -qx 'removed Points erc7201:example.points.totalMinted slot 3 offset 0' "$out" \
    && grep -qx 'moved Points erc7201:example.points.lastDay 4:0 -> 3:0' "$out" \
    && grep -qx 'moved Points erc7201:example.points.days 5:0 -> 4:0' "$out" \
    && grep -qx 'retyped Points erc7201:example.counted.count uint256 -> uint128' "$out" \
    && grep -qx 'retyped Counted erc7201:example.counted.count uint256 -> uint128' "$out" \
    && ! grep -q 'membership' "$out" && ! grep -q 'IMembership' "$out" \
    && ! grep -q '^not-compared ' "$out" && ! grep -q 'compatible' "$out" \
    && grep -qx 'layout: 7 problems in 3 contracts compared (0 renamed)' "$out"
}
check "layout names removed, moved, and retyped fields of an ERC-7201 namespaced struct, also in a base contract" namespaced_breaks

namespaced_appended() {
  local d="$T/ns" out="$T/ns-good.out"
  [ -d "$d/v1" ] || namespaced_builds "$d" || return 1
  run layout "$d/v1" "$d/v2" > "$out" 2>&1 || return 1
  ! grep -Eq '^(removed|moved|retyped|gap|renamed|not-compared) ' "$out" \
    && grep -qx 'layout: compatible (3 contracts compared, 3 namespaces, 0 renamed)' "$out"
}
check "layout passes an upgrade that appends a field to an ERC-7201 namespaced struct" namespaced_appended

# Four ways the namespaced storage cannot be compared: forge inspect layouts with no syntax tree, a
# new build made without --ast, a field whose struct is not in the build, and one artifact given
# alone, whose base contract sits in another artifact.
namespaced_unread() {
  local d="$T/ns" out status
  [ -d "$d/v1" ] || namespaced_builds "$d" || return 1
  [ -f "$T/layout/old.json" ] || layouts "$T/layout"
  out="$T/ns-inspect.out"
  run layout "$T/layout/old.json" "$T/layout/good.json" > "$out" 2>&1
  status=$?
  [ "$status" -eq 1 ] && grep -q '^not-compared VaultV2 namespaces: ' "$out" && ! grep -q 'compatible' "$out" || return 1
  out="$T/ns-flat.out"
  run layout "$d/v1" "$d/flat" > "$out" 2>&1
  status=$?
  [ "$status" -eq 1 ] && grep -q '^not-compared Points erc7201:example.points: ' "$out" \
    && grep -q '^not-compared Points erc7201:example.counted: ' "$out" \
    && grep -q '^not-compared Counted erc7201:example.counted: ' "$out" \
    && grep -q '^not-compared IMembership namespaces: ' "$out" && ! grep -q 'compatible' "$out" || return 1
  out="$T/ns-odd.out"
  run layout "$d/v1" "$d/odd" > "$out" 2>&1
  status=$?
  [ "$status" -eq 1 ] && grep -q '^not-compared Points erc7201:example.points: .*extra' "$out" \
    && ! grep -q '^not-compared Counted ' "$out" && ! grep -q 'compatible' "$out" || return 1
  out="$T/ns-alone.out"
  run layout "$d/v1/Points.sol/Points.json" "$d/v2/Points.sol/Points.json" > "$out" 2>&1
  status=$?
  [ "$status" -eq 1 ] && grep -q '^not-compared Points ' "$out" && ! grep -q 'compatible' "$out"
}
check "layout names a contract whose namespaced storage it could not compare and never prints compatible for it" namespaced_unread

# moved keeps every field of v1 and points both namespaces at other slots: Counted through its
# constant, Points through a literal in assembly.
slot_moved() {
  local d="$T/ns" out="$T/ns-moved.out" status c="0x$(printf '11%.0s' $(seq 32))" p="0x$(printf '22%.0s' $(seq 32))"
  [ -d "$d/v1" ] || namespaced_builds "$d" || return 1
  run layout "$d/v1" "$d/moved" > "$out" 2>&1
  status=$?
  [ "$status" -eq 1 ] || { echo "      exit $status"; return 1; }
  grep -qx "slot Counted erc7201:example.counted 0x183a6125c38840424c4a85fa12bab2ab606c4b6d0e7cc73c0c06ba5300eab500 -> $c" "$out" \
    && grep -qx "slot Points erc7201:example.counted 0x183a6125c38840424c4a85fa12bab2ab606c4b6d0e7cc73c0c06ba5300eab500 -> $c" "$out" \
    && grep -qx "slot Points erc7201:example.points 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00 -> $p" "$out" \
    && ! grep -q 'compatible' "$out" \
    && grep -qx 'layout: 3 problems in 3 contracts compared (0 renamed)' "$out" \
    || { echo "      $(tail -n 1 "$out")"; return 1; }
}
check "layout names a namespace whose slot changed between the versions" slot_moved

# expr-a and expr-b write Counted's slot constant as the same ERC-7201 formula; expr-c over another text.
slot_expression_compared() {
  local d="$T/ns" out="$T/ns-expr.out" status
  [ -d "$d/v1" ] || namespaced_builds "$d" || return 1
  run layout "$d/expr-a" "$d/expr-b" > "$out" 2>&1 || { echo "      the same expression: $(tail -n 1 "$out")"; return 1; }
  grep -qx 'layout: compatible (3 contracts compared, 3 namespaces, 0 renamed)' "$out" || return 1
  run layout "$d/expr-a" "$d/expr-c" > "$out" 2>&1
  status=$?
  [ "$status" -eq 1 ] && grep -q '^slot Counted erc7201:example.counted .* -> ' "$out" && ! grep -q 'compatible' "$out" \
    || { echo "      another expression: exit $status, $(tail -n 1 "$out")"; return 1; }
}
check "layout compares a slot constant written as an expression by its expression" slot_expression_compared

# noslot sets no slot for PointsStorage; twoslots sets it to two different values.
slot_unread() {
  local d="$T/ns" out status build
  [ -d "$d/v1" ] || namespaced_builds "$d" || return 1
  for build in noslot twoslots; do
    out="$T/ns-$build.out"
    run layout "$d/v1" "$d/$build" > "$out" 2>&1
    status=$?
    [ "$status" -eq 1 ] && grep -q '^not-compared Points erc7201:example.points: ' "$out" && ! grep -q 'compatible' "$out" \
      || { echo "      $build: exit $status, $(tail -n 1 "$out")"; return 1; }
  done
}
check "layout names a namespace whose slot it could not read and never prints compatible for it" slot_unread

slot_documented() {
  python3 -c 'import ast, sys
doc = ast.get_docstring(ast.parse(open(sys.argv[1], encoding="utf-8").read()))
sys.exit(0 if "slot <contract> erc7201:<id> <old> -> <new>" in doc and "sets no slot" in doc else 1)' "$SCRIPT" || return 1
  grep -qE '^\| `slot` \|' "$PLUGIN/docs/how-it-works.md" && grep -q 'sets no slot' "$PLUGIN/docs/how-it-works.md" || return 1
  grep -qE '^\| `slot` \|' "$PLUGIN/docs/how-it-works.ja.md"
}
check "the docs list the slot line of layout" slot_documented

skill_slot_and_simulation() {
  grep -qF '`gap`, or `slot` line' "$SKILL" && grep -qF 'without `--broadcast`' "$SKILL" \
    && grep -qF '`anvil`' "$SKILL" && grep -qF 'deploy script' "$SKILL"
}
check "the release-check SKILL.md names the slot line and where to simulate the upgrade" skill_slot_and_simulation

changelog_slot() {
  local entries
  entries="$(awk '/^## \[/ { on = 1 } on' "$PLUGIN/CHANGELOG.md" | grep '^- ')"
  printf '%s\n' "$entries" | grep -q 'slot' && printf '%s\n' "$entries" | grep -q '`anvil`'
}
check "the changelog names the slot comparison and the simulation step" changelog_slot

abis() {
  python3 - "$1" <<'PYEOF'
import json, os, sys
root = sys.argv[1]
os.makedirs(root, exist_ok=True)
def fn(name, inputs, outputs=(), mut="nonpayable"):
    return {"type": "function", "name": name, "stateMutability": mut,
            "inputs": [{"name": "", "type": t, "internalType": t} for t in inputs],
            "outputs": [{"name": "", "type": t, "internalType": t} for t in outputs]}
def ev(name, params):
    return {"type": "event", "name": name, "anonymous": False,
            "inputs": [{"name": "p%d" % i, "type": t, "indexed": ix, "internalType": t} for i, (t, ix) in enumerate(params)]}
def err(name, inputs):
    return {"type": "error", "name": name, "inputs": [{"name": "", "type": t, "internalType": t} for t in inputs]}
order = {"type": "tuple", "name": "order", "internalType": "struct Vault.Order",
         "components": [{"name": "amount", "type": "uint256"}, {"name": "to", "type": "address"}]}
old = [fn("deposit", ["uint256"], ["bool"]), fn("withdraw", ["uint256"]), fn("balanceOf", ["address"], ["uint256"], "view"),
       fn("price", [], ["uint256"], "view"), {"type": "receive", "stateMutability": "payable"},
       {"type": "function", "name": "place", "stateMutability": "nonpayable", "inputs": [order], "outputs": []},
       ev("Deposited", [("address", True), ("uint256", False)]), ev("Withdrawn", [("address", True), ("uint256", False)]),
       err("Paused", []), err("Insufficient", ["uint256", "uint256"])]
added = old + [fn("pause", []), ev("PausedSet", [("bool", False)]), err("Cap", ["uint256"])]
changed = [fn("deposit", ["uint256"], ["uint256"]), fn("balanceOf", ["address"], ["uint256"], "view"),
           fn("price", [], ["uint256"]), fn("pause", []),
           {"type": "function", "name": "place", "stateMutability": "nonpayable", "inputs": [order], "outputs": []},
           ev("Deposited", [("address", True), ("uint256", True)]), ev("Withdrawn", [("address", True), ("uint256", False), ("uint256", False)]),
           err("Insufficient", ["uint256", "uint256"]), err("Cap", ["uint256"])]
json.dump(old, open(os.path.join(root, "old.json"), "w"), indent=2)
json.dump({"abi": added}, open(os.path.join(root, "added.json"), "w"), indent=2)
json.dump({"abi": changed}, open(os.path.join(root, "changed.json"), "w"), indent=2)
PYEOF
}

abi_changes() {
  local d="$T/abi"
  [ -f "$SCRIPT" ] || return 1
  abis "$d"
  run abi "$d/old.json" "$d/added.json" > "$T/abi-added.out" 2>&1 || return 1
  grep -Eq '^abi: compatible \(1 contract compared\)$' "$T/abi-added.out" || return 1
  run abi "$d/old.json" "$d/changed.json" > "$T/abi-changed.out" 2>&1
  [ $? -eq 1 ] || return 1
  grep -qx 'changed-function changed deposit(uint256) outputs (bool) -> (uint256)' "$T/abi-changed.out" \
    && grep -qx 'changed-function changed price() stateMutability view -> nonpayable' "$T/abi-changed.out" \
    && grep -qx 'removed-function changed withdraw(uint256)' "$T/abi-changed.out" \
    && grep -qx 'removed-function changed receive()' "$T/abi-changed.out" \
    && grep -qx 'changed-event changed Deposited(address,uint256) indexed (true,false) -> (true,true)' "$T/abi-changed.out" \
    && grep -qx 'removed-event changed Withdrawn(address,uint256)' "$T/abi-changed.out" \
    && grep -qx 'removed-error changed Paused()' "$T/abi-changed.out" \
    && ! grep -Eq 'balanceOf|place|Insufficient|pause\(|Cap\(' "$T/abi-changed.out" \
    && grep -Eq '^abi: 7 breaking changes in 1 contract compared$' "$T/abi-changed.out"
}
check "abi names removed or changed functions, events, and errors and passes added ones" abi_changes

# Bytecode: PUSH1 0x5f (push data, not an opcode), PUSH0, MCOPY, TLOAD, TSTORE, CLZ, BLOBHASH,
# BLOBBASEFEE, STOP, then solc's CBOR metadata, whose hash bytes hold 5e and 5f too.
METADATA="a2646970667358221220$(printf '5e5f%.0s' $(seq 1 16))64736f6c634300081e0033"
RUNTIME="605f5f5e5c5d1e494a00$METADATA"

foundry_artifact() {
  # foundry_artifact <file> <creation hex> <runtime hex>
  mkdir -p "$(dirname "$1")"
  printf '{"abi": [], "bytecode": {"object": "0x%s"}, "deployedBytecode": {"object": "0x%s"}}\n' "$2" "$3" > "$1"
}

opcodes_named() {
  local d="$T/op"
  [ -f "$SCRIPT" ] || return 1
  foundry_artifact "$d/out/Vault.sol/Vault.json" "6080604052$RUNTIME" "$RUNTIME"
  run opcodes "$d/out" --evm shanghai > "$T/op-shanghai.out" 2>&1
  [ $? -eq 1 ] || return 1
  grep -qx 'opcode Vault runtime MCOPY needs cancun' "$T/op-shanghai.out" \
    && grep -qx 'opcode Vault runtime TLOAD needs cancun' "$T/op-shanghai.out" \
    && grep -qx 'opcode Vault runtime TSTORE needs cancun' "$T/op-shanghai.out" \
    && grep -qx 'opcode Vault runtime BLOBHASH needs cancun' "$T/op-shanghai.out" \
    && grep -qx 'opcode Vault runtime BLOBBASEFEE needs cancun' "$T/op-shanghai.out" \
    && grep -qx 'opcode Vault runtime CLZ needs osaka' "$T/op-shanghai.out" \
    && ! grep -q 'PUSH0' "$T/op-shanghai.out" \
    && [ "$(grep -c '^opcode ' "$T/op-shanghai.out")" -eq 6 ] || return 1
  run opcodes "$d/out" --evm paris > "$T/op-paris.out" 2>&1
  [ $? -eq 1 ] && grep -qx 'opcode Vault runtime PUSH0 needs shanghai' "$T/op-paris.out" \
    && [ "$(grep -c '^opcode ' "$T/op-paris.out")" -eq 7 ] || return 1
  run opcodes "$d/out" --evm Osaka > "$T/op-osaka.out" 2>&1 || return 1
  ! grep -q '^opcode ' "$T/op-osaka.out" && grep -Eq '^opcodes: every opcode runs on osaka \(1 contract\)$' "$T/op-osaka.out"
}
check "opcodes names each opcode the target EVM version lacks, skipping push data and metadata" opcodes_named

opcodes_shapes() {
  local d="$T/shapes" plain init lib
  [ -f "$SCRIPT" ] || return 1
  plain="6001600201$(printf '00')"
  # The constructor stores into transient storage once; the runtime that follows is plain.
  init="60016000""5d""6080604052"
  foundry_artifact "$d/foundry/Guard.sol/Guard.json" "$init$plain" "$plain"
  # A Hardhat artifact with an unlinked library placeholder, its debug file, and build-info.
  lib="73__\$b5b2f3a4c1d0e9f8a7b6c5d4e3f2a1b0c9\$__5af4"
  mkdir -p "$d/hardhat/contracts/Pool.sol" "$d/hardhat/build-info"
  printf '{"_format": "hh-sol-artifact-1", "contractName": "Pool", "bytecode": "0x60806040%s5e00", "deployedBytecode": "0x%s5e00"}\n' "$lib" "$lib" \
    > "$d/hardhat/contracts/Pool.sol/Pool.json"
  printf '{"_format": "hh-sol-dbg-1", "buildInfo": "../../build-info/x.json"}\n' > "$d/hardhat/contracts/Pool.sol/Pool.dbg.json"
  printf '{"output": {"contracts": {}}}\n' > "$d/hardhat/build-info/x.json"
  run opcodes "$d/foundry" --evm shanghai > "$T/shape-foundry.out" 2>&1
  [ $? -eq 1 ] && grep -qx 'opcode Guard creation TSTORE needs cancun' "$T/shape-foundry.out" \
    && ! grep -q 'Guard runtime' "$T/shape-foundry.out" || return 1
  run opcodes "$d/hardhat" --evm shanghai > "$T/shape-hardhat.out" 2>&1
  [ $? -eq 1 ] && grep -qx 'opcode Pool runtime MCOPY needs cancun' "$T/shape-hardhat.out" \
    && ! grep -q 'Pool creation MCOPY' "$T/shape-hardhat.out" \
    && grep -Eq '^opcodes: .* in 1 contract$' "$T/shape-hardhat.out" || return 1
  run opcodes "$d/foundry/Guard.sol/Guard.json" --evm cancun > "$T/shape-file.out" 2>&1 || return 1
  run opcodes "$d/foundry" --evm fusaka2 > "$T/shape-unknown.out" 2>&1
  [ $? -eq 2 ] && grep -q 'osaka' "$T/shape-unknown.out"
}
check "opcodes reads Foundry and Hardhat artifacts, checks creation code, and refuses an unknown EVM version" opcodes_shapes

no_urls() {
  [ "$(find "$ITEMS" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')" -ge 5 ] || return 1
  ! grep -rIlE 'https?://|www\.' "$ITEMS" > /dev/null || return 1
  ! grep -rL '^source: .\{8,\}' "$ITEMS" | grep -q .
}
check "no release-check item holds a URL" no_urls

skill_rules() {
  local phrase
  [ -f "$SKILL" ] || return 1
  for phrase in \
    'Read the versions with the solidity-code skill' \
    'Run `list`' \
    're-check it against the official document' \
    '`git worktree add`' \
    '`--extra-output storageLayout`' \
    '`--ast`' \
    'only it and what it imports' \
    'Run `layout`' \
    '`not-compared`' \
    'Run `abi`' \
    'Run `opcodes`' \
    '`npx @openzeppelin/upgrades-core validate`' \
    '`@custom:storage-location`' \
    '`forge snapshot --diff`' \
    '`forge build --sizes`' \
    'EIP-7825' \
    'use the evm-standards skill' \
    'the solidity-code skill' \
    'Remove the temporary worktree' \
    '`git worktree remove --force <folder>`' \
    'Never read a private key or a mnemonic' \
    'never sign' \
    'refuse a command that passes a key' \
    'Never read `.env` files' \
    'Never edit the items in the plugin'; do
    grep -qF -- "$phrase" "$SKILL" || return 1
  done
}
check "the release-check SKILL.md keeps its rules" skill_rules

SKILL_WORDS_MAX=659
SKILL_DESCRIPTION_MAX=300
skill_size() {
  [ -f "$SKILL" ] || return 1
  python3 - "$SKILL" "$SKILL_WORDS_MAX" "$SKILL_DESCRIPTION_MAX" <<'PYEOF'
import re, sys
front, body = open(sys.argv[1], encoding="utf-8").read().split("---", 2)[1:]
words = len(body.split())
chars = len(re.search(r"^description: (.*)$", front, re.M).group(1))
print("      SKILL.md body %d words (max %s), description %d characters (max %s)" % (words, sys.argv[2], chars, sys.argv[3]))
sys.exit(0 if words <= int(sys.argv[2]) and chars <= int(sys.argv[3]) else 1)
PYEOF
}
check "the release-check SKILL.md stays within its size limits" skill_size

# Each case has a case.yaml and an executable fixture.sh that runs the way claude plugin eval runs it
# (in home/cwd with HOME at home). The upgrade case holds the deployed version's layout and ABI and a
# build whose layout breaks; the opcodes case holds a build that a Shanghai chain cannot run.
CASES=(upgrade-layout-check chain-opcodes-check release-unrelated-request)
eval_suite() {
  local c home
  for c in "${CASES[@]}"; do
    [ -f "$EVALS/$c/case.yaml" ] && [ -x "$EVALS/$c/fixture.sh" ] || return 1
    home="$T/fixture-$c/home"
    mkdir -p "$home/cwd"
    (cd "$home/cwd" && HOME="$home" bash "$EVALS/$c/fixture.sh") > /dev/null 2>&1 || return 1
    [ -s "$home/cwd/foundry.toml" ] && [ -s "$home/cwd/src/Vault.sol" ] && [ -s "$home/cwd/out/Vault.sol/Vault.json" ] || return 1
    case "$c" in
      upgrade-layout-check)
        run layout "$home/cwd/snapshots/Vault.storage.json" "$home/cwd/out/Vault.sol/Vault.json" > /dev/null 2>&1
        [ $? -eq 1 ] || return 1
        run abi "$home/cwd/snapshots/Vault.abi.json" "$home/cwd/out/Vault.sol/Vault.json" > /dev/null 2>&1
        [ $? -eq 1 ] || return 1 ;;
      chain-opcodes-check)
        run opcodes "$home/cwd/out" --evm shanghai > /dev/null 2>&1
        [ $? -eq 1 ] || return 1 ;;
      release-unrelated-request)
        grep -q 'name: skill-not-loaded' "$EVALS/$c/case.yaml" && grep -q "input_match: 'release-check'" "$EVALS/$c/case.yaml" || return 1
        continue ;;
    esac
    grep -q 'name: skill-fired' "$EVALS/$c/case.yaml" && grep -q "input_match: 'release-check'" "$EVALS/$c/case.yaml" || return 1
  done
  git -C "$PLUGIN" check-ignore -q "evals/results/run.json"
}
check "the eval suite has its release-check cases and each fixture builds its state" eval_suite

readmes_list() {
  grep -qF '/evm-dev:release-check' "$REPO/README.md" && grep -qF '/evm-dev:release-check' "$REPO/README.ja.md"
}
check "the root READMEs list /evm-dev:release-check" readmes_list

others_kept() {
  # A test that another skill's test runs skips this check: the outer test runs every other skill's
  # tests once itself, so the same tests are not run again inside each other.
  [ -n "${EVM_DEV_NESTED:-}" ] && return 0
  local EVM_DEV_NESTED=1
  export EVM_DEV_NESTED
  bash "$PLUGIN/skills/evm-standards/scripts/evm-standards.sh" check > "$T/evm-standards.out" 2>&1 \
    && bash "$PLUGIN/skills/solidity-code/tests/test-solidity-code.sh" > "$T/solidity-code.out" 2>&1 \
    && bash "$PLUGIN/skills/financial-standards/tests/test-financial-standards.sh" > "$T/financial-standards.out" 2>&1 \
    && bash "$PLUGIN/skills/contract-tests/tests/test-contract-tests.sh" > "$T/contract-tests.out" 2>&1 \
    && bash "$PLUGIN/skills/contract-design/tests/test-contract-design.sh" > "$T/contract-design.out" 2>&1 \
    && bash "$PLUGIN/skills/wallet-design/tests/test-wallet-design.sh" > "$T/wallet-design.out" 2>&1 \
    && bash "$PLUGIN/skills/dapp-architecture/tests/test-dapp-architecture.sh" > "$T/dapp-architecture.out" 2>&1 \
    && bash "$PLUGIN/skills/multichain-design/tests/test-multichain-design.sh" > "$T/multichain-design.out" 2>&1 \
    && bash "$PLUGIN/skills/contract-deploy/tests/test-contract-deploy.sh" > "$T/contract-deploy.out" 2>&1
}
check "the other evm-dev skills still pass their tests with release-check" others_kept

printf '%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
