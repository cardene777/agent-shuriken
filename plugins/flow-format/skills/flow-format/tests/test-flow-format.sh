#!/usr/bin/env bash
# Tests for the flow-format plugin: which skill it holds, what its SKILL.md says about the answer
# form, whether its good example keeps that form, what no file in it names, and whether the
# repository lists it. Nothing is written outside a throwaway folder.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
PLUGIN_DIR="$(cd "$HERE/../../.." && pwd)"
TOP="$(cd "$PLUGIN_DIR/../.." && pwd)"
NAME=flow-format
SKILL="$SKILL_DIR/SKILL.md"
YAML="$SKILL_DIR/agents/openai.yaml"
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

# need <file>...: every file exists. The reason names the file from the plugin folder.
need() {
  local f
  for f in "$@"; do
    [ -f "$f" ] || { why="${f#"$PLUGIN_DIR"/} is missing"; return 1; }
  done
}

# says <phrase>...: SKILL.md holds every phrase, ignoring case. The reason names the first missing one.
says() {
  local phrase
  need "$SKILL" || return 1
  for phrase in "$@"; do
    grep -qiF -- "$phrase" "$SKILL" || { why="SKILL.md does not say \"$phrase\""; return 1; }
  done
}

# The frontmatter of SKILL.md, without the two --- lines.
frontmatter() {
  awk 'NR == 1 && $0 == "---" { on = 1; next } on && $0 == "---" { exit } on' "$SKILL"
}

holds_one_skill() {
  local found
  found="$(cd "$PLUGIN_DIR/skills" 2>/dev/null && LC_ALL=C ls -d -- */ 2>/dev/null | tr -d / | tr '\n' ' ')"
  [ "$found" = "$NAME " ] || { why="skills/ holds: ${found:-nothing}"; return 1; }
  need "$SKILL" "$YAML" || return 1
  grep -qx "name: $NAME" "$SKILL" || { why="SKILL.md does not say name: $NAME"; return 1; }
}

description_says_when() {
  need "$SKILL" || return 1
  local description word
  description="$(frontmatter | sed -n 's/^description: //p')"
  [ -n "$description" ] || { why="the frontmatter has no one-line description"; return 1; }
  for word in 'flow' 'procedure' 'chain of steps' 'workflow' 'Not for a question about one file or one idea'; do
    grep -qiF -- "$word" <<< "$description" || { why="the description does not say \"$word\": $description"; return 1; }
  done
}

starts_without_being_named() {
  need "$SKILL" "$YAML" || return 1
  grep -qE '^  allow_implicit_invocation: true$' "$YAML" \
    || { why="agents/openai.yaml does not set allow_implicit_invocation: true"; return 1; }
  ! frontmatter | grep -qE '^disable-model-invocation: *true' \
    || { why="SKILL.md sets disable-model-invocation: true"; return 1; }
}

gives_step_form() {
  says 'numbered steps' 'starts with a verb' 'blank line after the action sentence' \
    'not indented' 'one to three sentences' 'blank line between steps'
}

