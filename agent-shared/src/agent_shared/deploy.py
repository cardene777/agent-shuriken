"""Plans and writes what agent-shared places in each agent.

A source is a folder with the `.shared` layout: `skills/<name>/SKILL.md`, `rules/*.md`, and
`hooks.json` (the `hooks` object of Claude Code's settings). The agent table says where each agent
keeps skills, rules, and hooks. Every run first plans the whole change and checks it; when anything
must be refused, nothing is written.

What agent-shared placed is told apart from what the user wrote by hand in three ways:

  skill and rule links  the record (`placed.json`) names each link and the target it was given
  the rules block       `<!-- agent-shared begin source=<id> -->` ... `<!-- agent-shared end source=<id> -->`
  hooks                 the command's last line is `# agent-shared 1 source=<id>`, a shell comment

`<id>` is the first 12 hex digits of the SHA-256 of the source folder's real path, so each source
removes only what it placed itself.
"""

import hashlib
import json
import os
import queue
import shutil
import subprocess
import tempfile
import threading
import tomllib
from importlib import resources

MARK = "# agent-shared 1 source="
BEGIN = "<!-- agent-shared begin source={} -->"
END = "<!-- agent-shared end source={} -->"
RULE = "<!-- agent-shared rule {} -->"
MARK_LINE_START = "<!-- agent-shared "
TABLE_VERSION = 1
RECORD_VERSION = 1
CODEX_TIMEOUT = 30
RULE_FORMS = ("link", "block")
TRUST_KINDS = ("codex-app-server",)
PLUGIN_KINDS = ("claude", "codex")


class Refused(Exception):
    """The run must not write anything. `lines` names each reason."""

    def __init__(self, lines):
        super().__init__("\n".join(lines))
        self.lines = lines


class Usage(Exception):
    """The command line, a source folder, the agent table, or the record cannot be used."""


class TrustFailed(Exception):
    """Codex could not be asked to trust the hooks. The text is the reason."""


def home():
    return os.path.expanduser("~")


def expand(path):
    return os.path.abspath(os.path.expanduser(path))


def shown(path):
    """The path as printed: the home folder is written as `~`."""
    top = home()
    if path == top:
        return "~"
    if path.startswith(top + os.sep):
        return "~" + path[len(top):]
    return path


def source_id(path):
    return hashlib.sha256(os.path.realpath(path).encode("utf-8")).hexdigest()[:12]


def read_json(path, what):
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, UnicodeError, ValueError) as error:
        raise Usage("{} {} cannot be read as JSON ({})".format(what, shown(path), error))


def skill_names(folder):
    """The names of the folders under `folder` that hold a SKILL.md, in name order."""
    if not os.path.isdir(folder):
        return []
    return [name for name in sorted(os.listdir(folder))
            if not name.startswith(".") and os.path.isfile(os.path.join(folder, name, "SKILL.md"))]


