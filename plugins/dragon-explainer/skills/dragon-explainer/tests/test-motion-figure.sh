#!/bin/bash
# Tests for the motion block: a page written by `motion-diagram render`, named in the content JSON,
# is carried byte for byte in a frame of its own inside a captioned figure.
#
# What is checked:
#   1. render.py and build.py make the figure and its frame, the built file passes check.py, and a
#      missing or foreign page is refused with the block named. despace.py leaves the page alone.
#   2. build.py still refuses any other frame, and an html block still cannot hold one.
#   3. In a headless browser: the frame is as tall as the picture at 1400 and 390 px, a figure on a
#      later tab waits finished and runs once when shown, every figure on paper (?paper=1) shows the
#      finished picture and fits it, and the figures follow the light or dark of the document.
#      Without a browser these cases fail.
#   4. The docs, the schema, and the changelog describe the block.
#
# tests/fixtures/motion-page.html is a page written by `motion-diagram render` from the
# pull-requests example of motion-diagram; render it again with that command when the page changes.
#
# Exit 0 when every case passes, 1 when any fails (the failing cases are listed).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN="$(cd "$SKILL_DIR/../.." && pwd)"
SCRIPTS="$SKILL_DIR/scripts"
RENDER="$SCRIPTS/render.py"
DESPACE="$SCRIPTS/despace.py"
BUILD="$SCRIPTS/build.py"
CHECK="$SCRIPTS/check.py"
PAGE="$SCRIPT_DIR/fixtures/motion-page.html"
export PYTHONDONTWRITEBYTECODE=1

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dx-motion-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
FAILED=()
why=""

check() {
  local name="$1" fn="$2"
  why=""
  if "$fn"; then
    echo "  PASS: $name"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $name${why:+ ($why)}"; FAIL=$((FAIL + 1)); FAILED+=("$name")
  fi
}

# content <file> <lang> <page of the first tab's figure or ""> <page of the second tab's figure or "">:
# writes a content JSON with two tabs, each with one section, and a motion figure where a page is
# named. The Japanese text is written with JSON escapes so this file stays in English.
content() {
  python3 - "$@" <<'PY'
import json, sys
out, lang, first, second = sys.argv[1:5]
ja = lang == "ja"
def section(key, page, n):
    blocks = [{"type": "paragraph", "text": "\u4ed5\u7d44\u307f\u3092\u793a\u3059\u3002" if ja else "The flow of a pull request."}]
    if page:
        blocks.append({"type": "motion", "id": key + "-flow", "page": page,
                       "caption": ("\u56f3" if ja else "Figure ") + "1 " + ("\u5909\u66f4\u306e\u6d41\u308c" if ja else "Pull requests reach main")})
        return {"id": key + "-s1", "title": "Flow %d" % n, "blocks": blocks}
    return {"id": key + "-s1", "title": "Flow %d" % n, "nofigure": "text only", "blocks": blocks}
doc = {"title": "Pull requests", "lead": "How a pull request reaches main.", "lang": lang,
       "tabs": [{"id": "a", "label": "First", "sections": [section("a", first, 1)]},
                {"id": "b", "label": "Second", "sections": [section("b", second, 2)]}]}
json.dump(doc, open(out, "w"), ensure_ascii=True)
PY
}

# build <name> [ja]: renders and builds $WORK/<name>.json into $WORK/<name>.html.
build() {
  local name="$1" lang="${2:-en}"
  python3 "$RENDER" --in "$WORK/$name.json" --out "$WORK/$name.body.html" > "$WORK/$name.render" 2>&1 || { why="render exited $?: $(head -2 "$WORK/$name.render" | tr '\n' ' ')"; return 1; }
  if [ "$lang" = ja ]; then python3 "$DESPACE" "$WORK/$name.body.html" > /dev/null 2>&1 || { why="despace failed"; return 1; }; fi
  python3 "$BUILD" --in "$WORK/$name.body.html" --out "$WORK/$name.html" > "$WORK/$name.build" 2>&1 || { why="build exited $?: $(head -2 "$WORK/$name.build" | tr '\n' ' ')"; return 1; }
}

