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
    "look": {"version": "2.0.0", "file": "formats/look.md"},
    "report": {"version": "2.0.0", "file": "templates/report.html"},
    "sheet": {"version": "2.0.0", "file": "templates/sheet.html"},
    "document": {"version": "2.0.0", "file": "templates/document.html"},
    "choice": {"version": "2.0.0", "file": "templates/choice.html"},
    "verify": {"version": "2.0.0", "file": "scripts/page-design.py"},
}
provides = declaration.get("provides", {})
if declaration.get("musubi") != "2026-11-20" or any(provides.get(name) != content for name, content in want.items()):
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
    "## Explanations and help" "## Enlarging" "## Motion" \
    "## Header controls" "## Self-contained pages" "data-lang" "data-theme-choice" "prefers-reduced-motion"
}
check "the look format holds the rules of headings, facts, text, details, and motion" look_format

PATTERN_DIR="$SKILL_DIR/formats/patterns"
SOURCES="$PATTERN_DIR/sources.md"
# Each pattern file and the letter of its rule IDs.
PATTERNS=(details:D lists-and-tables:L input-and-confirmation:I states-and-notices:S)

# patterns_check <what>: reads the four pattern files and sources.md, and prints a problem for each
# place that breaks their shape. <what> is shape, sources, kinds, or disagree.
#
# A pattern file opens with "## Choose between" and a table whose Rule column names its rules. Each
# rule is a "### <letter><n> <rule in one line>" heading over an Item and Value table with the rows
# Use when, Do not use when (naming what to use instead), How, and Sources (source IDs joined with
# commas). "## Where the sources disagree" holds a Question, What the sources say, Took, and Why
# table. sources.md holds one ID, Source (a link), Kind, Checked, and Quote table.
patterns_check() {
  python3 - "$1" "$PATTERN_DIR" "${PATTERNS[@]}" <<'PYEOF'
import os, re, sys
what, folder, pairs = sys.argv[1], sys.argv[2], sys.argv[3:]
KINDS = {"Design system", "Research and articles", "Public guidance", "Accessibility", "This plugin"}
OUTSIDE = KINDS - {"This plugin"}
problems = []

def cells(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]

def table_after(lines, start):
    """The rows of the first table after lines[start], before the next heading: header first."""
    rows = []
    for line in lines[start + 1:]:
        if line.startswith("#"):
            break
        if line.startswith("|"):
            if not re.match(r"^\|[-| :]+\|$", line.strip()):
                rows.append(cells(line))
        elif rows:
            break
    return rows

cited = {}
for pair in pairs:
    name, letter = pair.split(":")
    path = os.path.join(folder, name + ".md")
    if not os.path.isfile(path):
        problems.append("formats/patterns/%s.md is missing" % name)
        continue
    lines = open(path, encoding="utf-8").read().split("\n")
    seconds = [i for i, line in enumerate(lines) if line.startswith("## ")]
    rules = [(i, re.match(r"^### ([A-Z])(\d+) (\S.*)$", line)) for i, line in enumerate(lines) if line.startswith("### ")]
    if what == "shape":
        if not seconds or lines[seconds[0]] != "## Choose between":
            problems.append("%s.md does not open with ## Choose between" % name)
        else:
            choose = table_after(lines, seconds[0])
            if len(choose) < 3 or "Rule" not in choose[0]:
                problems.append("%s.md: ## Choose between has no table with a Rule column and two rows" % name)
        numbers = []
        for i, found in rules:
            if not found or found.group(1) != letter:
                problems.append("%s.md:%d: a rule heading is not ### %s<n> <rule>" % (name, i + 1, letter))
                continue
            numbers.append(int(found.group(2)))
            if re.search("[:\uff1a\u3001\u3002]", found.group(3)):
                problems.append("%s.md:%d: the rule heading holds a colon" % (name, i + 1))
            rows = table_after(lines, i)
            if not rows or rows[0] != ["Item", "Value"]:
                problems.append("%s.md: %s%s has no Item and Value table" % (name, letter, found.group(2)))
                continue
            fields = {row[0]: row[1] if len(row) > 1 else "" for row in rows[1:]}
            if [row[0] for row in rows[1:]] != ["Use when", "Do not use when", "How", "Sources"]:
                problems.append("%s.md: %s%s does not have the rows Use when, Do not use when, How, and Sources" % (name, letter, found.group(2)))
                continue
            if not all(fields.values()):
                problems.append("%s.md: %s%s leaves a row empty" % (name, letter, found.group(2)))
            if "instead" not in fields["Do not use when"]:
                problems.append("%s.md: %s%s does not say what to use instead" % (name, letter, found.group(2)))
            if not all(re.fullmatch(r"[a-z0-9][a-z0-9-]*", s.strip()) for s in fields["Sources"].split(",")):
                problems.append("%s.md: %s%s names a source that is not an ID" % (name, letter, found.group(2)))
        if len(numbers) < 5:
            problems.append("%s.md holds %d rules, fewer than 5" % (name, len(numbers)))
        elif numbers != list(range(1, len(numbers) + 1)):
            problems.append("%s.md numbers its rules %s, not from 1 without gaps" % (name, numbers))
    for i, found in rules:
        if found:
            for row in table_after(lines, i)[1:]:
                if row[0] == "Sources" and len(row) > 1:
                    for source in row[1].split(","):
                        cited.setdefault(source.strip(), []).append("%s%s" % (found.group(1), found.group(2)))
    if what == "disagree":
        where = [i for i in seconds if lines[i] == "## Where the sources disagree"]
        rows = table_after(lines, where[0]) if where else []
        if not rows or rows[0] != ["Question", "What the sources say", "Took", "Why"]:
            problems.append("%s.md has no ## Where the sources disagree table of Question, What the sources say, Took, and Why" % name)
        elif len(rows) < 2 or not all(len(row) == 4 and all(row) for row in rows[1:]):
            problems.append("%s.md: ## Where the sources disagree has no row, or a row with an empty cell" % name)

if what in ("sources", "kinds"):
    if not os.path.isfile(os.path.join(folder, "sources.md")):
        problems.append("formats/patterns/sources.md is missing")
    else:
        lines = open(os.path.join(folder, "sources.md"), encoding="utf-8").read().split("\n")
        start = next((i - 1 for i, line in enumerate(lines) if line.startswith("| ID |")), None)
        rows = table_after(lines, start) if start is not None else []
        sources = {}
        if not rows or rows[0] != ["ID", "Source", "Kind", "Checked", "Quote"]:
            problems.append("sources.md has no ID, Source, Kind, Checked, and Quote table")
        for row in rows[1:]:
            if len(row) != 5:
                problems.append("sources.md: the row of %s does not have five cells" % row[0])
                continue
            source, link, kind, checked, quote = row
            if source in sources:
                problems.append("sources.md names %s twice" % source)
            sources[source] = kind
            if not re.fullmatch(r"\[[^\]]+\]\(https://[^)\s]+\)", link):
                problems.append("sources.md: %s has no link to an https URL" % source)
            if kind not in KINDS:
                problems.append("sources.md: %s has the kind %r" % (source, kind))
            if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", checked):
                problems.append("sources.md: %s has no checked date" % source)
            if not re.fullmatch(r'".{8,}"', quote):
                problems.append("sources.md: %s has no quote" % source)
        if what == "sources":
            for source, where in sorted(cited.items()):
                if source not in sources:
                    problems.append("%s cite %s, which sources.md does not hold" % (", ".join(where), source))
            for source in sorted(set(sources) - set(cited)):
                problems.append("sources.md holds %s, which no rule cites" % source)
        else:
            missing = sorted(OUTSIDE - {sources[s] for s in cited if s in sources})
            if missing:
                problems.append("no rule cites a source of the kind " + ", ".join(missing))
for problem in problems[:20]:
    print("      " + problem)
sys.exit(1 if problems else 0)
PYEOF
}

