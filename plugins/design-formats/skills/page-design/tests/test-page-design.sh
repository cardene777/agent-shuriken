#!/usr/bin/env bash
# Tests for page-design: the plugin files, the musubi declaration, the two formats, the four page
# type templates, and page-design.py verify. Pages written here live in a throwaway folder; nothing
# reaches the network. The musubi check runs only when the musubi command is on PATH, and is
# reported as skipped, never as passed, when it is not.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
SCRIPT="$SKILL_DIR/scripts/page-design.py"
STRUCTURE="$SKILL_DIR/formats/structure.md"
LOOK="$SKILL_DIR/formats/look.md"
DECLARATION="$SKILL_DIR/musubi.json"
SKILL="$SKILL_DIR/SKILL.md"
PLUGIN="$(cd "$SKILL_DIR/../.." && pwd)"
REPO="$(cd "$PLUGIN/../.." && pwd)"
TYPES=(report sheet document choice)
PASS=0
FAIL=0
SKIP=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
skip() { SKIP=$((SKIP + 1)); printf 'skip  %s (%s)\n' "$1" "$2"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }

run() { [ -f "$SCRIPT" ] || return 3; python3 "$SCRIPT" "$@"; }

# has <file> <text>...: every text appears in the file.
has() {
  local f="$1" s
  shift
  [ -f "$f" ] || { echo "      missing $f"; return 1; }
  for s in "$@"; do
    grep -qF -- "$s" "$f" || { echo "      $(basename "$f") lacks: $s"; return 1; }
  done
}

plugin_files() {
  local f
  for f in .claude-plugin/plugin.json .codex-plugin/plugin.json README.md README.ja.md CHANGELOG.md LICENSE \
    assets/icon.svg docs/how-it-works.md docs/how-it-works.ja.md skills/page-design/SKILL.md \
    skills/page-design/agents/openai.yaml; do
    [ -f "$PLUGIN/$f" ] || { echo "      missing $f"; return 1; }
  done
  python3 - "$PLUGIN" <<'PYEOF'
import json, sys
root = sys.argv[1]
for path in (".claude-plugin/plugin.json", ".codex-plugin/plugin.json"):
    manifest = json.load(open("%s/%s" % (root, path), encoding="utf-8"))
    if manifest.get("name") != "design-formats" or manifest.get("version") != "0.1.0":
        print("      %s is %s %s" % (path, manifest.get("name"), manifest.get("version")))
        sys.exit(1)
PYEOF
}
check "design-formats holds the files of a plugin at version 0.1.0" plugin_files

listed() {
  local page
  python3 - "$REPO/.claude-plugin/marketplace.json" <<'PYEOF' || return 1
import json, sys
plugins = json.load(open(sys.argv[1], encoding="utf-8"))["plugins"]
sys.exit(0 if any(p["name"] == "design-formats" and p["source"] == "./plugins/design-formats" for p in plugins) else 1)
PYEOF
  for page in README.md README.ja.md; do
    grep -qE '^\| \[design-formats\]\(plugins/design-formats\) \|' "$REPO/$page" || return 1
    grep -qF '/design-formats:page-design' "$REPO/$page" || return 1
  done
  for page in docs/publishing.md docs/publishing.ja.md; do
    grep -qE '^\| design-formats \|' "$REPO/$page" || return 1
    grep -qE '^\| (Question|質問) \|.*\| design-formats \|' "$REPO/$page" || return 1
  done
}
check "the marketplace and the repository pages list design-formats" listed