# frame_page <html> <figure id>: prints the page the frame of that figure carries.
frame_page() {
  python3 - "$1" "$2" <<'PY'
import sys
from html.parser import HTMLParser
class Find(HTMLParser):
    def __init__(self, want):
        super().__init__(convert_charrefs=True)
        self.want, self.inside, self.found = want, 0, None
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "figure" and a.get("id") == self.want:
            self.inside = 1
        elif tag == "iframe" and self.inside and self.found is None:
            self.found = a.get("srcdoc")
    def handle_endtag(self, tag):
        if tag == "figure":
            self.inside = 0
f = Find(sys.argv[2])
f.feed(open(sys.argv[1], encoding="utf-8").read().replace("<template", "<div data-was-template").replace("</template>", "</div>"))
if f.found is None:
    sys.exit(1)
sys.stdout.write(f.found)
PY
}

# --- 1. render and build ------------------------------------------------------------------------

a_motion_block_builds_a_figure() {
  cp "$PAGE" "$WORK/motion-page.html"
  content "$WORK/doc.json" en motion-page.html motion-page.html
  build doc || return 1
  grep -qE '<figure class="motion" id="a-flow">' "$WORK/doc.html" || { why="no motion figure with the block id"; return 1; }
  grep -qE '<figcaption>.*Pull requests reach main</figcaption>' "$WORK/doc.html" || { why="no caption"; return 1; }
  frame_page "$WORK/doc.html" a-flow > "$WORK/a.page" || { why="the figure has no frame with a page"; return 1; }
  cmp -s "$WORK/a.page" "$PAGE" || { why="the page in the frame differs from the rendered page"; return 1; }
  frame_page "$WORK/doc.html" b-flow > "$WORK/b.page" || { why="the figure of the second tab has no frame"; return 1; }
  cmp -s "$WORK/b.page" "$PAGE" || { why="the page in the second tab's frame differs"; return 1; }
  python3 "$CHECK" "$WORK/doc.html" > "$WORK/check.out" 2>&1 || { why="check.py: $(grep -m2 -E 'NG|FAIL' "$WORK/check.out" | tr '\n' ' ')"; return 1; }
}

a_motion_block_with_a_bad_page_is_refused() {
  local name
  printf '<!doctype html><html><body><p>Not a motion page</p></body></html>\n' > "$WORK/foreign.html"
  for name in missing.html foreign.html; do
    content "$WORK/bad.json" en "$name" ""
    rm -f "$WORK/bad.body.html"
    if python3 "$RENDER" --in "$WORK/bad.json" --out "$WORK/bad.body.html" > "$WORK/bad.out" 2>&1; then why="render accepted $name"; return 1; fi
    grep -q 'a-flow' "$WORK/bad.out" || { why="the refusal for $name does not name the block: $(head -1 "$WORK/bad.out")"; return 1; }
    [ ! -e "$WORK/bad.body.html" ] || { why="render wrote a file for $name"; return 1; }
  done
}

despace_leaves_the_page() {
  cp "$PAGE" "$WORK/motion-page.html"
  content "$WORK/ja.json" ja motion-page.html ""
  build ja ja || return 1
  frame_page "$WORK/ja.html" a-flow > "$WORK/ja.page" || { why="the Japanese document has no frame with a page"; return 1; }
  cmp -s "$WORK/ja.page" "$PAGE" || { why="despace changed the embedded page"; return 1; }
}

# --- 2. other frames stay refused ---------------------------------------------------------------

# A body rendered without a motion block builds; the same body with another frame put into its first
# section is refused, and nothing is written.
build_refuses_other_frames() {
  local frame
  content "$WORK/plain.json" en "" ""
  python3 "$RENDER" --in "$WORK/plain.json" --out "$WORK/plain.body.html" > /dev/null 2>&1 || { why="the plain document did not render"; return 1; }
  python3 "$BUILD" --in "$WORK/plain.body.html" --out "$WORK/plain.html" > /dev/null 2>&1 || { why="the plain document did not build"; return 1; }
  for frame in '<iframe src="https://example.com/x"></iframe>' '<iframe srcdoc="&lt;p&gt;x&lt;/p&gt;"></iframe>' '<iframe class="motion-frame" src="https://example.com/x"></iframe>'; do
    python3 - "$WORK/plain.body.html" "$WORK/frame.body.html" "$frame" <<'PY'
import sys
body = open(sys.argv[1], encoding="utf-8").read()
at = body.index("The flow of a pull request.")
open(sys.argv[2], "w", encoding="utf-8").write(body[:at] + sys.argv[3] + body[at:])
PY
    rm -f "$WORK/frame.html"
    if python3 "$BUILD" --in "$WORK/frame.body.html" --out "$WORK/frame.html" > /dev/null 2>&1; then why="build accepted $frame"; return 1; fi
    [ ! -e "$WORK/frame.html" ] || { why="build wrote a file for $frame"; return 1; }
  done
}

