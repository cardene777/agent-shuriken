#!/usr/bin/env bash
# Tests for design-doc.py verify, the design format, the musubi declaration, and the doc-formats
# plugin. Designs written here live in a throwaway folder; nothing reaches the network. The two
# musubi checks run only when the musubi command is on PATH, and are reported as skipped, never as
# passed, when it is not.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
SCRIPT="$SKILL_DIR/scripts/design-doc.py"
FORMAT="$SKILL_DIR/formats/design.md"
RULES="$SKILL_DIR/checks/design.json"
DECLARATION="$SKILL_DIR/musubi.json"
SKILL="$SKILL_DIR/SKILL.md"
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

run() { python3 "$SCRIPT" "$@"; }

# The sections of a skill that follows the format. Their order is not alphabetical, and one name
# holds commas, so a check that sorts or splits names fails here.
OWN=("Purpose and scope" "Parts" "Prices, ordering, and randomness" "Rollout")
DATED="Parts"

# sections <file>: writes a sections file with the four sections above, as a following skill keeps it.
sections() {
  local f="$1" s
  mkdir -p "$(dirname "$f")"
  {
    for s in "${OWN[@]}"; do
      printf '## %s\n\n' "$s"
      if [ "$s" = "$DATED" ]; then
        printf 'Fill in: each part, and the date each service was checked, written as YYYY-MM-DD.\n\n'
      else
        printf 'Fill in: what this part decides.\n\n'
      fi
    done
  } > "$f"
}

# design <file> [<section to leave out>]: writes a complete design with the four sections and Open
# decisions, one body line each carrying SECRET_TEXT_MARKER, so a check can tell whether verify
# printed the design's text.
design() {
  local f="$1" leave="${2:-}" s
  mkdir -p "$(dirname "$f")"
  {
    printf '# Token sale design\n\nWhat the sale does. SECRET_TEXT_MARKER\n\n'
    for s in "${OWN[@]}" "Open decisions"; do
      [ "$s" = "$leave" ] && continue
      printf '## %s\n\n' "$s"
      if [ "$s" = "$DATED" ]; then
        printf 'A sale and a vesting contract on OpenZeppelin 5.x, checked 2026-11-17. SECRET_TEXT_MARKER\n\n'
      else
        printf 'What this part decides. SECRET_TEXT_MARKER\n\n'
      fi
    done
  } > "$f"
}

# edit <file> <python expression on text>: rewrites a file through one Python expression.
edit() {
  python3 - "$1" "$2" <<'PYEOF'
import sys
path, expression = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
open(path, "w", encoding="utf-8").write(eval(expression, {"text": text}))
PYEOF
}

verify_with() { run verify --sections "$T/sections.md" --dated "$DATED" "$@"; }

sections "$T/sections.md"

plugin_files() {
  local f
  for f in .claude-plugin/plugin.json .codex-plugin/plugin.json README.md README.ja.md CHANGELOG.md LICENSE \
    assets/icon.svg docs/how-it-works.md docs/how-it-works.ja.md skills/design-doc/SKILL.md \
    skills/design-doc/agents/openai.yaml; do
    [ -f "$PLUGIN/$f" ] || { echo "      missing $f"; return 1; }
  done
  python3 - "$PLUGIN" <<'PYEOF'
import json, sys
root = sys.argv[1]
for path in (".claude-plugin/plugin.json", ".codex-plugin/plugin.json"):
    manifest = json.load(open("%s/%s" % (root, path), encoding="utf-8"))
    if manifest.get("name") != "doc-formats" or manifest.get("version") != "0.1.0":
        print("      %s is %s %s" % (path, manifest.get("name"), manifest.get("version")))
        sys.exit(1)
PYEOF
}
check "doc-formats holds the files of a plugin at version 0.1.0" plugin_files

listed() {
  local page
  python3 - "$REPO/.claude-plugin/marketplace.json" <<'PYEOF' || return 1
import json, sys
plugins = json.load(open(sys.argv[1], encoding="utf-8"))["plugins"]
sys.exit(0 if any(p["name"] == "doc-formats" and p["source"] == "./plugins/doc-formats" for p in plugins) else 1)
PYEOF
  for page in README.md README.ja.md; do
    grep -qE '^\| \[doc-formats\]\(plugins/doc-formats\) \|' "$REPO/$page" || return 1
    grep -qF '/doc-formats:design-doc' "$REPO/$page" || return 1
  done
  for page in docs/publishing.md docs/publishing.ja.md; do
    grep -qE '^\| doc-formats \|' "$REPO/$page" || return 1
  done
}
check "the marketplace and the repository pages list doc-formats" listed

