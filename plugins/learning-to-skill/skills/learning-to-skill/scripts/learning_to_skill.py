#!/usr/bin/env python3
"""Write a lesson from a session into the instruction files your agents read, after you approve the diff.

Commands:
  files    [--root DIR] [--home] [--json]
      List the instruction files and skills in the project, which agents read each one, the
      links and imports between them, repeated lines, and files over the size budget.
  check    [--root DIR] [--home] [--threshold N] --text LINE [--text LINE]...
      Show the lines in those files that say the same as LINE, or come close.
  propose  --file PATH [PLACEMENT] [--create] [--root DIR] --text LINE [--text LINE]...
      Print the diff that would add the lines to PATH and a fingerprint of that exact change.
      Nothing is written.
  apply    the same arguments as propose, plus --expect FINGERPRINT
      Write the change, only when the file and the lines still give FINGERPRINT.

PLACEMENT is one of --section HEADING, --new-section HEADING, --after-line N, --replace-line N,
or nothing for the end of the file.

The project is the nearest folder at or above the current folder that holds .git, or --root.
propose and apply change only instruction files inside the project or in the agents' folders in
your home folder.

Exit codes: 0 done. 1 check found a similar line, or propose and apply refused the change
(the line is already there, or the section is missing or ambiguous). 2 bad input.
3 the file or the change is not the one that was proposed; nothing was written.
"""
import argparse
import difflib
import hashlib
import json
import os
import re
import stat
import sys
import tempfile
from collections import Counter

CLAUDE = "Claude Code"
CODEX = "Codex"
COPILOT = "GitHub Copilot CLI"
GEMINI = "Gemini CLI"
AGENTS = (CLAUDE, CODEX, COPILOT, GEMINI)
IMPORTERS = (CLAUDE, GEMINI)  # agents that follow @path imports in the files they read

# Folders never searched: dependencies, build output, and caches.
SKIP_DIRS = {"node_modules", "vendor", "dist", "build", "out", "target", "venv", "env", "__pycache__",
             "coverage", "bower_components", "Pods", "DerivedData"}
# Hidden folders that hold agent instructions; every other hidden folder is skipped.
AGENT_DIRS = {".claude", ".github", ".gemini", ".agents"}
MAX_DEPTH = 8
# Where each agent loads project skills from: <folder>/<skill>/SKILL.md.
SKILL_FOLDERS = {
    ".claude/skills": (CLAUDE, COPILOT),
    ".agents/skills": (CODEX, GEMINI, COPILOT),
    ".github/skills": (COPILOT,),
    ".gemini/skills": (GEMINI,),
}
NAMED_FILES = ("AGENTS.md", "AGENTS.override.md", "CLAUDE.md", "CLAUDE.local.md", "GEMINI.md", "SKILL.md")
LINE_BUDGET = 200
SKILL_LINE_BUDGET = 500
CODEX_BYTES = 32768  # Codex reads at most this many bytes of AGENTS.md files (project_doc_max_bytes).
SIMILAR = 0.5
SHOWN_MATCHES = 5
SHOWN_REPEATS = 20
MAX_IMPORT_DEPTH = 5

FENCE = re.compile(r"^\s{0,3}(`{3,}|~{3,})")
HEADING = re.compile(r"^\s{0,3}(#{1,6})\s+(.*?)\s*#*\s*$")
LIST_ITEM = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s")
TABLE_RULE = re.compile(r"^\s*\|?\s*:?-{3,}")
IMPORT = re.compile(r"(?:^|\s)@([^\s]+)")


def die(message, code=2):
    print(message, file=sys.stderr)
    sys.exit(code)


def home():
    return os.path.expanduser("~")


def claude_home():
    return os.environ.get("CLAUDE_CONFIG_DIR") or os.path.join(home(), ".claude")


def codex_home():
    return os.environ.get("CODEX_HOME") or os.path.join(home(), ".codex")


def home_agent_dirs():
    h = home()
    return [claude_home(), codex_home()] + [os.path.join(h, d) for d in (".gemini", ".copilot", ".agents")]


def inside(path, folder):
    path, folder = os.path.abspath(path), os.path.abspath(folder)
    return path == folder or path.startswith(folder.rstrip(os.sep) + os.sep)


def project_root(start):
    """The nearest folder at or above start that holds .git, or start itself."""
    d = os.path.abspath(start)
    while True:
        if os.path.exists(os.path.join(d, ".git")):
            return d
        parent = os.path.dirname(d)
        if parent == d:
            return os.path.abspath(start)
        d = parent


def show(path, root):
    """A path as the user would write it: relative to the project, ~/ in the home folder, or absolute."""
    path = os.path.abspath(path)
    if root and inside(path, root):
        return os.path.relpath(path, root)
    if inside(path, home()) and path != home():
        return "~/" + os.path.relpath(path, home())
    return path


# ------------------------------------------------------------------ reading markdown

def read_text(path):
    """The file as text, or None when it cannot be read as UTF-8."""
    try:
        with open(path, "rb") as f:
            return f.read().decode("utf-8-sig")
    except (OSError, UnicodeDecodeError):
        return None


