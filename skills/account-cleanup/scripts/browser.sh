#!/bin/bash
# アカウントの削除に使うブラウザを動かす。本体は同じ置き場の browser.mjs。
# ブラウザは利用者のMacに窓を開き、AIはこの命令で画面を読み、押し、入れる。
# ログインのIDとパスワードは login が1Passwordから入力欄へ直に入れ、AIにも出力にも渡さない。
#
# 使い方:
#   browser.sh start                         ブラウザの窓を開く
#   browser.sh open <URL>                    ページを開く
#   browser.sh look                          画面の文字と、押せる物と入力欄を番号付きで出す (入力欄の値は出さない)
#   browser.sh click <番号>                  押す
#   browser.sh clicktext <文字> [--after <文字>]
#                                            番号の付かない押せる物を、画面の文字で押す
#                                            --after <文字> で、その文字より後ろに在る物だけを押す (行ごとに同じボタンが並ぶ時)
#   browser.sh type <番号> <文字>            入力欄に文字を入れる (パスワードの欄は拒む)
#   browser.sh select <番号> <選ぶ値>        選ぶ欄で選ぶ
#   browser.sh press <キー>                  キーを押す (例 Enter)
#   browser.sh login <1Passwordの項目のID> [--account <アカウント>] [--user-ref <番号>] [--pass-ref <番号>] [--site <ドメイン>]
#                                            ページのドメインが項目のURLと一致した時だけ、IDとパスワードを入れる
#                                            --user-ref <番号> と --pass-ref <番号> で、入れる欄を名指せる
#                                            項目にURLが無い時だけ、調べた公式のドメインを --site で渡せる
#   browser.sh shot <保存するpath>           画面を画像に残す
#   browser.sh stop                          窓を閉じる
#
# 初めて使う時に、Playwright (ブラウザを動かす道具) を置き場の node/ へ入れる。

. "$(dirname "$0")/common.sh"
need node "Node.js を入れてください。"

PLAYWRIGHT_VERSION=1.65.0
export ACCOUNT_CLEANUP_NODE_DIR="${ACCOUNT_CLEANUP_NODE_DIR:-$DATA_DIR/node}"
export ACCOUNT_CLEANUP_DATA_DIR="$DATA_DIR"
ensure_data_dir

if [ ! -f "$ACCOUNT_CLEANUP_NODE_DIR/node_modules/playwright-core/package.json" ]; then
  mkdir -p "$ACCOUNT_CLEANUP_NODE_DIR"
  echo "account-cleanup: ブラウザを動かす道具を入れます (初回だけ)" >&2
  if command -v pnpm >/dev/null 2>&1; then
    (cd "$ACCOUNT_CLEANUP_NODE_DIR" && pnpm add "playwright-core@$PLAYWRIGHT_VERSION" >/dev/null) || exit 1
  else
    need npm "Node.js と一緒に入る npm が見つかりません。"
    npm install --prefix "$ACCOUNT_CLEANUP_NODE_DIR" --no-audit --no-fund "playwright-core@$PLAYWRIGHT_VERSION" >/dev/null || exit 1
  fi
fi

exec node "$SCRIPT_DIR/browser.mjs" "$@"
