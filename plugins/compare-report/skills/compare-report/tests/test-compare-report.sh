#!/usr/bin/env bash
# Tests for new-report.sh, check-report.py, and to-pdf.sh in a throwaway HOME.
# A stand-in browser records its arguments and writes a small file in place of the PDF,
# so no real browser starts and nothing reaches the network.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$HERE/../scripts"
TEMPLATE="$HERE/../templates/report.html"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }
mode() { python3 -c 'import os, sys; print(format(os.stat(sys.argv[1]).st_mode & 0o777, "o"))' "$1"; }

# A real Chromium-based browser and pdftotext, for the checks that print a report for real.
# COMPARE_REPORT_TEST_BROWSER names the browser; otherwise the usual apps, the headless browsers
# Playwright downloaded, and then the usual commands are tried. The commands come last because a
# command can be a wrapper that finds its browser through HOME, which the test replaces.
# Without a browser and pdftotext, those checks are skipped.
real_browser=""
for b in "${COMPARE_REPORT_TEST_BROWSER:-}" \
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  "/Applications/Chromium.app/Contents/MacOS/Chromium" \
  "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
  "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" \
  "$HOME"/Library/Caches/ms-playwright/chromium_headless_shell-*/*/chrome-headless-shell \
  "$HOME"/.cache/ms-playwright/chromium_headless_shell-*/*/chrome-headless-shell \
  "$(command -v google-chrome 2>/dev/null)" "$(command -v chromium 2>/dev/null)" "$(command -v chromium-browser 2>/dev/null)"; do
  if [ -n "$b" ] && [ -x "$b" ]; then real_browser="$b"; break; fi
done
pdftotext_cmd="$(command -v pdftotext 2>/dev/null || true)"

export HOME="$T/home"
export PYTHONDONTWRITEBYTECODE=1
export TMPDIR="$T/tmp"
export COMPARE_REPORT_BROWSER="$T/bin/browser"
mkdir -p "$HOME" "$TMPDIR" "$T/bin"
umask 022
today="$(date +%Y-%m-%d)"

new_report() { bash "$SCRIPTS/new-report.sh" "$@"; }
check_report() { python3 "$SCRIPTS/check-report.py" "$@"; }
to_pdf() { bash "$SCRIPTS/to-pdf.sh" "$@"; }

# --- new-report.sh
export COMPARE_REPORT_HOME="$T/reports"
out="$(new_report static-site-generators)"; rc=$?
dir="$T/reports/static-site-generators-$today"
check "new-report exits 0 and prints the report path" '[ "$rc" = 0 ] && [ "$out" = "$dir/report.html" ]'
check "new-report copies the template unchanged" 'cmp -s "$TEMPLATE" "$dir/report.html"'
check "the report folder is readable only by the user" '[ "$(mode "$dir")" = 700 ]'
check "report.html is readable only by the user" '[ "$(mode "$dir/report.html")" = 600 ]'

printf 'edited\n' > "$dir/report.html"
new_report static-site-generators >/dev/null 2>"$T/err"; rc=$?
check "the same slug on the same day exits 3" '[ "$rc" = 3 ] && grep -q "already exists" "$T/err"'
check "an existing report is not overwritten" '[ "$(cat "$dir/report.html")" = edited ]'

for slug in "" "-x" "Static" "static sites" "a/b" "../x" "a_b"; do
  new_report "$slug" >/dev/null 2>"$T/err"; rc=$?
  check "the slug '$slug' exits 2 with the usage" '[ "$rc" = 2 ] && grep -q "^usage: new-report.sh" "$T/err"'
done
check "rejected slugs create nothing" '[ "$(ls "$T/reports")" = "static-site-generators-$today" ]'

unset COMPARE_REPORT_HOME
out="$(new_report databases)"
check "without COMPARE_REPORT_HOME the report goes under ~/.local/share/compare-report" \
  '[ "$out" = "$HOME/.local/share/compare-report/databases-$today/report.html" ] && [ -f "$out" ]'

