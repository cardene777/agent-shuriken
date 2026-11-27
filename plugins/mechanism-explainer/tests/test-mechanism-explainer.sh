#!/usr/bin/env bash
# Tests for the mechanism-explainer plugin. They read the plugin's pages, manifests, and skill, run the
# PDF script on a small page in a throwaway folder, and relay the manifest check of scripts/check.sh.
# The PDF check uses a Chromium-based browser already on the machine and is skipped without one.
# Nothing is fetched from the network and nothing is written outside the throwaway folder: the browser
# profile goes to TMPDIR, which points there, and the refusal check also points HOME there.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$(cd "$HERE/.." && pwd)"
ROOT="$(cd "$PLUGIN/../.." && pwd)"
SKILL="$PLUGIN/skills/mechanism-explainer"
DOC="$SKILL/SKILL.md"
PDF="$SKILL/scripts/to-pdf.py"
T="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$T"' EXIT

PASS=0
FAIL=0
SKIP=0
why=""
ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; [ -n "$why" ] && printf '        %s\n' "$why"; }
check() {
  why=""
  "$2"
  case $? in
    0) ok "$1" ;;
    77) SKIP=$((SKIP + 1)); printf 'skip  %s (%s)\n' "$1" "$why" ;;
    *) ng "$1" ;;
  esac
}

# The marketplace lists the plugin once, and the folder holds what every plugin holds.
marketplace_and_pages() {
  local n f
  n="$(jq '[.plugins[] | select(.name == "mechanism-explainer" and .source == "./plugins/mechanism-explainer")] | length' \
    "$ROOT/.claude-plugin/marketplace.json")"
  [ "$n" = 1 ] || { why="the marketplace lists mechanism-explainer $n times"; return 1; }
  for f in .claude-plugin/plugin.json .codex-plugin/plugin.json README.md README.ja.md docs/how-it-works.md \
    docs/how-it-works.ja.md CHANGELOG.md LICENSE assets/icon.svg skills/mechanism-explainer/SKILL.md \
    skills/mechanism-explainer/agents/openai.yaml; do
    [ -f "$PLUGIN/$f" ] || { why="plugins/mechanism-explainer/$f is missing"; return 1; }
  done
}

# The dependency line of AGENTS.md names the plugin and the dragon package it fetches.
agents_dragon() {
  local line
  line="$(grep -m1 '^- Keep runtime dependencies small' "$ROOT/AGENTS.md")"
  case "$line" in
    *mechanism-explainer*@cardenelabs/dragon*|*@cardenelabs/dragon*mechanism-explainer*) ;;
    *) why="the dependency line of AGENTS.md does not name mechanism-explainer with @cardenelabs/dragon"; return 1 ;;
  esac
  local mention
  mention="$(printf '%s' "$line" | grep -o 'The [^.]*mechanism-explainer[^.]*\.' | head -1)"
  case "$mention" in
    *npx*) ;;
    *) why="the sentence about mechanism-explainer does not say it runs dragon through npx"; return 1 ;;
  esac
}

# Line number of the first line matching a fixed string, or 0.
first_line() { grep -n -F -m1 -- "$1" "$DOC" | cut -d: -f1 || true; }

# The plan comes before any notation: each section is one question, a one-sentence answer,
# and one figure per question (#560).
plans_first() {
  [ -f "$DOC" ] || { why="SKILL.md is missing"; return 1; }
  local plan guide phrase
  plan="$(grep -n -m1 '^## .*[Pp]lan' "$DOC" | cut -d: -f1)"
  guide="$(first_line 'layout: guide')"
  [ -n "$plan" ] || { why="SKILL.md has no heading about the plan"; return 1; }
  [ -n "$guide" ] || { why="SKILL.md never names layout: guide"; return 1; }
  [ "$plan" -lt "$guide" ] || { why="the plan heading (line $plan) comes after the guide Markdown (line $guide)"; return 1; }
  for phrase in 'one question' 'one-sentence answer' 'one figure per question'; do
    grep -q -F -- "$phrase" "$DOC" || { why="SKILL.md does not say '$phrase'"; return 1; }
  done
}

