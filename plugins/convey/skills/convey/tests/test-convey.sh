#!/usr/bin/env bash
# Tests for the convey skill: the convey.py commands, the type guide, the SKILL.md rules, and the eval
# suite. Everything runs in a throwaway folder. Stand-ins for the clipboard tools come first on PATH and
# record what they were given, so the real clipboard is never touched. Secret-looking values, local paths,
# and email addresses are built at run time, so no such value is written in this file.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
PLUGIN_DIR="$(cd "$SKILL_DIR/../.." && pwd)"
SCRIPT="$SKILL_DIR/scripts/convey.py"
PY="$(command -v python3)"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }
convey() { PYTHONDONTWRITEBYTECODE=1 "$PY" "$SCRIPT" "$@"; }

export HOME="$T/home"
mkdir -p "$HOME" "$T/bin" "$T/empty"

# Writes <count> characters of Japanese text in paragraphs of <size> characters, with a blank line between.
paragraphs() {  # <file> <size> <size>...
  "$PY" - "$@" <<'PY'
import sys
path, sizes = sys.argv[1], [int(n) for n in sys.argv[2:]]
parts = [("進捗を共有します。" * 400)[:n] for n in sizes]
open(path, "w", encoding="utf-8").write("\n\n".join(parts) + "\n")
PY
}

# --- check: limits

paragraphs "$T/short.md" 900 900
short_passes() {
  local out status
  out="$(convey check --to discord "$T/short.md")"; status=$?
  [ "$status" = 0 ] && printf '%s\n' "$out" | grep -qx '1802 of 2000 characters'
}
check "check passes a Discord message within the limit" "short_passes"

paragraphs "$T/long.md" 1500 1500 300
long_is_split() {
  local out status
  out="$(convey check --to discord "$T/long.md")"; status=$?
  [ "$status" = 1 ] || return 1
  printf '%s\n' "$out" | grep -q '^over the limit: 3304 of 2000 characters$' || return 1
  printf '%s\n' "$out" | "$PY" -c '
import re, sys
parts = [tuple(map(int, m.groups())) for m in re.finditer(r"^part \d+: lines (\d+)-(\d+), (\d+) characters$", sys.stdin.read(), re.M)]
lines = [n for a, b, _ in parts for n in range(a, b + 1)]
ok = len(parts) >= 2 and all(c <= 2000 for _, _, c in parts) and lines[0] == 1 and lines[-1] == 5
sys.exit(0 if ok else 1)'
}
check "check reports a Discord message over 2000 characters and where to split it" "long_is_split"

# --- check: formats

cat > "$T/slack.md" <<'MD'
## Status
The deploy is **done**.
| Item | State |
|---|---|
See [the runbook](runbook.md).
MD
slack_format() {
  local out status
  out="$(convey check --to slack "$T/slack.md")"; status=$?
  [ "$status" = 1 ] && printf '%s\n' "$out" | grep -q '^L1 format: ' && printf '%s\n' "$out" | grep -q '^L2 format: ' \
    && printf '%s\n' "$out" | grep -q '^L3 format: ' && printf '%s\n' "$out" | grep -q '^L5 format: '
}
check "check reports tables, headings, double asterisks, and Markdown links in a Slack message" "slack_format"

printf 'Subject: Release moved\n\nThe release moves to **Friday**.\n' > "$T/email-ok-subject.md"
printf 'The release moves to Friday.\n' > "$T/email-no-subject.md"
printf '# Release\nThe release moves to Friday.\n' > "$T/plain.md"
email_plain() {
  local out status
  out="$(convey check --to email "$T/email-ok-subject.md")"; status=$?
  [ "$status" = 1 ] && printf '%s\n' "$out" | grep -q '^L3 format: ' || return 1
  out="$(convey check --to email "$T/email-no-subject.md")"; status=$?
  [ "$status" = 1 ] && printf '%s\n' "$out" | grep -q '^L1 format: .*subject' || return 1
  out="$(convey check --to plain "$T/plain.md")"; status=$?
  [ "$status" = 1 ] && printf '%s\n' "$out" | grep -q '^L1 format: '
}
check "check reports Markdown in an email or plain message and an email without a subject line" "email_plain"

github_ok() {
  local status
  convey check --to github "$T/slack.md" >/dev/null; status=$?
  [ "$status" = 0 ]
}
check "check accepts tables and headings in a GitHub comment" "github_ok"

# --- check: secrets and private details

