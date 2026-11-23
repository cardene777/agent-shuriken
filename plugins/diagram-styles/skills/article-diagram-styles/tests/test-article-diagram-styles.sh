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

no_image_in_plugin() {
  local images
  find "$PLUGIN" -type f > "$T/plugin-all-files"
  includes_skills "$T/plugin-all-files" || return 1
  images="$(grep -iE '\.(png|webp|jpe?g)$' "$T/plugin-all-files")"
  [ -z "$images" ] || { printf '%s\n' "$images" | sed "s|$REPO/|      |"; return 1; }
}
check "no image ships under the plugin" no_image_in_plugin

BUILT_IN="$SKILL_DIR/data/built-in-styles.json"
BUILT_IN_NAMES="handdraft pen-technical pencil-sketch chalkboard flat-vector blueprint isometric minimal watercolor newsprint woodblock retro-poster whiteboard comic-panel pixel-art clay low-poly papercraft diorama toy-blocks notebook-doodle grid-memo patent-drawing old-map sumi-e risograph copperplate paper-cut pictogram metro-map terminal-screen sticker"

built_in_thirty_two() {
  [ -f "$BUILT_IN" ] || { echo "      missing skills/article-diagram-styles/data/built-in-styles.json"; return 1; }
  python3 - "$BUILT_IN" <<'PYEOF'
import json, sys
want = {
    "line-drawing": ["handdraft", "pen-technical", "pencil-sketch", "chalkboard"],
    "drafting-and-flat": ["flat-vector", "blueprint", "isometric", "minimal"],
    "painting-and-print": ["watercolor", "newsprint", "woodblock", "retro-poster"],
    "friendly": ["whiteboard", "comic-panel", "pixel-art", "clay"],
    "dimensional": ["low-poly", "papercraft", "diorama", "toy-blocks"],
    "notebook-and-archive": ["notebook-doodle", "grid-memo", "patent-drawing", "old-map"],
    "ink-and-print": ["sumi-e", "risograph", "copperplate", "paper-cut"],
    "signs-and-screens": ["pictogram", "metro-map", "terminal-screen", "sticker"],
}
data = json.load(open(sys.argv[1], encoding="utf-8"))
problems = []
families = data.get("families")
styles = data.get("finish_profiles")
if not isinstance(families, dict) or set(families) != set(want):
    problems.append("families are %s, not the eight" % sorted(families or []))
    families = families if isinstance(families, dict) else {}
for name, family in families.items():
    if not isinstance(family, dict) or not str(family.get("label", "")).strip():
        problems.append("family %s has no label" % name)
if not isinstance(styles, dict):
    problems.append("finish_profiles is not an object")
    styles = {}
names = [n for members in want.values() for n in members]
if sorted(styles) != sorted(names):
    problems.append("the styles are %s, not the thirty-two" % sorted(styles))
text = lambda value: isinstance(value, str) and bool(value.strip())
for family, members in want.items():
    for name in members:
        style = styles.get(name)
        if not isinstance(style, dict):
            continue
        if style.get("family") != family:
            problems.append("%s is in %s, not %s" % (name, style.get("family"), family))
        for key in ("label", "line", "fill", "background", "lettering"):
            if not text(style.get(key)):
                problems.append("%s has no %s" % (name, key))
        suits = style.get("suits")
        if not isinstance(suits, list) or not suits or not all(text(s) and ";" not in s for s in suits):
            problems.append("%s has no list of suits without semicolons" % name)
        if style.get("status") != "active":
            problems.append("%s has status %s, not active" % (name, style.get("status")))
for problem in problems[:12]:
    print("      " + problem)
sys.exit(1 if problems else 0)
PYEOF
}
check "the built-in styles hold thirty-two styles in eight families with their written specification" built_in_thirty_two

# Each built-in style is told apart by its own words: no two styles share a line, a fill, or
# lettering, compared without case and outer spaces. It reads every style the file holds, so it
# holds for the styles shipped before this change and for the ones added since.
built_in_distinct() {
  [ -f "$BUILT_IN" ] || { echo "      missing skills/article-diagram-styles/data/built-in-styles.json"; return 1; }
  python3 - "$BUILT_IN" <<'PYEOF'
import json, sys
styles = json.load(open(sys.argv[1], encoding="utf-8")).get("finish_profiles")
if not isinstance(styles, dict) or len(styles) < 16:
    print("      read %s styles, fewer than the sixteen shipped before" % (len(styles) if isinstance(styles, dict) else "no"))
    sys.exit(1)
problems = []
for key in ("line", "fill", "lettering"):
    seen = {}
    for name, style in styles.items():
        value = style.get(key) if isinstance(style, dict) else None
        if not isinstance(value, str):
            continue  # A missing field is the specification check's to report.
        words = value.strip().lower()
        if words in seen:
            problems.append("%s and %s share the same %s" % (seen[words], name, key))
        seen.setdefault(words, name)
for problem in problems[:12]:
    print("      " + problem)
sys.exit(1 if problems else 0)
PYEOF
}
check "no two built-in styles share a line, a fill, or lettering" built_in_distinct

# In a sample run with the same content, four styles drifted from their definitions: flat-vector
# kept light gradients in its header band and icons, isometric drew its boxes in an oblique view,
# minimal used its accent color in several places, and comic-panel added clouds that explained
# nothing. Their definitions now say what they forbid, each in a sentence that starts with never.
drifted_styles_forbid() {
  [ -f "$BUILT_IN" ] || { echo "      missing skills/article-diagram-styles/data/built-in-styles.json"; return 1; }
  python3 - "$BUILT_IN" <<'PYEOF'
import json, re, sys
styles = json.load(open(sys.argv[1], encoding="utf-8")).get("finish_profiles", {})
want = {
    "flat-vector": ("gradients, even light ones in a header band or an icon",
                    [r"\bnever\b[^.;]*\bgradients?\b", r"\bheader band\b", r"\bicons?\b"]),
    "isometric": ("an oblique view", [r"\btrue 30-degree isometric projection\b", r"\bnever\b[^.;]*\boblique\b"]),
    "minimal": ("a second place for the accent color", [r"\bone place\b", r"\bnever\b[^.;]*\bsecond place\b"]),
    "comic-panel": ("decoration unrelated to the content",
                    [r"\bnever\b[^.;]*\bdecoration\b[^.;]*\bunrelated to the content\b"]),
}
problems = []
for name, (forbidden, patterns) in want.items():
    style = styles.get(name)
    if not isinstance(style, dict):
        problems.append("there is no built-in style %s" % name)
        continue
    text = " ".join(str(style.get(key, "")) for key in ("line", "fill", "background", "lettering"))
    missing = [pattern for pattern in patterns if not re.search(pattern, text, re.I)]
    if missing:
        problems.append("%s does not forbid %s: it lacks %s" % (name, forbidden, ", ".join(missing)))
for problem in problems:
    print("      " + problem)
sys.exit(1 if problems else 0)
PYEOF
}
check "the four styles that drifted name what they forbid" drifted_styles_forbid