# Every dragon command names the same exact version, and the page is exported as a guide page with cards.
pinned_export() {
  [ -f "$DOC" ] || { why="SKILL.md is missing"; return 1; }
  local versions
  grep -q -F 'layout: guide' "$DOC" || { why="SKILL.md does not name layout: guide"; return 1; }
  grep -q -F 'note: pop' "$DOC" || { why="SKILL.md does not name note: pop"; return 1; }
  grep -q -E 'npx -y @cardenelabs/dragon@[0-9]+\.[0-9]+\.[0-9]+ export ' "$DOC" \
    || { why="SKILL.md has no export through npx -y @cardenelabs/dragon@X.Y.Z"; return 1; }
  if grep -q -E '@cardenelabs/dragon(@latest|@\^|@~|[^@0-9a-z/-]|$)' "$DOC"; then
    why="SKILL.md names dragon without an exact version"; return 1
  fi
  versions="$(grep -o -E '@cardenelabs/dragon@[0-9]+\.[0-9]+\.[0-9]+' "$DOC" | sort -u | wc -l | tr -d ' ')"
  [ "$versions" = 1 ] || { why="SKILL.md names $versions different dragon versions"; return 1; }
}

# Both checks come before the export, and the skill fixes every error they name.
checks_before_export() {
  [ -f "$DOC" ] || { why="SKILL.md is missing"; return 1; }
  local chk lay exp
  chk="$(grep -n -m1 -E 'dragon@[0-9.]+ check [^-]' "$DOC" | cut -d: -f1)"
  lay="$(grep -n -m1 -E 'dragon@[0-9.]+ check --layout' "$DOC" | cut -d: -f1)"
  exp="$(grep -n -m1 -E 'dragon@[0-9.]+ export ' "$DOC" | cut -d: -f1)"
  [ -n "$chk" ] && [ -n "$lay" ] && [ -n "$exp" ] || { why="SKILL.md lacks dragon check, check --layout, or export"; return 1; }
  [ "$chk" -lt "$exp" ] && [ "$lay" -lt "$exp" ] || { why="a check (lines $chk, $lay) comes after the export (line $exp)"; return 1; }
  grep -q -i -E 'fix every (error|line)' "$DOC" || { why="SKILL.md does not say to fix every error"; return 1; }
}

# The PDF script prints a small page to a PDF. Skipped without a browser on the machine.
pdf_prints() {
  [ -f "$PDF" ] || { why="scripts/to-pdf.py is missing"; return 1; }
  local out status
  out="$(TMPDIR="$T" python3 "$PDF" "$HERE/fixtures/page.html" "$T/page.pdf" 2>&1)"
  status=$?
  if [ "$status" -eq 3 ]; then why="no Chromium-based browser on this machine"; return 77; fi
  [ "$status" -eq 0 ] || { why="to-pdf.py exited $status: $(printf '%s' "$out" | head -2)"; return 1; }
  [ -s "$T/page.pdf" ] || { why="to-pdf.py wrote no PDF"; return 1; }
  [ "$(head -c 5 "$T/page.pdf")" = "%PDF-" ] || { why="the file to-pdf.py wrote is not a PDF"; return 1; }
}

# With the browser pointed at a path that does not exist, the script ends with 3 and writes nothing.
pdf_refuses() {
  [ -f "$PDF" ] || { why="scripts/to-pdf.py is missing"; return 1; }
  local status
  HOME="$T/home" MECHANISM_EXPLAINER_BROWSER="$T/no-browser" python3 "$PDF" "$HERE/fixtures/page.html" "$T/none.pdf" >/dev/null 2>&1
  status=$?
  [ "$status" -eq 3 ] || { why="to-pdf.py exited $status without a browser"; return 1; }
  [ ! -e "$T/none.pdf" ] || { why="to-pdf.py wrote a file without a browser"; return 1; }
}

