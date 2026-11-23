#!/usr/bin/env bash
# Tests for the digital-dashboard plugin: which skill it holds, what no file in it names, that it
# ships no official document, how scripts/fetch_official.py downloads and checks the official files,
# how scripts/attachments.py lists what to attach, and how scripts/screen_kind.py marks candidates.
# Every download reads file:// addresses in a throwaway folder, so the tests never use the network.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
PLUGIN_DIR="$(cd "$HERE/../../.." && pwd)"
NAME=digital-dashboard
SKILL="$SKILL_DIR/SKILL.md"
MANIFEST="$SKILL_DIR/references/official-files.json"
FETCH="$SKILL_DIR/scripts/fetch_official.py"
ATTACH="$SKILL_DIR/scripts/attachments.py"
KIND="$SKILL_DIR/scripts/screen_kind.py"
NOTICES="$PLUGIN_DIR/THIRD_PARTY_NOTICES.md"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export PYTHONDONTWRITEBYTECODE=1
unset DIGITAL_DASHBOARD_HOME

why=""
check() {
  why=""
  if "$2"; then
    PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"
  else
    FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"
    [ -n "$why" ] && printf '        %s\n' "$why"
  fi
}

# need <file>...: every file exists.
need() {
  local f
  for f in "$@"; do
    [ -f "$f" ] || { why="$f is missing"; return 1; }
  done
}

# sha <file>: prints the SHA-256 of the file.
sha() {
  python3 -c 'import hashlib, sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$1"
}

# run <command>...: runs a command; sets out and status.
run() {
  out="$("$@" 2>&1)"
  status=$?
}

# fixture <folder>: writes two source files and a manifest with file:// addresses under the folder.
# The manifest lists a required document and an on-demand file that only sets colors.
fixture() {
  local dir="$1"
  mkdir -p "$dir/src"
  printf 'official guidebook\n' > "$dir/src/guidebook.pdf"
  printf '{"dataColors": ["#000000"]}\n' > "$dir/src/theme.json"
  cat > "$dir/manifest.json" <<EOF
[
  {"path": "guidebook.pdf", "url": "file://$dir/src/guidebook.pdf", "sha256": "$(sha "$dir/src/guidebook.pdf")",
   "title": "Guidebook", "attach": "required"},
  {"path": "themes/theme.json", "url": "file://$dir/src/theme.json", "sha256": "$(sha "$dir/src/theme.json")",
   "title": "Theme", "attach": "on-demand", "when": "When the drawing tool reads a theme file", "palette": true}
]
EOF
}

# stamps <folder>: prints the inode, modification time, and path of every file under the folder.
stamps() {
  python3 - "$1" <<'PY'
import os, sys
top = sys.argv[1]
for folder, _, files in sorted(os.walk(top)):
    for name in sorted(files):
        path = os.path.join(folder, name)
        info = os.stat(path)
        print(info.st_ino, info.st_mtime_ns, os.path.relpath(path, top))
PY
}

holds_one_skill() {
  local found
  found="$(cd "$PLUGIN_DIR/skills" 2>/dev/null && LC_ALL=C ls -d -- */ 2>/dev/null | tr -d / | tr '\n' ' ')"
  [ "$found" = "$NAME " ] || { why="skills/ holds: ${found:-nothing}"; return 1; }
  need "$SKILL" "$SKILL_DIR/agents/openai.yaml" || return 1
  grep -qx "name: $NAME" "$SKILL" || { why="SKILL.md does not say name: $NAME"; return 1; }
}

# The shapes no file of a public plugin may hold, one regular expression per line: a home folder on
# macOS or Linux where a path starts (a throwaway HOME such as $T/case/home/ is not one), the
# configuration folder of a local agent, and an issue reference. They are general shapes only, so
# this file names no product, company, or person.
SHAPES='(?<![A-Za-z0-9_.-])/(?:Users|home)/[A-Za-z0-9._-]+
~/[.](?:claude|codex)/
\b(?:GH|Issue) #[0-9]+'