built_in_no_samples() {
  [ -f "$BUILT_IN" ] || { echo "      missing skills/article-diagram-styles/data/built-in-styles.json"; return 1; }
  python3 - "$BUILT_IN" <<'PYEOF'
import json, sys
found = []
def walk(value, where):
    if isinstance(value, dict):
        for key, item in value.items():
            if key in ("images", "reference_id", "sample_ids"):
                found.append(where + key)
            walk(item, where + key + ".")
    elif isinstance(value, list):
        for index, item in enumerate(value):
            walk(item, "%s%d." % (where, index))
walk(json.load(open(sys.argv[1], encoding="utf-8")), "")
for key in found:
    print("      the built-in styles hold " + key)
sys.exit(1 if found else 0)
PYEOF
}
check "the built-in styles name no sample image" built_in_no_samples

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

# A HOME without .styles, and a HOME whose .styles holds sample images but no catalog.
validate_without_catalog() {
  local h status
  for h in "$T/h-none" "$T/h-nocat"; do
    mkdir -p "$h"
    [ "$h" = "$T/h-nocat" ] && styles "$h/.styles" --no-catalog
    HOME="$h" catalog "$h.out" --validate
    status=$?
    exits 0 "$status" "$h.out" "32 built-in styles" "style-catalog.json is missing" || { echo "      (HOME ${h#"$T"/})"; return 1; }
  done
}
check "validate passes with only the built-in styles when ~/.styles has no catalog" validate_without_catalog

validate_refuses_broken_home() {
  local status
  mkdir -p "$T/h-broken"
  styles "$T/h-broken/.styles" --schema 1
  HOME="$T/h-broken" catalog "$T/h-broken.out" --validate
  status=$?
  exits 1 "$status" "$T/h-broken.out" "schema_version" || return 1
  ! grep -q '^PASS' "$T/h-broken.out" || { echo "      the run passed on the built-in styles alone"; return 1; }
}
check "validate refuses a broken catalog under HOME instead of falling back to the built-in styles" validate_refuses_broken_home

# field <out> <name> <n>: the n-th tab-separated field of every --list line of the style <name>.
field() { awk -F'\t' -v n="$2" -v i="$3" '$1 == n { print $i }' "$1"; }

# lines_of <out> <name>: the number of --list lines of the style <name>.
lines_of() { awk -F'\t' -v n="$2" '$1 == n' "$1" | grep -c .; }

list_built_in() {
  local status
  mkdir -p "$T/h-list"
  HOME="$T/h-list" catalog "$T/h-list.out" --list
  status=$?
  exits 0 "$status" "$T/h-list.out" || return 1
  [ -f "$BUILT_IN" ] || { echo "      missing skills/article-diagram-styles/data/built-in-styles.json"; return 1; }
  python3 - "$T/h-list.out" "$BUILT_IN" <<'PYEOF'
import json, sys
lines = [line for line in open(sys.argv[1], encoding="utf-8").read().splitlines() if line.strip()]
styles = json.load(open(sys.argv[2], encoding="utf-8")).get("finish_profiles", {})
problems = []
if len(lines) != 32:
    problems.append("printed %d lines, not 32" % len(lines))
for name, style in styles.items():
    rows = [line.split("\t") for line in lines if line.split("\t")[0] == name]
    if len(rows) != 1:
        problems.append("%s is on %d lines, not one" % (name, len(rows)))
        continue
    row = rows[0]
    if len(row) != 5 or row[1] != "built-in":
        problems.append("the line of %s is not name, built-in, family, label, and suits: %r" % (name, row))
        continue
    if row[2] != style.get("family"):
        problems.append("the line of %s names the family %s, not %s" % (name, row[2], style.get("family")))
    missing = [s for s in style.get("suits", []) if s not in row[4].split("; ")]
    if missing:
        problems.append("the line of %s lacks the suits %s" % (name, missing))
for problem in problems[:12]:
    print("      " + problem)
sys.exit(1 if problems else 0)
PYEOF
}
check "list prints the thirty-two built-in styles without ~/.styles" list_built_in

list_user_styles() {
  local status name
  mkdir -p "$T/h-list-user"
  styles "$T/h-list-user/.styles" --user-style
  HOME="$T/h-list-user" catalog "$T/h-list-user.out" --list
  status=$?
  exits 0 "$status" "$T/h-list-user.out" || return 1
  [ "$(lines_of "$T/h-list-user.out" my-style)" -eq 1 ] && [ "$(field "$T/h-list-user.out" my-style 2)" = user ] ||
    { echo "      my-style is not on one line marked user"; sed 's/^/        /' "$T/h-list-user.out" | head -8; return 1; }
  for name in $BUILT_IN_NAMES; do
    [ "$(lines_of "$T/h-list-user.out" "$name")" -eq 1 ] || { echo "      the built-in style $name is not on one line"; return 1; }
  done
  [ "$(field "$T/h-list-user.out" watercolor 2)" = built-in ] || { echo "      watercolor is not marked built-in"; return 1; }
}
check "list prints the user's styles beside the built-in ones" list_user_styles

list_redefined_once() {
  local status
  mkdir -p "$T/h-list-redefined"
  styles "$T/h-list-redefined/.styles"
  HOME="$T/h-list-redefined" catalog "$T/h-list-redefined.out" --list
  status=$?
  exits 0 "$status" "$T/h-list-redefined.out" || return 1
  [ "$(lines_of "$T/h-list-redefined.out" pen-technical)" -eq 1 ] || { echo "      pen-technical is not on exactly one line"; return 1; }
  [ "$(field "$T/h-list-redefined.out" pen-technical 2)" = user ] || { echo "      the line of pen-technical is not marked user"; return 1; }
}
check "list prints a built-in style the user redefined once, as the user's" list_redefined_once

