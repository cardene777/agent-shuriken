#!/usr/bin/env bash
# Tests for the tech-book-figure skill of the diagram-styles plugin: the steps its SKILL.md holds
# for the style4 samples, and its musubi follow of article-diagram-styles/style4 with the lines
# musubi add prints. The fingerprint is computed here the way musubi computes it, so the test
# needs no musubi command and reaches no network.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
PLUGIN="$(cd "$SKILL_DIR/../.." && pwd)"
REPO="$(cd "$PLUGIN/../.." && pwd)"
ARTICLE="$PLUGIN/skills/article-diagram-styles"
PASS=0
FAIL=0
SKIP=0
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

stops_without_two_samples() {
  has "$SKILL_DIR/SKILL.md" \
    'If fewer than two images are in `~/.styles/diagram-style-samples/style4/`, stop before drawing and tell the user to put the style4 samples there'
}
check "the book skill stops when fewer than two style4 samples are found" stops_without_two_samples

stops_without_catalog() {
  has "$SKILL_DIR/SKILL.md" \
    'If `~/.styles/style-catalog.json` is missing, stop before drawing and tell the user to put the catalog and the sample images under `~/.styles/`'
}
check "the book skill stops before drawing when the catalog is missing" stops_without_catalog

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

needs_reference_images() {
  has "$SKILL_DIR/SKILL.md" \
    'If the image generation cannot take the style4 samples as reference images, stop before drawing' \
    'Do not draw from the name style4 and a description alone'
}
check "the book skill refuses to draw without the style4 samples as references" needs_reference_images

printf 'tech-book-figure: %d passed, %d failed (%d ran, %d skipped)\n' "$PASS" "$FAIL" "$((PASS + FAIL))" "$SKIP"
[ "$FAIL" -eq 0 ]