class Source:
    """A folder with the `.shared` layout."""

    def __init__(self, path):
        self.path = os.path.abspath(path)
        self.id = source_id(self.path)

    def skills(self):
        base = os.path.join(self.path, "skills")
        return {name: os.path.join(base, name) for name in skill_names(base)}

    def rules(self):
        base = os.path.join(self.path, "rules")
        if not os.path.isdir(base):
            return {}
        return {name: os.path.join(base, name) for name in sorted(os.listdir(base))
                if name.endswith(".md") and not name.startswith(".") and os.path.isfile(os.path.join(base, name))}

    def hooks(self, agent_names):
        """The declared hooks as (event, group without hooks, hook, tools) with the source folder filled in.
        `tools` is the set of agent names the hook goes to, or None for every agent."""
        path = os.path.join(self.path, "hooks.json")
        if not os.path.exists(path):
            return []
        data = read_json(path, "the hook declaration")
        events = data.get("hooks") if isinstance(data, dict) else None
        if not isinstance(events, dict):
            raise Usage("{} has no `hooks` object that maps events to lists of groups".format(shown(path)))
        declared = []
        for event, groups in events.items():
            if not isinstance(groups, list) or not all(isinstance(group, dict) for group in groups):
                raise Usage("`hooks.{}` in {} is not a list of groups".format(event, shown(path)))
            for group in groups:
                hooks = group.get("hooks")
                if not isinstance(hooks, list) or not hooks:
                    raise Usage("a group of `hooks.{}` in {} has no list of hooks".format(event, shown(path)))
                bare = {key: value for key, value in group.items() if key != "hooks"}
                for hook in hooks:
                    if not isinstance(hook, dict) or not isinstance(hook.get("command"), str):
                        raise Usage("a hook of `hooks.{}` in {} has no command string".format(event, shown(path)))
                    hook = dict(hook, command=hook["command"].replace("${CLAUDE_PLUGIN_ROOT}", self.path))
                    tools = hook.pop("tools", None)
                    if tools is not None:
                        if not isinstance(tools, list) or not tools or not all(isinstance(t, str) for t in tools):
                            raise Usage("the `tools` of a hook of `hooks.{}` in {} is not a list of agent names"
                                        .format(event, shown(path)))
                        unknown = sorted(set(tools) - set(agent_names))
                        if unknown:
                            raise Usage("a hook of `hooks.{}` in {} names agents that are not in the table: {}"
                                        .format(event, shown(path), ", ".join(unknown)))
                        tools = frozenset(tools)
                    declared.append((event, bare, hook, tools))
        return declared


def load_table(user_table):
    """The agent table: the default rows, with the rows of the user's table replacing or adding rows by name."""
    default = json.loads(resources.files("agent_shared").joinpath("agents.json").read_text(encoding="utf-8"))
    rows = checked_rows(default, "the default agent table")
    if user_table and os.path.exists(user_table):
        for row in checked_rows(read_json(user_table, "the agent table"), shown(user_table)):
            names = [existing["name"] for existing in rows]
            if row["name"] in names:
                rows[names.index(row["name"])] = row
            else:
                rows.append(row)
    return rows


def checked_rows(table, where):
    if not isinstance(table, dict) or table.get("version") != TABLE_VERSION or not isinstance(table.get("agents"), list):
        raise Usage("{} is not an agent table of version {} with an `agents` list".format(where, TABLE_VERSION))
    rows = []
    for row in table["agents"]:
        problem = None
        if not isinstance(row, dict) or not isinstance(row.get("name"), str) or not row["name"]:
            problem = "a row has no name"
        elif not isinstance(row.get("skills"), str):
            problem = "the row {} has no skills folder".format(row["name"])
        elif "repo_skills" in row and not isinstance(row["repo_skills"], str):
            problem = "the repo_skills of {} is not a path".format(row["name"])
        elif "rules" in row and not (isinstance(row["rules"], dict) and isinstance(row["rules"].get("place"), str)
                                     and row["rules"].get("form") in RULE_FORMS):
            problem = "the rules of {} need a place and a form ({})".format(row["name"], " or ".join(RULE_FORMS))
        elif "hooks" in row and not (isinstance(row["hooks"], dict) and isinstance(row["hooks"].get("file"), str)
                                     and row["hooks"].get("trust", TRUST_KINDS[0]) in TRUST_KINDS):
            problem = "the hooks of {} need a file".format(row["name"])
        elif "plugins" in row and row["plugins"] not in PLUGIN_KINDS:
            problem = "the plugins of {} is not one of {}".format(row["name"], ", ".join(PLUGIN_KINDS))
        if problem:
            raise Usage("{}: {}".format(where, problem))
        rows.append(row)
    return rows


def claude_plugin_skills(warnings):
    """{skill name: plugin} for the plugins installed in Claude Code and not turned off."""
    base = os.path.join(home(), ".claude")
    installed = os.path.join(base, "plugins", "installed_plugins.json")
    if not os.path.exists(installed):
        return {}
    try:
        data = read_json(installed, "Claude Code's plugin list")
        settings = os.path.join(base, "settings.json")
        enabled = (read_json(settings, "Claude Code's settings") if os.path.exists(settings) else {}).get("enabledPlugins") or {}
    except Usage as error:
        warnings.append("{}; skills were placed for Claude Code without checking its plugins".format(error))
        return {}
    found = {}
    for key, entries in (data.get("plugins") or {}).items():
        if enabled.get(key) is False or not isinstance(entries, list):
            continue
        for entry in entries:
            install = entry.get("installPath") if isinstance(entry, dict) else None
            if isinstance(install, str):
                for name in skill_names(os.path.join(install, "skills")):
                    found.setdefault(name, key)
    return found


