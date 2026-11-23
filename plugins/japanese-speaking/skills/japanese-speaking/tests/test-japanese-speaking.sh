#!/usr/bin/env bash
# Tests for the japanese-speaking skill: the speaking.py check command on the fixtures, and the order
# of the steps in SKILL.md. Everything runs on the fixtures next to this file and a throwaway folder.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
SCRIPT="$SKILL_DIR/scripts/speaking.py"
FIX="$HERE/fixtures"
PY="$(command -v python3)"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }
speaking() { PYTHONDONTWRITEBYTECODE=1 "$PY" "$SCRIPT" "$@"; }

# Runs check on a fixture and keeps the output and the exit status in $T.
run() {  # <name> <args>...
  local name="$1"
  shift
  speaking check "$@" >"$T/$name.out" 2>"$T/$name.err"
  printf '%s' "$?" >"$T/$name.status"
}
status_is() { [ "$(cat "$T/$1.status")" = "$2" ]; }
has() { grep -qE "$2" "$T/$1.out"; }
lacks() { ! grep -qE "$2" "$T/$1.out"; }

# --- check: JSON scripts

reports_patterns() {
  run rejected "$FIX/rejected-2026-11-18.json"
  status_is rejected 1 || return 1
  grep -E '^L[0-9]+ ' "$T/rejected.out" | grep -qvE '^L[0-9]+ [a-z-]+ .+$' && return 1
  has rejected '^L6 casual-contraction ' || return 1
  has rejected '^L10 casual-contraction '
}
check "check reports each pattern with its line number in a JSON script" "reports_patterns"

reads_plain_text() {
  run plain "$FIX/plain.txt"
  status_is plain 1 || return 1
  has plain '^L4 clipped-question ' || return 1
  has plain '^L5 particle-ending ' || return 1
  lacks plain '^L[123] '
}
check "check reads a plain text script with and without speaker names" "reads_plain_text"

finds_rejected_patterns() {
  run rejected2 "$FIX/rejected-2026-11-18.json"
  has rejected2 '^L8 quiz-question ' || return 1
  has rejected2 '^L3 particle-ending ' || return 1
  has rejected2 '^L3 clipped-question '
}
check "check finds the three patterns in the rejected 2026-11-18 drafts" "finds_rejected_patterns"

finds_casual_and_written() {
  run casual "$FIX/casual.json"
  status_is casual 1 || return 1
  local n
  for n in 1 2 3; do has casual "^L$n casual-contraction " || return 1; done
  for n in 4 5 6 7; do has casual "^L$n written-style " || return 1; done
  ! has casual "^L8 "
}
check "check finds casual contractions and written-style phrases" "finds_casual_and_written"

finds_sources() {
  run sources "$FIX/sources.json"
  status_is sources 1 || return 1
  has sources '^L1 unhedged-source ' || return 1
  has sources '^L2 vague-source ' || return 1
  has sources '^L3 vague-source ' || return 1
  lacks sources '^L2 unhedged-source ' || return 1
  lacks sources '^L4 '
}
check "check finds unhedged and vague sources" "finds_sources"

# --- check: notes and a clean script

prints_notes() {
  run notes "$FIX/notes.json"
  status_is notes 0 || return 1
  lacks notes '^L[0-9]+ ' || return 1
  has notes '^note repeated-ending L1-L3 ' || return 1
  has notes '^note long-sentence L2 ' || return 1
  run natural_notes "$FIX/natural.json"
  local name
  for name in utterance-length-median utterance-length-cv short-utterance-ratio backchannel-count ne-yo-ratio; do
    has natural_notes "^note $name " || return 1
  done
}
check "check prints script-level notes without failing" "prints_notes"

passes_natural() {
  run natural "$FIX/natural.json"
  status_is natural 0 || return 1
  lacks natural '^L[0-9]+ '
}
check "check passes a natural spoken script" "passes_natural"

# --- check: --source

lists_absent_names() {
  run sourced "$FIX/sourced.json" --source "$FIX/source.md"
  status_is sourced 1 || return 1
  has sourced '^L3 not-in-source CrewAI$' || return 1
  has sourced '^L3 not-in-source 15$' || return 1
  has sourced '^L4 not-in-source ミストラル$' || return 1
  lacks sourced 'not-in-source (LangGraph|ラングチェーン|オワスプ|12|モデル|チーム)$' || return 1
  lacks sourced '^L[12] '
}
check "check lists numbers and names absent from the source" "lists_absent_names"