def split_lines(text):
    """Split into lines without line endings, and say whether the text ended with a newline."""
    if text == "":
        return [], False
    lines = re.split(r"\r?\n", text)
    final = lines[-1] == ""
    if final:
        lines.pop()
    return lines, final


def body_start(lines):
    """Index of the first line after YAML frontmatter, or 0 when there is none."""
    if lines and lines[0].strip() == "---":
        for i in range(1, len(lines)):
            if lines[i].strip() in ("---", "..."):
                return i + 1
    return 0


def scan(lines):
    """Yield (index, kind, extra) for each line: kind is front, fence, code, heading, or text."""
    start = body_start(lines)
    fence = None
    for i, line in enumerate(lines):
        if i < start:
            yield i, "front", None
            continue
        m = FENCE.match(line)
        if fence is None and m:
            fence = m.group(1)[0]
            yield i, "fence", None
            continue
        if fence is not None:
            if m and m.group(1)[0] == fence:
                fence = None
                yield i, "fence", None
            else:
                yield i, "code", None
            continue
        h = HEADING.match(line)
        if h:
            yield i, "heading", (len(h.group(1)), h.group(2))
        else:
            yield i, "text", None


def headings(lines):
    return [(i, extra[0], extra[1]) for i, kind, extra in scan(lines) if kind == "heading"]


def content_lines(lines):
    """(line number, text) of the lines that can hold a rule: not blank, code, headings, or frontmatter."""
    out = []
    for i, kind, _ in scan(lines):
        line = lines[i]
        if kind == "text" and line.strip() and not TABLE_RULE.match(line):
            out.append((i + 1, line))
    return out


def has_paths_frontmatter(lines):
    end = body_start(lines)
    return any(re.match(r"^(paths|applyTo)\s*:", line) for line in lines[1:end])


def norm(text):
    """Lower case, without list markers, markdown punctuation, or repeated spaces."""
    text = re.sub(r"^\s*(?:[-*+]|\d+[.)])\s+(?:\[[ xX]\]\s+)?", "", text)
    text = re.sub(r"[^\w\s]", " ", text.lower())
    return re.sub(r"\s+", " ", text).strip()


def norm_title(text):
    return norm(re.sub(r"^\s*#+\s*", "", text))


def similarity(a, b):
    """Dice coefficient of character pairs, which works with and without spaces between words."""
    if a == b:
        return 1.0
    sa, sb = a.replace(" ", ""), b.replace(" ", "")
    pa = Counter(sa[i:i + 2] for i in range(len(sa) - 1))
    pb = Counter(sb[i:i + 2] for i in range(len(sb) - 1))
    if not pa or not pb:
        return 0.0
    score = 2.0 * sum((pa & pb).values()) / (sum(pa.values()) + sum(pb.values()))
    short, longer = (a, b) if len(a) <= len(b) else (b, a)
    if len(short) >= 12 and short in longer:
        score = max(score, 0.9)
    return min(score, 0.99)


# ------------------------------------------------------------------ finding the files

def gemini_names(settings_paths):
    """The context file names Gemini CLI reads, from the first settings file that sets context.fileName."""
    for p in settings_paths:
        try:
            with open(p, encoding="utf-8") as f:
                data = json.load(f)
        except (OSError, ValueError):
            continue
        value = (data.get("context") or {}).get("fileName") if isinstance(data, dict) else None
        if isinstance(value, str) and value.strip():
            return [value.strip()], p
        if isinstance(value, list):
            names = [v.strip() for v in value if isinstance(v, str) and v.strip()]
            if names:
                return names, p
    return ["GEMINI.md"], None


def skill_folder_type(rel):
    """The skill folder (such as .claude/skills) a SKILL.md path sits in, and the folder above that."""
    parts = rel.split("/")
    i = len(parts) - 4
    if i >= 0 and parts[i] + "/" + parts[i + 1] in SKILL_FOLDERS:
        return parts[i] + "/" + parts[i + 1], "/".join(parts[:i])
    return None, None


def count_md(folder):
    """The .md files in a skill folder, other than SKILL.md itself."""
    n = 0
    top = folder.count(os.sep)
    for dirpath, dirnames, filenames in os.walk(folder, followlinks=True):
        dirnames[:] = [d for d in dirnames if not d.startswith(".")] if dirpath.count(os.sep) - top < 3 else []
        n += sum(1 for f in filenames if f.endswith(".md") and not (dirpath == folder and f == "SKILL.md"))
    return n