# The description says what the skill makes: an explainer page answering questions with dragon figures, and a PDF.
description_names() {
  [ -f "$DOC" ] || { why="SKILL.md is missing"; return 1; }
  local desc word
  desc="$(sed -n '2,6p' "$DOC" | grep -m1 '^description:')"
  for word in explainer question dragon PDF; do
    case "$desc" in *"$word"*) ;; *) why="the description does not say $word"; return 1 ;; esac
  done
}

# The page opens with one figure of the whole mechanism, written in the page lead before the first topic,
# which dragon shows as the overview at the head of the page (cardene777/dragon#3961).
overview_in_lead() {
  [ -f "$DOC" ] || { why="SKILL.md is missing"; return 1; }
  grep -q -F 'overview figure' "$DOC" || { why="SKILL.md does not ask for an overview figure"; return 1; }
  grep -q -i -E 'page lead.*before the first topic|before the first topic.*page lead' "$DOC" \
    || { why="SKILL.md does not say the overview figure goes in the page lead before the first topic"; return 1; }
}

# Every question heading ends with a short menu name, with the length limits for Japanese and English.
menu_names() {
  [ -f "$DOC" ] || { why="SKILL.md is missing"; return 1; }
  grep -q -F '[menu: ' "$DOC" || { why="SKILL.md does not show [menu: ...]"; return 1; }
  grep -q -E '12 characters' "$DOC" || { why="SKILL.md does not give the 12-character limit for Japanese"; return 1; }
  grep -q -E '24 characters' "$DOC" || { why="SKILL.md does not give the 24-character limit for English"; return 1; }
}

# One sentence before each figure says what to look at, and two to four sentences after it say what it shows.
figure_explained() {
  [ -f "$DOC" ] || { why="SKILL.md is missing"; return 1; }
  grep -q -F 'one sentence before each figure' "$DOC" || { why="SKILL.md does not ask for one sentence before each figure"; return 1; }
  grep -q -F 'two to four sentences after it' "$DOC" || { why="SKILL.md does not ask for two to four sentences after each figure"; return 1; }
}

# The test page's source has an overview figure in its lead and a menu name on every question. When the
# pinned dragon is already on the machine, it exports the page with the left menu and the overview;
# without it the export part is skipped, so nothing is fetched.
test_page_overview() {
  local md="$HERE/fixtures/page.md" version out
  [ -f "$md" ] || { why="tests/fixtures/page.md is missing"; return 1; }
  out="$(python3 - "$md" <<'PY'
import re, sys
lines = open(sys.argv[1], encoding="utf-8").read().split("\n")
lead, fence, topic, questions, named = 0, False, False, 0, 0
for line in lines:
    if line.startswith("```"):
        if not fence and line.strip() == "```dragon" and not topic:
            lead += 1
        fence = not fence
        continue
    if fence:
        continue
    if line.startswith("## "):
        topic = True
    elif line.startswith("### "):
        questions += 1
        if re.search(r"\[menu: [^\]]+\]\s*$", line):
            named += 1
if lead != 1:
    print("the lead of page.md has %d figures" % lead); sys.exit(1)
if questions == 0 or named != questions:
    print("%d of %d questions in page.md have a menu name" % (named, questions)); sys.exit(1)
PY
)" || { why="$out"; return 1; }
  version="$(grep -o -E '@cardenelabs/dragon@[0-9]+\.[0-9]+\.[0-9]+' "$DOC" | head -1)"
  [ -n "$version" ] || { why="SKILL.md pins no dragon version"; return 1; }
  mkdir -p "$T/export" && cp "$md" "$T/export/page.md"
  if ! (cd "$T/export" && npm exec --offline --yes --package="$version" -- dragon export page.md >/dev/null 2>&1); then
    why="dragon ${version#@cardenelabs/dragon@} is not on this machine"; return 77
  fi
  grep -q 'class="pg-overview' "$T/export/page.html" || { why="the exported page has no overview"; return 1; }
  grep -q 'class="pg-menu' "$T/export/page.html" || { why="the exported page has no left menu"; return 1; }
}