provides() {
  [ -f "$DECLARATION" ] || return 1
  python3 - "$SKILL_DIR" <<'PYEOF'
import json, os, sys
skill = sys.argv[1]
declaration = json.load(open(os.path.join(skill, "musubi.json"), encoding="utf-8"))
want = {
    "structure": {"version": "1.0.0", "file": "formats/structure.md"},
    "look": {"version": "1.0.0", "file": "formats/look.md"},
    "report": {"version": "1.0.0", "file": "templates/report.html"},
    "sheet": {"version": "1.0.0", "file": "templates/sheet.html"},
    "document": {"version": "1.0.0", "file": "templates/document.html"},
    "choice": {"version": "1.0.0", "file": "templates/choice.html"},
    "verify": {"version": "1.0.0", "file": "scripts/page-design.py"},
}
if declaration.get("musubi") != "2026-11-20" or declaration.get("provides") != want:
    print("      musubi.json declares %s" % json.dumps(declaration, sort_keys=True))
    sys.exit(1)
for content in want.values():
    if not os.path.isfile(os.path.join(skill, content["file"])):
        print("      %s is missing" % content["file"])
        sys.exit(1)
PYEOF
}
check "page-design provides structure, look, four page types, and verify in musubi.json" provides

structure_format() {
  has "$STRUCTURE" "## Conclusion first" "## The whole picture before the details" \
    "## One glossary, linked from every use" "## Steps with real output" "## Only what to do"
}
check "the structure format holds the order of an explanation" structure_format

look_format() {
  has "$LOOK" "## Headings" "## Facts in a table" "## Joining items" "## Text size and weight" \
    "## Explanations and help" "## Details beside the list" "## Enlarging" "## Motion" \
    "## Header controls" "## Self-contained pages" "data-lang" "data-theme-choice" "prefers-reduced-motion"
}
check "the look format holds the rules of headings, facts, text, details, and motion" look_format

templates_pass() {
  local t f
  for t in "${TYPES[@]}"; do
    f="$SKILL_DIR/templates/$t.html"
    [ -f "$f" ] || { echo "      missing templates/$t.html"; return 1; }
    grep -qE '<html lang="en"' "$f" || { echo "      $t.html is not English by default"; return 1; }
    run verify --source "$f" > "$T/template-$t.out" 2>&1 || { sed 's/^/      /' "$T/template-$t.out"; return 1; }
  done
}
check "verify accepts every page type template" templates_pass

report_layout() {
  has "$LOOK" "Keep facts about the page apart from the results" "Show each value once" \
    "no paging when the list fits on one page" "Give each row its value as a number" || return 1
  python3 - "$SKILL_DIR/templates/report.html" <<'PYEOF'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
en = re.search(r"\n  en: \{(.*?)\n  \},", text, re.S).group(1)

def label(key):
    found = re.search(r"\b" + key + r': "([^"]+)"', en)
    return found.group(1) if found else key

def labels(name):
    found = re.search(r"\n  " + name + r": \[(.*?)\],\n", text, re.S)
    return {label(k) for k in re.findall(r'\["(\w+)",', found.group(1))} if found else set()

problems = []
shared = labels("facts") & labels("stats")
if shared:
    problems.append("facts and result numbers both show " + ", ".join(sorted(shared)))
if 'class="bar"' in text:
    problems.append("rows draw a bar without a number")
if 'class="value"' not in text:
    problems.append("rows do not show their value")
if "pages > 1 ?" not in text:
    problems.append("a list that fits on one page still shows the pager")
for problem in problems:
    print("      " + problem)
sys.exit(1 if problems else 0)
PYEOF
}
check "the report template keeps facts apart from results, shows row values, and hides a one-page pager" report_layout

look_figures() {
  has "$LOOK" "## Figures" "[shape: bar]" "[shape: donut]" '`flow`' '`architecture`' '`sequence`' "line chart" \
    'data-still' 'dragon embed' 'data-figure-lang'
}
check "the look format maps each kind of information to a still dragon figure" look_figures