pattern_shape() { patterns_check shape; }
check "each pattern file opens with a choose-between table and gives every rule an ID, a use, a do-not-use, a how, and its sources" pattern_shape

pattern_sources() { patterns_check sources; }
check "every source a rule cites is in sources.md with a URL, a kind, a checked date, and a quote" pattern_sources

pattern_kinds() { patterns_check kinds; }
check "the rules cite all four kinds of sources" pattern_kinds

pattern_disagree() { patterns_check disagree; }
check "each pattern file names the side it took where its sources disagree, with the reason" pattern_disagree

pattern_rules() {
  has "$PATTERN_DIR/details.md" "Give the list a fixed width and the details the rest of the row" \
    "Use a modal dialog only for a short, focused task" || return 1
  has "$PATTERN_DIR/lists-and-tables.md" "Put facts about the page in a table of row headers" || return 1
  has "$LOOK" "Break the line after each Japanese full stop"
}
check "the pattern rules keep facts in a table, break Japanese after each full stop, hold the list at a fixed width, and keep dialogs for short tasks" pattern_rules

skill_patterns() {
  local name
  grep -qE '^\| File \| Read it when \|$' "$SKILL" || { echo "      SKILL.md has no File and Read it when table"; return 1; }
  for name in details lists-and-tables input-and-confirmation states-and-notices sources; do
    grep -qE "^\| \`formats/patterns/$name\.md\` \| .{20,} \|$" "$SKILL" || { echo "      SKILL.md does not link formats/patterns/$name.md with when to read it"; return 1; }
  done
}
check "SKILL.md links each pattern file and says when to read it" skill_patterns

