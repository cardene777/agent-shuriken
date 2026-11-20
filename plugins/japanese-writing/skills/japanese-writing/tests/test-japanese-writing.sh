#!/usr/bin/env bash
# Tests for the japanese-writing skill: the files copied from coji/natural-japanese, the files written
# for this plugin, and two of the scripts. The scripts run on made-up text inside a copy of the skill
# folder in a throwaway directory, so nothing is written into the plugin. uv keeps the packages it
# downloads (sudachipy and its dictionary) in its usual cache. Checks that need uv are reported as
# "skip" when uv is missing.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
PLUGIN_DIR="$(cd "$SKILL_DIR/../.." && pwd)"
PASS=0
FAIL=0
SKIP=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
sk() { SKIP=$((SKIP + 1)); printf 'skip  %s (%s)\n' "$1" "$2"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }

COMMIT=1fb57128a2f0d160e61320154226fdc86343ee2a
# Files every copy of the skill has besides the upstream copies and the files listed in references/rules.md.
FRAME="SKILL.md agents/openai.yaml upstream-manifest.txt references/rules.md tests/test-japanese-writing.sh"

# --- the upstream copies and the manifest

upstream_files() {  # <skill folder>: the paths the manifest fingerprints
  grep -E '^[0-9a-f]{64}  ' "$1/upstream-manifest.txt" 2>/dev/null | cut -c67-
}

# Prints each fingerprinted path whose file is missing or differs, "no manifest" when there is none,
# and "no fingerprints" when it lists no file. Prints nothing when every upstream copy matches.
fingerprint_mismatches() {  # <skill folder>
  local dir="$1" sum p n=0
  [ -f "$dir/upstream-manifest.txt" ] || { echo "no manifest"; return; }
  while read -r sum p; do
    n=$((n + 1))
    if [ ! -f "$dir/$p" ] || [ "$(shasum -a 256 "$dir/$p" | cut -c1-64)" != "$sum" ]; then echo "$p"; fi
  done < <(grep -E '^[0-9a-f]{64}  ' "$dir/upstream-manifest.txt")
  [ "$n" -gt 0 ] || echo "no fingerprints"
}
check "the upstream files match their fingerprints" '[ -z "$(fingerprint_mismatches "$SKILL_DIR")" ]'

changed_copy_fails() {
  local copy="$T/changed" first
  cp -R "$SKILL_DIR" "$copy"
  first="$(upstream_files "$copy" | grep '^references/' | head -1)"
  [ -n "$first" ] || return 1
  printf ' ' >> "$copy/$first"
  [ "$(fingerprint_mismatches "$copy")" = "$first" ]
}
check "a changed upstream file fails the fingerprint check" "changed_copy_fails"

manifest_scope() {
  local m="$SKILL_DIR/upstream-manifest.txt"
  [ -f "$m" ] && grep -q "^# Source: coji/natural-japanese $COMMIT " "$m" || return 1
  [ -n "$(upstream_files "$SKILL_DIR")" ] || return 1
  ! upstream_files "$SKILL_DIR" | grep -qE '^scripts/(semantic|calibrate)\.py$' || return 1
  [ ! -e "$SKILL_DIR/scripts/semantic.py" ] && [ ! -e "$SKILL_DIR/scripts/calibrate.py" ]
}
check "the manifest names the upstream commit and leaves out the dropped scripts" "manifest_scope"

# --- the files written for this plugin

own_listed() {  # <skill folder>: the paths in the first column of the tables in references/rules.md
  sed -n 's/^| `\([^`]*[./][^`]*\)` |.*/\1/p' "$1/references/rules.md" 2>/dev/null
}

unlisted_files() {  # <skill folder>: files that are neither upstream copies, listed own files, nor the frame
  local dir="$1" f
  (cd "$dir" && find . -type f ! -name .DS_Store | sed 's|^\./||' | LC_ALL=C sort) | while IFS= read -r f; do
    upstream_files "$dir" | grep -qxF "$f" && continue
    own_listed "$dir" | grep -qxF "$f" && continue
    printf '%s\n' $FRAME | grep -qxF "$f" && continue
    printf '%s\n' "$f"
  done
}