# Prints file:line for every line under the folders given that holds one of SHAPES.
private_shapes_in() {
  SHAPES="$SHAPES" python3 - "$@" <<'PY'
import os, re, sys
pattern = re.compile("|".join(os.environ["SHAPES"].splitlines()))
images = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico")
for top in sys.argv[1:]:
    for folder, _, files in os.walk(top):
        for name in files:
            path = os.path.join(folder, name)
            if name.lower().endswith(images):
                continue
            with open(path, encoding="utf-8", errors="ignore") as source:
                for number, line in enumerate(source, 1):
                    if pattern.search(line):
                        print(f"{os.path.relpath(path, top)}:{number}")
PY
}

# need_scan: this file defines the private-name scan the checks below run.
need_scan() { declare -F private_shapes_in > /dev/null || { why="the test defines no private_shapes_in scan"; return 1; }; }

# The scan's patterns are general shapes only: SHAPES is assigned once, as three plain lines with no
# quote or expansion that could join parts into a word, and once the words of those shapes and the
# syntax of regular expressions are taken out, no letter is left. The name scan compiles no other
# pattern and the test searches with no recursive grep, so it cannot look for a specific word.
scan_lists_general_shapes() {
  local said
  said="$(python3 - "$HERE/test-digital-dashboard.sh" 2>&1 <<'PY'
import re, sys
source = open(sys.argv[1], encoding="utf-8").read()
found = re.findall(r"^SHAPES='([^']*)'$", source, re.M)
if len(found) != 1:
    sys.exit("SHAPES is assigned %d times, not once" % len(found))
lines = found[0].splitlines()
if len(lines) != 3 or any(c in found[0] for c in "\"$`"):
    sys.exit("SHAPES is not three plain lines: %r" % found[0])
rest = re.sub(r"\\[bdsw]|\[[^]]*\]|\b(?:Users|home|claude|codex|GH|Issue)\b", "", found[0])
if re.search(r"[A-Za-z]", rest):
    sys.exit("SHAPES holds a word other than the general shapes: %r" % rest)
compiled = re.findall(r"^\s*pattern = re[.]compile[(](.*)[)]$", source, re.M)
if compiled != ['"|".join(os.environ["SHAPES"].splitlines())']:
    sys.exit("the name scan compiles a pattern other than SHAPES: %r" % compiled)
greps = [str(n) for n, line in enumerate(source.splitlines(), 1) if re.search(r"\bgrep\s+(?:-[A-Za-z]*[rR]|--recursive)", line)]
if greps:
    sys.exit("the test searches with a recursive grep at line %s" % ", ".join(greps))
PY
)" || { why="$said"; return 1; }
}

# One line of each shape, planted in a throwaway folder, is found. The lines are printed from parts
# so that this file does not hold them.
scan_finds_planted_shapes() {
  need_scan || return 1
  local hits
  mkdir -p "$T/shapes"
  {
    printf 'see /%s/someone/notes\n' Users home
    printf 'see ~/.%s/settings\n' claude codex
    printf 'see %s #%d\n' GH 12 Issue 3
  } > "$T/shapes/planted.md"
  hits="$(private_shapes_in "$T/shapes" | LC_ALL=C sort | tr '\n' ' ')"
  [ "$hits" = "planted.md:1 planted.md:2 planted.md:3 planted.md:4 planted.md:5 planted.md:6 " ] \
    || { why="expected lines 1 to 6 of planted.md (a home folder under /Users and /home, a local agent path for each agent, an issue reference of each form), the scan found: ${hits:-nothing}"; return 1; }
}

# A home folder written with a <name> placeholder, a throwaway folder whose path ends in a home
# folder, and plain words with a bare number sign are not shapes.
scan_passes_placeholders() {
  need_scan || return 1
  local hits
  mkdir -p "$T/plain"
  {
    printf 'a placeholder such as /%s/<name> or /%s/<name>\n' Users home
    printf 'a throwaway HOME such as $T/case/%s/notes\n' home
    printf 'plain words, a docs/%s/page.md link, and #12 alone\n' home
  } > "$T/plain/plain.md"
  hits="$(private_shapes_in "$T/plain")"
  [ -z "$hits" ] || { why="the scan flagged: $(printf '%s ' $hits)"; return 1; }
}

