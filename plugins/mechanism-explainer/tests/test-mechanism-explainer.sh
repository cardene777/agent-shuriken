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
# and two to four figures.
plans_first() {
  [ -f "$DOC" ] || { why="SKILL.md is missing"; return 1; }
  local plan guide phrase
  plan="$(grep -n -m1 '^## .*[Pp]lan' "$DOC" | cut -d: -f1)"
  guide="$(first_line 'layout: guide')"
  [ -n "$plan" ] || { why="SKILL.md has no heading about the plan"; return 1; }
  [ -n "$guide" ] || { why="SKILL.md never names layout: guide"; return 1; }
  [ "$plan" -lt "$guide" ] || { why="the plan heading (line $plan) comes after the guide Markdown (line $guide)"; return 1; }
  for phrase in 'one question' 'one-sentence answer' 'two to four figures'; do
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
# overview tab and one tab per topic (#547). No page still says one page per question, the shape of #533.
splits_tabs() {
  [ -f "$DOC" ] || { why="SKILL.md is missing"; return 1; }
  local phrase f
  for phrase in 'one topic is one page' 'two or more topics' 'an overview tab' 'one tab per topic'; do
    grep -q -F -- "$phrase" "$DOC" || { why="SKILL.md does not say '$phrase'"; return 1; }
  done
  for f in "${PAGES[@]}"; do
    if grep -q -i -E 'one page per question|an overview page' "$f"; then
      why="${f#"$ROOT"/} still splits the explainer into one page per question"
      return 1
    fi
  done
}

# The number of questions and the kinds of material decide one page or topic tabs, so a plan cannot put
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

# Every box of the overview figure that a topic explains links to that topic, so its tab opens from the box
# and dragon draws the tab's map from the same links (#547).
links_overview() {
  grep -q -F -- 'link: #<topic id>' "$DOC" || { why="SKILL.md does not write link: #<topic id> on the overview boxes"; return 1; }
  grep -q -F -- 'Every box of the overview figure' "$DOC" || { why="SKILL.md does not link every box of the overview figure"; return 1; }
}

# Every dragon the skill and its pages run is 0.87.0 or later, the first version that splits a guide page
# with two or more topics into topic tabs and draws each tab's map (#547).
pins_tab_dragon() {
  local f v
  for f in "$DOC" "$PLUGIN/README.md" "$PLUGIN/README.ja.md" "$PLUGIN/docs/how-it-works.md" "$PLUGIN/docs/how-it-works.ja.md"; do
    for v in $(grep -o -E 'dragon@?[ ]?[0-9]+\.[0-9]+\.[0-9]+' "$f" | grep -o -E '[0-9]+\.[0-9]+\.[0-9]+' | sort -u); do
      python3 -c 'import sys; a = tuple(map(int, sys.argv[1].split("."))); sys.exit(0 if a >= (0, 87, 0) else 1)' "$v" \
        || { why="${f#"$ROOT"/} runs dragon $v, older than 0.87.0"; return 1; }
    done
  done
}

# Every dragon the skill and its pages run is 0.88.0 or later, the first version that splits each topic tab
# into one page per question and lists the figure titles of the open question in the side menu (#554).
pins_question_page_dragon() {
  local f v
  for f in "$DOC" "$PLUGIN/README.md" "$PLUGIN/README.ja.md" "$PLUGIN/docs/how-it-works.md" "$PLUGIN/docs/how-it-works.ja.md"; do
    for v in $(grep -o -E 'dragon@?[ ]?[0-9]+\.[0-9]+\.[0-9]+' "$f" | grep -o -E '[0-9]+\.[0-9]+\.[0-9]+' | sort -u); do
      python3 -c 'import sys; a = tuple(map(int, sys.argv[1].split("."))); sys.exit(0 if a >= (0, 88, 0) else 1)' "$v" \
        || { why="${f#"$ROOT"/} runs dragon $v, older than 0.88.0"; return 1; }
    done
  done
}

# SKILL.md tells the agent that each question is its own page, that the side menu has no numbers,
# and that it lists the figure titles under the open question (#554).
describes_question_pages() {
  local phrase
  for phrase in 'each question is its own page' 'side menu without numbers' 'figure titles under the open question'; do
    grep -q -F -- "$phrase" "$DOC" || { why="SKILL.md does not say '$phrase'"; return 1; }
  done
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
check "the skill splits two or more topics into tabs" splits_tabs
check "the skill splits at six questions or more than one kind" splits_by_count
check "the skill sorts the topics by kind" sorts_kinds
check "the skill puts a question after the topic it needs" orders_needed
check "the skill links overview boxes to their topics" links_overview
check "the skill pins a dragon with topic tabs" pins_tab_dragon
check "the skill pins a dragon with question pages" pins_question_page_dragon
check "the skill describes question pages" describes_question_pages
check "plugin manifests agree" repo_manifests

printf 'mechanism-explainer: ran %d checks, %d failed, %d skipped\n' "$((PASS + FAIL + SKIP))" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