every_file_listed() {
  local copy="$T/stray"
  [ -f "$SKILL_DIR/references/rules.md" ] && [ -n "$(own_listed "$SKILL_DIR")" ] || return 1
  [ -z "$(unlisted_files "$SKILL_DIR")" ] || return 1
  cp -R "$SKILL_DIR" "$copy"
  printf 'x\n' > "$copy/references/stray.md"
  [ "$(unlisted_files "$copy")" = "references/stray.md" ]
}
check "every file is an upstream copy or a listed own file" "every_file_listed"

# The name of the private workflow these files came from, split so that this file does not hold it.
W1=ik
W2=kan
no_workflow_name() {
  local f
  [ -n "$(own_listed "$SKILL_DIR")" ] || return 1
  for f in $(own_listed "$SKILL_DIR"); do [ -f "$SKILL_DIR/$f" ] || return 1; done
  ! grep -rqi "$W1$W2" "$PLUGIN_DIR"
}
check "no file names the private workflow" "no_workflow_name"

license_in_notices() {  # the whole upstream LICENSE appears in the notices, whitespace aside
  python3 - "$SKILL_DIR/LICENSE" "$PLUGIN_DIR/THIRD_PARTY_NOTICES.md" <<'PY'
import sys
words = lambda path: " ".join(open(path, encoding="utf-8").read().split())
sys.exit(0 if words(sys.argv[1]) in words(sys.argv[2]) else 1)
PY
}
notices_complete() {
  local n="$PLUGIN_DIR/THIRD_PARTY_NOTICES.md"
  [ -f "$n" ] && grep -qF 'coji/natural-japanese' "$n" && grep -qF "$COMMIT" "$n" \
    && grep -qE '(^|[^0-9])20[0-9]{2}-[0-9]{2}-[0-9]{2}([^0-9]|$)' "$n" && grep -qF 'MIT' "$n" && license_in_notices
}
check "the notices name the source, commit, date, and MIT license" "notices_complete"

# The guide to connecting sentences is adapted from two documents of Japan's Agency for Cultural Affairs.
# Their terms (the Public Data License 1.0, compatible with CC BY 4.0) ask for the title, the agency, the
# address, and a note that the text was edited.
CONNECTING="$SKILL_DIR/references/connecting.md"
KOYOBUN='公用文作成の考え方'
WAKARIAU='分かり合うための言語コミュニケーション'

connecting_sources() {
  [ -f "$CONNECTING" ] || return 1
  local head
  head="$(head -12 "$CONNECTING")"
  printf '%s' "$head" | grep -qF "$KOYOBUN" && printf '%s' "$head" | grep -qF "$WAKARIAU" \
    && printf '%s' "$head" | grep -qF '文化庁' && printf '%s' "$head" | grep -qF '加工して作成'
}
check "the guide to connecting sentences names its two sources and says it was edited" "connecting_sources"

connecting_body() {
  [ -f "$CONNECTING" ] || return 1
  local word
  for word in 理由 逆接 補足 順序 そのため しかし なお まず 接続助詞 中止法 結論 直す前 直した後; do
    grep -qF "$word" "$CONNECTING" || return 1
  done
}
check "the guide to connecting sentences lists connectives by relation and shows a rewrite" "connecting_body"

connecting_notices() {
  local n="$PLUGIN_DIR/THIRD_PARTY_NOTICES.md" want
  [ -f "$n" ] || return 1
  for want in "$KOYOBUN" "$WAKARIAU" '`skills/japanese-writing/references/connecting.md`' '公共データ利用規約' '加工' \
    'https://www.bunka.go.jp/seisaku/bunkashingikai/kokugo/hokoku/pdf/93731901_01.pdf' \
    'https://www.bunka.go.jp/koho_hodo_oshirase/hodohappyo/__icsFiles/afieldfile/2018/04/09/a1401904_03.pdf'; do
    grep -qF -- "$want" "$n" || return 1
  done
}
check "the notices name the Agency for Cultural Affairs documents, their terms, and the edit" "connecting_notices"

# --- the scripts, run the way SKILL.md says