list_leaves_out_retired() {
  local status
  mkdir -p "$T/h-list-retired"
  styles "$T/h-list-retired/.styles" --retire newsprint
  HOME="$T/h-list-retired" catalog "$T/h-list-retired.out" --list
  status=$?
  exits 0 "$status" "$T/h-list-retired.out" || return 1
  [ "$(lines_of "$T/h-list-retired.out" newsprint)" -eq 0 ] || { echo "      the retired newsprint is listed"; return 1; }
  [ "$(lines_of "$T/h-list-retired.out" watercolor)" -eq 1 ] || { echo "      watercolor is not listed, so the run proves nothing"; return 1; }
}
check "list leaves out a built-in style the user retired" list_leaves_out_retired

list_refuses_broken() {
  local status
  mkdir -p "$T/h-list-broken"
  styles "$T/h-list-broken/.styles" --schema 1
  HOME="$T/h-list-broken" catalog "$T/h-list-broken.out" --list
  status=$?
  exits 1 "$status" "$T/h-list-broken.out" "schema_version" || return 1
  [ "$(lines_of "$T/h-list-broken.out" watercolor)" -eq 0 ] || { echo "      the run listed the built-in styles"; return 1; }
}
check "list refuses a broken catalog instead of falling back to the built-in styles" list_refuses_broken

# shown <out> <python expression over the printed JSON s and the built-in watercolor w>: the expression holds.
shown() {
  python3 - "$1" "$BUILT_IN" "$2" <<'PYEOF'
import json, sys
try:
    s = json.load(open(sys.argv[1], encoding="utf-8"))
    w = json.load(open(sys.argv[2], encoding="utf-8"))["finish_profiles"]["watercolor"]
except (OSError, ValueError, KeyError) as error:
    print("      cannot read the shown style or the built-in watercolor: %s" % error)
    sys.exit(1)
if not eval(sys.argv[3]):
    print("      the shown style does not hold: " + sys.argv[3])
    print("        " + json.dumps(s)[:300])
    sys.exit(1)
PYEOF
}

show_built_in() {
  local status
  mkdir -p "$T/h-show"
  HOME="$T/h-show" catalog "$T/h-show.out" --show watercolor
  status=$?
  exits 0 "$status" "$T/h-show.out" || return 1
  shown "$T/h-show.out" 'all(s.get(k) == w[k] for k in ("line", "fill", "background", "lettering", "suits")) and s.get("source") == "built-in" and s.get("samples") == []'
}
check "show prints a built-in style without ~/.styles" show_built_in

validate_built_in_samples() {
  local status
  mkdir -p "$T/h-wash"
  styles "$T/h-wash/.styles" --built-in-sample watercolor painting-and-print
  HOME="$T/h-wash" catalog "$T/h-wash.out" --validate
  status=$?
  exits 0 "$status" "$T/h-wash.out" "PASS"
}
check "validate accepts samples registered to a built-in style" validate_built_in_samples

show_user_samples() {
  local status
  mkdir -p "$T/h-wash-show"
  styles "$T/h-wash-show/.styles" --built-in-sample watercolor painting-and-print
  HOME="$T/h-wash-show" catalog "$T/h-wash-show.out" --show watercolor
  status=$?
  exits 0 "$status" "$T/h-wash-show.out" || return 1
  shown "$T/h-wash-show.out" "s.get('line') == w['line'] and s.get('samples') == ['$T/h-wash-show/.styles/style-catalog/painting-and-print/watercolor/watercolor-f.png']"
}
check "show prints the user's samples of a built-in style" show_user_samples

show_user_definition() {
  local status
  mkdir -p "$T/h-pen-show"
  styles "$T/h-pen-show/.styles"
  HOME="$T/h-pen-show" catalog "$T/h-pen-show.out" --show pen-technical
  status=$?
  exits 0 "$status" "$T/h-pen-show.out" || return 1
  shown "$T/h-pen-show.out" "s.get('line') == 'black pen with a light wobble' and s.get('source') == 'user'"
}
check "show prints the user's definition of a redefined built-in style" show_user_definition

show_refuses() {
  local status name
  mkdir -p "$T/h-show-refuse"
  styles "$T/h-show-refuse/.styles" --retire newsprint
  for name in newsprint no-such-style; do
    HOME="$T/h-show-refuse" catalog "$T/h-show-refuse.out" --show "$name"
    status=$?
    exits 1 "$status" "$T/h-show-refuse.out" "$name" || { echo "      (--show $name)"; return 1; }
  done
}
check "show refuses a retired or unknown style" show_refuses

validate_retired_alone() {
  local status
  mkdir -p "$T/h-retire"
  styles "$T/h-retire/.styles" --retire newsprint
  jq -e '.finish_profiles.newsprint == {"status": "retired"}' "$T/h-retire/.styles/style-catalog.json" > /dev/null ||
    { echo "      the fixture's newsprint holds more than its status"; return 1; }
  HOME="$T/h-retire" catalog "$T/h-retire.out" --validate
  status=$?
  exits 0 "$status" "$T/h-retire.out" "PASS"
}
check "validate accepts a built-in style retired by status alone" validate_retired_alone

validate_refuses_unknown_style_image() {
  local status
  mkdir -p "$T/h-unknown"
  styles "$T/h-unknown/.styles" --built-in-sample no-such-style painting-and-print
  HOME="$T/h-unknown" catalog "$T/h-unknown.out" --validate
  status=$?
  exits 1 "$status" "$T/h-unknown.out" "no-such-style-f"
}
check "validate refuses an image of a style that is neither built in nor in the catalog" validate_refuses_unknown_style_image

STRUCTURES="$SKILL_DIR/data/built-in-structures.json"
STRUCTURE_NAMES="process-flow message-sequence timeline cycle layers tree nesting network side-by-side before-after two-axis-matrix correspondence-table state-machine decision-branch quantity-trend journey-map"

