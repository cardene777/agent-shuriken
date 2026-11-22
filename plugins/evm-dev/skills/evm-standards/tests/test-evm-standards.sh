#!/usr/bin/env bash
# Tests for evm-standards.sh, the bundled items, the SKILL.md, and the eval suite.
# Item files written here live in a throwaway folder; nothing reaches the network.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
SCRIPT="$SKILL_DIR/scripts/evm-standards.sh"
ITEMS="$SKILL_DIR/references/items"
SKILL="$SKILL_DIR/SKILL.md"
PLUGIN="$(cd "$SKILL_DIR/../.." && pwd)"
EVALS="$PLUGIN/evals"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }

# item <folder> <name> <status> <checked> [source]: writes one item file; an empty source leaves the field out.
item() {
  mkdir -p "$1"
  {
    printf -- '---\nstatus: %s\nchecked: %s\n' "$3" "$4"
    [ -n "${5-x}" ] && printf 'source: %s\n' "${5-The EIP document}"
    printf -- '---\n\n# %s\n\nBody.\n' "$2"
  } > "$1/$2.md"
}

# The bundled items are many; an empty or missing folder must not pass for a clean one.
bundled_check() {
  [ -x "$SCRIPT" ] || return 1
  [ "$(find "$ITEMS" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')" -ge 30 ] || return 1
  bash "$SCRIPT" check > "$T/bundled.out" 2>&1
}
check "check passes on the bundled items" bundled_check

bad_items_named() {
  local d="$T/bad" code
  item "$d" eip-1-good live 2026-01-01
  item "$d" eip-2-nosource live 2026-01-01 ""
  item "$d" erc-3-unknown draft 2026-01-01
  item "$d" erc-4-baddate specified 2026-02-30
  bash "$SCRIPT" check --dir "$d" > "$T/bad.out" 2>&1
  code=$?
  [ "$code" -eq 1 ] || return 1
  grep -q 'eip-2-nosource' "$T/bad.out" && grep -q 'erc-3-unknown' "$T/bad.out" \
    && grep -q 'erc-4-baddate' "$T/bad.out" && ! grep -q 'eip-1-good' "$T/bad.out"
}
check "check names an item with a missing field, an unknown status, or an impossible date" bad_items_named

# On 2026-02-01, an announced item checked 2026-01-01 is 31 days old (past 30), one checked
# 2026-01-02 is exactly 30 days old (not past), a live item checked 2026-01-01 is well within 180,
# a specified item checked 2025-11-05 is 88 days old (within 90), and a stopped item checked
# 2025-08-01 is 184 days old (past 180).
stale_marked() {
  local d="$T/stale"
  item "$d" eip-10-old announced 2026-01-01
  item "$d" eip-11-edge announced 2026-01-02
  item "$d" erc-12-live live 2026-01-01
  item "$d" erc-13-specified specified 2025-11-05
  item "$d" eip-14-stopped stopped 2025-08-01
  # Each status at exactly its days (still ok) and one day past them (stale), counted to 2026-02-01.
  item "$d" erc-15-specified-edge specified 2025-11-03
  item "$d" erc-16-specified-old specified 2025-11-02
  item "$d" erc-17-live-edge live 2025-08-05
  item "$d" erc-18-live-old live 2025-08-04
  item "$d" eip-19-stopped-edge stopped 2025-08-05
  bash "$SCRIPT" list --dir "$d" --today 2026-02-01 > "$T/list.out" 2>&1 || return 1
  grep -Eq '^stale +announced +2026-01-01 +eip-10-old$' "$T/list.out" \
    && grep -Eq '^ok +announced +2026-01-02 +eip-11-edge$' "$T/list.out" \
    && grep -Eq '^ok +live +2026-01-01 +erc-12-live$' "$T/list.out" \
    && grep -Eq '^ok +specified +2025-11-05 +erc-13-specified$' "$T/list.out" \
    && grep -Eq '^stale +stopped +2025-08-01 +eip-14-stopped$' "$T/list.out" \
    && grep -Eq '^ok +specified +2025-11-03 +erc-15-specified-edge$' "$T/list.out" \
    && grep -Eq '^stale +specified +2025-11-02 +erc-16-specified-old$' "$T/list.out" \
    && grep -Eq '^ok +live +2025-08-05 +erc-17-live-edge$' "$T/list.out" \
    && grep -Eq '^stale +live +2025-08-04 +erc-18-live-old$' "$T/list.out" \
    && grep -Eq '^ok +stopped +2025-08-05 +eip-19-stopped-edge$' "$T/list.out"
}
check "list marks the items past the days for their status" stale_marked

