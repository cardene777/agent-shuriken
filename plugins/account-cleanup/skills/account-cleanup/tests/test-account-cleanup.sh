#!/usr/bin/env bash
# Tests for the account-cleanup scripts in a throwaway HOME and data folder.
# Stand-ins for op, bw, and curl come first on PATH and record how they were called, and the browser
# databases are created here, so no real vault, browser profile, or network is touched.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
S="$HERE/../scripts"
PASS=0
FAIL=0
SKIP=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

# A Chromium-based browser opens the sheet and the follow-up page as the user does, for the checks on
# the drawn pages. ACCOUNT_CLEANUP_TEST_BROWSER names the browser; otherwise the headless browsers
# Playwright downloaded, the usual apps, and the usual commands are tried, all before HOME is replaced
# below. The headless browsers come first because a macOS app started without a display can abort and
# show a crash notice. Without a browser, those checks are skipped.
real_browser="${ACCOUNT_CLEANUP_TEST_BROWSER:-}"
if [ -z "$real_browser" ]; then
  for b in "$HOME"/Library/Caches/ms-playwright/chromium_headless_shell-*/*/chrome-headless-shell \
    "$HOME"/.cache/ms-playwright/chromium_headless_shell-*/*/chrome-headless-shell; do
    [ -x "$b" ] && real_browser="$b"
  done
fi
if [ -z "$real_browser" ]; then
  for b in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium" \
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
    "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" \
    "$(command -v google-chrome 2>/dev/null)" "$(command -v chromium 2>/dev/null)" "$(command -v chromium-browser 2>/dev/null)"; do
    if [ -n "$b" ] && [ -x "$b" ]; then real_browser="$b"; break; fi
  done
fi
[ -n "$real_browser" ] && [ ! -x "$real_browser" ] && real_browser=""

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
skip() { SKIP=$((SKIP + 1)); printf 'skip  %s\n' "$1"; }
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
out="$(printf '%s\n' '{"example.net": {"description": "A test site", "category": "other", "suggestion": "ok", "why": "Unused"}}' \
  | "$S/annotate.sh" - 2>"$T/err")"; rc=$?
check "annotate reads the descriptions from standard input with - and leaves no file behind" \
  '[ "$rc" = 0 ] && [ "$out" = "Attached descriptions to 1 candidate(s)." ] \
   && [ "$(jq -r ".[] | select(.key == \"example.net\") | .description" "$D/matched.json")" = "A test site" ] \
   && jq -e "has(\"example.org\") and has(\"example.net\")" "$D/descriptions.json" >/dev/null \
   && [ -z "$(find "$D" -name "descriptions-new*")" ]'

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
printf 'other\n' > "$D/region"
printf 'example.net\n' | "$S/plan.sh" > "$T/plan3.md"
check "plan for another region tells the agent to replace the citation" \
  'grep -qF "replace the GDPR citation with the data protection law that applies where the user lives" "$T/plan3.md" && grep -qxF "Erasure request (GDPR-style text)" "$T/plan3.md"'
rm "$D/region"

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

# The service column. Stuck service is the name the deletion list gives example.net. example.org is
# listed under the host name mail.example.org, which already holds the domain. missing.example is not
# a candidate, and the record for old.example was written before records kept a name.
"$S/followup.sh" add example.net "Send the erasure request" >/dev/null
"$S/followup.sh" add missing.example "Remove the saved card" >/dev/null
printf '2026-01-02\told.example\tA gift card balance is left\n' >> "$D/followups.tsv"
"$S/followup.sh" page >/dev/null
check "followup add keeps the service name from the candidates" \
  '[ "$(awk -F "\t" "\$2 == \"example.net\" { print \$4 }" "$D/followups.tsv")" = "Stuck service" ] && [ -z "$(awk -F "\t" "\$2 == \"missing.example\" { print \$4 }" "$D/followups.tsv")" ]'
# followup_cell <key>: the service cell of the row whose What's left column is the record of <key>,
# as "<shown name>|<text under it>"; the text under it is empty when the cell has none.
followup_cell() {
  python3 - "$D/followups.tsv" "$D/followups.html" "$1" <<'PY'
import html, re, sys
records = [l.rstrip("\n").split("\t") for l in open(sys.argv[1], encoding="utf-8") if l.strip()]
what = [r[2] for r in records if r[1] == sys.argv[3]][0]
page = open(sys.argv[2], encoding="utf-8").read()
# A row is the service as its header, then what is left and the date
for row in re.findall(r"<tr>(.*?)</tr>", page, re.S):
    cells = re.findall(r"<t[hd][^>]*>(.*?)</t[hd]>", row, re.S)
    if len(cells) == 3 and html.unescape(re.sub(r"<[^>]+>", "", cells[1])) == what:
        under = re.search(r"<small[^>]*>(.*?)</small>", cells[0], re.S)
        name = re.sub(r"<small[^>]*>.*?</small>", "", cells[0], flags=re.S)
        print(html.unescape(re.sub(r"<[^>]+>", "", name)).strip() + "|" + (html.unescape(re.sub(r"<[^>]+>", "", under.group(1))).strip() if under else ""))
PY
}
check "the follow-up page shows the service name with the domain under it only when it adds something" \
  '[ "$(followup_cell example.net)" = "Stuck service|example.net" ] && [ "$(followup_cell example.org)" = "mail.example.org|" ]'
check "the follow-up page shows the key alone for a record without a name" \
  '[ "$(followup_cell missing.example)" = "missing.example|" ] && [ "$(followup_cell old.example)" = "old.example|" ]'

# --- the drawn sheet and follow-up page
# The sheet and the follow-up page build their text in the browser, so these checks open them as the
# user does. A second set of candidates, built by the same scripts in a folder of its own, has every
# shape a row can take: a name that is its domain, a host name under its domain, a browser extension,
# every deletion effort, a site that is gone, and leftovers from a last round. A probe added to a copy
# of each page presses the page's own buttons and writes what it drew into the page. The drawn page,
# with a copy of every state it went through, then goes through the verify of page-design.
W="$T/drawn"
TEMPLATE="$HERE/../templates/sheet.html"
PAGE_DESIGN="$HERE/../../../../design-formats/skills/page-design/scripts/page-design.py"
mkdir -p "$W/browser-home"
cat > "$W/op-items.json" <<'JSON'
[{"id": "d01", "title": "Mailbox", "updated_at": "2025-09-02T09:00:00Z", "urls": [{"primary": true, "href": "https://mail.example.org/sign-in"}]},
 {"id": "d02", "title": "PhotoShare", "updated_at": "2021-05-14T09:00:00Z", "urls": [{"primary": true, "href": "https://www.photoshare.example/login"}]},
 {"id": "d03", "title": "QuickPizza", "updated_at": "2022-11-03T09:00:00Z", "urls": [{"primary": true, "href": "https://order.quickpizza.example/"}]},
 {"id": "d04", "title": "FitTrack", "updated_at": "2020-08-30T09:00:00Z", "urls": [{"primary": true, "href": "https://app.fittrack.example/"}]},
 {"id": "d05", "title": "Stuck service", "updated_at": "2024-04-09T09:00:00Z", "urls": [{"primary": true, "href": "https://stuck.example.net/"}]},
 {"id": "d06", "title": "Language app", "updated_at": "2022-09-03T09:00:00Z", "urls": [{"primary": true, "href": "https://lingo.example/"}]},
 {"id": "d07", "title": "Old forum", "updated_at": "2019-01-12T09:00:00Z", "urls": [{"primary": true, "href": "https://oldforum.example/"}]},
 {"id": "d08", "title": "Gone service", "updated_at": "2021-07-07T09:00:00Z", "urls": [{"primary": true, "href": "https://goneservice.example/"}]},
 {"id": "d09", "title": "Router", "updated_at": "2025-01-01T09:00:00Z", "urls": [{"primary": true, "href": "http://192.168.1.1/"}]},
 {"id": "d10", "title": "CloudDrive", "updated_at": "2026-10-20T09:00:00Z", "urls": [{"primary": true, "href": "https://clouddrive.example/"}]},
 {"id": "d11", "title": "Paper shop", "updated_at": "2025-06-01T09:00:00Z", "urls": [{"primary": true, "href": "https://shop.paperworks.example.co.jp/"}]}]
JSON
cat > "$W/sites.json" <<'JSON'
[{"name": "Mailbox", "url": "https://mail.example.org/delete", "difficulty": "easy", "domains": ["mail.example.org"]},
 {"name": "PhotoShare", "url": "https://photoshare.example/settings/delete", "difficulty": "easy", "domains": ["photoshare.example"]},
 {"name": "QuickPizza", "url": "https://quickpizza.example/help/close-account", "difficulty": "medium", "domains": ["quickpizza.example"]},
 {"name": "FitTrack", "url": "https://fittrack.example/privacy", "difficulty": "hard", "domains": ["fittrack.example"]},
 {"name": "Stuck service", "url": "https://stuck.example.net/privacy", "difficulty": "impossible", "domains": ["stuck.example.net"]},
 {"name": "Lingo", "url": "https://lingo.example/settings/account", "difficulty": "limited", "domains": ["lingo.example"]}]
JSON
python3 - "$W/browser-home/Library/Application Support/Google/Chrome/Default" <<'PY'
import os, sqlite3, sys
os.makedirs(sys.argv[1], exist_ok=True)
def chrome_time(unix):
    return (unix + 11644473600) * 1000000
