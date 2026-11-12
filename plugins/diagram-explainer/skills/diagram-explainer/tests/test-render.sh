#!/bin/bash
# Tests for the content JSON -> finished HTML pipeline:
# render.py -> despace.py (Japanese only) -> ladder.py -> build.py.
#
# What is checked:
#   1. Both bundled samples (English and Japanese) build, and the finished files are
#      self-contained, carry the right <html lang> and interface text, give every section a
#      figure or a stated reason, and pass check.py.
#   2. Every block type renders.
#   3. Bad input is refused (unknown or removed block types, duplicate ids, unsafe html/css,
#      unknown lang, missing ladder definitions, unfinished documents).
#   4. Sentences split at the Japanese full stop only in Japanese documents.
#   5. The schema (references/content.schema.json) and render.py accept the same block types,
#      chart kinds, and languages.
#   6. With a headless browser: the scripts draw charts and write interface text in the
#      document language. Without one, these cases print "skip: no browser".
#
# Exit 0 when every case passes, 1 when any fails (the failing cases are listed),
# 77 when python3 is missing.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPTS="$SKILL_DIR/scripts"
RENDER="$SCRIPTS/render.py"
DESPACE="$SCRIPTS/despace.py"
LADDER="$SCRIPTS/ladder.py"
BUILD="$SCRIPTS/build.py"
CHECK="$SCRIPTS/check.py"
TEMPLATE="$SKILL_DIR/templates/starter-doc.html"
SCHEMA="$SKILL_DIR/references/content.schema.json"
SAMPLE_EN="$SKILL_DIR/examples/content.sample.json"
SAMPLE_JA="$SKILL_DIR/examples/content.sample.ja.json"
LADDERS="$SKILL_DIR/examples/ladders"
export PYTHONDONTWRITEBYTECODE=1

PASS=0
FAIL=0
FAILED=()

_pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
_fail() { echo "  FAIL: $1${2:+ ($2)}"; FAIL=$((FAIL + 1)); FAILED+=("$1"); }
_assert() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then _pass "$name"; else _fail "$name" "expected=$expected actual=$actual"; fi
}
_yes() { if eval "$2"; then _pass "$1"; else _fail "$1"; fi; }
_has() { grep -qF -- "$2" "$1"; }

if ! command -v python3 >/dev/null 2>&1; then
  echo "cannot run: python3 is missing"
  exit 77
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diagram-explainer-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

echo "[test-render]"

for f in "$RENDER" "$LADDER" "$BUILD" "$TEMPLATE" "$SCHEMA" "$SAMPLE_EN" "$SAMPLE_JA"; do
  [ -f "$f" ] || _fail "0-0 required file exists: ${f#"$SKILL_DIR"/}"
done

