#!/usr/bin/env bash
# Tests for the remotion-explainer plugin. They read the plugin's pages, manifests, and skills, and run
# the frame checks of remotion-frame-checks on the skill's valid examples and on broken copies made in
# a throwaway folder. PNG frames are drawn here with Python's zlib, so the plugin stores no image.
# The checks of remotion-motion-plan run the same way on the skill's example plans and evidence library.
# The catalog of remotion-catalog is fetched from git repositories made in the throwaway folder, with
# HOME pointing there too, so no network is used and no real data folder is touched.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$(cd "$HERE/.." && pwd)"
ROOT="$(cd "$PLUGIN/../.." && pwd)"
SKILLS="$PLUGIN/skills"
FRAME="$SKILLS/remotion-frame-checks"
MOTION="$SKILLS/remotion-motion-plan"
CATALOG="$SKILLS/remotion-catalog"
T="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$T"' EXIT

PASS=0
FAIL=0
why=""
ok() { PASS=$((PASS + 1)); printf 'ok    %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; [ -n "$why" ] && printf '        %s\n' "$why"; }
check() { why=""; if "$2"; then ok "$1"; else ng "$1"; fi; }

# Both READMEs name the Remotion License and who needs a Company License, the English one says the
# plugin bundles no Remotion package, and no package manifest or installed package sits in the plugin.
readme_license() {
  local f found
  for f in README.md README.ja.md; do
    [ -f "$PLUGIN/$f" ] || { why="$f is missing"; return 1; }
    grep -q 'Remotion License' "$PLUGIN/$f" || { why="$f does not name the Remotion License"; return 1; }
    grep -q 'Company License' "$PLUGIN/$f" || { why="$f does not say who needs a Company License"; return 1; }
  done
  grep -q 'bundles no Remotion package' "$PLUGIN/README.md" \
    || { why="README.md does not say that the plugin bundles no Remotion package"; return 1; }
  found="$(find "$PLUGIN" \( -name package.json -o -name node_modules \) -print | head -1)"
  [ -z "$found" ] || { why="the plugin holds ${found#"$PLUGIN"/}"; return 1; }
}

# The dependency line of AGENTS.md names the plugin among the exceptions, and the plugin's scripts
# import only Node.js built-in modules or files next to them, which is what that line promises.
agents_node() {
  local rule
  rule="$(grep -m1 'Keep runtime dependencies small' "$ROOT/AGENTS.md")"
  case "$rule" in *'`remotion-explainer`'*) ;; *) why="the dependency line of AGENTS.md does not name remotion-explainer"; return 1 ;; esac
  case "$rule" in *'Six plugins are exceptions'*) ;; *) why="the dependency line of AGENTS.md does not count six exceptions"; return 1 ;; esac
  why="$(python3 - "$SKILLS" <<'PY'
import os, re, sys
skills = sys.argv[1]
spec = re.compile(r"""(?:\bfrom\s*|\bimport\s*\(\s*|\bimport\s+|\brequire\s*\(\s*)["']([^"']+)["']""")
found = 0
for root, _, files in os.walk(skills):
    for name in files:
        if not name.endswith((".mjs", ".js", ".cjs")):
            continue
        found += 1
        path = os.path.join(root, name)
        for module in spec.findall(open(path, encoding="utf-8").read()):
            if not (module.startswith("node:") or module.startswith("./")):
                sys.exit(print(f"{os.path.relpath(path, skills)} imports {module}") or 1)
if not found:
    sys.exit(print("no script under skills/") or 1)
PY
)" || return 1
  why=""
}

# remotion-frame-checks provides its four contracts under formats/ and their four checks under
# scripts/, each with a version, names every file in SKILL.md, and follows no other skill.
frame_provides() {
  why="$(python3 - "$FRAME" <<'PY'
import json, os, re, sys
skill = sys.argv[1]
for need in ("SKILL.md", "agents/openai.yaml", "musubi.json"):
    if not os.path.isfile(os.path.join(skill, need)):
        sys.exit(print(f"remotion-frame-checks has no {need}") or 1)
manifest = json.load(open(os.path.join(skill, "musubi.json"), encoding="utf-8"))
body = open(os.path.join(skill, "SKILL.md"), encoding="utf-8").read()
if manifest.get("musubi") not in ("2026-11-19", "2026-11-20", "2026-11-21"):
    sys.exit(print(f"musubi.json names the definition {manifest.get('musubi')!r}") or 1)
want = {
    "svg-geometry": "formats/svg-geometry.md",
    "layout": "formats/layout.md",
    "timing-boundary": "formats/timing-boundary.md",
    "scene-layers": "formats/scene-layers.md",
    "check-svg-geometry": "scripts/check-svg-geometry.mjs",
    "check-layout": "scripts/check-layout.mjs",
    "check-timing-boundary": "scripts/check-timing-boundary.mjs",
    "check-scene-layers": "scripts/check-scene-layers.mjs",
}
provides = manifest.get("provides") or {}
if sorted(provides) != sorted(want):
    sys.exit(print("musubi.json provides " + ", ".join(sorted(provides)) + ", not " + ", ".join(sorted(want))) or 1)
for name, path in want.items():
    entry = provides[name]
    if entry.get("file") != path:
        sys.exit(print(f"{name} names {entry.get('file')!r}, not {path}") or 1)
    if not re.fullmatch(r"\d+\.\d+\.\d+", str(entry.get("version", ""))):
        sys.exit(print(f"{name} has no MAJOR.MINOR.PATCH version") or 1)
    if not os.path.isfile(os.path.join(skill, path)):
        sys.exit(print(f"{path} does not exist") or 1)
    if f"`{path}`" not in body:
        sys.exit(print(f"SKILL.md does not name `{path}`") or 1)
if manifest.get("follows"):
    sys.exit(print("remotion-frame-checks follows " + ", ".join(manifest["follows"])) or 1)
if "../" in body:
    sys.exit(print("SKILL.md reads a path outside its folder") or 1)
PY
)" || return 1
  why=""
}