# Each built-in structure is defined in words, and no two of them share the relation they show or
# their parts, compared without case and outer spaces.
built_in_structures() {
  [ -f "$STRUCTURES" ] || { echo "      missing skills/article-diagram-styles/data/built-in-structures.json"; return 1; }
  python3 - "$STRUCTURES" <<'PYEOF'
import json, sys
want = {
    "flow-and-order": ["process-flow", "message-sequence", "timeline", "cycle"],
    "structure-and-containment": ["layers", "tree", "nesting", "network"],
    "comparison": ["side-by-side", "before-after", "two-axis-matrix", "correspondence-table"],
    "state-and-change": ["state-machine", "decision-branch", "quantity-trend", "journey-map"],
}
try:
    structures = json.load(open(sys.argv[1], encoding="utf-8")).get("structures")
except (OSError, ValueError, AttributeError) as error:
    print("      cannot read the built-in structures: %s" % error)
    sys.exit(1)
if not isinstance(structures, dict):
    print("      structures is not an object")
    sys.exit(1)
problems = []
names = [n for members in want.values() for n in members]
if sorted(structures) != sorted(names):
    problems.append("the structures are %s, not the sixteen" % sorted(structures))
text = lambda value: isinstance(value, str) and bool(value.strip())
for group, members in want.items():
    for name in members:
        structure = structures.get(name)
        if not isinstance(structure, dict):
            continue
        if structure.get("group") != group:
            problems.append("%s is in %s, not %s" % (name, structure.get("group"), group))
        for key in ("label", "shows", "parts", "reading_order", "fits", "misfits"):
            if not text(structure.get(key)):
                problems.append("%s has no %s" % (name, key))
        if structure.get("status") != "active":
            problems.append("%s has status %s, not active" % (name, structure.get("status")))
for key in ("shows", "parts"):
    seen = {}
    for name, structure in structures.items():
        value = structure.get(key) if isinstance(structure, dict) else None
        if not isinstance(value, str):
            continue  # A missing field is reported above.
        words = value.strip().lower()
        if words in seen:
            problems.append("%s and %s share the same %s" % (seen[words], name, key))
        seen.setdefault(words, name)
for problem in problems[:12]:
    print("      " + problem)
sys.exit(1 if problems else 0)
PYEOF
}
check "the built-in structures hold sixteen structures in four groups with their written definition" built_in_structures

built_in_structures_no_samples() {
  [ -f "$STRUCTURES" ] || { echo "      missing skills/article-diagram-styles/data/built-in-structures.json"; return 1; }
  python3 - "$STRUCTURES" <<'PYEOF'
import json, sys
found = []
def walk(value, where):
    if isinstance(value, dict):
        for key, item in value.items():
            if key in ("images", "reference_id", "sample_ids"):
                found.append(where + key)
            walk(item, where + key + ".")
    elif isinstance(value, list):
        for index, item in enumerate(value):
            walk(item, "%s%d." % (where, index))
walk(json.load(open(sys.argv[1], encoding="utf-8")), "")
for key in found:
    print("      the built-in structures hold " + key)
sys.exit(1 if found else 0)
PYEOF
}
check "the built-in structures name no sample image" built_in_structures_no_samples

structures_built_in() {
  local status
  mkdir -p "$T/h-structures"
  HOME="$T/h-structures" catalog "$T/h-structures.out" --structures
  status=$?
  exits 0 "$status" "$T/h-structures.out" || return 1
  [ -f "$STRUCTURES" ] || { echo "      missing skills/article-diagram-styles/data/built-in-structures.json"; return 1; }
  python3 - "$T/h-structures.out" "$STRUCTURES" <<'PYEOF'
import json, sys
lines = [line for line in open(sys.argv[1], encoding="utf-8").read().splitlines() if line.strip()]
structures = json.load(open(sys.argv[2], encoding="utf-8")).get("structures", {})
problems = []
if len(lines) != 16 or len(structures) != 16:
    problems.append("printed %d lines for %d built-in structures, not 16 for 16" % (len(lines), len(structures)))
for name, structure in structures.items():
    rows = [line.split("\t") for line in lines if line.split("\t")[0] == name]
    if len(rows) != 1:
        problems.append("%s is on %d lines, not one" % (name, len(rows)))
        continue
    row = rows[0]
    want = [name, "built-in", structure.get("group"), structure.get("label"), structure.get("shows")]
    if row != want:
        problems.append("the line of %s is %r, not name, built-in, group, label, and shows" % (name, row))
for problem in problems[:12]:
    print("      " + problem)
sys.exit(1 if problems else 0)
PYEOF
}
check "structures prints the sixteen built-in structures without ~/.styles" structures_built_in

structures_user() {
  local status name
  mkdir -p "$T/h-structures-user"
  styles "$T/h-structures-user/.styles" --user-structure
  HOME="$T/h-structures-user" catalog "$T/h-structures-user.out" --structures
  status=$?
  exits 0 "$status" "$T/h-structures-user.out" || return 1
  [ "$(lines_of "$T/h-structures-user.out" my-structure)" -eq 1 ] && [ "$(field "$T/h-structures-user.out" my-structure 2)" = user ] ||
    { echo "      my-structure is not on one line marked user"; sed 's/^/        /' "$T/h-structures-user.out" | head -8; return 1; }
  for name in $STRUCTURE_NAMES; do
    [ "$(lines_of "$T/h-structures-user.out" "$name")" -eq 1 ] || { echo "      the built-in structure $name is not on one line"; return 1; }
  done
  [ "$(field "$T/h-structures-user.out" process-flow 2)" = built-in ] || { echo "      process-flow is not marked built-in"; return 1; }
}
check "structures prints the user's structures beside the built-in ones" structures_user

structures_redefined_once() {
  local status
  mkdir -p "$T/h-structures-redefined"
  styles "$T/h-structures-redefined/.styles" --redefine-structure timeline
  HOME="$T/h-structures-redefined" catalog "$T/h-structures-redefined.out" --structures
  status=$?
  exits 0 "$status" "$T/h-structures-redefined.out" || return 1
  [ "$(lines_of "$T/h-structures-redefined.out" timeline)" -eq 1 ] || { echo "      timeline is not on exactly one line"; return 1; }
  [ "$(field "$T/h-structures-redefined.out" timeline 2)" = user ] || { echo "      the line of timeline is not marked user"; return 1; }
  [ "$(field "$T/h-structures-redefined.out" timeline 5)" = "The user's own words for timeline" ] ||
    { echo "      the line of timeline does not show the user's words"; return 1; }
}
check "structures prints a built-in structure the user redefined once, as the user's" structures_redefined_once