db = sqlite3.connect(os.path.join(sys.argv[1], "Login Data"))
db.execute("CREATE TABLE logins (origin_url TEXT, username_value TEXT, password_value BLOB, date_created INTEGER, date_last_used INTEGER, blacklisted_by_user INTEGER)")
db.executemany("INSERT INTO logins VALUES (?, ?, ?, ?, ?, ?)", [
    ("https://forum.example.com/login", "", b"", chrome_time(1546300800), chrome_time(1777593600), 0),
    ("https://coupons.example/", "", b"", chrome_time(1546300800), chrome_time(1640995200), 0),
    ("chrome-extension://abcdefghijklmnopabcdefghijklmnop/", "", b"", chrome_time(1640995200), chrome_time(1672531200), 0),
])
db.commit()
db = sqlite3.connect(os.path.join(sys.argv[1], "History"))
db.execute("CREATE TABLE urls (url TEXT, last_visit_time INTEGER)")
db.executemany("INSERT INTO urls VALUES (?, ?)", [
    ("https://news.example.org/", chrome_time(1704067200)),
    ("https://forum.example.com/thread/1", chrome_time(1717200000)),
    ("https://mail.example.org/inbox", chrome_time(1763500000)),
    ("https://clouddrive.example/files", chrome_time(1763000000)),
])
db.commit()
PY
(
  export ACCOUNT_CLEANUP_HOME="$W/data" ACCOUNT_CLEANUP_SITES="$W/sites.json" ACCOUNT_CLEANUP_BROWSER_HOME="$W/browser-home" \
    ACCOUNT_CLEANUP_TODAY=2026-11-21 OP_ITEMS="$W/op-items.json" OP_LOG="$W/op.log" CURL_LOG="$W/curl.log" CURL_DEAD="goneservice.example"
  "$S/add-candidate.sh" "TaskBoard (Sign in with Google)" "taskboard.example"
  "$S/prepare.sh" --sources 1password,chrome --region japan --history
  "$S/add-site.sh" coupons.example https://coupons.example/news/closing ended "The service closed in 2024"
  "$S/add-site.sh" paperworks.example.co.jp https://shop.paperworks.example.co.jp/mypage/withdraw easy
  "$S/prepare.sh" --rebuild --history
  "$S/annotate.sh" - <<'JSON'
{"example.org": {"description": "A web mail service", "category": "email", "suggestion": "ng", "why": "Other accounts reset their passwords through it"},
 "photoshare.example": {"description": "A photo-sharing social network", "category": "social", "suggestion": "ok", "why": "Not updated since 2021"},
 "quickpizza.example": {"description": "A pizza delivery ordering site", "category": "shopping", "suggestion": "ok", "why": "No orders saved since 2022"},
 "fittrack.example": {"description": "A fitness tracking app", "category": "other", "suggestion": "ok", "why": "Last updated in 2020"},
 "example.net": {"description": "A file conversion service", "category": "other", "suggestion": "ok", "why": "Not used since 2024",
                 "previous": {"round": 1, "label": "send request", "detail": "The service has no delete button. Send the drafted erasure request."}},
 "lingo.example": {"description": "A language-learning app", "category": "other", "suggestion": "ok", "why": "Not updated since 2022"},
 "oldforum.example": {"description": "Can't tell from the name", "category": "other", "suggestion": "ok", "why": "Untouched since 2019"},
 "goneservice.example": {"description": "Can't tell from the name", "category": "other", "suggestion": "ok", "why": "The site no longer answers"},
 "192.168.1.1": {"description": "The admin page of a home router", "category": "other", "suggestion": "ng", "why": "Not a web service account"},
 "coupons.example": {"description": "A coupon and discount site", "category": "shopping", "suggestion": "ok", "why": "The service closed in 2024",
                     "previous": {"round": 1, "label": "exchange", "detail": "Points were left. Exchange them on the points page, then delete."}},
 "abcdefghijklmnopabcdefghijklmnop": {"description": "A browser extension, most likely a crypto wallet", "category": "other", "suggestion": "ng", "why": "Check that no assets are left first"},
 "example.com": {"description": "A discussion forum", "category": "social", "suggestion": "ng", "why": "Opened in 2024"},
 "clouddrive.example": {"description": "A file storage service", "category": "cloud", "suggestion": "ng", "why": "Opened this month"},
 "example.co.jp": {"description": "A stationery shop", "category": "shopping", "suggestion": "ok", "why": "Not updated since 2025",
                   "previous": {"round": 1, "label": "exchange", "detail": "A gift card balance was left. Use it, then delete."}},
 "taskboard.example": {"description": "A task board for teams", "category": "work", "suggestion": "ng", "why": "Used for work"}}
JSON
  cp "$W/data/sheet.html" "$W/prev.html"
  jq 'map(.previous = null)' "$W/data/matched.json" > "$W/plain.json"
  "$S/build-sheet.sh" "$W/plain.json"
  cp "$W/data/sheet.html" "$W/plain.html"
  "$S/followup.sh" add example.net "Send the drafted erasure request from your own email"
  "$S/followup.sh" add coupons.example "Points are still left on the points page"
  "$S/followup.sh" add quickpizza.example "A Visa card is still saved as a payment method"
  "$S/followup.sh" page
  cp "$W/data/followups.html" "$W/followups.html"
) > "$W/build.log" 2>&1

cat > "$W/probe.js" <<'JS'
(function () {
  "use strict";
  // Runs right after the page's own script, in a copy of the page. It presses the page's own buttons,
  // writes what the page drew into #probe-result, and keeps a copy of each drawn state for verify.
  function q(s, r) { return (r || document).querySelector(s); }
  function qa(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function press(sel) { var b = q(sel); if (b) b.click(); return !!b; }
  var snaps = document.createElement("div");
  snaps.id = "probe-snapshots";
  function snap(name) {
    var s = document.createElement("section");
    s.setAttribute("data-state", name);
    s.appendChild(q("main").cloneNode(true));
    qa("dialog").forEach(function (d) { var c = d.cloneNode(true); c.removeAttribute("open"); s.appendChild(c); });
    snaps.appendChild(s);
  }
  function rgb(c) {
    var m = c.match(/rgba?\(([^)]+)\)/);
    if (!m) return null;
    var p = m[1].split(/[ ,/]+/).filter(Boolean).map(Number);
    return { r: p[0], g: p[1], b: p[2], a: p.length > 3 ? p[3] : 1 };
  }
  function lum(c) {
    function f(v) { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }
    return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
  }
  function blend(fg, bg) { return { r: fg.r * fg.a + bg.r * (1 - fg.a), g: fg.g * fg.a + bg.g * (1 - fg.a), b: fg.b * fg.a + bg.b * (1 - fg.a), a: 1 }; }
  function background(el) {
    var layers = [];
    for (var e = el; e; e = e.parentElement) {
      var c = rgb(getComputedStyle(e).backgroundColor);
      if (c && c.a > 0) { layers.push(c); if (c.a >= 1) break; }
    }
    var base = { r: 255, g: 255, b: 255, a: 1 };
    for (var i = layers.length - 1; i >= 0; i--) base = blend(layers[i], base);
    return base;
  }
  // Text drawn under 4.5:1 against the background it sits on. Disabled controls are left out
  function lowContrast(where) {
    var out = [];
    qa("body *").forEach(function (el) {
      if (el.closest("#probe-snapshots, script, style, [hidden]")) return;
      if (el.closest("dialog") && !el.closest("dialog[open]")) return;
      var own = Array.prototype.some.call(el.childNodes, function (n) { return n.nodeType === 3 && n.textContent.trim(); });
      if (!own) return;
      var s = getComputedStyle(el), box = el.getBoundingClientRect();
      if (s.visibility === "hidden" || s.display === "none" || box.width === 0 || el.disabled) return;
      var fg = rgb(s.color), bg = background(el);
      if (!fg) return;
      fg = blend(fg, bg);
      var a = lum(fg), b = lum(bg), ratio = (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
      if (ratio < 4.5) out.push(where + " \"" + el.textContent.trim().slice(0, 40) + "\" " + ratio.toFixed(2));
    });
    return out;
  }
  function themes(where) {
    var out = [];
    ["light", "dark"].forEach(function (theme) { press('[data-theme-choice="' + theme + '"]'); out = out.concat(lowContrast(theme + " " + where)); });
    return out;
  }
  var result = { width: window.innerWidth, langs: {} };
  ["en", "ja"].forEach(function (lang) {
    press('[data-lang="' + lang + '"]');
    var L = { tabs: {}, help: [], steps: [], contrast: [] };
    result.langs[lang] = L;
    if (!q("#sheet")) { L.contrast = themes(lang); snap(lang); return; }
    // The categories: the shown tabs of a long list, else the category filter of a short one, which
    // starts with all of them. A list of one category has neither and is read as all
    var tabs = qa("#tabs button").filter(function (b) { return !q("#tabs").hidden && !b.hidden; }).map(function (b) { return ["#tab-", b.getAttribute("data-t")]; });
    var filters = qa("#category button").map(function (b) { return ['#category [data-c="', b.getAttribute("data-c"), '"]']; });
    var cats = tabs.length ? tabs : filters.length ? filters : [[null, "all"]];
    cats.forEach(function (c) {
      var name = c[1];
      if (c[0]) press(c[0] + name + (c[2] || ""));
      var sel = q("#sort");
      var T = { sort: sel.value, sortLabel: sel.selectedOptions[0] ? sel.selectedOptions[0].textContent : "", options: qa("option", sel).map(function (o) { return o.value; }), rows: [] };
      // The names are measured in the list first, since a narrow screen hides the list behind the details
      var rows = qa("#rows .row").map(function (row) {
        var b = q(".row-name b", row), s = q(".row-name small", row);
        return { key: row.getAttribute("data-key"), name: b.textContent, sub: s ? s.textContent : null, nameClipped: b.scrollWidth > b.clientWidth + 1 };
      });
      rows.forEach(function (r, i) {
        q('#rows .row[data-key="' + CSS.escape(r.key) + '"] .name').click();
        var d = q("#detail");
        r.detailTitle = q("h2", d) ? q("h2", d).textContent : null;
        r.detailKey = q(".key", d) ? q(".key", d).textContent : null;
        T.rows.push(r);
        if (name === "all" || i === 0) L.contrast = L.contrast.concat(themes(lang + " " + name + " " + r.key));
        q("#sheet").setAttribute("data-view", "list");
      });
      if (rows.length) q('#rows .row[data-key="' + CSS.escape(rows[0].key) + '"] .name').click();
      snap(lang + "-" + name);
      q("#sheet").setAttribute("data-view", "list");
      L.tabs[name] = T;
    });
    var help = q("#help");
    if (help.showModal) help.showModal(); else help.setAttribute("open", "");
    L.help = qa("#effort-help dt", help).map(function (dt) { var dd = dt.nextElementSibling; return [dt.textContent, dd ? dd.textContent : ""]; });
    // The narrowest explanation as a share of the dialog, so a column one letter wide shows up
    var wide = help.getBoundingClientRect().width;
    L.helpShare = qa("#effort-help dd", help).reduce(function (m, dd) { return Math.min(m, dd.getBoundingClientRect().width / wide); }, 1);
    L.contrast = L.contrast.concat(themes(lang + " help"));
    help.close();
    L.steps = qa(".steps li").map(function (li) {
      var s = q("span", li), lh = parseFloat(getComputedStyle(s).lineHeight), r = li.getBoundingClientRect();
      return { top: Math.round(r.top), lines: Math.round(s.getBoundingClientRect().height / lh) };
    });
  });
  var pre = document.createElement("pre");
  pre.id = "probe-result";
  pre.textContent = JSON.stringify(result);
  document.body.appendChild(snaps);
  document.body.appendChild(pre);
})();
JS

# draw <name> <width>: opens a copy of $W/<name>.html with the probe in a window <width> pixels wide,
# and writes what it drew to $W/<name>-<width>.json and the drawn page to $W/<name>-<width>.drawn.html.
draw() {
  python3 - "$W/$1.html" "$W/probe.js" "$W/$1-$2.probed.html" <<'PY' || return 1
import sys
page = open(sys.argv[1], encoding="utf-8").read()
probe = open(sys.argv[2], encoding="utf-8").read()
i = page.rindex("</body>")
open(sys.argv[3], "w", encoding="utf-8").write(page[:i] + "<script>\n" + probe + "\n</script>\n" + page[i:])
PY
  "$real_browser" --headless --disable-gpu --no-first-run --no-default-browser-check --disable-extensions \
    --user-data-dir="$W/profile-$1-$2" --window-size="$2,900" --dump-dom "file://$W/$1-$2.probed.html" > "$W/$1-$2.dom.html" 2>/dev/null || return 1
  python3 - "$W/$1-$2.dom.html" "$W/$1-$2.json" "$W/$1-$2.drawn.html" <<'PY'
import html, re, sys
page = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'<pre id="probe-result">(.*?)</pre>', page, re.S)
if not m:
    sys.exit(1)
open(sys.argv[2], "w", encoding="utf-8").write(html.unescape(m.group(1)))
open(sys.argv[3], "w", encoding="utf-8").write(page[:m.start()] + page[m.end():])
PY
}

