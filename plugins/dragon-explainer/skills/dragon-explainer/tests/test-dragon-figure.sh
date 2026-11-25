#!/bin/bash
# Tests for the dragon figure of dragon-explainer:
# a `dragon` block names a .dragon notation file, render.py writes it as a still dragon block,
# and `dragon embed` draws it as an SVG so the finished page reads nothing from the network.
#
# What is checked:
#   1. The plugin is listed in the marketplace with both manifests, its README, how-it-works page,
#      changelog, icon, and Japanese counterparts.
#   2. A dragon block becomes a still dragon block with its caption, counted as the section's figure.
#   3. render.py refuses a dragon block whose file is missing, outside the content folder, or not .dragon.
#   4. After `dragon embed`, the page holds an SVG per dragon block, no dragon block, no network
#      script, and passes check.py.
#   5. The bundled English and Japanese samples carry a dragon figure and build through `dragon embed`.
#   6. SKILL.md runs `dragon check`, `dragon check --layout`, and `dragon embed` with a pinned version.
#
# Cases 4 and 5 run dragon with `npx -y @cardenelabs/dragon@<version>`, the version SKILL.md pins.
# Exit 0 when every case passes, 1 when any fails, 77 when python3 is missing.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN_DIR="$(cd "$SKILL_DIR/../.." && pwd)"
ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"
SCRIPTS="$SKILL_DIR/scripts"