# The same html block renders with a plain box and is refused with a frame.
an_html_block_cannot_hold_a_frame() {
  local inner
  for inner in '<div>box</div>' '<iframe src="https://example.com/x"></iframe>'; do
    python3 - "$WORK/html-frame.json" "$inner" <<'PY'
import json, sys
json.dump({"title": "Frame", "lead": "A frame in html.", "tabs": [{"id": "a", "label": "A", "sections": [{"id": "a-s1", "title": "A", "blocks": [
    {"type": "html", "id": "a-free", "caption": "Figure 1 Frame", "html": sys.argv[2]}]}]}]},
    open(sys.argv[1], "w"))
PY
    if python3 "$RENDER" --in "$WORK/html-frame.json" --out "$WORK/html-frame.body.html" > /dev/null 2>&1; then
      [ "$inner" = '<div>box</div>' ] || { why="render accepted an html block with a frame"; return 1; }
    else
      [ "$inner" != '<div>box</div>' ] || { why="render refused the html block with a plain box"; return 1; }
    fi
  done
}

# --- 3. in a headless browser -------------------------------------------------------------------

# probe <html> <query> <width> <out> <steps>: opens a copy of the document with a script that waits
# for every motion frame to load, takes <steps>, and saves what it saw as JSON.
probe() {
  local html="$1" query="$2" width="$3" out="$4" steps="$5"
  python3 - "$SCRIPTS" "$html" "$query" "$width" "$out" "$steps" <<'PY'
import json, re, sys
sys.path.insert(0, sys.argv[1])
import chrome
html, query, width, out, steps = sys.argv[2], sys.argv[3], int(sys.argv[4]), sys.argv[5], sys.argv[6]
exe, _ = chrome.find_chrome()
if not exe:
    print("no browser"); sys.exit(1)
script = """<script>
(function () {
  var pause = function (ms) { return new Promise(function (r) { setTimeout(r, ms); }); };
  var frames = function () { return [].slice.call(document.querySelectorAll('figure.motion iframe')); };
  var page = function (f) { try { var d = f.contentDocument; return d && d.querySelector('[data-md]') ? d : null; } catch (e) { return null; } };
  var look = function (f) {
    var d = page(f), counts = {}, finals = JSON.parse(d.getElementById('md-spec').textContent).finals;
    [].forEach.call(d.querySelectorAll('[data-count-for]'), function (e) { counts[e.getAttribute('data-count-for')] = Number(e.textContent.replace(/\\D/g, '')); });
    var cards = [].slice.call(d.querySelectorAll('.md-card'));
    return { full: Object.keys(finals).every(function (k) { return counts[k] === finals[k]; }), shown: cards.filter(function (c) { return c.style.opacity === '1'; }).length,
             places: cards.map(function (c) { return c.style.transform + ' ' + c.style.opacity; }).join('|'),
             height: f.getBoundingClientRect().height, inner: Math.ceil(d.body.getBoundingClientRect().height), width: f.getBoundingClientRect().width, theme: d.documentElement.getAttribute('data-theme') };
  };
  var moving = async function (f) { var a = look(f).places; await pause(400); return look(f).places !== a; };
  var starts = async function (f) { for (var i = 0; i < 8; i++) { if (await moving(f)) return true; } return false; };
  var settle = async function (f) { for (var i = 0; i < 200 && await moving(f); i++); };
  var loaded = async function () { for (var i = 0; i < 100; i++) { if (frames().length && frames().every(page)) return true; await pause(100); } return false; };
  var seen = {};
  // The mark is put together here, so the source of this script never matches it.
  var mark = '@@PRO' + 'BE@@';
  var done = function () { var p = document.createElement('pre'); p.id = 'probe-out'; p.textContent = mark + JSON.stringify(seen) + mark; document.body.appendChild(p); };
  window.addEventListener('load', async function () {
    try { %s } catch (e) { seen.error = String(e && e.stack || e); }
    done();
  });
})();
</script>""" % steps
doc = open(html, encoding="utf-8").read()
i = doc.lower().rfind("</body>")
copy = out + ".html"
open(copy, "w", encoding="utf-8").write(doc[:i] + script + doc[i:])
dom, err = chrome.run(exe, copy + query, width, 900, 30000, 180)
if err:
    print(err); sys.exit(1)
m = re.search(r"@@PROBE@@(.*?)@@PROBE@@", dom, re.S)
if not m:
    print("the document reported nothing"); sys.exit(1)
open(out, "w").write(m.group(1))
PY
}

