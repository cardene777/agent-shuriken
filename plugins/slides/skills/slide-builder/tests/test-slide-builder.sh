#!/usr/bin/env bash
# Tests for the slide-builder skill and the files of the slides plugin: which skills the plugin holds,
# what no file in it names, what both SKILL.md files say, the readability rules, and how
# scripts/validate.py judges an outline. Every outline the tests write goes to a throwaway folder.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
PLUGIN_DIR="$(cd "$HERE/../../.." && pwd)"
SKILL="$SKILL_DIR/SKILL.md"
RULES="$SKILL_DIR/references/readability-rules.md"
FORMAT="$SKILL_DIR/references/deck-format.md"
VALIDATOR="$SKILL_DIR/scripts/validate.py"
EXAMPLE="$SKILL_DIR/examples/slides-outline.md"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export PYTHONDONTWRITEBYTECODE=1

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

# validate <args>...: runs the validator; sets out and status.
validate() {
  out="$(python3 "$VALIDATOR" "$@" 2>&1)"
  status=$?
}

# one_page <takeaway sentence>: prints a one-slide outline whose takeaway is the sentence.
one_page() {
  printf '%s\n' '# Sample deck' '' '---' '' '## Slide 1 / 1 ─ Sorting the support inbox' '' \
    '> meta: type=content eyebrow="Part 1"' '' '### Takeaway' '' "$1" '' '---'
}

