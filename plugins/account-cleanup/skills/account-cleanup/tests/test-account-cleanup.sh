#!/usr/bin/env bash
# Tests for the account-cleanup scripts in a throwaway HOME and data folder.
# Stand-ins for op, bw, and curl come first on PATH and record how they were called, and the browser
# databases are created here, so no real vault, browser profile, or network is touched.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
S="$HERE/../scripts"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
skip() { printf 'skip  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }
mode() { python3 -c 'import os, sys; print(format(os.stat(sys.argv[1]).st_mode & 0o777, "o"))' "$1"; }

export HOME="$T/home"
export TMPDIR="$T/tmp"
export ACCOUNT_CLEANUP_HOME="$T/data"
export ACCOUNT_CLEANUP_SITES="$T/sites.json"
export ACCOUNT_CLEANUP_TODAY=2026-11-13
export OP_LOG="$T/op.log" BW_LOG="$T/bw.log" CURL_LOG="$T/curl.log"
export OP_ITEMS="$T/op-items.json" BW_ITEMS="$T/bw-items.json"
unset ACCOUNT_CLEANUP_CHROME_DIR ACCOUNT_CLEANUP_BROWSER_HOME ACCOUNT_CLEANUP_STALE_DAYS LOCALAPPDATA XDG_DATA_HOME BW_SESSION
mkdir -p "$HOME" "$TMPDIR" "$T/bin"
export PATH="$T/bin:$PATH"
D="$ACCOUNT_CLEANUP_HOME"

# --- stand-ins
cat > "$T/bin/op" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >> "$OP_LOG"
[ "${OP_FAILS:-0}" = 1 ] && exit 1
case "$1" in
  item)
    case "$2" in
      list) cat "$OP_ITEMS" ;;
      delete)
        if [ -n "${OP_FAIL_ONCE:-}" ] && [ ! -e "$OP_FAIL_ONCE" ]; then : > "$OP_FAIL_ONCE"; exit 1; fi ;;
      *) exit 9 ;;
    esac ;;
  signin) ;;
  *) exit 9 ;;
esac
SH
cat > "$T/bin/bw" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >> "$BW_LOG"
case "$1 $2" in
  "list items") cat "$BW_ITEMS" ;;
  "delete item") ;;
  *) exit 9 ;;
esac
SH
cat > "$T/bin/curl" <<'SH'
#!/bin/sh
for a in "$@"; do url=$a; done
host=${url#https://}
host=${host%/}
printf '%s\n' "$host" >> "$CURL_LOG"
case " ${CURL_DEAD:-} " in *" $host "*) exit 6 ;; esac
case " ${CURL_SLOW:-} " in *" $host "*) exit 28 ;; esac
exit 0
SH
chmod +x "$T/bin/op" "$T/bin/bw" "$T/bin/curl"

# --- fixtures. Every secret-looking value has a word the checks look for
cat > "$OP_ITEMS" <<'JSON'
[{"id": "op-mail", "title": "Mail", "updated_at": "2019-03-04T05:06:07Z",
  "urls": [{"href": "https://login.mail.example.org/"}, {"primary": true, "href": "https://WWW.Mail.Example.org/sign-in?next=1"}],
  "additional_information": "opusername", "fields": [{"label": "password", "value": "oppassword"}], "notesPlain": "opnote"},
 {"id": "op-router", "title": "Router", "updated_at": "2025-01-01T00:00:00Z", "urls": [{"primary": true, "href": "http://192.168.1.1/"}]},
 {"id": "op-nas", "title": "NAS", "updated_at": "2025-01-01T00:00:00Z", "urls": [{"primary": true, "href": "http://10.0.1.1/"}]},
 {"id": "op-paper", "title": "Paper", "updated_at": "2025-06-01T00:00:00Z", "urls": [{"primary": true, "href": "https://paper.example.co.jp/"}]},
 {"id": "op-stuck", "title": "Stuck", "updated_at": "2025-06-01T00:00:00Z", "urls": [{"primary": true, "href": "https://stuck.example.net/"}]}]