# The pages the plugin shows to readers and agents: the skill, both READMEs, both how-it-works pages, and the
# Codex plugin description.
PAGES=("$DOC" "$PLUGIN/README.md" "$PLUGIN/README.ja.md" "$PLUGIN/docs/how-it-works.md" "$PLUGIN/docs/how-it-works.ja.md" "$PLUGIN/.codex-plugin/plugin.json")

# No page calls the explainer one page that reads top to bottom, since an explainer with two or more
# topics is split into pages (#533). The Japanese phrases are written as escapes, so this file stays English:
# "one page" (1-mai no peeji), "read from top to bottom", and "the topics continue from the top".
no_one_page() {
  local f hit
  for f in "${PAGES[@]}"; do
    [ -f "$f" ] || { why="${f#"$ROOT"/} is missing"; return 1; }
    hit="$(python3 - "$f" <<'PY2'
import re, sys
pattern = re.compile(
    r"one (html )?page that (reads|answers)|reads top to bottom|runs the topics one after another"
    "|1\u679a\u306e\u9801|\u4e0a\u304b\u3089\u4e0b\u3078\u8aad\u3080|\u8a71\u984c\u306f\u4e0a\u304b\u3089\u9806\u306b\u7d9a",
    re.IGNORECASE,
)
for n, line in enumerate(open(sys.argv[1], encoding="utf-8"), 1):
    if pattern.search(line):
        print(n)
        break
PY2
)"
    [ -z "$hit" ] || { why="${f#"$ROOT"/}:$hit still calls the explainer one page"; return 1; }
  done
}

# The skill keeps an explainer with one topic on one page, and splits one with two or more topics into an
# overview page and one page per topic with no tabs at the top (#560). No page still says topic tabs, the
# shape of #547, or one page per question, the shape of #533. The Japanese phrases are written as escapes:
# "the overview tab", "a tab per topic", and "the topic tab".
splits_topics() {
  [ -f "$DOC" ] || { why="SKILL.md is missing"; return 1; }
  local phrase f
  for phrase in 'one topic is one page' 'two or more topics' 'an overview page' 'one page per topic' 'no tabs at the top'; do
    grep -q -F -- "$phrase" "$DOC" || { why="SKILL.md does not say '$phrase'"; return 1; }
  done
  for f in "${PAGES[@]}"; do
    if python3 - "$f" <<'PY3'
import re, sys
pattern = re.compile(
    r"one page per question|an overview tab|one tab per topic|topic tabs?\b"
    "|\u5168\u4f53\u50cf\u306e\u30bf\u30d6|\u8a71\u984c\u3054\u3068\u306e\u30bf\u30d6|\u8a71\u984c\u306e\u30bf\u30d6",
    re.IGNORECASE,
)
sys.exit(0 if any(pattern.search(line) for line in open(sys.argv[1], encoding="utf-8")) else 1)
PY3
    then
      why="${f#"$ROOT"/} still splits the explainer into tabs or into one page per question"
      return 1
    fi
  done
}

# The number of questions and the kinds of material decide one page or topic pages, so a plan cannot put
# six or more questions into one topic and write one long page (#551).
splits_by_count() {
  local phrase
  for phrase in 'one kind with five or fewer questions' 'six or more questions' 'more than one kind'; do
    grep -q -F -- "$phrase" "$DOC" || { why="SKILL.md does not say '$phrase'"; return 1; }
  done
}

# The plan sorts the material into four kinds and orders the topics so the mechanism comes first and the
# records and the reference material come last (#547).
sorts_kinds() {
  local phrase
  for phrase in 'the mechanism' 'background knowledge' 'records' 'reference material' 'the mechanism first' 'records and reference material last'; do
    grep -q -F -- "$phrase" "$DOC" || { why="SKILL.md does not say '$phrase'"; return 1; }
  done
}

# A question that needs another topic goes after that topic, even when the material wrote it earlier (#547).
orders_needed() {
  grep -q -F -- 'A question that needs another topic goes after that topic' "$DOC" \
    || { why="SKILL.md does not put a question after the topic it needs"; return 1; }
}