run_line() {  # the first line of SKILL.md that runs a script with uv
  grep -m1 -E 'uv run .*<skill folder>/scripts/<script>\.py <file>' "$SKILL_DIR/SKILL.md" 2>/dev/null | sed 's/^[[:space:]]*//'
}
run_script() {  # <skill folder> <script> <file>: the line from SKILL.md with its placeholders filled in
  local line
  line="$(run_line)"
  [ -n "$line" ] || return 99
  line="${line//<skill folder>/$1}"
  line="${line//<script>/$2}"
  line="${line//<file>/$3}"
  (cd "$T" && bash -c "$line")
}

RUN="$T/run"
cp -R "$SKILL_DIR" "$RUN"
find "$RUN" -name __pycache__ -prune -exec rm -rf {} +
cat > "$T/metaphor.md" <<'MD'
# 設定の説明

この節は設定の読み方を書く。
起動の時に設定を読む。
`config.json` は二つの置き場の隣に立ち、値を拾う。
MD

if ! command -v uv >/dev/null 2>&1; then
  sk "lint finds suspects in the AI-smelly sample" "uv is not installed"
  sk "suspects points at the line with a metaphor verb" "uv is not installed"
  sk "running the scripts leaves no bytecode in the skill folder" "uv is not installed"
else
  lint_out="$(run_script "$RUN" lint "$RUN/scripts/fixtures/ai-smelly.md" 2>"$T/lint.err")"
  lint_status=$?
  found="$(printf '%s\n' "$lint_out" | sed -n 's/^検出件数: \([0-9][0-9]*\)$/\1/p')"
  check "lint finds suspects in the AI-smelly sample" '[ "$lint_status" = 0 ] && [ -n "$found" ] && [ "$found" -ge 1 ]'

  suspects_out="$(run_script "$RUN" suspects "$T/metaphor.md" 2>"$T/suspects.err")"
  suspects_status=$?
  check "suspects points at the line with a metaphor verb" \
    '[ "$suspects_status" = 0 ] && printf "%s\n" "$suspects_out" | grep -q "^L5 \[比喩の動詞\] "'

  check "running the scripts leaves no bytecode in the skill folder" \
    '[ "$lint_status" = 0 ] && [ "$suspects_status" = 0 ] && [ -z "$(find "$RUN" -name __pycache__)" ]'
fi

# --- what SKILL.md, the rules, and the pages say

skill_points() {
  [ -f "$SKILL_DIR/SKILL.md" ] || return 1
  python3 - "$SKILL_DIR/SKILL.md" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
if re.search("[぀-ヿ㐀-鿿]", text):
    sys.exit(1)
body = text.split("---", 2)[2] if text.startswith("---") else text
for name in ("references/rules.md", "UPSTREAM-SKILL.md", "references/manual-checklist.md", "semantic.py"):
    if name not in body:
        sys.exit(1)
if not re.search(r"semantic\.py[^\n]*\bnot\b|\bnot\b[^\n]*semantic\.py", body):
    sys.exit(1)
sys.exit(0 if body.index("references/rules.md") < body.index("UPSTREAM-SKILL.md") else 1)
PY
}
check "the SKILL.md points to the rules, the upstream body, and the manual checklist" "skill_points"

rules_scope() {
  [ -f "$SKILL_DIR/references/rules.md" ] || return 1
  python3 - "$SKILL_DIR/references/rules.md" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
first = [line for line in text.splitlines() if re.match(r"^\| *1 *\|", line)]
if not first or "repo" not in first[0] or "利用者" not in first[0]:
    sys.exit(1)
parts = re.split(r"^## ", text, flags=re.M)
form = next((p for p in parts if p.startswith("2.")), "")
need = ("README", "Issue", "PR", "note", "ブログ", "エッセイ", "references/doctypes/")
sys.exit(0 if all(word in form for word in need) else 1)
PY
}
check "the rules put the repository first and apply the format to repository Markdown" "rules_scope"