# Each check passes the skill's valid example, refuses broken copies with the rule and the element,
# scene, or frame of the issue, and exits 2 when it is called the wrong way.
frame_judgments() {
  command -v node >/dev/null || { why="node is not installed"; return 1; }
  why="$(python3 - "$FRAME" "$T" <<'PY'
import copy, json, os, struct, subprocess, sys, zlib
frame, tmp = sys.argv[1], sys.argv[2]
scripts = os.path.join(frame, "scripts")
examples = os.path.join(frame, "examples")
problems = []

def run(script, args):
    p = subprocess.run(["node", os.path.join(scripts, script), *args], capture_output=True, text=True)
    try:
        out = json.loads(p.stdout)
    except ValueError:
        out = None
    return p.returncode, out, p.stderr.strip()

def summary(out, err):
    if out is None:
        return "no JSON result: " + (err.splitlines()[-1][:160] if err else "no output")
    rules = sorted({str(i.get("rule")) for i in out.get("issues") or []})
    return "decision " + str(out.get("decision")) + (" with " + ", ".join(rules) if rules else " and no issue")

def write(name, data):
    path = os.path.join(tmp, name)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f)
    return path

def passes(label, script, args):
    code, out, err = run(script, args)
    if code != 0 or not out or out.get("decision") != "pass" or out.get("issues"):
        problems.append(f"{label}: expected a pass, got exit {code} and {summary(out, err)}")
    return out

def refuses(label, script, rule, args, names=None):
    code, out, err = run(script, args)
    hits = [i for i in (out or {}).get("issues") or [] if i.get("rule") == rule]
    if code != 1 or (out or {}).get("decision") != "revise" or not hits:
        problems.append(f"{label}: expected exit 1 with {rule}, got exit {code} and {summary(out, err)}")
    elif names and not any(names(i) for i in hits):
        problems.append(f"{label}: the {rule} issue does not name where it is: {hits[0]}")

def load(name):
    with open(os.path.join(examples, name), encoding="utf-8") as f:
        return json.load(f)

def element(spec, id_):
    return next(e for e in spec["elements"] if e["id"] == id_)

def first_rule(spec, label):
    rules = [r for r in spec.get("clearanceRules") or [] if not r.get("allowOverlap") and (r.get("minimum") or 0) >= 2]
    if not rules:
        raise LookupError(f"the {label} example has no clearance rule with a minimum of 2 px or more")
    return rules[0]

def names_pair(rule):
    return lambda i: rule["a"] in str(i.get("element", "")) and rule["b"] in str(i.get("element", ""))

def overlap(spec, rule):
    s = copy.deepcopy(spec)
    a = element(s, rule["a"])["bounds"]
    element(s, rule["b"])["bounds"] = {"x": a["x"] + 1, "y": a["y"] + 1, "width": a["width"], "height": a["height"]}
    return s

def too_close(spec, rule):
    s = copy.deepcopy(spec)
    a = element(s, rule["a"])["bounds"]
    b = element(s, rule["b"])["bounds"]
    element(s, rule["b"])["bounds"] = {"x": a["x"] + a["width"] + rule["minimum"] / 2, "y": a["y"],
                                       "width": b["width"], "height": b["height"]}
    return s

