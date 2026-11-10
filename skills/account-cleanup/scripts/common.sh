#!/bin/bash
# 各scriptが最初に読む共通の値と関数。
# 作るファイルは全部、利用者だけが読める権限 (ファイルは600、置き場は700) にする。

set -euo pipefail
umask 077

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SKILL_DIR=$(dirname "$SCRIPT_DIR")
DATA_DIR="${ACCOUNT_CLEANUP_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/account-cleanup}"
SITES_FILE="${ACCOUNT_CLEANUP_SITES:-$SKILL_DIR/data/sites.json}"
ADDITIONS_FILE="$DATA_DIR/additions.json"
CANDIDATES_FILE="$DATA_DIR/candidates.jsonl"
MANUAL_FILE="$DATA_DIR/manual.jsonl"
MATCHED_FILE="$DATA_DIR/matched.json"
DESCRIPTIONS_FILE="$DATA_DIR/descriptions.json"
SHEET_FILE="$DATA_DIR/sheet.html"
# 消せなかった支払い先など、利用者が後で片付ける物の記録。片付けでは消さない
FOLLOWUPS_FILE="$DATA_DIR/followups.tsv"
# 削除に使うブラウザの記録 (ログインしたままのサイトの情報を持つ)。片付けで消す
BROWSER_PROFILE_DIR="$DATA_DIR/browser"

ensure_data_dir() {
  mkdir -p "$DATA_DIR"
  chmod 700 "$DATA_DIR"
}

# 命令が無い時に、何を入れればよいかを添えて止まる
need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'account-cleanup: %s が見つかりません。%s\n' "$1" "$2" >&2
    exit 3
  fi
}

# URL からホストを取り出す (小文字にし、先頭の www. を外す)
JQ_HOST='def host:
  if . == null or . == "" then ""
  else ascii_downcase
    | sub("^[a-z][a-z0-9+.-]*://"; "")
    | sub("[/?#].*$"; "")
    | sub("^[^@]*@"; "")
    | sub(":[0-9]+$"; "")
    | sub("^www[.]"; "")
  end;'

# ホストから、登録できる単位のドメインを取り出す (accounts.example.co.jp なら example.co.jp)
JQ_REGDOMAIN='def regdomain:
  split(".") as $p
  | if ($p | length) < 3 then ($p | join("."))
    else ($p[-2:] | join(".")) as $two
      | if ($two | IN("co.jp","ne.jp","or.jp","ac.jp","go.jp","gr.jp","ed.jp","lg.jp","co.uk","org.uk","ac.uk","gov.uk","me.uk","com.au","net.au","org.au","co.nz","com.br","com.cn","com.tw","com.hk","co.kr","com.sg","co.in","com.mx","co.za","com.tr"))
        then ($p[-3:] | join(".")) else $two end
    end;'