# --- check-report.py
cat > "$T/good.html" <<'HTML'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>Static site generators</title>
<style>body { color: #111; }</style></head>
<body>
<section id="summary"><p>Pick Hugo for large sites.</p></section>
<section id="candidates"><p>Hugo and Eleventy.</p></section>
<section id="axis-speed" class="axis"><h2>Build speed</h2>
<table>
<tr><th>Candidate</th><th>Score</th><th class="rationale">Why</th></tr>
<tr><td>Hugo</td><td><span class="score s">S</span></td><td>Fastest build in the benchmark</td></tr>
</table>
<div class="bar"><div class="fill" style="width: 80%"></div></div>
</section>
<section id="risks">
<table>
<tr><th>Risk</th><th>Level</th><th class="rationale">Why</th></tr>
<tr><td>One maintainer</td><td><span class="risk medium">Medium</span></td><td>Most commits come from one person</td></tr>
</table>
</section>
<section id="ranking"><ol><li>Hugo</li><li>Eleventy</li></ol></section>
<section id="sources"><ol><li><a href="https://example.org/benchmark">Benchmark</a></li></ol></section>
</body></html>
HTML

out="$(check_report "$T/good.html")"; rc=$?
check "a complete report prints ok and exits 0" '[ "$rc" = 0 ] && [ "$out" = ok ]'

# variant <file> <old text> <new text>: copy good.html with one replacement
variant() {
  python3 - "$T/good.html" "$T/$1" "$2" "$3" <<'PY'
import sys
src, dst, old, new = sys.argv[1:]
text = open(src, encoding="utf-8").read()
if text.count(old) != 1:
    raise SystemExit("variant: %r is not in good.html exactly once" % old)
open(dst, "w", encoding="utf-8").write(text.replace(old, new))
PY
}

# fails <name> <expected text in the output> <old text> <new text>
fails() {
  variant "$1.html" "$3" "$4" || { ng "$1: the variant could not be made"; return; }
  out="$(check_report "$T/$1.html")"; rc=$?
  if [ "$rc" = 1 ] && printf '%s\n' "$out" | grep -qF -- "$2"; then ok "$1 is reported"; else ng "$1 is reported (exit $rc: $out)"; fi
}

fails "a placeholder left in" "the placeholder {{TITLE}} is still in the report" \
  "<title>Static site generators</title>" "<title>{{TITLE}}</title>"
fails "an external script" "<script> loads https://cdn.example.org/a.js" \
  "</head>" '<script src="https://cdn.example.org/a.js"></script></head>'
fails "an external stylesheet" "<link> loads the stylesheet https://cdn.example.org/a.css" \
  "</head>" '<link rel="stylesheet" href="https://cdn.example.org/a.css"></head>'
fails "an @import" "the stylesheet imports @import" \
  "body { color: #111; }" '@import "https://fonts.example.org/a.css"; body { color: #111; }'
fails "a url() from the network" "the stylesheet loads url(//img.example.org/a.png)" \
  "body { color: #111; }" "body { background: url(//img.example.org/a.png); }"
fails "an image from the network" "<img> loads https://img.example.org/a.png" \
  "<p>Hugo and Eleventy.</p>" '<p>Hugo and Eleventy.</p><img src="https://img.example.org/a.png" alt="">'
fails "a missing section" 'the section with id="ranking" is missing' \
  '<section id="ranking">' '<section id="order">'
fails "an empty section" 'the section with id="candidates" is empty' \
  "<p>Hugo and Eleventy.</p>" ""
fails "no axis section" 'there is no section with class="axis"' \
  'class="axis"' 'class="chapter"'
fails "a score table without a rationale column" 'has no <th class="rationale"> column' \
  '<th class="rationale">Why</th></tr>
<tr><td>Hugo</td>' '<th>Why</th></tr>
<tr><td>Hugo</td>'
fails "a score whose text and class disagree" "the score shows 'A' but its class says S" \
  '<span class="score s">S</span>' '<span class="score s">A</span>'
fails "a score with two letter classes" "a score needs exactly one of the classes s, a, b, c, d" \
  'class="score s"' 'class="score s a"'
fails "a risk label without a level" "a risk label needs one of the classes critical, high, medium, low" \
  'class="risk medium"' 'class="risk"'
fails "a bar fill over 100%" 'a bar fill needs style="width: N%"' \
  'style="width: 80%"' 'style="width: 150%"'
fails "sources without a web link" "the sources section links no http or https page" \
  'href="https://example.org/benchmark"' 'href="benchmark.html"'

out="$(check_report "$TEMPLATE")"; rc=$?
check "the unfilled template fails on its placeholders" '[ "$rc" = 1 ] && printf "%s\n" "$out" | grep -qF "the placeholder {{SUMMARY}} is still in the report"'
check "the unfilled template names {{AUTHOR}}" 'printf "%s\n" "$out" | grep -qF "the placeholder {{AUTHOR}} is still in the report"'
check_report >/dev/null 2>&1; rc=$?
check "check-report.py without a file exits 2" '[ "$rc" = 2 ]'

# --- the author line on the cover
# fill_template <file> <author>: the real template with every placeholder filled
fill_template() {
  python3 - "$TEMPLATE" "$T/$1" "$2" <<'PY'
import re, sys
src, dst, author = sys.argv[1:]
values = {
    "LANG": "en", "TITLE": "Static site generators", "EYEBROW": "Comparison report",
    "SUBTITLE": "Hugo and Eleventy for a documentation site", "DATE": "2026-11-14",
    "STATS": "<div><dt>Candidates</dt><dd>2</dd></div>",
    "CONTENTS_HEADING": "Contents", "TOC": '<li><a href="#summary">Summary</a></li>',
    "SUMMARY": "<h2>Summary</h2><p>Pick Hugo for large sites.</p>",
    "CANDIDATES": "<h2>Candidates</h2><p>Hugo and Eleventy.</p>",
    "AXES": '<section id="axis-speed" class="chapter axis"><h2>Build speed</h2><p>Hugo builds fastest.</p></section>',
    "RISKS": "<h2>Risks</h2><p>Eleventy has one maintainer.</p>",
    "RANKING": "<h2>Ranking</h2><ol><li>Hugo</li><li>Eleventy</li></ol>",
    "SOURCES": '<h2>Sources</h2><ol><li><a href="https://example.org/benchmark">Benchmark</a></li></ol>',
    "FOOTER": "2026-11-14", "AUTHOR": author,
}
text = open(src, encoding="utf-8").read()
text = re.sub(r"\{\{([A-Z_]+)\}\}", lambda m: values[m.group(1)], text)
open(dst, "w", encoding="utf-8").write(text)
PY
}

cover="$(sed -n '/<section class="cover">/,/<\/section>/p' "$TEMPLATE")"
check "the template has the author line under the date and hides it when empty" \
  'printf "%s\n" "$cover" | grep -A1 -F "{{DATE}}" | tail -n 1 | grep -qF "<p class=\"cover-author\">{{AUTHOR}}</p>" && grep -qE "cover-author:empty[^{]*\{[^}]*display: *none" "$TEMPLATE"'

fill_template with-author.html "Prepared by Jane Doe" && out="$(check_report "$T/with-author.html")"; rc=$?
check "the filled template with an author prints ok" \
  '[ "$rc" = 0 ] && [ "$out" = ok ] && grep -qF "<p class=\"cover-author\">Prepared by Jane Doe</p>" "$T/with-author.html"'
fill_template no-author.html "" && out="$(check_report "$T/no-author.html")"; rc=$?
check "the filled template with an empty author prints ok" \
  '[ "$rc" = 0 ] && [ "$out" = ok ] && grep -qF "<p class=\"cover-author\"></p>" "$T/no-author.html"'
fill_template blank-author.html "   " && out="$(check_report "$T/blank-author.html")"; rc=$?
check "a blank author line is reported" \
  '[ "$rc" = 1 ] && printf "%s\n" "$out" | grep -qF "the author line on the cover holds only spaces"'

skill="$HERE/../SKILL.md"
check "SKILL.md asks for the author with the candidates and never reads git config or the system" \
  'grep -qF "In the same question as the candidates, ask for the author" "$skill" && grep -qF "scripts/author.sh" "$skill" && grep -qF "Never take the name from \`git config\`, the system" "$skill"'

structure="$HERE/../references/report-structure.md"
missing=""
for p in $(grep -oE '\{\{[A-Z_]+\}\}' "$TEMPLATE" | sort -u); do
  grep -qF "| \`$p\` |" "$structure" || missing="$missing $p"
done
check "report-structure.md lists every placeholder in the template" \
  '[ -z "$missing" ] && grep -qF "{{AUTHOR}}" "$TEMPLATE" && grep -qF "| \`{{AUTHOR}}\` |" "$structure"'

plugin="$HERE/../../.."
undocumented=""
for f in README.md README.ja.md docs/how-it-works.md docs/how-it-works.ja.md; do
  grep -qF "author.txt" "$plugin/$f" || undocumented="$undocumented $f"
done
check "the docs say where the author's name is kept" '[ -z "$undocumented" ]'

# --- author.sh
author() { bash "$SCRIPTS/author.sh" "$@"; }
af="$HOME/.local/share/compare-report/author.txt"

out="$(author)"; rc=$?
check "author.sh prints not saved before the first answer" '[ "$rc" = 0 ] && [ "$out" = "not saved" ]'
printf '[user]\n\tname = Jane Git\n' > "$HOME/.gitconfig"
out="$(author)"
check "author.sh does not fall back to git config user.name" '[ "$out" = "not saved" ] && [ ! -e "$af" ]'
rm -f "$HOME/.gitconfig"

out="$(author --set '  Jane Doe ')"; rc=$?
check "author.sh --set saves the name" '[ "$rc" = 0 ] && [ "$out" = "name: Jane Doe" ] && [ "$(author)" = "name: Jane Doe" ]'
check "the author file is readable only by the user" '[ "$(mode "$af")" = 600 ] && [ "$(mode "$(dirname "$af")")" = 700 ]'

author --set "$(printf 'Jane\nDoe')" >/dev/null 2>"$T/err"; rc=$?
check "author.sh rejects a name with a line break" '[ "$rc" = 2 ] && grep -q "one line" "$T/err" && [ "$(author)" = "name: Jane Doe" ]'
long="$(python3 -c 'print("x" * 101)')"
author --set "$long" >/dev/null 2>"$T/err"; rc=$?
check "author.sh rejects a name over 100 characters" '[ "$rc" = 2 ] && [ "$(author)" = "name: Jane Doe" ]'
wide="$(python3 -c 'print(chr(0x5c71) * 100)')"
out="$(COMPARE_REPORT_HOME="$T/wide" author --set "$wide")"; rc=$?
check "author.sh counts characters, not bytes" '[ "$rc" = 0 ] && [ "$out" = "name: $wide" ]'
author --set Jane extra >/dev/null 2>"$T/err"; rc=$?
check "author.sh with extra arguments exits 2 with the usage" '[ "$rc" = 2 ] && grep -q "^usage: author.sh" "$T/err"'

out="$(COMPARE_REPORT_HOME="$T/elsewhere" author --set 'Jane Doe')"
check "author.sh follows COMPARE_REPORT_HOME" '[ -f "$T/elsewhere/author.txt" ] && [ "$(COMPARE_REPORT_HOME="$T/elsewhere" author)" = "name: Jane Doe" ]'

out="$(author --set '')"; rc=$?
check "author.sh --set with an empty name saves no name" '[ "$rc" = 0 ] && [ "$out" = "no name" ] && [ -f "$af" ] && [ "$(author)" = "no name" ]'
out="$(author --forget)"; rc=$?
check "author.sh --forget removes the saved answer" '[ "$rc" = 0 ] && [ "$out" = "not saved" ] && [ ! -e "$af" ]'
check "author.sh leaves no temporary file" '[ -z "$(find "$HOME/.local/share/compare-report" "$T/elsewhere" -maxdepth 1 -name ".author*")" ]'

# --- to-pdf.sh
cat > "$T/bin/browser" <<'SH'
#!/bin/bash
printf '%s\n' "$@" > "$BROWSER_LOG"
for a in "$@"; do
  case "$a" in
    --print-to-pdf=*) out="${a#--print-to-pdf=}" ;;
    --user-data-dir=*) profile="${a#--user-data-dir=}" ;;
  esac
