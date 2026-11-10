#!/bin/bash
# 突き合わせ済みの候補に、使われていない見込みの理由を付ける。
# 付ける理由は3つで、候補の reasons に足す。
#   長く更新していない     最後に更新した日が ACCOUNT_CLEANUP_STALE_DAYS (既定 730) 日より前
#   サイトが見つからない   サイトの名前を引けない (curl の終了 6)。サービスが終わった見込み
#   開発用のアドレス       localhost、IPアドレス、.local などで、Webサービスのアカウントではない
# サイトに繋がったかは alive に入れる (true、false、判定できない時は null)。
# 時間切れなど名前を引けた上で繋がらなかった時は、見つからないと決めずに null のままにする。
# 開発用のアドレスとURLの無い候補には繋ぎに行かない。
#
# 使い方: triage.sh [--no-network] < matched.json > triaged.json

. "$(dirname "$0")/common.sh"
need jq "jq を入れてください。"

network=1
if [ "${1:-}" = "--no-network" ]; then
  network=0
fi

today=${ACCOUNT_CLEANUP_TODAY:-$(date +%Y-%m-%d)}
stale_days=${ACCOUNT_CLEANUP_STALE_DAYS:-730}

input=$(mktemp "${TMPDIR:-/tmp}/account-cleanup-triage.XXXXXX")
alive=$(mktemp "${TMPDIR:-/tmp}/account-cleanup-alive.XXXXXX")
trap 'rm -f "$input" "$alive"' EXIT
cat > "$input"

LOCAL_RE='^(localhost|.*\.localhost|.*\.local|.*\.internal|.*\.lan|.*\.home\.arpa|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|\[[0-9a-f:]+\])$'
# Chromium系ブラウザの拡張機能のID (a から p の小文字 32 文字)。多くは仮想通貨のウォレットの拡張機能
EXT_RE='^[a-p]{32}$'

# 繋ぎに行くキーごとに、名前を引けたかと繋がったかを `キー 状態` の形で書く。
# キーは保管庫の項目から来るので、ホスト名に使える文字だけのキーに絞り、命令の文字列へ埋め込まず引数で渡す。
if [ "$network" = 1 ] && command -v curl >/dev/null 2>&1; then
  jq -r '.[] | .key' "$input" \
    | grep -E '^[a-z0-9-]+(\.[a-z0-9-]+)+$' \
    | grep -Ev "$LOCAL_RE" \
    | xargs -P 16 -n 1 sh -c 'curl -s -o /dev/null -I --max-time 6 "https://$1/" >/dev/null 2>&1; c=$?; case $c in 0) echo "$1 true" ;; 6) echo "$1 false" ;; *) echo "$1 null" ;; esac' _ \
    > "$alive" || true
  # 並べて引くと名前を一時的に引けないことがあるので、見つからなかったキーだけ 1 件ずつ引き直す。
  # 引き直しても引けなかった時だけ見つからないと決め、繋がった時はあると記録する。
  retried=$(mktemp "${TMPDIR:-/tmp}/account-cleanup-alive2.XXXXXX")
  while read -r k state; do
    if [ "$state" = false ]; then
      # common.sh が set -e を立てているので、curl の失敗で script を終わらせず終了の値だけを取る
      c=0
      curl -s -o /dev/null -I --max-time 8 "https://$k/" >/dev/null 2>&1 || c=$?
      case $c in 0) echo "$k true" ;; 6) echo "$k false" ;; *) echo "$k null" ;; esac
    else
      echo "$k $state"
    fi
  done < "$alive" > "$retried"
  mv "$retried" "$alive"
fi

jq -c --arg today "$today" --argjson stale "$stale_days" --arg local_re "$LOCAL_RE" --arg ext_re "$EXT_RE" --rawfile alive "$alive" '
  ($alive | split("\n") | map(select(. != "") | split(" ") | {(.[0]): (.[1] | fromjson)}) | add // {}) as $seen
  | ($today | strptime("%Y-%m-%d") | mktime) as $now
  | map(
      . as $g
      | ($g.key | test($local_re)) as $is_local
      | ($g.key | test($ext_re)) as $is_ext
      | ((($g.key | startswith("name:")) or $is_local or $is_ext or ($g.key | contains("."))) | not) as $is_broken
      | (if $is_local or ($seen | has($g.key) | not) then null else $seen[$g.key] end) as $up
      | ((($g.updated // "") | length) == 10 and (($now - ($g.updated | strptime("%Y-%m-%d") | mktime)) / 86400) > $stale) as $old
      | $g + {
          alive: $up,
          reasons: (
            (if $is_ext then ["ブラウザの拡張機能 (Webサービスのアカウントではない)"] else [] end)
            + (if $is_broken then ["URLが壊れた項目 (サイトを特定できない)"] else [] end)
            + (if $is_local then ["開発用のアドレス (Webサービスのアカウントではない)"] else [] end)
            + (if $up == false then ["サイトが見つからない (サービス終了の見込み)"] else [] end)
            + (if $old then ["長く更新していない (最後は \($g.updated))"] else [] end)
          )
        })' "$input"