holds_two_skills() {
  local found skill
  found="$(cd "$PLUGIN_DIR/skills" && LC_ALL=C ls -d -- */ 2>/dev/null | tr -d / | tr '\n' ' ')"
  [ "$found" = "slide-builder slide-forge " ] || { why="skills/ holds: ${found:-nothing}"; return 1; }
  for skill in slide-builder slide-forge; do
    need "$PLUGIN_DIR/skills/$skill/SKILL.md" || return 1
    grep -qx "name: $skill" "$PLUGIN_DIR/skills/$skill/SKILL.md" || { why="$skill/SKILL.md does not say name: $skill"; return 1; }
  done
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
# pattern and the test searches with no recursive grep, so it cannot look for a specific word. The
# readability check compiles its own pattern of domain words under another name, and is not a name scan.
scan_lists_general_shapes() {
  local said
  said="$(python3 - "$HERE/test-slide-builder.sh" 2>&1 <<'PY'
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

# A shape planted in a copy of the plugin is found in a top-level file, in a file of a skill folder,
# and in a file of a hidden manifest folder, and nowhere else.
scan_finds_shapes_in_plugin_copy() {
  need_scan || return 1
  local hits
  cp -R "$PLUGIN_DIR" "$T/copy"
  printf 'see /%s/someone/notes\n' Users >> "$T/copy/README.md"
  printf 'see ~/.%s/settings\n' codex >> "$T/copy/skills/slide-builder/SKILL.md"
  printf 'see %s #%d\n' Issue 3 >> "$T/copy/.codex-plugin/plugin.json"
  hits="$(private_shapes_in "$T/copy" | sed 's/:[0-9]*$//' | LC_ALL=C sort | tr '\n' ' ')"
  [ "$hits" = ".codex-plugin/plugin.json README.md skills/slide-builder/SKILL.md " ] \
    || { why="expected .codex-plugin/plugin.json, README.md, and skills/slide-builder/SKILL.md, the scan found: ${hits:-nothing}"; return 1; }
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
  local skill f hit
  for skill in slide-builder slide-forge; do
    f="$PLUGIN_DIR/skills/$skill/SKILL.md"
    need "$f" || return 1
    hit="$(grep -inE 'askuserquestion|claude|codex|chatgpt|gpt-?[0-9]|opus|sonnet|haiku|gemini|copilot' "$f" | head -1)"
    [ -z "$hit" ] || { why="$skill/SKILL.md names an agent, its tool, or a model: $hit"; return 1; }
    ! sed -n '2,/^---$/p' "$f" | grep -q '^allowed-tools:' || { why="$skill/SKILL.md has allowed-tools in its frontmatter"; return 1; }
    grep -qF 'ask the user in the chat' "$f" || { why="$skill/SKILL.md does not say to ask the user in the chat"; return 1; }
  done
}

general_code_words() {
  need "$RULES" "$FORMAT" "$SKILL" "$VALIDATOR" || return 1
  local word hits
  grep -qi 'non-engineer' "$RULES" || { why="the rules do not set non-engineers as the default audience"; return 1; }
  for word in function method class struct variable; do
    grep -qiw "$word" "$RULES" || { why="the rules do not ban the code word '$word'"; return 1; }
  done
  grep -qF -- '--ban' "$RULES" || { why="the rules do not say how a deck adds its own words with --ban"; return 1; }
  # Words of one field, blockchain and patents, built from parts.
  hits="$(python3 - "$RULES" "$FORMAT" "$SKILL" "$VALIDATOR" <<'PY'
import re, sys
field = re.compile(r"smart con" r"tract|\bmi" r"nt\b|\bbu" r"rn\b|\bpat" r"ent|stable" r"coin|block" r"chain|soli" r"dity", re.I)
for path in sys.argv[1:]:
    for number, line in enumerate(open(path, encoding="utf-8"), 1):
        if field.search(line):
            print(f"{path.rsplit('/', 1)[-1]}:{number}")
PY
)"
  [ -z "$hits" ] || { why="field words at: $(printf '%s ' $hits)"; return 1; }
  # A general code word is flagged by default; a field word only when the deck asks for it.
  one_page 'Each request goes to one person, as a function of its topic.' > "$T/code-word.md"
  validate "$T/code-word.md"
  [ "$status" -eq 0 ] && [[ "$out" == *"banned word"*"function"* ]] || { why="'function' was not flagged: $out"; return 1; }
  one_page "We add each ledger entry and mi""nt a badge for it." > "$T/field-word.md"
  validate "$T/field-word.md"
  [ "$status" -eq 0 ] && [[ "$out" != *"banned word"* ]] || { why="a field word was flagged without --ban: $out"; return 1; }
  validate --ban ledger "$T/field-word.md"
  [ "$status" -eq 0 ] && [[ "$out" == *"banned word"*"ledger"* ]] || { why="--ban ledger did not flag 'ledger': $out"; return 1; }
}

standard_library_only() {
  need "$VALIDATOR" || return 1
  local bad
  bad="$(python3 - "$VALIDATOR" <<'PY'
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
}

runs_from_any_folder() {
  need "$SKILL" "$VALIDATOR" "$EXAMPLE" || return 1
  local here_out there_out
  grep -qF 'folder that contains this SKILL.md' "$SKILL" || { why="SKILL.md does not say where the validator's folder is"; return 1; }
  grep -qF 'python3 "$S/validate.py"' "$SKILL" || { why="SKILL.md does not run the validator through \$S"; return 1; }
  # A copy without its takeaways is rejected the same way from the skill and from a project.
  mkdir -p "$T/project/docs"
  grep -v '^### Takeaway' "$EXAMPLE" > "$T/project/docs/slides-outline.md"
  here_out="$(cd "$SKILL_DIR" && python3 "$VALIDATOR" "$T/project/docs/slides-outline.md" 2>&1; echo "exit=$?")"
  there_out="$(cd "$T/project" && python3 "$VALIDATOR" docs/slides-outline.md 2>&1; echo "exit=$?")"
  [ "$here_out" = "$there_out" ] || { why="from the skill: $here_out / from a project: $there_out"; return 1; }
  [[ "$there_out" == *"exit=1" ]] || { why="an outline without takeaways was not rejected: $there_out"; return 1; }
}

example_passes() {
  need "$VALIDATOR" "$EXAMPLE" || return 1
  local slides
  slides="$(grep -cE '^## Slide [0-9]+ / [0-9]+ ' "$EXAMPLE")"
  [ "$slides" -ge 10 ] || { why="the example has $slides slides, fewer than the ten the skill is for"; return 1; }
  validate "$EXAMPLE"
  [ "$status" -eq 0 ] || { why="the example is rejected: $(printf '%s' "$out" | tr '\n' ' ')"; return 1; }
  [[ "$out" == *"errors: 0, warnings: 0"* ]] || { why="expected no errors or warnings: $out"; return 1; }
}

# Takes the specification out of the first figure of the example, in two ways: only the list of
# elements, or everything under the heading. Either copy is rejected and the slide is named.
rejects_missing_figure() {
  need "$VALIDATOR" "$EXAMPLE" || return 1
  local variant n
  for variant in elements everything; do
    n="$(python3 - "$EXAMPLE" "$T/no-figure.md" "$variant" <<'PY'
import re, sys
source, target, variant = sys.argv[1:]
lines = open(source, encoding="utf-8").read().split("\n")
slide = heading = None
for i, line in enumerate(lines):
    found = re.match(r"^## Slide (\d+) / \d+ ", line)
    if found:
        slide = int(found.group(1))
    if re.match(r"^### Figure\s*$", line):
        heading = i
        break
if heading is None:
    sys.exit(1)
end = heading + 1
while end < len(lines) and not re.match(r"^(---\s*$|## |### )", lines[end]):
    end += 1
body = lines[heading + 1:end]
if variant == "elements":
    body = [line for line in body if not re.match(r"^\s*([-*]\s|\**Elements\b)", line)]
else:
    body = [""]
open(target, "w", encoding="utf-8").write("\n".join(lines[:heading + 1] + body + lines[end:]))
print(slide)
PY
)" || { why="the example has no ### Figure section"; return 1; }
    validate "$T/no-figure.md"
    [ "$status" -ne 0 ] || { why="a figure without its $variant was accepted: $out"; return 1; }
    [[ "$out" == *"slide[$n/"* ]] || { why="slide $n was not named: $out"; return 1; }
  done
}

