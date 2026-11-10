#!/bin/bash
# Chromium系ブラウザ (Chrome、Dia、Arc、Brave、Edge) に保存したパスワードの記録から、サイトのURLと日付だけを読む。
# 記録 (`Login Data`) は一時の置き場へ写してから読み、読み終えたら写しを消す。
# 選ぶ列は origin_url と日付の2つだけで、パスワードの列 (password_value) とユーザー名の列は選ばない。
# パスワードはブラウザが暗号化したまま記録に入っており、このscriptは鍵に触れない。
# ACCOUNT_CLEANUP_CHROME_DIR を決めた時は、その置き場だけを Chrome として読む。
#
# 使い方: inventory-chrome.sh
# 出力: 1行1件のJSON (source, id, name, url, domain, updated)。source はブラウザの名前、id はプロファイルの名前

. "$(dirname "$0")/common.sh"
need sqlite3 "sqlite3 を入れてください。"
need jq "jq を入れてください。"

# `ブラウザの名前<タブ>置き場` を1行ずつ出す
browser_dirs() {
  if [ -n "${ACCOUNT_CLEANUP_CHROME_DIR:-}" ]; then
    printf 'chrome\t%s\n' "$ACCOUNT_CLEANUP_CHROME_DIR"
    return
  fi
  local home=${ACCOUNT_CLEANUP_BROWSER_HOME:-$HOME}
  printf 'chrome\t%s\n' "$home/Library/Application Support/Google/Chrome" "$home/.config/google-chrome"
  printf 'dia\t%s\n' "$home/Library/Application Support/Dia/User Data"
  printf 'arc\t%s\n' "$home/Library/Application Support/Arc/User Data"
  printf 'brave\t%s\n' "$home/Library/Application Support/BraveSoftware/Brave-Browser" "$home/.config/BraveSoftware/Brave-Browser"
  printf 'edge\t%s\n' "$home/Library/Application Support/Microsoft Edge" "$home/.config/microsoft-edge"
  if [ -n "${LOCALAPPDATA:-}" ]; then
    printf 'chrome\t%s\n' "$LOCALAPPDATA/Google/Chrome/User Data"
  fi
}

work=$(mktemp -d "${TMPDIR:-/tmp}/account-cleanup-chrome.XXXXXX")
trap 'rm -rf "$work"' EXIT

found=0
while IFS=$'\t' read -r browser base; do
  [ -d "$base" ] || continue
  for db in "$base"/*/"Login Data" "$base"/*/"Login Data For Account"; do
    [ -f "$db" ] || continue
    found=1
    profile=$(basename "$(dirname "$db")")
    cp "$db" "$work/db"
    sqlite3 -json "$work/db" "SELECT origin_url, date_created, date_last_used FROM logins WHERE blacklisted_by_user = 0" \
      | jq -c --arg b "$browser" --arg p "$profile" "$JQ_HOST"'
        def chrome_day: if . == null or . == 0 then "" else ((. / 1000000) - 11644473600 | floor | todate | .[0:10]) end;
        .[]?
        | .origin_url as $u
        | {source: $b, id: $p, name: ($u | host), url: $u, domain: ($u | host),
           updated: (if (.date_last_used // 0) > 0 then (.date_last_used | chrome_day) else (.date_created | chrome_day) end)}'
    rm -f "$work/db" "$work/db-journal"
  done
done < <(browser_dirs)

if [ "$found" = 0 ]; then
  echo "account-cleanup: ブラウザの保存パスワードの記録が見つかりませんでした。" >&2
fi