# drawn <what>: one check on what the probe recorded, with the reason printed when it fails.
cat > "$W/check.py" <<'PY'
import json, re, sys
what, W, template = sys.argv[1:4]

def result(name, width):
    return json.load(open("%s/%s-%s.json" % (W, name, width), encoding="utf-8"))

def candidates(name):
    page = open("%s/%s.html" % (W, name), encoding="utf-8").read()
    return {g["key"]: g for g in json.loads(re.search(r'<script type="application/json" id="data">\s*(.*?)\s*</script>', page, re.S).group(1))}

def fail(why):
    print("      " + why)
    sys.exit(1)

def adds(name, key):
    n, k = name.lower(), key.lower()
    return n != k and not n.endswith("." + k)

def has_prev(g):
    return bool(g.get("previous") and g["previous"].get("label"))

if what == "domain-line":
    shapes = set()
    for lang, L in result("prev", 1400)["langs"].items():
        for row in L["tabs"]["all"]["rows"]:
            want = row["key"] if adds(row["name"], row["key"]) else None
            if row["sub"] != want or row["detailKey"] != want:
                fail("%s %s: under the name %r the row shows %r and the details show %r, expected %r" % (lang, row["key"], row["name"], row["sub"], row["detailKey"], want))
            n, k = row["name"].lower(), row["key"].lower()
            shapes.add("same" if n == k else "host" if n.endswith("." + k) else "other")
    if shapes != {"same", "host", "other"}:
        fail("the candidates hold only these shapes of name and domain: %s" % sorted(shapes))

elif what == "whole-names":
    extension = False
    for width in (1400, 390):
        for lang, L in result("prev", width)["langs"].items():
            for tab, T in L["tabs"].items():
                for row in T["rows"]:
                    if row["nameClipped"]:
                        fail("%spx %s %s: the name %r is cut" % (width, lang, tab, row["name"]))
                    if re.fullmatch(r"[a-p]{32}", row["key"]):
                        extension = True
                        if row["name"] != row["key"]:
                            fail("%spx %s: the extension shows %r instead of its ID" % (width, lang, row["name"]))
    if not extension:
        fail("no browser extension among the candidates")

elif what == "sort-follows":
    for name in ("prev", "plain"):
        data = candidates(name)
        for lang, L in result(name, 1400)["langs"].items():
            for tab, T in L["tabs"].items():
                rows = [data[r["key"]] for r in T["rows"]]
                where = "%s sheet, %s, %s tab, sort %r (%s)" % (name, lang, tab, T["sort"], T["sortLabel"])
                if T["sort"] == "prev":
                    flags = [has_prev(g) for g in rows]
                    if not any(flags) or flags != sorted(flags, reverse=True):
                        fail(where + ": the rows are not in the order of their last-round results")
                    labels = [g["previous"]["label"].lower() for g in rows if has_prev(g)]
                    if labels != sorted(labels):
                        fail(where + ": the last-round results are not in order")
                elif T["sort"] in ("old", "new"):
                    dates = [g.get("updated") or "" for g in rows]
                    if dates != sorted(dates, reverse=T["sort"] == "new"):
                        fail(where + ": the rows are not in the order of their last update")
                else:
                    fail(where + ": the tab starts with a sort the check does not know")

elif what == "prev-only-where-it-applies":
    data = candidates("prev")
    for lang, L in result("prev", 1400)["langs"].items():
        for tab, T in L["tabs"].items():
            some = any(has_prev(data[r["key"]]) for r in T["rows"])
            if ("prev" in T["options"]) != some:
                fail("%s %s tab: offers the sort by last round's result %s, and has rows with a last-round result %s" % (lang, tab, "prev" in T["options"], some))

elif what == "plain-never-prev":
    for lang, L in result("plain", 1400)["langs"].items():
        if "prev" in L["tabs"]:
            fail("%s: the sheet without a last round shows the tab of leftovers" % lang)
        for tab, T in L["tabs"].items():
            if "prev" in T["options"]:
                fail("%s %s tab: the sheet without a last round offers the sort by last round's result" % (lang, tab))

elif what == "effort-help":
    page = open(template, encoding="utf-8").read()
    # The deletion effort levels the details can show, one table of labels per language
    efforts = re.findall(r"^\s*effort: \{(.*?)\},?$", page, re.M)
    if len(efforts) != 2:
        fail("the dictionary of the template does not hold one effort table per language")
    for i, lang in enumerate(("en", "ja")):
        want = set(re.findall(r'"([^"]*)"', re.sub(r"\b\w+:", "", efforts[i])))
        shown = {}
        for label, text in result("prev", 1400)["langs"][lang]["help"]:
            shown[label.strip()] = text.strip()
        missing = sorted(l for l in want if not shown.get(l) or shown[l] == l)
        if missing:
            fail("%s: the help does not explain %s" % (lang, ", ".join(missing)))
        for width in (1400, 390):
            share = result("prev", width)["langs"][lang]["helpShare"]
            if share < 0.4:
                fail("%spx %s: an explanation in the help is only %d%% of the dialog wide" % (width, lang, share * 100))

elif what in ("sheet-contrast", "followups-contrast"):
    runs = [("prev", 1400), ("prev", 390), ("plain", 1400)] if what == "sheet-contrast" else [("followups", 1400)]
    low = []
    for name, width in runs:
        for lang, L in result(name, width)["langs"].items():
            low += ["%s %spx %s" % (name, width, x) for x in L["contrast"]]
    if low:
        seen = sorted(set(re.search(r"\"[^\"]*\" [\d.]+$", x).group(0) for x in low))
        fail("text under 4.5:1 in %d places, such as %s" % (len(low), "; ".join(seen[:8])))

elif what == "steps":
    for lang, L in result("prev", 1400)["langs"].items():
        steps = L["steps"]
        if len(steps) != 3 or len({s["top"] for s in steps}) != 1 or any(s["lines"] != 1 for s in steps):
            fail("%s: the steps sit at %s with %s lines" % (lang, [s["top"] for s in steps], [s["lines"] for s in steps]))
PY
drawn() { python3 "$W/check.py" "$1" "$W" "$TEMPLATE"; }
verify_drawn() {
  local f bad=0
  for f in "$@"; do
    python3 "$PAGE_DESIGN" verify "$W/$f.drawn.html" > "$W/$f.verify" 2>&1 || { sed 's/^/      /' "$W/$f.verify" | head -6; bad=1; }
  done
  return "$bad"
}

DRAWN_CHECKS="the drawn sheet shows the domain under a name only when it adds something
the drawn sheet shows every name whole at 1400px and 390px
each tab of the drawn sheet shows the sort its rows follow
the drawn sheet offers the sort by last round's result only on tabs with such rows
the drawn sheet without a last round never offers the sort by last round's result
the help of the drawn sheet explains every deletion effort in both languages
every text on the drawn sheet has a contrast of at least 4.5 to 1 in both themes
the three steps of the drawn sheet sit on one row with one line each at 1400px
every drawn state of the sheet passes page-design verify
the drawn follow-up page keeps a contrast of 4.5 to 1 and passes page-design verify"
if [ -z "$real_browser" ]; then
  while IFS= read -r c; do skip "$c (no Chromium-based browser)"; done <<< "$DRAWN_CHECKS"