# Rewrites the example's headings with the other spelling that scripts/outline-headings.json lists.
# The copy passes, and the same copy without the first figure's elements is rejected, so the other
# spellings are read and not skipped. With "drop", the first figure keeps only its heading.
other_spelling() {
  python3 - "$EXAMPLE" "$SKILL_DIR/scripts/outline-headings.json" "$1" "$2" <<'PY'
import json, re, sys
source, headings_path, target, mode = sys.argv[1:]
headings = json.load(open(headings_path, encoding="utf-8"))
out, dropping, dropped = [], False, False
for line in open(source, encoding="utf-8").read().split("\n"):
    for key in ("takeaway", "explanation", "figure"):
        if re.match(r"^###\s+" + re.escape(headings[key][0]) + r"\s*$", line):
            line = "### " + headings[key][1]
    if re.match(r"^\**" + re.escape(headings["elements"][0]) + r"\**\s*:?\s*\**\s*$", line):
        line = headings["elements"][1] + "。"
    if mode == "drop" and not dropped:
        if line == "### " + headings["figure"][1]:
            dropping = True
            out.append(line)
            continue
        if dropping:
            if re.match(r"^(---\s*$|## |### )", line):
                dropping, dropped = False, True
            else:
                continue
    out.append(line)
open(target, "w", encoding="utf-8").write("\n".join(out))
PY
}

accepts_other_spellings() {
  need "$VALIDATOR" "$EXAMPLE" "$SKILL_DIR/scripts/outline-headings.json" || return 1
  other_spelling "$T/other.md" keep || { why="could not rewrite the headings"; return 1; }
  grep -qE '^### Takeaway' "$T/other.md" && { why="the rewritten copy still has the English headings"; return 1; }
  validate "$T/other.md"
  [ "$status" -eq 0 ] || { why="the copy with the other spellings is rejected: $(printf '%s' "$out" | tr '\n' ' ')"; return 1; }
  other_spelling "$T/other-no-figure.md" drop || { why="could not rewrite the headings"; return 1; }
  validate "$T/other-no-figure.md"
  [ "$status" -ne 0 ] || { why="a figure without elements was accepted under the other spelling: $out"; return 1; }
}

check "the plugin holds the two skills by name" holds_two_skills
check "the private-name scan lists only general shapes" scan_lists_general_shapes
check "the private-name scan finds a planted line of each shape" scan_finds_planted_shapes
check "the private-name scan passes placeholders and plain words" scan_passes_placeholders
check "the private-name scan finds shapes planted in a copy of the plugin" scan_finds_shapes_in_plugin_copy
check "no file holds a home path, a local agent path, or an issue reference" no_local_names
check "the changelog says the name scan looks only for general shapes" changelog_names_general_shapes
check "the SKILL.md files name no agent or its tool" no_agent_names
check "the readability rules hold only general code words" general_code_words
check "the validator uses only the standard library" standard_library_only
check "the validator runs from any folder" runs_from_any_folder
check "the example outline passes the validator" example_passes
check "the validator rejects a page without a figure" rejects_missing_figure
check "the validator accepts the other heading spellings" accepts_other_spellings

printf '\n%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