# figures <template> <shape>...: prints a problem for each language that lacks a still block of a shape.
figures() {
  python3 - "$@" <<'PYEOF'
import re, sys
path, shapes = sys.argv[1], sys.argv[2:]
text = open(path, encoding="utf-8").read()
blocks = re.findall(r'<div[^>]*\bdata-figure-lang="(en|ja)"[^>]*>\s*<pre class="dragon" data-still>(.*?)</pre>', text, re.S)
problems = []
for lang in ("en", "ja"):
    mine = [body for found, body in blocks if found == lang]
    for shape in shapes:
        if not any(shape in body for body in mine):
            problems.append("no still %s block for %s" % (shape.strip(), lang))
for rule in ('html[lang="en"] [data-figure-lang="ja"]', 'html[lang="ja"] [data-figure-lang="en"]'):
    if rule not in text:
        problems.append("the figures of the other language are not hidden by " + rule)
if "cdn.jsdelivr.net/npm/@cardenelabs/dragon@" not in text:
    problems.append("the dragon entry line is missing")
for problem in problems:
    print("      " + problem)
sys.exit(1 if problems else 0)
PYEOF
}

report_figures() {
  figures "$SKILL_DIR/templates/report.html" "[shape: bar]" "[shape: donut]" || return 1
  # The figures show values that the rows do not, so no value is shown twice.
  python3 - "$SKILL_DIR/templates/report.html" <<'PYEOF'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
blocks = re.findall(r'<pre class="dragon" data-still>(.*?)</pre>', text, re.S)
values = {int(v) for body in blocks for v in re.findall(r"^\s*set \w+: (\d+)\s*$", body, re.M)}
scores = [int(v) for v in re.findall(r"\bscore: (\d+)", text)]
rows = set(scores) | {round(v / 1000) for v in scores}
shared = sorted(values & rows)
if not values:
    print("      the figures set no values")
    sys.exit(1)
if shared:
    print("      the figures repeat the row values " + ", ".join(map(str, shared)))
    sys.exit(1)
PYEOF
}
check "the report template holds a still bar chart and a still donut in both languages" report_figures

document_figures() {
  figures "$SKILL_DIR/templates/document.html" "flow " || return 1
  ! grep -qF 'const FLOW = {' "$SKILL_DIR/templates/document.html" || { echo "      the boxes drawn by hand are still there"; return 1; }
}
check "the document template holds a still flow of the steps in both languages" document_figures

# still_page <name> <entry line>: the good page with a still bar chart block, and the entry line when given.
still_page() {
  page "$T/html/$1.html"
  python3 - "$T/html/$1.html" "$2" "${3:-still}" <<'PYEOF'
import sys
path, entry, kind = sys.argv[1], sys.argv[2], sys.argv[3]
block = '<pre class="dragon"%s>chart Sales [shape: bar]\nitem a as A\nstep Week\n  say Sales.\n  set a: 3\n</pre>' % (" data-still" if kind == "still" else "")
text = open(path, encoding="utf-8").read().replace("<p>SECRET_TEXT_MARKER", block + "<p>SECRET_TEXT_MARKER")
if entry:
    text = text.replace("</head>", entry + "</head>")
open(path, "w", encoding="utf-8").write(text)
PYEOF
}
ENTRY_LINE='<script type="module" src="https://cdn.jsdelivr.net/npm/@cardenelabs/dragon@0.80/dist/cdn/dragon.js"></script>'

verify_figure_blocks() {
  still_page fig-block ""
  run verify "$T/html/fig-block.html" > "$T/fig-block.out" 2>&1
  [ $? -eq 1 ] || { echo "      a page with a dragon block did not exit 1"; return 1; }
  grep -Eq '^.*fig-block\.html:[0-9]+: figure-not-embedded: .*dragon embed' "$T/fig-block.out" || { echo "      the block was not named with dragon embed"; return 1; }
}
check "verify refuses a page that still holds a dragon block" verify_figure_blocks

verify_source_figures() {
  still_page fig-source "$ENTRY_LINE"
  run verify --source "$T/html/fig-source.html" > "$T/fig-source.out" 2>&1 || { sed 's/^/      /' "$T/fig-source.out"; return 1; }
  still_page fig-moving "$ENTRY_LINE" moving
  run verify --source "$T/html/fig-moving.html" > "$T/fig-moving.out" 2>&1
  [ $? -eq 1 ] || { echo "      a block without data-still did not exit 1"; return 1; }
  grep -Eq '^.*fig-moving\.html:[0-9]+: figure-not-still: .+' "$T/fig-moving.out" || { echo "      the block was not named figure-not-still"; return 1; }
  # Outside --source, the entry line still reads a file from outside.
  run verify "$T/html/fig-source.html" > "$T/fig-source-page.out" 2>&1
  grep -q ': external-file: ' "$T/fig-source-page.out" || { echo "      the entry line passed outside --source"; return 1; }
}
check "verify --source refuses a dragon block that is not still" verify_source_figures