elif [ ! -s "$W/prev.html" ] || [ ! -s "$W/plain.html" ] || [ ! -s "$W/followups.html" ]; then
  sed 's/^/      /' "$W/build.log" | tail -5
  while IFS= read -r c; do ng "$c (the pages to draw were not built)"; done <<< "$DRAWN_CHECKS"
elif ! { draw prev 1400 && draw prev 390 && draw plain 1400 && draw followups 1400; }; then
  while IFS= read -r c; do ng "$c (the browser did not draw the pages)"; done <<< "$DRAWN_CHECKS"
else
  check "the drawn sheet shows the domain under a name only when it adds something" "drawn domain-line"
  check "the drawn sheet shows every name whole at 1400px and 390px" "drawn whole-names"
  check "each tab of the drawn sheet shows the sort its rows follow" "drawn sort-follows"
  check "the drawn sheet offers the sort by last round's result only on tabs with such rows" "drawn prev-only-where-it-applies"
  check "the drawn sheet without a last round never offers the sort by last round's result" "drawn plain-never-prev"
  check "the help of the drawn sheet explains every deletion effort in both languages" "drawn effort-help"
  check "every text on the drawn sheet has a contrast of at least 4.5 to 1 in both themes" "drawn sheet-contrast"
  check "the three steps of the drawn sheet sit on one row with one line each at 1400px" "drawn steps"
  if [ -f "$PAGE_DESIGN" ]; then
    check "every drawn state of the sheet passes page-design verify" "verify_drawn prev-1400 prev-390 plain-1400"
    check "the drawn follow-up page keeps a contrast of 4.5 to 1 and passes page-design verify" \
      "drawn followups-contrast && verify_drawn followups-1400"
  else
    skip "every drawn state of the sheet passes page-design verify (page-design is not next to this plugin)"
    skip "the drawn follow-up page keeps a contrast of 4.5 to 1 and passes page-design verify (page-design is not next to this plugin)"
  fi
fi

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

# --- the SKILL.md and the eval suite that measures it (plugins/account-cleanup/evals)
SKILL="$HERE/../SKILL.md"
PLUGIN="$HERE/../../.."
EVALS="$PLUGIN/evals"
CHROME="Library/Application Support/Google/Chrome/Default"

# The rules are the guarantees in docs/safety.md, so a shorter SKILL.md keeps every one of them.
skill_rules() {
  local phrase
  for phrase in "op item get" "Login Data" "two-factor" "approval" "not part of deleting the account" \
    "card statements" "service name and domain" "outside this computer"; do
    grep -qiF -- "$phrase" "$SKILL" || return 1
  done
}
check "the SKILL.md keeps its rules on passwords, approval, and the browser" "skill_rules"

eval_cases() {
  local c
  for c in trigger-asks-first unrelated-request collect-and-describe password-not-shown plan-before-deleting; do
    [ -f "$EVALS/$c/case.yaml" ] || return 1
  done
}
check "the eval suite has the five cases" "eval_cases"

# Each fixture runs in an empty folder under its own HOME, as claude plugin eval runs it, without the
# overrides this test sets for the scripts, so the scripts use their real data folder and site list.
fixture_env() { env -u ACCOUNT_CLEANUP_HOME -u ACCOUNT_CLEANUP_SITES -u ACCOUNT_CLEANUP_TODAY HOME="$1" TMPDIR="$1/.tmp" "${@:2}"; }
fixture() {
  local d="$T/fixture-$1"
  rm -rf "$d"
  mkdir -p "$d/home/cwd" "$d/home/.tmp"
  (cd "$d/home/cwd" && fixture_env "$d/home" bash "$EVALS/$1/fixture.sh") >/dev/null 2>&1 && printf '%s\n' "$d/home"
}
fixtures_ready() {
  local h data=".local/share/account-cleanup"
  h="$(fixture trigger-asks-first)" && [ -f "$h/$CHROME/Login Data" ] && [ ! -e "$h/$data" ] || return 1
  h="$(fixture unrelated-request)" && [ -f "$h/cwd/package.json" ] && [ ! -e "$h/$data" ] || return 1
  h="$(fixture collect-and-describe)" && [ -f "$h/$CHROME/Login Data" ] && [ -f "$h/$CHROME/History" ] &&
    [ ! -e "$h/$data" ] || return 1
  h="$(fixture password-not-shown)" && [ -f "$h/$CHROME/Login Data" ] && [ ! -e "$h/$data" ] || return 1
  h="$(fixture plan-before-deleting)" && [ "$(cat "$h/$data/region" 2>/dev/null)" = japan ] || return 1
  # One chosen service cannot be deleted, so the plan carries the erasure request for Japan.
  printf 'account-cleanup selection\ntrailmap.example\n' | fixture_env "$h" "$S/plan.sh" 2>/dev/null |
    grep -qxF "Erasure request (Japan APPI Article 35)"
}
check "the eval fixtures build the states their cases start from" "fixtures_ready"

# The made-up saved passwords carry no password at all, so no case can show one even by mistake.
fixtures_have_no_password() {
  local c db rows=0 filled
  for c in trigger-asks-first collect-and-describe password-not-shown plan-before-deleting; do
    db="$T/fixture-$c/home/$CHROME/Login Data"
    [ -f "$db" ] || return 1
    rows=$((rows + $(sqlite3 "$db" "SELECT count(*) FROM logins")))
    filled="$(sqlite3 "$db" "SELECT count(*) FROM logins WHERE length(password_value) > 0 OR length(username_value) > 0")"
    [ "$filled" = 0 ] || return 1
  done
  [ "$rows" -gt 0 ]
}
check "the eval fixtures hold no password" "fixtures_have_no_password"

eval_results_ignored() { git -C "$PLUGIN" check-ignore -q evals/results/run.json; }
check "eval results are ignored by git" "eval_results_ignored"

# The limits are the sizes of the shortened SKILL.md. Every agent that starts the skill reads the
# whole body, and every session reads the description, so raise a limit only with a reason.
SKILL_WORDS_MAX=2340
SKILL_DESCRIPTION_MAX=445
skill_size() {
  python3 - "$SKILL" "$SKILL_WORDS_MAX" "$SKILL_DESCRIPTION_MAX" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
m = re.match(r"---\n(.*?)\n---\n(.*)", text, re.S)
desc = re.search(r"^description:\s*(.*)$", m.group(1), re.M).group(1).strip()
sys.exit(0 if len(m.group(2).split()) <= int(sys.argv[2]) and len(desc) <= int(sys.argv[3]) else 1)
PY
}
check "the SKILL.md stays within its size limits" "skill_size"

# The words of the two pages, read from each page's dictionary for one language.
dictionary_words() { # <what> <template>...
  python3 - "$@" <<'PY'
import re, sys
what, files = sys.argv[1], sys.argv[2:]
lang = "ja" if what == "ja-space" else "en"
# Kana and kanji, with the Japanese comma and full stop, built from code points.
JA = "%s-%s%s-%s" % tuple(map(chr, (0x3040, 0x30FF, 0x4E00, 0x9FFF)))
STOPS = chr(0x3001) + chr(0x3002)
space = re.compile(r"[%s%s] [A-Za-z0-9{]|[A-Za-z0-9}] [%s]" % (JA, STOPS, JA))
problems, seen = [], 0
for f in files:
    page = open(f, encoding="utf-8").read()
    block = re.search(r"^(\s+)%s: \{\n(.*?)^\1\}" % lang, page, re.S | re.M)
    if not block:
        problems.append("%s has no %s dictionary" % (f, lang))
        continue
    words = re.findall(r'(\w+): "([^"]*)"', block.group(2))
    seen += len(words)
    name = f.rsplit("/", 1)[1]
    for key, text in words:
        if what == "ja-space" and space.search(text):
            problems.append("%s %s: %r" % (name, key, text))
    if what == "en-tally":
        tally = [text for key, text in words if key == "tally"]
        bar = re.search(r'id="tally">(.*?)</span>', page, re.S)
        if name == "sheet.html" and (not tally or "·" in tally[0] or not bar or "·" in bar.group(1)):
            problems.append("%s: the bottom bar reads %r and the dictionary %r" % (name, bar.group(1) if bar else None, tally))
if not seen:
    problems.append("no words were read")
for p in problems[:8]:
    print("      " + p)
sys.exit(1 if problems else 0)
PY
}
check "the Japanese words put no space between Japanese and Latin letters or digits" \
  'dictionary_words ja-space "$HERE/../templates/sheet.html" "$HERE/../templates/followups.html"'
check "the English bottom bar joins its two counts without a middle dot" \
  'dictionary_words en-tally "$HERE/../templates/sheet.html"'

# --- the patterns of page-design on the sheet and the follow-up page
# These checks read the two templates and run the sheet's own functions in Node, without a browser.
FOLLOWUPS_TEMPLATE="$HERE/../templates/followups.html"
NODE="$(command -v node 2>/dev/null)"

# pattern <what> [page]: one check on the text of the templates (and of a built follow-up page),
# with the reason printed when it fails.
cat > "$T/patterns.py" <<'PY'
import glob, json, re, sys
what, sheet_path, followups_path, plugin = sys.argv[1:5]
built = sys.argv[5] if len(sys.argv) > 5 else None
sheet = open(sheet_path, encoding="utf-8").read()
followups = open(followups_path, encoding="utf-8").read()

def fail(why):
    print("      " + why)
    sys.exit(1)

def need(ok, why):
    if not ok:
        fail(why)

