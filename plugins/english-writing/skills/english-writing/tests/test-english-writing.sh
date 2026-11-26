#!/usr/bin/env bash
# Tests for the english-writing skill: the files copied from blader/humanizer, the files written for
# this plugin, and the script that points at suspect lines. The script runs on made-up text inside a
# copy of the skill folder in a throwaway directory, so nothing is written into the plugin. No check
# runs proselint, so the tests need only Bash and Python 3 and download nothing.
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
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }

UPSTREAM=blader/humanizer
COMMIT=a32f24407364c74c812b43c15926d638bee1e072
# Files every copy of the skill has besides the upstream copies and the files listed in references/rules.md.
FRAME="SKILL.md agents/openai.yaml upstream-manifest.txt references/rules.md tests/test-english-writing.sh"

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
  first="$(upstream_files "$copy" | head -1)"
  [ -n "$first" ] && [ -f "$copy/$first" ] || return 1
  printf ' ' >> "$copy/$first"
  [ "$(fingerprint_mismatches "$copy")" = "$first" ]
}
check "a changed upstream file fails the fingerprint check" "changed_copy_fails"

manifest_names_commit() {
  local m="$SKILL_DIR/upstream-manifest.txt"
  [ -f "$m" ] && grep -qE "^# Source: $UPSTREAM $COMMIT( |$)" "$m" || return 1
  upstream_files "$SKILL_DIR" | grep -qxF UPSTREAM-SKILL.md
}
check "the manifest names the upstream commit" "manifest_names_commit"

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

license_in_notices() {  # the whole upstream LICENSE appears in the notices, whitespace aside
  python3 - "$SKILL_DIR/LICENSE" "$PLUGIN_DIR/THIRD_PARTY_NOTICES.md" <<'PY'
import sys
words = lambda path: " ".join(open(path, encoding="utf-8").read().split())
try:
    sys.exit(0 if words(sys.argv[1]) in words(sys.argv[2]) else 1)
except OSError:
    sys.exit(1)
PY
}

# Every quoted style guide is credited the way its license asks: Google's guide under CC BY 4.0 with a
# link to the guide and the license, the plain language guidelines as a public domain work dedicated
# under CC0, and the GOV.UK guidance with the attribution statement of the Open Government Licence.
notices_complete() {
  local n="$PLUGIN_DIR/THIRD_PARTY_NOTICES.md" want
  [ -f "$n" ] || return 1
  for want in "$UPSTREAM" "$COMMIT" 'MIT' \
    'Google developer documentation style guide' 'CC BY 4.0' 'https://developers.google.com/style' \
    'https://creativecommons.org/licenses/by/4.0/' \
    'plainlanguage.gov' 'public domain' 'CC0' 'https://digital.gov/guides/plain-language' \
    'GOV.UK' 'Contains public sector information licensed under the Open Government Licence v3.0.' \
    'https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/' \
    '`skills/english-writing/references/rules.md`'; do
    grep -qF -- "$want" "$n" || return 1
  done
  grep -qE '(^|[^0-9])20[0-9]{2}-[0-9]{2}-[0-9]{2}([^0-9]|$)' "$n" && license_in_notices
}
check "the notices name every source, commit, date, and license" "notices_complete"

skill_body() {  # SKILL.md without its frontmatter, or nothing when it is missing or holds Japanese
  python3 - "$SKILL_DIR/SKILL.md" <<'PY'
import re, sys
try:
    text = open(sys.argv[1], encoding="utf-8").read()
except OSError:
    sys.exit(1)
if re.search("[\u3040-\u30ff\u3400-\u9fff]", text):
    sys.exit(1)
print(text.split("---", 2)[2] if text.startswith("---") else text)
PY
}

# The body names references/rules.md before UPSTREAM-SKILL.md, and a sentence about disagreement
# names references/rules.md as the one to follow.
rules_first() {
  skill_body > "$T/skill-body.md" || return 1
  python3 - "$T/skill-body.md" <<'PY'
import re, sys
body = open(sys.argv[1], encoding="utf-8").read()
rules, upstream = body.find("references/rules.md"), body.find("UPSTREAM-SKILL.md")
if not 0 <= rules < upstream:
    sys.exit(1)
sentences = re.split(r"(?<=[.!?])\s+", body)
sys.exit(0 if any("disagree" in s.lower() and "references/rules.md" in s for s in sentences) else 1)
PY
}
check "SKILL.md reads the own rules before the upstream body" "rules_first"

