#!/usr/bin/env bash
# Tests for ethereum-knowledge.sh, the bundled items, the SKILL.md, and the pages and manifests of the
# plugin that describe the skill. Item files written here live in a throwaway folder; nothing
# reaches the network.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
SCRIPT="$SKILL_DIR/scripts/ethereum-knowledge.sh"
ITEMS="$SKILL_DIR/references/items"
SKILL="$SKILL_DIR/SKILL.md"
PLUGIN="$(cd "$SKILL_DIR/../.." && pwd)"
REPO="$(cd "$PLUGIN/../.." && pwd)"
STANDARDS_SKILL="$PLUGIN/skills/evm-standards/SKILL.md"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export PYTHONDONTWRITEBYTECODE=1

why=""
check() {
  why=""
  if "$2"; then
    PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"
  else
    FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"
    [ -n "$why" ] && printf '        %s\n' "$why"
  fi
}

# need <file>...: every file exists.
need() {
  local f
  for f in "$@"; do
    [ -f "$f" ] || { why="${f#"$PLUGIN/"} is missing"; return 1; }
  done
}

# The items of the owner's copy the skill was moved from, and the items added since: the name, the
# status, and the date that status was confirmed. A question asked before the move finds the same item
# after it, in the same state. An item added later is listed here with the date it was checked.
EXPECTED="arbitrum-bold-stylus live 2026-11-11
aztec live 2026-11-11
based-rollup-preconfirmation live 2026-11-11
bridge-risk-framework live 2026-11-11
eclipse live 2026-11-11
eigenda live 2026-11-11
eip-6110-onchain-deposits live 2026-11-11
eip-7045-attestation-inclusion-range live 2026-11-16
eip-7251-max-effective-balance live 2026-11-10
eip-7514-max-epoch-churn live 2026-11-10
eip-7549-committee-index-outside-attestation live 2026-11-11
eip-7594-peerdas live 2026-11-11
eip-7684-return-deposits specified 2026-11-11
eip-7685-execution-layer-requests live 2026-11-11
eip-7716-anti-correlation-penalties specified 2026-11-16
eip-7732-enshrined-pbs specified 2026-11-16
eip-7805-focil specified 2026-11-16
eip-8025-optional-execution-proofs specified 2026-11-11
eip-8292-pq-attestation-aggregators specified 2026-11-23
ethereum-economic-zone announced 2026-11-08
fluent live 2026-11-11
fuel live 2026-11-11
herodotus-storage-proofs live 2026-11-11
intmax-plasma-next stopped 2026-11-11
l1-fast-confirmation specified 2026-11-16
l1-hash-away-from-poseidon announced 2026-11-11
l1-pqai27-proposal announced 2026-11-23
l1-single-slot-finality specified 2026-11-16
l2beat-stages live 2026-11-11
mantle live 2026-11-11
monomer stopped 2026-11-11
multi-prover live 2026-11-11
nil-zksharding specified 2026-11-11
op-stack-alt-da live 2026-11-11
op-stack-fault-proofs live 2026-11-16
op-stack-priority-ordering live 2026-11-16
op-stack-superchain live 2026-11-11
polygon-agglayer-cdk live 2026-11-16
rollup-as-a-service live 2026-11-11
ronin live 2026-11-11
scroll live 2026-11-11
shared-sequencer live 2026-11-11
sn-stack-madara live 2026-11-11
starknet live 2026-11-11
state-tree-binary-trie specified 2026-11-11
superchain-revenue-share live 2026-11-11
validium-external-da live 2026-11-11
world-chain live 2026-11-11
zk-stack-elastic-network live 2026-11-16
zkevm-types live 2026-11-11
zklink-nova stopped 2026-11-11
zksync-era-state-diffs live 2026-11-10
zkvm-block-proving live 2026-11-11"

# item <folder> <name> <status> <checked> <source>: writes one item file; an empty value leaves its
# field out.
item() {
  mkdir -p "$1"
  {
    printf -- '---\n'
    [ -n "$3" ] && printf 'status: %s\n' "$3"
    [ -n "$4" ] && printf 'checked: %s\n' "$4"
    [ -n "$5" ] && printf 'source: %s\n' "$5"
    printf -- '---\n\n# %s\n\nBody.\n' "$2"
  } > "$1/$2.md"
}

