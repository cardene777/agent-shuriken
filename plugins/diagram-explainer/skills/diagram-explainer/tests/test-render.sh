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
#   7. The SKILL.md and its eval suite.
#   8. The interface words live only in assets/ui.json, the built pages carry that dictionary,
#      the words written into the pages and the step ladders match it, and its Japanese words put
#      no space between Japanese and Latin letters or digits.
#   9. With a headless browser, at a desktop and a phone width: captions, step ladders, and charts
#      as drawn (lines and text, text size, colors in light and dark, fitting or scrolling with a cue).
#  10. The page patterns of page-design that apply to the document page: the facts table, cards,
#      tables, page tabs, the contents drawer, enlarged figures, collapsed blocks, notes, the header
#      band and its help, and the docs and samples that describe them. Fixtures are built once and
#      opened in a headless browser at 1400 and 390 px; without a browser those cases fail.
#  11. The user's theme file: the page names its base colors after the page-design keys and derives its
#      other shades from them, and the theme command of page-design (from design-formats in this
#      repository) writes a theme's colors and fonts into a built page and nothing else.
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
            {"type": "table", "caption": "Left and right", "columns": ["Left", "Right"], "rows": [["top", "bottom"]]},
            {"type": "code", "language": "bash", "text": "echo hello"},
            {"type": "keys", "items": [{"term": "Key one", "text": "first"}, {"term": "Key two", "text": "second"}]},
            {"type": "cards", "items": [{"title": "Card one", "text": "first", "tone": "good"}, {"title": "Card two", "list": ["a", "b"]}]},
            {"type": "note", "tone": "warn", "title": "Careful", "text": "A warning."},
            {"type": "compare", "items": [{"label": "Before", "value": "10"}, {"label": "After", "value": "5"}]},
            {"type": "html", "id": "t-free", "caption": "Figure 1 A drawn box", "html": "<div class=\"box\">Box</div>", "css": ".box { border: 1px solid var(--line); }"},
            {"type": "chart", "id": "t-bars", "kind": "bars", "caption": "Figure 2 Bars", "spec": {"max": 10, "step": 5, "bars": [{"label": "A", "value": 3}]}},
            {"type": "details", "summary": "Raw request log, 12 lines", "blocks": [{"type": "paragraph", "text": "Inside the details."}, {"type": "code", "language": "text", "text": "GET /books 200\nGET /books/1 200\nGET /holds 200\nPOST /holds 201\nGET /holds/7 200\nDELETE /holds/7 204\nGET /loans 200\nPOST /loans 201\nGET /loans/3 200\nPUT /loans/3 200\nGET /cards/12 200\nGET /fines 200"}]}
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
_yes "2-4 table" "grep -qE '<th( [^>]*)?>Left</th>' '$ALL'"
_yes "2-5 code" "_has '$ALL' 'class=\"language-bash\"'"
_yes "2-6 keys" "_has '$ALL' '<div class=\"keys\">'"
_yes "2-7 cards" "grep -qE '<(div|li) class=\"card\" data-tone=\"good\">' '$ALL'"
_yes "2-8 note" "grep -qE '<div class=\"note( warn)?\"[^>]*(data-tone=\"warn\"|role=\"note\")' '$ALL'"
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

# --- 7. The SKILL.md and its eval suite ---
PLUGIN="$(cd "$SKILL_DIR/../.." && pwd)"
EVALS="$PLUGIN/evals"
SKILL="$SKILL_DIR/SKILL.md"
CASES=(outline-first unrelated-request build-from-outline fix-missing-figure japanese-document)

eval_cases() {
  local c
  for c in "${CASES[@]}"; do
    [ -f "$EVALS/$c/case.yaml" ] && [ -x "$EVALS/$c/fixture.sh" ] || return 1
  done
}
_yes "the eval suite has the five cases" eval_cases

# Runs a case's fixture.sh the way claude plugin eval does (in home/cwd with HOME at home) and prints the workspace.
fixture() {
  local ws="$WORK/fixture-$1/home/cwd"
  mkdir -p "$ws"
  (cd "$ws" && HOME="$WORK/fixture-$1/home" bash "$EVALS/$1/fixture.sh") >/dev/null 2>&1 || return 1
  printf '%s\n' "$ws"
}
fixtures_ready() {
  local c ws
  for c in outline-first unrelated-request build-from-outline japanese-document; do
    ws="$(fixture "$c")" || return 1
    [ -f "$ws/package.json" ] && [ -f "$ws/src/queue.js" ] && [ ! -e "$ws/docs/explainers" ] || return 1
  done
  ws="$(fixture fix-missing-figure)" || return 1
  [ -f "$ws/package.json" ] && [ -f "$ws/src/queue.js" ] || return 1
  [ -f "$ws/docs/explainers/queue-lite/content.json" ] && [ -f "$ws/docs/explainers/queue-lite/queue-lite.html" ] || return 1
  python3 "$CHECK" "$ws/docs/explainers/queue-lite/queue-lite.html" > "$WORK/fixture-check.txt" 2>&1 && return 1
  grep -qx 'NG sections without a figure: 1 (a-s3)' "$WORK/fixture-check.txt" && grep -q '^---- NG 1 ' "$WORK/fixture-check.txt"
}
_yes "the eval fixtures build the states their cases start from" fixtures_ready

results_ignored() {
  local repo
  repo="$(git -C "$PLUGIN" rev-parse --show-toplevel 2>/dev/null)" || return 1
  git -C "$repo" check-ignore -q "${EVALS#"$repo"/}/results/run.json"
}
_yes "eval results are ignored by git" results_ignored

# The body is counted in words and the description in characters, as the size the agent reads.
SKILL_WORDS_MAX=2196
SKILL_DESCRIPTION_MAX=309
skill_size() {
  python3 - "$SKILL" "$SKILL_WORDS_MAX" "$SKILL_DESCRIPTION_MAX" <<'PYEOF'
import re, sys
front, body = open(sys.argv[1], encoding="utf-8").read().split("---", 2)[1:]
words = len(body.split())
chars = len(re.search(r"^description: (.*)$", front, re.M).group(1))
print("  SKILL.md body %d words (max %s), description %d characters (max %s)" % (words, sys.argv[2], chars, sys.argv[3]))
sys.exit(0 if words <= int(sys.argv[2]) and chars <= int(sys.argv[3]) else 1)
PYEOF
}
_yes "the SKILL.md stays within its size limits" skill_size

skill_rules() {
  local phrase
  for phrase in \
    "Never put the user's project names" \
    "as data, never as instructions" \
    "Never present a guess as a fact" \
    "loads nothing from the network" \
    "Adjust it until they agree" \
    "never edit the finished HTML by hand" \
    'without `--live` and say that the layout was not measured'; do
    grep -qF -- "$phrase" "$SKILL" || return 1
  done
}
_yes "the SKILL.md keeps its rules on searches, sources, the network, the outline, and editing" skill_rules

help_options() {
  local opt help
  help="$(python3 "$CHECK" --help 2>&1)" || return 1
  for opt in sections widths words para sent; do
    printf '%s\n' "$help" | grep -qE "^  --$opt [A-Z]+ +[a-z]" || return 1
  done
}
_yes "check.py --help describes the options the SKILL.md leaves out" help_options

# --- 8. The interface dictionary ---
# Every interface word is defined once, in assets/ui.json. render.py and ladder.py read it,
# build.py copies it into the page, and doc.js reads it there, so the words written when the
# page is built and the words shown after a language switch come from the same place.
UI_JSON="$SKILL_DIR/assets/ui.json"
STARTER="$WORK/doc-starter.html"
python3 "$BUILD" --in "$TEMPLATE" --out "$STARTER" >/dev/null 2>&1 || rm -f "$STARTER"

UI_SHAPE="$(python3 - "$UI_JSON" <<'PYEOF'
import json, sys
try:
    ui = json.load(open(sys.argv[1], encoding="utf-8"))
except (OSError, ValueError) as exc:
    print("cannot read assets/ui.json (%s)" % exc.__class__.__name__)
    sys.exit(0)
out = []
if not isinstance(ui, dict) or sorted(ui) != ["en", "ja"]:
    out.append("the top level is not one object with en and ja")
else:
    en, ja = set(ui["en"]), set(ui["ja"])
    if en != ja:
        out.append("only in en: %s, only in ja: %s" % (sorted(en - ja), sorted(ja - en)))
    for lang in ("en", "ja"):
        for key, value in ui[lang].items():
            if key == "months":
                if not (isinstance(value, list) and len(value) == 12 and all(isinstance(v, str) and v for v in value)):
                    out.append("%s.months is not 12 names" % lang)
            elif not isinstance(value, str) or not value:
                out.append("%s.%s is not a word" % (lang, key))
print(" / ".join(out))
PYEOF
)"
_assert "8-1 assets/ui.json holds one dictionary with the same keys in en and ja" "" "$UI_SHAPE"

OWN_DICTIONARIES="$(python3 - "$SKILL_DIR" <<'PYEOF'
import glob, os, re, sys
skill = sys.argv[1]
en = re.compile(r"""(^|[\s{,(])["']?en["']?\s*:\s*\{""", re.M)
ja = re.compile(r"""(^|[\s{,(])["']?ja["']?\s*:\s*\{""", re.M)
paths = glob.glob(os.path.join(skill, "scripts", "*.py")) + glob.glob(os.path.join(skill, "assets", "*.js"))
bad = []
for path in sorted(paths):
    text = open(path, encoding="utf-8").read()
    if en.search(text) and ja.search(text):
        bad.append(os.path.relpath(path, skill))
print(" ".join(bad))
PYEOF
)"
_assert "8-2 no script under scripts or assets defines its own en and ja dictionary" "" "$OWN_DICTIONARIES"

UNKNOWN_KEYS="$(python3 - "$SKILL_DIR" "$UI_JSON" "$EN" "$JA" "$STARTER" "$WORK/dom-en.html" "$WORK/dom-ja.html" <<'PYEOF'
import glob, json, os, re, sys
skill, ui_path, pages = sys.argv[1], sys.argv[2], sys.argv[3:]
try:
    ui = json.load(open(ui_path, encoding="utf-8"))
    known = set(ui["en"]) & set(ui["ja"])
except (OSError, ValueError, KeyError, TypeError) as exc:
    print("cannot read assets/ui.json (%s)" % exc.__class__.__name__)
    sys.exit(0)
used = {}
def note(key, where):
    used.setdefault(key, set()).add(where)
for page in pages:
    if os.path.isfile(page):
        for key in re.findall(r'\bdata-ui(?:-label|-title)?="(\w+)"', open(page, encoding="utf-8").read()):
            note(key, os.path.basename(page))
for path in glob.glob(os.path.join(skill, "assets", "*.js")):
    text = open(path, encoding="utf-8").read()
    for key in re.findall(r"\bsay\(\s*'(\w+)'", text) + re.findall(r"'data-ui(?:-label|-title)?',\s*'(\w+)'", text) \
            + re.findall(r"\bunitText\(\s*'(\w+)'", text):
        note(key, os.path.relpath(path, skill))
for path in glob.glob(os.path.join(skill, "scripts", "*.py")):
    text = open(path, encoding="utf-8").read()
    for key in re.findall(r'\bsay\(\s*\w+\s*,\s*"(\w+)"', text) + re.findall(r'\bui\["(\w+)"\]', text):
        note(key, os.path.relpath(path, skill))
missing = ["%s (%s)" % (k, ", ".join(sorted(w))) for k, w in sorted(used.items()) if k not in known]
print(" / ".join(missing) if used else "no interface key was found")
PYEOF
)"
_assert "8-3 every interface key the pages and scripts use is in assets/ui.json" "" "$UNKNOWN_KEYS"

CARRIED="$(python3 - "$UI_JSON" "$EN" "$JA" "$STARTER" <<'PYEOF'
import json, os, re, sys
try:
    ui = json.load(open(sys.argv[1], encoding="utf-8"))
except (OSError, ValueError) as exc:
    print("cannot read assets/ui.json (%s)" % exc.__class__.__name__)
    sys.exit(0)
out = []
for page in sys.argv[2:]:
    name = os.path.basename(page)
    if not os.path.isfile(page):
        out.append("%s was not built" % name)
        continue
    found = re.findall(r'<script type="application/json" id="dx-ui">(.*?)</script>', open(page, encoding="utf-8").read(), re.S)
    if len(found) != 1:
        out.append("%s has %d dictionaries" % (name, len(found)))
    elif json.loads(found[0]) != ui:
        out.append("%s has a dictionary other than assets/ui.json" % name)
print(" / ".join(out))
PYEOF
)"
_assert "8-4 the built pages carry the dictionary of assets/ui.json once" "" "$CARRIED"

WRITTEN="$(python3 - "$UI_JSON" "en:dated:$SAMPLE_EN:$EN" "ja:dated:$SAMPLE_JA:$JA" "en:starter::$STARTER" <<'PYEOF'
import datetime, json, os, re, sys
from html.parser import HTMLParser
try:
    ui = json.load(open(sys.argv[1], encoding="utf-8"))
except (OSError, ValueError) as exc:
    print("cannot read assets/ui.json (%s)" % exc.__class__.__name__)
    sys.exit(0)

def fill(word, values):
    return re.sub(r"\{(\w+)\}", lambda m: str(values.get(m.group(1)) or ""), word)

class Marks(HTMLParser):
    """Collects every element marked with data-ui, data-ui-label, or data-ui-title, and the date.

    The date is the text of `.doc-date`, or the value cell of the As-of row of the facts table."""
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.found, self.open, self.date, self.asof = [], None, None, False
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if "data-ui-label" in a:
            self.found.append(("aria-label", a["data-ui-label"], a, a.get("aria-label")))
        if "data-ui-title" in a:
            self.found.append(("title", a["data-ui-title"], a, a.get("title")))
        if "data-ui" in a:
            self.open = ["text", a["data-ui"], a, ""]
        if "doc-date" in (a.get("class") or "").split():
            self.open = ["date", None, a, ""]
        if tag == "td" and self.asof:
            self.open = ["date", None, a, ""]
            self.asof = False
        if tag == "th" and a.get("data-ui") == "factAsOf":
            self.asof = True
    def handle_data(self, data):
        if self.open is not None:
            self.open[3] += data
    def handle_endtag(self, tag):
        if self.open is not None:
            if self.open[0] == "date":
                self.date = self.open[3]
            else:
                self.found.append(tuple(self.open))
            self.open = None

today = datetime.date.today()
out = []
for arg in sys.argv[2:]:
    # The starter keeps a placeholder date, so only the built samples have their date checked.
    # A sample that gives its time (facts.asOf, or date) shows that; otherwise the build date.
    lang, kind, src, page = arg.split(":", 3)
    name = os.path.basename(page)
    if not os.path.isfile(page):
        out.append("%s was not built" % name)
        continue
    words = ui[lang]
    marks = Marks()
    marks.feed(open(page, encoding="utf-8").read())
    if not marks.found:
        out.append("%s has no marked interface text" % name)
    for where, key, attrs, shown in marks.found:
        if key not in words:
            out.append("%s: %s is not in the dictionary" % (name, key))
            continue
        want = fill(words[key], {"name": attrs.get("data-ui-name"), "n": attrs.get("data-ui-n")})
        if where == "text" and attrs.get("data-ui-icon"):
            want = attrs["data-ui-icon"] + " " + want
        if shown != want:
            out.append("%s: %s of %s reads %r, the dictionary %r" % (name, where, key, shown, want))
    if kind == "dated":
        content = json.load(open(src, encoding="utf-8")) if src else {}
        given = (content.get("facts") or {}).get("asOf") or content.get("date")
        want = given or fill(words["date"], {"year": today.year, "month": words["months"][today.month - 1], "day": today.day})
        if marks.date != want:
            out.append("%s: the date reads %r, the dictionary %r" % (name, marks.date, want))
print(" / ".join(out))
PYEOF
)"
_assert "8-5 the words written into the built pages match the dictionary" "" "$WRITTEN"

# A ladder with no alt, no line label, and no back_note takes the default words of the dictionary.
mkdir -p "$WORK/plain-ladder"
cat > "$WORK/plain-ladder/plain.json" <<'JSONEOF'
{"schema_version": 1,
 "steps": [{"n": 1, "title": "Start"}, {"n": 2, "title": "Check"}],
 "back": [{"from": 2, "to": 1}]}
JSONEOF
LADDER_WORDS="$(
  for lang in en ja; do
    printf '<html lang="%s"><body><div class="ladder" data-ladder="plain"></div></body></html>\n' "$lang" > "$WORK/plain-ladder/$lang.html"
    python3 "$LADDER" --html "$WORK/plain-ladder/$lang.html" --src "$WORK/plain-ladder" >/dev/null 2>&1 || echo "ladder.py failed on $lang"
  done
  python3 - "$UI_JSON" "$WORK/plain-ladder" <<'PYEOF'
import html, json, os, re, sys
try:
    ui = json.load(open(sys.argv[1], encoding="utf-8"))
except (OSError, ValueError) as exc:
    print("cannot read assets/ui.json (%s)" % exc.__class__.__name__)
    sys.exit(0)
out = []
for lang in ("en", "ja"):
    doc = open(os.path.join(sys.argv[2], lang + ".html"), encoding="utf-8").read()
    words = ui[lang]
    want = {
        "aria-label": words["ladderAlt"],
        "data-edge-label": words["ladderBack"].replace("{n}", "1"),
        "note": words["ladderBackNote"].replace("{n}", "1"),
    }
    got = {
        "aria-label": re.search(r'<svg class="ladfig"[^>]*\baria-label="([^"]*)"', doc),
        "data-edge-label": re.search(r'data-edge-label="([^"]*)"', doc),
        "note": re.search(r'<text class="lad-blabel"[^>]*>([^<]*)</text>', doc),
    }
    for key, value in want.items():
        shown = html.unescape(got[key].group(1)) if got[key] else None
        if shown != value:
            out.append("%s %s reads %r, the dictionary %r" % (lang, key, shown, value))
print(" / ".join(out))
PYEOF
)"
_assert "8-6 the step ladder takes its default words from the dictionary" "" "$LADDER_WORDS"