structures_leave_out_retired() {
  local status
  mkdir -p "$T/h-structures-retired"
  styles "$T/h-structures-retired/.styles" --retire-structure timeline
  HOME="$T/h-structures-retired" catalog "$T/h-structures-retired.out" --structures
  status=$?
  exits 0 "$status" "$T/h-structures-retired.out" || return 1
  [ "$(lines_of "$T/h-structures-retired.out" timeline)" -eq 0 ] || { echo "      the retired timeline is listed"; return 1; }
  [ "$(lines_of "$T/h-structures-retired.out" process-flow)" -eq 1 ] || { echo "      process-flow is not listed, so the run proves nothing"; return 1; }
}
check "structures leaves out a built-in structure the user retired" structures_leave_out_retired

# A catalog whose structures are whole, redefined, or retired passes, so the refusal below is about
# the missing field and not about the structures object itself.
validate_refuses_half_structure() {
  local status
  mkdir -p "$T/h-structure-whole" "$T/h-structure-half"
  styles "$T/h-structure-whole/.styles" --user-structure --redefine-structure timeline --retire-structure cycle
  HOME="$T/h-structure-whole" catalog "$T/h-structure-whole.out" --validate
  status=$?
  exits 0 "$status" "$T/h-structure-whole.out" "PASS" || { echo "      (a catalog with whole structures)"; return 1; }
  styles "$T/h-structure-half/.styles" --structure-lacks shows
  HOME="$T/h-structure-half" catalog "$T/h-structure-half.out" --validate
  status=$?
  exits 1 "$status" "$T/h-structure-half.out" "my-structure" "shows"
}
check "validate refuses a catalog structure without its written definition" validate_refuses_half_structure

show_structure_built_in() {
  local status
  mkdir -p "$T/h-show-structure"
  HOME="$T/h-show-structure" catalog "$T/h-show-structure.out" --show-structure process-flow
  status=$?
  exits 0 "$status" "$T/h-show-structure.out" || return 1
  python3 - "$T/h-show-structure.out" "$STRUCTURES" <<'PYEOF'
import json, sys
try:
    s = json.load(open(sys.argv[1], encoding="utf-8"))
    b = json.load(open(sys.argv[2], encoding="utf-8"))["structures"]["process-flow"]
except (OSError, ValueError, KeyError) as error:
    print("      cannot read the shown structure or the built-in process-flow: %s" % error)
    sys.exit(1)
keys = ("group", "label", "shows", "parts", "reading_order", "fits", "misfits", "status")
wrong = [k for k in keys if s.get(k) != b.get(k)]
if wrong or s.get("name") != "process-flow" or s.get("source") != "built-in":
    print("      the shown structure differs from the built-in process-flow in %s" % (wrong or "its name or source"))
    print("        " + json.dumps(s)[:300])
    sys.exit(1)
PYEOF
}
check "show-structure prints a built-in structure without ~/.styles" show_structure_built_in

show_structure_refuses() {
  local status
  mkdir -p "$T/h-show-structure-retired"
  styles "$T/h-show-structure-retired/.styles" --retire-structure timeline
  HOME="$T/h-show-structure-retired" catalog "$T/h-show-structure-retired.out" --show-structure timeline
  status=$?
  exits 1 "$status" "$T/h-show-structure-retired.out" timeline retired || return 1
  HOME="$T/h-show-structure-retired" catalog "$T/h-show-structure-retired.out" --show-structure no-such-structure
  status=$?
  exits 1 "$status" "$T/h-show-structure-retired.out" no-such-structure || { echo "      (an unknown structure)"; return 1; }
}
check "show-structure refuses a structure the user retired" show_structure_refuses

article_draws_built_in() {
  has "$SKILL_DIR/SKILL.md" 'If `~/.styles/style-catalog.json` is missing, draw in the built-in styles'
}
check "the article skill draws in the built-in styles without a catalog" article_draws_built_in

# The lines of the article SKILL.md that speak of a missing catalog never stop the skill.
article_does_not_stop() {
  python3 - "$SKILL_DIR/SKILL.md" <<'PYEOF'
import sys
lines = [l for l in open(sys.argv[1], encoding="utf-8") if "style-catalog.json" in l and "missing" in l]
if not lines:
    print("      no line of SKILL.md speaks of a missing style-catalog.json")
    sys.exit(1)
stops = [l.strip() for l in lines if "stop" in l]
for line in stops:
    print("      " + line[:160])
sys.exit(1 if stops else 0)
PYEOF
}
check "the article skill does not stop when the catalog is missing" article_does_not_stop

names_a_style() {
  has "$SKILL_DIR/SKILL.md" 'When the user or the `finish_profile` of the figure request names a style, draw in that style'
}
check "the article skill draws in the style the user names" names_a_style

picks_a_style() {
  has "$SKILL_DIR/SKILL.md" 'When no style is named, compare the topic of the article and the kinds of its figures with the `suits` of each style `--list` prints' \
    'choose one style for the article, and tell the user which style you chose and why'
}
check "the article skill picks a style from the topic and the figure kinds and says why" picks_a_style

falls_back() { has "$SKILL_DIR/SKILL.md" 'When no style clearly fits, draw in `handdraft`'; }
check "the article skill falls back to handdraft" falls_back

stops_on_unknown_style() {
  has "$SKILL_DIR/SKILL.md" 'When the named style is neither built in nor in the catalog, when it is retired, or when no style fits and `handdraft` is retired, do not draw' \
    'show the user the styles `--list` prints and ask them to choose one'
}
check "the article skill stops on an unknown or retired style and shows the list" stops_on_unknown_style

passes_samples_only() {
  has "$SKILL_DIR/SKILL.md" 'Pass the images `--show` prints under `samples` to the image generation as style references only when that list is not empty' \
    'when it is empty, draw from the written specification alone'
}
check "the article skill passes samples only when the user registered them for the chosen style" passes_samples_only

one_style() { has "$SKILL_DIR/SKILL.md" "Keep the article's drawing style across its figures, unless the user names several styles"; }
check "the article skill keeps one style across the figures of an article" one_style

