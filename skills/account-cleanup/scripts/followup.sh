#!/bin/bash
# 削除の途中で消せなかった支払い先など、利用者が後で自分で片付ける物を記録する。
# 記録は置き場の followups.tsv (利用者だけが読める) に1行ずつ足し、片付け (cleanup.sh) でも消さない。
# 一覧の画面は利用者のブラウザで開いて見る。チャットにはサービスの名前の一覧を出さない。
#
# 使い方:
#   followup.sh add <キー> <内容>   1行足す (例 followup.sh add example.com "Visaのカードが支払い方法に残っていて消せない")
#   followup.sh page                一覧の画面 (followups.html) を作り、件数とpathを出す
#   followup.sh done <キー>         利用者が片付けた行を外す

. "$(dirname "$0")/common.sh"
need jq "jq を入れてください。"

FOLLOWUPS_PAGE="$DATA_DIR/followups.html"

# タブと改行は1行1件の形を崩すので空白にする
flat() { printf '%s' "$1" | tr '\t\n\r' '   '; }

case "${1:-}" in
  add)
    if [ $# -lt 3 ]; then
      echo "使い方: followup.sh add <キー> <内容>" >&2
      exit 2
    fi
    ensure_data_dir
    printf '%s\t%s\t%s\n' "$(date +%Y-%m-%d)" "$(flat "$2")" "$(flat "${*:3}")" >> "$FOLLOWUPS_FILE"
    chmod 600 "$FOLLOWUPS_FILE"
    echo "後で片付ける物に記録しました: $(flat "$2")"
    ;;
  done)
    if [ $# -lt 2 ] || [ ! -f "$FOLLOWUPS_FILE" ]; then
      echo "使い方: followup.sh done <キー>" >&2
      exit 2
    fi
    tmp=$(mktemp "$DATA_DIR/followups.XXXXXX")
    awk -F '\t' -v k="$2" '$2 != k' "$FOLLOWUPS_FILE" > "$tmp" || true
    mv "$tmp" "$FOLLOWUPS_FILE"
    chmod 600 "$FOLLOWUPS_FILE"
    echo "片付けた物を外しました: $2"
    ;;
  page)
    ensure_data_dir
    [ -f "$FOLLOWUPS_FILE" ] || : > "$FOLLOWUPS_FILE"
    count=$(grep -c . "$FOLLOWUPS_FILE" || true)
    rows=$(jq -R -r 'split("\t") | "<tr><td>\(.[0] // "" | @html)</td><td>\(.[1] // "" | @html)</td><td>\(.[2:] | join(" ") | @html)</td></tr>"' "$FOLLOWUPS_FILE")
    cat > "$FOLLOWUPS_PAGE" <<EOF
<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'">
<title>後で片付ける物</title>
<style>
:root { --bg: #f6f7f9; --panel: #ffffff; --text: #1d2330; --sub: #5b6475; --line: #dfe3ea; }
@media (prefers-color-scheme: dark) { :root { --bg: #12151b; --panel: #1b2029; --text: #e7eaf0; --sub: #a3abba; --line: #2c3340; } }
body { margin: 0; background: var(--bg); color: var(--text); font: 15px/1.7 -apple-system, BlinkMacSystemFont, "Hiragino Sans", "Noto Sans JP", "Segoe UI", sans-serif; }
main { max-width: 960px; margin: 0 auto; padding: 24px 16px; }
h1 { font-size: 22px; margin: 0 0 8px; }
p { color: var(--sub); margin: 0 0 16px; }
.wrap { overflow-x: auto; background: var(--panel); border: 1px solid var(--line); border-radius: 12px; }
table { width: 100%; border-collapse: collapse; }
th, td { text-align: left; padding: 10px 14px; border-bottom: 1px solid var(--line); vertical-align: top; }
th { color: var(--sub); font-weight: 600; white-space: nowrap; }
td:first-child { white-space: nowrap; }
</style>
</head>
<body>
<main>
<h1>後で片付ける物 (${count} 件)</h1>
<p>アカウントの削除の途中で、AIが消せなかった支払い先などです。サービスのサイトにログインして、支払い方法の画面から消してください。</p>
<div class="wrap"><table>
<thead><tr><th>記録した日</th><th>サービス</th><th>残っている物</th></tr></thead>
<tbody>
${rows}
</tbody>
</table></div>
</main>
</body>
</html>
EOF
    chmod 600 "$FOLLOWUPS_PAGE"
    echo "後で片付ける物 ${count} 件"
    echo "$FOLLOWUPS_PAGE"
    ;;
  *)
    echo "使い方: followup.sh add <キー> <内容> | page | done <キー>" >&2
    exit 2
    ;;
esac