JSON
cat > "$BW_ITEMS" <<'JSON'
[{"type": 1, "id": "bw-shop", "name": "Shop", "revisionDate": "2024-02-03T04:05:06.000Z", "notes": "bwnote",
  "login": {"username": "bwusername", "password": "bwpassword", "totp": "bwtotp", "uris": [{"uri": "https://accounts.shop.example.com/login"}]}},
 {"type": 2, "id": "bw-note", "name": "Secure note", "notes": "bwsecurenote"}]
JSON
cat > "$ACCOUNT_CLEANUP_SITES" <<'JSON'
[{"name": "Mail service", "url": "https://mail.example.org/delete", "difficulty": "easy", "domains": ["mail.example.org"]},
 {"name": "Stuck service", "url": "https://stuck.example.net/privacy", "difficulty": "impossible", "notes": "No delete button", "domains": ["stuck.example.net"]},
 {"name": "Shop", "url": "https://shop.example.com/close", "difficulty": "medium", "domains": ["shop.example.com"]}]
JSON

chrome_db() {
  python3 - "$1" <<'PY'
import os, sqlite3, sys
path = sys.argv[1]
os.makedirs(os.path.dirname(path), exist_ok=True)
def chrome_time(unix):
    return (unix + 11644473600) * 1000000
db = sqlite3.connect(path)
db.execute("CREATE TABLE logins (origin_url TEXT, username_value TEXT, password_value BLOB, date_created INTEGER, date_last_used INTEGER, blacklisted_by_user INTEGER)")
db.executemany("INSERT INTO logins VALUES (?, ?, ?, ?, ?, ?)", [
    ("https://forum.example.com/login", "chromeusername", b"chromepassword", chrome_time(1546300800), chrome_time(1777593600), 0),
    ("https://never.example.com/", "", b"", chrome_time(1546300800), 0, 1),
    ("http://localhost:3000/", "chromeusername", b"chromepassword", chrome_time(1767225600), 0, 0),
])
db.commit()
PY
}

history_db() {
  python3 - "$1" <<'PY'
import os, sqlite3, sys
path = sys.argv[1]
os.makedirs(os.path.dirname(path), exist_ok=True)
def chrome_time(unix):
    return (unix + 11644473600) * 1000000
db = sqlite3.connect(path)
db.execute("CREATE TABLE urls (url TEXT, last_visit_time INTEGER)")
db.executemany("INSERT INTO urls VALUES (?, ?)", [
    ("https://forum.example.com/thread/1", chrome_time(1717200000)),
    ("https://www.forum.example.com/", chrome_time(1718000000)),
    ("https://private-clinic.example.net/results", chrome_time(1719000000)),
    ("https://news.example.org/", chrome_time(1704067200)),
])
db.commit()
PY
}

# --- inventory-1password.sh
out="$("$S/inventory-1password.sh")"; rc=$?
check "1Password: exits 0 with one line per Login item" '[ "$rc" = 0 ] && [ "$(printf "%s\n" "$out" | grep -c .)" = 5 ]'
check "1Password: each line has only source, id, name, url, domain, and updated" \
  '[ "$(printf "%s\n" "$out" | jq -c "keys" | sort -u)" = "[\"domain\",\"id\",\"name\",\"source\",\"updated\",\"url\"]" ]'
check "1Password: no username, password, or note reaches the output" '! printf "%s\n" "$out" | grep -qE "opusername|oppassword|opnote"'
first="$(printf "%s\n" "$out" | head -1)"
check "1Password: the primary URL is used, and the domain is lowercase without www." \
  '[ "$(printf "%s" "$first" | jq -r "[.url, .domain, .updated] | join(\" \")")" = "https://WWW.Mail.Example.org/sign-in?next=1 mail.example.org 2019-03-04" ]'