look_only_look() {
  ! grep -qF '## Details beside the list' "$LOOK" || { echo "      look.md still holds ## Details beside the list"; return 1; }
  ! grep -qF 'Facts sit on one quiet line' "$LOOK" || { echo "      look.md still puts facts on one quiet line"; return 1; }
  ! grep -qiE 'pressing a row shows its details' "$LOOK" || { echo "      look.md still says how a row shows its details"; return 1; }
  has "$LOOK" "formats/patterns/details.md" "formats/patterns/lists-and-tables.md"
}
check "the look format keeps only the look and leaves the list and details to the patterns" look_only_look

patterns_provided() {
  python3 - "$SKILL_DIR" <<'PYEOF'
import json, os, sys
skill = sys.argv[1]
provides = json.load(open(os.path.join(skill, "musubi.json"), encoding="utf-8")).get("provides", {})
problems = []
for name in ("details", "lists-and-tables", "input-and-confirmation", "states-and-notices"):
    want = {"version": "1.0.0", "file": "formats/patterns/%s.md" % name}
    if provides.get(name) != want:
        problems.append("musubi.json provides %s as %s" % (name, json.dumps(provides.get(name))))
    elif not os.path.isfile(os.path.join(skill, want["file"])):
        problems.append("%s is missing" % want["file"])
for problem in problems:
    print("      " + problem)
sys.exit(1 if problems else 0)
PYEOF
}
check "page-design provides the four pattern files in musubi.json" patterns_provided

pattern_pages() {
  local page
  for page in README.md README.ja.md docs/how-it-works.md docs/how-it-works.ja.md; do
    has "$PLUGIN/$page" "formats/patterns/" || return 1
  done
}
check "the design-formats pages describe the pattern files in English and Japanese" pattern_pages

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
  has "$LOOK" "Keep facts about the page apart from the results" "Show each value once" || return 1
  has "$PATTERN_DIR/lists-and-tables.md" "no paging when the list fits on one page" "Give each row its value as a number" || return 1
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
  has "$LOOK" "## Figures" "[shape: bar]" "[shape: donut]" "[shape: band]" '`flow`' '`architecture`' '`sequence`' "line chart" \
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