verify_figure_text() {
  breaks fig-embedded 'text.replace("<p>SECRET_TEXT_MARKER", "<div class=\"dragon-figure dragon-still\"><svg class=\"dg dg-a1\" style=\"display:block;max-width:100%\"><style>.dg-a1 .t{font-size:9px}</style><text style=\"font-size:10px\">Week: 3</text></svg></div><p>SECRET_TEXT_MARKER")'
  run verify "$T/html/fig-embedded.html" > "$T/fig-embedded.out" 2>&1 || { sed 's/^/      /' "$T/fig-embedded.out"; return 1; }
}
check "verify accepts the text inside an embedded dragon figure" verify_figure_text

follows_dragon() {
  python3 - "$DECLARATION" <<'PYEOF' || return 1
import json, sys
follows = json.load(open(sys.argv[1], encoding="utf-8")).get("follows", {})
want = ["dragon/notation", "dragon/embed", "dragon/chart", "dragon/flow", "dragon/architecture", "dragon/sequence"]
problems = [ref for ref in want if not (follows.get(ref, {}).get("optional") is True and follows[ref].get("version") and follows[ref].get("integrity"))]
for ref in problems:
    print("      musubi.json does not follow %s as an optional follow" % ref)
sys.exit(1 if problems else 0)
PYEOF
  has "$SKILL" 'When the `dragon` skill is installed' 'If the `dragon` skill is not installed' "npx -y @cardenelabs/dragon@" "dragon embed"
}
check "page-design follows the dragon skill for figures" follows_dragon

npx_pages() {
  local page
  for page in README.md README.ja.md docs/how-it-works.md docs/how-it-works.ja.md; do
    has "$PLUGIN/$page" "npx -y @cardenelabs/dragon@" || return 1
  done
  grep -m1 'Keep runtime dependencies small' "$REPO/AGENTS.md" | grep -qF '`design-formats`' || { echo "      AGENTS.md does not name design-formats in the dependency rule"; return 1; }
}
check "the pages say page-design fetches dragon through npx" npx_pages

copy_back() {
  local t f
  for t in sheet choice; do
    f="$SKILL_DIR/templates/$t.html"
    [ -f "$f" ] || return 1
    grep -qF 'navigator.clipboard.writeText' "$f" || { echo "      $t.html does not copy"; return 1; }
    grep -qF 'select()' "$f" || { echo "      $t.html has no fallback that selects the text"; return 1; }
    # The copied text is built from fixed English words, never from the dictionary.
    python3 - "$f" <<'PYEOF' || { echo "      $t.html builds the copied text from the dictionary"; return 1; }
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
body = re.search(r"function copyText\(\)\s*\{(.*?)\n\}", text, re.S)
sys.exit(0 if body and "TEXT[" not in body.group(1) and "t(" not in body.group(1) else 1)
PYEOF
  done
}
check "the sheet and choice templates copy text that does not depend on the language" copy_back

