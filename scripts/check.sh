#!/bin/bash
# Checks that the repository is consistent and that every plugin is ready to install and submit.
# Usage: bash scripts/check.sh
# Prints one line per check. Exits 0 when no check fails and 1 when any check fails.
# A check whose tool is missing is reported as "skip" and does not fail the run.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root" || exit 1

# Files whose Japanese text is intended, besides the *.ja.md pages: the `ja` dictionaries of
# the HTML pages, words that scripts match on Japanese websites and emails, the patterns and
# word lists that check Japanese prose, Japanese samples and their tests, and quotes copied word for
# word from Japanese guidance.
JA_ALLOWED=(
  plugins/design-formats/skills/page-design/formats/look.md
  plugins/design-formats/skills/page-design/formats/patterns/sources.md
  plugins/design-formats/skills/page-design/templates/report.html
  plugins/design-formats/skills/page-design/templates/sheet.html
  plugins/design-formats/skills/page-design/templates/document.html
  plugins/design-formats/skills/page-design/templates/choice.html
  plugins/design-formats/skills/page-design/tests/test-page-design.sh
  plugins/account-cleanup/skills/account-cleanup/templates/sheet.html
  plugins/account-cleanup/skills/account-cleanup/templates/followups.html
  plugins/machine-cleanup/skills/machine-cleanup/templates/sheet.html
  plugins/compare-report/skills/compare-report/templates/base.html
  plugins/slides/skills/slide-forge/scripts/edit-text.json
  plugins/slides/skills/slide-builder/scripts/outline-headings.json
  plugins/machine-cleanup/skills/machine-cleanup/tests/test-machine-cleanup.sh
  plugins/motion-diagram/skills/motion-diagram/templates/page.html
  plugins/motion-diagram/skills/motion-diagram/templates/ui.json
  plugins/motion-diagram/skills/motion-diagram/tests/test-motion-diagram.sh
  plugins/motion-diagram/examples/idea-intake.ja.json
  plugins/account-cleanup/skills/account-cleanup/scripts/browser.mjs
  plugins/account-cleanup/skills/account-cleanup/scripts/connections-guide.sh
  plugins/account-cleanup/skills/account-cleanup/scripts/subscriptions-guide.sh
  plugins/diagram-explainer/skills/diagram-explainer/assets/ui.json
  plugins/diagram-explainer/skills/diagram-explainer/scripts/check.py
  plugins/diagram-explainer/skills/diagram-explainer/scripts/figure.py
  plugins/diagram-explainer/skills/diagram-explainer/references/prose-words.txt
  plugins/diagram-explainer/skills/diagram-explainer/references/words-plain.txt
  plugins/diagram-explainer/skills/diagram-explainer/references/metaphor-words.tsv
  plugins/diagram-explainer/skills/diagram-explainer/examples/content.sample.ja.json
  plugins/diagram-explainer/skills/diagram-explainer/examples/ladders/checkout-ja.json
  plugins/diagram-explainer/skills/diagram-explainer/tests/test-render.sh
  plugins/diagram-explainer/skills/diagram-explainer/tests/fixtures/motion-page.html
  plugins/diagram-explainer/evals/japanese-document/case.yaml
  plugins/dragon-explainer/skills/dragon-explainer/assets/ui.json
  plugins/dragon-explainer/skills/dragon-explainer/scripts/check.py
  plugins/dragon-explainer/skills/dragon-explainer/scripts/figure.py
  plugins/dragon-explainer/skills/dragon-explainer/references/prose-words.txt
  plugins/dragon-explainer/skills/dragon-explainer/references/words-plain.txt
  plugins/dragon-explainer/skills/dragon-explainer/references/metaphor-words.tsv
  plugins/dragon-explainer/skills/dragon-explainer/examples/content.sample.ja.json
  plugins/dragon-explainer/skills/dragon-explainer/examples/a-flow.ja.dragon
  plugins/dragon-explainer/skills/dragon-explainer/examples/ladders/checkout-ja.json
  plugins/dragon-explainer/skills/dragon-explainer/tests/test-render.sh
  plugins/dragon-explainer/skills/dragon-explainer/tests/fixtures/motion-page.html
  plugins/dragon-explainer/evals/japanese-document/case.yaml
  plugins/diagram-styles/skills/article-diagram-styles/tests/test-article-diagram-styles.sh
  plugins/docs-publish/evals/_japanese.json
  plugins/excalidraw-diagram/skills/excalidraw-diagram/tests/test-excalidraw-diagram.sh
  plugins/techdebt/skills/techdebt/templates/base.html
  plugins/screen-video/skills/screen-video/scripts/lib/flow.mjs
  plugins/screen-video/skills/screen-video/scripts/lib/voice.mjs
  plugins/screen-video/skills/screen-video/templates/storyboard.html
  plugins/screen-video/skills/screen-video/templates/compare.html
  plugins/screen-video/skills/screen-video/tests/quality.mjs
  plugins/techdebt/skills/techdebt/tests/test-techdebt.sh
  plugins/japanese-speaking/README.md
  plugins/japanese-speaking/skills/japanese-speaking/SKILL.md
  plugins/japanese-speaking/skills/japanese-speaking/references/speaking.md
  plugins/japanese-speaking/skills/japanese-speaking/references/formats.md
  plugins/japanese-speaking/skills/japanese-speaking/references/review.md
  plugins/japanese-speaking/skills/japanese-speaking/references/speaking.en.md
  plugins/japanese-speaking/skills/japanese-speaking/references/formats.en.md
  plugins/japanese-speaking/skills/japanese-speaking/references/review.en.md
  plugins/japanese-speaking/skills/japanese-speaking/references/patterns.tsv
  plugins/japanese-speaking/skills/japanese-speaking/references/common-katakana.txt
  plugins/japanese-speaking/skills/japanese-speaking/scripts/speaking.py
  plugins/japanese-speaking/skills/japanese-speaking/tests/test-japanese-speaking.sh
  plugins/japanese-speaking/skills/japanese-speaking/tests/fixtures/rejected-2026-11-18.json
  plugins/japanese-speaking/skills/japanese-speaking/tests/fixtures/natural.json
  plugins/japanese-speaking/skills/japanese-speaking/tests/fixtures/plain.txt
  plugins/japanese-speaking/skills/japanese-speaking/tests/fixtures/casual.json
  plugins/japanese-speaking/skills/japanese-speaking/tests/fixtures/sources.json
  plugins/japanese-speaking/skills/japanese-speaking/tests/fixtures/sourced.json
  plugins/japanese-speaking/skills/japanese-speaking/tests/fixtures/notes.json
  plugins/japanese-speaking/skills/japanese-speaking/tests/fixtures/round-table.json
  plugins/japanese-writing/README.md
  plugins/convey/skills/convey/scripts/convey.py
  plugins/convey/skills/convey/references/filler-phrases.tsv
  plugins/convey/skills/convey/tests/test-convey.sh
  plugins/convey/evals/_fixture.py
  plugins/convey/evals/long-report-to-discord/case.yaml
  plugins/convey/evals/slack-format/case.yaml
  plugins/convey/evals/request-with-deadline/case.yaml
  plugins/convey/evals/handoff-message/case.yaml
  plugins/japanese-writing/skills/japanese-writing/references/rules.md
  plugins/japanese-writing/skills/japanese-writing/references/ai-smell.md
  plugins/japanese-writing/skills/japanese-writing/references/asking.md
  plugins/japanese-writing/skills/japanese-writing/references/explaining.md
  plugins/japanese-writing/skills/japanese-writing/references/natural-explanation.md
  plugins/japanese-writing/skills/japanese-writing/references/sentence-forms.md
  plugins/japanese-writing/skills/japanese-writing/references/subject-and-verb.md
  plugins/japanese-writing/skills/japanese-writing/references/terminology.md
  plugins/japanese-writing/skills/japanese-writing/references/connecting.md
  plugins/japanese-writing/skills/japanese-writing/references/metaphor-words.tsv
  plugins/japanese-writing/skills/japanese-writing/references/rules.en.md
  plugins/japanese-writing/skills/japanese-writing/references/terminology.en.md
  plugins/japanese-writing/skills/japanese-writing/references/subject-and-verb.en.md
  plugins/japanese-writing/skills/japanese-writing/references/ai-smell.en.md
  plugins/japanese-writing/skills/japanese-writing/references/explaining.en.md
  plugins/japanese-writing/skills/japanese-writing/references/asking.en.md
  plugins/japanese-writing/skills/japanese-writing/references/natural-explanation.en.md
  plugins/japanese-writing/skills/japanese-writing/references/sentence-forms.en.md
  plugins/japanese-writing/skills/japanese-writing/references/connecting.en.md
  plugins/japanese-writing/skills/japanese-writing/references/diagnose.en.md
  plugins/japanese-writing/skills/japanese-writing/references/manual-checklist.en.md
  plugins/japanese-writing/skills/japanese-writing/references/doctypes/guide.en.md
  plugins/japanese-writing/skills/japanese-writing/references/doctypes/memo.en.md
  plugins/japanese-writing/skills/japanese-writing/references/doctypes/minutes.en.md
  plugins/japanese-writing/skills/japanese-writing/references/doctypes/report.en.md
  plugins/japanese-writing/skills/japanese-writing/references/doctypes/slide.en.md
  plugins/japanese-writing/THIRD_PARTY_NOTICES.md
  plugins/japanese-writing/skills/japanese-writing/scripts/suspects.py
  plugins/japanese-writing/skills/japanese-writing/tests/test-japanese-writing.sh
  plugins/evm-dev/skills/evm-standards/tests/test-evm-standards.sh
  plugins/digital-dashboard/skills/digital-dashboard/tests/test-digital-dashboard.sh
  plugins/digital-dashboard/skills/digital-dashboard/scripts/screen_kind.py
  plugins/digital-dashboard/skills/digital-dashboard/references/numeric-format.md
  plugins/digital-dashboard/skills/digital-dashboard/references/time-axis.md
  plugins/digital-dashboard/THIRD_PARTY_NOTICES.md
  plugins/product-deck/skills/product-deck/tests/test-product-deck.sh
  plugins/product-deck/skills/product-deck/scripts/audit-text.mjs
  plugins/product-deck/skills/product-deck/references/banned-words.txt
)
# Third-party files copied unmodified; they are checked only for valid syntax. Besides these, every
# file that a skill's upstream-manifest.txt fingerprints counts as a copied file (vendored_files).
VENDORED=(plugins/account-cleanup/skills/account-cleanup/data/sites.json)
# Files allowed over the directories' 256 KiB limit. Each one makes Anthropic's directory hold
# the plugin for a reviewer, as docs/publishing.md says.
SIZE_EXCEPTIONS=(plugins/account-cleanup/skills/account-cleanup/data/sites.json)