look_line_chart() {
  grep -qE '^\| A change over time \| .*\[shape: line\]' "$LOOK" || { echo "      look.md: the row of a change over time does not use [shape: line]"; return 1; }
  ! grep -qF 'show a table until dragon draws a line chart' "$LOOK" || { echo "      look.md: still says to show a table instead of a line chart"; return 1; }
}
check "the look format draws a change over time as a dragon line chart" look_line_chart

report_line_chart() {
  figures "$SKILL_DIR/templates/report.html" "[shape: line]" || return 1
  # The line chart spans the width of the figures, above the two smaller figures.
  python3 - "$SKILL_DIR/templates/report.html" <<'PYEOF'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
cards = re.findall(r'<figure class="([^"]*)"[^>]*>(.*?)</figure>', text, re.S)
wide = [classes for classes, body in cards if "[shape: line]" in body]
if not wide or "wide" not in wide[0].split():
    print("      the line chart's card is not .figure.wide")
    sys.exit(1)
if "[shape: line]" not in cards[0][1]:
    print("      the line chart is not the first figure")
    sys.exit(1)
if not re.search(r"\.figure\.wide\s*\{[^}]*grid-column:\s*1\s*/\s*-1", text):
    print("      .figure.wide does not span the figures grid")
    sys.exit(1)
PYEOF
}
check "the report template holds a still line chart of the daily sales in both languages" report_line_chart

document_figures() {
  figures "$SKILL_DIR/templates/document.html" "[shape: band]" || return 1
  ! grep -qF 'const FLOW = {' "$SKILL_DIR/templates/document.html" || { echo "      the boxes drawn by hand are still there"; return 1; }
}
check "the document template holds a still flow of the steps in both languages" document_figures

# card_rule <template> <selector>: prints the declarations of the CSS rules whose selector list holds <selector>.
card_rule() {
  python3 - "$1" "$2" <<'PYEOF'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
style = "".join(re.findall(r"<style>(.*?)</style>", text, re.S))
# A comment before a rule is not part of its selector.
style = re.sub(r"/\*.*?\*/", "", style, flags=re.S)
for selectors, body in re.findall(r"([^{}]+)\{([^{}]*)\}", style):
    if sys.argv[2] in [s.strip() for s in selectors.split(",")]:
        print(body)
PYEOF
}