done
[ -d "${profile:-}" ] && printf '%s\n' "$profile" > "$BROWSER_LOG.profile"
[ "${BROWSER_WRITES:-1}" = 1 ] && printf '%%PDF-1.4\n' > "$out"
exit 0
SH
chmod +x "$T/bin/browser"
export BROWSER_LOG="$T/browser.log"

mkdir -p "$T/my reports"
cp "$T/good.html" "$T/my reports/report.html"
printf 'old\n' > "$T/my reports/report.pdf"
chmod 644 "$T/my reports/report.pdf"
out="$(to_pdf "$T/my reports/report.html")"; rc=$?
check "to-pdf exits 0 and prints the PDF next to the report" '[ "$rc" = 0 ] && [ "$out" = "$T/my reports/report.pdf" ]'
check "the old PDF is replaced by what the browser wrote" '[ "$(head -c 8 "$T/my reports/report.pdf")" = "%PDF-1.4" ]'
check "the PDF is readable only by the user although the caller's umask is 022" '[ "$(mode "$T/my reports/report.pdf")" = 600 ]'
url="$(python3 -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).as_uri())' "$T/my reports/report.html")"
check "the browser opens the report as a file:// URL" 'grep -qxF -- "$url" "$BROWSER_LOG" && case "$url" in file://*%20reports/report.html) true ;; *) false ;; esac'
check "the browser runs headless without extensions or background networking" \
  'grep -qx -- "--headless" "$BROWSER_LOG" && grep -qx -- "--disable-extensions" "$BROWSER_LOG" && grep -qx -- "--disable-background-networking" "$BROWSER_LOG"'