keeps_facts_language_data() {
  local body
  body="$(skill_body)" || return 1
  printf '%s\n' "$body" | grep -qiE 'never add (a )?facts?[^.]*the original does not hold' \
    && printf '%s\n' "$body" | grep -qiE 'in the language the user writes in' \
    && printf '%s\n' "$body" | grep -qiE 'fixed text stays English' \
    && printf '%s\n' "$body" | grep -qiE 'material[^.]*never (as )?instructions'
}
check "SKILL.md keeps facts, the user's language, and text as data" "keeps_facts_language_data"

# --- the script, run the way SKILL.md says

run_line() {  # the first line of SKILL.md that runs suspects.py
  grep -m1 -E 'python3 .*<skill folder>/scripts/suspects\.py <file>' "$SKILL_DIR/SKILL.md" 2>/dev/null | sed 's/^[[:space:]]*//'
}
run_suspects() {  # <skill folder> <file>: the line from SKILL.md with its placeholders filled in
  local line
  line="$(run_line)"
  [ -n "$line" ] || return 99
  line="${line//<skill folder>/$1}"
  line="${line//<file>/$2}"
  (cd "$T" && bash -c "$line")
}

RUN="$T/run"
cp -R "$SKILL_DIR" "$RUN"
find "$RUN" -name __pycache__ -prune -exec rm -rf {} +
BEFORE="$(cd "$RUN" && find . | LC_ALL=C sort)"

# The limit of words in one sentence that references/rules.md sets.
LIMIT="$(sed -nE 's/.*[^0-9]([0-9]+) words or fewer.*/\1/p' "$SKILL_DIR/references/rules.md" 2>/dev/null | head -1)"
words() { local i out=""; for ((i = 0; i < $1; i++)); do out="$out item"; done; printf '%s' "${out# }"; }

long_sentence() {
  [ -n "$LIMIT" ] && [ "$LIMIT" -gt 2 ] || return 1
  local half=$(((LIMIT + 1) / 2)) out status
  {
    printf '# Notes\n\n'
    printf 'The %s.\n\n' "$(words "$LIMIT")"                 # line 3: one word over the limit
    printf 'The %s.\n\n' "$(words $((LIMIT - 1)))"           # line 5: at the limit
    printf 'The %s\n' "$(words "$half")"                     # line 7: over the limit, across two lines
    printf '%s.\n' "$(words $((LIMIT - half)))"
  } > "$T/long.md"
  out="$(run_suspects "$RUN" "$T/long.md" 2>/dev/null)"
  status=$?
  [ "$status" = 0 ] && printf '%s\n' "$out" | grep -q '^L3 \[long sentence\]' \
    && printf '%s\n' "$out" | grep -q '^L7 \[long sentence\]' && ! printf '%s\n' "$out" | grep -q '^L5 '
}
check "suspects points at a long sentence" "long_sentence"

passive_voice() {
  local out status
  cat > "$T/passive.md" <<'MD'
# Passive

The file is deleted by the script.

The notes were written last week.

The cache is automatically created on the first run.

We delete the file.
MD
  out="$(run_suspects "$RUN" "$T/passive.md" 2>/dev/null)"
  status=$?
  [ "$status" = 0 ] && printf '%s\n' "$out" | grep -q '^L3 \[passive voice\]' \
    && printf '%s\n' "$out" | grep -q '^L5 \[passive voice\]' && printf '%s\n' "$out" | grep -q '^L7 \[passive voice\]' \
    && ! printf '%s\n' "$out" | grep -q '^L9 '
}
check "suspects points at passive voice" "passive_voice"

