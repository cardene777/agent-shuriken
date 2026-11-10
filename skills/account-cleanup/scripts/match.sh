#!/bin/bash
# グループごとに削除ページを付ける。
# 引く順は、追加の一覧 (利用者が検索して足した物) を先に、同梱の一覧 (JustDeleteMe) を後にする。
# それぞれの一覧で、ホストが一致する物を先に、登録できる単位のドメインが一致する物を後に探す。
# どちらにも無いグループには needs_search を付け、削除できないとされたサービスには消去の請求文を付ける。
#
# 使い方: match.sh < groups.json > matched.json

. "$(dirname "$0")/common.sh"
need jq "jq を入れてください。"

additions=$ADDITIONS_FILE
if [ ! -f "$additions" ]; then
  additions=$(mktemp "${TMPDIR:-/tmp}/account-cleanup-additions.XXXXXX")
  trap 'rm -f "$additions"' EXIT
  printf '[]\n' > "$additions"
fi

jq -c \
  --slurpfile sites "$SITES_FILE" \
  --slurpfile adds "$additions" \
  --rawfile tmpl "$SKILL_DIR/templates/erasure-request.md" \
  "$JQ_REGDOMAIN"'
  # 一覧を1回だけ、ドメインから引く索引と、登録できる単位のドメインから引く索引にする。
  # 同じドメインを持つ行が複数在る時は、一覧の先の行を採る。
  def index_of($list; $origin):
    [$list[] | . + {origin: $origin} | . as $s | ($s.domains // [])[] | {d: ., s: $s}]
    | {exact: (reduce .[] as $x ({}; .[$x.d] //= $x.s)),
       loose: (reduce .[] as $x ({}; .[$x.d | regdomain] //= $x.s))};
  def lookup($idx; $g): (first(([$g.key] + ($g.hosts // []))[] | $idx.exact[.] // empty) // $idx.loose[$g.key]);
  index_of($adds[0]; "addition") as $ai
  | index_of($sites[0]; "bundled") as $si
  | def found($g): lookup($ai; $g) // lookup($si; $g);
  map(. as $g
    | found($g) as $s
    | $g + {
        service: ($s.name // null),
        deletion: (if $s then {url: $s.url, difficulty: ($s.difficulty // "unknown"), notes: ($s.notes // null), email: ($s.email // null), email_subject: ($s.email_subject // null), email_body: ($s.email_body // null), origin: $s.origin} else null end),
        needs_search: ($s == null),
        erasure_request: (if $s and $s.difficulty == "impossible" then ($tmpl | gsub("[{][{]service[}][}]"; $s.name)) else null end)
      })'