profile="$(cat "$BROWSER_LOG.profile" 2>/dev/null)"
check "the browser gets a profile folder under TMPDIR" 'case "$profile" in "$TMPDIR"/compare-report-browser.*) true ;; *) false ;; esac'
check "the profile is removed afterwards" '[ -n "$profile" ] && [ ! -e "$profile" ] && [ -z "$(ls -A "$TMPDIR")" ]'

out="$(to_pdf "$T/my reports/report.html" "$T/elsewhere.pdf")"; rc=$?
check "a second argument names the PDF" '[ "$rc" = 0 ] && [ "$out" = "$T/elsewhere.pdf" ] && [ "$(mode "$T/elsewhere.pdf")" = 600 ]'

to_pdf >/dev/null 2>"$T/err"; rc=$?
check "to-pdf without a report exits 2" '[ "$rc" = 2 ] && grep -q "^usage: to-pdf.sh" "$T/err"'
to_pdf "$T/missing.html" >/dev/null 2>"$T/err"; rc=$?
check "to-pdf with a missing report exits 2" '[ "$rc" = 2 ]'
COMPARE_REPORT_BROWSER="$T/no-such-browser" to_pdf "$T/good.html" >/dev/null 2>"$T/err"; rc=$?
check "a COMPARE_REPORT_BROWSER that is not a program exits 3" '[ "$rc" = 3 ] && grep -q "No Chromium-based browser was found" "$T/err"'
BROWSER_WRITES=0 to_pdf "$T/good.html" >/dev/null 2>"$T/err"; rc=$?
check "a browser that writes nothing exits 4" '[ "$rc" = 4 ] && grep -q "did not write" "$T/err" && [ ! -e "$T/good.pdf" ]'
check "no profile is left behind after a failure" '[ -z "$(ls -A "$TMPDIR")" ]'