def codex_plugin_skills(warnings):
    """{skill name: plugin} for the plugins turned on in Codex's config.toml."""
    config = os.path.join(home(), ".codex", "config.toml")
    if not os.path.exists(config):
        return {}
    try:
        with open(config, "rb") as handle:
            data = tomllib.load(handle)
    except (OSError, tomllib.TOMLDecodeError) as error:
        warnings.append("{} cannot be read ({}); skills were placed for Codex without checking its plugins"
                        .format(shown(config), error))
        return {}
    cache = os.path.join(home(), ".codex", "plugins", "cache")
    found = {}
    for key, table in (data.get("plugins") or {}).items():
        if not isinstance(table, dict) or table.get("enabled") is not True:
            continue
        name, _, market = key.partition("@")
        base = os.path.join(cache, market, name)
        for version in sorted(os.listdir(base)) if os.path.isdir(base) else []:
            for skill in skill_names(os.path.join(base, version, "skills")):
                found.setdefault(skill, key)
    return found


class Record:
    """What agent-shared placed, per source: each link and the target it was given."""

    def __init__(self):
        folder = os.environ.get("AGENT_SHARED_STATE") or os.path.join(home(), ".local", "share", "agent-shared")
        self.folder = os.path.abspath(os.path.expanduser(folder))
        self.path = os.path.join(self.folder, "placed.json")
        self.sources = {}
        if os.path.exists(self.path):
            data = read_json(self.path, "the record")
            if not isinstance(data, dict) or data.get("version") != RECORD_VERSION or not isinstance(data.get("sources"), dict):
                raise Usage("the record {} is not of version {}; move it away to start a new record"
                            .format(shown(self.path), RECORD_VERSION))
            self.sources = data["sources"]

    def links(self, ids):
        return {place: target for sid in ids for place, target in (self.sources.get(sid) or {}).get("links", {}).items()}

    def owner(self, place):
        for sid, entry in self.sources.items():
            if place in entry.get("links", {}):
                return sid, entry
        return None, None

    def save(self, sources, links_by_source):
        for source in sources:
            links = links_by_source.get(source.id, {})
            if links:
                self.sources[source.id] = {"path": source.path, "links": dict(sorted(links.items()))}
            else:
                self.sources.pop(source.id, None)
        os.makedirs(self.folder, exist_ok=True)
        os.chmod(self.folder, 0o700)
        text = json.dumps({"version": RECORD_VERSION, "sources": self.sources}, ensure_ascii=False, indent=2) + "\n"
        handle, temporary = tempfile.mkstemp(dir=self.folder, prefix=".placed-")
        try:
            with os.fdopen(handle, "w", encoding="utf-8") as out:
                out.write(text)
            os.chmod(temporary, 0o600)
            os.replace(temporary, self.path)
        except BaseException:
            if os.path.exists(temporary):
                os.unlink(temporary)
            raise


def find_repo(argument):
    """The repository whose `.shared` is deployed: the named one, or the one that holds the current folder."""
    if argument:
        root = expand(argument)
        if not os.path.isdir(os.path.join(root, ".shared")):
            raise Usage("{} has no .shared folder".format(shown(root)))
        return root
    here, top = os.getcwd(), home()
    while True:
        if os.path.exists(os.path.join(here, ".git")):
            return here if here != top and os.path.isdir(os.path.join(here, ".shared")) else None
        parent = os.path.dirname(here)
        if parent == here:
            return None
        here = parent


def is_marked(hook, ids=None):
    """Whether agent-shared placed the hook, from any source or from one of `ids`."""
    command = hook.get("command") if isinstance(hook, dict) else None
    if not isinstance(command, str) or "\n" not in command:
        return False
    last = command.rsplit("\n", 1)[1]
    return last.startswith(MARK) and (ids is None or last[len(MARK):] in ids)


