#!/usr/bin/env bash
# Tests for the diagram-styles plugin and its article-diagram-styles skill: the plugin's files, the
# font and its notice, the catalog script against throwaway styles folders, the figure checks, the
# musubi contents, the steps both SKILL.md files hold, and the repository checks. It reads the
# repository around the plugin, so it runs from a checkout of the repository. Every styles folder
# and HOME it uses is a throwaway folder with small images drawn by tests/fixtures.py; nothing
# reads the user's ~/.styles or reaches the network.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
SCRIPTS="$SKILL_DIR/scripts"
PLUGIN="$(cd "$SKILL_DIR/../.." && pwd)"
REPO="$(cd "$PLUGIN/../.." && pwd)"
BOOK="$PLUGIN/skills/tech-book-figure"
FIXTURES="$HERE/fixtures.py"
PASS=0
FAIL=0
SKIP=0
T="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$T"' EXIT
export PYTHONDONTWRITEBYTECODE=1

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }

# has <file> <text>...: every text appears in the file.
has() {
  local f="$1" s
  shift
  [ -f "$f" ] || { echo "      missing ${f#"$REPO"/}"; return 1; }
  for s in "$@"; do
    grep -qF -- "$s" "$f" || { echo "      ${f#"$REPO"/} lacks: $s"; return 1; }
  done
}

# both <text>...: both SKILL.md files hold every text.
both() { has "$SKILL_DIR/SKILL.md" "$@" && has "$BOOK/SKILL.md" "$@"; }

# styles <dir> [options]: a throwaway styles folder (see tests/fixtures.py).
styles() { python3 "$FIXTURES" styles "$@" > /dev/null; }

# catalog <out> [arguments]: runs the catalog script, keeps its output in <out>, and returns its exit.
catalog() {
  local out="$1"
  shift
  [ -f "$SCRIPTS/diagram_sample_catalog.py" ] || { echo "      missing scripts/diagram_sample_catalog.py" > "$out"; return 127; }
  python3 "$SCRIPTS/diagram_sample_catalog.py" "$@" > "$out" 2>&1
}

# exits <want> <out> <text>...: the last run exited <want> and its output names every text.
exits() {
  local want="$1" got="$2" out="$3" s
  shift 3
  [ "$got" -eq "$want" ] || { echo "      exited $got, not $want"; sed 's/^/        /' "$out" | head -8; return 1; }
  for s in "$@"; do
    grep -qF -- "$s" "$out" || { echo "      the output does not name $s"; sed 's/^/        /' "$out" | head -8; return 1; }
  done
}

plugin_layout() {
  local f
  for f in .claude-plugin/plugin.json .codex-plugin/plugin.json skills/article-diagram-styles/SKILL.md skills/tech-book-figure/SKILL.md; do
    [ -f "$PLUGIN/$f" ] || { echo "      missing plugins/diagram-styles/$f"; return 1; }
  done
  grep -qx 'name: article-diagram-styles' "$SKILL_DIR/SKILL.md" || { echo "      article SKILL.md does not name article-diagram-styles"; return 1; }
  grep -qx 'name: tech-book-figure' "$BOOK/SKILL.md" || { echo "      book SKILL.md does not name tech-book-figure"; return 1; }
  python3 - "$SKILL_DIR/SKILL.md" "$BOOK/SKILL.md" <<'PYEOF' || return 1
import re, sys
japanese = re.compile("[぀-ヿ㐀-鿿ｦ-ﾟ]")
bad = [p for p in sys.argv[1:] if japanese.search(open(p, encoding="utf-8").read())]
for p in bad:
    print("      " + p.rsplit("/", 3)[-3] + "/SKILL.md is not written in English")
sys.exit(1 if bad else 0)
PYEOF
  jq -e '.plugins[] | select(.name == "diagram-styles") | .source == "./plugins/diagram-styles"' "$REPO/.claude-plugin/marketplace.json" > /dev/null ||
    { echo "      the marketplace does not list diagram-styles at ./plugins/diagram-styles"; return 1; }
}
check "the plugin holds both skills and the marketplace lists it" plugin_layout