# --- 1. Bundled samples ---
build_sample() {
  local lang="$1" src="$2" body="$WORK/body-$1.html" out="$WORK/doc-$1.html"
  python3 "$RENDER" --in "$src" --out "$body" >"$WORK/log-$lang.txt" 2>&1 \
    && _pass "1-$lang-1 render.py exits 0" || { _fail "1-$lang-1 render.py exits 0"; cat "$WORK/log-$lang.txt"; return; }
  if [ "$lang" = ja ]; then
    if [ -f "$DESPACE" ]; then
      python3 "$DESPACE" "$body" >>"$WORK/log-$lang.txt" 2>&1 \
        && _pass "1-$lang-2 despace.py exits 0" || _fail "1-$lang-2 despace.py exits 0"
    else
      echo "  skip: 1-$lang-2 despace.py is not present"
    fi
  fi
  if grep -q 'data-ladder=' "$body"; then
    python3 "$LADDER" --html "$body" --src "$LADDERS" >>"$WORK/log-$lang.txt" 2>&1 \
      && _pass "1-$lang-3 ladder.py exits 0" || _fail "1-$lang-3 ladder.py exits 0"
  fi
  python3 "$BUILD" --in "$body" --out "$out" >>"$WORK/log-$lang.txt" 2>&1 \
    && _pass "1-$lang-4 build.py exits 0" || { _fail "1-$lang-4 build.py exits 0"; cat "$WORK/log-$lang.txt"; return; }

  _yes "1-$lang-5 no <iframe" "! grep -qi '<iframe' '$out'"
  _yes "1-$lang-6 no srcdoc" "! grep -qi 'srcdoc' '$out'"
  _yes "1-$lang-7 no <script src=" "! grep -qiE '<script[^>]* src=' '$out'"
  _yes "1-$lang-8 no <link rel=\"stylesheet\"" "! grep -qiE '<link[^>]*rel=\"?stylesheet' '$out'"
  _yes "1-$lang-9 no @import" "! grep -q '@import' '$out'"
  _yes "1-$lang-10 no leftover asset markers" "! grep -q 'diagram-explainer:asset' '$out'"
  _yes "1-$lang-11 <html lang=\"$lang\">" "_has '$out' '<html lang=\"$lang\">'"

  local result
  result="$(python3 - "$out" <<'PYEOF'
import re, sys
doc = open(sys.argv[1], encoding="utf-8").read()
secs = re.findall(r'<section class="doc-sec" id="([^"]+)"([^>]*)>(.*?)</section>', doc, re.S)
bad = [sid for sid, attrs, inner in secs
       if "<figure" not in inner and not re.search(r'\bdata-nofig="[^"]+"', attrs)]
print("%d %s" % (len(secs), ",".join(bad) or "-"))
PYEOF
)"
  _yes "1-$lang-12 every section has a <figure> or data-nofig (sections ${result%% *}, missing ${result#* })" \
    "[ '${result#* }' = '-' ] && [ '${result%% *}' -gt 0 ]"

  if [ -f "$CHECK" ]; then
    if python3 "$CHECK" "$out" >"$WORK/check-$lang.txt" 2>&1; then
      _pass "1-$lang-13 check.py reports no problems"
    else
      _fail "1-$lang-13 check.py reports no problems"
      grep -E '^(NG|  )' "$WORK/check-$lang.txt" | head -20 | sed 's/^/      /'
    fi
  else
    echo "  skip: 1-$lang-13 check.py is not present"
  fi
}

build_sample en "$SAMPLE_EN"
build_sample ja "$SAMPLE_JA"

EN="$WORK/doc-en.html"
JA="$WORK/doc-ja.html"
if [ -f "$EN" ]; then
  _yes "1-en-14 English contents button and labels" \
    "_has '$EN' 'aria-expanded=\"false\">☰ Contents</button>' && _has '$EN' 'aria-label=\"Contents\"' && _has '$EN' 'data-step=\"-1\">Previous section</button>' && _has '$EN' 'aria-label=\"Pages\"'"
  _yes "1-en-15 no Japanese interface text written by render.py" \
    "! _has '$EN' '☰ 目次' && ! _has '$EN' 'aria-label=\"目次\"' && ! _has '$EN' '>前の節<'"
fi
if [ -f "$JA" ]; then
  _yes "1-ja-14 Japanese contents button and labels" \
    "_has '$JA' 'aria-expanded=\"false\">☰ 目次</button>' && _has '$JA' 'aria-label=\"目次\"' && _has '$JA' 'data-step=\"-1\">前の節</button>' && _has '$JA' 'aria-label=\"ページ\"'"
  _yes "1-ja-15 no English interface text written by render.py" \
    "! _has '$JA' '☰ Contents' && ! _has '$JA' 'aria-label=\"Contents\"' && ! _has '$JA' '>Previous section<'"
fi