# --- the word lists read in English

pattern_descriptions() {
  "$PY" - "$SKILL_DIR/references/patterns.tsv" <<'PY'
import re, sys
rows = [line for line in open(sys.argv[1], encoding="utf-8").read().splitlines() if line.strip()]
if not rows or rows[0].split("\t") != ["name", "pattern", "except", "description"]:
    sys.exit(1)
for row in rows[1:]:
    fields = row.split("\t")
    if len(fields) != 4 or not re.match("[A-Z]", fields[3]) or len(re.findall("[A-Za-z]+", fields[3])) < 3:
        sys.exit(1)
sys.exit(0 if len(rows) > 1 else 1)
PY
}
check "the pattern list gives every row an English description" "pattern_descriptions"

katakana_glosses() {
  "$PY" - "$SKILL_DIR/references/common-katakana.txt" <<'PY'
import re, sys
rows = [line for line in open(sys.argv[1], encoding="utf-8").read().splitlines() if line.strip() and not line.startswith("#")]
japanese = re.compile("[぀-ヿ㐀-鿿]")
for row in rows:
    fields = row.split("\t")
    if len(fields) != 2 or not japanese.search(fields[0]) or not re.search("[A-Za-z]", fields[1]) or japanese.search(fields[1]):
        sys.exit(1)
sys.exit(0 if rows else 1)
PY
}
check "the katakana list gives every word an English gloss" "katakana_glosses"

# A copy of the skill whose katakana list ends with a word and no gloss refuses the check with exit 2,
# prints no line of the script, and names the list and the line in one error line.
refuses_bare_katakana() {
  local copy="$T/bare" line
  cp -R "$SKILL_DIR" "$copy"
  printf 'ズレ\n' >> "$copy/references/common-katakana.txt"
  line="$(wc -l < "$copy/references/common-katakana.txt" | tr -d ' ')"
  PYTHONDONTWRITEBYTECODE=1 "$PY" "$copy/scripts/speaking.py" check "$FIX/sourced.json" --source "$FIX/source.md" >"$T/bare.out" 2>"$T/bare.err"
  [ "$?" = 2 ] && [ ! -s "$T/bare.out" ] || return 1
  [ "$(wc -l <"$T/bare.err" | tr -d ' ')" = 1 ] && grep -qE "^error: .*common-katakana\.txt.* line $line( |$|[^0-9])" "$T/bare.err"
}
check "check refuses a katakana line without a gloss" "refuses_bare_katakana"

# --- the English versions of the references

# Prints each reference under references/ whose English version <name>.en.md is missing, or differs in
# the number of headings at a level or in the number of table rows. Lines inside fenced code blocks are
# examples and are not counted. Prints "no references" when there is no reference.
shape_mismatches() {  # <skill folder>
  "$PY" - "$1" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])

def shape(path):
    headings, rows, fence = {}, 0, None
    for line in path.read_text(encoding="utf-8").splitlines():
        mark = re.match(r"^ {0,3}(`{3,}|~{3,})", line)
        if mark:
            run = mark.group(1)
            if fence is None:
                fence = run
            elif run[0] == fence[0] and len(run) >= len(fence) and not line.strip()[len(run):].strip():
                fence = None
            continue
        if fence:
            continue
        heading = re.match(r"^(#{1,6}) ", line)
        if heading:
            level = len(heading.group(1))
            headings[level] = headings.get(level, 0) + 1
        elif line.lstrip().startswith("|"):
            rows += 1
    return headings, rows

refs = sorted(p for p in (root / "references").rglob("*.md") if not p.name.endswith(".en.md"))
if not refs:
    print("no references")
for ref in refs:
    english = ref.with_name(ref.name[:-3] + ".en.md")
    if not english.is_file() or shape(english) != shape(ref):
        print(ref.relative_to(root))
PY
}
check "every reference has an English version with the same headings and table rows" '[ -z "$(shape_mismatches "$SKILL_DIR")" ]'

# Drops the first heading outside a code block from the given file.
drop_heading() {  # <file>
  "$PY" - "$1" <<'PY'
import re, sys
path = sys.argv[1]
lines = open(path, encoding="utf-8").read().split("\n")
inside = False
for i, line in enumerate(lines):
    if re.match(r"^ {0,3}(`{3,}|~{3,})", line):
        inside = not inside
    elif not inside and re.match(r"^#{1,6} ", line):
        del lines[i]
        open(path, "w", encoding="utf-8").write("\n".join(lines))
        sys.exit(0)
sys.exit(1)
PY
}