# Every box of the overview figure that a topic explains links to that topic, so its page opens from the box
# and dragon draws the page's map from the same links (#547).
links_overview() {
  grep -q -F -- 'link: #<topic id>' "$DOC" || { why="SKILL.md does not write link: #<topic id> on the overview boxes"; return 1; }
  grep -q -F -- 'Every box of the overview figure' "$DOC" || { why="SKILL.md does not link every box of the overview figure"; return 1; }
}

# Every dragon the skill and its pages run is 0.89.0 or later, the first version that drops the tabs at the
# top and lists the topics, the questions, and the headings of the open page in a side menu that opens and
# closes with arrows (#560).
pins_docs_menu_dragon() {
  local f v
  for f in "$DOC" "$PLUGIN/README.md" "$PLUGIN/README.ja.md" "$PLUGIN/docs/how-it-works.md" "$PLUGIN/docs/how-it-works.ja.md"; do
    for v in $(grep -o -E 'dragon@?[ ]?[0-9]+\.[0-9]+\.[0-9]+' "$f" | grep -o -E '[0-9]+\.[0-9]+\.[0-9]+' | sort -u); do
      python3 -c 'import sys; a = tuple(map(int, sys.argv[1].split("."))); sys.exit(0 if a >= (0, 89, 0) else 1)' "$v" \
        || { why="${f#"$ROOT"/} runs dragon $v, older than 0.89.0"; return 1; }
    done
  done
}

# SKILL.md tells the agent that each question is its own page, that the side menu has no numbers,
# and that it lists the headings of the open page (#554, #560).
describes_question_pages() {
  local phrase
  for phrase in 'each question is its own page' 'side menu without numbers' 'headings of the open page' 'opens and closes with an arrow'; do
    grep -q -F -- "$phrase" "$DOC" || { why="SKILL.md does not say '$phrase'"; return 1; }
  done
}

# Each question's page is divided by #### headings and holds one figure that follows the flow or the
# mechanism, at most two, with tables or code where they are enough. No page still asks for two to four
# figures, which left a run of figures with short sentences between them (#560). The Japanese phrase is
# written as an escape: "two to four figures".
asks_one_figure() {
  local phrase f
  for phrase in '`####` headings' 'one figure per question' 'at most two' 'tables or code'; do
    grep -q -F -- "$phrase" "$DOC" || { why="SKILL.md does not say '$phrase'"; return 1; }
  done
  for f in "${PAGES[@]}"; do
    if python3 - "$f" <<'PY4'
import re, sys
pattern = re.compile(r"two to four figures|2\u301c4\u679a")
sys.exit(0 if any(pattern.search(line) for line in open(sys.argv[1], encoding="utf-8")) else 1)
PY4
    then
      why="${f#"$ROOT"/} still asks for two to four figures"
      return 1
    fi
  done
}

# A Japanese page is checked with japanese-writing, so the skill follows its writing rules through musubi
# as an optional follow that musubi install brings along for Japanese (agent-shuriken#553).
follows_japanese_rules() {
  python3 - "$SKILL/musubi.json" <<'PY' || { why="musubi.json does not follow japanese-writing/rules as an optional follow for ja"; return 1; }
import json, re, sys
declaration = json.load(open(sys.argv[1], encoding="utf-8"))
follow = declaration.get("follows", {}).get("japanese-writing/rules", {})
ok = (
    declaration.get("musubi") == "2026-11-21"
    and follow.get("version") == "^1.0.0"
    and follow.get("optional") is True
    and follow.get("when") == {"languages": ["ja"]}
    and re.fullmatch(r"sha256-[A-Za-z0-9+/]{43}=", str(follow.get("integrity", ""))) is not None
)
sys.exit(0 if ok else 1)
PY
  local line
  for line in \
    'When the `japanese-writing` skill is installed, write in the `rules` format of the `japanese-writing` skill: open the `japanese-writing` skill by name and read the file it names for `rules`.' \
    'If the `japanese-writing` skill is not installed, go on without the `rules` of `japanese-writing`.'; do
    grep -qxF -- "$line" "$DOC" || { why="SKILL.md lacks the line: $line"; return 1; }
  done
  local f
  for f in README.md README.ja.md docs/how-it-works.md docs/how-it-works.ja.md; do
    grep -qF 'japanese-writing/rules' "$PLUGIN/$f" || { why="$f does not name japanese-writing/rules"; return 1; }
  done
}