font_notice() {
  local fonts dir
  fonts="$(find "$PLUGIN" -name KaiseiDecol-Bold.ttf 2>/dev/null)"
  [ "$(printf '%s' "$fonts" | grep -c .)" -eq 1 ] || { echo "      expected one KaiseiDecol-Bold.ttf under the plugin, found: ${fonts:-none}"; return 1; }
  dir="$(dirname "$fonts")"
  has "$dir/OFL.txt" "SIL OPEN FONT LICENSE Version 1.1" || return 1
  has "$PLUGIN/THIRD_PARTY_NOTICES.md" "Kaisei Decol" "Font-Kai/Kaisei" "SIL Open Font License 1.1" "${dir#"$PLUGIN"/}/KaiseiDecol-Bold.ttf"
}
check "the font ships with its license and notice" font_notice

# skill_files: every file under the plugin's skills folder, one path per line.
skill_files() { find "$PLUGIN/skills" -type f 2>/dev/null; }

# includes_skills <file list>: the list holds both SKILL.md files.
includes_skills() {
  grep -qx "$SKILL_DIR/SKILL.md" "$1" && grep -qx "$BOOK/SKILL.md" "$1" ||
    { echo "      the counted files do not include both SKILL.md files"; return 1; }
}

no_images() {
  local images
  skill_files > "$T/skill-files"
  includes_skills "$T/skill-files" || return 1
  images="$(grep -iE '\.(png|webp|jpe?g)$' "$T/skill-files")"
  [ -z "$images" ] || { printf '%s\n' "$images" | sed "s|$REPO/|      |"; return 1; }
}
check "no image ships under the skills" no_images

readmes_say_no_samples() {
  has "$PLUGIN/README.md" "ships no sample images" "~/.styles/" "style-catalog.json" &&
    has "$PLUGIN/README.ja.md" "見本の画像を載せません" "~/.styles/" "style-catalog.json"
}
check "the readmes say no sample image ships and where to put the samples" readmes_say_no_samples

pages_say_reads_writes_sends() {
  local page bad=0
  for page in README.md docs/how-it-works.md; do
    has "$PLUGIN/$page" "~/.styles/" "style-catalog.json" "only in the folder you name" \
      "sends the drawing instructions and the sample images to the image generation of the agent" || bad=1
  done
  for page in README.ja.md docs/how-it-works.ja.md; do
    has "$PLUGIN/$page" "~/.styles/" "style-catalog.json" "名指したフォルダだけ" \
      "描く指示と見本の画像を、スキルを動かしている道具の画像生成へ渡します" || bad=1
  done
  return "$bad"
}
check "the pages say what the plugin reads, writes, and sends to image generation" pages_say_reads_writes_sends

reads_home_styles() {
  local status
  mkdir -p "$T/h6"
  styles "$T/h6/.styles"
  HOME="$T/h6" catalog "$T/h6.out" --validate
  status=$?
  exits 0 "$status" "$T/h6.out" "$T/h6/.styles"
}
check "the catalog script reads ~/.styles by default" reads_home_styles

reads_only_given_folder() {
  local status
  mkdir -p "$T/h7"
  styles "$T/h7/.styles" --schema 1
  styles "$T/s7"
  HOME="$T/h7" catalog "$T/s7.out" --validate --styles "$T/s7"
  status=$?
  exits 0 "$status" "$T/s7.out" "$T/s7" || return 1
  ! grep -qF "$T/h7" "$T/s7.out" || { echo "      the run with --styles named the HOME folder"; return 1; }
}
check "the catalog script reads only the folder given by --styles" reads_only_given_folder

refuses_missing_catalog() {
  local status
  styles "$T/s8" --no-catalog
  catalog "$T/s8.out" --validate --styles "$T/s8"
  status=$?
  exits 1 "$status" "$T/s8.out" "style-catalog.json"
}
check "validate refuses a folder without style-catalog.json" refuses_missing_catalog

skills_stop_without_catalog() {
  both 'If `~/.styles/style-catalog.json` is missing, stop before drawing and tell the user to put the catalog and the sample images under `~/.styles/`'
}
check "both skills stop before drawing when the catalog is missing" skills_stop_without_catalog

accepts_version_2() {
  local status
  styles "$T/s11"
  catalog "$T/s11.out" --validate --styles "$T/s11"
  status=$?
  exits 0 "$status" "$T/s11.out" "PASS"
}
check "validate accepts a version 2 catalog" accepts_version_2