def style(page):
    return re.search(r"<style>(.*?)</style>", page, re.S).group(1)

def rules(page):
    # Every CSS rule as (media query or "", selector, declarations), one level of @media deep
    css, out, i = re.sub(r"/\*.*?\*/", "", style(page), flags=re.S), [], 0
    def block(text, media):
        for m in re.finditer(r"([^{}]+)\{([^{}]*)\}", text):
            out.append((media, " ".join(m.group(1).split()), m.group(2)))
    depth, start, media, last = 0, 0, None, 0
    for j, ch in enumerate(css):
        if ch == "{":
            if depth == 0:
                head = css[last:j].strip()
                if head.startswith("@media"):
                    media, start = head, j + 1
                else:
                    media = None
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                if media:
                    block(css[start:j], media)
                else:
                    block(css[last:j + 1], "")
                last, media = j + 1, None
    return out

def rule(page, pattern, media=None):
    # The declarations of the rules whose selector matches pattern, joined
    found = [d for m, s, d in rules(page) if re.search(pattern, s) and (media is None or (media in m))]
    return " ".join(found)

def script(page):
    return "\n".join(re.findall(r"<script>(.*?)</script>", page, re.S))

def body(js, name):
    # A function of the page, one line when it closes on its own line, else up to the closing brace at its indent
    m = re.search(r"^( *)function %s\(.*$" % re.escape(name), js, re.M)
    if not m:
        return ""
    line = m.group(0)
    if line.count("{") and line.count("{") == line.count("}"):
        return line
    end = re.search(r"^%s\}" % m.group(1), js[m.end():], re.M)
    return js[m.start():m.end() + (end.end() if end else 0)]

def words(page, lang):
    # The top-level entries of one language's dictionary
    m = re.search(r"^(\s+)%s: \{\n(.*?)^\1\}" % lang, page, re.S | re.M)
    need(m, "no %s dictionary" % lang)
    indent = len(m.group(1)) + 2
    return dict(re.findall(r'^ {%d}(\w+): "([^"]*)"' % indent, m.group(2), re.M))