def read_agent_json(path, refusals):
    """An agent's JSON settings, {} when the file does not exist, or None after adding a refusal."""
    if not os.path.exists(path):
        return {}
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, UnicodeError, ValueError) as error:
        refusals.append("{} cannot be read as JSON ({})".format(shown(path), error))
        return None
    hooks = data.get("hooks", {}) if isinstance(data, dict) else None
    if not isinstance(hooks, dict) or not all(isinstance(groups, list) for groups in hooks.values()):
        refusals.append("{} has a `hooks` value that is not a map of events to lists".format(shown(path)))
        return None
    return data


def with_hooks(data, ids, groups_by_event):
    """The settings with the hooks of the sources `ids` taken out and the declared groups added at the end."""
    data = json.loads(json.dumps(data))
    events = data.get("hooks")
    if events is None:
        if not groups_by_event:
            return data
        events = data["hooks"] = {}
    emptied = False
    for event in list(events):
        kept_groups = []
        for group in events[event]:
            inner = group.get("hooks", []) if isinstance(group, dict) else []
            kept = [hook for hook in inner if not is_marked(hook, ids)]
            if isinstance(group, dict) and len(kept) != len(inner):
                if not kept:
                    continue
                group = dict(group, hooks=kept)
            kept_groups.append(group)
        if kept_groups or not events[event]:
            events[event] = kept_groups
        else:
            del events[event]
            emptied = True
    for event, groups in groups_by_event.items():
        events.setdefault(event, []).extend(groups)
    if not events and emptied:
        del data["hooks"]
    return data


def block_lines(lines, sid, where, refusals):
    """The (begin, end) line numbers of the source's block in a rules file, None when it has none."""
    begins = [i for i, line in enumerate(lines) if line.rstrip("\n") == BEGIN.format(sid)]
    ends = [i for i, line in enumerate(lines) if line.rstrip("\n") == END.format(sid)]
    if not begins and not ends:
        return None
    if len(begins) != 1 or len(ends) != 1 or ends[0] < begins[0]:
        refusals.append("the agent-shared block of {} is broken; remove its marker lines by hand".format(shown(where)))
        return None
    return begins[0], ends[0]


def rules_block(sid, rules):
    out = [BEGIN.format(sid) + "\n"]
    for name, path in rules:
        with open(path, encoding="utf-8") as handle:
            body = handle.read()
        out.append(RULE.format(name) + "\n")
        out.append(body if body.endswith("\n") else body + "\n")
    out.append(END.format(sid) + "\n")
    return "".join(out)


def write_text(path, text):
    """Replaces the file's text in one step and keeps its mode."""
    folder = os.path.dirname(path)
    os.makedirs(folder, exist_ok=True)
    handle, temporary = tempfile.mkstemp(dir=folder, prefix=".agent-shared-")
    try:
        with os.fdopen(handle, "w", encoding="utf-8") as out:
            out.write(text)
        if os.path.exists(path):
            shutil.copymode(path, temporary)
        else:
            os.chmod(temporary, 0o644)
        os.replace(temporary, path)
    except BaseException:
        if os.path.exists(temporary):
            os.unlink(temporary)
        raise


class CodexServer:
    """Talks to `codex app-server` with one JSON message per line, reading the settings in `codex_home`."""

    def __init__(self, command, codex_home):
        env = dict(os.environ, CODEX_HOME=codex_home)
        try:
            self.proc = subprocess.Popen([command, "app-server"], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                         stderr=subprocess.DEVNULL, text=True, env=env, cwd=codex_home)
        except OSError as error:
            raise TrustFailed("Codex could not be started ({})".format(error.strerror or error))
        self.lines = queue.Queue()
        self.next_id = 0
        threading.Thread(target=self._read, daemon=True).start()

    def _read(self):
        for line in self.proc.stdout:
            self.lines.put(line)
        self.lines.put(None)

    def send(self, message):
        try:
            self.proc.stdin.write(json.dumps(message) + "\n")
            self.proc.stdin.flush()
        except OSError:
            raise TrustFailed("Codex stopped before {}".format(message.get("method")))

    def call(self, method, params):
        self.next_id += 1
        request_id = self.next_id
        self.send({"id": request_id, "method": method, "params": params})
        while True:
            try:
                line = self.lines.get(timeout=CODEX_TIMEOUT)
            except queue.Empty:
                raise TrustFailed("{} got no answer in {} seconds".format(method, CODEX_TIMEOUT))
            if line is None:
                raise TrustFailed("Codex stopped before answering {}".format(method))
            try:
                message = json.loads(line)
            except ValueError:
                continue
            if message.get("id") != request_id:
                continue
            if "error" in message:
                error = message["error"]
                raise TrustFailed("{} returned an error ({})".format(
                    method, error.get("message") if isinstance(error, dict) else error))
            return message.get("result") or {}

    def close(self):
        try:
            self.proc.stdin.close()
        except OSError:
            pass
        try:
            self.proc.terminate()
            self.proc.wait(timeout=5)
        except (OSError, subprocess.SubprocessError):
            self.proc.kill()


