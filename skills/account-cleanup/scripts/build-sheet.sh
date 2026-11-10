#!/bin/bash
# 突き合わせ済みの候補から、消すアカウントを選ぶHTMLの表を作り、そのpathを出す。
# 表は外から何も読み込まない (CSPで止め、画像もscriptも外のファイルを持たない)。
# 候補の名前に `<` などが入っていても表の外へ出ないよう、埋め込む前に < の形へ置き換える。
#
# 使い方: build-sheet.sh [matched.json]

. "$(dirname "$0")/common.sh"
need jq "jq を入れてください。"

src=${1:-$MATCHED_FILE}
if [ ! -f "$src" ]; then
  echo "account-cleanup: 突き合わせ済みの候補がありません: $src" >&2
  exit 2
fi

ensure_data_dir
payload=$(mktemp "$DATA_DIR/sheet-data.XXXXXX")
trap 'rm -f "$payload"' EXIT
jq -c . "$src" | sed -e 's/</\\u003c/g' -e 's/>/\\u003e/g' -e 's/&/\\u0026/g' > "$payload"

tmp=$(mktemp "$DATA_DIR/sheet.XXXXXX")
awk -v datafile="$payload" '
  $0 == "__DATA__" { while ((getline line < datafile) > 0) print line; next }
  { print }' "$SKILL_DIR/templates/sheet.html" > "$tmp"
mv "$tmp" "$SHEET_FILE"
chmod 600 "$SHEET_FILE"
printf '%s\n' "$SHEET_FILE"