# A shape planted in a copy of the plugin is found in a top-level file, in a file of the skill
# folder, and in a file of a hidden manifest folder, and nowhere else.
scan_finds_shapes_in_plugin_copy() {
  need_scan || return 1
  local hits
  cp -R "$PLUGIN_DIR" "$T/copy"
  printf 'see /%s/someone/notes\n' Users >> "$T/copy/README.md"
  printf 'see ~/.%s/settings\n' codex >> "$T/copy/skills/digital-dashboard/SKILL.md"
  printf 'see %s #%d\n' Issue 3 >> "$T/copy/.codex-plugin/plugin.json"
  hits="$(private_shapes_in "$T/copy" | sed 's/:[0-9]*$//' | LC_ALL=C sort | tr '\n' ' ')"
  [ "$hits" = ".codex-plugin/plugin.json README.md skills/digital-dashboard/SKILL.md " ] \
    || { why="expected .codex-plugin/plugin.json, README.md, and skills/digital-dashboard/SKILL.md, the scan found: ${hits:-nothing}"; return 1; }
}

no_local_names() {
  need_scan || return 1
  local hits
  # The scan finds planted lines (the checks above), so an empty result means the shapes are absent.
  hits="$(private_shapes_in "$PLUGIN_DIR")"
  [ -z "$hits" ] || { why="found at: $(printf '%s ' $hits)"; return 1; }
}

changelog_names_general_shapes() {
  local log="$PLUGIN_DIR/CHANGELOG.md"
  [ -f "$log" ] || { why="$log is missing"; return 1; }
  grep -qF 'looks only for general shapes' "$log" \
    || { why="CHANGELOG.md does not say that the name scan looks only for general shapes"; return 1; }
}

no_agent_names() {
  need "$SKILL" || return 1
  local hit
  # A folder such as .claude/ is a path, not the agent's name.
  hit="$(grep -inE '(^|[^.a-z])(askuserquestion|claude|codex|chatgpt|gpt-?[0-9]|opus|sonnet|haiku|gemini|copilot)' "$SKILL" | head -1)"
  [ -z "$hit" ] || { why="SKILL.md names an agent, its tool, or a model: $hit"; return 1; }
  ! sed -n '2,/^---$/p' "$SKILL" | grep -q '^allowed-tools:' || { why="SKILL.md has allowed-tools in its frontmatter"; return 1; }
  grep -qF 'ask the user in the chat' "$SKILL" || { why="SKILL.md does not say to ask the user in the chat"; return 1; }
}

# The official documents are listed for download, and the only image in the plugin is its icon.
ships_no_official_document() {
  need "$MANIFEST" || return 1
  local listed bad images
  listed="$(jq -r '[.[].path | ascii_downcase | capture("\\.(?<x>[a-z]+)$").x] | unique | join(" ")' "$MANIFEST" 2>/dev/null)"
  for ext in pdf pptx xlsx docx zip; do
    [[ " $listed " == *" $ext "* ]] || { why="official-files.json lists no .$ext document to download (lists: ${listed:-nothing})"; return 1; }
  done
  bad="$(cd "$PLUGIN_DIR" && find . -type f \( -iname '*.pdf' -o -iname '*.ppt' -o -iname '*.pptx' -o -iname '*.zip' \
    -o -iname '*.pbit' -o -iname '*.xls' -o -iname '*.xlsx' -o -iname '*.doc' -o -iname '*.docx' \) | LC_ALL=C sort)"
  [ -z "$bad" ] || { why="the plugin ships official documents: $(printf '%s ' $bad)"; return 1; }
  images="$(cd "$PLUGIN_DIR" && find . -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' \
    -o -iname '*.webp' -o -iname '*.svg' \) | LC_ALL=C sort | tr '\n' ' ')"
  [ "$images" = "./assets/icon.svg " ] || { why="the images are not only assets/icon.svg: ${images:-none}"; return 1; }
}