def trust_codex_hooks(place):
    """Asks Codex to trust the hooks agent-shared placed in `place`, the way Codex's /hooks screen does.
    Returns the number of keys changed, or None when there is no codex command."""
    name = os.environ.get("AGENT_SHARED_CODEX_BIN", "codex")
    command = shutil.which(name) if name else None
    if command is None:
        return None
    real = os.path.realpath(place)
    server = CodexServer(command, os.path.dirname(place))
    try:
        server.call("initialize", {"clientInfo": {"name": "agent-shared", "version": "1"}})
        server.send({"method": "initialized"})
        listed, marked = set(), {}
        for group in server.call("hooks/list", {}).get("data") or []:
            for hook in group.get("hooks") or []:
                if hook.get("source") != "user" or hook.get("pluginId") or not hook.get("key"):
                    continue
                if os.path.realpath(hook.get("sourcePath") or "") != real:
                    continue
                listed.add(hook["key"])
                if is_marked({"command": hook.get("command")}) and hook.get("currentHash"):
                    marked[hook["key"]] = hook["currentHash"]
        layers = server.call("config/read", {"includeLayers": True}).get("layers") or []
        user = next((layer for layer in layers if (layer.get("name") or {}).get("type") == "user"), {})
        state = ((user.get("config") or {}).get("hooks") or {}).get("state") or {}
        if not isinstance(state, dict):
            raise TrustFailed("Codex's hooks.state is not a map of keys")
        wanted = {key: dict(entry) if isinstance(entry, dict) else entry for key, entry in state.items()}
        for key, digest in marked.items():
            entry = wanted.get(key)
            wanted[key] = dict(entry if isinstance(entry, dict) else {}, trusted_hash=digest)
        for key in list(wanted):
            if os.path.realpath(key.rsplit(":", 3)[0]) == real and key not in listed:
                del wanted[key]
        if wanted == state:
            return 0
        params = {"edits": [{"keyPath": "hooks.state", "value": wanted, "mergeStrategy": "replace"}]}
        if user.get("version"):
            params["expectedVersion"] = user["version"]
        result = server.call("config/batchWrite", params)
        if result.get("status") != "ok":
            raise TrustFailed("config/batchWrite answered {}".format(result.get("status")))
        return sum(1 for key in set(wanted) | set(state) if wanted.get(key) != state.get(key))
    finally:
        server.close()


def user_sources(extra_sources):
    """~/.shared when it exists, then every --source folder once, in the order given."""
    main_path = os.path.join(home(), ".shared")
    sources = [Source(main_path)] if os.path.isdir(main_path) else []
    for path in extra_sources:
        path = expand(path)
        if not os.path.isdir(path):
            raise Usage("the source folder {} does not exist".format(shown(path)))
        if source_id(path) not in {source.id for source in sources}:
            sources.append(Source(path))
    return sources


def agent_table():
    main_path = os.path.join(home(), ".shared")
    return load_table(os.path.join(main_path, "agents.json") if os.path.isdir(main_path) else None)


