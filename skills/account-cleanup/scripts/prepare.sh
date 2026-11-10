#!/bin/bash
# 選んだ出所から候補を洗い出し、まとめて削除ページを付け、候補表を作る。
# 最後に件数の要約と候補表のpathを出す。候補の中身 (サービスの名前) は出さない。
#
# 使い方:
#   prepare.sh --sources 1password,bitwarden,chrome [--op-account <1Passwordのアカウント>] [--history]
#   prepare.sh --rebuild [--history]   (出所を読み直さず、手で足した候補を入れて作り直す)
#   --history を付けた時だけ、ブラウザの履歴から候補を最後に開いた日を読む (利用者が許した時だけ付ける)

. "$(dirname "$0")/common.sh"
need jq "jq を入れてください。"

sources=""
op_account=""
rebuild=0
history=0
while [ $# -gt 0 ]; do
  case "$1" in
    --sources) sources=${2:-}; shift 2 ;;
    --op-account) op_account=${2:-}; shift 2 ;;
    --rebuild) rebuild=1; shift ;;
    --history) history=1; shift ;;
    *) echo "account-cleanup: 知らない引数です: $1" >&2; exit 2 ;;
  esac
done

ensure_data_dir

if [ "$rebuild" = 0 ]; then
  if [ -z "$sources" ]; then
    echo "使い方: prepare.sh --sources 1password,bitwarden,chrome [--op-account <アカウント>]" >&2
    exit 2
  fi
  : > "$CANDIDATES_FILE"
  chmod 600 "$CANDIDATES_FILE"
  IFS=',' read -r -a list <<<"$sources"
  for s in "${list[@]}"; do
    case "$s" in
      1password)
        if [ -n "$op_account" ]; then
          "$SCRIPT_DIR/inventory-1password.sh" --account "$op_account" >> "$CANDIDATES_FILE" || echo "account-cleanup: 1Passwordを飛ばしました" >&2
        else
          "$SCRIPT_DIR/inventory-1password.sh" >> "$CANDIDATES_FILE" || echo "account-cleanup: 1Passwordを飛ばしました" >&2
        fi ;;
      bitwarden) "$SCRIPT_DIR/inventory-bitwarden.sh" >> "$CANDIDATES_FILE" || echo "account-cleanup: Bitwardenを飛ばしました" >&2 ;;
      chrome) "$SCRIPT_DIR/inventory-chrome.sh" >> "$CANDIDATES_FILE" || echo "account-cleanup: Chromeを飛ばしました" >&2 ;;
      *) echo "account-cleanup: 知らない出所です: $s (1password、bitwarden、chrome から選ぶ)" >&2; exit 2 ;;
    esac
  done
elif [ ! -f "$CANDIDATES_FILE" ]; then
  : > "$CANDIDATES_FILE"
  chmod 600 "$CANDIDATES_FILE"
fi

groups=$(mktemp "$DATA_DIR/groups.XXXXXX")
trap 'rm -f "$groups"' EXIT
if [ -f "$MANUAL_FILE" ]; then
  cat "$CANDIDATES_FILE" "$MANUAL_FILE"
else
  cat "$CANDIDATES_FILE"
fi | "$SCRIPT_DIR/merge.sh" > "$groups"

tmp=$(mktemp "$DATA_DIR/matched.XXXXXX")
if [ "$history" = 1 ]; then
  "$SCRIPT_DIR/match.sh" < "$groups" | "$SCRIPT_DIR/triage.sh" | "$SCRIPT_DIR/usage.sh" > "$tmp"
else
  "$SCRIPT_DIR/match.sh" < "$groups" | "$SCRIPT_DIR/triage.sh" > "$tmp"
fi
mv "$tmp" "$MATCHED_FILE"
chmod 600 "$MATCHED_FILE"
# 前にAIが書いた説明が在れば、作り直した候補にも付ける
if [ -f "$DESCRIPTIONS_FILE" ]; then
  "$SCRIPT_DIR/annotate.sh" "$DESCRIPTIONS_FILE" >/dev/null
fi
sheet=$("$SCRIPT_DIR/build-sheet.sh" "$MATCHED_FILE")

jq -r --arg sheet "$sheet" '
  "候補 \(length) 件 (同じサービスをまとめた後)",
  "長く更新していない \(map(select(.reasons | any(startswith("長く")))) | length) 件",
  "サイトが見つからない \(map(select(.alive == false)) | length) 件",
  "開発用のアドレス \(map(select(.reasons | any(startswith("開発用")))) | length) 件",
  "ブラウザの拡張機能 \(map(select(.reasons | any(startswith("ブラウザの拡張機能")))) | length) 件",
  "最近ブラウザで開いた \(map(select(.last_visit != null)) | length) 件 (履歴は \(.[0].history_since // "無し") 以降)",
  "削除ページが分かった \(map(select(.deletion != null)) | length) 件",
  "削除できないとされた \(map(select(.deletion.difficulty == "impossible")) | length) 件",
  "出所ごとの項目の数 " + ([.[].sources[].source] | group_by(.) | map("\(.[0]) \(length)") | join("、")),
  "候補表 \($sheet)"' "$MATCHED_FILE"
