#!/bin/bash
# Checks that the repository is consistent and safe to publish.
# Usage: bash scripts/check.sh
# Prints one line per check. Exits 0 when no check fails and 1 when any check fails.
# A check whose tool is missing is reported as "skip" and does not fail the run.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root" || exit 1

# Files whose Japanese text is intended: the `ja` dictionaries of the HTML pages,
# and words that scripts match on Japanese websites and emails.
JA_ALLOWED=(
  skills/account-cleanup/templates/sheet.html
  skills/account-cleanup/templates/followups.html
  skills/account-cleanup/scripts/browser.mjs
  skills/account-cleanup/scripts/connections-guide.sh
  skills/account-cleanup/scripts/subscriptions-guide.sh
  skills/pc-tidy/scripts/tidy.py
)
# Third-party files copied unmodified; they are checked only for valid syntax.
VENDORED=(skills/account-cleanup/data/sites.json)

pass=0 fail=0 skip=0

# Tracked and new files that exist in the working tree.
all_files() {
  git ls-files --cached --others --exclude-standard | while IFS= read -r f; do
    [ -f "$f" ] && printf '%s\n' "$f"
  done
}
# Text files written in this repository (no vendored data, no images).
own_text_files() {
  all_files | grep -vE '\.(png|jpg|jpeg|gif|webp|ico|zip)$' | grep -vxF -f <(printf '%s\n' "${VENDORED[@]}")
}

# run <name> <function>: the check fails when the function exits non-zero.
# Whatever the function prints is shown under a failing check as the reason.
run() {
  local name="$1" out status
  out="$("$2" 2>&1)"
  status=$?
  if [ "$status" -eq 0 ]; then
    printf 'ok    %s\n' "$name"
    pass=$((pass + 1))
  elif [ "$status" -eq 77 ]; then
    printf 'skip  %s (%s)\n' "$name" "$out"
    skip=$((skip + 1))
  else
    printf 'FAIL  %s\n' "$name"
    printf '%s\n' "$out" | head -20 | sed 's/^/        /'
    fail=$((fail + 1))
  fi
}

check_shell_syntax() {
  local f bad=0
  for f in $(all_files | grep '\.sh$'); do
    bash -n "$f" || bad=1
  done
  return "$bad"
}

check_node_syntax() {
  command -v node >/dev/null || { echo "node is not installed"; return 77; }
  local f bad=0
  for f in $(all_files | grep '\.mjs$'); do
    node --check "$f" || bad=1
  done
  return "$bad"
}

check_python_syntax() {
  all_files | grep '\.py$' | PYTHONDONTWRITEBYTECODE=1 python3 -c '
import ast, sys
bad = 0
for path in sys.stdin.read().split():
    try:
        ast.parse(open(path, encoding="utf-8").read(), path)
    except SyntaxError as error:
        print(f"{path}:{error.lineno}: {error.msg}")
        bad = 1
sys.exit(bad)'
}

check_json() {
  local f bad=0
  for f in $(all_files | grep '\.json$'); do
    jq empty "$f" >/dev/null 2>&1 || { echo "$f: not valid JSON"; bad=1; }
  done
  return "$bad"
}

# Every skill folder is one plugin of the same name, and every plugin points at a skill folder.
check_marketplace() {
  local manifest=.claude-plugin/marketplace.json skills listed
  skills="$(for d in skills/*/; do [ -f "$d/SKILL.md" ] && basename "$d"; done | sort)"
  listed="$(jq -r '.plugins[] | "\(.name) \(.skills | join(","))"' "$manifest")"
  [ "$(printf '%s\n' "$listed" | awk '{print $1}' | sort)" = "$skills" ] || {
    echo "plugins: $(printf '%s\n' "$listed" | awk '{print $1}' | tr '\n' ' ')"
    echo "skill folders: $(printf '%s\n' "$skills" | tr '\n' ' ')"
    return 1
  }
  printf '%s\n' "$listed" | while read -r name paths; do
    [ "$paths" = "./skills/$name" ] || { echo "plugin $name lists $paths instead of ./skills/$name"; exit 1; }
  done
}

check_skill_frontmatter() {
  local d name bad=0
  for d in skills/*/; do
    name="$(basename "$d")"
    [ -f "$d/SKILL.md" ] || continue
    head -1 "$d/SKILL.md" | grep -qx -- '---' || { echo "$name: SKILL.md does not start with frontmatter"; bad=1; }
    grep -qx "name: $name" "$d/SKILL.md" || { echo "$name: frontmatter name does not match the folder"; bad=1; }
    grep -qE '^description: .{40,}' "$d/SKILL.md" || { echo "$name: description is missing or too short"; bad=1; }
  done
  return "$bad"
}

# Codex reads agents/openai.yaml. A skill that only runs when the user calls it says so to both agents.
check_codex_metadata() {
  local d name yaml manual implicit bad=0
  for d in skills/*/; do
    name="$(basename "$d")"
    [ -f "$d/SKILL.md" ] || continue
    yaml="$d/agents/openai.yaml"
    [ -f "$yaml" ] || { echo "$name: agents/openai.yaml is missing"; bad=1; continue; }
    for key in display_name short_description default_prompt; do
      grep -qE "^  $key: \".+\"" "$yaml" || { echo "$name: interface.$key is missing"; bad=1; }
    done
    grep -qE "^  default_prompt: \".*\\\$$name\b" "$yaml" || { echo "$name: default_prompt does not mention \$$name"; bad=1; }
    manual=false
    grep -qx 'disable-model-invocation: true' "$d/SKILL.md" && manual=true
    implicit="$(sed -nE 's/^  allow_implicit_invocation: (true|false)$/\1/p' "$yaml")"
    if [ "$manual" = true ] && [ "$implicit" != false ]; then
      echo "$name: SKILL.md disables model invocation but openai.yaml does not set allow_implicit_invocation: false"; bad=1
    elif [ "$manual" = false ] && [ "$implicit" != true ]; then
      echo "$name: openai.yaml should set allow_implicit_invocation: true like SKILL.md"; bad=1
    fi
  done
  return "$bad"
}