manifest_has_fingerprints() {
  need "$MANIFEST" || return 1
  local bad
  bad="$(python3 - "$MANIFEST" <<'PY'
import json, re, sys
prefix = re.compile(r"^https://(www\.digital\.go\.jp/|github\.com/digital-go-jp/|raw\.githubusercontent\.com/digital-go-jp/)")
rows = json.load(open(sys.argv[1], encoding="utf-8"))
if not isinstance(rows, list) or not rows:
    sys.exit(print("the manifest is not a non-empty array"))
paths = set()
for row in rows:
    path = row.get("path") if isinstance(row, dict) else None
    if not isinstance(path, str) or not path or path.startswith("/") or ".." in path.split("/"):
        print(f"bad path: {row!r}"); continue
    if path in paths:
        print(f"{path} is listed twice")
    paths.add(path)
    if not re.fullmatch(r"[0-9a-f]{64}", str(row.get("sha256", ""))):
        print(f"{path}: sha256 is not 64 lowercase hexadecimal characters")
    if not prefix.match(str(row.get("url", ""))):
        print(f"{path}: url {row.get('url')!r} is not a published location of the Digital Agency")
    if row.get("attach") not in ("required", "on-demand"):
        print(f"{path}: attach is neither required nor on-demand")
PY
)"
  [ -z "$bad" ] || { why="$(printf '%s' "$bad" | head -3 | tr '\n' ' ')"; return 1; }
}

# Imports only the standard library, and writes to ~/.local/share/digital-dashboard/ by default.
fetch_standard_library() {
  need "$FETCH" || return 1
  local bad
  bad="$(python3 - "$FETCH" <<'PY'
import ast, re, sys
source = open(sys.argv[1], encoding="utf-8").read()
names = set()
for node in ast.walk(ast.parse(source)):
    if isinstance(node, ast.Import):
        names.update(alias.name.split(".")[0] for alias in node.names)
    elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
        names.add(node.module.split(".")[0])
outside = sorted(name for name in names if name not in sys.stdlib_module_names)
if re.search(r"^# /// script$", source, re.M):
    outside.append("a PEP 723 script block")
print(" ".join(outside))
PY
)"
  [ -z "$bad" ] || { why="imports beyond the standard library: $bad"; return 1; }
  fixture "$T/default"
  mkdir -p "$T/default/home"
  run env HOME="$T/default/home" python3 "$FETCH" --manifest "$T/default/manifest.json"
  [ "$status" -eq 0 ] || { why="the fetch without --dest exited $status: $out"; return 1; }
  [ -f "$T/default/home/.local/share/digital-dashboard/guidebook.pdf" ] \
    || { why="without --dest the files are not under ~/.local/share/digital-dashboard/: $out"; return 1; }
}

fetch_writes_listed_files() {
  need "$FETCH" || return 1
  fixture "$T/first"
  run python3 "$FETCH" --manifest "$T/first/manifest.json" --dest "$T/first/dest"
  [ "$status" -eq 0 ] || { why="the fetch exited $status: $out"; return 1; }
  local path want
  while IFS=$'\t' read -r path want; do
    [ -f "$T/first/dest/$path" ] || { why="$path was not written"; return 1; }
    [ "$(sha "$T/first/dest/$path")" = "$want" ] || { why="$path does not match its fingerprint"; return 1; }
  done < <(jq -r '.[] | [.path, .sha256] | @tsv' "$T/first/manifest.json")
  [ "$(cd "$T/first/dest" && find . -type f | grep -c .)" = 2 ] || { why="the destination holds files beyond the list: $(cd "$T/first/dest" && find . -type f | tr '\n' ' ')"; return 1; }
}