# seen_is <json> <python condition on d>: prints what was seen when the condition does not hold.
seen_is() {
  python3 - "$1" "$2" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
if not eval(sys.argv[2], {}, {"d": d}):
    print(json.dumps(d)[:400])
    sys.exit(1)
PY
}

the_frame_is_as_tall_as_the_picture() {
  local width
  [ -s "$WORK/doc.html" ] || a_motion_block_builds_a_figure || return 1
  for width in 1400 390; do
    probe "$WORK/doc.html" "" "$width" "$WORK/tall-$width.json" "
      seen.loaded = await loaded(); await pause(1500);
      var s = look(frames()[0]); seen.height = s.height; seen.inner = s.inner; seen.width = s.width;
      seen.section = document.querySelector('#a-s1').getBoundingClientRect().width;" > "$WORK/tall.err" || { why="at $width px: $(cat "$WORK/tall.err")"; return 1; }
    seen_is "$WORK/tall-$width.json" 'd.get("loaded") and d.get("inner", 0) > 100 and abs(d["height"] - d["inner"]) <= 2 and d["width"] <= d["section"]' > "$WORK/tall.diff" || { why="at $width px the frame does not fit the picture: $(cat "$WORK/tall.diff")"; return 1; }
  done
}

# On virtual time the headless browser does not compute when a frame comes on screen, so the page in
# this document gets two stand-ins in its head: a timer for the animation frames and an observer that
# reports the picture on screen when the steps call it, as a browser does when the tab opens.
a_figure_on_a_later_tab_runs_when_shown() {
  python3 - "$PAGE" "$WORK/motion-page.html" <<'PY'
import sys
page = open(sys.argv[1], encoding="utf-8").read()
stand_in = """<script>
window.requestAnimationFrame = f => setTimeout(() => f(performance.now()), 16);
window.__watchers = [];
window.IntersectionObserver = class { constructor(cb) { this.cb = cb; window.__watchers.push(this); } observe(el) { this.el = el; } disconnect() { this.off = true; } };
window.__onScreen = on => window.__watchers.forEach(w => { if (!w.off && w.el) w.cb([{ isIntersecting: on, target: w.el }]); });
</script>"""
open(sys.argv[2], "w", encoding="utf-8").write(page.replace("<head>", "<head>" + stand_in, 1))
PY
  content "$WORK/later.json" en "" motion-page.html
  build later || return 1
  probe "$WORK/later.html" "" 1400 "$WORK/later.json.seen" "
    seen.before = frames().length;
    document.querySelector('[role=tab][data-page=\"b\"]').click();
    seen.loaded = await loaded(); var f = frames()[0];
    f.contentWindow.__onScreen(false); await pause(2000);
    var b = look(f); seen.waitFull = b.full; seen.waitShown = b.shown; seen.waitMoving = await moving(f);
    f.contentWindow.__onScreen(true); seen.started = await starts(f);
    await settle(f); var a = look(f); seen.endFull = a.full;
    f.contentWindow.__onScreen(false); f.contentWindow.__onScreen(true); seen.again = await starts(f);" > "$WORK/later.err" || { why="$(cat "$WORK/later.err")"; return 1; }
  seen_is "$WORK/later.json.seen" 'd.get("before") == 0 and d.get("loaded")' > "$WORK/later.diff" || { why="the figure was not made when the tab opened: $(cat "$WORK/later.diff")"; return 1; }
  seen_is "$WORK/later.json.seen" 'd.get("waitFull") and d.get("waitShown", 0) > 0 and d.get("waitMoving") is False' > "$WORK/later.diff" || { why="the figure did not wait finished: $(cat "$WORK/later.diff")"; return 1; }
  seen_is "$WORK/later.json.seen" 'd.get("started") is True and d.get("endFull") and d.get("again") is False' > "$WORK/later.diff" || { why="the figure did not run once when shown: $(cat "$WORK/later.diff")"; return 1; }
}