chooses_a_structure() {
  has "$SKILL_DIR/SKILL.md" \
    'choose a structure for each figure from the question the reader wants answered, among the structures `--structures` prints' \
    'Record the name of the chosen structure in `structure`, both in the figure spec and in the entry of the figure in `composition-ledger.json`' \
    'Use the `structure-comparison` mode only when the user asks to compare the same content in different structures' \
    'draw as many structures as the user asks for, and three when no number is given' \
    'Choose the structure and the style separately; any structure can be drawn in any style'
}
check "SKILL.md says how a structure is chosen and recorded" chooses_a_structure

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
        HOME="$h" python3 "$s" --structures > /dev/null 2>&1
        HOME="$h" python3 "$s" --show-structure process-flow > /dev/null 2>&1
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
for name, version in (("style-catalog", "1.2.0"), ("figure-request", "1.2.0"), ("style4", "1.1.0")):
    item = provides.get(name)
    if not isinstance(item, dict):
        problems.append("provides no " + name)
        continue
    if item.get("version") != version:
        problems.append(name + " is at version " + str(item.get("version")) + ", not " + version)
    if not item.get("file") or not os.path.isfile(os.path.join(skill, item["file"])):
        problems.append(name + " names a file that does not exist: " + str(item.get("file")))
for problem in problems:
    print("      " + problem)
sys.exit(1 if problems else 0)
PYEOF
}
check "article-diagram-styles provides style-catalog and figure-request at 1.2.0 and style4 at 1.1.0" provides_three

pages_say_built_in() {
  local page bad=0
  for page in README.md docs/how-it-works.md; do
    has "$PLUGIN/$page" "thirty-two built-in styles" "defined in words" '`article-diagram-styles` draws without `~/.styles/`' \
      "adds styles beside the built-in ones" "replaces the built-in style of the same name" '`retired`' \
      '`tech-book-figure` draws from the written style4 rules without `~/.styles/`' || bad=1
  done
  for page in README.ja.md docs/how-it-works.ja.md; do
    has "$PLUGIN/$page" "32の既定の画風" "文で定義" '`~/.styles/`が無くても`article-diagram-styles`は描きます' \
      "既定の画風の横に画風を足し" "同じ名前の既定の画風を置き換え" '`retired`' \
      '`~/.styles/`が無くても`tech-book-figure`は文で書いたstyle4の決まりで描きます' || bad=1
  done
  return "$bad"
}
check "the pages say both skills draw without ~/.styles" pages_say_built_in

pages_say_structures() {
  local page bad=0
  for page in README.md docs/how-it-works.md; do
    has "$PLUGIN/$page" "sixteen built-in structures" "chosen apart from the style" || bad=1
  done
  for page in README.ja.md docs/how-it-works.ja.md; do
    has "$PLUGIN/$page" "16の既定の構図" "構図は画風と別に選び" || bad=1
  done
  return "$bad"
}
check "the pages say the built-in structures are chosen apart from the style" pages_say_structures

# The plugin's files, the root pages, and the marketplace no longer give sixteen as the number of
# built-in styles. The tests are left out, and so are the released sections of the changelog, which
# keep what each release shipped. A count of sixteen colors in a style's own words is not a count
# of styles, and neither is the count of the sixteen built-in structures, so only sixteen followed
# by styles or by built-in without structures, or 16 followed by 画風, is counted.
no_sixteen() {
  {
    find "$PLUGIN" -type f -not -path '*/tests/*'
    printf '%s\n' "$REPO/README.md" "$REPO/README.ja.md" "$REPO/.claude-plugin/marketplace.json"
  } > "$T/sixteen-files"
  includes_skills "$T/sixteen-files" || return 1
  python3 - "$T/sixteen-files" "$REPO" "$PLUGIN/CHANGELOG.md" <<'PYEOF'
import re, sys
listed, repo, changelog = sys.argv[1:4]
paths = [path for path in open(listed, encoding="utf-8").read().split("\n") if path]
needed = ["README.md", "README.ja.md", ".claude-plugin/marketplace.json", "plugins/diagram-styles/README.md",
          "plugins/diagram-styles/THIRD_PARTY_NOTICES.md", "plugins/diagram-styles/CHANGELOG.md",
          "plugins/diagram-styles/skills/article-diagram-styles/references/style-families.md"]
problems = ["the counted files do not include " + p for p in needed if repo + "/" + p not in paths]
count = re.compile(r"\b(?:sixteen|16)\s+(?:built-in\s+)?(?:drawing\s+)?styles?\b"
                   r"|\b(?:sixteen|16)\s+built-in\b(?!\s+(?:figure\s+)?structures?\b)"
                   r"|16\s*(?:種類?)?の(?:既定の)?画風", re.I)
# The pattern still counts the styles and lets the structures pass.
for line, counted in (("ships sixteen built-in styles", True), ("sixteen built-in ones", True), ("16の既定の画風", True),
                      ("ships sixteen built-in structures", False), ("16の既定の構図", False)):
    if bool(count.search(line)) != counted:
        problems.append("the pattern %s %r" % ("misses" if counted else "counts", line))
for path in paths:
    data = open(path, "rb").read()
    if b"\0" in data:
        continue  # A binary file such as the font holds no words.
    released = False
    for number, line in enumerate(data.decode("utf-8", "replace").splitlines(), 1):
        if path == changelog and line.startswith("## ["):
            released = not line.startswith("## [Unreleased]")
        if released:
            continue
        if count.search(line):
            problems.append("%s:%d names sixteen built-in styles" % (path[len(repo) + 1:], number))
for problem in problems[:12]:
    print("      " + problem)
sys.exit(1 if problems else 0)
PYEOF
}
check "no page names sixteen built-in styles" no_sixteen

descriptions_say_built_in() {
  local f bad=0
  for f in .claude-plugin/plugin.json .codex-plugin/plugin.json; do
    jq -r .description "$PLUGIN/$f" | grep -qF "built-in styles" || { echo "      the description of $f lacks: built-in styles"; bad=1; }
  done
  jq -r '.plugins[] | select(.name == "diagram-styles") | .description' "$REPO/.claude-plugin/marketplace.json" | grep -qF "built-in styles" ||
    { echo "      the marketplace description of diagram-styles lacks: built-in styles"; bad=1; }
  grep '^description: ' "$SKILL_DIR/SKILL.md" | grep -qF "built-in styles" || { echo "      the SKILL.md description lacks: built-in styles"; bad=1; }
  grep '^  short_description: ' "$SKILL_DIR/agents/openai.yaml" | grep -qF "built-in styles" ||
    { echo "      the short_description of agents/openai.yaml lacks: built-in styles"; bad=1; }
  return "$bad"
}
check "the descriptions say the plugin ships built-in styles" descriptions_say_built_in

catalog_page() {
  has "$SKILL_DIR/references/style-catalog.md" '`data/built-in-styles.json`' '`suits`' \
    "replaces the built-in style of the same name" "takes the built-in style of the same name out of use" \
    "may name a built-in style"
}
check "the catalog page describes the built-in styles and how a catalog adds, replaces, and retires them" catalog_page