check "1Password: op is called only with item list" '[ "$(sort -u "$OP_LOG")" = "item list --categories Login --format json" ]'
: > "$OP_LOG"
"$S/inventory-1password.sh" --account team >/dev/null
check "1Password: --account is passed on" '[ "$(cat "$OP_LOG")" = "item list --categories Login --format json --account team" ]'
OP_FAILS=1 "$S/inventory-1password.sh" >/dev/null 2>"$T/err"; rc=$?
check "1Password: a locked vault exits 4 with a hint" '[ "$rc" = 4 ] && grep -q "Open the 1Password app" "$T/err"'

# --- inventory-bitwarden.sh
out="$("$S/inventory-bitwarden.sh")"; rc=$?
check "Bitwarden: only Login items are read" '[ "$rc" = 0 ] && [ "$(printf "%s\n" "$out" | grep -c .)" = 1 ] && ! printf "%s" "$out" | grep -q "Secure note"'
check "Bitwarden: no username, password, one-time code, or note reaches the output" '! printf "%s\n" "$out" | grep -qE "bwusername|bwpassword|bwtotp|bwnote|bwsecurenote"'
check "Bitwarden: the line has the URL, domain, and date" \
  '[ "$(printf "%s" "$out" | jq -r "[.source, .id, .domain, .updated] | join(\" \")")" = "bitwarden bw-shop accounts.shop.example.com 2024-02-03" ]'
check "Bitwarden: bw is called only with list items" '[ "$(sort -u "$BW_LOG")" = "list items" ]'

# --- inventory-chrome.sh
chrome_db "$HOME/Library/Application Support/Google/Chrome/Default/Login Data"
out="$("$S/inventory-chrome.sh")"; rc=$?
check "Chrome: exits 0 and skips sites the user never saves" '[ "$rc" = 0 ] && [ "$(printf "%s\n" "$out" | grep -c .)" = 2 ] && ! printf "%s" "$out" | grep -q never.example.com'
check "Chrome: no username or password reaches the output" '! printf "%s\n" "$out" | grep -qE "chromeusername|chromepassword"'
check "Chrome: the profile is the id and the last use is the date" \
  '[ "$(printf "%s\n" "$out" | head -1 | jq -r "[.source, .id, .domain, .updated] | join(\" \")")" = "chrome Default forum.example.com 2026-05-01" ]'
check "Chrome: the copy of the database is removed" '[ -z "$(ls -A "$TMPDIR")" ]'
mkdir -p "$T/other-chrome/Profile 2"
chrome_db "$T/other-chrome/Profile 2/Login Data For Account"
out="$(ACCOUNT_CLEANUP_CHROME_DIR="$T/other-chrome" "$S/inventory-chrome.sh")"
check "Chrome: ACCOUNT_CLEANUP_CHROME_DIR reads only that folder" '[ "$(printf "%s\n" "$out" | jq -r .id | sort -u)" = "Profile 2" ]'

# --- merge.sh and regdomain
item() { printf '{"source":"1password","id":"%s","name":"%s","url":"http://%s/","domain":"%s","updated":"2025-01-01"}\n' "$1" "$2" "$3" "$3"; }
{
  item a Accounts accounts.example.com
  item b Example example.com
  item c "Example JP" accounts.example.co.jp
  item d Router 192.168.1.1
  item e NAS 10.0.1.1
  item f "NAS office" nas.office.lan
  item g "Printer office" printer.office.lan
  item h "Mac mini" mini.local
  item i "Local dev" localhost
  item j "IPv6 dev" "[::1]"
  printf '{"source":"bitwarden","id":"k","name":"No URL","url":"","domain":"","updated":""}\n'
} > "$T/hosts.jsonl"
groups="$("$S/merge.sh" < "$T/hosts.jsonl")"
keys="$(printf '%s' "$groups" | jq -r '.[].key' | LC_ALL=C sort | tr '\n' ' ')"
check "merge: one candidate per registrable domain, and each local host and IP address on its own" \
  '[ "$keys" = "10.0.1.1 192.168.1.1 [::1] example.co.jp example.com localhost mini.local name:no url nas.office.lan printer.office.lan " ]'
