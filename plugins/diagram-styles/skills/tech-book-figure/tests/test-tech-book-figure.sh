#!/usr/bin/env bash
# Tests for the tech-book-figure skill of the diagram-styles plugin: scripts/book_style.py, which
# tells the skill whether to draw from the written style4 rules or from the user's style4 samples
# and reads the user's theme file, the steps its SKILL.md holds for both, the written style4 rules
# it follows, the pages and the changelog, and its musubi follow of article-diagram-styles/style4
# with the lines musubi add prints. Every HOME, styles folder, repository, and theme file it uses is
# a throwaway folder; nothing reads the user's ~/.styles or theme file. The fingerprint is computed
# here the way musubi computes it, so the test needs no musubi command and reaches no network.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
PLUGIN="$(cd "$SKILL_DIR/../.." && pwd)"
REPO="$(cd "$PLUGIN/../.." && pwd)"
ARTICLE="$PLUGIN/skills/article-diagram-styles"
SCRIPT="$SKILL_DIR/scripts/book_style.py"
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

# lacks <file> <text>...: no text appears in the file.
lacks() {
  local f="$1" s
  shift
  [ -f "$f" ] || { echo "      missing ${f#"$REPO"/}"; return 1; }
  for s in "$@"; do
    if grep -qF -- "$s" "$f"; then echo "      ${f#"$REPO"/} still holds: $s"; return 1; fi
  done
}

# book <HOME> <folder> <out>: runs book_style.py from <folder> with <HOME>, keeps standard output in
# <out> and standard error in <out>.err, and returns its exit.
book() {
  : > "$3"
  : > "$3.err"
  [ -f "$SCRIPT" ] || { echo "      missing skills/tech-book-figure/scripts/book_style.py"; return 127; }
  (cd "$2" && HOME="$1" python3 "$SCRIPT") > "$3" 2> "$3.err"
}

# exits <want> <got> <out> <text>...: the run exited <want> and its standard output names every text.
exits() {
  local want="$1" got="$2" out="$3" s
  shift 3
  [ "$got" -eq "$want" ] || { echo "      exited $got, not $want"; sed 's/^/        /' "$out" "$out.err" | head -8; return 1; }
  for s in "$@"; do
    grep -qF -- "$s" "$out" || { echo "      the output does not name $s"; sed 's/^/        /' "$out" | head -8; return 1; }
  done
}

# styles <HOME> <image>...: a throwaway ~/.styles with a catalog that records the layouts of
# flow-a.png only, and the named images in diagram-style-samples/style4/.
styles() {
  local home="$1" image
  shift
  mkdir -p "$home/.styles/diagram-style-samples/style4"
  cat > "$home/.styles/style-catalog.json" <<'JSON'
{
  "schema_version": 2,
  "images": [
    {"id": "flow-a", "path": "style-catalog/line-drawing/handdraft/flow-a.png",
     "original_paths": ["diagram-style-samples/style4/flow-a.png"], "layouts": ["left-to-right-flow"]}
  ]
}
JSON
  for image in "$@"; do
    printf 'image %s\n' "$image" > "$home/.styles/diagram-style-samples/style4/$image"
  done
}

# A theme file with the six keys a figure takes, one key it holds but does not use from each other
# group, and font.size at the lowest value the shared format allows.
FULL_THEME='{
  "light": {"bg": "#fafaf7", "ink": "#111111", "sub": "#555555", "accent": "#0b6e4f", "accent-soft": "#e3f2ec", "bar": "#eeeeee"},
  "dark": {"bg": "#101312"},
  "font": {"sans": "\"Inter\", sans-serif", "size": 12},
  "space": {"page-width": 1100}
}'

mkdir -p "$T/plain"

written_without_styles() {
  local h="$T/h-none" status
  mkdir -p "$h"
  book "$h" "$T/plain" "$T/none.out"
  status=$?
  exits 0 "$status" "$T/none.out" "style4: written" "missing: ~/.styles/style-catalog.json" || return 1
  if grep -q '^sample:' "$T/none.out"; then echo "      it lists a sample without ~/.styles"; return 1; fi
  [ ! -e "$h/.styles" ] || { echo "      it created ~/.styles"; return 1; }
}
check "the book script picks the written style4 rules when HOME has no .styles" written_without_styles