OUTLINE="$SKILL/scripts/outline.py"
DESIGN="$SKILL/references/outline-design.md"

# The outline comes before the plan of the figures: the skill writes outline.json, draws it with
# scripts/outline.py, opens it in a browser, and writes nothing before the person approves it (#578).
outline_first() {
  [ -f "$DOC" ] || { why="SKILL.md is missing"; return 1; }
  local outline figures guide command phrase
  outline="$(grep -n -m1 -E '^## .*[Oo]utline' "$DOC" | cut -d: -f1)"
  figures="$(grep -n -m1 -E '^## .*figures' "$DOC" | cut -d: -f1)"
  guide="$(first_line 'layout: guide')"
  command="$(first_line 'scripts/outline.py')"
  [ -n "$outline" ] || { why="SKILL.md has no heading about the outline"; return 1; }
  [ -n "$figures" ] && [ -n "$guide" ] || { why="SKILL.md lacks the plan of the figures or layout: guide"; return 1; }
  [ "$outline" -lt "$figures" ] && [ "$outline" -lt "$guide" ] \
    || { why="the outline heading (line $outline) comes after the plan of the figures (line $figures) or the guide Markdown (line $guide)"; return 1; }
  [ -n "$command" ] && [ "$command" -gt "$outline" ] && [ "$command" -lt "$figures" ] \
    || { why="SKILL.md does not run scripts/outline.py in the outline step"; return 1; }
  for phrase in 'outline.json' 'in a browser' 'approves the outline'; do
    grep -q -F -- "$phrase" "$DOC" || { why="SKILL.md does not say '$phrase'"; return 1; }
  done
}

# Writes the test outline, changed by one line of Python that edits `o`, into its own folder, and runs
# the outline script on it. The output goes to out.txt in the same folder.
outline_run() {
  local dir="$T/outline-$1"
  mkdir -p "$dir"
  python3 - "$HERE/fixtures/outline.json" "$dir/outline.json" "$2" <<'PY'
import json, sys
o = json.load(open(sys.argv[1], encoding="utf-8"))
exec(sys.argv[3])
json.dump(o, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
  python3 "$OUTLINE" "$dir/outline.json" >"$dir/out.txt" 2>&1
}

# The test outline becomes one light page: the title and its point first, every chapter a closed toggle
# with its point, one button for every chapter, and the sections of each page as headings with their
# points under them, with no bullet list or table (#578).
outline_draws() {
  [ -f "$OUTLINE" ] || { why="scripts/outline.py is missing"; return 1; }
  local dir="$T/outline-ok" out
  outline_run ok 'pass' || { why="outline.py refused the test outline: $(head -2 "$dir/out.txt" | tr '\n' ' ')"; return 1; }
  [ -f "$dir/outline.html" ] || { why="outline.py wrote no outline.html next to outline.json"; return 1; }
  out="$(python3 - "$dir/outline.json" "$dir/outline.html" <<'PY'
import html, json, re, sys
o = json.load(open(sys.argv[1], encoding="utf-8"))
page = open(sys.argv[2], encoding="utf-8").read()
def text(s):
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", html.escape(s))
def fail(message):
    print(message); sys.exit(1)
if '<meta name="color-scheme" content="light">' not in page:
    fail("the page does not declare a light color scheme")
if "prefers-color-scheme" in page or re.search(r"color-scheme:\s*[^;}]*dark", page):
    fail("the page has a dark mode")
first = page.find("<details")
if first < 0:
    fail("the page has no chapter toggles")
head = page[:first]
if "<h1>%s</h1>" % html.escape(o["title"]) not in head:
    fail("the title is not the h1 before the chapters")
if text(o["point"]) not in head:
    fail("the point of the title is not before the chapters")
chapters = re.findall(r'<details class="chapter"[^>]*>\s*<summary>(.*?)</summary>', page, re.S)
if len(chapters) != len(o["chapters"]):
    fail("the page has %d chapter toggles for %d chapters" % (len(chapters), len(o["chapters"])))
if re.search(r"<details[^>]*\bopen\b", page):
    fail("a chapter toggle starts open")
for summary, chapter in zip(chapters, o["chapters"]):
    if html.escape(chapter["name"]) not in summary or text(chapter["point"]) not in summary:
        fail("the toggle of %s does not show its name and its point" % chapter["name"])
if len(re.findall(r"<button\b", page)) != 1:
    fail("the page does not have exactly one button")
if "Open all chapters" not in page:
    fail("the button does not say Open all chapters")
for chapter in o["chapters"]:
    for p in chapter["pages"]:
        for s in p["sections"]:
            pair = r"<dt>%s</dt>\s*<dd>%s</dd>" % (re.escape(html.escape(s["name"])), re.escape(text(s["point"])))
            if not re.search(pair, page):
                fail("the section %s is not its heading with its point under it" % s["name"])
for tag in ("ul", "ol", "li", "table"):
    if re.search(r"<%s\b" % tag, page):
        fail("the page has a <%s> element" % tag)
PY
)" || { why="$out"; return 1; }
}

