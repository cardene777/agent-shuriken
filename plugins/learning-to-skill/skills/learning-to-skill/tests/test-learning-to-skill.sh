#!/usr/bin/env bash
# Tests for learning_to_skill.py against throwaway projects under a throwaway HOME.
# Nothing here reaches the network or touches a real project.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../scripts/learning_to_skill.py"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }

export HOME="$T/home"
unset CLAUDE_CONFIG_DIR CODEX_HOME
mkdir -p "$HOME"

l2s() { python3 "$SCRIPT" "$@"; }
# row <output> <path>: the line of the files table for that path.
row() { printf '%s\n' "$1" | awk -v p="  $2 " 'index($0, p) == 1'; }
# fp <propose arguments>: the fingerprint that propose prints.
fp() { python3 "$SCRIPT" propose "$@" 2>/dev/null | awk '$1 == "Fingerprint" { print $2 }'; }
sum() { python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"; }
mode() { python3 -c 'import os,sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$1"; }

write_agents() {
  cat > "$1" <<'MD'
# Shop

## Build

- Use `pnpm`, not `npm`.
- Run `pnpm build` before pushing.

## Testing

Tests live in `test/`.

## Style

- Keep functions short.

## Examples

```text
## Fake
```

## Notes

- First note.

## Notes

- Second note.
MD
}

# --- a project with most kinds of files
P="$T/shop"
mkdir -p "$P/.git" "$P/web" "$P/.github" "$P/.claude/skills/release/references" "$P/plugins/tool/skills/tool" \
  "$P/node_modules/pkg" "$P/.claude/worktrees/wt" "$P/vendored/.git" "$P/big" "$T/elsewhere/linked"
write_agents "$P/AGENTS.md"
printf '@AGENTS.md\n\nSee `@not/imported.md` for nothing.\n' > "$P/CLAUDE.md"
printf -- '- Run `pnpm build` before pushing.\n' > "$P/.github/copilot-instructions.md"
printf '# Web\n\n- Use the components in `web/ui`.\n' > "$P/web/AGENTS.md"
printf -- '---\nname: release\ndescription: Release the shop.\n# comment\n---\n\n# Release\n\n1. Tag it.\n' \
  > "$P/.claude/skills/release/SKILL.md"
printf 'Notes.\n' > "$P/.claude/skills/release/references/notes.md"
printf -- '---\nname: linked\ndescription: A skill kept elsewhere.\n---\n\nBody.\n' > "$T/elsewhere/linked/SKILL.md"
ln -s "$T/elsewhere/linked" "$P/.claude/skills/linked"
printf -- '---\nname: tool\ndescription: A skill this project ships.\n---\n\nBody.\n' > "$P/plugins/tool/skills/tool/SKILL.md"
printf -- '- Hidden in dependencies.\n' > "$P/node_modules/pkg/AGENTS.md"
printf 'gitdir: elsewhere\n' > "$P/.claude/worktrees/wt/.git"
printf -- '- Inside a worktree.\n' > "$P/.claude/worktrees/wt/AGENTS.md"
printf -- '- Inside another repository.\n' > "$P/vendored/AGENTS.md"
python3 -c '
import sys
with open(sys.argv[1], "w") as f:
    for i in range(210):
        f.write("- rule %d " % i + "word " * 32 + "\n")
' "$P/big/AGENTS.md"

out="$(l2s files --root "$P")"; rc=$?
check "files exits 0" '[ "$rc" = 0 ]'
check "a file imported with @path is read by Claude Code through the import" \
  'row "$out" AGENTS.md | grep -q "Claude Code (imported by CLAUDE.md)"'
check "with a CLAUDE.md in the project, Claude Code does not read AGENTS.md on its own" \
  '! row "$out" AGENTS.md | grep -q "the project has no CLAUDE.md"'
check "the importing file names what it imports, and an @path in inline code is not an import" \
  'row "$out" CLAUDE.md | grep -q "imports AGENTS.md" && ! printf "%s\n" "$out" | grep -q "not/imported"'
check "Codex and GitHub Copilot CLI read the root AGENTS.md" 'row "$out" AGENTS.md | grep -q "Codex, GitHub Copilot CLI"'
check "a nested AGENTS.md is scoped to its folder" 'row "$out" web/AGENTS.md | grep -q "for work in web/"'
check "files under node_modules are not listed" '! printf "%s\n" "$out" | grep -q "node_modules"'
check "worktrees and nested repositories are not searched" \
  '! printf "%s\n" "$out" | grep -qE "worktrees|vendored"'
check "a project skill names its agents and counts the other .md files in its folder" \
  'row "$out" .claude/skills/release/SKILL.md | grep -q "Claude Code, GitHub Copilot CLI; 1 more .md file in the skill folder"'
check "a skill linked into .claude/skills is found" '[ -n "$(row "$out" .claude/skills/linked/SKILL.md)" ]'
check "a skill outside an agent skill folder is loaded by no agent" \
  'row "$out" plugins/tool/skills/tool/SKILL.md | grep -q "no agent; no agent loads it from here"'
check "the agent view says what Gemini CLI would read" \
  'printf "%s\n" "$out" | grep -q "^  Gemini CLI          nothing (it reads GEMINI.md, which is missing)"'
check "the agent view lists Claude Code files read by name first" \
  'printf "%s\n" "$out" | grep -q "^  Claude Code         CLAUDE.md, AGENTS.md (imported by CLAUDE.md)$"'
check "the file that reaches the most agents is named" \
  'printf "%s\n" "$out" | grep -q "^AGENTS.md reaches the most agents: Claude Code, Codex, GitHub Copilot CLI.$"'
check "a line repeated in two files is listed with both places" \
  'printf "%s\n" "$out" | grep -q "AGENTS.md:6, .github/copilot-instructions.md:1"'
check "a file over 200 lines is flagged" 'printf "%s\n" "$out" | grep -q "big/AGENTS.md  210 lines, over the budget of 200"'
check "AGENTS.md files over 32 KiB from the root down are flagged for Codex" \
  'printf "%s\n" "$out" | grep -q "big/AGENTS.md  Codex reads at most 32 KiB"'
real_p="$(cd "$P" && pwd -P)"
sub_out="$(cd "$P/web" && l2s files)"
check "the project is found from a subfolder" '[ "$(printf "%s\n" "$sub_out" | head -1)" = "Instruction files in $real_p" ]'
json="$(l2s files --root "$P" --json)"
check "--json parses and gives the readers of each file" \
  'printf "%s" "$json" | python3 -c "import json,sys; d=json.load(sys.stdin); a=[f for f in d[\"files\"] if f[\"path\"]==\"AGENTS.md\"][0]; sys.exit(0 if {r[\"agent\"] for r in a[\"readers\"]}=={\"Codex\",\"GitHub Copilot CLI\",\"Claude Code\"} and d[\"widest\"]==\"AGENTS.md\" else 1)"'

# --- the home folder
mkdir -p "$HOME/.claude/skills/notes" "$T/codexhome"
printf -- '- Answer in short sentences.\n' > "$HOME/.claude/CLAUDE.md"
printf -- '---\nname: notes\ndescription: Notes.\n---\n' > "$HOME/.claude/skills/notes/SKILL.md"
printf -- '- Prefer small diffs.\n' > "$T/codexhome/AGENTS.md"
home_out="$(CODEX_HOME="$T/codexhome" l2s files --root "$P" --home)"
check "--home lists ~/.claude/CLAUDE.md for every project" \
  'row "$home_out" "~/.claude/CLAUDE.md" | grep -q "Claude Code; every project"'
check "--home follows CODEX_HOME" '[ -n "$(row "$home_out" "$T/codexhome/AGENTS.md")" ]'
check "--home lists the home skill folders" \
  'printf "%s\n" "$home_out" | grep -q "~/.claude/skills  1 skill, read by Claude Code, GitHub Copilot CLI: notes"'
check "--home adds the home files to the agent view" \
  'printf "%s\n" "$home_out" | grep -q "^  Claude Code         CLAUDE.md, ~/.claude/CLAUDE.md (every project), AGENTS.md (imported by CLAUDE.md)$"'
no_home_out="$(CODEX_HOME="$T/codexhome" l2s files --root "$P")"
check "without --home, nothing in the home folder is listed" \
  '! printf "%s\n" "$no_home_out" | grep -qE "~/|codexhome"'

# --- a project without CLAUDE.md, with Gemini settings and an override
Q="$T/solo"
mkdir -p "$Q/.git" "$Q/.gemini" "$Q/sub"
printf -- '- Ship small changes.\n' > "$Q/AGENTS.md"
printf '{"context": {"fileName": ["AGENTS.md"]}}\n' > "$Q/.gemini/settings.json"
printf -- '- Sub rule.\n' > "$Q/sub/AGENTS.md"
printf -- '- Sub override.\n' > "$Q/sub/AGENTS.override.md"
out="$(l2s files --root "$Q")"
check "without a CLAUDE.md, Claude Code reads AGENTS.md" 'row "$out" AGENTS.md | grep -q "Claude Code (the project has no CLAUDE.md)"'
check "context.fileName in .gemini/settings.json makes Gemini CLI read AGENTS.md" \
  'row "$out" AGENTS.md | grep -q "Gemini CLI" && printf "%s\n" "$out" | grep -q "^Gemini CLI reads AGENTS.md, as .gemini/settings.json says.$"'
check "AGENTS.override.md takes Codex away from AGENTS.md in its folder" \
  'row "$out" sub/AGENTS.md | grep -q "Codex reads AGENTS.override.md here instead" && ! row "$out" sub/AGENTS.md | grep -q "  Codex" && row "$out" sub/AGENTS.override.md | grep -q "Codex"'

# --- a project whose CLAUDE.md is a link and whose GEMINI.md imports AGENTS.md
L="$T/linked"
mkdir -p "$L/.git"
write_agents "$L/AGENTS.md"
ln -s AGENTS.md "$L/CLAUDE.md"
printf '@AGENTS.md\n' > "$L/GEMINI.md"
out="$(l2s files --root "$L")"
check "a link is shown as a link, and its readers reach the file it points at" \
  'row "$out" CLAUDE.md | grep -q "link to AGENTS.md" && row "$out" AGENTS.md | grep -q "Claude Code (through the link CLAUDE.md)"'
check "a GEMINI.md that imports AGENTS.md gives AGENTS.md to Gemini CLI" \
  'row "$out" AGENTS.md | grep -q "Gemini CLI (imported by GEMINI.md)"'

# --- check
out="$(l2s check --root "$P" --text '- Use `pnpm`, not `npm`.')"; rc=$?
check "an exact copy is reported as same and exits 1" '[ "$rc" = 1 ] && printf "%s\n" "$out" | grep -q "same  AGENTS.md:5"'
out="$(l2s check --root "$P" --text 'Use pnpm instead of npm')"; rc=$?
check "a close line is reported with its score" '[ "$rc" = 1 ] && printf "%s\n" "$out" | grep -qE "^  0\.[5-9][0-9]  AGENTS.md:5"'
out="$(l2s check --root "$P" --text 'Deploy only on Tuesdays')"; rc=$?
check "an unrelated rule is reported as nothing similar and exits 0" '[ "$rc" = 0 ] && printf "%s\n" "$out" | grep -q "nothing similar"'
J="$T/nospace"
mkdir -p "$J/.git"
# Japanese text built from code points, so this file stays ASCII: "write the test first, then implement".
jp_line="$(python3 -c 'print("- " + "".join(map(chr, [0x30c6, 0x30b9, 0x30c8, 0x3092, 0x5148, 0x306b, 0x66f8, 0x3044, 0x3066, 0x304b, 0x3089, 0x5b9f, 0x88c5, 0x3059, 0x308b])))')"
jp_rule="$(python3 -c 'print("".join(map(chr, [0x30c6, 0x30b9, 0x30c8, 0x3092, 0x5148, 0x306b, 0x66f8, 0x304f])))')"
printf '%s\n' "$jp_line" > "$J/AGENTS.md"
l2s check --root "$J" --text "$jp_rule" >/dev/null; rc=$?
check "rules written without spaces between words are compared" '[ "$rc" = 1 ]'

# --- propose
E="$T/edit"
mkdir -p "$E/.git" "$E/.claude/skills/empty" "$E/sub"
write_agents "$E/AGENTS.md"
printf '# Readme\n' > "$E/README.md"
printf -- '---\nname: empty\ndescription: Nothing yet.\n---\n' > "$E/.claude/skills/empty/SKILL.md"
before="$(sum "$E/AGENTS.md")"
out="$(cd "$E" && l2s propose --file AGENTS.md --section Testing --text '- Run `pnpm test` before every commit.')"; rc=$?
check "propose exits 0 and names the place" '[ "$rc" = 0 ] && printf "%s\n" "$out" | grep -q "^Placement  at the end of the section \"Testing\", after line 10$"'
check "propose shows the added line in a diff" 'printf "%s\n" "$out" | grep -q "^+- Run \`pnpm test\` before every commit.$"'
check "propose says who reads the file" 'printf "%s\n" "$out" | grep -q "^Read by    Codex, GitHub Copilot CLI, Claude Code (the project has no CLAUDE.md)$"'
check "propose prints a fingerprint" 'printf "%s\n" "$out" | grep -qE "^Fingerprint  [0-9a-f]{16}$"'
check "propose writes nothing" '[ "$(sum "$E/AGENTS.md")" = "$before" ]'
(cd "$E" && l2s propose --file AGENTS.md --section Build --text '- Use `pnpm`, not `npm`.' >/dev/null 2>"$T/err"); rc=$?
check "a line already in the file is refused with exit 1" '[ "$rc" = 1 ] && grep -q "already in AGENTS.md at line 5" "$T/err"'
(cd "$E" && l2s propose --file AGENTS.md --section Deploy --text '- x y z' >/dev/null 2>"$T/err"); rc=$?
check "a missing section is refused with the list of headings" '[ "$rc" = 1 ] && grep -q "line 3  ## Build" "$T/err"'
(cd "$E" && l2s propose --file AGENTS.md --section Notes --text '- x y z' >/dev/null 2>"$T/err"); rc=$?
check "two sections with the same heading are refused" '[ "$rc" = 1 ] && grep -q "More than one section" "$T/err"'
(cd "$E" && l2s propose --file AGENTS.md --section Fake --text '- x y z' >/dev/null 2>&1); rc=$?
check "a heading inside a code fence is not a section" '[ "$rc" = 1 ]'
(cd "$E" && l2s propose --file "$P/.claude/skills/release/SKILL.md" --root "$P" --section comment --text 'x' >/dev/null 2>&1); rc=$?
check "a comment in YAML frontmatter is not a section" '[ "$rc" = 1 ]'
(cd "$E" && l2s propose --file README.md --text '- x' >/dev/null 2>&1); rc=$?
check "a file that is not an instruction file is refused with exit 2" '[ "$rc" = 2 ]'
(cd "$E" && l2s propose --file AGENTS.md --text "$(printf 'one\ntwo')" >/dev/null 2>&1); rc=$?
check "a --text value with a line break is refused with exit 2" '[ "$rc" = 2 ]'
(cd "$E" && l2s propose --file GEMINI.md --text '- x' >/dev/null 2>&1); rc=$?
check "a missing file is refused without --create" '[ "$rc" = 2 ]'
out="$(cd "$E" && l2s propose --file GEMINI.md --create --text '- Run `pnpm build` before every push.')"
check "with --create, the diff starts a new file" \
  'printf "%s\n" "$out" | grep -q "^--- /dev/null$" && printf "%s\n" "$out" | grep -q "^+++ b/GEMINI.md$"'
check "propose lists similar lines in the other files" \
  'printf "%s\n" "$out" | grep -qE "^  0\.[5-9][0-9]  AGENTS.md:6  - Run \`pnpm build\` before pushing.$"'
check "propose says which agents will read a new file" 'printf "%s\n" "$out" | grep -q "^Read by    Gemini CLI, GitHub Copilot CLI$"'
printf -- '- Another project.\n' > "$T/elsewhere/AGENTS.md"
(cd "$E" && l2s propose --file "$T/elsewhere/AGENTS.md" --text '- x' >/dev/null 2>"$T/err"); rc=$?
check "a file outside the project and the home agent folders is refused" '[ "$rc" = 2 ] && grep -q "is outside the project" "$T/err"'

# --- apply
args=(--file AGENTS.md --section Build --text '- Never commit `.env` files.')
f1="$(cd "$E" && fp "${args[@]}")"
(cd "$E" && l2s apply "${args[@]}" --expect 0000000000000000 >/dev/null 2>"$T/err"); rc=$?
check "apply with another fingerprint exits 3 and writes nothing" '[ "$rc" = 3 ] && [ "$(sum "$E/AGENTS.md")" = "$before" ]'
(cd "$E" && l2s apply --file AGENTS.md --section Build --text '- Never commit secrets.' --expect "$f1" >/dev/null 2>&1); rc=$?
check "apply with lines other than the proposed ones exits 3" '[ "$rc" = 3 ] && [ "$(sum "$E/AGENTS.md")" = "$before" ]'
chmod 640 "$E/AGENTS.md"
out="$(cd "$E" && l2s apply "${args[@]}" --expect "$f1")"; rc=$?
check "apply with the printed fingerprint exits 0" '[ "$rc" = 0 ] && printf "%s\n" "$out" | grep -q "^Wrote 1 line to AGENTS.md"'
check "apply keeps the permissions of the file" '[ "$(mode "$E/AGENTS.md")" = 0o640 ]'
args=(--file AGENTS.md --section Testing --text '- Run `pnpm test` before every commit.')
(cd "$E" && l2s apply "${args[@]}" --expect "$(fp "${args[@]}")" >/dev/null)
args=(--file AGENTS.md --new-section Releases --text '- Tag every release.')
(cd "$E" && l2s apply "${args[@]}" --expect "$(fp "${args[@]}")" >/dev/null)
args=(--file AGENTS.md --replace-line 27 --text '- First note, rewritten.')
out="$(cd "$E" && l2s propose "${args[@]}")"
check "--replace-line shows the old line removed and the new one added" \
  'printf "%s\n" "$out" | grep -q "^-- First note.$" && printf "%s\n" "$out" | grep -q "^+- First note, rewritten.$"'
(cd "$E" && l2s apply "${args[@]}" --expect "$(fp "${args[@]}")" >/dev/null)
cat > "$T/expected.md" <<'MD'
# Shop

## Build

- Use `pnpm`, not `npm`.
- Run `pnpm build` before pushing.
- Never commit `.env` files.

## Testing

Tests live in `test/`.

- Run `pnpm test` before every commit.

## Style

- Keep functions short.

## Examples

```text
## Fake
```

## Notes

- First note, rewritten.

## Notes

- Second note.

## Releases

- Tag every release.
MD
check "lines join a list, follow a paragraph after a blank line, open new sections, and replace lines" \
  'cmp -s "$T/expected.md" "$E/AGENTS.md"'

f2="$(cd "$E" && fp --file AGENTS.md --section Style --text '- Name things plainly.')"
printf '\n- Added by someone else.\n' >> "$E/AGENTS.md"
changed="$(sum "$E/AGENTS.md")"
(cd "$E" && l2s apply --file AGENTS.md --section Style --text '- Name things plainly.' --expect "$f2" >/dev/null 2>&1); rc=$?
check "apply refuses when the file changed after the proposal" '[ "$rc" = 3 ] && [ "$(sum "$E/AGENTS.md")" = "$changed" ]'

args=(--file .claude/skills/empty/SKILL.md --text 'Say what the skill does.')
(cd "$E" && l2s apply "${args[@]}" --expect "$(fp "${args[@]}")" >/dev/null)
check "a file with only frontmatter gets the line after the frontmatter" \
  '[ "$(cat "$E/.claude/skills/empty/SKILL.md")" = "$(printf -- "---\nname: empty\ndescription: Nothing yet.\n---\n\nSay what the skill does.")" ]'

printf '# Sub\r\n\r\n- One.\r\n' > "$E/sub/CLAUDE.md"
args=(--file sub/CLAUDE.md --text '- Two.')
(cd "$E" && l2s apply "${args[@]}" --expect "$(fp "${args[@]}")" >/dev/null)
check "apply keeps CRLF line endings" \
  'python3 -c "import sys; b=open(sys.argv[1],\"rb\").read(); sys.exit(0 if b==b\"# Sub\r\n\r\n- One.\r\n- Two.\r\n\" else 1)" "$E/sub/CLAUDE.md"'

printf '\xef\xbb\xbf# Gemini\n' > "$E/GEMINI.md"
args=(--file GEMINI.md --text '- Keep answers short.')
(cd "$E" && l2s apply "${args[@]}" --expect "$(fp "${args[@]}")" >/dev/null)
check "apply keeps a byte order mark" \
  'python3 -c "import sys; b=open(sys.argv[1],\"rb\").read(); sys.exit(0 if b==b\"\xef\xbb\xbf# Gemini\n\n- Keep answers short.\n\" else 1)" "$E/GEMINI.md"'

args=(--file .github/copilot-instructions.md --create --text '- Use the shared lint config.')
(cd "$E" && l2s apply "${args[@]}" --expect "$(fp "${args[@]}")" >/dev/null); rc=$?
check "apply --create starts the file and its folder" \
  '[ "$rc" = 0 ] && [ "$(cat "$E/.github/copilot-instructions.md")" = "- Use the shared lint config." ]'
check "apply leaves no temporary file behind" \
  '[ -z "$(find "$E" -name ".learning-to-skill-*")" ]'

args=(--file CLAUDE.md --section Style --text '- Prefer early returns.')
(cd "$L" && l2s apply "${args[@]}" --expect "$(fp "${args[@]}")" >/dev/null); rc=$?
check "apply through a link changes the file it points at and keeps the link" \
  '[ "$rc" = 0 ] && [ -L "$L/CLAUDE.md" ] && grep -q "^- Prefer early returns.$" "$L/AGENTS.md"'

args=(--file "$HOME/.claude/CLAUDE.md" --text '- Say when you are unsure.')
out="$(cd "$E" && l2s propose "${args[@]}")"
check "a file in the home folder can be proposed and says it applies to every project" \
  'printf "%s\n" "$out" | grep -q "^Read by    Claude Code, in every project$"'
(cd "$E" && l2s apply "${args[@]}" --expect "$(fp "${args[@]}")" >/dev/null); rc=$?
check "a file in the home folder can be written" '[ "$rc" = 0 ] && grep -q "^- Say when you are unsure.$" "$HOME/.claude/CLAUDE.md"'

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