def walk_project(root, names):
    """Relative paths of the instruction files and SKILL.md files under root."""
    found = []
    for dirpath, dirnames, filenames in os.walk(root):
        rel = os.path.relpath(dirpath, root)
        rel = "" if rel == "." else rel.replace(os.sep, "/")
        depth = 0 if not rel else rel.count("/") + 1
        if os.path.basename(dirpath) == "skills" and os.path.basename(os.path.dirname(dirpath)) in AGENT_DIRS:
            # Agent skill folders often hold links to skills kept elsewhere, so follow them here.
            for name in sorted(os.listdir(dirpath)):
                if not name.startswith(".") and os.path.isfile(os.path.join(dirpath, name, "SKILL.md")):
                    found.append(rel + "/" + name + "/SKILL.md")
            dirnames[:] = []
            continue
        keep = []
        for d in dirnames:
            if d in SKIP_DIRS or (d.startswith(".") and d not in AGENT_DIRS) or depth >= MAX_DEPTH:
                continue
            if os.path.exists(os.path.join(dirpath, d, ".git")):
                continue  # another repository, a submodule, or a worktree
            keep.append(d)
        dirnames[:] = sorted(keep)
        for f in sorted(filenames):
            p = (rel + "/" + f).lstrip("/")
            if (f in NAMED_FILES or f in names or p == ".github/copilot-instructions.md"
                    or (p.startswith(".github/instructions/") and f.endswith(".instructions.md"))
                    or ("/.claude/rules/" in "/" + p and f.endswith(".md"))):
                found.append(p)
    return found


def new_entry(abs_path, display, home_level=False):
    text = read_text(abs_path)
    lines = split_lines(text)[0] if text is not None else []
    try:
        size = os.path.getsize(abs_path)
    except OSError:
        size = 0
    return {"path": display, "abs": os.path.abspath(abs_path), "real": os.path.realpath(abs_path),
            "link": os.path.islink(abs_path), "kind": "instructions", "folder": "", "readers": [],
            "notes": [], "lines": len(lines), "bytes": size, "home": home_level, "scoped": False,
            "_lines": lines}


def add_reader(entry, agent, how=""):
    if (agent, how) not in entry["readers"]:
        entry["readers"].append((agent, how))


def classify_project(rel, entry, names, has_claude_md, overrides):
    """Fill in which agents read a project file, from its name and place."""
    name = os.path.basename(rel)
    folder = os.path.dirname(rel)
    if name == "SKILL.md":
        entry["kind"] = "skill"
        key, above = skill_folder_type(rel)
        if key:
            for agent in SKILL_FOLDERS[key]:
                add_reader(entry, agent)
            entry["folder"] = above
            if above:
                entry["notes"].append("for work in " + above + "/")
        else:
            entry["folder"] = folder
            entry["notes"].append("no agent loads it from here")
        extra = count_md(os.path.dirname(entry["abs"]))
        if extra:
            entry["notes"].append("%d more .md file%s in the skill folder" % (extra, "" if extra == 1 else "s"))
        return
    if rel == ".github/copilot-instructions.md":
        add_reader(entry, COPILOT)
        return
    if rel.startswith(".github/instructions/"):
        add_reader(entry, COPILOT)
        entry["scoped"] = True
        entry["notes"].append("only for files matching its applyTo")
        return
    if "/.claude/rules/" in "/" + rel:
        add_reader(entry, CLAUDE)
        entry["folder"] = rel.split(".claude/rules/")[0].rstrip("/")
        if entry["folder"]:
            entry["notes"].append("for work in " + entry["folder"] + "/")
        if has_paths_frontmatter(entry["_lines"]):
            entry["scoped"] = True
            entry["notes"].append("only for files matching its paths")
        return
    if os.path.basename(folder) == ".claude" and name == "CLAUDE.md":
        folder = os.path.dirname(folder)
    entry["folder"] = folder
    if folder:
        entry["notes"].append("for work in " + folder + "/")
    if name == "AGENTS.override.md":
        add_reader(entry, CODEX)
        entry["notes"].append("Codex reads it in place of AGENTS.md")
    if name == "AGENTS.md":
        if folder in overrides:
            entry["notes"].append("Codex reads AGENTS.override.md here instead")
        else:
            add_reader(entry, CODEX)
        add_reader(entry, COPILOT)
        if not has_claude_md:
            add_reader(entry, CLAUDE, "the project has no CLAUDE.md")
    if name == "CLAUDE.md":
        add_reader(entry, CLAUDE)
        if rel == "CLAUDE.md":
            add_reader(entry, COPILOT)
    if name == "CLAUDE.local.md":
        add_reader(entry, CLAUDE)
        entry["notes"].append("personal, usually not committed")
    if name in names:
        add_reader(entry, GEMINI)
    elif name == "GEMINI.md":
        entry["notes"].append("Gemini CLI reads " + ", ".join(names) + " instead")
    if name == "GEMINI.md" and rel == "GEMINI.md":
        add_reader(entry, COPILOT)