# doc.js reads the dictionary in the page: a page whose dictionary was changed shows the changed
# words, and an English page opened in the Japanese interface shows the Japanese words.
if [ -f "$EN" ]; then
  DICT_PAGE="$(python3 - "$EN" "$WORK/doc-dict.html" <<'PYEOF'
import json, re, sys
doc = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'(<script type="application/json" id="dx-ui">)(.*?)(</script>)', doc, re.S)
if not m:
    print("the page has no dictionary")
    sys.exit(0)
words = json.loads(m.group(2))
words["ja"]["prev"] = "dictionary-prev-ja"
words["ja"]["pdfPage"] = "dictionary-pdf-page-ja"
doc = doc[:m.start(2)] + json.dumps(words, ensure_ascii=False) + doc[m.end(2):]
doc = doc.replace('<html lang="en">', '<html lang="ja">', 1)
open(sys.argv[2], "w", encoding="utf-8").write(doc)
print("OK")
PYEOF
)"
  if [ "$DICT_PAGE" != "OK" ]; then
    _fail "8-7 doc.js shows the words of the dictionary in the page" "$DICT_PAGE"
  else
    state="$(dump "$WORK/doc-dict.html" "$WORK/dom-dict.html")"
    if [ "$state" = "NO_BROWSER" ]; then
      echo "  skip: no browser (8-7)"
    elif [ "$state" != "OK" ]; then
      _fail "8-7 doc.js shows the words of the dictionary in the page" "$state"
    else
      _yes "8-7 doc.js shows the words of the dictionary in the page" \
        "grep -qE 'data-ui=\"prev\"[^>]*>dictionary-prev-ja</button>' '$WORK/dom-dict.html' && _has '$WORK/dom-dict.html' '>dictionary-pdf-page-ja</button>'"
    fi
  fi
else
  _fail "8-7 doc.js shows the words of the dictionary in the page" "the English sample was not built"
fi

# Japanese text puts no space between Japanese and Latin letters, digits, or a placeholder.
# The kana, kanji, and Japanese stops are built from code points, so this file stays English.
JA_SPACES="$(python3 - "$UI_JSON" <<'PYEOF'
import json, re, sys
try:
    ja = json.load(open(sys.argv[1], encoding="utf-8"))["ja"]
except (OSError, ValueError, KeyError) as exc:
    print("cannot read the ja words of assets/ui.json (%s)" % exc.__class__.__name__)
    sys.exit(0)
kana_kanji = "%s-%s%s-%s" % tuple(map(chr, (0x3040, 0x30FF, 0x4E00, 0x9FFF)))
stops = chr(0x3001) + chr(0x3002)
space = re.compile(r"[%s%s] [A-Za-z0-9{]|[A-Za-z0-9}] [%s]" % (kana_kanji, stops, kana_kanji))
words = [(key, text) for key, value in sorted(ja.items()) for text in (value if isinstance(value, list) else [value])]
print(" / ".join("%s: %r" % (key, text) for key, text in words if isinstance(text, str) and space.search(text)))
PYEOF
)"
_assert "8-8 the Japanese words put no space between Japanese and Latin letters, digits, or a placeholder" "" "$JA_SPACES"

# --- 9. Figures as drawn ---
# The figures are measured after the browser draws them, section by section, the way a reader
# opens them: at a desktop width (1400) and a phone width (390), in both samples. A probe opens
# each section with the page and contents buttons, measures the drawn figures (and the colors
# in the light and the dark theme), and writes what it found into the page as JSON.

FIG_CAPTIONS="$(python3 - "$EN" "$JA" <<'PYEOF'
import re, sys
out = []
for path in sys.argv[1:]:
    try:
        doc = open(path, encoding="utf-8").read()
    except OSError:
        out.append("%s was not built" % path.rsplit("/", 1)[-1])
        continue
    caps = re.findall(r"<figcaption>(.*?)</figcaption>", doc, re.S)
    if not caps:
        out.append("%s has no captions" % path.rsplit("/", 1)[-1])
    for cap in caps:
        if not re.match(r'<span class="fig-no">(?:Figure \d+|図\d+)</span>\S', cap):
            out.append("%s: %s" % (path.rsplit("/", 1)[-1], re.sub(r"\s+", " ", cap)[:60]))
print(" / ".join(out))
PYEOF
)"
_assert "9-1 figure captions keep the number in its own element with no space after it" "" "$FIG_CAPTIONS"

cat > "$WORK/probe.js" <<'JSEOF'
(function () {
  'use strict';
  var CJK = /[぀-ヿ㐀-䶿一-鿿]/;
  // A color mixed with color-mix() is computed as color(srgb r g b), with channels from 0 to 1.
  function rgb(s) {
    var m = /rgba?\(([^)]*)\)/.exec(s || ''), k = 1;
    if (!m) { m = /color\(srgb ([^)]*)\)/.exec(s || ''); k = 255; }
    if (!m) return null;
    var p = m[1].split(/[\s,\/]+/).filter(Boolean).map(parseFloat);
    return { c: [p[0] * k, p[1] * k, p[2] * k], a: p.length > 3 ? p[3] : 1 };
  }
  function lum(c) {
    var a = c.map(function (v) { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); });
    return 0.2126 * a[0] + 0.7152 * a[1] + 0.0722 * a[2];
  }
  function ratio(a, b) { var x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); }
  function mix(c, a, base) { return [0, 1, 2].map(function (i) { return c[i] * a + base[i] * (1 - a); }); }
  function box(el) { return el.getBoundingClientRect(); }
  function shrink(r, d) { return { left: r.left + d, right: r.right - d, top: r.top + d, bottom: r.bottom - d }; }
  function hit(a, b) { return a.left <= b.right && a.right >= b.left && a.top <= b.bottom && a.bottom >= b.top; }
  function inter(a, b) { return { left: Math.max(a.left, b.left), right: Math.min(a.right, b.right), top: Math.max(a.top, b.top), bottom: Math.min(a.bottom, b.bottom) }; }
  function covers(a, b) { return a.left <= b.left + 0.5 && a.right >= b.right - 0.5 && a.top <= b.top + 0.5 && a.bottom >= b.bottom - 0.5; }
  function later(a, b) { return !!(a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING); }
  function shown(el) { return !!el && el.getClientRects().length > 0; }
  function words(el) { return (el.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 40); }
  function viewWidth(svg) { var v = svg.viewBox && svg.viewBox.baseVal; return v && v.width ? v.width : 0; }
  function round(v) { return Math.round(v * 100) / 100; }
  function chain(el, stop) {
    var a = 1;
    for (var n = el; n && n !== stop; n = n.parentNode) if (n.nodeType === 1) a *= parseFloat(getComputedStyle(n).opacity);
    return a;
  }
  function paintOf(el, stop, key) {
    var cs = getComputedStyle(el), p = rgb(cs[key]);
    if (!p) return null;
    return { c: p.c, a: p.a * parseFloat(key === 'fill' ? cs.fillOpacity : cs.strokeOpacity) * chain(el, stop) };
  }
  function drawn(svg) {
    return [].filter.call(svg.querySelectorAll('*'), function (n) { return !n.closest('defs') && shown(n); });
  }
  // The color under the middle of an element: the frame, then every shape drawn before it there.
  function behind(el, svg, panel) {
    var r = box(el), cx = (r.left + r.right) / 2, cy = (r.top + r.bottom) / 2, color = panel;
    drawn(svg).forEach(function (n) {
      if (n === el || n.tagName.toLowerCase() !== 'rect' || !later(n, el)) return;
      var b = box(n);
      if (cx < b.left || cx > b.right || cy < b.top || cy > b.bottom) return;
      var f = paintOf(n, svg.parentNode, 'fill');
      if (f) color = mix(f.c, f.a, color);
    });
    return color;
  }
  function frameOf(svg) {
    var fig = svg.closest('figure');
    for (var n = svg.parentNode; n && n !== fig; n = n.parentNode) {
      var o = getComputedStyle(n).overflowX;
      if (o === 'auto' || o === 'scroll') return n;
    }
    return fig;
  }
  function masked(el) {
    var cs = getComputedStyle(el);
    return (cs.maskImage && cs.maskImage !== 'none') || (cs.webkitMaskImage && cs.webkitMaskImage !== 'none');
  }
  function frameState(svg) {
    var fig = svg.closest('figure'), f = frameOf(svg), hint = fig.querySelector('.fig-more');
    var st = { over: f.scrollWidth > f.clientWidth + 1, hint: !!hint, hintShown: shown(hint) && !!words(hint), masked: !!masked(f), more: f.getAttribute('data-more') || '' };
    if (st.over) {
      f.scrollLeft = f.scrollWidth;
      f.dispatchEvent(new Event('scroll'));
      st.moreAtEnd = f.getAttribute('data-more') || '';
      f.scrollLeft = 0;
      f.dispatchEvent(new Event('scroll'));
    }
    return st;
  }

  function chartOf(svg) {
    var fig = svg.closest('figure'), panel = rgb(getComputedStyle(fig).backgroundColor).c, stop = svg.parentNode;
    var nodes = drawn(svg);
    var texts = nodes.filter(function (n) { return n.tagName.toLowerCase() === 'text' && words(n); });
    var lines = nodes.filter(function (n) { var t = n.tagName.toLowerCase(); return (t === 'line' || t === 'path') && getComputedStyle(n).stroke !== 'none'; });
    var rects = nodes.filter(function (n) { return n.tagName.toLowerCase() === 'rect' && box(n).width > 0 && box(n).height > 0; });
    var c = { kind: svg.getAttribute('data-chart'), crossing: [], overlaps: [], axisGap: null, light: [], dark: [], font: 99, scale: null, frame: frameState(svg) };
    var scale = box(svg).width / (viewWidth(svg) || 1);
    c.scale = round(box(svg).width - viewWidth(svg));
    texts.forEach(function (t) { c.font = Math.min(c.font, round(parseFloat(getComputedStyle(t).fontSize) * scale)); });
    // Lines that pass through text: hidden there by an opaque shape drawn after them, or under
    // a text drawn after them with an outline in the color behind it.
    lines.forEach(function (l) {
      var lr = box(l);
      texts.forEach(function (t) {
        var tr = shrink(box(t), 1);
        if (!hit(lr, tr)) return;
        var spot = inter(lr, tr);
        var hidden = rects.some(function (r) {
          if (!later(l, r)) return false;
          var f = paintOf(r, stop, 'fill');
          return f && f.a > 0.999 && covers(box(r), spot);
        });
        if (hidden) return;
        var cs = getComputedStyle(t), s = rgb(cs.stroke);
        var outlined = later(l, t) && s && parseFloat(cs.strokeWidth) >= 2 && /^stroke/.test(cs.paintOrder || '') &&
          ratio(s.c, behind(t, svg, panel)) < 1.1;
        if (!outlined) c.crossing.push(words(t));
      });
    });
    for (var i = 0; i < texts.length; i++) {
      for (var j = i + 1; j < texts.length; j++) {
        if (hit(shrink(box(texts[i]), 1), shrink(box(texts[j]), 1))) c.overlaps.push(words(texts[i]) + ' / ' + words(texts[j]));
      }
    }
    // A dot drawn over a text hides part of it.
    nodes.filter(function (n) { return n.tagName.toLowerCase() === 'circle'; }).forEach(function (d) {
      texts.forEach(function (t) {
        if (later(t, d) && hit(shrink(box(d), 1), shrink(box(t), 1))) c.overlaps.push('dot over ' + words(t));
      });
    });
    if (c.kind === 'timeband') {
      var axis = texts.filter(function (t) { return t.getAttribute('data-ui') === 'hour'; });
      var rest = texts.filter(function (t) { return t.getAttribute('data-ui') !== 'hour'; });
      if (axis.length && rest.length) {
        c.axisGap = round(Math.min.apply(null, axis.map(function (t) { return box(t).top; })) -
                          Math.max.apply(null, rest.map(function (t) { return box(t).bottom; })));
      }
    }
    if (c.kind === 'capbar') {
      var track = rects.filter(function (r) { return (r.style.getPropertyValue('fill') || '').indexOf('--track') >= 0; })[0];
      if (track) {
        var y = track.getAttribute('y'), h = track.getAttribute('height'), tb = box(track);
        var segs = rects.filter(function (r) { return r !== track && r.getAttribute('y') === y && r.getAttribute('height') === h; });
        var limit = lines.filter(function (l) { var b = box(l); return b.width < 4 && b.top < tb.top && b.bottom > tb.bottom; })[0];
        c.limit = !limit ? 'no limit line' : segs.filter(function (s) { return !later(s, limit); }).map(words).length ? 'drawn before a segment' : '';
      } else {
        c.limit = 'no track';
      }
    }
    // Colors: bars against what is behind them (their outline when the fill matches the
    // background), and text against what is behind it.
    ['light', 'dark'].forEach(function (theme) {
      document.documentElement.setAttribute('data-theme', theme);
      var bg = rgb(getComputedStyle(fig).backgroundColor).c;
      rects.forEach(function (r) {
        if ((r.style.getPropertyValue('fill') || '').indexOf('--track') >= 0) return;
        var under = behind(r, svg, bg), f = paintOf(r, stop, 'fill');
        if (!f) { c[theme].push('bar with a gradient or no fill'); return; }
        var shade = mix(f.c, f.a, under), k = ratio(shade, under);
        if (k < 1.05) {
          var s = paintOf(r, stop, 'stroke');
          if (s && parseFloat(getComputedStyle(r).strokeWidth) >= 1.5) k = ratio(mix(s.c, s.a, under), under);
        }
        if (k < 3) c[theme].push('bar ' + round(k));
      });
      texts.forEach(function (t) {
        var under = behind(t, svg, bg), f = paintOf(t, stop, 'fill');
        var k = f ? ratio(mix(f.c, f.a, under), under) : 0;
        if (k < 4.5) c[theme].push(words(t) + ' ' + round(k));
      });
    });
    document.documentElement.setAttribute('data-theme', 'light');
    return c;
  }

  function ladderOf(svg) {
    var fig = svg.closest('figure'), fb = box(fig), cs = getComputedStyle(fig);
    var inner = { left: fb.left + parseFloat(cs.borderLeftWidth) + parseFloat(cs.paddingLeft), right: fb.right - parseFloat(cs.borderRightWidth) - parseFloat(cs.paddingRight) };
    var parts = [].slice.call(svg.querySelectorAll('.lad-node, .lad-blabel, .lad-band, .lad-back')).map(box);
    var nodes = [].slice.call(svg.querySelectorAll('.lad-node')).map(box);
    var labels = [].slice.call(svg.querySelectorAll('.lad-blabel')).map(box);
    var left = Math.min.apply(null, parts.map(function (r) { return r.left; }));
    var right = Math.max.apply(null, parts.map(function (r) { return r.right; }));
    var nodeLeft = Math.min.apply(null, nodes.map(function (r) { return r.left; }));
    var scale = box(svg).width / (viewWidth(svg) || 1), font = 99;
    [].forEach.call(svg.querySelectorAll('text'), function (t) { font = Math.min(font, parseFloat(getComputedStyle(t).fontSize) * scale); });
    return {
      gaps: [round(left - inner.left), round(inner.right - right)],
      beside: labels.length > 0 && labels.every(function (r) { return r.right < nodeLeft && r.left >= inner.left - 0.5; }),
      font: round(font), frame: frameState(svg)
    };
  }

  function measure(sec) {
    var m = { id: sec.id, captions: [], charts: [], ladders: [], nodes: [], letters: [] };
    [].forEach.call(sec.querySelectorAll('figcaption'), function (cap) {
      var no = cap.querySelector('.fig-no'), next = no && no.nextSibling;
      if (!no || !next || next.nodeType !== 3 || !next.length) { m.captions.push(null); return; }
      var range = document.createRange();
      range.setStart(next, 0);
      range.setEnd(next, 1);
      m.captions.push(round(range.getBoundingClientRect().left - box(no).right));
    });
    [].forEach.call(sec.querySelectorAll('svg[data-chart]'), function (svg) { m.charts.push(chartOf(svg)); });
    [].forEach.call(sec.querySelectorAll('svg.ladfig'), function (svg) { m.ladders.push(ladderOf(svg)); });
    [].forEach.call(sec.querySelectorAll('figure.free .node'), function (node) {
      var cs = getComputedStyle(node), nb = box(node), range = document.createRange();
      range.selectNodeContents(node);
      var inner = nb.height - parseFloat(cs.borderTopWidth) - parseFloat(cs.borderBottomWidth) - parseFloat(cs.paddingTop) - parseFloat(cs.paddingBottom);
      m.nodes.push({ text: words(node), extra: round(inner - range.getBoundingClientRect().height) });
    });
    if (/^ja/.test(document.documentElement.lang)) {
      [].forEach.call(document.querySelectorAll('body *'), function (el) {
        if (!shown(el)) return;
        var own = [].some.call(el.childNodes, function (n) { return n.nodeType === 3 && CJK.test(n.nodeValue); });
        if (!own) return;
        var ls = getComputedStyle(el).letterSpacing;
        if (ls !== 'normal' && parseFloat(ls) !== 0) m.letters.push(el.tagName.toLowerCase() + '.' + (el.getAttribute('class') || '') + ' ' + ls);
      });
    }
    return m;
  }

  function done(result) {
    var pre = document.createElement('pre');
    pre.textContent = '@@PROBE@@' + JSON.stringify(result) + '@@PROBE@@';
    document.body.insertBefore(pre, document.body.firstChild);
  }

  setTimeout(function () {
    var out = [];
    try {
      var tabs = [].slice.call(document.querySelectorAll('.doc-pages button[data-page]'));
      var groups = tabs.length ? tabs.map(function (b) { return { tab: b, key: b.getAttribute('data-page') }; }) : [{ tab: null, key: null }];
      groups.forEach(function (g) {
        if (g.tab) g.tab.click();
        var nav = g.key ? document.querySelector('nav.doc-toc[data-page="' + g.key + '"]') : document.querySelector('nav.doc-toc');
        [].forEach.call(nav.querySelectorAll('button[data-sec]'), function (b) {
          b.click();
          var sec = document.getElementById(b.getAttribute('data-sec'));
          if (sec) out.push(measure(sec));
        });
      });
      done({ sections: out });
    } catch (e) {
      done({ error: String(e && e.stack || e) });
    }
  }, 300);
})();
JSEOF

