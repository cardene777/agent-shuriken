#!/usr/bin/env bash

# 長く使っていない物を一覧にし、選んだ物だけを片付ける。 本体は同じ dir の `tidy.py`。
#
# 使い方
#   tidy.sh list [--json]                 候補を測って一覧と HTML を書く
#   tidy.sh explain --notes <file> [--json] 番号ごとの名前と説明を残して HTML を作り直す
#   tidy.sh comment --paste <file> [--json] 貼り返された文のコメントを残して HTML を作り直す
#   tidy.sh apply --select <番号> [--json]  前の一覧の番号の物だけを消す (番号は `1,3,5-8` の形)
#
# 技の dir だけを写した PC でも動くよう、この dir の外の物を読まない。
# 一覧はホーム全体を測るため、`nice -n 10` で計算の優先度だけを下げて走らせる。
# 読み書きは絞らない。 `taskpolicy` で読み書きまで絞ると、並行の作業が多い間はほぼ進まなかった。

set -u

dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
python=$(command -v python3 2>/dev/null || printf '/usr/bin/python3')

if [ "${1:-}" = list ] && [ -z "${IKKAN_TIDY_LOW_PRIORITY:-}" ] && command -v nice >/dev/null 2>&1; then
  export IKKAN_TIDY_LOW_PRIORITY=1
  exec nice -n 10 "$python" -I "$dir/tidy.py" "$@"
fi
exec "$python" -I "$dir/tidy.py" "$@"
