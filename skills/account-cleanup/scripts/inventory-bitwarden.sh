#!/bin/bash
# Bitwarden の保管庫から、ログインの項目の名前とURLと更新日だけを読む。
# `bw list items` はパスワードとユーザー名とメモも返すため、このscriptの中で欄を絞ってから出す。
# 絞る前の出力はファイルにも画面にも出さない。
# 先に端末で `export BW_SESSION="$(bw unlock --raw)"` を打ってから Claude Code を起動しておく。
#
# 使い方: inventory-bitwarden.sh
# 出力: 1行1件のJSON (source, id, name, url, domain, updated)

. "$(dirname "$0")/common.sh"
need bw "Bitwardenの命令 (bw) を入れてください。"
need jq "jq を入れてください。"

if ! bw list items | jq -c "$JQ_HOST"'
  .[]
  | select(.type == 1)
  | ((.login.uris // []) | .[0].uri // "") as $u
  | {source: "bitwarden", id: .id, name: (.name // ""), url: $u, domain: ($u | host), updated: ((.revisionDate // "")[0:10])}'; then
  echo "account-cleanup: Bitwardenの保管庫を読めませんでした。端末で export BW_SESSION=\"\$(bw unlock --raw)\" を打ってから Claude Code を起動し直してください。" >&2
  exit 4
fi