check "merge: the hosts of one service are merged with both names" \
  '[ "$(printf "%s" "$groups" | jq -r ".[] | select(.key == \"example.com\") | .names | join(\",\")")" = "Accounts,Example" ]'

if command -v node >/dev/null 2>&1; then
  # regdomain_js <file of hosts>: the regdomain of browser.mjs applied to each line, without running the rest of the file
  regdomain_js() {
    node -e '
      const fs = require("fs");
      const src = fs.readFileSync(process.argv[1], "utf8");
      const from = src.indexOf("const LOCAL_NAME"), to = src.indexOf("function parseUrl");
      if (from < 0 || to < from) { console.log("regdomain not found in browser.mjs"); process.exit(0); }
      const regdomain = new Function(src.slice(from, to) + "; return regdomain;")();
      for (const h of fs.readFileSync(process.argv[2], "utf8").split("\n").filter(Boolean)) console.log(regdomain(h));
    ' "$S/browser.mjs" "$1"
  }
  printf '%s\n' accounts.example.com example.com accounts.example.co.jp shop.example.co.uk 192.168.1.1 10.0.1.1 \
    nas.office.lan printer.office.lan mini.local localhost app.localhost db.internal printer.home.arpa '[::1]' > "$T/regdomain-hosts.txt"
  js="$(regdomain_js "$T/regdomain-hosts.txt")"
  jqr="$(bash -c '. "$1/common.sh"; jq -R -r "$JQ_REGDOMAIN regdomain" "$2"' _ "$S" "$T/regdomain-hosts.txt")"
  check "browser.mjs regdomain gives the same result as common.sh" '[ "$(printf "%s\n" "$js" | grep -c .)" = 14 ] && [ "$js" = "$jqr" ]'
  printf 'user.github.io\n' > "$T/hosting.txt"
  check "browser.mjs keeps a hosting subdomain such as user.github.io whole" '[ "$(regdomain_js "$T/hosting.txt")" = user.github.io ]'
else
  skip "browser.mjs regdomain (node is not installed)"
fi

# --- triage.sh
{
  cat "$T/hosts.jsonl"
  printf '{"source":"chrome","id":"Default","name":"Wallet","url":"chrome-extension://abcdefghijklmnopabcdefghijklmnop/","domain":"abcdefghijklmnopabcdefghijklmnop","updated":"2025-01-01"}\n'
  printf '{"source":"1password","id":"m","name":"Broken","url":"notadomain","domain":"notadomain","updated":"2025-01-01"}\n'
  printf '{"source":"1password","id":"n","name":"Old","url":"https://oldsite.example/","domain":"oldsite.example","updated":"2019-01-01"}\n'
  printf '{"source":"1password","id":"o","name":"Dead","url":"https://deadsite.example/","domain":"deadsite.example","updated":"2025-01-01"}\n'
  printf '{"source":"1password","id":"p","name":"Slow","url":"https://slowsite.example/","domain":"slowsite.example","updated":"2025-01-01"}\n'
} | "$S/merge.sh" > "$T/groups.json"
reasons() { jq -r --arg k "$2" '.[] | select(.key == $k) | "\(.alive) \(.reasons | join(","))"' "$1"; }

"$S/triage.sh" --no-network < "$T/groups.json" > "$T/quiet.json"
check "triage --no-network contacts nothing" '[ ! -e "$CURL_LOG" ]'
check "triage: an IP address is a development address" '[ "$(reasons "$T/quiet.json" 192.168.1.1)" = "null dev-address" ]'
check "triage: a .lan name is a development address" '[ "$(reasons "$T/quiet.json" nas.office.lan)" = "null dev-address" ]'
check "triage: an IPv6 address is a development address" '[ "$(reasons "$T/quiet.json" "[::1]")" = "null dev-address" ]'
check "triage: a Chromium extension ID is a browser extension" '[ "$(reasons "$T/quiet.json" abcdefghijklmnopabcdefghijklmnop)" = "null browser-extension" ]'
check "triage: a key without a dot is a broken URL" '[ "$(reasons "$T/quiet.json" notadomain)" = "null broken-url" ]'
check "triage: an item last updated over 730 days ago is stale" '[ "$(reasons "$T/quiet.json" oldsite.example)" = "null stale" ]'
check "triage: a recent item has no reason" '[ "$(reasons "$T/quiet.json" example.com)" = "null " ]'
ACCOUNT_CLEANUP_STALE_DAYS=10000 "$S/triage.sh" --no-network < "$T/groups.json" > "$T/lenient.json"
check "triage: ACCOUNT_CLEANUP_STALE_DAYS changes the limit" '[ "$(reasons "$T/lenient.json" oldsite.example)" = "null " ]'