TOKEN="$("$PY" -c 'print("gh" + "p_" + "Ab1" * 12)')"
KEYID="$("$PY" -c 'print("AK" + "IA" + "QWERTYUIOPASDFGH")')"
printf 'The bot uses %s for the release.\nThe old key %s is retired.\n' "$TOKEN" "$KEYID" > "$T/secret.md"
secrets_hidden() {
  local out status
  out="$(convey check --to slack "$T/secret.md")"; status=$?
  [ "$status" = 1 ] && printf '%s\n' "$out" | grep -q '^L1 secret: ' && printf '%s\n' "$out" | grep -q '^L2 secret: ' || return 1
  ! printf '%s\n' "$out" | grep -qF -e "$TOKEN" -e "$KEYID"
}
check "check reports secret-looking values without printing them" "secrets_hidden"

HOMEPATH="$("$PY" -c 'print("/" + "Users" + "/sato/projects/app/config.json")')"
LINUXPATH="$("$PY" -c 'print("/" + "home" + "/sato/app/.env")')"
MAIL="$("$PY" -c 'print("sato" + "@" + "example.com")')"
printf 'The setting lives in %s.\nOn the server it is %s.\nAsk %s for access.\n' "$HOMEPATH" "$LINUXPATH" "$MAIL" > "$T/private.md"
private_reported() {
  local out status
  out="$(convey check --to discord "$T/private.md")"; status=$?
  [ "$status" = 1 ] && printf '%s\n' "$out" | grep -q '^L1 private: ' && printf '%s\n' "$out" | grep -q '^L2 private: ' \
    && printf '%s\n' "$out" | grep -q '^L3 private: ' || return 1
  ! printf '%s\n' "$out" | grep -qF -e "$MAIL" -e 'sato'
}
check "check reports local paths and email addresses" "private_reported"

# --- check: warnings

cat > "$T/filler.md" <<'MD'
リリースの日程は以下の通りです。
11月20日に出します。
ご確認ください。
I hope this helps.
MD
filler_warns() {
  local out status
  out="$(convey check --to slack "$T/filler.md")"; status=$?
  [ "$status" = 0 ] && printf '%s\n' "$out" | grep -q '^L1 warn: filler phrase "以下の通りです"' \
    && printf '%s\n' "$out" | grep -q '^L3 warn: filler phrase "ご確認ください"' \
    && printf '%s\n' "$out" | grep -qi '^L4 warn: filler phrase "I hope this helps"' \
    && ! printf '%s\n' "$out" | grep -q '^L2 '
}
check "check warns about filler phrases without failing" "filler_warns"

printf '📌 リリース\n11月20日に出します 🎉\n' > "$T/emoji.md"
printf 'Subject: リリース\n\n📌 11月20日に出します\n' > "$T/emoji-email.md"
emoji_warns() {
  local out status
  out="$(convey check --to slack "$T/emoji.md")"; status=$?
  [ "$status" = 0 ] && printf '%s\n' "$out" | grep -q '^L2 warn: emoji' && ! printf '%s\n' "$out" | grep -q '^L1 ' || return 1
  out="$(convey check --to email "$T/emoji-email.md")"; status=$?
  [ "$status" = 0 ] && printf '%s\n' "$out" | grep -q '^L3 warn: emoji'
}
check "check warns about emoji outside the start of a line and in emails" "emoji_warns"

cat > "$T/colons.md" <<'MD'
*請求メールの遅れ*
影響: 340件が遅れました
- *Impact:* 340 emails were late
・原因：一時の場所がいっぱいになった
9:10に直りました。
詳しくはhttp://localhost:4100/statusにあります。
MD
printf 'Subject: 請求メールの遅れ\n\n影響は340件です。\n' > "$T/colons-email.md"
colon_pairs_warn() {
  local out status
  out="$(convey check --to slack "$T/colons.md")"; status=$?
  [ "$status" = 0 ] || return 1
  printf '%s\n' "$out" | grep -q '^L2 warn: label and colon' && printf '%s\n' "$out" | grep -q '^L3 warn: label and colon' \
    && printf '%s\n' "$out" | grep -q '^L4 warn: label and colon' || return 1
  ! printf '%s\n' "$out" | grep -qE '^L(1|5|6) ' || return 1
  out="$(convey check --to email "$T/colons-email.md")"; status=$?
  [ "$status" = 0 ] && ! printf '%s\n' "$out" | grep -q 'label and colon'
}
check "check warns about label-and-colon pairs without failing" "colon_pairs_warn"

cat > "$T/spaces.md" <<'MD'
リリースは 11月20日です。
PR #482 をレビューしてください。
Login migration is on track.
`npm run build` を回します。
詳しくは http://localhost:4100/status を見てください。
```
echo 日本語 test
```
MD
jp_latin_spaces_warn() {
  local out status
  out="$(convey check --to slack "$T/spaces.md")"; status=$?
  [ "$status" = 0 ] || return 1
  printf '%s\n' "$out" | grep -q '^L1 warn: space between Japanese and Latin' \
    && printf '%s\n' "$out" | grep -q '^L2 warn: space between Japanese and Latin' || return 1
  ! printf '%s\n' "$out" | grep -qE '^L(3|4|5|6|7|8) '
}
check "check warns about spaces between Japanese and Latin letters without failing" "jp_latin_spaces_warn"