# One image is just below the two the samples need; a file that is not an image is not counted.
written_with_one_sample() {
  local h="$T/h-one" status
  styles "$h" flow-a.png
  printf 'notes\n' > "$h/.styles/diagram-style-samples/style4/notes.txt"
  book "$h" "$T/plain" "$T/one.out"
  status=$?
  exits 0 "$status" "$T/one.out" "style4: written" \
    "missing: two or more images in ~/.styles/diagram-style-samples/style4/ (found 1)" || return 1
  if grep -q '^sample:' "$T/one.out"; then echo "      it lists a sample with fewer than two images"; return 1; fi
}
check "the book script draws from the written rules when fewer than two style4 samples are placed" written_with_one_sample

# Two images are the fewest that make the samples count; flow-a.png has layouts in the catalog and
# map-b.webp has none.
samples_with_two() {
  local h="$T/h-two" status
  styles "$h" flow-a.png map-b.webp
  book "$h" "$T/plain" "$T/two.out"
  status=$?
  exits 0 "$status" "$T/two.out" "style4: samples" \
    "sample: $h/.styles/diagram-style-samples/style4/flow-a.png (layouts: left-to-right-flow)" \
    "sample: $h/.styles/diagram-style-samples/style4/map-b.webp (layouts: not recorded in the catalog)" || return 1
  if grep -q '^missing:' "$T/two.out"; then echo "      it names something missing with two samples"; return 1; fi
}
check "the book script lists the style4 samples and their layouts when the catalog and two samples are placed" samples_with_two

skill_steps() {
  has "$SKILL_DIR/SKILL.md" \
    'python3 "$D/scripts/book_style.py"' \
    'When it prints `style4: written`, draw from the written style4 rules alone' \
    'When it prints `style4: samples`, choose two or more of the samples it lists' \
    'If the image generation cannot take reference images, draw from the written style4 rules alone' \
    'tell the user which of the two the figure was drawn from and what was missing'
}
check "the book skill draws from the written style4 rules and passes samples only when the script lists them" skill_steps

no_stop() {
  lacks "$SKILL_DIR/SKILL.md" \
    'stop before drawing and tell the user to put the style4 samples there' \
    'If `~/.styles/style-catalog.json` is missing, stop before drawing' \
    'If the image generation cannot take the style4 samples as reference images, stop before drawing' \
    'Do not draw from the name style4 and a description alone' || return 1
  lacks "$ARTICLE/references/style4.md" \
    'Do not guess the look from the name style4 or from these words' \
    'When fewer than two images are there, stop before drawing' \
    'never draw from the name style4 and a description alone'
}
check "the book skill no longer stops for missing style4 samples" no_stop

style4_words_enough() {
  has "$ARTICLE/references/style4.md" \
    'The words on this page are enough to draw style4' \
    '## How style4 is drawn' '- Ground:' '- Lines:' '- Letters:' '- Palette:' '- Fills:' '- Marks:' '- Print:' \
    'an add-on'
}
check "the style4 rules say their words are enough to draw" style4_words_enough

follows_style4() {
  [ -f "$SKILL_DIR/musubi.json" ] || { echo "      missing skills/tech-book-figure/musubi.json"; return 1; }
  [ -f "$ARTICLE/musubi.json" ] || { echo "      missing skills/article-diagram-styles/musubi.json"; return 1; }
  python3 - "$SKILL_DIR/musubi.json" "$ARTICLE" <<'PYEOF'
import base64, hashlib, json, os, sys
follows = json.load(open(sys.argv[1], encoding="utf-8")).get("follows", {})
provider = sys.argv[2]
style4 = json.load(open(os.path.join(provider, "musubi.json"), encoding="utf-8")).get("provides", {}).get("style4", {})
problems = []
follow = follows.get("article-diagram-styles/style4")
if not isinstance(follow, dict):
    problems.append("tech-book-figure does not follow article-diagram-styles/style4")
else:
    if follow.get("version") != "^1.0.0":
        problems.append("the follow's range is %s, not ^1.0.0" % follow.get("version"))
    if "optional" in follow:
        problems.append("the follow is marked optional")
    # musubi's fingerprint: sha256 over each file's path, byte length, and bytes, in the order the
    # provider's SKILL.md, the content file, and the check file.
    paths = ["SKILL.md", style4.get("file", "")] + ([style4["check"]] if style4.get("check") else [])
    digest = hashlib.sha256()
    try:
        for path in paths:
            data = open(os.path.join(provider, path), "rb").read()
            digest.update(("%s\n%d\n" % (path, len(data))).encode())
            digest.update(data)
            digest.update(b"\n")
        want = "sha256-" + base64.b64encode(digest.digest()).decode()
        if follow.get("integrity") != want:
            problems.append("the fingerprint is %s, not %s from the current style4 files" % (follow.get("integrity"), want))
    except OSError as error:
        problems.append("cannot read the style4 files: %s" % error)
for problem in problems:
    print("      " + problem)
sys.exit(1 if problems else 0)
PYEOF
}
check "tech-book-figure follows style4 by range and fingerprint without optional" follows_style4