request_page() {
  has "$SKILL_DIR/references/figure-request.md" 'A built-in style, or a style of `~/.styles/style-catalog.json` whose `status` is `active`'
}
check "the figure request takes a built-in style or a style of the catalog" request_page

request_structure() {
  has "$SKILL_DIR/references/figure-request.md" '`figures[].structure`' \
    'A built-in structure, or a structure of `~/.styles/style-catalog.json` whose `status` is `active`, by the name `--structures` prints' \
    '`structure-comparison` only when the user asked to compare the same content in different structures'
}
check "the figure request names a structure and the structure comparison" request_structure

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

# review_and_contract <HOME> <work> <out prefix>: runs the review check and the contract check on the
# records of the work folder, leaving their exits in REVIEW_STATUS and CONTRACT_STATUS.
review_and_contract() {
  (cd "$SCRIPTS" && HOME="$1" python3 "$SCRIPTS/validate_anchor_candidate.py" --review "$2/review.json") > "$3-review.out" 2>&1
  REVIEW_STATUS=$?
  (cd "$SCRIPTS" && HOME="$1" python3 "$SCRIPTS/validate_visual_contract.py" --contract "$2/contract.json" --figure-spec "$2/contract-spec.json") > "$3-contract.out" 2>&1
  CONTRACT_STATUS=$?
}

accepts_built_in_records() {
  local h="$T/h-rec" w="$T/w-rec"
  mkdir -p "$h"
  python3 "$FIXTURES" work "$w" --style line-drawing --finish handdraft > /dev/null
  review_and_contract "$h" "$w" "$T/rec"
  exits 0 "$REVIEW_STATUS" "$T/rec-review.out" || { echo "      (the review check)"; return 1; }
  exits 0 "$CONTRACT_STATUS" "$T/rec-contract.out" || { echo "      (the contract check)"; return 1; }
}
check "the review and contract checks accept a built-in style without ~/.styles" accepts_built_in_records

refuses_retired_records() {
  local h="$T/h-rec-retired" w="$T/w-rec-retired"
  mkdir -p "$h"
  styles "$h/.styles" --retire newsprint
  python3 "$FIXTURES" work "$w" --style illustrated --finish newsprint > /dev/null
  review_and_contract "$h" "$w" "$T/rec-retired"
  exits 1 "$REVIEW_STATUS" "$T/rec-retired-review.out" newsprint || { echo "      (the review check)"; return 1; }
  exits 1 "$CONTRACT_STATUS" "$T/rec-retired-contract.out" newsprint || { echo "      (the contract check)"; return 1; }
}
check "the review and contract checks refuse a built-in style the user retired" refuses_retired_records

accepts_user_family() {
  local h="$T/h-rec-mine" w="$T/w-rec-mine"
  mkdir -p "$h"
  styles "$h/.styles" --user-style
  python3 "$FIXTURES" work "$w" --style my-family --finish my-style > /dev/null
  review_and_contract "$h" "$w" "$T/rec-mine"
  exits 0 "$CONTRACT_STATUS" "$T/rec-mine-contract.out"
}
check "the contract check accepts a family from the user's catalog" accepts_user_family

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

# ledger_fixture <work> [options]: a composition ledger and its figure specs (see tests/fixtures.py).
ledger_fixture() { python3 "$FIXTURES" ledger "$@" > /dev/null; }

# ledger_check <HOME> <work> <out>: runs the ledger check on the ledger of the work folder, keeps its
# output in <out>, and returns its exit.
ledger_check() {
  [ -f "$SCRIPTS/validate_composition_ledger.py" ] || { echo "      missing scripts/validate_composition_ledger.py" > "$3"; return 127; }
  HOME="$1" python3 "$SCRIPTS/validate_composition_ledger.py" --ledger "$2/ledger.json" > "$3" 2>&1
}

# The check names the structures it read when it passes, so a run that ignores structure does not
# pass this check.
ledger_accepts_structures() {
  local h="$T/h-ledger" hu="$T/h-ledger-user" status
  mkdir -p "$h" "$hu"
  ledger_fixture "$T/w-ledger" --structure process-flow --structure timeline
  ledger_check "$h" "$T/w-ledger" "$T/w-ledger.out"
  status=$?
  exits 0 "$status" "$T/w-ledger.out" process-flow timeline || { echo "      (built-in structures)"; return 1; }
  styles "$hu/.styles" --user-structure
  ledger_fixture "$T/w-ledger-user" --structure my-structure
  ledger_check "$hu" "$T/w-ledger-user" "$T/w-ledger-user.out"
  status=$?
  exits 0 "$status" "$T/w-ledger-user.out" my-structure || { echo "      (a structure of the user's catalog)"; return 1; }
}
check "the ledger accepts figures that name a structure in use" ledger_accepts_structures

ledger_refuses_missing_structure() {
  local h="$T/h-ledger-refuse" kind status
  mkdir -p "$h"
  styles "$h/.styles" --retire-structure timeline
  for kind in missing unknown retired; do
    case "$kind" in
      missing) ledger_fixture "$T/w-ledger-$kind" --no-structure ;;
      unknown) ledger_fixture "$T/w-ledger-$kind" --structure no-such-structure ;;
      retired) ledger_fixture "$T/w-ledger-$kind" --structure timeline ;;
    esac
    ledger_check "$h" "$T/w-ledger-$kind" "$T/w-ledger-$kind.out"
    status=$?
    exits 1 "$status" "$T/w-ledger-$kind.out" "entry 1 structure" || { echo "      (a $kind structure)"; return 1; }
  done
}
check "the ledger refuses a figure without a structure in use" ledger_refuses_missing_structure

ledger_refuses_spec_mismatch() {
  local h="$T/h-ledger-mismatch" status
  mkdir -p "$h"
  ledger_fixture "$T/w-ledger-mismatch" --structure process-flow --spec-structure timeline
  ledger_check "$h" "$T/w-ledger-mismatch" "$T/w-ledger-mismatch.out"
  status=$?
  exits 1 "$status" "$T/w-ledger-mismatch.out" "figure spec structure"
}
check "the ledger refuses a figure spec whose structure differs from its entry" ledger_refuses_spec_mismatch