provides() {
  [ -f "$DECLARATION" ] || return 1
  python3 - "$SKILL_DIR" <<'PYEOF'
import json, os, sys
skill = sys.argv[1]
declaration = json.load(open(os.path.join(skill, "musubi.json"), encoding="utf-8"))
provides = declaration.get("provides", {})
want = {
    "design": {"version": "1.0.0", "file": "formats/design.md", "check": "checks/design.json"},
    "verify": {"version": "1.0.0", "file": "scripts/design-doc.py"},
}
if declaration.get("musubi") != "2026-11-19" or provides != want or "follows" in declaration:
    print("      musubi.json declares %s" % json.dumps(declaration, sort_keys=True))
    sys.exit(1)
for content in want.values():
    for key in ("file", "check"):
        if key in content and not os.path.isfile(os.path.join(skill, content[key])):
            print("      %s is missing" % content[key])
            sys.exit(1)
PYEOF
}
check "design-doc provides design and verify in musubi.json" provides

# The frame every design shares: a title and an intro to fill in, the fixed sentence, a place for
# the following skill's sections, and Open decisions as the last section.
format_frame() {
  [ -f "$FORMAT" ] || return 1
  head -1 "$FORMAT" | grep -q '^# Fill in: ' || return 1
  grep -v '^#' "$FORMAT" | grep -q '^Fill in: ' || return 1
  grep -qF 'Each section decides one part and points to the others instead of repeating them.' "$FORMAT" || return 1
  grep -qF '<!-- Put the sections of the skill that follows this format here, in its order. -->' "$FORMAT" || return 1
  [ "$(grep -E '^## ' "$FORMAT" | tail -1)" = "## Open decisions" ] || return 1
  python3 - "$FORMAT" <<'PYEOF'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
place = text.index("<!-- Put the sections of the skill")
sys.exit(0 if place < text.index("## Open decisions") else 1)
PYEOF
}
check "the design format holds the shared frame" format_frame

format_no_sections() {
  [ -f "$FORMAT" ] || return 1
  [ "$(grep -cE '^## ' "$FORMAT")" -eq 1 ]
}
check "the design format holds no field's sections" format_no_sections

verify_complete() {
  local f="$T/complete/sale.md"
  design "$f"
  verify_with "$f" > "$T/verify-ok.out" 2>&1 || return 1
  grep -q '(5 sections)' "$T/verify-ok.out" || return 1
  # Other level-two headings may sit between the required ones.
  cp "$f" "$T/complete/extra.md"
  edit "$T/complete/extra.md" 'text.replace("## Parts", "## Glossary\n\nTerms.\n\n## Parts", 1)'
  verify_with "$T/complete/extra.md" > "$T/verify-extra.out" 2>&1
}
check "verify accepts a complete design with the sections of the sections file" verify_complete

# Each broken design breaks one thing, so a check that misses one of them fails here.
verify_refusals() {
  local d="$T/broken" f
  design "$d/missing.md" "Rollout"
  design "$d/no-decisions.md" "Open decisions"
  design "$d/misplaced.md"
  edit "$d/misplaced.md" 'text.replace("## Parts", "## TEMP").replace("## Prices, ordering, and randomness", "## Parts").replace("## TEMP", "## Prices, ordering, and randomness")'
  design "$d/empty.md"
  edit "$d/empty.md" 'text.replace("## Rollout\n\nWhat this part decides. SECRET_TEXT_MARKER\n", "## Rollout\n\n<!-- left empty -->\n")'
  design "$d/unfinished.md"
  printf 'Fill in: who may pause the sale.\n' >> "$d/unfinished.md"
  design "$d/title.md"
  edit "$d/title.md" 'text.replace("# Token sale design", "# Fill in: the name of the design")'
  for f in missing no-decisions misplaced empty unfinished title; do
    verify_with "$d/$f.md" > "$T/verify-$f.out" 2>&1
    [ $? -eq 1 ] || { echo "      $f did not exit 1"; return 1; }
    ! grep -q 'SECRET_TEXT_MARKER' "$T/verify-$f.out" || { echo "      $f printed the design"; return 1; }
  done
  grep -Eq '^missing: Rollout$' "$T/verify-missing.out" \
    && grep -Eq '^missing: Open decisions$' "$T/verify-no-decisions.out" \
    && grep -Eq '^out of order: (Parts|Prices, ordering, and randomness)$' "$T/verify-misplaced.out" \
    && grep -Eq '^empty: Rollout$' "$T/verify-empty.out" \
    && grep -Eq '^unfinished: Open decisions$' "$T/verify-unfinished.out" \
    && grep -Eq '^unfinished: title$' "$T/verify-title.out"
}
check "verify names each missing, misplaced, empty, or unfinished section without printing the design's text" verify_refusals

