#!/bin/bash
# 出所ごとの候補 (1行1件のJSON) を、登録できる単位のドメインごとに1つのグループへまとめる。
# accounts.example.com と www.example.com と example.com は example.com の1グループになる。
# URLの無い候補は名前ごとにまとめる。
#
# 使い方: merge.sh < candidates.jsonl > groups.json
# 出力: グループの配列 (key, names, urls, hosts, sources, updated)

. "$(dirname "$0")/common.sh"
need jq "jq を入れてください。"

jq -s -c "$JQ_REGDOMAIN"'
  map(. + {key: (if (.domain // "") != "" then (.domain | regdomain) else "name:" + ((.name // "") | ascii_downcase) end)})
  | group_by(.key)
  | map({
      key: .[0].key,
      names: (map(.name // "") | map(select(. != "")) | unique),
      urls: (map(.url // "") | map(select(. != "")) | unique),
      hosts: (map(.domain // "") | map(select(. != "")) | unique),
      sources: (map({source, id}) | unique),
      updated: (map(.updated // "") | max)
    })'
