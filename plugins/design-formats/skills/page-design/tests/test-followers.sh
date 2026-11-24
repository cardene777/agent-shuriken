#!/usr/bin/env bash
# Tests that the report skills of the repository follow page-design through musubi as optional
# follows: the declarations, the lines in each SKILL.md, the templates that verify accepts, the
# musubi check with and without design-formats, the pages, the changelogs, and the followers' own
# tests. It reads the other plugins of this repository, so it runs from a checkout of the repository,
# not from an installed plugin. Copies live in a throwaway folder; nothing reaches the network. The
# musubi checks run only when the musubi command is on PATH, and are reported as skipped, never as
# passed, when it is not. The followers' own tests and scripts/check.sh take more than 20
# minutes, so they run only with --own-tests: when a format, a template, or verify of page-design
# changes, and before releasing design-formats. Without it, both checks are reported as skipped.
set -u

OWN_TESTS=0
case "$#:${1:-}" in
  0:) ;;
  1:--own-tests) OWN_TESTS=1 ;;
  *) echo "usage: bash $0 [--own-tests]" >&2; exit 2 ;;
esac

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
SCRIPT="$SKILL_DIR/scripts/page-design.py"
PLUGIN="$(cd "$SKILL_DIR/../.." && pwd)"
REPO="$(cd "$PLUGIN/../.." && pwd)"
PASS=0
FAIL=0
SKIP=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
skip() { SKIP=$((SKIP + 1)); printf 'skip  %s (%s)\n' "$1" "$2"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }

# Each follower: <skill> <plugin> <kind>, where the kind is the page type template it follows, or
# chat for a skill that reports in the chat.
FOLLOWERS="techdebt techdebt report
compare-report compare-report report
machine-cleanup machine-cleanup sheet
account-cleanup account-cleanup sheet
diagram-explainer diagram-explainer document
repo-progress repo-progress chat
secure-dotfile secure-dotfile chat
init-project init-project chat
release-check evm-dev chat
portman portman chat"
PLUGINS="techdebt compare-report machine-cleanup account-cleanup diagram-explainer repo-progress secure-dotfile init-project evm-dev portman"

skill_dir() { printf '%s/plugins/%s/skills/%s' "$REPO" "$2" "$1"; }

# The skills folders musubi reads: page-design, design-doc (which the evm-dev design skills follow),
# and every follower's plugin.
skills_folders() {
  local p
  [ "${1:-}" = "without-design-formats" ] || printf '%s\n' "$PLUGIN/skills"
  printf '%s\n' "$REPO/plugins/doc-formats/skills"
  for p in $PLUGINS; do printf '%s\n' "$REPO/plugins/$p/skills"; done
}

follows_page_design() {
  python3 - "$REPO" "$FOLLOWERS" <<'PYEOF'
import json, os, re, sys
repo, followers = sys.argv[1], sys.argv[2]
problems = []
for line in followers.splitlines():
    skill, plugin, kind = line.split()
    path = os.path.join(repo, "plugins", plugin, "skills", skill, "musubi.json")
    if not os.path.isfile(path):
        problems.append("%s has no musubi.json" % skill)
        continue
    follows = json.load(open(path, encoding="utf-8")).get("follows", {})
    want = ["page-design/structure"] if kind == "chat" else ["page-design/structure", "page-design/look", "page-design/" + kind, "page-design/verify"]
    # A skill that writes pages may also follow the theme format, to apply the user's theme file.
    extra = [] if kind == "chat" else [ref for ref in ("page-design/theme",) if ref in follows]
    mine = sorted(ref for ref in follows if ref.startswith("page-design/") and ref not in extra)
    if mine != sorted(want):
        problems.append("%s follows %s, not %s" % (skill, ", ".join(mine) or "nothing of page-design", ", ".join(want)))
    for ref in want + extra:
        follow = follows.get(ref, {})
        # structure and theme are at 1.0.0; the look, the page types, and verify moved to 2.0.0 with the pattern rules.
        version = "^1.0.0" if ref in ("page-design/structure", "page-design/theme") else "^2.0.0"
        if follow and not (follow.get("version") == version and follow.get("optional") is True
                           and re.fullmatch(r"sha256-[A-Za-z0-9+/]{43}=", str(follow.get("integrity", "")))):
            problems.append("%s follows %s without %s, a fingerprint, and optional true" % (skill, ref, version))
for problem in problems:
    print("      " + problem)
sys.exit(1 if problems else 0)
PYEOF
}
check "the report skills follow page-design as optional follows" follows_page_design