# The dated section needs a real date; without --dated no section needs one.
verify_dated() {
  local d="$T/dated" f
  design "$d/undated.md"
  edit "$d/undated.md" 'text.replace(", checked 2026-11-17", "")'
  design "$d/impossible.md"
  edit "$d/impossible.md" 'text.replace("2026-11-17", "2026-02-30")'
  for f in undated impossible; do
    verify_with "$d/$f.md" > "$T/dated-$f.out" 2>&1
    [ $? -eq 1 ] || return 1
    grep -Eq '^no checked date: Parts$' "$T/dated-$f.out" || return 1
  done
  run verify --sections "$T/sections.md" "$d/undated.md" > "$T/dated-none.out" 2>&1
}
check "verify names a dated section without a checked date" verify_dated

# ids_design <file> <citing text> <ID>...: a complete design whose first section carries the citing
# text and whose Open decisions section ends with a table that defines the given IDs.
ids_design() {
  local f="$1" cites="$2"
  shift 2
  design "$f"
  python3 - "$f" "$cites" "$@" <<'PYEOF'
import sys
p, cites, ids = sys.argv[1], sys.argv[2], sys.argv[3:]
text = open(p, encoding="utf-8").read().replace("SECRET_TEXT_MARKER", "SECRET_TEXT_MARKER " + cites, 1)
rows = "".join("| %s | A decision. SECRET_TEXT_MARKER |\n" % i for i in ids)
open(p, "w", encoding="utf-8").write(text.rstrip("\n") + "\n\n| ID | Decision |\n|---|---|\n" + rows)
PYEOF
}

# A cited ID is undefined when no row of the Open decisions table starts with it, and D10 is not
# D1. verify names each undefined ID once and never prints the design's text.
verify_undefined_id() {
  local f="$T/ids/undefined.md"
  ids_design "$f" "Rests on D2, D9, D9, and D10." D1 D2
  verify_with "$f" > "$T/verify-undefined.out" 2>&1
  [ $? -eq 1 ] || return 1
  ! grep -q 'SECRET_TEXT_MARKER' "$T/verify-undefined.out" || return 1
  grep -Eq '^undefined decision: D9$' "$T/verify-undefined.out" \
    && grep -Eq '^undefined decision: D10$' "$T/verify-undefined.out" \
    && [ "$(grep -c '^undefined decision: ' "$T/verify-undefined.out")" -eq 2 ]
}
check "verify names a cited Open decisions ID the table does not define" verify_undefined_id

# An ID the table defines but the text never cites is fine, and standard names are not IDs.
verify_uncited_id() {
  local f="$T/ids/uncited.md"
  ids_design "$f" "Rests on D2. ERC-20, EIP-7825, SR2025, and step B3 apply." D1 D2
  verify_with "$f" > "$T/verify-uncited.out" 2>&1
}
check "verify accepts an uncited Open decisions ID and standard names" verify_uncited_id

# The format with a sections file put in its place, as a skill starts a design, is not finished.
verify_unfilled() {
  [ -f "$FORMAT" ] || return 1
  python3 - "$FORMAT" "$T/sections.md" "$T/unfilled.md" <<'PYEOF'
import sys
frame = open(sys.argv[1], encoding="utf-8").read()
own = open(sys.argv[2], encoding="utf-8").read()
at = frame.index("## Open decisions")
open(sys.argv[3], "w", encoding="utf-8").write(frame[:at] + own + frame[at:])
PYEOF
  verify_with "$T/unfilled.md" > "$T/verify-unfilled.out" 2>&1
  [ $? -eq 1 ] && grep -q '^unfinished: ' "$T/verify-unfilled.out"
}
check "verify refuses the unfilled format" verify_unfilled

# A sections file that names no section would compare nothing, so it is refused instead of passed.
verify_no_sections() {
  local d="$T/none" f
  [ -f "$SCRIPT" ] || return 1
  design "$d/sale.md"
  mkdir -p "$d"
  printf 'Fill in: nothing here is a heading.\n' > "$d/prose.md"
  : > "$d/empty.md"
  printf '```markdown\n## Purpose and scope\n```\n' > "$d/fenced.md"
  for f in prose empty fenced absent; do
    run verify --sections "$d/$f.md" "$d/sale.md" > "$T/none-$f.out" 2>&1
    [ $? -eq 2 ] || { echo "      $f did not exit 2"; return 1; }
    ! grep -q ': ok' "$T/none-$f.out" || return 1
  done
  grep -q 'no sections' "$T/none-prose.out" && grep -q 'no sections' "$T/none-fenced.out"
}
check "verify refuses a sections file with no sections" verify_no_sections