# Each change of the test outline must be refused with exit 1, write no page, and name the reason.
# Arguments: the folder name, the reason the output must hold, then pairs of a case name and its edit.
outline_refuses() {
  [ -f "$OUTLINE" ] || { why="scripts/outline.py is missing"; return 1; }
  local reason="$1" name edit status
  shift
  while [ "$#" -gt 1 ]; do
    name="$1" edit="$2"
    shift 2
    outline_run "$name" "$edit"
    status=$?
    [ "$status" -eq 1 ] || { why="outline.py exited $status for $name"; return 1; }
    [ ! -e "$T/outline-$name/outline.html" ] || { why="outline.py wrote a page for $name"; return 1; }
    grep -q -F -- "$reason" "$T/outline-$name/out.txt" || { why="outline.py did not say '$reason' for $name"; return 1; }
  done
}

refuses_question_or_number() {
  outline_refuses 'question mark or number' \
    title-question 'o["title"] += "?"' \
    chapter-question 'o["chapters"][0]["name"] += "?"' \
    section-wide-question 'o["chapters"][0]["pages"][0]["sections"][0]["name"] += "？"' \
    page-dash-number 'o["chapters"][0]["pages"][0]["name"] = "1-1 " + o["chapters"][0]["pages"][0]["name"]' \
    chapter-dot-number 'o["chapters"][1]["name"] = "2. " + o["chapters"][1]["name"]'
}

refuses_empty_or_repeated_point() {
  outline_refuses 'point' \
    empty-point 'o["chapters"][0]["point"] = ""' \
    blank-point 'o["chapters"][0]["pages"][1]["sections"][0]["point"] = "   "' \
    missing-point 'del o["overview"][0]["point"]' \
    title-point-again 'o["chapters"][1]["point"] = o["point"]' \
    section-point-again 'o["chapters"][0]["pages"][0]["sections"][1]["point"] = o["chapters"][0]["pages"][0]["sections"][0]["point"]'
}

refuses_bullet() {
  outline_refuses 'bullet' \
    dash-point 'o["chapters"][0]["pages"][0]["point"] = "- " + o["chapters"][0]["pages"][0]["point"]' \
    star-name 'o["overview"][0]["name"] = "* " + o["overview"][0]["name"]' \
    middle-dot-point 'o["chapters"][0]["pages"][0]["sections"][0]["point"] = "・" + o["chapters"][0]["pages"][0]["sections"][0]["point"]' \
    later-line-bullet 'o["chapters"][1]["pages"][0]["sections"][0]["point"] += "\n- another item"'
}