CURL_DEAD="deadsite.example" CURL_SLOW="slowsite.example" "$S/triage.sh" < "$T/groups.json" > "$T/net.json"
check "triage: a name that does not resolve twice is site-not-found" '[ "$(reasons "$T/net.json" deadsite.example)" = "false site-not-found" ]'
check "triage: a not-found name is tried once more on its own" '[ "$(grep -cx deadsite.example "$CURL_LOG")" = 2 ]'
check "triage: a timeout leaves alive unknown without a reason" '[ "$(reasons "$T/net.json" slowsite.example)" = "null " ]'
check "triage: a site that answers is alive" '[ "$(reasons "$T/net.json" example.com)" = "true " ]'
check "triage: development addresses, extensions, broken URLs, and names are never contacted" \
  '! grep -qE "^(192\.168\.1\.1|10\.0\.1\.1|nas\.office\.lan|printer\.office\.lan|mini\.local|localhost|\[::1\]|abcdefghijklmnopabcdefghijklmnop|notadomain|name:.*)$" "$CURL_LOG"'
check "triage: no URL like https://1.1/ is contacted" '! grep -qx "1.1" "$CURL_LOG" && ! grep -qx "0.1" "$CURL_LOG"'
rm -f "$CURL_LOG"

# --- usage.sh
history_db "$HOME/Library/Application Support/Google/Chrome/Default/History"
printf '[{"key":"forum.example.com"},{"key":"example.co.jp"}]' | "$S/usage.sh" > "$T/usage.json"; rc=$?
check "usage: the last visit of a candidate is attached" \
  '[ "$rc" = 0 ] && [ "$(jq -r ".[] | select(.key == \"forum.example.com\") | .last_visit" "$T/usage.json")" = 2024-06-10 ]'
check "usage: a candidate that was not visited has no date" '[ "$(jq -r ".[] | select(.key == \"example.co.jp\") | .last_visit" "$T/usage.json")" = null ]'
check "usage: history_since is the oldest date in the history" '[ "$(jq -r ".[0].history_since" "$T/usage.json")" = 2024-01-01 ]'
check "usage: domains that are not candidates never reach the output" '! grep -qE "private-clinic|news\.example" "$T/usage.json"'
check "usage: the copy of the history is removed" '[ -z "$(ls -A "$TMPDIR")" ]'

# --- prepare.sh
"$S/prepare.sh" >/dev/null 2>&1; rc=$?
check "prepare without --sources or --rebuild exits 2" '[ "$rc" = 2 ] && [ ! -e "$D" ]'
"$S/prepare.sh" --rebuild --region mars >/dev/null 2>&1; rc=$?
check "prepare with an unknown region exits 2" '[ "$rc" = 2 ] && [ ! -e "$D" ]'
"$S/prepare.sh" --sources 1password,lastpass >/dev/null 2>"$T/err"; rc=$?
check "prepare with an unknown source exits 2" '[ "$rc" = 2 ] && grep -q "unknown source: lastpass" "$T/err"'

: > "$OP_LOG"
out="$(CURL_DEAD="example.co.jp" "$S/prepare.sh" --sources 1password,bitwarden,chrome --region japan)"; rc=$?
check "prepare exits 0 and prints the summary" '[ "$rc" = 0 ] && printf "%s\n" "$out" | grep -qx "Candidates: 7 (after merging the same service)"'
check "prepare counts the reasons" \
  'printf "%s\n" "$out" | grep -qx "Development addresses: 3" && printf "%s\n" "$out" | grep -qx "Site not found: 1" && printf "%s\n" "$out" | grep -qx "Not updated in a long time: 1"'