# The three lines musubi add prints for a required follow of a format (musubi-cli 0.2.0).
musubi_lines() {
  has "$SKILL_DIR/SKILL.md" \
    'Write in the `style4` format of the `article-diagram-styles` skill: open the `article-diagram-styles` skill by name and read the file it names for `style4`.' \
    'If the `musubi` command is available, run `musubi check` before reading, and stop if it fails.' \
    'If the `article-diagram-styles` skill is not installed, do not start: tell the user that `article-diagram-styles` is missing and how to install it, then stop.'
}
check "the book skill holds the three lines musubi add prints" musubi_lines

theme_none() {
  local h="$T/h-theme-none" status
  mkdir -p "$h"
  book "$h" "$T/plain" "$T/theme-none.out"
  status=$?
  exits 0 "$status" "$T/theme-none.out" "theme: none" || return 1
  if grep -q '^theme light\.' "$T/theme-none.out"; then echo "      it prints theme values without a theme file"; return 1; fi
}
check "the book script keeps style4 without a theme file" theme_none

# The repository's theme wins over the home theme, which sets another accent.
repo_theme_first() {
  local h="$T/h-theme-repo" r="$T/repo" status
  mkdir -p "$h" "$r/.git" "$r/book"
  printf '%s\n' "$FULL_THEME" > "$r/.design-theme.json"
  printf '%s\n' '{"light": {"accent": "#ff0000"}}' > "$h/.design-theme.json"
  book "$h" "$r/book" "$T/theme-repo.out"
  status=$?
  exits 0 "$status" "$T/theme-repo.out" "theme: $r/.design-theme.json" \
    "theme light.bg: #fafaf7, the ground in place of white" \
    "theme light.ink: #111111, the lines and letters in place of black" \
    "theme light.sub: #555555, the gray of hatching, dotted lines, and secondary labels" \
    "theme light.accent: #0b6e4f, the first accent in place of teal" \
    "theme light.accent-soft: #e3f2ec, the light fill of the first accent" \
    'theme font.sans: "Inter", sans-serif, the letters in the look of this typeface in place of handwriting' \
    "theme not used by a figure: dark.bg, font.size, light.bar, space.page-width" || return 1
  if grep -qF '#ff0000' "$T/theme-repo.out"; then echo "      it read the home theme although the repository holds one"; return 1; fi
}
check "the book script reads the repository theme before the home theme" repo_theme_first

# A theme file in a subfolder of a repository is not the repository's theme, and outside a
# repository only the home theme is read.
theme_root_or_home() {
  local h="$T/h-theme-home" r="$T/repo2" status
  mkdir -p "$h" "$r/.git" "$r/book" "$T/plain2"
  printf '%s\n' '{"light": {"accent": "#ff0000"}}' > "$r/book/.design-theme.json"
  printf '%s\n' '{"light": {"accent": "#2a5bd7"}}' > "$h/.design-theme.json"
  book "$h" "$r/book" "$T/theme-sub.out"
  status=$?
  exits 0 "$status" "$T/theme-sub.out" "theme: $h/.design-theme.json" "theme light.accent: #2a5bd7" || return 1
  if grep -qF '#ff0000' "$T/theme-sub.out"; then echo "      it read a theme file from a subfolder of the repository"; return 1; fi
  printf '%s\n' '{"light": {"accent": "#ff0000"}}' > "$T/plain2/.design-theme.json"
  book "$h" "$T/plain2" "$T/theme-out.out"
  status=$?
  exits 0 "$status" "$T/theme-out.out" "theme: $h/.design-theme.json" "theme light.accent: #2a5bd7" || return 1
  if grep -qF '#ff0000' "$T/theme-out.out"; then echo "      it read a theme file outside a repository root"; return 1; fi
}
check "the book script reads the theme only at the repository root or in HOME" theme_root_or_home

