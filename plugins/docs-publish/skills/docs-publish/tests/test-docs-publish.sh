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
check "the map has version 1 and the source language first" \
  '[ "$(jq -r "[.version, (.languages | map(.code) | join(\",\"))] | join(\" \")" "$T/s/docs/_translation-map.json")" = "1 en,de" ]'
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
python3 - "$C/docs/de/faq.md" <<'PY'
import sys
p = sys.argv[1]; t = open(p).read()
heading = "## " + chr(0x5C0E) + chr(0x5165); word = chr(0x307E) + chr(0x305A)
open(p, "w", encoding="utf-8").write(t.replace("## Install", heading).replace("Follow", word))
PY
out="$(dp translated --root "$C/docs" "$C/docs/de/faq.md")"; rc=$?
check "a translation in another script is recorded" '[ "$rc" = 0 ] && has "recorded      de/faq.md"'
out="$(run_check)"; rc=$?
check "a translation in another script passes the check" '[ "$rc" = 0 ]'

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
jq '.version = 2' "$C/docs/_translation-map.json" > "$C/x" && mv "$C/x" "$C/docs/_translation-map.json"
run_check >/dev/null 2>"$T/err"; rc=$?
check "a map of another version exits 2" '[ "$rc" = 2 ] && grep -q "has version 2; this script reads version 1 only" "$T/err"'
case_copy badpage
jq '.pages += [{"path": "../../etc/passwd", "source_sha256": {}}]' "$C/docs/_translation-map.json" > "$C/x" && mv "$C/x" "$C/docs/_translation-map.json"
run_check >/dev/null 2>"$T/err"; rc=$?
check "a map with a path outside the layout exits 2" '[ "$rc" = 2 ] && grep -q "is not a page path this layout allows" "$T/err"'
dp check --root "$T/nowhere" >/dev/null 2>"$T/err"; rc=$?
check "check without a map exits 2" '[ "$rc" = 2 ] && grep -q "No _translation-map.json in" "$T/err"'

printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
