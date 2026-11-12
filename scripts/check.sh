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
# word lists that check Japanese prose, and Japanese samples and their tests.
JA_ALLOWED=(
  plugins/account-cleanup/skills/account-cleanup/templates/sheet.html
  plugins/account-cleanup/skills/account-cleanup/templates/followups.html
  plugins/account-cleanup/skills/account-cleanup/scripts/browser.mjs
  plugins/account-cleanup/skills/account-cleanup/scripts/connections-guide.sh
  plugins/account-cleanup/skills/account-cleanup/scripts/subscriptions-guide.sh
  plugins/pc-tidy/skills/pc-tidy/scripts/tidy.py
  plugins/diagram-explainer/skills/diagram-explainer/assets/charts.js
  plugins/diagram-explainer/skills/diagram-explainer/assets/doc.js
  plugins/diagram-explainer/skills/diagram-explainer/assets/print.js
  plugins/diagram-explainer/skills/diagram-explainer/scripts/render.py
  plugins/diagram-explainer/skills/diagram-explainer/scripts/ladder.py
  plugins/diagram-explainer/skills/diagram-explainer/scripts/check.py
  plugins/diagram-explainer/skills/diagram-explainer/scripts/figure.py
  plugins/diagram-explainer/skills/diagram-explainer/references/prose-words.txt
  plugins/diagram-explainer/skills/diagram-explainer/references/words-plain.txt
  plugins/diagram-explainer/skills/diagram-explainer/references/metaphor-words.tsv
  plugins/diagram-explainer/skills/diagram-explainer/examples/content.sample.ja.json
  plugins/diagram-explainer/skills/diagram-explainer/examples/ladders/checkout-ja.json
  plugins/diagram-explainer/skills/diagram-explainer/tests/test-render.sh
)
# Third-party files copied unmodified; they are checked only for valid syntax.
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
# Text files written in this repository (no vendored data, no images).
own_text_files() {
  all_files | grep -vE '\.(png|jpg|jpeg|gif|webp|svg|ico|zip)$' | grep -vxF -f <(printf '%s\n' "${VENDORED[@]}")
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
    ls plugins/"$name"/skills/*/SKILL.md >/dev/null 2>&1 || { echo "$name: no skills/<skill>/SKILL.md"; bad=1; }
    [ ! -e "plugins/$name/hooks" ] || { echo "$name: hooks make the plugin ineligible for OpenAI's directory"; bad=1; }
  done
  return "$bad"
}

# The plugin directories hold a version for a reviewer over these limits.
check_plugin_limits() {
  local name count f bad=0
  for name in $(plugin_names); do
    count="$(all_files | grep -c "^plugins/$name/")"
    [ "$count" -le 512 ] || { echo "$name: $count files, over 512"; bad=1; }
    for f in $(all_files | grep "^plugins/$name/" | grep -vE '\.(png|jpg|jpeg|gif|webp|svg|woff2?|ttf|otf)$' | grep -vxF -f <(printf '%s\n' "${SIZE_EXCEPTIONS[@]}")); do
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
check_versions() {
  local name changelog version released bad=0
  for changelog in CHANGELOG.md plugins/*/CHANGELOG.md; do
    [ -f "$changelog" ] || continue
    grep -qx '## \[Unreleased\]' "$changelog" || { echo "$changelog has no ## [Unreleased] section"; bad=1; }
    [ -n "$(newest_release "$changelog")" ] || { echo "$changelog has no ## [X.Y.Z] - YYYY-MM-DD section"; bad=1; }
  done
  for name in $(plugin_names); do
    [ -f "plugins/$name/CHANGELOG.md" ] || continue
    version="$(jq -r .version "plugins/$name/.claude-plugin/plugin.json")"
    released="$(newest_release "plugins/$name/CHANGELOG.md")"
    [ "$version" = "$released" ] || { echo "$name is $version but its CHANGELOG.md's newest release is $released"; bad=1; }
  done
  return "$bad"
}

# Each README has a row per plugin whose last column links the plugin's current version.
check_readme_tables() {
  local name readme version row bad=0
  for readme in README.md README.ja.md; do
    for name in $(plugin_names); do
      row="$(grep -E "^\| \[$name\]\(plugins/$name\) \|" "$readme")"
      [ -n "$row" ] || { echo "$readme has no table row for $name"; bad=1; continue; }
      version="$(jq -r .version "plugins/$name/.claude-plugin/plugin.json")"
      [[ "$row" == *"| [$version](plugins/$name/CHANGELOG.md) |" ]] \
        || { echo "$readme: the row for $name does not end with [$version](plugins/$name/CHANGELOG.md)"; bad=1; }
      # The run column names the Claude Code command of every skill and the name Codex lists.
      for skill in plugins/"$name"/skills/*/; do
        skill="$(basename "$skill")"
        [[ "$row" == *"\`/$name:$skill\`"* ]] || { echo "$readme: the row for $name does not show \`/$name:$skill\`"; bad=1; }
      done
      display="$(jq -r '.interface.displayName // empty' "plugins/$name/.codex-plugin/plugin.json")"
      [[ "$row" == *"**$display**"* ]] || { echo "$readme: the row for $name does not show **$display** for Codex"; bad=1; }
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
check_links() {
  local f link target bad=0
  for f in $(all_files | grep '\.md$'); do
    while IFS= read -r link; do
      target="${link%%#*}"
      [ -n "$target" ] || continue
      [ -e "$(dirname "$f")/$target" ] || { echo "$f: $link does not exist"; bad=1; }
    done < <(grep -oE '\]\([^) ]+\)|src="[^"]+"' "$f" | sed -E 's/^\]\(//; s/\)$//; s/^src="//; s/"$//' | grep -vE '^[a-z]+:|^#')
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

# Japanese appears only in *.ja.md pages and the allowed files, or as the language name on a switch.
check_english() {
  own_text_files | grep -vE '\.ja\.md$' | grep -vxF -f <(printf '%s\n' "${JA_ALLOWED[@]}") | python3 -c '
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
run "plugins stay within directory limits" check_plugin_limits
run "SKILL.md frontmatter" check_skill_frontmatter
run "Codex skill metadata matches SKILL.md" check_codex_skill_metadata
run "versions match the changelogs" check_versions
run "README tables list every plugin" check_readme_tables
run "publishing tables list every plugin" check_publishing_tables
run "pages have Japanese counterparts" check_japanese_pages
run "relative links resolve" check_links
run "no local user paths" check_no_personal_paths
run "no email addresses" check_no_email
run "English outside the Japanese pages" check_english
run "no build output tracked" check_no_build_output
run "bundled data is credited" check_notices
run "claude plugin validate" check_plugin_validate

printf '%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ]