def lum(hex_color):
    v = [int(hex_color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    v = [c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4 for c in v]
    return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2]

def ratio(a, b):
    x, y = lum(a), lum(b)
    return (max(x, y) + 0.05) / (min(x, y) + 0.05)

def theme_vars(page):
    # The color variables of the light theme and of the dark theme
    css = style(page)
    light = re.search(r":root\s*\{(.*?)\}", css, re.S).group(1)
    dark = re.search(r':root\[data-theme="dark"\]\s*\{(.*?)\}', css, re.S).group(1)
    return [dict(re.findall(r"(--[\w-]+):\s*(#[0-9a-fA-F]{6})", t)) for t in (light, dark)]

js = script(sheet)
en, ja = words(sheet, "en"), words(sheet, "ja")

if what == "detail":
    need(re.search(r'<section class="detail" id="detail" aria-labelledby="detail-title"', sheet), "the details panel is not a section named by #detail-title")
    need("<aside" not in sheet, "the details panel is still an aside")
    need(re.search(r'\.id = "detail-title"', js) and re.search(r"\.tabIndex = -1", js), "the heading of the details has no id detail-title or cannot take the focus")
    need(re.search(r'kv\.setAttribute\("aria-label"', js), "the table of facts has no name")
elif what == "split":
    need('class="split"' in sheet and rule(sheet, r"^\.split$"), "no .split container")
    need(not re.search(r"\bpanes\b", sheet), "the page still has .panes")
elif what == "motion":
    need(re.search(r"(animation|transition):", rule(sheet, r"\.detail")), "the details change with no motion")
    reduce = rule(sheet, r".", "prefers-reduced-motion: reduce")
    need(re.search(r"(animation|transition): none", reduce), "reduced motion does not turn the motion off")
elif what == "list":
    need(re.search(r'<ul class="list" id="rows"', sheet), "the list is not a ul")
    need("listbox" not in sheet and '"option"' not in sheet, "the list still uses the listbox and option roles")
    row = body(js, "rowEl")
    need(re.search(r'el\("li"', row) and re.search(r'el\("button", "name"', row), "a row is not a li with a name button")
    need(re.search(r'"aria-current", "true"', js), "the shown row is not marked current")
elif what == "load":
    need(re.search(r"initialKey\(location\.hash", js), "the page does not open the item the hash names")
elif what == "scroll":
    lst, det, head = rule(sheet, r"^\.list$"), rule(sheet, r"^\.detail$"), rule(sheet, r"^\.detail-head$")
    need("overflow-y: auto" in lst and "max-height" in lst, "the list does not scroll on its own")
    need("overflow-y: auto" in det and "overflow-x: hidden" in det, "the details do not scroll only vertically")
    need("position: sticky" in head and "top: 0" in head, "the name and the choice buttons do not stay on top of the details")
elif what == "choose":
    choose = body(js, "choose")
    need(choose and "render(" not in choose, "choosing builds the whole list again")
    need(re.search(r"choose\(g\.key", body(js, "pickButtons")), "the choice buttons do not call choose")
elif what == "memo-raw":
    m = re.search(r'memo\.addEventListener\("input", function \(\) \{(.*?)\}\);', js, re.S)
    need(m and "trim(" not in m.group(1) and "replace(" not in m.group(1), "the memo is cleaned while it is typed")
elif what == "narrow":
    narrow = rule(sheet, r".", "max-width: 860px")
    need('[data-view="detail"]' in rule(sheet, r'data-view="detail"', "max-width: 860px") or 'data-view="detail"' in " ".join(s for m, s, d in rules(sheet) if "860px" in m), "the narrow screen has no detail view")
    need(any('data-view="list"' in s and "display: none" in d for m, s, d in rules(sheet) if "860px" in m), "the narrow screen does not hide the details in the list view")
    need(any('data-view="detail"' in s and "display: none" in d for m, s, d in rules(sheet) if "860px" in m), "the narrow screen does not hide the list in the detail view")
    need(re.search(r'getElementById\("detail-title"\)\.focus\(\)', js), "opening the details does not move the focus to its heading")
elif what == "back":
    for lang, d in (("en", en), ("ja", ja)):
        need(all(d.get(k) for k in ("back", "prevItem", "nextItem")), "%s: no words for back, previous, and next" % lang)
    need("neighbors(" in body(js, "renderDetail"), "the details have no previous and next")
    need(re.search(r"focusRow\(", js), "going back does not return the focus to the row")
elif what == "hash":
    need('addEventListener("hashchange"' in js, "the page does not follow the hash")
    need(re.search(r"history\.replaceState\([^;]*itemId\(", js), "opening an item does not write the hash")
    need(re.search(r"\.id = itemId\(", js), "a row has no id from itemId")
elif what == "dialog-focus":
    need(re.search(r"lastFocus = document\.activeElement", js), "a dialog does not remember the focus")
    need(re.search(r'addEventListener\("close"', js) and "lastFocus.focus()" in js, "closing a dialog does not return the focus")
elif what == "no-all-tab":
    need('data-t="all"' not in sheet and "tabAll" not in en, "the page still has an all tab")
elif what == "category-filter":
    need(re.search(r'id="category" role="group"', sheet), "no category filter in the toolbar")
    need("useTabs(" in js, "the page does not choose between tabs and the category filter")
elif what == "search-chip":
    row = body(js, "rowEl")
    need("state.q" in row and "tabName(tabOf(g))" in row, "a row found by a search does not name its category")
elif what == "tabs-row":
    tabs = rule(sheet, r"^\.tabs$")
    need("flex-wrap: nowrap" in tabs and "overflow-x: auto" in tabs, "the tabs wrap to a second row")
    need("white-space: nowrap" in rule(sheet, r"^\.tabs (button|\[role=\"tab\"\])$"), "a tab label can wrap")
    need('scrollIntoView({ block: "nearest", inline: "nearest" })' in js, "the chosen tab is not scrolled into view")
elif what == "tab-roles":
    need(re.search(r'role="tab"[^>]*aria-controls="panel"', sheet) and re.search(r'role="tabpanel"[^>]*aria-labelledby', sheet), "the tabs have no panel")
    need(all('"%s"' % k in js for k in ("ArrowRight", "ArrowLeft", "Home", "End")), "the tabs do not move with the arrow, Home, and End keys")
elif what == "labels":
    need(re.search(r'<label for="q"', sheet) and re.search(r'<label for="sort"', sheet), "the search or the sort has no visible label")
    need("placeholder" not in sheet.lower(), "the page still uses a placeholder")
    need("renderFilterCounts" in js, "the filter buttons show no counts")
elif what == "pager-nav":
    need(re.search(r'<nav class="pager" id="pager-top"[^>]*aria-label', sheet), "the pager is not a named nav")
    p = rule(sheet, r"^\.pager button$")
    need("min-width: 40px" in p and "min-height: 40px" in p, "the pager buttons are smaller than 40px")
    need(re.search(r'getElementById\("list-title"\)\.focus\(\)', js), "a new page does not move the focus to the list heading")
elif what == "range":
    need('id="range"' in sheet and sheet.index('id="range"') < sheet.index('id="pager-top"'), "no range line above the pager")
elif what == "pager-phone":
    need('matchMedia("(max-width: 599px)")' in js and re.search(r"pagerItems\([^)]*\? 5 : 7", js), "the pager shows the same count of numbers on a phone")
elif what == "words":
    need(en.get("ok") == "Delete" and en.get("ng") == "Keep" and ja.get("ok") == "\u6d88\u3059" and ja.get("ng") == "\u6b8b\u3059", "the choice buttons are not Delete and Keep")
    need(not re.search(r"\bOK\b", sheet) and "\u30c0\u30e1" not in sheet, "the page still says OK or the old Japanese word")
    need("Delete" in en.get("step1", "") and "Keep" in en.get("step1", "") and "delete" in en.get("copy", "").lower(), "the steps and the copy button do not use the same words")
    need("\u6d88\u3059" in ja.get("step1", "") and "\u6b8b\u3059" in ja.get("step1", ""), "the Japanese steps do not use the same words")
elif what == "docs-words":
    files = [plugin + "/" + f for f in ("README.md", "README.ja.md", "docs/how-it-works.md", "docs/how-it-works.ja.md", "skills/account-cleanup/SKILL.md", ".codex-plugin/plugin.json")]
    files += sorted(glob.glob(plugin + "/evals/*/case.yaml"))
    for f in files:
        for n, line in enumerate(open(f, encoding="utf-8"), 1):
            if line.lstrip().startswith("!["):
                continue
            need(not re.search(r"\bOK\b", line) and "\u30c0\u30e1" not in line, "%s:%d still calls a choice OK" % (f.split(plugin + "/")[1], n))
    need("Delete" in open(plugin + "/README.md", encoding="utf-8").read(), "README.md does not name Delete")
    need("\u300c\u6d88\u3059\u300d" in open(plugin + "/README.ja.md", encoding="utf-8").read(), "README.ja.md does not name the Japanese Delete")
elif what == "check-mark":
    need(re.search(r"\\2713|\u2713", rule(sheet, r'\.pick button\[aria-pressed="true"\]::before')), "the pressed choice shows no check mark")
    need("background" in rule(sheet, r'\[data-choice="del"\]') and "background" in rule(sheet, r'\[data-choice="keep"\]'), "a chosen row has no background")
    need(re.search(r'setAttribute\("data-choice"', js), "a row does not carry its choice")
elif what == "group":
    pick = body(js, "pickButtons")
    need('setAttribute("role", "group")' in pick and re.search(r'setAttribute\("aria-label", [^;]*title\(g\)', pick), "the pair of choice buttons is not a named group")
elif what == "dialog-close":
    for d in re.findall(r"<dialog.*?</dialog>", sheet, re.S):
        need(re.search(r'<button[^>]*class="close"[^>]*data-i18n-aria="close"[^>]*>(&times;|\u00d7)</button>', d), "a dialog has no corner x")
    need('data-i18n="close"' not in sheet, "a dialog still has a text close button")
    c = rule(sheet, r"^dialog \.close$")
    need("position: absolute" in c and "top:" in c and "right:" in c, "the close button is not in the corner")
elif what == "round":
    need('data-round="__ROUND__"' in sheet, "the template has no place for the round")
    need("staleStores(" in js and "storeName(" in js, "the page does not keep its choices per round")
elif what == "save-state":
    need(re.search(r'id="save-state"[^>]*role="status"', sheet), "no save state at the top right")
    need('addEventListener("beforeunload"' in js, "leaving the page never asks")
    for lang, d in (("en", en), ("ja", ja)):
        need(d.get("saved") and d.get("notSaved"), "%s: no words for the save state" % lang)
elif what == "docs-storage":
    for f in ("README.md", "README.ja.md", "docs/how-it-works.md", "docs/how-it-works.ja.md"):
        text = open(plugin + "/" + f, encoding="utf-8").read()
        need("account-cleanup-choice" in text and "account-cleanup-memo" in text, "%s does not describe the choice and memo storage" % f)
elif what == "memo-width":
    need("max-width: 720px" in rule(sheet, r"^\.memo$"), "the memo field can grow past 720px")
elif what == "memo-label":
    need(en.get("memoLabel") == "Memo" and ja.get("memoLabel") == "\u30e1\u30e2", "the memo is not labelled Memo")
    need(en.get("memoHint") and ja.get("memoHint"), "no hint between the memo label and the field")
    need('"aria-describedby"' in body(js, "renderDetail"), "the memo field does not point at its hint")
    need("memoPlaceholder" not in sheet, "the memo still has a placeholder")
elif what == "copy-none":
    copy = body(js, "copyChosen")
    need(copy and "clipboard" in copy and "return;" in copy[:copy.index("clipboard")], "the copy button copies even when nothing is marked Delete")
elif what == "review":
    need(re.search(r'<section [^>]*id="review"[^>]*aria-labelledby="review-title"', sheet) and 'id="review-list"' in sheet, "no review that lists the accounts to delete")
    need("cannot be undone" in en.get("reviewWarn", "") and "\u623b\u305b\u307e\u305b\u3093" in ja.get("reviewWarn", ""), "the review does not warn that it cannot be undone")
elif what == "review-text":
    need(re.search(r'<label for="review-text"', sheet) and re.search(r'<textarea id="review-text"[^>]*readonly', sheet), "the text to paste is not in a labelled read-only box")
    need('id="fallback"' not in sheet, "the dialog for a failed copy is still there")
    need(en.get("reviewManual") and ja.get("reviewManual"), "the review does not say how to copy by hand")
elif what == "status":
    need(re.search(r'<p id="copy-status" role="status"', sheet), "no status line beside the copy button")
    need('id="toast"' not in sheet and not re.search(r'id="detail"[^>]*aria-live', sheet), "the toast or the live details are still there")
    need("clearStatus()" in body(js, "choose"), "a new choice does not clear the status line")
elif what == "bar-480":
    need(any(".bar div" in s and "flex-direction: column" in d for m, s, d in rules(sheet) if "max-width: 479px" in m), "the bottom bar does not stack below 480px")
    need(any(".bar button" in s and "width: 100%" in d for m, s, d in rules(sheet) if "max-width: 479px" in m), "the copy button does not fill the width below 480px")
elif what == "warning":
    need(re.search(r'</ol>\s*<p class="warn"[^>]*data-i18n="warn"', sheet), "no warning under the steps")
    need("cannot be restored" in en.get("warn", "") and "\u623b\u305b\u307e\u305b\u3093" in ja.get("warn", ""), "the warning does not say deleted accounts cannot be restored")
elif what == "empty":
    for lang, d in (("en", en), ("ja", ja)):
        need(d.get("emptyCategory") and d.get("emptySheet"), "%s: no words for an empty category or sheet" % lang)
    # The toolbar alone, or the whole part that holds the list and the toolbar
    need(re.search(r'(toolbar|"sheet)"\)\.hidden = true', js) and 't("emptySheet")' in js, "an empty sheet keeps its list and toolbar")
elif what == "no-match":
    for lang, d in (("en", en), ("ja", ja)):
        need("{q}" in d.get("noMatch", "") and d.get("clearFilters"), "%s: no words for a search with no match" % lang)
    # Either both places name the words, or both build the same empty line that does
    both = js.count('t("noMatch")') >= 2 or ('t("noMatch")' in body(js, "emptyLine") and "emptyLine(" in body(js, "renderRows") and "emptyLine(" in body(js, "renderDetail"))
    need(both and 'state.q = ""' in js, "the list and the details do not both say what was searched, or nothing clears it")
elif what == "broken":
    need(re.search(r'try \{\s*data = JSON\.parse\(document\.getElementById\("data"\)', js) and "showBroken()" in js, "unreadable data is not caught")
    need(en.get("broken") and ja.get("broken"), "no words for unreadable data")
elif what == "line-contrast":
    for name, page in (("sheet", sheet), ("follow-up page", followups)):
        for theme, v in zip(("light", "dark"), theme_vars(page)):
            for bg in ("--bg", "--panel"):
                r = ratio(v["--line"], v[bg])
                need(r >= 3, "%s %s: --line against %s is %.2f to 1" % (name, theme, bg, r))
    need(all("--selected" in v for v in theme_vars(sheet)), "the sheet has no --selected in both themes")
elif what == "chip-icon":
    need(re.search(r'aria-hidden', body(js, "statusChip")), "a status chip has no icon before its text")
    need(not re.search(r'el\("span", "chip[ "]', body(js, "rowChips")), "a status chip is built without its icon")
elif what == "colors":
    for var in ("--del", "--keep"):
        users = [s for m, s, d in rules(sheet) if "var(%s)" % var in d]
        need(users, "no %s color" % var)
        need(all('aria-pressed="true"' in s or "data-choice" in s for s in users), "%s is used for something other than the choice: %s" % (var, users))
    need(not any(s.startswith(".diff") and "color" in d for m, s, d in rules(sheet)), "the deletion effort still has a color")
    need(not re.search(r"--(easy|medium|hard|impossible|unknown|ok|ng)\b", style(sheet)), "the old color variables are still there")
elif what == "skill-label":
    need("one or two words" in open(plugin + "/skills/account-cleanup/SKILL.md", encoding="utf-8").read(), "SKILL.md does not keep the last-round label to one or two words")
elif what.startswith("followups-"):
    page = open(built, encoding="utf-8").read() if built else ""
    rows = re.findall(r"<tbody>(.*?)</tbody>", page, re.S)
    rows = re.findall(r"<tr>(.*?)</tr>", rows[0], re.S) if rows else []
    if what == "followups-title":
        need(re.search(r'<h1 id="heading"[^>]*>Things to clean up later</h1>', followups) and "{n}" not in followups, "the title still holds the count")
        facts = re.search(r'<table class="facts">(.*?)</table>', page, re.S)
        need(facts and re.search(r">3<", facts.group(1)) and "2026-11-22" in facts.group(1), "no facts table with the count and the date")
    elif what == "followups-table":
        need(re.search(r'<table [^>]*aria-labelledby="heading"', page) or "<caption" in page, "the table has no name")
        need(page.count('<th scope="col"') == 3, "the column headers have no scope")
        need("border-bottom: 2px" in rule(followups, r"^thead th$"), "the line under the header row is not 2px")
    elif what == "followups-sticky":
        t = rule(followups, r"^thead th$")
        need("position: sticky" in t and "top: 0" in t, "the header row does not stay on top")
    elif what == "followups-columns":
        head = re.findall(r'<th scope="col" data-i18n="(\w+)"', followups)
        need(head == ["colService", "colLeft", "colDate"], "the columns are %s" % head)
        need(rows and all(r.lstrip().startswith('<th scope="row">') for r in rows), "the service is not a row header")
    elif what == "followups-width":
        need("width: 100%" not in rule(followups, r"^table$"), "the table fills the width")
        need("padding: 8px 12px" in rule(followups, r"^th, td$"), "the cells are not 8px by 12px")
    elif what == "followups-newest":
        dates = [re.findall(r"(\d{4}-\d\d-\d\d)", r)[-1] for r in rows]
        need(len(dates) == 3 and dates == sorted(dates, reverse=True), "the records are in the order %s" % dates)
    elif what == "followups-phone":
        need(any("display: none" in d and ("table" in s or ".wrap" in s) for m, s, d in rules(followups) if "max-width: 599px" in m), "the table stays below 600px")
        cards = re.findall(r'<li class="card">(.*?)</li>', page, re.S)
        need(len(cards) == 3 and all(re.search(r"<h2", c) and "<dl" in c for c in cards), "no heading and value pairs for each record")
    elif what == "followups-empty":
        need('class="empty"' in page and "<thead" not in page, "an empty list still shows a table")
else:
    fail("unknown check " + what)
PY
pattern() { python3 "$T/patterns.py" "$1" "$TEMPLATE" "$FOLLOWUPS_TEMPLATE" "$PLUGIN" "${2:-}"; }

# sheet_js <functions> <code>: runs the named functions of the sheet in Node, with the page's dictionary
# and stand-ins for its state, and prints what <code> logs. A name ending in ? is taken only when it exists.
sheet_js() {
  python3 - "$TEMPLATE" "$1" "$2" <<'PY' | "$NODE" -
import re, sys
page, names, code = open(sys.argv[1], encoding="utf-8").read(), sys.argv[2].split(), sys.argv[3]
js = "\n".join(re.findall(r"<script>(.*?)</script>", page, re.S))
def body(name):
    m = re.search(r"^( *)function %s\(.*$" % re.escape(name), js, re.M)
    if not m:
        return None
    line = m.group(0)
    if line.count("{") and line.count("{") == line.count("}"):
        return line + "\n"
    end = re.search(r"^%s\}" % m.group(1), js[m.end():], re.M)
    return js[m.start():m.end() + end.end()] + "\n"
words = re.search(r"^  var I18N = (\{.*?^  \});", js, re.S | re.M)
out = ["var I18N = %s;" % (words.group(1) if words else "{en: {}, ja: {}}"),
       'var lang = "en", PAGE = 50, data = [], picks = {}, memos = {}, prevRound = 0, SOURCE = {};',
       'var STORE = "account-cleanup-choice", MEMO_STORE = "account-cleanup-memo";',
       'var state = { tab: "cand", q: "", f: "all", page: 1, sel: null };',
       'var sorts = { prev: "prev", cand: "old", rest: "old", all: "old" };',
       # Text outside ASCII is printed as \u escapes, so this file holds no Japanese letters
       r'function ascii(s) { return String(s).replace(/[\u0080-\uffff]/g, function (c) { return "\\u" + ("000" + c.charCodeAt(0).toString(16)).slice(-4); }); }']
for name in ["t?", "fill?", "label?"] + names:
    optional = name.endswith("?")
    found = body(name.rstrip("?"))
    if found is None and not optional:
        print('console.log("the page has no function %s");' % name)
        sys.exit(0)
    out.append(found or "")
print("\n".join(out) + "\n" + code)
PY
}
# js_is <functions> <code> <expected>: sheet_js, compared with what it should print
js_is() {
  local got
  [ -n "$NODE" ] || { echo "      node is not installed"; return 1; }
  got="$(sheet_js "$1" "$2" 2>&1)"
  [ "$got" = "$3" ] || { printf '      printed %s\n' "$got" | head -4; return 1; }
}

# The round mark a built sheet carries
round_of() { python3 -c 'import re, sys; m = re.search(r"data-round=\"([0-9a-f]{8,})\"", open(sys.argv[1], encoding="utf-8").read()); print(m.group(1) if m else "")' "$1"; }
rounds_apart() {
  local R="$T/round" a b c
  ( export ACCOUNT_CLEANUP_HOME="$R"; "$S/prepare.sh" --sources 1password >/dev/null 2>&1 ) || return 1
  a="$(round_of "$R/sheet.html")"
  ( export ACCOUNT_CLEANUP_HOME="$R"; "$S/prepare.sh" --rebuild >/dev/null 2>&1 ) || return 1
  b="$(round_of "$R/sheet.html")"
  ( export ACCOUNT_CLEANUP_HOME="$R"; "$S/prepare.sh" --sources 1password >/dev/null 2>&1 ) || return 1
  c="$(round_of "$R/sheet.html")"
  [ -n "$a" ] && [ "$a" = "$b" ] && [ "$a" != "$c" ] || { echo "      round marks after collecting, rebuilding, and collecting again: '$a' '$b' '$c'"; return 1; }
}

# A follow-up page built from three records, out of date order, and one built from none
FU="$T/followups-patterns"
followup_page() { # <records> <page copy>
  rm -rf "$FU" && mkdir -p "$FU" && chmod 700 "$FU" && printf '%b' "$1" > "$FU/followups.tsv" &&
    ACCOUNT_CLEANUP_HOME="$FU" ACCOUNT_CLEANUP_TODAY=2026-11-22 "$S/followup.sh" page >/dev/null 2>&1 && cp "$FU/followups.html" "$2"
}
followup_page '2026-01-02\told.example\tA gift card balance is left\tOld shop\n2026-03-04\tnew.example\tA card is still saved\tNew shop\n2026-02-01\tmid.example\tSend the erasure request\t\n' "$T/followups-three.html"
followup_page '' "$T/followups-none.html"

SELECTION_JS='data = [{ key: "a.example" }, { key: "b.example" }, { key: "c.example" }];
picks = { "a.example": "ok", "b.example": "ng", "c.example": "ok" };'
check "the details panel is a section named by its focusable heading" 'pattern detail'
check "the sheet puts the list and the details in a .split container" 'pattern split'
check "the details change with a short motion that reduced motion turns off" 'pattern motion'
check "the list is a ul whose rows hold a name button and mark only the shown row current" 'pattern list'
check "on load the sheet opens the item in the hash, else the first, and only on a wide screen" \
  'pattern load && js_is "initialKey itemId" "console.log([initialKey(\"#\" + itemId(\"b.example\"), [\"a.example\", \"b.example\"], true), initialKey(\"#item-zz\", [\"a.example\", \"b.example\"], true), initialKey(\"\", [\"a.example\", \"b.example\"], true), String(initialKey(\"#\" + itemId(\"b.example\"), [\"a.example\", \"b.example\"], false)), String(initialKey(\"\", [], true))].join(\"|\"));" "b.example|a.example|a.example|null|null"'
check "the list and the details scroll apart, vertically only, with the name and choice buttons kept on top" 'pattern scroll'
check "choosing updates only that row and keeps the focus on the pressed button" 'pattern choose'
check "the memo keeps what was typed and is trimmed only in the copied text" \
  'pattern memo-raw && js_is "selectionText memoText" "$SELECTION_JS memos = { \"a.example\": \"  keep\\tthe photos\\n \" }; console.log(JSON.stringify(selectionText()));" "\"account-cleanup selection\\na.example\\tkeep the photos\\nc.example\\n\""'
check "on a narrow screen the sheet shows the list or the details and moves the focus to the heading" 'pattern narrow'
check "the details have a back button and previous and next buttons, and back returns the focus to the row" \
  'pattern back && js_is neighbors "var k = [\"a\", \"b\", \"c\"]; console.log([neighbors(k, \"a\"), neighbors(k, \"b\"), neighbors(k, \"c\")].map(function (n) { return n.prev + \">\" + n.next; }).join(\"|\"));" "null>b|a>c|b>null"'
HASH_JS='data = [{ key: "P", service: "P", updated: "2020-01-01", previous: { label: "exchange" } }];
for (var i = 0; i < 60; i++) data.push({ key: "k" + (i < 10 ? "0" : "") + i, service: "k" + i, updated: (2000 + i) + "-01-01", reasons: ["stale"] });
function at(k) { var p = placeOf(k); return p.tab + " " + p.page; }
console.log([itemId("name:Task board"), at("k55"), at("k03"), at("P")].join("|"));'
check "the hash names the open item and opening a hash moves to its category and page" \
  'pattern hash && js_is "itemId placeOf categoryList? useTabs tabOf hasPrev isCandidate compareRows title" "$HASH_JS" "item-name%3ATask%20board|cand 2|cand 1|prev 1"'
check "closing a dialog returns the focus to where it was" 'pattern dialog-focus'
check "the sheet shows only non-empty category tabs and never a single tab or an all tab" \
  'pattern no-all-tab && js_is shownTabs "console.log([shownTabs({ prev: 0, cand: 3, rest: 0 }), shownTabs({ prev: 2, cand: 3, rest: 0 }), shownTabs({ prev: 1, cand: 1, rest: 1 })].map(JSON.stringify).join(\"|\"));" "[]|[\"prev\",\"cand\"]|[\"prev\",\"cand\",\"rest\"]"'
check "with 50 candidates or fewer the categories are filter buttons instead of tabs" \
  'pattern category-filter && js_is useTabs "console.log([useTabs(50), useTabs(51)].join(\"|\"));" "false|true"'
SEARCH_JS='data = [{ key: "one.example", service: "Shop One", reasons: ["stale"], updated: "2020-01-01" },
  { key: "two.example", service: "Shop Two", reasons: [], updated: "2021-01-01" },
  { key: "three.example", service: "Other", reasons: ["stale"], updated: "2022-01-01" }];