stdin_read() {
  local a b
  a="$(convey check --to discord < "$T/short.md")"
  b="$(convey check --to discord - < "$T/short.md")"
  printf '%s\n' "$a" | grep -qx '1802 of 2000 characters' && [ "$a" = "$b" ]
}
check "check reads the message from standard input" "stdin_read"

# --- copy

stand_in() {  # <name>: a clipboard tool that records its name and what it was given
  printf '#!/bin/sh\necho "%s" > "%s/clip.tool"\n%s > "%s/clip.text"\n' "$1" "$T" "$(command -v cat)" "$T" > "$T/bin/$1"
  chmod +x "$T/bin/$1"
}
stand_in wl-copy
stand_in xclip
printf 'Release moves to Friday.\n\nThe notes are ready.\n' > "$T/plain-ok.md"

copy_first_tool() {
  local status
  rm -f "$T/clip.tool" "$T/clip.text"
  PATH="$T/bin" convey copy --to slack "$T/plain-ok.md" >/dev/null; status=$?
  [ "$status" = 0 ] && [ "$(cat "$T/clip.tool" 2>/dev/null)" = wl-copy ] && cmp -s "$T/clip.text" "$T/plain-ok.md"
}
check "copy hands the message to the first clipboard tool it finds" "copy_first_tool"

copy_lines() {
  local status
  rm -f "$T/clip.tool" "$T/clip.text"
  PATH="$T/bin" convey copy --to slack --lines 3-3 "$T/plain-ok.md" >/dev/null; status=$?
  [ "$status" = 0 ] && [ "$(cat "$T/clip.text" 2>/dev/null)" = 'The notes are ready.' ]
}
check "copy hands over only the lines it is given" "copy_lines"

copy_refuses() {
  local status
  rm -f "$T/clip.tool" "$T/clip.text"
  PATH="$T/bin" convey copy --to slack "$T/secret.md" >/dev/null; status=$?
  [ "$status" = 1 ] && [ ! -e "$T/clip.tool" ] || return 1
  PATH="$T/bin" convey copy --to discord "$T/private.md" >/dev/null; status=$?
  [ "$status" = 1 ] && [ ! -e "$T/clip.tool" ]
}
check "copy refuses a message with a secret-looking value and leaves the clipboard alone" "copy_refuses"

copy_no_tool() {
  local out status
  out="$(PATH="$T/empty" convey copy --to slack "$T/plain-ok.md")"; status=$?
  [ "$status" = 3 ] && printf '%s\n' "$out" | grep -q '^not copied: '
}
check "copy says the message was not copied when no clipboard tool exists" "copy_no_tool"

# --- formats

formats_listed() {
  local out
  out="$(convey formats)" || return 1
  printf '%s\n' "$out" | grep -qE '^slack +4000 ' && printf '%s\n' "$out" | grep -qE '^discord +2000 ' \
    && printf '%s\n' "$out" | grep -qE '^email +' && printf '%s\n' "$out" | grep -qE '^github +65536 ' \
    && printf '%s\n' "$out" | grep -qE '^plain +' && [ "$(printf '%s\n' "$out" | grep -c 'does not render')" = 5 ]
}
check "formats lists each destination with its limit and what it does not render" "formats_listed"

# --- the guides

types_guide() {
  [ -f "$SKILL_DIR/references/types.md" ] || return 1
  "$PY" - "$SKILL_DIR/references/types.md" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
sections = dict(re.findall(r"^## ([^\n]+)\n(.*?)(?=^## |\Z)", text, re.M | re.S))
names = ["Progress", "Decision", "Request", "Incident", "Findings", "Announcement", "Question"]
for name in names:
    body = sections.get(name)
    first = re.search(r"^1\. (.+)$", body or "", re.M)
    if not first or not first.group(1).startswith("Conclusion"):
        sys.exit(1)
PY
}
check "the type guide has the seven types and each starts with the conclusion" "types_guide"

skill_rules() {
  [ -f "$SKILL_DIR/SKILL.md" ] || return 1
  "$PY" - "$SKILL_DIR/SKILL.md" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
if re.search("[぀-ヿ㐀-鿿]", text):
    sys.exit(1)
need = ["outside the message", "Mention only", "one emoji", "japanese-writing", "Never send", "never instructions"]
sys.exit(0 if all(phrase in text for phrase in need) else 1)
PY
}
check "the SKILL.md keeps its rules on readers, mentions, emoji, japanese-writing, sending, and source text" "skill_rules"