command -v python3 > /dev/null || { echo "skip: python3 is missing"; exit 77; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
FAILED=()
why=""

check() {
  local name="$1" fn="$2"
  why=""
  if "$fn"; then
    echo "  PASS: $name"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $name${why:+ ($why)}"; FAIL=$((FAIL + 1)); FAILED+=("$name")
  fi
}

# The dragon version SKILL.md pins, as in `npx -y @cardenelabs/dragon@0.80.1 embed`.
dragon_version() {
  grep -oE '@cardenelabs/dragon@[0-9]+\.[0-9]+\.[0-9]+' "$SKILL_DIR/SKILL.md" 2>/dev/null | head -1 | sed 's/.*@//'
}

dragon() {
  local version
  version="$(dragon_version)"
  [ -n "$version" ] || { why="SKILL.md pins no dragon version"; return 1; }
  npx -y "@cardenelabs/dragon@$version" "$@"
}

# notation <file>: a small flow diagram in the dragon notation.
notation() {
  cat > "$1" <<'DRAGON'
flow Checking an order

box take as Take the order
choice ok as Is it paid
box ship as Ship it
box ask as Ask for payment

ok -> ask: not paid

step Take
  say The order arrives.
  start -> take

step Check
  say The payment is checked.
  take -> ok: check

step Ship
  say A paid order ships.
  ok -> ship: paid
  ship -> finish
DRAGON
}

# content <dir> <src>: a content JSON with one section whose only figure is a dragon block naming <src>.
content() {
  python3 - "$1" "$2" <<'PY'
import json, sys
out, src = sys.argv[1:3]
doc = {
    "lang": "en",
    "title": "Order checks",
    "lead": "An order is checked for payment before it ships.",
    "tabs": [{"key": "p", "title": "Flow", "sections": [{
        "id": "p-s1",
        "title": "How is an order checked?",
        "answer": "A paid order ships and an unpaid one waits.",
        "blocks": [
            {"type": "paragraph", "text": "The payment decides whether the order ships."},
            {"type": "dragon", "id": "f-order", "src": src, "caption": "Figure 1 How an order is checked"},
        ],
    }]}],
}
with open(out + "/content.json", "w", encoding="utf-8") as f:
    json.dump(doc, f, ensure_ascii=False, indent=2)
PY
}

# build <content.json> <out.html>: render, build, and embed the dragon figures.
build() {
  local dir body
  dir="$(dirname "$2")"
  body="$dir/body.html"
  python3 "$SCRIPTS/render.py" --in "$1" --out "$body" > "$dir/render.log" 2>&1 || { why="render.py refused: $(tail -1 "$dir/render.log")"; return 1; }
  python3 "$SCRIPTS/despace.py" "$body" > /dev/null 2>&1
  python3 "$SCRIPTS/build.py" --in "$body" --out "$2" > "$dir/build.log" 2>&1 || { why="build.py refused: $(tail -1 "$dir/build.log")"; return 1; }
  dragon embed "$2" --out "$2" > "$dir/embed.log" 2>&1 || { why="dragon embed failed: $(tail -1 "$dir/embed.log")"; return 1; }
}

plugin_is_listed_with_both_manifests() {
  python3 - "$ROOT" "$PLUGIN_DIR" <<'PY' || { why="see the line above"; return 1; }
import json, os, sys
root, plugin = sys.argv[1:3]
market = json.load(open(os.path.join(root, ".claude-plugin/marketplace.json")))
entry = next((p for p in market.get("plugins", []) if p.get("name") == "dragon-explainer"), None)
if not entry:
    sys.exit(print("    the marketplace has no dragon-explainer entry") or 1)
claude = json.load(open(os.path.join(plugin, ".claude-plugin/plugin.json")))
codex = json.load(open(os.path.join(plugin, ".codex-plugin/plugin.json")))
for key in ["name", "version", "description"]:
    if claude.get(key) != codex.get(key):
        sys.exit(print(f"    the two manifests differ in {key}") or 1)
if claude.get("name") != "dragon-explainer" or entry.get("description") != claude.get("description"):
    sys.exit(print("    the manifest name or description does not match the marketplace") or 1)
for f in ["README.md", "README.ja.md", "docs/how-it-works.md", "docs/how-it-works.ja.md", "CHANGELOG.md", "LICENSE", "assets/icon.svg", "skills/dragon-explainer/SKILL.md", "skills/dragon-explainer/agents/openai.yaml"]:
    if not os.path.isfile(os.path.join(plugin, f)):
        sys.exit(print(f"    {f} is missing") or 1)
PY
}

dragon_block_renders_a_still_block() {
  local d="$TMP/still"
  mkdir -p "$d"
  notation "$d/f-order.dragon"
  content "$d" "f-order.dragon"
  python3 "$SCRIPTS/render.py" --in "$d/content.json" --out "$d/body.html" > "$d/render.log" 2>&1 || { why="render.py refused: $(tail -1 "$d/render.log")"; return 1; }
  python3 - "$d/body.html" <<'PY' || { why="see the line above"; return 1; }
import re, sys
page = open(sys.argv[1], encoding="utf-8").read()
fig = re.search(r'<figure[^>]*class="[^"]*dragon[^"]*"[^>]*>(.*?)</figure>', page, re.S)
if not fig:
    sys.exit(print("    no dragon figure in the rendered page") or 1)
body = fig.group(1)
if '<pre class="dragon" data-still>' not in body or "box take as Take the order" not in body:
    sys.exit(print("    the figure does not hold the notation as a still dragon block") or 1)
if "How an order is checked" not in body or "<figcaption" not in body:
    sys.exit(print("    the figure has no caption") or 1)
if "data-nofig" in page:
    sys.exit(print("    the section with a dragon figure is marked as having none") or 1)
PY
}

dragon_block_refuses_bad_file() {
  local d="$TMP/bad" src
  mkdir -p "$d/inner"
  notation "$TMP/outside.dragon"
  printf 'not notation\n' > "$d/inner/notes.txt"
  for src in "missing.dragon" "../outside.dragon" "inner/notes.txt"; do
    content "$d" "$src"
    if python3 "$SCRIPTS/render.py" --in "$d/content.json" --out "$d/body.html" > "$d/render.log" 2>&1; then
      why="render.py accepted the dragon file $src"; return 1
    fi
    grep -q "f-order" "$d/render.log" || { why="the refusal for $src does not name the block"; return 1; }
  done
}

embedded_page_is_offline() {
  local d="$TMP/offline"
  mkdir -p "$d"
  notation "$d/f-order.dragon"
  content "$d" "f-order.dragon"
  build "$d/content.json" "$d/order.html" || return 1
  python3 - "$d/order.html" <<'PY' || { why="see the line above"; return 1; }
import re, sys
page = open(sys.argv[1], encoding="utf-8").read()
fig = re.search(r'<figure[^>]*class="[^"]*dragon[^"]*"[^>]*>(.*?)</figure>', page, re.S)
if not fig or "<svg" not in fig.group(1):
    sys.exit(print("    the dragon figure holds no SVG after dragon embed") or 1)
if '<pre class="dragon"' in page:
    sys.exit(print("    a dragon block is left after dragon embed") or 1)
if re.search(r'<script[^>]+src=["\']https?:', page):
    sys.exit(print("    a script still loads from the network") or 1)
PY
  python3 "$SCRIPTS/check.py" "$d/order.html" > "$d/check.log" 2>&1 || { why="check.py failed: $(grep -m1 '^NG' "$d/check.log")"; return 1; }
}

samples_build_with_dragon_figures() {
  local lang sample d
  for lang in en ja; do
    sample="$SKILL_DIR/examples/content.sample.json"
    [ "$lang" = ja ] && sample="$SKILL_DIR/examples/content.sample.ja.json"
    [ -f "$sample" ] || { why="$sample is missing"; return 1; }
    grep -q '"type": *"dragon"' "$sample" || { why="the $lang sample has no dragon block"; return 1; }
    d="$TMP/sample-$lang"
    mkdir -p "$d"
    cp -R "$SKILL_DIR/examples/." "$d/"
    cp "$sample" "$d/content.json"
    build "$d/content.json" "$d/sample.html" || { why="the $lang sample: $why"; return 1; }
    grep -q '<pre class="dragon"' "$d/sample.html" && { why="the $lang sample keeps a dragon block"; return 1; }
    python3 "$SCRIPTS/check.py" "$d/sample.html" > "$d/check.log" 2>&1 || { why="check.py failed on the $lang sample: $(grep -m1 '^NG' "$d/check.log")"; return 1; }
  done
}

skill_runs_dragon_check_and_embed() {
  local skill="$SKILL_DIR/SKILL.md" version
  [ -f "$skill" ] || { why="SKILL.md is missing"; return 1; }
  version="$(dragon_version)"
  [ -n "$version" ] || { why="SKILL.md pins no dragon version"; return 1; }
  grep -q "@cardenelabs/dragon@$version check " "$skill" || { why="SKILL.md does not run dragon check"; return 1; }
  grep -q "check --layout" "$skill" || { why="SKILL.md does not run dragon check --layout"; return 1; }
  grep -q "@cardenelabs/dragon@$version embed " "$skill" || { why="SKILL.md does not run dragon embed"; return 1; }
}

echo "[test-dragon-figure]"
check plugin-is-listed-with-both-manifests plugin_is_listed_with_both_manifests
check dragon-block-renders-a-still-block dragon_block_renders_a_still_block
check dragon-block-refuses-bad-file dragon_block_refuses_bad_file
check embedded-page-is-offline embedded_page_is_offline
check samples-build-with-dragon-figures samples_build_with_dragon_figures
check skill-runs-dragon-check-and-embed skill_runs_dragon_check_and_embed

echo ""
echo "[test-dragon-figure] ran: $((PASS + FAIL))"
echo "[test-dragon-figure] PASS: $PASS, FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "failed cases:"
  for name in "${FAILED[@]}"; do echo "    $name"; done
  exit 1
fi
exit 0