# good_example_form [file]: prints nothing when the first fence under "## Good example" of the file
# (SKILL.md by default) is an answer of six numbered steps from an issue to a merge, each an action
# sentence that starts with a verb, a blank line, and an unindented paragraph of one to three
# sentences, one per line, with a blank line between steps. Otherwise prints the first problem.
good_example_form() {
  python3 -I - "${1:-$SKILL}" <<'PY'
import re, sys
lines = open(sys.argv[1], encoding="utf-8").read().split("\n")
try:
    start = lines.index("## Good example")
except ValueError:
    print("SKILL.md has no '## Good example' heading"); sys.exit()
body, inside = [], False
for line in lines[start + 1:]:
    if line.startswith("## "):
        break
    if line.startswith("```"):
        if inside:
            break
        inside = True
        continue
    if inside:
        body.append(line)
if not body:
    print("the good example has no fenced answer"); sys.exit()
while body and body[-1] == "":
    body.pop()
not_verbs = {"the", "a", "an", "this", "that", "then", "next", "first", "step", "after", "when", "it"}
one_sentence = re.compile(r"^[^\s].*[.!?]$")
second_sentence = re.compile(r"[.!?] [A-Z]")
steps, i = [], 0
while i < len(body):
    m = re.match(r"^(\d+)\. (.+)$", body[i])
    if not m:
        print(f"line {i + 1} of the answer is not a numbered step: {body[i]!r}"); sys.exit()
    number, action = int(m.group(1)), m.group(2)
    if number != len(steps) + 1:
        print(f"step {number} comes where step {len(steps) + 1} should be"); sys.exit()
    first = action.split()[0].strip(",.").lower()
    if first in not_verbs or not action[0].isupper():
        print(f"step {number} does not start with a verb: {action!r}"); sys.exit()
    if not one_sentence.match(action) or second_sentence.search(action):
        print(f"step {number} is not one action sentence: {action!r}"); sys.exit()
    if i + 1 >= len(body) or body[i + 1] != "":
        print(f"step {number} has no blank line after the action sentence"); sys.exit()
    i += 2
    paragraph = []
    while i < len(body) and body[i] != "":
        paragraph.append(body[i]); i += 1
    if not 1 <= len(paragraph) <= 3:
        print(f"the paragraph of step {number} has {len(paragraph)} lines, not one to three"); sys.exit()
    for line in paragraph:
        if line[0].isspace() or re.match(r"^(\d+\.|[-*]) ", line):
            print(f"the paragraph of step {number} is indented or a list: {line!r}"); sys.exit()
        if not one_sentence.match(line) or second_sentence.search(line):
            print(f"a line of step {number} is not one sentence: {line!r}"); sys.exit()
    if i < len(body):
        i += 1
        if i < len(body) and body[i] == "":
            print(f"step {number} is followed by more than one blank line"); sys.exit()
    steps.append(action.lower())
topics = ["issue", "branch", "test", "pull request", "review", "merge"]
if len(steps) != len(topics):
    print(f"the answer has {len(steps)} steps, not {len(topics)}"); sys.exit()
for number, (action, topic) in enumerate(zip(steps, topics), 1):
    if topic not in action:
        print(f"step {number} does not name the {topic}: {action!r}"); sys.exit()
PY
}

good_example_keeps_form() {
  need "$SKILL" || return 1
  local problem
  # The parser itself must refuse a broken answer, or a pass below says nothing.
  printf '## Good example\n\n```text\n1. The issue is opened.\n\nIt says what to change.\n```\n' > "$T/broken.md"
  problem="$(good_example_form "$T/broken.md")"
  [ -n "$problem" ] || { why="the parser accepted a step that starts with \"The\""; return 1; }
  problem="$(good_example_form)"
  [ -z "$problem" ] || { why="$problem"; return 1; }
}

allows_text_diagram() {
  says 'plain-text diagram' 'after the steps' 'branches or loops'
}

keeps_mermaid_out() {
  says 'Do not write Mermaid in a chat answer' 'a file the person asked for'
}

answers_in_their_language() {
  says 'in the language the person writes in'
}

# other_names <file>: prints line:text for every slash command, $ skill name, or <plugin>:<skill>
# name in the file, leaving out the skill's own name.
other_names() {
  python3 -I - "$1" "$NAME" <<'PY'
import re, sys
path, own = sys.argv[1], sys.argv[2]
shapes = [
    r"(?:^|[\s(`\"'])/[a-z][a-z0-9-]*(?::[a-z][a-z0-9-]*)?\b",
    r"(?:^|[\s(`\"'])\$[a-z][a-z0-9-]+\b",
    r"\b[a-z][a-z0-9-]*:[a-z][a-z0-9-]+\b",
]
pattern = re.compile("|".join(shapes))
for number, line in enumerate(open(path, encoding="utf-8"), 1):
    for hit in pattern.findall(line.replace(f"{own}:{own}", "")):
        print(f"{number}:{hit.strip()}")
PY
}