LINE_CHECK='If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.'
LINE_CHAT_READ='When the `page-design` skill is installed, write the report in the `structure` format of the `page-design` skill: open the `page-design` skill by name and read the file it names for `structure`.'
LINE_CHAT_MISSING='If the `page-design` skill is not installed, go on without the `structure` of `page-design`.'
LINE_PAGE_MISSING='If the `page-design` skill is not installed, go on with the templates of this skill, without the formats of `page-design`.'

# page_read <kind>: the line of a page skill that names the contents it reads.
page_read() {
  printf 'When the `page-design` skill is installed, follow the `structure` and `look` formats and the `%s` page type of the `page-design` skill: open the `page-design` skill by name and read the files it names for `structure`, `look`, `%s`, and `verify`.' "$1" "$1"
}

# has <file> <text>...: every text appears in the file.
has() {
  local f="$1" s
  shift
  [ -f "$f" ] || { echo "      missing $f"; return 1; }
  for s in "$@"; do
    grep -qF -- "$s" "$f" || { echo "      ${f#"$REPO"/} lacks: $s"; return 1; }
  done
}

musubi_lines() {
  local skill plugin kind f bad=0
  while read -r skill plugin kind; do
    f="$(skill_dir "$skill" "$plugin")/SKILL.md"
    if [ "$kind" = chat ]; then
      has "$f" "$LINE_CHAT_READ" "$LINE_CHECK" "$LINE_CHAT_MISSING" || bad=1
    else
      has "$f" "$(page_read "$kind")" "$LINE_CHECK" "$LINE_PAGE_MISSING" || bad=1
    fi
  done <<< "$FOLLOWERS"
  return "$bad"
}
check "the report skills carry the musubi lines for page-design" musubi_lines

page_verify_line() {
  local skill plugin kind bad=0
  while read -r skill plugin kind; do
    [ "$kind" = chat ] && continue
    has "$(skill_dir "$skill" "$plugin")/SKILL.md" \
      'When the `page-design` skill is installed, run its `verify` on the finished page' \
      'the file it names for `verify`' || bad=1
  done <<< "$FOLLOWERS"
  return "$bad"
}
check "the page skills run the verify of page-design on their pages" page_verify_line

# The six pages: each template as it is, and the explainer template finished by build.py, since its
# styles and scripts come from assets/ when it is built.
pages() {
  printf '%s\n' "$(skill_dir techdebt techdebt)/templates/base.html" \
    "$(skill_dir compare-report compare-report)/templates/base.html" \
    "$(skill_dir machine-cleanup machine-cleanup)/templates/sheet.html" \
    "$(skill_dir account-cleanup account-cleanup)/templates/sheet.html" \
    "$(skill_dir account-cleanup account-cleanup)/templates/followups.html" \
    "$T/starter-doc.html"
}

build_starter() {
  local d
  d="$(skill_dir diagram-explainer diagram-explainer)"
  [ -f "$T/starter-doc.html" ] && return 0
  python3 "$d/scripts/build.py" --in "$d/templates/starter-doc.html" --out "$T/starter-doc.html" > "$T/build.out" 2>&1 ||
    { sed 's/^/      /' "$T/build.out"; return 1; }
}

templates_verify() {
  local f bad=0 source
  build_starter || return 1
  while read -r f; do
    [ -f "$f" ] || { echo "      missing $f"; bad=1; continue; }
    # A template that still holds dragon blocks is checked as a source, before dragon embed.
    source=""
    grep -q 'class="dragon"' "$f" && source="--source"
    python3 "$SCRIPT" verify $source "$f" > "$T/verify.out" 2>&1 || { sed "s|$REPO/||; s|^|      |" "$T/verify.out"; bad=1; }
  done < <(pages)
  return "$bad"
}
check "verify accepts every report page template" templates_verify

theme_choice() {
  build_starter || return 1
  python3 - $(pages) <<'PYEOF'
import re, sys
problems = []
for path in sys.argv[1:]:
    text = open(path, encoding="utf-8").read()
    name = "/".join(path.split("/")[-4:])
    style = "".join(re.findall(r"<style[^>]*>(.*?)</style>", text, re.S))
    script = "".join(re.findall(r"<script[^>]*>(.*?)</script>", text, re.S))
    if ':root[data-theme="dark"]' not in style:
        problems.append(name + ' has no :root[data-theme="dark"] colors')
    if ':root:not([data-theme="light"])' not in style:
        problems.append(name + ' does not guard the dark colors with :root:not([data-theme="light"])')
    if not re.search(r"""dataset\.theme\s*=|setAttribute\(\s*["']data-theme["']""", script):
        problems.append(name + " never sets data-theme on the page")
    for mode in ("light", "dark"):
        if 'data-theme-choice="%s"' % mode not in text:
            problems.append(name + " has no %s button" % mode)
for problem in problems:
    print("      " + problem)
sys.exit(1 if problems else 0)
PYEOF
}
check "the report page templates apply the light and dark choice" theme_choice