refuses_version_1() {
  local status
  styles "$T/s12" --schema 1
  catalog "$T/s12.out" --validate --styles "$T/s12"
  status=$?
  exits 1 "$status" "$T/s12.out" "schema_version"
}
check "validate refuses a version 1 catalog" refuses_version_1

refuses_resources() {
  local status
  styles "$T/s13" --resources
  catalog "$T/s13.out" --validate --styles "$T/s13"
  status=$?
  exits 1 "$status" "$T/s13.out" "resources"
}
check "validate refuses a catalog that holds resources" refuses_resources

refuses_changed_image() {
  local status
  styles "$T/s14a" --corrupt path
  catalog "$T/s14a.out" --validate --styles "$T/s14a"
  status=$?
  exits 1 "$status" "$T/s14a.out" "style-catalog/illustrated/pen-technical/pen-c.png" || return 1
  styles "$T/s14b" --corrupt original
  catalog "$T/s14b.out" --validate --styles "$T/s14b"
  status=$?
  exits 1 "$status" "$T/s14b.out" "diagram-style-samples/style4/flow-a.png"
}
check "validate refuses an image whose sha256 differs" refuses_changed_image

refuses_wrong_counts() {
  local status kind
  for kind in source unique; do
    styles "$T/s15-$kind" --counts "$kind"
    catalog "$T/s15-$kind.out" --validate --styles "$T/s15-$kind"
    status=$?
    case "$kind" in
      source) exits 1 "$status" "$T/s15-$kind.out" "source_registrations" || return 1 ;;
      unique) exits 1 "$status" "$T/s15-$kind.out" "unique_images" || return 1 ;;
    esac
  done
}
check "validate refuses counts that do not match the catalog" refuses_wrong_counts

refuses_unnamed_image() {
  local status
  styles "$T/s16" --stray
  catalog "$T/s16.out" --validate --styles "$T/s16"
  status=$?
  exits 1 "$status" "$T/s16.out" "diagram-style-samples/style2/stray-sample.webp"
}
check "validate refuses an image the catalog does not name" refuses_unnamed_image

# snapshot <dir>: the name and SHA-256 of every file under the folder, sorted.
snapshot() {
  python3 - "$1" <<'PYEOF'
import hashlib, os, sys
root = sys.argv[1]
for base, dirs, files in sorted(os.walk(root)):
    for name in sorted(files):
        path = os.path.join(base, name)
        print(hashlib.sha256(open(path, "rb").read()).hexdigest(), os.path.relpath(path, root))
PYEOF
}

