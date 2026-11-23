#!/usr/bin/env bash
# Tests for docs_publish.py in throwaway folders under a throwaway HOME. Nothing reaches the network.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../scripts/docs_publish.py"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }

# changelog_entries <changelog>: the entries from ## [Unreleased] down to the link definitions. A
# release moves a line from Unreleased into its version's section, where it stays, so a check that
# looks for a line reads every section.
changelog_entries() { awk '/^## \[Unreleased\]/ { on = 1 } on && /^\[[^]]+\]: / { exit } on' "$1"; }

export HOME="$T/home"
export PYTHONDONTWRITEBYTECODE=1
mkdir -p "$HOME"

dp() { python3 "$SCRIPT" "$@"; }
tree_sum() { (cd "$1" && find . -type f | LC_ALL=C sort | xargs shasum -a 256); }

cat > "$T/plan.json" <<'JSON'
{"project": "Acme Shop",
 "languages": [{"code": "en", "name": "English"}, {"code": "de", "name": "Deutsch"}],
 "concepts": [{"slug": "carts", "title": "Carts"}],
 "api": [{"slug": "createCart.md", "title": "createCart"}],
 "cookbook": [{"slug": "apply-a-coupon", "title": "Apply a coupon"}]}
JSON
PAGES="README.md quickstart.md concepts/README.md concepts/carts.md api/README.md api/createCart.md cookbook/README.md cookbook/apply-a-coupon.md faq.md"

# --- scaffold
mkdir -p "$T/dry"
out="$(cd "$T/dry" && dp scaffold --dry-run "$T/plan.json")"; rc=$?
check "a dry run exits 0" '[ "$rc" = 0 ]'
check "a dry run writes nothing" '[ -z "$(ls -A "$T/dry")" ]'
check "a dry run lists 18 pages and the map" '[ "$(printf "%s\n" "$out" | grep -c "^new ")" = 19 ]'

mkdir -p "$T/s"
out="$(cd "$T/s" && dp scaffold "$T/plan.json")"; rc=$?
check "scaffold exits 0" '[ "$rc" = 0 ]'
missing=""
for lang in en de; do for p in $PAGES; do [ -f "$T/s/docs/$lang/$p" ] || missing="$missing $lang/$p"; done; done
check "scaffold writes every page in every language" '[ -z "$missing" ]'
check "a slug ending in .md is used without the extension" '[ -f "$T/s/docs/en/api/createCart.md" ] && [ ! -e "$T/s/docs/en/api/createCart.md.md" ]'
check "the map has version 2 and the source language first" \
  '[ "$(jq -r "[.version, (.languages | map(.code) | join(\",\"))] | join(\" \")" "$T/s/docs/_translation-map.json")" = "2 en,de" ]'
check "a plan without projects to follow keeps an empty list" '[ "$(jq -c .follow "$T/s/docs/_translation-map.json")" = "[]" ]'
check "the map lists the pages in reading order" \
  '[ "$(jq -r ".pages | map(.path) | join(\" \")" "$T/s/docs/_translation-map.json")" = "$PAGES" ]'
check "the source part index links every planned page" 'grep -qxF -- "- [Carts](carts.md)" "$T/s/docs/en/concepts/README.md"'
check "a starter page links its counterpart in the language switch" \
  'grep -qxF "English · [Deutsch](../../de/concepts/carts.md)" "$T/s/docs/en/concepts/carts.md"'
check "a translation starter names the source page" 'grep -qF "Translate en/api/createCart.md into Deutsch" "$T/s/docs/de/api/createCart.md"'
check "a starter page links back to its part index" 'grep -qxF -- "- [API reference](README.md)" "$T/s/docs/en/api/createCart.md"'
before="$(tree_sum "$T/s")"
(cd "$T/s" && dp scaffold "$T/plan.json") >/dev/null 2>"$T/err"; rc=$?
check "scaffold on laid-out docs exits 3 and changes nothing" \
  '[ "$rc" = 3 ] && [ "$before" = "$(tree_sum "$T/s")" ] && grep -q "already laid out" "$T/err"'

mkdir -p "$T/k/docs/en"
printf 'my own words\n' > "$T/k/docs/en/quickstart.md"
out="$(cd "$T/k" && dp scaffold "$T/plan.json")"
check "an existing page is kept as it is" '[ "$(cat "$T/k/docs/en/quickstart.md")" = "my own words" ]'
check "a kept page is reported as kept" 'printf "%s\n" "$out" | grep -q "^kept  docs/en/quickstart.md (it already exists)"'

# The plan gives the reading order, so each part keeps it instead of sorting its pages (#237).
jq '.concepts = [{"slug": "zebra", "title": "Zebra"}, {"slug": "apple", "title": "Apple"}, {"slug": "mango", "title": "Mango"}]' \
  "$T/plan.json" > "$T/order.json"
mkdir -p "$T/odry" "$T/o"
out="$(cd "$T/odry" && dp scaffold --dry-run "$T/order.json")"
check "the dry run lists each part's pages in the order of the plan" \
  '[ "$(printf "%s\n" "$out" | sed -n "s|^new   docs/en/concepts/||p" | paste -sd, -)" = "README.md,zebra.md,apple.md,mango.md" ]'
(cd "$T/o" && dp scaffold "$T/order.json") >/dev/null
check "scaffold lists each part's pages in the order of the plan" \
  '[ "$(grep "^- \[" "$T/o/docs/en/concepts/README.md" | paste -sd, -)" = "- [Zebra](zebra.md),- [Apple](apple.md),- [Mango](mango.md)" ]'

# HTTP endpoints and hosted services: an API page marked as an endpoint gets its own outline.
headings() { grep '^## ' "$1" | sed 's/^## //' | paste -sd, -; }
ENDPOINT_OUTLINE="Endpoint,Authentication,Parameters,Request body,Response,Errors,Example,Related"
SIGNATURE_OUTLINE="Signature,Parameters,Returns,Errors,Example,Related"
jq '.api = [{"slug": "create-cart", "title": "POST /v1/carts", "endpoint": true}, {"slug": "createCart", "title": "createCart", "endpoint": false}]' \
  "$T/plan.json" > "$T/endpoint.json"