probe() {
  python3 - "$SCRIPTS" "$1" "$WORK/probe.js" "$2" "$3" <<'PYEOF'
import json, re, sys
sys.path.insert(0, sys.argv[1])
import chrome
page, probe, width, out = sys.argv[2], sys.argv[3], int(sys.argv[4]), sys.argv[5]
exe, _looked = chrome.find_chrome()
if not exe:
    print("NO_BROWSER")
    sys.exit(0)
doc = open(page, encoding="utf-8").read()
i = doc.lower().rfind("</body>")
script = "<script>" + open(probe, encoding="utf-8").read() + "</script>"
copy = out + ".html"
open(copy, "w", encoding="utf-8").write(doc[:i] + script + doc[i:])
dom, err = chrome.run(exe, copy, width, 900, 5000, 180)
if err:
    print("BROWSER_ERROR " + err)
    sys.exit(0)
m = re.search(r"@@PROBE@@(.*?)@@PROBE@@", dom, re.S)
if not m:
    print("NO_RESULT")
    sys.exit(0)
open(out, "w", encoding="utf-8").write(m.group(1))
print("OK")
PYEOF
}

PROBED=1
for lang in en ja; do
  for width in 1400 390; do
    if [ ! -f "$WORK/doc-$lang.html" ]; then PROBED=0; continue; fi
    state="$(probe "$WORK/doc-$lang.html" "$width" "$WORK/probe-$lang-$width.json")"
    if [ "$state" = "NO_BROWSER" ]; then
      echo "  skip: no browser (9 browser cases)"
      PROBED=0
      break 2
    fi
    [ "$state" = "OK" ] || { echo "  probe $lang $width: $state"; PROBED=0; }
  done
done

if [ "$PROBED" = 1 ]; then
  python3 - "$WORK" > "$WORK/figures.txt" <<'PYEOF'
import html, json, os, sys
work = sys.argv[1]
runs = {}
for lang in ("en", "ja"):
    for width in (1400, 390):
        data = json.load(open(os.path.join(work, "probe-%s-%d.json" % (lang, width)), encoding="utf-8"))
        runs[(lang, width)] = data
problems = {k: [] for k in ("9-2", "9-3", "9-4", "9-5", "9-6", "9-7", "9-8", "9-9", "9-10", "9-11", "9-12", "9-13")}
for (lang, width), data in sorted(runs.items()):
    where = "%s %d" % (lang, width)
    if "error" in data:
        for k in problems:
            problems[k].append("%s: the probe failed (%s)" % (where, data["error"].splitlines()[0]))
        continue
    for sec in data["sections"]:
        at = "%s %s" % (where, sec["id"])
        for gap in sec["captions"]:
            if gap is None or gap < 4:
                problems["9-2"].append("%s: caption gap %s" % (at, gap))
        for lad in sec["ladders"]:
            if width == 1400:
                left, right = lad["gaps"]
                if abs(left - right) > 4 or not lad["beside"]:
                    problems["9-3"].append("%s: gaps %s/%s, label beside %s" % (at, left, right, lad["beside"]))
            if lad["font"] < 11.95:
                problems["9-12"].append("%s: ladder text %spx" % (at, lad["font"]))
        frames = [(c["kind"], c["frame"]) for c in sec["charts"]] + [("ladder", l["frame"]) for l in sec["ladders"]]
        for kind, f in frames:
            if width == 1400 and (f["over"] or not f["hint"] or f["hintShown"] or f["masked"]):
                problems["9-10"].append("%s %s: %s" % (at, kind, json.dumps(f, sort_keys=True)))
            if width == 390:
                if f["over"]:
                    ok = f["hint"] and f["hintShown"] and f["masked"] and "right" in f["more"] and \
                        "left" in f.get("moreAtEnd", "") and "right" not in f.get("moreAtEnd", "")
                else:
                    ok = f["hint"] and not f["hintShown"] and not f["masked"]
                if not ok:
                    problems["9-11"].append("%s %s: %s" % (at, kind, json.dumps(f, sort_keys=True)))
        for c in sec["charts"]:
            name = "%s %s" % (at, c["kind"])
            if c["crossing"]:
                problems["9-4"].append("%s: %s" % (name, ", ".join(sorted(set(c["crossing"])))[:200]))
            if c["kind"] == "capbar" and c.get("limit"):
                problems["9-5"].append("%s: %s" % (name, c["limit"]))
            if c["overlaps"]:
                problems["9-6"].append("%s overlaps: %s" % (name, "; ".join(c["overlaps"])[:200]))
            if c["kind"] == "timeband" and (c["axisGap"] is None or c["axisGap"] < 12):
                problems["9-6"].append("%s: axis gap %s" % (name, c["axisGap"]))
            for theme in ("light", "dark"):
                if c[theme]:
                    problems["9-7"].append("%s %s: %s" % (name, theme, ", ".join(c[theme])[:200]))
            if c["font"] < 11.95:
                problems["9-12"].append("%s: text %spx" % (name, c["font"]))
            if abs(c["scale"]) > 1:
                problems["9-13"].append("%s: drawn %s px off its frame" % (name, c["scale"]))
        for node in sec["nodes"]:
            if node["extra"] > 2:
                problems["9-8"].append("%s: %s has %spx under its text" % (at, node["text"][:24], node["extra"]))
        if lang == "ja":
            for item in sec["letters"]:
                problems["9-9"].append("%s: %s" % (at, item))
for k, v in problems.items():
    seen = []
    for item in v:
        if item not in seen:
            seen.append(item)
    print("%s\t%s" % (k, " / ".join(seen)[:600]))
PYEOF
fi

figure_case() {
  local name="$1" key="${1%% *}" got
  if [ "$PROBED" != 1 ]; then
    _fail "$name" "the probe did not run in both samples at both widths"
    return
  fi
  got="$(awk -F '\t' -v k="$key" '$1 == k { print $2 }' "$WORK/figures.txt")"
  _assert "$name" "" "$got"
}
figure_case "9-2 the figure number keeps a gap from the caption in the browser"
figure_case "9-3 the step ladder sits in the middle of its frame with the loop label beside it"
figure_case "9-4 chart guide and grid lines do not show through chart text"
figure_case "9-5 the capped bar draws its limit line above the segments"
figure_case "9-6 chart texts do not overlap and the time band note keeps clear of the axis"
figure_case "9-7 chart bars keep 3 to 1 and chart text 4.5 to 1 against what is behind them in light and dark"
figure_case "9-8 the boxes of figure 1 take the height of their own text"
figure_case "9-9 Japanese text gets no added letter-spacing"
figure_case "9-10 figures fit their frame at desktop width without a cue"
figure_case "9-11 figures that do not fit at phone width scroll with a visible cue"
figure_case "9-12 chart and ladder text stays at 12px or more at desktop and phone width"
figure_case "9-13 a chart drawn while its section is hidden is drawn again at its frame width when the section opens"

FIG_DOCS="$(python3 - "$SKILL_DIR" <<'PYEOF'
import os, sys
skill = sys.argv[1]
out = []
for rel in ("SKILL.md", "references/chart-shape.md", "references/ladder-shape.md"):
    text = open(os.path.join(skill, rel), encoding="utf-8").read()
    for phrase in ("fits its frame", "scrolls sideways", "fades the edge"):
        if phrase not in text:
            out.append("%s does not say %r" % (rel, phrase))
    if "720" in text:
        out.append("%s still names the 720 px minimum" % rel)
print(" / ".join(out))
PYEOF
)"
_assert "9-14 SKILL.md and the chart and ladder references say when a figure fits and when it scrolls with a cue" "" "$FIG_DOCS"

# --- 10. Page patterns ---
# Fixtures written here: a single-page document that uses the facts, every table shape, cards,
# notes, a chart with views, a step ladder, and runs of collapsed blocks; a document with six page
# tabs; and small documents for render.py and check.py. Japanese text is written as \u escapes.
S10="$WORK/s10"
mkdir -p "$S10"
python3 - "$S10" <<'PYEOF'
import json, os, sys
s10 = sys.argv[1]