second_fetch_downloads_nothing() {
  need "$FETCH" || return 1
  local before after
  fixture "$T/second"
  run python3 "$FETCH" --manifest "$T/second/manifest.json" --dest "$T/second/dest"
  [ "$status" -eq 0 ] || { why="the first fetch exited $status: $out"; return 1; }
  before="$(stamps "$T/second/dest")"
  sleep 1
  run python3 "$FETCH" --manifest "$T/second/manifest.json" --dest "$T/second/dest"
  [ "$status" -eq 0 ] || { why="the second fetch exited $status: $out"; return 1; }
  after="$(stamps "$T/second/dest")"
  [ "$before" = "$after" ] || { why="the second fetch changed: $(diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | head -3 | tr '\n' ' ')"; return 1; }
}

fetch_rejects_wrong_fingerprint() {
  need "$FETCH" || return 1
  fixture "$T/wrong"
  # The guidebook's fingerprint is that of another file, and a stale copy already sits in place.
  jq --arg s "$(printf 'another file\n' | python3 -c 'import hashlib, sys; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())')" \
    '(.[] | select(.path == "guidebook.pdf") | .sha256) = $s' "$T/wrong/manifest.json" > "$T/wrong/bad.json"
  mkdir -p "$T/wrong/dest"
  printf 'stale copy\n' > "$T/wrong/dest/guidebook.pdf"
  run python3 "$FETCH" --manifest "$T/wrong/bad.json" --dest "$T/wrong/dest"
  [ "$status" -ne 0 ] || { why="a file with a different fingerprint was accepted: $out"; return 1; }
  [[ "$out" == *"guidebook.pdf"* ]] || { why="the refusal does not name guidebook.pdf: $out"; return 1; }
  [ ! -e "$T/wrong/dest/guidebook.pdf" ] || { why="the file with a different fingerprint was left in place"; return 1; }
  [ -f "$T/wrong/dest/themes/theme.json" ] || { why="the file that matched was not written"; return 1; }
  [ "$(cd "$T/wrong/dest" && find . -type f | grep -c .)" = 1 ] || { why="the destination holds leftovers: $(cd "$T/wrong/dest" && find . -type f | tr '\n' ' ')"; return 1; }
}

# The SKILL.md runs the fetch before it lists the attachments, and the list refuses unfetched files.
skill_fetches_first() {
  need "$SKILL" "$ATTACH" || return 1
  local fetch_at attach_at
  fetch_at="$(grep -nE '^ *python3 .*fetch_official\.py' "$SKILL" | head -1 | cut -d: -f1)"
  attach_at="$(grep -nE '^ *python3 .*attachments\.py' "$SKILL" | head -1 | cut -d: -f1)"
  [ -n "$fetch_at" ] && [ -n "$attach_at" ] || { why="SKILL.md does not run both fetch_official.py and attachments.py"; return 1; }
  [ "$fetch_at" -lt "$attach_at" ] || { why="SKILL.md lists attachments (line $attach_at) before it fetches (line $fetch_at)"; return 1; }
  fixture "$T/unfetched"
  mkdir -p "$T/unfetched/repo" "$T/unfetched/official"
  run python3 "$ATTACH" --repo "$T/unfetched/repo" --manifest "$T/unfetched/manifest.json" --official "$T/unfetched/official"
  [ "$status" -ne 0 ] || { why="the list went on without the fetched files: $out"; return 1; }
  [[ "$out" == *"fetch_official.py"* ]] || { why="the refusal does not say to run fetch_official.py: $out"; return 1; }
}

# fetched <folder>: fetches the fixture of the folder into <folder>/official.
fetched() {
  fixture "$1"
  mkdir -p "$1/repo"
  python3 "$FETCH" --manifest "$1/manifest.json" --dest "$1/official" > /dev/null 2>&1
}