# Two, three, and five structures pass: the comparison has no upper limit.
ledger_accepts_comparison() {
  local h="$T/h-comparison" n status name
  local all=(process-flow timeline cycle layers before-after) args
  mkdir -p "$h"
  for n in 2 3 5; do
    args=()
    for name in "${all[@]:0:$n}"; do args+=(--structure "$name"); done
    ledger_fixture "$T/w-comparison-$n" --mode structure-comparison --request "Draw this in several structures." "${args[@]}"
    ledger_check "$h" "$T/w-comparison-$n" "$T/w-comparison-$n.out"
    status=$?
    exits 0 "$status" "$T/w-comparison-$n.out" structure-comparison "${all[@]:0:$n}" || { echo "      ($n structures)"; return 1; }
  done
}
check "the ledger accepts a structure comparison of two or more structures" ledger_accepts_comparison

ledger_refuses_comparison() {
  local h="$T/h-comparison-refuse" status
  mkdir -p "$h"
  ledger_fixture "$T/w-comparison-repeat" --mode structure-comparison --request "Compare the structures." \
    --structure timeline --structure cycle --structure timeline
  ledger_check "$h" "$T/w-comparison-repeat" "$T/w-comparison-repeat.out"
  status=$?
  exits 1 "$status" "$T/w-comparison-repeat.out" structure-comparison timeline || { echo "      (a repeated structure)"; return 1; }
  ledger_fixture "$T/w-comparison-one" --mode structure-comparison --request "Compare the structures." --structure timeline
  ledger_check "$h" "$T/w-comparison-one" "$T/w-comparison-one.out"
  status=$?
  exits 1 "$status" "$T/w-comparison-one.out" structure-comparison || { echo "      (one figure)"; return 1; }
  ledger_fixture "$T/w-comparison-unasked" --mode structure-comparison --structure timeline --structure cycle
  ledger_check "$h" "$T/w-comparison-unasked" "$T/w-comparison-unasked.out"
  status=$?
  exits 1 "$status" "$T/w-comparison-unasked.out" comparison_request || { echo "      (no comparison_request)"; return 1; }
}
check "the ledger refuses a structure comparison that repeats a structure or has one figure" ledger_refuses_comparison

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

# released <changelog> <version>: the lines of the ## [<version>] section.
released() { awk -v v="$2" 'index($0, "## [" v "]") == 1 {on=1; next} /^## \[/{on=0} on' "$1"; }

# Before the first release the entries sit under ## [Unreleased]; a release moves them into the
# section of the version both plugin.json files carry and leaves ## [Unreleased] empty.
changelog_line() {
  local version
  [ -f "$PLUGIN/CHANGELOG.md" ] || { echo "      missing plugins/diagram-styles/CHANGELOG.md"; return 1; }
  version="$(jq -r .version "$PLUGIN/.claude-plugin/plugin.json")"
  unreleased "$PLUGIN/CHANGELOG.md" | grep -q '^- ' && return 0
  released "$PLUGIN/CHANGELOG.md" "$version" | grep -q '^- ' ||
    { echo "      no line under ## [Unreleased] or ## [$version]"; return 1; }
}
check "the changelog has a line under Unreleased or the released version" changelog_line

# names_in_changelog <changelog> <version> <text>: a line under ## [Unreleased] or ## [<version>]
# names the text.
names_in_changelog() { { unreleased "$1"; released "$1" "$2"; } | grep '^- ' | grep -qF -- "$3"; }

# changelog_names <text>: a line of the plugin's changelog names the text. A release moves the line
# from ## [Unreleased] into its version's section, where it stays through later releases, so a line
# under ## [Unreleased] or any release counts. These shapes, and a changelog whose sections do not
# name the text, are tried on throwaway changelogs before the plugin's own changelog is read.
changelog_names() {
  local version text="$1"
  printf '# Changelog\n\n## [Unreleased]\n\n- ships %s\n\n## [0.2.0] - 2026-11-21\n\n- ships an older set of styles\n' "$text" > "$T/changelog-before"
  printf '# Changelog\n\n## [Unreleased]\n\n## [0.3.0] - 2026-11-22\n\n- ships %s\n\n## [0.2.0] - 2026-11-21\n\n- ships an older set of styles\n' "$text" > "$T/changelog-after"
  names_in_changelog "$T/changelog-before" 0.2.0 "$text" || { echo "      a line under ## [Unreleased] is not counted"; return 1; }
  names_in_changelog "$T/changelog-after" 0.3.0 "$text" || { echo "      a line under the released version is not counted"; return 1; }
  names_in_changelog "$T/changelog-after" 0.4.0 "$text" || { echo "      a line under an older release is not counted"; return 1; }
  printf '# Changelog\n\n## [Unreleased]\n\n## [0.3.0] - 2026-11-22\n\n- ships an older set of styles\n\n[%s]: https://example.com\n' "$text" > "$T/changelog-none"
  ! names_in_changelog "$T/changelog-none" 0.3.0 "$text" || { echo "      a changelog whose sections do not name the text is counted"; return 1; }
  [ -f "$PLUGIN/CHANGELOG.md" ] || { echo "      missing plugins/diagram-styles/CHANGELOG.md"; return 1; }
  version="$(jq -r .version "$PLUGIN/.claude-plugin/plugin.json")"
  names_in_changelog "$PLUGIN/CHANGELOG.md" "$version" "$text" ||
    { echo "      no section of the changelog names the $text"; return 1; }
}

changelog_thirty_two() { changelog_names "thirty-two built-in styles"; }
check "the changelog names the thirty-two built-in styles under Unreleased or any release" changelog_thirty_two

changelog_structures() { changelog_names "sixteen built-in structures"; }
check "the changelog names the built-in structures under Unreleased or any release" changelog_structures

releasing_pages() {
  has "$REPO/docs/releasing.md" 'musubi check plugins/diagram-styles/skills' &&
    has "$REPO/docs/releasing.ja.md" 'musubi check plugins/diagram-styles/skills'
}
check "the releasing pages run musubi check before releasing diagram-styles" releasing_pages

repo_checks() { bash "$REPO/scripts/check.sh" > "$T/check.out" 2>&1 || { grep -A3 '^FAIL' "$T/check.out" | head -20 | sed 's/^/      /'; return 1; }; }
check "the repository checks pass" repo_checks

printf 'article-diagram-styles: %d passed, %d failed (%d ran, %d skipped)\n' "$PASS" "$FAIL" "$((PASS + FAIL))" "$SKIP"
[ "$FAIL" -eq 0 ]