mkdir -p "$T/e"
(cd "$T/e" && dp scaffold "$T/endpoint.json") >/dev/null 2>&1; rc=$?
endpoint_page="$T/e/docs/en/api/create-cart.md"
check "an endpoint page in the plan gets the endpoint outline" \
  '[ "$rc" = 0 ] && [ "$(headings "$endpoint_page")" = "$ENDPOINT_OUTLINE" ] && grep -q "method and the path" "$endpoint_page" && grep -q "status code" "$endpoint_page" && grep -q "complete request" "$endpoint_page" && [ "$(headings "$T/e/docs/en/api/createCart.md")" = "$SIGNATURE_OUTLINE" ] && grep -qF "Translate en/api/create-cart.md into Deutsch" "$T/e/docs/de/api/create-cart.md"'
check "a function page keeps the signature outline" \
  '[ "$(headings "$T/s/docs/en/api/createCart.md")" = "$SIGNATURE_OUTLINE" ] && grep -q "The signature exactly as the code declares it" "$T/s/docs/en/api/createCart.md"'
python3 - "$T/plan.json" "$T/badendpoint.json" <<'PY'
import json, sys
plan = json.load(open(sys.argv[1]))
plan["api"][0]["endpoint"] = "yes"
plan["concepts"][0]["endpoint"] = True
json.dump(plan, open(sys.argv[2], "w"))
PY
mkdir -p "$T/bade"
(cd "$T/bade" && dp scaffold "$T/badendpoint.json") >/dev/null 2>"$T/err"; rc=$?
check "a bad endpoint mark in the plan is refused" \
  '[ "$rc" = 2 ] && [ -z "$(ls -A "$T/bade")" ] && grep -q "api\[0\]: endpoint must be true or false" "$T/err" && grep -q "concepts\[0\]: only an API page can be an endpoint" "$T/err"'
qs="$T/s/docs/en/quickstart.md"
check "the quickstart starter page fits a service the reader signs up for" \
  'grep -q "install command" "$qs" && grep -qi "sign up" "$qs" && grep -q "account" "$qs" && grep -q "API key" "$qs" && grep -q "first request" "$qs" && [ "$(grep -c "docs-publish:todo" "$qs")" = 4 ]'

# Projects to follow: recorded from the plan, never fetched by the script.
FOLLOW='[{"name": "Sibling A", "url": "https://git.example.org/acme/sibling-a", "adopted": "One API page per function, with parameters, return value, and errors in that order"}, {"name": "Sibling B", "url": "https://docs.example.com/sibling-b/", "adopted": "A Cookbook page per task, named as the task"}]'
jq --argjson f "$FOLLOW" '. + {follow: $f}' "$T/plan.json" > "$T/follow.json"
mkdir -p "$T/fdry" "$T/f2"
out="$(cd "$T/fdry" && dp scaffold --dry-run "$T/follow.json")"; rc=$?
(cd "$T/f2" && dp scaffold "$T/follow.json") >/dev/null 2>&1
check "a plan with projects to follow is shown and kept in the map" \
  '[ "$rc" = 0 ] && printf "%s\n" "$out" | grep -qxF "follow Sibling A (https://git.example.org/acme/sibling-a): One API page per function, with parameters, return value, and errors in that order" && [ "$(jq -c .follow "$T/f2/docs/_translation-map.json")" = "$(jq -c .follow "$T/follow.json")" ]'
python3 - "$T/plan.json" "$T/badfollow.json" <<'PY'
import json, sys
plan = json.load(open(sys.argv[1]))
plan["follow"] = [{"name": "", "url": "http://plain.example.org", "adopted": ""}, "Sibling C",
                  {"name": "Sibling D", "url": "https://d.example.org", "adopted": "x" * 201}]
json.dump(plan, open(sys.argv[2], "w"))
PY
mkdir -p "$T/badf"
(cd "$T/badf" && dp scaffold "$T/badfollow.json") >/dev/null 2>"$T/err"; rc=$?
check "a plan with a bad project to follow is refused and names the entry" \
  '[ "$rc" = 2 ] && [ -z "$(ls -A "$T/badf")" ] && grep -q "follow\[0\]: give the project" "$T/err" && grep -q "follow\[0\]: url must start with https://" "$T/err" && grep -q "follow\[0\]: adopted must" "$T/err" && grep -q "follow\[1\]: list each project" "$T/err" && grep -q "follow\[2\]: adopted must" "$T/err"'

cat > "$T/bad.json" <<'JSON'
{"project": "Acme",
 "languages": [{"code": "EN", "name": "English"}, {"code": "de", "name": "Deutsch"}, {"code": "de", "name": "Deutsch"}],
 "concepts": [{"slug": "../escape", "title": "Escape"}, {"slug": "README", "title": "Index"}],
 "api": [],
 "cookbook": [{"slug": "a", "title": "A"}, {"slug": "a", "title": "Again"}, {"slug": "b", "title": "[b]"}]}
JSON
mkdir -p "$T/bad"
(cd "$T/bad" && dp scaffold "$T/bad.json") >/dev/null 2>"$T/err"; rc=$?
check "a bad plan exits 2 and writes nothing" '[ "$rc" = 2 ] && [ -z "$(ls -A "$T/bad")" ]'
check "every problem in the plan is listed at once" '[ "$(grep -c "^  " "$T/err")" = 7 ]'
check "a slug that climbs out of its folder is refused" 'grep -q "concepts\[0\]: slug must" "$T/err"'
check "a language listed twice is refused" 'grep -q "languages\[2\]: de is listed twice" "$T/err"'

printf '{"project": "Solo", "languages": [{"code": "en", "name": "English"}], "concepts": [{"slug": "a", "title": "A"}], "api": [{"slug": "b", "title": "B"}], "cookbook": [{"slug": "c", "title": "C"}]}\n' > "$T/solo.json"
mkdir -p "$T/solo"
(cd "$T/solo" && dp scaffold "$T/solo.json") >/dev/null
check "one language writes no language switch" '! grep -q "·" "$T/solo/docs/en/concepts/a.md"'
check "check names the single language" '(cd "$T/solo" && dp check) | head -1 | grep -qx "docs: 9 pages in en"'
(cd "$T/solo" && dp translated a.md) >/dev/null 2>&1; rc=$?
check "translated with one language exits 2" '[ "$rc" = 2 ]'

out="$(dp check --root "$T/s/docs")"; rc=$?
check "check on starter pages exits 1 and lists the to-do notes" \
  '[ "$rc" = 1 ] && printf "%s\n" "$out" | grep -q "^todo         en/quickstart.md has 4 to-do notes left"'
check "orphans are not reported while a language has to-do notes" '! printf "%s\n" "$out" | grep -q "^orphan"'
dp translated --root "$T/s/docs" faq.md >"$T/out" 2>&1; rc=$?
check "translated refuses a page whose source still has to-do notes" \
  '[ "$rc" = 1 ] && grep -q "not recorded  de/faq.md: en/faq.md still has to-do notes" "$T/out"'