# --- 2. Every block type ---
cat > "$WORK/all-blocks.json" <<'JSONEOF'
{
  "title": "Every block",
  "lead": "One of each block type.",
  "tabs": [
    {
      "id": "t",
      "label": "Blocks",
      "sections": [
        {
          "id": "t-s1",
          "title": "Blocks",
          "blocks": [
            {"type": "paragraph", "text": "A paragraph."},
            {"type": "heading", "text": "A sub-heading"},
            {"type": "list", "items": ["first item", "second item"]},
            {"type": "table", "columns": ["Left", "Right"], "rows": [["top", "bottom"]]},
            {"type": "code", "language": "bash", "text": "echo hello"},
            {"type": "keys", "items": [{"term": "Key one", "text": "first"}, {"term": "Key two", "text": "second"}]},
            {"type": "cards", "items": [{"title": "Card one", "text": "first", "tone": "good"}, {"title": "Card two", "list": ["a", "b"]}]},
            {"type": "note", "tone": "warn", "title": "Careful", "text": "A warning."},
            {"type": "compare", "items": [{"label": "Before", "value": "10"}, {"label": "After", "value": "5"}]},
            {"type": "html", "id": "t-free", "caption": "Figure 1 A drawn box", "html": "<div class=\"box\">Box</div>", "css": ".box { border: 1px solid var(--line); }"},
            {"type": "chart", "id": "t-bars", "kind": "bars", "caption": "Figure 2 Bars", "spec": {"max": 10, "step": 5, "bars": [{"label": "A", "value": 3}]}},
            {"type": "details", "summary": "More detail", "blocks": [{"type": "paragraph", "text": "Inside the details."}]}
          ]
        }
      ]
    }
  ]
}
JSONEOF

python3 "$RENDER" --in "$WORK/all-blocks.json" --out "$WORK/all.html" >/dev/null 2>&1
_assert "2-0 every block type renders with exit 0" "0" "$?"
ALL="$WORK/all.html"
_yes "2-1 paragraph" "_has '$ALL' '<p>A paragraph.</p>'"
_yes "2-2 heading" "_has '$ALL' '<h3>A sub-heading</h3>'"
_yes "2-3 list" "_has '$ALL' '<li>first item</li>'"
_yes "2-4 table" "_has '$ALL' '<th>Left</th>'"
_yes "2-5 code" "_has '$ALL' 'class=\"language-bash\"'"
_yes "2-6 keys" "_has '$ALL' '<div class=\"keys\">'"
_yes "2-7 cards" "_has '$ALL' '<div class=\"card\" data-tone=\"good\">'"
_yes "2-8 note" "_has '$ALL' '<div class=\"note\" data-tone=\"warn\">'"
_yes "2-9 compare" "_has '$ALL' '<div class=\"compare\">'"
_yes "2-10 html with caption becomes a figure with scoped css" \
  "_has '$ALL' '<figure class=\"free\" id=\"t-free\">' && _has '$ALL' '<style>#t-free { .box'"
_yes "2-11 chart" "_has '$ALL' 'data-chart=\"bars\"' && _has '$ALL' 'type=\"application/json\" id=\"t-bars-spec\"'"
_yes "2-12 details and the blocks inside it" "_has '$ALL' '<details class=\"exp\">' && _has '$ALL' 'Inside the details.'"
_yes "2-13 lang defaults to en" "_has '$ALL' '<html lang=\"en\">'"

# --- 3. Refused input ---
_rc_render() { python3 "$RENDER" --in "$1" --out "$WORK/ng.html" >/dev/null 2>&1; echo "$?"; }
_variant() {
  # _variant <name> <python expression applied to the loaded JSON as d>
  python3 - "$WORK/all-blocks.json" "$WORK/$1.json" "$2" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
blocks = d["tabs"][0]["sections"][0]["blocks"]
exec(sys.argv[3])
json.dump(d, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False)
PYEOF
  echo "$WORK/$1.json"
}
_assert "3-1 unknown block type is refused" "1" "$(_rc_render "$(_variant unknown 'blocks[0]["type"] = "unknown-kind"')")"
_assert "3-2 the removed figure block is refused" "1" \
  "$(_rc_render "$(_variant figure 'blocks.append({"type": "figure", "id": "f1", "caption": "Figure 9 x"})')")"
