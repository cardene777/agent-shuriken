#!/usr/bin/env bash
# Tests for doc_review.py against throwaway documents in a throwaway repository.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../scripts/doc_review.py"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export DOC_REVIEW_HOME="$T/state"
R="$T/repo"
mkdir -p "$R/docs/adr" "$R/src" "$R/notes"

ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }

git -C "$R" init -q
printf '# Shop\n' > "$R/README.md"
printf 'print(1)\n' > "$R/src/app.py"

cat > "$R/docs/SPEC.md" <<'MD'
---
title: "[front](matter-link.md)"
---
# Shop spec

## 1. Scope

See [design](DESIGN.md#2-data-model) and [missing](NOPE.md).
Also [bad anchor](DESIGN.md#no-such-section), [self](#1-scope), and [self bad](#nowhere).
Web [site](https://example.com/x) and [mail](mailto:someone@example.com).
`[in code](missing-in-code.md)` stays ignored, and so does ``a `[x](y.md)` b``.
[dir](../src), [root](/README.md), [accents](DESIGN.md#données--café--naïve-setup), and [kana](DESIGN.md#日本語の見出し).
[encoded](DESIGN.md#%E6%97%A5%E6%9C%AC%E8%AA%9E%E3%81%AE%E8%A6%8B%E5%87%BA%E3%81%97), [second](DESIGN.md#overview-1), [third](DESIGN.md#overview-2), [setext](DESIGN.md#setext-title).
A footnote[^1] and an <a href="DESIGN.md#c-sharp">HTML link</a>.

[^1]: A footnote, not a link.
[ref]: missing-ref.md

## 2. Limits

#### Too deep

## 4. Errors

### 3.1 Misplaced

| Name | Value |
|---|---|
| a | 1 |
| b | 2 | 3 |
| `x|y` | a \| b |

```bash
[fenced](missing-fenced.md)
## not a heading
```

## 2026 roadmap

## 404 page
MD

cat > "$R/docs/DESIGN.md" <<'MD'
# Design

## 2. Data model

## Données & Café — `naïve` setup

## 日本語の見出し

## Overview

## Overview

Setext title
------------

<span id="c-sharp"></span>
MD

printf '# Broken\n\n```js\nconst a = 1;\n' > "$R/docs/broken.md"
printf '# Use Postgres\n' > "$R/docs/adr/0001-use-postgres.md"
printf '# Notes\n' > "$R/notes/2026-11-12-notes.md"
printf '# API spec\n' > "$R/notes/spec_api.md"
printf '# Special offers\n' > "$R/notes/specials.md"
printf 'plain text\n' > "$R/notes/todo.txt"

run() { python3 "$SCRIPT" "$@"; }

OUT="$(cd "$R" && run start docs/SPEC.md docs/DESIGN.md docs/broken.md docs/adr/0001-use-postgres.md notes/2026-11-12-notes.md notes/spec_api.md notes/specials.md notes/todo.txt)"
CODE=$?
check "start exits 0" "[ $CODE -eq 0 ]"
has() { printf '%s\n' "$OUT" | grep -qF -- "$1"; }
check "a missing file is found" "has 'docs/SPEC.md:8  link  link target not found: NOPE.md'"
check "a missing anchor in another file is found" "has 'docs/SPEC.md:9  anchor  anchor #no-such-section not found in docs/DESIGN.md'"
check "a missing anchor in the same file is found" "has 'anchor #nowhere not found in this file'"
check "a broken reference definition is found" "has 'link target not found: missing-ref.md'"
check "a duplicate heading's third anchor is missing" "has 'anchor #overview-2 not found in docs/DESIGN.md'"
check "a heading level jump is found" "has 'docs/SPEC.md:21  heading  heading level jumps from H2 to H4'"
check "a gap in heading numbers is found" "has 'docs/SPEC.md:23  numbering  heading 4 follows 2'"
check "a sub-number under the wrong parent is found" "has 'docs/SPEC.md:25  numbering  heading 3.1 sits under 4'"
check "a table row with an extra cell is found" "has 'docs/SPEC.md:30  table  row has 3 cells, header has 2'"
check "an unclosed code block is found" "has 'docs/broken.md:3  fence  code block opened here is never closed'"
check "only those 10 form findings are reported" "has 'Form checks: 10 findings'"
check "web links, code, front matter, footnotes, and valid anchors are not reported" \
  "! printf '%s\n' \"\$OUT\" | grep -E '^  [^ ]+:[0-9]+  ' | grep -qE 'example.com|in-code|y.md|fenced|matter-link|1-scope|données|日本語|%E6|overview-1|setext|c-sharp|footnote|not a heading|2026|404|src|README'"
check "kinds are guessed from the paths" \
  "has 'docs/SPEC.md  kind spec' && has 'docs/DESIGN.md  kind design' && has 'docs/adr/0001-use-postgres.md  kind adr' && has 'notes/2026-11-12-notes.md  kind other' && has 'notes/spec_api.md  kind spec' && has 'notes/specials.md  kind other'"
check "a file that is not Markdown is named" "has 'notes/todo.txt  kind other, not Markdown'"

REV="$(printf '%s\n' "$OUT" | sed -n 's/^Review: //p')"
check "start creates a private review folder" "[ -d \"$REV\" ] && [ \"\$(stat -f %Lp \"$REV\" 2>/dev/null || stat -c %a \"$REV\")\" = 700 ]"
check "start.json is readable only by the user" "[ \"\$(stat -f %Lp \"$REV/start.json\" 2>/dev/null || stat -c %a \"$REV/start.json\")\" = 600 ]"

F="$T/findings.json"
record() { python3 "$SCRIPT" record "$REV" --findings "$F"; }
fails_with() { # <exit code> <text>
  local out code
  out="$(record 2>&1)"; code=$?
  [ "$code" -eq "$1" ] && printf '%s\n' "$out" | grep -qF -- "$2" && [ ! -e "$REV/findings.json" ]
}

printf '[{"severity":"major","reviewer":"content","file":"docs/SPEC.md","where":"## 2. Limits","problem":"No rate limit","fix":"State the limit"}]' > "$F"
check "a finding without a status is refused and nothing is written" "fails_with 2 'status must be fixed or rejected'"
printf '[{"severity":"minor","reviewer":"form","file":"docs/SPEC.md","where":"line 29","problem":"Extra cell","fix":"Remove it","status":"rejected"}]' > "$F"
check "a rejected finding without a reason is refused" "fails_with 2 'a rejected finding needs a reason'"
printf '[{"severity":"major","reviewer":"content","file":"docs/SPEC.md","where":"## 2. Limits","problem":"No rate limit","fix":"State the limit","status":"fixed"}]' > "$F"
check "a fixed finding on an unchanged file is refused" "fails_with 2 'marked fixed, but docs/SPEC.md has not changed since start'"
printf '[{"severity":"major","reviewer":"content","file":"docs/OTHER.md","where":"x","problem":"p","fix":"f","status":"rejected","reason":"r"}]' > "$F"
check "a finding on a file that was not reviewed is refused" "fails_with 2 'is not one of the reviewed files'"
printf '[{"severity":"blocker","reviewer":"content","file":"docs/SPEC.md","where":"x","problem":"p","fix":"f","status":"rejected","reason":"r"}]' > "$F"
check "an unknown severity is refused" "fails_with 2 'severity must be one of critical, major, minor'"
printf 'not json' > "$F"
check "a findings file that is not JSON is refused" "fails_with 2 'not valid JSON'"

printf '\n## 3. Rate limits\n\nAt most 10 requests a second.\n' >> "$R/docs/SPEC.md"
cat > "$F" <<'JSON'
[
 {"severity": "minor", "reviewer": "form", "file": "docs/SPEC.md", "where": "line 29", "problem": "The row has an extra cell", "fix": "Remove the third cell", "status": "rejected", "reason": "The third cell is a planned column"},
 {"severity": "critical", "reviewer": "content", "file": "SPEC.md", "where": "## 2. Limits", "problem": "No rate limit is given", "fix": "State the limit", "status": "fixed"},
 {"severity": "major", "reviewer": "both", "file": "docs/SPEC.md", "where": "## 4. Errors", "problem": "Error codes are missing", "fix": "List the codes", "status": "fixed"}
]
JSON
OUT="$(record)"; CODE=$?
check "record exits 0 once the document changed" "[ $CODE -eq 0 ]"
check "record prints the counts" "printf '%s\n' \"\$OUT\" | grep -qF 'Recorded 3 findings for docs/SPEC.md, docs/DESIGN.md'"
check "record counts by severity and status" "printf '%s\n' \"\$OUT\" | grep -qF 'critical 1, major 1, minor 1; fixed 2, not fixed 1'"
check "record lists findings not fixed with the reason" "printf '%s\n' \"\$OUT\" | grep -qF 'The third cell is a planned column'"
check "a file named by its base name is matched" "grep -q '\"file\": \"docs/SPEC.md\"' \"$REV/findings.json\" && ! grep -q '\"file\": \"SPEC.md\"' \"$REV/findings.json\""
check "findings are sorted by severity" "python3 -c 'import json,sys; f=json.load(open(sys.argv[1]))[\"findings\"]; sys.exit(0 if [x[\"severity\"] for x in f]==[\"critical\",\"major\",\"minor\"] else 1)' \"$REV/findings.json\""
check "the record files are readable only by the user" \
  "[ \"\$(stat -f %Lp \"$REV/review.md\" 2>/dev/null || stat -c %a \"$REV/review.md\")\" = 600 ] && [ \"\$(stat -f %Lp \"$REV/findings.json\" 2>/dev/null || stat -c %a \"$REV/findings.json\")\" = 600 ]"
check "review.md has the table, the decisions, and the form checks" \
  "grep -qF '| Critical | 1 | 1 | 0 |' \"$REV/review.md\" && grep -qF 'Not fixed: The third cell is a planned column' \"$REV/review.md\" && grep -qF 'heading 4 follows 2' \"$REV/review.md\""

printf '[{"severity":"critical","reviewer":"content","file":"docs/DESIGN.md","where":"## 2. Data model","problem":"No keys","fix":"Add keys","status":"rejected","reason":"Out of scope for this document"}]' > "$F"
OUT="$(record)"
check "a critical finding left unfixed asks for the user" "printf '%s\n' \"\$OUT\" | grep -qF 'Critical findings not fixed: 1. Ask the user how to proceed.'"
printf '[]' > "$F"
OUT="$(record)"
check "an empty list records no findings" "printf '%s\n' \"\$OUT\" | grep -qF 'Recorded no findings' && grep -qF 'No findings.' \"$REV/review.md\""

OUT2="$(cd "$R" && run start docs/SPEC.md)"
REV2="$(printf '%s\n' "$OUT2" | sed -n 's/^Review: //p')"
check "a second start gets its own folder" "[ -n \"$REV2\" ] && [ \"$REV2\" != \"$REV\" ] && [ -f \"$REV2/start.json\" ]"
check "the second start reads the changed document" "printf '%s\n' \"\$OUT2\" | grep -qF 'heading 3 follows 4'"

(cd "$R" && run start docs/NOPE.md >/dev/null 2>&1); CODE=$?
check "a missing document exits 3" "[ $CODE -eq 3 ]"
python3 "$SCRIPT" record "$T/nowhere" --findings "$F" >/dev/null 2>&1; CODE=$?
check "a missing review folder exits 3" "[ $CODE -eq 3 ]"
check "the state folder is readable only by the user" "[ \"\$(stat -f %Lp \"$DOC_REVIEW_HOME\" 2>/dev/null || stat -c %a \"$DOC_REVIEW_HOME\")\" = 700 ]"
check "the documents were not changed by the script" "grep -qF '| b | 2 | 3 |' \"$R/docs/SPEC.md\" && [ ! -e \"$R/.doc-review\" ]"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