holds_named_items() {
  local want have
  need "$SKILL" "$SKILL_DIR/agents/openai.yaml" "$SCRIPT" "$SKILL_DIR/tests/test-ethereum-knowledge.sh" || return 1
  grep -qx 'name: ethereum-knowledge' "$SKILL" || { why="SKILL.md does not say name: ethereum-knowledge"; return 1; }
  [ -d "$ITEMS" ] || { why="references/items/ is missing"; return 1; }
  want="$(printf '%s\n' "$EXPECTED" | awk '{print $1 ".md"}' | LC_ALL=C sort)"
  have="$(cd "$ITEMS" && LC_ALL=C ls -A | LC_ALL=C sort)"
  [ "$want" = "$have" ] || {
    why="references/items/ differs from the listed names: $(diff <(printf '%s\n' "$want") <(printf '%s\n' "$have") | grep '^[<>]' | tr '\n' ' ')"
    return 1
  }
}
check "the skill holds the named items" holds_named_items

# Every item opens with exactly the three fields, in this order, and the script accepts them all.
bundled_check() {
  local f n=0 status
  [ -x "$SCRIPT" ] || { why="scripts/ethereum-knowledge.sh is missing or not executable"; return 1; }
  for f in "$ITEMS"/*.md; do
    [ -f "$f" ] || { why="references/items/ holds no items"; return 1; }
    n=$((n + 1))
    sed -n '1p;5p' "$f" | grep -qvx -- '---' && { why="$(basename "$f") does not open with a front matter of three fields"; return 1; }
    sed -n 2p "$f" | grep -qE '^status: ' && sed -n 3p "$f" | grep -qE '^checked: [0-9]{4}-[0-9]{2}-[0-9]{2}$' \
      && sed -n 4p "$f" | grep -qE '^source: .{10,}' || { why="$(basename "$f") does not open with status, checked, and source"; return 1; }
  done
  bash "$SCRIPT" check > "$T/bundled.out" 2>&1
  status=$?
  [ "$status" -eq 0 ] || { why="check exited $status: $(head -3 "$T/bundled.out" | tr '\n' ' ')"; return 1; }
  grep -q "($n items)" "$T/bundled.out" || { why="check did not count the $n items: $(cat "$T/bundled.out")"; return 1; }
}
check "check passes on the bundled items" bundled_check

# Japanese text and its punctuation, by code point, so that this file holds none of it.
items_english() {
  [ -n "$(find "$ITEMS" -name '*.md' 2>/dev/null)" ] || { why="references/items/ holds no items"; return 1; }
  why="$(python3 - "$ITEMS" <<'PY'
import os, re, sys
japanese = re.compile("[%s-%s%s-%s%s-%s%s-%s]" % tuple(map(chr, (0x3000, 0x30FF, 0x3400, 0x9FFF, 0xF900, 0xFAFF, 0xFF00, 0xFFEF))))
for name in sorted(os.listdir(sys.argv[1])):
    for number, line in enumerate(open(os.path.join(sys.argv[1], name), encoding="utf-8"), 1):
        if japanese.search(line):
            print("not English: %s:%d" % (name, number))
            sys.exit(0)
PY
)"
  [ -z "$why" ]
}
check "every item is in English" items_english

# Each item keeps the status and the date listed above, which come to 3 announced, 10 specified,
# 37 live, and 3 stopped.
statuses_kept() {
  local name status checked file got totals
  [ -d "$ITEMS" ] || { why="references/items/ is missing"; return 1; }
  while read -r name status checked; do
    file="$ITEMS/$name.md"
    [ -f "$file" ] || { why="$name.md is missing"; return 1; }
    got="$(sed -n 's/^status: //p' "$file" | head -1) $(sed -n 's/^checked: //p' "$file" | head -1)"
    [ "$got" = "$status $checked" ] || { why="$name has $got, not $status $checked"; return 1; }
  done <<EOF
$EXPECTED
EOF
  totals="$(sed -n 's/^status: //p' "$ITEMS"/*.md | LC_ALL=C sort | LC_ALL=C uniq -c | awk '{printf "%s=%s ", $2, $1}')"
  [ "$totals" = "announced=3 live=37 specified=10 stopped=3 " ] || { why="the statuses add up to $totals"; return 1; }
}
check "the items keep the statuses of the private copy" statuses_kept

# The old status words of the owner's copy are refused like any other unknown status.
bad_items_named() {
  local d="$T/bad" good="$T/good" status old name
  [ -f "$SCRIPT" ] || { why="scripts/ethereum-knowledge.sh is missing"; return 1; }
  old="$(printf '\345\213\225\343\201\204\343\201\246\343\201\204\343\202\213')"
  item "$d" eip-1-good live 2026-01-01 "The EIP document"
  item "$d" l2-erc-bridge live 2026-01-01 "The project's documentation"
  item "$d" eip-2-nostatus "" 2026-01-01 "The EIP document"
  item "$d" eip-3-nochecked live "" "The EIP document"
  item "$d" eip-4-nosource live 2026-01-01 ""
  item "$d" eip-5-draft draft 2026-01-01 "The EIP document"
  item "$d" eip-6-oldword "$old" 2026-01-01 "The EIP document"
  item "$d" eip-7-baddate specified 2026-02-30 "The EIP document"
  item "$d" erc-20-token live 2026-01-01 "The ERC document"
  bash "$SCRIPT" check --dir "$d" > "$T/bad.out" 2>&1
  status=$?
  [ "$status" -eq 1 ] || { why="check exited $status on bad items"; return 1; }
  for name in eip-2-nostatus eip-3-nochecked eip-4-nosource eip-5-draft eip-6-oldword eip-7-baddate erc-20-token; do
    grep -q "$name" "$T/bad.out" || { why="check did not name $name"; return 1; }
  done
  ! grep -qE 'eip-1-good|l2-erc-bridge' "$T/bad.out" || { why="check named a good item"; return 1; }
  item "$good" eip-1-good live 2026-01-01 "The EIP document"
  item "$good" l2-erc-bridge live 2026-01-01 "The project's documentation"
  bash "$SCRIPT" check --dir "$good" > "$T/good.out" 2>&1 || { why="check refused good items: $(cat "$T/good.out")"; return 1; }
  mkdir -p "$T/empty"
  bash "$SCRIPT" check --dir "$T/empty" > /dev/null 2>&1
  status=$?
  [ "$status" -eq 1 ] || { why="check exited $status on a folder with no items"; return 1; }
}
check "check names an item with a missing field, an unknown status, an impossible date, or an ERC name" bad_items_named

# Counted to 2026-02-01: each status at exactly its days (still ok) and one day past them (stale).
stale_marked() {
  local d="$T/stale" status
  [ -f "$SCRIPT" ] || { why="scripts/ethereum-knowledge.sh is missing"; return 1; }
  item "$d" eip-10-old announced 2026-01-01 "The EIP document"
  item "$d" eip-11-edge announced 2026-01-02 "The EIP document"
  item "$d" eip-12-live live 2026-01-01 "The EIP document"
  item "$d" eip-13-specified specified 2025-11-05 "The EIP document"
  item "$d" eip-14-stopped stopped 2025-08-01 "The EIP document"
  item "$d" eip-15-specified-edge specified 2025-11-03 "The EIP document"
  item "$d" eip-16-specified-old specified 2025-11-02 "The EIP document"
  item "$d" eip-17-live-edge live 2025-08-05 "The EIP document"
  item "$d" eip-18-live-old live 2025-08-04 "The EIP document"
  item "$d" eip-19-stopped-edge stopped 2025-08-05 "The EIP document"
  item "$d" eip-20-stopped-old stopped 2025-08-04 "The EIP document"
  bash "$SCRIPT" list --dir "$d" --today 2026-02-01 > "$T/list.out" 2>&1 || { why="list failed: $(cat "$T/list.out")"; return 1; }
  grep -Eq '^stale +announced +2026-01-01 +eip-10-old$' "$T/list.out" \
    && grep -Eq '^ok +announced +2026-01-02 +eip-11-edge$' "$T/list.out" \
    && grep -Eq '^ok +live +2026-01-01 +eip-12-live$' "$T/list.out" \
    && grep -Eq '^ok +specified +2025-11-05 +eip-13-specified$' "$T/list.out" \
    && grep -Eq '^stale +stopped +2025-08-01 +eip-14-stopped$' "$T/list.out" \
    && grep -Eq '^ok +specified +2025-11-03 +eip-15-specified-edge$' "$T/list.out" \
    && grep -Eq '^stale +specified +2025-11-02 +eip-16-specified-old$' "$T/list.out" \
    && grep -Eq '^ok +live +2025-08-05 +eip-17-live-edge$' "$T/list.out" \
    && grep -Eq '^stale +live +2025-08-04 +eip-18-live-old$' "$T/list.out" \
    && grep -Eq '^ok +stopped +2025-08-05 +eip-19-stopped-edge$' "$T/list.out" \
    && grep -Eq '^stale +stopped +2025-08-04 +eip-20-stopped-old$' "$T/list.out" \
    && grep -qx '11 items, 5 stale as of 2026-02-01' "$T/list.out" \
    || { why="list printed: $(tr '\n' '|' < "$T/list.out")"; return 1; }
  bash "$SCRIPT" list --dir "$d" --today 2026-02-30 > /dev/null 2>&1
  status=$?
  [ "$status" -eq 2 ] || { why="list --today 2026-02-30 exited $status, not 2"; return 1; }
}
check "list marks the items past the days for their status" stale_marked

no_urls() {
  local f
  [ -n "$(find "$ITEMS" -name '*.md' 2>/dev/null)" ] || { why="references/items/ holds no items"; return 1; }
  f="$(grep -rIlE 'https?://|www\.' "$ITEMS" | head -1)"
  [ -z "$f" ] || { why="$(basename "$f") holds a URL"; return 1; }
}
check "no item holds a URL" no_urls

# Prints file:line for every line under the folder given that names the author's PC or the steps of
# the author's own workflow. The words are built from parts so that this file does not hold them.
names_of_this_pc() {
  python3 - "$1" <<'PY'
import os, re, sys
ja = lambda *points: "".join(map(chr, points))
pattern = re.compile("/Us" "ers/|~/[.]cl" "aude/|~/[.]co" "dex/|(?i:ik" "kan)|/si" "ft\\b|" + ja(0x8EFD, 0x5FAE))
for folder, _, files in os.walk(sys.argv[1]):
    for name in files:
        path = os.path.join(folder, name)
        with open(path, encoding="utf-8", errors="ignore") as source:
            for number, line in enumerate(source, 1):
                if pattern.search(line):
                    print(f"{os.path.relpath(path, sys.argv[1])}:{number}")
PY
}

no_local_names() {
  local hits
  need "$SKILL" || return 1
  # The scan catches planted lines, so an empty result means the words are absent.
  mkdir -p "$T/control"
  printf 'see %s and the %s steps\n%s\n' "~/.co""dex/config" "ik""kan" "$(printf '\350\273\275\345\276\256')" > "$T/control/planted.md"
  [ "$(names_of_this_pc "$T/control" | grep -c .)" -eq 2 ] || { why="the scan misses a planted line"; return 1; }
  hits="$(names_of_this_pc "$SKILL_DIR")"
  [ -z "$hits" ] || { why="found at: $(printf '%s ' $hits)"; return 1; }
}
check "no file names the author's PC or private workflow" no_local_names

skill_rules() {
  local phrase
  need "$SKILL" || return 1
  for phrase in \
    'Run `list` before answering' \
    're-check it against the official documents before you answer, and say what changed' \
    'say that you could not confirm it, with the date the item was checked' \
    'Never edit the items in the plugin'; do
    grep -qF -- "$phrase" "$SKILL" || { why="SKILL.md does not say: $phrase"; return 1; }
  done
}
check "the SKILL.md keeps its rules on stale items and on not editing the items" skill_rules

no_agent_names() {
  local hit
  need "$SKILL" || return 1
  # A folder such as .claude/ is a path, not the agent's name.
  hit="$(grep -inE '(^|[^.a-z])(askuserquestion|claude|codex|chatgpt|gpt-?[0-9]|opus|sonnet|haiku|gemini|copilot)' "$SKILL" | head -1)"
  [ -z "$hit" ] || { why="SKILL.md names an agent, its tool, or a model: $hit"; return 1; }
  ! sed -n '2,/^---$/p' "$SKILL" | grep -q '^allowed-tools:' || { why="SKILL.md has allowed-tools in its frontmatter"; return 1; }
}
check "the SKILL.md names no agent or its tool" no_agent_names

# The body is counted in words and the description in characters, as the size the agent reads.
SKILL_WORDS_MAX=500
SKILL_DESCRIPTION_MAX=300
skill_size() {
  need "$SKILL" || return 1
  python3 - "$SKILL" "$SKILL_WORDS_MAX" "$SKILL_DESCRIPTION_MAX" <<'PYEOF'
import re, sys
front, body = open(sys.argv[1], encoding="utf-8").read().split("---", 2)[1:]
words = len(body.split())
chars = len(re.search(r"^description: (.*)$", front, re.M).group(1))
print("      SKILL.md body %d words (max %s), description %d characters (max %s)" % (words, sys.argv[2], chars, sys.argv[3]))
sys.exit(0 if words <= int(sys.argv[2]) and chars <= int(sys.argv[3]) else 1)
PYEOF
}
check "the ethereum-knowledge SKILL.md stays within its size limits" skill_size

# One sentence of each description sends the other kind of EIP question to the other skill, so that
# one question starts one of the two skills.
descriptions_split() {
  need "$SKILL" "$STANDARDS_SKILL" || return 1
  why="$(python3 - "$SKILL" "$STANDARDS_SKILL" <<'PY'
import re, sys

def description(path):
    front = open(path, encoding="utf-8").read().split("---", 2)[1]
    return re.search(r"^description: (.*)$", front, re.M).group(1)

def naming(text, name):
    return [s for s in re.split(r"(?<=\.)\s+", text.strip()) if name in s]

own = naming(description(sys.argv[1]), "evm-standards")
other = naming(description(sys.argv[2]), "ethereum-knowledge")
if len(own) != 1:
    print("the ethereum-knowledge description has %d sentences naming evm-standards, not 1" % len(own))
elif not (re.search(r"\bERCs?\b", own[0]) and "contract" in own[0] and "wallet" in own[0]):
    print("the sentence naming evm-standards does not name ERCs, contracts, and wallets: " + own[0])
elif len(other) != 1:
    print("the evm-standards description has %d sentences naming ethereum-knowledge, not 1" % len(other))
elif not ("L2" in other[0] and "consensus" in other[0]):
    print("the sentence naming ethereum-knowledge does not name L2 and consensus: " + other[0])
PY
)"
  [ -z "$why" ]
}
check "the two descriptions split the EIP questions" descriptions_split

# The coverage table of each README: the covered column names L2 and consensus, and the column of
# what is not covered names neither. The Japanese words are built from code points.
readme_tables() {
  need "$PLUGIN/README.md" "$PLUGIN/README.ja.md" || return 1
  why="$(python3 - "$PLUGIN/README.md" "$PLUGIN/README.ja.md" <<'PY'
import re, sys

ja = lambda *points: "".join(map(chr, points))

def columns(path, header):
    lines = open(path, encoding="utf-8").read().splitlines()
    if header not in lines:
        return None
    rows = []
    for line in lines[lines.index(header) + 2:]:
        if not line.startswith("|"):
            break
        rows.append([cell.strip() for cell in line.strip().strip("|").split("|")])
    return " ".join(r[0] for r in rows), " ".join(r[-1] for r in rows)

consensus_ja = ja(0x30B3, 0x30F3, 0x30BB, 0x30F3, 0x30B5, 0x30B9)
for path, header, consensus in (
    (sys.argv[1], "| Covered | Not covered |", r"(?i)consensus"),
    (sys.argv[2], "| " + ja(0x6271, 0x3046) + " | " + ja(0x6271, 0x308F, 0x306A, 0x3044) + " |", consensus_ja),
):
    found = columns(path, header)
    if found is None:
        print("%s has no coverage table" % path.rsplit("/", 1)[-1])
        break
    covered, left = found
    if "L2" not in covered or not re.search(consensus, covered):
        print("the covered column of %s does not name L2 and consensus" % path.rsplit("/", 1)[-1])
        break
    if "L2" in left or re.search(consensus, left):
        print("the not covered column of %s still names L2 or consensus" % path.rsplit("/", 1)[-1])
        break
PY
)"
  [ -z "$why" ]
}
check "the README tables cover L2 and consensus" readme_tables

# Each how-it-works page names the script, the items it reads, and a table of its two commands, and
# no sentence of it leaves L2 networks or consensus-only EIPs out.
how_it_works() {
  need "$PLUGIN/docs/how-it-works.md" "$PLUGIN/docs/how-it-works.ja.md" || return 1
  why="$(python3 - "$PLUGIN/docs/how-it-works.md" "$PLUGIN/docs/how-it-works.ja.md" <<'PY'
import re, sys

ja = lambda *points: "".join(map(chr, points))
topic = re.compile("L2|(?i:consensus)|" + ja(0x30B3, 0x30F3, 0x30BB, 0x30F3, 0x30B5, 0x30B9))
left_out = re.compile(r"(?i:left out|leaves? out|not covered|do(?:es)? not cover|exclud)|" + "|".join((ja(0x5916, 0x3057), ja(0x5916, 0x3059), ja(0x5916, 0x308C), ja(0x6271, 0x308F, 0x306A))))
for path in sys.argv[1:]:
    name = path.rsplit("/", 1)[-1]
    text = open(path, encoding="utf-8").read()
    if "skills/ethereum-knowledge/scripts/ethereum-knowledge.sh" not in text or "skills/ethereum-knowledge/references/items/" not in text:
        print("%s does not name the script and the items it reads" % name)
        break
    lines = text.splitlines()
    start = next(i for i, line in enumerate(lines) if "ethereum-knowledge.sh" in line)
    block = []
    for line in lines[start:]:
        if line.startswith("## ") and block:
            break
        block.append(line)
    if not any(line.startswith("| `check` |") for line in block) or not any(line.startswith("| `list` |") for line in block):
        print("%s does not give a table of check and list next to the script" % name)
        break
    sentences = [s for line in lines for s in re.split(r"(?<=[.;])\s+|(?<=" + ja(0x3002) + ")", line) if s]
    hit = next((s for s in sentences if topic.search(s) and left_out.search(s)), None)
    if hit:
        print("%s still leaves them out: %s" % (name, hit[:100]))
        break
PY
)"
  [ -z "$why" ]
}
check "how-it-works describes the ethereum-knowledge script" how_it_works

manifests_name() {
  need "$PLUGIN/.claude-plugin/plugin.json" "$PLUGIN/.codex-plugin/plugin.json" "$REPO/.claude-plugin/marketplace.json" || return 1
  why="$(python3 - "$PLUGIN/.claude-plugin/plugin.json" "$PLUGIN/.codex-plugin/plugin.json" "$REPO/.claude-plugin/marketplace.json" <<'PY'
import json, sys
descriptions = [(sys.argv[1], json.load(open(sys.argv[1]))["description"]), (sys.argv[2], json.load(open(sys.argv[2]))["description"])]
descriptions += [(sys.argv[3], p["description"]) for p in json.load(open(sys.argv[3]))["plugins"] if p["name"] == "evm-dev"]
if len(descriptions) != 3:
    print("the marketplace has no single evm-dev entry")
for path, text in descriptions:
    if "L2" not in text or "consensus" not in text:
        print("the description in %s does not name L2 and consensus" % "/".join(path.split("/")[-2:]))
        break
PY
)"
  [ -z "$why" ]
}
check "the manifests name L2 and consensus" manifests_name

# changelog_entries <changelog>: the entry lines of ## [Unreleased] and of every release section.
changelog_entries() { awk '/^## \[/ { on = 1 } on' "$1" | grep '^- '; }

# A release moves the line from ## [Unreleased] into a release section, and later releases push it
# further down, so the line counts under Unreleased or any release. A throwaway changelog whose line
# sits under an older release counts, and one whose sections do not name the skill does not.
changelog_names() {
  need "$PLUGIN/CHANGELOG.md" || return 1
  printf '%s\n' '# Changelog' '' '## [Unreleased]' '' '## [2.0.0] - 2026-01-02' '' '- Something else' '' \
    '## [1.0.0] - 2026-01-01' '' '- `ethereum-knowledge` arrives' > "$T/older.md"
  printf '%s\n' '# Changelog' '' '## [Unreleased]' '' '- Something else' '' '## [1.0.0] - 2026-01-01' '' \
    '- Another thing' > "$T/none.md"
  changelog_entries "$T/older.md" | grep -qF 'ethereum-knowledge' \
    || { why="a line under an older release is not counted"; return 1; }
  ! changelog_entries "$T/none.md" | grep -qF 'ethereum-knowledge' \
    || { why="a changelog whose sections do not name the skill is counted"; return 1; }
  changelog_entries "$PLUGIN/CHANGELOG.md" | grep -qF 'ethereum-knowledge' \
    || { why="no line under ## [Unreleased] or any release names ethereum-knowledge"; return 1; }
}
check "the changelog names the new skill under Unreleased or any release" changelog_names

printf '%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