names_no_other_skill() {
  need "$SKILL" || return 1
  local hits
  {
    printf 'run /%s first\n' review
    printf 'type $%s in the box\n' review
    printf 'call %s:%s\n' tools review
    printf 'plain words, docs/adr/page.md, 10:30, and %s:%s\n' "$NAME" "$NAME"
  } > "$T/names.md"
  hits="$(other_names "$T/names.md" | cut -d: -f1 | tr '\n' ' ')"
  [ "$hits" = "1 2 3 " ] || { why="the name scan found lines ${hits:-none} of the planted file, not 1 2 3"; return 1; }
  hits="$(other_names "$SKILL")"
  [ -z "$hits" ] || { why="SKILL.md names: $(printf '%s ' $hits)"; return 1; }
}

no_agent_names() {
  need "$SKILL" || return 1
  local hit key
  # A folder such as .claude/ is a path, not the agent's name.
  hit="$(grep -inE '(^|[^.a-z])(askuserquestion|claude|codex|chatgpt|gpt-?[0-9]|opus|sonnet|haiku|gemini|copilot|cursor)' "$SKILL" | head -1)"
  [ -z "$hit" ] || { why="SKILL.md names an agent, its tool, or a model: $hit"; return 1; }
  for key in allowed-tools context agent; do
    ! frontmatter | grep -q "^$key:" || { why="SKILL.md has $key in its frontmatter"; return 1; }
  done
}

# Prints file:line for every line under the folders given that holds a home path, a local agent
# path, or an issue reference. Each shape is a general form, and none spells out the text it finds.
names_of_this_pc() {
  python3 -I - "$@" <<'PY'
import os, re, sys
shapes = {
    "home path": r"/(?:Users|home)/[^/\s]+/",
    "local agent path": r"~/\.(?:claude|codex)/",
    "issue reference": r"\b(?:GH|Issue) #\d+",
}
pattern = re.compile("|".join(shapes.values()))
images = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico")
for top in sys.argv[1:]:
    for folder, _, files in os.walk(top):
        for name in sorted(files):
            path = os.path.join(folder, name)
            if name.lower().endswith(images):
                continue
            with open(path, encoding="utf-8", errors="ignore") as source:
                for number, line in enumerate(source, 1):
                    if pattern.search(line):
                        print(f"{os.path.relpath(path, top)}:{number}")
PY
}

# The scan finds each shape planted at the end of SKILL.md in a copy of the plugin, one per line, and
# nothing in the line of plain words. The shapes are printed from parts so that this file does not
# hold them.
scan_finds_planted_shapes() {
  need "$SKILL" || return 1
  local hits expected="" n lines
  mkdir -p "$T/control"
  cp -R "$PLUGIN_DIR" "$T/control/$NAME"
  lines="$(wc -l < "$SKILL" | tr -d ' ')"
  {
    printf '/%s/someone/notes.md\n' Users
    printf '/%s/someone/notes.md\n' home
    printf '~/.%s/settings.json\n' claude
    printf '~/.%s/config.toml\n' codex
    printf 'fixed in %s #%d\n' GH 12
    printf 'see %s #%d\n' Issue 3
    printf 'plain words, a docs/home/page.md link, and #12 alone\n'
  } >> "$T/control/$NAME/skills/$NAME/SKILL.md"
  for n in 1 2 3 4 5 6; do expected="${expected}skills/$NAME/SKILL.md:$((lines + n)) "; done
  hits="$(names_of_this_pc "$T/control/$NAME" | grep -v '^skills/[^/]*/tests/' | tr '\n' ' ')"
  [ "$hits" = "$expected" ] || { why="expected ${expected}observed: ${hits:-nothing}"; return 1; }
}

no_local_names() {
  need "$SKILL" || return 1
  local hits
  hits="$(names_of_this_pc "$PLUGIN_DIR")"
  [ -z "$hits" ] || { why="found at: $(printf '%s ' $hits)"; return 1; }
}

