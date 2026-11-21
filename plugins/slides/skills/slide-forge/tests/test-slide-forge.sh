#!/usr/bin/env bash
# Tests for the slide-forge skill of the slides plugin: how SKILL.md and scripts/export_all.sh run
# the PowerPoint builder through uv, what the export writes with uv, without uv, and without
# Playwright's browser, the language switch of the edit toolbar, and the dependency rule in AGENTS.md.
# Every deck is written to a throwaway folder. The export runs uv, which fetches python-pptx, Pillow,
# and Playwright into uv's cache the first time; the browser is never downloaded.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$HERE/.." && pwd)"
PLUGIN_DIR="$(cd "$HERE/../../.." && pwd)"
REPO="$(cd "$PLUGIN_DIR/../.." && pwd)"
SKILL="$SKILL_DIR/SKILL.md"
EXPORT="$SKILL_DIR/scripts/export_all.sh"
INJECT="$SKILL_DIR/scripts/inject_edit_mode.py"
PASS=0
FAIL=0
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export PYTHONDONTWRITEBYTECODE=1

why=""
check() {
  why=""
  if "$2"; then
    PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"
  else
    FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"
    [ -n "$why" ] && printf '        %s\n' "$why"
  fi
}

# need <file>...: every file exists.
need() {
  local f
  for f in "$@"; do
    [ -f "$f" ] || { why="$f is missing"; return 1; }
  done
}

# deck <folder>: writes the content.json and edit-mode.html that the edit step leaves in a deck
# folder. The avatar is a 40 x 20 PNG, so the builder has to crop it to a square.
deck() {
  mkdir -p "$1"
  python3 - "$1" <<'PY'
import base64, json, struct, sys, zlib
def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
rows = b"".join(b"\x00" + b"\x30\x60\x90" * 40 for _ in range(20))
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 40, 20, 8, 2, 0, 0, 0)) \
    + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"")
content = {
    "title": "Team update",
    "subtitle": "Support desk, week 12",
    "avatar": "data:image/png;base64," + base64.b64encode(png).decode(),
    "bullets": ["Replies now go out within four hours", "Two people joined the night shift"],
    "footer": "Week 12",
}
open(sys.argv[1] + "/content.json", "w", encoding="utf-8").write(json.dumps(content))
open(sys.argv[1] + "/edit-mode.html", "w", encoding="utf-8").write(
    '<!doctype html>\n<html lang="en"><head><meta charset="utf-8"><title>Team update</title>\n'
    "<!-- slide-forge-inject-start --><script>/* editor */</script><!-- slide-forge-inject-end -->\n"
    '</head><body><h1 contenteditable="true" data-key="title">Team update</h1>\n'
    '<!-- slide-forge-inject-start --><div id="slide-forge-toolbar"></div><!-- slide-forge-inject-end -->\n'
    "</body></html>\n")
PY
}

# Runs the export once, with uv on PATH and with an empty folder as Playwright's browser folder, so
# the PDF cannot be printed. Two checks read the result: export_out, export_status, and $T/project.
exported=""
export_once() {
  need "$EXPORT" || return 1
  command -v uv >/dev/null || { why="uv is not on PATH, so the export cannot run"; return 1; }
  [ -n "$exported" ] && return 0
  exported=1
  deck "$T/project/decks/team-update"
  mkdir -p "$T/no-browsers"
  export_out="$(cd "$T/project" && PLAYWRIGHT_BROWSERS_PATH="$T/no-browsers" bash "$EXPORT" decks/team-update 2>&1)"
  export_status=$?
}

builder_through_uv() {
  need "$SKILL" "$EXPORT" || return 1
  local f hits
  for f in "$SKILL" "$EXPORT"; do
    grep -F 'uv run' "$f" | grep -F -- '--with python-pptx' | grep -F -- '--with Pillow' | grep -qF 'build_pptx.py' \
      || { why="$(basename "$f") has no line that runs build_pptx.py through uv run --with python-pptx --with Pillow"; return 1; }
  done
  hits="$(grep -lF 'pip install' "$SKILL" "$EXPORT" "$SKILL_DIR"/references/*.md 2>/dev/null)"
  [ -z "$hits" ] || { why="pip install is still asked for in: $(printf '%s ' $hits)"; return 1; }
}