def cases():
    # SVG geometry: overlap, clearance below the minimum, a connector off its port, an arrival that misses.
    geo = load("svg-geometry.json")
    passes("the svg-geometry example", "check-svg-geometry.mjs", [write("geo.json", geo)])
    rule = first_rule(geo, "svg-geometry")
    refuses("two SVG elements that overlap", "check-svg-geometry.mjs", "element-collision",
            [write("geo-overlap.json", overlap(geo, rule))], names_pair(rule))
    refuses("two SVG elements closer than the minimum", "check-svg-geometry.mjs", "element-clearance",
            [write("geo-close.json", too_close(geo, rule))], names_pair(rule))
    if not geo.get("connectors") or not geo.get("arrivals"):
        raise LookupError("the svg-geometry example has no connector or no arrival")
    g = copy.deepcopy(geo)
    g["connectors"][0]["points"][-1]["x"] += 10
    connector = g["connectors"][0]["id"]
    refuses("a connector that ends off its port", "check-svg-geometry.mjs", "connector-end",
            [write("geo-end.json", g)], lambda i: i.get("element") == connector)
    g = copy.deepcopy(geo)
    g["arrivals"][0]["actualPoint"]["x"] += 10
    arrival = g["arrivals"][0]["frame"]
    refuses("an arrival that stops short of its port", "check-svg-geometry.mjs", "arrival-miss",
            [write("geo-arrival.json", g)], lambda i: i.get("frame") == arrival)

    # Layout: overlap, clearance below the minimum, content in the subtitle zone, content outside the safe area.
    lay = load("layout-spec.json")
    passes("the layout example", "check-layout.mjs", [write("layout.json", lay)])
    rule = first_rule(lay, "layout")
    refuses("two layout elements that overlap", "check-layout.mjs", "collision",
            [write("layout-overlap.json", overlap(lay, rule))], names_pair(rule))
    refuses("two layout elements closer than the minimum", "check-layout.mjs", "clearance",
            [write("layout-close.json", too_close(lay, rule))], names_pair(rule))
    s = copy.deepcopy(lay)
    target = next(e for e in s["elements"] if e.get("role") != "caption")
    zone = s["subtitleSafeZone"]
    target["bounds"] = {"x": zone["x"], "y": zone["y"], "width": min(target["bounds"]["width"], zone["width"]),
                        "height": min(target["bounds"]["height"], zone["height"])}
    refuses("content inside the subtitle zone", "check-layout.mjs", "subtitle-collision",
            [write("layout-subtitle.json", s)], lambda i: i.get("element") == target["id"])
    s = copy.deepcopy(lay)
    target = next(e for e in s["elements"] if not e.get("allowOutsideSafe"))
    target["bounds"]["x"] = s["safeContent"]["x"] - 20
    refuses("content outside the safe area", "check-layout.mjs", "safe-content",
            [write("layout-safe.json", s)], lambda i: i.get("element") == target["id"])

    # Scene layers: a scene missing a layer, and two scenes in a row with the same design.
    sc = load("scene-design-layers.json")
    passes("the scene-layers example", "check-scene-layers.mjs", [write("scenes.json", sc)])
    s = copy.deepcopy(sc)
    del s["scenes"][1]["motion"]
    scene = s["scenes"][1]["id"]
    refuses("a scene without its motion layer", "check-scene-layers.mjs", "missing-layer",
            [write("scenes-missing.json", s)], lambda i: i.get("scene") == scene)
    s = copy.deepcopy(sc)
    for key in ("silhouetteFamily", "spatialGrammar", "revealGrammar"):
        s["scenes"][1][key] = s["scenes"][0][key]
    refuses("two scenes in a row with the same design", "check-scene-layers.mjs", "repeated-design-system",
            [write("scenes-repeated.json", s)], lambda i: i.get("scene") == scene)

    # Timing boundary: PNG frames around a start or an end, drawn with every row filter.
    background = (0xF4, 0xF5, 0xF1)
    def png(path, visible, color_type):
        width, height, bpp = 12, 10, 4 if color_type == 6 else 3
        rows, prev = [], bytes(width * bpp)
        for y in range(height):
            raw = bytearray()
            for x in range(width):
                pixel = (30, 30, 30) if visible and 2 <= x < 6 and 2 <= y < 5 else background
                raw += bytes(pixel + ((255,) if color_type == 6 else ()))
            kind = y % 5
            out = bytearray(len(raw))
            for i in range(len(raw)):
                a = raw[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                if kind == 0:
                    p = 0
                elif kind == 1:
                    p = a
                elif kind == 2:
                    p = b
                elif kind == 3:
                    p = (a + b) // 2
                else:
                    pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                    p = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                out[i] = (raw[i] - p) & 0xFF
            rows.append(bytes([kind]) + bytes(out))
            prev = bytes(raw)
        def chunk(kind, data):
            return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
        with open(path, "wb") as f:
            f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, color_type, 0, 0, 0))
                    + chunk(b"IDAT", zlib.compress(b"".join(rows))) + chunk(b"IEND", b""))
    def frames(label, pattern, color_type=6):
        entries = []
        for number, visible in sorted(pattern.items()):
            path = os.path.join(tmp, f"{label}-{number}.png")
            png(path, visible, color_type)
            entries.append(f"{number}={path}")
        return entries
    start = ["--background", "#F4F5F1", "--start", "10"]
    end = ["--background", "#F4F5F1", "--end", "20"]
    audit = os.path.join(tmp, "audit", "temporal-boundary-audit.json")
    passes("frames that appear after the start", "check-timing-boundary.mjs",
           start + ["--out", audit] + frames("enter", {8: 0, 9: 0, 10: 0, 11: 1, 12: 1}))
    try:
        if json.load(open(audit, encoding="utf-8")).get("decision") != "pass":
            problems.append("--out wrote a result other than the pass it printed")
    except (OSError, ValueError):
        problems.append("--out did not write the result")
    passes("RGB frames that appear after the start", "check-timing-boundary.mjs",
           start + frames("enter-rgb", {8: 0, 9: 0, 10: 0, 11: 1, 12: 1}, color_type=2))
    passes("frames that are gone at the end", "check-timing-boundary.mjs",
           end + frames("exit", {18: 1, 19: 1, 20: 0, 21: 0, 22: 0}))
    refuses("a frame visible at the start", "check-timing-boundary.mjs", "premature-visible-pixels",
            start + frames("early", {8: 0, 9: 0, 10: 1, 11: 1, 12: 1}), lambda i: i.get("frame") == 10)
    refuses("a frame visible after the end", "check-timing-boundary.mjs", "late-visible-pixels",
            end + frames("late", {18: 1, 19: 1, 20: 0, 21: 1, 22: 0}), lambda i: i.get("frame") == 21)
    refuses("an element shown for one frame", "check-timing-boundary.mjs", "short-lived",
            start + frames("flash", {8: 0, 9: 0, 10: 0, 11: 1, 12: 0}), lambda i: i.get("frame") == 11)
    refuses("an element that comes back after hiding", "check-timing-boundary.mjs", "flicker",
            start + frames("flicker", {8: 0, 9: 0, 10: 0, 11: 1, 12: 0, 13: 1}), lambda i: i.get("frame") == 12)
    refuses("a boundary frame left out", "check-timing-boundary.mjs", "missing-boundary-frame",
            start + frames("gap", {8: 0, 10: 0, 11: 1, 12: 1}), lambda i: i.get("frame") == 9)

    # Called the wrong way.
    for script, args in (("check-svg-geometry.mjs", []), ("check-layout.mjs", []), ("check-scene-layers.mjs", []),
                         ("check-timing-boundary.mjs", ["--start", "10"] + frames("usage", {8: 0, 9: 0, 10: 0, 11: 0, 12: 0}))):
        code, _, _ = run(script, args)
        if code != 2:
            problems.append(f"{script} {' '.join(args[:2])}: expected exit 2 for a wrong call, got {code}")