def home_files():
    """The instruction files in the home folder with their readers, and the home skill folders."""
    h = home()
    claude, codex = claude_home(), codex_home()
    files = [(os.path.join(claude, "CLAUDE.md"), (CLAUDE,))]
    for dirpath, dirnames, filenames in os.walk(os.path.join(claude, "rules")):
        dirnames[:] = sorted(d for d in dirnames if not d.startswith("."))
        files += [(os.path.join(dirpath, f), (CLAUDE,)) for f in sorted(filenames) if f.endswith(".md")]
    override = os.path.join(codex, "AGENTS.override.md")
    files.append((override if os.path.isfile(override) else os.path.join(codex, "AGENTS.md"), (CODEX,)))
    names, _ = gemini_names([os.path.join(h, ".gemini", "settings.json")])
    files += [(os.path.join(h, ".gemini", n), (GEMINI,)) for n in names]
    files.append((os.path.join(h, ".copilot", "copilot-instructions.md"), (COPILOT,)))
    skills = [(os.path.join(claude, "skills"), (CLAUDE, COPILOT)), (os.path.join(codex, "skills"), (CODEX,)),
              (os.path.join(h, ".agents", "skills"), (CODEX, GEMINI, COPILOT)),
              (os.path.join(h, ".gemini", "skills"), (GEMINI,)), (os.path.join(h, ".copilot", "skills"), (COPILOT,))]
    return [(p, r) for p, r in files if os.path.isfile(p)], skills


def list_skills(folder):
    try:
        names = sorted(os.listdir(folder))
    except OSError:
        return []
    return [n for n in names if not n.startswith(".") and os.path.isfile(os.path.join(folder, n, "SKILL.md"))]


def importers(entry):
    """The agents that read this file and follow the @path imports in it."""
    return [a for a in IMPORTERS if any(x == a for x, _ in entry["readers"])]


def imports_of(entry):
    """Files that an instruction file pulls in with @path, outside code, as Claude Code and Gemini CLI read them."""
    base = os.path.dirname(entry["abs"])
    out = []
    for i, kind, _ in scan(entry["_lines"]):
        if kind not in ("text", "heading"):
            continue
        line = re.sub(r"`[^`]*`", " ", entry["_lines"][i])
        for m in IMPORT.finditer(line):
            target = m.group(1).rstrip(".,;:)]")
            if not target:
                continue
            if target.startswith("~/"):
                path = os.path.expanduser(target)
            else:
                path = target if os.path.isabs(target) else os.path.join(base, target)
            if os.path.isfile(path):
                out.append(os.path.abspath(path))
    return out


def discover(root, with_home=False, extra=None):
    """Every instruction file and skill the agents read, with readers, links, and imports resolved.

    extra is a project-relative path to include even when it does not exist yet."""
    settings = [os.path.join(root, ".gemini", "settings.json")]
    if with_home:
        settings.append(os.path.join(home(), ".gemini", "settings.json"))
    names, names_from = gemini_names(settings)
    rels = walk_project(root, set(names))
    if extra and extra not in rels:
        rels.append(extra)
    has_claude_md = any(os.path.basename(r) == "CLAUDE.md" for r in rels)
    overrides = {os.path.dirname(r) for r in rels if os.path.basename(r) == "AGENTS.override.md"}
    entries = []
    for rel in rels:
        e = new_entry(os.path.join(root, rel), rel)
        classify_project(rel, e, set(names), has_claude_md, overrides)
        entries.append(e)
    skill_dirs = []
    if with_home:
        files, skill_dirs = home_files()
        for path, readers in files:
            e = new_entry(path, show(path, None), home_level=True)
            for a in readers:
                add_reader(e, a)
            e["notes"].append("every project")
            entries.append(e)
    by_abs = {e["abs"]: e for e in entries}
    by_real = {}
    for e in entries:
        if not e["link"]:
            by_real.setdefault(e["real"], e)
    # Links: the agents that read a link read the file it points at.
    for e in entries:
        if e["link"]:
            target = by_real.get(e["real"])
            e["notes"].append("link to " + (target["path"] if target else show(e["real"], root)))
            if target:
                for agent, _ in list(e["readers"]):
                    add_reader(target, agent, "through the link " + e["path"])
    # Imports: Claude Code and Gemini CLI also read the files their instruction files import with @path.
    queue = [(e, 0) for e in entries if e["kind"] != "skill" and importers(e)]
    seen = set()
    while queue:
        src, depth = queue.pop(0)
        key = (src["abs"], tuple(importers(src)))
        if key in seen or depth >= MAX_IMPORT_DEPTH:
            continue
        seen.add(key)
        for path in imports_of(src):
            target = by_abs.get(path) or by_real.get(os.path.realpath(path))
            if target is None:
                target = new_entry(path, show(path, root), home_level=src["home"])
                target["kind"] = "imported"
                target["folder"] = src["folder"]
                entries.append(target)
                by_abs[target["abs"]] = target
                by_real.setdefault(target["real"], target)
            if "imports " + target["path"] not in src["notes"]:
                src["notes"].append("imports " + target["path"])
            for agent in importers(src):
                add_reader(target, agent, "imported by " + src["path"])
            if src["scoped"]:
                target["scoped"] = True
            queue.append((target, depth + 1))
    return entries, skill_dirs, names, names_from


# ------------------------------------------------------------------ summaries

def always_loaded(e):
    return e["kind"] != "skill" and not e["folder"] and not e["scoped"]


