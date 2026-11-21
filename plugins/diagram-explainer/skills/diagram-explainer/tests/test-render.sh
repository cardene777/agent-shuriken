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
#      and the words written into the pages and the step ladders match it.
#   9. With a headless browser, at a desktop and a phone width: captions, step ladders, and charts
#      as drawn (lines and text, text size, colors in light and dark, fitting or scrolling with a cue).
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
SKILL_WORDS_MAX=2173
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

WRITTEN="$(python3 - "$UI_JSON" "en:dated:$EN" "ja:dated:$JA" "en:starter:$STARTER" <<'PYEOF'
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
    """Collects every element marked with data-ui, data-ui-label, or data-ui-title, and the date."""
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.found, self.open, self.date = [], None, None
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
    lang, kind, page = arg.split(":", 2)
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
        want = fill(words["date"], {"year": today.year, "month": words["months"][today.month - 1], "day": today.day})
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
  function rgb(s) {
    var m = /rgba?\(([^)]*)\)/.exec(s || '');
    if (!m) return null;
    var p = m[1].split(/[\s,\/]+/).filter(Boolean).map(parseFloat);
    return { c: [p[0], p[1], p[2]], a: p.length > 3 ? p[3] : 1 };
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

echo ""
echo "[test-render] ran: $((PASS + FAIL))"
echo "[test-render] PASS: $PASS, FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "failed cases:"
  printf '  %s\n' "${FAILED[@]}"
  exit 1
fi
exit 0