try:
    cases()
except (OSError, ValueError, LookupError, KeyError, IndexError, StopIteration, TypeError) as e:
    problems.append(f"{type(e).__name__}: {e}")
if problems:
    print(f"{len(problems)} problems; the first: {problems[0]}")
    sys.exit(1)
PY
)" || return 1
  why=""
}

# remotion-motion-plan provides its four contracts under formats/ and their four checks under scripts/,
# each with a version, names every file in SKILL.md, and follows no other skill.
motion_provides() {
  why="$(python3 - "$MOTION" <<'PY'
import json, os, re, sys
skill = sys.argv[1]
for need in ("SKILL.md", "agents/openai.yaml", "musubi.json"):
    if not os.path.isfile(os.path.join(skill, need)):
        sys.exit(print(f"remotion-motion-plan has no {need}") or 1)
manifest = json.load(open(os.path.join(skill, "musubi.json"), encoding="utf-8"))
body = open(os.path.join(skill, "SKILL.md"), encoding="utf-8").read()
if manifest.get("musubi") not in ("2026-11-19", "2026-11-20", "2026-11-21"):
    sys.exit(print(f"musubi.json names the definition {manifest.get('musubi')!r}") or 1)
want = {
    "choreography": "formats/choreography.md",
    "continuous-choreography": "formats/continuous-choreography.md",
    "motion-language": "formats/motion-language.md",
    "motion-evidence": "formats/motion-evidence.md",
    "check-choreography": "scripts/check-choreography.mjs",
    "check-continuous-choreography": "scripts/check-continuous-choreography.mjs",
    "check-motion-language": "scripts/check-motion-language.mjs",
    "check-motion-evidence": "scripts/check-motion-evidence.mjs",
}
provides = manifest.get("provides") or {}
if sorted(provides) != sorted(want):
    sys.exit(print("musubi.json provides " + ", ".join(sorted(provides)) + ", not " + ", ".join(sorted(want))) or 1)
for name, path in want.items():
    entry = provides[name]
    if entry.get("file") != path:
        sys.exit(print(f"{name} names {entry.get('file')!r}, not {path}") or 1)
    if not re.fullmatch(r"\d+\.\d+\.\d+", str(entry.get("version", ""))):
        sys.exit(print(f"{name} has no MAJOR.MINOR.PATCH version") or 1)
    if not os.path.isfile(os.path.join(skill, path)):
        sys.exit(print(f"{path} does not exist") or 1)
    if f"`{path}`" not in body:
        sys.exit(print(f"SKILL.md does not name `{path}`") or 1)
if manifest.get("follows"):
    sys.exit(print("remotion-motion-plan follows " + ", ".join(manifest["follows"])) or 1)
if "../" in body:
    sys.exit(print("SKILL.md reads a path outside its folder") or 1)
PY
)" || return 1
  why=""
}

# Each motion plan check passes the skill's example, refuses broken copies with the rule and the scene
# or library entry of the issue, and exits 2 when it is called the wrong way.
motion_judgments() {
  command -v node >/dev/null || { why="node is not installed"; return 1; }
  why="$(python3 - "$MOTION" "$T" <<'PY'
import copy, json, os, subprocess, sys
skill, tmp = sys.argv[1], sys.argv[2]
scripts = os.path.join(skill, "scripts")
examples = os.path.join(skill, "examples")
problems = []

def run(script, args):
    p = subprocess.run(["node", os.path.join(scripts, script), *args], capture_output=True, text=True)
    try:
        out = json.loads(p.stdout)
    except ValueError:
        out = None
    return p.returncode, out, p.stderr.strip()

def summary(out, err):
    if out is None:
        return "no JSON result: " + (err.splitlines()[-1][:160] if err else "no output")
    rules = sorted({str(i.get("rule")) for i in out.get("issues") or []})
    return "decision " + str(out.get("decision")) + (" with " + ", ".join(rules) if rules else " and no issue")

def write(name, data):
    path = os.path.join(tmp, name)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f)
    return path

def passes(label, script, args):
    code, out, err = run(script, args)
    if code != 0 or not out or out.get("decision") != "pass" or out.get("issues"):
        problems.append(f"{label}: expected a pass, got exit {code} and {summary(out, err)}")

def refuses(label, script, rule, args, key, value):
    code, out, err = run(script, args)
    hits = [i for i in (out or {}).get("issues") or [] if i.get("rule") == rule]
    if code != 1 or (out or {}).get("decision") != "revise" or not hits:
        problems.append(f"{label}: expected exit 1 with {rule}, got exit {code} and {summary(out, err)}")
    elif not any(i.get(key) == value for i in hits):
        problems.append(f"{label}: the {rule} issue does not name {key} {value}: {hits[0]}")

def load(name):
    with open(os.path.join(examples, name), encoding="utf-8") as f:
        return json.load(f)