out="$(to_pdf "$T/my reports/report.html" 2>"$T/err")"; rc=$?
check "a PDF without page destinations keeps titles only and says why" \
  '[ "$rc" = 0 ] && [ "$out" = "$T/my reports/report.pdf" ] && [ "$(head -c 8 "$out")" = "%PDF-1.4" ] && [ "$(wc -l < "$T/err" | tr -d " ")" = 1 ] && grep -q "^The PDF contents show titles only" "$T/err"'

plugin="$HERE/../../.."
ja_pages="$(python3 -c 'print("".join(map(chr, (0x30da, 0x30fc, 0x30b8, 0x756a, 0x53f7))))')"
undocumented=""
for f in README.md docs/how-it-works.md; do grep -qF "page number" "$plugin/$f" || undocumented="$undocumented $f"; done
for f in README.ja.md docs/how-it-works.ja.md; do grep -qF "$ja_pages" "$plugin/$f" || undocumented="$undocumented $f"; done
check "the docs describe the page numbers" '[ -z "$undocumented" ]'

# --- to-pdf.sh with a real browser
# long_report <file> [extra contents entry]: the real template filled with nine sections of different lengths
long_report() {
  python3 - "$TEMPLATE" "$1" "${2:-}" <<'PY'
import re, sys
src, dst, extra = sys.argv[1:]
para = "<p>" + "The candidates were measured on the same machine and the same sample site, and every figure below cites its source. " * 6 + "</p>"
sections = [("summary", "Summary", 3), ("candidates", "Candidates", 6), ("axis-speed", "Build speed", 9),
            ("axis-cost", "Cost", 4), ("axis-docs", "Documentation", 12), ("axis-plugins", "Plugins", 2),
            ("risks", "Risks", 5), ("ranking", "Ranking", 7), ("sources", "Sources", 3)]
body = {i: f"<h2>{t}</h2>" + para * n for i, t, n in sections}
toc = "".join(f'<li><a href="#{i}">{t}</a></li>' for i, t, n in sections) + extra
axes = "".join(f'<section id="{i}" class="chapter axis">{body[i]}</section>' for i, t, n in sections if i.startswith("axis-"))
values = {"LANG": "en", "TITLE": "Static site generators", "EYEBROW": "Comparison report", "SUBTITLE": "Four generators",
          "DATE": "2026-11-14", "AUTHOR": "", "STATS": "<div><dt>Candidates</dt><dd>4</dd></div>",
          "CONTENTS_HEADING": "Contents", "TOC": toc, "AXES": axes, "FOOTER": "2026-11-14",
          "SUMMARY": body["summary"], "CANDIDATES": body["candidates"], "RISKS": body["risks"],
          "RANKING": body["ranking"], "SOURCES": body["sources"]}
text = open(src, encoding="utf-8").read()
open(dst, "w", encoding="utf-8").write(re.sub(r"\{\{([A-Z_]+)\}\}", lambda m: values[m.group(1)], text))
PY
}