# A key the format does not list, a color that is not one, a number just below and just above its
# range, and a group the format does not have are each named; a file that is not JSON is refused too.
theme_refused() {
  local h="$T/h-theme-bad" status before s
  mkdir -p "$h"
  printf '%s\n' '{"light": {"acent": "#0b6e4f", "ink": "blue"}, "font": {"size": 11}, "space": {"radius": 65}, "colors": {}}' > "$h/.design-theme.json"
  before="$(shasum "$h/.design-theme.json")"
  book "$h" "$T/plain" "$T/theme-bad.out"
  status=$?
  [ "$status" -eq 1 ] || { echo "      exited $status, not 1, for a theme with bad keys"; sed 's/^/        /' "$T/theme-bad.out.err" | head -8; return 1; }
  for s in "light.acent" "light.ink" "font.size" "space.radius" "colors" "stop before drawing"; do
    grep -qF -- "$s" "$T/theme-bad.out.err" || { echo "      standard error does not name $s"; sed 's/^/        /' "$T/theme-bad.out.err" | head -8; return 1; }
  done
  if grep -q '^theme light\.' "$T/theme-bad.out"; then echo "      it prints theme values from a refused file"; return 1; fi
  [ "$before" = "$(shasum "$h/.design-theme.json")" ] || { echo "      the refused theme file changed"; return 1; }
  printf '%s\n' '{"light": ' > "$h/.design-theme.json"
  book "$h" "$T/plain" "$T/theme-json.out"
  status=$?
  [ "$status" -eq 1 ] || { echo "      exited $status, not 1, for a theme that is not JSON"; return 1; }
  grep -qF "not JSON" "$T/theme-json.out.err" || { echo "      standard error does not say the theme is not JSON"; return 1; }
}
check "the book script refuses a theme file with an unknown key or a bad value, naming each key" theme_refused

skill_theme() {
  has "$SKILL_DIR/SKILL.md" \
    'apply the theme values it prints in place of the style4 colors and letters' \
    'When it prints `theme: none`, keep the style4 colors and handwritten letters' \
    'When it exits 1 because the theme file is refused, stop before drawing, show the user each key it names'
}
check "the book skill applies the theme and stops before drawing when the theme file is refused" skill_theme

# snapshot <dir>: every path under the folder with the SHA-256 of each file.
snapshot() { (cd "$1" && find . | LC_ALL=C sort && find . -type f -exec shasum -a 256 {} + | LC_ALL=C sort); }

writes_nothing() {
  local h="$T/h-still" r="$T/repo3"
  styles "$h" flow-a.png map-b.webp
  printf '%s\n' "$FULL_THEME" > "$h/.design-theme.json"
  mkdir -p "$r/.git"
  printf '%s\n' "$FULL_THEME" > "$r/.design-theme.json"
  snapshot "$h" > "$T/still-before"
  book "$h" "$T/plain" "$T/still1.out" || { echo "      the run with the home theme failed"; return 1; }
  book "$h" "$r" "$T/still2.out" || { echo "      the run with the repository theme failed"; return 1; }
  snapshot "$h" > "$T/still-after"
  cmp -s "$T/still-before" "$T/still-after" || { diff "$T/still-before" "$T/still-after" | sed 's/^/      /' | head -8; return 1; }
}
check "the book script writes nothing under HOME" writes_nothing

book_pages() {
  local page bad=0
  for page in README.md README.ja.md docs/how-it-works.md docs/how-it-works.ja.md; do
    has "$PLUGIN/$page" '`book_style.py`' '`.design-theme.json`' '`~/.design-theme.json`' '`light.accent`' '`font.sans`' || bad=1
  done
  return "$bad"
}
check "the book pages describe the theme file and the written style4 rules" book_pages

changelog_line() {
  has "$PLUGIN/CHANGELOG.md" '`tech-book-figure` draws from the written style4 rules' '`.design-theme.json`'
}
check "the changelog names the written style4 rules and the theme file" changelog_line

printf 'tech-book-figure: %d passed, %d failed (%d ran, %d skipped)\n' "$PASS" "$FAIL" "$((PASS + FAIL))" "$SKIP"
[ "$FAIL" -eq 0 ]