def cases():
    # Choreography: every object on screen at entry, no state change, the same grammar twice, a rough
    # that differs from the final cut.
    plan = load("choreography-plan.json")
    passes("the choreography example", "check-choreography.mjs", [write("choreo.json", plan)])
    p = copy.deepcopy(plan)
    for item in p["scenes"][1]["objectLifecycles"]:
        item["introducedAt"] = "entry"
    refuses("a scene that places every object at entry", "check-choreography.mjs", "no-late-introduction",
            [write("choreo-entry.json", p)], "scene", p["scenes"][1]["id"])
    p = copy.deepcopy(plan)
    for item in p["scenes"][0]["objectLifecycles"]:
        item["resultState"] = item["entryState"]
    refuses("a scene where nothing changes state", "check-choreography.mjs", "no-state-change",
            [write("choreo-state.json", p)], "scene", p["scenes"][0]["id"])
    p = copy.deepcopy(plan)
    p["scenes"][1]["viewGrammar"] = p["scenes"][0]["viewGrammar"]
    refuses("two scenes in a row with the same view grammar", "check-choreography.mjs", "repeated-view-grammar",
            [write("choreo-grammar.json", p)], "scene", p["scenes"][1]["id"])
    p = copy.deepcopy(plan)
    p["scenes"][0]["finalMotionParity"]["handoff"] = False
    refuses("a rough whose handoff differs from the final cut", "check-choreography.mjs", "motion-parity",
            [write("choreo-parity.json", p)], "scene", p["scenes"][0]["id"])

    # Continuous choreography: a handoff that clears the board, a summary with a new symbol, the same axis twice.
    plan = load("continuous-choreography-plan.json")
    passes("the continuous choreography example", "check-continuous-choreography.mjs", [write("cont.json", plan)])
    p = copy.deepcopy(plan)
    p["scenes"][1]["entryFrom"]["subject"] = "a-fresh-board"
    refuses("a handoff that clears the board", "check-continuous-choreography.mjs", "handoff-not-carried",
            [write("cont-handoff.json", p)], "scene", p["scenes"][1]["id"])
    p = copy.deepcopy(plan)
    summary_scene = next(s for s in p["scenes"] if s.get("role") == "summary")
    summary_scene["subjects"].append("a-new-symbol")
    refuses("a summary that adds a new symbol", "check-continuous-choreography.mjs", "summary-new-subject",
            [write("cont-summary.json", p)], "scene", summary_scene["id"])
    p = copy.deepcopy(plan)
    if p["scenes"][0].get("primaryAxis") in (None, "none"):
        raise LookupError("the first scene of the continuous example moves along no axis")
    p["scenes"][1]["primaryAxis"] = p["scenes"][0]["primaryAxis"]
    refuses("two scenes in a row moving along the same axis", "check-continuous-choreography.mjs", "repeated-axis",
            [write("cont-axis.json", p)], "scene", p["scenes"][1]["id"])

    # Motion language, against the example evidence library.
    library = load("motion-evidence-library.json")
    lib = write("library.json", library)
    plan = load("motion-language-plan.json")
    passes("the motion language example", "check-motion-language.mjs", [write("lang.json", plan), lib])
    p = copy.deepcopy(plan)
    p["scenes"][0]["evidenceIds"] = []
    refuses("a motion without evidence", "check-motion-language.mjs", "missing-evidence",
            [write("lang-none.json", p), lib], "scene", p["scenes"][0]["id"])
    p = copy.deepcopy(plan)
    p["scenes"][0]["evidenceIds"] = ["no-such-entry"]
    refuses("a motion citing an entry the library lacks", "check-motion-language.mjs", "unknown-evidence",
            [write("lang-unknown.json", p), lib], "scene", p["scenes"][0]["id"])
    candidate = next(e["id"] for e in library["entries"] if e.get("status") == "candidate")
    p = copy.deepcopy(plan)
    p["scenes"][0]["evidenceIds"] = [candidate]
    refuses("a motion citing only a candidate entry", "check-motion-language.mjs", "unverified-evidence",
            [write("lang-candidate.json", p), lib], "scene", p["scenes"][0]["id"])
    p = copy.deepcopy(plan)
    p["scenes"][1]["primaryRecipe"] = p["scenes"][0]["primaryRecipe"]
    refuses("two scenes in a row with the same recipe", "check-motion-language.mjs", "repeated-recipe",
            [write("lang-repeat.json", p), lib], "scene", p["scenes"][1]["id"])

    # Motion evidence library: a verified entry without a time range, a duplicate id, a source without a URL.
    passes("the motion evidence example", "check-motion-evidence.mjs", [lib])
    l = copy.deepcopy(library)
    verified = next(e for e in l["entries"] if e.get("status") == "verified")
    verified["observations"][0]["range"] = "not checked"
    refuses("a verified entry without a time range", "check-motion-evidence.mjs", "verified-without-range",
            [write("lib-range.json", l)], "entry", verified["id"])
    l = copy.deepcopy(library)
    l["entries"][1]["id"] = l["entries"][0]["id"]
    refuses("two entries with one id", "check-motion-evidence.mjs", "duplicate-entry",
            [write("lib-duplicate.json", l)], "entry", l["entries"][0]["id"])
    l = copy.deepcopy(library)
    del l["entries"][0]["source"]["url"]
    refuses("a source without its address", "check-motion-evidence.mjs", "source-shape",
            [write("lib-source.json", l)], "entry", l["entries"][0]["id"])

    # Called the wrong way.
    for script, args in (("check-choreography.mjs", []), ("check-continuous-choreography.mjs", []),
                         ("check-motion-language.mjs", [write("lang-alone.json", plan)]), ("check-motion-evidence.mjs", [])):
        code, _, _ = run(script, args)
        if code != 2:
            problems.append(f"{script} with {len(args)} arguments: expected exit 2 for a wrong call, got {code}")