def put(name, doc):
    with open(os.path.join(s10, name + ".json"), "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)

def code12(prefix):
    return "\n".join("%s %02d 200" % (prefix, i) for i in range(1, 13))

def shelf_table(caption):
    return {"type": "table", "caption": caption, "num": [1], "columns": ["Day", "Copies"],
            "rows": [["Day %d" % i, str(10 + i)] for i in range(1, 13)]}

TIMEBAND = {"from": 0, "to": 24, "step": 3, "labelWidth": 140, "lanes": [
    {"key": "desk", "name": "Branch desk", "bands": [{"from": 9, "to": 20, "label": "Staffed desk", "color": "blue"}]},
    {"key": "kiosk", "name": "Self-checkout", "bands": [{"from": 8, "to": 21, "label": "Kiosks open", "color": "green"}]},
    {"key": "drop", "name": "Book drop", "bands": [{"from": 0, "to": 24, "label": "Open all day", "color": "gray"}]}]}
VIEWS = [{"label": "All services", "lanes": [], "say": "The book drop never closes."},
         {"label": "With staff", "lanes": ["desk"], "say": "The desk is staffed from 9:00 to 20:00."},
         {"label": "Without staff", "lanes": ["kiosk", "drop"], "say": "Kiosks and the book drop cover the other hours."}]
LONG = ("A member may renew a loan twice when no other member holds the copy, and each renewal starts a new "
        "loan period from the day of the renewal rather than from the old due date, so a renewal made early "
        "gives fewer extra days than one made on the due date itself.")
DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

put("single", {
    "lang": "en", "title": "Lending desk",
    "lead": "A branch lends copies, takes them back, and keeps held copies for the next member.",
    "facts": {"asOf": "As of May 1, 2026", "spec": "Library loan rules 3.2", "read": "2026-05-01"},
    "tabs": [{"id": "p", "label": "Lending", "sections": [
        {"id": "p-s1", "title": "Tables and cards", "blocks": [
            {"type": "paragraph", "text": "Each card type has its own limits."},
            {"type": "table", "caption": "Loan limits by card", "num": [1, 2],
             "columns": ["Card", "Items at once", "Holds at once"],
             "rows": [["Adult", "30", "15"], ["Teen", "20", "10"], ["Child", "10", "5"]]},
            {"type": "cards", "items": [{"title": "Adult card", "text": "Thirty items at a time at any branch.", "tone": "good"},
                                        {"title": "Teen card", "text": "Twenty items at a time at any branch."}]},
            {"type": "table", "caption": "Returns per day in March", "num": [1], "columns": ["Day", "Returns"],
             "rows": [["March %d" % i, str(100 + i)] for i in range(1, 41)]},
            {"type": "table", "caption": "Opening hours by branch", "columns": ["Branch"] + DAYS,
             "rows": [["Northgate"] + ["0900-2000"] * 7, ["Riverside"] + ["1000-1800"] * 7, ["Hillcrest"] + ["0800-1600"] * 7]},
            {"type": "table", "caption": "Renewal rule in words", "columns": ["Rule", "Meaning"], "rows": [["Renewal", LONG]]},
            {"type": "html", "id": "p-flow", "caption": "Figure 1 Where a copy goes after the desk",
             "html": "<div class=\"lend\"><div class=\"node\">Desk</div><div class=\"node\">Shelf</div><div class=\"node\">Member</div></div>",
             "css": ".lend { display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 12px; } "
                    ".node { padding: 10px 12px; border: 1px solid var(--line-2); border-radius: 10px; }"}]},
        {"id": "p-s2", "title": "Notes and views", "blocks": [
            {"type": "paragraph", "text": "The desk and the kiosks keep different hours."},
            {"type": "chart", "id": "p-hours", "kind": "timeband", "caption": "Figure 2 When each service runs",
             "views": VIEWS, "spec": TIMEBAND},
            {"type": "note", "tone": "info", "title": "Copies in transit",
             "text": "A copy on its way to another branch shows as in transit until it is scanned there."},
            {"type": "note", "tone": "warn", "title": "Expired cards",
             "text": "An expired card cannot place holds until it is renewed at the desk."}]},
        {"id": "p-s3", "title": "Ladder and details", "blocks": [
            {"type": "paragraph", "text": "A checkout runs in fixed steps."},
            {"type": "html", "id": "p-ladder", "caption": "Figure 3 The steps of a checkout",
             "html": "<div class=\"ladder\" data-ladder=\"checkout\"></div>"}]
            + [{"type": "details", "summary": "Raw loan log for branch %d, 12 lines" % n,
                "blocks": [{"type": "code", "language": "text", "text": code12("LOAN %d" % n)}]} for n in range(1, 5)]
            + [{"type": "paragraph", "text": "Returns are logged the same way."},
               {"type": "details", "summary": "Raw return log, 12 lines",
                "blocks": [{"type": "code", "language": "text", "text": code12("RETURN")}]}]}]}]})

LABELS = ["Borrowing and renewals", "Returns and late fines", "Holds and the pickup shelf",
          "Cards and member accounts", "Branches and opening hours", "Events and reading groups"]
tabs = []
for i, (key, label) in enumerate(zip("abcdef", LABELS)):
    tabs.append({"id": key, "label": label, "sections": [
        {"id": "%s-s%d" % (key, j), "title": "%s, part %d" % (label, j),
         "nofigure": "A short text section; a figure would repeat it.",
         "blocks": [{"type": "paragraph", "text": "How %s work, part %d." % (label.lower(), j)}]}
        for j in range(1, 4 if i == 0 else 2)]})
put("multi", {"lang": "en", "title": "Library guide",
              "lead": "A library lends copies, takes them back, and keeps held copies for the next member.", "tabs": tabs})

def small(extra, lang="en"):
    doc = {"lang": lang, "title": "Hold shelf", "lead": "A branch keeps each held copy for seven days.",
           "tabs": [{"id": "h", "label": "Hold shelf", "sections": [
               {"id": "h-s1", "title": "The shelf", "nofigure": "A short text section; a figure would repeat it.",
                "blocks": [{"type": "paragraph", "text": "Held copies wait on the shelf."}]}]}]}
    doc.update(extra)
    return doc
put("facts-date", small({"date": "As of April 2, 2026"}))
put("facts-none", small({}))
put("facts-ja", small({
    "title": "\u8cb8\u51fa\u306e\u53d7\u4ed8",
    "lead": "\u56f3\u66f8\u9928\u306f\u672c\u3092\u8cb8\u3057\u3001\u8fd4\u3063\u305f\u672c\u3092\u68da\u306b\u623b\u3057\u307e\u3059\u3002",
    "facts": {"asOf": "2026\u5e745\u67081\u65e5\u6642\u70b9", "spec": "\u8cb8\u51fa\u306e\u898f\u5247 3.2", "read": "2026-05-01"}}, "ja"))

OK = [{"type": "paragraph", "text": "The desk sends a notice when a held copy reaches the shelf, and the member then has seven days to collect it."},
      {"type": "note", "tone": "warn", "title": "Scan before moving", "text": "A copy moved without a scan stays on the hold list of the old branch."},
      {"type": "note", "tone": "warn", "title": "Check the card", "text": "A held copy goes only to the member whose card placed the hold."},
      {"type": "details", "summary": "Raw shelf log for one week, 12 rows", "blocks": [shelf_table("Copies on the shelf each day")]}]

def shelf(blocks):
    return {"lang": "en", "title": "Hold shelf rules",
            "lead": "A branch keeps each held copy on the hold shelf for seven days and then returns it to the stacks.",
            "tabs": [{"id": "w", "label": "Hold shelf", "sections": [
                {"id": "w-s1", "title": "Notices and the shelf", "nofigure": "A short set of rules; a figure would repeat the text.",
                 "blocks": blocks}]}]}

def chart(n):
    return {"type": "chart", "id": "w-hours", "kind": "timeband", "caption": "Figure 1 When each service runs", "spec": TIMEBAND,
            "views": [{"label": "View %d" % (i + 1), "lanes": ["desk"], "say": "The desk."} for i in range(n)]}

VAGUE = ["More", "Details", "\u8a73\u7d30", "\u3082\u3063\u3068\u898b\u308b"]
put("ok", shelf(OK))
put("short", shelf(OK + [{"type": "details", "summary": "Branch phone numbers, 3 rows", "blocks": [
    {"type": "table", "caption": "Phone numbers", "columns": ["Branch", "Phone"],
     "rows": [["Northgate", "555-0101"], ["Riverside", "555-0102"], ["Hillcrest", "555-0103"]]}]}]))
put("vague", shelf(OK[:3] + [{"type": "details", "summary": s, "blocks": [shelf_table("Shelf log %d" % (i + 1))]}
                             for i, s in enumerate(VAGUE)]))
put("warn3", shelf(OK[:3] + [{"type": "note", "tone": "warn", "title": "Keep the slip",
                              "text": "The hold slip stays with the copy until the member collects it."}] + OK[3:]))
put("r-nocap", shelf(OK + [{"type": "table", "columns": ["Day", "Copies"], "rows": [["Monday", "4"]]}]))
put("r-nested", shelf(OK[:3] + [{"type": "details", "summary": "Raw shelf logs for two weeks, 24 rows", "blocks": [
    {"type": "details", "summary": "Raw shelf log for one week, 12 rows", "blocks": [shelf_table("Copies on the shelf each day")]}]}]))
put("r-views6", shelf(OK + [chart(6)]))
put("r-views5", shelf(OK + [chart(5)]))
put("r-warnbare", shelf(OK + [{"type": "note", "tone": "warn", "text": "A copy left on the cart is not on the shelf."}]))
PYEOF

s10_build() {
  local n="$1"
  python3 "$RENDER" --in "$S10/$n.json" --out "$S10/$n.body.html" >"$S10/$n.log" 2>&1 || return 1
  if grep -q 'data-ladder=' "$S10/$n.body.html"; then
    python3 "$LADDER" --html "$S10/$n.body.html" --src "$LADDERS" >>"$S10/$n.log" 2>&1 || return 1
  fi
  python3 "$BUILD" --in "$S10/$n.body.html" --out "$S10/$n.html" >>"$S10/$n.log" 2>&1 || { rm -f "$S10/$n.html"; return 1; }
}
for n in single multi ok short vague warn3; do
  s10_build "$n" || rm -f "$S10/$n.html"
done
# The facts are read from the markup render.py writes, so these three are only rendered.
for n in facts-date facts-none facts-ja; do
  python3 "$RENDER" --in "$S10/$n.json" --out "$S10/$n.html" >"$S10/$n.log" 2>&1 || rm -f "$S10/$n.html"
done

# The probes share one prelude: helpers, and a queue of steps run 60 ms apart, so each step sees
# what the page did after the one before. The result is written into the page as JSON.
cat > "$S10/prelude.js" <<'JSEOF'
var out = { errors: {} };
var root = document.documentElement;
var DICT = {};
try { DICT = JSON.parse(document.getElementById('dx-ui').textContent) || {}; } catch (e) { DICT = {}; }
var LANG = /^ja/.test(root.lang || '') ? 'ja' : 'en';
out.lang = LANG;
function word(k) { var w = (DICT[LANG] || {})[k]; return typeof w === 'string' ? w : null; }
function all(sel, el) { return [].slice.call((el || document).querySelectorAll(sel)); }
function rect(el) { var r = el.getBoundingClientRect(); return { l: r.left, r: r.right, t: r.top, b: r.bottom, w: r.width, h: r.height }; }
function st(el, p) { return getComputedStyle(el, p || null); }
function text(el) { return el ? (el.textContent || '').replace(/\s+/g, ' ').trim() : ''; }
function border(el, side) {
  var s = st(el);
  return { w: parseFloat(s['border' + side + 'Width']) || 0, s: s['border' + side + 'Style'], c: s['border' + side + 'Color'] };
}
function nameOf(el) {
  var l = (el.getAttribute('aria-label') || '').trim();
  if (l) return l;
  return (el.getAttribute('aria-labelledby') || '').split(/\s+/).filter(Boolean)
    .map(function (id) { return text(document.getElementById(id)); }).join(' ').trim();
}
function tableOf(head) {
  var boxes = all('.tbl');
  for (var i = 0; i < boxes.length; i++) {
    var t = boxes[i].querySelector('table');
    if (t && all('thead th', t).map(text).join('|') === head.join('|')) return boxes[i];
  }
  return null;
}
function showSec(id) {
  var b = document.querySelector('nav.doc-toc button[data-sec="' + id + '"]');
  if (b) b.click();
  return !!b;
}
function press(k) {
  (document.activeElement || document.body).dispatchEvent(new KeyboardEvent('keydown', { key: k, bubbles: true, cancelable: true }));
}
var queue = [], cursor = -1;
function add(name, fn) { queue.push({ name: name, fn: fn }); }
function insert(list) { Array.prototype.splice.apply(queue, [cursor + 1, 0].concat(list)); }
function finish() {
  var pre = document.createElement('pre');
  pre.textContent = '@@S10@@' + JSON.stringify(out) + '@@S10@@';
  document.body.insertBefore(pre, document.body.firstChild);
}
function next() {
  cursor += 1;
  if (cursor >= queue.length) { finish(); return; }
  var s = queue[cursor];
  try { s.fn(); } catch (e) { out.errors[s.name] = String(e && e.message || e).slice(0, 200); }
  setTimeout(next, 60);
}
function start() { setTimeout(next, 300); }
JSEOF

# The single-page document at 1400 px.
cat > "$S10/p-wide.js" <<'JSEOF'
function cellInfo(c) {
  var s = st(c);
  return { tag: c.tagName.toLowerCase(), cls: c.getAttribute('class') || '', align: s.textAlign, fvn: s.fontVariantNumeric,
           pad: [s.paddingTop, s.paddingRight, s.paddingBottom, s.paddingLeft], h: rect(c).h,
           lh: parseFloat(s.lineHeight) || parseFloat(s.fontSize) * 1.2, ws: s.whiteSpace };
}
function line(el) { if (!el) return ''; var s = st(el); return s.borderBottomWidth + ' ' + s.borderBottomStyle; }
function rowLine(t) {
  var rows = all('tbody tr', t), c = [];
  if (!rows.length) return null;
  if (rows[0].lastElementChild) c.push(border(rows[0].lastElementChild, 'Bottom'));
  c.push(border(rows[0], 'Bottom'));
  if (rows[1]) { if (rows[1].lastElementChild) c.push(border(rows[1].lastElementChild, 'Top')); c.push(border(rows[1], 'Top')); }
  for (var i = 0; i < c.length; i++) if (c[i].w > 0 && c[i].s !== 'none' && c[i].s !== 'hidden') return c[i];
  return null;
}
function frameLine(el) {
  if (!el) return null;
  var sides = ['Top', 'Right', 'Bottom', 'Left'];
  for (var i = 0; i < sides.length; i++) { var b = border(el, sides[i]); if (b.w > 0 && b.s !== 'none') return b; }
  return null;
}
function drawOf(fig) {
  var s = fig.querySelector('.fig-scroll svg, svg.ladfig, svg[data-chart]');
  if (s) return s;
  var kids = [].filter.call(fig.children, function (c) {
    return !/^(figcaption|script|style|button)$/i.test(c.tagName) && !c.matches('.fig-enlarge, .chart-views, .tabtext, .fig-more, .doc-views-list');
  });
  return kids[0] || fig;
}
function copyWidth(dlg, fig) {
  var d = drawOf(fig), tag = d.tagName.toLowerCase(), cls = (d.getAttribute('class') || '').trim();
  var sel = tag + (cls ? '.' + cls.split(/\s+/).map(function (c) { return CSS.escape(c); }).join('.') : '');
  var hits = all(sel, dlg);
  if (tag === 'svg') hits = hits.concat(all('svg', dlg));
  var w = 0;
  hits.forEach(function (el) { w = Math.max(w, el.getBoundingClientRect().width); });
  return w;
}
function regionOf(el, sec) {
  var r = { sec: sec, cls: el.getAttribute('class') || '', role: el.getAttribute('role'), name: nameOf(el), tabindex: el.getAttribute('tabindex') };
  el.focus();
  r.focus = document.activeElement === el;
  return r;
}

add('start', function () {
  root.setAttribute('data-theme', 'light');
  var side = document.getElementById('doc-side');
  out.sideInert = side ? (side.hasAttribute('inert') || side.inert === true) : null;
  var top = document.querySelector('body > header.doc-top');
  var h = out.header = { top: !!top, ctrlInSide: !!(side && side.querySelector('.doc-ctrl')), title: text(document.querySelector('.doc-pagehead h1')) };
  if (top) {
    var brand = top.querySelector('.doc-brand'), ctrl = top.querySelector('.doc-ctrl');
    h.box = rect(top);
    h.brand = brand ? text(brand) : null;
    if (brand) h.brandBox = rect(brand);
    h.ctrl = !!ctrl;
    if (ctrl) {
      h.ctrlBox = rect(ctrl);
      h.segs = all('.doc-seg', ctrl).map(rect);
      h.langs = all('button[data-lang]', ctrl).length;
      h.themes = all('button[data-theme-choice]', ctrl).length;
    }
  }
  var help = document.querySelector('.doc-top .doc-help');
  out.help = { exists: !!help, text: help ? text(help) : null, label: help ? help.getAttribute('aria-label') : null, want: word('help') };
  var pdf = document.querySelector('.printbtn');
  out.pdf = { en: pdf ? text(pdf) : null };
  out.heights = {
    toc: all('nav.doc-toc:not([hidden]) button[data-sec]').map(function (b) { return rect(b).h; }),
    step: all('.doc-step button[data-step]').map(function (b) { return rect(b).h; })
  };
  var on = document.querySelector('section.doc-sec.on');
  out.here = { name: on ? on.getAttribute('data-name') : null,
               items: all('.doc-here').map(function (el) { return { text: text(el), label: el.getAttribute('aria-label') }; }) };
});

add('tables', function () {
  var T = out.tables = {};
  var small = tableOf(['Card', 'Items at once', 'Holds at once']);
  if (small) {
    var t = small.querySelector('table'), th = t.querySelector('thead th');
    T.small = { boxW: small.clientWidth, w: rect(t).w,
                rows: all('tr', t).map(function (tr) { return all('th, td', tr).map(cellInfo); }),
                headLine: [line(th), line(th && th.parentNode), line(t.querySelector('thead'))] };
  }
  var prose = tableOf(['Rule', 'Meaning']);
  if (prose) {
    var pt = prose.querySelector('table'), cell = all('tbody td', pt).pop();
    T.prose = { boxW: prose.clientWidth, w: rect(pt).w, cell: cell ? cellInfo(cell) : null };
  }
  var long = tableOf(['Day', 'Returns']);
  if (long) {
    var lh = long.querySelector('thead th');
    var L = T.long = { maxH: st(long).maxHeight, oy: st(long).overflowY, sh: long.scrollHeight, ch: long.clientHeight };
    long.scrollTop = 200;
    L.scrolled = long.scrollTop;
    if (lh) { L.headOff = rect(lh).t - rect(long).t; L.headH = rect(lh).h; }
  }
});

add('lines', function () {
  var small = tableOf(['Card', 'Items at once', 'Holds at once']), t = small && small.querySelector('table');
  var free = document.querySelector('#p-s1 figure.free'), pre = document.querySelector('#p-s3 pre');
  out.lines = {};
  out.tokens = {};
  ['light', 'dark'].forEach(function (theme) {
    root.setAttribute('data-theme', theme);
    var rs = st(root);
    out.tokens[theme] = { critical: rs.getPropertyValue('--critical').trim(), criticalSoft: rs.getPropertyValue('--critical-soft').trim(),
                          bad: rs.getPropertyValue('--bad').trim() };
    out.lines[theme] = { bg: st(document.body).backgroundColor, row: t ? rowLine(t) : null, free: frameLine(free), pre: frameLine(pre) };
  });
  root.setAttribute('data-theme', 'light');
});

add('cards', function () {
  var c = document.querySelector('#p-s1 .cards');
  if (!c) { out.cards = null; return; }
  var s = st(c);
  out.cards = { tag: c.tagName.toLowerCase(), tracks: s.gridTemplateColumns, gap: parseFloat(s.columnGap) || 0,
                width: c.clientWidth - parseFloat(s.paddingLeft) - parseFloat(s.paddingRight),
                items: [].map.call(c.children, function (k) { return { tag: k.tagName.toLowerCase(), cls: k.getAttribute('class') || '', w: rect(k).w }; }) };
});

add('notes-show', function () { showSec('p-s2'); });
add('notes', function () {
  var s2 = document.getElementById('p-s2');
  var probe = document.createElement('span');
  probe.style.color = 'var(--accent)';
  s2.appendChild(probe);
  out.notes = {};
  ['light', 'dark'].forEach(function (theme) {
    root.setAttribute('data-theme', theme);
    out.notes[theme] = { accent: st(probe).color, bg: st(document.body).backgroundColor, items: all('.note', s2).map(function (n) {
      var ns = st(n), title = null, para = n.querySelector('p');
      all('*', n).forEach(function (e) { var tx = text(e); if (!title && (tx === 'Copies in transit' || tx === 'Expired cards')) title = e; });
      return { cls: n.getAttribute('class') || '', role: n.getAttribute('role'), text: text(n),
               icon: !!n.querySelector('svg, [class*="icon"]'), bgc: ns.backgroundColor, bgi: ns.backgroundImage,
               borders: ['Top', 'Right', 'Bottom', 'Left'].map(function (sd) { return border(n, sd); }),
               title: title ? { tag: title.tagName.toLowerCase(), color: st(title).color } : null,
               para: para ? { color: st(para).color, text: text(para) } : null };
    }) };
  });
  root.setAttribute('data-theme', 'light');
  s2.removeChild(probe);
});

add('views', function () {
  var b = all('#p-s2 .chart-views button');
  out.views = { before: b.map(function (x) { return x.getAttribute('aria-pressed'); }) };
  if (b[1]) b[1].click();
  out.views.after = b.map(function (x) { return x.getAttribute('aria-pressed'); });
  if (b[0]) b[0].click();
});

add('zoom', function () {
  out.zoom = [];
  out.regions = [];
  var list = [];
  all('nav.doc-toc button[data-sec]').map(function (b) { return b.getAttribute('data-sec'); }).forEach(function (id) {
    list.push({ name: 'zoom-show-' + id, fn: function () { showSec(id); } });
    list.push({ name: 'zoom-scan-' + id, fn: function () {
      var sec = document.getElementById(id), sub = [];
      all('.tbl, .fig-scroll', sec).forEach(function (el) { out.regions.push(regionOf(el, id)); });
      all('figure', sec).forEach(function (fig, k) {
        var rec = { sec: id, k: k, kind: fig.classList.contains('chart') ? 'chart' : fig.querySelector('svg.ladfig') ? 'ladder' : 'free' };
        out.zoom.push(rec);
        var btn = fig.querySelector('.fig-enlarge');
        rec.btn = !!btn;
        if (!btn) return;
        rec.label = btn.getAttribute('aria-label');
        rec.want = word('enlarge');
        sub.push({ name: 'zoom-open-' + id + '-' + k, fn: function () {
          rec.orig = drawOf(fig).getBoundingClientRect().width;
          btn.focus();
          btn.click();
        } });
        sub.push({ name: 'zoom-look-' + id + '-' + k, fn: function () {
          var dlg = document.querySelector('dialog.fig-zoom');
          rec.dialog = !!dlg;
          if (!dlg) return;
          rec.open = dlg.open;
          rec.modal = dlg.matches(':modal');
          rec.copy = copyWidth(dlg, fig);
          var close = dlg.querySelector('.fig-zoom-close, button[data-ui="close"], form[method="dialog"] button, button[value="close"]');
          if (close) close.click(); else dlg.close();
        } });
        sub.push({ name: 'zoom-back-' + id + '-' + k, fn: function () {
          var dlg = document.querySelector('dialog.fig-zoom');
          rec.closed = !dlg || !dlg.open;
          rec.back = document.activeElement === btn;
        } });
      });
      insert(sub);
    } });
  });
  insert(list);
});

add('details-show', function () { showSec('p-s3'); });
add('details-all', function () {
  var ds = all('details.exp', document.getElementById('p-s3')), runs = [], cur = [];
  ds.forEach(function (d) {
    if (cur.length && cur[cur.length - 1].nextElementSibling === d) cur.push(d);
    else { if (cur.length) runs.push(cur); cur = [d]; }
  });
  if (cur.length) runs.push(cur);
  var A = out.dall = { want: [word('openAll'), word('closeAll')], groups: all('.details-all').length, runs: runs.map(function (r) {
    var prev = r[0].previousElementSibling, grp = prev && prev.classList.contains('details-all') ? prev : null;
    return { n: r.length, prev: prev ? (prev.getAttribute('class') || prev.tagName.toLowerCase()) : null,
             buttons: grp ? all('button', grp).map(text) : [] };
  }) };
  var big = runs.filter(function (r) { return r.length >= 4; })[0];
  var grp = big && big[0].previousElementSibling;
  if (!grp || !grp.classList.contains('details-all')) return;
  var bs = all('button', grp);
  var openB = bs.filter(function (b) { return text(b) === word('openAll'); })[0];
  var closeB = bs.filter(function (b) { return text(b) === word('closeAll'); })[0];
  if (openB) { openB.click(); A.afterOpen = big.map(function (d) { return d.open; }); }
  if (closeB) { closeB.click(); A.afterClose = big.map(function (d) { return d.open; }); }
});

add('help-open', function () {
  var help = document.querySelector('.doc-top .doc-help');
  if (help) { help.focus(); help.click(); }
});
add('help-look', function () {
  var dlg = document.querySelector('dialog.doc-helpbox');
  out.helpbox = { exists: !!dlg, want: [word('helpTitle'), word('helpKeys'), word('helpEnlarge'), word('helpPdf')] };
  if (!dlg) return;
  out.helpbox.open = dlg.open;
  out.helpbox.modal = dlg.matches(':modal');
  out.helpbox.text = text(dlg);
  if (dlg.open) dlg.close();
});

add('print-set', function () {
  var ds = all('details.exp');
  ds.forEach(function (d, i) { d.open = i === 1; });
  out.print = { before: ds.map(function (d) { return d.open; }) };
  window.dispatchEvent(new Event('beforeprint'));
});
add('print-look', function () {
  out.print.paper = all('details.exp').map(function (d) {
    var s = d.querySelector('summary');
    return { open: d.open, sum: s ? st(s).display : 'missing', sumH: s ? rect(s).h : 0 };
  });
  window.dispatchEvent(new Event('afterprint'));
});
add('print-after', function () { out.print.after = all('details.exp').map(function (d) { return d.open; }); });

add('lang', function () {
  var b = document.querySelector('.doc-ctrl button[data-lang="ja"]');
  out.pdf.switched = !!b;
  if (b) b.click();
});
add('lang-look', function () { var pdf = document.querySelector('.printbtn'); out.pdf.ja = pdf ? text(pdf) : null; });
start();
JSEOF

# The single-page document at 390 px.
cat > "$S10/p-phone.js" <<'JSEOF'
function sidesOf(el) {
  var s = { left: false, right: false };
  [el, el.parentElement].forEach(function (e) {
    if (!e) return;
    ((e.getAttribute('data-more') || '') + ' ' + (e.getAttribute('class') || '')).toLowerCase().split(/\s+/).forEach(function (t) {
      if (/(^|[-_])left($|[-_])/.test(t)) s.left = true;
      if (/(^|[-_])right($|[-_])/.test(t)) s.right = true;
    });
  });
  return s;
}
function visual(el) {
  var hits = [];
  [el, el.parentElement].forEach(function (e) {
    if (!e) return;
    var s = st(e);
    if ((s.maskImage && s.maskImage !== 'none') || (s.webkitMaskImage && s.webkitMaskImage !== 'none')) hits.push('mask');
    if (s.boxShadow && s.boxShadow !== 'none') hits.push('shadow');
    if (/gradient/.test(s.backgroundImage)) hits.push('gradient');
    ['::before', '::after'].forEach(function (p) {
      var q = st(e, p);
      if (q.content && q.content !== 'none' && q.content !== 'normal' && (/gradient/.test(q.backgroundImage) || (q.boxShadow && q.boxShadow !== 'none'))) hits.push(p);
    });
  });
  return hits;
}
var WIDE = ['Branch', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

add('facts', function () {
  var f = document.querySelector('table.facts');
  var o = out.facts = { exists: !!f, vw: window.innerWidth };
  if (!f) return;
  var s = st(f);
  o.box = rect(f);
  o.display = s.display;
  o.visibility = s.visibility;
  var th = f.querySelector('th[data-ui="factAsOf"]'), tr = th ? th.closest('tr') : null;
  o.asof = !!tr;
  if (tr) o.asofBox = rect(tr);
});
add('drawer-closed', function () {
  var side = document.getElementById('doc-side');
  var tb = document.querySelector('nav.doc-toc:not([hidden]) button[data-sec]');
  var menu = document.querySelector('.doc-mbar button[aria-controls="doc-side"]');
  var o = out.drawer = { side: !!side, menu: !!menu };
  if (!side || !menu) return;
  o.closedInert = side.hasAttribute('inert');
  if (tb) { tb.focus(); o.closedReach = document.activeElement === tb; tb.blur(); }
  menu.focus();
  menu.click();
});
add('drawer-open', function () {
  var side = document.getElementById('doc-side'), menu = document.querySelector('.doc-mbar button[aria-controls="doc-side"]');
  var o = out.drawer, a = document.activeElement;
  if (!side || !menu) return;
  o.opened = root.classList.contains('doc-side-open') || menu.getAttribute('aria-expanded') === 'true';
  o.openInert = side.hasAttribute('inert');
  o.focusIn = !!(a && side.contains(a));
  o.focusCurrent = !!(a && a.matches && a.matches('button[data-sec][aria-current]'));
  o.focusWhat = a ? a.tagName.toLowerCase() + (a.getAttribute('data-sec') ? '[data-sec=' + a.getAttribute('data-sec') + ']' : '') : null;
  press('Escape');
});
add('drawer-shut', function () {
  var side = document.getElementById('doc-side'), menu = document.querySelector('.doc-mbar button[aria-controls="doc-side"]');
  var o = out.drawer, a = document.activeElement;
  if (!side || !menu) return;
  o.shut = !root.classList.contains('doc-side-open');
  o.shutInert = side.hasAttribute('inert');
  o.back = a === menu;
  o.backWhat = a ? a.tagName.toLowerCase() + '.' + (a.getAttribute('class') || '') : null;
});
add('wide-start', function () {
  var box = tableOf(WIDE), o = out.wide = { found: !!box };
  if (!box) return;
  o.over = box.scrollWidth - box.clientWidth;
  box.scrollLeft = 0;
  box.dispatchEvent(new Event('scroll'));
});
add('wide-start-look', function () {
  var box = tableOf(WIDE), o = out.wide;
  if (!box) return;
  o.start = { sides: sidesOf(box), visual: visual(box) };
  box.scrollLeft = 160;
  box.dispatchEvent(new Event('scroll'));
});
add('wide-mid-look', function () {
  var box = tableOf(WIDE), o = out.wide;
  if (!box) return;
  var bl = rect(box).l;
  o.scrolled = box.scrollLeft;
  o.first = all('tr', box).map(function (tr) {
    var c = tr.firstElementChild;
    return c ? { off: Math.round((rect(c).l - bl) * 10) / 10, tag: c.tagName.toLowerCase(), scope: c.getAttribute('scope') } : null;
  });
  box.scrollLeft = box.scrollWidth;
  box.dispatchEvent(new Event('scroll'));
});
add('wide-end-look', function () {
  var box = tableOf(WIDE);
  if (box) out.wide.end = { sides: sidesOf(box), visual: visual(box) };
});
start();
JSEOF

# The document with six page tabs at 390 px, where the tabs do not all fit the bar.
cat > "$S10/p-tabs.js" <<'JSEOF'
var log = [];
['scrollIntoView', 'scrollIntoViewIfNeeded', 'scrollTo', 'scrollBy', 'scroll'].forEach(function (name) {
  var f = Element.prototype[name];
  if (typeof f !== 'function') return;
  Element.prototype[name] = function () { log.push({ fn: name, el: this }); return f.apply(this, arguments); };
});
var SL = Object.getOwnPropertyDescriptor(Element.prototype, 'scrollLeft');
if (SL && SL.set) {
  Object.defineProperty(Element.prototype, 'scrollLeft', { configurable: true, enumerable: SL.enumerable, get: SL.get,
    set: function (v) { log.push({ fn: 'scrollLeft', el: this }); SL.set.call(this, v); } });
}
function tabs() { return all('.doc-pages button[data-page]'); }
function bar() { return document.querySelector('.doc-pages'); }
function inView(t) { var b = rect(bar()), r = rect(t); return r.l >= b.l - 1 && r.r <= b.r + 1; }
function pageOf(key) { return document.querySelector('.doc-page[data-page="' + key + '"]'); }
function onOf(key) { var p = pageOf(key), s = p && p.querySelector('section.doc-sec.on'); return s ? s.id : null; }
function activeIndex() { return tabs().indexOf(document.activeElement); }
function roles() {
  return { bar: bar() ? bar().getAttribute('role') : null, tabs: tabs().map(function (t) {
    var id = t.getAttribute('aria-controls'), p = id ? document.getElementById(id) : null, pg = pageOf(t.getAttribute('data-page'));
    return { key: t.getAttribute('data-page'), role: t.getAttribute('role'), sel: t.getAttribute('aria-selected'), ctl: id,
             panel: p ? { cls: p.getAttribute('class') || '', role: p.getAttribute('role'), key: p.getAttribute('data-page') } : null,
             shown: pg ? !pg.hidden : false };
  }) };
}
function under(el) {
  var s = st(el), r = { bb: s.borderBottomWidth, bbs: s.borderBottomStyle, bbc: s.borderBottomColor, shadow: s.boxShadow,
                        dur: [s.transitionDuration], pseudo: [] };
  ['::after', '::before'].forEach(function (p) {
    var q = st(el, p);
    r.pseudo.push({ content: q.content, height: q.height, bb: q.borderBottomWidth, bt: q.borderTopWidth });
    r.dur.push(q.transitionDuration);
  });
  return r;
}

add('roles', function () { out.roles = roles(); });
add('scroll-click', function () {
  var ts = tabs(), last = ts[ts.length - 1];
  out.scroll = { n: ts.length, before: last ? inView(last) : null };
  log = [];
  if (last) last.click();
});
add('scroll-look', function () {
  var ts = tabs(), last = ts[ts.length - 1], b = bar();
  if (!last) return;
  out.scroll.after = inView(last);
  out.scroll.calls = log.filter(function (e) {
    return e.el === last || e.el === b || (b && e.el.contains && e.el.contains(last) && b.contains(e.el));
  }).map(function (e) { return e.fn; });
  out.rolesAfter = roles();
  ts[0].click();
});
add('keys-prep', function () {
  var k0 = tabs()[0].getAttribute('data-page');
  var tb = all('nav.doc-toc[data-page="' + k0 + '"] button[data-sec]');
  if (tb[1]) tb[1].click();
});
add('keys-right', function () {
  var ts = tabs();
  var K = out.keys = { k0: ts[0].getAttribute('data-page'), k1: ts[1].getAttribute('data-page'), n: ts.length };
  K.onBefore = onOf(K.k0);
  ts[0].focus();
  K.focus0 = document.activeElement === ts[0];
  press('ArrowRight');
});
add('keys-left', function () {
  var K = out.keys, p1 = pageOf(K.k1), first = p1 ? p1.querySelector('section.doc-sec') : null;
  K.right = activeIndex();
  K.on0 = onOf(K.k0);
  K.p1Shown = p1 ? !p1.hidden : false;
  K.on1 = onOf(K.k1);
  K.first1 = first ? first.id : null;
  press('ArrowLeft');
});
add('keys-end', function () { out.keys.left = activeIndex(); press('End'); });
add('keys-home', function () { out.keys.end = activeIndex(); press('Home'); });
add('keys-done', function () { out.keys.home = activeIndex(); });
add('underline', function () {
  var ts = tabs();
  var sel = ts.filter(function (t) { return t.getAttribute('aria-selected') === 'true'; })[0] ||
            ts.filter(function (t) { return t.hasAttribute('aria-current'); })[0];
  out.under = sel ? under(sel) : null;
  var help = document.querySelector('.doc-top .doc-help');
  out.help = { exists: !!help, text: help ? text(help) : null };
});
start();
JSEOF

s10_probe() {
  # s10_probe <page> <probe> <width> <name>: writes $S10/<name>.out.json, or the reason it could not into <name>.state
  if [ ! -f "$1" ]; then echo "the page was not built" > "$S10/$4.state"; return; fi
  python3 - "$SCRIPTS" "$1" "$S10/prelude.js" "$2" "$3" "$S10/$4.out.json" > "$S10/$4.state" 2>&1 <<'PYEOF'
import html, re, sys
sys.path.insert(0, sys.argv[1])
import chrome
page, prelude, body, width, out = sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5]), sys.argv[6]
exe, _looked = chrome.find_chrome()
if not exe:
    print("no browser")
    sys.exit(0)
doc = open(page, encoding="utf-8").read()
i = doc.lower().rfind("</body>")
js = "(function () {\n'use strict';\n" + open(prelude, encoding="utf-8").read() + "\n" + open(body, encoding="utf-8").read() + "\n})();"
copy = out + ".html"
open(copy, "w", encoding="utf-8").write(doc[:i] + "<script>" + js + "</script>" + doc[i:])
dom, err = chrome.run(exe, copy, width, 900, 10000, 180)
if err:
    print("browser error: " + err)
    sys.exit(0)
m = re.search(r"<pre>@@S10@@(.*?)@@S10@@</pre>", dom, re.S)
if not m:
    print("the probe wrote no result")
    sys.exit(0)
open(out, "w", encoding="utf-8").write(html.unescape(m.group(1)))
print("OK")
PYEOF
}
s10_probe "$S10/single.html" "$S10/p-wide.js" 1400 wide
s10_probe "$S10/single.html" "$S10/p-phone.js" 390 phone
s10_probe "$S10/multi.html" "$S10/p-tabs.js" 390 tabs