themed_request_drops_palette() {
  need "$ATTACH" "$FETCH" || return 1
  fetched "$T/theme" || { why="the fixture could not be fetched"; return 1; }
  run python3 "$ATTACH" --repo "$T/theme/repo" --manifest "$T/theme/manifest.json" --official "$T/theme/official" --theme Mercury
  [ "$status" -eq 0 ] || { why="the themed list exited $status: $out"; return 1; }
  local f
  for f in color-palette.md theme-spec.md chart-library.md themes/theme.json; do
    [[ "$out" != *"$f"* ]] || { why="the themed list still attaches $f"; return 1; }
  done
  printf '%s\n' "$out" | grep -qE $'^request\t.*Mercury.*instead of the color palette of the guidebook' \
    || { why="the themed list has no request line for the theme's colors: $out"; return 1; }
  run python3 "$ATTACH" --repo "$T/theme/repo" --manifest "$T/theme/manifest.json" --official "$T/theme/official"
  [ "$status" -eq 0 ] || { why="the list without a theme exited $status: $out"; return 1; }
  [[ "$out" == *"color-palette.md"* && "$out" == *"themes/theme.json"* ]] || { why="without a theme the palette is not attached: $out"; return 1; }
  ! printf '%s\n' "$out" | grep -q $'^request\t' || { why="without a theme the list still asks for the theme's colors"; return 1; }
}

# declare <repo> <json>: writes the repository's declaration and the files it names.
declare_sources() {
  mkdir -p "$1/.claude" "$1/catalog/dashboard/conventions"
  printf '%s\n' "$2" > "$1/.claude/design-sources.json"
  printf '# Dashboard guide\n' > "$1/catalog/dashboard/guide.md"
  printf '%s\n' '---' 'title: numbers' '---' '' '# How to write numbers' > "$1/catalog/dashboard/numbers.md"
  printf '# Manual\n' > "$1/catalog/dashboard/manual.md"
  printf '# Finance conventions\n' > "$1/catalog/dashboard/conventions/finance.md"
}

follows_declaration() {
  need "$ATTACH" || return 1
  local repo="$T/declared" expected
  fetched "$repo-src" || { why="the fixture could not be fetched"; return 1; }
  declare_sources "$repo" '{"schema_version": 3,
    "dashboard_attach_globs": ["catalog/dashboard/guide.md"],
    "dashboard_convention_template": "catalog/dashboard/conventions/{domain}.md",
    "dashboard_on_demand_globs": ["catalog/dashboard/numbers.md",
      {"glob": "catalog/dashboard/manual.md", "when": "When the steps of the official tool are needed"}]}'
  run python3 "$ATTACH" --repo "$repo" --domain finance --manifest "$repo-src/manifest.json" --official "$repo-src/official"
  [ "$status" -eq 0 ] || { why="the declared list exited $status: $out"; return 1; }
  expected="$(printf '%s\n' "required	$repo/catalog/dashboard/guide.md" "domain	$repo/catalog/dashboard/conventions/finance.md" \
    "on-demand	$repo/catalog/dashboard/numbers.md	# How to write numbers" \
    "on-demand	$repo/catalog/dashboard/manual.md	When the steps of the official tool are needed")"
  [ "$out" = "$expected" ] || { why="the declared list is: $(printf '%s' "$out" | tr '\t\n' '  ')"; return 1; }
  # A declaration that names only the required files is not filled up with the skill's own files.
  declare_sources "$repo" '{"schema_version": 2, "dashboard_attach_globs": ["catalog/dashboard/guide.md"]}'
  run python3 "$ATTACH" --repo "$repo" --domain finance --manifest "$repo-src/manifest.json" --official "$repo-src/official"
  [ "$status" -eq 0 ] && [ "$out" = "required	$repo/catalog/dashboard/guide.md" ] \
    || { why="a declaration of the required files only gave: $status $(printf '%s' "$out" | tr '\t\n' '  ')"; return 1; }
  # Version 1 has no fields for the material, so the skill's own list is used.
  declare_sources "$repo" '{"schema_version": 1, "dashboard_attach_globs": ["catalog/dashboard/guide.md"]}'
  run python3 "$ATTACH" --repo "$repo" --manifest "$repo-src/manifest.json" --official "$repo-src/official"
  [ "$status" -eq 0 ] && [[ "$out" != *"catalog/dashboard"* && "$out" == *"$repo-src/official/guidebook.pdf"* ]] \
    || { why="a version 1 declaration did not fall back to the fetched files: $status $out"; return 1; }
  # An unknown version and a pattern that matches nothing stop the list.
  declare_sources "$repo" '{"schema_version": 9, "dashboard_attach_globs": ["catalog/dashboard/guide.md"]}'
  run python3 "$ATTACH" --repo "$repo" --manifest "$repo-src/manifest.json" --official "$repo-src/official"
  [ "$status" -ne 0 ] || { why="an unknown version was read: $out"; return 1; }
  declare_sources "$repo" '{"schema_version": 3, "dashboard_attach_globs": ["catalog/dashboard/missing-*.md"]}'
  run python3 "$ATTACH" --repo "$repo" --manifest "$repo-src/manifest.json" --official "$repo-src/official"
  [ "$status" -ne 0 ] || { why="a pattern that matches nothing gave an empty list: $out"; return 1; }
}