try:
    cases()
except (OSError, ValueError, LookupError, KeyError, IndexError, StopIteration, TypeError) as e:
    problems.append(f"{type(e).__name__}: {e}")
if problems:
    print(f"{len(problems)} problems; the first: {problems[0]}")
    sys.exit(1)
PY
)" || return 1
  why=""
}

# catalog_run makes five source repositories in the throwaway folder, lists them with a pinned commit
# each, runs sync, build, and search of remotion-catalog with HOME there, then again with
# REMOTION_EXPLAINER_HOME, and writes what it saw to $T/catalog-run.json for the three checks below.
catalog_run() {
  [ -f "$T/catalog-run.json" ] && return 0
  python3 - "$CATALOG" "$T" <<'PY'
import json, os, stat, subprocess, sys
skill, tmp = sys.argv[1], sys.argv[2]
script = os.path.join(skill, "scripts", "catalog.mjs")
repos = os.path.join(tmp, "repos")
home = os.path.join(tmp, "home")
work = os.path.join(tmp, "work")
custom = os.path.join(tmp, "custom")
for d in (repos, home, work):
    os.makedirs(d, exist_ok=True)
base_env = {"PATH": os.environ["PATH"], "HOME": home, "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_AUTHOR_NAME": "Test", "GIT_AUTHOR_EMAIL": "test@example.com", "GIT_COMMITTER_NAME": "Test",
            "GIT_COMMITTER_EMAIL": "test@example.com", "GIT_AUTHOR_DATE": "2026-01-01T00:00:00Z",
            "GIT_COMMITTER_DATE": "2026-01-01T00:00:00Z"}

def git(repo, *args):
    return subprocess.run(["git", "-C", repo, *args], env=base_env, capture_output=True, text=True, check=True).stdout.strip()

def repo(name, files, later=None):
    path = os.path.join(repos, name)
    os.makedirs(path)
    git(path, "init", "-q")
    git(path, "config", "uploadpack.allowReachableSHA1InWant", "true")
    git(path, "config", "uploadpack.allowAnySHA1InWant", "true")
    for rel, text in files.items():
        os.makedirs(os.path.dirname(os.path.join(path, rel)) or path, exist_ok=True)
        with open(os.path.join(path, rel), "w", encoding="utf-8") as f:
            f.write(text)
    git(path, "add", "-A")
    git(path, "commit", "-q", "-m", "first")
    pinned = git(path, "rev-parse", "HEAD")
    for rel, text in (later or {}).items():
        with open(os.path.join(path, rel), "w", encoding="utf-8") as f:
            f.write(text)
        git(path, "add", "-A")
        git(path, "commit", "-q", "-m", "later")
    return path, pinned

readme = ("# Example templates\n\n### Motion (2)\n\n| Template | File | Description |\n|---|---|---|\n"
          "| Route line | `route-line.tsx` | A route path drawn along a bezier line |\n"
          "| Title reveal | `title-reveal.tsx` | A title that fades in word by word |\n\n"
          "### Devices (1)\n\n| Template | File | Description |\n|---|---|---|\n"
          "| Phone frame | `phone-frame.tsx` | A phone screen shown as a device |\n")
alpha, alpha_pin = repo("alpha", {
    "LICENSE": "MIT License\n", "README.md": readme,
    "templates/route-line.tsx": "export const RouteLine = () => <path d='M0 0 C10 10 20 10 30 0' strokeDashoffset={1} />;\n",
    "templates/title-reveal.tsx": "export const TitleReveal = () => <h1>Each word of the title fades in</h1>;\n",
    "templates/phone-frame.tsx": "export const PhoneFrame = () => <div className='phone screen' />;\n",
    "media/clip.txt": "a stand-in for a media file the list leaves out\n",
}, later={"templates/late-added.tsx": "export const LateAdded = () => null;\n"})
library = {"cards": [{"name": "card-stack", "category": "ui-entrance", "summary": "Cards slide in and stack with depth",
                      "use": "Showing items gathered into a pile", "tags": ["cards", "stack"],
                      "source": "references/card-stack.md",
                      "styles": [{"key": "card-stack-slide", "label": "Card stack slide",
                                  "description": "Cards slide in from the side and stack with depth"}]}]}
beta, beta_pin = repo("beta", {
    "LICENSE": "Apache License\nVersion 2.0, January 2004\n",
    "gallery/api/library.json": json.dumps(library),
    "references/card-stack.md": "# Card stack\n\nCards slide in and stack.\n",
    "demos/ui-entrance/card-stack/CardStack.tsx": "export const CardStack = () => <div className='stack of cards' />;\n",
})
gamma, gamma_pin = repo("gamma", {"README.md": "# No license here\n", "templates/a.tsx": "export const A = 1;\n"})
delta, _ = repo("delta", {"LICENSE": "MIT License\n", "templates/b.tsx": "export const B = 1;\n"})
epsilon, epsilon_pin = repo("epsilon", {"LICENSE": "All rights reserved\n", "templates/c.tsx": "export const C = 1;\n"})
files_adapter = {"kind": "files", "folder": "templates", "extension": ".tsx", "readme": "README.md"}
sources = {"schemaVersion": 1, "sources": [
    {"id": "alpha", "repository": f"file://{alpha}", "commit": alpha_pin, "license": "MIT", "licenseEvidence": "LICENSE",
     "exclude": ["media/"], "adapter": files_adapter},
    {"id": "beta", "repository": f"file://{beta}", "commit": beta_pin, "license": "Apache-2.0", "licenseEvidence": "LICENSE",
     "adapter": {"kind": "cards", "library": "gallery/api/library.json", "demos": "demos"}},
    {"id": "gamma", "repository": f"file://{gamma}", "commit": gamma_pin, "license": "MIT", "licenseEvidence": "LICENSE",
     "adapter": files_adapter},
    {"id": "delta", "repository": f"file://{delta}", "commit": "main", "license": "MIT", "licenseEvidence": "LICENSE",
     "adapter": files_adapter},
    {"id": "epsilon", "repository": f"file://{epsilon}", "commit": epsilon_pin, "license": "LicenseRef-proprietary",
     "licenseEvidence": "LICENSE", "adapter": files_adapter},
]}
list_file = os.path.join(tmp, "sources.json")
with open(list_file, "w", encoding="utf-8") as f:
    json.dump(sources, f)

def run(args, env_extra=None):
    env = dict(base_env, **(env_extra or {}))
    p = subprocess.run(["node", script, *args], cwd=work, env=env, capture_output=True, text=True)
    try:
        out = json.loads(p.stdout)
    except ValueError:
        out = None
    return {"code": p.returncode, "out": out, "err": p.stderr.strip()[-400:]}

def listing(root):
    found = []
    for r, dirs, names in os.walk(root):
        if ".git" in dirs:
            dirs.remove(".git")
        for n in dirs + names:
            found.append(os.path.relpath(os.path.join(r, n), root))
    return sorted(found)

def mode(path):
    try:
        return oct(stat.S_IMODE(os.stat(path).st_mode))
    except OSError:
        return None

result = {"pins": {"alpha": alpha_pin, "beta": beta_pin}}
result["sync"] = run(["sync", "--sources", list_file])
result["build"] = run(["build", "--sources", list_file])
result["searches"] = {
    "motion route": run(["search", "--layer", "motion", "route"]),
    "typography title": run(["search", "--layer", "typography", "title"]),
    "form phone": run(["search", "--layer", "form", "phone"]),
    "typography phone": run(["search", "--layer", "typography", "phone"]),
    "composition stack": run(["search", "--layer", "composition", "stack"]),
    "no layer": run(["search", "route"]),
    "unknown layer": run(["search", "--layer", "sound", "route"]),
}
data = os.path.join(home, ".local", "share", "remotion-explainer")
clone = os.path.join(data, "catalog", "sources", "alpha")
result["home"] = listing(home)
result["work"] = listing(work)
result["modes"] = {"data": mode(data), "catalog": mode(os.path.join(data, "catalog")),
                   "catalog.json": mode(os.path.join(data, "catalog", "catalog.json"))}
result["sourceFolders"] = sorted(os.listdir(os.path.join(data, "catalog", "sources"))) if os.path.isdir(os.path.join(data, "catalog", "sources")) else []
try:
    result["alphaHead"] = git(clone, "rev-parse", "HEAD")
except (subprocess.CalledProcessError, OSError):
    result["alphaHead"] = None
result["alphaLate"] = os.path.exists(os.path.join(clone, "templates", "late-added.tsx"))
result["alphaMedia"] = os.path.exists(os.path.join(clone, "media"))
before = listing(home)
result["customSync"] = run(["sync", "--sources", list_file], {"REMOTION_EXPLAINER_HOME": custom})
result["customBuild"] = run(["build", "--sources", list_file], {"REMOTION_EXPLAINER_HOME": custom})
result["customHomeUnchanged"] = listing(home) == before
result["custom"] = listing(custom)
result["customModes"] = {"data": mode(custom), "catalog.json": mode(os.path.join(custom, "catalog", "catalog.json"))}
with open(os.path.join(tmp, "catalog-run.json"), "w", encoding="utf-8") as f:
    json.dump(result, f)
PY
}

