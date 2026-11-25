#!/usr/bin/env bash
# Tests for the mechanism-explainer plugin. They read the plugin's pages, manifests, and skill, run the
# PDF script on a small page in a throwaway folder, and relay the manifest check of scripts/check.sh.
# The PDF check uses a Chromium-based browser already on the machine and is skipped without one.
# Nothing is fetched from the network and no real data folder is touched: HOME points at the throwaway
# folder while the PDF script runs.
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
  out="$(HOME="$T/home" python3 "$PDF" "$HERE/fixtures/page.html" "$T/page.pdf" 2>&1)"
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
check "plugin manifests agree" repo_manifests

printf 'mechanism-explainer: ran %d checks, %d failed, %d skipped\n' "$((PASS + FAIL + SKIP))" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