# The references hold no table, so the table case adds one to the Japanese guide and leaves the English
# guide with fewer table rows; the other cases remove the English guide or one of its headings.
shorter_english_fails() {
  local broken copy
  [ -f "$SKILL_DIR/references/speaking.en.md" ] || return 1
  for broken in missing heading row; do
    copy="$T/shape-$broken"
    cp -R "$SKILL_DIR" "$copy"
    case "$broken" in
      missing) rm "$copy/references/speaking.en.md" ;;
      heading) drop_heading "$copy/references/speaking.en.md" || return 1 ;;
      row) printf '\n| a | b |\n|---|---|\n| 1 | 2 |\n' >> "$copy/references/speaking.md" ;;
    esac
    [ "$(shape_mismatches "$copy")" = "references/speaking.md" ] || return 1
  done
}
check "a missing or shorter English version fails the check" "shorter_english_fails"

# --- check: input it cannot read

rejects_bad_input() {
  local name
  for name in missing broken no-lines no-text; do
    case "$name" in
      missing) run "$name" "$T/missing.json" ;;
      broken) run "$name" "$FIX/broken.txt" ;;
      *) run "$name" "$FIX/$name.json" ;;
    esac
    status_is "$name" 2 || return 1
    [ ! -s "$T/$name.out" ] || return 1
    [ "$(wc -l <"$T/$name.err" | tr -d ' ')" = 1 ] || return 1
    grep -qE '^error: .+' "$T/$name.err" || return 1
  done
}
check "check rejects unreadable input with exit 2" "rejects_bad_input"

# --- SKILL.md

skill_order() {
  [ -f "$SKILL_DIR/SKILL.md" ] || return 1
  "$PY" - "$SKILL_DIR/SKILL.md" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
order = ["## 3. Write", "## 4. Check with the script", "## 5. Have a fresh reader listen", "## 6. Fix and check again"]
at = [text.find(h) for h in order]
if -1 in at or at != sorted(at):
    sys.exit(1)
if "Add no fact, number, or name that the material does not have" not in text:
    sys.exit(1)
if "speaking.py\" check" not in text and "speaking.py check" not in text:
    sys.exit(1)
PY
}
check "SKILL.md orders write, check, fresh review, and fix and forbids new facts" "skill_order"

# The skill reads the Japanese references; the English versions are for people who read English.
skill_language() {
  local s="$SKILL_DIR/SKILL.md"
  grep -qF '.en.md' "$s" && grep -qiE 'reads? the Japanese references' "$s" && grep -qiE 'for people who read English' "$s" \
    && grep -qiE 'explains? (its|the) changes in the language the user writes in' "$s" && grep -qiE 'script stays Japanese' "$s"
}
check "the SKILL.md explains changes in the user's language and keeps the script Japanese" "skill_language"

# --- the pages and the changelog

PLUGIN_DIR="$(cd "$SKILL_DIR/../.." && pwd)"

pages_english() {
  local page
  for page in README.md docs/how-it-works.md; do
    grep -qF '.en.md' "$PLUGIN_DIR/$page" && grep -qiE 'in English' "$PLUGIN_DIR/$page" || return 1
  done
  for page in README.ja.md docs/how-it-works.ja.md; do
    grep -qF '.en.md' "$PLUGIN_DIR/$page" && grep -qF '英語' "$PLUGIN_DIR/$page" || return 1
  done
}
check "the pages say the references read in English" "pages_english"

# changelog_entries <changelog>: the entry lines under ## [Unreleased] and every release. A release moves
# a line from ## [Unreleased] into its version's section, where it stays through later releases, so
# either place counts. Link definitions and the header are not entry lines.
changelog_entries() { awk '/^## \[/ { on = 1 } on' "$1" | grep '^- '; }

# The helper counts a line under an older release, and not a changelog whose sections lack the text.
changelog_counts_any_release() {
  printf '# Changelog\n\n## [Unreleased]\n\n## [0.3.0] - 2026-11-30\n\n- a later change\n\n## [0.2.0] - 2026-11-23\n\n- the round-table format\n' > "$T/changelog-older"
  printf '# Changelog\n\n## [Unreleased]\n\n## [0.2.0] - 2026-11-23\n\n- another change\n\n[round-table]: https://example.com\n' > "$T/changelog-none"
  changelog_entries "$T/changelog-older" | grep -qi 'round-table' && ! changelog_entries "$T/changelog-none" | grep -qi 'round-table'
}