pass=0 fail=0 skip=0

# Tracked and new files that exist in the working tree.
all_files() {
  git ls-files --cached --others --exclude-standard | while IFS= read -r f; do
    [ -f "$f" ] && printf '%s\n' "$f"
  done
}
# Third-party files copied unmodified: VENDORED and the files each upstream-manifest.txt fingerprints.
vendored_files() {
  local manifest dir
  printf '%s\n' "${VENDORED[@]}"
  for manifest in plugins/*/skills/*/upstream-manifest.txt; do
    [ -f "$manifest" ] || continue
    dir="$(dirname "$manifest")"
    grep -E '^[0-9a-f]{64}  ' "$manifest" | cut -c67- | sed "s|^|$dir/|"
  done
}
# Text files written in this repository (no vendored data, no images, no fonts).
own_text_files() {
  all_files | grep -vE '\.(png|jpg|jpeg|gif|webp|svg|ico|zip|woff2?|ttf|otf|ogg)$' | grep -vxF -f <(vendored_files)
}
plugin_names() {
  for d in plugins/*/; do basename "$d"; done
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

# Every plugin folder is one marketplace entry with the same name and description, and back.
check_marketplace() {
  local manifest=.claude-plugin/marketplace.json listed name bad=0
  listed="$(jq -r '.plugins[].name' "$manifest" | sort)"
  [ "$listed" = "$(plugin_names | sort)" ] || {
    echo "marketplace lists: $(printf '%s\n' "$listed" | tr '\n' ' ')"
    echo "plugin folders: $(plugin_names | tr '\n' ' ')"
    return 1
  }
  for name in $(plugin_names); do
    jq -e --arg n "$name" --slurpfile p "plugins/$name/.claude-plugin/plugin.json" '
      .plugins[] | select(.name == $n) | .source == "./plugins/\($n)" and .description == $p[0].description
    ' "$manifest" >/dev/null || { echo "$name: the marketplace entry needs source ./plugins/$name and the plugin.json description"; bad=1; }
  done
  return "$bad"
}

# The Claude Code and Codex manifests of a plugin agree, and the Codex listing fields are complete.
check_manifests() {
  local name claude codex bad=0
  for name in $(plugin_names); do
    claude="plugins/$name/.claude-plugin/plugin.json"
    codex="plugins/$name/.codex-plugin/plugin.json"
    [ -f "$claude" ] && [ -f "$codex" ] || { echo "$name: needs both .claude-plugin/plugin.json and .codex-plugin/plugin.json"; bad=1; continue; }
    jq -e --arg n "$name" '.name == $n and (.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))' "$claude" >/dev/null \
      || { echo "$name: plugin.json needs name $name and a X.Y.Z version"; bad=1; }
    for key in name version description author license; do
      [ "$(jq -c ".$key" "$claude")" = "$(jq -c ".$key" "$codex")" ] || { echo "$name: $key differs between the two manifests"; bad=1; }
    done
    jq -e '.interface | (.displayName | length) <= 30 and (.shortDescription | length) <= 30
      and (.longDescription | length) > 0 and (.developerName | length) > 0
      and (.category | length) > 0 and (.capabilities | type) == "array"' "$codex" >/dev/null \
      || { echo "$name: .codex-plugin interface needs displayName and shortDescription of at most 30 characters, longDescription, developerName, category, and capabilities"; bad=1; }
  done
  return "$bad"
}

# OpenAI's directory needs a square icon and logo of at least 48 px, as PNG, JPEG, WebP, or SVG under 5 MiB.
check_icons() {
  local name codex key path bad=0
  for name in $(plugin_names); do
    codex="plugins/$name/.codex-plugin/plugin.json"
    [ -f "$codex" ] || continue
    for key in composerIcon logo; do
      path="$(jq -r ".interface.$key // empty" "$codex")"
      [[ "$path" == ./* ]] || { echo "$name: interface.$key must be a ./ path inside the plugin"; bad=1; continue; }
      python3 - "plugins/$name/${path#./}" "$name: interface.$key" <<'PY' || bad=1
import re, struct, sys
path, label = sys.argv[1], sys.argv[2]
try:
    data = open(path, "rb").read()
except OSError:
    sys.exit(print(f"{label} points at {path}, which does not exist") or 1)
if len(data) > 5 * 1024 * 1024:
    sys.exit(print(f"{label}: {path} is over 5 MiB") or 1)
if path.endswith(".svg"):
    box = re.search(rb'viewBox="\s*[-\d.]+\s+[-\d.]+\s+([\d.]+)\s+([\d.]+)\s*"', data)
    size = (float(box.group(1)), float(box.group(2))) if box else None
elif path.endswith(".png") and data[:8] == b"\x89PNG\r\n\x1a\n":
    size = struct.unpack(">II", data[16:24])
else:
    sys.exit(print(f"{label}: {path} must be an SVG with a viewBox or a PNG") or 1)
if not size or size[0] != size[1] or size[0] < 48:
    sys.exit(print(f"{label}: {path} must be square and at least 48 px, not {size}") or 1)
PY
    done
  done
  return "$bad"
}

check_plugin_files() {
  local name f bad=0
  for name in $(plugin_names); do
    for f in README.md README.ja.md CHANGELOG.md LICENSE; do
      [ -f "plugins/$name/$f" ] || { echo "$name: $f is missing"; bad=1; }
    done
    cmp -s LICENSE "plugins/$name/LICENSE" || { echo "$name: LICENSE differs from the root LICENSE"; bad=1; }
    # A plugin that holds hooks and no skills is checked by check_hook_plugins instead.
    [ -e "plugins/$name/hooks" ] && continue
    ls plugins/"$name"/skills/*/SKILL.md >/dev/null 2>&1 || { echo "$name: no skills/<skill>/SKILL.md"; bad=1; }
  done
  return "$bad"
}

