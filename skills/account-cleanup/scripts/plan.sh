#!/bin/bash
# 候補表から貼った選択 (OKにしたアカウント) を受け取り、選んだアカウントだけについて手順を出す。
# 選択は1行目が `account-cleanup selection`、2行目からがグループのキー (ドメイン) の形。
# どのアカウントも、削除ページより先に、支払いの画面で有料の契約が残っていないかを確かめて解約する行と、
# 登録したカードと口座を消す行を出す。
# サイトが見つからないアカウントと、削除ページの難しさが ended (サービス終了) のアカウントは、削除も解約もできないので、1Passwordの片付けだけを出す。
#
# 使い方: plan.sh [matched.json] < 貼った選択

. "$(dirname "$0")/common.sh"
need jq "jq を入れてください。"

src=${1:-$MATCHED_FILE}
if [ ! -f "$src" ]; then
  echo "account-cleanup: 突き合わせ済みの候補がありません: $src" >&2
  exit 2
fi

selection=$(sed -e 's/^[[:space:]]*[-*][[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^account-cleanup selection$' | grep -v '^$' || true)
if [ -z "$selection" ]; then
  echo "account-cleanup: 選んだアカウントがありません。" >&2
  exit 2
fi

printf '%s\n' "$selection" | jq -R . | jq -s -r --slurpfile m "$src" '
  def difflabel: {easy: "かんたん", medium: "ふつう", hard: "難しい", impossible: "削除できない", limited: "一部だけ消せる", unknown: "未確認", ended: "サービス終了"}[.] // .;
  def source_name: {"1password": "1Password", bitwarden: "Bitwarden", chrome: "Chrome", dia: "Dia", arc: "Arc", brave: "Brave", edge: "Edge", manual: "手で足した"}[.] // .;
  def has_reason($w): (.reasons // []) | any(contains($w));
  def billing_rows:
    "| 解約 (削除より先に行う) | ログインした後、サービスの設定の「お支払い」「プラン」「サブスクリプション」の画面を開き、有料の契約が残っていれば解約する |\n"
    + "| 支払い先 | 削除より先に、「支払い方法」の画面で登録したカードと口座を消す。消せない時は followup.sh add で記録し、終わった時に利用者に見せる |\n"
    + "| App Storeで払っている時 | https://apps.apple.com/account/subscriptions で解約する (サービス側で消しても止まらない) |\n"
    + "| Google Playで払っている時 | https://play.google.com/store/account/subscriptions で解約する (サービス側で消しても止まらない) |\n"
    + "| PayPalで払っている時 | https://www.paypal.com/myaccount/autopay/ で自動支払いを止める |\n";
  map(split("\t") | {k: (.[0] | gsub("^\\s+|\\s+$"; "")), memo: ((.[1:] | join(" ")) | gsub("^\\s+|\\s+$"; ""))} | select(.k != "")) as $lines
  | ($lines | map(.k)) as $keys
  | ($lines | map(select(.memo != "") | {(.k): .memo}) | add // {}) as $memos
  | ($m[0] | map({(.key): .}) | add // {}) as $by
  | ($keys | map(select($by[.] == null))) as $missing
  | ($keys | map(select($by[.] != null)) | map($by[.])) as $picked
  | (if ($missing | length) > 0 then "候補に無いキー " + ($missing | join(" ")) + "\n\n" else "" end)
  + ($picked | to_entries | map(
      .value as $g
      | "## " + (.key + 1 | tostring) + ". " + ($g.service // $g.names[0] // $g.key) + " (" + $g.key + ")\n\n"
      + (if $g.description then $g.description + "\n\n" else "" end)
      + "| 項目 | 中身 |\n|---|---|\n"
      + (if $memos[$g.key] then "| あなたのメモ | " + ($memos[$g.key] | gsub("\\|"; "/")) + " |\n" else "" end)
      + (if ($g | has_reason("拡張機能")) then
           "| 削除 | ブラウザの拡張機能なので削除は不要。中のウォレットに資産が残っていないかを確かめてから1Passwordを片付ける |\n"
         elif ($g | has_reason("壊れた")) then
           "| 削除 | URLが壊れていてサイトを特定できないので削除は不要。項目の名前を見て要らなければ1Passwordを片付ける |\n"
         elif ($g | has_reason("開発用")) then
           "| 削除 | 開発用のアドレスでアカウントではないので削除は不要。1Passwordの片付けだけ行う |\n"
         elif $g.alive == false then
           "| 削除 | サイトが見つからないので削除は不要。1Passwordの片付けだけ行う |\n"
         elif $g.deletion.difficulty == "ended" then
           "| 削除 | サービスが終了したので削除は不要。1Passwordの片付けだけ行う |\n"
           + (if $g.deletion.notes then "| 終了の告知 | " + $g.deletion.url + " (" + ($g.deletion.notes | gsub("\n"; " ")) + ") |\n" else "| 終了の告知 | " + $g.deletion.url + " |\n" end)
         else
           billing_rows
           + (if $g.deletion then
                "| 削除ページ | " + $g.deletion.url + " |\n"
                + "| 手間 | " + ($g.deletion.difficulty | difflabel) + " |\n"
                + (if $g.deletion.notes then "| 手順 | " + ($g.deletion.notes | gsub("\n"; " ")) + " |\n" else "" end)
                + (if $g.deletion.email then "| 削除を頼む宛先 | " + $g.deletion.email + " |\n" else "" end)
              else
                "| 削除ページ | 未確認。サービスの名前で検索して見つけ、add-site.sh で足してから plan.sh を打ち直す |\n"
              end)
         end)
      + "| パスワード管理の項目 | " + ($g.sources | map((.source | source_name) + (if (.id // "") != "" then " " + .id else "" end)) | join("、")) + " |\n"
      + (if $g.erasure_request and $g.alive != false then "\n消去の請求文\n\n```\n" + $g.erasure_request + "```\n" else "" end)
    ) | join("\n"))'