_assert "3-3 duplicate ids are refused" "1" \
  "$(_rc_render "$(_variant dup 'blocks.append(dict(blocks[9]))')")"
_assert "3-4 <script> in an html block is refused" "1" \
  "$(_rc_render "$(_variant script 'blocks[9]["html"] = "<div>x</div><script>alert(1)</script>"')")"
_assert "3-5 <iframe> in an html block is refused" "1" \
  "$(_rc_render "$(_variant iframe 'blocks[9]["html"] = "<iframe srcdoc=\"x\"></iframe>"')")"
_assert "3-6 @import in css is refused" "1" \
  "$(_rc_render "$(_variant import 'blocks[9]["css"] = "@import url(x.css);"')")"
_assert "3-7 an unknown lang is refused" "1" "$(_rc_render "$(_variant lang 'd["lang"] = "fr"')")"
_assert "3-8 a section with an empty nofigure is refused" "1" \
  "$(_rc_render "$(_variant nofig 'd["tabs"][0]["sections"][0]["nofigure"] = " "')")"

printf '%s\n' '<html lang="en"><body><div class="ladder" data-ladder="missing"></div></body></html>' > "$WORK/ladder-missing.html"
python3 "$LADDER" --html "$WORK/ladder-missing.html" --src "$WORK" >/dev/null 2>&1
_assert "3-9 ladder.py refuses a slot with no definition" "1" "$?"

printf '%s\n' '{"schema_version": 1, "steps": [{"n": 1, "title": "a"}, {"n": 2, "title": "b"}], "back": [{"from": 1, "to": 2}]}' > "$WORK/forward.json"
printf '%s\n' '<html lang="en"><body><div class="ladder" data-ladder="forward"></div></body></html>' > "$WORK/ladder-forward.html"
python3 "$LADDER" --html "$WORK/ladder-forward.html" --src "$WORK" >/dev/null 2>&1
_assert "3-10 ladder.py refuses a back line that points forward" "1" "$?"

_rc_build() { printf '%s\n' "$1" > "$WORK/b-in.html"; python3 "$BUILD" --in "$WORK/b-in.html" --out "$WORK/b-out.html" >/dev/null 2>&1; echo "$?"; }
_assert "3-11 build.py refuses an <iframe>" "1" "$(_rc_build '<html><body><iframe src="x.html"></iframe></body></html>')"
_assert "3-12 build.py refuses an unfilled ladder slot" "1" "$(_rc_build '<html><body><div class="ladder" data-ladder="x"></div></body></html>')"
_assert "3-13 build.py refuses an empty <svg>" "1" "$(_rc_build '<html><body><svg viewBox="0 0 1 1"></svg></body></html>')"
_assert "3-14 build.py refuses a missing asset" "1" "$(_rc_build $'<style>\n/* diagram-explainer:asset nope.css */\n</style>')"
_assert "3-15 build.py refuses a mermaid diagram" "1" "$(_rc_build '<div class="mermaid">graph TD</div>')"
_assert "3-16 build.py accepts an empty chart <svg>" "0" "$(_rc_build '<html><body><svg data-chart="bars"></svg></body></html>')"

# --- 4. Sentence splitting ---
_variant split_en 'blocks[0]["text"] = "One。Two."' >/dev/null
python3 "$RENDER" --in "$WORK/split_en.json" --out "$WORK/split-en.html" >/dev/null 2>&1
_yes "4-1 an English document does not split at 。" "_has '$WORK/split-en.html' '<p>One。Two.</p>'"
_variant split_ja 'd["lang"] = "ja"; blocks[0]["text"] = "一つ目。二つ目。「中。」の後。"' >/dev/null
python3 "$RENDER" --in "$WORK/split_ja.json" --out "$WORK/split-ja.html" >/dev/null 2>&1
_yes "4-2 a Japanese document splits at 。 but not inside brackets" \
  "_has '$WORK/split-ja.html' '<p>一つ目。<br>二つ目。<br>「中。」の後。</p>'"