# pdf_pages <pdf>: compares the PDF contents with the pages of the headings and the numbers at the bottom
pdf_pages() {
  "$pdftotext_cmd" -layout "$1" - | python3 -c '
import re, sys
pages = sys.stdin.read().split("\f")
pages = [p.splitlines() for p in pages if p.strip()]
titles = ["Summary", "Candidates", "Build speed", "Cost", "Documentation", "Plugins", "Risks", "Ranking", "Sources"]
toc, heading = {}, {}
for n, lines in enumerate(pages, 1):
    for line in lines:
        m = re.match(r"\s*\d+\.\s+(.+?)(?:\s+(\d+))?\s*$", line)
        if m and m.group(1) in titles and m.group(1) not in toc:
            toc[m.group(1)] = int(m.group(2)) if m.group(2) else None
        m = re.match(r"\s*\d\d\s+(.+?)\s*$", line)
        if m and m.group(1) in titles and m.group(1) not in heading:
            heading[m.group(1)] = n
for t in titles:
    print(f"contents {t}: {toc.get(t)} heading {heading.get(t)}")
for n, lines in enumerate(pages, 1):
    last = [l.strip() for l in lines if l.strip()][-1]
    print(f"bottom {n}: {last}")
'
}

dump_dom() {
  "$real_browser" --headless --disable-gpu --no-first-run --user-data-dir="$T/dom-profile" --dump-dom "$1" 2>/dev/null
  rm -rf "$T/dom-profile"
}