# evm-dev depends on doc-formats for its design skills; no follower depends on design-formats.
no_dependency() {
  local p f
  for p in $PLUGINS; do
    for f in "$REPO/plugins/$p/.claude-plugin/plugin.json" "$REPO/plugins/$p/.codex-plugin/plugin.json"; do
      python3 -c 'import json, sys; sys.exit(1 if "design-formats" in json.dumps(json.load(open(sys.argv[1], encoding="utf-8")).get("dependencies", [])) else 0)' "$f" ||
        { echo "      ${f#"$REPO"/} depends on design-formats"; return 1; }
    done
  done
}
check "the report plugins do not depend on design-formats" no_dependency

# counted_follows <folder>...: the number of follows in every musubi.json under the folders.
counted_follows() {
  python3 - "$@" <<'PYEOF'
import glob, json, os, sys
total = 0
for folder in sys.argv[1:]:
    for path in glob.glob(os.path.join(folder, "*", "musubi.json")):
        total += len(json.load(open(path, encoding="utf-8")).get("follows", {}))
print(total)
PYEOF
}

# page_design_follows: the number of page-design follows the followers declare.
page_design_follows() {
  local skill plugin kind n=0
  while read -r skill plugin kind; do
    [ -f "$(skill_dir "$skill" "$plugin")/musubi.json" ] || continue
    n=$((n + $(grep -c '"page-design/' "$(skill_dir "$skill" "$plugin")/musubi.json")))
  done <<< "$FOLLOWERS"
  echo "$n"
}

musubi_accepts() {
  local folders=() want
  while read -r f; do folders+=("$f"); done < <(skills_folders)
  [ "$(page_design_follows)" -eq 25 ] || { echo "      the followers declare $(page_design_follows) page-design follows, not 25"; return 1; }
  musubi check "${folders[@]}" > "$T/musubi.out" 2>&1 || { sed 's/^/      /' "$T/musubi.out"; return 1; }
  ! grep -q 'follows page-design/' "$T/musubi.out" || { grep 'follows page-design/' "$T/musubi.out" | sed 's/^/      /'; return 1; }
  want="$(counted_follows "${folders[@]}")"
  grep -q "follows=$want)" "$T/musubi.out" || { tail -1 "$T/musubi.out" | sed 's/^/      /'; echo "      expected follows=$want"; return 1; }
}

# Without design-formats every page-design follow is skipped with a warning, and the check passes.
musubi_skips_missing() {
  local folders=() skill plugin kind ref
  while read -r f; do folders+=("$f"); done < <(skills_folders without-design-formats)
  musubi check "${folders[@]}" > "$T/musubi-alone.out" 2>&1 || { sed 's/^/      /' "$T/musubi-alone.out"; return 1; }
  while read -r skill plugin kind; do
    for ref in structure look "$kind" verify; do
      [ "$kind" = chat ] && [ "$ref" != structure ] && continue
      grep -qF "$skill follows page-design/$ref only when page-design is installed" "$T/musubi-alone.out" ||
        { echo "      no warning that $skill skips page-design/$ref"; return 1; }
    done
  done <<< "$FOLLOWERS"
}

# refused_after <file under page-design> <skill>...: changing the file stops every named follower.
refused_after() {
  local file="$1" d="$T/copies" folders=() skill plugin kind
  shift
  rm -rf "$d"
  mkdir -p "$d/plugins"
  cp -R "$PLUGIN" "$REPO/plugins/doc-formats" "$d/plugins/" || return 1
  for p in $PLUGINS; do cp -R "$REPO/plugins/$p" "$d/plugins/" || return 1; done
  printf '\nA changed line.\n' >> "$d/plugins/design-formats/skills/page-design/$file"
  folders=("$d/plugins/design-formats/skills" "$d/plugins/doc-formats/skills")
  for p in $PLUGINS; do folders+=("$d/plugins/$p/skills"); done
  musubi check "${folders[@]}" > "$T/musubi-changed.out" 2>&1
  [ $? -eq 1 ] || { echo "      musubi check did not exit 1 after $file changed"; return 1; }
  for skill in "$@"; do
    grep -q "/$skill/musubi.json:[0-9]*: $skill: the fingerprint of page-design/" "$T/musubi-changed.out" ||
      { echo "      $skill was not refused after $file changed"; return 1; }
  done
  # Only the followers of the changed content are refused.
  while read -r skill plugin kind; do
    case " $* " in *" $skill "*) continue ;; esac
    ! grep -q "/$skill/musubi.json:" "$T/musubi-changed.out" || { echo "      $skill was refused after $file changed"; return 1; }
  done <<< "$FOLLOWERS"
}