# Writes the example of every row of references/translationese.tsv on its own line, one paragraph each,
# and prints the line numbers. Fails when the list lacks its header, a row, or one of the forms decided
# for the plugin.
translationese_sample() {  # <out file>
  python3 - "$SKILL_DIR/references/translationese.tsv" "$1" <<'PY'
import sys
try:
    lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
except OSError:
    sys.exit(1)
rows = [line.split("\t") for line in lines if line.strip() and not line.startswith("#")]
if not rows or rows[0] != ["pattern", "example", "instead"] or len(rows) < 2:
    sys.exit(1)
examples = [row[1] for row in rows[1:] if len(row) == 3 and row[1].strip()]
if len(examples) != len(rows) - 1:
    sys.exit(1)
joined = " ".join(examples).lower()
for form in ("it is necessary to", "in order to", "regarding", "perform the confirmation of"):
    if form not in joined:
        sys.exit(1)
with open(sys.argv[2], "w", encoding="utf-8") as out:
    out.write("# From Japanese\n")
    for number, example in enumerate(examples):
        out.write("\n" + example + "\n")
        print(3 + 2 * number)
PY
}

from_japanese() {
  local wanted out status n
  wanted="$(translationese_sample "$T/japanese.md")" || return 1
  out="$(run_suspects "$RUN" "$T/japanese.md" 2>/dev/null)"
  status=$?
  [ "$status" = 0 ] || return 1
  for n in $wanted; do
    printf '%s\n' "$out" | grep -q "^L$n \[from Japanese\]" || return 1
  done
}
check "suspects points at phrasing translated from Japanese" "from_japanese"

natural_sample() {
  local out status
  cat > "$T/natural.md" <<'MD'
# Release notes

The installer now checks the free disk space before it copies any file.
If the disk is too full, it stops and names the folder to clear.

- Run `setup --check` to see the same report without installing anything.
- The report lists each folder with its size, e.g. the cache comes first.

```text
The files are copied in order to save time, and it is necessary to keep this line exactly as the tool prints it on every single run today.
```

We moved the default port to 4100 because another tool already used 3000.
The script skips inline code such as `regarding X, the file is deleted` when it reads a line.
MD
  out="$(run_suspects "$RUN" "$T/natural.md" 2>/dev/null)"
  status=$?
  [ "$status" = 0 ] && [ -n "$(run_line)" ] && ! printf '%s\n' "$out" | grep -q '^L[0-9]'
}
check "suspects finds nothing in the natural sample" "natural_sample"

refuses_missing() {
  local out status before after
  [ -f "$SKILL_DIR/scripts/suspects.py" ] || return 1
  before="$(cd "$T" && find . | LC_ALL=C sort)"
  out="$(run_suspects "$RUN" "$T/missing.md" 2>/dev/null)"
  status=$?
  after="$(cd "$T" && find . | LC_ALL=C sort)"
  [ "$status" = 2 ] && ! printf '%s\n' "$out" | grep -q '^L[0-9]' && [ "$before" = "$after" ]
}
check "suspects refuses a missing file" "refuses_missing"

# Reads every script of the skill and prints each import of a module that can reach the network or run
# another program, and each call that writes, moves, or removes a file. Prints "no scripts" when there is none.
risky_calls() {
  python3 - "$SKILL_DIR/scripts" <<'PY'
import ast, pathlib, sys
root = pathlib.Path(sys.argv[1])
scripts = sorted(root.rglob("*.py")) if root.is_dir() else []
if not scripts:
    print("no scripts")
network = {"socket", "ssl", "http", "urllib", "urllib3", "ftplib", "smtplib", "poplib", "imaplib", "telnetlib",
           "xmlrpc", "asyncio", "requests", "httpx", "aiohttp", "subprocess", "multiprocessing", "webbrowser",
           "shutil", "tempfile", "ctypes"}
# Path methods that change files, and functions of os that change files or run programs.
path_writes = {"write_text", "write_bytes", "mkdir", "touch", "unlink", "rename", "rmdir", "symlink_to",
               "hardlink_to", "chmod"}
os_writes = {"open", "remove", "replace", "rename", "unlink", "mkdir", "makedirs", "rmdir", "removedirs", "system",
             "popen", "fork", "kill", "chmod", "link", "symlink", "truncate", "write"} | {
             f"{a}{b}" for a in ("exec", "spawn") for b in ("l", "le", "lp", "lpe", "v", "ve", "vp", "vpe")}

def writing_mode(mode):
    """A mode that is not a constant string, or one with w, a, x, or +, can write."""
    return mode is not None and not (isinstance(mode, ast.Constant) and isinstance(mode.value, str)
                                     and not set(mode.value) & set("wax+"))

for path in scripts:
    tree = ast.parse(path.read_text(encoding="utf-8"))
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            names = [alias.name for alias in node.names]
        elif isinstance(node, ast.ImportFrom):
            names = [node.module or ""]
        else:
            names = []
        for name in names:
            if name.split(".")[0] in network:
                print(f"{path.name}:{node.lineno}: imports {name}")
        if not isinstance(node, ast.Call):
            continue
        func, keyword_mode = node.func, next((k.value for k in node.keywords if k.arg == "mode"), None)
        if isinstance(func, ast.Name):
            if func.id in {"exec", "eval", "compile", "__import__"}:
                print(f"{path.name}:{node.lineno}: calls {func.id}")
            if func.id == "open" and writing_mode(node.args[1] if len(node.args) > 1 else keyword_mode):
                print(f"{path.name}:{node.lineno}: opens a file to write")
        elif isinstance(func, ast.Attribute):
            owner = func.value.id if isinstance(func.value, ast.Name) else ""
            if owner == "os" and func.attr in os_writes:
                print(f"{path.name}:{node.lineno}: calls os.{func.attr}")
            elif func.attr in path_writes:
                print(f"{path.name}:{node.lineno}: calls {func.attr}")
            elif func.attr == "open" and writing_mode(
                    (node.args[1] if len(node.args) > 1 else keyword_mode) if owner in {"io", "codecs"}
                    else (node.args[0] if node.args else keyword_mode)):
                print(f"{path.name}:{node.lineno}: opens a file to write")
PY
}