real_checks=(
  "every contents entry in the PDF shows the page that holds its section heading"
  "every page but the cover shows its number at the bottom"
  "the cover shows no page number"
  "printing leaves report.html unchanged and no copy in its folder"
  "report.html in a browser has no page numbers in its contents"
  "a contents link to a missing section keeps titles only and names the section"
)
if [ -z "$real_browser" ] || [ -z "$pdftotext_cmd" ]; then
  for name in "${real_checks[@]}"; do printf 'skip  %s (needs a Chromium-based browser and pdftotext)\n' "$name"; done
else
  mkdir -p "$T/real"
  long_report "$T/real/report.html"
  cp "$T/real/report.html" "$T/original.html"
  out="$(COMPARE_REPORT_BROWSER="$real_browser" to_pdf "$T/real/report.html" 2>"$T/real-err")"; rc=$?
  pages="$(pdf_pages "$T/real/report.pdf")"
  printf '%s\n' "$pages" > "$T/real-pages"
  # every entry's number equals the page of its heading, and the headings spread over at least five pages
  check "every contents entry in the PDF shows the page that holds its section heading" \
    '[ "$rc" = 0 ] && LC_ALL=C awk "/^contents /{ n++; if (\$NF != \$(NF-2)) bad++; p[\$NF] = 1 } END { for (k in p) d++; exit !(n == 9 && bad == 0 && d >= 5) }" "$T/real-pages"'
  check "every page but the cover shows its number at the bottom" \
    'LC_ALL=C awk "/^bottom / && \$2 != \"1:\" { n++; if (\$2 != \$NF \":\") bad++ } END { exit !(n >= 5 && bad == 0) }" "$T/real-pages"'
  check "the cover shows no page number" '! grep -qE "^bottom 1: [0-9]+$" "$T/real-pages"'
  check "printing leaves report.html unchanged and no copy in its folder" \
    'cmp -s "$T/original.html" "$T/real/report.html" && [ "$(ls -A "$T/real" | tr "\n" " ")" = "report.html report.pdf " ]'
  dom_toc="$(dump_dom "file://$T/real/report.html" | python3 -c 'import re, sys
m = re.search(r"<nav class=\"toc[^\"]*\"[^>]*>(.*?)</nav>", sys.stdin.read(), re.S)
print(re.sub(r"<[^>]+>", " ", m.group(1)) if m else "")')"
  check "report.html in a browser has no page numbers in its contents" \
    'printf "%s" "$dom_toc" | grep -q "Build speed" && ! printf "%s" "$dom_toc" | grep -q "[0-9]"'

  mkdir -p "$T/missing"
  long_report "$T/missing/report.html" '<li><a href="#axis-missing">Missing</a></li>'
  out="$(COMPARE_REPORT_BROWSER="$real_browser" to_pdf "$T/missing/report.html" 2>"$T/missing-err")"; rc=$?
  pdf_pages "$T/missing/report.pdf" > "$T/missing-pages"
  check "a contents link to a missing section keeps titles only and names the section" \
    '[ "$rc" = 0 ] && [ "$out" = "$T/missing/report.pdf" ] && [ "$(wc -l < "$T/missing-err" | tr -d " ")" = 1 ] && grep -q "^The PDF contents show titles only" "$T/missing-err" && grep -qF "#axis-missing" "$T/missing-err" && LC_ALL=C awk "/^contents /{ n++; if (\$(NF-2) != \"None\") bad++ } END { exit !(n == 9 && bad == 0) }" "$T/missing-pages"'
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ]