check "prepare counts the items per source" 'printf "%s\n" "$out" | grep -qx "Items per source: 1password 5, bitwarden 1, chrome 2"'
check "prepare saves the region" '[ "$(cat "$D/region")" = japan ] && printf "%s\n" "$out" | grep -qx "Region for erasure requests: japan"'
check "prepare prints no item names or hosts" '! printf "%s\n" "$out" | grep -v "^Candidate sheet: " | grep -qiE "mail|router|nas|paper|stuck|shop|forum|192\.168"'
check "prepare reads 1Password only with item list" '[ "$(sort -u "$OP_LOG")" = "item list --categories Login --format json" ]'
check "prepare attaches the deletion page from the list" \
  '[ "$(jq -r ".[] | select(.key == \"example.org\") | .deletion.url" "$D/matched.json")" = "https://mail.example.org/delete" ]'
check "prepare marks a candidate missing from the list for a search" \
  '[ "$(jq -r ".[] | select(.key == \"example.co.jp\") | .needs_search" "$D/matched.json")" = true ]'
OP_FAILS=1 "$S/prepare.sh" --sources 1password,bitwarden >/dev/null 2>"$T/err"; rc=$?
check "prepare goes on without a locked 1Password" '[ "$rc" = 0 ] && grep -q "skipped 1Password" "$T/err" && [ "$(jq length "$D/matched.json")" = 1 ]'
CURL_DEAD="example.co.jp" "$S/prepare.sh" --sources 1password,bitwarden,chrome >/dev/null

# --- add-site.sh and match.sh
"$S/add-site.sh" example.co.jp ftp://paper.example.co.jp/ >/dev/null 2>&1; rc=$?
check "add-site refuses a URL that is not http or https" '[ "$rc" = 2 ] && [ ! -e "$D/additions.json" ]'
"$S/add-site.sh" example.co.jp https://paper.example.co.jp/bye trivial >/dev/null 2>&1; rc=$?
check "add-site refuses an unknown difficulty" '[ "$rc" = 2 ]'
"$S/add-site.sh" Example.co.jp https://paper.example.co.jp/old hard >/dev/null
"$S/add-site.sh" example.co.jp https://paper.example.co.jp/bye easy "Settings, then Close account" >/dev/null
check "add-site replaces the older row for the same domain" \
  '[ "$(jq -r "map(.url) | join(\" \")" "$D/additions.json")" = "https://paper.example.co.jp/bye" ]'
"$S/add-site.sh" mail.example.org https://mail.example.org/own-page hard >/dev/null
"$S/match.sh" < "$D/matched.json" > "$T/rematched.json"
check "match uses a page added with add-site" \
  '[ "$(jq -r ".[] | select(.key == \"example.co.jp\") | [.deletion.url, .deletion.origin, .needs_search] | join(\" \")" "$T/rematched.json")" = "https://paper.example.co.jp/bye addition false" ]'
check "match prefers the additions list to the bundled list" \
  '[ "$(jq -r ".[] | select(.key == \"example.org\") | .deletion.url" "$T/rematched.json")" = "https://mail.example.org/own-page" ]'
"$S/add-site.sh" mail.example.org https://mail.example.org/delete easy >/dev/null

# --- add-candidate.sh, build-sheet.sh, and list-for-ai.sh
"$S/add-candidate.sh" '</script><img src=x onerror=alert(1)>' 'www.Odd.example.com/path' >/dev/null
check "add-candidate adds https:// and takes the host" \
  '[ "$(jq -r "[.url, .domain] | join(\" \")" "$D/manual.jsonl")" = "https://www.Odd.example.com/path odd.example.com" ]'