var a = visible().map(title).join(","); state.q = "shop"; console.log(a + "|" + visible().map(title).join(","));'
check "a search looks in every category and names the category on each row" \
  'pattern search-chip && js_is "visible categoryList? tabOf hasPrev isCandidate compareRows title" "$SEARCH_JS" "Shop One,Other|Shop One,Shop Two"'
check "each category name is a noun of one or two words in both languages" \
  'js_is "" "var w = function (s) { return s.trim().split(/\\s+/).length; }; console.log([\"tabPrev\", \"tabCand\", \"tabRest\"].every(function (k) { return I18N.en[k] && w(I18N.en[k]) <= 2 && I18N.ja[k] && I18N.ja[k].length <= 8 && I18N.ja[k].indexOf(\"\\u3001\") < 0; }) && !(\"tabPrevRound\" in I18N.en));" "true"'
check "the tabs stay on one row that scrolls sideways to the chosen tab" 'pattern tabs-row'
check "the tabs have tab roles and move with the arrow, Home, and End keys" 'pattern tab-roles'
check "search and sort have visible labels and no placeholder, and filter buttons show counts" 'pattern labels'
check "rows with the same date are sorted by name" \
  'js_is "compareRows title" "var r = [{ key: \"b.example\", service: \"Beta\", updated: \"2024-01-01\" }, { key: \"c.example\", service: \"Cat\", updated: \"2023-01-01\" }, { key: \"a.example\", service: \"Alpha\", updated: \"2024-01-01\" }]; function by(s) { return r.slice().sort(function (x, y) { return compareRows(x, y, s); }).map(title).join(\",\"); } console.log(by(\"old\") + \"|\" + by(\"new\"));" "Cat,Alpha,Beta|Alpha,Beta,Cat"'