# Every plugin carries the version of the newest release in CHANGELOG.md.
check_versions() {
  local released versions
  grep -qx '## \[Unreleased\]' CHANGELOG.md || { echo "CHANGELOG.md has no ## [Unreleased] section"; return 1; }
  released="$(sed -nE 's/^## \[([0-9]+\.[0-9]+\.[0-9]+)\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$/\1/p' CHANGELOG.md | head -1)"
  [ -n "$released" ] || { echo "CHANGELOG.md has no ## [X.Y.Z] - YYYY-MM-DD section"; return 1; }
  versions="$(jq -r '.plugins[] | "\(.name) \(.version)"' .claude-plugin/marketplace.json)"
  printf '%s\n' "$versions" | while read -r name version; do
    [ "$version" = "$released" ] || { echo "plugin $name is $version but CHANGELOG.md's newest release is $released"; exit 1; }
  done
}

check_readme_skills() {
  local d name bad=0
  for d in skills/*/; do
    name="$(basename "$d")"
    grep -qx "## $name" README.md || { echo "README.md has no ## $name section"; bad=1; }
  done
  return "$bad"
}

# Relative links and images in the Markdown files point at files that exist.
check_links() {
  local f link bad=0
  for f in $(all_files | grep '\.md$'); do
    for link in $(grep -oE '\]\([^)#]+\)|src="[^"]+"' "$f" | sed -E 's/^\]\(//; s/\)$//; s/^src="//; s/"$//' | grep -vE '^[a-z]+:'); do
      [ -e "$(dirname "$f")/$link" ] || { echo "$f: $link does not exist"; bad=1; }
    done
  done
  return "$bad"
}

check_no_personal_paths() {
  own_text_files | while IFS= read -r f; do
    grep -nE '/Users/[A-Za-z0-9]|/home/[a-z][a-z0-9_-]*/' "$f" | sed "s|^|$f:|"
  done | grep . && return 1
  return 0
}

check_no_email() {
  own_text_files | while IFS= read -r f; do
    grep -noE '[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}' "$f" \
      | grep -vE '@example\.(com|org|net)$' | sed "s|^|$f:|"
  done | grep . && return 1
  return 0
}

# Japanese appears only in the allowed files, or as the language name on a switch.
check_english() {
  own_text_files | grep -vxF -f <(printf '%s\n' "${JA_ALLOWED[@]}") | python3 -c '
import re, sys
japanese = re.compile("[%s-%s%s-%s%s-%s]+" % tuple(map(chr, (0x3040, 0x30FF, 0x3400, 0x9FFF, 0xFF66, 0xFF9F))))
bad = 0
for path in sys.stdin.read().splitlines():
    for number, line in enumerate(open(path, encoding="utf-8"), 1):
        words = japanese.findall(line)
        if words and any(word != "日本語" for word in words):
            print(f"{path}:{number}: {line.strip()[:80]}")
            bad = 1
sys.exit(bad)'
}

check_no_build_output() {
  git ls-files | grep -E '(\.pyc$|__pycache__/|node_modules/|\.DS_Store$)' && return 1
  return 0
}

# Every bundled data file is credited.
check_notices() {
  local f bad=0
  for f in $(all_files | grep -E '^skills/[^/]+/data/'); do
    grep -qF "\`$f\`" THIRD_PARTY_NOTICES.md || { echo "$f is not listed in THIRD_PARTY_NOTICES.md"; bad=1; }
  done
  return "$bad"
}

check_plugin_validate() {
  command -v claude >/dev/null || { echo "claude is not installed"; return 77; }
  claude plugin validate . >/dev/null 2>&1 || { claude plugin validate . 2>&1 | tail -5; return 1; }
}

run "shell scripts parse" check_shell_syntax
run "node scripts parse" check_node_syntax
run "python scripts parse" check_python_syntax
run "JSON files parse" check_json
run "marketplace lists every skill once" check_marketplace
run "SKILL.md frontmatter" check_skill_frontmatter
run "Codex metadata matches SKILL.md" check_codex_metadata
run "plugin versions match CHANGELOG.md" check_versions
run "README.md has a section per skill" check_readme_skills
run "relative links resolve" check_links
run "no local user paths" check_no_personal_paths
run "no email addresses" check_no_email
run "English outside the ja dictionaries" check_english
run "no build output tracked" check_no_build_output
run "bundled data is credited" check_notices
run "claude plugin validate" check_plugin_validate

printf '%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ]