# Paper mode fills every page, and printing starts with beforeprint, which the browser also sends to
# each frame. The figures are read at that moment: on virtual time a figure already on screen may have
# started a run that the headless browser never moves past its first frame.
on_paper_every_figure_is_finished() {
  [ -s "$WORK/doc.html" ] || a_motion_block_builds_a_figure || return 1
  probe "$WORK/doc.html" "?paper=1" 1400 "$WORK/paper.json" "
    seen.loaded = await loaded(); await pause(500);
    window.dispatchEvent(new Event('beforeprint'));
    seen.figures = frames().map(function (f) { var s = look(f); return { full: s.full, shown: s.shown, height: s.height, inner: s.inner }; });" > "$WORK/paper.err" || { why="$(cat "$WORK/paper.err")"; return 1; }
  seen_is "$WORK/paper.json" 'd.get("loaded") and len(d.get("figures", [])) == 2 and all(f["full"] and f["shown"] > 0 and abs(f["height"] - f["inner"]) <= 2 for f in d["figures"])' > "$WORK/paper.diff" || { why="$(cat "$WORK/paper.diff")"; return 1; }
}

figures_follow_light_and_dark() {
  [ -s "$WORK/doc.html" ] || a_motion_block_builds_a_figure || return 1
  probe "$WORK/doc.html" "" 1400 "$WORK/theme.json" "
    seen.loaded = await loaded(); await pause(300);
    document.querySelector('button[data-theme-choice=\"dark\"]').click(); await pause(100);
    seen.dark = look(frames()[0]).theme;
    document.querySelector('button[data-theme-choice=\"light\"]').click(); await pause(100);
    seen.light = look(frames()[0]).theme;" > "$WORK/theme.err" || { why="$(cat "$WORK/theme.err")"; return 1; }
  seen_is "$WORK/theme.json" 'd.get("dark") == "dark" and d.get("light") == "light"' > "$WORK/theme.diff" || { why="$(cat "$WORK/theme.diff")"; return 1; }
}

# --- 4. docs ------------------------------------------------------------------------------------

the_docs_describe_the_block() {
  python3 - "$SKILL_DIR" "$PLUGIN" <<'PY' > "$WORK/docs.diff" || { why="$(cat "$WORK/docs.diff")"; return 1; }
import json, re, sys
skill, plugin = sys.argv[1], sys.argv[2]
missing = []
def need(path, *words):
    text = open(path, encoding="utf-8").read()
    lacks = [w for w in words if w not in text]
    if lacks:
        missing.append("%s lacks %s" % (path.split("/plugins/")[-1], ", ".join(lacks)))
need(skill + "/SKILL.md", "`motion`", "motion-diagram render")
need(skill + "/references/document-shape.md", "`motion`", "motion-diagram render")
for page in ("README.md", "README.ja.md", "docs/how-it-works.md", "docs/how-it-works.ja.md"):
    need(plugin + "/" + page, "motion", "motion-diagram")
schema = json.load(open(skill + "/references/content.schema.json"))
block = schema["$defs"]["block"]
if "motion" not in block["properties"]["type"]["enum"]:
    missing.append("the schema enum has no motion")
if not any(r.get("if", {}).get("properties", {}).get("type", {}).get("const") == "motion" and set(r.get("then", {}).get("required", [])) >= {"id", "page", "caption"} for r in block.get("allOf", [])):
    missing.append("the schema does not require id, page, and caption for motion")
log = open(plugin + "/CHANGELOG.md", encoding="utf-8").read()
# The line moves from Unreleased into a release section when the plugin is released.
releases = log.split("## [Unreleased]", 1)[-1]
if "`motion`" not in releases:
    missing.append("the changelog has no motion line under Unreleased or a release")
if missing:
    print("; ".join(missing))
    sys.exit(1)
PY
}

echo "[test-motion-figure]"
check "a motion block builds a captioned figure that carries the page in a frame" a_motion_block_builds_a_figure
check "a motion block with a missing or foreign page is refused" a_motion_block_with_a_bad_page_is_refused
check "despace leaves the embedded page as it was" despace_leaves_the_page
check "build refuses a frame that is not a motion figure" build_refuses_other_frames
check "an html block holding a frame is refused" an_html_block_cannot_hold_a_frame
check "the frame is as tall as the picture at 1400 and 390 px" the_frame_is_as_tall_as_the_picture
check "a motion figure on a later tab waits finished and runs once when shown" a_figure_on_a_later_tab_runs_when_shown
check "on paper every motion figure shows the finished picture and fits it" on_paper_every_figure_is_finished
check "motion figures follow the light or dark of the document" figures_follow_light_and_dark
check "the docs, the schema, and the changelog describe the motion block" the_docs_describe_the_block

echo ""
echo "[test-motion-figure] ran: $((PASS + FAIL))"
echo "[test-motion-figure] PASS: $PASS, FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "failed cases:"
  for name in "${FAILED[@]}"; do echo "    $name"; done
  exit 1
fi
exit 0