falls_back_to_fetched() {
  need "$ATTACH" || return 1
  local f
  fetched "$T/plain" || { why="the fixture could not be fetched"; return 1; }
  run python3 "$ATTACH" --repo "$T/plain/repo" --domain finance --manifest "$T/plain/manifest.json" --official "$T/plain/official"
  [ "$status" -eq 0 ] || { why="the list exited $status: $out"; return 1; }
  printf '%s\n' "$out" | grep -qxF "required	$T/plain/official/guidebook.pdf" || { why="the fetched guidebook is not a required attachment: $out"; return 1; }
  for f in abstraction-principles.md chart-decision-tree.md color-palette.md; do
    printf '%s\n' "$out" | grep -qxF "required	$SKILL_DIR/references/$f" || { why="the rule file $f is not a required attachment"; return 1; }
  done
  printf '%s\n' "$out" | grep -qxF "domain	$SKILL_DIR/references/conventions/finance.md" || { why="the finance conventions are not attached"; return 1; }
  printf '%s\n' "$out" | grep -qxF "on-demand	$T/plain/official/themes/theme.json	When the drawing tool reads a theme file" \
    || { why="the fetched on-demand file is not listed with when to add it"; return 1; }
  for f in numeric-format.md time-axis.md visual-ssot.md dos-donts.md; do
    printf '%s\n' "$out" | grep -qE "^on-demand	$SKILL_DIR/references/$f	.+" || { why="the rule file $f is not on demand with when to add it"; return 1; }
  done
  for f in $(printf '%s\n' "$out" | cut -f2); do
    [ -f "$f" ] || { why="the list names a file that does not exist: $f"; return 1; }
  done
}

# judge <name> <table rows>: writes a screen specification and prints the first pass's verdict.
judge() {
  {
    printf '%s\n' '# Screen' '' '## 項目定義' '' '| 項目 | 種別 | 出典 | 備考 |' '|---|---|---|---|'
    printf '%s\n' "${@:2}"
  } > "$T/kind/$1.md"
  python3 "$KIND" "$T/kind/$1.md" 2>&1 | sed -nE 's/.*=> ([a-z]+)$/\1/p'
}

