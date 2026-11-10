#!/bin/bash
# 削除したアカウントの項目を、パスワード管理から戻せる形で消す。
# 1Password は `op item delete --archive` でアーカイブへ移し、Bitwarden は `bw delete item` でごみ箱へ移す。
# どちらも完全には消さない (完全に消すのは利用者がアプリで行う)。
# Chrome の項目は命令で消さず、利用者が Chrome のパスワード マネージャーの画面で消す。
#
# 使い方: remove-item.sh <1password|bitwarden|chrome> <項目のID> [--account <1Passwordのアカウント>]

. "$(dirname "$0")/common.sh"

if [ $# -lt 2 ]; then
  echo "使い方: remove-item.sh <1password|bitwarden|chrome> <項目のID> [--account <アカウント>]" >&2
  exit 2
fi
source_name=$1
id=$2

case "$source_name" in
  1password)
    need op "1Passwordの命令 (op) を入れてください。"
    args=(item delete "$id" --archive)
    signin=(signin)
    if [ "${3:-}" = "--account" ] && [ -n "${4:-}" ]; then
      args+=(--account "$4")
      signin+=(--account "$4")
    fi
    # アプリの承認が切れた後の最初の1回は、承認を待たずに失敗する。
    # signin でアプリの承認 (Touch ID) を待ってから、1回だけやり直す
    if ! op "${args[@]}"; then
      op "${signin[@]}" >/dev/null 2>&1
      op "${args[@]}" || exit 1
    fi
    echo "1Passwordの項目 $id をアーカイブへ移しました。"
    ;;
  bitwarden)
    need bw "Bitwardenの命令 (bw) を入れてください。"
    bw delete item "$id"
    echo "Bitwardenの項目 $id をごみ箱へ移しました。"
    ;;
  chrome)
    echo "Chromeの項目は命令では消しません。Chromeで chrome://password-manager/passwords を開き、そのサイトの項目を消してください。" >&2
    exit 2
    ;;
  *)
    echo "account-cleanup: 知らない出所です: $source_name" >&2
    exit 2
    ;;
esac