writes_pptx() {
  export_once || return 1
  local folder="$T/project/decks/team-update" problems
  [ "$export_status" -eq 0 ] || { why="the export exited $export_status: $(printf '%s' "$export_out" | tail -5 | tr '\n' ' ')"; return 1; }
  need "$folder/team-update.pptx" "$folder/team-update.html" || return 1
  problems="$(python3 - "$folder/team-update.pptx" "$folder/team-update.html" <<'PY'
import sys, zipfile
problems = []
try:
    deck = zipfile.ZipFile(sys.argv[1])
    slide = deck.read("ppt/slides/slide1.xml").decode("utf-8")
    for text in ("Team update", "Two people joined the night shift", "Week 12"):
        if text not in slide:
            problems.append(f"the slide lacks {text!r}")
    if not any(name.startswith("ppt/media/") for name in deck.namelist()):
        problems.append("the avatar picture is missing")
except (zipfile.BadZipFile, KeyError) as error:
    problems.append(f"not a PowerPoint file: {error}")
page = open(sys.argv[2], encoding="utf-8").read()
if "Team update" not in page:
    problems.append("the HTML lost the slide")
if "slide-forge-inject" in page:
    problems.append("the HTML keeps the edit toolbar")
print("; ".join(problems))
PY
)"
  [ -z "$problems" ] || { why="$problems"; return 1; }
}

stops_without_uv() {
  need "$EXPORT" || return 1
  local folder="$T/plain/decks/intro" d before after out status
  for d in /usr/bin /bin; do
    [ ! -e "$d/uv" ] || { why="$d/uv exists, so PATH cannot leave uv out"; return 1; }
  done
  deck "$folder"
  before="$(ls -A "$folder")"
  out="$(cd "$T/plain" && PATH=/usr/bin:/bin /bin/bash "$EXPORT" decks/intro 2>&1)"
  status=$?
  after="$(ls -A "$folder")"
  [ "$status" -ne 0 ] || { why="the export exited 0 without uv: $out"; return 1; }
  [ "$before" = "$after" ] || { why="files were written without uv: $(printf '%s ' $after)"; return 1; }
  printf '%s' "$out" | grep -qiw 'install' && printf '%s' "$out" | grep -qw 'uv' \
    || { why="the message does not say how to install uv: $out"; return 1; }
}

skips_pdf_without_browser() {
  export_once || return 1
  local folder="$T/project/decks/team-update"
  grep -qF 'uv run --with playwright' "$EXPORT" || { why="export_all.sh does not print the PDF through uv run --with playwright"; return 1; }
  [ "$export_status" -eq 0 ] || { why="the export exited $export_status without the browser: $(printf '%s' "$export_out" | tail -5 | tr '\n' ' ')"; return 1; }
  [ ! -e "$folder/team-update.pdf" ] || { why="a PDF was written without the browser"; return 1; }
  need "$folder/team-update.pptx" "$folder/team-update.html" || return 1
  [[ "$export_out" == *"playwright install chromium"* ]] || { why="the message does not say how to install the browser: $export_out"; return 1; }
  [ -z "$(ls -A "$T/no-browsers")" ] || { why="a browser was downloaded into PLAYWRIGHT_BROWSERS_PATH"; return 1; }
}