writes_nothing_under_styles() {
  local h="$T/h17" w="$T/w17" s name ran=""
  mkdir -p "$h"
  styles "$h/.styles"
  python3 "$FIXTURES" work "$w" --mode generated > /dev/null
  snapshot "$h/.styles" > "$T/before"
  for s in "$SCRIPTS"/*.py; do
    [ -f "$s" ] || continue
    name="$(basename "$s")"
    ran="$ran $name"
    case "$name" in
      diagram_sample_catalog.py)
        HOME="$h" python3 "$s" --validate > /dev/null 2>&1
        HOME="$h" python3 "$s" > /dev/null 2>&1
        HOME="$h" python3 "$s" --sample "$h/.styles/style-catalog/illustrated/pen-technical/flow-a.png" > /dev/null 2>&1 ;;
      validate_content_brief.py) HOME="$h" python3 "$s" "$w/brief.json" > /dev/null 2>&1 ;;
      validate_figure_spec.py) HOME="$h" python3 "$s" "$w/figure.figure.json" > /dev/null 2>&1 ;;
      validate_anchor_candidate.py) (cd "$SCRIPTS" && HOME="$h" python3 "$s" --review "$w/review.json") > /dev/null 2>&1 ;;
      validate_visual_contract.py) (cd "$SCRIPTS" && HOME="$h" python3 "$s" --contract "$w/contract.json" --figure-spec "$w/contract-spec.json") > /dev/null 2>&1 ;;
      validate_composition_ledger.py) HOME="$h" python3 "$s" --ledger "$w/ledger.json" > /dev/null 2>&1 ;;
      *) HOME="$h" python3 "$s" --help > /dev/null 2>&1 ;;
    esac
  done
  case " $ran " in
    *" diagram_sample_catalog.py "*) ;;
    *) echo "      the scripts that ran do not include diagram_sample_catalog.py (ran:${ran:- none})"; return 1 ;;
  esac
  snapshot "$h/.styles" > "$T/after"
  cmp -s "$T/before" "$T/after" || { diff "$T/before" "$T/after" | sed 's/^/      /' | head -8; return 1; }
}
check "the scripts write nothing under ~/.styles" writes_nothing_under_styles

provides_three() {
  [ -f "$SKILL_DIR/musubi.json" ] || { echo "      missing skills/article-diagram-styles/musubi.json"; return 1; }
  python3 - "$SKILL_DIR" <<'PYEOF'
import json, os, sys
skill = sys.argv[1]
provides = json.load(open(os.path.join(skill, "musubi.json"), encoding="utf-8")).get("provides", {})
problems = []
for name in ("style4", "figure-request", "style-catalog"):
    item = provides.get(name)
    if not isinstance(item, dict):
        problems.append("provides no " + name)
        continue
    if item.get("version") != "1.0.0":
        problems.append(name + " is at version " + str(item.get("version")) + ", not 1.0.0")
    if not item.get("file") or not os.path.isfile(os.path.join(skill, item["file"])):
        problems.append(name + " names a file that does not exist: " + str(item.get("file")))
for problem in problems:
    print("      " + problem)
sys.exit(1 if problems else 0)
PYEOF
}
check "article-diagram-styles provides style4, figure-request, and style-catalog" provides_three

names_no_tool() {
  skill_files | grep -vE '/(tests|agents)/' > "$T/named-files"
  includes_skills "$T/named-files" || return 1
  python3 - "$T/named-files" "$REPO" <<'PYEOF'
import re, sys
words = re.compile(r"codex|claude|openai|chatgpt|gpt|gemini|copilot|imagegen|image_gen|referenced_image_paths|dall-e", re.I)
problems = []
for path in open(sys.argv[1], encoding="utf-8").read().split("\n"):
    if not path:
        continue
    data = open(path, "rb").read()
    if b"\0" in data:
        continue  # A binary file such as the font holds no words.
    for number, line in enumerate(data.decode("utf-8").splitlines(), 1):
        for word in words.findall(line):
            problems.append("%s:%d names %s" % (path[len(sys.argv[2]) + 1:], number, word))
for problem in problems[:12]:
    print("      " + problem)
sys.exit(1 if problems else 0)
PYEOF
}
check "the skill files name no agent or image tool" names_no_tool

draws_with_agent_generation() {
  both 'Draw the finished figure with the image generation of the agent running this skill'
}
check "both skills draw with the image generation of the agent running them" draws_with_agent_generation

saves_and_stops() {
  both 'If the agent running this skill has no image generation' \
    'write the content summary, the figure spec, and the drawing instructions into the folder the user names, and stop' \
    'continue this skill in an agent that has image generation'
}
check "both skills save the design and stop without image generation" saves_and_stops

refuses_stand_ins() {
  both 'Do not draw the finished figure with HTML or SVG in place of image generation' \
    'do not call another agent or tool through a shell command to draw it'
}
check "both skills refuse to stand in for image generation" refuses_stand_ins

resumes_from_design() {
  both 'read the saved content summary, figure spec, and drawing instructions, and start from the drawing step without redoing the design'
}
check "both skills resume from the saved design" resumes_from_design

reviews_in_separate_pass() {
  has "$SKILL_DIR/SKILL.md" 'If the agent cannot start a separate reviewer' \
    'in a separate pass that reads only the article excerpt, the reader question, the finished PNG, and the published-width version' \
    'tell the user that the review was not independent'
}
check "the article skill reviews in a separate pass without a separate reviewer" reviews_in_separate_pass

shell_commands() { both 'shell command'; }
check "both skills run their scripts as shell commands" shell_commands

user_language() { both 'Talk to the user in the language they write in'; }
check "both skills talk in the language the user writes in" user_language

accepts_generated() {
  local h="$T/h30" w="$T/w30" status
  mkdir -p "$h"
  styles "$h/.styles"
  python3 "$FIXTURES" work "$w" --mode generated > /dev/null
  [ -f "$SCRIPTS/validate_figure_spec.py" ] && [ -f "$SCRIPTS/validate_anchor_candidate.py" ] ||
    { echo "      missing scripts/validate_figure_spec.py or scripts/validate_anchor_candidate.py"; return 1; }
  HOME="$h" python3 "$SCRIPTS/validate_figure_spec.py" "$w/figure.figure.json" > "$T/s30.out" 2>&1
  status=$?
  exits 0 "$status" "$T/s30.out" || return 1
  (cd "$SCRIPTS" && HOME="$h" python3 "$SCRIPTS/validate_anchor_candidate.py" --review "$w/review.json") > "$T/a30.out" 2>&1
  status=$?
  exits 0 "$status" "$T/a30.out"
}
check "the figure checks accept rendering_mode generated" accepts_generated

refuses_other_modes() {
  local w="$T/w31" mode status
  python3 "$FIXTURES" work "$w" --mode generated > /dev/null
  [ -f "$SCRIPTS/validate_figure_spec.py" ] || { echo "      missing scripts/validate_figure_spec.py"; return 1; }
  for mode in imagegen html ""; do
    python3 - "$w/figure.figure.json" "$mode" <<'PYEOF'
import json, sys
spec = json.load(open(sys.argv[1], encoding="utf-8"))
spec["rendering_mode"] = sys.argv[2]
json.dump(spec, open(sys.argv[1], "w", encoding="utf-8"))
PYEOF
    python3 "$SCRIPTS/validate_figure_spec.py" "$w/figure.figure.json" > "$T/s31.out" 2>&1
    status=$?
    exits 1 "$status" "$T/s31.out" "rendering_mode" || { echo "      (rendering_mode '$mode')"; return 1; }
  done
}
check "validate_figure_spec refuses any other rendering_mode" refuses_other_modes

tests_under_tests() {
  local found
  [ -f "$SCRIPTS/diagram_sample_catalog.py" ] || { echo "      the counted scripts do not include diagram_sample_catalog.py"; return 1; }
  found="$(find "$SCRIPTS" -name 'test_*' -type f)"
  [ -z "$found" ] || { printf '%s\n' "$found" | sed "s|$REPO/|      |"; return 1; }
}
check "the script tests sit under tests" tests_under_tests

no_home_or_private_step() {
  find "$PLUGIN" -type f > "$T/plugin-files"
  includes_skills "$T/plugin-files" || return 1
  python3 - "$T/plugin-files" "$REPO" <<'PYEOF'
import re, sys
pattern = re.compile(r"/(?:Users/[A-Za-z0-9]|home/[a-z][a-z0-9_-]*/)|\bikkan-[a-z]")
problems = []
for path in open(sys.argv[1], encoding="utf-8").read().split("\n"):
    if not path:
        continue
    data = open(path, "rb").read()
    if b"\0" in data:
        continue
    for number, line in enumerate(data.decode("utf-8").splitlines(), 1):
        if pattern.search(line):
            problems.append("%s:%d" % (path[len(sys.argv[2]) + 1:], number))