figure_cards() {
  local template selector
  for pair in "report.html .figure" "report.html #zoom-body" "document.html figure" "document.html #zoom-body"; do
    template=${pair%% *}
    selector=${pair#* }
    card_rule "$SKILL_DIR/templates/$template" "$selector" | grep -qE -- '--dragon-figure-background: *var\(--surface\)' ||
      { echo "      $template: $selector does not pass --dragon-figure-background: var(--surface)"; return 1; }
  done
}
check "the figure cards pass the card color to dragon" figure_cards

report_figures_centered() {
  local rules
  rules=$(card_rule "$SKILL_DIR/templates/report.html" ".figure")
  printf '%s\n' "$rules" | grep -qE 'display: *flex' || { echo "      report.html: .figure is not a flex box"; return 1; }
  printf '%s\n' "$rules" | grep -qE 'flex-direction: *column' || { echo "      report.html: .figure does not stack its parts"; return 1; }
  printf '%s\n' "$rules" | grep -qE 'justify-content: *center' || { echo "      report.html: .figure does not center its figure"; return 1; }
}
check "the report figures sit in the middle of their cards" report_figures_centered

look_card_color() {
  has "$LOOK" '--dragon-figure-background'
}
check "the look format says to pass the card color to dragon" look_card_color

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

# refused <file> <rule>: verify exits 1 and names the rule with a line and a fix.
refused() {
  run verify "$1" > "$1.out" 2>&1
  [ $? -eq 1 ] || { echo "      $(basename "$1") was not refused"; return 1; }
  grep -Eq "^.*$(basename "$1"):[0-9]+: $2: .+" "$1.out" || { echo "      $(basename "$1") did not name $2 with a line and a fix"; sed 's/^/        /' "$1.out"; return 1; }
}

# accepted <file>: verify exits 0.
accepted() { run verify "$1" > "$1.out" 2>&1 || { echo "      $(basename "$1") was refused"; sed 's/^/        /' "$1.out"; return 1; }; }

# Strings in a page's script, as a report keeps an agent's notes in JSON: a long one, one with
# escapes, a short one, one that builds markup, and long prose. Each page adds one string to the
# good page.
mkdir -p "$T/html"
LONG_PROSE='"The loop is the busiest code in the repository and the place most releases touch. " * 4'
FACTS='"the loop runs 64 steps, 12 callers use it, 3 tests cover it, 2 releases changed it"'
with_string() { # <name> <python expression of the string's source text, quotes included>
  breaks "$1" "text.replace(\"</script>\", \"const NOTE = \" + ($2) + \";\\n</script>\", 1)"
}
with_string script-long "'\"' + $LONG_PROSE + $FACTS + '\"'"
with_string script-escaped "'\"the loop runs 64 steps,\\\\n12 callers use it,\\\\n3 tests cover it, and \\\\\"values\\\\\" stays one list\"'"
with_string script-short "'\"' + $FACTS + '\"'"
with_string script-markup "'\"' + '<tr><td>64 steps</td><td>12 callers</td><td>3 tests</td></tr>' * 8 + '\"'"
with_string script-prose "'\"' + $LONG_PROSE + '\"'"
check "verify refuses a long script string that joins facts in one line" "refused '$T/html/script-long.html' facts-in-one-line"
check "verify refuses a script string with escapes that joins facts in one line" "refused '$T/html/script-escaped.html' facts-in-one-line"
check "verify still refuses a short script string that joins facts in one line" "refused '$T/html/script-short.html' facts-in-one-line"
check "verify skips a long script string that builds markup" "accepted '$T/html/script-markup.html'"
check "verify accepts a long script string of prose" "accepted '$T/html/script-prose.html'"

# The docs say that verify reads strings in a script of any length, with their escapes read.
# The Japanese words are written as escapes.
script_docs() {
  python3 - "$PLUGIN" <<'PYEOF'
import sys
root = sys.argv[1]
unreleased = open(root + "/CHANGELOG.md", encoding="utf-8").read().split("## [Unreleased]")[1].split("\n## [")[0]
texts = {"CHANGELOG.md (Unreleased)": unreleased,
         "docs/how-it-works.md": open(root + "/docs/how-it-works.md", encoding="utf-8").read(),
         "docs/how-it-works.ja.md": open(root + "/docs/how-it-works.ja.md", encoding="utf-8").read()}
want = {"CHANGELOG.md (Unreleased)": ["of any length", "escapes"],
        "docs/how-it-works.md": ["of any length", "escapes"],
        "docs/how-it-works.ja.md": ["\u9577\u3055\u306b\u3088\u3089\u305a", "\u30a8\u30b9\u30b1\u30fc\u30d7"]}
problems = ["%s does not say %r" % (name, [w for w in words if w not in texts[name]])
            for name, words in want.items() if any(w not in texts[name] for w in words)]
for p in problems:
    print("      " + p)
sys.exit(1 if problems else 0)
PYEOF
}
check "the docs say verify reads script strings of any length" script_docs

verify_facts_table() {
  local name
  # The facts of a page are a table whose label cells are row headers.
  breaks facts-row-headers 'text.replace("<table><tr><th>Store</th>", "<table class=\"facts\"><tbody><tr><th scope=\"row\">Store</th>").replace("<tr><th>Products</th>", "<tr><th scope=\"row\">Products</th>")'
  accepted "$T/html/facts-row-headers.html" || return 1
  breaks facts-dl 'text.replace("<table><tr><th>Store</th>", "<dl class=\"facts\"><div><dt>Week</dt><dd>Nov 10 to 16</dd></div></dl><table><tr><th>Store</th>")'
  breaks facts-div 'text.replace("<table><tr><th>Store</th>", "<div id=\"facts\"><span>Week</span> <b>Nov 10 to 16</b></div><table><tr><th>Store</th>")'
  breaks facts-cells 'text.replace("<table><tr><th>Store</th>", "<table class=\"facts\"><tr><td>Store</td>").replace("<tr><th>Products</th>", "<tr><td>Products</td>")'
  breaks facts-column-headers 'text.replace("<table><tr><th>Store</th>", "<table class=\"facts\"><tr><th scope=\"col\">Store</th>").replace("<tr><th>Products</th>", "<tr><th scope=\"col\">Products</th>")'
  for name in facts-dl facts-div facts-cells facts-column-headers; do
    refused "$T/html/$name.html" facts-not-table || return 1
  done
}
check "verify refuses facts that are not a table with row headers" verify_facts_table

verify_sentence_lines() {
  local d="$T/sentences" name
  mkdir -p "$d"
  printf '# Sales\n\n売り切れた。明日も焼く。\n' > "$d/md-joined.md"
  printf '# Sales\n\n- 売り切れた。 明日も焼く。\n' > "$d/md-space.md"
  breaks html-joined 'text.replace("<p>SECRET_TEXT_MARKER", "<p>売り切れた。明日も焼く。</p><p>SECRET_TEXT_MARKER")'
  breaks html-source-line 'text.replace("<p>SECRET_TEXT_MARKER", "<p>売り切れた。\n明日も焼く。</p><p>SECRET_TEXT_MARKER")'
  cp "$T/html/html-joined.html" "$T/html/html-source-line.html" "$d/"
  for name in md-joined.md md-space.md html-joined.html html-source-line.html; do
    refused "$d/$name" sentence-per-line || return 1
  done
}
check "verify refuses a Japanese sentence that does not end its line" verify_sentence_lines

verify_sentence_ends() {
  local d="$T/sentence-ends" name
  mkdir -p "$d"
  printf '# Sales\n\n売り切れた。\n明日も焼く。\n「売り切れた。」と店長が言った。\n- 三日とも売り切れた。 \n\n| Item | Value |\n|---|---|\n| Note | 売り切れた。明日も焼く。 |\n\n```text\n売り切れた。明日も焼く。\n```\n' > "$d/md-ends.md"
  breaks html-ends 'text.replace("<p>SECRET_TEXT_MARKER", "<p>売り切れた。<br>明日も焼く。</p><p>「売り切れた。」と店長が言った。</p><pre>売り切れた。明日も焼く。</pre><p>SECRET_TEXT_MARKER")'
  cp "$T/html/html-ends.html" "$d/"
  for name in md-ends.md html-ends.html; do
    accepted "$d/$name" || return 1
  done
}
check "verify accepts a Japanese sentence that ends its line" verify_sentence_ends

verify_list_width() {
  local name
  breaks split-fixed 'text.replace("</style>", ".split { display: grid; grid-template-columns: minmax(300px, 380px) minmax(0, 1fr); }\n.list-detail .split { grid-template-columns: 360px 1fr; }\n@media (max-width: 860px) { .split { grid-template-columns: 1fr; } }\n</style>")'
  accepted "$T/html/split-fixed.html" || return 1
  breaks split-shares 'text.replace("</style>", ".split { display: grid; grid-template-columns: minmax(0, 1.1fr) minmax(0, 1fr); }\n</style>")'
  breaks split-halves 'text.replace("</style>", ".split { display: grid; grid-template-columns: 1fr 1fr; }\n</style>")'
  breaks split-grows 'text.replace("</style>", ".split { display: grid; grid-template-columns: minmax(320px, 1fr) minmax(0, 1fr); }\n</style>")'
  breaks split-percent 'text.replace("</style>", ".split { display: grid; grid-template-columns: minmax(0, 40%) 1fr; }\n</style>")'
  for name in split-shares split-halves split-grows split-percent; do
    refused "$T/html/$name.html" list-detail-width || return 1
  done
}
check "verify refuses a list column that grows with the page beside its details" verify_list_width

# The report and sheet templates of e5ed749 put the facts in a <dl> and let the list column grow,
# the two shapes the pattern rules replaced. The check is skipped where git cannot read that commit.
OLD=e5ed749
old_templates() {
  local t
  mkdir -p "$T/old"
  for t in report sheet; do
    git -C "$REPO" show "$OLD:plugins/design-formats/skills/page-design/templates/$t.html" > "$T/old/$t.html" 2>/dev/null || return 1
    run verify --source "$T/old/$t.html" > "$T/old/$t.out" 2>&1
    [ $? -eq 1 ] || { echo "      $t.html of $OLD was not refused"; return 1; }
    grep -q ": facts-not-table: " "$T/old/$t.out" || { echo "      $t.html of $OLD was not refused for its facts"; return 1; }
    grep -q ": list-detail-width: " "$T/old/$t.out" || { echo "      $t.html of $OLD was not refused for its list column"; return 1; }
  done
}
if git -C "$REPO" cat-file -e "$OLD:plugins/design-formats/skills/page-design/templates/report.html" 2>/dev/null; then
  check "verify refuses the report and sheet templates of e5ed749, before the pattern rules" old_templates
else
  skip "verify refuses the report and sheet templates of e5ed749, before the pattern rules" "git cannot read $OLD here"
fi

templates_facts() {
  local t f
  for t in "${TYPES[@]}"; do
    f="$SKILL_DIR/templates/$t.html"
    grep -qE '<table class="facts"' "$f" || { echo "      $t.html does not hold the facts in <table class=\"facts\">"; return 1; }
    ! grep -qE '<dl class="facts"|<dt>\$\{' "$f" || { echo "      $t.html still builds the facts as <dt> and <dd>"; return 1; }
    grep -qF '<th scope="row"' "$f" || { echo "      $t.html does not build the facts' labels as row headers"; return 1; }
    card_rule "$f" ".facts th" | grep -qE 'background: *var\(--label\)' || { echo "      $t.html: .facts th has no background of --label"; return 1; }
    [ "$(grep -cE -- '--label: *#' "$f")" -ge 3 ] || { echo "      $t.html does not define --label for light, dark, and the dark choice"; return 1; }
  done
}
check "the templates build facts as a table of row headers on a shaded label color" templates_facts

templates_lines() {
  local t f
  for t in "${TYPES[@]}"; do
    f="$SKILL_DIR/templates/$t.html"
    grep -qE 'const lines = \(s\) => esc\(s\)\.replace\(/\\u3002.*, "\\u3002<br>"\);' "$f" || { echo "      $t.html does not define lines(), which breaks after each full stop"; return 1; }
    grep -qF 'el.innerHTML = lines(t(el.dataset.t))' "$f" || { echo "      $t.html does not put the dictionary's text through lines()"; return 1; }
    # A value in an attribute and the text of a <pre> keep esc(); every other text goes through lines().
    python3 - "$f" <<'PYEOF' || { echo "      $t.html puts text from DATA or the dictionary in the page without lines()"; return 1; }
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
bare = [m.start() for m in re.finditer(r"esc\((?:pick|t)\(", text) if not text[:m.start()].endswith(('="${', "<pre>${"))]
sys.exit(1 if bare else 0)
PYEOF
  done
}
check "the templates break Japanese text after each full stop" templates_lines

templates_list_width() {
  local t
  for t in report sheet; do
    card_rule "$SKILL_DIR/templates/$t.html" ".split" | grep -qE 'grid-template-columns: *minmax\([0-9]+px, *[0-9]+px\) +minmax\(0, *1fr\)' ||
      { echo "      $t.html: .split does not hold the list at a fixed width beside a detail of 1fr"; return 1; }
  done
}
check "the list templates hold the list at a fixed width and give the details the rest" templates_list_width

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