only_erc_eip() {
  local f n=0
  for f in "$ITEMS"/*; do
    [ -e "$f" ] || return 1
    case "$(basename "$f")" in
      erc-*.md | eip-*.md) n=$((n + 1)) ;;
      *) return 1 ;;
    esac
  done
  [ "$n" -ge 30 ]
}
check "every item is an ERC or an EIP" only_erc_eip

no_urls() {
  [ -d "$ITEMS" ] || return 1
  ! grep -rIlE 'https?://|www\.' "$ITEMS" > /dev/null
}
check "no item holds a URL" no_urls

skill_rules() {
  local phrase
  [ -f "$SKILL" ] || return 1
  for phrase in \
    'Run `list` before answering' \
    're-check it against the official ERC or EIP document before you answer' \
    'say that you could not confirm it, with the date the item was checked' \
    'Never edit the items in the plugin'; do
    grep -qF -- "$phrase" "$SKILL" || return 1
  done
}
check "the SKILL.md keeps its rules on stale items and on not editing the items" skill_rules

# The body is counted in words and the description in characters, as the size the agent reads.
SKILL_WORDS_MAX=500
SKILL_DESCRIPTION_MAX=300
skill_size() {
  [ -f "$SKILL" ] || return 1
  python3 - "$SKILL" "$SKILL_WORDS_MAX" "$SKILL_DESCRIPTION_MAX" <<'PYEOF'
import re, sys
front, body = open(sys.argv[1], encoding="utf-8").read().split("---", 2)[1:]
words = len(body.split())
chars = len(re.search(r"^description: (.*)$", front, re.M).group(1))
print("      SKILL.md body %d words (max %s), description %d characters (max %s)" % (words, sys.argv[2], chars, sys.argv[3]))
sys.exit(0 if words <= int(sys.argv[2]) and chars <= int(sys.argv[3]) else 1)
PYEOF
}
check "the SKILL.md stays within its size limits" skill_size

# Each case has a case.yaml and an executable fixture.sh that runs the way claude plugin eval runs it
# (in home/cwd with HOME at home). The knowledge cases grade that the skill fired; the unrelated one
# grades that it did not.
CASES=(eof-status p256-precompile erc-status unrelated-request)
eval_suite() {
  local c home
  for c in "${CASES[@]}"; do
    [ -f "$EVALS/$c/case.yaml" ] && [ -x "$EVALS/$c/fixture.sh" ] || return 1
    home="$T/fixture-$c/home"
    mkdir -p "$home/cwd"
    (cd "$home/cwd" && HOME="$home" bash "$EVALS/$c/fixture.sh") > /dev/null 2>&1 || return 1
    case "$c" in
      unrelated-request) grep -q 'name: skill-not-loaded' "$EVALS/$c/case.yaml" || return 1 ;;
      *) grep -q 'name: skill-fired' "$EVALS/$c/case.yaml" || return 1 ;;
    esac
  done
  git -C "$PLUGIN" check-ignore -q "evals/results/run.json"
}
check "the eval suite has its cases and each fixture builds its state" eval_suite

every_item_can() {
  local f n=0
  for f in "$ITEMS"/*.md; do
    [ -f "$f" ] || return 1
    n=$((n + 1))
    sed -n '/^---$/,/^---$/p' "$f" | grep -qE '^can: .{20,}' || { echo "      no can field: $(basename "$f")"; return 1; }
  done
  [ "$n" -ge 30 ]
}
check "every item says what the standard lets contracts and wallets do" every_item_can

# The article index fixtures have the line form of an llms.txt index and are read through a file:// URL
# or a path, so no test reaches the network. Every run gets a throwaway HOME, so the user's own
# ~/.evm-dev/article-index is never read, and EVM_DEV_HOME points the kept copies into the throwaway
# folder. A run that names an https index also points the proxies at a closed port, so a fetch fails
# at once instead of reaching the site.
INDEX="$T/llms.txt"
write_index() {
  {
    printf '# Example articles\n\n> Articles\n\n## Blockchain / ERC\n\n'
    printf -- '- [\\[EIP7702\\] EOAをコントラクトアカウントに変える仕組み](https://example.com/articles/aaa.md): EOAが取引の間コントラクトのコードを使えるようにする提案です。\n'
    printf -- '- [\\[ERC7821\\] EIP7702を使うバッチ実行](https://example.com/articles/bbb.md): バッチ実行のインターフェースです。\n'
    printf -- '- [\\[ACP209\\] EIP-7702をAvalancheで導入する仕組み](https://example.com/articles/ccc.md): Avalancheの提案です。\n'
    printf -- '- [\\[EIP7951\\] パスキーの署名を検証するプリコンパイル](https://example.com/articles/ddd.md): secp256r1の署名をコントラクトで検証します。\n'
    [ -n "${1-}" ] && printf -- '- [\\[EIP9999\\] 後から足した記事](https://example.com/articles/eee.md): 新しい提案です。\n'
  } > "$INDEX"
}

# one_index <file> <link>...: writes an index whose EIP-7702 articles link to each link given.
one_index() {
  local f="$1" link
  shift
  : > "$f"
  for link in "$@"; do
    printf -- '- [\\[EIP7702\\] Setting code on an account](%s): How an account runs contract code.\n' "$link" >> "$f"
  done
}

# can_item <folder> <name> <status> <checked> <can> <body>
can_item() {
  mkdir -p "$1"
  printf -- '---\nstatus: %s\nchecked: %s\nsource: The EIP document\ncan: %s\n---\n\n# %s\n\n%s\n' "$3" "$4" "$5" "$2" "$6" > "$1/$2.md"
}

# run_std <kept folder> <index URL> <args>...: names the index in EVM_DEV_INDEX_URL.
run_std() { HOME="$T/std-home" EVM_DEV_HOME="$1" EVM_DEV_INDEX_URL="$2" bash "$SCRIPT" "${@:3}"; }

# run_home <home> <kept folder> <args>...: names nothing in EVM_DEV_INDEX_URL, so only <home>/.evm-dev is read.
run_home() {
  env -u EVM_DEV_INDEX_URL HOME="$1" EVM_DEV_HOME="$2" https_proxy=http://127.0.0.1:9 http_proxy=http://127.0.0.1:9 \
    HTTPS_PROXY=http://127.0.0.1:9 HTTP_PROXY=http://127.0.0.1:9 bash "$SCRIPT" "${@:3}"
}

# name_index <home> <line>: writes the one line of <home>/.evm-dev/article-index.
name_index() { mkdir -p "$1/.evm-dev" && printf '%s\n' "$2" > "$1/.evm-dev/article-index"; }

find_no_index() {
  local d="$T/none-items" out="$T/none.out" home
  can_item "$d" eip-7951-p256 live 2026-11-10 "Contracts can verify passkey signatures on the P-256 curve." "A precompile."
  for home in "$T/bare-home" "$T/empty-home"; do
    mkdir -p "$home"
    [ "$home" = "$T/empty-home" ] && name_index "$home" ""
    run_home "$home" "$T/none-keep" find --dir "$d" passkey > "$out" 2>&1 || return 1
    grep -q '^item eip-7951-p256 ' "$out" || return 1
    grep -qx 'articles: no article index is named' "$out" || return 1
    ! grep -q '^article ' "$out" || return 1
    [ -z "$(ls -A "$T/none-keep" 2>/dev/null)" ] || return 1
  done
}
check "find reads no index when none is named" find_no_index

index_url_in_file() {
  local home="$T/url-home" out="$T/url.out"
  write_index
  name_index "$home" "file://$INDEX"
  run_home "$home" "$T/url-keep" article 7702 > "$out" 2>&1 || return 1
  grep -q '^article EIP7702 https://example.com/articles/aaa ' "$out"
}
check "an index URL in article-index is read" index_url_in_file

path_in_file() {
  local home="$T/path-home" out="$T/path.out" line
  write_index
  mkdir -p "$home"
  cp "$INDEX" "$home/articles.txt"
  for line in "$INDEX" "~/articles.txt"; do
    name_index "$home" "$line"
    run_home "$home" "$T/path-keep" article 7702 > "$out" 2>&1 || return 1
    grep -q '^article EIP7702 https://example.com/articles/aaa ' "$out" || return 1
  done
  [ -z "$(ls -A "$T/path-keep" 2>/dev/null)" ]
}
check "a path in article-index is read as a file and not kept" path_in_file

env_wins() {
  local home="$T/wins-home" out="$T/wins.out"
  mkdir -p "$T/wins"
  one_index "$T/wins/file-index.txt" https://example.com/from-file.md
  one_index "$T/wins/env-index.txt" https://example.com/from-env.md
  name_index "$home" "$T/wins/file-index.txt"
  HOME="$home" EVM_DEV_HOME="$T/wins-keep" EVM_DEV_INDEX_URL="file://$T/wins/env-index.txt" \
    bash "$SCRIPT" article 7702 > "$out" 2>&1 || return 1
  grep -q '^article EIP7702 https://example.com/from-env ' "$out" && ! grep -q 'from-file' "$out"
}
check "EVM_DEV_INDEX_URL wins over article-index" env_wins

# kept_name <index URL>: the name of the copy kept for that URL.
kept_name() {
  python3 -c 'import hashlib, sys; print("article-index-%s.txt" % hashlib.sha256(sys.argv[1].encode()).hexdigest()[:16])' "$1"
}

url_host_rule() {
  local home="$T/host-home" keep="$T/host-keep" out="$T/host.out" url=https://example.com/llms.txt
  mkdir -p "$keep" && chmod 700 "$keep"
  one_index "$keep/$(kept_name "$url")" https://example.com/articles/same.md https://example.org/articles/other.md \
    http://example.com/articles/plain.md
  chmod 600 "$keep/$(kept_name "$url")"
  name_index "$home" "$url"
  run_home "$home" "$keep" article 7702 > "$out" 2>&1 || return 1
  grep -q '^article EIP7702 https://example.com/articles/same ' "$out" || return 1
  ! grep -qE 'example\.org|articles/plain' "$out"
}
check "an index read from a URL gives only https links on its own host" url_host_rule

file_https_only() {
  local home="$T/https-home" out="$T/https.out"
  mkdir -p "$home"
  one_index "$home/index.txt" https://example.org/articles/other-host.md http://example.com/articles/plain.md
  name_index "$home" "$home/index.txt"
  run_home "$home" "$T/https-keep" article 7702 > "$out" 2>&1 || return 1
  grep -q '^article EIP7702 https://example.org/articles/other-host ' "$out" && ! grep -q 'articles/plain' "$out"
}
check "an index read from a file gives only https links" file_https_only

kept_per_url() {
  local keep="$T/per-keep" out="$T/per.out"
  mkdir -p "$T/per"
  one_index "$T/per/first.txt" https://example.com/first.md
  one_index "$T/per/second.txt" https://example.com/second.md
  run_std "$keep" "file://$T/per/first.txt" article 7702 > "$out" 2>&1 || return 1
  grep -q '^article EIP7702 https://example.com/first ' "$out" || return 1
  run_std "$keep" "file://$T/per/second.txt" article 7702 > "$out" 2>&1 || return 1
  grep -q '^article EIP7702 https://example.com/second ' "$out" && ! grep -q 'example.com/first' "$out"
}
check "a kept copy belongs to one index URL" kept_per_url

scripts_no_url() {
  local hits
  hits="$(grep -ohE 'https?://[^ )"'"'"'<>`]+' "$SKILL_DIR/scripts/standards.py" "$SCRIPT" \
    | grep -vE '^https?://example\.(com|org)(/|$)')"
  [ -z "$hits" ] || { echo "      URLs: $(printf '%s ' $hits)"; return 1; }
}
check "the scripts name no article index of their own" scripts_no_url

find_lists() {
  local d="$T/find-items" out="$T/find.out" a b
  can_item "$d" eip-7951-p256 live 2026-11-10 "Contracts can verify passkey signatures on the P-256 curve." "A precompile."
  can_item "$d" eip-7702-setcode live 2026-11-09 "An EOA can run contract code for one transaction." "Wallets can batch calls."
  can_item "$d" erc-20-token live 2026-11-08 "Tokens move between accounts with a standard interface." "Transfers."
  write_index
  run_std "$T/find-home" "file://$INDEX" find --dir "$d" passkey signatures パスキー 署名 batch バッチ > "$out" 2>&1 || return 1
  grep -q '^item eip-7951-p256 live 2026-11-10 ' "$out" && grep -q '^item eip-7702-setcode live 2026-11-09 ' "$out" || return 1
  ! grep -q 'erc-20-token' "$out" || return 1
  a=$(grep -n '^item eip-7951-p256 ' "$out" | cut -d: -f1); b=$(grep -n '^item eip-7702-setcode ' "$out" | cut -d: -f1)
  [ "$a" -lt "$b" ] || return 1
  grep -q '^article EIP7951 https://example.com/articles/ddd ' "$out" && grep -q '^article ERC7821 https://example.com/articles/bbb ' "$out" || return 1
  a=$(grep -n '^article EIP7951 ' "$out" | cut -d: -f1); b=$(grep -n '^article ERC7821 ' "$out" | cut -d: -f1)
  [ "$a" -lt "$b" ] || return 1
  ! grep -qE 'articles/(aaa|ccc)' "$out"
}
check "find lists the items and the articles that match the words" find_lists

find_passkey() {
  run_std "$T/passkey-home" "file://$T/no-index.txt" find passkey P-256 > "$T/passkey.out" 2>&1 || return 1
  grep -q '^item eip-7951-secp256r1-precompile ' "$T/passkey.out"
}
check "find returns EIP-7951 for a passkey signature" find_passkey

article_gives() {
  local out="$T/article.out" form
  write_index
  for form in 7702 EIP-7702 eip7702; do
    run_std "$T/article-home" "file://$INDEX" article "$form" > "$out" 2>&1 || return 1
    grep -q '^article EIP7702 https://example.com/articles/aaa ' "$out" || return 1
    ! grep -qE 'articles/(bbb|ccc|ddd)' "$out" || return 1
  done
  run_std "$T/article-home" "file://$INDEX" article 1234 > "$out" 2>&1 || return 1
  ! grep -q '^article ' "$out"
}
check "article gives the articles on a standard" article_gives

find_offline() {
  local d="$T/offline-items" out="$T/offline.out"
  can_item "$d" eip-7951-p256 live 2026-11-10 "Contracts can verify passkey signatures on the P-256 curve." "A precompile."
  run_std "$T/offline-home" "file://$T/no-index.txt" find --dir "$d" passkey > "$out" 2>&1 || return 1
  grep -q '^item eip-7951-p256 ' "$out" && grep -qi 'could not read' "$out"
}
check "find answers from the items when the index cannot be read" find_offline

request_has_no_words() {
  local out="$T/request.out"
  write_index
  run_std "$T/request-home" "file://$INDEX" find secretword > "$out" 2>&1 || return 1
  grep -qF "file://$INDEX" "$out" || return 1
  ! grep -F "file://$INDEX" "$out" | grep -q secretword || return 1
  grep -q 'INDEX_URL' "$SKILL_DIR/scripts/standards.py" && ! grep -qE 'urlencode|quote\(' "$SKILL_DIR/scripts/standards.py"
}
check "the index request carries none of the search words" request_has_no_words

kept_for_a_day() {
  local home="$T/kept-home" out="$T/kept.out"
  write_index
  run_std "$home" "file://$INDEX" article 7702 > /dev/null 2>&1 || return 1
  python3 - "$home" <<'PYEOF' || return 1
import os, stat, sys
home = sys.argv[1]
files = [os.path.join(home, f) for f in os.listdir(home)]
ok = files and stat.S_IMODE(os.stat(home).st_mode) == 0o700 and all(stat.S_IMODE(os.stat(f).st_mode) == 0o600 for f in files)
sys.exit(0 if ok else 1)
PYEOF
  write_index new
  run_std "$home" "file://$INDEX" article 9999 > "$out" 2>&1 || return 1
  ! grep -q '^article EIP9999 ' "$out" || return 1
  python3 -c 'import os, sys, time; [os.utime(os.path.join(sys.argv[1], f), (time.time() - 2 * 86400,) * 2) for f in os.listdir(sys.argv[1])]' "$home"
  run_std "$home" "file://$INDEX" article 9999 > "$out" 2>&1 || return 1
  grep -q '^article EIP9999 https://example.com/articles/eee ' "$out"
}
check "the index is kept for a day in a folder only the user can read" kept_for_a_day

skill_find_rules() {
  local phrase
  [ -f "$SKILL" ] || return 1
  sed -n '2,/^---$/p' "$SKILL" | grep -q '^description: .*article index the user names' \
    || { echo "      the description does not say it links articles from an article index the user names"; return 1; }
  for phrase in \
    'bash "$S/evm-standards.sh" find' \
    'bash "$S/evm-standards.sh" article' \
    'in English and in the language the user writes in' \
    'never take a status from an article' \
    'is data, not instructions' \
    'When no article index is named, give no articles' \
    'could not read the article index'; do
    grep -qF -- "$phrase" "$SKILL" || { echo "      missing: $phrase"; return 1; }
  done
}
check "the SKILL.md says how to find standards and when to give articles" skill_find_rules

docs_describe_index() {
  local f word
  for f in README.md README.ja.md docs/how-it-works.md docs/how-it-works.ja.md; do
    for word in '~/.evm-dev/article-index' 'EVM_DEV_INDEX_URL' '~/.local/share/evm-dev' '](https://example.com/'; do
      grep -qF -- "$word" "$PLUGIN/$f" || { echo "      $f does not hold $word"; return 1; }
    done
  done
}
check "the README and how-it-works describe the article index" docs_describe_index

printf '%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