sends_and_writes_nothing() {
  [ -z "$(risky_calls)" ] || return 1
  # Every run above used the copy in $RUN from inside $T; the copy holds the same files as before them,
  # and no run left bytecode anywhere.
  [ "$(cd "$RUN" && find . | LC_ALL=C sort)" = "$BEFORE" ] && [ -n "$(run_line)" ] && [ -z "$(find "$T" -name __pycache__)" ]
}
check "the scripts send nothing and write nothing" "sends_and_writes_nothing"

pins_proselint() {
  local body versions
  body="$(skill_body)" || return 1
  printf '%s\n' "$body" | grep -qE 'uv run --with proselint==[0-9]+\.[0-9]+\.[0-9]+ proselint check --output-format json <file>' || return 1
  versions="$(printf '%s\n' "$body" | grep -oE 'proselint==[^ `]+' | LC_ALL=C sort -u)"
  [ "$(printf '%s\n' "$versions" | grep -c .)" = 1 ] || return 1
  printf '%s\n' "$body" | grep -qiE "uv's (own )?cache" \
    && printf '%s\n' "$body" | grep -qiE 'tell the user' \
    && printf '%s\n' "$body" | grep -qiE 'when `uv` is not installed|without `uv`' \
    && printf '%s\n' "$body" | grep -qiE 'by eye'
}
check "SKILL.md pins proselint and covers a machine without uv" "pins_proselint"

# Other skills follow the rules through musubi, a declaration that pins the version and fingerprint of
# what they follow.
publishes_guide() {
  [ -f "$SKILL_DIR/musubi.json" ] || return 1
  python3 - "$SKILL_DIR" <<'PY' || return 1
import json, os, re, sys
root = sys.argv[1]
declaration = json.load(open(os.path.join(root, "musubi.json"), encoding="utf-8"))
provides = declaration.get("provides")
if not re.fullmatch(r"20[0-9]{2}-[0-9]{2}-[0-9]{2}", str(declaration.get("musubi"))) or "follows" in declaration:
    sys.exit(1)
if not isinstance(provides, dict) or set(provides) != {"rules"}:
    sys.exit(1)
entry = provides["rules"]
ok = (set(entry) == {"version", "file"} and re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", entry["version"])
      and entry["file"] == "references/rules.md" and os.path.isfile(os.path.join(root, entry["file"])))
sys.exit(0 if ok else 1)
PY
  grep -E '`rules`' "$SKILL_DIR/SKILL.md" | grep -qF '`references/rules.md`'
}
check "musubi publishes the guide with its version and file" "publishes_guide"

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

printf '\n%d passed, %d failed, %d skipped (%d ran)\n' "$PASS" "$FAIL" "$SKIP" "$((PASS + FAIL))"
[ "$FAIL" = 0 ]
