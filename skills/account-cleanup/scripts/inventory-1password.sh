#!/bin/bash
# 1Password の保管庫から、ログインの項目の名前とURLと更新日だけを読む。
# 呼ぶのは `op item list` だけで、パスワードの欄を返す `op item get` と `op read` は呼ばない。
# `op` の出力はこのscriptの中で欄を絞ってから出し、絞る前の出力はファイルに書かない。
#
# 使い方: inventory-1password.sh [--account <1Passwordのアカウント>]
# 出力: 1行1件のJSON (source, id, name, url, domain, updated)

. "$(dirname "$0")/common.sh"
need op "1Passwordの命令 (op) を入れ、1Passwordのアプリの設定で命令との連携をオンにしてください。"
need jq "jq を入れてください。"

args=(item list --categories Login --format json)
if [ "${1:-}" = "--account" ] && [ -n "${2:-}" ]; then
  args+=(--account "$2")
fi

if ! op "${args[@]}" | jq -c "$JQ_HOST"'
  .[]
  | ((.urls // []) | (map(select(.primary == true)) + .) | .[0].href // "") as $u
  | {source: "1password", id: .id, name: (.title // ""), url: $u, domain: ($u | host), updated: ((.updated_at // "")[0:10])}'; then
  echo "account-cleanup: 1Passwordの保管庫を読めませんでした。1Passwordのアプリを開いてロックを解除してから、もう一度実行してください。" >&2
  exit 4
fi
