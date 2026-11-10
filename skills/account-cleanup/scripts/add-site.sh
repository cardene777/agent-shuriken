#!/bin/bash
# 検索で見つけた削除ページを、手元の追加の一覧へ足す。
# 次の突き合わせからは、同梱の一覧より先にこの一覧を引く。同じドメインの古い行は置き換える。
# 追加の一覧は片付けでは消さず、次に使う時も引き継ぐ。
#
# 使い方: add-site.sh <ドメイン> <削除ページのURL> [難しさ easy|medium|hard|impossible|ended] [手順の説明]
# サービスが終わっていた時は難しさを ended にし、URLには終了の告知のページを書く。

. "$(dirname "$0")/common.sh"
need jq "jq を入れてください。"

if [ $# -lt 2 ]; then
  echo "使い方: add-site.sh <ドメイン> <削除ページのURL> [難しさ] [手順の説明]" >&2
  exit 2
fi
domain=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
url=$2
difficulty=${3:-unknown}
notes=${4:-}

case "$url" in
  https://*|http://*) ;;
  *) echo "account-cleanup: 削除ページのURLは https:// か http:// で始めてください: $url" >&2; exit 2 ;;
esac
case "$difficulty" in
  easy|medium|hard|impossible|limited|unknown|ended) ;;
  *) echo "account-cleanup: 難しさは easy、medium、hard、impossible、limited、ended のどれかにしてください: $difficulty" >&2; exit 2 ;;
esac

ensure_data_dir
[ -f "$ADDITIONS_FILE" ] || printf '[]\n' > "$ADDITIONS_FILE"
tmp=$(mktemp "$DATA_DIR/additions.XXXXXX")
jq --arg d "$domain" --arg u "$url" --arg diff "$difficulty" --arg n "$notes" '
  map(select((.domains // []) | index($d) | not))
  + [{name: $d, url: $u, difficulty: $diff, notes: (if $n == "" then null else $n end), domains: [$d], added: (now | todate | .[0:10])}]' \
  "$ADDITIONS_FILE" > "$tmp"
mv "$tmp" "$ADDITIONS_FILE"
chmod 600 "$ADDITIONS_FILE"
echo "追加の一覧に足しました: $domain → $url"