# --- a finished set of pages in English and German
# page <path>: writes stdin to en/<path> and de/<path>, with @SWITCH@ replaced by the language switch.
page() {
  local path="$1" up="" n body
  n="$(printf '%s' "$path" | tr -cd '/' | wc -c | tr -d ' ')"
  for ((i = 0; i <= n; i++)); do up="../$up"; done
  body="$(cat)"
  printf '%s\n' "${body//@SWITCH@/English · [Deutsch](${up}de/$path)}" > "$D/en/$path"
  printf '%s\n' "${body//@SWITCH@/[English](${up}en/$path) · Deutsch}" > "$D/de/$path"
}

F="$T/fixture"
mkdir -p "$F"
(cd "$F" && dp scaffold "$T/plan.json") >/dev/null
D="$F/docs"
mkdir -p "$D/assets"
printf '<svg xmlns="http://www.w3.org/2000/svg"/>\n' > "$D/assets/coupon.svg"

page README.md <<'MD'
# Acme Shop documentation

@SWITCH@

Acme Shop keeps a shopping cart for a web store.

## Get started

- [Quickstart](quickstart.md)

## Concepts

- [Concepts](concepts/README.md)

## API reference

- [API reference](api/)

## Cookbook

- [Cookbook](cookbook/README.md)

## FAQ

- [FAQ](faq.md)
MD

page quickstart.md <<'MD'
# Quickstart

@SWITCH@

Install the library and create a cart.

## Install

```bash
npm install acme-shop
```

## First run

```js
import { createCart } from "acme-shop";
console.log(createCart().items.length);
```