# --- 5. Schema and render.py agree ---
MISMATCH="$(python3 - "$SCHEMA" "$RENDER" <<'PYEOF'
import importlib.util, json, re, sys
schema = json.load(open(sys.argv[1], encoding="utf-8"))
src = open(sys.argv[2], encoding="utf-8").read()
block = schema["$defs"]["block"]
types = set(block["properties"]["type"]["enum"])
accepted = set(re.findall(r'kind == "([a-z]+)"', src))
spec = importlib.util.spec_from_file_location("render", sys.argv[2])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
charts = set()
for rule in block["allOf"]:
    if rule["if"]["properties"]["type"]["const"] == "chart":
        charts = set(rule["then"]["properties"]["kind"]["enum"])
langs = schema["properties"]["lang"]["enum"]
out = []
if not accepted or types != accepted:
    out.append("block types schema=%s render=%s" % (sorted(types), sorted(accepted)))
if charts != set(mod.CHARTS):
    out.append("chart kinds schema=%s render=%s" % (sorted(charts), sorted(mod.CHARTS)))
if list(langs) != list(mod.LANGS) or schema["properties"]["lang"].get("default") != mod.LANGS[0]:
    out.append("lang schema=%s render=%s" % (langs, list(mod.LANGS)))
print(" / ".join(out))
PYEOF
)"
_assert "5-1 schema and render.py accept the same types, chart kinds, and languages" "" "$MISMATCH"

# --- 6. In a headless browser ---
dump() {
  python3 - "$SCRIPTS" "$1" "$2" <<'PYEOF'
import sys
sys.path.insert(0, sys.argv[1])
import chrome
exe, _looked = chrome.find_chrome()
if not exe:
    print("NO_BROWSER")
    sys.exit(0)
out, err = chrome.run(exe, sys.argv[2], 1280, 900, 3000, 60)
if err:
    print("BROWSER_ERROR " + err)
    sys.exit(0)
open(sys.argv[3], "w", encoding="utf-8").write(out)
print("OK")
PYEOF
}
for lang in en ja; do
  [ -f "$WORK/doc-$lang.html" ] || continue
  state="$(dump "$WORK/doc-$lang.html" "$WORK/dom-$lang.html")"
  if [ "$state" = "NO_BROWSER" ]; then
    echo "  skip: no browser (6-$lang cases)"
    continue
  fi
  if [ "$state" != "OK" ]; then
    _fail "6-$lang-0 the browser opens the document" "$state"
    continue
  fi
  DOM="$WORK/dom-$lang.html"
  _yes "6-$lang-1 charts on the first page are drawn" "_has '$DOM' 'data-chart-drawn'"
  if [ "$lang" = en ]; then
    _yes "6-en-2 PDF menu in English" "_has '$DOM' 'data-print=\"page\">This page only</button>' && _has '$DOM' 'data-print=\"all\">All pages</button>'"
    _yes "6-en-3 time axis in English" "_has '$DOM' '>3:00</text>'"
    _yes "6-en-4 section count label in English" "_has '$DOM' 'aria-label=\"Section 1 of 4\"'"
  else
    _yes "6-ja-2 PDF menu in Japanese" "_has '$DOM' 'data-print=\"page\">このページだけ</button>' && _has '$DOM' 'data-print=\"all\">全部のページ</button>'"
    _yes "6-ja-3 time axis in Japanese" "_has '$DOM' '>3時</text>'"
    _yes "6-ja-4 section count label in Japanese" "_has '$DOM' 'aria-label=\"全4節中1節目\"'"
  fi
done

echo ""
echo "[test-render] PASS: $PASS, FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "failed cases:"
  printf '  %s\n' "${FAILED[@]}"
  exit 1
fi
exit 0