changelog_english() {
  changelog_counts_any_release && changelog_entries "$PLUGIN_DIR/CHANGELOG.md" | grep -F '.en.md' | grep -qi 'English'
}
check "the changelog names the English references under Unreleased or any release" "changelog_english"

changelog_round_table() {
  changelog_counts_any_release && changelog_entries "$PLUGIN_DIR/CHANGELOG.md" | grep -qi 'round-table'
}
check "the changelog names the round-table under Unreleased or any release" "changelog_round_table"

# --- the round-table for three or more speakers

FORMATS="$SKILL_DIR/references/formats.md"

# formats.md holds six formats, and the round-table section says who leads, how turns pass, and how it closes.
formats_round_table() {
  "$PY" - "$FORMATS" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
sections = re.split(r"^## ", text, flags=re.M)[1:]
if len(sections) != 6:
    sys.exit(1)
table = next((s for s in sections if "座談" in s.split("\n", 1)[0]), None)
if table is None or not re.search(r"^1\. ", table, re.M) or not re.search(r"^4\. ", table, re.M):
    sys.exit(1)
sys.exit(0 if all(word in table for word in ("3人以上", "司会", "名指", "全員", "締め")) else 1)
PY
}
check "formats.md lays out a host-led round-table for three or more speakers" "formats_round_table"

rules_name_speakers() {
  local speaking="$SKILL_DIR/references/speaking.md" review="$SKILL_DIR/references/review.md"
  grep -F '意見を全部そろえない' "$speaking" | grep -qF '話し手' || return 1
  ! grep -F '意見を全部そろえない' "$speaking" | grep -qE '2人|もう1人' || return 1
  grep -F '専門家役' "$review" | grep -qF '話し手' && grep -F '意見が全部そろ' "$review" | grep -qF '話し手' || return 1
  ! grep -qE '2人|もう1人' "$review"
}
check "the rules on differing views and quizzing name speakers, not two people" "rules_name_speakers"

reader_silent() {
  grep -F '3人以上' "$SKILL_DIR/references/review.md" | grep -qF '一度も話さない話し手'
}
check "the fresh reader looks for a speaker silent through a beat" "reader_silent"

# A round-table prints one note per named speaker, in the order they first speak, and keeps exit 0;
# a narration with no speaker names prints none.
speaker_counts() {
  run round "$FIX/round-table.json"
  status_is round 0 || return 1
  [ "$(grep '^note speaker-utterances ' "$T/round.out")" = "$(printf 'note speaker-utterances ハル 4\nnote speaker-utterances ルミ 2\nnote speaker-utterances ボルト 2\nnote speaker-utterances ソラ 1')" ] || return 1
  printf '昔の電話は、数字の穴に指を入れて回す形でした。\n今はボタンを押すだけです。\n' > "$T/narration.txt"
  run narration "$T/narration.txt"
  status_is narration 0 && ! grep -q '^note speaker-utterances ' "$T/narration.out"
}
check "check prints how many utterances each speaker has" "speaker_counts"

skill_round_table() {
  "$PY" - "$SKILL_DIR/SKILL.md" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r"^## 1\. .*?(?=^## 2\. )", text, re.S | re.M)
sys.exit(0 if m and re.search(r"number of speakers", m.group(0)) and re.search(r"round-table", m.group(0)) else 1)
PY
}
check "SKILL.md asks for the number of speakers and names the round-table" "skill_round_table"

pages_six() {
  grep -qE '^\| Round-table \|' "$PLUGIN_DIR/README.md" && grep -qE '^\| 座談 \|' "$PLUGIN_DIR/README.ja.md" \
    && grep -qF 'six formats' "$PLUGIN_DIR/docs/how-it-works.md" && grep -qF '6つの形式' "$PLUGIN_DIR/docs/how-it-works.ja.md" \
    && ! grep -qiE 'five formats' "$PLUGIN_DIR/README.md" "$PLUGIN_DIR/docs/how-it-works.md" \
    && ! grep -qF '5つの形式' "$PLUGIN_DIR/README.ja.md" "$PLUGIN_DIR/docs/how-it-works.ja.md"
}
check "the pages list six formats including the round-table" "pages_six"

printf '\n%d passed, %d failed, 0 skipped (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" = 0 ]