def agent_view(entries):
    """For each agent, the files it reads in every session: at the project root and in the home folder."""
    reals = {x["real"] for x in entries if not x["link"]}
    view = {}
    for agent in AGENTS:
        items = []
        for e in entries:
            if (e["link"] and e["real"] in reals) or not always_loaded(e):
                continue
            hows = [h for a, h in e["readers"] if a == agent]
            if not hows:
                continue
            how = "" if "" in hows else hows[0]
            if e["home"] and not how:
                how = "every project"
            items.append((how not in ("", "every project"), e["path"] + (" (" + how + ")" if how else "")))
        # Files the agent reads by name come first, then the ones it reaches through links and imports.
        view[agent] = [label for _, label in sorted(items, key=lambda x: x[0])]
    return view


def missing_hint(agent, names):
    wanted = {CLAUDE: ["CLAUDE.md"], CODEX: ["AGENTS.md"],
              COPILOT: ["AGENTS.md", ".github/copilot-instructions.md"], GEMINI: names}[agent]
    return "it reads %s, which %s missing" % (" and ".join(wanted), "is" if len(wanted) == 1 else "are")


def widest(entries):
    """The project root file that reaches the most agents, and those agents."""
    best, best_agents = None, []
    for e in entries:
        if e["link"] or e["home"] or not always_loaded(e):
            continue
        agents = [a for a in AGENTS if any(x == a for x, _ in e["readers"])]
        if len(agents) > len(best_agents):
            best, best_agents = e, agents
    return best, best_agents


def unique(entries):
    done = set()
    for e in entries:
        if e["real"] not in done:
            done.add(e["real"])
            yield e


def repeated(entries):
    """Lines that appear more than once across the instruction files, after normalizing."""
    places, order = {}, []
    for e in unique(entries):
        for n, line in content_lines(e["_lines"]):
            key = norm(line)
            if len(key) < 12:
                continue
            if key not in places:
                places[key] = []
                order.append(key)
            places[key].append((e["path"], n, line.strip()))
    return [(places[k][0][2], places[k]) for k in order if len(places[k]) > 1]


def codex_chain_bytes(entries):
    """For each folder with an AGENTS file Codex reads, the bytes Codex reads from the root down to it."""
    codex = {e["folder"]: e for e in entries
             if not e["home"] and e["kind"] == "instructions" and any(a == CODEX for a, _ in e["readers"])}
    out = {}
    for folder, e in codex.items():
        parts = folder.split("/") if folder else []
        out[e["path"]] = sum(codex[f]["bytes"] for f in ("/".join(parts[:i]) for i in range(len(parts) + 1))
                             if f in codex)
    return out


