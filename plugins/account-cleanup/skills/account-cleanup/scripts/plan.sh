#!/bin/bash
# Take the selection pasted from the candidate sheet (the accounts marked OK) and print the steps for those accounts only.
# The selection's first line is `account-cleanup selection`; each following line is a group key (domain),
# optionally followed by a tab and the user's memo.
# For every account it prints, before the deletion page, a row to check the billing page for a paid plan and cancel it,
# and a row to remove saved cards and bank accounts.
# Accounts whose site cannot be found, and accounts whose deletion page has difficulty ended (service shut down),
# can be neither deleted nor cancelled, so only the password manager cleanup is printed for them.
# Accounts whose service is listed as impossible to delete get an erasure request, picked by the region
# that prepare.sh --region saved (eu and uk: GDPR; california: CCPA/CPRA; japan: APPI; other or unset: GDPR with a note).
# The groups are matched again here, so deletion pages added with add-site.sh after prepare.sh are used.
#
# Usage: plan.sh [matched.json] < pasted selection

. "$(dirname "$0")/common.sh"
need jq "Install jq."

src=${1:-$MATCHED_FILE}
if [ ! -f "$src" ]; then
  echo "account-cleanup: no matched candidates: $src" >&2
  exit 2
fi

selection=$(sed -e 's/^[[:space:]]*[-*][[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^account-cleanup selection$' | grep -v '^$' || true)
if [ -z "$selection" ]; then
  echo "account-cleanup: no accounts were selected." >&2
  exit 2
fi

region=$(cat "$REGION_FILE" 2>/dev/null || true)
note=""
case "$region" in
  eu|uk) template=gdpr; law="GDPR Article 17" ;;
  california) template=ccpa; law="CCPA/CPRA, California Civil Code §1798.105" ;;
  japan) template=appi; law="Japan APPI Article 35" ;;
  other)
    template=gdpr; law="GDPR-style text"
    note="The user lives outside the EU, the UK, California and Japan. Before showing this request, replace the GDPR citation with the data protection law that applies where the user lives. If you cannot identify one with confidence, tell the user and remove the citation rather than guess." ;;
  *)
    template=gdpr; law="GDPR-style text"
    note="No region was saved. Ask where the user lives and save it with prepare.sh --rebuild --region <eu|uk|california|japan|other>, then run plan.sh again." ;;
esac

ensure_data_dir
rematched=$(mktemp "$DATA_DIR/plan.XXXXXX")
trap 'rm -f "$rematched"' EXIT
"$SCRIPT_DIR/match.sh" < "$src" > "$rematched"

printf '%s\n' "$selection" | jq -R . | jq -s -r --slurpfile m "$rematched" \
  --rawfile tmpl "$SKILL_DIR/templates/erasure-request-$template.md" --arg law "$law" --arg note "$note" '
  def difflabel: {easy: "easy", medium: "medium", hard: "hard", impossible: "impossible (send the erasure request below)", limited: "limited (only some data can be deleted)", unknown: "unknown", ended: "service ended"}[.] // .;
  def source_name: {"1password": "1Password", bitwarden: "Bitwarden", chrome: "Chrome", dia: "Dia", arc: "Arc", brave: "Brave", edge: "Edge", manual: "added by hand"}[.] // .;
  def has_reason($r): (.reasons // []) | index($r) != null;
  def billing_rows:
    "| Cancel (before deleting) | After signing in, open the service settings for \"Billing\", \"Plan\" or \"Subscription\" and cancel any paid plan that is still active |\n"
    + "| Payment methods | Before deleting, remove saved cards and bank accounts on the \"Payment methods\" page. If one cannot be removed, record it with followup.sh add and show the user at the end |\n"
    + "| If billed through the App Store | Cancel at https://apps.apple.com/account/subscriptions (deleting the account on the service does not stop it) |\n"
    + "| If billed through Google Play | Cancel at https://play.google.com/store/account/subscriptions (deleting the account on the service does not stop it) |\n"
    + "| If billed through PayPal | Stop the automatic payment at https://www.paypal.com/myaccount/autopay/ |\n";
  map(split("\t") | {k: (.[0] | gsub("^\\s+|\\s+$"; "")), memo: ((.[1:] | join(" ")) | gsub("^\\s+|\\s+$"; ""))} | select(.k != "")) as $lines
  | ($lines | map(.k)) as $keys
  | ($lines | map(select(.memo != "") | {(.k): .memo}) | add // {}) as $memos
  | ($m[0] | map({(.key): .}) | add // {}) as $by
  | ($keys | map(select($by[.] == null))) as $missing
  | ($keys | map(select($by[.] != null)) | map($by[.])) as $picked
  | (if ($missing | length) > 0 then "Keys not in the candidates: " + ($missing | join(" ")) + "\n\n" else "" end)
  + ($picked | to_entries | map(
      .value as $g
      | ($g.service // $g.names[0] // $g.key) as $name
      | "## " + (.key + 1 | tostring) + ". " + $name + " (" + $g.key + ")\n\n"
      + (if $g.description then $g.description + "\n\n" else "" end)
      + "| Item | Details |\n|---|---|\n"
      + (if $memos[$g.key] then "| Your memo | " + ($memos[$g.key] | gsub("\\|"; "/")) + " |\n" else "" end)
      + (if ($g | has_reason("browser-extension")) then
           "| Deletion | Not needed: this is a browser extension. Have the user confirm no assets remain in its wallet, then clean up the password manager items |\n"
         elif ($g | has_reason("broken-url")) then
           "| Deletion | Not needed: the URL is broken, so the site cannot be identified. Check the item name; if it is not needed, clean up the password manager items |\n"
         elif ($g | has_reason("dev-address")) then
           "| Deletion | Not needed: a development address, not an account. Only clean up the password manager items |\n"
         elif $g.alive == false then
           "| Deletion | Not needed: the site cannot be found. Only clean up the password manager items |\n"
         elif $g.deletion.difficulty == "ended" then
           "| Deletion | Not needed: the service has shut down. Only clean up the password manager items |\n"
           + (if $g.deletion.notes then "| Shutdown notice | " + $g.deletion.url + " (" + ($g.deletion.notes | gsub("\n"; " ")) + ") |\n" else "| Shutdown notice | " + $g.deletion.url + " |\n" end)
         else
           billing_rows
           + (if $g.deletion then
                "| Deletion page | " + $g.deletion.url + " |\n"
                + "| Effort | " + ($g.deletion.difficulty | difflabel) + " |\n"
                + (if $g.deletion.notes then "| Steps | " + ($g.deletion.notes | gsub("\n"; " ")) + " |\n" else "" end)
                + (if $g.deletion.email then "| Email to request deletion | " + $g.deletion.email + " |\n" else "" end)
              else
                "| Deletion page | Unknown. Search for it by the service name, add it with add-site.sh, then run plan.sh again |\n"
              end)
         end)
      + "| Password manager items | " + ($g.sources | map((.source | source_name) + (if (.id // "") != "" then " " + .id else "" end)) | join(", ")) + " |\n"
      + (if ($g.deletion.difficulty // "") == "impossible" and $g.alive != false then
           "\nErasure request (" + $law + ")\n\n"
           + (if $note != "" then "Note for the agent: " + $note + "\n\n" else "" end)
           + "```\n" + ($tmpl | gsub("[{][{]service[}][}]"; $name)) + "```\n"
         else "" end)
    ) | join("\n"))'