check "the pager is a named nav with 40px buttons that moves the focus to the list heading" 'pattern pager-nav'
check "the sheet shows the total and the shown range above the pager" \
  'pattern range && js_is rangeText "var o = [rangeText(1, 230), rangeText(5, 230), rangeText(1, 12)]; lang = \"ja\"; o.push(rangeText(2, 230)); console.log(ascii(o.join(\"|\")));" "Showing 1\u201350 of 230|Showing 201\u2013230 of 230|Showing 1\u201312 of 12|230\u4ef6\u4e2d51\u301c100\u4ef6\u76ee"'
check "the pager names previous and next, leaves out the end it cannot go to, and shows at most five numbers on a phone" \
  'pattern pager-phone && js_is pagerItems "console.log([pagerItems(1, 1, 7), pagerItems(1, 3, 7), pagerItems(2, 3, 7), pagerItems(3, 3, 7), pagerItems(6, 12, 5), pagerItems(1, 12, 5), pagerItems(12, 12, 5)].map(function (x) { return x.join(\" \"); }).join(\"|\"));" "|1 2 3 next|prev 1 2 3 next|prev 1 2 3|prev 4 5 6 7 8 next|1 2 3 4 5 next|prev 8 9 10 11 12"'
check "the choice buttons are Delete and Keep and the page uses the same words everywhere" 'pattern words'
check "SKILL.md, the READMEs, the manifest, and the evals call the choices Delete and Keep" 'pattern docs-words'
check "the pressed choice shows a check mark and the chosen row a selected background" 'pattern check-mark'
check "each pair of choice buttons is a group named after the service" 'pattern group'
check "the tally says nothing is chosen yet when nothing is chosen" \
  'js_is tallyText "var o = []; [\"en\", \"ja\"].forEach(function (l) { lang = l; o.push(tallyText(0, 0), tallyText(3, 2)); }); console.log(ascii(o.join(\"|\")));" "Nothing chosen yet|Delete 3, Keep 2|\u307e\u3060\u9078\u3093\u3067\u3044\u307e\u305b\u3093|\u6d88\u30593\u4ef6\u3001\u6b8b\u30592\u4ef6"'
check "dialogs close with an x in the corner" 'pattern dialog-close'
check "choices and memos are stored per round and other rounds' entries are removed" \
  'pattern round && js_is "storeName staleStores" "console.log(storeName(\"account-cleanup-choice\", \"r2\") + \"|\" + staleStores([\"account-cleanup-choice\", \"account-cleanup-choice-r1\", \"account-cleanup-memo-r1\", \"account-cleanup-choice-r2\", \"account-cleanup-memo-r2\", \"account-cleanup-lang\", \"account-cleanup-theme\", \"other\"], \"r2\").join(\" \"));" "account-cleanup-choice-r2|account-cleanup-choice account-cleanup-choice-r1 account-cleanup-memo-r1" && rounds_apart'
check "the sheet shows whether choices are saved and asks before leaving only when work would be lost" 'pattern save-state'
check "the README and how-it-works describe the choice and memo storage in both languages" 'pattern docs-storage'
check "the memo field is at most 720px wide" 'pattern memo-width'
check "the memo is labelled Memo with a hint that only rows to delete carry it, and no placeholder" 'pattern memo-label'
check "with nothing to delete the copy button copies nothing and says why" \
  'pattern copy-none && js_is copyStatus "lang = \"en\"; var a = copyStatus(0), b = copyStatus(12); lang = \"ja\"; var c = copyStatus(0), d = copyStatus(12); console.log([/nothing/i.test(a) && !/\\d/.test(a), /\\b12\\b/.test(b), /\u30b3\u30d4\u30fc\u3057\u3066\u3044\u307e\u305b\u3093/.test(c) && !/\\d/.test(c), /12\u4ef6/.test(d)].join(\",\"));" "true,true,true,true"'
check "copying opens a review that names every account to delete and warns it cannot be undone" \
  'pattern review && js_is reviewTitle "var o = [reviewTitle(1), reviewTitle(12)]; lang = \"ja\"; o.push(reviewTitle(12)); console.log(ascii(o.join(\"|\")));" "Delete 1 account|Delete 12 accounts|12\u4ef6\u306e\u30a2\u30ab\u30a6\u30f3\u30c8\u3092\u6d88\u3059"'
check "the review shows the text in a labelled read-only box with how to copy it by hand" 'pattern review-text'
check "the copy result is a status line with the count that clears on change, with no toast or live details" 'pattern status'
check "below 480px the bottom bar stacks and the button fills the width" 'pattern bar-480'
check "a warning under the steps says deleted accounts cannot be restored" 'pattern warning'
check "an empty category says why and an empty sheet replaces the list and toolbar" 'pattern empty'
check "a search with no match names the words and offers to clear the filters" 'pattern no-match'
check "unreadable data replaces the page with a message to rebuild it" 'pattern broken'
check "the line color has 3 to 1 contrast in both themes and the sheet defines --selected" 'pattern line-contrast'
check "each status chip has an icon before its text" 'pattern chip-icon'
check "each color has one meaning and the deletion effort has no color" 'pattern colors'
EFFORT_JS='var g = [{ deletion: { difficulty: "easy" } }, { deletion: { difficulty: "medium" } }, { deletion: { difficulty: "hard" } },
  { deletion: { difficulty: "impossible" } }, { deletion: { difficulty: "limited" } }, { deletion: { difficulty: "unknown" } },
  { needs_search: true, deletion: { difficulty: "easy" } }, {}, { deletion: { difficulty: "ended" } }, { alive: false, deletion: { difficulty: "easy" } }];
var w = function (s) { return s.trim().split(/\s+/).length; }, en = I18N.en, ja = I18N.ja;
var chips = ["chipOk", "chipNg", "chipGone", "chipMemo"].every(function (k) { return en[k] && w(en[k]) <= 2 && ja[k]; });
var levels = Object.keys(en.effort || {}).join(" ") + "/" + Object.keys(ja.effort || {}).join(" ");
var short = Object.keys(en.effort || {}).every(function (k) { return w(en.effort[k]) <= 2; });
console.log(g.map(effortLevel).join(" ") + "|" + chips + "|" + levels + "|" + short);'
check "chip names have at most two words and the deletion effort has at most five levels" \
  'pattern skill-label && js_is effortLevel "$EFFORT_JS" "easy steps request request request unknown unknown unknown nothing nothing|true|easy steps request unknown nothing/easy steps request unknown nothing|true"'
check "the follow-up page has a plain title and a facts table with the count and date" 'pattern followups-title "$T/followups-three.html"'
check "the follow-up table has a name, column headers with scope, and a 2px header line" 'pattern followups-table "$T/followups-three.html"'
check "the follow-up table keeps its header row on top" 'pattern followups-sticky "$T/followups-three.html"'
check "the follow-up table starts with the service as a row header" 'pattern followups-columns "$T/followups-three.html"'
check "the follow-up table is as wide as its content with 8px by 12px cells" 'pattern followups-width "$T/followups-three.html"'
check "the follow-up page lists the newest record first" 'pattern followups-newest "$T/followups-three.html"'
check "below 600px the follow-up page shows each record as a heading and value pairs" 'pattern followups-phone "$T/followups-three.html"'
check "an empty follow-up page shows a sentence instead of a table" 'pattern followups-empty "$T/followups-none.html"'
check "the changelog names the new sheet behavior under Unreleased" 'grep -qF "Delete and Keep buttons" "$PLUGIN/CHANGELOG.md"'
check "the copied text keeps its fixed first line and one key per line in either language" \
  'js_is "selectionText memoText?" "$SELECTION_JS memos = { \"a.example\": \"photos first\" }; var o = []; [\"en\", \"ja\"].forEach(function (l) { lang = l; o.push(JSON.stringify(selectionText())); }); console.log(o.join(\"|\"));" "\"account-cleanup selection\\na.example\\tphotos first\\nc.example\\n\"|\"account-cleanup selection\\na.example\\tphotos first\\nc.example\\n\""'

printf '\n%d passed, %d failed (%d ran, %d skipped)\n' "$PASS" "$FAIL" "$((PASS + FAIL))" "$SKIP"
[ "$FAIL" = 0 ]