def agent_hook_groups(declared, agent_name):
    """The groups deploy adds to one agent's hook file, by event, and the (event, command) pairs they carry.
    Each declared hook goes in its own copy of its group, with the source's mark on a last line of its command."""
    groups, commands = {}, set()
    for source, event, bare, hook, tools in declared:
        if tools is not None and agent_name not in tools:
            continue
        commands.add((event, hook["command"]))
        marked = dict(hook, command=hook["command"] + "\n" + MARK + source.id)
        groups.setdefault(event, []).append(dict(bare, hooks=[marked]))
    return groups, commands


def hooks(agent_name, extra_sources):
    """Prints, as JSON, the hook groups deploy would add to the agent's hook file. Writes nothing. Returns 0."""
    sources = user_sources(extra_sources)
    if not sources:
        raise Usage("there are no hooks to print: create ~/.shared, or pass --source")
    table = agent_table()
    agent_names = [row["name"] for row in table]
    if agent_name not in agent_names:
        raise Usage("the agent {} is not in the agent table (agents: {})".format(agent_name, ", ".join(agent_names)))
    row = next(row for row in table if row["name"] == agent_name)
    groups = {}
    if "hooks" in row:
        declared = [(source,) + hook for source in sources for hook in source.hooks(agent_names)]
        groups, _commands = agent_hook_groups(declared, agent_name)
    print(json.dumps({"hooks": groups}, ensure_ascii=False, indent=2))
    return 0