# Hooks make a plugin ineligible for OpenAI's directory, so only a plugin that holds hooks and no
# skills carries them, it keeps them in hooks/hooks.json, and AGENTS.md states the rule.
check_hook_plugins() {
  local name bad=0
  grep -qF 'holds hooks and no skills' AGENTS.md \
    || { echo "AGENTS.md does not say that only a plugin that holds hooks and no skills carries hooks"; bad=1; }
  for name in $(plugin_names); do
    [ -e "plugins/$name/hooks" ] || continue
    [ ! -e "plugins/$name/skills" ] || { echo "$name: a plugin with hooks holds no skills"; bad=1; }
    [ -f "plugins/$name/hooks/hooks.json" ] || { echo "$name: hooks/hooks.json is missing"; bad=1; }
  done
  return "$bad"
}

# The plugin directories hold a version for a reviewer over these limits.
check_plugin_limits() {
  local name count f bad=0
  for name in $(plugin_names); do
    count="$(all_files | grep -c "^plugins/$name/")"
    [ "$count" -le 512 ] || { echo "$name: $count files, over 512"; bad=1; }
    for f in $(all_files | grep "^plugins/$name/" | grep -vE '\.(png|jpg|jpeg|gif|webp|svg|woff2?|ttf|otf|ogg)$' | grep -vxF -f <(printf '%s\n' "${SIZE_EXCEPTIONS[@]}")); do
      [ "$(wc -c < "$f")" -le 262144 ] || { echo "$f is over 256 KiB"; bad=1; }
    done
  done
  return "$bad"
}