def over_budget(entries):
    out = []
    chain = codex_chain_bytes(entries)
    for e in unique(entries):
        limit = SKILL_LINE_BUDGET if os.path.basename(e["abs"]) == "SKILL.md" else LINE_BUDGET
        if e["lines"] > limit:
            out.append((e["path"], "%d lines, over the budget of %d" % (e["lines"], limit)))
        if chain.get(e["path"], 0) > CODEX_BYTES:
            out.append((e["path"], "Codex reads at most %d KiB of AGENTS.md files from the root down, and "
                        "these have %d bytes" % (CODEX_BYTES // 1024, chain[e["path"]])))
    return out


def readers_text(e):
    parts = [a + (" (" + h + ")" if h else "") for a, h in e["readers"]]
    return ", ".join(parts) if parts else "no agent"


def root_of(args):
    return os.path.abspath(args.root) if args.root else project_root(os.getcwd())


# ------------------------------------------------------------------ files

def cmd_files(args):
    root = root_of(args)
    entries, skill_dirs, names, names_from = discover(root, args.home)
    view = agent_view(entries)
    best, best_agents = widest(entries)
    home_skills = [(d, r, list_skills(d)) for d, r in skill_dirs]
    home_skills = [x for x in home_skills if x[2]]
    if args.json:
        print(json.dumps({
            "root": root,
            "gemini_context_files": names,
            "files": [{"path": e["path"], "kind": e["kind"], "lines": e["lines"], "bytes": e["bytes"],
                       "readers": [{"agent": a, "how": h} for a, h in e["readers"]], "notes": e["notes"],
                       "link": e["link"], "home": e["home"]} for e in entries],
            "agents": view,
            "widest": best["path"] if best else None,
            "repeated": [{"line": line, "places": ["%s:%d" % (p, n) for p, n, _ in places]}
                         for line, places in repeated(entries)],
            "over_budget": [{"path": p, "why": why} for p, why in over_budget(entries)],
            "home_skills": [{"folder": show(d, None), "readers": list(r), "skills": s} for d, r, s in home_skills],
        }, indent=2))
        return 0

    print("Instruction files in %s" % show(root, None))
    if names_from:
        print("Gemini CLI reads %s, as %s says." % (", ".join(names), show(names_from, root)))
    print()
    if not entries:
        print("  none yet")
    else:
        width = min(max(len(e["path"]) for e in entries), 60)
        for e in entries:
            notes = "; ".join(e["notes"])
            print("  %-*s %5d %-5s  %s%s" % (width, e["path"], e["lines"], "line" if e["lines"] == 1 else "lines",
                                              readers_text(e), "; " + notes if notes else ""))
    if home_skills:
        print()
        print("Skill folders in your home folder")
        for d, r, skills in home_skills:
            print("  %s  %d skill%s, read by %s: %s" % (show(d, None), len(skills), "" if len(skills) == 1 else "s",
                                                       ", ".join(r), ", ".join(skills)))
    print()
    print("Each agent, in every session")
    for agent in AGENTS:
        items = view[agent]
        print("  %-19s %s" % (agent, ", ".join(items) if items else "nothing (%s)" % missing_hint(agent, names)))
    print()
    if best:
        print("%s reaches the most agents: %s." % (best["path"], ", ".join(best_agents)))
    else:
        print("No instruction file at the project root yet.")
    reps = repeated(entries)
    if reps:
        print()
        print("Repeated lines")
        for line, places in reps[:SHOWN_REPEATS]:
            print("  %s" % line)
            print("    %s" % ", ".join("%s:%d" % (p, n) for p, n, _ in places))
        if len(reps) > SHOWN_REPEATS:
            print("  and %d more" % (len(reps) - SHOWN_REPEATS))
    over = over_budget(entries)
    if over:
        print()
        print("Over the size budget")
        for path, why in over:
            print("  %s  %s" % (path, why))
    return 0


# ------------------------------------------------------------------ check

def all_lines(entries):
    return [(e["path"], n, line.strip(), norm(line)) for e in unique(entries)
            for n, line in content_lines(e["_lines"])]


def matches_for(text, lines, threshold):
    key = norm(text)
    found = []
    for path, n, line, other in lines:
        if key and other:
            score = similarity(key, other)
            if score >= threshold:
                found.append((score, path, n, line))
    found.sort(key=lambda x: (-x[0], x[1], x[2]))
    return found[:SHOWN_MATCHES]


def print_matches(found):
    for score, path, n, line in found:
        print("  %-4s  %s:%d  %s" % ("same" if score >= 1.0 else "%.2f" % score, path, n, line))


def validate_texts(texts):
    if not texts:
        die("Give the rule with --text, once per line.")
    for t in texts:
        if "\n" in t or "\r" in t:
            die("A --text value holds a line break. Pass each line as its own --text.")
    if not any(t.strip() for t in texts):
        die("Every --text value is blank.")


def cmd_check(args):
    validate_texts(args.text)
    root = root_of(args)
    entries = discover(root, args.home)[0]
    lines = all_lines(entries)
    if not lines:
        print("No instruction files to compare with in %s." % show(root, None))
        return 0
    any_found = False
    for t in args.text:
        if not t.strip():
            continue
        print("Rule: %s" % t.strip())
        found = matches_for(t, lines, args.threshold)
        if found:
            any_found = True
            print_matches(found)
        else:
            print("  nothing similar")
    return 1 if any_found else 0


# ------------------------------------------------------------------ propose and apply

def in_skill_folder(path):
    d = os.path.dirname(path)
    for _ in range(5):
        if os.path.isfile(os.path.join(d, "SKILL.md")):
            return True
        parent = os.path.dirname(d)
        if parent == d:
            break
        d = parent
    return False


def is_instruction_file(path, gemini):
    for p in {path, os.path.realpath(path)}:
        name = os.path.basename(p)
        if name in NAMED_FILES or name in gemini or name.endswith(".instructions.md"):
            return True
        if name == "copilot-instructions.md":
            return True
        if name.endswith(".md") and ("/.claude/rules/" in p.replace(os.sep, "/") or in_skill_folder(p)):
            return True
    return False


def is_list_block(lines, last):
    """Whether the paragraph that ends at index last is a list."""
    i = last
    while i > 0 and lines[i - 1].strip():
        i -= 1
    return bool(LIST_ITEM.match(lines[i]))


def place(lines, texts, args):
    """Return (insert index, lines replaced, lines to insert, description), or exit with a refusal."""
    if args.replace_line is not None or args.after_line is not None:
        n = args.replace_line if args.replace_line is not None else args.after_line
        if not 1 <= n <= len(lines):
            die("Line %d is outside the file, which has %d lines." % (n, len(lines)))
        if args.replace_line is not None:
            return n - 1, 1, list(texts), "in place of line %d" % n
        return n, 0, list(texts), "after line %d" % n
    heads = headings(lines)
    if args.new_section is not None:
        title = norm_title(args.new_section)
        if not title:
            die("--new-section needs a heading.")
        if any(norm_title(h[2]) == title for h in heads):
            die("The section \"%s\" already exists. Use --section to add to it." % args.new_section.strip(), 1)
        level = max(2, min((h[1] for h in heads), default=2))
        block = ["#" * level + " " + re.sub(r"^\s*#+\s*", "", args.new_section).strip(), ""] + list(texts)
        last = max((i for i, line in enumerate(lines) if line.strip()), default=-1)
        if last >= 0:
            block = [""] + block
        return last + 1, len(lines) - last - 1, block, "in a new section at the end of the file"
    start, end, label, heading_line = body_start(lines), len(lines), "at the end of the file", None
    if args.section is not None:
        title = norm_title(args.section)
        found = [h for h in heads if norm_title(h[2]) == title]
        if not found:
            listed = "\n".join("  line %d  %s" % (h[0] + 1, lines[h[0]].strip()) for h in heads) or "  none"
            die("No section \"%s\" in this file. Its headings:\n%s\nPick one with --section, or add one with "
                "--new-section." % (args.section.strip(), listed), 1)
        if len(found) > 1:
            listed = "\n".join("  line %d  %s" % (h[0] + 1, lines[h[0]].strip()) for h in found)
            die("More than one section is called \"%s\":\n%s\nUse --after-line with the line to add after."
                % (args.section.strip(), listed), 1)
        heading_line, level, name = found[0]
        start = heading_line
        end = next((h[0] for h in heads if h[0] > heading_line and h[1] <= level), len(lines))
        label = "at the end of the section \"%s\"" % name
    last = max((i for i in range(start, end) if lines[i].strip()), default=None)
    if last is None:
        # An empty file, or one with only frontmatter.
        return start, 0, ([""] if start else []) + list(texts), label
    if last != heading_line and is_list_block(lines, last) and LIST_ITEM.match(texts[0]):
        block = list(texts)
    else:
        block = [""] + list(texts)
    if last + 1 < len(lines) and lines[last + 1].strip():
        block.append("")
    return last + 1, 0, block, label + ", after line %d" % (last + 1)


def plan(args):
    """Work out the change without writing anything."""
    validate_texts(args.text)
    path = os.path.abspath(args.file)
    root = root_of(args)
    if not inside(path, root) and not any(inside(path, d) for d in home_agent_dirs()):
        die("%s is outside the project %s and the agents' folders in your home folder." % (path, root))
    names, _ = gemini_names([os.path.join(root, ".gemini", "settings.json")])
    if not is_instruction_file(path, set(names)):
        die("%s is not an instruction file. Only AGENTS.md, CLAUDE.md, GEMINI.md, copilot-instructions.md, "
            "*.instructions.md, .claude/rules/*.md, and SKILL.md with the .md files in its folder can be changed."
            % show(path, root))
    real = os.path.realpath(path)
    if os.path.exists(real) and not os.path.isfile(real):
        die("%s is not a regular file." % show(path, root))
    exists = os.path.isfile(real)
    if not exists and not args.create:
        die("%s does not exist. Add --create to start it." % show(path, root))
    raw = b""
    if exists:
        with open(real, "rb") as f:
            raw = f.read()
    try:
        text = raw.decode("utf-8-sig")
    except UnicodeDecodeError:
        die("%s is not UTF-8 text, so it is left as it is." % show(path, root))
    newline = "\r\n" if "\r\n" in text else "\n"
    lines, final = split_lines(text)
    if not lines:
        final = True
    texts = [t.rstrip() for t in args.text]
    replaced = args.replace_line - 1 if args.replace_line is not None else None
    present = {norm(line): n for n, line in content_lines(lines) if n - 1 != replaced}
    for t in texts:
        if norm(t) and norm(t) in present:
            n = present[norm(t)]
            die("This line is already in %s at line %d:\n  %s\nNothing to add." % (
                show(path, root), n, lines[n - 1].strip()), 1)
    pos, removed, block, label = place(lines, texts, args)
    new_lines = lines[:pos] + block + lines[pos + removed:]
    new_text = newline.join(new_lines) + (newline if final and new_lines else "")
    data = (b"\xef\xbb\xbf" if raw.startswith(b"\xef\xbb\xbf") else b"") + new_text.encode("utf-8")
    digest = hashlib.sha256()
    for part in (real.encode("utf-8"), raw if exists else b"\0missing", data):
        digest.update(part)
        digest.update(b"\0")
    display = show(path, root)
    diff = list(difflib.unified_diff(lines, new_lines, fromfile="a/" + display if exists else "/dev/null",
                                     tofile="b/" + display, lineterm="", n=3))
    return {"path": path, "real": real, "root": root, "display": display, "exists": exists, "raw": raw,
            "data": data, "lines": lines, "new_lines": new_lines, "fingerprint": digest.hexdigest()[:16],
            "diff": diff, "label": label, "texts": texts}


def readers_for(p):
    """Which agents read the target file, as text, and the discovered entries."""
    in_home = not inside(p["path"], p["root"])
    extra = None if in_home else os.path.relpath(p["path"], p["root"]).replace(os.sep, "/")
    entries, skill_dirs, _, _ = discover(p["root"], in_home, extra)
    for want_link in (False, True):
        for e in entries:
            if e["real"] == p["real"] and e["link"] == want_link:
                return readers_text(e) + (", in every project" if e["home"] else ""), entries
    for d, readers in skill_dirs:
        if inside(p["path"], d) and os.path.basename(p["path"]) == "SKILL.md":
            return ", ".join(readers) + ", in every project", entries
    if in_skill_folder(p["path"]) and os.path.basename(p["path"]) != "SKILL.md":
        return "agents that use the skill, when its SKILL.md points to this file", entries
    return "no agent loads it by itself", entries


def describe(p):
    readers, entries = readers_for(p)
    print("File       %s" % p["display"])
    if os.path.islink(p["path"]):
        print("Writes to  %s, the file %s links to" % (show(p["real"], p["root"]), p["display"]))
    print("Read by    %s" % readers)
    print("Placement  %s" % p["label"])
    if p["exists"]:
        print("Size       %d -> %d lines" % (len(p["lines"]), len(p["new_lines"])))
    else:
        n = len(p["new_lines"])
        print("Size       new file, %d line%s" % (n, "" if n == 1 else "s"))
    limit = SKILL_LINE_BUDGET if os.path.basename(p["real"]) == "SKILL.md" else LINE_BUDGET
    if len(p["new_lines"]) > limit:
        print("Warning    the file would have %d lines, over the budget of %d. Shorten it or move details "
              "into another file." % (len(p["new_lines"]), limit))
    return entries


def cmd_propose(args):
    p = plan(args)
    entries = describe(p)
    print()
    print("\n".join(p["diff"]))
    print()
    lines = all_lines(entries)
    similar = []
    for t in p["texts"]:
        if t.strip():
            similar += [m for m in matches_for(t, lines, SIMILAR) if m not in similar]
    if similar:
        print("Similar lines already in the instruction files")
        print_matches(sorted(similar, key=lambda x: (-x[0], x[1], x[2]))[:SHOWN_MATCHES])
    else:
        print("Similar lines already in the instruction files: none")
    print()
    print("Fingerprint  %s" % p["fingerprint"])
    print("Nothing was written. Show this diff to the user. After they approve it, run the same command with "
          "apply in place of propose and add --expect %s." % p["fingerprint"])
    return 0


def current_bytes(real):
    try:
        with open(real, "rb") as f:
            return f.read()
    except FileNotFoundError:
        return None


def cmd_apply(args):
    p = plan(args)
    if p["fingerprint"] != args.expect:
        die("%s or the change is not the one that was proposed (fingerprint %s, expected %s). Nothing was "
            "written. Run propose again and show the new diff to the user." % (
                p["display"], p["fingerprint"], args.expect), 3)
    real = p["real"]
    folder = os.path.dirname(real)
    if p["exists"]:
        mode = stat.S_IMODE(os.stat(real).st_mode)
    else:
        os.makedirs(folder, exist_ok=True)
        umask = os.umask(0)
        os.umask(umask)
        mode = 0o666 & ~umask
    fd, tmp = tempfile.mkstemp(prefix=".learning-to-skill-", dir=folder)
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(p["data"])
        os.chmod(tmp, mode)
        # Check once more right before replacing, in case the file changed while this ran.
        if current_bytes(real) != (p["raw"] if p["exists"] else None):
            os.unlink(tmp)
            die("%s changed while writing. Nothing was written. Run propose again." % p["display"], 3)
        os.replace(tmp, real)
    except OSError as error:
        if os.path.exists(tmp):
            os.unlink(tmp)
        die("Could not write %s: %s" % (p["display"], error.strerror or error))
    if current_bytes(real) != p["data"]:
        die("%s does not hold the expected text after writing." % p["display"])
    readers = readers_for(p)[0]
    added = sum(1 for t in p["texts"] if t.strip())
    print("Wrote %d line%s to %s, %s." % (added, "" if added == 1 else "s", show(real, p["root"]), p["label"]))
    print("Read by %s." % readers)
    print("Nothing was committed.")
    return 0


# ------------------------------------------------------------------ command line

def main(argv=None):
    parser = argparse.ArgumentParser(description="Write lessons into the instruction files your agents read.")
    sub = parser.add_subparsers(dest="command")
    sub.required = True

    def common(p, texts=False):
        p.add_argument("--root", help="the project folder (default: the nearest folder with .git)")
        if texts:
            p.add_argument("--text", action="append", default=[], help="one line of the rule; repeat for more")

    f = sub.add_parser("files", help="list the instruction files and which agents read them")
    common(f)
    f.add_argument("--home", action="store_true", help="also list the files in your home folder")
    f.add_argument("--json", action="store_true", help="print JSON")

    c = sub.add_parser("check", help="find lines that already say the same")
    common(c, texts=True)
    c.add_argument("--home", action="store_true", help="also compare with the files in your home folder")
    c.add_argument("--threshold", type=float, default=SIMILAR,
                   help="similarity from 0 to 1 that counts as close (default %.1f)" % SIMILAR)

    for name in ("propose", "apply"):
        p = sub.add_parser(name, help="show the diff of a change" if name == "propose" else "write a proposed change")
        common(p, texts=True)
        p.add_argument("--file", required=True, help="the instruction file to change")
        where = p.add_mutually_exclusive_group()
        where.add_argument("--section", help="add at the end of the section with this heading")
        where.add_argument("--new-section", help="add a section with this heading at the end of the file")
        where.add_argument("--after-line", type=int, help="add right after this line")
        where.add_argument("--replace-line", type=int, help="put the lines in place of this line")
        p.add_argument("--create", action="store_true", help="start the file when it does not exist")
        if name == "apply":
            p.add_argument("--expect", required=True, help="the fingerprint that propose printed")

    args = parser.parse_args(argv)
    return {"files": cmd_files, "check": cmd_check, "propose": cmd_propose, "apply": cmd_apply}[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