"$S/prepare.sh" --rebuild >/dev/null
sheet="$D/sheet.html"
check "the sheet keeps exactly the template's two closing script tags" '[ "$(grep -o "</script>" "$sheet" | wc -l | tr -d " ")" = 2 ]'
check "a candidate name with </script> is escaped in the sheet" 'grep -qF "\u003c/script\u003e\u003cimg src=x onerror=alert(1)\u003e" "$sheet"'
check "the sheet loads nothing from the network" '! grep -qiE "<script[^>]+src=|<link[^>]+href=\"https?:" "$sheet"'
list="$("$S/list-for-ai.sh")"
check "list-for-ai prints only the key, names, hosts, date, reasons, and listed name" \
  '[ "$(printf "%s\n" "$list" | jq -c "keys" | sort -u)" = "[\"hosts\",\"key\",\"known_as\",\"names\",\"reasons\",\"updated\"]" ]'
check "list-for-ai prints no URL paths or item IDs" '! printf "%s\n" "$list" | grep -qE "sign-in|/login|op-mail|bw-shop"'

# --- annotate.sh
cat > "$T/desc.json" <<'JSON'
{"example.org": {"description": "A mail service", "category": "Email", "suggestion": "ng", "why": "Other accounts reset through it"},
 "example.co.jp": {"description": "A paper shop", "category": "stationery", "suggestion": "maybe", "why": "Unclear",
                   "previous": {"round": 1, "label": "Needs a phone call", "detail": "Call support"}}}
JSON
out="$("$S/annotate.sh" "$T/desc.json" 2>"$T/err")"; rc=$?
check "annotate attaches descriptions and warns about an unknown category" \
  '[ "$rc" = 0 ] && [ "$out" = "Attached descriptions to 2 candidate(s)." ] && grep -q "stored 1 unknown category value(s) as other" "$T/err"'
check "annotate lowercases a known category and stores an unknown one as other" \
  '[ "$(jq -r "[.[] | select(.key == \"example.org\" or .key == \"example.co.jp\") | .category] | sort | join(\" \")" "$D/matched.json")" = "email other" ]'
check "annotate keeps only ok or ng as a suggestion" \
  '[ "$(jq -r ".[] | select(.key == \"example.co.jp\") | [.suggestion, .previous.label] | map(tostring) | join(\" \")" "$D/matched.json")" = "null Needs a phone call" ]'
"$S/prepare.sh" --rebuild >/dev/null
check "a rebuild keeps the descriptions" '[ "$(jq -r ".[] | select(.key == \"example.org\") | .description" "$D/matched.json")" = "A mail service" ]'

# --- plan.sh
printf 'account-cleanup selection\nexample.org\tkeep the | photos first\n- 192.168.1.1\nexample.net\nmissing.example\n\n' > "$T/selection.txt"
"$S/plan.sh" < "$T/selection.txt" > "$T/plan.md"; rc=$?
check "plan exits 0 and names keys that are not candidates" '[ "$rc" = 0 ] && grep -qx "Keys not in the candidates: missing.example" "$T/plan.md"'
check "plan prints a section for each selected candidate only" \
  '[ "$(grep -c "^## " "$T/plan.md")" = 3 ] && ! grep -qE "10\.0\.1\.1|shop\.example|forum\.example" "$T/plan.md"'
check "plan prints the memo with its bar replaced" 'grep -qxF "| Your memo | keep the / photos first |" "$T/plan.md"'
check "plan prints the deletion page and the billing rows" \
  'grep -qxF "| Deletion page | https://mail.example.org/delete |" "$T/plan.md" && [ "$(grep -c "^| Cancel (before deleting) |" "$T/plan.md")" = 2 ]'
check "plan prints only the password manager cleanup for a development address" \
  'grep -qF "Not needed: a development address" "$T/plan.md" && grep -qxF "| Password manager items | 1Password op-router |" "$T/plan.md"'
check "plan prints the erasure request for the saved region with the service name" \
  'grep -qxF "Erasure request (Japan APPI Article 35)" "$T/plan.md" && grep -qF "Dear Stuck service team," "$T/plan.md" && ! grep -qF "{{service}}" "$T/plan.md"'