toolbar_languages() {
  need "$INJECT" || return 1
  local out problems
  printf '%s\n' '<!doctype html>' '<html lang="en"><head><meta charset="utf-8"><title>About me</title></head>' \
    '<body><h1 contenteditable="true" data-key="title">About me</h1></body></html>' > "$T/static.html"
  out="$(python3 "$INJECT" "$T/static.html" "$T/edit.html" 2>&1)" || { why="the injector failed: $out"; return 1; }
  problems="$(python3 - "$T/edit.html" <<'PY'
import json, re, sys
page = open(sys.argv[1], encoding="utf-8").read()
# Kana, kanji, and half-width kana, the ranges scripts/check.sh reads as Japanese.
japanese = re.compile("[%s-%s%s-%s%s-%s]" % tuple(map(chr, (0x3040, 0x30FF, 0x3400, 0x9FFF, 0xFF66, 0xFF9F))))
found = re.search(r'<script type="application/json" id="slide-forge-text">(.*?)</script>', page, re.S)
if not found:
    sys.exit(print("no dictionary in <script type=\"application/json\" id=\"slide-forge-text\">"))
text = json.loads(found.group(1))
if sorted(text) != ["en", "ja"]:
    sys.exit(print(f"the dictionary has {sorted(text)}, not en and ja"))
problems = []
if set(text["en"]) != set(text["ja"]):
    problems.append(f"en and ja differ in {sorted(set(text['en']) ^ set(text['ja']))}")
problems += [f"ja.{key} is not Japanese" for key, value in text["ja"].items() if not japanese.search(value)]
bar = re.search(r'<div id="slide-forge-toolbar"[^>]*>.*?<!-- slide-forge-inject-end -->', page, re.S)
if not bar:
    sys.exit(print("; ".join(problems + ["no toolbar"])))
bar = bar.group(0)
if not re.match(r'<div id="slide-forge-toolbar"[^>]*\blang="en"', bar):
    problems.append("the toolbar is not marked lang=en")
switch = re.findall(r'<button[^>]*data-lang="(\w+)"[^>]*>([^<]*)</button>', bar)
if switch != [("en", "English"), ("ja", "日本語")]:
    problems.append(f"the switch is {switch}, not English and Japanese")
labels = re.findall(r'<(\w+)[^>]*\bdata-t="([\w-]+)"[^>]*>([^<]*)</\1>', bar)
if not labels:
    problems.append("no toolbar label reads the dictionary")
for tag, key, label in labels:
    if key not in text["en"]:
        problems.append(f"{key} is not in the dictionary")
    elif label.strip() != text["en"][key]:
        problems.append(f"{key} shows {label.strip()!r}, not the English {text['en'][key]!r}")
if "data-lang=" not in bar or 0 <= bar.find("data-t=") < bar.find("data-lang="):
    problems.append("the language switch is not at the top of the toolbar")
for call in re.findall(r"\b(?:alert|confirm)\(([^)]*)\)", page):
    if not call.strip().startswith("t("):
        problems.append(f"a message is not read from the dictionary: {call}")
if japanese.search(page.replace(found.group(0), "").replace("日本語", "")):
    problems.append("Japanese text outside the dictionary")
print("; ".join(problems))
PY
)"
  [ -z "$problems" ] || { why="$problems"; return 1; }
}

agents_names_slides() {
  local rule word
  [ -f "$REPO/AGENTS.md" ] || { why="no AGENTS.md two folders above the plugin; run the tests in the repository"; return 1; }
  rule="$(grep -m1 'Keep runtime dependencies small' "$REPO/AGENTS.md")"
  for word in '`slides`' 'uv run --with' '`python-pptx`' '`Pillow`' 'Playwright' '`japanese-writing`' '`design-formats`'; do
    [[ "$rule" == *"$word"* ]] || { why="the dependency rule in AGENTS.md does not say $word"; return 1; }
  done
}

check "the SKILL.md runs the builder through uv" builder_through_uv
check "export writes a pptx with uv" writes_pptx
check "export stops without uv" stops_without_uv
check "export skips the PDF without the browser" skips_pdf_without_browser
check "the edit toolbar defaults to English and offers Japanese" toolbar_languages
check "AGENTS.md names slides as a uv exception" agents_names_slides

printf '\n%d passed, %d failed (%d ran)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