# catalog_judge <part> runs one part of the judgment below on $T/catalog-run.json.
catalog_judge() {
  command -v node >/dev/null || { why="node is not installed"; return 1; }
  command -v git >/dev/null || { why="git is not installed"; return 1; }
  [ -f "$CATALOG/scripts/catalog.mjs" ] || { why="remotion-catalog has no scripts/catalog.mjs"; return 1; }
  catalog_run 2>"$T/catalog-run.err" || { why="the catalog run stopped: $(tail -1 "$T/catalog-run.err")"; return 1; }
  why="$(python3 - "$1" "$T/catalog-run.json" "$CATALOG" <<'PY'
import json, os, re, sys
part, path, skill = sys.argv[1], sys.argv[2], sys.argv[3]
r = json.load(open(path, encoding="utf-8"))
def fail(message):
    sys.exit(print(message) or 1)
def out(step):
    if not r[step]["out"]:
        fail(f"{step} printed no JSON (exit {r[step]['code']}): {r[step]['err']}")
    return r[step]["out"]
if part == "fetch":
    sync = out("sync")
    if r["sync"]["code"] != 1:
        fail(f"sync exited {r['sync']['code']}, not 1, although three sources had to be left out")
    fetched = sorted(item["id"] for item in sync.get("fetched", []))
    left = {item["id"]: item.get("reason", "") for item in sync.get("leftOut", [])}
    if fetched != ["alpha", "beta"]:
        fail(f"sync fetched {fetched}, not alpha and beta")
    if sorted(left) != ["delta", "epsilon", "gamma"] or not all(left.values()):
        fail(f"sync left out {left}, not gamma, delta, and epsilon each with a reason")
    if "licen" not in left["gamma"].lower() or "licen" not in left["epsilon"].lower() or "commit" not in left["delta"].lower():
        fail(f"the reasons do not name the license or the commit: {left}")
    if r["sourceFolders"] != ["alpha", "beta"]:
        fail(f"the data folder holds the sources {r['sourceFolders']}, not only alpha and beta")
    if r["alphaHead"] != r["pins"]["alpha"]:
        fail(f"alpha is at {r['alphaHead']}, not at its pinned commit {r['pins']['alpha']}")
    if r["alphaLate"]:
        fail("alpha holds a file of a commit after the pinned one")
    if r["alphaMedia"]:
        fail("alpha holds the media folder its entry excludes")
    shipped = json.load(open(os.path.join(skill, "data", "sources.json"), encoding="utf-8"))
    allowed = {"MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC", "0BSD", "CC0-1.0", "Unlicense"}
    if not shipped.get("sources"):
        fail("data/sources.json lists no source")
    for s in shipped["sources"]:
        if not re.fullmatch(r"[0-9a-f]{40}", str(s.get("commit", ""))):
            fail(f"{s.get('id')} in data/sources.json has no pinned commit")
        if not str(s.get("repository", "")).startswith("https://"):
            fail(f"{s.get('id')} in data/sources.json is not fetched over https")
        if s.get("license") not in allowed or not s.get("licenseEvidence"):
            fail(f"{s.get('id')} in data/sources.json has no allowed license with its evidence")
elif part == "search":
    build = out("build")
    if r["build"]["code"] != 0 or not build.get("items"):
        fail(f"build exited {r['build']['code']} with {build.get('items')} items")
    s = r["searches"]
    def results(key):
        step = s[key]
        if step["code"] != 0 or not step["out"]:
            fail(f"search {key} exited {step['code']}: {step['err']}")
        return step["out"].get("results", [])
    for key, layer in (("motion route", "motion"), ("typography title", "typography"), ("form phone", "form"),
                       ("typography phone", "typography"), ("composition stack", "composition")):
        for item in results(key):
            if layer not in (item.get("layers") or {}) or not item["layers"][layer]:
                fail(f"search {key} returned {item.get('id')}, which has no {layer} layer")
            if not item.get("source") or not item.get("file"):
                fail(f"search {key} returned {item.get('id')} without its source and file")
    want = {"motion route": ("alpha:route-line", "alpha", "templates/route-line.tsx"),
            "typography title": ("alpha:title-reveal", "alpha", "templates/title-reveal.tsx"),
            "form phone": ("alpha:phone-frame", "alpha", "templates/phone-frame.tsx"),
            "composition stack": ("beta:card-stack-slide", "beta", "demos/ui-entrance/card-stack/CardStack.tsx")}
    for key, (id_, source, file) in want.items():
        hit = [i for i in results(key) if i.get("id") == id_]
        if not hit or hit[0].get("source") != source or hit[0].get("file") != file:
            fail(f"search {key} did not return {id_} from {source} with the file {file}")
    if any(i.get("id") == "alpha:phone-frame" for i in results("typography phone")):
        fail("the typography layer returned the phone frame, which has no typography")
    if s["no layer"]["code"] != 2 or s["unknown layer"]["code"] != 2:
        fail(f"a search without a known layer exited {s['no layer']['code']} and {s['unknown layer']['code']}, not 2")
elif part == "folder":
    for step in ("sync", "build"):
        out(step)
    prefix = os.path.join(".local", "share", "remotion-explainer")
    stray = [p for p in r["home"] if not (p == prefix or p.startswith(prefix + os.sep) or prefix.startswith(p + os.sep) or p in (".local", os.path.join(".local", "share")))]
    if stray:
        fail(f"the catalog wrote outside its data folder: {stray[:3]}")
    if r["work"]:
        fail(f"the catalog wrote into the folder it ran from: {r['work'][:3]}")
    if r["modes"] != {"data": "0o700", "catalog": "0o700", "catalog.json": "0o600"}:
        fail(f"the data folder is not readable only by the user: {r['modes']}")
    if r["customSync"]["code"] != 1 or r["customBuild"]["code"] != 0 or not r["customHomeUnchanged"]:
        fail("with REMOTION_EXPLAINER_HOME the catalog did not keep to that folder")
    if os.path.join("catalog", "catalog.json") not in r["custom"] or r["customModes"] != {"data": "0o700", "catalog.json": "0o600"}:
        fail(f"REMOTION_EXPLAINER_HOME does not hold the catalog readable only by the user: {r['customModes']}")
PY
)" || return 1
  why=""
}
catalog_fetch() { catalog_judge fetch; }
catalog_search() { catalog_judge search; }
catalog_folder() { catalog_judge folder; }

check "the READMEs state the Remotion license terms" readme_license
check "AGENTS.md names the plugin's Node.js use" agents_node
check "remotion-frame-checks provides its contracts and checks" frame_provides
check "the frame checks accept valid and refuse broken examples" frame_judgments
check "remotion-motion-plan provides its contracts and checks" motion_provides
check "the motion plan checks accept valid and refuse broken plans" motion_judgments
check "remotion-catalog fetches only licensed sources at pinned commits" catalog_fetch
check "remotion-catalog searches each layer" catalog_search
check "remotion-catalog keeps its data in its own folder" catalog_folder

printf 'checks: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
