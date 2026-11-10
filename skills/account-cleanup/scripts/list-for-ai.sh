#!/bin/bash
# AIが何のサイトかの説明と見立てを書くための、候補の短い一覧を出す。
# 出すのはキー、名前、ホスト、最後に更新した日、理由、同梱の一覧での名前だけで、URLの道筋とIDは出さない。
#
# 使い方: list-for-ai.sh [matched.json]
# 出力: 1行1件のJSON

. "$(dirname "$0")/common.sh"
need jq "jq を入れてください。"

src=${1:-$MATCHED_FILE}
jq -c '.[] | {key, names, hosts, updated, reasons: (.reasons // []), known_as: .service}' "$src"
