#!/bin/bash
# 整理が終わった後に、候補と候補表を消す。
# 追加の一覧 (検索して足した削除ページ) は個人の情報を持たないので残し、次に使う時も引く。
# 後で片付ける物の記録 (followups.tsv) は、利用者が片付け終えるまで要るので残す。
#
# 使い方: cleanup.sh

. "$(dirname "$0")/common.sh"

removed=0
for f in "$CANDIDATES_FILE" "$MANUAL_FILE" "$MATCHED_FILE" "$SHEET_FILE" "$DESCRIPTIONS_FILE"; do
  if [ -e "$f" ]; then
    rm -f "$f"
    removed=$((removed + 1))
  fi
done
# 削除に使ったブラウザの記録は、ログインしたままのサイトの情報を持つので、窓を閉じてから消す
if [ -d "$BROWSER_PROFILE_DIR" ]; then
  if [ -f "$DATA_DIR/browser-state.json" ]; then
    "$SCRIPT_DIR/browser.sh" stop >/dev/null 2>&1 || true
  fi
  rm -rf "$BROWSER_PROFILE_DIR"
  removed=$((removed + 1))
fi
echo "候補と候補表のファイルを ${removed} 件消しました。"
if [ -s "$FOLLOWUPS_FILE" ]; then
  echo "後で片付ける物の記録は残しました: $FOLLOWUPS_FILE"
fi