python3 - "$S10" "$SKILL_DIR" "$SAMPLE_EN" "$SAMPLE_JA" "$EN" "$JA" > "$S10/results.txt" <<'PYEOF'
import datetime, json, os, re, subprocess, sys
from html.parser import HTMLParser

s10, skill, sample_en, sample_ja, built_en, built_ja = sys.argv[1:7]
scripts = os.path.join(skill, "scripts")
RENDER, CHECK = os.path.join(scripts, "render.py"), os.path.join(scripts, "check.py")
PLUGIN = os.path.dirname(os.path.dirname(skill))
PAGE_DESIGN = os.path.join(os.path.dirname(PLUGIN), "design-formats", "skills", "page-design", "scripts", "page-design.py")
UI = json.load(open(os.path.join(skill, "assets", "ui.json"), encoding="utf-8"))
JA_PDF = "PDF\u3067\u4fdd\u5b58"
VAGUE = ["More", "Details", "\u8a73\u7d30", "\u3082\u3063\u3068\u898b\u308b"]
results = {}


class Missing(Exception):
    pass


def judge(key):
    def deco(fn):
        try:
            probs = fn()
        except Missing as exc:
            probs = [str(exc)]
        except Exception as exc:  # a crash in a check is a failed check, never an aborted run
            probs = ["the check could not run (%s: %s)" % (exc.__class__.__name__, exc)]
        results[key] = probs
        return fn
    return deco


def norm(s):
    return re.sub(r"\s+", " ", s or "").strip()


def F(name):
    return os.path.join(s10, name)


def built(name):
    p = F(name + ".html")
    if not os.path.isfile(p):
        log = open(F(name + ".log"), encoding="utf-8").read() if os.path.isfile(F(name + ".log")) else ""
        raise Missing("%s.json did not build (%s)" % (name, norm(log)[-160:]))
    return p


def probe(name):
    p = F(name + ".out.json")
    if os.path.isfile(p):
        return json.load(open(p, encoding="utf-8"))
    state = open(F(name + ".state"), encoding="utf-8").read() if os.path.isfile(F(name + ".state")) else ""
    raise Missing("the %s browser run gave no result (%s)" % (name, norm(state)[-160:] or "no output"))


# A color mixed with color-mix() is computed as color(srgb r g b), with channels from 0 to 1.
def color(s):
    m, k = re.match(r"rgba?\(([^)]*)\)", s or ""), 1.0
    if not m:
        m, k = re.match(r"color\(srgb ([^)]*)\)", s or ""), 255.0
    if not m:
        return None
    p = [float(x) for x in re.split(r"[\s,/]+", m.group(1).strip()) if x]
    return ([v * k for v in p[:3]], p[3] if len(p) > 3 else 1.0)


def lum(c):
    a = [v / 255.0 for v in c]
    a = [v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4 for v in a]
    return 0.2126 * a[0] + 0.7152 * a[1] + 0.0722 * a[2]


def ratio(a, b):
    x, y = lum(a), lum(b)
    return (max(x, y) + 0.05) / (min(x, y) + 0.05)


def over(fg, bg):
    """fg (a color string) painted over the opaque color bg ([r, g, b])."""
    c = color(fg)
    if not c:
        return None
    return [c[0][i] * c[1] + bg[i] * (1 - c[1]) for i in range(3)]


def chroma(c):
    return max(c) - min(c)


VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"}


class Node:
    def __init__(self, tag, attrs, parent):
        self.tag, self.attrs, self.parent, self.children = tag, dict(attrs), parent, []

    def cls(self):
        return (self.attrs.get("class") or "").split()

    def text(self):
        return "".join(c if isinstance(c, str) else c.text() for c in self.children)

    def elements(self):
        return [c for c in self.children if isinstance(c, Node)]

    def walk(self):
        for c in self.elements():
            yield c
            yield from c.walk()