printf 'account-cleanup selection\n\n' | "$S/plan.sh" >/dev/null 2>&1; rc=$?
check "plan with nothing selected exits 2" '[ "$rc" = 2 ]'
rm "$D/region"
printf 'example.net\n' | "$S/plan.sh" > "$T/plan2.md"
check "plan without a saved region tells the agent to ask" 'grep -qF "No region was saved." "$T/plan2.md" && grep -qxF "Erasure request (GDPR-style text)" "$T/plan2.md"'

# --- remove-item.sh
: > "$OP_LOG"
: > "$BW_LOG"
out="$("$S/remove-item.sh" 1password op-mail)"; rc=$?
check "remove-item archives a 1Password item" '[ "$rc" = 0 ] && [ "$(cat "$OP_LOG")" = "item delete op-mail --archive" ] && [ "$out" = "Moved 1Password item op-mail to the archive." ]'
: > "$OP_LOG"
OP_FAIL_ONCE="$T/op-failed" "$S/remove-item.sh" 1password op-nas --account team >/dev/null; rc=$?
check "remove-item signs in and retries once when the first call fails" \
  '[ "$rc" = 0 ] && [ "$(tr "\n" "|" < "$OP_LOG")" = "item delete op-nas --archive --account team|signin --account team|item delete op-nas --archive --account team|" ]'
"$S/remove-item.sh" bitwarden bw-shop >/dev/null; rc=$?
check "remove-item moves a Bitwarden item to the trash" '[ "$rc" = 0 ] && [ "$(cat "$BW_LOG")" = "delete item bw-shop" ]'
"$S/remove-item.sh" chrome Default >/dev/null 2>"$T/err"; rc=$?
check "remove-item leaves Chrome items to the user" '[ "$rc" = 2 ] && grep -q "chrome://password-manager" "$T/err"'
"$S/remove-item.sh" lastpass x >/dev/null 2>&1; rc=$?
check "remove-item refuses an unknown source" '[ "$rc" = 2 ]'
check "every 1Password delete is an archive" '! grep "^item delete" "$OP_LOG" | grep -qv -- "--archive"'

# --- followup.sh
"$S/followup.sh" add example.org "$(printf 'A card\tis <b>still</b> saved')" >/dev/null
"$S/followup.sh" add example.co.jp "Ask support to close it" >/dev/null
check "followup keeps one line per record with tabs turned into spaces" \
  '[ "$(grep -c . "$D/followups.tsv")" = 2 ] && [ "$(head -1 "$D/followups.tsv" | cut -f3)" = "A card is <b>still</b> saved" ]'
out="$("$S/followup.sh" page)"
check "followup page counts the records and escapes HTML" \
  'printf "%s\n" "$out" | grep -qx "Things to clean up later: 2" && grep -qF "A card is &lt;b&gt;still&lt;/b&gt; saved" "$D/followups.html"'
"$S/followup.sh" done example.co.jp >/dev/null
check "followup done removes that record" '[ "$(cut -f2 "$D/followups.tsv")" = example.org ]'

# --- permissions and cleanup.sh
check "the data folder is readable only by the user" '[ "$(mode "$D")" = 700 ]'
loose="$(find "$D" -type f ! -perm 600)"
check "every file in the data folder is readable only by the user" '[ -z "$loose" ]'
check "no temporary file is left in TMPDIR" '[ -z "$(ls -A "$TMPDIR")" ]'
mkdir -p "$D/browser/Default"
printf 'japan\n' > "$D/region"
out="$("$S/cleanup.sh")"; rc=$?
left=""
for f in candidates.jsonl manual.jsonl matched.json sheet.html descriptions.json region browser; do [ -e "$D/$f" ] && left="$left $f"; done
check "cleanup removes the candidates, sheet, descriptions, region, and browser profile" '[ "$rc" = 0 ] && [ -z "$left" ]'
check "cleanup keeps the additions list and the follow-up list" '[ -s "$D/additions.json" ] && [ -s "$D/followups.tsv" ] && printf "%s\n" "$out" | grep -q "Kept the follow-up list"'

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ]