# The skill gives the writer the reader-first rules of the outline and the explainer, and no longer writes
# headings as questions or asks who reads the page (#578).
reader_first_rules() {
  [ -f "$DOC" ] || { why="SKILL.md is missing"; return 1; }
  local phrase
  for phrase in 'short noun headings' 'without question marks or numbers' 'its point in one sentence' \
    'never repeat a sentence' 'paragraphs and tables instead of bullet lists' 'lines about the reader, the goals, or the length'; do
    grep -q -i -F -- "$phrase" "$DOC" || { why="SKILL.md does not say '$phrase'"; return 1; }
  done
  ! grep -q -F -- '<question>?' "$DOC" || { why="SKILL.md still writes a heading as a question"; return 1; }
  ! grep -q -F -- 'who reads the page' "$DOC" || { why="SKILL.md still asks who reads the page"; return 1; }
}

# The design rules of the outline page live in a reference file the skill links, and every rule in its
# tables names a source URL (#578).
design_sources() {
  [ -f "$DESIGN" ] || { why="references/outline-design.md is missing"; return 1; }
  grep -q -F 'references/outline-design.md' "$DOC" || { why="SKILL.md does not link references/outline-design.md"; return 1; }
  local out
  out="$(python3 - "$DESIGN" <<'PY'
import re, sys
lines = open(sys.argv[1], encoding="utf-8").read().split("\n")
separator = re.compile(r"^\|\s*:?-{3,}")
rows = []
for i, line in enumerate(lines):
    if not line.startswith("|") or separator.match(line):
        continue
    if i + 1 < len(lines) and separator.match(lines[i + 1]):
        continue
    rows.append((i + 1, line))
if len(rows) < 10:
    print("outline-design.md has %d rules in its tables" % len(rows)); sys.exit(1)
for n, line in rows:
    if "https://" not in line:
        print("outline-design.md:%d names no source URL" % n); sys.exit(1)
PY
)" || { why="$out"; return 1; }
}

# The repository's manifest check, relayed from scripts/check.sh.
repo_manifests() {
  local out
  out="$(cd "$ROOT" && bash scripts/check.sh 2>&1)"
  printf '%s\n' "$out" | grep -q -x 'ok    plugin manifests agree' \
    || { why="$(printf '%s\n' "$out" | grep -A3 'plugin manifests agree' | head -4 | tr '\n' ' ')"; return 1; }
}

check "the marketplace lists the plugin with its pages" marketplace_and_pages
check "AGENTS.md names the plugin's dragon use" agents_dragon
check "the skill plans questions and figures first" plans_first
check "the skill exports a guide page with a pinned dragon" pinned_export
check "the skill checks the notation and the layout before exporting" checks_before_export
check "the PDF script prints an exported page" pdf_prints
check "the PDF script refuses without a browser" pdf_refuses
check "the description names the page and the PDF" description_names
check "the skill puts an overview figure in the page lead" overview_in_lead
check "the skill names each question for the side menu" menu_names
check "the skill explains every figure before and after it" figure_explained
check "the test page has an overview and menu names" test_page_overview
check "no page calls the explainer one page" no_one_page
check "the skill splits two or more topics into pages without tabs" splits_topics
check "the skill splits at six questions or more than one kind" splits_by_count
check "the skill sorts the topics by kind" sorts_kinds
check "the skill puts a question after the topic it needs" orders_needed
check "the skill links overview boxes to their topics" links_overview
check "the skill pins a dragon with the docs menu" pins_docs_menu_dragon
check "the skill describes question pages and the docs menu" describes_question_pages
check "the skill asks for one figure and headings per question" asks_one_figure
check "mechanism-explainer follows rules of japanese-writing for Japanese pages" follows_japanese_rules
check "the skill plans the outline and shows it before writing" outline_first
check "the outline script draws a light page with closed chapter toggles" outline_draws
check "the outline script refuses a question or a numbered name" refuses_question_or_number
check "the outline script refuses an empty or repeated point" refuses_empty_or_repeated_point
check "the outline script refuses a bullet" refuses_bullet
check "the skill gives the reader-first writing rules" reader_first_rules
check "the skill keeps the outline design rules with their sources" design_sources
check "plugin manifests agree" repo_manifests

printf 'mechanism-explainer: ran %d checks, %d failed, %d skipped\n' "$((PASS + FAIL + SKIP))" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