for problem in problems[:12]:
    print("      " + problem)
sys.exit(1 if problems else 0)
PYEOF
}
check "no file names a home folder or a private workflow step" no_home_or_private_step

# unreleased <changelog>: the lines between ## [Unreleased] and the next release.
unreleased() { awk '/^## \[Unreleased\]/{on=1; next} /^## \[/{on=0} on' "$1"; }

changelog_line() {
  [ -f "$PLUGIN/CHANGELOG.md" ] || { echo "      missing plugins/diagram-styles/CHANGELOG.md"; return 1; }
  unreleased "$PLUGIN/CHANGELOG.md" | grep -q '^- ' || { echo "      no line under ## [Unreleased]"; return 1; }
}
check "the changelog has a line under Unreleased" changelog_line

releasing_pages() {
  has "$REPO/docs/releasing.md" 'musubi check plugins/diagram-styles/skills' &&
    has "$REPO/docs/releasing.ja.md" 'musubi check plugins/diagram-styles/skills'
}
check "the releasing pages run musubi check before releasing diagram-styles" releasing_pages

repo_checks() { bash "$REPO/scripts/check.sh" > "$T/check.out" 2>&1 || { grep -A3 '^FAIL' "$T/check.out" | head -20 | sed 's/^/      /'; return 1; }; }
check "the repository checks pass" repo_checks

printf 'article-diagram-styles: %d passed, %d failed (%d ran, %d skipped)\n' "$PASS" "$FAIL" "$((PASS + FAIL))" "$SKIP"
[ "$FAIL" -eq 0 ]
