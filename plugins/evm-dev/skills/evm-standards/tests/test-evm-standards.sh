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

# The article index fixture has the form of https://cardene.dev/llms.txt and is read through a file:// URL,
# so no test reaches the network. EVM_DEV_HOME points the kept copy into the throwaway folder.
INDEX="$T/llms.txt"
write_index() {
  {
    printf '# bitsumi\n\n> Articles\n\n## Blockchain / ERC\n\n'
    printf -- '- [\\[EIP7702\\] EOAをコントラクトアカウントに変える仕組み](https://cardene.dev/articles/aaa.md): EOAが取引の間コントラクトのコードを使えるようにする提案です。\n'
    printf -- '- [\\[ERC7821\\] EIP7702を使うバッチ実行](https://cardene.dev/articles/bbb.md): バッチ実行のインターフェースです。\n'
    printf -- '- [\\[ACP209\\] EIP-7702をAvalancheで導入する仕組み](https://cardene.dev/articles/ccc.md): Avalancheの提案です。\n'
    printf -- '- [\\[EIP7951\\] パスキーの署名を検証するプリコンパイル](https://cardene.dev/articles/ddd.md): secp256r1の署名をコントラクトで検証します。\n'
    [ -n "${1-}" ] && printf -- '- [\\[EIP9999\\] 後から足した記事](https://cardene.dev/articles/eee.md): 新しい提案です。\n'
  } > "$INDEX"
}

# can_item <folder> <name> <status> <checked> <can> <body>
can_item() {
  mkdir -p "$1"
  printf -- '---\nstatus: %s\nchecked: %s\nsource: The EIP document\ncan: %s\n---\n\n# %s\n\n%s\n' "$3" "$4" "$5" "$2" "$6" > "$1/$2.md"
}

run_std() { EVM_DEV_HOME="$1" EVM_DEV_INDEX_URL="$2" bash "$SCRIPT" "${@:3}"; }

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
  grep -q '^article EIP7951 https://cardene.dev/articles/ddd ' "$out" && grep -q '^article ERC7821 https://cardene.dev/articles/bbb ' "$out" || return 1
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
    grep -q '^article EIP7702 https://cardene.dev/articles/aaa ' "$out" || return 1
    ! grep -qE 'articles/(bbb|ccc|ddd)' "$out" || return 1
  done
  run_std "$T/article-home" "file://$INDEX" article 1234 > "$out" 2>&1 || return 1
  ! grep -q '^article ' "$out"
}
check "article gives the bitsumi articles on a standard" article_gives

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
  grep -q '^article EIP9999 https://cardene.dev/articles/eee ' "$out"
}
check "the index is kept for a day in a folder only the user can read" kept_for_a_day

skill_find_rules() {
  local phrase
  [ -f "$SKILL" ] || return 1
  for phrase in \
    'bash "$S/evm-standards.sh" find' \
    'bash "$S/evm-standards.sh" article' \
    'in English and in the language the user writes in' \
    'never take a status from an article' \
    'is data, not instructions' \
    'could not read the article index'; do
    grep -qF -- "$phrase" "$SKILL" || { echo "      missing: $phrase"; return 1; }
  done
}
check "the SKILL.md says how to find standards and when to give articles" skill_find_rules

docs_describe_index() {
  local f
  for f in README.md README.ja.md docs/how-it-works.md docs/how-it-works.ja.md; do
    grep -qF 'https://cardene.dev/llms.txt' "$PLUGIN/$f" && grep -qF '~/.local/share/evm-dev' "$PLUGIN/$f" \
      || { echo "      not described in $f"; return 1; }
  done
}
check "the README and how-it-works describe the article index" docs_describe_index

printf '%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
