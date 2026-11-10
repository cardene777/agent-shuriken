#!/bin/bash
# 連携の画面やメールで見つけたサービスを、手で候補に足す。
# 足した候補は prepare.sh --rebuild で候補表に入る。
#
# 使い方: add-candidate.sh <サービスの名前> <URL>

. "$(dirname "$0")/common.sh"
need jq "jq を入れてください。"

if [ $# -lt 2 ]; then
  echo "使い方: add-candidate.sh <サービスの名前> <URL>" >&2
  exit 2
fi

ensure_data_dir
jq -nc --arg n "$1" --arg u "$2" "$JQ_HOST"'
  ($u | if test("^[a-z][a-z0-9+.-]*://"; "i") then . else "https://" + . end) as $url
  | {source: "manual", id: "", name: $n, url: $url, domain: ($url | host), updated: ""}' >> "$MANUAL_FILE"
chmod 600 "$MANUAL_FILE"
echo "候補に足しました: $1"
