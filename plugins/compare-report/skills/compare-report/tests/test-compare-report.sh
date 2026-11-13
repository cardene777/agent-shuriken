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
check_report >/dev/null 2>&1; rc=$?
check "check-report.py without a file exits 2" '[ "$rc" = 2 ]'

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

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ]