def deploy(extra_sources, repo_argument):
    """Plans the deployment, refuses before writing when anything is in the way, then writes it. Returns 0."""
    sources = user_sources(extra_sources)
    repo_root = find_repo(repo_argument)
    repo = Source(os.path.join(repo_root, ".shared")) if repo_root else None
    if not sources and repo is None:
        raise Usage("there is nothing to deploy: create ~/.shared, or pass --source or --repo")

    table = agent_table()
    agent_names = [row["name"] for row in table]
    record = Record()
    run = sources + ([repo] if repo else [])
    run_ids = {source.id for source in run}
    refusals, warnings, notes = [], [], []

    skills, rules, declared = {}, {}, []
    for source in sources:
        for kind, found, items in (("skill", skills, source.skills()), ("rule", rules, source.rules())):
            for name, path in items.items():
                if name in found:
                    refusals.append("the {} {} is in two sources: {} and {}".format(
                        kind, name, shown(found[name][1].path), shown(source.path)))
                else:
                    found[name] = (path, source)
        declared += [(source,) + hook for hook in source.hooks(agent_names)]

    # links: place -> (target text, source)
    wanted = {}
    blocks = {}
    hook_files = {}
    plugin_cache = {}
    for row in table:
        kind = row.get("plugins")
        if kind and kind not in plugin_cache:
            plugin_cache[kind] = (claude_plugin_skills if kind == "claude" else codex_plugin_skills)(warnings)
        plugins = plugin_cache.get(kind, {})
        base = expand(row["skills"])
        for name, (path, source) in skills.items():
            if name in plugins:
                notes.append("skipped the skill {} for {}: the plugin {} already has it".format(name, row["name"], plugins[name]))
            else:
                wanted[os.path.join(base, name)] = (path, source)
        if "rules" in row:
            place = expand(row["rules"]["place"])
            if row["rules"]["form"] == "link":
                for name, (path, source) in rules.items():
                    wanted[os.path.join(place, name)] = (path, source)
            else:
                blocks[place] = {source.id: sorted((name, path) for name, (path, owner) in rules.items() if owner is source)
                                 for source in sources}
        if "hooks" in row:
            place = expand(row["hooks"]["file"])
            entry = hook_files.setdefault(place, {"trust": row["hooks"].get("trust"), "groups": {}, "commands": set()})
            groups, commands = agent_hook_groups(declared, row["name"])
            entry["commands"] |= commands
            for event, added in groups.items():
                entry["groups"].setdefault(event, []).extend(added)
        if repo and isinstance(row.get("repo_skills"), str):
            base = os.path.join(repo_root, row["repo_skills"])
            for name, path in repo.skills().items():
                wanted[os.path.join(base, name)] = (os.path.relpath(path, base), repo)

    # The links in the way: something agent-shared did not place, or a link placed from another source.
    for place, (target, source) in sorted(wanted.items()):
        owner, entry = record.owner(place)
        if owner is not None and owner not in run_ids:
            refusals.append("{} was placed from another source, {}; deploy both sources in one run"
                            .format(shown(place), shown(entry.get("path", "?"))))
        elif os.path.lexists(place) and not (owner is not None and os.path.islink(place)
                                              and os.readlink(place) == record.sources[owner]["links"][place]):
            refusals.append("{} is in the way: agent-shared did not place it".format(shown(place)))

    blocks_text = {}
    for place, by_source in blocks.items():
        text = ""
        if os.path.exists(place):
            with open(place, encoding="utf-8") as handle:
                text = handle.read()
        lines = text.splitlines(keepends=True)
        for sid, items in by_source.items():
            for name, path in items:
                with open(path, encoding="utf-8") as handle:
                    if any(line.startswith(MARK_LINE_START) for line in handle):
                        refusals.append("the rule {} has a line that starts like an agent-shared marker".format(shown(path)))
            found = block_lines(lines, sid, place, refusals)
            new = rules_block(sid, items).splitlines(keepends=True) if items else []
            if found:
                lines[found[0]:found[1] + 1] = new
            elif new:
                if lines and not lines[-1].endswith("\n"):
                    lines[-1] += "\n"
                lines += new
        new_text = "".join(lines)
        if new_text != text:
            blocks_text[place] = new_text

    hooks_text = {}
    for place, entry in hook_files.items():
        data = read_agent_json(place, refusals)
        if data is None:
            continue
        hand = {(event, hook["command"]) for event, groups in data.get("hooks", {}).items()
                for group in groups if isinstance(group, dict) for hook in group.get("hooks", [])
                if isinstance(hook, dict) and isinstance(hook.get("command"), str) and not is_marked(hook)}
        for event, command in sorted(entry["commands"] & hand):
            refusals.append("{} has a hook that agent-shared did not place with the same command: {} {}"
                            .format(shown(place), event, command))
        new = with_hooks(data, run_ids, entry["groups"])
        if new != data:
            hooks_text[place] = json.dumps(new, ensure_ascii=False, indent=2) + "\n"

    if refusals:
        raise Refused(refusals)

    # Write: take out links this run no longer places, then place the rest.
    placed = {source.id: {} for source in run}
    for place, target in sorted(record.links(run_ids).items()):
        if place in wanted and wanted[place][0] == target:
            continue
        if os.path.islink(place) and os.readlink(place) == target:
            os.unlink(place)
            notes.append("removed {}".format(shown(place)))
    for place, (target, source) in sorted(wanted.items()):
        placed[source.id][place] = target
        if os.path.islink(place) and os.readlink(place) == target:
            continue
        os.makedirs(os.path.dirname(place), exist_ok=True)
        os.symlink(target, place)
        notes.append("placed {}".format(shown(place)))
    for place, text in sorted(blocks_text.items()):
        write_text(place, text)
        notes.append("wrote the rules block in {}".format(shown(place)))
    for place, text in sorted(hooks_text.items()):
        write_text(place, text)
        notes.append("wrote the hooks in {}".format(shown(place)))
    record.save(run, placed)

    for place, entry in sorted(hook_files.items()):
        if entry["trust"] != "codex-app-server" or not os.path.exists(place):
            continue
        with open(place, encoding="utf-8") as handle:
            if place not in hooks_text and MARK not in handle.read():
                continue
        how = "Open /hooks in Codex once and trust the hooks in {}.".format(shown(place))
        try:
            changed = trust_codex_hooks(place)
        except TrustFailed as error:
            warnings.append("Codex's hook trust was not written ({}). {}".format(error, how))
            continue
        if changed is None:
            warnings.append("Codex was not found, so it does not trust the hooks yet. {}".format(how))
        elif changed:
            notes.append("wrote Codex's trust for the hooks in {}".format(shown(place)))

    for line in notes:
        print(line)
    for line in warnings:
        print("warning: " + line)
    print("deployed {} skills and {} rules from {} source{} to {}".format(
        len(skills) + (len(repo.skills()) if repo else 0), len(rules), len(run), "" if len(run) == 1 else "s",
        ", ".join(agent_names)))
    return 0
