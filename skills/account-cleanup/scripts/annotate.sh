#!/bin/bash
# AIが書いた説明のファイルを、候補に付けて候補表を作り直す。
# 説明のファイルはキーごとに次の4つを持つJSON。
#   description  何のサイトかの短い説明
#   category     種類 (メール、銀行、カード、行政、仕事、ドメイン、クラウド、パスワード管理、買い物、SNS、開発、その他 など)
#   suggestion   見立て。ok (消してよさそう) か ng (残した方がよさそう)
#   why          見立ての理由
# 前の回に消せなかった候補は、次の1つも持てる (候補表の先頭のタブに集まる)。
#   previous     {"round": 回の番号, "label": 短い札, "detail": 止まった理由と次にやること}
# 説明の無い候補はそのまま残す。
#
# 使い方: annotate.sh <説明のファイル> [matched.json]

. "$(dirname "$0")/common.sh"
need jq "jq を入れてください。"

desc=${1:-}
target=${2:-$MATCHED_FILE}
if [ -z "$desc" ] || [ ! -f "$desc" ]; then
  echo "使い方: annotate.sh <説明のファイル> [matched.json]" >&2
  exit 2
fi
if [ ! -f "$target" ]; then
  echo "account-cleanup: 突き合わせ済みの候補がありません: $target" >&2
  exit 2
fi

ensure_data_dir
# 説明は置き場の descriptions.json にも足しておき、候補を作り直した時にも付け直す
if [ "$desc" != "$DESCRIPTIONS_FILE" ]; then
  merged=$(mktemp "$DATA_DIR/descriptions.XXXXXX")
  if [ -f "$DESCRIPTIONS_FILE" ]; then
    jq -s '.[0] + .[1]' "$DESCRIPTIONS_FILE" "$desc" > "$merged"
  else
    jq . "$desc" > "$merged"
  fi
  mv "$merged" "$DESCRIPTIONS_FILE"
  chmod 600 "$DESCRIPTIONS_FILE"
fi

tmp=$(mktemp "$DATA_DIR/matched.XXXXXX")
jq -c --slurpfile d "$desc" '
  ($d[0] // {}) as $desc
  | map(. as $g
      | ($desc[$g.key] // null) as $x
      | if $x == null then $g
        else $g + {
          description: ($x.description // null),
          category: ($x.category // null),
          suggestion: (if ($x.suggestion // "") | IN("ok", "ng") then $x.suggestion else null end),
          why: ($x.why // null),
          previous: (if ($x.previous | type) == "object" and (($x.previous.label // "") | length) > 0
                     then $x.previous | {round: (.round // null), label, detail: (.detail // null)} else null end)
        } end)' "$target" > "$tmp"
mv "$tmp" "$target"
chmod 600 "$target"
count=$(jq --slurpfile d "$desc" '[.[] | select(.key as $k | $d[0] | has($k))] | length' "$target")
if [ "$target" = "$MATCHED_FILE" ]; then
  "$SCRIPT_DIR/build-sheet.sh" "$target" >/dev/null
fi
echo "説明を ${count} 件の候補に付けました。"