missing_names() {  # <skill folder> <file>...: the skill files these files name that do not exist
  python3 - "$@" <<'PY'
import os, re, sys
root, files = sys.argv[1], sys.argv[2:]
name = re.compile(r"(?<![\w/.-])((?:references|scripts|assets)/[A-Za-z0-9_./-]*[A-Za-z0-9_-]\.(?:md|py|tsv|txt)"
                  r"|(?:UPSTREAM-)?SKILL\.md|IMPORTED\.md|upstream-manifest\.txt)")
missing = set()
for path in files:
    for m in name.finditer(open(path, encoding="utf-8").read()):
        if not os.path.exists(os.path.join(root, m.group(1))):
            missing.add(m.group(1))
print("\n".join(sorted(missing)))
PY
}

own_names_exist() {
  local files=() f
  for f in $(own_listed "$SKILL_DIR" | grep -E '\.(md|py)$'); do files+=("$SKILL_DIR/$f"); done
  [ "${#files[@]}" -gt 0 ] || return 1
  for f in "${files[@]}"; do [ -f "$f" ] || return 1; done
  [ -z "$(missing_names "$SKILL_DIR" "$SKILL_DIR/references/rules.md" "${files[@]}")" ]
}
check "every file the own references name exists" "own_names_exist"

# The upstream body and references only: the sample texts under scripts/fixtures/ name scripts/calibrate.py,
# which tunes thresholds against a corpus this plugin leaves out, and are read by no step.
upstream_names_exist() {
  local files=() f
  for f in $(upstream_files "$SKILL_DIR" | grep -E '^(UPSTREAM-SKILL\.md|references/.*\.md)$'); do files+=("$SKILL_DIR/$f"); done
  [ "${#files[@]}" -gt 0 ] || return 1
  [ -z "$(missing_names "$SKILL_DIR" "${files[@]}" | grep -vxF 'scripts/semantic.py')" ]
}
check "every file the upstream body names exists except semantic.py" "upstream_names_exist"

pages_say() {
  local f
  for f in README.md docs/how-it-works.md README.ja.md docs/how-it-works.ja.md; do
    [ -f "$PLUGIN_DIR/$f" ] || return 1
    grep -qF 'sudachipy' "$PLUGIN_DIR/$f" && grep -qF 'sudachidict-core' "$PLUGIN_DIR/$f" \
      && grep -qF 'semantic.py' "$PLUGIN_DIR/$f" || return 1
  done
  grep -qiE 'never sends|is not sent|sends no' "$PLUGIN_DIR/README.md" \
    && grep -qiE 'never sends|is not sent|sends no' "$PLUGIN_DIR/docs/how-it-works.md" \
    && grep -qF '送らない' "$PLUGIN_DIR/README.ja.md" && grep -qF '送らない' "$PLUGIN_DIR/docs/how-it-works.ja.md"
}
check "the README and how-it-works say what uv downloads and that no text is sent" "pages_say"

# Other skills, such as convey, follow the connecting guide through musubi (#260).
provides_connecting() {
  [ -f "$SKILL_DIR/musubi.json" ] || return 1
  python3 - "$SKILL_DIR/musubi.json" <<'PY'
import json, sys
declaration = json.load(open(sys.argv[1], encoding="utf-8"))
want = {"connecting": {"version": "1.0.0", "file": "references/connecting.md"}}
sys.exit(0 if declaration.get("musubi") == "2026-11-19" and declaration.get("provides") == want and "follows" not in declaration else 1)
PY
}
check "japanese-writing provides connecting in musubi.json" "provides_connecting"

names_connecting() {
  grep -E '`connecting`' "$SKILL_DIR/SKILL.md" | grep -qF '`references/connecting.md`'
}
check "the SKILL.md names the file of connecting" "names_connecting"

pages_musubi() {
  local page
  for page in README.md README.ja.md docs/how-it-works.md docs/how-it-works.ja.md; do
    grep -qF 'musubi.json' "$PLUGIN_DIR/$page" && grep -qF '`connecting`' "$PLUGIN_DIR/$page" || return 1
  done
}
check "the pages describe musubi.json and connecting" "pages_musubi"

printf '\n%d passed, %d failed, %d skipped (%d ran)\n' "$PASS" "$FAIL" "$SKIP" "$((PASS + FAIL))"
[ "$FAIL" = 0 ]