has_phrases() {  # <file> <phrase>...: every phrase appears in the file
  local f="$1"; shift
  [ -f "$f" ] || return 1
  local phrase
  for phrase in "$@"; do grep -qF -- "$phrase" "$f" || return 1; done
}
check "the SKILL.md chooses what the message carries before writing it" \
  'has_phrases "$SKILL_DIR/SKILL.md" "Choose what the message carries" "by opening" "what to do first" "get stuck" "undecided"'
check "the SKILL.md writes every line as a sentence" \
  'has_phrases "$SKILL_DIR/SKILL.md" "including list items" "particles" "spaces, colons" "its own sentence" "no headings"'
check "the type guide leaves to the linked material what the reader can read there" \
  'has_phrases "$SKILL_DIR/references/types.md" "leave the part to that material"'
check "the SKILL.md shows how sentences relate with connecting words" \
  'has_phrases "$SKILL_DIR/SKILL.md" "connecting word" "a reason" "a contrast" "an order" "an addition" "references/connecting.md"'

# --- the eval suite

CASES="long-report-to-discord slack-format private-details-stay-out request-with-deadline handoff-message unrelated-request"
eval_suite() {
  local c
  [ "$(cd "$PLUGIN_DIR/evals" 2>/dev/null && find . -mindepth 1 -maxdepth 1 -type d ! -name results | sed 's|^\./||' | LC_ALL=C sort | tr '\n' ' ')" \
    = "$(printf '%s\n' $CASES | LC_ALL=C sort | tr '\n' ' ')" ] || return 1
  for c in $CASES; do
    [ -f "$PLUGIN_DIR/evals/$c/case.yaml" ] && [ -f "$PLUGIN_DIR/evals/$c/fixture.sh" ] || return 1
    grep -qx "name: $c" "$PLUGIN_DIR/evals/$c/case.yaml" || return 1
  done
}
check "the eval suite has the six cases" "eval_suite"

fixtures_build() {
  local c dir texts
  for c in $CASES; do
    dir="$T/fixture-$c"
    mkdir -p "$dir"
    (cd "$dir" && PYTHONDONTWRITEBYTECODE=1 bash "$PLUGIN_DIR/evals/$c/fixture.sh") >/dev/null 2>&1 || return 1
    texts="$(cd "$dir" && find . -type f -name '*.md' | wc -l | tr -d ' ')"
    [ "$texts" -ge 1 ] || return 1
    if [ "$c" = private-details-stay-out ]; then
      grep -rqE '/(Users|home)/[a-z]+/' "$dir" && grep -rqE '[a-z]+@[a-z]+\.[a-z]+' "$dir" || return 1
    else
      ! grep -rqE '/(Users|home)/[a-z]+/|[a-z]+@[a-z]+\.[a-z]+' "$dir" || return 1
    fi
    if [ "$c" = handoff-message ]; then
      # What the message should leave out (why the zip is split, what the labels mean) and keep (the two
      # undecided points, what pen can edit) are all in the source.
      grep -q '100MB' "$dir/handoff.md" && grep -q '〔例〕は' "$dir/handoff.md" && grep -q '30日間' "$dir/handoff.md" \
        && grep -q '文字だけ' "$dir/handoff.md" || return 1
    fi
  done
}
check "the eval fixtures build the texts their cases start from" "fixtures_build"

# The `connected` grader passes a message in which at least two sentences start with a conjunction and
# fails one with fewer. Its pattern uses only syntax that Python and JavaScript read the same way.
connected_grader() {
  "$PY" - "$PLUGIN_DIR/evals/handoff-message/case.yaml" "$PLUGIN_DIR/evals/long-report-to-discord/case.yaml" <<'PY'
import re, sys
two = "@ken 新しい画面を上げました。\nまず、2つのzipを同じフォルダに置いてから解凍してください。\nただし、penで直せるのは文字だけです。\n"
one = "@ken 新しい画面を上げました。\nまず、2つのzipを同じフォルダに置いてから解凍してください。\npenで直せるのは文字だけです。\n"
none = "@ken 新しい画面を上げました。\n2つのzipを同じフォルダに置いて解凍してください。\npenで直せるのは文字だけです。\n"
for path in sys.argv[1:]:
    try:
        text = open(path, encoding="utf-8").read()
    except OSError:
        sys.exit(1)
    block = re.search(r"- name: connected\n((?:    .*\n)+)", text)
    if not block or "type: regex" not in block.group(1) or "path: message.md" not in block.group(1):
        sys.exit(1)
    quoted = re.search(r"^    pattern: '((?:[^']|'')*)'$", block.group(1), re.M)
    if not quoted:
        sys.exit(1)
    pattern = re.compile(quoted.group(1).replace("''", "'"))
    if not pattern.search(two) or pattern.search(one) or pattern.search(none):
        sys.exit(1)
PY
}
check "the handoff and long-report cases grade that sentences are connected" "connected_grader"

printf '\n%d passed, %d failed, 0 skipped (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" = 0 ]