check_skill_frontmatter() {
  local d name bad=0
  for d in plugins/*/skills/*/; do
    name="$(basename "$d")"
    [ -f "$d/SKILL.md" ] || { echo "$d has no SKILL.md"; bad=1; continue; }
    head -1 "$d/SKILL.md" | grep -qx -- '---' || { echo "$name: SKILL.md does not start with frontmatter"; bad=1; }
    grep -qx "name: $name" "$d/SKILL.md" || { echo "$name: frontmatter name does not match the folder"; bad=1; }
    grep -qE '^description: .{40,}' "$d/SKILL.md" || { echo "$name: description is missing or too short"; bad=1; }
  done
  return "$bad"
}

# Codex reads agents/openai.yaml. A skill that only runs when the user calls it says so to both agents.
check_codex_skill_metadata() {
  local d name yaml manual implicit key bad=0
  for d in plugins/*/skills/*/; do
    name="$(basename "$d")"
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

# newest_release <changelog>: prints the version of the newest "## [X.Y.Z] - YYYY-MM-DD" heading.
newest_release() {
  sed -nE 's/^## \[([0-9]+\.[0-9]+\.[0-9]+)\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$/\1/p' "$1" | head -1
}

# Each plugin carries the version of its newest release, and every changelog keeps an Unreleased section.
# A plugin before its first release has only the Unreleased section and carries 0.1.0, the version
# its first release will have, as docs/creating-a-plugin.md says.
check_versions() {
  local name changelog version released bad=0
  for changelog in CHANGELOG.md plugins/*/CHANGELOG.md; do
    [ -f "$changelog" ] || continue
    grep -qx '## \[Unreleased\]' "$changelog" || { echo "$changelog has no ## [Unreleased] section"; bad=1; }
  done
  [ -n "$(newest_release CHANGELOG.md)" ] || { echo "CHANGELOG.md has no ## [X.Y.Z] - YYYY-MM-DD section"; bad=1; }
  for name in $(plugin_names); do
    [ -f "plugins/$name/CHANGELOG.md" ] || continue
    version="$(jq -r .version "plugins/$name/.claude-plugin/plugin.json")"
    released="$(newest_release "plugins/$name/CHANGELOG.md")"
    if [ -z "$released" ]; then
      [ "$version" = 0.1.0 ] || { echo "$name has no release in its CHANGELOG.md yet, so it carries 0.1.0, not $version"; bad=1; }
      continue
    fi
    [ "$version" = "$released" ] || { echo "$name is $version but its CHANGELOG.md's newest release is $released"; bad=1; }
  done
  return "$bad"
}

# Each README has a row per plugin whose last column links the plugin's current version.
# The root changelog names every plugin: a released plugin is a row of the ### Plugins table of the
# newest repository release, and a new plugin has a line under ## [Unreleased] that starts with
# "The <name> plugin". Versions are not compared here, since plugins are released between repository
# releases; scripts/release.sh compares them when the repository is released.
check_root_changelog() {
  local name table unreleased bad=0
  table="$(awk '/^## \[[0-9]+\.[0-9]+\.[0-9]+\] - / { if (seen) exit; seen = 1; on = 1; next } /^## \[/ { on = 0 } on' CHANGELOG.md)"
  unreleased="$(awk '/^## \[Unreleased\]/ { on = 1; next } /^## \[/ { on = 0 } on' CHANGELOG.md)"
  for name in $(plugin_names); do
    printf '%s\n' "$table" | grep -qE "^\| $name \| [0-9]+\.[0-9]+\.[0-9]+ \|$" && continue
    printf '%s\n' "$unreleased" | grep -qE "^- The $name plugin" && continue
    echo "CHANGELOG.md does not name $name: add a line under ## [Unreleased] that starts with \"The $name plugin\""
    bad=1
  done
  return "$bad"
}
check_readme_tables() {
  local name readme version row bad=0
  for readme in README.md README.ja.md; do
    for name in $(plugin_names); do
      row="$(grep -E "^\| \[$name\]\(plugins/$name\) \|" "$readme")"
      [ -n "$row" ] || { echo "$readme has no table row for $name"; bad=1; continue; }
      version="$(jq -r .version "plugins/$name/.claude-plugin/plugin.json")"
      [[ "$row" == *"| [$version](plugins/$name/CHANGELOG.md) |" ]] \
        || { echo "$readme: the row for $name does not end with [$version](plugins/$name/CHANGELOG.md)"; bad=1; }
      # The run column names, for every skill, the Claude Code command and the name Codex lists after typing $.
      for skill in plugins/"$name"/skills/*/; do
        [ -d "$skill" ] || continue
        display="$(sed -nE 's/^  display_name: "(.+)"$/\1/p' "$skill/agents/openai.yaml")"
        skill="$(basename "$skill")"
        [[ "$row" == *"\`/$name:$skill\`"* ]] || { echo "$readme: the row for $name does not show \`/$name:$skill\`"; bad=1; }
        [[ "$row" == *"**$display**"* ]] || { echo "$readme: the row for $name does not show **$display** for Codex"; bad=1; }
      done
    done
  done
  return "$bad"
}

# The publishing pages have a status row and a data handling column for every plugin.
check_publishing_tables() {
  local page name headers bad=0
  for page in docs/publishing.md docs/publishing.ja.md; do
    [ -f "$page" ] || { echo "$page is missing"; bad=1; continue; }
    # A table's header is the line right above its |---| separator.
    headers="$(awk 'prev != "" && /^\|-/ { print prev } { prev = $0 }' "$page")"
    for name in $(plugin_names); do
      grep -q "^| $name |" "$page" || { echo "$page has no status row for $name"; bad=1; }
      printf '%s\n' "$headers" | grep -qF "| $name |" || { echo "$page: no table header has a column for $name"; bad=1; }
    done
  done
  return "$bad"
}

# Every page has a Japanese counterpart with the same headings, table rows, and code fences.
check_japanese_pages() {
  local f ja bad=0
  for f in $(all_files | grep -E '(^|/)(README|docs/[^/]+)\.md$' | grep -vE '\.ja\.md$' | grep -vE '^plugins/[^/]+/skills/'); do
    ja="${f%.md}.ja.md"
    [ -f "$ja" ] || { echo "$f has no $ja"; bad=1; continue; }
    for pattern in '^#' '^\|' '^```'; do
      [ "$(grep -c "$pattern" "$f")" = "$(grep -c "$pattern" "$ja")" ] \
        || { echo "$ja: the number of lines matching $pattern differs from $f"; bad=1; }
    done
  done
  return "$bad"
}

# Relative links and images in the Markdown files point at files that exist.
# Prints the lines of a Markdown file that are outside fenced code blocks.
# A fence opens with three or more backticks or tildes and closes on a line
# with the same character, at least as many of them, and nothing else, so a
# sample page with its own fences can sit inside a longer fence.
outside_code() {
  awk '
    function run(s, c,   n) { n = 0; while (substr(s, n + 1, 1) == c) n++; return n }
    {
      t = $0; sub(/^[ \t]*/, "", t)
      c = substr(t, 1, 1); n = (c == "`" || c == "~") ? run(t, c) : 0
      if (open == 0) {
        if (n >= 3) { open = n; mark = c; next }
        line = $0; gsub(/`[^`]+`/, "", line); print line
      } else if (c == mark && n >= open && substr(t, n + 1) ~ /^[ \t]*$/) {
        open = 0
      }
    }' "$1"
}

# Links inside code are examples, not links, so only the text outside fences and inline code spans is read.
check_links() {
  local f link target bad=0
  for f in $(all_files | grep '\.md$'); do
    while IFS= read -r link; do
      target="${link%%#*}"
      [ -n "$target" ] || continue
      [ -e "$(dirname "$f")/$target" ] || { echo "$f: $link does not exist"; bad=1; }
    done < <(outside_code "$f" | grep -oE '\]\([^) ]+\)|src="[^"]+"' | sed -E 's/^\]\(//; s/\)$//; s/^src="//; s/"$//' | grep -vE '^[a-z]+:|^#')
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

# Japanese headings join their words without a comma or a colon, so a page copied from another keeps the same plain headings.
# Lines inside fenced code blocks are skipped, since they are examples, not headings.
check_japanese_headings() {
  own_text_files | grep -E '\.ja\.md$' | grep -vE '^\.ikkan/' | python3 -c '
import re, sys
heading = re.compile(r"^#{1,6}\s")
bad_mark = re.compile("[\u3001\uff1a]|\\w:(\\s|$)")
bad = 0
for path in sys.stdin.read().splitlines():
    fence = False
    for number, line in enumerate(open(path, encoding="utf-8"), 1):
        if line.lstrip().startswith("```") or line.lstrip().startswith("~~~"):
            fence = not fence
            continue
        if not fence and heading.match(line) and bad_mark.search(re.sub(r"`[^`]*`", "", line)):
            print(f"{path}:{number}: {line.strip()[:80]}")
            bad = 1
sys.exit(bad)'
}

# Japanese appears only in *.ja.md pages and the allowed files, or as the language name on a switch.
# The records under .ikkan/ are written by the ikkan workflow in Japanese and are not installed with any plugin.
check_english() {
  own_text_files | grep -vE '\.ja\.md$' | grep -vE '^\.ikkan/' | grep -vxF -f <(printf '%s\n' "${JA_ALLOWED[@]}") | python3 -c '
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
  git ls-files | grep -E '(\.pyc$|__pycache__/|node_modules/|\.DS_Store$|Thumbs\.db$|__MACOSX/)' && return 1
  return 0
}

# agent-shared lives in a repository of its own, and both README pages name it.
check_readme_names_agent_shared() {
  local page bad=0
  for page in README.md README.ja.md; do
    grep -qF 'github.com/cardene777/agent-shared' "$page" \
      || { echo "$page does not name github.com/cardene777/agent-shared"; bad=1; }
  done
  return "$bad"
}

# No copy of agent-shared is left here: no agent-shared/ folder, no docs/agent-shared page, and no
# file that names the old install command, which installed agent-shared from this repository.
# The records under .ikkan/ quote the command when they describe this check, so they are skipped.
check_no_agent_shared_copy() {
  local bad=0
  all_files | grep -E '^agent-shared/|^docs/agent-shared(\.ja)?\.md$' && bad=1
  own_text_files | grep -vxF scripts/check.sh | grep -vE '^\.ikkan/' | while IFS= read -r f; do
    grep -nF 'agent-shuriken#subdirectory=agent-shared' "$f" | sed "s|^|$f:|"
  done | grep . && bad=1
  return "$bad"
}

# Every bundled data file is credited in its plugin's THIRD_PARTY_NOTICES.md.
check_notices() {
  local f plugin rel bad=0
  for f in $(all_files | grep -E '^plugins/[^/]+/skills/[^/]+/data/'); do
    plugin="$(printf '%s\n' "$f" | cut -d/ -f2)"
    rel="${f#plugins/$plugin/}"
    grep -qF "\`$rel\`" "plugins/$plugin/THIRD_PARTY_NOTICES.md" 2>/dev/null \
      || { echo "$f is not listed in plugins/$plugin/THIRD_PARTY_NOTICES.md"; bad=1; }
  done
  return "$bad"
}

# A plugin script that asks for packages beyond the Python standard library (PEP 723 `dependencies`)
# is allowed only when the dependency rule in AGENTS.md names its plugin as an exception.
check_script_dependencies() {
  local f plugin rule bad=0
  rule="$(grep -m1 'Keep runtime dependencies small' AGENTS.md)"
  for f in $(all_files | grep -E '^plugins/[^/]+/skills/[^/]+/scripts/.*\.py$' | python3 -c '
import re, sys
block = re.compile(r"^# /// script$(.*?)^# ///$", re.S | re.M)
for path in sys.stdin.read().split():
    m = block.search(open(path, encoding="utf-8").read())
    if m and re.search(r"^# dependencies = \[\n# +\"", m.group(1), re.M):
        print(path)'); do
    plugin="$(printf '%s\n' "$f" | cut -d/ -f2)"
    case "$rule" in
      *"\`$plugin\`"*) ;;
      *) echo "$f asks for packages beyond the standard library, and AGENTS.md does not name $plugin"; bad=1 ;;
    esac
  done
  return "$bad"
}

# Issues are written in English and titled like commit subjects, because the pull request and the
# squashed commit take an issue's title. New ikkan records are in English too.
check_agents_english() {
  local phrase bad=0
  for phrase in \
    'commits, issues, and pull requests in English' \
    'the sections the ikkan workflow adds to an issue' \
    'Title an issue in English like a commit subject' \
    'New records under `.ikkan/` are written in English' \
    'older ones are in Japanese'; do
    grep -qF -- "$phrase" AGENTS.md || { echo "AGENTS.md does not say: $phrase"; bad=1; }
  done
  return "$bad"
}

check_plugin_validate() {
  command -v claude >/dev/null || { echo "claude is not installed"; return 77; }
  local target bad=0
  for target in . $(plugin_names | sed 's|^|plugins/|'); do
    claude plugin validate "$target" 2>&1 | grep -q 'Validation passed' || {
      echo "claude plugin validate $target failed:"; claude plugin validate "$target" 2>&1 | tail -5; bad=1
    }
  done
  return "$bad"
}

run "shell scripts parse" check_shell_syntax
run "node scripts parse" check_node_syntax
run "python scripts parse" check_python_syntax
run "JSON files parse" check_json
run "marketplace lists every plugin once" check_marketplace
run "plugin manifests agree" check_manifests
run "plugin icons are square and present" check_icons
run "plugin folders are complete" check_plugin_files
run "hooks live only in plugins without skills" check_hook_plugins
run "plugins stay within directory limits" check_plugin_limits
run "SKILL.md frontmatter" check_skill_frontmatter
run "Codex skill metadata matches SKILL.md" check_codex_skill_metadata
run "versions match the changelogs" check_versions
run "README tables list every plugin" check_readme_tables
run "the root changelog names every plugin" check_root_changelog
run "publishing tables list every plugin" check_publishing_tables
run "pages have Japanese counterparts" check_japanese_pages
run "relative links resolve" check_links
run "no local user paths" check_no_personal_paths
run "no email addresses" check_no_email
run "English outside the Japanese pages" check_english
run "Japanese headings have no commas or colons" check_japanese_headings
run "no build output tracked" check_no_build_output
run "README names the agent-shared repository" check_readme_names_agent_shared
run "no agent-shared copy is left" check_no_agent_shared_copy
run "bundled data is credited" check_notices
run "script dependencies are named in AGENTS.md" check_script_dependencies
run "AGENTS.md asks for issues and new .ikkan records in English" check_agents_english
run "claude plugin validate" check_plugin_validate

printf '%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ]