# Open decisions belongs to the format, so a sections file that holds it would ask for it twice.
verify_own_decisions() {
  local d="$T/own"
  [ -f "$SCRIPT" ] || return 1
  design "$d/sale.md"
  { cat "$T/sections.md"; printf '## Open decisions\n\nFill in: the questions.\n'; } > "$d/sections.md"
  run verify --sections "$d/sections.md" "$d/sale.md" > "$T/own.out" 2>&1
  [ $? -eq 2 ] && grep -q 'Open decisions' "$T/own.out"
}
check "verify refuses a sections file that holds Open decisions" verify_own_decisions

verify_unknown_dated() {
  local d="$T/unknown"
  [ -f "$SCRIPT" ] || return 1
  design "$d/sale.md"
  run verify --sections "$T/sections.md" --dated "Contracts" "$d/sale.md" > "$T/unknown.out" 2>&1
  [ $? -eq 2 ] && grep -q 'Contracts' "$T/unknown.out"
}
check "verify refuses a dated section the sections file does not hold" verify_unknown_dated

# A heading inside a fenced example in the sections file is not a section the design must hold.
verify_fenced_heading() {
  local d="$T/fenced"
  design "$d/sale.md"
  python3 - "$T/sections.md" "$d/sections.md" <<'PYEOF'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
example = "For example:\n\n```markdown\n## Example heading\n```\n\n"
open(sys.argv[2], "w", encoding="utf-8").write(text.replace("## Parts\n\n", "## Parts\n\n" + example, 1))
PYEOF
  run verify --sections "$d/sections.md" --dated "$DATED" "$d/sale.md" > "$T/fenced.out" 2>&1 || return 1
  ! grep -q 'Example heading' "$T/fenced.out"
}
check "verify skips headings inside fenced code in the sections file" verify_fenced_heading

FOLLOWERS=(contract-design dapp-architecture wallet-design multichain-design financial-standards)

musubi_accepts() {
  musubi check "$REPO/plugins/doc-formats/skills" "$REPO/plugins/evm-dev/skills" > "$T/musubi.out" 2>&1 || { sed 's/^/      /' "$T/musubi.out"; return 1; }
  grep -q 'follows=10)' "$T/musubi.out"
}

# A changed format must stop every skill that follows it until its fingerprint is checked again.
musubi_refuses_changed() {
  local d="$T/copies" s
  mkdir -p "$d"
  cp -R "$REPO/plugins/doc-formats" "$REPO/plugins/evm-dev" "$d/" || return 1
  printf '\nA changed line.\n' >> "$d/doc-formats/skills/design-doc/formats/design.md"
  musubi check "$d/doc-formats/skills" "$d/evm-dev/skills" > "$T/musubi-changed.out" 2>&1
  [ $? -eq 1 ] || return 1
  for s in "${FOLLOWERS[@]}"; do
    grep -q "$s" "$T/musubi-changed.out" || { echo "      $s was not named"; return 1; }
  done
}

if command -v musubi > /dev/null 2>&1; then
  check "musubi check accepts every skill that follows design-doc" musubi_accepts
  check "musubi check refuses the five design skills after the design format changes" musubi_refuses_changed
else
  skip "musubi check accepts every skill that follows design-doc" "the musubi command is not on PATH"
  skip "musubi check refuses the five design skills after the design format changes" "the musubi command is not on PATH"
fi

releasing_step() {
  local page
  for page in docs/releasing.md docs/releasing.ja.md; do
    grep -qF 'musubi check plugins/doc-formats/skills plugins/evm-dev/skills' "$REPO/$page" || return 1
  done
}
check "the releasing pages run musubi check before doc-formats or evm-dev is released" releasing_step

# unreleased <changelog>: the lines between ## [Unreleased] and the next release.
unreleased() { awk '/^## \[Unreleased\]/{on=1; next} /^## \[/{on=0} on' "$1"; }

# A new plugin's changelog opens with its first release; the changes to evm-dev and the new plugin
# in the repository wait under Unreleased.
changelogs() {
  awk '/^## \[0\.1\.0\]/{on=1; next} /^## \[/{on=0} on' "$PLUGIN/CHANGELOG.md" | grep -q 'design-doc' || return 1
  unreleased "$REPO/plugins/evm-dev/CHANGELOG.md" | grep -q 'design-doc' || return 1
  unreleased "$REPO/CHANGELOG.md" | grep -q 'doc-formats'
}
check "the changelogs name the shared design format" changelogs

printf '%d passed, %d failed (%d ran, %d skipped)\n' "$PASS" "$FAIL" "$((PASS + FAIL))" "$SKIP"
[ "$FAIL" -eq 0 ]