marks_candidates() {
  need "$KIND" || return 1
  mkdir -p "$T/kind"
  local got
  got="$(judge chart-and-number '| Sales trend | グラフ | API | |' '| Orders | 数値 | API | |')"
  [ "$got" = candidate ] || { why="a chart with a number is '$got', not candidate"; return 1; }
  got="$(judge chart-and-summary '| Trend | グラフ | API | |' '| Totals | サマリー | API | |')"
  [ "$got" = candidate ] || { why="a chart with a summary is '$got', not candidate"; return 1; }
  got="$(judge chart-only '| Spread | グラフ | API | |' '| Note | テキスト | Manual | |')"
  [ "$got" = other ] || { why="a chart without a total is '$got', not other"; return 1; }
  got="$(judge total-only '| Total | 合計 | API | |' '| List | テーブル | API | |')"
  [ "$got" = other ] || { why="a total without a chart is '$got', not other"; return 1; }
  # The words in the source column are not kinds.
  got="$(judge source-column '| List | テーブル | グラフ API | |' '| Detail | テキスト | 数値 service | |')"
  [ "$got" = other ] || { why="words in the source column were read as kinds: '$got'"; return 1; }
  # A table under another heading is not counted.
  printf '%s\n' '## 項目定義' '' '| 項目 | 種別 | 出典 |' '|---|---|---|' '| List | テーブル | API |' '' \
    '## 画面遷移' '' '| 項目 | 種別 | 出典 |' '|---|---|---|' '| Trend | グラフ | API |' '| Count | 数値 | API |' > "$T/kind/other-section.md"
  got="$(python3 "$KIND" "$T/kind/other-section.md" 2>&1 | sed -nE 's/.*=> ([a-z]+)$/\1/p')"
  [ "$got" = other ] || { why="a table under another heading was counted: '$got'"; return 1; }
  # A specification written in English is judged the same way.
  printf '%s\n' '## Item definitions' '' '| Item | Kind | Source |' '|---|---|---|' '| Sales | Chart | API |' '| Orders | Total | API |' > "$T/kind/english.md"
  got="$(python3 "$KIND" "$T/kind/english.md" 2>&1 | sed -nE 's/.*=> ([a-z]+)$/\1/p')"
  [ "$got" = candidate ] || { why="an English specification with a chart and a total is '$got', not candidate"; return 1; }
}

notices_name_source_and_license() {
  need "$NOTICES" "$MANIFEST" || return 1
  local path
  grep -qF 'digital.go.jp' "$NOTICES" || { why="THIRD_PARTY_NOTICES.md does not name digital.go.jp"; return 1; }
  grep -qF 'Public Data License (PDL) 1.0' "$NOTICES" || { why="THIRD_PARTY_NOTICES.md does not name the Public Data License (PDL) 1.0"; return 1; }
  grep -qF 'National Land Numerical Information' "$NOTICES" || { why="THIRD_PARTY_NOTICES.md does not give the terms of the map data"; return 1; }
  for path in $(jq -r '.[].path' "$MANIFEST"); do
    grep -qF "\`$path\`" "$NOTICES" || { why="THIRD_PARTY_NOTICES.md does not list $path"; return 1; }
  done
}

check "the plugin holds one skill of its name" holds_one_skill
check "the private-name scan lists only general shapes" scan_lists_general_shapes
check "the private-name scan finds a planted line of each shape" scan_finds_planted_shapes
check "the private-name scan passes placeholders and plain words" scan_passes_placeholders
check "the private-name scan finds shapes planted in a copy of the plugin" scan_finds_shapes_in_plugin_copy
check "no file holds a home path, a local agent path, or an issue reference" no_local_names
check "the changelog says the name scan looks only for general shapes" changelog_names_general_shapes
check "the SKILL.md names no agent or its tool" no_agent_names
check "the plugin ships no official document or page image" ships_no_official_document
check "the manifest lists official files with fingerprints" manifest_has_fingerprints
check "the fetch script uses only the standard library" fetch_standard_library
check "fetch writes every listed file with a matching fingerprint" fetch_writes_listed_files
check "a second fetch downloads nothing" second_fetch_downloads_nothing
check "fetch rejects a file whose fingerprint differs" fetch_rejects_wrong_fingerprint
check "the SKILL.md fetches before attaching" skill_fetches_first
check "the themed request drops the official palette" themed_request_drops_palette
check "the attachment list follows the repository declaration" follows_declaration
check "the attachment list falls back to the fetched files" falls_back_to_fetched
check "the first pass marks a chart with a total as a candidate" marks_candidates
check "the notices name the source and the license" notices_name_source_and_license

printf '\n%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