repository_lists_it() {
  local file first
  # The question table has a column per plugin, so its header is the one line naming the first
  # plugin folder and this plugin as cells.
  first="$(cd "$TOP/plugins" && LC_ALL=C ls -d -- */ | head -1 | tr -d /)"
  jq -e --arg n "$NAME" '[.plugins[] | select(.name == $n and .source == "./plugins/" + $n)] | length == 1' \
    "$TOP/.claude-plugin/marketplace.json" > /dev/null \
    || { why=".claude-plugin/marketplace.json does not list $NAME once from ./plugins/$NAME"; return 1; }
  for file in README.md README.ja.md; do
    grep -qE "^\| \[$NAME\]\(plugins/$NAME\) \|" "$TOP/$file" || { why="$file has no table row for $NAME"; return 1; }
  done
  for file in docs/publishing.md docs/publishing.ja.md; do
    grep -qE "^\| $NAME \|" "$TOP/$file" || { why="$file has no status row for $NAME"; return 1; }
    grep -F "| $first |" "$TOP/$file" | grep -qF "| $NAME |" \
      || { why="the question table of $file has no column for $NAME"; return 1; }
  done
  root_changelog_names "$TOP/CHANGELOG.md" \
    || { why="CHANGELOG.md names $NAME neither under ## [Unreleased] nor in the newest release's Plugins table"; return 1; }
}

# root_changelog_names <file>: the root changelog names the plugin with a line under ## [Unreleased]
# that starts with "The <name> plugin".
root_changelog_names() {
  local unreleased
  unreleased="$(awk '/^## \[Unreleased\]/ { on = 1; next } /^## \[/ { on = 0 } on' "$1")"
  grep -qE "^- The $NAME plugin" <<< "$unreleased"
}

# changelog_case <file> <form>: writes a root changelog that names the plugin under Unreleased
# (unreleased), only in the Plugins table of the newest release (newest), only in the table of an
# older release (older), or nowhere (none).
changelog_case() {
  {
    printf '# Changelog\n\n## [Unreleased]\n\n'
    [ "$2" = unreleased ] && printf -- '- The %s plugin, which explains a flow\n' "$NAME"
    printf -- '- A change to the repository itself\n\n## [0.2.0] - 2026-12-01\n\n### Plugins\n\n| Plugin | Version |\n|---|---|\n| convey | 0.3.0 |\n'
    [ "$2" = newest ] && printf '| %s | 0.1.0 |\n' "$NAME"
    printf '\n## [0.1.0] - 2026-11-01\n\n### Plugins\n\n| Plugin | Version |\n|---|---|\n| convey | 0.2.0 |\n'
    [ "$2" = older ] && printf '| %s | 0.1.0 |\n' "$NAME"
    printf '\n'
  } > "$1"
}

accepts_the_newest_release() {
  changelog_case "$T/newest.md" newest
  root_changelog_names "$T/newest.md" || { why="a changelog naming $NAME only in the newest release's Plugins table was refused"; return 1; }
}

accepts_the_unreleased_line() {
  changelog_case "$T/unreleased.md" unreleased
  root_changelog_names "$T/unreleased.md" || { why="a changelog naming $NAME under ## [Unreleased] was refused"; return 1; }
}

refuses_neither() {
  local form
  for form in none older; do
    changelog_case "$T/$form.md" "$form"
    ! root_changelog_names "$T/$form.md" || { why="a changelog naming $NAME in the $form form was accepted"; return 1; }
  done
}

check "the plugin holds one skill of its name" holds_one_skill
check "the description says when it starts and when it does not" description_says_when
check "the agent can start the skill without being named" starts_without_being_named
check "the SKILL.md gives the numbered step form" gives_step_form
check "the good example walks from an issue to a merge in six steps of the form" good_example_keeps_form
check "the SKILL.md allows a text diagram after the steps" allows_text_diagram
check "the SKILL.md keeps Mermaid out of the chat answer" keeps_mermaid_out
check "the SKILL.md answers in the person's language" answers_in_their_language
check "the SKILL.md names no other skill or command" names_no_other_skill
check "the SKILL.md names no agent or its tool" no_agent_names
check "no file holds a home path, a local agent path, or an issue reference" no_local_names
check "the scan finds a planted line of each shape" scan_finds_planted_shapes
check "the repository lists flow-format" repository_lists_it
check "the root changelog check accepts the newest release's Plugins table" accepts_the_newest_release
check "the root changelog check accepts the line under Unreleased" accepts_the_unreleased_line
check "the root changelog check refuses a changelog that names neither" refuses_neither

printf 'checks: %d\n' "$((PASS + FAIL))"
printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