musubi_refuses_changed() {
  refused_after formats/structure.md techdebt compare-report machine-cleanup account-cleanup diagram-explainer \
    repo-progress secure-dotfile init-project release-check portman || return 1
  refused_after templates/report.html techdebt compare-report
}

if command -v musubi > /dev/null 2>&1; then
  check "musubi check accepts page-design and its followers" musubi_accepts
  check "musubi check skips page-design when design-formats is not installed" musubi_skips_missing
  check "musubi check refuses the followers after a format changes" musubi_refuses_changed
else
  skip "musubi check accepts page-design and its followers" "the musubi command is not on PATH"
  skip "musubi check skips page-design when design-formats is not installed" "the musubi command is not on PATH"
  skip "musubi check refuses the followers after a format changes" "the musubi command is not on PATH"
fi

pages_describe() {
  local p page bad=0
  for p in $PLUGINS; do
    for page in README.md README.ja.md docs/how-it-works.md docs/how-it-works.ja.md; do
      has "$REPO/plugins/$p/$page" "musubi.json" "page-design" '"optional": true' || bad=1
    done
  done
  return "$bad"
}
check "the pages describe the page-design follow" pages_describe

names_followers() {
  local page skill plugin kind bad=0
  for page in README.md README.ja.md docs/how-it-works.md docs/how-it-works.ja.md; do
    while read -r skill plugin kind; do
      has "$PLUGIN/$page" "$skill" || bad=1
    done <<< "$FOLLOWERS"
  done
  return "$bad"
}
check "design-formats names the skills that follow page-design" names_followers

releasing_step() {
  local page line p
  for page in docs/releasing.md docs/releasing.ja.md; do
    line="$(grep -F 'musubi check plugins/design-formats/skills' "$REPO/$page" | head -1)"
    [ -n "$line" ] || { echo "      $page has no musubi check for design-formats"; return 1; }
    for p in doc-formats $PLUGINS; do
      printf '%s\n' "$line" | grep -qF "plugins/$p/skills" || { echo "      $page does not check plugins/$p/skills with design-formats"; return 1; }
    done
  done
}
check "the releasing pages run musubi check for page-design and its followers" releasing_step

# entries <changelog>: the entries from ## [Unreleased] on. A release moves the entries of
# Unreleased into its own section, so a plugin released after it followed page-design keeps its line.
entries() { awk '/^## \[Unreleased\]/{on=1} /^\[Unreleased\]:/{on=0} on' "$1"; }

changelogs() {
  local p bad=0
  for p in design-formats $PLUGINS; do
    entries "$REPO/plugins/$p/CHANGELOG.md" | grep -q 'page-design' || { echo "      plugins/$p/CHANGELOG.md has no entry on page-design"; bad=1; }
  done
  return "$bad"
}
check "the changed plugins note the page-design follow in their changelogs" changelogs

own_tests() {
  local t bad=0
  for t in \
    plugins/techdebt/skills/techdebt/tests/test-techdebt.sh \
    plugins/compare-report/skills/compare-report/tests/test-compare-report.sh \
    plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh \
    plugins/account-cleanup/skills/account-cleanup/tests/test-account-cleanup.sh \
    plugins/diagram-explainer/skills/diagram-explainer/tests/test-render.sh \
    plugins/repo-progress/skills/repo-progress/tests/test-repo-progress.sh \
    plugins/secure-dotfile/skills/secure-dotfile/tests/test-secure-dotfile.sh \
    plugins/init-project/skills/init-project/tests/test-init-project.sh \
    plugins/evm-dev/skills/release-check/tests/test-release-check.sh \
    plugins/portman/skills/portman/tests/test-portman.sh \
    plugins/design-formats/skills/page-design/tests/test-page-design.sh; do
    bash "$REPO/$t" > "$T/own.out" 2>&1 || { echo "      $t failed"; grep -E '^(FAIL|not ok|NG)' "$T/own.out" | head -5 | sed 's/^/        /'; bad=1; }
  done
  return "$bad"
}

repo_checks() { bash "$REPO/scripts/check.sh" > "$T/check.out" 2>&1 || { tail -5 "$T/check.out" | sed 's/^/      /'; return 1; }; }
WHEN="run with --own-tests when page-design changes and before releasing design-formats"
if [ "$OWN_TESTS" = 1 ]; then
  check "the followers and page-design keep passing their own tests" own_tests
  check "the repository checks pass" repo_checks
else
  skip "the followers and page-design keep passing their own tests" "$WHEN"
  skip "the repository checks pass" "$WHEN"
fi

printf '%d passed, %d failed (%d ran, %d skipped)\n' "$PASS" "$FAIL" "$((PASS + FAIL))" "$SKIP"
[ "$FAIL" -eq 0 ]