# page <file>: a page that keeps every rule. Each broken page below breaks one of them.
page() {
  mkdir -p "$(dirname "$1")"
  cat > "$1" <<'HTMLEOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Weekly sales of the bakery</title>
<style>
:root { --bg: #fff; --ink: #111; }
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { --bg: #111; --ink: #eee; } }
:root[data-theme="dark"] { --bg: #111; --ink: #eee; }
body { background: var(--bg); color: var(--ink); font-size: 15px; }
</style>
</head>
<body>
<header><h1 data-t="title">Weekly sales of the bakery</h1>
<button type="button" data-lang="en">English</button><button type="button" data-lang="ja">日本語</button>
<button type="button" data-theme-choice="light">Light</button><button type="button" data-theme-choice="dark">Dark</button></header>
<table><tr><th>Store</th><td>Main street</td></tr><tr><th>Products</th><td>24</td></tr></table>
<p>SECRET_TEXT_MARKER Croissants sold out on three days.</p>
<script>
const TEXT = { en: { title: "Weekly sales of the bakery" }, ja: { title: "パン屋の週の売り上げ" } };
</script>
</body>
</html>
HTMLEOF
}

# breaks <name> <python expression on text>: a copy of the good page with one rule broken.
breaks() {
  page "$T/html/$1.html"
  python3 - "$T/html/$1.html" "$2" <<'PYEOF'
import sys
path, expression = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
open(path, "w", encoding="utf-8").write(eval(expression, {"text": text}))
PYEOF
}

verify_html_refusals() {
  local name rule
  page "$T/html/good.html"
  run verify "$T/html/good.html" > "$T/html-good.out" 2>&1 || { sed 's/^/      /' "$T/html-good.out"; return 1; }
  breaks colon-heading 'text.replace("<h1 data-t=\"title\">Weekly sales of the bakery</h1>", "<h1>Bakery: weekly sales</h1>")'
  breaks ja-heading 'text.replace("<h1 data-t=\"title\">Weekly sales of the bakery</h1>", "<h1>パン屋の売り上げ、一覧</h1>")'
  breaks data-heading 'text.replace("</script>", "const DATA = { title: { en: \"Bakery: weekly sales\", ja: \"パン屋の週の売り上げ\" } };\n</script>")'
  breaks facts-line 'text.replace("<p>SECRET_TEXT_MARKER", "<p>Main street store, 2026-11-10 to 2026-11-16, 24 products, 1,240 customers, generated 2026-11-17 08:00</p><p>SECRET_TEXT_MARKER")'
  breaks label-colon 'text.replace("<p>SECRET_TEXT_MARKER", "<p>Why it sold: it sold out by noon</p><p>SECRET_TEXT_MARKER")'
  breaks small-text 'text.replace("font-size: 15px", "font-size: 10px")'
  breaks no-switch 'text.replace("<button type=\"button\" data-lang=\"en\">English</button><button type=\"button\" data-lang=\"ja\">日本語</button>", "")'
  breaks no-dictionary 'text.replace("const TEXT = { en: { title: \"Weekly sales of the bakery\" }, ja: { title: \"パン屋の週の売り上げ\" } };", "")'
  breaks no-dark 'text.replace("@media (prefers-color-scheme: dark) { :root:not([data-theme=\"light\"]) { --bg: #111; --ink: #eee; } }", "")'
  breaks external 'text.replace("</head>", "<script src=\"https://cdn.example.com/lib.js\"></script></head>")'
  for name in colon-heading:heading-punctuation ja-heading:heading-punctuation data-heading:heading-punctuation \
    facts-line:facts-in-one-line \
    label-colon:label-colon small-text:small-text no-switch:missing-language-switch \
    no-dictionary:missing-dictionary no-dark:missing-dark-colors external:external-file; do
    rule="${name#*:}"
    name="${name%%:*}"
    run verify "$T/html/$name.html" > "$T/html-$name.out" 2>&1
    [ $? -eq 1 ] || { echo "      $name did not exit 1"; return 1; }
    grep -Eq "^.*$name\.html:[0-9]+: $rule: .+" "$T/html-$name.out" || { echo "      $name did not name $rule with a line and a fix"; return 1; }
  done
}
check "verify refuses an HTML page that breaks a rule" verify_html_refusals

verify_markdown_refusals() {
  local d="$T/md" name rule
  mkdir -p "$d"
  printf '# Weekly sales of the bakery\n\nCroissants sold out on three days. SECRET_TEXT_MARKER\n\n| Item | Value |\n|---|---|\n| Store | Main street |\n\n```text\nWhy: this colon is inside a code block\n```\n' > "$d/good.md"
  run verify "$d/good.md" > "$T/md-good.out" 2>&1 || { sed 's/^/      /' "$T/md-good.out"; return 1; }
  printf '# Bakery: weekly sales\n\nText.\n' > "$d/colon-heading.md"
  printf '## 売れた商品、理由\n\nText.\n' > "$d/ja-heading.md"
  printf '# Sales\n\n- Why it sold: it sold out by noon\n' > "$d/label-colon.md"
  printf '# Sales\n\nMain street store, 2026-11-10 to 2026-11-16, 24 products, 1,240 customers, generated 2026-11-17 08:00\n' > "$d/facts-line.md"
  for name in colon-heading:heading-punctuation ja-heading:heading-punctuation label-colon:label-colon facts-line:facts-in-one-line; do
    rule="${name#*:}"
    name="${name%%:*}"
    run verify "$d/$name.md" > "$T/md-$name.out" 2>&1
    [ $? -eq 1 ] || { echo "      $name did not exit 1"; return 1; }
    grep -Eq "^.*$name\.md:[0-9]+: $rule: .+" "$T/md-$name.out" || { echo "      $name did not name $rule with a line and a fix"; return 1; }
  done
}
check "verify refuses a Markdown document that breaks a rule" verify_markdown_refusals

verify_quiet() {
  local f
  [ -f "$SCRIPT" ] || return 1
  for f in "$T"/html/*.html "$T"/md/*.md; do
    run verify "$f" > "$T/quiet.out" 2>&1
    ! grep -q 'SECRET_TEXT_MARKER\|Bakery: weekly\|Why it sold\|1,240 customers' "$T/quiet.out" || { echo "      $(basename "$f") printed its text"; return 1; }
  done
  run verify "$T/none.html" > "$T/none.out" 2>&1
  [ $? -eq 2 ] || { echo "      a missing file did not exit 2"; return 1; }
  printf 'x\n' > "$T/page.txt"
  run verify "$T/page.txt" > "$T/txt.out" 2>&1
  [ $? -eq 2 ] || { echo "      a file that is neither HTML nor Markdown did not exit 2"; return 1; }
}
check "verify prints rule names and line numbers, never the page's text" verify_quiet

skill_steps() {
  has "$SKILL" "name: page-design" "formats/structure.md" "formats/look.md" "templates/report.html" \
    "templates/sheet.html" "templates/document.html" "templates/choice.html" "scripts/page-design.py verify" \
    "musubi.json" "Claude Code" "Codex"
}
check "the skill tells a following skill how to read the formats and run verify" skill_steps

musubi_accepts() {
  musubi check "$PLUGIN/skills" > "$T/musubi.out" 2>&1 || { sed 's/^/      /' "$T/musubi.out"; return 1; }
  # musubi prints counts, not names; the folder holds one skill, page-design.
  grep -q 'skills=1' "$T/musubi.out"
}
if command -v musubi > /dev/null 2>&1; then
  check "musubi check accepts page-design" musubi_accepts
else
  skip "musubi check accepts page-design" "the musubi command is not on PATH"
fi

# unreleased <changelog>: the lines between ## [Unreleased] and the next release.
unreleased() { awk '/^## \[Unreleased\]/{on=1; next} /^## \[/{on=0} on' "$1"; }

changelogs() {
  [ -f "$PLUGIN/CHANGELOG.md" ] || return 1
  awk '/^## \[0\.1\.0\]/{on=1; next} /^## \[/{on=0} on' "$PLUGIN/CHANGELOG.md" | grep -q 'page-design' || return 1
  unreleased "$REPO/CHANGELOG.md" | grep -q 'design-formats'
}
check "the changelogs name page-design" changelogs

repo_checks() { bash "$REPO/scripts/check.sh" > "$T/check.out" 2>&1 || { tail -5 "$T/check.out" | sed 's/^/      /'; return 1; }; }
check "the repository checks pass" repo_checks

printf '%d passed, %d failed (%d ran, %d skipped)\n' "$PASS" "$FAIL" "$((PASS + FAIL))" "$SKIP"
[ "$FAIL" -eq 0 ]