It prints `0`. See [createCart](api/createCart.md) and the [FAQ](faq.md#install).

## Next steps

- [Concepts](concepts/README.md)
- [Cookbook](cookbook/README.md)
MD

page concepts/README.md <<'MD'
# Concepts

@SWITCH@

- [Carts](carts.md)
MD

page concepts/carts.md <<'MD'
# Carts

@SWITCH@

A cart holds items until checkout.

## How it works

```mermaid
flowchart LR
  A[Add an item] --> B[Cart]
```

Code is not read for links: `[x](missing.md)`.

```js
const steps = [(next) => next];
steps[0](missing.md);
```

## Related

- [createCart](../api/createCart.md "The API page")
- [Concepts](<README.md>)
- [Website](https://example.com/docs)
- [Mail](mailto:team@example.com)
- [Top](#carts)
- [Home](/docs/en/README.md)
MD

page api/README.md <<'MD'
# API reference

@SWITCH@

| Name | What it does |
|---|---|
| [createCart](createCart.md) | Creates a cart |
MD

page api/createCart.md <<'MD'
# createCart

@SWITCH@

Creates an empty cart.

## Signature

```ts
function createCart(): Cart
```

## Related

- [Apply a coupon](../cookbook/apply-a-coupon.md)
- [Concepts][concepts]

[concepts]: ../concepts/README.md
MD

page cookbook/README.md <<'MD'
# Cookbook

@SWITCH@

- [Apply a coupon](apply-a-coupon.md)
MD

page cookbook/apply-a-coupon.md <<'MD'
# Apply a coupon

@SWITCH@

## Steps

```js
cart.apply("SAVE10");
```

![The coupon flow](../../assets/coupon.svg)

<img src="../../assets/coupon.svg" alt="">

## Related

- [Cookbook](README.md)
MD

page faq.md <<'MD'
# FAQ

@SWITCH@

## Install

Follow the [Quickstart](quickstart.md).
A note[^1] is not a link.

[^1]: A footnote, not a link.
MD

out="$(dp translated --root "$D" $PAGES)"; rc=$?
check "translated records every finished page" '[ "$rc" = 0 ] && [ "$(printf "%s\n" "$out" | grep -c "^recorded ")" = 9 ]'
check "the map records the sha256 of the source page" \
  '[ "$(jq -r ".pages[] | select(.path == \"faq.md\") | .source_sha256.de" "$D/_translation-map.json")" = "$(shasum -a 256 "$D/en/faq.md" | cut -d" " -f1)" ]'
check "writing the map leaves no temporary file" '[ -z "$(find "$D" -maxdepth 1 -name ".*")" ]'
before="$(tree_sum "$F")"
out="$(dp check --root "$D")"; rc=$?
check "a finished set has no problems" '[ "$rc" = 0 ] && printf "%s\n" "$out" | tail -1 | grep -q "^No problems. Links: [0-9]* checked, 0 broken"'
check "links that start with / are counted as not checked" 'printf "%s\n" "$out" | tail -1 | grep -q "2 not checked because they start with /"'
check "check changes no file" '[ "$before" = "$(tree_sum "$F")" ]'

# case <name>: a fresh copy of the finished set in $C/docs
case_copy() { C="$T/case-$1"; rm -rf "$C"; cp -R "$F" "$C"; }
run_check() { dp check --root "$C/docs"; }
has() { printf '%s\n' "$out" | grep -qF -- "$1"; }

case_copy missing; rm "$C/docs/de/faq.md"
out="$(run_check)"; rc=$?
check "a page missing in one language is reported" '[ "$rc" = 1 ] && has "missing      de/faq.md is in the map"'

case_copy unmapped; printf '# Extra\n' > "$C/docs/en/concepts/extra.md"
out="$(run_check)"
check "a page that is not in the map is reported" 'has "unmapped     en/concepts/extra.md is not in the map"'

case_copy todo; printf '<!-- docs-publish:todo say more -->\n' >> "$C/docs/de/faq.md"
out="$(run_check)"
check "a to-do note left in a page is reported" 'has "todo         de/faq.md has 1 to-do note left"'

case_copy heading; printf '\n## Extra\n' >> "$C/docs/de/faq.md"
out="$(run_check)"
check "a translation with other headings is reported" 'has "structure    de/faq.md: headings differ (en: 1 2, de: 1 2 2)"'

case_copy fence; python3 - "$C/docs/de/quickstart.md" <<'PY'
import sys
p = sys.argv[1]; t = open(p).read()
open(p, "w").write(t.replace("```bash\nnpm install acme-shop\n```\n", "npm install acme-shop\n"))
PY
out="$(run_check)"
check "a translation with other code blocks is reported" 'has "code blocks differ (en: bash js, de: js)"'

case_copy table; grep -v "^|---" "$C/docs/de/api/README.md" > "$C/x" && mv "$C/x" "$C/docs/de/api/README.md"
out="$(run_check)"
check "a translation with other table rows is reported" 'has "table rows differ (en: 3, de: 2)"'

case_copy stale; printf 'One more sentence.\n' >> "$C/docs/en/faq.md"
out="$(run_check)"
check "a source page changed after its translation is reported" 'has "stale        en/faq.md changed after de/faq.md was translated from it"'
dp translated --root "$C/docs" de/faq.md >/dev/null; rc=$?
out="$(run_check)"
check "recording the translation again clears the report" '[ "$rc" = 0 ] && ! printf "%s\n" "$out" | grep -q "^stale"'

case_copy untranslated
jq '(.pages[] | select(.path == "faq.md") | .source_sha256) = {}' "$C/docs/_translation-map.json" > "$C/x" && mv "$C/x" "$C/docs/_translation-map.json"
out="$(run_check)"
check "a translation never recorded is reported" 'has "untranslated de/faq.md is not recorded as a translation of en/faq.md"'

case_copy link; printf 'Read [the steps](quickstrat.md).\n' >> "$C/docs/en/faq.md"
line="$(grep -n quickstrat "$C/docs/en/faq.md" | cut -d: -f1)"
out="$(run_check)"
check "a broken link is reported with its line" 'has "link         en/faq.md:$line: quickstrat.md does not exist"'
check "the summary counts the broken link" 'printf "%s\n" "$out" | tail -1 | grep -q ", 1 broken"'

case_copy relative; printf '\nSee [Carts](carts.md).\n' >> "$C/docs/en/api/createCart.md"
out="$(run_check)"
check "a link is resolved from the page's own folder" 'has "link         en/api/createCart.md:" && has "carts.md does not exist"'

case_copy image; printf '\n![Flow](../assets/flow.png)\n' >> "$C/docs/en/cookbook/apply-a-coupon.md"
out="$(run_check)"
check "a broken image is reported" 'has "../assets/flow.png does not exist"'

case_copy refdef; printf '\n[gone]: ../concepts/gone.md\n' >> "$C/docs/en/api/createCart.md"
out="$(run_check)"
check "a broken reference definition is reported" 'has "../concepts/gone.md does not exist"'

case_copy html; printf '\n<a href="nowhere.md">x</a>\n' >> "$C/docs/en/faq.md"
out="$(run_check)"
check "a broken HTML link is reported" 'has "nowhere.md does not exist"'

case_copy letters; printf '\nSee [Quickstart](Quickstart.md).\n' >> "$C/docs/en/faq.md"
out="$(run_check)"
check "a link whose letter case differs from the file is reported" 'printf "%s\n" "$out" | grep -E "^link +en/faq.md:[0-9]+: Quickstart.md (does not exist|differs in letter case)" >/dev/null'

case_copy crosslink; printf '\nSee [Schnellstart](../de/quickstart.md).\n' >> "$C/docs/en/faq.md"
out="$(run_check)"
check "a link into another language other than the counterpart is reported" \
  'has "crosslink    en/faq.md:" && has "../de/quickstart.md points into de/; link the page in en/ instead"'

case_copy switch; grep -v "^\[English\]" "$C/docs/de/faq.md" > "$C/x" && mv "$C/x" "$C/docs/de/faq.md"
out="$(run_check)"
check "a page without the language switch is reported" 'has "switch       de/faq.md has no link to en/faq.md"'

case_copy orphan; grep -v "carts.md" "$C/docs/en/concepts/README.md" > "$C/x" && mv "$C/x" "$C/docs/en/concepts/README.md"
out="$(run_check)"
check "a page no link reaches is reported" 'has "orphan       en/concepts/carts.md cannot be reached by following links from en/README.md"'
check "the other language is not reported as orphaned" '! has "orphan       de/"'

case_copy mermaid
for lang in en de; do
  python3 - "$C/docs/$lang/concepts/carts.md" <<'PY'
import sys
p = sys.argv[1]; t = open(p).read()
open(p, "w").write(t.replace("```mermaid\nflowchart LR\n  A[Add an item] --> B[Cart]\n```\n", ""))
PY
done
out="$(run_check)"
check "a concept page without a Mermaid diagram is reported" 'has "content      en/concepts/carts.md has no Mermaid diagram"'

case_copy code
for lang in en de; do
  python3 - "$C/docs/$lang/api/createCart.md" <<'PY'
import sys
p = sys.argv[1]; t = open(p).read()
open(p, "w").write(t.replace("```ts\nfunction createCart(): Cart\n```\n", "function createCart(): Cart\n"))
PY
done
out="$(run_check)"
check "an API page without a code example is reported" 'has "content      en/api/createCart.md has no code example"'

case_copy cjk
python3 - "$C/docs/de/faq.md" "$C/docs/de/quickstart.md" <<'PY'
import sys
p = sys.argv[1]; t = open(p).read()
heading = "## " + chr(0x5C0E) + chr(0x5165); word = chr(0x307E) + chr(0x305A)
open(p, "w", encoding="utf-8").write(t.replace("## Install", heading).replace("Follow", word))
# The link to that heading follows it, with the anchor GitHub makes from the new heading.
q = sys.argv[2]; t = open(q, encoding="utf-8").read()
open(q, "w", encoding="utf-8").write(t.replace("faq.md#install", "faq.md#" + heading[3:]))
PY
out="$(dp translated --root "$C/docs" "$C/docs/de/faq.md")"; rc=$?
check "a translation in another script is recorded" '[ "$rc" = 0 ] && has "recorded      de/faq.md"'
out="$(run_check)"; rc=$?
check "a translation in another script passes the check" '[ "$rc" = 0 ]'

# --- links to headings (#237): an anchor must be one GitHub makes from a heading of the target page.
# A file the pages link to, outside the docs folder but inside the folder that holds it.
outside_readme() {
  printf '# Acme Shop\n\n## Getting started\n\nRead the docs.\n\n<a name="legacy-install"></a>\n' > "$C/README.md"
}
case_copy anchors
outside_readme
python3 - "$C/docs/en/faq.md" "$C/docs/de/faq.md" <<'PY'
import sys
from urllib.parse import quote
ja = lambda *points: "".join(map(chr, points))
read_run_send = ja(0x8AAD, 0x3080, 0x7269, 0x3001, 0x52D5, 0x304B, 0x3059, 0x7269, 0x3001, 0x9001, 0x308B, 0x7269)
settings = ja(0x8A2D, 0x5B9A, 0xFF08, 0xFF21, 0xFF09)
example = ja(0x4F8B)
usage = ja(0x306E, 0x4F7F, 0x3044, 0x65B9)
and_more = ja(0x3068) + "**" + ja(0x307B, 0x304B) + "**" + ja(0x306E, 0x30A4, 0x30F3, 0x30B9, 0x30C8, 0x30FC, 0x30EB, 0x30FB, 0x8A2D, 0x5B9A)
shared = "[g](faq.md#install), [h](concepts/carts.md#how-it-works), [i](api/#api-reference), " \
         "[j](../../README.md#getting-started), [k](../../README.md#legacy-install)"
pages = {
    sys.argv[1]: (["Read, run, & send", "Settings (A)", "Example", "Example", "`apply --confirm` usage",
                   "See [the API](api/createCart.md) and **more**"],
                  ["read-run--send", "settings-a", "example", "example-1", "apply---confirm-usage",
                   "see-the-api-and-more"]),
    sys.argv[2]: ([read_run_send, settings, example, example, "`apply --confirm`" + usage,
                   "[API](api/createCart.md)" + and_more],
                  [ja(0x8AAD, 0x3080, 0x7269, 0x52D5, 0x304B, 0x3059, 0x7269, 0x9001, 0x308B, 0x7269),
                   quote(ja(0x8A2D, 0x5B9A, 0xFF41)), example, example + "-1", "apply---confirm" + usage,
                   "api" + ja(0x3068, 0x307B, 0x304B, 0x306E, 0x30A4, 0x30F3, 0x30B9, 0x30C8, 0x30FC, 0x30EB,
                              0x8A2D, 0x5B9A)]),
}
for path, (headings, anchors) in pages.items():
    text = open(path, encoding="utf-8").read()
    text += "".join("\n## %s\n\nText.\n" % h for h in headings)
    text += "\nJump to %s, %s.\n" % (", ".join("[%s](#%s)" % (chr(97 + i), a) for i, a in enumerate(anchors)), shared)
    open(path, "w", encoding="utf-8").write(text)
PY
dp translated --root "$C/docs" faq.md >/dev/null; rc=$?
out="$(run_check)"; check_rc=$?
check "links to headings that exist pass, including Japanese headings" \
  '[ "$rc" = 0 ] && [ "$check_rc" = 0 ] && ! printf "%s\n" "$out" | grep -q "^anchor"'

case_copy anchor
printf '\nSee [the steps](quickstart.md#instal), [Install](quickstart.md#Install), and [the top](#faqs).\n' >> "$C/docs/en/faq.md"
line="$(grep -n "quickstart.md#instal" "$C/docs/en/faq.md" | cut -d: -f1)"
out="$(run_check)"; rc=$?
check "a link to a heading the target page lacks is reported" \
  '[ "$rc" = 1 ] && has "anchor       en/faq.md:$line: quickstart.md#instal" && has "anchor       en/faq.md:$line: quickstart.md#Install" && ! has "anchor       en/quickstart.md"'
check "a link to a missing heading on the same page is reported" 'has "anchor       en/faq.md:$line: #faqs"'
check "the summary counts a link to a missing heading and says how to fix it" \
  'printf "%s\n" "$out" | tail -1 | grep -q ", 3 broken" && printf "%s\n" "$out" | grep -qE "^  anchor +\S"'

case_copy outside
outside_readme
printf '\nSee [Install](../../README.md#install) and [Start](../../README.md#getting-started).\n' >> "$C/docs/en/faq.md"
out="$(run_check)"
check "a link to a missing heading of a page outside the docs folder is reported" \
  'has "anchor       en/faq.md:" && has "../../README.md#install" && ! has "../../README.md#getting-started"'

case_copy above
printf '# Outside\n' > "$T/outside.md"
printf '\nSee [Outside](../../../outside.md#nowhere).\n' >> "$C/docs/en/faq.md"
out="$(run_check)"
check "a heading outside the folder above the docs folder is not checked" \
  '! has "outside.md#nowhere" && printf "%s\n" "$out" | tail -1 | grep -q ", 0 broken"'

case_copy notmarkdown
printf 'print("acme")\n' > "$C/script.py"
printf '\nSee [the flow](../assets/coupon.svg#frame) and [line 1](../../script.py#L1).\n' >> "$C/docs/en/faq.md"
out="$(run_check)"
check "an anchor on a file that is not Markdown is not checked" \
  '! printf "%s\n" "$out" | grep -q "^anchor" && printf "%s\n" "$out" | tail -1 | grep -q ", 0 broken"'

# --- translated refuses what does not match
case_copy refuse; printf '\n## Extra\n' >> "$C/docs/de/faq.md"
before="$(cat "$C/docs/_translation-map.json")"
out="$(dp translated --root "$C/docs" faq.md)"; rc=$?
check "translated refuses a translation with another structure" \
  '[ "$rc" = 1 ] && has "not recorded  de/faq.md: headings differ" && [ "$before" = "$(cat "$C/docs/_translation-map.json")" ]'
printf '<!-- docs-publish:todo finish -->\n' > "$C/docs/de/faq.md"
out="$(dp translated --root "$C/docs" faq.md)"; rc=$?
check "translated refuses a translation with to-do notes" '[ "$rc" = 1 ] && has "de/faq.md: it still has to-do notes"'
dp translated --root "$C/docs" en/faq.md >/dev/null 2>"$T/err"; rc=$?
check "translated refuses the source language" '[ "$rc" = 2 ] && grep -q "en is the source language" "$T/err"'
out="$(dp translated --root "$C/docs" concepts/none.md)"; rc=$?
check "translated refuses a page not in the map" '[ "$rc" = 1 ] && has "de/concepts/none.md: it is not in the map"'

# --- projects to follow in the map
# follow_copy <name>: a copy of the finished set whose map, in the current version, follows two projects
follow_copy() { case_copy "$1"; jq --argjson f "$FOLLOW" '.version = 2 | .follow = $f' "$C/docs/_translation-map.json" > "$C/x" && mv "$C/x" "$C/docs/_translation-map.json"; }
follow_copy follow
plain_out="$(dp check --root "$D")"; plain_rc=$?
out="$(run_check)"; rc=$?
check "check passes with and without projects to follow" \
  '[ "$plain_rc" = 0 ] && [ "$rc" = 0 ] && printf "%s\n" "$plain_out" | tail -1 | grep -q "^No problems." && printf "%s\n" "$out" | tail -1 | grep -q "^No problems."'
check "check names the projects the docs follow" \
  'has "Follows: Sibling A (https://git.example.org/acme/sibling-a), Sibling B (https://docs.example.com/sibling-b/)" && ! printf "%s\n" "$plain_out" | grep -q "^Follows:"'
dp add --root "$C/docs" concepts/caching.md --title "Caching" >/dev/null 2>&1
dp drop --root "$C/docs" cookbook/apply-a-coupon.md >/dev/null 2>&1
dp translated --root "$C/docs" faq.md >/dev/null 2>&1
check "add, drop, and translated keep the projects to follow" \
  '[ "$(jq -c .follow "$C/docs/_translation-map.json")" = "$(jq -c . <<< "$FOLLOW")" ] && jq -e ".pages[] | select(.path == \"concepts/caching.md\")" "$C/docs/_translation-map.json" >/dev/null'
case_copy v1
jq 'del(.follow) | .version = 1' "$C/docs/_translation-map.json" > "$C/x" && mv "$C/x" "$C/docs/_translation-map.json"
run_check >/dev/null 2>&1; rc=$?
dp add --root "$C/docs" concepts/caching.md --title "Caching" >/dev/null 2>&1
check "a version 1 map is read as following no project and written as version 2" \
  '[ "$rc" = 0 ] && [ "$(jq -c "[.version, .follow]" "$C/docs/_translation-map.json")" = "[2,[]]" ]'

# --- add and drop
case_copy add
out="$(dp add --root "$C/docs" concepts/caching.md --title "Caching")"; rc=$?
check "add exits 0 and writes the page in both languages" \
  '[ "$rc" = 0 ] && [ -f "$C/docs/en/concepts/caching.md" ] && [ -f "$C/docs/de/concepts/caching.md" ]'
check "add records the page in reading order" \
  '[ "$(jq -r ".pages | map(.path) | join(\" \")" "$C/docs/_translation-map.json")" = "README.md quickstart.md concepts/README.md concepts/caching.md concepts/carts.md api/README.md api/createCart.md cookbook/README.md cookbook/apply-a-coupon.md faq.md" ]'
check "add tells where to link the page" 'has "Link it from concepts/README.md in every language."'
dp add --root "$C/docs" api/client/connect --title "connect" >/dev/null; rc=$?
check "add takes a page in a subfolder and links it back to the part index" \
  '[ "$rc" = 0 ] && grep -qxF -- "- [API reference](../README.md)" "$C/docs/en/api/client/connect.md"'
printf 'kept text\n' > "$C/docs/en/cookbook/kept.md"
out="$(dp add --root "$C/docs" cookbook/kept.md --title "Kept")"
check "add keeps a page that already exists" \
  '[ "$(cat "$C/docs/en/cookbook/kept.md")" = "kept text" ] && has "kept  $C/docs/en/cookbook/kept.md (it already exists)"'
refused=0
for bad in ../x.md guides/x.md faq.md concepts/carts.md concepts/README.md; do
  dp add --root "$C/docs" "$bad" --title "X" >/dev/null 2>&1 || [ $? != 2 ] || refused=$((refused + 1))
done
check "add refuses paths outside the parts, fixed pages, and pages already mapped" '[ "$refused" = 5 ]'
out="$(dp add --root "$C/docs" api/get-cart.md --title "GET /v1/carts/{id}" --endpoint)"; rc=$?
check "add --endpoint writes the endpoint outline" \
  '[ "$rc" = 0 ] && [ "$(headings "$C/docs/en/api/get-cart.md")" = "$ENDPOINT_OUTLINE" ] && grep -qF "Translate en/api/get-cart.md into Deutsch" "$C/docs/de/api/get-cart.md" && jq -e ".pages[] | select(.path == \"api/get-cart.md\")" "$C/docs/_translation-map.json" >/dev/null'
dp add --root "$C/docs" concepts/sessions.md --title "Sessions" --endpoint >/dev/null 2>"$T/err"; rc=$?
check "add refuses --endpoint for a page outside api/" \
  '[ "$rc" = 2 ] && [ ! -e "$C/docs/en/concepts/sessions.md" ] && grep -q "only an API page can be an endpoint" "$T/err"'

case_copy drop
out="$(dp drop --root "$C/docs" cookbook/apply-a-coupon.md)"; rc=$?
check "drop exits 0 and removes the page from the map" \
  '[ "$rc" = 0 ] && ! jq -e ".pages[] | select(.path == \"cookbook/apply-a-coupon.md\")" "$C/docs/_translation-map.json" >/dev/null'
check "drop deletes no file and lists the files left" \
  '[ -f "$C/docs/en/cookbook/apply-a-coupon.md" ] && [ -f "$C/docs/de/cookbook/apply-a-coupon.md" ] && has "$C/docs/de/cookbook/apply-a-coupon.md"'
out="$(run_check)"
check "the files of a dropped page are reported as not in the map" \
  'has "unmapped     de/cookbook/apply-a-coupon.md" && has "unmapped     en/cookbook/apply-a-coupon.md"'
dp drop --root "$C/docs" faq.md >/dev/null 2>&1; rc=$?
check "drop refuses one of the five parts" '[ "$rc" = 2 ]'

# --- the map
case_copy version
jq '.version = 3' "$C/docs/_translation-map.json" > "$C/x" && mv "$C/x" "$C/docs/_translation-map.json"
run_check >/dev/null 2>"$T/err"; rc=$?
check "a map of version 3 exits 2" '[ "$rc" = 2 ] && grep -q "has version 3; this script reads versions 1 and 2 only" "$T/err"'
case_copy badfollow
jq '.version = 2 | .follow = [{"name": "X", "url": "ftp://x.example.org", "adopted": "Layout"}]' "$C/docs/_translation-map.json" > "$C/x" && mv "$C/x" "$C/docs/_translation-map.json"
run_check >/dev/null 2>"$T/err"; rc=$?
check "a map with a bad project to follow exits 2" '[ "$rc" = 2 ] && grep -q "follow\[0\]: url must start with https://" "$T/err"'
case_copy badpage
jq '.pages += [{"path": "../../etc/passwd", "source_sha256": {}}]' "$C/docs/_translation-map.json" > "$C/x" && mv "$C/x" "$C/docs/_translation-map.json"
run_check >/dev/null 2>"$T/err"; rc=$?
check "a map with a path outside the layout exits 2" '[ "$rc" = 2 ] && grep -q "is not a page path this layout allows" "$T/err"'
dp check --root "$T/nowhere" >/dev/null 2>"$T/err"; rc=$?
check "check without a map exits 2" '[ "$rc" = 2 ] && grep -q "No _translation-map.json in" "$T/err"'

# --- the docs
SKILL="$HERE/../SKILL.md"
PLUGIN="$HERE/../../.."
follow_step="$(awk '/^### 2\. Read the projects to follow/{f=1; next} /^### /{f=0} f' "$SKILL")"
step_says() { printf '%s\n' "$follow_step" | grep -qiF -- "$1"; }
check "SKILL.md reads the projects to follow only when the user names them and agrees" \
  'step_says "only when the user names" && step_says "agrees" && step_says "gh api" && step_says "web" && step_says "five pages" && step_says "skip"'
check "SKILL.md says not to copy text from the docs it follows" 'step_says "never copy"'
# The Japanese words for "named" and "agreement", built from code points so this file stays in English.
ja_named="$(python3 -c 'print("".join(map(chr, (0x540d, 0x6307, 0x3057, 0x305f))))')"
ja_agree="$(python3 -c 'print("".join(map(chr, (0x540c, 0x610f))))')"
check "the READMEs say the docs of other projects are read only with the user's agreement" \
  'grep -i "projects you name" "$PLUGIN/README.md" | grep -q "agreement" && grep -F "$ja_named" "$PLUGIN/README.ja.md" | grep -qF "$ja_agree"'

# The skill writes the docs of the user's own libraries, command-line tools, and web services (#231).
ROOT="$PLUGIN/../.."
page_row() { grep -F -- "$1" "$SKILL"; }
endpoint_row="$(page_row '| `api/<slug>.md` for an HTTP endpoint |')"
row_says() { printf '%s\n' "$endpoint_row" | grep -qiF -- "$1"; }
check "SKILL.md gives an HTTP endpoint page a layout of its own" \
  '[ "$(printf "%s\n" "$endpoint_row" | grep -c .)" = 1 ] && row_says "method and path" && row_says "authentication" && row_says "parameters" && row_says "request body" && row_says "status code" && row_says "errors" && row_says "complete request" && row_says "response" && grep -qF "\"endpoint\": true" "$SKILL"'
quickstart_row="$(page_row '| `quickstart.md` |')"
check "SKILL.md starts the Quickstart of a service from an account, an API key, and a first request" \
  'printf "%s\n" "$quickstart_row" | grep -q "install command" && printf "%s\n" "$quickstart_row" | grep -q "account" && printf "%s\n" "$quickstart_row" | grep -q "API key" && printf "%s\n" "$quickstart_row" | grep -q "first request"'
read_step="$(awk '/^### 1\. Read the project/{f=1; next} /^### /{f=0} f' "$SKILL")"
check "SKILL.md reads the issues of a private repository that gh can read" \
  'printf "%s\n" "$read_step" | grep -q "private" && printf "%s\n" "$read_step" | grep -q "gh issue list" && printf "%s\n" "$read_step" | grep -q "gh issue view"'
rules="$(awk '/^## Rules/{f=1; next} /^## /{f=0} f' "$SKILL")"
check "SKILL.md never puts a real API key in a page" \
  'printf "%s\n" "$rules" | grep -i "never" | grep -q "real API key" && printf "%s\n" "$rules" | grep -q "placeholder"'
check "SKILL.md sends requests only to a copy of the service on the user's machine" \
  'grep -q "only to a copy the project starts on this machine" "$SKILL" && grep -q "never to the hosted service" "$SKILL"'

# An existing docs folder when the user cannot be asked (#237).
plan_step="$(awk '/^### 3\. Agree on the plan/{f=1; next} /^### /{f=0} f' "$SKILL")"
unasked="$(printf '%s\n' "$plan_step" | grep -i "cannot be asked")"
unasked_says() { printf '%s\n' "$unasked" | grep -qiF -- "$1"; }
check "SKILL.md uses an existing docs folder when the dry run lists every file as new" \
  'unasked_says "docs/" && unasked_says "every file as \`new\`" && unasked_says "use \`docs/\`" && unasked_says "report"'
check "SKILL.md writes nothing into an existing docs folder when the dry run keeps a file" \
  'unasked_says "\`kept\`" && unasked_says "write nothing"'

entries="$(changelog_entries "$PLUGIN/CHANGELOG.md")"
changelog_line() { printf '%s\n' "$entries" | grep '^- ' | grep -i -- "$1" | grep -qi -- "$2"; }
check "the changelog has a line for each change of #237" \
  'changelog_line "order of the plan" "scaffold" && changelog_line "heading" "check" && changelog_line "cannot be asked" "docs/"'

# The changelog reading counts a line that only a released section holds, and finds nothing when no
# section names the text (a link definition does not count).
changelog_reading() {
  printf '# Changelog\n\n## [Unreleased]\n\n## [0.3.0] - 2026-11-30\n\n- a later change\n\n## [0.2.0] - 2026-11-23\n\n- ships the needle\n\n[Unreleased]: compare/v0.3.0...HEAD\n[0.3.0]: tag/v0.3.0\n' > "$T/log-released.md"
  printf '# Changelog\n\n## [Unreleased]\n\n- something else\n\n## [0.2.0] - 2026-11-23\n\n- another change\n\n[needle]: tag/needle\n' > "$T/log-none.md"
  changelog_entries "$T/log-released.md" | grep -qF 'ships the needle' || { echo "      a line only the 0.2.0 section holds was not read"; return 1; }
  if changelog_entries "$T/log-none.md" | grep -qF 'needle'; then echo "      a changelog that names the text only in a link definition was read as naming it"; return 1; fi
}
check "docs-publish changelog reading counts any release and fails when no section names the text" changelog_reading

# descriptions: every place that says what the plugin does, one text per line.
descriptions() {
  sed -n 's/^description: //p' "$SKILL"
  for f in "$PLUGIN/README.md" "$PLUGIN/README.ja.md" "$PLUGIN/docs/how-it-works.md" "$PLUGIN/docs/how-it-works.ja.md"; do
    tr '\n' ' ' < "$f"; printf '\n'
  done
  jq -r '.description' "$PLUGIN/.claude-plugin/plugin.json"
  jq -r '.description, .interface.longDescription' "$PLUGIN/.codex-plugin/plugin.json"
  jq -r '.plugins[] | select(.name == "docs-publish") | .description' "$ROOT/.claude-plugin/marketplace.json"
  grep -F '| [docs-publish](plugins/docs-publish) |' "$ROOT/README.md" "$ROOT/README.ja.md"
}
# The Japanese words for "library", "command line", "service", and "open source", from code points.
ja_word() { python3 -c 'import sys; print("".join(chr(int(c, 16)) for c in sys.argv[1:]))' "$@"; }
ja_library="$(ja_word 30e9 30a4 30d6 30e9 30ea)"
ja_command_line="$(ja_word 30b3 30de 30f3 30c9 30e9 30a4 30f3)"
ja_service="$(ja_word 30b5 30fc 30d3 30b9)"
ja_open_source="$(ja_word 30aa 30fc 30d7 30f3 30bd 30fc 30b9)"
names_all_three() {
  local line n=0
  while IFS= read -r line; do
    n=$((n + 1))
    if printf '%s\n' "$line" | grep -qiE 'librar' && printf '%s\n' "$line" | grep -qiE 'command-line tool' &&
      printf '%s\n' "$line" | grep -qiE 'web service'; then continue; fi
    if printf '%s\n' "$line" | grep -qF "$ja_library" && printf '%s\n' "$line" | grep -qF "$ja_command_line" &&
      printf '%s\n' "$line" | grep -qF "Web$ja_service"; then continue; fi
    printf 'does not name all three: %s\n' "${line:0:120}" >&2
    return 1
  done < <(descriptions)
  [ "$n" = 11 ]
}
check "every description names libraries, command-line tools, and web services" "names_all_three"
check "no description limits the skill to open source projects" \
  '! descriptions | grep -qiE "open[ -]source" && ! descriptions | grep -qF "$ja_open_source" && ! jq -r ".keywords[]" "$PLUGIN/.claude-plugin/plugin.json" "$PLUGIN/.codex-plugin/plugin.json" | grep -qi "open-source"'

# check reads the Markdown files outside the docs folder that the pages link to with an anchor (#237).
# The Japanese words for "heading" and "outside the folder", from code points.
ja_heading="$(ja_word 898b 51fa 3057)"
ja_outside="$(ja_word 30d5 30a9 30eb 30c0 306e 5916)"
says_reads_outside() { grep -i "headings" "$1" | grep -qi "outside the docs folder"; }
says_reads_outside_ja() { grep -F "$ja_heading" "$1" | grep -qF "$ja_outside"; }
check "the READMEs and how-it-works say check reads the headings of linked Markdown outside the docs folder" \
  'says_reads_outside "$PLUGIN/README.md" && says_reads_outside "$PLUGIN/docs/how-it-works.md" && says_reads_outside_ja "$PLUGIN/README.ja.md" && says_reads_outside_ja "$PLUGIN/docs/how-it-works.ja.md"'

# --- check says how to fix what it lists, so the SKILL.md does not need a table of problems
case_copy fixlines
python3 - "$C/docs/de/faq.md" <<'PY'
import sys
p = sys.argv[1]
text = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(text.replace("(quickstart.md)", "(quickstart-gone.md)"))
PY
printf '\nOne more line.\n' >> "$C/docs/en/faq.md"
out="$(run_check)"
fix_lines() {
  python3 - "$out" <<'PY'
import re, sys
KINDS = {"missing", "unmapped", "todo", "content", "structure", "untranslated", "stale", "link", "crosslink",
         "switch", "orphan"}
head, _, tail = sys.argv[1].partition("\nHow to fix:\n")
listed = {m.group(1) for m in re.finditer(r"^([a-z]+) +\S", head, re.M)} & KINDS
fixed = {m.group(1) for m in re.finditer(r"^  ([a-z]+) +\S", tail, re.M)}
sys.exit(0 if {"link", "stale"} <= listed and listed <= fixed else 1)
PY
}
check "check says how to fix each kind of problem it lists" "fix_lines"

# --- the eval suite that measures the SKILL.md (plugins/docs-publish/evals)
EVALS="$PLUGIN/evals"
eval_cases() {
  local c
  for c in plan-first api-page translate-page check-and-fix unrelated-request; do
    [ -f "$EVALS/$c/case.yaml" ] || return 1
  done
}
check "the eval suite has the five cases" "eval_cases"

# Each fixture runs in an empty folder with its own HOME, as claude plugin eval runs it, and leaves
# the state its case starts from.
fixture() {
  local d="$T/fixture-$1"
  rm -rf "$d"
  mkdir -p "$d/home" "$d/work"
  (cd "$d/work" && HOME="$d/home" bash "$EVALS/$1/fixture.sh") >/dev/null 2>&1 && printf '%s\n' "$d/work"
}
fixtures_ready() {
  local w out
  w="$(fixture plan-first)" && [ -f "$w/package.json" ] && [ ! -e "$w/docs" ] || return 1
  w="$(fixture api-page)" && grep -q 'docs-publish:todo' "$w/docs/en/api/slugify.md" || return 1
  w="$(fixture translate-page)" && ! grep -q 'docs-publish:todo' "$w/docs/en/quickstart.md" &&
    grep -q 'docs-publish:todo' "$w/docs/ja/quickstart.md" || return 1
  w="$(fixture check-and-fix)" || return 1
  out="$(cd "$w" && dp check)"
  [ "$(printf '%s\n' "$out" | grep -cE '^(link|stale) ')" -ge 2 ] &&
    ! printf '%s\n' "$out" | grep -qE '^(missing|unmapped|todo|content|structure|untranslated|crosslink|switch|orphan) ' ||
    return 1
  # The translations are in Japanese, so the only work the case leaves is the two problems: a page
  # left in English would have the agent translate the whole set instead.
  python3 - "$w/docs/ja" <<'PY'
import os, re, sys
kana = re.compile("[%s-%s]" % (chr(0x3040), chr(0x30FF)))
pages = [os.path.join(d, f) for d, _, files in os.walk(sys.argv[1]) for f in files if f.endswith(".md")]
def first_text(path):
    """The page before its first code block, without the title and the language switch."""
    return "\n".join(open(path, encoding="utf-8").read().split("```")[0].splitlines()[3:])
sys.exit(0 if len(pages) == 10 and all(kana.search(first_text(p)) for p in pages) else 1)
PY
}
check "the eval fixtures build the states their cases start from" "fixtures_ready"

eval_results_ignored() { git -C "$PLUGIN" check-ignore -q evals/results/run.json; }
check "eval results are ignored by git" "eval_results_ignored"

# The limits are the sizes of the shortened SKILL.md. Every agent that starts the skill reads the
# whole body, and every session reads the description, so raise a limit only with a reason.
# 1972 words grew to 2134 for the HTTP endpoint page, the Quickstart of a hosted service, and the
# rules on API keys and on where requests go (#231). 2134 grew by 56 words to 2190 for what to do with an
# existing docs folder when the user cannot be asked (#237).
SKILL_WORDS_MAX=2190
SKILL_DESCRIPTION_MAX=317
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

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