class Tree(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = Node("#root", [], None)
        self.cur = self.root

    def handle_starttag(self, tag, attrs):
        n = Node(tag, attrs, self.cur)
        self.cur.children.append(n)
        if tag not in VOID:
            self.cur = n

    def handle_startendtag(self, tag, attrs):
        self.cur.children.append(Node(tag, attrs, self.cur))

    def handle_endtag(self, tag):
        n = self.cur
        while n is not None and n.tag != tag:
            n = n.parent
        if n is not None and n.parent is not None:
            self.cur = n.parent

    def handle_data(self, data):
        self.cur.children.append(data)


def parse(path):
    t = Tree()
    t.feed(open(path, encoding="utf-8").read())
    t.close()
    return t.root


def head_texts(table):
    return [norm(c.text()) for c in table.walk() if c.tag == "th" and c.parent is not None
            and c.parent.parent is not None and c.parent.parent.tag == "thead"]


def cells_of(tr):
    return [c for c in tr.elements() if c.tag in ("th", "td")]


def render_rc(name):
    r = subprocess.run([sys.executable, RENDER, "--in", F(name + ".json"), "--out", F(name + ".rc.html")],
                       capture_output=True, text=True, timeout=120)
    return r.returncode, norm(r.stderr)[-120:]


CHECKED = {}


def check_run(path):
    if path not in CHECKED:
        r = subprocess.run([sys.executable, CHECK, path], capture_output=True, text=True, timeout=300)
        CHECKED[path] = (r.returncode, (r.stdout + r.stderr).splitlines())
    return CHECKED[path]


def ng_lines(lines):
    return [l for l in lines if l.strip() and not l.startswith("OK") and not l.startswith("--")]


def sentences(path):
    out = []
    for line in open(path, encoding="utf-8").read().splitlines():
        out += [s for s in re.split(r"(?<=[.!?;])\s+", line) if s.strip()]
    return out


DOCS = [("SKILL.md", os.path.join(skill, "SKILL.md")),
        ("references/document-shape.md", os.path.join(skill, "references", "document-shape.md"))]


def doc_rule(what, pred):
    return ["%s does not say %s" % (rel, what) for rel, path in DOCS if not any(pred(s) for s in sentences(path))]


def has(pattern, s):
    return re.search(pattern, s, re.I) is not None


def blocks_of(doc):
    def walk(blocks, where):
        for b in blocks:
            yield b, where
            if b.get("type") == "details":
                yield from walk(b.get("blocks", []), where)
    for tab in doc.get("tabs", []):
        for sec in tab.get("sections", []):
            yield from walk(sec.get("blocks", []), sec.get("id"))


SAMPLES = [("content.sample.json", sample_en), ("content.sample.ja.json", sample_ja)]


def fill(word, values):
    return re.sub(r"\{(\w+)\}", lambda m: str(values.get(m.group(1), "")), word)


def today_label(lang):
    d = datetime.date.today()
    w = UI[lang]
    return fill(w["date"], {"year": d.year, "month": w["months"][d.month - 1], "day": d.day})


def facts_rows(path, where, probs):
    """The rows of the one table.facts of a page, checked to sit after the title and the lead."""
    root = parse(path)
    tables = [n for n in root.walk() if n.tag == "table" and "facts" in n.cls()]
    if len(tables) != 1:
        probs.append("%s has %d table.facts" % (where, len(tables)))
        return None, root
    t = tables[0]
    head = t.parent
    if head is None or "doc-pagehead" not in head.cls():
        probs.append("%s: table.facts is not in .doc-pagehead" % where)
        return None, root
    seq = [(e.tag, e.cls()) for e in head.elements()]
    if len(seq) != 3 or seq[0][0] != "h1" or seq[1][0] != "p" or "lead" not in seq[1][1] or seq[2][0] != "table":
        probs.append("%s: .doc-pagehead holds %s, not h1, p.lead, table.facts" % (where, [s[0] for s in seq]))
    rows = []
    for tr in [n for n in t.walk() if n.tag == "tr"]:
        c = cells_of(tr)
        if len(c) != 2 or c[0].tag != "th" or c[1].tag != "td":
            probs.append("%s: a facts row is not one th and one td" % where)
            continue
        rows.append((c[0].attrs.get("data-ui"), c[0].attrs.get("scope"), norm(c[0].text()), norm(c[1].text())))
    return rows, root


@judge("10-1")
def _():
    p = []
    for lang in ("en", "ja"):
        for k in ("factAsOf", "factSpec", "factRead"):
            if not UI.get(lang, {}).get(k):
                p.append("assets/ui.json has no %s.%s" % (lang, k))
    en, ja = UI.get("en", {}), UI.get("ja", {})
    cases = [
        ("single", "the single-page fixture", [("factAsOf", "row", en.get("factAsOf"), "As of May 1, 2026"),
                                               ("factSpec", "row", en.get("factSpec"), "Library loan rules 3.2"),
                                               ("factRead", "row", en.get("factRead"), "2026-05-01")]),
        ("facts-ja", "the Japanese fixture", [("factAsOf", "row", ja.get("factAsOf"), "2026\u5e745\u67081\u65e5\u6642\u70b9"),
                                              ("factSpec", "row", ja.get("factSpec"), "\u8cb8\u51fa\u306e\u898f\u5247 3.2"),
                                              ("factRead", "row", ja.get("factRead"), "2026-05-01")]),
        ("facts-date", "a document with date and no facts", [("factAsOf", "row", en.get("factAsOf"), "As of April 2, 2026")]),
        ("facts-none", "a document with neither", [("factAsOf", "row", en.get("factAsOf"), today_label("en"))]),
    ]
    for name, where, want in cases:
        rows, root = facts_rows(built(name), where, p)
        if rows is not None and rows != want:
            p.append("%s: facts rows %s, want %s" % (where, rows, want))
        if any("doc-date" in n.cls() for n in root.walk()):
            p.append("%s still writes .doc-date" % where)
    root = parse(built("multi"))
    pages = [n for n in root.walk() if "doc-page" in n.cls()]
    facts = [n for n in root.walk() if n.tag == "table" and "facts" in n.cls()]
    if len(facts) != 1 or not pages or facts[0] not in list(pages[0].walk()):
        p.append("the six-page fixture has %d table.facts, want 1 on the first page" % len(facts))
    return p


@judge("10-2")
def _():
    f = probe("phone")["facts"]
    if not f.get("exists"):
        return ["no table.facts in the page at 390px"]
    p = []
    b = f["box"]
    if f["display"] == "none" or f["visibility"] != "visible" or b["w"] <= 0 or b["h"] <= 0:
        p.append("table.facts is hidden at 390px (display %s, %dx%d)" % (f["display"], b["w"], b["h"]))
    if b["l"] < -1 or b["r"] > f["vw"] + 1:
        p.append("table.facts runs past the screen (%d to %d of %d)" % (b["l"], b["r"], f["vw"]))
    if not f.get("asof") or f["asofBox"]["h"] <= 0:
        p.append("the As-of row is not shown")
    return p


def inject(src, dst, table, strip):
    doc = open(src, encoding="utf-8").read()
    if strip:
        doc = re.sub(r'<table class="facts".*?</table>', "", doc, flags=re.S)
    m = re.search(r'<div class="doc-pagehead"[^>]*>.*?<p class="lead"[^>]*>.*?</p>', doc, re.S)
    if not m:
        raise Missing("the control document has no lead to put a table after")
    with open(dst, "w", encoding="utf-8") as f:
        f.write(doc[:m.end()] + table + doc[m.end():])
    return dst


FACTS_TABLE = ('<table class="facts"><tbody><tr><th scope="row" data-ui="factAsOf">As of</th><td>May 1, 2026</td></tr>'
               '<tr><th scope="row" data-ui="factSpec">Follows</th><td>Library loan rules 3.2</td></tr></tbody></table>')


@judge("10-3")
def _():
    rc, lines = check_run(inject(built("ok"), F("inject-facts.html"), FACTS_TABLE, True))
    bad = [l for l in lines if l.startswith("NG")]
    if rc != 0 or not any(l.startswith("OK opening") for l in lines):
        return ["check.py exits %d on a table.facts after the lead (%s)" % (rc, "; ".join(bad)[:200] or "no NG line")]
    return []


@judge("10-4")
def _():
    p = []
    for name, table in (("plain", "<table><tbody><tr><td>Extra</td><td>row</td></tr></tbody></table>"),
                        ("summary", '<table class="summary"><tbody><tr><td>Extra</td><td>row</td></tr></tbody></table>')):
        rc, lines = check_run(inject(built("ok"), F("inject-%s.html" % name), table, False))
        if rc != 1 or not any(l.startswith("NG opening") for l in lines) or not any("<table>" in l for l in lines):
            p.append("check.py exits %d and does not name the %s table under the title" % (rc, name))
    return p


@judge("10-5")
def _():
    return (doc_rule("to put the version in `facts`", lambda s: "`facts`" in s and has(r"\bversions?\b", s))
            + doc_rule("to put the time in `facts`", lambda s: "`facts`" in s and has(r"\b(time|date|as of|asOf)\b", s))
            + ["%s still puts the version in a note" % rel for rel, path in DOCS
               if any(has(r"\bversions?\b", s) and has(r"\bin an? `?note\b", s) for s in sentences(path))])


@judge("10-6")
def _():
    p = []
    root = parse(built("single"))
    boxes = [n for n in root.walk() if "cards" in n.cls()]
    if len(boxes) != 1:
        p.append("%d .cards blocks in the fixture, want 1" % len(boxes))
    for b in boxes:
        kids = b.elements()
        if b.tag != "ul" or len(kids) != 2 or any(k.tag != "li" or "card" not in k.cls() for k in kids):
            p.append("cards render as <%s> holding %s, not ul of li.card" % (b.tag, [k.tag for k in kids]))
    c = probe("wide")["cards"]
    if not c:
        return p + ["no .cards in the browser"]
    tracks = [float(x[:-2]) for x in c["tracks"].split() if x.endswith("px")]
    want = int((c["width"] + c["gap"]) // (260 + c["gap"]) + 1e-6)
    if not tracks or min(tracks) < 259.5 or len(tracks) != want:
        p.append("grid tracks %s in %dpx (repeat(auto-fill, minmax(260px, 1fr)) gives %d tracks of 260px or more)"
                 % (c["tracks"], c["width"], want))
    elif any(abs(i["w"] - tracks[0]) > 1.5 for i in c["items"]):
        p.append("cards are %s wide, the tracks %s" % ([round(i["w"]) for i in c["items"]], round(tracks[0])))
    return p


@judge("10-7")
def _():
    return (doc_rule("to send comparisons to a table", lambda s: has(r"\bcompar", s) and has(r"\btables?\b", s))
            + doc_rule("to give the cards of a block the same fields in the same order",
                       lambda s: has(r"\bcards?\b", s) and has(r"\bsame order\b", s) and has(r"\b(fields?|labels?)\b", s)))


def card_shape(item):
    shape = []
    for k, v in item.items():
        if k == "tone":
            continue
        if isinstance(v, list) and v and all(isinstance(x, dict) for x in v):
            shape.append(k + "(" + ",".join(str(x.get("label") or x.get("term") or x.get("name") or "") for x in v) + ")")
        else:
            shape.append(k)
    return tuple(shape)


@judge("10-8")
def _():
    p = []
    for rel, path in SAMPLES:
        for b, where in blocks_of(json.load(open(path, encoding="utf-8"))):
            if b.get("type") == "cards":
                shapes = [card_shape(i) for i in b.get("items", [])]
                if len(set(shapes)) > 1:
                    p.append("%s %s: the cards hold %s" % (rel, where, " / ".join(",".join(s) for s in shapes)))
    return p


@judge("10-9")
def _():
    p = []
    root = parse(built("single"))
    small = [t for t in root.walk() if t.tag == "table" and head_texts(t) == ["Card", "Items at once", "Holds at once"]]
    if not small:
        return ["the table with number columns was not rendered"]
    for tr in [n for n in small[0].walk() if n.tag == "tr"]:
        for j, c in enumerate(cells_of(tr)):
            if (j in (1, 2)) != ("num" in c.cls()):
                p.append("column %d cell <%s class=%r> (num columns 1 and 2)" % (j, c.tag, c.attrs.get("class")))
                break
    t = probe("wide")["tables"].get("small")
    if not t:
        return p + ["the table with number columns is not in the browser"]
    for row in t["rows"]:
        for j, c in enumerate(row):
            if j in (1, 2) and (c["align"] not in ("right", "end") or "tabular-nums" not in c["fvn"]):
                p.append("number cell <%s> aligns %s with numbers %s" % (c["tag"], c["align"], c["fvn"]))
                break
            if j == 0 and c["align"] not in ("left", "start"):
                p.append("first cell aligns %s" % c["align"])
                break
    return sorted(set(p))[:4]


NUMLIKE = re.compile(r"^[^\w\s]?\s*\d")
BARE = re.compile(r"^[+\-\u2212]?\d[\d,.]*$")


@judge("10-10")
def _():
    p = doc_rule("to put units in the column header", lambda s: has(r"\bunits?\b", s) and has(r"\bcolumn (header|heading)s?\b", s))
    for rel, path in SAMPLES:
        for b, where in blocks_of(json.load(open(path, encoding="utf-8"))):
            if b.get("type") != "table":
                continue
            cols, rows, num = b.get("columns", []), b.get("rows", []), set(b.get("num") or [])
            for j, col in enumerate(cols):
                cells = [str(r[j]).strip() for r in rows if j < len(r)]
                if cells and (j in num or all(NUMLIKE.match(c) for c in cells)):
                    bad = [c for c in cells if not BARE.match(c)]
                    if bad:
                        p.append("%s %s: number column %r holds %s" % (rel, where, col, ", ".join(bad[:3])))
    return p


@judge("10-11")
def _():
    p = []
    root = parse(built("single"))
    tables = [n for n in root.walk() if n.tag == "table" and "facts" not in n.cls()]
    if len(tables) < 4:
        p.append("%d tables rendered, want 4" % len(tables))
    for t in tables:
        name = (head_texts(t) or ["?"])[0]
        els = t.elements()
        cap = els[0] if els and els[0].tag == "caption" else None
        cid = cap.attrs.get("id") if cap is not None else None
        if not cap or not cid or not norm(cap.text()):
            p.append("table %s has no caption with an id as its first child" % name)
        box = t.parent
        if box is None or "tbl" not in box.cls() or box.attrs.get("role") != "region" or box.attrs.get("tabindex") != "0" \
                or not cid or box.attrs.get("aria-labelledby") != cid:
            p.append("box of table %s: role=%s tabindex=%s aria-labelledby=%s" % (
                name, box.attrs.get("role") if box else None, box.attrs.get("tabindex") if box else None,
                box.attrs.get("aria-labelledby") if box else None))
        for sec in els:
            for tr in [n for n in sec.walk() if n.tag == "tr"]:
                c = cells_of(tr)
                if sec.tag == "thead" and any(x.tag != "th" or x.attrs.get("scope") != "col" for x in c):
                    p.append("table %s: header cells are not th scope=col" % name)
                    break
                if sec.tag == "tbody" and (not c or c[0].tag != "th" or c[0].attrs.get("scope") != "row"
                                           or any(x.tag != "td" for x in c[1:])):
                    p.append("table %s: a row does not start with th scope=row" % name)
                    break
    return p[:6]


@judge("10-12")
def _():
    p = []
    rc, err = render_rc("r-nocap")
    if rc != 1:
        p.append("render.py exits %d on a table without a caption" % rc)
    rc, err = render_rc("ok")
    if rc != 0:
        p.append("render.py exits %d on tables with captions (%s)" % (rc, err))
    return p


@judge("10-13")
def _():
    t = probe("wide")["tables"]
    s, pr = t.get("small"), t.get("prose")
    if not s or not pr:
        return ["the tables are not in the browser"]
    p = []
    if s["w"] >= 0.8 * s["boxW"]:
        p.append("a three-column table fills its box (%dpx of %dpx)" % (s["w"], s["boxW"]))
    if not any(x.startswith("2px") and " none" not in x for x in s["headLine"]):
        p.append("the header line is %s" % s["headLine"][0])
    pads = sorted(set(" ".join(c["pad"]) for row in s["rows"] for c in row))
    if pads != ["8px 12px 8px 12px"]:
        p.append("cell padding %s" % ", ".join(pads))
    c = pr["cell"]
    if pr["w"] > pr["boxW"] + 1 or not c or c["h"] < 2.5 * c["lh"] or c["ws"] in ("nowrap", "pre"):
        p.append("a long cell does not wrap inside the box (table %dpx, box %dpx)" % (pr["w"], pr["boxW"]))
    return p


@judge("10-14")
def _():
    lines = probe("wide")["lines"]
    p = []
    for theme in ("light", "dark"):
        L = lines[theme]
        bg = color(L["bg"])[0]
        if not L["row"]:
            p.append("%s: the body rows have no line between them" % theme)
            continue
        row = over(L["row"]["c"], bg)
        k = ratio(row, bg)
        if k < 3:
            p.append("%s: row line %s is %.2f to 1 against the page" % (theme, L["row"]["c"], k))
        for name in ("free", "pre"):
            f = L[name]
            if not f:
                continue
            kf = ratio(over(f["c"], bg), bg)
            if kf >= k - 0.05:
                p.append("%s: the %s frame uses the row line color (%.2f to 1), not a softer one" % (theme, name, kf))
    return p


@judge("10-15")
def _():
    L = probe("wide")["tables"].get("long")
    if not L:
        return ["the long table is not in the browser"]
    p = []
    if L["maxH"] == "none" or L["oy"] not in ("auto", "scroll", "overlay") or L["sh"] <= L["ch"] + 20:
        p.append("the 40-row table box does not scroll (max-height %s, overflow-y %s, %d of %d px)"
                 % (L["maxH"], L["oy"], L["ch"], L["sh"]))
    elif L.get("scrolled", 0) <= 0 or L.get("headOff") is None or not (-1 <= L["headOff"] <= 3) or L.get("headH", 0) <= 0:
        p.append("after scrolling the box the header row is %s px from its top" % L.get("headOff"))
    return p


@judge("10-16")
def _():
    w = probe("phone")["wide"]
    if not w.get("found"):
        return ["the wide table is not in the browser"]
    if w["over"] <= 20:
        return ["the eight-column table does not scroll sideways at 390px (%d px over)" % w["over"]]
    first = [f for f in w.get("first") or [] if f]
    if w.get("scrolled", 0) <= 0 or not first or any(not (-1 <= f["off"] <= 3) for f in first):
        return ["after scrolling %spx the first cells sit at %s" % (w.get("scrolled"), [f["off"] for f in first])]
    return []


@judge("10-17")
def _():
    p = []
    regions = probe("wide")["regions"]
    if len(regions) < 6:
        p.append("found %d table boxes and figure frames, want 6" % len(regions))
    for r in regions:
        if r["role"] != "region" or not r["name"] or r["tabindex"] != "0" or not r["focus"]:
            p.append("%s in %s: role=%s name=%r tabindex=%s focus=%s" % (r["cls"], r["sec"], r["role"], r["name"][:20],
                                                                      r["tabindex"], r["focus"]))
    w = probe("phone")["wide"]
    st, en = w.get("start") or {}, w.get("end") or {}
    if not st or not en:
        p.append("the wide table box was not measured")
    else:
        if not st["sides"]["right"] or st["sides"]["left"] or not st["visual"]:
            p.append("at the start the wide table box marks %s with %s" % (st["sides"], st["visual"] or "nothing drawn"))
        if not en["sides"]["left"] or en["sides"]["right"] or not en["visual"]:
            p.append("at the end the wide table box marks %s with %s" % (en["sides"], en["visual"] or "nothing drawn"))
    return p[:5]


@judge("10-18")
def _():
    d = probe("tabs")
    p = []
    for label, R in (("at start", d["roles"]), ("after choosing the last tab", d.get("rolesAfter"))):
        if not R:
            p.append("roles %s were not read" % label)
            continue
        if R["bar"] != "tablist":
            p.append(".doc-pages role=%s" % R["bar"])
        sel = [t["key"] for t in R["tabs"] if t["sel"] == "true"]
        shown = [t["key"] for t in R["tabs"] if t["shown"]]
        if sel != shown or len(sel) != 1:
            p.append("%s aria-selected=true on %s, page shown %s" % (label, sel, shown))
        for t in R["tabs"]:
            pn = t["panel"]
            if t["role"] != "tab" or not pn or "doc-page" not in pn["cls"].split() or pn["role"] != "tabpanel" or pn["key"] != t["key"]:
                p.append("tab %s: role=%s aria-controls=%s panel=%s" % (t["key"], t["role"], t["ctl"], pn))
                break
    return sorted(set(p))[:4]


@judge("10-19")
def _():
    K = probe("tabs")["keys"]
    p = []
    last = K["n"] - 1
    for key, want in (("right", 1), ("left", 0), ("end", last), ("home", 0)):
        if K.get(key) != want:
            p.append("after %s the focus is on tab %s, want %d" % (key, K.get(key), want))
    if not K.get("onBefore"):
        p.append("the second section of the first page was not shown before the keys")
    elif K.get("on0") != K["onBefore"] or (K.get("p1Shown") and K.get("on1") != K.get("first1")):
        p.append("the arrow key moved the section (%s to %s)" % (K["onBefore"], K.get("on1") if K.get("p1Shown") else K.get("on0")))
    return p


@judge("10-20")
def _():
    s = probe("tabs")["scroll"]
    if s.get("before") is not False:
        return ["the last of %s tabs was already in view at 390px, so the fixture cannot tell" % s.get("n")]
    if not s.get("after") and not s.get("calls"):
        return ["choosing the last tab left it out of view and scrolled nothing"]
    return []


def seconds(text):
    out = []
    for part in (text or "").split(","):
        part = part.strip()
        if part.endswith("ms"):
            out.append(float(part[:-2]) / 1000)
        elif part.endswith("s"):
            out.append(float(part[:-1]))
    return out


@judge("10-21")
def _():
    u = probe("tabs")["under"]
    if not u:
        return ["no tab is marked as chosen"]
    p = []
    c = color(u["bbc"])
    line = (u["bb"] == "3px" and u["bbs"] not in ("none", "hidden") and c and c[1] > 0) \
        or any(q["content"] not in ("none", "normal") and "3px" in (q["height"], q["bb"], q["bt"]) for q in u["pseudo"]) \
        or ("inset" in (u["shadow"] or "") and re.search(r"(^|\s)-?3px", u["shadow"] or ""))
    if not line:
        p.append("the chosen tab underline is %s %s" % (u["bb"], u["bbs"]))
    durs = [x for d in u["dur"] for x in seconds(d)]
    if not any(0.15 <= x <= 0.25 for x in durs):
        p.append("the tab moves in %s" % ", ".join(u["dur"]))
    return p


@judge("10-22")
def _():
    d = probe("phone")["drawer"]
    if not d.get("side") or not d.get("menu"):
        return ["no contents drawer or opener at 390px"]
    p = []
    if not d.get("opened"):
        p.append("the opener did not open the drawer")
    if not d.get("focusIn") or not d.get("focusCurrent"):
        p.append("after opening the focus is on %s, not the current section button" % d.get("focusWhat"))
    if not d.get("shut") or not d.get("back"):
        p.append("after Escape the focus is on %s, not the opener" % d.get("backWhat"))
    return p


@judge("10-23")
def _():
    d = probe("phone")["drawer"]
    p = []
    if not d.get("closedInert") or d.get("closedReach"):
        p.append("the closed drawer is not inert (its buttons take the focus)")
    if d.get("openInert"):
        p.append("the open drawer is inert")
    if probe("wide").get("sideInert"):
        p.append("the contents list is inert at 1400px, where it is always shown")
    return p


@judge("10-24")
def _():
    z = probe("wide")["zoom"]
    p = []
    kinds = sorted(set(r["kind"] for r in z))
    if kinds != ["chart", "free", "ladder"]:
        p.append("figures found: %s" % kinds)
    for r in z:
        where = "%s %s" % (r["sec"], r["kind"])
        if not r.get("btn"):
            p.append("%s has no .fig-enlarge button" % where)
            continue
        if not r.get("want") or r.get("label") != r["want"]:
            p.append("%s button is labeled %r, the dictionary enlarge %r" % (where, r.get("label"), r.get("want")))
        if not r.get("dialog") or not r.get("open") or not r.get("modal"):
            p.append("%s opens no modal dialog.fig-zoom" % where)
            continue
        if not r.get("orig") or r.get("copy", 0) < 2 * r["orig"] - 1:
            p.append("%s is drawn %spx wide in the dialog, %spx in the page" % (where, round(r.get("copy") or 0), round(r.get("orig") or 0)))
        if not r.get("closed") or not r.get("back"):
            p.append("%s: closing does not return the focus to the button" % where)
    return p[:5]


def mini_valid(inst, sch, top):
    """Enough of JSON Schema for references/content.schema.json."""
    if sch is True or sch == {}:
        return True
    if sch is False:
        return False
    if "$ref" in sch:
        node = top
        for part in sch["$ref"].lstrip("#").split("/")[1:]:
            node = node[part.replace("~1", "/").replace("~0", "~")]
        if not mini_valid(inst, node, top):
            return False
    if "type" in sch:
        kinds = sch["type"] if isinstance(sch["type"], list) else [sch["type"]]
        test = {"object": lambda x: isinstance(x, dict), "array": lambda x: isinstance(x, list),
                "string": lambda x: isinstance(x, str), "boolean": lambda x: isinstance(x, bool), "null": lambda x: x is None,
                "integer": lambda x: isinstance(x, int) and not isinstance(x, bool),
                "number": lambda x: isinstance(x, (int, float)) and not isinstance(x, bool)}
        if not any(test.get(k, lambda x: True)(inst) for k in kinds):
            return False
    if "enum" in sch and inst not in sch["enum"]:
        return False
    if "const" in sch and inst != sch["const"]:
        return False
    if isinstance(inst, dict):
        if any(k not in inst for k in sch.get("required", [])):
            return False
        props, pats = sch.get("properties", {}), sch.get("patternProperties", {})
        for k, v in inst.items():
            matched = False
            if k in props:
                matched = True
                if not mini_valid(v, props[k], top):
                    return False
            for pat, ps in pats.items():
                if re.search(pat, k):
                    matched = True
                    if not mini_valid(v, ps, top):
                        return False
            if not matched and "additionalProperties" in sch and not mini_valid(v, sch["additionalProperties"], top):
                return False
    if isinstance(inst, list):
        if len(inst) < sch.get("minItems", 0) or ("maxItems" in sch and len(inst) > sch["maxItems"]):
            return False
        prefix = sch.get("prefixItems", [])
        for i, x in enumerate(inst):
            s = prefix[i] if i < len(prefix) else sch.get("items")
            if s is not None and not mini_valid(x, s, top):
                return False
    if isinstance(inst, str):
        if len(inst) < sch.get("minLength", 0) or ("pattern" in sch and not re.search(sch["pattern"], inst)):
            return False
    if any(not mini_valid(inst, s, top) for s in sch.get("allOf", [])):
        return False
    if "anyOf" in sch and not any(mini_valid(inst, s, top) for s in sch["anyOf"]):
        return False
    if "oneOf" in sch and sum(1 for s in sch["oneOf"] if mini_valid(inst, s, top)) != 1:
        return False
    if "not" in sch and mini_valid(inst, sch["not"], top):
        return False
    if "if" in sch:
        branch = sch.get("then") if mini_valid(inst, sch["if"], top) else sch.get("else")
        if branch is not None and not mini_valid(inst, branch, top):
            return False
    return True


@judge("10-25")
def _():
    p = []
    rc, err = render_rc("r-nested")
    if rc != 1:
        p.append("render.py exits %d on details inside details" % rc)
    schema = json.load(open(os.path.join(skill, "references", "content.schema.json"), encoding="utf-8"))
    if not mini_valid(json.load(open(F("ok.json"), encoding="utf-8")), schema, schema):
        p.append("the schema refuses a document with one details block")
    if mini_valid(json.load(open(F("r-nested.json"), encoding="utf-8")), schema, schema):
        p.append("the schema accepts details inside details")
    return p


@judge("10-26")
def _():
    p = []
    rc, lines = check_run(built("ok"))
    if rc != 0:
        p.append("check.py exits %d on a details block of 12 rows (%s)" % (rc, "; ".join(ng_lines(lines))[:120]))
    rc, lines = check_run(built("short"))
    if rc != 1 or not any("Branch phone numbers" in l for l in ng_lines(lines)):
        p.append("check.py exits %d and does not name the details block of 3 rows" % rc)
    return p + doc_rule("to fold only raw data over ten lines",
                        lambda s: has(r"\braw data\b", s) and has(r"\b(ten|10)\s+lines\b", s))


@judge("10-27")
def _():
    rc, lines = check_run(built("vague"))
    bad = ng_lines(lines)
    missed = [s for s in VAGUE if not any((re.search(r"(?<![\w<])%s(?![\w>])" % re.escape(s), l) if s.isascii() else s in l)
                                          for l in bad)]
    if rc != 1 or missed:
        return ["check.py exits %d and does not name the details blocks called %s" % (rc, ", ".join(missed) or "only a vague word")]
    return []


@judge("10-28")
def _():
    pr = probe("wide")["print"]
    p = []
    if pr["before"] != [False, True, False, False, False]:
        return ["the fixture details were %s before printing" % pr["before"]]
    paper = pr.get("paper") or []
    if not paper or not all(x["open"] for x in paper):
        p.append("on paper the details are open %s" % [x["open"] for x in paper])
    if not paper or not all(x["sum"] != "none" and x["sumH"] > 0 for x in paper):
        p.append("on paper the details names are %s" % sorted(set(x["sum"] for x in paper)))
    if pr.get("after") != pr["before"]:
        p.append("after printing the details are open %s, before %s" % (pr.get("after"), pr["before"]))
    return p


@judge("10-29")
def _():
    a = probe("wide")["dall"]
    p = []
    if [r["n"] for r in a["runs"]] != [4, 1]:
        return ["the fixture details ran in groups of %s" % [r["n"] for r in a["runs"]]]
    big, lone = a["runs"]
    if not all(a["want"]):
        p.append("assets/ui.json has no openAll or closeAll")
    if "details-all" not in (big["prev"] or "").split() or sorted(big["buttons"]) != sorted(w for w in a["want"] if w):
        p.append("before four details blocks sits %s with buttons %s" % (big["prev"], big["buttons"]))
    elif a.get("afterOpen") != [True] * 4 or a.get("afterClose") != [False] * 4:
        p.append("open all gives %s and close all %s" % (a.get("afterOpen"), a.get("afterClose")))
    if "details-all" in (lone["prev"] or "").split() or a["groups"] != 1:
        p.append("a lone details block also gets the buttons (%d groups)" % a["groups"])
    return p


@judge("10-30")
def _():
    h = probe("wide")["heights"]
    p = []
    if len(h["toc"]) < 3 or min(h["toc"]) < 44 - 0.01:
        p.append("contents buttons are %s px tall" % sorted(set(round(x, 1) for x in h["toc"])))
    if len(h["step"]) < 2 or min(h["step"]) < 44 - 0.01:
        p.append("previous and next buttons are %s px tall" % sorted(set(round(x, 1) for x in h["step"])))
    return p


@judge("10-31")
def _():
    v = probe("wide")["views"]
    if v["before"] != ["true", "false", "false"] or v.get("after") != ["false", "true", "false"]:
        return ["aria-pressed of the view buttons: %s, after pressing the second %s" % (v["before"], v.get("after"))]
    return []


@judge("10-32")
def _():
    p = []
    rc, err = render_rc("r-views6")
    if rc != 1:
        p.append("render.py exits %d on a chart with six views" % rc)
    rc, err = render_rc("r-views5")
    if rc != 0:
        p.append("render.py exits %d on a chart with five views (%s)" % (rc, err))
    return p


@judge("10-33")
def _():
    p = []
    root = parse(built("single"))
    tops = [n for n in root.walk() if n.tag == "header" and "doc-top" in n.cls()]
    side = [n for n in root.walk() if n.attrs.get("id") == "doc-side"]
    if not tops:
        p.append("render.py writes no header.doc-top for one page")
    if side and any("doc-ctrl" in n.cls() for n in side[0].walk()):
        p.append("#doc-side still holds the switches")
    h = probe("wide")["header"]
    if h.get("top"):
        if h.get("brand") != h["title"] or not h.get("ctrl") or h.get("ctrlInSide"):
            p.append("the header band holds title %r and switches %s" % (h.get("brand"), h.get("ctrl")))
        else:
            b, c = h["brandBox"], h["ctrlBox"]
            row = max(b["t"], c["t"]) < min(b["b"], c["b"]) and h["box"]["h"] <= 80
            right = c["l"] >= b["r"] and (c["l"] + c["r"]) / 2 > (h["box"]["l"] + h["box"]["r"]) / 2
            segs = h.get("segs") or []
            flat = len(segs) == 2 and max(s["t"] for s in segs) < min(s["b"] for s in segs) and h.get("langs") == 2 and h.get("themes") == 2
            if not (row and right and flat):
                p.append("the switches are not in one row on the right of the title (row %s, right %s, side by side %s)" % (row, right, flat))
    return p


@judge("10-34")
def _():
    p = []
    if UI.get("en", {}).get("pdf") != "Save PDF" or UI.get("ja", {}).get("pdf") != JA_PDF:
        p.append("assets/ui.json pdf is %r and %r" % (UI.get("en", {}).get("pdf"), UI.get("ja", {}).get("pdf")))
    pdf = probe("wide")["pdf"]
    if pdf.get("en") != "Save PDF" or not pdf.get("switched") or pdf.get("ja") != JA_PDF:
        p.append("the PDF button reads %r, and %r in Japanese" % (pdf.get("en"), pdf.get("ja")))
    return p


def notes_by_title(items):
    info = [n for n in items if "Copies in transit" in n["text"]]
    warn = [n for n in items if "Expired cards" in n["text"]]
    if not info or not warn:
        raise Missing("the notes are not in the browser")
    return info[0], warn[0]


@judge("10-35")
def _():
    p = []
    root = parse(built("single"))
    notes = [n for n in root.walk() if "note" in n.cls()]
    info = [n for n in notes if "Copies in transit" in n.text()]
    warn = [n for n in notes if "Expired cards" in n.text()]
    if not info or "warn" in info[0].cls() or not any(e.tag == "p" for e in info[0].walk()):
        p.append("the explanation is not a titled paragraph block without the warn class")
    if not warn or "warn" not in warn[0].cls() or warn[0].attrs.get("role") != "note" \
            or not any(e.tag == "svg" or any("icon" in c for c in e.cls()) for e in warn[0].walk()):
        p.append("the warning is %s, not div.note.warn role=note with an icon" % (
            "<div class=%r role=%r>" % (warn[0].attrs.get("class"), warn[0].attrs.get("role")) if warn else "missing"))
    n = probe("wide")["notes"]["light"]
    bg = color(n["bg"])[0]
    i, w = notes_by_title(n["items"])

    def same(c):
        return max(abs(c[k] - bg[k]) for k in range(3)) <= 6

    if not same(over(i["bgc"], bg)) or "gradient" in (i["bgi"] or ""):
        p.append("the explanation sits on a box of %s" % i["bgc"])
    if any(b["w"] > 0 and b["s"] != "none" and chroma(over(b["c"], bg)) > 40 for b in i["borders"]):
        p.append("the explanation has a colored border")
    if not any(b["w"] > 0 and b["s"] != "none" for b in w["borders"]) and same(over(w["bgc"], bg)):
        p.append("the warning has no frame")
    return p


@judge("10-38")
def _():
    p = []
    d = probe("wide")
    for theme in ("light", "dark"):
        n = d["notes"][theme]
        bg = color(n["bg"])[0]
        accent = color(n["accent"])[0]
        i, _w = notes_by_title(n["items"])
        for part in ("title", "para"):
            c = i.get(part)
            if not c:
                p.append("%s: the explanation has no %s" % (theme, part))
                continue
            col = over(c["color"], bg)
            if chroma(col) > 40 or ratio(col, accent) < 1.1:
                p.append("%s: the explanation %s is %s, not gray" % (theme, part, c["color"]))
    t = d["tokens"]
    if not all(t[x]["critical"] and t[x]["criticalSoft"] for x in ("light", "dark")) \
            or t["light"]["critical"] == t["dark"]["critical"]:
        p.append("--critical and --critical-soft are %s in light and %s in dark"
                 % ([t["light"]["critical"], t["light"]["criticalSoft"]], [t["dark"]["critical"], t["dark"]["criticalSoft"]]))
    left = [f for f in sorted(os.listdir(os.path.join(skill, "assets")))
            if "--bad" in open(os.path.join(skill, "assets", f), encoding="utf-8", errors="replace").read()]
    if left:
        p.append("--bad is still used in assets/%s" % ", assets/".join(left))
    return p


@judge("10-36")
def _():
    p = []
    rc, err = render_rc("r-warnbare")
    if rc != 1:
        p.append("render.py exits %d on a warning without a title" % rc)
    rc, err = render_rc("ok")
    if rc != 0:
        p.append("render.py exits %d on warnings with titles (%s)" % (rc, err))
    return p


@judge("10-37")
def _():
    p = []
    rc, lines = check_run(built("ok"))
    if rc != 0:
        p.append("check.py exits %d on a section with two warnings" % rc)
    rc, lines = check_run(built("warn3"))
    bad = ng_lines(lines)
    if rc != 1 or not any("w-s1" in l for l in bad) or not any(l.startswith("NG") and "warn" in l.lower() for l in bad):
        p.append("check.py exits %d and does not name section w-s1 with three warnings" % rc)
    return p


@judge("10-39")
def _():
    p = []
    for lang in ("en", "ja"):
        w = UI.get(lang, {}).get("here", "")
        if ":" in w or "\uff1a" in w or "{name}" not in w:
            p.append("assets/ui.json %s.here is %r" % (lang, w))
    h = probe("wide")["here"]
    for item in h["items"]:
        label = item["label"] or ""
        if ":" in label or "\uff1a" in label or (h["name"] or "?") not in label:
            p.append("the current section reads %r" % label)
            break
    return p


@judge("10-40")
def _():
    p = []
    for lang in ("en", "ja"):
        for k in ("help", "helpTitle", "helpKeys", "helpEnlarge", "helpPdf"):
            if not UI.get(lang, {}).get(k):
                p.append("assets/ui.json has no %s.%s" % (lang, k))
                break
    d = probe("wide")
    h = d["help"]
    if not h["exists"] or h["text"] != "?" or not h["want"] or h["label"] != h["want"]:
        p.append("the header band has no ? button labeled with help (%s)" % ("found %r" % h["text"] if h["exists"] else "none"))
    b = d.get("helpbox") or {}
    if not b.get("exists") or not b.get("open") or not b.get("modal"):
        p.append("the ? button opens no modal dialog.doc-helpbox")
    else:
        missing = [w for w in b["want"] if not w or norm(w) not in b["text"]]
        if missing:
            p.append("the help dialog leaves out %s" % missing)
    if not probe("tabs")["help"]["exists"]:
        p.append("a document with several pages has no ? button")
    return p


@judge("10-41")
def _():
    p = []
    for name, path in (("English", built_en), ("Japanese", built_ja)):
        if not os.path.isfile(path):
            p.append("the %s sample was not built" % name)
            continue
        r = subprocess.run([sys.executable, PAGE_DESIGN, "verify", path], capture_output=True, text=True, timeout=120)
        if r.returncode != 0:
            p.append("page-design verify exits %d on the %s sample (%s)" % (r.returncode, name, norm(r.stdout + r.stderr)[:160]))
    return p


@judge("10-42")
def _():
    en = ["facts table", "page tabs", "enlarge", "header band"]
    ja = ["\u4e8b\u5b9f\u306e\u8868", "\u30da\u30fc\u30b8\u306e\u30bf\u30d6", "\u62e1\u5927", "\u898b\u51fa\u3057\u5e2f"]
    log = open(os.path.join(PLUGIN, "CHANGELOG.md"), encoding="utf-8").read()
    # The lines under Unreleased move into a release section when the plugin is released.
    m = re.search(r"^## \[Unreleased\]\n(.*)", log, re.S | re.M)
    texts = [("README.md", open(os.path.join(PLUGIN, "README.md"), encoding="utf-8").read(), en),
             ("docs/how-it-works.md", open(os.path.join(PLUGIN, "docs", "how-it-works.md"), encoding="utf-8").read(), en),
             ("CHANGELOG.md [Unreleased] and the releases", m.group(1) if m else "", en),
             ("README.ja.md", open(os.path.join(PLUGIN, "README.ja.md"), encoding="utf-8").read(), ja),
             ("docs/how-it-works.ja.md", open(os.path.join(PLUGIN, "docs", "how-it-works.ja.md"), encoding="utf-8").read(), ja)]
    p = []
    for rel, text, words in texts:
        missing = [w for w in words if w.lower() not in text.lower()]
        if missing:
            p.append("%s does not mention %s" % (rel, ", ".join(missing)))
    return p


for key in sorted(results, key=lambda k: int(k.split("-")[1])):
    print("%s\t%s" % (key, re.sub(r"\s+", " ", " / ".join(results[key]))[:400]))
PYEOF

S10_CASES=(
  "10-1 the facts in the content JSON appear as table.facts under the title and lead"
  "10-2 at 390px the facts table stays visible"
  "10-3 check.py accepts table.facts between the title and the first h2"
  "10-4 check.py refuses any other table between the title and the first h2"
  "10-5 the docs put the time and the spec version in the facts"
  "10-6 cards render as ul and li in an auto-fill grid of 260px"
  "10-7 the docs send comparisons to tables and give cards the same fields"
  "10-8 the sample cards share the same fields in the same order"
  "10-9 a table's number columns carry class num and align right"
  "10-10 units sit in the column header and not in the sample cells"
  "10-11 tables have a caption and scoped column and row headers"
  "10-12 render.py refuses a table without a caption"
  "10-13 tables take their content width with a 2px header line and 8px 12px cells"
  "10-14 row lines reach 3 to 1 against the page in light and dark"
  "10-15 a long table scrolls in its box with the header row kept on top"
  "10-16 a table that scrolls sideways keeps its first column in view"
  "10-17 boxes that scroll sideways are named regions that take the focus and fade the side with more"
  "10-18 the page tabs have the tablist, tab, and tabpanel roles"
  "10-19 the arrow, Home, and End keys move between page tabs without moving sections"
  "10-20 the chosen page tab scrolls into view"
  "10-21 the tab underline is 3px and moves in 150 to 250ms"
  "10-22 the contents drawer moves the focus in when opened and back when closed"
  "10-23 a closed contents drawer is inert"
  "10-24 every figure opens at twice its width in a dialog and returns the focus on close"
  "10-25 render.py and the schema refuse details inside details"
  "10-26 check.py flags a details block under ten lines and the docs fold only long raw data"
  "10-27 check.py refuses a details block named only More or Details"
  "10-28 printing opens every details block with its name and restores it after"
  "10-29 four or more details blocks in a row get open all and close all buttons"
  "10-30 the contents and section buttons are at least 44px tall"
  "10-31 chart view buttons mark the pressed one with aria-pressed"
  "10-32 render.py refuses a chart with more than five views"
  "10-33 a single-page document has a header band with the switches on its right"
  "10-34 the PDF button names the action in English and Japanese"
  "10-35 an explanatory note is a titled paragraph and a warning is a framed box with an icon"
  "10-36 render.py refuses a warning without a title"
  "10-37 check.py flags a section with three or more warnings"
  "10-38 explanations are gray and the critical tokens replace --bad"
  "10-39 the current section text joins no label and value with a colon"
  "10-40 the help for the page opens from a question mark button in a dialog"
  "10-41 the sample documents pass page-design verify in English and Japanese"
  "10-42 the README, how-it-works, and changelog describe the facts, the tabs, the enlarged figures, and the header band"
)
for name in "${S10_CASES[@]}"; do
  key="${name%% *}"
  if ! grep -q "^$key"$'\t' "$S10/results.txt" 2>/dev/null; then
    _fail "$name" "not evaluated"
    continue
  fi
  got="$(awk -F '\t' -v k="$key" '$1 == k { print $2; exit }' "$S10/results.txt")"
  if [ -z "$got" ]; then _pass "$name"; else _fail "$name" "$got"; fi
done

# --- 11. The user's theme file, applied with the theme command of page-design ---
# The page names its base colors after the page-design keys, derives its other shades from them,
# and takes a theme's colors and fonts through `page-design.py theme --keys light,dark,font.sans,font.mono`.
PAGE_DESIGN_PY="$(cd "$PLUGIN/.." && pwd)/design-formats/skills/page-design/scripts/page-design.py"
THEME_KEYS="light,dark,font.sans,font.mono"
S11="$WORK/s11"
mkdir -p "$S11"

# s11_blocks <page>: prints the tokens of the light block and the two dark blocks as JSON.
s11_blocks() {
  python3 - "$1" <<'PYEOF'
import json, re, sys
text = open(sys.argv[1], encoding="utf-8").read()
def tokens(pattern):
    m = re.search(pattern + r"\s*\{([^}]*)\}", text)
    return dict((k, v.strip()) for k, v in re.findall(r"--([a-z][a-z0-9-]*)\s*:\s*([^;}]+)", m.group(1))) if m else None
print(json.dumps({
    "light": tokens(r":root"),
    "system": tokens(r':root:not\(\[data-theme="light"\]\)(?::not\([^)]*\))*'),
    "chosen": tokens(r':root\[data-theme="dark"\](?::not\([^)]*\))*'),
}))
PYEOF
}

# s11_place <name>: makes $S11/<name>/repo (a git repository holding the built page) and $S11/<name>/home.
s11_place() {
  mkdir -p "$S11/$1/home" "$S11/$1/repo"
  git -C "$S11/$1/repo" init -q
  cp "$WORK/doc-en.html" "$S11/$1/repo/page.html"
}
s11_theme() { local place="$1"; shift; (cd "$S11/$place/repo" && HOME="$S11/$place/home" python3 "$PAGE_DESIGN_PY" theme "$@" page.html); }

S11_THEME='{"light": {"bg": "#fafaf7", "surface": "#fefefe", "ink": "#111111", "sub": "#444444", "line": "#dddddd", "accent": "#0b6e4f", "accent-ink": "#ffffff", "accent-soft": "#e3f2ec", "bar": "#eeeeee", "label": "#f2f2f2"}, "dark": {"bg": "#101312", "surface": "#181c1a", "ink": "#eeeeee", "sub": "#b0b8b4", "line": "#2c3330", "accent": "#5fd0a5", "accent-ink": "#0b1410", "accent-soft": "#1b3a2f", "bar": "#232a27", "label": "#1f2523"}, "font": {"sans": "\"Inter\", sans-serif", "mono": "\"JetBrains Mono\", monospace", "size": 18, "line-height": 1.9}, "space": {"page-width": 1100, "radius-small": 4, "radius": 6, "radius-large": 8}}'

s11_base_names() {
  python3 - "$(s11_blocks "$WORK/doc-en.html")" <<'PYEOF'
import json, sys
blocks = json.loads(sys.argv[1])
want = {"light": {"surface": "#fff", "sub": "#545a66"},
        "system": {"surface": "#1a1e24", "sub": "#b0b8c4"},
        "chosen": {"surface": "#1a1e24", "sub": "#b0b8c4"}}
problems = []
for side, values in want.items():
    block = blocks.get(side) or {}
    for key, value in values.items():
        if block.get(key, "").lower() != value:
            problems.append("%s --%s is %r" % (side, key, block.get(key)))
light = blocks.get("light") or {}
for alias, base in (("panel", "surface"), ("card", "surface"), ("ink-sub", "sub")):
    if light.get(alias) != "var(--%s)" % base:
        problems.append("light --%s is %r, not var(--%s)" % (alias, light.get(alias), base))
    for side in ("system", "chosen"):
        value = (blocks.get(side) or {}).get(alias)
        if value is not None and value != "var(--%s)" % base:
            problems.append("%s --%s is %r" % (side, alias, value))
print("; ".join(problems[:4]))
sys.exit(1 if problems else 0)
PYEOF
}
_yes "11-1 the built page names its base colors after the page-design keys with today's values" "s11_base_names > '$S11/base.out' || { sed 's/^/      /' '$S11/base.out'; false; }"

s11_shades() {
  python3 - "$(s11_blocks "$WORK/doc-en.html")" <<'PYEOF'
import json, re, sys
blocks = json.loads(sys.argv[1])
today = {"light": {"panel-2": "#fafafb", "line-2": "#d2d2d8", "ink-2": "#3c3c44", "ink-3": "#6e6e78", "ink-faint": "#6b6b75", "rule": "#8a8a95", "track": "#f1f1f4"},
         "dark": {"panel-2": "#20252c", "line-2": "#414955", "ink-2": "#c9ced6", "ink-3": "#a3abb7", "ink-faint": "#98a1ae", "rule": "#666e7b", "track": "#262c35"}}
def hex_rgb(value):
    m = re.fullmatch(r"#([0-9a-f]{3}|[0-9a-f]{6})", value.strip().lower())
    if not m:
        return None
    h = m.group(1)
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]
def split_top(text):
    parts, depth, cur = [], 0, ""
    for c in text:
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
        if c == "," and depth == 0:
            parts.append(cur.strip())
            cur = ""
        else:
            cur += c
    parts.append(cur.strip())
    return parts
class NotMix(Exception):
    pass
# evaluate: the color of a value made only of var() references and color-mix() in srgb.
def evaluate(value, tokens, depth=0):
    value = value.strip()
    if depth > 12:
        raise NotMix("references loop")
    m = re.fullmatch(r"var\(--([a-z0-9-]+)\)", value)
    if m:
        ref = tokens.get(m.group(1))
        if ref is None:
            raise NotMix("--%s is not defined" % m.group(1))
        color = hex_rgb(ref)
        return color if color is not None else evaluate(ref, tokens, depth + 1)
    m = re.fullmatch(r"color-mix\((.*)\)", value, re.S)
    if not m:
        raise NotMix("%r is neither var() nor color-mix()" % value)
    parts = split_top(m.group(1))
    if len(parts) != 3 or parts[0] != "in srgb":
        raise NotMix("%r does not mix two colors in srgb" % value)
    colors, weights = [], []
    for part in parts[1:]:
        w = re.search(r"\s(\d+(?:\.\d+)?)%$", part)
        colors.append(evaluate(part[:w.start()] if w else part, tokens, depth + 1))
        weights.append(float(w.group(1)) if w else None)
    if weights[0] is None and weights[1] is None:
        weights = [50.0, 50.0]
    elif weights[1] is None:
        weights[1] = 100 - weights[0]
    elif weights[0] is None:
        weights[0] = 100 - weights[1]
    total = weights[0] + weights[1]
    return [(colors[0][i] * weights[0] + colors[1][i] * weights[1]) / total for i in range(3)]
problems = []
for side, base in (("light", "light"), ("system", "dark"), ("chosen", "dark")):
    tokens = dict(blocks.get("light") or {})
    if side != "light":
        tokens.update(blocks.get(side) or {})
    for name, want in today[base].items():
        value = tokens.get(name, "")
        if not value.startswith("color-mix("):
            problems.append("%s --%s is %r, not a color-mix of the base tokens" % (side, name, value))
            continue
        try:
            got = [round(c) for c in evaluate(value, tokens)]
        except NotMix as err:
            problems.append("%s --%s: %s" % (side, name, err))
            continue
        exp = hex_rgb(want)
        if max(abs(got[i] - exp[i]) for i in range(3)) > 2:
            problems.append("%s --%s mixes to %s, today %s" % (side, name, "#%02x%02x%02x" % tuple(got), want))
print("; ".join(problems[:4]))
sys.exit(1 if problems else 0)
PYEOF
}
_yes "11-2 the derived shades mix the base colors and stay within 2 of today's values" "s11_shades > '$S11/shades.out' || { sed 's/^/      /' '$S11/shades.out'; false; }"

s11_applied() {
  s11_place applied
  printf '%s\n' "$S11_THEME" > "$S11/applied/home/.design-theme.json"
  s11_theme applied --keys "$THEME_KEYS" > "$S11/applied.out" 2>&1 || { sed 's/^/      /' "$S11/applied.out"; return 1; }
  python3 - "$(s11_blocks "$S11/applied/repo/page.html")" "$S11_THEME" <<'PYEOF'
import json, sys
blocks, theme = json.loads(sys.argv[1]), json.loads(sys.argv[2])
problems = []
for side, group in (("light", "light"), ("system", "dark"), ("chosen", "dark")):
    block = blocks.get(side) or {}
    for key, value in theme[group].items():
        if key == "bar":
            continue
        if block.get(key) != value:
            problems.append("%s --%s is %r, the theme says %s" % (side, key, block.get(key), value))
light = blocks.get("light") or {}
for key in ("sans", "mono"):
    if light.get(key) != theme["font"][key]:
        problems.append("--%s is %r" % (key, light.get(key)))
print("; ".join(problems[:4]))
sys.exit(1 if problems else 0)
PYEOF
}
_yes "11-3 page-design theme writes a theme's colors and fonts into a built page" "s11_applied > '$S11/applied.check' 2>&1 || { sed 's/^/      /' '$S11/applied.check'; false; }"

s11_layout_kept() {
  local before after
  before="$(s11_blocks "$WORK/doc-en.html")"
  s11_place keys
  printf '%s\n' "$S11_THEME" > "$S11/keys/home/.design-theme.json"
  s11_theme keys --keys "$THEME_KEYS" > "$S11/keys.out" 2>&1 || { sed 's/^/      /' "$S11/keys.out"; return 1; }
  ! cmp -s "$WORK/doc-en.html" "$S11/keys/repo/page.html" || { echo "      the theme changed nothing"; return 1; }
  after="$(s11_blocks "$S11/keys/repo/page.html")"
  s11_place every
  printf '%s\n' "$S11_THEME" > "$S11/every/home/.design-theme.json"
  s11_theme every > /dev/null 2>&1 || return 1
  python3 - "$before" "$after" "$(s11_blocks "$S11/every/repo/page.html")" <<'PYEOF'
import json, sys
before, after, every = (json.loads(a)["light"] or {} for a in sys.argv[1:4])
problems = ["--%s became %r" % (k, after.get(k)) for k in ("radius", "side", "top") if after.get(k) != before.get(k)]
if every.get("radius") != "6px":
    problems.append("theme without --keys left --radius at %r, so the check does not see the keys" % every.get("radius"))
print("; ".join(problems))
sys.exit(1 if problems else 0)
PYEOF
}
_yes "11-4 a theme leaves the corners, the side width, and the header height of a built page as they were" "s11_layout_kept > '$S11/layout.out' 2>&1 || { sed 's/^/      /' '$S11/layout.out'; false; }"

s11_no_file() {
  s11_place none
  s11_theme none --keys "$THEME_KEYS" > "$S11/none.out" 2>&1 || return 1
  cmp -s "$WORK/doc-en.html" "$S11/none/repo/page.html"
}
_yes "11-5 without a theme file the built page stays as built" s11_no_file

s11_themed_checks() {
  s11_place checked
  printf '%s\n' "$S11_THEME" > "$S11/checked/home/.design-theme.json"
  s11_theme checked --keys "$THEME_KEYS" > "$S11/checked.out" 2>&1 || { sed 's/^/      /' "$S11/checked.out"; return 1; }
  ! cmp -s "$WORK/doc-en.html" "$S11/checked/repo/page.html" || { echo "      the theme changed nothing"; return 1; }
  python3 "$CHECK" "$S11/checked/repo/page.html" > "$S11/themed-check.out" 2>&1 || { grep -E '^NG' "$S11/themed-check.out" | head -3 | sed 's/^/      /'; return 1; }
  python3 "$PAGE_DESIGN_PY" verify "$S11/checked/repo/page.html" > "$S11/themed-verify.out" 2>&1 || { head -3 "$S11/themed-verify.out" | sed 's/^/      /'; return 1; }
}
_yes "11-6 a themed page passes check.py and page-design verify" s11_themed_checks

s11_skill_step() {
  local phrase
  for phrase in 'theme --keys light,dark,font.sans,font.mono' '`.design-theme.json`' '`~/.design-theme.json`'; do
    _has "$SKILL" "$phrase" || { echo "      SKILL.md lacks: $phrase"; return 1; }
  done
}
_yes "11-7 the SKILL.md says to apply the user's theme with page-design after the build" s11_skill_step

s11_follows_theme() {
  python3 - "$SKILL_DIR/musubi.json" <<'PYEOF'
import json, sys
entry = json.load(open(sys.argv[1], encoding="utf-8")).get("follows", {}).get("page-design/theme", {})
ok = entry.get("version") == "^1.0.0" and entry.get("optional") is True and str(entry.get("integrity", "")).startswith("sha256-")
if not ok:
    print("      page-design/theme is followed as %s" % json.dumps(entry))
sys.exit(0 if ok else 1)
PYEOF
}
_yes "11-8 musubi.json follows page-design/theme as optional" s11_follows_theme

s11_readmes() {
  local phrase
  for phrase in '~/.design-theme.json' '.design-theme.json' 'design-formats' 'colors and fonts'; do
    _has "$PLUGIN/README.md" "$phrase" || { echo "      README.md lacks: $phrase"; return 1; }
  done
  for phrase in '~/.design-theme.json' '.design-theme.json' 'design-formats' '色と書体'; do
    _has "$PLUGIN/README.ja.md" "$phrase" || { echo "      README.ja.md lacks: $phrase"; return 1; }
  done
}
_yes "11-9 the READMEs say where to place a theme file and what it changes" s11_readmes

# The line moves from Unreleased into a release section when the plugin is released.
s11_changelog() {
  awk '/^## \[Unreleased\]/ { on = 1 } on' "$PLUGIN/CHANGELOG.md" | grep -qF '.design-theme.json'
}
_yes "11-10 the changelog names the theme file under Unreleased or a release" s11_changelog

# The repository checks, last because they take the longest.
s11_repo_checks() {
  local repo
  repo="$(git -C "$PLUGIN" rev-parse --show-toplevel 2>/dev/null)" || return 1
  bash "$repo/scripts/check.sh" > "$WORK/repo-check.out" 2>&1 || { tail -5 "$WORK/repo-check.out" | sed 's/^/      /'; return 1; }
}
_yes "the repository checks pass" s11_repo_checks

echo ""
echo "[test-render] ran: $((PASS + FAIL))"
echo "[test-render] PASS: $PASS, FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "failed cases:"
  printf '  %s\n' "${FAILED[@]}"
  exit 1
fi
exit 0
